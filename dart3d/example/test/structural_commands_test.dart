// W5 structural-command checks: the SceneDiff → command-op bridge in
// diff_apply.dart — canonical op order, per-op shapes, and the
// resource/payload re-diff — pinned by
// docs/structural-commands-spec.md. Same constraint as the W3/W4
// tests: package:dart3d/dart3d.dart is unreachable under `dart test`
// (the barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly. `SceneController.applyDiff` is out of reach for the same
// reason — it is a thin wrapper that forwards diffCommands' output to
// applyCommands, so diffCommands is what these assertions exercise.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Deterministic ids — explicit (session, index) pairs, so tokens are
  // stable across the two documents and the expected op shapes can
  // name them exactly.
  const vertsId = LocalId(1, 0);
  const idxId = LocalId(1, 1);
  const imgId = LocalId(1, 2);
  const lateId = LocalId(1, 3);
  const quadGeoId = LocalId(1, 10);
  const boxGeoId = LocalId(1, 11);
  const addedGeoId = LocalId(2, 12);
  const matId = LocalId(1, 20);
  const mat2Id = LocalId(1, 21);
  const texId = LocalId(1, 22);
  const quadId = LocalId(1, 30);
  const moverId = LocalId(1, 31);
  const parentId = LocalId(1, 32);
  const childId = LocalId(1, 33);
  const dimId = LocalId(1, 34);
  const addedId = LocalId(2, 40);
  const addedRootId = LocalId(2, 41);

  final positions = [
    Vector3(-0.5, 0, -0.5),
    Vector3(0.5, 0, -0.5),
    Vector3(0.5, 0, 0.5),
    Vector3(-0.5, 0, 0.5),
  ];
  final verts = VertexPack.unskinned(positions: positions);
  final morphedVerts = VertexPack.unskinned(
    positions: [for (final p in positions) p + Vector3(0, 0.1, 0)],
  );
  final indices = Uint16List.fromList(const [
    0,
    2,
    1,
    0,
    3,
    2,
  ]).buffer.asUint8List();
  final img = Uint8List(2 * 2 * 4);
  final bounds = BoundsSpec(
    min: Vector3(-0.5, 0, -0.5),
    max: Vector3(0.5, 0, 0.5),
  );

  ComponentSpec mesh(LocalId geo, LocalId mat) => ComponentSpec(
    'mesh',
    properties: {
      'geometry': ResourceRefValue(geo),
      'material': ResourceRefValue(mat),
    },
  );

  /// v1: a shared payload quad + a procedural box, two materials, a
  /// texture, a parent/child subtree that v2 removes, and a
  /// manifest-only payload that v2 fills.
  SceneDocument doc1() {
    final doc = SceneDocument();
    doc.addPayload(
      PayloadSpec(
        vertsId,
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: verts.lengthInBytes,
        bytes: verts,
      ),
    );
    doc.addPayload(
      PayloadSpec(
        idxId,
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: indices.lengthInBytes,
        bytes: indices,
      ),
    );
    doc.addPayload(
      PayloadSpec(
        imgId,
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: 2,
        height: 2,
        length: img.lengthInBytes,
        bytes: img,
      ),
    );
    doc.addPayload(
      PayloadSpec(
        lateId,
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: verts.lengthInBytes,
      ),
    );
    doc.addResource(
      GeometryResource(
        quadGeoId,
        vertices: vertsId,
        indices: idxId,
        bounds: bounds,
      ),
    );
    doc.addResource(
      GeometryResource(
        boxGeoId,
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.5)),
      ),
    );
    doc.addResource(
      MaterialResource(
        matId,
        type: 'physicallyBased',
        properties: {'baseColor': ColorValue(0.9, 0.1, 0.1, 1.0)},
      ),
    );
    doc.addResource(
      MaterialResource(
        mat2Id,
        type: 'physicallyBased',
        properties: {'baseColor': ColorValue(0.1, 0.1, 0.9, 1.0)},
      ),
    );
    doc.addResource(TextureResource(texId, payload: imgId));
    doc.addNode(
      NodeSpec(
        id: quadId,
        name: 'quad',
        transform: TrsTransform(),
        components: [mesh(quadGeoId, matId)],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: moverId,
        name: 'mover',
        transform: TrsTransform(),
        components: [mesh(boxGeoId, mat2Id)],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: parentId,
        name: 'parent',
        transform: TrsTransform(),
        children: [childId],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(id: childId, name: 'child', transform: TrsTransform()),
    );
    doc.addNode(
      NodeSpec(id: dimId, name: 'dim', transform: TrsTransform()),
      root: true,
    );
    return doc;
  }

  /// v2: same ids, mutated — the parent subtree is gone, `mover` is
  /// moved and reparented under `quad`, `dim` hides, the vertex chunk
  /// and the box/material specs changed, and two nodes are new.
  SceneDocument doc2() {
    final doc = SceneDocument();
    doc.addPayload(
      PayloadSpec(
        vertsId,
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: morphedVerts.lengthInBytes,
        bytes: morphedVerts,
      ),
    );
    doc.addPayload(
      PayloadSpec(
        idxId,
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: indices.lengthInBytes,
        bytes: indices,
      ),
    );
    doc.addPayload(
      PayloadSpec(
        imgId,
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: 2,
        height: 2,
        length: img.lengthInBytes,
        bytes: img,
      ),
    );
    // Bytes arrive where v1's manifest entry had none — the spec's
    // "arrive where old was null" upsertPayload case.
    doc.addPayload(
      PayloadSpec(
        lateId,
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: verts.lengthInBytes,
        bytes: verts,
      ),
    );
    doc.addResource(
      GeometryResource(
        quadGeoId,
        vertices: vertsId,
        indices: idxId,
        bounds: bounds,
      ),
    );
    doc.addResource(
      GeometryResource(
        boxGeoId,
        procedural: CuboidGeometrySpec(extents: Vector3.all(1.5)),
      ),
    );
    doc.addResource(
      MaterialResource(
        matId,
        type: 'physicallyBased',
        properties: {'baseColor': ColorValue(0.2, 0.9, 0.3, 1.0)},
      ),
    );
    doc.addResource(
      MaterialResource(
        mat2Id,
        type: 'physicallyBased',
        properties: {'baseColor': ColorValue(0.1, 0.1, 0.9, 1.0)},
      ),
    );
    doc.addResource(TextureResource(texId, payload: imgId));
    doc.addResource(
      GeometryResource(addedGeoId, procedural: SphereGeometrySpec(radius: 0.3)),
    );
    doc.addNode(
      NodeSpec(
        id: quadId,
        name: 'quad',
        transform: TrsTransform(),
        children: [addedId, moverId],
        components: [mesh(quadGeoId, matId)],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: moverId,
        name: 'mover',
        transform: TrsTransform(translation: Vector3(1, 0, 0)),
        components: [mesh(boxGeoId, mat2Id)],
      ),
    );
    final dim = NodeSpec(id: dimId, name: 'dim', transform: TrsTransform());
    dim.visible = false;
    doc.addNode(dim, root: true);
    doc.addNode(
      NodeSpec(
        id: addedId,
        name: 'added',
        transform: TrsTransform(translation: Vector3(0, 1, 0)),
        components: [mesh(addedGeoId, mat2Id)],
      ),
    );
    doc.addNode(
      NodeSpec(id: addedRootId, name: 'addedRoot', transform: TrsTransform()),
      root: true,
    );
    return doc;
  }

  List<Map<String, Object?>> opsFor(SceneDocument a, SceneDocument b) =>
      diffCommands(diffScene(a, b), a, b);

  group('canonical op order', () {
    test('removeNode → upsertPayload → upsertResource → addNode → '
        'updateNode, contiguous and in batch order', () {
      final ops = opsFor(doc1(), doc2());
      const order = {
        'removeNode': 0,
        'upsertPayload': 1,
        'upsertResource': 2,
        'addNode': 3,
        'updateNode': 4,
      };
      var phase = -1;
      final seen = <String>{};
      for (final op in ops) {
        final name = op['op'] as String;
        final rank = order[name]!;
        expect(
          rank,
          greaterThanOrEqualTo(phase),
          reason: '$name out of canonical order in $ops',
        );
        phase = rank;
        seen.add(name);
      }
      expect(seen, containsAll(order.keys));
    });

    test('the full batch, in order', () {
      final ops = opsFor(doc1(), doc2());
      expect(ops, hasLength(13));
      expect(
        [for (final o in ops) o['op']],
        [
          'removeNode',
          'removeNode',
          'upsertPayload',
          'upsertPayload',
          'upsertResource',
          'upsertResource',
          'upsertResource',
          'upsertResource',
          'addNode',
          'addNode',
          'updateNode',
          'updateNode',
          'updateNode',
        ],
      );
    });
  });

  group('node ops', () {
    test('removeNode carries the removed node token', () {
      final ops = opsFor(doc1(), doc2());
      final removes = [
        for (final o in ops)
          if (o['op'] == 'removeNode') o['node'],
      ];
      expect(removes, [parentId.toToken(), childId.toToken()]);
    });

    test('addNode carries node token, parent, and manifest-shape spec', () {
      final ops = opsFor(doc1(), doc2());
      final adds = [
        for (final o in ops)
          if (o['op'] == 'addNode') o,
      ];
      expect(adds, hasLength(2));

      final child = adds[0];
      expect(child['node'], addedId.toToken());
      expect(child['parent'], quadId.toToken());
      final spec = child['spec'] as Map<String, Object?>;
      expect(spec['name'], 'added');
      expect(spec['transform'], {
        'trs': {
          't': [0.0, 1.0, 0.0],
          'r': [0.0, 0.0, 0.0, 1.0],
          's': [1.0, 1.0, 1.0],
        },
      });
      final components = spec['components'] as List;
      expect(components, hasLength(1));
      expect(components[0], {
        'type': 'mesh',
        'properties': {
          'geometry': {'rref': 'geo:${addedGeoId.toToken()}'},
          'material': {'rref': 'mat:${mat2Id.toToken()}'},
        },
      });

      // A root add carries the parent key explicitly null.
      final root = adds[1];
      expect(root['node'], addedRootId.toToken());
      expect(root.containsKey('parent'), isTrue);
      expect(root['parent'], isNull);
    });

    test('updateNode carries flags + spec; reparented reads parent', () {
      final ops = opsFor(doc1(), doc2());
      final updates = {
        for (final o in ops)
          if (o['op'] == 'updateNode') o['node'] as String: o,
      };
      expect(updates.keys, {
        quadId.toToken(),
        moverId.toToken(),
        dimId.toToken(),
      });

      final quad = updates[quadId.toToken()]!;
      expect(quad['flags'], ['components']);
      expect(quad.containsKey('parent'), isFalse);
      final quadSpec = quad['spec'] as Map<String, Object?>;
      // Children ride in the spec only — the adds attach themselves.
      expect(quadSpec['children'], [
        'n:${addedId.toToken()}',
        'n:${moverId.toToken()}',
      ]);

      final mover = updates[moverId.toToken()]!;
      expect(mover['flags'], ['transform', 'reparented', 'components']);
      expect(mover['parent'], quadId.toToken());
      expect((mover['spec'] as Map)['transform'], {
        'trs': {
          't': [1.0, 0.0, 0.0],
          'r': [0.0, 0.0, 0.0, 1.0],
          's': [1.0, 1.0, 1.0],
        },
      });

      final dim = updates[dimId.toToken()]!;
      expect(dim['flags'], ['visible']);
      expect((dim['spec'] as Map)['visible'], isFalse);
    });

    test('a skin-only NodeChange emits an updateNode with the skin '
        'flag and no parent', () {
      final diff = SceneDiff(
        added: const [],
        removed: const [],
        changed: [NodeChange(moverId, skin: true)],
      );
      final ops = diffCommands(diff, doc1(), doc2());
      final stale = [
        for (final o in ops)
          if (o['op'] == 'updateNode' && o['node'] == moverId.toToken()) o,
      ];
      expect(stale, hasLength(1));
      expect(stale.single['flags'], ['skin']);
      // mover has no skin member — the re-decode unbinds.
      expect(
        (stale.single['spec'] as Map).containsKey('skin'),
        isFalse,
      );
      expect(stale.single.containsKey('parent'), isFalse);
      // The batch is not suppressed — resource/payload re-diffs still
      // emit their ops.
      expect([
        for (final o in ops) o['op'],
      ], containsAll(['upsertPayload', 'upsertResource']));
    });
  });

  group('resource and payload re-diff', () {
    test('a geometry spec change produces upsertResource', () {
      final ops = opsFor(doc1(), doc2());
      final upserts = {
        for (final o in ops)
          if (o['op'] == 'upsertResource') o['id'] as String: o,
      };
      expect(upserts.keys, {
        'geo:${quadGeoId.toToken()}',
        'geo:${boxGeoId.toToken()}',
        'mat:${matId.toToken()}',
        'geo:${addedGeoId.toToken()}',
      });
      final box = upserts['geo:${boxGeoId.toToken()}']!;
      final res = box['resource'] as Map<String, Object?>;
      expect(res['kind'], 'geometry');
      expect(res['procedural'], isA<Map>());
      // The material re-encodes its property bag in the same tagged
      // form the manifest uses.
      final mat = upserts['mat:${matId.toToken()}']!;
      expect((mat['resource'] as Map)['properties'], {
        'baseColor': {
          'c': [0.2, 0.9, 0.3, 1.0],
        },
      });
      // The changed quad geometry re-encodes its payload refs with
      // chunk: tokens.
      final quadGeo = upserts['geo:${quadGeoId.toToken()}']!;
      expect(
        (quadGeo['resource'] as Map)['vertices'],
        'chunk:${vertsId.toToken()}',
      );
    });

    test('a payload byte change produces upsertPayload with base64', () {
      final ops = opsFor(doc1(), doc2());
      final payloads = {
        for (final o in ops)
          if (o['op'] == 'upsertPayload') o['id'] as String: o,
      };
      expect(payloads.keys, {
        'chunk:${vertsId.toToken()}',
        'chunk:${lateId.toToken()}',
      });
      expect(
        base64Decode(
          payloads['chunk:${vertsId.toToken()}']!['bytes']! as String,
        ),
        morphedVerts,
      );
      expect(
        base64Decode(
          payloads['chunk:${lateId.toToken()}']!['bytes']! as String,
        ),
        verts,
      );
      // Unchanged payloads emit nothing — no idx or img upsert.
      expect(payloads.keys, isNot(contains('chunk:${idxId.toToken()}')));
      expect(payloads.keys, isNot(contains('chunk:${imgId.toToken()}')));
    });

    test('upsertPayload carries the chunk spec for runtime-minted '
        'payloads', () {
      final ops = opsFor(doc1(), doc2());
      final late = ops.firstWhere(
        (o) => o['id'] == 'chunk:${lateId.toToken()}',
      );
      // Natives register these into their payload-spec table — the
      // manifest's payloads block only covers install-time chunks, so
      // without them a runtime-minted chunk's consumers never decode.
      expect(late['encoding'], 'vertexBuffer');
      expect(late['layout'], 'unskinned_uv1_tangent');
      expect(late['length'], verts.lengthInBytes);
      expect(late.containsKey('format'), isFalse);
    });

    test('an unchanged texture/payload pair emits no ops', () {
      final ops = opsFor(doc1(), doc2());
      final texOps = [
        for (final o in ops)
          if (o['id'] == 'tex:${texId.toToken()}') o,
      ];
      expect(texOps, isEmpty);
    });
  });

  group('spec fidelity', () {
    test('encodeNodeCommandSpec output equals the manifest node entry', () {
      final doc = doc2();
      final manifest = jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
      final nodes = manifest['nodes'] as Map<String, dynamic>;
      for (final id in [quadId, moverId, addedId, dimId]) {
        final entry = nodes['n:${id.toToken()}'];
        expect(entry, isNotNull, reason: 'missing manifest node for $id');
        expect(
          encodeNodeCommandSpec(doc.nodes[id]!, doc),
          entry,
          reason: 'spec for ${id.toToken()} diverges from the manifest',
        );
      }
    });
  });

  group('edge cases', () {
    test('an empty diff emits an empty batch', () {
      expect(diffScene(doc1(), doc1()).isEmpty, isTrue);
      expect(opsFor(doc1(), doc1()), isEmpty);
    });

    test('every op survives the commandBytes JSON round-trip', () {
      final ops = opsFor(doc1(), doc2());
      final decoded = [
        for (final op in ops)
          jsonDecode(utf8.decode(D3Protocol.commandBytes(op)))
              as Map<String, dynamic>,
      ];
      expect(decoded, hasLength(ops.length));
      for (final op in decoded) {
        expect(op['op'], isA<String>());
      }
      // Node id tokens parse back through the last-colon strip, same
      // as the native D3Wire.localIdKey decoder.
      final addOp = decoded.firstWhere((o) => o['op'] == 'addNode');
      expect(LocalId.parse(addOp['node'] as String), addedId);
      expect(LocalId.parse(addOp['parent'] as String), quadId);
    });
  });
}
