import 'dart:convert';
import 'dart:typed_data';

import 'scene_model.dart';

/// The `SceneDiff` → `command`-op bridge (W5 structural mutations).
///
/// `diffScene` reports *which* nodes changed but not the new content —
/// `NodeChange` carries flags, not values — so every op carries the
/// replacement state: node ops embed the manifest `nodes` entry shape
/// (see [encodeNodeCommandSpec]), resource ops the re-encoded resource
/// entry, payload ops the chunk bytes. `SceneDiff` folds resource
/// edits into `NodeChange.components` without exposing which resources
/// changed, so the resource and payload pools are re-diffed here
/// directly against [oldDoc].
///
/// Op order is the spec's canonical one — `removeSkin` and
/// `removeAnimation` first (skins/clips reference nodes, so the
/// dependents detach before `removeNode`), then `upsertPayload`,
/// `upsertResource`, `addNode`, `updateNode`, `upsertSkin` and
/// `upsertAnimation`, and `updateStage` last — so detaches precede
/// re-adds, chunks land before the resources and clips that decode
/// them, resources land before the nodes that reference them, the
/// batch's added/updated nodes exist before a skin's joints or an
/// animation's channel targets rebind, and the stage re-decodes only
/// after the environment resource it names has been upserted.
/// Re-sending a batch is safe: the native side treats `addNode` on a
/// live id as a full update and warns + no-ops node ops on missing
/// ids.
///
/// `stageChanged` emits a trailing `updateStage` op carrying the new
/// stage JSON (W7), and the view list is diffed directly — upstream's
/// `diffScene`/`composeScene` treat `views` as install-only, so the
/// encoded lists are compared here and a difference ships one
/// wholesale-replace `updateViews` op, emitted last (after
/// `updateStage`) so any camera node or render target a view
/// references has already landed in the batch (W14). The skin and
/// animation pools are re-diffed here
/// directly against [oldDoc], same as the resource pool: `SceneDiff`'s
/// `animationsChanged` is a single bool and there is no `skinsChanged`
/// at all, so the per-entry emit decision re-derives upstream's
/// `_skinsEqual`/`_animationsChanged` predicates ([_skinChanged],
/// [_animationChanged]). The one case that produces no spec-level
/// difference — a channel target added, removed, renamed, or
/// rest-transform-edited (upstream's retarget rule) — is folded back
/// in through the `retargeted` set so its animation still re-ships
/// and natives rebind.
List<Map<String, Object?>> diffCommands(
  SceneDiff diff,
  SceneDocument? oldDoc,
  SceneDocument newDoc,
) {
  final idKey = manifestIdKey(newDoc);
  final parents = _parents(newDoc);

  final ops = <Map<String, Object?>>[];
  if (oldDoc != null) {
    for (final id in oldDoc.skins.keys) {
      if (!newDoc.skins.containsKey(id)) {
        ops.add({'op': 'removeSkin', 'id': 'skin:${id.toToken()}'});
      }
    }
    for (final id in oldDoc.animations.keys) {
      if (!newDoc.animations.containsKey(id)) {
        ops.add({'op': 'removeAnimation', 'id': 'anim:${id.toToken()}'});
      }
    }
  }
  for (final id in diff.removed) {
    ops.add({'op': 'removeNode', 'node': id.toToken()});
  }
  for (final entry in newDoc.payloads.entries) {
    final bytes = entry.value.bytes;
    // Only arrivals and content changes produce an upsert — a chunk
    // can't be "unsent", so a payload that loses its bytes is skipped.
    if (bytes == null) continue;
    if (_bytesEqual(oldDoc?.payload(entry.key)?.bytes, bytes)) continue;
    // The spec rides the op: a runtime-minted chunk's encoding/layout
    // never reaches the manifest's `payloads` block, so without these
    // fields the native `payloadSpecs` table never learns the chunk's
    // shape and every consumer stays unresolved.
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
  for (final id in _changedResources(oldDoc, newDoc)) {
    ops.add({
      'op': 'upsertResource',
      'id': idKey(id),
      'resource': encodeResource(newDoc.resources[id]!, idKey),
    });
  }
  // Added nodes emit parents before children — `addNode` self-attaches
  // via `parent`, so the parent must already exist when a child's op
  // lands (natives warn + root on an unresolvable parent rather than
  // defer). `diff.added` order is document insertion order, which does
  // not guarantee that.
  final added = <LocalId>{...diff.added};
  final emitted = <LocalId>{};
  for (final id in diff.added) {
    void emit(LocalId nid) {
      if (!emitted.add(nid)) return;
      final p = parents[nid];
      if (p != null && added.contains(p)) emit(p);
      final node = newDoc.nodes[nid];
      if (node == null) return;
      ops.add({
        'op': 'addNode',
        'node': nid.toToken(),
        'parent': p?.toToken(),
        'spec': encodeNodeCommandSpec(node, newDoc),
      });
    }

    emit(id);
  }
  for (final change in diff.changed) {
    final node = newDoc.nodes[change.id];
    if (node == null) continue;
    final flags = <String>[
      if (change.transform) 'transform',
      if (change.name) 'name',
      if (change.layers) 'layers',
      if (change.visible) 'visible',
      if (change.reparented) 'reparented',
      if (change.components) 'components',
      if (change.skin) 'skin',
    ];
    if (flags.isEmpty) continue;
    ops.add({
      'op': 'updateNode',
      'node': change.id.toToken(),
      'flags': flags,
      'spec': encodeNodeCommandSpec(node, newDoc),
      if (change.reparented) 'parent': parents[change.id]?.toToken(),
    });
  }
  // W11: skin/animation upserts land after the node ops — a skin's
  // joints and a channel's targets resolve against the post-batch
  // graph, and the upsert re-attaches to every node whose `skin`
  // member names it (the same rebind-consumers contract as
  // `upsertResource`). A node's `skin` member change rides the
  // `updateNode` `skin` flag instead — the spec re-encodes the member
  // and natives re-decode it, no skin upsert needed.
  for (final skin in newDoc.skins.values) {
    if (!_skinChanged(oldDoc, newDoc, skin)) continue;
    ops.add({
      'op': 'upsertSkin',
      'id': idKey(skin.id),
      'skin': encodeSkinSpec(skin, newDoc),
    });
  }
  // Channel targets whose live node was added/removed, renamed, or
  // rest-transform-edited need a rebind even when the spec itself is
  // byte-identical — upstream's `retargeted` rule.
  final retargeted = <LocalId>{
    ...diff.added,
    ...diff.removed,
    for (final change in diff.changed)
      if (change.name || change.transform) change.id,
  };
  for (final animation in newDoc.animations.values) {
    if (!_animationChanged(oldDoc, newDoc, animation, retargeted)) {
      continue;
    }
    ops.add({
      'op': 'upsertAnimation',
      'id': idKey(animation.id),
      'animation': encodeAnimationSpec(animation, newDoc),
    });
  }
  // W7: a stage diff lands last as `updateStage` — the encoded
  // manifest `stage` block, produced by upstream's public `encodeStage`
  // with this document's manifest id keys (`environmentRef` reads
  // `env:<token>`). `diffScene` also sets `stageChanged` when only the
  // referenced environment resource's content changed; that resource
  // already shipped in the upsertResource pass above, so by the time
  // natives re-run `decodeStage` every reference resolves.
  if (diff.stageChanged) {
    ops.add({'op': 'updateStage', 'stage': encodeStage(newDoc.stage, idKey)});
  }
  // W14: upstream `diffScene` never diffs `views` (install-only
  // there), so the encoded lists are compared here directly — any
  // difference re-ships the whole list (`updateViews` is
  // wholesale-replace). The op lands last in the batch: a view may
  // reference a camera node or render texture shipped above.
  if (_encodeViews(oldDoc) != _encodeViews(newDoc)) {
    ops.add({
      'op': 'updateViews',
      'views': [for (final v in newDoc.views) encodeViewSpec(v, idKey)],
    });
  }
  return ops;
}

/// A [NodeSpec] encoded as the manifest `nodes` entry — the `spec`
/// shape `addNode`/`updateNode` carry (upstream's `_encodeNode` is
/// private; this emits the identical fields). [doc] supplies the
/// manifest id-key prefixes (`n:`/`geo:`/`skin:`/`chunk:`/…) used in
/// `children`, `skin`, and `rref` property values. A surviving prefab
/// `instance` (a lazy placeholder, or a nested lazy instance inside a
/// streamed subtree — W15) emits through [encodeInstanceSpec]; its
/// presence is the placeholder tag the natives record.
Map<String, Object?> encodeNodeCommandSpec(NodeSpec node, SceneDocument doc) {
  final idKey = manifestIdKey(doc);
  return {
    if (node.name.isNotEmpty) 'name': node.name,
    'transform': switch (node.transform) {
      MatrixTransform(:final matrix) => {'matrix': matrix.storage.toList()},
      TrsTransform(:final translation, :final rotation, :final scale) => {
        'trs': {
          't': [translation.x, translation.y, translation.z],
          'r': [rotation.x, rotation.y, rotation.z, rotation.w],
          's': [scale.x, scale.y, scale.z],
        },
      },
    },
    if (node.children.isNotEmpty)
      'children': [for (final c in node.children) idKey(c)],
    if (node.components.isNotEmpty)
      'components': [
        for (final c in node.components)
          {
            'type': c.type,
            if (c.properties.isNotEmpty)
              'properties': {
                for (final e in c.properties.entries)
                  e.key: encodePropertyValue(e.value, idKey),
              },
          },
      ],
    if (node.layers != 1) 'layers': node.layers,
    if (node.skin != null) 'skin': idKey(node.skin!),
    if (node.instance != null)
      'instance': encodeInstanceSpec(node.instance!, idKey),
    if (!node.visible) 'visible': false,
  };
}

/// A [PrefabInstanceSpec] encoded as the manifest node's `instance`
/// member — upstream's `_encodeInstance` is private; this emits the
/// identical fields. The id space is the PREFAB's, not the host's:
/// override targets, removed node ids, and member ids all name prefab-
/// local nodes, so [idKey] falls back to the `id:` prefix for them
/// (matching what the manifest encoder produces for an unexpanded
/// instance). Natives only record the member — the streaming layer
/// resolves it.
Map<String, Object?> encodeInstanceSpec(
  PrefabInstanceSpec instance,
  String Function(LocalId) idKey,
) => {
  'source': instance.source.key,
  if (instance.load != LoadPolicy.eager) 'load': instance.load.name,
  if (instance.overrides.isNotEmpty)
    'overrides': [
      for (final o in instance.overrides)
        {
          'target': idKey(o.target),
          'path': o.path,
          'value': encodePropertyValue(o.value, idKey),
        },
    ],
  if (instance.attachments.isNotEmpty)
    'attachments': [
      for (final a in instance.attachments)
        {
          'node': idKey(a.node),
          if (a.parent != null) 'parent': idKey(a.parent!),
        },
    ],
  if (instance.removedNodes.isNotEmpty)
    'removedNodes': [for (final id in instance.removedNodes) idKey(id)],
  if (instance.addedComponents.isNotEmpty)
    'addedComponents': [
      for (final c in instance.addedComponents)
        {
          'type': c.type,
          if (c.properties.isNotEmpty)
            'properties': {
              for (final e in c.properties.entries)
                e.key: encodePropertyValue(e.value, idKey),
            },
        },
    ],
  if (instance.removedComponentTypes.isNotEmpty)
    'removedComponentTypes': instance.removedComponentTypes,
  if (instance.memberComponents.isNotEmpty)
    'memberComponents': [
      for (final mc in instance.memberComponents)
        {
          'member': idKey(mc.member),
          'component': {
            'type': mc.component.type,
            if (mc.component.properties.isNotEmpty)
              'properties': {
                for (final e in mc.component.properties.entries)
                  e.key: encodePropertyValue(e.value, idKey),
              },
          },
        },
    ],
};

/// A [SkinSpec] encoded as the manifest `skins` entry — the `skin`
/// shape `upsertSkin` carries (upstream's `_encodeSkin` is private;
/// this emits the identical fields).
Map<String, Object?> encodeSkinSpec(SkinSpec skin, SceneDocument doc) {
  final idKey = manifestIdKey(doc);
  return {
    'joints': [for (final j in skin.joints) idKey(j)],
    'inverseBindMatrices': idKey(skin.inverseBindMatrices),
    if (skin.skeleton != null) 'skeleton': idKey(skin.skeleton!),
  };
}

/// An [AnimationSpec] encoded as the manifest `animations` entry —
/// the `animation` shape `upsertAnimation` carries (upstream's
/// `_encodeAnimation` is private; this emits the identical fields).
Map<String, Object?> encodeAnimationSpec(
  AnimationSpec animation,
  SceneDocument doc,
) {
  final idKey = manifestIdKey(doc);
  return {
    if (animation.name.isNotEmpty) 'name': animation.name,
    'channels': [
      for (final ch in animation.channels)
        {
          'target': idKey(ch.target),
          if (ch.targetName != null) 'targetName': ch.targetName,
          'property': ch.property.name,
          'timeline': idKey(ch.timeline),
          'keyframes': idKey(ch.keyframes),
        },
    ],
  };
}

/// A [RenderViewSpec] plus the dart3d `viewport` extension (W24).
///
/// Upstream's spec is final-shaped — it has no field for the
/// `"viewport":[l,b,w,h]` member dart3d adds to the manifest `views`
/// entry (a split-screen rect in target-pixel units, bottom-left
/// origin — absent means the full target). The extension rides a
/// subclass so it flows through `doc.views`, [diffCommands],
/// `SceneController.updateViews`, and `D3Protocol.loadSceneBytes`
/// with no API change — every one of those re-encodes through
/// [encodeViewSpec], which emits the member for this type only.
final class Dart3dRenderViewSpec extends RenderViewSpec {
  /// Creates a view spec carrying the upstream fields plus [viewport].
  Dart3dRenderViewSpec({
    required super.cameraNode,
    super.target,
    super.layerMask = 0xFFFFFFFF,
    super.order = 0,
    super.antiAliasingMode,
    super.renderScale,
    super.filterQuality,
    this.viewport,
  });

  /// `[left, bottom, width, height]` in target-pixel units — a
  /// split-screen rect inside the view's target (screen or render
  /// texture); null draws the full target.
  final List<double>? viewport;
}

/// A [RenderViewSpec] encoded as the manifest `views` entry — the
/// entry shape `updateViews` carries (upstream's `_encodeView` is
/// private; this emits the identical fields): `camera` always, plus
/// `target`/`layerMask`/`order`/`antiAliasing`/`renderScale`/
/// `filterQuality` only when non-default. [idKey] supplies the
/// manifest id-key prefixes for the `n:`/`rt:` tokens. A
/// [Dart3dRenderViewSpec] adds `"viewport":[l,b,w,h]` (target-pixel
/// units) — absent means the full target.
Map<String, Object?> encodeViewSpec(
  RenderViewSpec view,
  String Function(LocalId) idKey,
) => {
  'camera': idKey(view.cameraNode),
  if (view.target != null) 'target': idKey(view.target!),
  if (view.layerMask != 0xFFFFFFFF) 'layerMask': view.layerMask,
  if (view.order != 0) 'order': view.order,
  if (view.antiAliasingMode != null) 'antiAliasing': view.antiAliasingMode,
  if (view.renderScale != null) 'renderScale': view.renderScale,
  if (view.filterQuality != null) 'filterQuality': view.filterQuality,
  if (view is Dart3dRenderViewSpec && view.viewport != null)
    'viewport': view.viewport,
};

/// The manifest `views` entry decoded back to a spec — the inverse of
/// [encodeViewSpec], producing a [Dart3dRenderViewSpec] so the
/// `viewport` extension survives a manifest round-trip (upstream's
/// `_decodeView` drops it). Malformed/absent members take the spec
/// defaults; `camera` is required and [LocalId.parse] throws on a
/// missing token, same as upstream.
RenderViewSpec decodeViewSpec(Map<String, Object?> json) =>
    Dart3dRenderViewSpec(
      cameraNode: LocalId.parse(json['camera'] as String),
      target: json['target'] != null
          ? LocalId.parse(json['target'] as String)
          : null,
      layerMask: (json['layerMask'] as num?)?.toInt() ?? 0xFFFFFFFF,
      order: (json['order'] as num?)?.toInt() ?? 0,
      antiAliasingMode: json['antiAliasing'] as String?,
      renderScale: (json['renderScale'] as num?)?.toDouble(),
      filterQuality: json['filterQuality'] as String?,
      viewport: (json['viewport'] as List?)
          ?.map((v) => (v as num).toDouble())
          .toList(),
    );

/// Re-decodes [doc]'s view list from the raw `.fscene` manifest
/// object so the dart3d view extensions survive — upstream's
/// `_decodeView` emits one spec per manifest entry, unskipped and in
/// order, so the lists pair by index. Entries that aren't JSON
/// objects keep upstream's spec.
void applyViewExtensions(SceneDocument doc, Map<String, Object?> manifest) {
  final viewsJson = manifest['views'];
  if (viewsJson is! List) return;
  for (var i = 0; i < doc.views.length && i < viewsJson.length; i++) {
    final entry = viewsJson[i];
    if (entry is Map) {
      doc.views[i] = decodeViewSpec(Map<String, Object?>.from(entry));
    }
  }
}

/// The `.fscene` text decode dart3d callers use — upstream
/// [readFscene] plus [applyViewExtensions], so a `viewport` on a
/// manifest `views` entry reaches `doc.views` instead of being
/// dropped by upstream's `_decodeView` (W24).
SceneDocument readFsceneWithExtensions(String manifest) {
  final doc = readFscene(manifest);
  // `stripJsonc` matches upstream's own reader tolerance — the logged
  // path (W29's `readFsceneLogged`) decodes through here too.
  applyViewExtensions(
    doc,
    jsonDecode(stripJsonc(manifest)) as Map<String, Object?>,
  );
  return doc;
}

/// [doc]'s view list as canonical JSON, encoded with the document's
/// own manifest id keys — the compare form the `updateViews` emit
/// decision uses (upstream has no `viewsChanged` to consult). A null
/// or empty list reads as `[]` so absent and cleared docs compare
/// equal to each other, not to a populated one.
String _encodeViews(SceneDocument? doc) {
  if (doc == null || doc.views.isEmpty) return '[]';
  final idKey = manifestIdKey(doc);
  return canonicalJson([
    for (final view in doc.views) encodeViewSpec(view, idKey),
  ]);
}

/// Whether [skin]'s realized content differs between the docs: new,
/// joint list or skeleton changed, or its inverse-bind chunk's bytes
/// changed — upstream `diffScene`'s `_skinsEqual` minus the
/// live-binding clause (a stale joint *node* is a rebind, handled by
/// the bound nodes' `skin` updateNode flag rather than a re-send).
bool _skinChanged(SceneDocument? oldDoc, SceneDocument newDoc, SkinSpec skin) {
  final old = oldDoc?.skins[skin.id];
  if (old == null) return true;
  if (old.skeleton != skin.skeleton) return true;
  if (!_listEquals(old.joints, skin.joints)) return true;
  return !_bytesEqual(
    oldDoc?.payload(old.inverseBindMatrices)?.bytes,
    newDoc.payload(skin.inverseBindMatrices)?.bytes,
  );
}

/// Whether [animation]'s realized content differs between the docs —
/// upstream `diffScene`'s `_animationsChanged` inner loop factored
/// per animation: new, renamed, channel count/target/targetName/
/// property changed, a channel's timeline or keyframes chunk bytes
/// changed, or a channel's target is in [retargeted] (its live node
/// was added, removed, renamed, or rest-transform-edited, so the
/// binding is stale under an identical spec).
bool _animationChanged(
  SceneDocument? oldDoc,
  SceneDocument newDoc,
  AnimationSpec animation,
  Set<LocalId> retargeted,
) {
  final old = oldDoc?.animations[animation.id];
  if (old == null) return true;
  if (old.name != animation.name) return true;
  if (old.channels.length != animation.channels.length) return true;
  for (var i = 0; i < animation.channels.length; i++) {
    final oc = old.channels[i];
    final nc = animation.channels[i];
    if (oc.target != nc.target ||
        oc.targetName != nc.targetName ||
        oc.property != nc.property) {
      return true;
    }
    if (retargeted.contains(nc.target)) return true;
    if (!_bytesEqual(
          oldDoc?.payload(oc.timeline)?.bytes,
          newDoc.payload(nc.timeline)?.bytes,
        ) ||
        !_bytesEqual(
          oldDoc?.payload(oc.keyframes)?.bytes,
          newDoc.payload(nc.keyframes)?.bytes,
        )) {
      return true;
    }
  }
  return false;
}

/// The manifest's `<kind>:<token>` id-key resolver (upstream's private
/// `_buildPrefixMap`): `n`/`geo`/`mat`/`tex`/`rt`/`env`/`skin`/`anim`/
/// `chunk`, `id` for anything unclassified. Both native decoders strip
/// everything through the last colon, so prefixes are readability
/// only — emitting them keeps command ops visually consistent with the
/// manifest entries they patch.
String Function(LocalId) manifestIdKey(SceneDocument doc) {
  final prefixes = <LocalId, String>{
    for (final id in doc.nodes.keys) id: 'n',
    for (final id in doc.skins.keys) id: 'skin',
    for (final id in doc.animations.keys) id: 'anim',
    for (final id in doc.payloads.keys) id: 'chunk',
  };
  for (final r in doc.resources.values) {
    prefixes[r.id] = switch (r) {
      GeometryResource() => 'geo',
      MaterialResource() => 'mat',
      TextureResource() => 'tex',
      RenderTextureResource() => 'rt',
      EnvironmentResource() => 'env',
    };
  }
  return (id) => '${prefixes[id] ?? 'id'}:${id.toToken()}';
}

/// Node id → parent id, computed from [doc]'s `children` lists
/// (absent → root). Mirrors upstream `diffScene`'s private `_parents`.
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

/// Resource ids whose realized content differs between the docs: the
/// spec re-encodes differently, a payload it references has different
/// bytes, it's new, or (transitively) a resource it references
/// changed. This re-derives the set upstream's `diffScene` computes
/// internally and folds into `NodeChange.components` — the emitted
/// `upsertResource` list is a superset of what natives strictly need,
/// which is fine: they rebind consumers surgically regardless.
Set<LocalId> _changedResources(SceneDocument? oldDoc, SceneDocument newDoc) {
  // Same resolver upstream's diff uses — prefixes would be a no-op for
  // an equality compare.
  String encode(ResourceSpec r) =>
      canonicalJson(encodeResource(r, (id) => id.toToken()));

  final changed = <LocalId>{};
  for (final entry in newDoc.resources.entries) {
    final old = oldDoc?.resources[entry.key];
    if (old == null || encode(old) != encode(entry.value)) {
      changed.add(entry.key);
      continue;
    }
    for (final payloadId in _resourcePayloads(entry.value)) {
      if (!_bytesEqual(
        oldDoc?.payload(payloadId)?.bytes,
        newDoc.payload(payloadId)?.bytes,
      )) {
        changed.add(entry.key);
        break;
      }
    }
  }

  // Propagate through resource-to-resource references (a material
  // referencing a changed texture is itself changed) to a fixed point.
  var grew = changed.isNotEmpty;
  while (grew) {
    grew = false;
    for (final entry in newDoc.resources.entries) {
      if (changed.contains(entry.key)) continue;
      final refs = <LocalId>{};
      _collectRefs(_resourceProperties(entry.value), refs);
      if (refs.any(changed.contains)) {
        changed.add(entry.key);
        grew = true;
      }
    }
  }
  return changed;
}

/// The payload ids a resource's realization reads — geometry's vertex/
/// index/morph chunks, a texture's image chunk. Same list as upstream
/// `diffScene`'s `_resourcePayloads`.
List<LocalId> _resourcePayloads(ResourceSpec resource) => switch (resource) {
  GeometryResource() => [
    if (resource.vertices != null) resource.vertices!,
    if (resource.indices != null) resource.indices!,
    if (resource.morphTargets != null) resource.morphTargets!.deltas,
  ],
  TextureResource() => [if (resource.payload != null) resource.payload!],
  _ => const [],
};

/// The property bags scanned for resource-to-resource references —
/// upstream scans material properties only.
Map<String, PropertyValue> _resourceProperties(ResourceSpec resource) =>
    switch (resource) {
      MaterialResource() => resource.properties,
      _ => const {},
    };

/// Collects every [ResourceRefValue] id reachable through [properties]
/// (including nested lists and maps).
void _collectRefs(Map<String, PropertyValue> properties, Set<LocalId> out) {
  void walk(PropertyValue value) {
    switch (value) {
      case ResourceRefValue():
        out.add(value.id);
      case ListValue():
        value.values.forEach(walk);
      case MapValue():
        value.values.values.forEach(walk);
      default:
        break;
    }
  }

  properties.values.forEach(walk);
}

/// Byte-wise chunk compare; two absent chunks count as equal. Same
/// semantics as upstream `diffScene`'s `_payloadsEqual`.
bool _bytesEqual(Uint8List? a, Uint8List? b) {
  if (a == null || b == null) return identical(a, b);
  if (a.lengthInBytes != b.lengthInBytes) return false;
  for (var i = 0; i < a.lengthInBytes; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Element-wise list compare; same semantics as upstream `diffScene`'s
/// `_listEquals`.
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
