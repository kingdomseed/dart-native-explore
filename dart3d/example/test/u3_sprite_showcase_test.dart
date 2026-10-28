// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u3_sprite_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

ShowcaseScene load() => loadShowcaseScene(
  showcaseItems.singleWhere((item) => item.label == 'u3-sprite'),
)!;

Map selectedWire(SceneDocument doc) =>
    encodeResource(u3SelectedSpriteMaterial(doc), (id) => id.toToken()) as Map;

Map stable(SceneDocument doc) {
  final wire = jsonDecode(writeFsceneWithExtensions(doc)) as Map;
  for (final resource in (wire['resources'] as Map).values.cast<Map>()) {
    if (resource['name'] == 'u3.sprite.selected') {
      (resource['properties'] as Map).remove('baseColorTextureTransform');
    }
  }
  return wire;
}

void main() {
  test(
    'public route keeps the ordinary probe separate and shares one image',
    () {
      expect(AppRoute.boot(model: 'u3-sprite').screen, AppScreen.showcase);
      final scene = load();
      final doc = scene.document;
      expect(scene.frameRadius, 0);
      expect(doc.payloads, hasLength(1));
      expect(doc.resources.values.whereType<TextureResource>(), hasLength(1));
      final texture = doc.resources.values.whereType<TextureResource>().single;
      final selected = u3SelectedSpriteMaterial(doc);
      expect(selected.type, 'd3:sprite');
      final refNode = u3SpriteNode(doc, 'reference');
      final refId =
          (refNode.components.single.properties['material'] as ResourceRefValue)
              .id;
      expect(refId, isNot(selected.id));
      final refMaterial = doc.resources[refId] as MaterialResource;
      for (final material in [selected, refMaterial]) {
        expect(
          (material.properties['baseColorTexture'] as ResourceRefValue).id,
          texture.id,
        );
      }
      final shadowMaterial =
          u3SpriteNode(
                doc,
                'shadowSprite',
              ).components.single.properties['material']
              as ResourceRefValue;
      expect(shadowMaterial.id, selected.id);
      final ordinary = loadShowcaseScene(
        showcaseItems.singleWhere((item) => item.label == 'u3-atlas-probe'),
      )!;
      expect(
        ordinary.document.resources.values.whereType<MaterialResource>().map(
          (m) => m.type,
        ),
        ['unlit', 'unlit'],
      );
      expect(
        doc.nodes.values.where(
          (n) => n.components.any((c) => c.type == 'spotLight'),
        ),
        hasLength(1),
      );
      expect(
        (u3SpriteNode(doc, 'spot').components.single.properties['castsShadow']
                as BoolValue)
            .value,
        isTrue,
      );
      expect(
        u3SpriteNode(doc, 'receiver').components.single.type,
        'd3:procMesh',
      );
      expect(
        u3SpriteNode(doc, 'caster').components.single.properties['shape'],
        isA<StringValue>(),
      );
      expect(
        (doc.resources[doc.stage.environmentRef] as EnvironmentResource)
            .toneMapping,
        'linear',
      );
      expect(
        writeFsceneWithExtensions(load().document),
        writeFsceneWithExtensions(doc),
      );
    },
  );

  test(
    'marked alpha texels include colored zero coverage and half coverage with padded edges',
    () {
      final bytes = load().document.payloads.values.single.bytes!;
      List<int> pixel(int x, int y) =>
          bytes.sublist((y * 40 + x) * 4, (y * 40 + x) * 4 + 4);
      expect(pixel(10, 2), [255, 0, 0, 0]);
      expect(pixel(10, 9), [255, 0, 0, 128]);
      expect(pixel(10, 15), [255, 0, 0, 255]);
      expect(pixel(3, 3), [255, 255, 255, 255]);
      expect(pixel(14, 14), [0, 0, 0, 255]);
      expect(pixel(0, 0), [255, 0, 0, 0]);
      expect(pixel(19, 19), [255, 0, 0, 255]);
      expect(pixel(30, 29), [255, 255, 0, 128]);
    },
  );

  test(
    'NextFrame emits real upserts, wraps, preserves the fixed reference and reloads',
    () {
      final doc = load().document;
      final controller = SceneController()..loadDocument(doc);
      final element = RecordingElement(controller);
      controller.attachElement(element);
      addTearDown(controller.dispose);
      final controls = U3SpriteControls(controller, doc);
      addTearDown(controls.dispose);
      final before = stable(doc);
      final pixels = Uint8List.fromList(doc.payloads.values.single.bytes!);
      element.mutations.clear();
      for (final (frame, u, v) in [
        (1, 0.550000011920929, 0.05000000074505806),
        (2, 0.05000000074505806, 0.550000011920929),
        (3, 0.550000011920929, 0.550000011920929),
        (0, 0.05000000074505806, 0.05000000074505806),
      ]) {
        controls.nextFrame();
        expect(controls.frame, frame);
        expect(element.mutations, hasLength(1));
        final mutation = element.mutations.removeAt(0);
        expect(mutation.tag, D3Protocol.command);
        final op = jsonDecode(utf8.decode(mutation.data)) as Map;
        expect(op.keys, unorderedEquals(['op', 'id', 'resource']));
        expect(op['op'], 'upsertResource');
        expect(op['id'], u3SelectedSpriteMaterial(doc).id.toToken());
        expect(op['resource'], selectedWire(doc));
        expect(op['resource']['type'], 'd3:sprite');
        expect(op['resource']['properties']['baseColorTextureTransform'], {
          'map': {
            'offset': {
              'v2': [u, v],
            },
            'scale': {
              'v2': [0.3999999761581421, 0.3999999761581421],
            },
          },
        });
        expect(selectedWire(controller.document!), op['resource']);
        expect(stable(controller.document!), before);
        expect(doc.payloads.values.single.bytes, pixels);
      }
      controls.nextFrame();
      final saved = writeFsceneWithExtensions(controller.document!);
      controller.loadFscene(saved);
      expect(writeFsceneWithExtensions(controller.document!), saved);
      expect(
        selectedWire(
          controller.document!,
        )['properties']['baseColorTextureTransform']['map']['offset']['v2'],
        [0.550000011920929, 0.05000000074505806],
      );
    },
  );

  test(
    'actual tint component, source removal, blend and same-ID type replacements survive transport',
    () {
      final doc = load().document;
      final controller = SceneController()..loadDocument(doc);
      final element = RecordingElement(controller);
      controller.attachElement(element);
      addTearDown(controller.dispose);
      final controls = U3SpriteControls(controller, doc);
      addTearDown(controls.dispose);
      final id = u3SelectedSpriteMaterial(doc).id;
      final cameraBefore = encodeNodeCommandSpec(
        u3SpriteNode(doc, 'camera'),
        doc,
      );
      element.mutations.clear();
      controls.toggleTint();
      expect(element.mutations.map((m) => m.tag), [
        D3Protocol.command,
        D3Protocol.command,
      ]);
      final update = jsonDecode(utf8.decode(element.mutations[0].data)) as Map;
      expect(update['op'], 'updateNode');
      expect(update['flags'], ['components']);
      expect(update['spec']['components'][0]['properties']['color'], {
        'c': [0.8, 0.6, 0.4, 0.5],
      });
      expect(selectedWire(doc)['properties']['baseColor'], {
        'c': [closeTo(0.4, 1e-6), closeTo(0.7, 1e-6), closeTo(0.9, 1e-6), 0.5],
      });
      controls.blend = D3SpriteBlendMode.additive;
      controls.upsert();
      expect(selectedWire(doc)['properties']['blendMode'], {'s': 'additive'});
      controls.textured = false;
      controls.upsert();
      expect(
        selectedWire(doc)['properties'],
        isNot(contains('baseColorTexture')),
      );
      controls.textured = true;
      controls.upsert();
      expect(selectedWire(doc)['properties']['baseColorTexture'], isNotNull);
      controls.ordinary = true;
      controls.upsert();
      expect(u3SelectedSpriteMaterial(doc).type, 'physicallyBased');
      expect(selectedWire(doc)['properties'], isNot(contains('blendMode')));
      controls.ordinary = false;
      controls.upsert();
      expect(u3SelectedSpriteMaterial(doc).type, 'd3:sprite');
      expect(u3SelectedSpriteMaterial(doc).id, id);
      expect(
        encodeNodeCommandSpec(u3SpriteNode(doc, 'camera'), doc),
        cameraBefore,
      );
      final saved = writeFsceneWithExtensions(controller.document!);
      controller.loadFscene(saved);
      expect(writeFsceneWithExtensions(controller.document!), saved);
      expect(
        (u3SpriteNode(
                  controller.document!,
                  'selected',
                ).components.single.properties['color']
                as ColorValue)
            .a,
        0.5,
      );
      expect(selectedWire(controller.document!)['properties']['blendMode'], {
        's': 'additive',
      });
    },
  );

  test(
    'explicit depth control crosses the translucent pair without changing frames or camera',
    () {
      final doc = load().document;
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final controls = U3SpriteControls(controller, doc);
      final selected = selectedWire(doc);
      controls.crossDepths();
      expect(
        (u3SpriteNode(doc, 'overlapBack').transform as TrsTransform)
            .translation
            .z,
        closeTo(-0.3, 1e-6),
      );
      expect(selectedWire(doc), selected);
      controls.crossDepths();
      expect(
        (u3SpriteNode(doc, 'overlapBack').transform as TrsTransform)
            .translation
            .z,
        closeTo(0.3, 1e-6),
      );
    },
  );

  test(
    'one-second caller timer uses the same upsert and stops on pause and disposal',
    () async {
      final doc = load().document;
      final controller = SceneController()..loadDocument(doc);
      final element = RecordingElement(controller);
      controller.attachElement(element);
      addTearDown(controller.dispose);
      final controls = U3SpriteControls(controller, doc);
      addTearDown(controls.dispose);
      element.mutations.clear();
      controls.togglePlayback();
      expect(controls.playing, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      controls.togglePlayback();
      expect(controls.frame, 1);
      expect(element.mutations, hasLength(1));
      final timedOp =
          jsonDecode(utf8.decode(element.mutations.single.data)) as Map;
      expect(timedOp['op'], 'upsertResource');
      expect(timedOp['resource'], selectedWire(doc));
      controls.nextFrame();
      expect(controls.frame, 2);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(controls.frame, 2);
      controls.togglePlayback();
      controls.dispose();
      controller.loadDocument(buildU3SpriteDocument());
      element.mutations.clear();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(controls.playing, isFalse);
      expect(element.mutations, isEmpty);
    },
  );

  test(
    'render-texture variant uses an isolated ordinary source and existing view codecs',
    () {
      final doc = buildU3SpriteDocument(
        renderTexture: true,
        tinted: true,
        blend: D3SpriteBlendMode.additive,
      );
      final rt = doc.resources.values.whereType<RenderTextureResource>().single;
      final source = u3SpriteNode(doc, 'rtSheet');
      expect(
        (source.components.single.properties['shape'] as StringValue).value,
        'plane',
      );
      expect(source.layers, 2);
      expect(doc.views.map((v) => v.layerMask), [2, 1]);
      expect(doc.views.first.target, rt.id);
      expect(doc.views.last.target, isNull);
      final referenceId =
          (u3SpriteNode(
                    doc,
                    'reference',
                  ).components.single.properties['material']
                  as ResourceRefValue)
              .id;
      final reference = doc.resources[referenceId] as MaterialResource;
      expect(
        reference.properties,
        isNot(contains('baseColorTextureTransform')),
      );
      expect(
        (u3SelectedSpriteMaterial(doc).properties['baseColorTexture']
                as ResourceRefValue)
            .id,
        rt.id,
      );
      final wire = writeFsceneWithExtensions(doc);
      expect(wire, contains('rt:${rt.id.toToken()}'));
      final decoded = readFsceneWithExtensions(wire);
      expect(writeFsceneWithExtensions(decoded), wire);
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final controls = U3SpriteControls(controller, doc);
      controls.nextFrame();
      expect(controls.texture, rt.id);
      final untextured = buildU3SpriteDocument(
        renderTexture: true,
        untextured: true,
      );
      final otherController = SceneController()..loadDocument(untextured);
      addTearDown(otherController.dispose);
      final other = U3SpriteControls(otherController, untextured);
      other.textured = true;
      other.upsert();
      expect(
        (u3SelectedSpriteMaterial(untextured).properties['baseColorTexture']
                as ResourceRefValue)
            .id,
        untextured.resources.values
            .whereType<RenderTextureResource>()
            .single
            .id,
      );
    },
  );

  test('visible fixture geometry fits above controls at 402 by 874', () {
    final scene = load();
    final doc = scene.document;
    final camera = SceneCamera.fromDocument(doc, cameraNode: scene.cameraNode)!;
    for (final node in doc.nodes.values.where(
      (n) => n.components.any((c) => c.type == 'd3:procMesh'),
    )) {
      final bounds = meshNodeWorldBounds(doc)[node.id]!;
      for (final x in [bounds.$1.x, bounds.$2.x]) {
        for (final y in [bounds.$1.y, bounds.$2.y]) {
          for (final z in [bounds.$1.z, bounds.$2.z]) {
            final point = camera.worldToScreen(Vector3(x, y, z), 402, 874)!;
            expect(point.$1, inInclusiveRange(16, 386), reason: node.name);
            expect(point.$2, inInclusiveRange(100, 560), reason: node.name);
          }
        }
      }
    }
  });
}

class RecordingElement extends SceneViewElement {
  RecordingElement(SceneController controller)
    : super(SceneViewLeaf(controller: controller));
  final mutations = <({int tag, Uint8List data})>[];
  @override
  void sendMutation(int tag, Uint8List data) =>
      mutations.add((tag: tag, data: data));
}
