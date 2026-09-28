/// Prefab composition that carries dart3d extension resources.
///
/// Upstream `composeScene`/`composeSceneAsync` build a new document
/// from each input's `resources` pool, remapping prefab resource ids
/// to `sharedId(prefab document, id)`. dart3d's W26 procedural-shape
/// resources live outside that pool ([d3ExtensionResources]), so plain
/// composition drops them. The composed mesh keeps a geometry ref that
/// resolves to nothing, and the natives draw nothing.
///
/// These wrappers give upstream a per-call shallow clone of each input
/// document (the host, and every prefab the resolver/loader returns)
/// in which each extension resource stands in as a placeholder upstream
/// resource. Upstream then copies and remaps it like any other
/// resource, and the wrapper swaps every placeholder in the output back
/// to its extension entry under the remapped id. Input documents are
/// never mutated. A prefab cache shared by concurrent composes (for
/// example two `loadSubtreeAsync` calls) is safe: each call sees only
/// its own clones. The clones share node/component/resource objects
/// with the inputs, which upstream composition only reads.
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
  // Nothing to expand: upstream returns the host itself, and so do we.
  if (!_hasEager(document)) return document;
  final stash = _Stash();
  final out = composeScene(
    stash.stand(document),
    resolve: (ref) => stash.stand(resolve(ref)),
  );
  return stash.harvest(out);
}

/// [composeSceneAsync] that keeps [d3ExtensionResources]; see
/// [composeSceneWithExtensions].
Future<SceneDocument> composeSceneAsyncWithExtensions(
  SceneDocument document, {
  required AsyncPrefabLoader load,
}) async {
  if (!_hasEager(document)) return document;
  final stash = _Stash();
  final out = await composeSceneAsync(
    stash.stand(document),
    load: (ref) async => stash.stand(await load(ref)),
  );
  return stash.harvest(out);
}

bool _hasEager(SceneDocument doc) => doc.nodes.values.any(
  (n) => n.instance != null && n.instance!.load == LoadPolicy.eager,
);

/// The placeholder bookkeeping for one compose call. Each placeholder
/// is a geometry resource whose `procedural` spec is a fresh object
/// minted here. Upstream's `_remapResource` passes `procedural` through
/// by reference, so placeholders are recognized by object identity,
/// never by their dimensions. An authored cuboid of any extents can't
/// collide with one.
final class _Stash {
  final Map<ProceduralGeometry, Map<String, Object?>> _entries = Map.identity();

  /// A shallow clone of [doc] with its extension resources stood in as
  /// placeholders. [doc] is untouched.
  SceneDocument stand(SceneDocument doc) {
    final ext = d3ExtensionResources(doc);
    if (ext.isEmpty) return doc;
    final clone =
        SceneDocument(
            documentId: doc.documentId,
            allocator: doc.allocator,
            stage: doc.stage,
          )
          ..formatVersion = doc.formatVersion
          ..generator = doc.generator
          ..payloadSource = doc.payloadSource;
    clone.featuresUsed.addAll(doc.featuresUsed);
    clone.featuresRequired.addAll(doc.featuresRequired);
    clone.resources.addAll(doc.resources);
    clone.nodes.addAll(doc.nodes);
    clone.roots.addAll(doc.roots);
    clone.skins.addAll(doc.skins);
    clone.animations.addAll(doc.animations);
    clone.payloads.addAll(doc.payloads);
    clone.views.addAll(doc.views);
    for (final entry in ext.entries) {
      if (clone.resources.containsKey(entry.key)) continue;
      final marker = CuboidGeometrySpec(extents: Vector3.all(1));
      _entries[marker] = entry.value;
      clone.resources[entry.key] = GeometryResource(
        entry.key,
        procedural: marker,
      );
    }
    return clone;
  }

  SceneDocument harvest(SceneDocument out) {
    final ext = d3ExtensionResources(out);
    for (final id in out.resources.keys.toList()) {
      final r = out.resources[id];
      if (r is! GeometryResource) continue;
      final procedural = r.procedural;
      if (procedural == null) continue;
      final entry = _entries[procedural];
      if (entry == null) continue;
      out.resources.remove(id);
      ext[id] = copyExtensionEntry(entry);
    }
    return out;
  }
}
