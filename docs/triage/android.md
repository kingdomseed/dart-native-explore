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
