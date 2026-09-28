/// Prefab composition that carries dart3d extension resources.
///
/// Upstream `composeScene`/`composeSceneAsync` build a new document
/// from each input's `resources` pool, remapping prefab resource ids
/// to `sharedId(prefab document, id)`. dart3d's W26 procedural-shape
/// resources live outside that pool ([d3ExtensionResources]), so plain
/// composition drops them. The composed mesh keeps a geometry ref that
/// resolves to nothing, and the natives draw nothing.
///
/// These wrappers stand each extension resource in as a placeholder
/// upstream resource for the length of the compose call, so upstream
/// copies and remaps it like any other resource. They then swap every
/// placeholder in the output back to its extension entry under the
/// remapped id. The placeholders are removed from the input documents
/// (the host and every prefab the resolver hands out) before the call
/// returns, even when composition throws.
library;

import 'package:vector_math/vector_math.dart';

import 'diff_apply.dart';
import 'scene_model.dart';

/// [composeScene] that keeps [d3ExtensionResources] — host entries
/// under their own ids, prefab entries under the ids upstream remaps
/// them to.
SceneDocument composeSceneWithExtensions(
  SceneDocument document, {
  required PrefabResolver resolve,
}) {
  final stash = _Stash()..stand(document);
  try {
    final out = composeScene(
      document,
      resolve: (ref) {
        final prefab = resolve(ref);
        stash.stand(prefab);
        return prefab;
      },
    );
    return stash.harvest(out);
  } finally {
    stash.restore();
  }
}

/// [composeSceneAsync] that keeps [d3ExtensionResources]; see
/// [composeSceneWithExtensions].
Future<SceneDocument> composeSceneAsyncWithExtensions(
  SceneDocument document, {
  required AsyncPrefabLoader load,
}) async {
  final stash = _Stash()..stand(document);
  try {
    final out = await composeSceneAsync(
      document,
      load: (ref) async {
        final prefab = await load(ref);
        stash.stand(prefab);
        return prefab;
      },
    );
    return stash.harvest(out);
  } finally {
    stash.restore();
  }
}

/// The placeholder bookkeeping for one compose call. A placeholder is
/// a cuboid with extents `(-1, -1, token)`. Negative extents never
/// occur in a real document, and `token` indexes [_entries].
final class _Stash {
  final List<Map<String, Object?>> _entries = [];
  final Map<SceneDocument, List<LocalId>> _stood = Map.identity();

  void stand(SceneDocument doc) {
    if (_stood.containsKey(doc)) return;
    final ids = <LocalId>[];
    _stood[doc] = ids;
    for (final entry in d3ExtensionResources(doc).entries) {
      if (doc.resources.containsKey(entry.key)) continue;
      final token = _entries.length;
      _entries.add(entry.value);
      doc.resources[entry.key] = GeometryResource(
        entry.key,
        procedural: CuboidGeometrySpec(
          extents: Vector3(-1, -1, token.toDouble()),
        ),
      );
      ids.add(entry.key);
    }
  }

  SceneDocument harvest(SceneDocument out) {
    final ext = d3ExtensionResources(out);
    for (final id in out.resources.keys.toList()) {
      final token = _tokenOf(out.resources[id]);
      if (token == null) continue;
      out.resources.remove(id);
      ext[id] = copyExtensionEntry(_entries[token]);
    }
    return out;
  }

  void restore() {
    for (final e in _stood.entries) {
      for (final id in e.value) {
        e.key.resources.remove(id);
      }
    }
  }

  int? _tokenOf(ResourceSpec? r) {
    if (r is! GeometryResource) return null;
    final p = r.procedural;
    if (p is! CuboidGeometrySpec) return null;
    final e = p.extents;
    if (e.x != -1 || e.y != -1) return null;
    final token = e.z.toInt();
    return token >= 0 && token < _entries.length ? token : null;
  }
}
