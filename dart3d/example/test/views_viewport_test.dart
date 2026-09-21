// W24 view `viewport` extension: the dart3d `Dart3dRenderViewSpec`
// codec, its survival through the `.fscene` manifest mutation
// (`loadSceneBytes`) and the `.fsceneb` container reader, and the
// `updateViews` emit decision on a viewport-only diff. Same
// constraint as the W14 tests: package:dart3d/dart3d.dart is
// unreachable under `dart test`, so this pulls the pure-Dart
// libraries directly.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';

void main() {
  const camId = LocalId(1, 60);
  const cam2Id = LocalId(1, 61);

  /// A document with two camera nodes and [views] (default: one
  /// screen view on `cam`).
  SceneDocument viewDoc({List<RenderViewSpec>? views}) {
    final doc = SceneDocument();
    for (final (id, name) in [(camId, 'cam'), (cam2Id, 'cam2')]) {
      doc.addNode(
        NodeSpec(
          id: id,
          name: name,
          transform: TrsTransform(),
          components: [
            ComponentSpec(
              'camera',
              properties: {'fovRadiansY': DoubleValue(1.0)},
            ),
          ],
        ),
        root: true,
      );
    }
    doc.views.addAll(views ?? [RenderViewSpec(cameraNode: camId)]);
    return doc;
  }

  /// The manifest `views` entry list from the wire mutation —
  /// `loadSceneBytes` re-encodes views through dart3d's codec, so
  /// `viewport` survives where upstream `writeFscene` drops it.
  List<dynamic> wireViews(SceneDocument doc) =>
      (jsonDecode(utf8.decode(D3Protocol.loadSceneBytes(doc)))
              as Map<String, dynamic>)['views']
          as List<dynamic>;

  group('encodeViewSpec', () {
    test('a Dart3dRenderViewSpec emits viewport as [l,b,w,h]', () {
      final doc = viewDoc(
        views: [
          Dart3dRenderViewSpec(
            cameraNode: camId,
            order: 2,
            viewport: const [0, 0, 640, 480],
          ),
        ],
      );
      expect(wireViews(doc).single, {
        'camera': 'n:${camId.toToken()}',
        'order': 2,
        'viewport': [0, 0, 640, 480],
      });
    });

    test('a null viewport omits the key — upstream shape unchanged', () {
      final doc = viewDoc(views: [Dart3dRenderViewSpec(cameraNode: camId)]);
      expect(wireViews(doc).single, {'camera': 'n:${camId.toToken()}'});
    });

    test('a plain RenderViewSpec never emits the key', () {
      final doc = viewDoc();
      expect(wireViews(doc).single, {'camera': 'n:${camId.toToken()}'});
    });
  });

  group('decodeViewSpec', () {
    test('round-trips every member including viewport', () {
      final doc = viewDoc(
        views: [
          Dart3dRenderViewSpec(
            cameraNode: camId,
            layerMask: 4,
            order: 1,
            antiAliasingMode: 'msaa',
            renderScale: 0.5,
            filterQuality: 'high',
            viewport: const [10, 20, 300, 200],
          ),
        ],
      );
      final decoded = decodeViewSpec(
        Map<String, Object?>.from(wireViews(doc).single as Map),
      );
      expect(decoded, isA<Dart3dRenderViewSpec>());
      expect(decoded.cameraNode, camId);
      expect(decoded.layerMask, 4);
      expect(decoded.order, 1);
      expect(decoded.antiAliasingMode, 'msaa');
      expect(decoded.renderScale, 0.5);
      expect(decoded.filterQuality, 'high');
      expect((decoded as Dart3dRenderViewSpec).viewport, [
        10.0,
        20.0,
        300.0,
        200.0,
      ]);
    });

    test('an absent viewport decodes null; defaults fill the rest', () {
      final decoded = decodeViewSpec({'camera': 'n:${camId.toToken()}'});
      expect(decoded, isA<Dart3dRenderViewSpec>());
      expect((decoded as Dart3dRenderViewSpec).viewport, isNull);
      expect(decoded.target, isNull);
      expect(decoded.layerMask, 0xFFFFFFFF);
      expect(decoded.order, 0);
    });
  });

  group('manifest survival', () {
    /// A two-view split-screen doc: `cam` on the left half, `cam2`
    /// on the right — both in 1280×720 target pixels.
    SceneDocument splitDoc() => viewDoc(
      views: [
        Dart3dRenderViewSpec(
          cameraNode: camId,
          viewport: const [0, 0, 640, 720],
        ),
        Dart3dRenderViewSpec(
          cameraNode: cam2Id,
          order: 1,
          viewport: const [640, 0, 640, 720],
        ),
      ],
    );

    test('readFsceneWithExtensions preserves viewport per view', () {
      // The wire manifest carries the extension; upstream readFscene
      // would drop it — the dart3d decode restores it.
      final manifest = utf8.decode(D3Protocol.loadSceneBytes(splitDoc()));
      final doc = readFsceneWithExtensions(manifest);
      expect(doc.views, hasLength(2));
      expect((doc.views[0] as Dart3dRenderViewSpec).viewport, [
        0.0,
        0.0,
        640.0,
        720.0,
      ]);
      expect(doc.views[1].order, 1);
      expect(doc.views[1].cameraNode, cam2Id);
      expect((doc.views[1] as Dart3dRenderViewSpec).viewport, [
        640.0,
        0.0,
        640.0,
        720.0,
      ]);
    });

    test('upstream readFscene alone would lose it — the decoder is '
        'what preserves', () {
      final manifest = utf8.decode(D3Protocol.loadSceneBytes(splitDoc()));
      final upstream = readFscene(manifest);
      expect(upstream.views, hasLength(2));
      expect(upstream.views[0], isNot(isA<Dart3dRenderViewSpec>()));
    });

    test('readFsceneb preserves viewport through the container', () {
      // The JSON chunk is the patched manifest — the same bytes
      // loadSceneBytes puts on the wire.
      final manifest = utf8.decode(D3Protocol.loadSceneBytes(splitDoc()));
      final jsonChunk = utf8.encode(manifest);
      final body = BytesBuilder()
        ..add(
          Uint8List(8)
            ..setRange(4, 8, ascii.encode('JSON'))
            ..buffer.asByteData().setUint32(0, jsonChunk.length, Endian.little),
        )
        ..add(jsonChunk);
      final remainder = jsonChunk.length % 8;
      if (remainder != 0) body.add(Uint8List(8 - remainder));
      final bodyBytes = body.toBytes();
      final container = Uint8List(16 + bodyBytes.length)
        ..setRange(0, 4, const [0x46, 0x53, 0x43, 0x42])
        ..setRange(16, 16 + bodyBytes.length, bodyBytes);
      ByteData.sublistView(container)
        ..setUint32(4, 2, Endian.little)
        ..setUint32(8, container.length, Endian.little);

      final doc = readFsceneb(container);
      expect(doc.views, hasLength(2));
      expect((doc.views[0] as Dart3dRenderViewSpec).viewport, [
        0.0,
        0.0,
        640.0,
        720.0,
      ]);
      expect((doc.views[1] as Dart3dRenderViewSpec).viewport, [
        640.0,
        0.0,
        640.0,
        720.0,
      ]);
    });
  });

  group('diff', () {
    test('a viewport-only change emits one trailing updateViews', () {
      final a = viewDoc(views: [Dart3dRenderViewSpec(cameraNode: camId)]);
      final b = viewDoc(
        views: [
          Dart3dRenderViewSpec(
            cameraNode: camId,
            viewport: const [0, 0, 320, 240],
          ),
        ],
      );
      final diff = diffScene(a, b);
      expect(diff.isEmpty, isTrue);
      final ops = diffCommands(diff, a, b);
      expect(ops, hasLength(1));
      expect(ops.single, {
        'op': 'updateViews',
        'views': [
          {
            'camera': 'n:${camId.toToken()}',
            'viewport': [0, 0, 320, 240],
          },
        ],
      });
    });

    test('order and layerMask changes still trigger updateViews', () {
      final a = viewDoc();
      final b = viewDoc(views: [RenderViewSpec(cameraNode: camId, order: 3)]);
      final ops = diffCommands(diffScene(a, b), a, b);
      expect(ops, hasLength(1));
      expect(ops.single['op'], 'updateViews');
    });
  });
}
