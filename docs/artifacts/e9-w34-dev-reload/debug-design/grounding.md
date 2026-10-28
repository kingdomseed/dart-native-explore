# W34 production debug-view grounding

## Overview

The caller needs to select one resolved channel, independently toggle a filled wireframe overlay, and return to current authored rendering. The existing scene/document must stay serializable and editable through the accepted reload library. This is the existing W34 scope, not the 0.24 per-node/split/collider debug API or W28 shader translation.

The iOS single opaque quad capability is proven and independently reviewed. Its temporary material properties, hook class and main were removed. Accepted production-intended source stays baseline58, with no debug API yet. Source/build/native/performance proof remain separate.

## Key concepts and existing boundaries

`SceneView` owns renderer configuration. Current widget settings are allowsCameraControl, showsStatistics, backgroundColor, antialiasingMode and quality. `SceneViewElement.mount` sends viewConfig before attaching the controller; update diffs the config and sends only when relevant fields change. `_config` always sends explicit quality default to clear a previous tier. The native applyViewConfig owners apply these values to each host and quality precedence. This is an existing configuration route, not a new command requirement.

`SceneController` owns authored scene content and mirrors document-affecting commands. loadDocument emits a full scene and payloads. Runtime-only setNodeHighlights sends one command and is excluded from serialization. That foundation intentionally uses native scene lifetime, clears on load/native recreation, and does not retain/replay selection across reattachment. It proves a transport/lifetime precedent, not a requirement that debug configuration share highlight lifetime.

Native material registries and actual material consumers differ. Instance double-sided clones, variants/default snapshots, LOD geometry, camera-facing replacements, animation material factors, late texture arrivals and baked catchers have their own active slot/owner behavior. A registry-only material loop misses actual draws. Changing a material's shader affects every renderer that shares it. Existing render textures and SceneKit screen siblings share scene objects; bake scenes copy source attachments at bake time. Diagnostic output must not contaminate authored resources or cached captures. Each candidate must identify the actual rendering/binding owner rather than introduce a speculative parallel registry.

## How it works now

Caller → SceneViewElement → viewConfig → native applyViewConfig is the renderer-settings route. Caller → SceneController → command/batch → native command drain is the transient-operation route. Neither requires modifying upstream scene 0.3.0's sealed schema. Document hot reload continues through the accepted dev_reload/host/HTTP-sidecar preparation and applyDiff path, already reviewed. Shader hot reload is outside W34.

The iOS probe used SceneController.applyCommands(upsertResource) solely as throwaway fixture transport. decodeMaterial built the normal actual PBR material, retained texture slots/transforms/factors, then appended diagnostic RGB at final fragment. `_surface.normal` is the sampled view-space normal; geometryNormal deliberately ignores the normal map. The real showWireframe debug bit overlays actual triangle edges over fill. None of this settles public ownership, current-update restoration or shared-renderer isolation.

The Android source map places sampled material inputs inside prepareMaterial and the normal at getWorldNormalVector after preparation. Current litSpec SCREEN_SPACE reflection bypasses postLightingColor replacement; a diagnostic recipe must account for this. A per-light surfaceShading return alone fails zero/multiple-light and IBL/emissive isolation. gltfio Wireframe is AABBs, not mesh edges. Android needs actual triangle edges with the existing geometry/instance/deformation owner; no AABB substitute.

## Channel and lifetime decisions to make

Close exactly normals, metallic, roughness, base color and depth, with independent wireframe. Metallic/roughness/base color mean sampled material inputs after textures and authored/runtime factors, before lighting. Do not substitute authored scalar values or renderer-specific squared BRDF roughness. Choose and document one cross-platform normal coordinate space. Define depth precisely; per-fragment view-space depth is different from nonlinear reverse-Z hardware depth or Euclidean distance. Existing BLEND depth proxies and discarded render-target depth prevent a universal main-depth-texture interpretation.

Specify the diagnostic display transfer and behavior of tone/exposure/effects. Probe RGB passed through actual camera packing/resolve and is not calibrated raw shader output. Turning debugging off must reveal current authored state, including material/texture/stage changes received while debugging, rather than an obsolete snapshot.

Define full scene replacement, structural re-realization, controller swap, view recreation, attach-before-load, resource/geometry/variant/LOD changes and teardown. Choose one source of truth. No dual retained/native configuration without a real need. Existing Android testing requires release builds, so dev tooling cannot depend on kDebugMode in a way that removes its authorized verification path. Prefer explicit opt-in without changing authored serialization.

This is not permission to broaden the feature list, build a modifier framework, renderer fork, generic registry, revision protocol, or new clock. API and native implementation should fit existing settings, material and draw owners. Other families and shared paths are reachable constraints to design for or prove, not an invitation to claim their runtime correctness from the quad.

## Sources and proof

Actual parent source is /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb, read-only to designers. HEAD2f38e4e33f0b1cb678bc408a42d069c796cefc12 with dirty accepted58 overlay. Immutable archive /private/tmp/dart3d-e9-reload-library-implementation-20261027/r1/parent-source.tgz SHA2566a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706. Adjacent parent-source-sha256.txt names all58. Designers may import that snapshot into their own prepared checkout for coherent source.

- dart3d/lib/src/scene_view.dart: SceneView/SceneViewElement, config diff and mount order.
- dart3d/lib/src/scene_controller.dart: loadDocument, setNodeHighlights, applyCommands, attach/detach and serialization.
- dart3d/lib/src/protocol.dart: viewConfig vs document operations.
- dart3d/ios/Classes/SceneViewHost.swift: applyViewConfig1312, redecodeResource, render/bake/target/sibling owners.
- dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt: applyViewConfig2487, native render/bake/target and scene lifetime.
- /private/tmp/dart3d-e9-debug-source-20261027/ios/source-map.md and android/source-map.md: both read and accepted as source grounding. Reuse their facts; inspect precise omitted paths when needed, avoid repeating broad exploration.
- /private/tmp/dart3d-e9-debug-native-review-20261027/r1/report.md: independent bounded iOS PASS. Exact source/replay, normal/geometric control, diagonal overlay and restoration verified offline. No production API accepted.
- docs/program-v2.md:201 onward replaces old ten-lane gate. E9 row411; W34 behavior floor docs/full-engine-program.md:1126. T2 native matrix and T4 remain mandatory, old broad swarm is superseded.

Fresh scoped open/draft PR title search debug returned empty without listing watchedPR65. Exact Linear JHD W34 search returned empty. Matching local E9/reload branches are already recorded in tracker. No CONTEXT.md under dart3d/docs was found. Shared Linear get_agent_context was exposed but earlier returned tool not found; that source is unavailable, not evidence that shared notes are absent.

## Constraints and next proof

No existing ownership is being refactored at this stage. The design adds developer debug selection around existing owners, preserving authored material/resource ownership and controller/document semantics. Architecture rationale comes from the actual view/command/material/capture call paths and their current public contracts; no historical motive is inferred.

A142 remains reserved. Simulator is off. Design work performs no device queries, runs or material baking. Android GPU capability and full W34 remain unproven. A design should name the smallest implementation slice and decisive native checks, and identify factual blockers instead of papering them over. It should not add new acceptance gates beyond existing behavior proof.
