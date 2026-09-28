# dart3d program v2 — stabilize, then finish the engine and ship

Supersedes the execution protocol and unit ordering of
`docs/full-engine-program.md` (W15–W34). The per-unit scope text in that
file stays the reference for *what* each remaining unit covers, except
where this file re-scopes it. Why the reset: see
`docs/program-audit-2026-09-28.md`.

## Goals

1. **Engine:** full parity with a *pinned* upstream `flutter_scene`
   surface — **final target flutter_scene 0.24 / scene 0.4**, reached
   through the 0.23.0 milestone below — on iOS and Android, with evidence a reviewer can re-check.
2. **Product:** a DartNative Mythic dice app on dart3d, using
   `mythic_dice_parser`, with the dice feel the operator asked for.
3. **Release:** dart3d published on dartpub.dev as the first 3D plugin.

## Decisions (made here, change only with the operator)

| # | Decision | Why |
|---|---|---|
| D1 | **Two-stage parity pin.** Milestone: flutter_scene 0.23.0 / scene 0.3.0, commit `0dc6ee80` (bdero/flutter_scene), `.fscene` v5, `.fsceneb` v2 — finish the existing work (Tracks S, E) against this first. **Final goal: flutter_scene 0.24 / scene 0.4** (Track V), pinned to the published 0.24.0/0.4.0 tags when they ship; until then unreleased master (`b02c99989`, 2026-09-27) is the preview reference. | The old plan cited a `/tmp` monorepo that no longer exists; "parity" had no fixed target. |
| D2 | **Keep SceneKit on iOS for now; run a time-boxed Filament-on-Metal spike (S1) before W28.** | SceneKit is soft-deprecated (WWDC25) but the iOS 27 SDK carries no deprecation annotations. A single Filament renderer would collapse the iOS halves of W28/W20/W31 into the Android implementation, but costs a rewrite of SceneKit-provided pieces (particles, floor mirror, physics via Jolt C++). Decide with data, not now. RealityKit is ruled out (weaker shader control, no decal/planar primitives). |
| D3 | **Upgrade Filament 1.71.6 → 1.77.2+ in lockstep (filament-android, filament-utils-android, filamat-android, gltfio-android) once 1.77.2 is on Maven;** replace CPU-baked instancing with GPU instancing. | `RenderableManager.Builder.instances(n)` + `getInstanceIndex()` already works in the Java API; Java `InstanceBuffer` lands in 1.77.2. Unblocks W31 and mesh particles. Materials recompile automatically (runtime filamat). |
| D4 | **Mirror upstream vocabulary; invent `d3:` extensions only where upstream has no wire form**, and model them on upstream's runtime API. | Keeps `.fscene` interchange. Applies to W19 (upstream `CharacterController` codec exists → use it, drop the invented `characterMove` op) and W27 (`DecalNode` is runtime-only upstream → `d3:decal` modeled on it). |
| D5 | **Audio ships as a sibling package `dart3d_audio`,** not in the core plugin. | Filament has no audio; Android needs its own backend (Oboe/AAudio). Keeps the core small; mirrors upstream's split (soloud/fmod packages). |
| D6 | **W33 splits:** W33a external textures and W33b semantics proceed; W33c widget-to-texture is blocked on DartNative (no offscreen widget capture) — file a feature request upstream. | DartNative renders widgets as native views; no `toImage`, `RepaintBoundary` is a no-op. |
| D7 | **Out of scope:** upstream `kit/` (day-night, water, joystick, third-person, steering, spawners…), editor/MCP, networking. These are app-level on top of dart3d. | The old Appendix B was silent on them. |
| D8 | **In scope, newly added:** camera controllers + pointer picking (U1), Wedge/Ring/Extrude + spot shadows + shadow-catcher bake (U2; 0.23.0 ships `spot_shadow.dart` only — point-light shadows are 0.24, V3), rendering extras (U3: selection outline, iOS tone-mapper selection, sprites + texture atlas), animation property resolver (U4). | Upstream 0.23.0 surface no unit covered; picking and orbit cameras are also what the dice app and demos need. |
| D9 | **Out of scope as engine parity:** upstream declarative widgets (`widgets/declarative.dart`, `render_texture_view.dart` — Flutter-widget API, replaced by dart3d's own `SceneView`/`SceneController` on DartNative) and upstream profiling (`memory_report.dart`, `render_profile.dart` — Impeller-internal; dart3d exposes native stats instead, tracked in E9 debug views). | They describe the host framework, not the scene contract. |

**Open for the operator (defaults apply unless changed):**

- **O1 — the no-demo rule.** Default: *lift it for Track P only.* Engine
  units still don't polish the showcase, but the dice app and demo run in
  parallel with Track E instead of waiting for the engine to close.
- **O2 — device budget.** Default: the A142 and the iPhone 17 Pro sim are
  the gate devices; the iPad is optional coverage.

## Verification gate (replaces the 10-lane swarm)

The old gate (10 live lanes + perf + operator video per unit) was never
actually run, so merges happened on tests alone while the plan's boxes
stayed empty. The new gate is smaller and mandatory.

| Tier | When | Required evidence |
|---|---|---|
| **T1 — CI** | every PR | `dn analyze` + `dn test` in **every Dart package the PR changes** (`dart3d/`, `dart3d/example/`, and each new package such as `dart3d_audio/` or the dice app gets its own CI step when it is created). Target (R3): add Android `compileReleaseKotlin` and iOS `swiftc -typecheck` jobs. |
| **T2 — device smoke** | every PR touching `dart3d/android/**`, `dart3d/ios/**`, or the wire vocabulary | On A142 **Vulkan and GL** and on the iOS sim: app boots, harness runs to completion, dice roll and settle, zero FATAL/crash in logs. One screenshot per surface + log excerpt, committed under `docs/artifacts/<unit>/`. |
| **T3 — feature lanes** | every unit | The unit's own live checks, same evidence rules: the subset of its old "Verify, live" block that exercises new behavior, or for units new in v2, the checks listed under **New-unit T3** below. |
| **T4 — review** | units that change what users see | Operator reviews screenshots (video optional) in the PR before merge. |
| **Perf** | only units that claim a perf number | The measured number, device, and method, committed. |

Rules:

- Evidence lives in the repo (`docs/artifacts/<unit>/`, small PNGs + text
  logs; videos via release assets), never only in `/tmp`.
- If a device is unavailable, the PR says so explicitly and stays **draft**
  until T2 runs. No merge without T2 for native changes.
- Every automated review thread (Codex / Devin Review) gets a verdict
  (fixed / won't-fix + reason / deferred + issue) in the PR before merge.
- A new head after verification needs T1 + T2 again, **and T3 again for every lane whose covered behavior the new diff can affect** (when in doubt, re-run it). Only diffs that provably can't touch a lane (docs, unrelated platform) may reuse its evidence, and the PR says which lanes were reused and why.
- `docs/verification-matrix.md` gets a row per merged unit, pointing at
  its evidence.

### New-unit T3

| Unit | Required live checks (A142 Vulkan + GL, iOS sim) |
|---|---|
| E1 Filament upgrade + GPU instancing | W26 instancing lanes render identically to pre-upgrade screenshots; 10k-instance scene frame time measured before/after; W18 particles + W22 materials lanes unchanged; no material compile errors on either backend |
| U1 cameras + picking | orbit/fly/follow each driven by gestures with screenshots at 3 poses; tap-to-pick returns the expected node id on 5 targets incl. a skinned mesh and an instanced mesh |
| U2 geometry + shadows | Wedge/Ring/Extrude render with correct normals (lit from 2 angles); spot-light shadows visible on a receiver; catcher bake mode shows a baked patch |
| U3 rendering extras | selection outline on a picked node; each iOS tone-mapper visibly distinct; sprite atlas frames advance |
| U4 property resolver | a clip animating a material color and a light intensity plays on both platforms |
| V0 re-pin | the published tags' `.fscene`/`.fsceneb` versions recorded; every 0.24 example `.fscene` loads in dart3d's Dart mirror with no unknown-component warnings except those assigned to V1–V6 |
| V1 wire fields | a document using each new field round-trips through `serializeScene`; each `shadowCastingMode` value visibly differs on both platforms; each supported SMAA setting produces a visible edge difference (zoomed crop) or a renderer diagnostic confirming it applied, on A142 Vulkan, A142 GL and iOS — unsupported settings log a warn-once and are listed as limits |
| V2 ortho | an upstream 0.24 ortho-camera example matches upstream framing (screenshot overlay); splats sort correctly under ortho (after W31) |
| V3 point shadows | a point light casts shadows onto a floor and a wall from an occluder on both platforms |
| V4 decals | the upstream 0.24 decal example renders with correct projection and fade; a `d3:decal` document from E7 still loads (migrated or aliased) |
| V5 `.fmat` | an additive-blended material, a depth-write-off material, a depth-test-off material (draws over an occluder) and an unlit engine-input material each render as in the upstream example; a material without a precision qualifier compiles at mediump on both platforms (compiled-shader dump or diagnostic) and a highp-requiring case still renders correctly; a malformed `.fmat` surfaces its diagnostics |
| V6 runtime | 64 point lights render without per-light cost cliffs (frame time recorded); sun sweep with progressive prefilter holds frame budget; spatial audio pans with the camera; character yaw follows movement; every 0.24 debug-view mode dart3d supports renders its channel on both platforms (one screenshot per mode) |
| V7 breaking changes | a written map of each upstream breaking change to the dart3d behavior (changed / not applicable), with one test per changed behavior |
| V8 conformance | every example in the published 0.24 corpus screenshotted on A142 Vulkan, A142 GL and iOS sim next to the upstream render, pass/fail per example in `verification-matrix.md` |

## Tracks and order

### Track S — stabilize (S0 blocks Tracks E and R; S1 blocks only E6)

- [x] S0a Repo hygiene + CI (PR #12)
- [ ] S0f Move `docs/artifacts/w30-review.mp4` (57 MB) and the root `DartNativeX-*.mp4` to GitHub release assets and link them; history rewrite to reclaim clone size is an operator decision (force-push)
- [ ] S0b P1 fixes + review-thread triage — `stabilize/android`,
      `stabilize/ios`, `stabilize/dart`; triage tables in `docs/triage/`
- [ ] S0c **Verification backfill** at one head after S0b: T2 + the key
      T3 lanes for W15, W16, W18, W22, W23, W24, W25, W26, W29 on both
      platforms; update `verification-matrix.md`
- [ ] S0d Doc truth pass: `extended-surface-audit.md`,
      `environment-ibl-spec.md`, `texture-material-spec.md`, README
      exclusions; mark `full-engine-program.md` superseded
- [ ] S0e Android `disposeView` teardown (new DartNative hook) if not done
      in S0b
- [ ] S1 **Renderer spike** (≤ 3 days): Filament 1.77 on iOS Metal
      rendering the dice table + one showcase asset; measure binary size,
      frame time, integration cost. Output: go/no-go on D2.

### Track E — engine (after S0, one unit at a time per platform owner)

| Order | Unit | Scope notes vs the old plan | Size | Depends |
|---|---|---|---|---|
| E1 | **Filament upgrade + GPU instancing** (new) | D3. Re-run the full W26 + W18 lanes afterward. | L | 1.77.2 on Maven |
| E2 | **U1 camera controllers + picking** (new) | Orbit/fly/follow controllers, `scene_pointer` hit tests (BVH or native hit test). | M | — |
| E3 | **W17 sky / environment** | Generate the equirect natively, not in Dart (Dart per-pixel scatter won't hit the A142 budget). Rate-limit IBL re-prefilter on sun sweeps. | M–L | — |
| E4 | **W19 character controller** | Upstream `CharacterController` codec (D4); Android `CharacterVirtual` + `CustomCharacterContactListener` in plain Kotlin (jolt-jni ≥ 6.0.0); iOS sweep-and-slide. | L | — |
| E5 | **U2 geometry + shadow breadth** (new) | Wedge/Ring/Extrude; spot-light shadows (point shadows are the 0.24 delta, V3); shadow-catcher bake mode. | M | — |
| E5b | **U3 rendering extras** (new) | Selection outline, iOS tone-mapper selection, sprites + texture atlas. | M | E2 |
| E5c | **U4 animation property resolver** (new) | Animate non-transform properties (material, light, camera params). | M | — |
| E6 | **W28 shader contract** | Prototype first. Scope after S1: one translator (Filament only) or two (Filament + SceneKit modifiers). | XL | S1 |
| E7 | **W27 decals** | `d3:decal` modeled on upstream 0.24 `DecalNode` (D4); rides W28. | L | E6 |
| E8 | **W20 environment volumes** | Filament: one IndirectLight per scene → camera-in-volume switching is the ceiling; accept `SCNFloor` mirror on iOS if S1 = no-go. | XL | E3, E6 |
| E9 | **W34 debug views + dev reload** | iOS sim first (Dart `dart:io` watch + `dn run` reload); Android via host watcher + `adb reverse` push (release-only engine). Shader hot reload lives in W28, not here. | M–L | — |
| E10 | **W33a external textures / W33b semantics** | Android: ACQUIRED `Stream` (NATIVE is deprecated); iOS: AVPlayer as material contents. W33c blocked (D6). | M + M | — |
| E11 | **W32 audio → `dart3d_audio`** | D5. iOS SCNAudio/AVAudioEngine; Android Oboe. | L | — |
| E12 | **W31 splats** | Needs E1. CPU sort + index re-upload on Android unless a C++ path is accepted. Target count set by a measurement, not assumed. | XL | E1 |

### Track P — product (parallel with E if O1 = lift)

- [ ] P1 Define the parser → scene contract (`parse → RollSpec → outcome`)
      in `mythic_dice_parser`; decide physics-outcome vs parser-outcome
      reconciliation (recommended: physics picks faces, parser evaluates
      the expression over the rolled faces).
- [ ] P2 DartNative dice app shell (`dn create`), wired to the parser and
      dart3d. Replaces the example's dice tab as the dice product.
- [ ] P3 Dice feel, from the 09-17 feedback: pick-up-and-toss roll,
      labeled Reset, table follows screen aspect (edges = glass walls,
      survives pan), in-app quality picker (auto by device + override),
      iPad white screen root cause.
- [ ] P4 Demo app (**depends on E2** for the orbit controller): curated showcase (not test lanes) with a stage,
      orbit camera, side-by-side reference against flutter_scene demos;
      3D animated DartNative logo centerpiece (Blender).

### Track V — 0.24 parity (final goal; after Track E closes on 0.23.0)

Scope = the upstream delta from `0dc6ee80` to the published
flutter_scene 0.24.0 / scene 0.4.0 tags. Before starting, re-diff the
published tags (master is 200+ commits ahead and still moving) and
re-cut this list; items below are from the 2026-09-27 master preview.

- [ ] V0 Re-pin to the published 0.24.0/0.4.0 tags; diff `packages/scene`
      (wire) and `packages/flutter_scene` (runtime) changelogs; confirm
      `.fscene` stays v5 or add the migration.
- [ ] V1 Wire additions: `Node.shadowCastingMode`, SMAA fields, any new
      codecs; both natives + Dart mirror.
- [ ] V2 Orthographic reconciliation: `projection:"orthographic"` already
      realizes on both platforms (W6; `verification-matrix.md` rows 21,
      133). Scope is only what 0.24 changes — any new ortho camera
      fields/API in scene 0.4, the `Lighting` projection scale/offset
      semantics (shared with V7), and splat sorting under ortho once W31
      lands.
- [ ] V3 Point-light shadows — new in 0.24 (0.23.0 has spot shadows only, covered by U2); cube/omni shadow maps on Filament and SceneKit.
- [ ] V4 Decals against the published `DecalNode` contract — reconcile
      E7's `d3:decal` extension with upstream (migrate or alias).
- [ ] V5 `.fmat` additions (W28 follow-up): `blending: additive`,
      `depth_write`/`depth_test`, unlit `engine_inputs`, compile
      diagnostics, mediump default.
- [ ] V6 Lighting/runtime semantics: froxel-clustered lights (light-count
      scaling on both platforms), progressive radiance prefilter (W20
      follow-up), spatial audio following the view camera
      (`dart3d_audio`), character `rotatesToMovement`/`yaw` (W19
      follow-up), debug views (W34 follow-up).
- [ ] V7 Breaking-change audit: `Lighting` projection scale/offset
      (replaces `tanHalfFov`), `initializeStaticResources()` throwing —
      map to dart3d equivalents or record as not applicable.
- [ ] V8 Conformance: run the 0.24 example corpus through dart3d on both
      platforms; T3 evidence per item.

### Track R — release (after S0; before first publish)

- [ ] R1 Package hygiene: podspec `:ios, '15.0'`, `publish_to` removed,
      package-level tests under `dart3d/test/`, CHANGELOG, LICENSE check.
- [ ] R2 Verify `dn plugin build` for a view plugin on the current `dn`
      (DartNative issue #19 says fixed; `plugin_development.md` says not).
- [ ] R3 CI: Android Kotlin compile + iOS Swift typecheck jobs (macOS).
- [ ] R4 Consumer build test: a fresh `dn create` app depending on dart3d
      by path, then by git, resolves Filament/jolt-jni and builds both
      platforms.
- [ ] R5 Publish to dartpub.dev (operator signs in; GitHub-backed).

## Operating rules

- One PR per unit, branch `s<N>-<slug>` / `e<N>-<slug>` / `p<N>-<slug>` /
  `r<N>-<slug>` / `v<N>-<slug>` (by track),
  base `main`, the operator merges.
- Platform owners keep disjoint file boundaries (`dart3d/ios/**`,
  `dart3d/android/**`, `dart3d/lib/**` + `example/**`, `docs/**`).
  New trees get their own owner when created: `dart3d_audio/**` (E11,
  split by its own ios/android/lib the same way), the dice app
  (`apps/mythic_dice_dn/**` or wherever P2 creates it), and
  `mythic_gme_apps/packages/mythic_dice_parser/**` (P1 — a separate repo
  with its own PR flow and CI).
- Delete the branch after merge; the head is tagged `archive/<branch>`
  first if it carries unsquashed history worth keeping.
- The program's state lives in this file's checkboxes and
  `verification-matrix.md` — not in agent-local orchestration folders.
