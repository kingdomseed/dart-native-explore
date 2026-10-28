// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u4_material_scene.dart';
import 'package:dart3d_example/u4_property_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

MaterialResource material(SceneDocument doc, String name) => doc
    .resources
    .values
    .whereType<MaterialResource>()
    .singleWhere((m) => m.name == 'u4.materials.$name');

LocalId ref(ComponentSpec component, String field) =>
    (component.properties[field] as ResourceRefValue).id;

void main() {
  test('sheen case sends zero-to-one PBR alpha on an angled backed card', () {
    final doc = buildU4MaterialDocument(sheen: true);
    final pbr = material(doc, 'pbr');
    expect((pbr.properties['alphaMode'] as StringValue).value, 'BLEND');
    final sheen = pbr.properties['sheenColor'] as ColorValue;
    expect([sheen.r, sheen.g, sheen.b, sheen.a], [1, 1, 1, 1]);
    expect((pbr.properties['sheenRoughness'] as DoubleValue).value, 1);
    final pose = u4MaterialNode(doc, 'pbr').transform as TrsTransform;
    final forward = Vector3(0, 0, 1)..applyQuaternion(pose.rotation);
    expect(forward.z, closeTo(0.5, 0.000001));
    final backing =
        u4MaterialNode(doc, 'pbr.backing').transform as TrsTransform;
    expect(backing.translation.z, greaterThan(0.6));
    final clip = doc.animations.values.single as Dart3dAnimationSpec;
    final channel = clip.propertyChannels
        .cast<D3MaterialBaseColorChannel>()
        .singleWhere((c) => c.material == pbr.id);
    final keys = ByteData.sublistView(doc.payloads[channel.keyframes]!.bytes!);
    expect(
      [for (var i = 0; i < 8; i++) keys.getFloat32(i * 4, Endian.little)],
      [0, 0, 0, 0, 0, 0, 0, 1],
    );
    final controller = SceneController();
    final recording = RecordingElement(controller);
    controller.attachElement(recording);
    controller.loadDocument(doc);
    expect(controller.animations[clip.id]!.duration, 2);
    final load = recording.sent.singleWhere(
      (m) => m.tag == D3Protocol.loadScene,
    );
    final wire = jsonDecode(utf8.decode(load.data)) as Map;
    final animation = (wire['animations'] as Map).values.single as Map;
    final pbrTrack = (animation['d3:properties'] as List)
        .cast<Map>()
        .singleWhere((track) => track['material'] == 'mat:${pbr.id.toToken()}');
    expect(pbrTrack, {
      'kind': 'materialBaseColor',
      'material': 'mat:${pbr.id.toToken()}',
      'timeline': 'chunk:${channel.timeline.toToken()}',
      'keyframes': 'chunk:${channel.keyframes.toToken()}',
    });
    controller.dispose();
    final ordinary = buildU4MaterialDocument(sheen: false);
    expect(
      material(ordinary, 'pbr').properties.containsKey('sheenColor'),
      false,
    );
    expect(
      material(ordinary, 'pbr').properties.containsKey('alphaMode'),
      false,
    );
  });

  test('u4-materials routes to a self-contained fixed showcase', () {
    expect(AppRoute.boot(model: 'u4-materials').screen, AppScreen.showcase);
    final item = showcaseItems.singleWhere((i) => i.label == 'u4-materials');
    expect(item.assetKey, kBuiltinU4MaterialsKey);
    final scene = loadShowcaseScene(
      item,
      bytesFor: (_) => fail('asset lookup'),
    )!;
    final doc = scene.document;
    expect(scene.frameRadius, 0);
    expect(scene.cameraNode, u4MaterialNode(doc, 'camera').id);
    expect(doc.nodes, hasLength(10));
    final env = doc.resources[doc.stage.environmentRef] as EnvironmentResource;
    expect(env.environment, isA<EmptyEnvironment>());
    expect(env.environmentIntensity, 0);
    expect(env.exposure, 1);
    expect(env.toneMapping, 'linear');
    expect(env.effects.bloomEnabled, isFalse);
    final lights = doc.nodes.values
        .expand((n) => n.components)
        .where((c) => c.type.endsWith('Light'))
        .toList();
    expect(lights.map((c) => c.type), ['directionalLight']);
    expect((lights.single.properties['intensity'] as DoubleValue).value, 1);
    expect((lights.single.properties['castsShadow'] as BoolValue).value, false);
  });

  test('one opaque literal checker is shared by four independent factors', () {
    final doc = buildU4MaterialDocument();
    final texture = doc.resources.values.whereType<TextureResource>().single;
    final image = doc.payloads[texture.payload]!;
    expect(image.encoding, PayloadEncoding.image);
    expect(image.format, 'rgba8');
    expect([image.width, image.height, image.length], [2, 2, 16]);
    expect(image.bytes, [
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
    final textured = [
      'shared',
      'pbr',
      'reference',
      'alpha',
    ].map((name) => material(doc, name)).toList();
    expect(textured.map((m) => m.id).toSet(), hasLength(4));
    for (final m in textured) {
      expect(
        (m.properties['baseColorTexture'] as ResourceRefValue).id,
        texture.id,
      );
      expect(m.properties.containsKey('doubleSided'), false);
    }
    for (final name in ['shared.canonical', 'shared.live']) {
      final mesh = u4MaterialNode(doc, name).components.single;
      expect(mesh.type, 'mesh');
      expect(ref(mesh, 'material'), material(doc, 'shared').id);
    }
    for (final name in ['shared', 'pbr']) {
      final m = material(doc, name);
      final rest = m.properties['baseColor'] as ColorValue;
      expect([rest.r, rest.g, rest.b, rest.a], [0, 0, 0, 1]);
      expect(m.type, name == 'pbr' ? 'physicallyBased' : 'unlit');
    }
    expect(
      (material(doc, 'pbr').properties['roughness'] as DoubleValue).value,
      1,
    );
    expect(
      (material(doc, 'pbr').properties['metallic'] as DoubleValue).value,
      0,
    );
    final white =
        material(doc, 'reference').properties['baseColor'] as ColorValue;
    expect([white.r, white.g, white.b, white.a], [1, 1, 1, 1]);
    expect(
      ref(u4MaterialNode(doc, 'reference').components.single, 'material'),
      material(doc, 'reference').id,
    );
    expect(
      (material(doc, 'alpha').properties['alphaMode'] as StringValue).value,
      'BLEND',
    );
    expect(material(doc, 'alpha').type, 'unlit');
    expect(material(doc, 'backing').type, 'unlit');
    expect(
      material(doc, 'backing').properties.containsKey('baseColorTexture'),
      false,
    );
  });

  test('ordinary double-sided instance references the animated resource', () {
    final doc = buildU4MaterialDocument();
    final instance = u4MaterialNode(doc, 'snapshot').components.single;
    final canonical = u4MaterialNode(doc, 'shared.canonical').components.single;
    expect(instance.type, 'd3:instances');
    expect(ref(instance, 'material'), ref(canonical, 'material'));
    expect(ref(instance, 'geometry'), ref(canonical, 'geometry'));
    expect((instance.properties['doubleSided'] as BoolValue).value, true);
    expect(instance.properties.containsKey('billboard'), false);
    expect(instance.properties.containsKey('attributes'), false);
    final transforms = instance.properties['transforms'] as ListValue;
    expect(transforms.values, hasLength(1));
    expect(
      (transforms.values.single as Matrix4Value).value.storage,
      Matrix4.identity().storage,
    );
    for (final name in ['alpha', 'snapshot']) {
      final face = u4MaterialNode(doc, name).transform as TrsTransform;
      final backing = u4MaterialNode(doc, '$name.backing');
      final pose = backing.transform as TrsTransform;
      expect(pose.translation.x, face.translation.x);
      expect(pose.translation.y, face.translation.y);
      expect(pose.translation.z, greaterThan(face.translation.z));
      expect(
        ref(backing.components.single, 'material'),
        material(doc, 'backing').id,
      );
    }
  });

  test('typed property-only clip dispatches exact little-endian curves', () {
    final doc = buildU4MaterialDocument();
    final clip = doc.animations.values.single as Dart3dAnimationSpec;
    expect(clip.name, 'u4.materials');
    expect(clip.channels, isEmpty);
    expect(clip.propertyChannels, hasLength(3));
    expect(
      clip.propertyChannels.every((c) => c is D3MaterialBaseColorChannel),
      true,
    );
    final channels = clip.propertyChannels.cast<D3MaterialBaseColorChannel>();
    expect(channels.map((c) => c.material), [
      material(doc, 'shared').id,
      material(doc, 'pbr').id,
      material(doc, 'alpha').id,
    ]);
    expect(channels.map((c) => c.timeline).toSet(), hasLength(1));
    expect(channels.take(2).map((c) => c.keyframes).toSet(), hasLength(1));
    for (final c in channels) {
      final times = doc.payloads[c.timeline]!;
      final keys = doc.payloads[c.keyframes]!;
      expect(times.encoding, PayloadEncoding.floats);
      expect(keys.encoding, PayloadEncoding.floats);
      expect(times.bytes, [0, 0, 0, 0, 0, 0, 0, 64]);
      expect(keys.bytes, [
        0,
        0,
        128,
        63,
        0,
        0,
        128,
        62,
        0,
        0,
        128,
        62,
        0,
        0,
        128,
        c.material == material(doc, 'alpha').id ? 62 : 63,
        0,
        0,
        128,
        62,
        0,
        0,
        128,
        62,
        0,
        0,
        128,
        63,
        if (c.material == material(doc, 'alpha').id) ...[
          0,
          0,
          64,
          63,
        ] else ...[
          0,
          0,
          128,
          63,
        ],
      ]);
    }
    final controller = SceneController();
    final recording = RecordingElement(controller);
    controller.attachElement(recording);
    controller.loadDocument(doc);
    expect(controller.animations.keys, [clip.id]);
    expect(controller.animations[clip.id]!.duration, 2);
    final load = recording.sent.singleWhere(
      (m) => m.tag == D3Protocol.loadScene,
    );
    final manifest = jsonDecode(utf8.decode(load.data)) as Map;
    final wire = encodeAnimationSpec(clip, doc);
    expect((manifest['animations'] as Map).values.single, wire);
    expect(wire['channels'], isEmpty);
    expect((wire['d3:properties'] as List).map((c) => (c as Map)['kind']), [
      'materialBaseColor',
      'materialBaseColor',
      'materialBaseColor',
    ]);
    final payloads = recording.sent
        .where((m) => m.tag == D3Protocol.payload)
        .toList();
    expect(payloads, hasLength(4));
    for (var i = 0; i < payloads.length; i++) {
      expect(
        payloads[i].data.sublist(8),
        doc.payloads.values.elementAt(i).bytes,
      );
    }
    controller.dispose();
  });

  test(
    'existing controls request only clock mutations and preserve authored scene',
    () {
      final doc = buildU4MaterialDocument();
      final before = writeFsceneWithExtensions(doc);
      final bytesBefore = doc.payloads.values
          .map((p) => p.bytes!.toList())
          .toList();
      final controller = SceneController();
      final recording = RecordingElement(controller);
      controller.attachElement(recording);
      controller.loadDocument(doc);
      final mirror = writeFsceneWithExtensions(controller.serializeScene()!);
      recording.sent.clear();
      final logs = <String>[];
      final controls = U4PropertyControls(controller, doc, log: logs.add);
      final token = controls.clip.toToken();
      for (final time in [0.0, 1.0, 2.0]) {
        controls.seek(time);
      }
      controls.togglePlayback();
      controls.togglePlayback();
      controls.stop();
      controls.setWeight(0.25);
      controls.setWeight(1);
      expect(recording.commands, [
        {
          'op': 'anim',
          'anim': token,
          'play': true,
          'time': 0.0,
          'weight': 1.0,
          'loop': true,
        },
        {'op': 'anim', 'anim': token, 'pause': true},
        for (final time in [0.0, 1.0, 2.0]) ...[
          {'op': 'anim', 'anim': token, 'pause': true},
          {'op': 'anim', 'anim': token, 'time': time},
        ],
        {'op': 'anim', 'anim': token, 'play': true},
        {'op': 'anim', 'anim': token, 'pause': true},
        {'op': 'anim', 'anim': token, 'stop': true},
        for (final weight in [0.25, 1.0]) ...[
          {'op': 'anim', 'anim': token, 'play': true, 'weight': weight},
          {'op': 'anim', 'anim': token, 'pause': true},
        ],
      ]);
      expect(recording.sent.every((m) => m.tag == D3Protocol.command), true);
      expect(writeFsceneWithExtensions(doc), before);
      expect(writeFsceneWithExtensions(controller.serializeScene()!), mirror);
      expect(
        doc.payloads.values.map((p) => p.bytes!.toList()).toList(),
        bytesBefore,
      );
      expect(
        logs.every(
          (line) => line.contains('requested') && !line.contains('PASS'),
        ),
        true,
      );
      controller.dispose();
    },
  );

  test('authored bounds project above the reserved footer at 402x874', () {
    final doc = buildU4MaterialDocument();
    final bounds = documentContentBounds(doc)!;
    final camera = SceneCamera.fromDocument(
      doc,
      cameraNode: u4MaterialNode(doc, 'camera').id,
    )!;
    for (final x in [bounds.$1.x, bounds.$2.x]) {
      for (final y in [bounds.$1.y, bounds.$2.y]) {
        for (final z in [bounds.$1.z, bounds.$2.z]) {
          final point = camera.worldToScreen(Vector3(x, y, z), 402, 874)!;
          expect(point.$1, inInclusiveRange(16, 386));
          expect(point.$2, inInclusiveRange(80, 614));
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
