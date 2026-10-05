# Android stabilization triage — 2026-09-28

Branch `stabilize/android` (rebased onto `main` by the coordinator;
SHAs below are post-rebase). Scope:
`dart3d/android/**` only. Device: Nothing A142 (`00064149A002033`,
Mali-G610, Android 16), release builds via `dn run --release`, both
Filament backends (Vulkan default, GL via `DART3D_BACKEND=opengl`).
Evidence PNGs live in `docs/artifacts/stabilize-android/`.

Gates at branch head: `dn analyze` clean, `dn test` 321/321,
`./gradlew :dart3d:compileReleaseKotlin` clean (one pre-existing
`filterWidth` deprecation warning), JVM unit tests 34/34
(`:dart3d:testReleaseUnitTest`, 9 new).

## P1 results (audit §3)

| # | P1 | Verdict | Commits | Evidence |
|---|---|---|---|---|
| 1 | Directional shadow chain inert | **Fixed.** Root cause: `decodeLight` never set a direction, so every light used Filament's default `(0,−1,0)` rotated by the node transform, and the dice key grazed the table with its shadows falling away from every receiver. **Emission axis (corrected in fc88f6a):** upstream flutter_scene 0.23.0 `DirectionalLightComponent.worldDirection` = rotation × (0,0,1), or the serialized `localDirection`. `SpotLightComponent` aims along its local `direction` (codec default (0,−1,0)). Android now builds each light's direction from those wire vectors through the z-mirror, so wire +Z is Filament (0,0,−1). The first cut (8653c1f) used wire −Z to match the example's inverted `aimLight`, which would have made upstream-authored lights shine backwards. The dice table `aimLight` is now `fwd = dir`, which leaves the key's world direction unchanged. Also: `shadowMaxDistance` now maps to `shadowFar` (it was written to `maxShadowDistance`, the contact-shadow length), and `contactShadowDistance` maps to `maxShadowDistance`. The `d3_shadow_catcher` "SPIR-V panic" does not reproduce at head: the catcher compiles on both backends. | 8653c1f, fc88f6a | `shadows-before-vulkan.png` vs `shadows-after-vulkan.png` / `shadows-after-gl.png` (post-fix build: the dice cast DPCF shadows and the table is lit from above). fcar and dash render lit from the front-right key. The harness W24 catcher lane was not visually confirmed. |
| 2 | Main-thread ANR ~3×/50 min | **Fixed (root cause), partially bounded.** The ANR trace on the device (`/data/anr/anr_2026-09-20-23-29-32-852`, via bugreport) shows main in `MaterialBuilder.nBuilderBuild` ← `Dart3dView.<init>` ← `DNPluginRegistry.createView`. Every view creation (each tab switch) compiled 7 filamat packages on main, at ~4 s each for the lit set. Fixed with a process-wide package cache, a background prewarm, non-blocking view init (the frame loop holds mutations until the packages load), and background KHR-variant compiles. `slow frame` logging was added. | 9482304, 6b4dcca, c1f3490, d316a17 | Before: `Skipped 1528 frames` (12.6 s main block at first view); showcase switch `slow frame 3863ms`. After: 12-cycle Dice→Showcase→Harness soak with taps (36 view creations, ~4 min, Vulkan): **0 ANR, 0 crashes**, 27 `disposeView` releases, max `slow frame 509ms`, max `Skipped 54 frames`, 0 main-thread compiles. Remaining main-thread work is a big document's first realize: ~1.0–1.3 s for the 1900-op showcase. |
| 3 | Zombie mode on warm relaunch | **Fixed.** (a) The framework's JNI `createView` caller swallows a throwing provider (verified in `DNViewFactory` bytecode), so `Dart3dBridge.createView` now catches, logs `SceneView init FAILED` with the stack, and returns a visible `InitFailedView`; mutations to it log once per kind. (b) `onDetachedFromWindow` used to destroy the Engine on every detach, so a re-attached view was dead and Dart kept driving it. With the framework's `disposeView` hook (detected reflectively, present in the installed SDK), detach now only parks the frame loop, and `disposeView` releases. Older frameworks keep the release-on-detach behavior. Mutations or re-attach after release now log errors. | cadd6ef | Warm relaunch (BACK, then `am start` in the same pid): `dart3d view 3 released (disposeView(3))`, new engine, scene renders (`warm-relaunch-gl.png`). |
| 4 | Re-realize drops command-added `addNode` | **Fixed.** Top-level `addNode`/`updateNode`/`removeNode` and subtree loads now go into one arrival-ordered journal that replays after the deferred-payload re-realize. The journal is cleared on `loadScene`. | 6a75881 | Harness: `re-realize replay: 68 plain op(s), 0 subtree(s)` (VK), `51 plain op(s)` (GL). |
| 5 | KTX2 provider process-global leak / UAF | **Fixed.** There is now one provider per Engine, and `nKtx2Release` deletes it just before `engine.destroy()`. | cadd6ef | `materials` showcase → Dice → Showcase: `ktx2: provider released with its engine`, then the new engine decodes again (`ktx2 64x64 ETC2_EAC_SRGBA8`). |
| 6 | Turbulence gradient table | **Fixed.** Confirmed 322 vs 256 floats, diverging from the Dart table at index 32. Replaced with the exact 256-value table, and a JVM test pins it. | e3f4f27 | `TurbulenceGradientsTest` (3 tests). |
| 7 | W26 hang/OOM | **Fixed.** Uncapped icosphere confirmed (`maxOf(0, …)`). All caps now mirror `dart3d/lib/src/geometry/limits.dart` (table below). Also fixed: 32-bit indices above 65,536 vertices on sphere/torus (they were always UINT16), a vertex-budget cap on instance bakes, and the dash `(0,0)` infinite loop, which existed in Kotlin too. | ae1c966, 8572f74 | `MeshFactoryTest`: 256×256 sphere uses UINT32 and max index = vc−1; icosphere(30) clamps to 81,920 triangles; zero-count tube; degenerate dashes render solid. |

## Cap values (Android == Dart `limits.dart` on origin/stabilize/dart)

| Constant | Value | Android site |
|---|---|---|
| segment-style counts (segments, rings, radial/tubular/height segments, capRings, segmentsX/Z, tube + ribbon stations) | 1..512, radial counts of cylinder/cone/capsule/disc/tube ≥3, stations ≥2 | `FsceneRealizer.seg()` |
| icosphere subdivisions | 0..6 | `seg(…, max = 6)` + `MeshFactory.icosphere` |
| UINT16 → UINT32 index switch | > 65,536 vertices | `MeshFactory.indexWidthFor` |
| baked instances | 16,384 | `MAX_BAKED_INSTANCES` |
| baked vertices (instances × base vertices) | 2^20, floor of one instance | `MAX_BAKED_VERTICES` |
| dash spans | 16,384; an invalid `(on,off)` renders solid | `MeshFactory.MAX_DASH_SPANS` |

Values are clamped with a warn-once, never rejected.

## Review-thread triage (PRs #1, #8, #9, #10, #11 — `dart3d/android/**`)

44 threads: 43 unresolved, plus 1 already resolved and listed for completeness.
**Fixed 32 · Won't-fix 6 · Deferred 6.**

| PR | Comment id | File:line (original) | Summary | Verdict | Commit / reason |
|---|---|---|---|---|---|
| #1 | 4045925298 | Dart3dView.kt:1221 | Env payload early return strands other claimants | WON'T-FIX (already fixed) | Resolved on GitHub. `applyPayload` no longer returns after `decodeStage` ("No early return" comment) |
| #1 | 4046091801 | dart3d_jni.cpp:175 | KTX2 provider never released with its Engine | FIXED | cadd6ef |
| #8 | 4054179783 | Dart3dView.kt:1051 | LUT cache unbounded | FIXED | 2e48bd4 (LRU of 4, cleared on loadScene) |
| #8 | 4054179787 | FsceneRealizer.kt:2838 | Retained LUT claim missing from stage fingerprint | FIXED | 2e48bd4 |
| #8 | 4054179790 | StageEffects.kt:604 | GI continuous fields not interpolated | FIXED | 2e48bd4 (Swift twin → iOS owner) |
| #8 | 4054179800 | Dart3dView.kt:757 | AE compensation below Filament's ISO floor | FIXED | 2e48bd4 (overflow moves into shutter time) |
| #8 | 4054324481 | Dart3dView.kt:985 | Grain-off sets dithering NONE | FIXED | 2e48bd4 (always TEMPORAL) |
| #8 | 4058547710 | Dart3dView.kt:888 | lensFlare.intensity ignored when bloom on | WON'T-FIX (platform limit) | Filament has one `BloomOptions.strength` for bloom and the flare composite. Now logged once instead of silent (2e48bd4) |
| #8 | 4058547715 | Dart3dView.kt:809 | Exposure not applied to screen-view cameras created later | FIXED | 2e48bd4 |
| #9 | 4054361821 | Dart3dView.kt:665 | P1 catcher reads `shadowMultiplier` from MaterialInputs | WON'T-FIX (stale) | The body no longer reads it, and the build is lazy. It compiles on VK and GL at head |
| #9 | 4054361848 | FsceneRealizer.kt:1652 | angularRadius radians vs degrees / sun-only | FIXED | 8653c1f (converted, plus a warn-once that DIRECTIONAL ignores it) |
| #9 | 4054616508 | FsceneRealizer.kt:1722 | Cascade splits not normalized to shadow range | FIXED | 8653c1f |
| #10 | 4054413346 | MeshFactory.kt:1613 | P1 quaternion Y-branch bug in instance tangents | WON'T-FIX (stale) | Both packers (`MeshFactory.packTangentFrame`, `FsceneRealizer` ~5546) set `q[1]=0.25s`. The bake uses `packTangentFrame` |
| #10 | 4054413359 | FsceneRealizer.kt:1096 | P1 instance payload consumers not tracked | FIXED | c10cc91 (`redecodeInstancesForPayload` on upsertPayload and binary chunks; iOS → iOS owner) |
| #10 | 4054413362 | FsceneRealizer.kt:979 | `widthInPixels` has no effect | DEFER (M, ~1 day) | Needs projection/viewport-aware re-expansion per frame on both natives and the Dart mirror |
| #10 | 4054413377 | Dart3dView.kt:3735 | P1 AABB stale after re-facing | FIXED | c10cc91 |
| #10 | 4054413396 | MeshFactory.kt:1551 | Bake drops base topology | FIXED | 8572f74 (non-triangle geometry refused with a warn, like iOS) |
| #10 | 4054413401 | FsceneRealizer.kt:850 | Tessellation params not forwarded | WON'T-FIX (stale) | `procedural()` forwards segmentsX/Z, segments/rings, radial/tubular today |
| #10 | 4054413423 | FsceneRealizer.kt:891 | Invalid tube counts crash | FIXED | ae1c966 |
| #10 | 4058581072 | FsceneRealizer.kt:1357 | doubleSided duplicate rebound by material upsert | FIXED | c10cc91 (the snapshot is no longer a shared consumer) |
| #10 | 4058581075 | Dart3dView.kt:3741 | Re-face per render-pass camera | DEFER (M, ~1 day) | Per-pass re-expansion or per-view geometry. The same issue exists on iOS |
| #10 | 4058690785 | FsceneRealizer.kt:872 | P1 icosphere subdivisions uncapped | FIXED | ae1c966, 8572f74 |
| #10 | 4058878323 | FsceneRealizer.kt:1438 | Instance payloads not registered | FIXED | c10cc91 (duplicate of 4054413359) |
| #10 | 4058878324 | Dart3dView.kt:4255 | Line ribbons skew under nonuniform scale | DEFER (S–M, ~3 h) | Compute the side vector in world space and map it back by the inverse transform. Twin exists on iOS |
| #10 | 4058878325 | MeshFactory.kt:704 | Cuboid −Y face winds inward | FIXED | ae1c966 |
| #10 | 4059089045 | FsceneRealizer.kt:1581 | P1 bake not capped by vertex budget | FIXED | ae1c966, 8572f74 |
| #10 | 4059089048 | Dart3dView.kt:4364 | AABB stale after re-facing | FIXED | c10cc91 (duplicate of 4054413377) |
| #10 | 4059420374 | MeshFactory.kt:1695 | Bake topology | FIXED | 8572f74 (duplicate of 4054413396) |
| #10 | 4059420387 | MeshFactory.kt:748 | UINT16 overflow on big sphere/torus | FIXED | ae1c966 |
| #10 | 4062294020 | MeshFactory.kt:1685 | Mirrored instances not rewound | FIXED | 8572f74 (iOS twin → iOS owner) |
| #10 | 4062454701 | Dart3dView.kt:4482 | Re-face per rendered camera | DEFER (M) | Duplicate of 4058581075 |
| #10 | 4062454704 | FsceneRealizer.kt:1524 | removeNode leaks proc mesh / duplicate MI / facing entry | FIXED | c10cc91 (removeNode, re-realize sweep and view release) |
| #11 | 4058498623 | ParticleRuntime.kt:1456 | P1 billboard upload counts elements, not bytes | WON'T-FIX (stale) | `setBufferAt(…, count*4*VERTEX_BYTES)` is already in place |
| #11 | 4058498631 | ParticleRuntime.kt:1401 | Pole-on spherical billboards collapse | FIXED | 4faa367 |
| #11 | 4058498633 | Dart3dView.kt:831 | Billboards oriented for host camera only | DEFER (M) | Same family as 4058581075 (per-view facing) |
| #11 | 4058553338 | Dart3dView.kt:3766 | 100 ms clamp pre-empts particle maxFrameTime | FIXED | 4faa367 |
| #11 | 4058553345 | ParticleRuntime.kt:1415 | Flipbook frame0 overrun | FIXED | 4faa367 |
| #11 | 4058553357 | FsceneRealizer.kt:2788 | pause/enabled toggles destroy live particles | DEFER (M, ~0.5 day) | Needs gate-only component updates to mutate the live runtime instead of `teardownComponents`. iOS twin exists |
| #11 | 4058553373 | ParticleRuntime.kt:721 | Gradient table malformed | FIXED | e3f4f27 |
| #11 | 4058717351 | ParticleRuntime.kt:549 | Turbulence sampled in mirrored space | FIXED | 4faa367 (also the Dart 4ddd4cc module reset) |
| #11 | 4058717355 | ParticleRuntime.kt:395 | Explicit zero direction becomes +Y | FIXED | 4faa367 |
| #11 | 4059493137 | ParticleRuntime.kt:1309 | Alpha particles unsorted | FIXED | 4faa367 (primitive long-key back-to-front sort; additive unsorted) |
| #11 | 4059493140 | ParticleRuntime.kt:1740 | velocityAligned spin handedness | FIXED | 4faa367 |
| #11 | 4059885225 | FsceneRealizer.kt:1531 | Particles not re-attached while LOD culled | FIXED | 4faa367 |

Also fixed while in the code (no thread): shadow `shadowFar` mapping and
`contactShadowDistance` → `maxShadowDistance` (8653c1f);
closed-polyline width/color wrap, billboard scale-then-rotate, ribbon
normals, per-segment lineSegments colors, no caps on closed tubes, ribbon
`stations` cap (8572f74, 8865095); `attributes` without `color` threw
`JSONException` (c10cc91).

## PR #16 review (Codex, 6 threads)

All six claims hold against the code at `b6fa42b`, and all are fixed in
one commit (see the git log for "PR #16 review fixes"). Verification is
`compileReleaseKotlin`, JVM tests 34/34 and `dn test` 321/321. There
was no device run, because the integration agent holds the A142 and the
simulator.

| Comment id | File:line | Verdict | Draft reply |
|---|---|---|---|
| 4122634272 | FsceneRealizer.kt:1673 | FIXED (P1, real) | Confirmed: an empty billboard rebake destroyed `procGpuMesh` and returned before re-registering, leaving `cameraFacing` pointing at the dead VertexBuffer. `destroyProcRenderable` now drops the node's facing entry along with the buffers, so every rebuild path (procMesh and instances) re-registers only when it produces geometry. |
| 4122634293 | Dart3dView.kt:807 | FIXED | Confirmed: an async base-package rejection left a live blank view. The view now overlays the same on-screen "failed to initialize" notice as `InitFailedView` (with the failed package keys and API), and drops queued mutations instead of holding them forever. |
| 4122634307 | FsceneRealizer.kt:1843 | FIXED | Confirmed: a doubleSided `d3:instances` snapshot taken while its KHR variant was compiling kept the base stand-in. When a variant lands, `onVariantCompiled` now also re-bakes every doubleSided instances node bound to that material (`redecodeDoubleSidedInstancesForMaterial`), recreating the duplicate from the variant instance. |
| 4122634320 | MaterialPackages.kt:36 | FIXED | Confirmed. The fixed vocabulary (base lit/unlit, trail, catcher, particles: a handful per API) stays process-lifetime. KHR variant packages (non-zero extension mask) now live in a 12-entry access-order LRU; an evicted variant recompiles in the background on its next use. |
| 4122634329 | Dart3dView.kt:1480 | FIXED | Confirmed: only `rawDt` honored the `lastFrameNanos == 0` sentinel, so a resume injected a 100 ms physics/animation/trail step. The general `dt` is now 0 on the sentinel frame as well, which also applies to the very first frame. |
| 4122634342 | ParticleRuntime.kt:1338 | FIXED | Confirmed: radial distance misorders laterally offset particles and anything under an ortho camera. The key is now view depth, `(p − camPos) · camForward` (the camera's world forward is passed into `tick`), mapped through an order-preserving float→int transform so negative depths sort correctly too. |

## PR #16 review, round 3 (Codex, 6 threads)

The branch is rebased onto `main` (1c3f961, PR #14 merged), with the
integration fixes cherry-picked from `origin/stabilize/integration`
(51ec9d3, 3673e02, 8aa13fa, e0c5b41, c115d3e, a6b8c1a, ab62511,
62b3a19). Green without devices: `compileReleaseKotlin`, JVM tests
34/34, `dn analyze` clean, `dn test` dart3d 273 / example 126.

| Comment id | File:line | Verdict | Draft reply |
|---|---|---|---|
| 4123023188 | FsceneRealizer.kt:3452 | FIXED (integration) | Right: the demo keys were authored for −Z. They now all aim through the shared `aimAlong` helper (`example/lib/light_aim.dart`), which points node +Z along the intended travel direction: cube, imported, feature and showcase keys in 51ec9d3, and the "keys travel with the camera" correction in a6b8c1a. Verified on the A142 and the iOS sim in the integration T2 run (`docs/triage/integration.md`). |
| 4123023200 | example/lib/dice_table_scene.dart:732 | FIXED (integration, stopgap) | Confirmed. The iOS directional intensities are now scaled by `kIosDirectionalScale` (SceneKit's 1000-per-unit vs Android's calibrated 10 lx/unit at Filament's default exposure) through `keyLightIntensity` (3673e02; showcase fill c115d3e). The direction stays corrected. Unifying the native unit mapping is tracked in `docs/triage/integration.md` as the real fix. |
| 4123023209 | Dart3dView.kt:3026 | FIXED | Confirmed. `applyUpsertPayload` now services every claimant: the instance rebake, geometry, skin and animation handlers each run when they claim the chunk. The "unclaimed" log fires only when none did, matching `applyPayload`'s binary path. |
| 4123023220 | FsceneRealizer.kt:1677 | FIXED | Confirmed. `destroyProcRenderable` now removes the entity's `(entity, slot)` pairs from `materialConsumers` before a rebuild re-registers them, so repeated payload rebakes no longer grow the list or cause repeated rebinds. |
| 4123023229 | MaterialPackages.kt:244 | FIXED | Confirmed: a throwing prewarm left `prewarmStarted` set with no cache or `failed` entry, so views polled forever. The catch now clears the marker and the waiting view's frame loop re-requests the prewarm. After 2 thrown attempts per API, the missing base packages are marked failed, which the view surfaces as its visible init-failure notice. |
| 4123023236 | Dart3dView.kt:1972 | FIXED | Confirmed. The journal now compacts as ops arrive. An `updateNode` drops earlier updates of the same node whose flags it covers. A `removeNode` drops the node's earlier updates, and cancels out entirely against a journaled `addNode` of that node when nothing journaled still names it as a parent. A one-time warning fires if the journal still reaches 2048 entries. |

## PR #16 review, round 4 (Codex, 6 threads)

The branch is rebased onto `main` with PR #15 merged. There was no
device use (the A142 is off-limits pending the operator). Green:
`compileReleaseKotlin`, JVM tests 34/34, `dn test` dart3d 273 /
example 126, `dn analyze` clean.

| Comment id | File:line | Verdict | Draft reply |
|---|---|---|---|
| 4124222987 | Dart3dView.kt:2059 | FIXED (P1, real) | Confirmed: `install()` swaps in the manifest's resource registries, and the journal held only structural ops. Top-level `upsertResource` ops are now journaled in arrival order, ahead of the structural ops that reference them. A later upsert of the same id supersedes the earlier entry, so replay restores op-created and replaced textures, materials, geometry and render targets before dependents resolve. |
| 4124223003 | Dart3dView.kt:2065 | FIXED (aligned with iOS, PR #15 r2) | The ordering problem is real, but moving the reload to the end breaks subtrees grafted under one of its members after the first load. As on iOS, a re-load keeps its first-load slot, and every top-level journal op after that slot that names a member of the re-loaded batch is pruned. The re-load superseded those ops live, so replay reproduces the re-loaded state without re-sequencing. |
| 4124223014 | Dart3dBridge.kt:84 | FIXED | Confirmed. `Dart3dView`'s `init` body is now wrapped: on any throw it releases the Choreographer callback, UiHelper, Jolt world and KTX2 provider, then calls `engine.destroy()` (which frees the renderer, scene, view, textures and materials the Engine still owns) before rethrowing to the bridge's `InitFailedView`. |
| 4124223024 | FsceneRealizer.kt:1680 | FIXED (P1, real) | Confirmed: `instancesProps` was assigned only after the transforms resolved, so a payload-backed node that decoded before its matrices chunk arrived was invisible to `redecodeInstancesForPayload`. The spec is now retained before transforms are resolved, so the chunk's arrival (binary `applyPayload` or `upsertPayload`) rebakes it. |
| 4124223033 | Dart3dView.kt:4316 | FIXED | Confirmed. A new `failTerminal()` path marks the view dead: it shows the on-screen notice, removes the frame callback, clears queued work, and makes `onMutation` reject later mutations (with a one-time error log). A later re-attach no longer restarts the loop. |
| 4124223041 | Dart3dView.kt:833 | FIXED | Confirmed. Loading the cached base packages into the Engine is now wrapped. On a throw, the already-loaded `Material`s are destroyed and the view goes through `failTerminal()` instead of crashing the UI thread from the Choreographer callback. During construction, the terminal path throws instead, so the bridge shows `InitFailedView`; state declared after `init` isn't initialized yet at that point. |

## PR #16 review, round 5 (Codex, 2 threads) + replay-path self-review

No device use. Green: `compileReleaseKotlin`, JVM tests 34/34, `dn test`
dart3d 273 / example 126.

| Comment id | File:line | Verdict | Draft reply |
|---|---|---|---|
| 4124448401 | Dart3dView.kt:2163 | FIXED | Confirmed: the reload member scan only read `node`, so a later top-level `upsertResource` for one of the batch's own resources survived and overwrote the reloaded definition on replay. The scan now collects the batch's node ids and its resource slots (the same latest-wins keys the journal uses for `upsertResource`/skins/animations). Later top-level ops on either are pruned. |
| 4124448417 | Dart3dView.kt:2128 | FIXED | Confirmed: `install()` re-applies the manifest `views`. `updateViews` is now journaled latest-wins, so replay restores the live camera, render-target, order and quality list. |

**Self-review: every command op against what a deferred-payload
re-realize (`realize` + `install`) resets.** The journal now holds two
kinds of entry. Structural ops (`addNode`/`updateNode`/`removeNode`,
compacted) and subtree loads replay in arrival order. Live-state ops
keep only their latest entry per target. Checked:

| Op | install() resets it? | Handling |
|---|---|---|
| addNode / updateNode / removeNode | yes (nodes rebuilt from the manifest) | journaled, compacted (rounds 3–4) |
| loadSubtree / unloadSubtree | yes | journaled, first-load slot plus member pruning (round 4, this round) |
| upsertResource | yes (registries replaced) | journaled latest-wins per id (round 4) |
| upsertSkin / removeSkin | yes (`resources.skins` replaced) | **journaled latest-wins per id (new)** |
| upsertAnimation / removeAnimation | yes (`resources.animations` replaced) | **journaled latest-wins per id (new)** |
| selectVariant | yes (`variantComponents` rebuilt from the manifest) | **journaled latest-wins per node (new)**; `removeNode` drops it |
| setMorphWeights | yes (renderables rebuilt at authored weights) | **journaled latest-wins per node (new)**; `removeNode` drops it |
| updateViews | yes (`applyViews(manifest views)`) | **journaled latest-wins (new, 4124448417)** |
| anim (play/pause/stop/time/timeScale/weight/loop) | yes (`animClips.clear()`) | **clip state carried across the re-realize (new)** rather than replaying op history, so playback time continues; dropped only if the animation no longer exists |
| updateStage | no | `realize(…, preserveStage = true)` re-decodes the live stage |
| upsertPayload | no | `payloadStore` persists; `opPayloadSpecs` merge back in `install()` |
| addJoint / updateJoint / removeJoint | no | `world.retainJointsForNodes(nodes.keys)` keeps command joints for surviving nodes. Not re-verified in this round |
| applyImpulse / applyTorque / setVelocity / clearForces | yes (bodies rebuilt at the manifest pose) | **not replayed, by design:** transient impulses against a pose that no longer exists. Losing dynamic body state on a re-realize is the known pre-existing limitation (Devin followups #1: "deferred-payload re-realize destroys live state"). Proper fix: preserve body poses/velocities across install (M). **Done in S0g** (`BodyCarry`; `docs/artifacts/s0g-physics-rerealize/`): the result of those impulses carries, so they still need no replay |
| setTransforms (binary message, not a command) | yes (nodes rebuilt at the manifest TRS) | **not replayed, same limitation:** live transform writes revert until the next write. Most producers (physics sync, camera rig) rewrite every frame. Fix together with the body state above (M) |
| query / render | no (read-only / one-shot) | nothing to replay |

## PR #16 review, round 6 (Codex, 4 threads)

No device use. Green: `compileReleaseKotlin`, JVM tests 34/34, `dn test`
dart3d 273 / example 126.

| Comment id | File:line | Verdict | Draft reply |
|---|---|---|---|
| 4127109903 | Dart3dView.kt:808 | FIXED | Confirmed: `failTerminal()` removes the callback, but the `doFrame` that called it then re-posted unconditionally. `doFrame` now re-arms only while the view is neither detached nor terminally failed. |
| 4127109916 | Dart3dView.kt:637 | FIXED | Confirmed. The eager property allocations that run before `init` (`createRenderer`/`createScene`/`createView`, `SurfaceView`, `UiHelper`, `JoltWorld`) now go through `guarded { }`. On a throw it frees the KTX2 provider and calls `engine.destroy()` (which also frees the objects it created), then rethrows. `createEngine()` itself allocates nothing on failure. |
| 4127109921 | Dart3dView.kt:2161 | FIXED | Confirmed: latest-wins compaction can move a render-target upsert behind the `updateViews` that depends on it. The (single, latest) `updateViews` entry now replays after every other journal entry and subtree. Nothing depends on views, and everything views resolve (targets, cameras) is restored by then. |
| 4127109932 | Dart3dView.kt:2154 | FIXED (P1, real) | Confirmed: `install()` pruned joints against the bare manifest node set, before replay re-created command-added nodes. During a deferred-payload re-realize the prune is now deferred until after the journal replay, and runs against the live node set. `JoltWorld` re-pends joints whose bodies were removed, and re-realizes them when the replayed nodes' bodies are added. A new document (`loadScene`) still prunes at install. |

**Round 6 and the surface lifecycle:** only the `doFrame` re-arm guard
touches the frame callback. It adds a stop condition (terminal or
detached) and changes nothing on the surface/swapchain path.

### Follow-up issue (not fixed here): Vulkan warm-relaunch crash

T2 on c679636 found that a Vulkan warm relaunch crashes ~60 ms after
resume in `Renderer.nBeginFrame` ("Cannot present in swapchain
error=-1000000000", i.e. `VK_ERROR_SURFACE_LOST_KHR`, plus "enumerate size
error"). origin/main crashes too, with `vkCreateAndroidSurfaceKHR
error=-1000000001` (`VK_ERROR_NATIVE_WINDOW_IN_USE_KHR`). My understanding
of the cause, not device-verified:

- `UiHelper.RendererCallback.onDetachedFromSurface` and
  `onNativeWindowChanged` call `engine.destroySwapChain()` and return
  immediately. Filament's destroy is **asynchronous**: the driver thread
  still holds the `VkSurfaceKHR`/`ANativeWindow` after
  `surfaceDestroyed` returns and Android tears the window down. Filament's
  Android samples call `engine.flushAndWait()` right after
  `destroySwapChain` in `onDetachedFromSurface` for exactly this reason.
- **On main:** the old view is released on detach, but its Engine's
  teardown hasn't finished when the new activity's view creates a surface
  on the same (or a recycled) native window. The window is still
  connected, which gives `NATIVE_WINDOW_IN_USE`.
- **On this branch:** detach only parks the view when `disposeView`
  exists. The first `beginFrame` after resume presents to a swapchain whose
  window Android already destroyed, which gives `SURFACE_LOST`. That
  happens either because the destroy was never flushed, or because a
  swapchain created in `onNativeWindowChanged` raced the old one's async
  destruction.
- **Proposed fix (S):** after each `destroySwapChain` in
  `onDetachedFromSurface`/`onNativeWindowChanged`, call
  `engine.flushAndWait()`. Also skip `render()` while `uiHelper` reports
  no valid surface. Verify with a Vulkan warm-relaunch loop on the A142.

**Resolved in S0g (#18).** The cause is confirmed on the device: a 0.3 s
Home → relaunch crashes the unfixed head on the first iteration. The fix
adds `flushAndWait()` after every swapchain destroy and skips `render()`
while there is no surface, and it passes 10/10 on Vulkan and GL. The drain
takes 34–239 ms, so the driver really was still holding the window. See
`docs/artifacts/s0g-vulkan-relaunch/logs.md`.

## Needs other owner

- **Dart (example): other hard-coded light rotations assume −Z emission.**
  `cube_scene.dart`, `imported_scene.dart` and `feature_scene.dart` ("key":
  axisAngle((0.7,0,0.7), −0.8)), plus `showcase_loader.dart` ("showcase.key":
  axisAngle((0.6,0.3,0.74), −0.85)). Rotating +Z by these gives a direction
  with **positive** y, so under the upstream +Z contract these keys shine
  upward on both platforms. Negate the angles, or aim them with a
  `fwd = dir` helper. They are outside the one file I was allowed to edit.
- **iOS: dice key light now blows out the table.** Verified on the sim with
  the `aimLight` fix (`ios-dice-after-aimfix.png`, debug build). The key
  now travels downward on iOS too; before the fix it pointed up and the
  table was lit only by the env and fill. The wood reads nearly white, so
  the 2400-unit SceneKit intensity is far hotter than Android's calibrated
  lux mapping. The direction is right, but iOS needs an intensity/exposure
  calibration for this scene. iOS / Dart owner.
- **Dice readout vs visible top face (pre-existing, not texture-related).**
  The numerals are geometry, so flipUV doesn't affect them. The initial
  layout and readout are identical to the pre-branch baseline screenshot.
  On both backends the d6, d8 and d10u readouts match the visible top face,
  but d12, d20 and d10t often don't. GL roll (`dice-roll-gl.png`): readout
  d12:6 d20:5 d10t:00, visible 8 / 8 / 40. Vulkan roll: readout d12:12
  d20:19 d10t:30, visible 11 / 19-ish / 40. Likely the Dart face table
  (`dice_faces.json`) or the pose hand-off (the z-mirror on returned
  quaternions) for those shapes. Needs the Dart owner, with an iOS
  comparison.
- **iOS twins of fixed Android threads:** GI field lerp (4054179790),
  instance payload rebake (4054413359), mirrored-instance winding
  (4062294020), `lutImages` cache bound (4054179783), particle
  pause/enable preservation (4058553357), per-view facing (4058581075).
- **Dart:** there is no native→Dart "view init failed" event. Android now
  shows the failure on screen and in logcat, but the Dart side can't
  react to it. Suggest a dispatch type (e.g. 6 = `viewError`) so
  `SceneController` can surface it.
- **Dart/iOS:** icosphere seam/pole vertex split (Dart f52e52d) is not
  mirrored on Android yet. Estimate S (~2 h): split in `MeshFactory.icosphere`.
- **Dash appearance: fixed in this branch** (efe9e3e, with the coordinator's
  investigation cherry-picked as 86ba43a, `docs/investigations/dash-materials.md`).
  Filament's MaterialBuilder defaults to `flipUV = true`, and the lit/unlit/variant
  packages never turned it off, so every UV-mapped texture sampled upside
  down. Encoded (PNG/JPEG) uploads also swapped R↔B, and now decode
  unpremultiplied. Verified on the A142: `dash-after-vulkan.png` and
  `dash-after-gl.png` show the orange beak and feet, blue body and green eye
  rings, matching iOS and upstream. The `logo` lane renders Flutter blue; the
  `glb` lane (`glb-after-vulkan.png`) shows the logo's true pink→orange→cyan
  hues, upright. The before shots are `dash-vulkan.png` / `dash-gl.png`.
  **Remaining difference:** the glb logo's transparent background is still
  black on Android (near-white on iOS), even with `inPremultiplied = false`.
  The PNG's alpha-0 texels probably carry black RGB, and the material is
  opaque, so iOS's white is the odd one out. Not investigated.
- **Materials lane (`DART3D_MODEL=materials`) renders fully black on the A142**
  (Vulkan). Also black on a 14:55 run before the flipUV patch. Its textures
  decode (`64x64 rgba8`, `ktx2 … ETC2_EAC_SRGBA8`) and there are no errors.
  I couldn't rebuild the pre-branch baseline to tell whether this is a
  regression (the checkout was blocked in this session). Needs an Android
  follow-up (S–M).

## Unverified / caveats

- **W24 shadow catcher lane:** the harness screenshots (GL, W24 phase)
  are too busy to confirm the catcher patch visually. What is verified:
  the catcher material compiles on both backends and nothing panics.
- **Replay journal:** verified by log count, not by visually diffing the
  +192 s harness emitters.
- **Particle fixes (turbulence mirror, sort, spin sign, pole-on):**
  compile-verified and reasoned against the Dart reference. Not visually
  diffed against iOS.
- **ANR:** the soak was ~4 min of scripted tab switching. The original
  report was ~3 ANRs per 50 min of interactive use, so a full 50-minute
  soak was not run.
- **Cold start:** on the first launch after install, the lit packages
  compile in the background (~10–12 s on the A142). The scene stays
  blank that long, but main is free. Later views in the same process
  load instantly.

## Deferred findings → issues

Every DEFER row above is tracked: W26 geometry (caps, `widthInPixels`,
closed sweeps, ribbon scale, iOS parity ports) → #20; per-view camera
facing → #21; iOS late-binding consumers → #22; particle pause/enabled
toggles → #23; Vulkan warm relaunch → #18.

# S0g native object lifetime — 2026-10-05

Branch `s0g-android-native-lifetime`. Measurements and device runs:
`docs/artifacts/s0g-android-lifetime/`.

## jolt-jni ownership audit

Rules, read from the 6.0.0 jar (`JoltPhysicsObject` and each class the
plugin touches):

- A wrapper owns native memory when it was given a freeing action
  (`setVirtualAddress(va, action)`). `close()` runs the action once;
  the Cleaner, where it runs, is a second caller of the same action.
- A wrapper built with a container (`super(container, va)`) or with a
  bare address is a view. It frees nothing and needs no `close()`.
- Ref-counted targets (`Shape`, `ShapeSettings`, `Constraint`,
  `ConstraintSettings`, `GroupFilter`) are co-owners: constructing the
  Java wrapper takes a reference, `close()` drops it. The native object
  dies when the last reference goes, so an unclosed wrapper pins it
  after the body that used it is destroyed.
- `ShapeSettings.create()` returns a `ShapeResult` (owner).
  `ShapeResult.get()` returns a `ShapeRefC` (owner) that carries a
  second co-owning `Shape` wrapper (`getPtr()`). One `create().get()`
  therefore makes three owners besides the settings.
- `Vec3`, `RVec3`, `Quat` and `VertexList` are plain Java.
  `CombineFunction` and `Body` wrap addresses they do not own.
- `PhysicsSystem` puts itself in a static map; only `forgetMe()` takes
  it out.

| Object | Where | Kind | Before | After |
|---|---|---|---|---|
| `BroadPhaseLayerInterfaceTable`, `ObjectLayerPairFilterTable`, `ObjectVsBroadPhaseLayerFilterTable` | `JoltWorld` fields | owner | closed in `close()` | same |
| `GroupFilterTable` | `JoltWorld` field | co-owner | closed in `close()`, but every leaked `CollisionGroup` held another reference | freed with the world |
| `PhysicsSystem` | `JoltWorld` field | owner | native freed; the Java wrapper stayed in jolt-jni's static map with the listener and the world | `forgetMe()` before `close()` |
| `TempAllocatorMalloc`, `JobSystemSingleThreaded`, `CustomContactListener` | `JoltWorld` fields | owner | closed in `close()` | same |
| `CombineFunction` ×2 | `JoltWorld` fields | view | nothing to free | same |
| `Body`, `ContactManifold`, `SubShapeIdPair` in the contact callbacks | per contact | view | nothing to free | same |
| `CollisionGroup` | one per body | owner | **never closed** | closed once the settings have copied it |
| Sub-group id in the group table | one per body | table slot | **never reused**: after 1024 bodies in one view the layer/mask filter was skipped | handed back on `removeBody` (`CollisionSubGroups`) |
| `BodyCreationSettings` | one per body | owner | **never closed**; also held a shape and a filter reference | scope |
| `BoxShape` (3 sites), `SphereShape`, `CapsuleShape`, `CylinderShape` | collider decode | co-owner | **never closed** | scope |
| `ConvexHullShapeSettings` (2 sites) | collider decode | co-owner | **never closed** | scope |
| `MeshShapeSettings` | collider decode | co-owner | **never closed** | scope |
| `IndexedTriangleList` | mesh collider | owner | **never closed** | scope |
| `IndexedTriangle` | one per triangle | owner | **never closed** | closed after `set` copies it |
| `StaticCompoundShapeSettings` | collider decode | co-owner | **never closed** | scope |
| `RotatedTranslatedShapeSettings` | collider `localPose` | co-owner | **never closed** | scope |
| `RotatedTranslatedShape` | `boundingBox` collider | co-owner | **never closed** | scope |
| `ShapeResult`, `ShapeRefC`, its inner `Shape` | 5 `create().get()` sites | owner ×3 | **never closed** | scope (`shapeOf`) |
| `MassProperties` from `massPropertiesOverride` | per body with a mass | view | nothing to free | same |
| `Body` | per body | view | removed and destroyed at node removal, component teardown, scene install; `destroyAllBodies` at release | same |
| `Fixed`/`Point`/`Hinge`/`Slider`/`SixDof` constraint settings | joint build | co-owner | closed after `create` | same |
| `MotorSettings` ×3, `SpringSettings` view | joint build | owner, view | closed | same |
| `Constraint` | per joint | co-owner | closed after `removeConstraint` | same |
| `Body.sFixedToWorld()` | world-anchored joint | view | nothing to free | same |
| `RRayCast`, `RayCastSettings`, `AllHitCastRayCollector`, `RayCastResult` | `raycast` | owner | closed | same |
| Hits from a collector | queries | view | nothing to free | same |
| `TransformedShape` | raycast normal | owner | closed, except when the leaf lookup threw | scope |
| Shape from `TransformedShape.getShape()` | raycast normal | co-owner | **never closed**: one pinned shape reference per ray hit | scope |
| Leaf shape from `getLeafShape` | raycast normal | co-owner | closed | scope |
| `AaBox`, `GetTrianglesContext` | raycast normal | owner | closed | scope |
| Probe `SphereShape`, `RMat44`, `CollideShapeSettings`, `AllHitCollideShapeCollector` | `normalProbe`, overlaps | owner | closed | same |
| `BoxShape`, `SphereShape`, `RShapeCast`, `ShapeCastSettings`, `ClosestHitCastShapeCollector` | overlap and shape cast | owner | closed | same |
| `Vec3`, `RVec3`, `Quat` in per-frame pose reads, impulses and velocity writes | per frame, per roll | plain Java | nothing to free | same |

Per frame and per roll the plugin creates no owning jolt-jni object,
before or after. That includes `pollJointBreaks`, which runs every
physics step and builds a `Vec3` and an `RVec3` per joint anchor in
`anchorWorld` (review thread 4159700728 on #44): both are final Java
classes with three number fields and no native peer, and
`Body.getPosition`/`getRotation` fill them through a thread-local
buffer. Everything that leaked did so per scene realize, and the dice
screen realizes twice per visit (the document, then again when its last
payload lands).

Also found while reading:

- **`JoltWorld.update` could not run on API 26 and 27** (review thread
  4159700734 on #44). It called `Reference.reachabilityFence`, which is
  API 28. R8 moves the call into an outline class, so the class loads,
  and the first physics step throws `NoSuchMethodError` (the release
  dex has the direct `invoke-static`; there is no backport). The eight
  calls now go through `Reachability.fence` (`Fenced.kt`), which checks
  the API level and falls back to a volatile store below 28.
  `:dart3d:lintRelease` reported exactly those eight `NewApi` errors
  and nothing else above API 26 in the module; it reports none now. No
  API 26 or 27 device was available: this is verified by the dex and
  by lint, not by a run.
- **`ShapeResult.get()` was called without checking the result.** On a
  rejected hull or mesh Jolt's `Result::Get()` reads the error string's
  bytes as a shape reference. `shapeOf` checks `hasError()` and logs
  Jolt's reason.

## Filament lifetime audit

Two questions per creation site: can the Java object be collected while
native code still uses its handle, and is the native object destroyed
on every path.

**Collected too early.** Read from the 1.71.6 jars: the classes with a
finalizer that frees native memory are every `Builder` (`Engine`,
`Texture`, `RenderTarget`, `RenderableManager`, `LightManager`,
`VertexBuffer`, `IndexBuffer`, `BufferObject`, `SkinningBuffer`,
`MorphTargetBuffer`, `Skybox`, `IndirectLight`, `ColorGrading`,
`Stream`), `ToneMapper`, filamat's `MaterialBuilder`, and
filament-utils' `Manipulator` and its builder. `Material.Builder` has
none. The engine-owned objects themselves (`Texture`, `Material`,
`MaterialInstance`, buffers, `View`, `Scene`, `Camera`, `Renderer`,
`SwapChain`, `ColorGrading`, `IndirectLight`, `Skybox`) have no
finalizer: losing the Java reference never frees them, so for those the
only question is the leak one.

Every builder's `build()` reads its native handle and then calls into
native code with nothing left to keep the Java builder alive, which is
the window the ColorGrading crash came through. How wide the window is
depends on how long the native call runs: microseconds for a texture or
a buffer, tens of milliseconds for a color grading LUT, roughly 100 ms
for `Engine.Builder.build()`, and 3–6 s for a filamat compile on the
background thread. All 30 remaining `build` calls now go through
`fenced { }` (`Fenced.kt`):

| Builder | Sites |
|---|---|
| `Engine.Builder` | `Dart3dView` ×2 |
| `Texture.Builder` | `EnvironmentFactory`, `TextureFactory` ×2, `RenderTargets` ×2 |
| `RenderTarget.Builder` | `RenderTargets` |
| `RenderableManager.Builder` | `Dart3dView`, `ParticleRuntime`, `FsceneRealizer` ×5 |
| `LightManager.Builder` | `FsceneRealizer` ×2 |
| `VertexBuffer.Builder`, `IndexBuffer.Builder` | `ParticleRuntime`, `FsceneRealizer` ×2, each |
| `SkinningBuffer.Builder`, `MorphTargetBuffer.Builder` | `FsceneRealizer` |
| `Skybox.Builder` ×2, `IndirectLight.Builder` | `FsceneRealizer` |
| `Manipulator.Builder` | `Dart3dView` |
| filamat `MaterialBuilder` | `MaterialPackages.compile` |

`ColorGrading.Builder` keeps the fence it got in #16 (it also has to
hold its `ToneMapper` and LUT buffer). `ToneMapper` is used nowhere
else. `Manipulator` stays in a field while attached and is freed by its
finalizer afterwards. Buffers handed to `setImage`, `setBufferAt` and
`setBuffer` were not changed: Filament's JNI layer is documented to
hold the buffer until the upload callback, and that was not re-verified
against the native library here.

The fence is `Reference.reachabilityFence` from API 28. On API 26 and
27 it is a volatile store, which no device here could exercise.

**The GPU probe's EGL reference** (review thread 4180998568 on #49).
`GpuProbe` called `eglInitialize` and never `eglTerminate`. Android's
libEGL counts initializations of the display
(`egl_display_t::initialize` does `refs++`, and `terminate` only tears
the display down for the last holder), so the probe held one reference
for the life of the process. It now calls `eglTerminate` once, after
restoring the previous context and destroying its own context and
surface, on every path past a successful initialize. Filament's OpenGL
backend and the system renderer hold their own references, and
Filament's own platform code pairs the two calls the same way when an
engine is destroyed.

**Never destroyed, or used after destroy.** Every `engine.create…`,
`Builder.build`, `EntityManager.create`, `MaterialInstance.duplicate`
and prefilter `run` was traced to its destroy on replacement, on
removal, on scene install and on view release. One engine exists per
view and `engine.destroy()` frees what is left, so only growth inside
one view's life counts. Fixed:

| Hazard | Path | Fix |
|---|---|---|
| A `rectAreaLight`'s four cluster entities and lights survived every scene install and the view release; they stayed in the scene, lighting the next document | `loadScene` or a payload re-realize on a document with a rect light | destroyed with their node in both sweeps (`destroyLightCluster`) |
| Upserting a material that a variant binding had applied left the destroyed instance on the renderable, and the next variant apply adopted it as the binding's default | `upsertResource` on a variant material, or its background variant compile landing, then deselecting the variant | the binding's slot is rebound to the fresh instance before the old one is destroyed |
| A `doubleSided` `d3:instances` node's duplicated material kept sampling a texture after a texture upsert destroyed it | texture or render-texture upsert, or a texture payload, on a texture that material samples | the duplicate is registered as a consumer of its source's textures and unregistered when destroyed |
| A released view kept its payload chunks, manifest, op journal and LUT buffers | any release; costs about 4.8 MB of Java heap per hero view for as long as anything references the view | `dropDocumentState()` at the end of `release` |

Traced and clean: the engine, renderer, scene, view, swap chain and
camera; the three fallback textures; the seven base materials, the
variant materials, the catcher and particle materials; the IBL
prefilter helpers; environment textures, skybox, indirect light and
color grading on re-apply; resource textures, render targets, material
instances and GPU meshes on upsert, install and release; node entities,
skinning buffers, trails, LOD renderables, proc and instance meshes;
sprite and mesh particle runtimes; per-view cameras and offscreen
views. No Filament object is created per frame.

Reported by the read-through and **not fixed** (each needs a document
the example does not produce, and none was reproduced):

- An id reused across resource kinds. Texture and render-texture ids
  share one key space: upserting a `texture` over a live render texture
  destroys the render target's color texture under it, and the reverse
  overwrites the plain texture without destroying it.
- Two components of one type on a node. A second `trail` overwrites the
  first's entity and buffers; a second `mesh` on a skinned node
  overwrites its `SkinningBuffer`.
- One geometry key in two primitive slots of a mesh, then a geometry
  upsert: only the first slot is rebound before the old buffers go.
- The camera entity id is not returned to the `EntityManager` when view
  construction fails.
- A throw between a create and its registration is not a leak path only
  because nothing catches it: the frame loop has no handler, so it ends
  the process.
- Not a lifetime issue, seen in passing: `install` clears
  `cameraFacing` after the fresh decode has filled it, so facing shapes
  declared in a manifest may lose their per-frame re-expansion after a
  `loadScene`. Not verified on a device.
