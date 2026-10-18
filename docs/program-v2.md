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

## Definition of done (operator, 2026-10-02)

dart3d is finished when all four hold. Nothing else is scheduled before
they do — **no side quests until the engine is done**: no new demos,
look-dev, dice polish or design passes; an idea that is not on this list
goes into the backlog, not into a branch.

1. **Engine at the 0.24 standard.** Tracks S, E and V closed: the API
   surface and behavior match flutter_scene 0.24 / scene 0.4 on both
   platforms, with evidence, and it holds frame rate on the low-end
   device (Fire tablet).
2. **An API a real app can adopt.** One pass over the public Dart API for
   naming, defaults, errors and lifecycle; a fresh app can add dart3d and
   show a lit, loaded model in a few lines (R6, R4).
3. **Agent skills that match upstream's.** flutter_scene ships six
   (`idioms`, `kit`, `looks`, `performance`, `procedural`,
   `verification-loop`), an installer (`dart run flutter_scene:skills`)
   and a test that compiles every snippet. dart3d ships the equivalents
   for what it implements (R7).
4. **Docs that make it clear.** README, a getting-started path, per-area
   guides and a CHANGELOG, written for someone who has never seen the
   repo (R8).

## Where we are (2026-10-05)

**Landed since the reset.** S0a/b/e/f, the Vulkan relaunch fix, the P4
hero (#31), `switchAnimation` (#34), the Track V re-cut (#37; upstream
0.24 is still unpublished), and the example's dice experience through
DR2 with the DartNative set (#36, #38–#42).

**Sidelined.** The P2 game rooms (Blender look-dev) stopped after round
3 and stay on `p3-game-rooms-wip` (operator, 2026-10-02). The operator's
brother continues them on his own from the scripts; no agent work is
planned there. Nothing in dart3d depends on them. What dart3d does need
from look-dev — the DartNative set's spec and reference renders — is on
`main` (`docs/design/dice-lookdev.md`, `docs/design/dice-lookdev/`).

**Next, in order.** Engine first, then release. Product work waits.

1. **Stabilize** — S0h cold start is closed: material packages ship
   precompiled and are cached on disk. First frame, first launch /
   later launches: A142 0.57 / 0.52 s (was 11.2 s), Fire tablet 1.25 /
   0.89 s (was 18.1 s), Wacom tablet 0.83 / 0.56 s
   (`docs/artifacts/s0h-cold-start/`,
   `docs/artifacts/s0-three-device-baseline/`). Next: S0g and the S0c
   backfill. Fire tablet baseline: `docs/artifacts/s0-fire-tablet-baseline/`.
   Frame rate (S0j): a third device, the Wacom DTHA116 (Mali-G57 MC2,
   8 GB), ran the dice at 13 fps because the tier was picked by memory.
   The tier is now picked by GPU name first, then memory (#49): dice racked / rolling are 44 / 44
   fps on the Fire tablet, 51 / 44 on the Wacom and 50 / 50 on the
   A142. Open from that: 60 fps at rest is not reached on either
   tablet, the low profile's shadows are hard, LOW always takes OpenGL
   although Vulkan is faster on the Wacom, and only two rows of the GPU
   table are measured.
   Open from the tablet run: dice at an edge can still cover the rim
   line.
   Native lifetime (S0g, #50): before #50 the app ran out of Java heap
   after 22 visits to the dice screen on the Fire tablet. #50 closes
   every jolt-jni object it creates (22 sites leaked per scene load),
   fences all Filament builders and frees a released view's document;
   50 visits and 200 rolls then complete. **Memory per visit is still
   not flat in the app**: DartNative's view registry keeps the hero
   screen's view tree (its scroll view's content is never
   unregistered), and the Dart heap grows about 7 MB per visit for a
   reason not yet found. With the scroll view out, the native heap
   ends +4.4 MB after 50 visits against +18.5 MB on `main`
   (`docs/artifacts/s0g-android-lifetime/`).
   Physics across a re-realize (S0g, in review, branch
   `s0g-android-physics-rerealize`): bodies keep their motion and sleep
   state on Android, and the harness's W25 settle lane passes for the
   first time (`docs/artifacts/s0g-physics-rerealize/`). On iOS the
   two ordering fixes have now run (2026-10-05, below); carrying body
   state across a re-realize is still not built there.
   Look parity (S0g, in review, #57, branch `s0g-look-parity`): one
   document now gives the same picture on the iPhone simulator and
   the A142 within a stated tolerance, measured patch by patch on a
   reference board, and the example has no per-platform numbers left.
   Eleven causes were found and fixed, most of them on iOS (linear
   colours read as sRGB, colour textures sampled undecoded, no tone
   mapper, a different bloom), two in what the wire's numbers meant
   (light units, a gradient sky dimmed by the environment on
   Android). What does not match, and why, is listed for S1 in
   `docs/artifacts/s0g-look-parity/`.
   iOS debt (2026-10-05, `docs/artifacts/ios-debt-2026-10/`): one
   simulator is allowed again, and everything merged on Android
   evidence since 2026-09-29 ran on it — hero, Showcase, the harness
   to completion, and the dice lanes. Three defects found and fixed:
   the dice table was built on the UI isolate (the background build
   threw), the dice cast no shadows on iOS (SceneKit's 100-unit shadow
   range and single shadow sample), and blended meshes cast none at
   all (each die showed its logo's shadow instead of its own).
2. **S1 renderer spike**, then **Track E** in its table order (E1 → E12).
3. **Track V** — the 0.24 delta, re-pinned when upstream publishes.
4. **Track R** — API pass, consumer build, agent skills, README and
   docs, publish.

Not every open S0 box blocks Track E or R: S0d is folded into R8 (so
it is exempt from Track R's "after S0"), S0c is
backfilled as each lane's unit is touched, and the S0g look-parity
items (light units, colour saturation) are in review (#57). The rest
of S0 does block E.

**Paused until the engine is done.** P3 DR3 and later (notation, audio,
juice; DR3 needs P1's parser contract first), P5 demos, P7 design pass,
and anything in P2. P6 (Dash/fcar
replacements) stays tied to R5 because publishing needs it.

**Verification debt.** The operator re-enabled one iOS simulator on
2026-10-05 (physical iOS devices, the iPad and Android emulators stay
off). Evidence for everything below: `docs/artifacts/ios-debt-2026-10/`.

*Paid on the iPhone 17 Pro simulator (iOS 27, debug):*

- T2 for main `63fe903` and for the branch that carries the fixes:
  hero, dice, Showcase (materials, glb, playground, fcar, dash) and
  the harness to its last lane, with no crash or exception line.
- The dice lanes owed by #36 and #38–#42: readout against the face
  shown (10 rolls, 70 of 70 dice), the d4 turn and re-read, the
  cocked nudge, numerals, the logo, and culling parity for #39 (no
  far-side faces through the shells).
- Gestures: aim, hold-and-toss and sweep, driven by scripted touch
  paths.
- #45: the tray refits and the dice are read again on a rotation from
  portrait to landscape, and a landscape roll reads correctly.
- #52: both iOS ordering fixes ran — every dice load logs the restore
  and the first physics tick is at the fitted rack.
- `s0g-ios-dynamic-body-reseat` (#55): ran with and without it, with
  the verdict "merge"; it merged on 2026-10-05.

*Still owed:*

- **Rotation from landscape back to portrait** on iOS. Not run: it
  needs the operator to rotate the simulator, or a rotation method
  they have approved (Xcode 27 has no Simulator.app and `simctl`
  cannot rotate).
- **A finger.** Every gesture so far, on both platforms, is a scripted
  path; the fling velocity on iOS came from the app's own estimate,
  never from the platform.
- **A physical iOS device.** Everything above is the simulator: no
  frame-rate number, no TAA (skipped on the simulator by design), no
  real GPU.
- **#39 on the OpenGL backend** (Android) — unchanged by this run.
- **Body state across a re-realize on iOS** — not built.
- **The blended-mesh shadow stand-in on skinned, morphed or
  camera-facing meshes** — left out of the fix; such a mesh still
  casts nothing on iOS. The stand-in also writes camera depth, so
  depth of field through a blended mesh reads the mesh's surface.
- **The look on a physical iOS device** (#57). Look parity was
  measured on the simulator only: its screenshots are 8-bit sRGB and
  its SceneKit hands the resolve pass an 8-bit image. A device with a
  P3 display and a different drawable format has not been looked at.
- **KTX2 colour textures on iOS** (#57): they load through a different
  call than the one found to ignore its sRGB option, and were not
  measured.

**Review.** Codex code review is out of quota; PRs since #36 were
reviewed by an Opus reviewer agent, each finding checked against the
code before fixing (verdicts are in the PR comments). Codex's inline
comments on #44–#49 got their verdicts on 2026-10-05, in the two S0g
PRs and in `docs/artifacts/s0-codex-followups/`.

## Decisions (made here, change only with the operator)

| # | Decision | Why |
|---|---|---|
| D1 | **Two-stage parity pin.** Milestone: flutter_scene 0.23.0 / scene 0.3.0, commit `0dc6ee80` (bdero/flutter_scene), `.fscene` v5, `.fsceneb` v2 — finish the existing work (Tracks S, E) against this first. **Final goal: flutter_scene 0.24 / scene 0.4** (Track V), pinned to the published 0.24.0/0.4.0 tags when they ship; until then unreleased master is the preview reference — `b473543a`, 2026-09-30, per V0 (the tags are not published; release branch `bdero/release-0.24` @ `168fad28` is a stale candidate). | The old plan cited a `/tmp` monorepo that no longer exists; "parity" had no fixed target. |
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
| **T2 — device smoke** | every PR touching `dart3d/android/**`, `dart3d/ios/**`, or the wire vocabulary | On A142 **Vulkan and GL**, on the Fire tablet (KFTUWI, Mali-G52), on the Wacom tablet (DTHA116, Mali-G57, the weak-GPU/large-memory case; baseline in `docs/artifacts/s0-three-device-baseline/`), and on the iOS sim (one simulator, re-enabled 2026-10-05; see *Verification debt*): app boots, harness (booted with `--dart-define=DART3D_SCENE=harness`; it has no UI entry) runs to completion, dice roll and settle, zero FATAL/crash in logs. One screenshot per surface + log excerpt, committed under `docs/artifacts/<unit>/`. |
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
  Check the **inline** threads (`gh api --paginate …/pulls/<n>/comments`), not only
  the PR conversation: #43–#49 merged with 30 Codex inline comments
  unanswered because only the conversation was read. They were triaged
  afterwards (verdicts on each thread).
- **iOS** (operator, 2026-10-05): one simulator is allowed again, one
  booted on the Mac at a time (`AGENTS.md` §Devices), so the iOS half
  of T2 is back. **When the simulator is not available** (another
  project has it, or the operator pauses it as on 2026-09-30): T2 is
  the Android half
  in full — A142 on Vulkan *and* OpenGL, the Fire tablet and the Wacom
  tablet, each with the harness. A diff that touches `dart3d/ios/**` is
  type-checked against the simulator SDK. **Every** PR that skips the
  normal iOS T2 or T3 — an iOS diff, a shared Dart or wire change, or an
  Android-only change whose parity needs an iOS look, as #39's culling
  did — says "not run on iOS" in the PR and adds a line to
  *Verification debt*. All of that debt is paid on
  device before R5; a change whose iOS behavior cannot be reasoned about
  from the Android run waits for iOS instead of merging.
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
| V1 wire fields | a document using each new field round-trips through `serializeScene`; a stage with default TAA/SMAA fields realizes the scene 0.4 defaults natively (V7-4, logged values on both platforms); each `shadowCastingMode` value visibly differs on both platforms; each supported SMAA setting produces a visible edge difference (zoomed crop) or a renderer diagnostic confirming it applied, on A142 Vulkan, A142 GL and iOS — unsupported settings log a warn-once and are listed as limits |
| V2 ortho | the upstream ortho smoke scene (`examples/smoke_render/lib/smoke_scenes.dart:1648`, the only upstream ortho fixture) matches upstream framing (screenshot overlay); each `orthographicSize` mode frames as upstream at two aspect ratios; a document using the legacy `orthoScale` still realizes; a perspective and an ortho scene with an off-center projection offset and non-unit scale light identically to upstream (screenshot overlay of lit surfaces, or a renderer diagnostic printing the applied scale/offset); splats sort correctly under ortho (after W31) |
| V3 point shadows | a point light inside an open-front box of receivers with occluders on all six axes casts a shadow on every face (±X, ±Y, ±Z), on A142 Vulkan, A142 GL and iOS |
| V4 decals | the upstream decal smoke scene (`smoke_scenes.dart:1969`) renders with correct projection and fade; the E7 `d3:decal` fixture still renders with its original projection box and fade (screenshot matches its E7 evidence) on every backend |
| V5 `.fmat` | an additive-blended material, a `depth_test: always` material (draws over an occluder) and an unlit engine-input material each render as in the upstream example; a material without a precision qualifier compiles at mediump on both platforms (compiled-shader dump or diagnostic) and a highp-requiring case still renders correctly; a malformed `.fmat` surfaces its diagnostics; `default_black`/`default_transparent` samplers read black/transparent while unset; each master-only key in the V5 table that ships in the published tag gets one fixture |
| V6 runtime | light scaling: frame time at 64 point lights ≤ 1.5× the 8-light frame time on A142 Vulkan and iOS, and a large mesh reached by 64 lights shades all of them; spatial audio pans with the camera; a tick listener runs before every fixed step and fly-camera move intent drives the camera; every 0.24 debug-view mode dart3d supports renders its channel on both platforms (one screenshot per mode) |
| V5b DICOM (port outcome only) | a float data texture uploads exactly — verified by **numeric readback** of a known r32Float test pattern (native test hook: Metal `getBytes` / Filament `Texture` readback into a float buffer, compared per texel within 0 ULP), not by rendered colour (shader precision, 8-bit output and colour conversion could mask corruption) on A142 Vulkan, A142 GL and iOS; upstream's DICOM example renders MPR, MIP and DVR matching the upstream render (screenshot per mode per platform) with window/level and transfer-function changes visible |
| V6b screen distortion | a shockwave pulse modeled on upstream's dice VFX (`examples/flutter_app/lib/dice/dice_vfx.dart:466-471`; no dedicated fixture exists) pulses visibly on A142 Vulkan, A142 GL and iOS, matching the upstream render (screenshot pair per platform) |
| V7 breaking changes | a written map of each upstream breaking change to the dart3d behavior (changed / not applicable), with one test per changed behavior |
| V8 conformance | every example in the published 0.24 corpus screenshotted on A142 Vulkan, A142 GL and iOS sim next to the upstream render, pass/fail per example in `verification-matrix.md`; V8 closes only when every example passes, or a failure is re-classified as an explicit, operator-approved exclusion — any other failure keeps V8 open |

## Tracks and order

### Track S — stabilize (S0 blocks Tracks E and R; S1 blocks only E6)

- [x] S0a Repo hygiene + CI (PR #12)
- [x] S0f Videos out of git: `w30-review.mp4` is a release asset
      (`docs/artifacts/README.md`); the third-party DartNativeX clip was
      removed (kept locally, not republished); history rewritten 2026-09-29 to
      drop both plus the old `.cxx` build output
- [x] S0b P1 fixes + review-thread triage — PRs #14 (Dart), #15 (iOS),
      #16 (Android); 7 Codex review rounds, every thread verified and
      answered; triage tables in `docs/triage/`; every deferred finding
      is tracked in an issue (#18, #20–#23)
- [ ] S0c **Verification backfill** — *partial.* Done: Android T2 (A142 Vulkan + GL) on the rewritten
      lineage — PR #25's smoke (harness, ROLL, Showcase) on a branch cut from
      main `4e12ef3`, merged as `ab861c7` (`docs/artifacts/s0g-vulkan-relaunch/`) (`docs/triage/integration.md`
      §Final T2). iOS T2 closed on main `4e12ef3` (ROLL-button roll +
      settle and a Dice/Showcase/Harness tab storm, 0 error lines —
      `docs/artifacts/integration/final/ios-main/`). Still open: the key T3 lanes for W15, W16, W18, W22, W23, W24,
      W25, W26, W29 on both platforms; update
      `verification-matrix.md`
- [ ] S0d Doc truth pass: `extended-surface-audit.md`,
      `environment-ibl-spec.md`, `texture-material-spec.md`, README
      exclusions; mark `full-engine-program.md` superseded
- [x] S0e Android `disposeView` teardown (in #16)
- [ ] S0g Stabilization follow-ups (`docs/triage/integration.md`
      §Follow-ups): **#18 Vulkan warm-relaunch crash (P1)**; dice readout
      (inverse quaternion + mirrored face normals — root cause confirmed);
      ~~native light-unit unification (then delete the example's iOS 0.26
      scale)~~; ~~iOS colour saturation vs Android~~; root-cause the Mali page
      fault behind the catcher/particle prewarm and restore it; ~~audit the
      remaining Filament builder sites for the GC-reachability hazard~~;
      ~~W25 settle lane never passes after wLoose~~; ~~body
      poses/velocities across deferred re-realize (M)~~ on Android.
      *Android native lifetime — landed* (#50, 2026-10-05). Done: the jolt-jni ownership
      audit and deterministic close of every owner (`NativeScope`;
      nothing relies on the Cleaner, which API 26–32 lack); collision
      sub-group ids reused instead of running out after 1024 bodies;
      `JoltWorld.update` no longer calls an API 28 method on API 26–27
      (from the dex and lint, not run); the GPU probe gives back its EGL
      display reference; all 31 Filament builder sites fenced;
      three Filament destroy-order hazards fixed (rect-light cluster
      entities, a variant binding's default after a material upsert, a
      doubleSided duplicate after a texture upsert); a released view
      drops its document. Measured on the Fire tablet (API 30): `main`
      dies of `OutOfMemoryError` at visit 22; the branch completes 50
      visits and 200 rolls; rolls are flat; frame rate unchanged on all
      three devices (A142 on Vulkan and on forced OpenGL). **Open:**
      per-visit growth in the app from two
      causes outside the plugin's native code (the framework's view
      registry holds the hero's view tree; the Dart heap grows about
      7 MB per visit, cause unknown); a native slope under about 0.1 MB
      per load is not excluded; no API 26/27 device; four Filament
      hazards that need unusual documents are listed, not fixed
      (`docs/triage/android.md` §S0g native object lifetime). Evidence:
      `docs/artifacts/s0g-android-lifetime/`
      *Physics across a re-realize — in review* (2026-10-05, branch
      `s0g-android-physics-rerealize`). Done on Android: kinematic and
      dynamic bodies keep pose, linear and angular velocity and sleep
      state across a payload-arrival re-realize (`BodyCarry`); the
      harness's W25 dice close-out passes and wLoose settles by event
      (the breakable joint's box had been in free fall since its joint
      broke, and the close-out used a random throw that can leave the
      slab). Also the #45 review threads: a rejected `addNode` or
      `updateNode` no longer drops a saved transform (both natives),
      iOS restores in two passes. T2 on all three devices, A142 on
      both backends. The two iOS ordering fixes ran on 2026-10-05, and
      `s0g-ios-dynamic-body-reseat` (#55) merged the same day after
      running there. **Open, iOS:** the body state (described, not
      built). Evidence: `docs/artifacts/s0g-physics-rerealize/`
      *Look parity — in review* (#57, 2026-10-05). The wire's light,
      environment and exposure numbers mean what upstream's do on both
      natives (`docs/android-parity-spec.md` §Light units); iOS
      resolves its image in a pass of its own (inverse of SceneKit's
      curve, Filament's bloom, upstream's grading, tone map, vignette
      and LUT); the example's iOS light scale, `heroIos` /
      `heroAndroid` and per-platform environment intensity are
      deleted. Measured on a reference board
      (`DART3D_SCENE=lookref`, `tool/look_capture.sh`,
      `tool/look_compare.py`): every patch class is inside its
      tolerance (8 of 255 unlit, emissive, textured and sky; 16 lit,
      spheres, lights and shadow) in all 12 variants, from a baseline
      of up to 255. **Open:** the residual list in the README (the
      environment's diffuse term, highlights through Filament's grade
      table, shadow filtering, `agx` / `reinhard` on Android, colour
      grading and vignette on Android unmeasured), a physical iOS
      device, and three Android findings not fixed here: point and
      spot lights clipped to a cross under an orthographic camera,
      lights fading out toward 100 units from the camera, and
      `bloomThreshold` having no effect. Evidence:
      `docs/artifacts/s0g-look-parity/`
- [x] S0h Android cold-start material compile — **done** (#48; tablet
      run 2026-10-05). Root cause: filamat's SPIR-V optimizer, 3–6 s
      per lit package, run on the device at every cold start. Fix:
      packages are named by a hash of their recipe and the Filament
      pin, shipped as assets (the plugin's fixed set of 20; an app can
      add its variants) and cached on disk, with the runtime compile as
      the fallback. First frame, first launch / later launches: A142
      11.15 s → 0.57 / 0.52 s; Fire tablet 18.1 s → 1.25 / 0.89 s
      (targets: under 3 s and under 1.5 s); Wacom tablet 0.83 / 0.56 s.
      The hero's clear-coat variant is on the first frame instead of
      swapping in at 14 s. APK +1.0 MB. Tables and what stays open:
      `docs/artifacts/s0h-cold-start/`,
      `docs/artifacts/s0-three-device-baseline/`
- [ ] S0j Low-end Android frame rate — #47 and the GPU-aware tier
      (#49) landed. Measured with
      the `dart3d.perf` log lane (frame intervals, Filament GPU time,
      physics). #47: the frame log, Jolt stepping on the calling
      thread, and a low-end device profile (PCF shadows, FXAA, dynamic
      resolution, OpenGL) picked when no `SceneQuality` is set; Fire
      tablet dice 8.7 → 44 fps racked and 8.8 → 43 fps rolling, hero
      34 → 55 fps (`docs/artifacts/s0-tablet-frame-rate/`). The tier
      was picked by memory, and the Wacom DTHA116 (Mali-G57 MC2, 8 GB,
      1440×2200) showed the gap: 13 fps on the dice screen through the
      standard pipeline. Now the GPU's name, read from the GL driver
      before the engine is built, is checked against a short table of
      fill-rate-bound families, with memory as the fallback: Wacom dice
      13 → 51 fps racked and 13 → 44 fps rolling; Fire tablet (44 / 44)
      and A142 (50 / 50, standard tier, Vulkan) unchanged. Open: 60 fps
      at rest on the tablets; hard shadows on the low profile; LOW
      always takes OpenGL although Vulkan runs the low pipeline faster
      on the Wacom; only Mali-G52 and Mali-G57 are measured rows.
      Tables: `docs/artifacts/s0-three-device-baseline/`
- [x] ~~S0i Reduced motion~~ — **not planned** (operator, 2026-09-29):
      reduced motion is an app-level concern, not the dart3d package's, and the
      example is a motion showcase. DartNative exposes no reduced-motion signal
      anyway; apps built on dart3d can add their own if they need it.
- [ ] S1 **Renderer spike** (≤ 3 days): Filament 1.77 on iOS Metal
      rendering the dice table + one showcase asset; measure binary size,
      frame time, integration cost. Output: go/no-go on D2.

### Track E — engine (after S0, one unit at a time per platform owner)

| Order | Unit | Scope notes vs the old plan | Size | Depends |
|---|---|---|---|---|
| E1 | **Filament upgrade + GPU instancing** (new) | D3. Re-run the full W26 + W18 lanes afterward. | L | 1.77.2 on Maven |
| E2 | **U1 camera controllers + picking** (new) | Orbit/fly/follow controllers, `scene_pointer` hit tests (BVH or native hit test). | M | — |
| E3 | **W17 sky / environment** | Generate the equirect natively, not in Dart (Dart per-pixel scatter won't hit the A142 budget). Rate-limit IBL re-prefilter on sun sweeps; also carries the progressive-prefilter check moved from V6 (upstream [#422](https://github.com/bdero/flutter_scene/pull/422) is the reference). Added T3: during a sun sweep no frame exceeds 33 ms on A142, and captures at 3 intermediate steps converge to the full-prefilter reference. | M–L | — |
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

Demo plan and upstream mapping: `docs/design/demo-program.md` (operator
decisions in §8). Principle: today's harness lanes and dice table are
scaffolding, not the demo.

- [ ] P1 Parser → scene contract (`parse → RollSpec → outcome`): physics
      picks faces, `mythic_dice_parser` evaluates over them
      (`PreRolledDiceRoller`) for rolls whose dice are known up front.
      **Exploding/reroll expressions** (e.g. `4d6!`) need an extra physical
      throw mid-evaluation, which requires `CallbackDiceRoller` to become
      async in `mythic_dice_parser` — an explicit P1 dependency; until it
      lands, P3 scopes explode/reroll to the pre-rolled fallback (extra dice
      rolled virtually, shown after). No extraction/package split planned.
- [ ] P2 **Standalone dice-roller app** — dice rolling only, mobile only,
      built on dart3d, operator's portfolio (possibly published free or
      paid). Separate project. Carries the **11 themed sets + environments**
      from look-dev (`docs/design/dice-lookdev.md`, branch
      `p3-dice-lookdev`) and a **cinematic intro**: start in a side camera
      view exploring the themed environment, fly to the table, then roll
      top-down. Starts after the example's dice experience reaches DR3.
      **Game rooms (look-dev, Blender only)** on `p3-game-rooms-wip`:
      round 2 rebuilt all 11 rooms from the Codex concept images with
      ~100 modeled props (`tool/dice_lookdev/assets/`, built by Codex
      `gpt-6-astra`); every set passes the readability gate in its
      top-down play view. Round 3 fixed defects (a curved cut-out
      behind the tray, dark bands, gate headroom) and gave six rooms a
      second art pass. **Sidelined 2026-10-02:** the density/wear/
      atmosphere and window-backdrop passes are not scheduled; the
      operator's brother continues the rooms independently from the
      scripts. How the rooms would reach real time is undecided.
- [ ] P3 **Dice experience in the example** — the demo's main experience:
      a **DartNative-themed dice set** with really fluid rolls (operator,
      2026-09-30). Phases DR1–DR5 (demo-program §5): readout fix +
      screen-fitted walls + labeled Reset → aim/toss/sweep → notation +
      count-up + audio → juice → polish. Rules for every set: numbers
      always super readable (contrast gate), top-down play camera, no
      tetrahedron d4 (crystal-shard d4), and **the environment never
      distracts from the dice** (subdued/defocused surroundings; dice are
      the brightest, sharpest element).
      Includes the 09-17 feedback (pick-up-and-toss, walls = screen
      edges, quality picker, iPad white screen).
      **DR1 (foundation)** — merged #36: readout fix,
      crystal-shard d4 (procedural, look-dev geometry), screen-fitted
      walls + ceiling in the frustum planes (safe areas, rotation),
      top-down 35° camera at 15% d20, labeled Reset, upstream physics
      numbers; A142 evidence `docs/artifacts/p3-dr1/`; iOS device check
      pending.
      **DR2 (the throw)** — merged #38: d4 numerals read along
      the crystal and the d4 turns upright after settling; cocked-die
      detection (per-die tolerance, catches d20 edge-rests) + physical
      nudge, read at the next settle; aim arrow (420 px pull, colour/
      width ramp, dissolve) → Poisson cluster spawned off-screen behind
      the arrow through an opened gate wall, ballistic lift, end-over-end
      spin, per-die spin retune; long-press pick-up to a hover plane +
      fling toss; sweep from a die. Input is `GestureDetector` on the
      scene view (`Listener` hides/doesn't reach it on Android). A142
      evidence `docs/artifacts/p3-dr2/`; iOS device check pending.
      **DartNative set** — merged #39: the example's dice
      are the look-dev DartNative set, built procedurally in Dart
      (`dice_polyhedra.dart` geometry + numbering, `dice_numerals.dart`
      atlas from Inter outlines, `dice_set.dart` mesh/material): smoky
      frosted translucent shell, the P4 logo inside each die held level
      as a soft glow, near-white numerals in dark keylines; d20 at 21%
      of the short side; deep-indigo felt tray with the gradient rim.
      Real-time gaps (both documented, smallest honest approximation):
      no refraction/blur — the frost is alpha-blended smoke on both
      natives (SceneKit has no refraction; Filament screen-space
      transmission untried to keep one path), so the logo reads sharp
      but dim rather than frost-blurred; dart3d's Android blended
      variants didn't cull back faces (far side showed through the
      numerals) — fixed natively (explicit `CullingMode.BACK`). Two
      point lights hung the A142's GPU (Vulkan, 60 s frames) — not
      used. A142 evidence `docs/artifacts/p3-dartnative-set/`; iOS
      device check pending.
      Operator tweaks after #39: no dark band behind the numerals (#40);
      every numeral fits inside its face's inlay, one size for one-digit
      and one for two-digit numerals per die (#41); no dot by the 9, the
      6 keeps its dot (#42).
      **Next: DR3** — notation + count-up + audio. Open with the
      operator: the indigo table may still read as black; the toss needs
      a real-finger check.
- [ ] P4 Hero launch scene + 3D DartNative logo. Logo landed (#26).
      Hero (M0) landed on `p4-hero-scene` (#31; spec
      `docs/design/hero-scene-brief.md`; `lib/hero_screen.dart`,
      `hero_scene.dart`, `hero_motion.dart`; evidence
      `docs/artifacts/p4-hero/`). Interim orbit is Dart-driven (one
      pivot transform per frame) until E2's orbit controller lands.
      The per-platform `DnLogoStage.heroIos`/`heroAndroid` stopgap is
      gone (#57): one `DnLogoStage.hero`.
- [ ] P5 Demo program M2–M18 (demo-program §4 + §8): showroom, physics
      playground, road trip, campfire, explosions, material gallery, …;
      engine-gated demos follow their units. New flagships: **M16 pirate
      ship on water** (E6) and **M17 Frankfurt street-corner diorama with a
      streetcar** (OSM footprints + Blender + Kenney; never commit the
      private address), and **M18 steampunk feudal-Japan
      diorama** (inspired by Owlcat's trailer; original art only).
- [ ] P6 License-clean replacements for Dash and fcar before any public
      demo build (Kenney CC0 / Khronos samples / own Blender models).
- [ ] P7 Full UI design pass with Claude Design — at the END of the demo
      work.

### Track V — 0.24 parity (final goal; after Track E closes on 0.23.0)

Scope = the upstream delta from `0dc6ee80` to flutter_scene 0.24.0 /
scene 0.4.0. Re-cut by V0 on **2026-09-30** against the upstream state
below; each item carries its upstream PR/commit, size, the dart3d files
it touches, its Track E dependency, and whether it is in the release
candidate (**RC✓**) or only on master (**master-only**).

**V0 findings (2026-09-30):** checked with `gh api repos/bdero/flutter_scene/{tags,releases,branches}` and the pub.dev API.

- **0.24.0 / 0.4.0 are not published.** Newest tags and releases:
  `flutter_scene-0.23.0` and `scene-0.3.0`, both at
  `0dc6ee8062a4aaaffb2d1f91e3aeb3005d5b54e4` (released 2026-08-25).
  pub.dev latest is `flutter_scene 0.23.0` and `scene 0.3.0`.
- **Release candidate:** branch `bdero/release-0.24` @
  `168fad28f0d6ffb871f204da72d63d1a826ce8f1` (2026-09-14; version bumps
  in `0806665e` "Prepare the 0.24 release train"). It forks master at
  `160464d3` ([#404](https://github.com/bdero/flutter_scene/pull/404)) and is 3 commits ahead and 156 behind master. It is
  stale: nothing merged after 2026-09-15 is in it (ortho cameras,
  display-referred surfaces, progressive prefilter, spatial-audio
  follow, the #437 `.fmat` hooks).
- **Scope reference:** master HEAD
  `b473543a654281ecb9e9882dd651e12202eee576` (2026-09-30, [#437](https://github.com/bdero/flutter_scene/pull/437)),
  274 commits ahead of `0dc6ee80`. Its pubspecs still say 0.23.0/0.3.0,
  and both CHANGELOGs have an open `## 0.24.0` / `## 0.4.0` section.
  The old preview ref `b02c9998` (2026-09-27) is superseded.
- **What was diffed:** `packages/scene` (18 files, +2088/−84);
  the codecs in `packages/flutter_scene/lib/src/fscene/realize/`
  (`builtin_codecs.dart`, `ui_codecs.dart`, `stage.dart`, `realize.dart`,
  `resource_realizer.dart`; `physics_codecs.dart`, `audio_codecs.dart`,
  `particle_emitter_codec.dart` and `render_extras_codecs.dart` are unchanged);
  `packages/flutter_scene/lib/src/fmat/fmat_parser.dart`; both CHANGELOGs.
- **`.fscene` stays v5 and `.fsceneb` stays v2, so no migration is needed.**
  At `b473543a`: `currentFsceneVersion = 5`
  (`packages/scene/lib/src/scene_document.dart:9`) and `kFscenebVersion = 2`
  (`packages/scene/lib/src/binary/fsceneb.dart:44`). The migration
  list (`_migrateV1ToV2` … `_migrateV4ToV5`) and `supportedFeatures`
  (`skinning`, `prefabInstances`, `streaming`, `renderTextures`) are
  unchanged. Every 0.4 addition is an optional key, and the writer omits
  it when it holds its default. One default *value* changed: TAA (V7-4).
- **Runtime-only in 0.24:** `DecalNode`, `Scene.screenDistortion`,
  `Scene.debug`, `Node.renderOrder` and `shadowCasterChannelMask` on spot
  and point lights. None of them has a codec on master, so the D4 rule
  (`d3:` extension modeled on the runtime API) applies to each one dart3d realizes.
- **Next step:** when the tags ship, diff `flutter_scene-0.24.0` against
  `b473543a` and amend this list. V0 stays open until then.

Sizes: S ≤ 1 day, M ≤ 1 week, L ≤ 3 weeks, XL > 3 weeks.
"Natives" = `dart3d/ios/Classes/FsceneRealizer.swift` +
`dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt`
unless the row names other files.

**Plan corrections found by V0** (the list below already applies them):

| Old item | Verdict | Evidence |
|---|---|---|
| V2 "ortho already realizes (W6)" | **Wrong key set.** dart3d realizes ortho from an invented `orthoScale`/`orthographicScale` (SceneKit half-height). Upstream 0.23 had no ortho: its camera codec offered `options: ['perspective']` only. 0.24 standardizes different keys. | `FsceneRealizer.swift:4841-4844`, `Dart3dView.kt:3095-3101`, `RenderTargets.kt:139-141`; upstream #411 |
| V2 / V7 "Lighting projection scale/offset" | **Not in the RC** (master-only), and it is no dart3d concern: `Lighting` is flutter_scene's shader-uniform helper. `tanHalfFov` has no hits in `dart3d/`. | V7-1 |
| V4 "migrate or alias to the published `DecalNode` contract" | **No wire contract exists.** `DecalNode` is runtime-only on master: no codec, and nothing in `packages/scene`. E7's `d3:decal` stays. V4 shrinks to an API-shape check and folds into E7 acceptance. | `lib/src/decal.dart` (master) |
| V5 `depth_write` | **Already in 0.23.0.** `fmat_parser.dart:565` at `0dc6ee80` parses it, so it belongs to E6/W28. Only `depth_test` is new. | — |
| V5b DICOM | **Not a 0.24 delta.** `examples/flutter_app/lib/example_dicom.dart` and `assets/dicom_volume.fmat` exist at `0dc6ee80`. It is a 0.23.0-corpus decision; the checkpoint text stands. | `git ls-tree 0dc6ee80` |
| V6 progressive radiance prefilter | **Already covered by E3.** It fixes flutter_scene's own Impeller prefilter, and it is master-only. dart3d prefilters natively (Filament `libs/iblprefilter`, see `EnvironmentFactory.kt:34`; SceneKit on iOS), and E3 already scopes "rate-limit IBL re-prefilter on sun sweeps". The hitch check moves to E3's T3. | #422 |
| V6 character `rotatesToMovement`/`yaw` | **Out of scope (D7).** It lives on `ThirdPersonControllerComponent` in `lib/src/kit/character/third_person_controller.dart`, and no codec carries it. It is kit, not the `KinematicCharacterControllerCodec` that W19 mirrors (that codec is unchanged in 0.24). Dropped. | #385 |
| V6 spatial audio, V6b distortion | Master-only / RC✓ respectively; neither has a wire form (see rows). | — |
| *missing* | Added: V1c TAA default change, V1d `displayReferred`, V1g unknown-data preservation, V1h `editor` block, V1i `-split<N>` hints, V3 point-shadow codec fields, V5 master-only `.fmat` keys, V6f tick listeners + fly move input, V6g runtime additions triage. | rows below |

**Items:**

- [x] **V0 Re-diff** (this section). Re-open to re-diff when the tags ship.
- [ ] **V1 Wire additions** (scene 0.4 + codec keys; Dart mirror + both natives)

  | # | Upstream delta | PR / commit | Size | dart3d files | Depends | RC |
  |---|---|---|---|---|---|---|
  | V1a | Bump `scene: ^0.3.0` → `^0.4.0` once published; round-trip every new key through `serializeScene` | — | S | `dart3d/pubspec.yaml`, `lib/src/diff_apply.dart` (`readFsceneWithExtensions` :484, `writeFsceneWithExtensions` :592), `test/scene_codec_fixture_test.dart` | — | — |
  | V1b | Node `shadowCasting`: `off` / `on` / `doubleSided` / `shadowsOnly` (`NodeSpec.shadowCastingMode`, prefab override path `shadowCasting`) | [#372](https://github.com/bdero/flutter_scene/pull/372) [`7406d661`](https://github.com/bdero/flutter_scene/commit/7406d661) | M | natives: node decode + `updateNode` path; `lib/src/protocol.dart` (flag list) | E5 (spot receivers to check against) | RC✓ |
  | V1c | Stage `effects.smaa` {`threshold`, `maxSearchSteps`, `maxDiagonalSearchSteps`, `cornerRounding`}; TAA and SMAA tuning now reach the scene, and the **TAA spec defaults changed** (V7-4) | [#372](https://github.com/bdero/flutter_scene/pull/372) [`0da324c5`](https://github.com/bdero/flutter_scene/commit/0da324c5) | S | `ios/Classes/StageEffects.swift` (:231-239 TAA defaults), `android/.../StageEffects.kt` (:277-293). Neither Filament nor SceneKit has SMAA: `RenderTargets.kt:326` already logs `smaa` as having no Filament knob, and iOS `RenderTargets.swift:677` maps only none/msaa. So: parse, warn once, list as a limit | — | RC✓ |
  | V1d | Unlit material resource `displayReferred` (draws past the tone curve); `widget` component `displayReferred` (default true) | [#419](https://github.com/bdero/flutter_scene/pull/419) [`b5bc75cc`](https://github.com/bdero/flutter_scene/commit/b5bc75cc) | M | natives: unlit material decode (`android/.../MaterialPackages.kt`, `FsceneRealizer.swift` material path). The widget half is blocked with W33c (D6) | — | master-only |
  | V1e | `PointLight` shadow keys: see V3 | #372 | — | — | — | RC✓ |
  | V1f | Camera ortho keys: see V2 | #411 | — | — | — | master-only |
  | V1g | Unknown-data preservation: `readFscene`/`writeFscene` keep unknown keys, unknown value objects, unknown `.fsceneb` chunks (`UnknownValue`, `UnknownChunk`) | [#423](https://github.com/bdero/flutter_scene/pull/423) [`7ef3b7c2`](https://github.com/bdero/flutter_scene/commit/7ef3b7c2), [`eaec5e26`](https://github.com/bdero/flutter_scene/commit/eaec5e26) | S | `lib/src/diff_apply.dart` and `lib/src/compose_extensions.dart` exist because 0.3 drops `d3` keys: re-test them, and simplify where 0.4 now keeps the keys. `lib/src/fsceneb_reader.dart:126` already skips unknown chunks | — | master-only |
  | V1h | Document `editor` block (`EditorStateSpec`: camera pose, selection) | [#372](https://github.com/bdero/flutter_scene/pull/372) [`b3bd6f60`](https://github.com/bdero/flutter_scene/commit/b3bd6f60) | S | Editor is out of scope (D7). The natives read named top-level keys only (`FsceneRealizer.swift:42-80`, `.kt:448-476`), so the block is ignored. Needs a Dart round-trip test only | — | RC✓ |
  | V1i | `-split<N>` node-name mesh split hints (`applyMeshSplitHints`, `splitTriangleMeshByGrid` in scene 0.4) | [#372](https://github.com/bdero/flutter_scene/pull/372) [`673a0bb2`](https://github.com/bdero/flutter_scene/commit/673a0bb2) | S | optional: `lib/src/glb_import.dart` / `lib/src/gltf/fscene_emitter.dart` call the scene 0.4 helper | — | RC✓ |

- [ ] **V2 Orthographic cameras.** [#411](https://github.com/bdero/flutter_scene/pull/411)
      ([`1fa830b2`](https://github.com/bdero/flutter_scene/commit/1fa830b2), [`1a3a8fce`](https://github.com/bdero/flutter_scene/commit/1a3a8fce)). **M. master-only.** Depends: — (E12 for splat sorting).
      Upstream `camera` codec keys: `projection: "orthographic"` plus
      `orthographicNear` (signed, default 0), `orthographicFar` (1000),
      `orthographicSize` (`height`|`width`|`contain`|`cover`|`stretch`|`pixelsPerUnit`),
      `orthographicWidth`/`orthographicHeight` (full extents, default 10),
      `orthographicPixelsPerUnit` (32), `orthographicZoom` (1),
      `orthographicOffset` (vec2 lens shift, world units).
      dart3d work: map these onto `SCNCamera` and Filament
      `Camera.setProjection(ORTHO…)`. `pixelsPerUnit` and the fit modes
      need the view's logical size. Keep `orthoScale`/`orthographicScale`
      as a deprecated alias (half-height = `orthographicHeight / 2`).
      Files: `ios/Classes/FsceneRealizer.swift` (:4841-4844),
      `android/.../Dart3dView.kt` (:3095-3101), `android/.../RenderTargets.kt`
      (:139-141). Splats under ortho land after E12 (W31).
      The only upstream ortho scene is a smoke scene
      (`examples/smoke_render/lib/smoke_scenes.dart:1648`). No
      `flutter_app` example uses ortho.
- [ ] **V3 Point-light shadows.** [#372](https://github.com/bdero/flutter_scene/pull/372) ([`0da324c5`](https://github.com/bdero/flutter_scene/commit/0da324c5)). **M. RC✓.** Depends: E5.
      Upstream `pointLight` codec gains `castsShadow` (false),
      `shadowMapResolution` (512, power of two 64–4096), `shadowNear` (0.1),
      `shadowDepthBias` (0), `shadowNormalBias` (0.1), `shadowSoftness` (1),
      `shadowCasterFaces` (`front`). dart3d's light decode is shared across
      types, so `castsShadow` already reaches the builders for point lights:
      Filament `ShadowOptions` at `FsceneRealizer.kt:3496-3523`, SceneKit
      `castsShadow` at `FsceneRealizer.swift:4879-4893`. That path has never
      been device-verified for point lights. The other five keys are
      unmapped; dart3d reads its own `shadowRadius`. Runtime-only:
      `shadowCasterChannelMask` on spot and point lights, and the
      `shadowCasterOverflowCount` diagnostics.
- [ ] **V4 Decal contract check.** [#369](https://github.com/bdero/flutter_scene/pull/369) ([`6b45aeb0`](https://github.com/bdero/flutter_scene/commit/6b45aeb0)). **S. RC✓.** Depends: E6, E7.
      There is no wire form to migrate to (see corrections). Diff E7's `d3:decal` against
      `DecalNode`: its `.fmat` material, `fade`, `project()`,
      `boxTransform()`, and the decal-inverse and fade parameters. Record
      differences in E7's PR. Fold into E7 acceptance if they match.
- [ ] **V5 `.fmat` additions** (W28 follow-up). **XL total. Depends: E6.**
      dart3d has no `.fmat` translator yet: `FsceneRealizer.swift:6229` and
      `FsceneRealizer.kt:5149` log `fmat` skies as unsupported. Every
      row lands in E6's translator(s).

  | Key / behavior | PR / commit | Size | RC |
  |---|---|---|---|
  | `blending: additive` | [#369](https://github.com/bdero/flutter_scene/pull/369) [`5d7be2ae`](https://github.com/bdero/flutter_scene/commit/5d7be2ae) | S | RC✓ |
  | `depth_test: less_equal \| always` (translucent pass) | [#369](https://github.com/bdero/flutter_scene/pull/369) [`6b45aeb0`](https://github.com/bdero/flutter_scene/commit/6b45aeb0) | S | RC✓ |
  | Unlit `engine_inputs`, `scene_color_reach`, `GetSceneWorldPosition` | [#369](https://github.com/bdero/flutter_scene/pull/369) [`d9ba0d92`](https://github.com/bdero/flutter_scene/commit/d9ba0d92) | M | RC✓ |
  | mediump fragment default, explicit highp (`shaders/PRECISION.md`) | [#401](https://github.com/bdero/flutter_scene/pull/401) [`5cf64816`](https://github.com/bdero/flutter_scene/commit/5cf64816), [`05d96e17`](https://github.com/bdero/flutter_scene/commit/05d96e17) | M | RC✓ |
  | Compile diagnostics with line numbers (`FmatCompileException.diagnostics`, `shaderSourceWindow`) | [#399](https://github.com/bdero/flutter_scene/pull/399) [`3cbb4f69`](https://github.com/bdero/flutter_scene/commit/3cbb4f69) | S | RC✓ |
  | `#include <wireframe.glsl>` barycentric helpers; `MaterialGroup` (Dart helper) | [#369](https://github.com/bdero/flutter_scene/pull/369) [`5d7be2ae`](https://github.com/bdero/flutter_scene/commit/5d7be2ae) | S | RC✓ |
  | `hint: default_black` / `default_transparent` sample black/transparent (were white) | [#441](https://github.com/bdero/flutter_scene/pull/441) [`85f47359`](https://github.com/bdero/flutter_scene/commit/85f47359) | S | master-only |
  | `effects_depth` | [#437](https://github.com/bdero/flutter_scene/pull/437) [`e2dfcd52`](https://github.com/bdero/flutter_scene/commit/e2dfcd52) | S | master-only |
  | `alpha_to_coverage` | [#437](https://github.com/bdero/flutter_scene/pull/437) [`838208c1`](https://github.com/bdero/flutter_scene/commit/838208c1) | S | master-only |
  | `directional_light: false`, `environment_lighting: false` | [#437](https://github.com/bdero/flutter_scene/pull/437) [`9b10e750`](https://github.com/bdero/flutter_scene/commit/9b10e750), [`8107ea58`](https://github.com/bdero/flutter_scene/commit/8107ea58) | S | master-only |
  | Lit `Light()` / `Ambient()` / `Composite()` hooks, per-light table row + shadow slot | [#437](https://github.com/bdero/flutter_scene/pull/437) [`c1aea187`](https://github.com/bdero/flutter_scene/commit/c1aea187), [`e2fff3e4`](https://github.com/bdero/flutter_scene/commit/e2fff3e4) | L | master-only |
  | `Vertex()` model transform; attribute-driven vertex stage runs in depth/shadow passes | [#437](https://github.com/bdero/flutter_scene/pull/437) [`4f0ca831`](https://github.com/bdero/flutter_scene/commit/4f0ca831), [`fe6c6512`](https://github.com/bdero/flutter_scene/commit/fe6c6512) | M | master-only |

- [ ] **V5b DICOM volume example: decision checkpoint** (operator,
      2026-09-29). This is **a 0.23.0-corpus item, not a 0.24 delta**
      (see corrections). It is excluded until E6 lands and **decided when E6 closes,
      before V5 starts.** Upstream's example is a capability showcase
      (private Flutter GPU internals, r32Float slice atlas + raymarch
      `.fmat`), not scene-contract behavior. Exactly one outcome, recorded
      here:
      - **Port:** V5b owns float data-texture upload (S–M) + the port, with
        its T3 row below; it lands before V8.
      - **No port:** the operator records a **renewed explicit exclusion**
        for V8. A dart3d-own showpiece may still be built as a demo, but it
        does not resolve DICOM for V8.
- [ ] **V6 Lighting and runtime semantics**

  | # | Upstream delta | PR / commit | Size | dart3d files | Depends | RC |
  |---|---|---|---|---|---|---|
  | V6a | Froxel-clustered punctual lights (no per-object light cap; 255 per froxel) | [#372](https://github.com/bdero/flutter_scene/pull/372) [`d08f6d7c`](https://github.com/bdero/flutter_scene/commit/d08f6d7c), [`8885bd28`](https://github.com/bdero/flutter_scene/commit/8885bd28) | S (Android) / L (iOS) | Filament already shades punctual lights through its own froxel grid, so Android is verify-only. SceneKit limits the lights per node, so the iOS scope depends on S1 (D2). `ios/Classes/SceneViewHost.swift`, `FsceneRealizer.swift` light decode | S1 | RC✓ |
  | V6c | Spatial audio follows the `SceneView` camera when no scene camera / `AudioListener` is set | [#409](https://github.com/bdero/flutter_scene/pull/409) [`8518fcd7`](https://github.com/bdero/flutter_scene/commit/8518fcd7) | S | `dart3d_audio/` | E11 | master-only |
  | V6e | Surface debug views (`Scene.debug.view`, `split`, `overlays`, `Node.debugView`); `splitView`/`splitOverlays`; `DebugDraw.colliders` | [#394](https://github.com/bdero/flutter_scene/pull/394) [`54cd2625`](https://github.com/bdero/flutter_scene/commit/54cd2625); [#437](https://github.com/bdero/flutter_scene/pull/437) [`d65a0c1d`](https://github.com/bdero/flutter_scene/commit/d65a0c1d), [`4513ca8b`](https://github.com/bdero/flutter_scene/commit/4513ca8b); [#402](https://github.com/bdero/flutter_scene/pull/402) [`0ad15113`](https://github.com/bdero/flutter_scene/commit/0ad15113) | M | runtime-only: a `command` op (`lib/src/protocol.dart`) + native debug material paths | E9 | #394, #402 RC✓; splitView master-only |
  | V6f | `Scene.addTickListener` (`SceneTickListener`) + `FlyCameraController.setMoveInput` (analog move intent) | [#404](https://github.com/bdero/flutter_scene/pull/404) [`65a5b309`](https://github.com/bdero/flutter_scene/commit/65a5b309) | S | `lib/src/scene_controller.dart`, E2's fly controller | E2 | RC✓ |
  | V6g | Runtime additions without wire; triage at V8, realize only if a corpus example needs one: `Node.renderOrder` ([`dafe761c`](https://github.com/bdero/flutter_scene/commit/dafe761c)), custom planar mirrors ([`81c7010a`](https://github.com/bdero/flutter_scene/commit/81c7010a)), linear-HDR `RenderTexture` ([`38b81d90`](https://github.com/bdero/flutter_scene/commit/38b81d90)), per-draw instance/index range ([`c2d72f87`](https://github.com/bdero/flutter_scene/commit/c2d72f87)), double-sided materials cast from both faces ([`450cd38d`](https://github.com/bdero/flutter_scene/commit/450cd38d)), sliced `Scene.warmUp` ([`0043b7ea`](https://github.com/bdero/flutter_scene/commit/0043b7ea), which S0h can learn from), `SceneView.maxFrameRate` ([`b4102ed3`](https://github.com/bdero/flutter_scene/commit/b4102ed3)) | [#437](https://github.com/bdero/flutter_scene/pull/437) | S each | per item | — | master-only |

  Dropped from the old V6: the progressive radiance prefilter (moved to E3) and
  the character `rotatesToMovement`/`yaw` (D7). See the corrections.
- [ ] **V6b `Scene.screenDistortion`** (radial shockwave pulses: `radius`,
      `thickness`, `strength`, `chromaticAberration`; a `CustomRenderPass`).
      [#369](https://github.com/bdero/flutter_scene/pull/369) ([`656f6f2f`](https://github.com/bdero/flutter_scene/commit/656f6f2f)). **M. RC✓.** Depends: E6 (post-pass shader).
      Runtime-only, so it needs a `d3:` stage extension or a command op (D4).
      The only upstream consumer is the master-only dice VFX
      (`examples/flutter_app/lib/dice/dice_vfx.dart:466-471`), which is relevant to P3
      juice. Realize it on both platforms, or record an operator-approved
      exclusion before V8.
- [ ] **V7 Breaking changes:** map each one to dart3d behavior (T3 row: one
      test per *affected* row).

  | # | Upstream break | PR / commit | RC | dart3d affected? |
  |---|---|---|---|---|
  | V7-1 | `Lighting` takes `projectionScaleX/Y`, `projectionOffsetX/Y`, `orthographic` in place of `tanHalfFovX/Y` (deprecated getters) | [#411](https://github.com/bdero/flutter_scene/pull/411) [`1fa830b2`](https://github.com/bdero/flutter_scene/commit/1fa830b2) | master-only | **No.** `Lighting` is flutter_scene's shader-uniform struct, and dart3d has no equivalent (`tanHalfFov`: 0 hits). The semantic half (off-center ortho) is V2. |
  | V7-2 | `Scene.initializeStaticResources()` completes with its error | [#372](https://github.com/bdero/flutter_scene/pull/372) [`fce6aa96`](https://github.com/bdero/flutter_scene/commit/fce6aa96) | RC✓ | **No.** dart3d has no Dart-side static-resource load; its natives compile materials (`MaterialPackages.kt`). |
  | V7-3 | `Geometry.uploadVertexData` takes `TypedData`, not `ByteData` | [#420](https://github.com/bdero/flutter_scene/pull/420) [`9011b481`](https://github.com/bdero/flutter_scene/commit/9011b481) | master-only | **No.** dart3d does not depend on `flutter_scene` and has no `Geometry` class. |
  | V7-4 | scene 0.4 TAA spec defaults now match the renderer's: `minimumCurrentWeight` 0.1→0.15, `varianceGamma` 1.0→1.2, `sharpness` 0→0.15, `jitterSequenceLength` 16→11, `jitterScale` 1.0→0.46, `objectMotion` true→false, `skinnedMotion` true→false. The writer omits defaults | [#372](https://github.com/bdero/flutter_scene/pull/372) [`0da324c5`](https://github.com/bdero/flutter_scene/commit/0da324c5) | RC✓ | **Yes.** Both natives hard-code the 0.3 defaults (`StageEffects.swift:231-239`, `StageEffects.kt:277-293`). After the V1a bump, a document holding 0.4 defaults omits those keys and the natives fill in 0.3 values. Fix in V1c together with the bump. |
  | V7-5 | Implementer-facing (RC changelog `168fad28` only): `Geometry.emitsStandardVaryings`/`debugEdges`, `Material.depthCompare`/`participatesInDebugViews`, `Camera.projectToScreenUv`, `ComponentCodec.writeLiveProperty`, `IrradianceFieldBakeStepper` `pointShadowFrame` | [`168fad28`](https://github.com/bdero/flutter_scene/commit/168fad28) | RC✓ | **No.** These are flutter_scene class hierarchies, which dart3d neither implements nor imports. |
  | V7-6 | `Node.castsShadows` deprecated in favor of `shadowCastingMode` | [#372](https://github.com/bdero/flutter_scene/pull/372) [`7406d661`](https://github.com/bdero/flutter_scene/commit/7406d661) | RC✓ | **No** (runtime API). The wire gains the new `shadowCasting` key (V1b) and nothing is removed. |
  | V7-7 | `.fmat` `default_black`/`default_transparent` hints sample black/transparent (were white); fragment precision defaults to mediump | [#441](https://github.com/bdero/flutter_scene/pull/441), [#401](https://github.com/bdero/flutter_scene/pull/401) | master-only / RC✓ | **Not yet.** dart3d has no `.fmat` translator. E6 must implement the 0.24 semantics from the start (V5). |

- [ ] **V8 Conformance:** run the 0.24 example corpus through dart3d on both
      platforms, with T3 evidence per item. New in the corpus since `0dc6ee80`
      (`examples/flutter_app/lib/main.dart`): **Debug views**
      (`example_debug_views.dart`, [#394](https://github.com/bdero/flutter_scene/pull/394), RC✓) and **Dice Shadows**
      (`example_dice_shadows.dart` + `lib/dice/*`, [#409](https://github.com/bdero/flutter_scene/pull/409)/[#427](https://github.com/bdero/flutter_scene/pull/427),
      master-only). Its shadows onto Flutter widgets are W33c-blocked (D6).
      The `flutter_scene_input` controls screen ([#404](https://github.com/bdero/flutter_scene/pull/404)) is app-level (D7).
      The smoke-render scenes (`examples/smoke_render/lib/smoke_scenes.dart`:
      ortho :1648, decal :1969) are the only upstream fixtures for V2 and V4.

**0.24 upstream changes with no dart3d scope** (reason in brackets):
web-only fixes #407, #408, #413, #420 [no web target]; per-platform
shader bundles #410 and the Impeller/Vulkan/Metal crash fixes #425, #431,
#438 [flutter_scene renderer internals]; GPU frame pacing #400, quality
ladder #396, transient-buffer and render-target recycling #437 [host renderer;
dart3d has its own `viewQuality`]; render stats, shader reflection and captures
#399, memory-pressure release #373 [D9 profiling]; DFG asset, CPU mip build
and mip-probe fix #422 [Impeller-side]; ETC1S transcode/encode #432, #433
[runtime transcoder and cook tool, no wire change]; skin-weight normalization and
unit normals #418, inverse-transpose normals `19adefd7`, unskinned morph
binding #429 [renderer-internal: Filament and SceneKit skin and morph natively;
V8 would catch a visual gap]; cascade caster culling #405 [perf];
the cinematic kit (added and removed inside #437, net zero) [D7].
Adjacent pre-existing dart3d gap, not a 0.24 item: upstream #430 applies
glTF sampler wrap modes at runtime import. dart3d's importer parses
`wrapS`/`wrapT` (`lib/src/gltf/parser.dart:545-546`), but
`lib/src/gltf/fscene_emitter.dart` never emits a texture `wrap`.

### Track R — release (after S0; before first publish)

- [ ] R1 Package hygiene: podspec `:ios, '15.0'`, `publish_to` removed,
      package-level tests under `dart3d/test/`, CHANGELOG, LICENSE check.
- [ ] R2 Verify `dn plugin build` for a view plugin on the current `dn`
      (DartNative issue #19 says fixed; `plugin_development.md` says not).
- [ ] R3 CI: Android Kotlin compile + iOS Swift typecheck jobs (macOS).
- [ ] R4 Consumer build test: a fresh `dn create` app depending on dart3d
      by path, then by git, resolves Filament/jolt-jni and builds both
      platforms.
- [ ] R6 **API pass** — review the whole public Dart surface as a
      consumer would meet it: names, defaults, nullability, error messages,
      lifecycle (create, load, dispose, hot restart), what is exported and
      what is internal. Remove or hide what a real app should not see.
      Output: a short API guide and a `dart3d/example/lib/minimal/` app
      that is the README's first code block, built in CI.
- [ ] R7 **Agent skills**, mirroring upstream's set
      (`packages/flutter_scene/skills/`): `dart3d-idioms` (correct usage,
      the traps, what exists), `dart3d-looks` (lighting + post presets),
      `dart3d-performance` (frame budget on device), `dart3d-procedural`
      (content from code), `dart3d-verification-loop` (see your own
      output: screenshots on device). Upstream's `kit` skill covers
      gameplay kit code that is out of scope here (D7); `dart3d-idioms`
      says so and points at what to build app-side. Include an installer
      (`dart run dart3d:skills [--check]`, versioned like upstream's) and
      a test that compiles every snippet in every skill.
- [ ] R8 **README and docs** — README rewritten around: what it is,
      install, first scene, loading a model, physics, materials and
      looks, platform notes, limits. Per-area guides under `dart3d/doc/`,
      CHANGELOG, and the doc truth pass (S0d) folded in. Every code block
      is taken from a file that compiles.
- [ ] R5 Publish to dartpub.dev (**requires P6**: the Dash/fcar showcase
      assets must be replaced or excluded via `.pubignore` before any publish) — operator signs in; GitHub-backed.

## Operating rules

- One PR per unit, branch `s<N>-<slug>` / `e<N>-<slug>` / `p<N>-<slug>` /
  `r<N>-<slug>` / `v<N>-<slug>` (by track),
  base `main`, the operator merges.
  Legacy exception: the sidelined game rooms keep their original
  branch name `p3-game-rooms-wip` (tagged `archive/p3-game-rooms-wip`)
  although they belong to P2.
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
