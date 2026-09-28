// Regressions for the Codex review threads on PR #14 (stabilize/dart):
// 4122294463 unknown procedural shape names, 4122294474 extension
// resources through prefab composition, 4122294480 normals under a
// singular instance transform.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:dart3d/src/compose_extensions.dart';
import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/doc_layer.dart';
import 'package:dart3d/src/geometry/mesh_data.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/subtree_stream.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

Map<String, Object?> procResource(String shape) => {
  'kind': 'geometry',
  'procedural': {
    'shape': shape,
    'points': [
      {
        'v3': [0, 0, 0],
      },
      {
        'v3': [1, 0, 0],
      },
    ],
    'radius': 0.2,
  },
};

/// A document whose single root mesh node draws extension resource
/// [geo] (shape [shape]).
SceneDocument docWithExtension(LocalId geo, LocalId node, String shape) {
  final doc = SceneDocument();
  d3ExtensionResources(doc)[geo] = procResource(shape);
  doc.addNode(
    NodeSpec(
      id: node,
      name: 'tube',
      transform: TrsTransform(),
      components: [
        ComponentSpec('mesh', properties: {'geometry': ResourceRefValue(geo)}),
      ],
    ),
    root: true,
  );
  return doc;
}

LocalId meshGeometry(NodeSpec node) =>
    (node.components.single.properties['geometry']! as ResourceRefValue).id;

void main() {
  group('4122294463 — only the dart3d shape vocabulary is an extension', () {
    Map<String, dynamic> manifestWith(String shape) {
      final m =
          jsonDecode(writeFscene(SceneDocument())) as Map<String, dynamic>;
      m['resources'] = {
        'geo:${const LocalId(1, 1).toToken()}': procResource(shape),
      };
      return m;
    }

    test('a known W26 shape is kept', () {
      expect(isD3ExtensionResourceJson(procResource('tube')), isTrue);
      final doc = readFsceneWithExtensions(jsonEncode(manifestWith('tube')));
      expect(d3ExtensionResources(doc), hasLength(1));
    });

    test('a typo is refused by the decoder, not swallowed', () {
      expect(isD3ExtensionResourceJson(procResource('cylnder')), isFalse);
      expect(
        () => readFsceneWithExtensions(jsonEncode(manifestWith('cylnder'))),
        throwsA(isA<FsceneFormatException>()),
      );
    });

    test('the mirror refuses a typo upsert instead of storing it', () {
      final doc = SceneDocument();
      expect(
        () => foldCommandIntoDocument(doc, {
          'op': 'upsertResource',
          'id': 'geo:${const LocalId(1, 1).toToken()}',
          'resource': procResource('cylnder'),
        }),
        throwsA(anything),
      );
      expect(d3ExtensionResources(doc), isEmpty);
    });
  });

  group('4122294474 — extension resources survive prefab composition', () {
    final prefabGeo = const LocalId(7, 1);
    final prefabNode = const LocalId(7, 2);
    final prefabRef = AssetRef('prefabs/tube.fscene');

    SceneDocument prefab() => docWithExtension(prefabGeo, prefabNode, 'tube');

    test('upstream composeScene alone loses them (the reported bug)', () {
      final host = SceneDocument();
      host.createNode(root: true).instance = PrefabInstanceSpec(
        source: prefabRef,
      );
      final out = composeScene(host, resolve: (_) => prefab());
      final inst = out.nodes.values.firstWhere((n) => n.components.isNotEmpty);
      expect(out.resources, isNot(contains(meshGeometry(inst))));
      expect(d3ExtensionResources(out), isEmpty);
    });

    test('an eager prefab carries its extension resource, remapped', () {
      final host = docWithExtension(
        const LocalId(1, 10),
        const LocalId(1, 11),
        'ribbon',
      );
      final instance = host.createNode(root: true)
        ..instance = PrefabInstanceSpec(source: prefabRef);
      final source = prefab();
      final out = composeSceneWithExtensions(host, resolve: (_) => source);

      final ext = d3ExtensionResources(out);
      // Host's own extension resource keeps its id.
      expect(ext[const LocalId(1, 10)], procResource('ribbon'));
      // The prefab's lands under the id the composed mesh references.
      final geo = meshGeometry(out.nodes[instance.id]!);
      expect(geo, isNot(prefabGeo)); // remapped like any prefab resource
      expect(ext[geo], procResource('tube'));
      // No placeholder leaks into the composed or source documents.
      expect(out.resources, isEmpty);
      expect(source.resources, isEmpty);
      expect(host.resources, isEmpty);
      expect(d3ExtensionResources(source), contains(prefabGeo));
      // The wire manifest carries it.
      final wire =
          jsonDecode(writeFsceneWithExtensions(out)) as Map<String, dynamic>;
      final wireGeo = (wire['resources'] as Map)['geo:${geo.toToken()}'] as Map;
      expect((wireGeo['procedural'] as Map)['shape'], 'tube');
    });

    test('async composition behaves the same', () async {
      final host = SceneDocument();
      final instance = host.createNode(root: true)
        ..instance = PrefabInstanceSpec(source: prefabRef);
      final out = await composeSceneAsyncWithExtensions(
        host,
        load: (_) async => prefab(),
      );
      final geo = meshGeometry(out.nodes[instance.id]!);
      expect(d3ExtensionResources(out)[geo], procResource('tube'));
      expect(out.resources, isEmpty);
    });

    test('a streamed subtree upserts the extension resource', () {
      final host = SceneDocument();
      final placeholder = host.createNode(root: true)
        ..instance = PrefabInstanceSpec(
          source: prefabRef,
          load: LoadPolicy.lazy,
        );
      final result = encodeSubtreeLoad(
        placeholder,
        resolve: (_) => prefab(),
        hostDoc: host,
      );
      final upserts = [
        for (final op in result.ops)
          if (op['op'] == 'upsertResource') op,
      ];
      expect(upserts, hasLength(1));
      expect(upserts.single['resource'], procResource('tube'));
      final update = result.ops.firstWhere((op) => op['op'] == 'updateNode');
      final comps = (update['spec']! as Map)['components'] as List;
      expect(jsonEncode(comps), contains(upserts.single['id'] as String));
    });
  });

  group('4122712642 — concurrent composes share a cached prefab', () {
    test('both outputs carry the real extension resource', () async {
      // Call A loads the shared prefab P early, then waits on Q; call B
      // loads P while A still holds it. Any per-document mutation by A
      // is visible to B at that moment.
      final cached = docWithExtension(
        const LocalId(9, 1),
        const LocalId(9, 2),
        'tube',
      );
      final other = docWithExtension(
        const LocalId(8, 1),
        const LocalId(8, 2),
        'capsule',
      );
      AsyncPrefabLoader loader(Map<String, int> delays) => (ref) async {
        await Future<void>.delayed(Duration(milliseconds: delays[ref.key]!));
        return ref.key == 'p' ? cached : other;
      };

      SceneDocument host(String shape, List<String> refs) {
        final h = docWithExtension(
          const LocalId(1, 20),
          const LocalId(1, 21),
          shape,
        );
        for (final r in refs) {
          h.createNode(root: true).instance = PrefabInstanceSpec(
            source: AssetRef(r),
          );
        }
        return h;
      }

      final results = await Future.wait([
        composeSceneAsyncWithExtensions(
          host('ribbon', ['q', 'p']),
          load: loader({'p': 5, 'q': 60}),
        ),
        composeSceneAsyncWithExtensions(
          host('disc', ['p']),
          load: loader({'p': 25}),
        ),
      ]);
      for (final out in results) {
        expect(out.resources, isEmpty, reason: 'no sentinel may leak');
        final shapes = [
          for (final e in d3ExtensionResources(out).values)
            (e['procedural']! as Map)['shape'],
        ];
        expect(shapes, contains('tube'));
      }
      expect(cached.resources, isEmpty);
      expect(d3ExtensionResources(cached).keys, [const LocalId(9, 1)]);
    });

    test('a document without eager instances is returned as is', () {
      final doc = docWithExtension(
        const LocalId(1, 30),
        const LocalId(1, 31),
        'tube',
      );
      final out = composeSceneWithExtensions(
        doc,
        resolve: (_) => throw StateError('no prefab'),
      );
      expect(identical(out, doc), isTrue);
      expect(doc.resources, isEmpty);
    });
  });

  group('4122294480 — singular transforms keep usable normals', () {
    D3MeshData transformed(Matrix4 m, Vector3 n) {
      final b = D3MeshBuilder()
        ..emit(Vector3(0, 0, 0), n: n)
        ..emit(Vector3(1, 0, 0), n: n)
        ..emit(Vector3(0, 1, 0), n: n)
        ..tri(0, 1, 2)
        ..transform(m);
      return b.build();
    }

    Vector3 normal0(D3MeshData m) =>
        Vector3(m.normals[0], m.normals[1], m.normals[2]);

    test('diag(1,1,0) on an XY triangle keeps (0,0,1)', () {
      final m = transformed(Matrix4.diagonal3Values(1, 1, 0), Vector3(0, 0, 1));
      expect(normal0(m).distanceTo(Vector3(0, 0, 1)), closeTo(0, 1e-9));
    });

    test('a rotated flattening rotates the surviving normal', () {
      final rot = Matrix4.rotationX(math90);
      final m = transformed(
        rot * Matrix4.diagonal3Values(1, 1, 0),
        Vector3(0, 0, 1),
      );
      // Rx(90°) takes +Z to −Y.
      expect(normal0(m).distanceTo(Vector3(0, -1, 0)), closeTo(0, 1e-6));
    });

    test('rank-1 collapse falls back to the source normal', () {
      final m = transformed(Matrix4.diagonal3Values(1, 0, 0), Vector3(0, 0, 1));
      expect(normal0(m).length, closeTo(1, 1e-9));
      expect(normal0(m).distanceTo(Vector3(0, 0, 1)), closeTo(0, 1e-9));
    });

    test('invertible transforms are unchanged (inverse-transpose)', () {
      final m = transformed(
        Matrix4.diagonal3Values(-2, 1, 1),
        Vector3(1, 1, 0).normalized(),
      );
      expect(
        normal0(m).distanceTo(Vector3(-1, 2, 0).normalized()),
        closeTo(0, 1e-6),
      );
    });
  });
}

const math90 = 1.5707963267948966;
