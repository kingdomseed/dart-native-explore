import 'dart:convert';
import 'dart:typed_data';
import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:test/test.dart';
import 'u4_property_animation_test.dart' as data;

class RecordingElement extends SceneViewElement {
  RecordingElement(SceneController controller)
    : super(SceneViewLeaf(controller: controller));
  final sent = <({int tag, Uint8List data})>[];
  @override
  void sendMutation(int tag, Uint8List bytes) {
    sent.add((tag: tag, data: Uint8List.fromList(bytes)));
  }
}

void main() {
  test(
    'malformed raw animation upsert is rejected before dispatch or mirror change',
    () {
      final controller = SceneController();
      final element = RecordingElement(controller);
      controller.attachElement(element);
      controller.loadDocument(data.fixture());
      final prior = controller.document!.animations[data.clip];
      element.sent.clear();
      expect(
        () => controller.applyCommands([
          {
            'op': 'upsertAnimation',
            'id': 'anim:000000800000A',
            'animation': {
              'channels': [],
              'd3:properties': [
                {'kind': 'unknown'},
              ],
            },
          },
        ]),
        throwsA(anything),
      );
      expect(element.sent, isEmpty);
      expect(controller.document!.animations[data.clip], same(prior));
      controller.applyCommands([
        {
          'op': 'upsertAnimation',
          'id': 'anim:000000800000A',
          'animation': data.literal,
        },
      ]);
      expect(
        controller.document!.animations[data.clip],
        isA<Dart3dAnimationSpec>(),
      );
      expect(jsonDecode(utf8.decode(element.sent.single.data)), {
        'op': 'upsertAnimation',
        'id': 'anim:000000800000A',
        'animation': data.literal,
      });
      controller.detachElement(element);
    },
  );
  test(
    'controller preserves authored clip through controls and same-ID diff/clear/remove',
    () {
      final controller = SceneController(), doc = data.fixture();
      final element = RecordingElement(controller);
      controller.attachElement(element);
      controller.loadDocument(doc);
      element.sent.clear();
      controller.playAnimation(
        data.clip,
        time: 1,
        weight: 0.25,
        timeScale: 2,
        loop: true,
      );
      controller.pauseAnimation(data.clip);
      controller.seekAnimation(data.clip, 2);
      controller.stopAnimation(data.clip);
      expect(element.sent.map((m) => jsonDecode(utf8.decode(m.data))), [
        {
          'op': 'anim',
          'anim': '000000800000A',
          'play': true,
          'time': 1.0,
          'weight': 0.25,
          'timeScale': 2.0,
          'loop': true,
        },
        {'op': 'anim', 'anim': '000000800000A', 'pause': true},
        {'op': 'anim', 'anim': '000000800000A', 'time': 2.0},
        {'op': 'anim', 'anim': '000000800000A', 'stop': true},
      ]);
      final saved = controller.serializeScene()!;
      expect(
        encodeAnimationSpec(saved.animations[data.clip]!, saved),
        data.literal,
      );
      final next = serializeScene(doc);
      next.animations[data.clip] = Dart3dAnimationSpec(
        data.clip,
        propertyChannels: [
          D3LightIntensityChannel(
            node: data.light,
            timeline: data.times,
            keyframes: data.powers,
          ),
        ],
      );
      element.sent.clear();
      controller.applyDiff(diffScene(doc, next), next);
      expect(
        (jsonDecode(utf8.decode(element.sent.single.data)) as Map)['op'],
        'upsertAnimation',
      );
      expect(controller.animations[data.clip]!.channelCount, 1);
      controller.applyCommands([
        {
          'op': 'upsertAnimation',
          'id': 'anim:000000800000A',
          'animation': {'channels': [], 'd3:properties': []},
        },
      ]);
      expect(controller.animations[data.clip]!.channelCount, 0);
      controller.applyCommands([
        {'op': 'removeAnimation', 'id': 'anim:000000800000A'},
      ]);
      expect(controller.animations, isEmpty);
      controller.detachElement(element);
    },
  );
  test('controller forwards late binary payloads and same-ID replacements', () {
    final controller = SceneController();
    final element = RecordingElement(controller);
    controller.attachElement(element);
    final doc = data.fixture();
    doc.payloads[data.powers]!.bytes = null;
    controller.loadDocument(doc);
    element.sent.clear();
    controller.sendPayload(
      PayloadSpec(
        data.powers,
        encoding: PayloadEncoding.floats,
        bytes: data.f32([3, 7]),
      ),
    );
    expect(element.sent.single.tag, D3Protocol.payload);
    final wire = ByteData.sublistView(element.sent.single.data);
    expect(wire.getUint32(0, Endian.little), 1);
    expect(wire.getUint32(4, Endian.little), 8);
    expect(element.sent.single.data.sublist(8), data.f32([3, 7]));
    element.sent.clear();
    controller.sendPayload(
      PayloadSpec(
        data.powers,
        encoding: PayloadEncoding.floats,
        bytes: data.f32([-1, 6]),
      ),
    );
    expect(element.sent.single.data.sublist(8), data.f32([-1, 6]));
    expect(
      controller.serializeScene()!.payloads[data.powers]!.bytes,
      data.f32([-1, 6]),
    );
    expect(
      () => D3Protocol.loadSceneBytes(controller.document!),
      throwsFormatException,
    );
    element.sent.clear();
    controller.sendPayload(
      PayloadSpec(
        data.powers,
        encoding: PayloadEncoding.floats,
        bytes: data.f32([4, 8]),
      ),
    );
    expect(
      controller.serializeScene()!.payloads[data.powers]!.bytes,
      data.f32([4, 8]),
    );
    controller.detachElement(element);
  });
  test(
    'malformed nested animation metadata leaves earlier mirror and dispatch untouched',
    () {
      final controller = SceneController();
      final element = RecordingElement(controller);
      controller.attachElement(element);
      controller.loadDocument(data.fixture());
      element.sent.clear();
      final before = writeFsceneWithExtensions(controller.document!);
      expect(
        () => controller.applyCommands([
          {'op': 'removeAnimation', 'id': 'anim:000000800000A'},
          {
            'op': 'batch',
            'ops': [
              {
                'op': 'upsertAnimation',
                'id': 'anim:000000800000A',
                'animation': {'d3:properties': 'bad'},
              },
            ],
          },
        ]),
        throwsFormatException,
      );
      expect(element.sent, isEmpty);
      expect(writeFsceneWithExtensions(controller.document!), before);
      controller.detachElement(element);
    },
  );
  test(
    'available curves validate against preceding payload updates in a raw batch',
    () {
      final controller = SceneController();
      final element = RecordingElement(controller);
      controller.attachElement(element);
      controller.loadDocument(data.fixture());
      element.sent.clear();
      controller.applyCommands([
        {'op': 'removeAnimation', 'id': 'anim:000000800000A'},
        {
          'op': 'upsertPayload',
          'id': 'chunk:000000800000C',
          'encoding': 'floats',
          'bytes': base64Encode(data.f32([0, 1, 2])),
        },
        {
          'op': 'upsertPayload',
          'id': 'chunk:000000800000G',
          'encoding': 'floats',
          'bytes': base64Encode(data.f32([2, 4, 6])),
        },
        {
          'op': 'upsertAnimation',
          'id': 'anim:000000800000A',
          'animation': {
            'channels': [],
            'd3:properties': [(data.literal['d3:properties'] as List)[1]],
          },
        },
      ]);
      expect(element.sent.single.tag, D3Protocol.command);
      expect(controller.animations[data.clip]!.duration, 2);
      controller.detachElement(element);
    },
  );
  test(
    'strict native capability check refuses unfinished property playback without changing document',
    () {
      final controller = SceneController();
      expect(
        () => controller.loadDocument(data.fixture(), strictFeatures: true),
        throwsA(isA<FsceneUnsupportedFeatureException>()),
      );
      expect(controller.document, isNull);
    },
  );
  test(
    'unrelated extended host survives actual lazy async and nested subtree loads',
    () async {
      final controller = SceneController();
      final element = RecordingElement(controller);
      controller.attachElement(element);
      final host = data.fixture();
      const placeholder = LocalId(2, 1), nested = LocalId(3, 2);
      host.addNode(
        NodeSpec(
          id: placeholder,
          instance: PrefabInstanceSpec(
            source: const AssetRef('outer'),
            load: LoadPolicy.lazy,
          ),
        ),
        root: true,
      );
      final outer = SceneDocument()
        ..addNode(
          NodeSpec(id: const LocalId(3, 1), children: [nested]),
          root: true,
        )
        ..addNode(
          NodeSpec(
            id: nested,
            instance: PrefabInstanceSpec(
              source: const AssetRef('inner'),
              load: LoadPolicy.lazy,
            ),
          ),
        );
      final ordinary = SceneDocument()
        ..addNode(NodeSpec(id: const LocalId(4, 1)), root: true);
      final hostBefore = writeFsceneWithExtensions(host),
          outerBefore = writeFsceneWithExtensions(outer);
      controller.loadDocument(host);
      element.sent.clear();
      await controller.loadSubtreeAsync(
        placeholder,
        loadPrefab: (_) async => outer,
      );
      expect(
        encodeAnimationSpec(
          controller.document!.animations[data.clip]!,
          controller.document!,
        ),
        data.literal,
      );
      final command = jsonDecode(utf8.decode(element.sent.single.data)) as Map;
      final nestedOp = (command['ops'] as List).cast<Map>().singleWhere(
        (o) => o['op'] == 'addNode' && (o['spec'] as Map)['instance'] != null,
      );
      final nestedId = LocalId.parse(nestedOp['node'] as String);
      element.sent.clear();
      await controller.loadSubtreeAsync(
        nestedId,
        loadPrefab: (_) async => ordinary,
      );
      expect(element.sent, hasLength(1));
      controller.unloadSubtree(nestedId);
      element.sent.clear();
      await expectLater(
        controller.loadSubtreeAsync(
          nestedId,
          loadPrefab: (_) async => data.fixture(),
        ),
        throwsUnsupportedError,
      );
      expect(element.sent, isEmpty);
      expect(writeFsceneWithExtensions(host), hostBefore);
      expect(writeFsceneWithExtensions(outer), outerBefore);
      controller.detachElement(element);
    },
  );
}
