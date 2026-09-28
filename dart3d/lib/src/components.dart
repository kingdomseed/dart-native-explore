// Component-level wire ops and the document capability pass.
//
// Pure-Dart (no dartnative import) so the shapes are reachable under
// `dart test` — see docs/extended-surface-program.md §W12.

import 'scene_model.dart';

/// The `selectVariant` op: selects variant [selected] on the
/// `materialsVariants` component mounted on [node] — upstream
/// `MaterialsVariantsComponent.select`. A null [selected] re-applies
/// each binding's default material.
Map<String, Object?> encodeSelectVariantCommand(
  LocalId node,
  String? selected,
) => {'op': 'selectVariant', 'node': node.toToken(), 'selected': selected};

/// The `render` op: triggers one render pass for the
/// `RenderTextureResource` [target]. Required to refresh a `manual`
/// target; on an `interval` target it forces an early refresh (W14).
Map<String, Object?> encodeRenderCommand(LocalId target) => {
  'op': 'render',
  'target': 'rt:${target.toToken()}',
};

/// Feature names dart3d realizes today (kept in sync with the native
/// decode surfaces — `skinning` landed in W11, `materialsVariants` in
/// W12, `renderTextures` in W14, `prefabInstances`/`streaming` in W15,
/// `particles` in W18, the W26 geometry/instancing surface below).
///
/// `prefabInstances` is realized Dart-side: eager instances expand
/// through `SceneController.loadDocumentComposed` (upstream
/// `composeSceneAsync`) before the manifest goes out, and lazy ones
/// stream through `loadSubtree`. The natives only ever see composed
/// content or tagged placeholders — see [uncomposedEagerInstances].
const kRealizedFeatures = {
  'skinning',
  'materialsVariants',
  'renderTextures',
  'prefabInstances',
  'streaming',
  'particles',
  // W26 — the `d3:procMesh` shape vocabulary and `d3:instances`
  // component.
  'd3ProcGeometry',
  'd3Instances',
  'd3Billboards',
};

/// Feature names with a named follow-on workstream — the warning names
/// the plan so a degraded document says *where* the capability lands.
/// Empty today: W15 (`prefabInstances`/`streaming`) merged.
const kPlannedFeatures = <String, String>{};

/// The eager prefab-instance nodes in [doc] that have not been
/// composed — nodes whose `instance` member is still present with a
/// non-lazy load policy. The natives realize an `instance` node only
/// as a contentless placeholder (the W15 lazy-stream contract), so an
/// eager instance must be expanded Dart-side
/// (`SceneController.loadDocumentComposed`) before it reaches them.
List<LocalId> uncomposedEagerInstances(SceneDocument doc) => [
  for (final node in doc.nodes.values)
    if (node.instance case final inst? when inst.load != LoadPolicy.lazy)
      node.id,
];

/// The `featuresRequired` names this engine would not realize for
/// [doc] as-is — the set a strict loader refuses on. Upstream's
/// decoder already rejects required features outside
/// `supportedFeatures`; this is the engine-level half: features
/// upstream's format supports but this engine has not implemented
/// (W29), plus `prefabInstances` when [doc] still carries eager
/// instances nobody composed ([uncomposedEagerInstances]).
Set<String> missingRequiredFeatures(SceneDocument doc) {
  final missing = doc.featuresRequired.difference(kRealizedFeatures);
  if (doc.featuresRequired.contains('prefabInstances') &&
      uncomposedEagerInstances(doc).isNotEmpty) {
    missing.add('prefabInstances');
  }
  return missing;
}

/// The `featuresRequired`/`featuresUsed` capability pass (W12).
///
/// Upstream's decoder refuses *unknown* required features at parse
/// time, but a document requiring a feature the natives haven't
/// realized yet parses fine and then degrades silently — the manifest
/// still streams, the natives just skip the blocks. This pass returns
/// one warning line per unrealized feature so the load path can make
/// the gap loud. `featuresRequired` entries read as degradation
/// warnings; `featuresUsed`-only entries are advisories. Eager prefab
/// instances that reach this pass uncomposed add one line naming the
/// composing load path — they would otherwise realize as empty
/// placeholders.
List<String> unrealizedFeatureWarnings(SceneDocument doc) {
  final warnings = <String>[];
  final seen = <String>{};
  String suffix(String feature) {
    final wave = kPlannedFeatures[feature];
    return wave != null ? ' (planned $wave)' : '';
  }

  for (final feature in doc.featuresRequired) {
    if (kRealizedFeatures.contains(feature) || !seen.add(feature)) {
      continue;
    }
    warnings.add(
      "document requires feature '$feature' that dart3d natives "
      'do not realize yet${suffix(feature)}; scene may be degraded',
    );
  }
  for (final feature in doc.featuresUsed) {
    if (kRealizedFeatures.contains(feature) || !seen.add(feature)) {
      continue;
    }
    warnings.add(
      "document uses feature '$feature' that dart3d natives "
      'do not realize yet${suffix(feature)}',
    );
  }
  final eager = uncomposedEagerInstances(doc);
  if (eager.isNotEmpty) {
    warnings.add(
      'document carries ${eager.length} uncomposed eager prefab '
      'instance(s); they realize as empty placeholders — load through '
      'loadDocumentComposed to expand them',
    );
  }
  return warnings;
}
