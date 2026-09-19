// The document layer (W29): `serializeScene` and the live-document fold
// that keeps it truthful.
//
// dart3d has no Dart-side `Node` graph — the live scene is the tracked
// `SceneDocument` plus every structural op sent since it loaded. The
// controller folds each outgoing `command` op and transform write into
// that document here, so [serializeScene] returns the graph the natives
// actually hold, not just the last manifest.
//
// Decoding reuses upstream's `decodeDocument` through a synthetic
// one-entry document rather than a parallel decoder, so a spec folded
// here decodes exactly as it does in a manifest (upstream's `_decodeNode`
// and friends are private — the document decoder is the public gate).

import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

/// The `command` ops that carry document state — the set
/// [foldCommandIntoDocument] consumes. Everything else on the command
/// channel (`anim`, `setMorphWeights`, `selectVariant`, `render`, the
/// physics/joint ops, `query`) is runtime state upstream's format does
/// not serialize either, so it passes through untouched.
bool commandAffectsDocument(Map<String, Object?> op) =>
    _documentOps.contains(op['op']);

const _documentOps = {
  'addNode',
  'removeNode',
  'updateNode',
  'upsertResource',
  'upsertPayload',
  'updateStage',
  'upsertSkin',
  'removeSkin',
  'upsertAnimation',
  'removeAnimation',
  'updateViews',
};

/// The live graph back as a standalone [SceneDocument] — dart3d's form
/// of upstream's `serializeScene(Node root)`, with the document playing
/// the live graph's role.
///
/// The snapshot is detached — re-encoded then decoded, with chunk bytes
/// copied back in, so later live edits (including in-place byte
/// mutation) cannot reach into it — and carries this document's own id
/// space: serializing, then realizing with `SceneController.loadDocument`
/// reproduces the scene — including payload chunks, whose bytes ride the
/// binary channel and so cannot appear in the JSON tree.
SceneDocument serializeScene(SceneDocument live) {
  final snapshot = decodeDocument(encodeDocument(live));
  for (final entry in live.payloads.entries) {
    final bytes = entry.value.bytes;
    snapshot.payloads[entry.key]?.bytes = bytes == null
        ? null
        : Uint8List.fromList(bytes);
  }
  return snapshot;
}

/// Upstream's `readFscene` plus the migration lane log (W29): peeks at
/// [source]'s encoded `fscene` version — `stripJsonc` loosens the
/// source the same way the reader does — decodes, and calls [log] with
/// `dart3d: migrated fscene vN → vM` when the encoded version differs
/// from the decoded document's, i.e. the `migrateFscene` chain ran.
/// A same-version source logs nothing; a source the peek can't parse
/// leaves [log] uncalled and lets `readFscene` throw the real error.
///
/// The sink is injected because `dnLog` isn't reachable everywhere the
/// decode is — the showcase loader stays `dart test`-compatible and
/// passes its own `log` parameter through.
SceneDocument readFsceneLogged(
  String source, {
  void Function(String message)? log,
}) {
  int? encodedVersion;
  try {
    if (jsonDecode(stripJsonc(source)) case {'fscene': int v}) {
      encodedVersion = v;
    }
  } catch (_) {
    // `readFscene` reports the parse failure.
  }
  final doc = readFscene(source);
  final from = encodedVersion;
  if (from != null && from != doc.formatVersion) {
    log?.call('dart3d: migrated fscene v$from → v${doc.formatVersion}');
  }
  return doc;
}

/// Folds one outgoing `command` [op] into [doc], keeping the document a
/// mirror of the live scene. Ops not in [commandAffectsDocument]'s set
/// are ignored.
///
/// Semantics track the wire contract (protocol.dart): `addNode` on a
/// live id applies as a full update, `updateNode` applies only its
/// `flags` fields — a missing `flags` member decodes to the empty set
/// on both natives, so nothing applies, not even the reparent edge —
/// `spec`'s `children` is inert (a node's children are whoever named
/// it as `parent`), and node ops on missing ids no-op.
void foldCommandIntoDocument(SceneDocument doc, Map<String, Object?> op) {
  switch (op['op']) {
    case 'addNode':
      final id = _opId(op, 'node');
      final spec = _decodeEntry<NodeSpec>(doc, 'nodes', op['node'], op['spec']);
      spec.children
        ..clear()
        ..addAll(doc.nodes[id]?.children ?? const []);
      doc.nodes[id] = spec;
      _attach(doc, id, _opParent(op));
    case 'removeNode':
      _removeSubtree(doc, _opId(op, 'node'));
    case 'updateNode':
      final node = doc.nodes[_opId(op, 'node')];
      if (node == null) return;
      // Both natives decode a missing `flags` member to the empty
      // set — no field applies, including the reparent edge — so an
      // op without one must no-op here the same way. `diffCommands`
      // always emits `flags`; this only bites hand-rolled ops.
      final flags = (op['flags'] as List?)?.cast<String>();
      if (flags == null || flags.isEmpty) return;
      final spec = _decodeEntry<NodeSpec>(doc, 'nodes', op['node'], op['spec']);
      bool flagged(String field) => flags.contains(field);
      if (flagged('name')) node.name = spec.name;
      if (flagged('transform')) node.transform = spec.transform;
      if (flagged('layers')) node.layers = spec.layers;
      if (flagged('visible')) node.visible = spec.visible;
      if (flagged('skin')) node.skin = spec.skin;
      if (flagged('components')) {
        node.components
          ..clear()
          ..addAll(spec.components);
      }
      // The reparent edge is the wire's `parent`, not a spec field.
      if (flagged('reparented')) {
        _attach(doc, node.id, _opParent(op));
      }
    case 'upsertResource':
      doc.resources[_opId(op, 'id')] = _decodeEntry<ResourceSpec>(
        doc,
        'resources',
        op['id'],
        op['resource'],
      );
    case 'upsertPayload':
      _upsertPayload(doc, op);
    case 'updateStage':
      doc.stage = _decodeFragment(doc, {'stage': op['stage']}).stage;
    case 'upsertSkin':
      doc.skins[_opId(op, 'id')] = _decodeEntry<SkinSpec>(
        doc,
        'skins',
        op['id'],
        op['skin'],
      );
    case 'removeSkin':
      doc.skins.remove(_opId(op, 'id'));
    case 'upsertAnimation':
      doc.animations[_opId(op, 'id')] = _decodeEntry<AnimationSpec>(
        doc,
        'animations',
        op['id'],
        op['animation'],
      );
    case 'removeAnimation':
      doc.animations.remove(_opId(op, 'id'));
    case 'updateViews':
      doc.views
        ..clear()
        ..addAll(_decodeFragment(doc, {'views': op['views']}).views);
  }
}

/// Folds one `setTransforms` write into [doc] — the per-frame half of
/// the live graph. Absent fields keep the node's previous values, as on
/// the wire; a `MatrixTransform` base is decomposed first.
void foldTransformIntoDocument(
  SceneDocument doc,
  LocalId node, {
  Vector3? translation,
  Quaternion? rotation,
  Vector3? scale,
}) {
  final spec = doc.nodes[node];
  if (spec == null) return;
  final base = switch (spec.transform) {
    TrsTransform t => t,
    MatrixTransform(:final matrix) => _decompose(matrix),
  };
  spec.transform = TrsTransform(
    translation: translation ?? base.translation,
    rotation: rotation ?? base.rotation,
    scale: scale ?? base.scale,
  );
}

/// Folds one binary-channel payload delivery (`SceneController.sendPayload`)
/// into [doc]: the sent spec is authoritative, so it replaces any manifest
/// entry under the same id.
void foldPayloadIntoDocument(SceneDocument doc, PayloadSpec payload) {
  doc.payloads[payload.id] = payload;
}

// The manifest entry decode: wrap [entry] as [pool]'s single member in a
// document skeleton and run upstream's `decodeDocument`, so private
// per-kind decoders apply unchanged. [key] is the op's id token —
// `LocalId.parse` strips any readability prefix, so the bare `node`
// token and the prefixed `geo:`/`skin:`/`chunk:` forms both work.
T _decodeEntry<T>(SceneDocument doc, String pool, Object? key, Object? entry) {
  final token = key as String;
  final decoded = _decodeFragment(doc, {
    pool: <String, dynamic>{token: entry},
  });
  final map = switch (pool) {
    'nodes' => decoded.nodes,
    'resources' => decoded.resources,
    'skins' => decoded.skins,
    'animations' => decoded.animations,
    _ => throw ArgumentError.value(pool, 'pool'),
  };
  return map[LocalId.parse(token)] as T;
}

// A document skeleton carrying [fragment]'s blocks, decoded by upstream.
// `stage` must be present and a map for `_decodeStage` to run; an empty
// map decodes to defaults.
SceneDocument _decodeFragment(
  SceneDocument base,
  Map<String, Object?> fragment,
) {
  return decodeDocument(<String, dynamic>{
    'fscene': base.formatVersion,
    'documentId': base.documentId.toToken(),
    'stage': const <String, dynamic>{},
    ...fragment,
  });
}

LocalId _opId(Map<String, Object?> op, String field) =>
    LocalId.parse(op[field] as String);

LocalId? _opParent(Map<String, Object?> op) {
  final parent = op['parent'];
  return parent is String ? LocalId.parse(parent) : null;
}

// Moves [node] under [parent] (null → scene root), matching the wire's
// parent-edge authority: the id leaves `roots` and every children list
// first, so a reparent can never double-attach.
void _attach(SceneDocument doc, LocalId node, LocalId? parent) {
  doc.roots.remove(node);
  for (final n in doc.nodes.values) {
    n.children.remove(node);
  }
  final resolved = parent == null ? null : doc.nodes[parent];
  if (resolved != null) {
    resolved.children.add(node);
  } else {
    doc.roots.add(node);
  }
}

// Drops [id] and its subtree, as `removeNode` does natively. Other
// pools keep their entries — a skin or channel naming a dead joint is
// the caller's problem, same as on the wire.
void _removeSubtree(SceneDocument doc, LocalId id) {
  final node = doc.nodes.remove(id);
  if (node == null) return;
  for (final child in node.children) {
    _removeSubtree(doc, child);
  }
  doc.roots.remove(id);
  for (final n in doc.nodes.values) {
    n.children.remove(id);
  }
}

// `upsertPayload` is the one op whose spec fields arrive flattened on
// the op (plus wire-only `bytes`) rather than as a manifest entry, so
// it builds its spec directly. The fold tracks the native handlers:
// undecodable `bytes` no-ops the whole op — they warn and return
// before any state changes — an `encoding` member replaces the spec
// wholesale (absent fields decode to null, not the old values), and
// a resend without `encoding` updates the stored bytes only.
void _upsertPayload(SceneDocument doc, Map<String, Object?> op) {
  final id = _opId(op, 'id');
  final bytes = _opBytes(op['bytes']);
  if (bytes == null) return;
  final existing = doc.payloads[id];
  if (op['encoding'] is! String) {
    // Spec-less resend: the natives update `payloadStore` and leave
    // the spec alone, so the bytes fold into the existing entry — or
    // nowhere when there isn't one to carry them (the document model
    // has no spec-less payload).
    if (existing == null) return;
    existing.bytes = bytes;
    return;
  }
  final encodingName = op['encoding'] as String;
  doc.payloads[id] = PayloadSpec(
    id,
    // A name outside `PayloadEncoding.values` can't be represented —
    // upstream `_decodePayload` throws on it too — so it degrades to
    // `bytes`, the enum's own opaque marker: stored, byte-carrying,
    // and unconsumable, which is the native state for a verbatim
    // encoding no consumer decodes. Dropping the op would lose a
    // chunk the send already delivered.
    encoding: PayloadEncoding.values.any((e) => e.name == encodingName)
        ? PayloadEncoding.values.byName(encodingName)
        : PayloadEncoding.bytes,
    layout: op['layout'] as String?,
    format: op['format'] as String?,
    width: (op['width'] as num?)?.toInt(),
    height: (op['height'] as num?)?.toInt(),
    length: (op['length'] as num?)?.toInt() ?? bytes.lengthInBytes,
    bytes: bytes,
  );
}

// Both `bytes` forms decode to the chunk, or null when the wire value
// can't — the same "missing/undecodable bytes → warn + return" gate
// the natives apply before touching the payload store.
Uint8List? _opBytes(Object? bytes) {
  try {
    return switch (bytes) {
      String s => base64Decode(s),
      List l => Uint8List.fromList(l.cast<int>()),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

TrsTransform _decompose(Matrix4 matrix) {
  final translation = Vector3.zero();
  final rotation = Quaternion.identity();
  final scale = Vector3.zero();
  matrix.decompose(translation, rotation, scale);
  return TrsTransform(
    translation: translation,
    rotation: rotation,
    scale: scale,
  );
}
