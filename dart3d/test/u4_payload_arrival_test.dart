import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:test/test.dart';

import 'u4_controller_test.dart' show RecordingElement;
import 'u4_property_animation_test.dart' as data;

SceneDocument lightDocument() {
  final doc = data.fixture();
  doc.animations[data.clip] = Dart3dAnimationSpec(
    data.clip,
    propertyChannels: [
      D3LightIntensityChannel(
        node: data.light,
        timeline: data.times,
        keyframes: data.powers,
      ),
    ],
  );
  return doc;
}

void main() {
  for (final timelineFirst in [true, false]) {
    test(
      'binary curve replacement accepts ${timelineFirst ? 'timeline' : 'values'} first',
      () {
        final controller = SceneController();
        final element = RecordingElement(controller);
        controller.attachElement(element);
        controller.loadDocument(lightDocument());
        element.sent.clear();
        final chunks = [
          PayloadSpec(
            data.times,
            encoding: PayloadEncoding.floats,
            bytes: data.f32([0, 1, 2]),
          ),
          PayloadSpec(
            data.powers,
            encoding: PayloadEncoding.floats,
            bytes: data.f32([2, 4, 6]),
          ),
        ];
        for (final chunk in timelineFirst ? chunks : chunks.reversed) {
          controller.sendPayload(chunk);
          expect(element.sent.last.tag, D3Protocol.payload);
          final snapshot = controller.serializeScene()!;
          expect(snapshot.payloads[chunk.id]!.bytes, chunk.bytes);
          expect(snapshot.animations[data.clip], isA<Dart3dAnimationSpec>());
        }
        expect(element.sent, hasLength(2));
        expect(
          controller.document!.payloads[data.times]!.bytes,
          data.f32([0, 1, 2]),
        );
        expect(
          controller.document!.payloads[data.powers]!.bytes,
          data.f32([2, 4, 6]),
        );
        controller.detachElement(element);
      },
    );
  }

  test('runtime invalid curve cannot leave an earlier removal unsent', () {
    final controller = SceneController();
    final element = RecordingElement(controller);
    controller.attachElement(element);
    final doc = lightDocument();
    const other = LocalId(1, 30);
    doc.animations[other] = Dart3dAnimationSpec(
      other,
      propertyChannels:
          (doc.animations[data.clip] as Dart3dAnimationSpec).propertyChannels,
    );
    controller.loadDocument(doc);
    element.sent.clear();
    final ops = <Map<String, Object?>>[
      {'op': 'removeAnimation', 'id': 'anim:000000800000A'},
      {
        'op': 'upsertPayload',
        'id': 'chunk:000000800000G',
        'encoding': 'floats',
        'bytes': base64Encode(data.f32([-1, 6])),
      },
    ];
    controller.applyCommands(ops);
    expect(controller.document!.animations.containsKey(data.clip), isFalse);
    expect(controller.document!.animations.containsKey(other), isTrue);
    expect(
      controller.document!.payloads[data.powers]!.bytes,
      data.f32([-1, 6]),
    );
    expect(element.sent.single.tag, D3Protocol.command);
    expect(jsonDecode(utf8.decode(element.sent.single.data)), {
      'op': 'batch',
      'ops': ops,
    });
    controller.detachElement(element);
  });

  test(
    'corrective diff can encode an intermediate curve and retain its clip',
    () {
      final controller = SceneController();
      final element = RecordingElement(controller);
      controller.attachElement(element);
      controller.loadDocument(lightDocument());
      controller.sendPayload(
        PayloadSpec(
          data.times,
          encoding: PayloadEncoding.floats,
          bytes: data.f32([0, 1, 2]),
        ),
      );
      final old = controller.document!;
      final next = controller.serializeScene()!;
      next.payloads[data.powers]!.bytes = data.f32([2, 4, 6]);
      element.sent.clear();
      final ops = controller.applyDiff(diffScene(old, next), next);
      expect(ops.map((op) => op['op']), ['upsertPayload', 'upsertAnimation']);
      expect(element.sent.single.tag, D3Protocol.command);
      expect(
        controller.document!.animations[data.clip],
        isA<Dart3dAnimationSpec>(),
      );
      expect(
        controller.document!.payloads[data.powers]!.bytes,
        data.f32([2, 4, 6]),
      );
      controller.detachElement(element);
    },
  );

  test(
    'full document load still rejects an invalid completed curve before dispatch',
    () {
      final controller = SceneController();
      final element = RecordingElement(controller);
      controller.attachElement(element);
      controller.loadDocument(lightDocument());
      final prior = controller.document;
      element.sent.clear();
      final invalid = lightDocument();
      invalid.payloads[data.powers]!.bytes = data.f32([-1, 6]);
      expect(() => controller.loadDocument(invalid), throwsFormatException);
      expect(controller.document, same(prior));
      expect(element.sent, isEmpty);
      controller.detachElement(element);
    },
  );

  for (final encoding in ['floats', 'bytes']) {
    test(
      'runtime $encoding payload metadata survives serialization and correction',
      () {
        final controller = SceneController();
        final element = RecordingElement(controller);
        controller.attachElement(element);
        controller.loadDocument(lightDocument());
        element.sent.clear();
        controller.applyCommands([
          {
            'op': 'upsertPayload',
            'id': 'chunk:000000800000G',
            'encoding': encoding,
            'bytes': [1, 2, 3],
          },
        ]);
        expect(element.sent.single.tag, D3Protocol.command);
        final next = controller.serializeScene()!;
        expect(
          next.payloads[data.powers]!.bytes,
          Uint8List.fromList([1, 2, 3]),
        );
        expect(next.payloads[data.powers]!.length, 3);
        expect(next.payloads[data.powers]!.encoding.name, encoding);
        expect(() => D3Protocol.loadSceneBytes(next), throwsFormatException);
        next.payloads[data.powers] = PayloadSpec(
          data.powers,
          encoding: PayloadEncoding.floats,
          bytes: data.f32([3, 7]),
        );
        element.sent.clear();
        controller.applyDiff(diffScene(controller.document!, next), next);
        expect(element.sent.single.tag, D3Protocol.command);
        expect(
          () => D3Protocol.loadSceneBytes(controller.document!),
          returnsNormally,
        );
        expect(
          controller.serializeScene()!.payloads[data.powers]!.bytes,
          data.f32([3, 7]),
        );
        controller.detachElement(element);
      },
    );
  }

  for (final badMetadata in <Map<String, Object?>>[
    {'encoding': 'bytes'},
    {'length': 7},
  ]) {
    test(
      'corrective diff sends changed $badMetadata with identical payload bytes',
      () {
        final controller = SceneController();
        final element = RecordingElement(controller);
        controller.attachElement(element);
        controller.loadDocument(lightDocument());
        final bytes = data.f32([2, 6]);
        controller.applyCommands([
          {
            'op': 'upsertPayload',
            'id': 'chunk:000000800000G',
            'encoding': 'floats',
            'bytes': base64Encode(bytes),
            ...badMetadata,
          },
        ]);
        final next = controller.serializeScene()!;
        next.payloads[data.powers] = PayloadSpec(
          data.powers,
          encoding: PayloadEncoding.floats,
          length: 8,
          bytes: bytes,
        );
        element.sent.clear();
        final ops = controller.applyDiff(
          diffScene(controller.document!, next),
          next,
        );
        expect(ops, [
          {
            'op': 'upsertPayload',
            'id': 'chunk:000000800000G',
            'encoding': 'floats',
            'length': 8,
            'bytes': base64Encode(bytes),
          },
        ]);
        expect(jsonDecode(utf8.decode(element.sent.single.data)), ops.single);
        expect(
          () => D3Protocol.loadSceneBytes(controller.document!),
          returnsNormally,
        );
        controller.detachElement(element);
      },
    );
  }
}
