// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u3_tone_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('u3-tone route uses the boot operator and a fixed camera', () {
    final item = showcaseItems.singleWhere((item) => item.label == 'u3-tone');
    expect(AppRoute.boot(model: item.label).screen, AppScreen.showcase);
    expect(item.assetKey, kBuiltinU3ToneKey);
    final logs = <String>[];
    final scene = loadShowcaseScene(item, log: logs.add)!;
    expect(u3Tone(scene.document).name, kBootU3Tone);
    expect(scene.frameRadius, 0);
    expect(scene.document.nodes[scene.cameraNode]!.name, 'u3.tone.camera');
    expect(logs.single, contains('tone=$kBootU3Tone exposure=1 fixed-camera'));
    expect(scene.document.nodes, hasLength(17));
    expect(scene.document.resources, hasLength(18));
    expect(
      scene.document.nodes.values
          .expand((node) => node.components)
          .where((component) => component.type.endsWith('Light')),
      isEmpty,
    );
  });

  test('all five boot documents differ only in the tone field', () {
    final baseline = _withoutTone(buildU3ToneDocument());
    expect(U3Tone.values.map((tone) => tone.name), [
      'pbrNeutral',
      'aces',
      'reinhard',
      'linear',
      'agx',
    ]);
    for (final tone in U3Tone.values) {
      final doc = buildU3ToneDocument(tone: tone);
      expect(u3Tone(doc), tone);
      expect(_withoutTone(doc), baseline);
    }
  });

  test(
    'public controller emits environment upserts and mirrors each selection',
    () {
      final doc = buildU3ToneDocument();
      final baseline = _withoutTone(doc);
      final controller = SceneController()..loadDocument(doc);
      final element = _RecordingElement(controller);
      controller.attachElement(element);
      addTearDown(controller.dispose);
      element.mutations.clear();
      for (final tone in [...U3Tone.values, U3Tone.pbrNeutral]) {
        selectU3Tone(controller, doc, tone);
        final mutation = element.mutations.removeAt(0);
        expect(mutation.tag, D3Protocol.command);
        final op = jsonDecode(utf8.decode(mutation.data)) as Map;
        expect(op['op'], 'upsertResource');
        expect(op['id'], doc.stage.environmentRef!.toToken());
        final resource = op['resource'] as Map;
        expect(resource['toneMapping'], tone.name);
        expect(resource['exposure'], 1);
        expect(resource['environmentIntensity'], 0);
        expect(resource['agxWhite'] ?? 16.29, 16.29);
        expect(resource['agxContrast'] ?? 1.25, 1.25);
        expect(u3Tone(controller.document!), tone);
        expect(u3Tone(doc), tone);
        expect(_withoutTone(controller.document!), baseline);
        expect(_withoutTone(doc), baseline);
      }
      expect(element.mutations, isEmpty);
    },
  );

  test('serialized emission retains HDR gray steps and saturated patches', () {
    final doc = buildU3ToneDocument();
    final wire = jsonDecode(writeFsceneWithExtensions(doc)) as Map;
    final resources = (wire['resources'] as Map).values.cast<Map>();
    final materials = resources.where(
      (resource) => resource['kind'] == 'material',
    );
    final strengths = <double>[];
    for (final material in materials) {
      final props = material['properties'] as Map;
      strengths.add((props['emissiveStrength']['d'] as num).toDouble());
    }
    expect(strengths, [
      0.018,
      0.09,
      0.18,
      0.5,
      1,
      2,
      4,
      12,
      2,
      2,
      2,
      2,
      8,
      8,
      8,
      8,
    ]);
    final colors = doc.resources.values
        .whereType<MaterialResource>()
        .skip(8)
        .map((material) => material.properties['emissive']! as ColorValue);
    expect(colors.map((color) => [color.r, color.g, color.b]), [
      [1, 0.02, 0.02],
      [0.02, 1, 0.02],
      [0.02, 0.02, 1],
      [1, 0.25, 0.02],
      [1, 0.02, 0.02],
      [0.02, 1, 0.02],
      [0.02, 0.02, 1],
      [1, 0.25, 0.02],
    ]);
    final environment =
        doc.resources[doc.stage.environmentRef]! as EnvironmentResource;
    expect(environment.effects.bloomEnabled, isFalse);
    expect(environment.effects.colorGradingEnabled, isFalse);
    expect(environment.effects.vignetteEnabled, isFalse);
    expect(environment.effects.temporalAntiAliasingEnabled, isFalse);
  });

  test('all tile bounds project above the footer on portrait phones', () {
    final item = showcaseItems.singleWhere((item) => item.label == 'u3-tone');
    final scene = loadShowcaseScene(item)!;
    final camera = SceneCamera.fromDocument(
      scene.document,
      cameraNode: scene.cameraNode,
    )!;
    final bounds = documentContentBounds(scene.document)!;
    for (final (width, height) in [(402.0, 874.0), (390.0, 844.0)]) {
      for (final x in [bounds.$1.x, bounds.$2.x]) {
        for (final y in [bounds.$1.y, bounds.$2.y]) {
          for (final z in [bounds.$1.z, bounds.$2.z]) {
            final screen = camera.worldToScreen(
              Vector3(x, y, z),
              width,
              height,
            )!;
            expect(screen.$1, inInclusiveRange(16, width - 16));
            expect(screen.$2, inInclusiveRange(80, height - 200));
          }
        }
      }
    }
  });
}

Map<String, dynamic> _withoutTone(SceneDocument doc) {
  final wire =
      jsonDecode(writeFsceneWithExtensions(doc)) as Map<String, dynamic>;
  final resources = wire['resources'] as Map;
  resources.values
      .cast<Map>()
      .singleWhere((resource) => resource['kind'] == 'environment')
      .remove('toneMapping');
  return wire;
}

class _RecordingElement extends SceneViewElement {
  _RecordingElement(SceneController controller)
    : super(SceneViewLeaf(controller: controller));

  final mutations = <({int tag, Uint8List data})>[];

  @override
  void sendMutation(int tag, Uint8List data) =>
      mutations.add((tag: tag, data: data));
}
