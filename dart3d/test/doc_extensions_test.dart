// Stabilization regressions for the dart3d document extensions the
// upstream codec drops or refuses (docs/triage/dart.md): malformed
// `viewport` values, the serializeScene → write → read round-trip, W26
// procedural-shape geometry resources in the document mirror, and
// dart3d `featuresRequired` names.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/doc_layer.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';

void main() {
  const camId = LocalId(1, 60);
  const lineGeo = LocalId(1, 70);
  const lineNode = LocalId(1, 71);

  SceneDocument cameraDoc() {
    final doc = SceneDocument();
    doc.addNode(
      NodeSpec(
        id: camId,
        name: 'cam',
        transform: TrsTransform(),
        components: [
          ComponentSpec('camera', properties: {'fovRadiansY': DoubleValue(1)}),
        ],
      ),
      root: true,
    );
    return doc;
  }

  /// A W26 polyline as an upstream-style `procedural` geometry resource
  /// — the manifest entry shape the natives accept.
  Map<String, Object?> polylineResource({double width = 0.1}) => {
    'kind': 'geometry',
    'procedural': {
      'shape': 'polyline',
      'points': [
        {
          'v3': [0, 0, 0],
        },
        {
          'v3': [1, 0, 0],
        },
      ],
      'width': width,
    },
  };

  Map<String, dynamic> manifestOf(String text) =>
      jsonDecode(text) as Map<String, dynamic>;

  group('viewport decode', () {
    final camToken = 'n:${camId.toToken()}';
    for (final bad in <Object?>[
      'full',
      [0, 0, 100],
      [0, null, 100, 100],
      [0, 0, '100', 100],
      {'l': 0},
    ]) {
      test('malformed $bad decodes to a full-target view', () {
        final view = decodeViewSpec({'camera': camToken, 'viewport': bad});
        expect((view as Dart3dRenderViewSpec).viewport, isNull);
      });
    }

    test('a malformed viewport no longer rejects the whole scene', () {
      final m = manifestOf(writeFscene(cameraDoc()));
      m['views'] = [
        {
          'camera': camToken,
          'viewport': [0, null, 1, 1],
        },
      ];
      final doc = readFsceneWithExtensions(jsonEncode(m));
      expect(doc.views, hasLength(1));
      expect((doc.views.single as Dart3dRenderViewSpec).viewport, isNull);
    });

    test('a well-formed viewport still decodes', () {
      final view = decodeViewSpec({
        'camera': camToken,
        'viewport': [0, 0, 320.5, 240],
      });
      expect((view as Dart3dRenderViewSpec).viewport, [0, 0, 320.5, 240]);
    });
  });

  group('serializeScene + writeFsceneWithExtensions', () {
    test('viewport survives the persisted round-trip', () {
      final live = cameraDoc()
        ..views.add(
          Dart3dRenderViewSpec(
            cameraNode: camId,
            viewport: const [0, 0, 640, 480],
          ),
        );
      final text = writeFsceneWithExtensions(serializeScene(live));
      expect(manifestOf(text)['views'], [
        {
          'camera': 'n:${camId.toToken()}',
          'viewport': [0, 0, 640, 480],
        },
      ]);
      final back = readFsceneWithExtensions(text);
      expect((back.views.single as Dart3dRenderViewSpec).viewport, const [
        0,
        0,
        640,
        480,
      ]);
    });

    test('no extensions: byte-identical to upstream writeFscene', () {
      final doc = cameraDoc();
      expect(writeFsceneWithExtensions(doc), writeFscene(doc));
      expect(utf8.decode(D3Protocol.loadSceneBytes(doc)), writeFscene(doc));
    });
  });

  group('W26 procedural resources in the document mirror', () {
    Map<String, Object?> upsert(Map<String, Object?> resource) => {
      'op': 'upsertResource',
      'id': 'geo:${lineGeo.toToken()}',
      'resource': resource,
    };

    test('upstream decode refuses the shape (the original drop)', () {
      final m = manifestOf(writeFscene(cameraDoc()));
      m['resources'] = {'geo:${lineGeo.toToken()}': polylineResource()};
      expect(() => readFscene(jsonEncode(m)), throwsA(anything));
      // …the extension-aware reader keeps it.
      final doc = readFsceneWithExtensions(jsonEncode(m));
      expect(d3ExtensionResources(doc).keys, [lineGeo]);
      expect(doc.resources, isNot(contains(lineGeo)));
    });

    test('upsertResource folds instead of dropping; serialize keeps it', () {
      final doc = cameraDoc();
      foldCommandIntoDocument(doc, upsert(polylineResource()));
      final node = NodeSpec(
        id: lineNode,
        name: 'line',
        transform: TrsTransform(),
        components: [
          ComponentSpec(
            'mesh',
            properties: {'geometry': ResourceRefValue(lineGeo)},
          ),
        ],
      );
      foldCommandIntoDocument(doc, {
        'op': 'addNode',
        'node': lineNode.toToken(),
        'spec': encodeNodeCommandSpec(node, doc),
      });
      expect(d3ExtensionResources(doc)[lineGeo], polylineResource());
      expect(doc.nodes, contains(lineNode));

      final snapshot = serializeScene(doc);
      expect(d3ExtensionResources(snapshot)[lineGeo], polylineResource());
      final text = writeFsceneWithExtensions(snapshot);
      final resources = manifestOf(text)['resources'] as Map;
      expect(resources['geo:${lineGeo.toToken()}'], polylineResource());
      // The wire manifest carries it too.
      final wire = manifestOf(utf8.decode(D3Protocol.loadSceneBytes(doc)));
      expect(
        (wire['resources'] as Map)['geo:${lineGeo.toToken()}'],
        polylineResource(),
      );
      // Snapshot is detached.
      d3ExtensionResources(doc).clear();
      expect(d3ExtensionResources(snapshot), contains(lineGeo));
    });

    test('an upstream resource upsert under the same id replaces it', () {
      final doc = cameraDoc();
      foldCommandIntoDocument(doc, upsert(polylineResource()));
      foldCommandIntoDocument(
        doc,
        upsert({
          'kind': 'geometry',
          'procedural': {
            'shape': 'cuboid',
            'extents': [1, 1, 1],
          },
        }),
      );
      expect(d3ExtensionResources(doc), isEmpty);
      expect(doc.resources[lineGeo], isA<GeometryResource>());
      foldCommandIntoDocument(doc, upsert(polylineResource()));
      expect(doc.resources, isNot(contains(lineGeo)));
      expect(d3ExtensionResources(doc), contains(lineGeo));
    });

    test('diffCommands re-emits a changed extension resource', () {
      final a = cameraDoc();
      d3ExtensionResources(a)[lineGeo] = polylineResource();
      final same = cameraDoc();
      d3ExtensionResources(same)[lineGeo] = polylineResource();
      final changed = cameraDoc();
      d3ExtensionResources(changed)[lineGeo] = polylineResource(width: 0.5);

      List<Map<String, Object?>> upserts(
        SceneDocument from,
        SceneDocument to,
      ) => [
        for (final op in diffCommands(diffScene(from, to), from, to))
          if (op['op'] == 'upsertResource') op,
      ];
      expect(upserts(a, same), isEmpty);
      final ops = upserts(a, changed);
      expect(ops, hasLength(1));
      expect(ops.single['id'], 'geo:${lineGeo.toToken()}');
      expect(ops.single['resource'], polylineResource(width: 0.5));
    });
  });

  group('dart3d featuresRequired', () {
    test('d3 features decode and survive serialize', () {
      final m = manifestOf(writeFscene(cameraDoc()));
      m['featuresRequired'] = ['d3Instances', 'skinning', 'particles'];
      expect(() => readFscene(jsonEncode(m)), throwsA(anything));
      final doc = readFsceneWithExtensions(jsonEncode(m));
      expect(doc.featuresRequired, {'d3Instances', 'skinning', 'particles'});
      final again = serializeScene(doc);
      expect(again.featuresRequired, doc.featuresRequired);
    });

    test('an unknown required feature is still refused', () {
      final m = manifestOf(writeFscene(cameraDoc()));
      m['featuresRequired'] = ['gaussianSplats'];
      expect(
        () => readFsceneWithExtensions(jsonEncode(m)),
        throwsA(isA<FsceneUnsupportedFeatureException>()),
      );
    });
  });
}
