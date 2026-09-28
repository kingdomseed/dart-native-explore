// W14 render-texture + views checks: the `renderTexture` resource and
// `views` manifest encodings, the `updateViews`/`render` command ops,
// and the `updateStage` quality knobs — pinned by
// docs/extended-surface-program.md §W14. Same constraint as the
// W3–W13 tests: package:dart3d/dart3d.dart is unreachable under
// `dart test` (the barrel transitively imports package:dartnative,
// which needs DartNative's patched SDK), so this pulls the pure-Dart
// libraries directly and exercises `diffCommands` —
// `SceneController.renderTexture`/`updateViews` are thin wrappers over
// `encodeRenderCommand`/`encodeViewSpec`.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:dart3d/src/components.dart';
import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';

void main() {
  // Deterministic ids — explicit (session, index) pairs so tokens are
  // stable across documents and expected shapes can name them.
  const rtId = LocalId(1, 50);
  const camId = LocalId(1, 60);

  /// A document with one render texture, one camera node, and —
  /// unless [withView] is false — a view binding them ([view]
  /// overrides the default cam→rt entry).
  SceneDocument rtDoc({
    int width = 256,
    int height = 256,
    String update = 'everyFrame',
    bool withView = true,
    RenderViewSpec? view,
  }) {
    final doc = SceneDocument();
    doc.addResource(
      RenderTextureResource(rtId, width: width, height: height, update: update),
    );
    doc.addNode(
      NodeSpec(
        id: camId,
        name: 'cam',
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
    if (withView) {
      doc.views.add(view ?? RenderViewSpec(cameraNode: camId, target: rtId));
    }
    return doc;
  }

  /// The manifest `resources` entry for a render texture.
  Map<String, dynamic> rtEntry({
    String update = 'everyFrame',
    int? intervalMilliseconds,
    String filter = 'linear',
    String wrap = 'clampToEdge',
  }) {
    final doc = SceneDocument();
    doc.addResource(
      RenderTextureResource(
        rtId,
        width: 256,
        height: 128,
        update: update,
        intervalMilliseconds: intervalMilliseconds,
        filter: filter,
        wrap: wrap,
      ),
    );
    final manifest = jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
    return (manifest['resources']
            as Map<String, dynamic>)['rt:${rtId.toToken()}']
        as Map<String, dynamic>;
  }

  group('render texture manifest', () {
    test('the resource encodes kind/width/height with defaults omitted', () {
      final entry = rtEntry();
      expect(entry['kind'], 'renderTexture');
      expect(entry['width'], 256);
      expect(entry['height'], 128);
      // everyFrame/linear/clampToEdge are the wire defaults.
      expect(entry.containsKey('update'), isFalse);
      expect(entry.containsKey('filter'), isFalse);
      expect(entry.containsKey('wrap'), isFalse);
      expect(entry.containsKey('intervalMilliseconds'), isFalse);
    });

    test("update:'manual' emits the key; non-defaults round out", () {
      expect(rtEntry(update: 'manual')['update'], 'manual');
      final interval = rtEntry(
        update: 'interval',
        intervalMilliseconds: 500,
        filter: 'nearest',
        wrap: 'repeat',
      );
      expect(interval['update'], 'interval');
      expect(interval['intervalMilliseconds'], 500);
      expect(interval['filter'], 'nearest');
      expect(interval['wrap'], 'repeat');
    });
  });

  group('views manifest', () {
    test('a view entry carries camera/target tokens, defaults omitted', () {
      final manifest = jsonDecode(writeFscene(rtDoc())) as Map<String, dynamic>;
      expect(manifest['views'], [
        {'camera': 'n:${camId.toToken()}', 'target': 'rt:${rtId.toToken()}'},
      ]);
    });

    test('non-default members emit per upstream _encodeView', () {
      final doc = rtDoc(
        view: RenderViewSpec(
          cameraNode: camId,
          target: rtId,
          layerMask: 2,
          order: 1,
          antiAliasingMode: 'msaa',
          renderScale: 0.5,
          filterQuality: 'high',
        ),
      );
      final manifest = jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
      expect((manifest['views'] as List).single, {
        'camera': 'n:${camId.toToken()}',
        'target': 'rt:${rtId.toToken()}',
        'layerMask': 2,
        'order': 1,
        'antiAliasing': 'msaa',
        'renderScale': 0.5,
        'filterQuality': 'high',
      });
    });

    test('a null target omits the key — the screen-target shape', () {
      final doc = rtDoc(view: RenderViewSpec(cameraNode: camId));
      final manifest = jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
      expect((manifest['views'] as List).single, {
        'camera': 'n:${camId.toToken()}',
      });
    });
  });

  group('command ops', () {
    test('an rt content change emits upsertResource with the rt id', () {
      final a = rtDoc();
      final b = rtDoc(width: 512);
      final ops = diffCommands(diffScene(a, b), a, b);
      expect(ops, hasLength(1));
      final op = ops.single;
      expect(op['op'], 'upsertResource');
      expect(op['id'], 'rt:${rtId.toToken()}');
      expect((op['resource'] as Map)['width'], 512);
    });

    test(
      'a views-only change emits one trailing updateViews — nothing else',
      () {
        final a = rtDoc(withView: false);
        final b = rtDoc();
        // The views list is the only difference, and upstream
        // diffScene never flags it — the op comes from diffCommands'
        // own encoded-list compare.
        final diff = diffScene(a, b);
        expect(diff.isEmpty, isTrue);
        final ops = diffCommands(diff, a, b);
        expect(ops, hasLength(1));
        expect(ops.single, {
          'op': 'updateViews',
          'views': [
            {
              'camera': 'n:${camId.toToken()}',
              'target': 'rt:${rtId.toToken()}',
            },
          ],
        });
      },
    );

    test('updateViews lands last, after resource and stage ops', () {
      final a = rtDoc(withView: false);
      final b = rtDoc(width: 512);
      b.stage.renderScale = 0.5;
      final ops = diffCommands(diffScene(a, b), a, b);
      expect(
        [for (final o in ops) o['op']],
        ['upsertResource', 'updateStage', 'updateViews'],
      );
    });

    test('identical view lists emit no updateViews', () {
      final a = rtDoc();
      final b = rtDoc();
      expect(diffCommands(diffScene(a, b), a, b), isEmpty);
    });

    test('encodeRenderCommand carries the op and rt-prefixed target', () {
      expect(encodeRenderCommand(rtId), {
        'op': 'render',
        'target': 'rt:${rtId.toToken()}',
      });
    });

    test('a stage renderScale change emits updateStage with the key', () {
      final a = rtDoc();
      final b = rtDoc();
      b.stage.renderScale = 0.75;
      final ops = diffCommands(diffScene(a, b), a, b);
      expect(ops, hasLength(1));
      expect(ops.single, {
        'op': 'updateStage',
        'stage': {'renderScale': 0.75},
      });
    });
  });
}
