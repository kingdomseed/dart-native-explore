// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u4_owner_scene.dart';
import 'package:dart3d_example/u4_property_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

List<double> color(MaterialResource material) {
  final value = material.properties['baseColor'] as ColorValue;
  return [value.r, value.g, value.b, value.a];
}

LocalId materialRef(NodeSpec node) =>
    (node.components.single.properties['material'] as ResourceRefValue).id;

void main() {
  test(
    'u4-owners is self-contained with three ordinary single-sided cards',
    () {
      expect(AppRoute.boot(model: 'u4-owners').screen, AppScreen.showcase);
      final item = showcaseItems.singleWhere((i) => i.label == 'u4-owners');
      expect(item.assetKey, kBuiltinU4OwnersKey);
      final scene = loadShowcaseScene(
        item,
        bytesFor: (_) => fail('owner fixture must not load assets'),
      )!;
      final doc = scene.document;
      expect(scene.frameRadius, 0);
      expect(scene.cameraNode, u4OwnerNode(doc, 'camera').id);
      expect(scene.summary, 'Left → right: canonical · default · rebind');
      expect(doc.nodes, hasLength(5));
      expect(doc.resources, hasLength(5));
      final a = u4OwnerMaterial(doc, 'A');
      expect(color(a), [1, 1, 1, 1]);
      expect(color(u4OwnerMaterial(doc, 'B')), [0, 1, 0, 1]);
      expect(color(u4OwnerMaterial(doc, 'F')), [1, 0.5, 0, 1]);
      for (final material
          in doc.resources.values.whereType<MaterialResource>()) {
        expect(material.type, 'unlit');
        expect(material.properties.keys, ['baseColor']);
      }
      final xs = <double>[];
      final geometries = <LocalId>{};
      for (final name in ['canonical', 'default', 'rebind']) {
        final node = u4OwnerNode(doc, name);
        expect(node.components.single.type, 'mesh');
        expect(node.components.single.properties.keys.toSet(), {
          'geometry',
          'material',
        });
        expect(materialRef(node), a.id);
        geometries.add(
          (node.components.single.properties['geometry'] as ResourceRefValue)
              .id,
        );
        xs.add((node.transform as TrsTransform).translation.x);
      }
      expect(xs, [closeTo(-1.2, 1e-6), 0, closeTo(1.2, 1e-6)]);
      expect(geometries, hasLength(1));
      final cameraNode = u4OwnerNode(doc, 'camera');
      expect((cameraNode.transform as TrsTransform).translation.storage, [
        0,
        0,
        -10,
      ]);
      final camera = cameraNode.components.single;
      expect(
        (camera.properties['projection'] as StringValue).value,
        'perspective',
      );
      expect(
        (camera.properties['fovRadiansY'] as DoubleValue).value,
        math.pi / 3,
      );
      final env =
          doc.resources[doc.stage.environmentRef] as EnvironmentResource;
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

      final root = u4OwnerNode(doc, 'variants');
      expect(doc.roots, contains(root.id));
      final variants = root.components.single;
      expect(variants.type, 'materialsVariants');
      expect(
        (variants.properties['variants'] as ListValue).values
            .cast<StringValue>()
            .map((v) => v.value),
        ['other'],
      );
      final bindings = (variants.properties['bindings'] as ListValue).values
          .cast<MapValue>()
          .toList();
      expect(bindings, hasLength(2));
      for (var i = 0; i < bindings.length; i++) {
        final binding = bindings[i].values;
        expect(binding.keys.toSet(), {
          'node',
          'primitive',
          'default',
          'materials',
        });
        expect(
          (binding['node'] as ResourceRefValue).id,
          u4OwnerNode(doc, ['default', 'rebind'][i]).id,
        );
        expect((binding['primitive'] as IntValue).value, 0);
        expect((binding['default'] as ResourceRefValue).id, a.id);
        final materials = (binding['materials'] as MapValue).values;
        expect(materials.keys, ['0']);
        expect(
          (materials['0'] as ResourceRefValue).id,
          u4OwnerMaterial(doc, 'B').id,
        );
      }
    },
  );

  test(
    'one typed property-only clip dispatches literal endpoints and payloads',
    () {
      final doc = buildU4OwnerDocument();
      final clip = doc.animations.values.single as Dart3dAnimationSpec;
      expect(clip.name, 'u4.owners');
      expect(clip.channels, isEmpty);
      final channel =
          clip.propertyChannels.single as D3MaterialBaseColorChannel;
      expect(channel.material, u4OwnerMaterial(doc, 'A').id);
      expect(doc.payloads, hasLength(2));
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
          doc.payloads.values.elementAt(i).bytes,
        );
      }
      controller.dispose();
    },
  );

  test(
    'public owner mutations preserve authored defaults and change only requested owners',
    () {
      final doc = buildU4OwnerDocument();
      final authored = writeFsceneWithExtensions(doc);
      final controller = SceneController();
      final recording = RecordingElement(controller);
      controller.attachElement(recording);
      controller.loadDocument(doc);
      final logs = <String>[];
      final playback = U4PropertyControls(controller, doc, log: logs.add);
      final owners = U4OwnerControls(controller, log: logs.add);
      final before = controller.serializeScene()!;
      final root = u4OwnerNode(before, 'variants');
      final rootBefore = encodeNodeCommandSpec(root, before);
      final a = u4OwnerMaterial(before, 'A');
      final rebind = u4OwnerNode(before, 'rebind');
      recording.sent.clear();
      playback.setWeight(0.25);
      playback.seek(1);
      owners.other();
      playback.seek(2);
      owners.defaults();
      playback.seek(1);
      owners.other();
      expect(writeFsceneWithExtensions(doc), authored);
      owners.replaceA();
      final replaced = controller.serializeScene()!;
      expect(color(u4OwnerMaterial(replaced, 'A')), [0.2, 0.4, 0.6, 1]);
      expect(u4OwnerMaterial(replaced, 'A').id, a.id);
      playback.seek(2);
      owners.defaults();
      final priorRebind = encodeNodeCommandSpec(
        u4OwnerNode(replaced, 'rebind'),
        replaced,
      );
      owners.rebindF();
      final rebound = controller.serializeScene()!;
      final newRebind = u4OwnerNode(rebound, 'rebind');
      expect(materialRef(newRebind), u4OwnerMaterial(rebound, 'F').id);
      expect(
        encodeNodeCommandSpec(u4OwnerNode(rebound, 'variants'), rebound),
        rootBefore,
      );
      for (final name in ['canonical', 'default']) {
        expect(materialRef(u4OwnerNode(rebound, name)), a.id);
      }
      final afterRebind = encodeNodeCommandSpec(newRebind, rebound);
      expect(afterRebind['components'], [
        {
          'type': 'mesh',
          'properties': {
            'geometry': {
              'rref':
                  'geo:${(rebind.components.single.properties['geometry'] as ResourceRefValue).id.toToken()}',
            },
            'material': {
              'rref': 'mat:${u4OwnerMaterial(rebound, 'F').id.toToken()}',
            },
          },
        },
      ]);
      expect(
        {...afterRebind}..remove('components'),
        {...priorRebind}..remove('components'),
      );
      playback.setWeight(1);
      playback.seek(1);
      owners.other();
      owners.defaults();

      final token = playback.clip.toToken();
      List<Map<String, Object?>> seek(double time) => [
        {'op': 'anim', 'anim': token, 'pause': true},
        {'op': 'anim', 'anim': token, 'time': time},
      ];
      Map<String, Object?> variant(String? selected) => {
        'op': 'selectVariant',
        'node': root.id.toToken(),
        'selected': selected,
      };
      expect(recording.commands, [
        {'op': 'anim', 'anim': token, 'play': true, 'weight': 0.25},
        {'op': 'anim', 'anim': token, 'pause': true},
        ...seek(1),
        variant('other'),
        ...seek(2),
        variant(null),
        ...seek(1),
        variant('other'),
        {
          'op': 'upsertResource',
          'id': a.id.toToken(),
          'resource': {
            'kind': 'material',
            'name': 'u4.owners.A',
            'type': 'unlit',
            'properties': {
              'baseColor': {
                'c': [0.2, 0.4, 0.6, 1.0],
              },
            },
          },
        },
        ...seek(2),
        variant(null),
        {
          'op': 'updateNode',
          'node': rebind.id.toToken(),
          'flags': ['components'],
          'spec': afterRebind,
        },
        {'op': 'anim', 'anim': token, 'play': true, 'weight': 1.0},
        {'op': 'anim', 'anim': token, 'pause': true},
        ...seek(1),
        variant('other'),
        variant(null),
      ]);
      expect(recording.sent.every((m) => m.tag == D3Protocol.command), true);
      final expected = readFsceneWithExtensions(
        writeFsceneWithExtensions(before),
      );
      expected.resources[a.id] = u4OwnerMaterial(rebound, 'A');
      expected.nodes[rebind.id]!.components.single.properties['material'] =
          ResourceRefValue(u4OwnerMaterial(expected, 'F').id);
      expect(
        jsonDecode(writeFsceneWithExtensions(controller.serializeScene()!)),
        jsonDecode(writeFsceneWithExtensions(expected)),
      );
      expect(
        jsonDecode(writeFsceneWithExtensions(doc)),
        jsonDecode(writeFsceneWithExtensions(expected)),
      );
      expect(
        logs.every(
          (line) => line.contains('requested') && !line.contains('PASS'),
        ),
        true,
      );
      playback.stop();
      expect(recording.commands.last, {
        'op': 'anim',
        'anim': token,
        'stop': true,
      });
      controller.dispose();
    },
  );

  test('all card bounds project above the lower 320 points at 402x874', () {
    final doc = buildU4OwnerDocument();
    final bounds = documentContentBounds(doc)!;
    final camera = SceneCamera.fromDocument(
      doc,
      cameraNode: u4OwnerNode(doc, 'camera').id,
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
