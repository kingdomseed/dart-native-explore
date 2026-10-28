// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/u2_catcher_scene.dart';
import 'package:dart3d_example/w34_debug_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('live blend caster survives the public scene load serialization', () {
    final controller = SceneController()
      ..loadDocument(
        buildW34DebugDocument(liveCatcher: true, blendCaster: true),
      );
    addTearDown(controller.dispose);
    final restored = readFsceneWithExtensions(
      writeFsceneWithExtensions(controller.serializeScene()!),
    );
    final caster = restored.nodes.values.singleWhere(
      (node) => node.name == 'u2.catcher.caster',
    );
    final id =
        (caster.components.single.properties['material']! as ResourceRefValue)
            .id;
    final material = restored.resources[id]! as MaterialResource;
    expect((material.properties['alphaMode']! as StringValue).value, 'blend');
    final color = material.properties['baseColor']! as ColorValue;
    expect([color.r, color.g, color.b, color.a], [0.82, 0.34, 0.12, 0.55]);
    final opaque = buildW34DebugDocument(liveCatcher: true);
    final opaqueCaster = opaque.nodes.values.singleWhere(
      (node) => node.name == 'u2.catcher.caster',
    );
    final opaqueId =
        (opaqueCaster.components.single.properties['material']!
                as ResourceRefValue)
            .id;
    expect(
      (opaque.resources[opaqueId]! as MaterialResource).properties['alphaMode'],
      isNull,
    );
  });

  test('live fixture retains the real receiver and typed U4 float curves', () {
    final doc = buildW34DebugDocument(liveCatcher: true);
    final controller = SceneController()..loadDocument(doc);
    addTearDown(controller.dispose);
    final sink = _Sink(controller);
    controller.attachElement(sink);
    final restored = readFsceneWithExtensions(
      writeFsceneWithExtensions(controller.serializeScene()!),
    );
    expect(
      (u2CatcherMaterial(restored).properties['mode']! as StringValue).value,
      'live',
    );
    final baked = buildW34DebugDocument(bakedCatcher: true);
    expect(
      encodeNodeCommandSpec(
        restored.nodes[u2CatcherReceiverId(restored)]!,
        restored,
      ),
      encodeNodeCommandSpec(baked.nodes[u2CatcherReceiverId(baked)]!, baked),
    );
    expect(
      encodeResource(
        restored.resources[u2CatcherGeometryId(restored)]!,
        (id) => id.toToken(),
      ),
      encodeResource(
        baked.resources[u2CatcherGeometryId(baked)]!,
        (id) => id.toToken(),
      ),
    );
    expect(
      restored.nodes.values.where(
        (n) => n.name.startsWith('u2.catcher.caster'),
      ),
      hasLength(1),
    );
    final light = restored.nodes.values.singleWhere(
      (n) => n.name == 'u2.catcher.light',
    );
    expect(light.components.single.type, 'spotLight');
    expect(
      (light.components.single.properties['intensity']! as DoubleValue).value,
      100,
    );
    final clip = restored.animations.values.single as Dart3dAnimationSpec;
    final channel = clip.propertyChannels.single as D3LightIntensityChannel;
    expect(channel.node, light.id);
    for (final (id, values) in [
      (channel.timeline, [0.0, 2.0]),
      (channel.keyframes, [20.0, 160.0]),
    ]) {
      final payload = restored.payloads[id]!;
      expect(payload.encoding, PayloadEncoding.floats);
      final data = ByteData.sublistView(
        controller.serializeScene()!.payloads[id]!.bytes!,
      );
      expect([
        data.getFloat32(0, Endian.little),
        data.getFloat32(4, Endian.little),
      ], values);
    }
    final manifest = jsonDecode(
      utf8.decode(
        sink.mutations.firstWhere((m) => m.tag == D3Protocol.loadScene).data,
      ),
    );
    expect(
      (manifest['animations'] as Map).values.single,
      encodeAnimationSpec(doc.animations.values.single, doc),
    );
    expect(restored.views.single.target, isNull);
    expect(
      restored.nodes[restored.views.single.cameraNode]!.name,
      'w34.camera',
    );
    expect(
      restored.resources.values.whereType<RenderTextureResource>(),
      isEmpty,
    );
    expect(
      (restored.resources.values
                  .whereType<MaterialResource>()
                  .singleWhere((m) => m.name == 'w34.backdrop')
                  .properties['baseColor']!
              as ColorValue)
          .a,
      1,
    );
    expect(writeFsceneWithExtensions(restored), isNot(contains('debugView')));
    expect(buildW34DebugDocument().animations, isEmpty);
    expect(baked.animations, isEmpty);
    expect(buildW34DebugDocument(materials: true).animations, isEmpty);
    expect(buildW34DebugDocument(skinned: true).animations, isEmpty);
  });

  test(
    'live light controls emit public transforms, components and U4 commands',
    () {
      final doc = buildW34DebugDocument(liveCatcher: true);
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final controls = W34LiveLightControls(controller, doc);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      controls.togglePose();
      final transform = sink.mutations.removeAt(0);
      expect(transform.tag, D3Protocol.setTransforms);
      final data = ByteData.sublistView(transform.data);
      expect(data.getUint32(0, Endian.little), 1);
      expect(data.getUint8(12), 3);
      expect(
        [
          for (var i = 0; i < 3; i++)
            data.getFloat32(13 + i * 4, Endian.little),
        ],
        [2, 5, 1],
      );
      final rotation = (controls.light.transform as TrsTransform).rotation;
      for (var i = 0; i < 4; i++) {
        expect(
          data.getFloat32(25 + i * 4, Endian.little),
          closeTo(rotation.storage[i], 1e-6),
        );
      }
      expect((controls.light.transform as TrsTransform).translation.storage, [
        2,
        5,
        1,
      ]);
      final token = controls.clip.toToken();
      for (final time in [0.0, 2.0]) {
        controls.seek(time);
        final ops = sink.mutations
            .map((m) => jsonDecode(utf8.decode(m.data)))
            .toList();
        expect(ops, [
          {
            'op': 'anim',
            'anim': token,
            'play': true,
            'time': time,
            'weight': 1.0,
            'loop': true,
          },
          {'op': 'anim', 'anim': token, 'pause': true},
        ]);
        expect(controls.playing, isFalse);
        sink.mutations.clear();
      }
      controls.togglePlayback();
      controls.togglePlayback();
      controls.releaseIntensityOverride();
      expect(
        sink.mutations.map((m) => jsonDecode(utf8.decode(m.data))).toList(),
        [
          {
            'op': 'anim',
            'anim': token,
            'play': true,
            'weight': 1.0,
            'loop': true,
          },
          {'op': 'anim', 'anim': token, 'pause': true},
          {
            'op': 'anim',
            'anim': token,
            'play': true,
            'time': 0.0,
            'weight': 0.0,
          },
          {'op': 'anim', 'anim': token, 'pause': true},
        ],
      );
      expect(controls.cue, 'Rest');
      for (final present in [false, true]) {
        sink.mutations.clear();
        controls.togglePresence();
        expect(controls.present, present);
        final mutation = sink.mutations.last;
        expect(mutation.tag, D3Protocol.command);
        final op = jsonDecode(utf8.decode(mutation.data));
        expect(op['op'], 'updateNode');
        expect(op['node'], controls.light.id.toToken());
        expect(op['flags'], ['components']);
        expect(op['spec']['components'], present ? hasLength(1) : isNull);
        expect(
          controller.document!.nodes[controls.light.id]!.components,
          hasLength(present ? 1 : 0),
        );
      }
      for (final intensity in [80.0, 100.0]) {
        sink.mutations.clear();
        controls.replace();
        final op = jsonDecode(utf8.decode(sink.mutations.last.data));
        expect(op['op'], 'updateNode');
        expect(op['spec']['components'].single['type'], 'spotLight');
        expect(op['spec']['components'].single['properties']['intensity'], {
          'd': intensity,
        });
        expect(op['spec']['components'].single['properties']['range'], {
          'd': 12.0,
        });
      }
      sink.mutations.clear();
      moveW34CatcherCaster(controller, doc, moved: true);
      expect(sink.mutations.removeAt(0).tag, D3Protocol.setTransforms);
      upsertU2CatcherMaterial(controller, doc, u2CatcherMaterial(doc));
      final replace = jsonDecode(utf8.decode(sink.mutations.removeAt(0).data));
      expect(replace['op'], 'upsertResource');
      expect(replace['id'], u2CatcherMaterial(doc).id.toToken());
      expect(replace['resource']['properties']['mode'], {'s': 'live'});
      controls.seek(2);
      sink.mutations.clear();
      controls.reload();
      expect(controls.cue, 'Rest');
      expect(controls.playing, isFalse);
      expect(controls.moved, isTrue);
      expect(sink.mutations.first.tag, D3Protocol.loadScene);
      final restored = readFsceneWithExtensions(
        writeFsceneWithExtensions(controller.serializeScene()!),
      );
      expect(
        (restored.nodes[controls.light.id]!.transform as TrsTransform)
            .translation
            .storage,
        [2, 5, 1],
      );
      expect(
        (restored.nodes.values
                    .singleWhere((n) => n.name == 'u2.catcher.caster')
                    .transform
                as TrsTransform)
            .translation
            .x,
        closeTo(0.9, 1e-6),
      );
    },
  );

  test('live geometry fits above its two extra control rows', () {
    final doc = buildW34DebugDocument(liveCatcher: true);
    final controller = SceneController()..loadDocument(doc);
    addTearDown(controller.dispose);
    final camera = SceneCamera.fromDocument(
      doc,
      cameraNode: doc.views.single.cameraNode,
    )!;
    for (final moved in [false, true]) {
      moveW34CatcherCaster(controller, doc, moved: moved);
      final bounds = meshNodeWorldBounds(doc);
      for (final node in doc.nodes.values.where(
        (n) => n.name == 'u2.catcher.receiver' || n.name == 'u2.catcher.caster',
      )) {
        final (min, max) = bounds[node.id]!;
        for (final height in [440.0, 500.0, 600.0]) {
          for (final x in [min.x, max.x]) {
            for (final y in [min.y, max.y]) {
              for (final z in [min.z, max.z]) {
                final point = camera.worldToScreen(
                  Vector3(x, y, z),
                  402,
                  height,
                )!;
                expect(point.$1, inInclusiveRange(12, 390), reason: node.name);
                expect(
                  point.$2,
                  inInclusiveRange(32, height - 32),
                  reason: node.name,
                );
              }
            }
          }
        }
      }
    }
  });

  test(
    'baked receiver and both caster positions fit the portrait scene area',
    () {
      final doc = buildW34DebugDocument(bakedCatcher: true);
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final camera = SceneCamera.fromDocument(
        doc,
        cameraNode: doc.views.single.cameraNode,
      )!;
      for (final moved in [false, true]) {
        moveW34CatcherCaster(controller, doc, moved: moved);
        final bounds = meshNodeWorldBounds(doc);
        for (final node in doc.nodes.values.where(
          (node) =>
              node.name == 'u2.catcher.receiver' ||
              node.name == 'u2.catcher.caster',
        )) {
          final (min, max) = bounds[node.id]!;
          for (final height in [600.0, 700.0]) {
            for (final x in [min.x, max.x]) {
              for (final y in [min.y, max.y]) {
                for (final z in [min.z, max.z]) {
                  final point = camera.worldToScreen(
                    Vector3(x, y, z),
                    402,
                    height,
                  )!;
                  expect(
                    point.$1,
                    inInclusiveRange(12, 390),
                    reason: node.name,
                  );
                  expect(
                    point.$2,
                    inInclusiveRange(32, height - 32),
                    reason: node.name,
                  );
                }
              }
            }
          }
        }
      }
    },
  );

  test(
    'baked fixture loads the real transformed U2 receiver and one caster',
    () {
      final doc = buildW34DebugDocument(bakedCatcher: true);
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      expect(sink.mutations.any((m) => m.tag == D3Protocol.loadScene), isTrue);
      final restored = readFsceneWithExtensions(
        writeFsceneWithExtensions(controller.serializeScene()!),
      );
      final receiver = restored.nodes[u2CatcherReceiverId(restored)]!;
      expect(receiver.components.single.type, 'd3:instances');
      expect(
        (receiver.components.single.properties['doubleSided']! as BoolValue)
            .value,
        isTrue,
      );
      final transform = receiver.transform as TrsTransform;
      expect(transform.translation.x, closeTo(0.1, 1e-6));
      expect(transform.translation.y, closeTo(0.025, 1e-6));
      expect(transform.translation.z, closeTo(-0.08, 1e-6));
      expect(transform.scale.x, 1);
      expect(transform.scale.y, 1);
      expect(transform.scale.z, closeTo(0.86, 1e-6));
      expect(transform.rotation.x, 0);
      expect(transform.rotation.y, closeTo(0.059964, 1e-6));
      expect(transform.rotation.z, 0);
      expect(transform.rotation.w, closeTo(0.998201, 1e-6));
      final geometry =
          restored.resources[u2CatcherGeometryId(restored)]!
              as GeometryResource;
      final plane = geometry.procedural! as PlaneGeometrySpec;
      expect(
        [plane.width, plane.depth, plane.segmentsX, plane.segmentsZ],
        [4.2, 4.2, 2, 2],
      );
      final catcher = u2CatcherMaterial(restored);
      expect(catcher.type, 'shadowCatcher');
      expect((catcher.properties['mode']! as StringValue).value, 'baked');
      expect((catcher.properties['softness']! as DoubleValue).value, 0);
      expect(catcher.properties.containsKey('d3CatcherRegion'), isFalse);
      expect(
        restored.nodes.values.where(
          (n) => n.name.startsWith('u2.catcher.caster'),
        ),
        hasLength(1),
      );
      final light = restored.nodes.values.singleWhere(
        (n) => n.name == 'u2.catcher.light',
      );
      expect(light.components.single.type, 'spotLight');
      expect(
        (light.components.single.properties['castsShadow']! as BoolValue).value,
        isTrue,
      );
      final camera = restored.nodes[restored.views.single.cameraNode]!;
      expect(camera.name, 'w34.camera');
      expect((camera.transform as TrsTransform).translation.storage, [
        0,
        4.5,
        -6,
      ]);
      expect(camera.components.single.type, 'camera');
      expect(restored.views.single.target, isNull);
      expect(
        restored.resources.values.whereType<RenderTextureResource>(),
        isEmpty,
      );
      final backdrop = restored.resources.values
          .whereType<MaterialResource>()
          .singleWhere((m) => m.name == 'w34.backdrop');
      expect(backdrop.type, 'physicallyBased');
      expect((backdrop.properties['baseColor']! as ColorValue).a, 1);
    },
  );

  test(
    'caster motion emits transforms, explicit same-ID refresh survives reload',
    () {
      final doc = buildW34DebugDocument(bakedCatcher: true);
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      final caster = doc.nodes.values.singleWhere(
        (n) => n.name == 'u2.catcher.caster',
      );
      final material = u2CatcherMaterial(doc);
      final originalMaterial = encodeResource(material, (id) => id.toToken());
      moveW34CatcherCaster(controller, doc, moved: true);
      expect(sink.mutations.single.tag, D3Protocol.setTransforms);
      final bytes = ByteData.sublistView(sink.mutations.removeAt(0).data);
      expect(bytes.lengthInBytes, 25);
      expect(bytes.getUint32(0, Endian.little), 1);
      expect(bytes.getUint32(4, Endian.little), caster.id.session);
      expect(bytes.getUint32(8, Endian.little), caster.id.index);
      expect(bytes.getUint8(12), 1);
      expect(bytes.getFloat32(13, Endian.little), closeTo(0.9, 1e-6));
      expect(bytes.getFloat32(17, Endian.little), closeTo(0.7, 1e-6));
      expect(bytes.getFloat32(21, Endian.little), 0);
      expect(
        (caster.transform as TrsTransform).translation.x,
        closeTo(0.9, 1e-6),
      );
      expect(
        (controller.document!.nodes[caster.id]!.transform as TrsTransform)
            .translation
            .x,
        closeTo(0.9, 1e-6),
      );
      for (var refresh = 0; refresh < 2; refresh++) {
        upsertU2CatcherMaterial(controller, doc, u2CatcherMaterial(doc));
        final mutation = sink.mutations.removeAt(0);
        expect(mutation.tag, D3Protocol.command);
        expect(jsonDecode(utf8.decode(mutation.data)), {
          'op': 'upsertResource',
          'id': material.id.toToken(),
          'resource': originalMaterial,
        });
      }
      final current = readFsceneWithExtensions(
        writeFsceneWithExtensions(controller.serializeScene()!),
      );
      expect(
        (current.nodes[caster.id]!.transform as TrsTransform).translation.x,
        closeTo(0.9, 1e-6),
      );
      expect(
        encodeResource(u2CatcherMaterial(current), (id) => id.toToken()),
        originalMaterial,
      );
      controller.loadDocument(doc);
      expect(sink.mutations.removeAt(0).tag, D3Protocol.loadScene);
      expect(
        (controller.document!.nodes[caster.id]!.transform as TrsTransform)
            .translation
            .x,
        closeTo(0.9, 1e-6),
      );
      moveW34CatcherCaster(controller, doc, moved: false);
      expect(sink.mutations.single.tag, D3Protocol.setTransforms);
      expect((caster.transform as TrsTransform).translation.x, 0);
      expect(
        (caster.transform as TrsTransform).translation.y,
        closeTo(0.7, 1e-6),
      );
      expect((caster.transform as TrsTransform).translation.z, 0);
    },
  );

  test(
    'material fixture records unlit and both native-colored sprite draws',
    () {
      final doc = buildW34DebugDocument(materials: true);
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      expect(sink.mutations.any((m) => m.tag == D3Protocol.loadScene), isTrue);
      final restored = readFsceneWithExtensions(
        writeFsceneWithExtensions(controller.serializeScene()!),
      );
      final unlit = restored.resources.values
          .whereType<MaterialResource>()
          .singleWhere((m) => m.name == 'w34.mapped');
      expect(unlit.type, 'unlit');
      expect(
        (unlit.properties['baseColorTextureTransform']! as MapValue)
            .values
            .keys,
        containsAll(['offset', 'scale', 'rotation']),
      );
      for (final blend in ['alpha', 'additive']) {
        final sprite = restored.resources.values
            .whereType<MaterialResource>()
            .singleWhere((m) => m.name == 'w34.sprite.$blend');
        expect(sprite.type, 'd3:sprite');
        expect((sprite.properties['blendMode']! as StringValue).value, blend);
        expect(
          (sprite.properties['baseColor']! as ColorValue).a,
          closeTo(0.7, 1e-6),
        );
        final node = restored.nodes.values.singleWhere(
          (n) => n.name == sprite.name,
        );
        final color = node.components.single.properties['color']! as ColorValue;
        expect([color.r, color.g, color.b, color.a], [0.8, 0.6, 0.4, 0.5]);
      }
      final geometry = restored.resources.values
          .whereType<GeometryResource>()
          .single;
      final vertices = ByteData.sublistView(
        doc.payloads[geometry.vertices]!.bytes!,
      );
      expect(vertices.getFloat32(40, Endian.little), closeTo(0.8, 1e-6));
      final target = restored.views.singleWhere((v) => v.target != null);
      final monitor = restored.nodes.values.singleWhere(
        (n) => n.name == 'w34.authoredTarget',
      );
      expect(monitor.layers & target.layerMask, 0);
    },
  );

  test(
    'material controls emit current textures, tint, native color and coverage',
    () {
      final doc = buildW34DebugDocument(materials: true);
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      for (final coverage in ['opaque', 'mask', 'blend']) {
        editW34MaterialFamilies(
          controller,
          doc,
          edited: true,
          textured: false,
          colored: false,
          coverage: coverage,
        );
        final batch = jsonDecode(utf8.decode(sink.mutations.removeAt(0).data));
        expect(batch['op'], 'batch');
        final ops = batch['ops'] as List;
        final materials = ops
            .where((op) => op['op'] == 'upsertResource')
            .toList();
        expect(materials.length, 3);
        expect(materials[0]['resource']['type'], 'unlit');
        expect(materials[0]['resource']['properties']['alphaMode'], {
          's': coverage,
        });
        expect(materials[0]['resource']['properties']['baseColor'], {
          'c': [0.18, 0.7, 0.4, 0.65],
        });
        for (final op in materials) {
          expect(
            op['resource']['properties'].containsKey('baseColorTexture'),
            isFalse,
          );
        }
        for (final op in materials.skip(1)) {
          expect(op['resource']['properties']['baseColor'], {
            'c': [0.18, 0.7, 0.4, 0.4],
          });
        }
        final nodes = ops.where((op) => op['op'] == 'updateNode').toList();
        expect(nodes.length, 2);
        for (final op in nodes) {
          expect(op['flags'], ['components']);
          expect(op['spec']['components'][0]['properties']['color'], {
            'c': [0.35, 0.9, 0.7, 0.8],
          });
        }
      }
      editW34MaterialFamilies(
        controller,
        doc,
        edited: false,
        textured: true,
        colored: true,
        coverage: 'opaque',
      );
      final current = readFsceneWithExtensions(
        writeFsceneWithExtensions(controller.serializeScene()!),
      );
      final sprites = current.resources.values
          .whereType<MaterialResource>()
          .where((m) => m.type == 'd3:sprite')
          .toList();
      expect(sprites.length, 2);
      for (final sprite in sprites) {
        expect(sprite.properties['baseColorTexture'], isA<ResourceRefValue>());
        expect((sprite.properties['baseColor']! as ColorValue).a, 0.7);
      }
      expect(writeFsceneWithExtensions(current), isNot(contains('debugView')));
      controller.loadDocument(current);
      expect(sink.mutations.last.tag, D3Protocol.loadScene);
    },
  );

  test('consumer fixture retains bone slots across rig removal and re-add', () {
    final doc = buildW34DebugDocument(skinned: true);
    final rig = doc.nodes.values.singleWhere((n) => n.name == 'w34.rig');
    final joint = doc.nodes.values.singleWhere((n) => n.name == 'w34.joint');
    final mesh = doc.nodes.values.singleWhere((n) => n.name == 'w34.quad');
    final skin = doc.skins[mesh.skin]!;
    expect(skin.joints, [rig.id, joint.id]);
    expect(skin.skeleton, rig.id);
    expect(rig.children, [joint.id]);
    expect(mesh.children, isNot(contains(rig.id)));
    final geometryId =
        (mesh.components.single.properties['geometry']! as ResourceRefValue).id;
    final geometry = doc.resources[geometryId]! as GeometryResource;
    final vertices = ByteData.sublistView(
      doc.payloads[geometry.vertices]!.bytes!,
    );
    expect(vertices.lengthInBytes, 4 * VertexPack.skinnedUv1TangentStride);
    expect(vertices.getFloat32(72, Endian.little), 1);
    expect(vertices.getFloat32(88, Endian.little), 1);
    final controller = SceneController()..loadDocument(doc);
    addTearDown(controller.dispose);
    final sink = _Sink(controller);
    controller.attachElement(sink);
    sink.mutations.clear();
    poseW34Joint(controller, joint, posed: true);
    expect(sink.mutations.single.tag, D3Protocol.setTransforms);
    expect(
      (controller.document!.nodes[joint.id]!.transform as TrsTransform)
          .translation,
      Vector3(0, 0.35, 0),
    );
    sink.mutations.clear();
    setW34RigPresent(controller, doc, rig, joint, present: false);
    expect(controller.document!.nodes.containsKey(rig.id), isFalse);
    expect(controller.document!.nodes.containsKey(joint.id), isFalse);
    expect(controller.document!.nodes[mesh.id]!.skin, skin.id);
    expect(controller.document!.skins[skin.id]!.joints, [rig.id, joint.id]);
    expect(jsonDecode(utf8.decode(sink.mutations.single.data)), {
      'op': 'removeNode',
      'node': rig.id.toToken(),
    });
    sink.mutations.clear();
    setW34RigPresent(controller, doc, rig, joint, present: true);
    expect(controller.document!.nodes[rig.id]!.children, [joint.id]);
    expect(controller.document!.nodes.containsKey(joint.id), isTrue);
    final batch = jsonDecode(utf8.decode(sink.mutations.single.data));
    expect(batch['op'], 'batch');
    final adds = batch['ops'] as List;
    expect(adds.map((op) => op['op']), ['addNode', 'addNode']);
    expect(adds[0]['parent'], isNull);
    expect(adds[1]['parent'], rig.id.toToken());
    final translation = adds[1]['spec']['transform']['trs']['t'];
    expect(translation[0], 0);
    expect(translation[1], closeTo(0.35, 1e-6));
    expect(translation[2], 0);
  });

  test(
    'viewport control uses public view replacement and preserves authored target',
    () {
      final doc = buildW34DebugDocument();
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      final target = doc.views.singleWhere((v) => v.target != null);
      setW34Viewport(controller, doc, inset: true);
      final inset = jsonDecode(utf8.decode(sink.mutations.removeAt(0).data));
      expect(inset['op'], 'updateViews');
      expect(inset['views'][0]['target'], 'rt:${target.target!.toToken()}');
      expect(inset['views'][1]['viewport'], [60.0, 60.0, 1086.0, 900.0]);
      expect(inset['views'][1]['camera'], inset['views'][0]['camera']);
      setW34Viewport(controller, doc, inset: false);
      final full = jsonDecode(utf8.decode(sink.mutations.removeAt(0).data));
      expect(full['views'][1].containsKey('viewport'), isFalse);
      expect(full['views'][0], inset['views'][0]);
    },
  );

  test(
    'indexed mapped quad carries diagonal, tangent frame and nonwhite color',
    () {
      final doc = buildW34DebugDocument();
      final quad = doc.nodes.values.singleWhere(
        (node) => node.name == 'w34.quad',
      );
      final geometryId =
          (quad.components.single.properties['geometry']! as ResourceRefValue)
              .id;
      final geometry = doc.resources[geometryId]! as GeometryResource;
      final vertices = ByteData.sublistView(
        doc.payloads[geometry.vertices]!.bytes!,
      );
      final indices = ByteData.sublistView(
        doc.payloads[geometry.indices]!.bytes!,
      );
      expect(vertices.lengthInBytes, 4 * 72);
      final triangles = [
        for (var offset = 0; offset < indices.lengthInBytes; offset += 2)
          indices.getUint16(offset, Endian.little),
      ];
      expect(triangles, [0, 2, 1, 0, 3, 2]);
      for (var vertex = 0; vertex < 4; vertex++) {
        final base = vertex * 72;
        expect(vertices.getFloat32(base + 20, Endian.little), -1);
        expect(
          vertices.getFloat32(base + 40, Endian.little),
          closeTo(0.8, 1e-6),
        );
        expect(vertices.getFloat32(base + 56, Endian.little), 1);
        expect(vertices.getFloat32(base + 68, Endian.little), -1);
      }
      final material = doc.resources.values
          .whereType<MaterialResource>()
          .singleWhere((material) => material.name == 'w34.mapped');
      final normalId =
          (material.properties['normalTexture']! as ResourceRefValue).id;
      final normal = doc.resources[normalId]! as TextureResource;
      expect(normal.content, 'normal');
      final pixels = doc.payloads[normal.payload]!.bytes!;
      expect(pixels.length, 64 * 64 * 4);
      expect(pixels.sublist(0, 4), [128, 128, 255, 255]);
      expect(pixels.sublist(60 * 4, 61 * 4), [218, 128, 218, 255]);
      expect(pixels.sublist((60 * 64) * 4, (60 * 64 + 1) * 4), [
        128,
        37,
        218,
        255,
      ]);
      expect(pixels.sublist((60 * 64 + 60) * 4, (60 * 64 + 61) * 4), [
        54,
        201,
        201,
        255,
      ]);
      final mrId =
          (material.properties['metallicRoughnessTexture']! as ResourceRefValue)
              .id;
      final mr = doc.resources[mrId]! as TextureResource;
      expect(mr.content, 'data');
      expect(doc.payloads[mr.payload]!.bytes, [
        255,
        64,
        32,
        255,
        255,
        128,
        192,
        255,
        255,
        192,
        128,
        255,
        255,
        255,
        255,
        255,
      ]);
    },
  );

  test(
    'authored target shares screen camera but excludes its sampling monitor',
    () {
      final doc = buildW34DebugDocument();
      final targetView = doc.views.singleWhere((view) => view.target != null);
      final screenView = doc.views.singleWhere((view) => view.target == null);
      expect(targetView.cameraNode, screenView.cameraNode);
      final target = doc.resources[targetView.target]! as RenderTextureResource;
      expect(target.update, 'manual');
      final monitor = doc.nodes.values.singleWhere(
        (node) => node.name == 'w34.authoredTarget',
      );
      expect(monitor.layers & targetView.layerMask, 0);
      expect(monitor.layers & screenView.layerMask, isNonZero);
      final quad = doc.nodes.values.singleWhere(
        (node) => node.name == 'w34.quad',
      );
      expect(quad.layers & targetView.layerMask, isNonZero);
      final matId =
          (monitor.components.single.properties['material']!
                  as ResourceRefValue)
              .id;
      final material = doc.resources[matId]! as MaterialResource;
      expect(
        (material.properties['baseColorTexture']! as ResourceRefValue).id,
        target.id,
      );
    },
  );

  test(
    'factor and coverage controls emit current authored edits and survive reload',
    () {
      final doc = buildW34DebugDocument();
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      for (final coverage in ['opaque', 'mask', 'blend']) {
        editW34DebugMaterial(controller, doc, edited: true, coverage: coverage);
        final mutation = sink.mutations.removeAt(0);
        expect(mutation.tag, D3Protocol.command);
        final op =
            jsonDecode(utf8.decode(mutation.data)) as Map<String, dynamic>;
        expect(op['op'], 'upsertResource');
        expect(op['resource']['properties']['baseColor'], {
          'c': [0.18, 0.7, 0.4, 1.0],
        });
        expect(op['resource']['properties']['metallic'], {'d': 0.25});
        expect(op['resource']['properties']['roughness'], {'d': 0.9});
        expect(op['resource']['properties']['normalScale'], {'d': 0.35});
        expect(op['resource']['properties']['alphaMode'], {'s': coverage});
      }
      final target = doc.resources.values
          .whereType<RenderTextureResource>()
          .single;
      controller.renderTexture(target.id);
      expect(jsonDecode(utf8.decode(sink.mutations.removeAt(0).data)), {
        'op': 'render',
        'target': 'rt:${target.id.toToken()}',
      });
      final serialized = writeFsceneWithExtensions(
        controller.serializeScene()!,
      );
      expect(serialized, isNot(contains('debugView')));
      expect(serialized, isNot(contains('_w34Probe')));
      final restored = readFsceneWithExtensions(serialized);
      final current = restored.resources.values
          .whereType<MaterialResource>()
          .singleWhere((material) => material.name == 'w34.mapped');
      expect((current.properties['metallic']! as DoubleValue).value, 0.25);
      expect((current.properties['alphaMode']! as StringValue).value, 'blend');
      expect(
        restored.views.singleWhere((view) => view.target != null).cameraNode,
        restored.views.singleWhere((view) => view.target == null).cameraNode,
      );
      controller.loadDocument(restored);
      expect(sink.mutations.first.tag, D3Protocol.loadScene);
    },
  );
}

class _Sink extends SceneViewElement {
  _Sink(SceneController controller)
    : super(SceneViewLeaf(controller: controller));
  final mutations = <({int tag, Uint8List data})>[];

  @override
  void sendMutation(int tag, Uint8List data) =>
      mutations.add((tag: tag, data: data));
}
