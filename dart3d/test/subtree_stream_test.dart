// W15 subtree-streaming checks: the loadSubtree/unloadSubtree op
// encoders in subtree_stream.dart — the placeholder tag on the wire,
// upstream compose fidelity inside the emitted batch, the unload
// reversal, and the diff bridge carrying `instance` — pinned by the
// W15 section of protocol.dart's op table. Same constraint as the W5
// tests: package:dart3d/dart3d.dart is unreachable under `dart test`
// (the barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly. `SceneController.loadSubtree` is a thin wrapper that
// forwards encodeSubtreeLoad's batch inside the envelope op, so the
// encoders are what these assertions exercise.
// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/subtree_stream.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Deterministic ids — explicit (session, index) pairs, so the
  // composed members' remapped tokens are stable across assertions.
  const instId = LocalId(9, 1);
  const beaconId = LocalId(9, 2);
  const rootId = LocalId(7, 1);
  const aId = LocalId(7, 2);
  const bId = LocalId(7, 3);
  const cId = LocalId(7, 4);
  const geoId = LocalId(7, 20);
  const matId = LocalId(7, 21);
  const hostMatId = LocalId(9, 20);
  const lazyInnerId = LocalId(7, 5);
  const ibmId = LocalId(7, 30);
  const skinId = LocalId(7, 40);
  const animId = LocalId(7, 41);

  ComponentSpec mesh(LocalId geo, LocalId mat) => ComponentSpec(
    'mesh',
    properties: {
      'geometry': ResourceRefValue(geo),
      'material': ResourceRefValue(mat),
    },
  );

  /// A small prefab: root container (mesh + a `marker` component the
  /// removedComponentTypes lane strips) with children `a` (which
  /// carries the lazy nested instance `inner` under it) and `b`
  /// (whose subtree is one child `c`). The instance delta exercises
  /// every upstream field: an override on `a`, a memberComponent on
  /// `a`, `b` removed, a light added on the instance root, `marker`
  /// stripped from it, and the host `beacon` grafted under `a`.
  ({SceneDocument prefab, SceneDocument host}) docs() {
    final prefab = SceneDocument();
    prefab.addResource(
      GeometryResource(
        geoId,
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.2)),
      ),
    );
    prefab.addResource(
      MaterialResource(
        matId,
        type: 'physicallyBased',
        properties: {'baseColor': ColorValue(0.2, 0.45, 0.95, 1.0)},
      ),
    );
    final inner = prefab.addNode(
      NodeSpec(
        id: lazyInnerId,
        name: 'inner',
        instance: PrefabInstanceSpec(
          source: const AssetRef('nested'),
          load: LoadPolicy.lazy,
        ),
      ),
    );
    final a = prefab.addNode(
      NodeSpec(
        id: aId,
        name: 'a',
        transform: TrsTransform(translation: Vector3(1, 0, 0)),
        children: [inner.id],
        components: [mesh(geoId, matId)],
      ),
    );
    final c = prefab.addNode(
      NodeSpec(
        id: cId,
        name: 'c',
        transform: TrsTransform(translation: Vector3(0, 0.2, 0)),
        components: [mesh(geoId, matId)],
      ),
    );
    final b = prefab.addNode(
      NodeSpec(
        id: bId,
        name: 'b',
        transform: TrsTransform(translation: Vector3(-1, 0, 0)),
        children: [c.id],
        components: [mesh(geoId, matId)],
      ),
    );
    prefab.addNode(
      NodeSpec(
        id: rootId,
        name: 'root',
        children: [a.id, b.id],
        components: [
          mesh(geoId, matId),
          ComponentSpec('marker', properties: {'note': StringValue('x')}),
        ],
      ),
      root: true,
    );
    // A skin + animation pool entry — the unload reversal must
    // retract what the load upserts.
    prefab.addPayload(
      PayloadSpec(
        ibmId,
        encoding: PayloadEncoding.floats,
        length: 64,
        bytes: Uint8List(64),
      ),
    );
    prefab.addSkin(SkinSpec(skinId, joints: [aId], inverseBindMatrices: ibmId));
    prefab.addAnimation(
      AnimationSpec(
        animId,
        name: 'spin',
        channels: [
          AnimationChannelSpec(
            target: aId,
            property: AnimationProperty.rotation,
            timeline: ibmId,
            keyframes: ibmId,
          ),
        ],
      ),
    );

    final host = SceneDocument();
    host.addResource(
      MaterialResource(
        hostMatId,
        type: 'physicallyBased',
        properties: {'baseColor': ColorValue(0.9, 0.2, 0.2, 1.0)},
      ),
    );
    final beacon = host.addNode(
      NodeSpec(
        id: beaconId,
        name: 'beacon',
        transform: TrsTransform(translation: Vector3(0, 0.5, 0)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(geoId),
              'material': ResourceRefValue(hostMatId),
            },
          ),
        ],
      ),
      root: true,
    );
    final inst = host.addNode(
      NodeSpec(
        id: instId,
        name: 'inst',
        transform: TrsTransform(translation: Vector3(4, 0, 4)),
        instance: PrefabInstanceSpec(
          source: const AssetRef('grid'),
          load: LoadPolicy.lazy,
          overrides: [
            PropertyOverride(
              target: aId,
              path: 'transform.trs.t',
              value: Vec3Value(Vector3(2, 0, 0)),
            ),
          ],
          attachments: [Attachment(beacon.id, parent: aId)],
          removedNodes: [bId],
          addedComponents: [
            ComponentSpec(
              'pointLight',
              properties: {'intensity': DoubleValue(40)},
            ),
          ],
          removedComponentTypes: ['marker'],
          memberComponents: [
            MemberComponent(
              member: aId,
              component: ComponentSpec(
                'pointLight',
                properties: {'intensity': DoubleValue(5)},
              ),
            ),
          ],
        ),
      ),
      root: true,
    );
    expect(beacon.id, beaconId);
    expect(inst.id, instId);
    return (prefab: prefab, host: host);
  }

  SceneDocument resolve(AssetRef ref) {
    final d = docs();
    return switch (ref.key) {
      'grid' => d.prefab,
      'nested' => () {
        final nested = SceneDocument();
        nested.addNode(
          NodeSpec(
            id: const LocalId(5, 1),
            name: 'nestedRoot',
            components: [
              ComponentSpec(
                'pointLight',
                properties: {'intensity': DoubleValue(1)},
              ),
            ],
          ),
          root: true,
        );
        return nested;
      }(),
      _ => throw ArgumentError('unknown prefab ${ref.key}'),
    };
  }

  Map<String, Object?> opSpec(Map<String, Object?> op) =>
      (op['spec']! as Map).cast<String, Object?>();

  test('placeholder spec carries the instance member on the wire', () {
    final d = docs();
    final spec = encodeNodeCommandSpec(d.host.nodes[instId]!, d.host);
    final instance = spec['instance'] as Map?;
    expect(instance, isNotNull);
    expect(instance!['source'], 'grid');
    expect(instance['load'], 'lazy');
    // The delta fields encode in the prefab's own id space (upstream's
    // unremapped-lazy rule) — the natives record the tag, never
    // resolve it.
    expect(instance['removedNodes'], ['id:${bId.toToken()}']);
    // `node` names a host-document node (n: prefix); `parent` names a
    // prefab-local id the host doc has no prefix entry for (id:).
    expect(instance['attachments'], [
      {'node': 'n:${beaconId.toToken()}', 'parent': 'id:${aId.toToken()}'},
    ]);
    expect(instance['memberComponents'], isNotEmpty);
    expect(instance['addedComponents'], isNotEmpty);
    expect(instance['removedComponentTypes'], ['marker']);
    expect(instance['overrides'], [
      {
        'target': 'id:${aId.toToken()}',
        'path': 'transform.trs.t',
        'value': {
          'v3': [2.0, 0.0, 0.0],
        },
      },
    ]);
    // Eager omits the member's `load` field — upstream's rule.
    final eager = encodeNodeCommandSpec(
      NodeSpec(
        id: const LocalId(1, 1),
        instance: PrefabInstanceSpec(source: const AssetRef('x')),
      ),
      SceneDocument(),
    );
    expect((eager['instance']! as Map).containsKey('load'), isFalse);
  });

  test('loadSubtree emits the canonical batch', () {
    final d = docs();
    final result = encodeSubtreeLoad(
      d.host.nodes[instId]!,
      resolve: resolve,
      hostDoc: d.host,
    );
    final ops = result.ops;
    // Canonical order: resources/payloads first, then the instance's
    // own update (clears the tag), then member adds.
    final kinds = ops.map((o) => o['op']).toList();
    final firstNode = kinds.indexWhere(
      (k) => k == 'updateNode' || k == 'addNode',
    );
    expect(
      kinds
          .sublist(0, firstNode)
          .every(
            (k) =>
                k == 'upsertResource' ||
                k == 'upsertPayload' ||
                k == 'removeNode',
          ),
      isTrue,
      reason: 'resource/payload ops precede node ops: $kinds',
    );
    // The host material dedupes — only prefab resources upsert.
    final upserts = ops.where((o) => o['op'] == 'upsertResource');
    expect(upserts.length, 2); // prefab geometry + material

    // The instance's own update carries explicit `instance: null` —
    // the wire's clear-the-tag signal. An absent member would read as
    // "unchanged" natively (a reparent-only update must not strip the
    // tag).
    final instUpdate = ops.firstWhere(
      (o) => o['op'] == 'updateNode' && o['node'] == instId.toToken(),
    );
    final spec = opSpec(instUpdate);
    expect(spec.containsKey('instance'), isTrue);
    expect(spec['instance'], isNull);
    // The single-root prefab merges its root into the instance: the
    // root's mesh lands on the instance's components, plus the added
    // pointLight; the `marker` type is stripped.
    final types = [
      for (final c in spec['components']! as List) (c as Map)['type'],
    ];
    expect(types, containsAll(['mesh', 'pointLight']));
    expect(types, isNot(contains('marker')));
    // Transform merges root's (identity here — no flag needed) — the
    // flags list the fields the merge changed: components at minimum.
    expect(instUpdate['flags'], contains('components'));

    // Members: a + inner (b and its subtree removed) — `a` is a
    // streamed root under the instance, `inner` lands under `a`.
    final adds = ops.where((o) => o['op'] == 'addNode').toList();
    expect(adds.length, 2);
    // `a`'s emitted spec carries the override (t = [2,0,0] not [1,0,0])
    // and the memberComponent's added pointLight.
    final aAdd = adds.firstWhere((o) {
      final s = opSpec(o);
      return (s['name'] as String?) == 'a';
    });
    expect(aAdd['parent'], instId.toToken());
    final aSpec = opSpec(aAdd);
    expect(
      ((aSpec['transform']! as Map)['trs']! as Map)['t'],
      [2.0, 0.0, 0.0],
      reason: 'override bakes into the emitted transform',
    );
    final aTypes = [
      for (final c in aSpec['components']! as List) (c as Map)['type'],
    ];
    expect(aTypes, containsAll(['mesh', 'pointLight']));
    // The nested lazy instance streams as a tagged placeholder —
    // `instance` intact, unremapped prefab-local ids inside.
    final innerAdd = adds.firstWhere((o) {
      final s = opSpec(o);
      return (s['name'] as String?) == 'inner';
    });
    final innerSpec = opSpec(innerAdd);
    expect(innerAdd['parent'], aAdd['node']);
    expect((innerSpec['instance']! as Map)['source'], 'nested');
    expect((innerSpec['instance']! as Map)['load'], 'lazy');

    // The beacon grafts under the composed `a` via a reparent-only
    // updateNode — the same op the natives already implement.
    final reparent = ops.firstWhere(
      (o) => o['op'] == 'updateNode' && o['node'] == beaconId.toToken(),
    );
    expect(reparent['flags'], ['reparented']);
    expect(reparent['parent'], aAdd['node']);
    // The reparent spec carries no `instance` member — the counterpart
    // of the explicit-null contract: absent means preserve the tag.
    expect(opSpec(reparent).containsKey('instance'), isFalse);

    // Streamed roots = just `a` (b removed; beacon is an attachment,
    // not a root; the merged single-root prefab has no separate root).
    expect(result.streamed.roots, [LocalId.parse(aAdd['node']! as String)]);
    expect(result.streamed.attachments, [beaconId]);
    expect(result.streamed.flags, contains('components'));
  });

  test('priorRoots not re-produced get a removeNode first', () {
    final d = docs();
    const stale = LocalId(3, 99);
    const stale2 = LocalId(3, 100);
    final result = encodeSubtreeLoad(
      d.host.nodes[instId]!,
      resolve: resolve,
      hostDoc: d.host,
      priorRoots: [stale, stale2],
    );
    expect(result.ops.first, {'op': 'removeNode', 'node': stale.toToken()});
    // Every doomed root's removeNode lands before the batch's first
    // add/update — the order the native replay fix relies on: a
    // re-load can doom another stream's placeholder, and its record
    // must be dead before any member re-realizes (F1).
    final firstAdd = result.ops.indexWhere(
      (o) => o['op'] == 'addNode' || o['op'] == 'updateNode',
    );
    final removes = result.ops
        .where((o) => o['op'] == 'removeNode')
        .map((o) => o['node'])
        .toList();
    expect(removes, [stale.toToken(), stale2.toToken()]);
    expect(firstAdd, greaterThan(removes.length - 1));
  });

  test('unloadSubtree reverses the load: reparent, removes, retag', () {
    final d = docs();
    final loaded = encodeSubtreeLoad(
      d.host.nodes[instId]!,
      resolve: resolve,
      hostDoc: d.host,
    );
    final unload = encodeSubtreeUnload(
      d.host.nodes[instId]!,
      streamed: loaded.streamed,
      attachmentHomes: {beaconId: null},
      hostDoc: d.host,
    );
    // Beacon home first, roots out, restore last — a host node grafted
    // under a doomed member must leave before the removeNode lands.
    expect(unload[0]['op'], 'updateNode');
    expect(unload[0]['node'], beaconId.toToken());
    expect(unload[0]['flags'], ['reparented']);
    expect(unload[0]['parent'], isNull);
    final removes = unload.where((o) => o['op'] == 'removeNode').toList();
    expect(removes.length, 1);
    expect(removes.single['node'], loaded.streamed.roots.single.toToken());
    final restore = unload.last;
    expect(restore['op'], 'updateNode');
    expect(restore['node'], instId.toToken());
    // The placeholder spec rides the restore — `instance` back on the
    // wire is what re-tags the node for the next loadSubtree.
    final spec = opSpec(restore);
    expect((spec['instance']! as Map)['source'], 'grid');
    expect((spec['instance']! as Map)['load'], 'lazy');
    expect(restore['flags'], loaded.streamed.flags);
  });

  test('diffCommands carries the instance member on a placeholder add', () {
    final d = docs();
    final empty = SceneDocument();
    final ops = diffCommands(diffScene(empty, d.host), empty, d.host);
    final add = ops.firstWhere(
      (o) => o['op'] == 'addNode' && o['node'] == instId.toToken(),
    );
    expect((opSpec(add)['instance']! as Map)['load'], 'lazy');
  });

  test('encodeSubtreeLoad throws on a non-instance node', () {
    expect(
      () => encodeSubtreeLoad(
        NodeSpec(id: const LocalId(1, 1)),
        resolve: resolve,
      ),
      throwsArgumentError,
    );
  });

  test('load composes identically to a pre-realize composeScene', () {
    final d = docs();
    // The same instance expanded eagerly through upstream compose —
    // the streamed batch must emit exactly the nodes that compose
    // produces, modulo the placeholder/tag bookkeeping.
    final scratch = SceneDocument();
    scratch.addNode(
      NodeSpec(
        id: instId,
        name: 'inst',
        transform: TrsTransform(translation: Vector3(4, 0, 4)),
        instance: d.host.nodes[instId]!.instance!.copyWith(
          load: LoadPolicy.eager,
        ),
      ),
    );
    scratch.addNode(NodeSpec(id: beaconId));
    final composed = composeScene(scratch, resolve: resolve);
    final streamed = encodeSubtreeLoad(
      d.host.nodes[instId]!,
      resolve: resolve,
      hostDoc: d.host,
    );
    final addedIds = {
      for (final o in streamed.ops)
        if (o['op'] == 'addNode') o['node'] as String,
    };
    // Every node REACHABLE under the composed instance lands as an
    // addNode — removedNodes' orphaned subtrees stay in the document
    // (upstream's dead-weight outcome) and never realize.
    final reachable = <LocalId>{};
    final stack = [...composed.nodes[instId]!.children];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!reachable.add(id) || id == beaconId) continue;
      stack.addAll(composed.nodes[id]!.children);
    }
    reachable.remove(beaconId);
    expect(
      addedIds,
      {for (final id in reachable) id.toToken()},
      reason: 'streamed adds must match the reachable composed members',
    );
  });

  test('loadSubtree throws when removedNodes deletes the merged root', () {
    final d = docs();
    final inst = d.host.nodes[instId]!;
    // The prefab's single root merges into the instance node — a
    // removedNodes entry naming it deletes the merged node upstream,
    // leaving nothing to stream. The encoder rejects it rather than
    // null-crashing on the absent composed node.
    final doomed = NodeSpec(
      id: inst.id,
      name: inst.name,
      transform: inst.transform,
      instance: inst.instance!.copyWith(removedNodes: [rootId]),
    );
    expect(
      () => encodeSubtreeLoad(doomed, resolve: resolve, hostDoc: d.host),
      throwsArgumentError,
    );
  });

  test('unloadSubtree retracts the skins and animations it added', () {
    final d = docs();
    final loaded = encodeSubtreeLoad(
      d.host.nodes[instId]!,
      resolve: resolve,
      hostDoc: d.host,
    );
    // The stream upserts the prefab's skin/animation pools under
    // their per-instance composed ids, and the record keeps them.
    expect(loaded.streamed.skins, isNotEmpty);
    expect(loaded.streamed.animations, isNotEmpty);
    expect(
      loaded.ops.where((o) => o['op'] == 'upsertSkin').map((o) => o['id']),
      [for (final s in loaded.streamed.skins) 'skin:${s.toToken()}'],
    );
    expect(
      loaded.ops.where((o) => o['op'] == 'upsertAnimation').map((o) => o['id']),
      [for (final a in loaded.streamed.animations) 'anim:${a.toToken()}'],
    );
    final unload = encodeSubtreeUnload(
      d.host.nodes[instId]!,
      streamed: loaded.streamed,
      attachmentHomes: {beaconId: null},
      hostDoc: d.host,
    );
    // Dependents detach before the nodes they reference — the
    // canonical remove order: reparents out, skin/clip removes, then
    // the streamed roots' removeNode.
    final kinds = unload.map((o) => o['op']).toList();
    expect(kinds.first, 'updateNode');
    final firstRemoveNode = kinds.indexOf('removeNode');
    expect(
      kinds.sublist(1, firstRemoveNode),
      everyElement(isIn(['removeSkin', 'removeAnimation'])),
    );
    expect(unload.where((o) => o['op'] == 'removeSkin').map((o) => o['id']), [
      for (final s in loaded.streamed.skins) 'skin:${s.toToken()}',
    ]);
    expect(
      unload.where((o) => o['op'] == 'removeAnimation').map((o) => o['id']),
      [for (final a in loaded.streamed.animations) 'anim:${a.toToken()}'],
    );
  });

  test('nested lazy placeholders resolve through the stream record', () {
    final d = docs();
    final loaded = encodeSubtreeLoad(
      d.host.nodes[instId]!,
      resolve: resolve,
      hostDoc: d.host,
    );
    final innerAdd = loaded.ops.firstWhere((o) {
      return o['op'] == 'addNode' && opSpec(o)['name'] == 'inner';
    });
    final innerId = LocalId.parse(innerAdd['node']! as String);
    // Streamed members never join the tracked document — the record's
    // placeholders map is what the public loadSubtree resolves them
    // through. The recorded spec is the emitted addNode's: `instance`
    // intact, prefab-local id space.
    final nested = loaded.streamed.placeholders[innerId];
    expect(nested, isNotNull);
    expect(nested!.instance!.source.key, 'nested');
    expect(nested.instance!.load, LoadPolicy.lazy);
    // The recorded spec feeds encodeSubtreeLoad directly — the same
    // call SceneController.loadSubtree makes on the resolved node.
    final inner = encodeSubtreeLoad(nested, resolve: resolve);
    final innerUpdate = inner.ops.firstWhere(
      (o) => o['op'] == 'updateNode' && o['node'] == innerId.toToken(),
    );
    expect(opSpec(innerUpdate).containsKey('instance'), isTrue);
    expect(opSpec(innerUpdate)['instance'], isNull);
  });
}
