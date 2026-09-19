/// W15 prefab subtree streaming — the `loadSubtree`/`unloadSubtree`
/// op encoders.
///
/// A node whose spec carries an `instance` member is a lazy prefab
/// placeholder: it arrives in the manifest or an `addNode` as a
/// tagged, contentless node, and the natives record the tag (see
/// `docs/structural-commands-spec.md`). [encodeSubtreeLoad] expands
/// one placeholder's subtree through upstream `composeScene` — the
/// same expansion `loadScene` performs for eager instances, run at
/// stream-in time — and emits the composed content as the standard
/// command batch (`updateNode` on the instance, `upsertPayload`/
/// `upsertResource`, `addNode` per member, `updateNode` reparents for
/// attachments, `upsertSkin`/`upsertAnimation`), so the subtree lands
/// through the exact decode paths a diff uses. The instance node's
/// own update re-specs it without `instance`, which is what clears
/// the placeholder tag natively. [encodeSubtreeUnload] emits the
/// reverse batch: attachment reparents home first (so grafted host
/// nodes leave the doomed subtree), then `removeSkin`/
/// `removeAnimation` for the pools the stream upserted and
/// `removeNode` per streamed root, then a restore `updateNode`
/// carrying the placeholder spec — `instance` member back on the
/// wire — which re-tags the node.
///
/// Compose runs on a scratch document holding a copy of the instance
/// node with `load` flipped to eager — upstream only expands eager
/// instances, and the copy keeps compose's in-place mutations
/// (transform merge, component graft, `instance = null`) out of the
/// tracked document. Per-instance node/skin/animation ids derive from
/// (instance id, prefab-local id) and resource/payload ids from the
/// prefab's document identity, exactly as a pre-realize compose
/// produces — a subtree streamed through these ops is
/// indistinguishable on the wire from one that arrived expanded.
///
/// `removedNodes`, `overrides`, `memberComponents`, `addedComponents`,
/// `removedComponentTypes`, and `attachments` are upstream
/// `composeScene` semantics, not reimplemented ones — the encoders
/// only translate the composed result into ops. A nested lazy
/// instance inside a streamed prefab keeps its `instance` member on
/// its `addNode` spec (upstream's unremapped-id-space rule), arriving
/// as a placeholder a later `loadSubtree` resolves — the stream
/// record's [StreamedSubtree.placeholders] makes those members
/// reachable through the public API even though streamed nodes never
/// join the tracked document.
///
/// Two persistence lines are deliberate: the unload emits
/// `removeSkin`/`removeAnimation` for the pools the stream upserted,
/// but payloads and resources stay — shared ids derive from the
/// prefab's document identity, so the host document and sibling
/// instances may legitimately consume them, and the op vocabulary
/// has no `removePayload`/`removeResource` to retract them anyway.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'diff_apply.dart';
import 'scene_model.dart';

/// What one [encodeSubtreeLoad] created — the bookkeeping
/// [encodeSubtreeUnload] needs to reverse exactly that stream-in:
/// which child ids were grafted under the instance node, which host
/// nodes were reparented into the subtree, which skin/animation ids
/// the batch upserted, which nested lazy placeholders the subtree
/// carries, and which instance-node fields the merge changed (the
/// restore update's flag set).
final class StreamedSubtree {
  /// Creates a stream record.
  const StreamedSubtree({
    required this.roots,
    required this.attachments,
    required this.flags,
    this.skins = const [],
    this.animations = const [],
    this.placeholders = const {},
  });

  /// The composed child ids attached directly under the instance
  /// node — each is the root of one streamed subtree; `removeNode`
  /// per entry on unload drops everything the stream added.
  final List<LocalId> roots;

  /// Host node ids the stream reparented into the subtree (upstream
  /// `Attachment` grafts) — unload returns them to their authored
  /// parents before the roots drop.
  final List<LocalId> attachments;

  /// The `updateNode` flags the load-time instance update carried —
  /// the fields compose's merge changed, which are exactly the fields
  /// the unload's restore update writes back.
  final List<String> flags;

  /// The composed skin ids the load upserted — unload retracts them
  /// via `removeSkin`, since the pool entries would outlive the
  /// subtree they were streamed for.
  final List<LocalId> skins;

  /// The composed animation ids the load upserted — unload retracts
  /// them via `removeAnimation`, same as [skins].
  final List<LocalId> animations;

  /// Nested lazy placeholders inside the streamed subtree, keyed by
  /// their composed (remapped) ids — the spec is the one the member's
  /// `addNode` carried, `instance` intact in the prefab-local id
  /// space. Streamed members never join the tracked document, so this
  /// map is what `SceneController.loadSubtree` resolves them through.
  final Map<LocalId, NodeSpec> placeholders;
}

/// Composes [placeholder]'s prefab subtree and returns the op list
/// that realizes it plus the [StreamedSubtree] record reversing it.
///
/// [placeholder] is the instance node as it exists live (from the
/// tracked document, or caller-supplied for a placeholder inside a
/// previously streamed subtree); it must carry `instance` or this
/// throws [ArgumentError]. [resolve] loads the referenced prefab
/// document (and any eager prefab documents the prefab itself
/// references — the same contract as `composeScene`'s `resolve`).
/// [hostDoc], when given, dedupes payload/resource upserts against
/// content already installed. [priorRoots] lists roots a previous
/// stream-in of this same node created — roots not in the new set get
/// a `removeNode` first, making a re-load a replace instead of a
/// pile-up.
({List<Map<String, Object?>> ops, StreamedSubtree streamed}) encodeSubtreeLoad(
  NodeSpec placeholder, {
  required PrefabResolver resolve,
  SceneDocument? hostDoc,
  List<LocalId> priorRoots = const [],
}) => _encodeFromComposed(
  placeholder,
  composed: composeScene(
    _instanceScratch(placeholder, hostDoc),
    resolve: resolve,
  ),
  hostDoc: hostDoc,
  priorRoots: priorRoots,
);

/// [encodeSubtreeLoad] on upstream `composeSceneAsync` — [loadPrefab]
/// resolves each `source` AssetRef to its decoded document
/// transitively (the prefab's own eager prefabs included), for callers
/// whose asset layer is async.
Future<({List<Map<String, Object?>> ops, StreamedSubtree streamed})>
encodeSubtreeLoadAsync(
  NodeSpec placeholder, {
  required AsyncPrefabLoader loadPrefab,
  SceneDocument? hostDoc,
  List<LocalId> priorRoots = const [],
}) async => _encodeFromComposed(
  placeholder,
  composed: await composeSceneAsync(
    _instanceScratch(placeholder, hostDoc),
    load: loadPrefab,
  ),
  hostDoc: hostDoc,
  priorRoots: priorRoots,
);

/// The scratch document both encoders compose: a copy of
/// [placeholder] with `load` flipped to eager (upstream only expands
/// eager instances, and the copy keeps compose's in-place mutations —
/// transform merge, component graft, `instance = null` — out of the
/// tracked document) plus a bare stub per attachment target so
/// upstream's exists-in-document graft check passes.
SceneDocument _instanceScratch(NodeSpec placeholder, SceneDocument? hostDoc) {
  final instance = placeholder.instance;
  if (instance == null) {
    throw ArgumentError(
      'loadSubtree: node ${placeholder.id} is not a prefab instance',
    );
  }
  final scratch = SceneDocument(
    documentId: hostDoc?.documentId ?? DocumentId.generate(),
  );
  scratch.addNode(
    NodeSpec(
      id: placeholder.id,
      name: placeholder.name,
      transform: placeholder.transform,
      children: [...placeholder.children],
      components: [...placeholder.components],
      layers: placeholder.layers,
      skin: placeholder.skin,
      instance: instance.copyWith(load: LoadPolicy.eager),
      visible: placeholder.visible,
    ),
  );
  for (final a in instance.attachments) {
    if (!scratch.nodes.containsKey(a.node)) {
      scratch.addNode(NodeSpec(id: a.node));
    }
  }
  return scratch;
}

/// Translates a composed scratch document into the wire batch — the
/// shared emit path for [encodeSubtreeLoad] and
/// [encodeSubtreeLoadAsync].
({List<Map<String, Object?>> ops, StreamedSubtree streamed})
_encodeFromComposed(
  NodeSpec placeholder, {
  required SceneDocument composed,
  SceneDocument? hostDoc,
  required List<LocalId> priorRoots,
}) {
  final instance = placeholder.instance!;
  // A single-root prefab merges its root INTO the instance node, so a
  // `removedNodes` entry naming that root deletes the merged node
  // (upstream `_removeNode` runs on `remapId(root) == placeholder.id`)
  // — nothing is left to re-spec or hang members under.
  final composedInstance = composed.nodes[placeholder.id];
  if (composedInstance == null) {
    throw ArgumentError(
      'loadSubtree: node ${placeholder.id.toToken()}\'s removedNodes '
      'deletes the prefab root it merges into',
    );
  }
  final parents = _parents(composed);
  final idKey = manifestIdKey(composed);

  final authored = placeholder.children.toSet();
  final attachmentTargets = {for (final a in instance.attachments) a.node};
  // Streamed roots: the children compose grafted under the instance
  // node that are neither authored children nor attachment grafts.
  // Reachable members are everything under those roots — prefab
  // orphans (in the doc but off every children list) never realize,
  // matching upstream's dead-weight-in-document outcome.
  final roots = <LocalId>[
    for (final c in composedInstance.children)
      if (composed.nodes.containsKey(c) &&
          !authored.contains(c) &&
          !attachmentTargets.contains(c))
        c,
  ];
  final reachable = <LocalId>{};
  final stack = [...roots];
  while (stack.isNotEmpty) {
    final id = stack.removeLast();
    if (!reachable.add(id)) continue;
    final node = composed.nodes[id];
    if (node == null) continue;
    stack.addAll(node.children);
  }
  reachable.removeAll(attachmentTargets);

  final specAfter = encodeNodeCommandSpec(composedInstance, composed);
  if (composedInstance.instance == null) {
    // The explicit null is what clears the placeholder tag natively —
    // an absent `instance` member reads as "unchanged" so a
    // reparent-only update (`spec: {}`) never strips the tag.
    specAfter['instance'] = null;
  }
  final flags = _changedFlags(placeholder, composedInstance);

  final ops = <Map<String, Object?>>[];
  // Canonical batch order (diff_apply): removes, payloads, resources,
  // node ops, skins/animations. The instance's own update lands with
  // the node ops — it re-specs the node without `instance`, clearing
  // the placeholder tag.
  for (final r in priorRoots) {
    if (!roots.contains(r)) {
      ops.add({'op': 'removeNode', 'node': r.toToken()});
    }
  }
  for (final entry in composed.payloads.entries) {
    final bytes = entry.value.bytes;
    if (bytes == null) continue;
    if (_bytesEqual(hostDoc?.payload(entry.key)?.bytes, bytes)) {
      continue;
    }
    final spec = entry.value;
    ops.add({
      'op': 'upsertPayload',
      'id': idKey(entry.key),
      'bytes': base64Encode(bytes),
      'encoding': spec.encoding.name,
      if (spec.layout != null) 'layout': spec.layout,
      if (spec.format != null) 'format': spec.format,
      if (spec.width != null) 'width': spec.width,
      if (spec.height != null) 'height': spec.height,
      if (spec.length != null) 'length': spec.length,
    });
  }
  for (final entry in composed.resources.entries) {
    final old = hostDoc?.resources[entry.key];
    if (old != null &&
        canonicalJson(encodeResource(old, (id) => id.toToken())) ==
            canonicalJson(encodeResource(entry.value, (id) => id.toToken()))) {
      continue;
    }
    ops.add({
      'op': 'upsertResource',
      'id': idKey(entry.key),
      'resource': encodeResource(entry.value, idKey),
    });
  }
  ops.add({
    'op': 'updateNode',
    'node': placeholder.id.toToken(),
    'flags': flags,
    'spec': specAfter,
  });
  // Parents precede children within the added set (diff_apply's emit
  // rule); every member's parent is either another member or the
  // instance node itself, which is already live.
  final emitted = <LocalId>{};
  void emit(LocalId id) {
    if (!emitted.add(id)) return;
    final parent = parents[id];
    if (parent != null &&
        parent != placeholder.id &&
        reachable.contains(parent)) {
      emit(parent);
    }
    final node = composed.nodes[id];
    if (node == null) return;
    ops.add({
      'op': 'addNode',
      'node': id.toToken(),
      'parent': parent?.toToken(),
      'spec': encodeNodeCommandSpec(node, composed),
    });
  }

  for (final id in reachable) {
    emit(id);
  }
  // Attachment grafts ride updateNode reparents — the target is a
  // live host node, only its parent changes. `spec` is inert for a
  // reparent-only update.
  for (final a in instance.attachments) {
    if (!composed.nodes.containsKey(a.node)) continue;
    if (a.node == placeholder.id) continue;
    ops.add({
      'op': 'updateNode',
      'node': a.node.toToken(),
      'flags': ['reparented'],
      'spec': <String, Object?>{},
      'parent': parents[a.node]?.toToken(),
    });
  }
  for (final skin in composed.skins.values) {
    ops.add({
      'op': 'upsertSkin',
      'id': idKey(skin.id),
      'skin': encodeSkinSpec(skin, composed),
    });
  }
  for (final animation in composed.animations.values) {
    ops.add({
      'op': 'upsertAnimation',
      'id': idKey(animation.id),
      'animation': encodeAnimationSpec(animation, composed),
    });
  }

  return (
    ops: ops,
    streamed: StreamedSubtree(
      roots: roots,
      attachments: [for (final a in instance.attachments) a.node],
      flags: flags,
      skins: [for (final s in composed.skins.values) s.id],
      animations: [for (final a in composed.animations.values) a.id],
      placeholders: {
        for (final id in reachable)
          if (composed.nodes[id]?.instance != null) id: composed.nodes[id]!,
      },
    ),
  );
}

/// The reverse batch for one [encodeSubtreeLoad]: reparent attachment
/// targets back to their authored homes, retract the pools the stream
/// upserted (`removeSkin`/`removeAnimation` — dependents detach
/// before the nodes they reference, the canonical remove order),
/// `removeNode` each streamed root, then restore the instance node's
/// placeholder spec (the `instance` member rides back on the wire,
/// re-tagging it). Upserted payloads and resources persist by design
/// — their ids are shared per prefab document, and the vocabulary
/// has no remove ops for them. [attachmentHomes] maps each streamed
/// attachment target to the parent it had in the host document
/// (absent → scene root).
List<Map<String, Object?>> encodeSubtreeUnload(
  NodeSpec placeholder, {
  required StreamedSubtree streamed,
  Map<LocalId, LocalId?> attachmentHomes = const {},
  SceneDocument? hostDoc,
}) {
  final specDoc =
      hostDoc ?? (SceneDocument()..addNode(_bareCopy(placeholder), root: true));
  return [
    for (final t in streamed.attachments)
      {
        'op': 'updateNode',
        'node': t.toToken(),
        'flags': ['reparented'],
        'spec': <String, Object?>{},
        'parent': attachmentHomes[t]?.toToken(),
      },
    for (final s in streamed.skins)
      {'op': 'removeSkin', 'id': 'skin:${s.toToken()}'},
    for (final a in streamed.animations)
      {'op': 'removeAnimation', 'id': 'anim:${a.toToken()}'},
    for (final r in streamed.roots) {'op': 'removeNode', 'node': r.toToken()},
    {
      'op': 'updateNode',
      'node': placeholder.id.toToken(),
      'flags': streamed.flags,
      'spec': encodeNodeCommandSpec(placeholder, specDoc),
    },
  ];
}

/// The `updateNode` flags compose's merge flipped on the instance
/// node — the minimal set the wire needs. Transform compares by
/// matrix storage, components by their prefix-free canonical encoding
/// (prefab-local `rref` ids remap on composition, so token equality
/// is the honest compare).
List<String> _changedFlags(NodeSpec before, NodeSpec after) => [
  if (!_listEquals(
    before.transform.toMatrix4().storage,
    after.transform.toMatrix4().storage,
  ))
    'transform',
  if (before.name != after.name) 'name',
  if (before.layers != after.layers) 'layers',
  if (before.visible != after.visible) 'visible',
  if (_componentsJson(before.components) != _componentsJson(after.components))
    'components',
  if (before.skin != after.skin) 'skin',
];

/// The components array in canonical JSON with bare-token id keys —
/// prefix-free so a spec from the host document and one from the
/// composed subtree compare on content, not on which doc's prefix map
/// encoded them.
String _componentsJson(List<ComponentSpec> components) => canonicalJson([
  for (final c in components)
    {
      'type': c.type,
      if (c.properties.isNotEmpty)
        'properties': {
          for (final e in c.properties.entries)
            e.key: encodePropertyValue(e.value, (id) => id.toToken()),
        },
    },
]);

/// A field-wise copy for documents that need [placeholder] as their
/// only node (the restore spec's id-key source when no host doc is
/// available).
NodeSpec _bareCopy(NodeSpec node) => NodeSpec(
  id: node.id,
  name: node.name,
  transform: node.transform,
  children: [...node.children],
  components: [...node.components],
  layers: node.layers,
  skin: node.skin,
  instance: node.instance,
  visible: node.visible,
);

/// Node id → parent id from [doc]'s `children` lists (absent → root).
Map<LocalId, LocalId?> _parents(SceneDocument doc) {
  final parents = <LocalId, LocalId?>{
    for (final id in doc.nodes.keys) id: null,
  };
  for (final node in doc.nodes.values) {
    for (final child in node.children) {
      parents[child] = node.id;
    }
  }
  return parents;
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Byte-wise chunk compare; two absent chunks count as equal (the
/// `_bytesEqual` semantics diff_apply applies to payloads).
bool _bytesEqual(Uint8List? a, Uint8List? b) {
  if (a == null || b == null) return identical(a, b);
  if (a.lengthInBytes != b.lengthInBytes) return false;
  for (var i = 0; i < a.lengthInBytes; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
