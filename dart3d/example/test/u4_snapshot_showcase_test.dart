// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u4_property_scene.dart';
import 'package:dart3d_example/u4_snapshot_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

List<double> color(MaterialResource material) {
  final c = material.properties['baseColor'] as ColorValue;
  return [c.r, c.g, c.b, c.a];
}

LocalId ref(ComponentSpec component, String field) =>
    (component.properties[field] as ResourceRefValue).id;

void main() {
  test('u4-snapshots loads two cards with an independent variant root', () {
    expect(AppRoute.boot(model: 'u4-snapshots').screen, AppScreen.showcase);
    final item = showcaseItems.singleWhere((i) => i.label == 'u4-snapshots');
    expect(item.assetKey, kBuiltinU4SnapshotsKey);
    final scene = loadShowcaseScene(
      item,
      bytesFor: (_) => fail('snapshot fixture must not load assets'),
    )!;
    final doc = scene.document;
    expect(scene.frameRadius, 0);
    expect(scene.cameraNode, u4SnapshotNode(doc, 'camera').id);
    expect(scene.summary, 'Left → right: current · snapshot');
    expect(doc.nodes, hasLength(4));
    expect(doc.resources, hasLength(6));
    expect(doc.payloads, hasLength(4));
    final a = u4SnapshotMaterial(doc, 'A');
    final b = u4SnapshotMaterial(doc, 'B');
    expect(a.type, 'unlit');
    expect(a.properties.keys.toSet(), {'baseColor', 'baseColorTexture'});
    expect(color(a), [1, 1, 1, 1]);
    expect(b.type, 'unlit');
    expect(color(b), [0, 1, 0, 1]);
    expect(b.properties.keys, ['baseColor']);
    expect(
      (a.properties['baseColorTexture'] as ResourceRefValue).id,
      u4SnapshotTexture(doc, U4SnapshotTexture.t1).id,
    );
    for (final name in U4SnapshotTexture.values) {
      final image = doc.payloads[u4SnapshotTexture(doc, name).payload]!;
      expect(image.encoding, PayloadEncoding.image);
      expect(image.format, 'rgba8');
      expect([image.width, image.height, image.length], [2, 2, 16]);
      expect(image.bytes, isNull);
    }
    final current = u4SnapshotNode(doc, 'current');
    final snapshot = u4SnapshotNode(doc, 'snapshot');
    expect(current.components.single.type, 'mesh');
    expect(snapshot.components.single.type, 'd3:instances');
    expect(ref(current.components.single, 'material'), a.id);
    expect(ref(snapshot.components.single, 'material'), a.id);
    expect(
      ref(current.components.single, 'geometry'),
      ref(snapshot.components.single, 'geometry'),
    );
    expect(
      (snapshot.components.single.properties['doubleSided'] as BoolValue).value,
      true,
    );
    final matrices =
        snapshot.components.single.properties['transforms'] as ListValue;
    expect(matrices.values, hasLength(1));
    expect((current.transform as TrsTransform).translation.storage, [
      closeTo(-0.7, 1e-6),
      1.5,
      0,
    ]);
    expect((snapshot.transform as TrsTransform).translation.storage, [
      closeTo(0.7, 1e-6),
      1.5,
      0,
    ]);
    final root = u4SnapshotNode(doc, 'variants');
    expect(doc.roots, contains(root.id));
    expect(root.id, isNot(snapshot.id));
    final variants = root.components.single;
    expect(variants.type, 'materialsVariants');
    expect(
      (variants.properties['variants'] as ListValue).values
          .cast<StringValue>()
          .map((v) => v.value),
      ['other'],
    );
    final binding =
        ((variants.properties['bindings'] as ListValue).values.single
                as MapValue)
            .values;
    expect((binding['node'] as ResourceRefValue).id, snapshot.id);
    expect((binding['primitive'] as IntValue).value, 0);
    expect((binding['default'] as ResourceRefValue).id, a.id);
    final materials = (binding['materials'] as MapValue).values;
    expect(materials.keys, ['0']);
    expect((materials['0'] as ResourceRefValue).id, b.id);
    final camera = u4SnapshotNode(doc, 'camera');
    expect((camera.transform as TrsTransform).translation.storage, [0, 0, -10]);
    expect(
      (camera.components.single.properties['fovRadiansY'] as DoubleValue).value,
      math.pi / 3,
    );
    final env = doc.resources[doc.stage.environmentRef] as EnvironmentResource;
    expect(env.environment, isA<EmptyEnvironment>());
    expect(env.environmentIntensity, 0);
    expect(env.exposure, 1);
    expect(env.toneMapping, 'linear');
    expect(env.effects.bloomEnabled, false);
    expect(
      doc.nodes.values
          .expand((n) => n.components)
          .where((c) => c.type.endsWith('Light')),
      isEmpty,
    );
  });

  test('public load sends one typed clip and only ready curve payloads', () {
    final doc = buildU4SnapshotDocument();
    final clip = doc.animations.values.single as Dart3dAnimationSpec;
    expect(clip.channels, isEmpty);
    expect(clip.name, 'u4.snapshots');
    final channel = clip.propertyChannels.single as D3MaterialBaseColorChannel;
    expect(channel.material, u4SnapshotMaterial(doc, 'A').id);
    for (final (id, values) in [
      (channel.timeline, [0.0, 2.0]),
      (channel.keyframes, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0]),
    ]) {
      final payload = doc.payloads[id]!;
      expect(payload.encoding, PayloadEncoding.floats);
      final bytes = ByteData.sublistView(payload.bytes!);
      expect([
        for (var i = 0; i < bytes.lengthInBytes; i += 4)
          bytes.getFloat32(i, Endian.little),
      ], values);
    }
    final controller = SceneController();
    final recording = RecordingElement(controller);
    controller.attachElement(recording);
    addTearDown(controller.dispose);
    controller.loadDocument(doc);
    expect(controller.animations[clip.id]!.duration, 2);
    final manifest =
        jsonDecode(
              utf8.decode(
                recording.sent
                    .singleWhere((m) => m.tag == D3Protocol.loadScene)
                    .data,
              ),
            )
            as Map;
    expect(manifest['featuresRequired'], contains('d3:propertyAnimation'));
    final animation = (manifest['animations'] as Map).values.single as Map;
    expect(animation['channels'], isEmpty);
    expect(animation['d3:properties'], [
      {
        'kind': 'materialBaseColor',
        'material': 'mat:${channel.material.toToken()}',
        'timeline': 'chunk:${channel.timeline.toToken()}',
        'keyframes': 'chunk:${channel.keyframes.toToken()}',
      },
    ]);
    final payloads = recording.sent
        .where((m) => m.tag == D3Protocol.payload)
        .toList();
    expect(payloads, hasLength(2));
    for (var i = 0; i < 2; i++) {
      expect(
        payloads[i].data.sublist(8),
        doc.payloads[[channel.timeline, channel.keyframes][i]]!.bytes,
      );
    }
    final reopened = readFsceneWithExtensions(
      writeFsceneWithExtensions(controller.serializeScene()!),
    );
    expect(reopened.animations[clip.id], isA<Dart3dAnimationSpec>());
    for (final name in U4SnapshotTexture.values) {
      expect(
        reopened.payloads[u4SnapshotTexture(reopened, name).payload]!.bytes,
        isNull,
      );
    }
  });

  test(
    'late image commands and repeated sprite refresh preserve clip and camera',
    () {
      final doc = buildU4SnapshotDocument();
      final controller = SceneController();
      final recording = RecordingElement(controller);
      controller.attachElement(recording);
      addTearDown(controller.dispose);
      controller.loadDocument(doc);
      final logs = <String>[];
      final playback = U4PropertyControls(controller, doc, log: logs.add);
      final controls = U4SnapshotControls(controller, log: logs.add);
      final before = controller.serializeScene()!;
      final detached = writeFsceneWithExtensions(before);
      final a = u4SnapshotMaterial(before, 'A');
      final t1 = u4SnapshotTexture(before, U4SnapshotTexture.t1);
      final t2 = u4SnapshotTexture(before, U4SnapshotTexture.t2);
      final root = u4SnapshotNode(before, 'variants');
      final clip = playback.clip;
      final token = clip.toToken();
      recording.sent.clear();
      playback.setWeight(0.25);
      playback.seek(1);
      final priorImage = writeFsceneWithExtensions(
        controller.serializeScene()!,
      );
      controls.texture1();
      final afterImage = controller.serializeScene()!;
      final expectedImage = readFsceneWithExtensions(priorImage);
      expectedImage.payloads[t1.payload!] = afterImage.payloads[t1.payload]!;
      expect(
        writeFsceneWithExtensions(afterImage),
        writeFsceneWithExtensions(expectedImage),
      );
      expect(afterImage.payloads[t2.payload]!.bytes, isNull);
      expect(color(u4SnapshotMaterial(afterImage, 'A')), [1, 1, 1, 1]);
      controls.spriteRefresh();
      final firstRefresh = controller.serializeScene()!;
      expect(firstRefresh.payloads[t2.payload]!.bytes, isNull);
      expect(u4SnapshotMaterial(firstRefresh, 'A').type, 'd3:sprite');
      expect(color(u4SnapshotMaterial(firstRefresh, 'A')), [
        closeTo(0.2, 1e-6),
        closeTo(0.4, 1e-6),
        closeTo(0.6, 1e-6),
        1,
      ]);
      playback.seek(2);
      controls.texture2();
      final priorRepeat = writeFsceneWithExtensions(
        controller.serializeScene()!,
      );
      controls.spriteRefresh();
      expect(
        writeFsceneWithExtensions(controller.serializeScene()!),
        priorRepeat,
      );
      playback.seek(1);
      controls.other();
      controls.defaults();
      final after = controller.serializeScene()!;
      final finalMaterial = u4SnapshotMaterial(after, 'A');
      expect(finalMaterial.id, a.id);
      expect(
        (finalMaterial.properties['baseColorTexture'] as ResourceRefValue).id,
        t2.id,
      );
      expect(
        (finalMaterial.properties['blendMode'] as StringValue).value,
        'alpha',
      );
      expect(writeFsceneWithExtensions(before), detached);
      final expected = readFsceneWithExtensions(detached);
      expected.resources[a.id] = finalMaterial;
      expected.payloads[t1.payload!] = after.payloads[t1.payload]!;
      expected.payloads[t2.payload!] = after.payloads[t2.payload]!;
      expect(
        jsonDecode(writeFsceneWithExtensions(after)),
        jsonDecode(writeFsceneWithExtensions(expected)),
      );
      expect(
        encodeAnimationSpec(after.animations[clip]!, after),
        encodeAnimationSpec(before.animations[clip]!, before),
      );
      expect(
        encodeNodeCommandSpec(u4SnapshotNode(after, 'camera'), after),
        encodeNodeCommandSpec(u4SnapshotNode(before, 'camera'), before),
      );
      expect(
        encodeNodeCommandSpec(u4SnapshotNode(after, 'variants'), after),
        encodeNodeCommandSpec(root, before),
      );
      final reopened = readFsceneWithExtensions(
        writeFsceneWithExtensions(after),
      );
      expect(reopened.animations[clip], isA<Dart3dAnimationSpec>());
      expect(
        writeFsceneWithExtensions(reopened),
        writeFsceneWithExtensions(after),
      );
      final refresh = {
        'op': 'upsertResource',
        'id': a.id.toToken(),
        'resource': {
          'kind': 'material',
          'name': 'u4.snapshots.A',
          'type': 'd3:sprite',
          'properties': {
            'baseColor': {
              'c': [
                closeTo(0.2, 1e-6),
                closeTo(0.4, 1e-6),
                closeTo(0.6, 1e-6),
                1.0,
              ],
            },
            'baseColorTexture': {'rref': t2.id.toToken()},
            'blendMode': {'s': 'alpha'},
          },
        },
      };
      Map<String, Object?> image(LocalId id, List<int> pixels) => {
        'op': 'upsertPayload',
        'id': id.toToken(),
        'encoding': 'image',
        'format': 'rgba8',
        'width': 2,
        'height': 2,
        'length': 16,
        'bytes': pixels,
      };
      List<Map<String, Object?>> seek(double time) => [
        {'op': 'anim', 'anim': token, 'pause': true},
        {'op': 'anim', 'anim': token, 'time': time},
      ];
      expect(recording.sent.every((m) => m.tag == D3Protocol.command), true);
      expect(recording.commands, [
        {'op': 'anim', 'anim': token, 'play': true, 'weight': 0.25},
        {'op': 'anim', 'anim': token, 'pause': true},
        ...seek(1),
        image(t1.payload!, [
          255,
          255,
          255,
          255,
          96,
          96,
          96,
          255,
          96,
          96,
          96,
          255,
          255,
          255,
          255,
          255,
        ]),
        refresh,
        ...seek(2),
        image(t2.payload!, [
          64,
          64,
          64,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          64,
          64,
          64,
          255,
        ]),
        refresh,
        ...seek(1),
        {'op': 'selectVariant', 'node': root.id.toToken(), 'selected': 'other'},
        {'op': 'selectVariant', 'node': root.id.toToken(), 'selected': null},
      ]);
      expect(after.payloads[t1.payload]!.bytes, [
        255,
        255,
        255,
        255,
        96,
        96,
        96,
        255,
        96,
        96,
        96,
        255,
        255,
        255,
        255,
        255,
      ]);
      expect(after.payloads[t2.payload]!.bytes, [
        64,
        64,
        64,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        64,
        64,
        64,
        255,
      ]);
      expect(
        logs.every(
          (line) => line.contains('requested') && !line.contains('PASS'),
        ),
        true,
      );
      playback.togglePlayback();
      playback.stop();
      expect(recording.commands.sublist(recording.commands.length - 2), [
        {'op': 'anim', 'anim': token, 'play': true},
        {'op': 'anim', 'anim': token, 'stop': true},
      ]);
    },
  );

  test('both cards project above the lower 320 points at 402x874', () {
    final doc = buildU4SnapshotDocument();
    final bounds = documentContentBounds(doc)!;
    final camera = SceneCamera.fromDocument(
      doc,
      cameraNode: u4SnapshotNode(doc, 'camera').id,
    )!;
    for (final x in [bounds.$1.x, bounds.$2.x]) {
      for (final y in [bounds.$1.y, bounds.$2.y]) {
        for (final z in [bounds.$1.z, bounds.$2.z]) {
          final point = camera.worldToScreen(Vector3(x, y, z), 402, 874)!;
          expect(point.$1, inInclusiveRange(16, 386));
          expect(point.$2, inInclusiveRange(80, 554));
        }
      }
    }
  });
}

class RecordingElement extends SceneViewElement {
  RecordingElement(SceneController controller)
    : super(SceneViewLeaf(controller: controller));
  final sent = <({int tag, Uint8List data})>[];
  List<Map> get commands =>
      sent.map((m) => jsonDecode(utf8.decode(m.data)) as Map).toList();
  @override
  void sendMutation(int tag, Uint8List data) =>
      sent.add((tag: tag, data: Uint8List.fromList(data)));
}
