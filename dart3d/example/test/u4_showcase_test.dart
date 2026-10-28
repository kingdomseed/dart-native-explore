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
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('u4 uses the existing route and a self-contained fixed camera', () {
    final item = showcaseItems.singleWhere((item) => item.label == 'u4');
    expect(AppRoute.boot(model: 'u4').screen, AppScreen.showcase);
    expect(item.assetKey, kBuiltinU4Key);
    final scene = loadShowcaseScene(item)!;
    final doc = scene.document;
    expect(scene.frameRadius, 0);
    expect(
      scene.summary,
      kBootU4Camera
          ? 'Camera FOV · fixed pose'
          : kBootU4Light == U4LightKind.directional
          ? 'Shared color pair · neutral lit face'
          : 'Shared color pair · ${kBootU4Light.name} light',
    );
    expect(scene.cameraNode, u4Node(doc, 'camera').id);
    expect(doc.nodes, hasLength(5));
    expect(doc.resources, hasLength(4));
    expect(
      doc.animations.values.single.name,
      kBootU4Camera ? 'u4.camera' : 'u4.color-light',
    );
    final environment =
        doc.resources[doc.stage.environmentRef]! as EnvironmentResource;
    expect(environment.environment, isA<EmptyEnvironment>());
    expect(environment.environmentIntensity, 0);
    expect(environment.exposure, 1);
    expect(environment.toneMapping, 'linear');
    expect(environment.effects.bloomEnabled, isFalse);
    expect(
      doc.nodes.values
          .expand((n) => n.components)
          .where((c) => c.type.endsWith('Light'))
          .map((c) => c.type),
      [kBootU4Light.componentType],
    );
    final light = u4Node(doc, 'light').components.single;
    expect((light.properties['intensity'] as DoubleValue).value, 1);
    final materials = doc.resources.values
        .whereType<MaterialResource>()
        .toList();
    expect(materials, hasLength(2));
    final shared = materials.singleWhere((m) => m.name == 'u4.shared');
    expect(shared.type, 'unlit');
    final color = shared.properties['baseColor'] as ColorValue;
    expect([color.r, color.g, color.b, color.a], [1, 1, 1, 1]);
    for (final name in ['shared.left', 'shared.right']) {
      expect(
        (u4Node(doc, name).components.single.properties['material']
                as ResourceRefValue)
            .id,
        shared.id,
      );
    }
    expect(
      (u4Node(doc, 'lit').components.single.properties['material']
              as ResourceRefValue)
          .id,
      isNot(shared.id),
    );
    expect(
      materials.singleWhere((m) => m.name == 'u4.neutral').type,
      'physicallyBased',
    );
    final camera = u4Node(doc, 'camera').components.single;
    expect(
      (camera.properties['fovRadiansY'] as DoubleValue).value,
      math.pi / 3,
    );
    expect(
      (camera.properties['projection'] as StringValue).value,
      'perspective',
    );
  });

  for (final kind in U4LightKind.values) {
    test(
      '${kind.name} keeps the original IDs, clip, payloads and fixed scene',
      () {
        final normal = buildU4PropertyDocument();
        final selected = buildU4PropertyDocument(lightKind: kind);
        final light = u4Node(selected, 'light');
        expect(light.components.single.type, kind.componentType);
        final props = light.components.single.properties;
        expect((props['intensity'] as DoubleValue).value, 1);
        expect((props['castsShadow'] as BoolValue).value, false);
        final white = props['color'] as ColorValue;
        expect([white.r, white.g, white.b, white.a], [1, 1, 1, 1]);
        if (kind != U4LightKind.directional) {
          expect((props['range'] as DoubleValue).value, 12);
          final pose = light.transform as TrsTransform;
          expect(pose.translation.storage, [
            closeTo(0.95, 1e-6),
            kind == U4LightKind.area ? 3.5 : 1.25,
            -3,
          ]);
          final forward = pose.rotation.asRotationMatrix().transform(
            Vector3(0, 0, 1),
          );
          final towardReceiver = Vector3(0.95, 1.25, 0) - pose.translation;
          expect(
            forward.normalized().dot(towardReceiver.normalized()),
            closeTo(1, 1e-6),
          );
        }
        if (kind == U4LightKind.spot) {
          expect((props['innerConeAngle'] as DoubleValue).value, 0.25);
          expect((props['outerConeAngle'] as DoubleValue).value, math.pi / 4);
        }
        if (kind == U4LightKind.area) {
          expect((props['width'] as DoubleValue).value, 2);
          expect((props['height'] as DoubleValue).value, 1);
        }
        Map comparable(SceneDocument doc) {
          final wire = jsonDecode(writeFsceneWithExtensions(doc)) as Map;
          wire.remove('documentId');
          (wire['nodes'] as Map).remove(
            'n:${u4Node(doc, 'light').id.toToken()}',
          );
          return wire;
        }

        expect(comparable(selected), comparable(normal));
        expect(selected.nodes.keys, normal.nodes.keys);
        expect(
          selected.payloads.values.map((p) => p.bytes),
          normal.payloads.values.map((p) => p.bytes),
        );
        final camera = buildU4PropertyDocument(camera: true, lightKind: kind);
        final defaultCamera = buildU4PropertyDocument(camera: true);
        final cameraWire = jsonDecode(writeFsceneWithExtensions(camera)) as Map
          ..remove('documentId');
        final defaultCameraWire =
            jsonDecode(writeFsceneWithExtensions(defaultCamera)) as Map
              ..remove('documentId');
        expect(cameraWire, defaultCameraWire);
        expect(
          camera.payloads.values.map((p) => p.bytes),
          defaultCamera.payloads.values.map((p) => p.bytes),
        );
      },
    );
  }

  for (final (kind, type) in [
    (U4LightKind.point, 'pointLight'),
    (U4LightKind.spot, 'spotLight'),
    (U4LightKind.area, 'rectAreaLight'),
  ]) {
    test(
      '${kind.name} owner updates use public transport and persist only components',
      () {
        final doc = buildU4PropertyDocument(lightKind: kind);
        final controller = SceneController();
        final recording = _RecordingElement(controller);
        controller.attachElement(recording);
        controller.loadDocument(doc);
        final logs = <String>[];
        final playback = U4PropertyControls(controller, doc);
        final owners = U4LightControls(controller, kind, log: logs.add);
        final before = controller.serializeScene()!;
        final beforeText = writeFsceneWithExtensions(before);
        final node = u4Node(before, 'light');
        final nodeSpec = encodeNodeCommandSpec(node, before);
        final token = playback.clip.toToken();
        final snapshots = <SceneDocument>[];
        final expectedCommands = <Map>[];
        recording.sent.clear();

        void seek(double time) {
          playback.seek(time);
          expectedCommands.addAll([
            {'op': 'anim', 'anim': token, 'pause': true},
            {'op': 'anim', 'anim': token, 'time': time},
          ]);
        }

        void update(void Function() action, double? rest) {
          final prior = controller.serializeScene()!;
          final priorText = writeFsceneWithExtensions(prior);
          action();
          expect(writeFsceneWithExtensions(prior), priorText);
          final snapshot = controller.serializeScene()!;
          snapshots.add(snapshot);
          final properties = {
            'color': {
              'c': [1.0, 1.0, 1.0, 1.0],
            },
            'intensity': {'d': rest},
            'castsShadow': {'b': false},
            'range': {'d': 12.0},
            if (kind == U4LightKind.spot) ...{
              'innerConeAngle': {'d': 0.25},
              'outerConeAngle': {'d': math.pi / 4},
            },
            if (kind == U4LightKind.area) ...{
              'width': {'d': rest == 3 ? 3.0 : 2.0},
              'height': {'d': rest == 3 ? 2.0 : 1.0},
            },
          };
          final components = [
            if (rest != null) {'type': type, 'properties': properties},
          ];
          final expectedSpec = {...nodeSpec, 'components': components};
          if (rest == null) expectedSpec.remove('components');
          expectedCommands.add({
            'op': 'updateNode',
            'node': node.id.toToken(),
            'flags': ['components'],
            'spec': expectedSpec,
          });
          expect(
            encodeNodeCommandSpec(u4Node(snapshot, 'light'), snapshot),
            expectedSpec,
          );
          final persisted = readFsceneWithExtensions(
            writeFsceneWithExtensions(snapshot),
          );
          expect(
            encodeNodeCommandSpec(u4Node(persisted, 'light'), persisted),
            expectedSpec,
          );
          final expected = jsonDecode(beforeText) as Map;
          ((expected['nodes'] as Map)['n:${node.id.toToken()}']
                  as Map)['components'] =
              components;
          // An empty component list is omitted by the manifest codec.
          if (rest == null) {
            ((expected['nodes'] as Map)['n:${node.id.toToken()}'] as Map)
                .remove('components');
          }
          expect(jsonDecode(writeFsceneWithExtensions(snapshot)), expected);
          expect(controller.animations.keys, [playback.clip]);
          expect(controller.animations[playback.clip]!.duration, 2);
          expect(snapshot.animations.values.single, isA<Dart3dAnimationSpec>());
          expect(
            snapshot.payloads.values.map((p) => p.bytes),
            before.payloads.values.map((p) => p.bytes),
          );
        }

        seek(1);
        seek(2);
        playback.setWeight(0.25);
        expectedCommands.addAll([
          {'op': 'anim', 'anim': token, 'play': true, 'weight': 0.25},
          {'op': 'anim', 'anim': token, 'pause': true},
        ]);
        seek(1);
        update(owners.replace, 3);
        seek(2);
        update(owners.remove, null);
        update(owners.reAdd, 1);
        seek(1);
        expect(recording.commands, expectedCommands);
        expect(recording.sent.every((m) => m.tag == D3Protocol.command), true);
        expect(playback.playing, false);
        expect(playback.weight, 0.25);
        expect(writeFsceneWithExtensions(before), beforeText);
        expect(u4Node(snapshots[0], 'light').components.single.type, type);
        expect(u4Node(snapshots[1], 'light').components, isEmpty);
        expect(u4Node(snapshots[2], 'light').components.single.type, type);
        expect(logs, [
          'dart3d: u4 requested light=${kind.name} Replace light rest=3',
          'dart3d: u4 requested light=${kind.name} Remove light',
          'dart3d: u4 requested light=${kind.name} Re-add light rest=1',
        ]);
        controller.dispose();
      },
    );
  }

  test(
    'selected property-only clip carries literal f32 curves and exact kinds',
    () {
      for (final camera in [false, true]) {
        final doc = buildU4PropertyDocument(camera: camera);
        final clip = doc.animations.values.single as Dart3dAnimationSpec;
        expect(clip.channels, isEmpty);
        final encoded = encodeAnimationSpec(clip, doc);
        expect(encoded['channels'], isEmpty);
        final channels = (encoded['d3:properties'] as List).cast<Map>();
        expect(
          channels.map((c) => c['kind']),
          camera
              ? ['cameraFovRadiansY']
              : ['materialBaseColor', 'lightIntensity'],
        );
        for (final channel in channels) {
          final target = channel['kind'] == 'materialBaseColor'
              ? 'material'
              : 'node';
          expect(channel.keys.toSet(), {
            'kind',
            target,
            'timeline',
            'keyframes',
          });
          expect(
            channel[target],
            startsWith(target == 'material' ? 'mat:' : 'n:'),
          );
          final times =
              doc.payloads[LocalId.parse(channel['timeline'] as String)]!;
          final values =
              doc.payloads[LocalId.parse(channel['keyframes'] as String)]!;
          expect(times.encoding, PayloadEncoding.floats);
          expect(values.encoding, PayloadEncoding.floats);
          expect(_floats(times), [0, 2]);
          if (camera) {
            expect(_floats(values)[0], closeTo(math.pi / 4, 1e-7));
            expect(_floats(values)[1], closeTo(math.pi / 2, 1e-7));
          } else {
            expect(
              _floats(values),
              channel['kind'] == 'materialBaseColor'
                  ? [1, 0, 0, 1, 0, 0, 1, 1]
                  : [2, 6],
            );
          }
        }
        final controller = SceneController();
        final element = _RecordingElement(controller);
        controller.attachElement(element);
        controller.loadDocument(doc);
        expect(controller.animations.keys, [clip.id]);
        expect(controller.animations[clip.id]!.duration, 2);
        final load = element.sent.singleWhere(
          (m) => m.tag == D3Protocol.loadScene,
        );
        final manifest = jsonDecode(utf8.decode(load.data)) as Map;
        expect((manifest['animations'] as Map).values.single, encoded);
        final deliveredPayloads = element.sent
            .where((m) => m.tag == D3Protocol.payload)
            .toList();
        expect(deliveredPayloads, hasLength(4));
        for (var i = 0; i < deliveredPayloads.length; i++) {
          expect(
            deliveredPayloads[i].data.sublist(8),
            doc.payloads.values.elementAt(i).bytes,
          );
        }
        controller.dispose();
      }
    },
  );

  for (final camera in [false, true]) {
    for (final bare in [false, true]) {
      test(
        'public controls emit exact mutations camera=$camera bare=$bare',
        () {
          final doc = buildU4PropertyDocument(camera: camera);
          final before = writeFsceneWithExtensions(doc);
          final clip = doc.animations.values.single;
          final controller = SceneController();
          final element = _RecordingElement(controller);
          controller.attachElement(element);
          controller.loadDocument(doc);
          final mirrorBefore = writeFsceneWithExtensions(
            controller.serializeScene()!,
          );
          element.sent.clear();
          final logs = <String>[];
          final controls = U4PropertyControls(
            controller,
            doc,
            bareIds: bare,
            log: logs.add,
          );
          final initial = element.commands;
          final token = clip.id.toToken();
          if (bare) {
            final batch = initial.removeAt(0);
            expect(batch['op'], 'batch');
            final ops = (batch['ops'] as List).cast<Map>();
            expect(ops.map((op) => op['op']), [
              'removeAnimation',
              'upsertAnimation',
            ]);
            expect(ops.map((op) => op['id']), [token, token]);
            final animation = ops[1]['animation'] as Map;
            expect(animation['channels'], isEmpty);
            final canonical =
                encodeAnimationSpec(clip, doc)['d3:properties'] as List;
            final delivered = (animation['d3:properties'] as List).cast<Map>();
            for (var i = 0; i < delivered.length; i++) {
              expect(delivered[i]['kind'], (canonical[i] as Map)['kind']);
              for (final field in [
                'material',
                'node',
                'timeline',
                'keyframes',
              ]) {
                if (delivered[i].containsKey(field)) {
                  expect(
                    delivered[i][field],
                    LocalId.parse(
                      (canonical[i] as Map)[field] as String,
                    ).toToken(),
                  );
                  expect(delivered[i][field], isNot(contains(':')));
                }
              }
            }
          }
          expect(initial, [
            {
              'op': 'anim',
              'anim': token,
              'play': true,
              'time': 0.0,
              'weight': 1.0,
              'loop': true,
            },
            {'op': 'anim', 'anim': token, 'pause': true},
          ]);
          element.sent.clear();
          for (final time in [0.0, 1.0, 2.0]) {
            controls.seek(time);
          }
          controls.seek(1);
          controls.setWeight(0.25);
          controls.togglePlayback();
          controls.setWeight(1);
          controls.togglePlayback();
          controls.stop();
          expect(element.commands, [
            for (final time in [0.0, 1.0, 2.0]) ...[
              {'op': 'anim', 'anim': token, 'pause': true},
              {'op': 'anim', 'anim': token, 'time': time},
            ],
            {'op': 'anim', 'anim': token, 'pause': true},
            {'op': 'anim', 'anim': token, 'time': 1.0},
            {'op': 'anim', 'anim': token, 'play': true, 'weight': 0.25},
            {'op': 'anim', 'anim': token, 'pause': true},
            {'op': 'anim', 'anim': token, 'play': true},
            {'op': 'anim', 'anim': token, 'play': true, 'weight': 1.0},
            {'op': 'anim', 'anim': token, 'pause': true},
            {'op': 'anim', 'anim': token, 'stop': true},
          ]);
          expect(
            element.sent.every((m) => m.tag == D3Protocol.command),
            isTrue,
          );
          expect(writeFsceneWithExtensions(doc), before);
          expect(
            writeFsceneWithExtensions(controller.serializeScene()!),
            mirrorBefore,
          );
          expect(logs.first, contains('rawIds=$bare'));
          expect(logs.every((log) => log.contains('requested')), isTrue);
          expect(controls.playing, isFalse);
          expect(controls.weight, 1);
          controller.dispose();
        },
      );
    }
  }

  test(
    'camera selector changes only the clip, retaining geometry and payloads',
    () {
      Map comparable(bool camera) {
        final doc = buildU4PropertyDocument(camera: camera);
        final wire = jsonDecode(writeFsceneWithExtensions(doc)) as Map;
        wire.remove('documentId');
        wire.remove('animations');
        return wire;
      }

      expect(comparable(true), comparable(false));
      final normal = buildU4PropertyDocument();
      final camera = buildU4PropertyDocument(camera: true);
      expect(
        camera.payloads.values.map((p) => p.bytes),
        normal.payloads.values.map((p) => p.bytes),
      );
    },
  );

  test(
    'bounds fit above reserved footer at rest and narrowest authored FOV',
    () {
      final doc = buildU4PropertyDocument();
      final bounds = documentContentBounds(doc)!;
      for (final fov in [math.pi / 4, math.pi / 3, math.pi / 2]) {
        u4Node(doc, 'camera').components.single.properties['fovRadiansY'] =
            DoubleValue(fov);
        final camera = SceneCamera.fromDocument(
          doc,
          cameraNode: u4Node(doc, 'camera').id,
        )!;
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
                expect(screen.$2, inInclusiveRange(80, height - 260));
              }
            }
          }
        }
      }
    },
  );
}

List<double> _floats(PayloadSpec payload) {
  final data = ByteData.sublistView(payload.bytes!);
  return [
    for (var i = 0; i < data.lengthInBytes; i += 4)
      data.getFloat32(i, Endian.little),
  ];
}

class _RecordingElement extends SceneViewElement {
  _RecordingElement(SceneController controller)
    : super(SceneViewLeaf(controller: controller));
  final sent = <({int tag, Uint8List data})>[];
  List<Map> get commands =>
      sent.map((m) => jsonDecode(utf8.decode(m.data)) as Map).toList();
  @override
  void sendMutation(int tag, Uint8List data) =>
      sent.add((tag: tag, data: Uint8List.fromList(data)));
}
