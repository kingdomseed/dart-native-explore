# dart3d program audit and remaining-work inventory — 2026-09-28

Audit of `main` @ `946653b` after the Devin full-engine run (PRs #1–#11,
2026-09-17 → 09-21). Sources: every PR body/comment/review thread, all
`docs/` plans and specs, Devin's orchestration state
(`~/.local/share/devin/orchestrate/`), the code, and upstream
`flutter_scene` 0.23.0 / `scene` 0.3.0 from the pub cache.

## TL;DR

1. **11 of 20 full-engine units merged; 9 never started** (W17, W19, W20,
   W27, W28, W31, W32, W33, W34).
2. **The merged units are code-complete but under-verified.** The plan's
   gate (10 live lanes + perf + operator review per unit) was run for
   essentially none of them. Only W21, W30 and pre-fix W15 have device
   evidence; 7 PRs say "no device access". `full-engine-program.md` has
   zero boxes checked outside five in W16.
3. **~110 automated review comments (Codex) were never triaged**,
   including ~10 P1s on W26; PRs #2–#7 got no automated review at all.
   Spot-checked P1s are still open on main.
4. **The plan drifted from reality** in both directions: prescribed
   techniques that turned out infeasible (GPU instancing in Filament's
   Java API) were silently downgraded, and several remaining units have
   hollow or blocked dependencies (W31 on CPU-baked instancing, W33 on a
   DartNative widget-to-texture bridge that doesn't exist, W27 on an
   upstream decal contract that doesn't exist in 0.23.0).
5. **The original product goals fell out of the program**: no parser
   integration, no DartNative dice app shell, no dartpub.dev publish path,
   and demo work is frozen by the "no demo until the engine closes" rule.

Recommendation: before seeding any new unit, run a **stabilization pass**
(verification backfill + P1 triage + hygiene), then **re-plan W17–W34**
with the decisions in §7.

## 1. Environment (as of this audit)

- DartNative SDK upgraded to framework `4c1cdb074e0` / engine `868544b`
  (2026-09-26 release: code push preview, platform-parity restyling, new
  widgets). `dartnative/` upstream clone pulled to `cb4a012`.
- On the new SDK: `dn analyze` clean, `dn test` **321/321 pass**,
  `dn build apk --release` OK (117 MB), example launches on the iPhone 17
  Pro sim via `dn run -d <sim>`.
- **Gotcha:** `dn build ios --simulator` (generic destination, both archs)
  fails on Xcode 27 — its `lipo -verify_arch` now accepts a single arch,
  and flutter_tools passes `arm64 x86_64`
  (`~/zero/packages/flutter_tools/lib/src/build_system/targets/darwin.dart`).
  Use `dn run -d <sim-id>` (single arch). Worth reporting upstream.
- Plugin contract unchanged by the release (ViewType.claim, NativeElement,
  PluginMutation, `@_cdecl` provider, `compileOnly project(':dartnative_android')`
  — dart3d already matches). New optional `DNActivityHooks` could pause
  rendering on user-leave.
- Code push cannot patch dart3d's native code, assets, or wire changes;
  at most app-side Dart constants (throw tuning, readout). Every SDK bump
  needs a fresh store release before patches apply.
- `.devin/skills/` copies are stale vs `dartnative/skills/` (missing
  FastList/FastGrid guidance, localization, `registerSkiaFactories()`).

## 2. Program status vs evidence

| Unit | PR | Device evidence | Notable downgrades / deferrals |
|---|---|---|---|
| W21 materials | #1 | iOS sim + A142 | iOS KTX2 non-supercompressed only (BasisU warn-only); Android light units still the ×10 heuristic, env intensity masked by per-platform authoring; exposure lane + review open |
| W15 prefab streaming | #2 | both, **pre-fix head only** | fix-round head never re-verified; Android lane 4 missing; `components.dart:43` still gates `prefabInstances`/`streaming` as "planned W15" so `strictFeatures:true` rejects prefab docs |
| W30 Vulkan | #3 | **full** (10 lanes + video + GL/VK perf table) | not re-run after later PRs → W16/W24 materials panicked on Vulkan until `4a0c02b` |
| W29 document layer | #4 | tests only | no `.fsceneb` writer, Draco/meshopt multi-buffer refused, no prefab compose on import; perf lane not run |
| W23 physics | #5 | typecheck + 1 device-found fix | revolute limits via pinned slider joint; multi-axis generic joints fall back; iOS pair exclusion cap 24; Android single-point manifold, `clearForces` no-op |
| W22 KHR_materials | #6 | harness ran pre-fix | iridescence/diffuseTransmission dropped both; iOS drops specular/aniso/IOR/volume/dispersion; "86-asset catalog" became a JSON classification (tautological); goldens classified not image-diffed; review screenshots predate 4 engine commits |
| W16 trails + LOD | #7 | none | `blendRange` no-op; primary-view-only LOD; PR body describes superseded design |
| W25 stage effects | #8 | none | iOS SSR/GI/godRays declared limits (SCNTechnique never tried); iOS lift/gamma/gain no-op; Android CA/GI/godRays/metering limits |
| W24 views + shadows | #9 | none | iOS cascades/contact shadows log-once; catcher live-mode only (no bake); Android directional shadows inert |
| W26 geometry + instancing | #10 | none | instancing is **CPU-baked**, capped 16,384; no Wedge/Ring/Extrude; new shapes are dart3d-only `d3:procMesh` |
| W18 particles | #11 | "pending" | iOS ignores bursts/seed/turbulence/maxParticles/etc. (burst-only emitters emit nothing); mesh particles are sprites on iOS, entity pool on Android; 1000@60fps never measured |

Process violations worth knowing: W18/W25/W26 merged within 17 minutes
with heads re-committed 1–4 min before merge (no swarm at head);
verification-matrix.md stops at W21/W18-pending; device evidence for most
units lived in `/tmp/swarm-*` and is gone; agent fix-round comments and
"PASS" comments post as the owner account, so operator sign-off is
indistinguishable from agent activity.

Earlier programs (W0–W14): done and live-verified per
`verification-matrix.md`, but `dart3d-completion-program.md` boxes were
never checked, and W2's "upstream-built `.fscene` rolls identically" was
never done.

## 3. Bug inventory (prioritized)

### P1 — fix before new feature work

| Bug | Platform | Evidence |
|---|---|---|
| Directional shadow-map chain inert (no dice shadows; catcher can't show) | Android | followups [w24-verify]; FsceneRealizer.kt:3351, Dart3dView.kt:2093 |
| Main-thread ANR ~3×/50 min on both backends | Android | followups #3; W30 gate caveat |
| Zombie mode: warm relaunch swallows SceneView init exception → blank screen | Android | followups [w24-verifier] |
| Deferred-payload re-realize drops command-added `addNode` nodes | both | Dart3dView.kt:2516, SceneViewHost.swift:1201 |
| KTX2 provider process-global, never released → leak + UAF on address reuse | Android | dart3d_jni.cpp:175; PR #1 thread |
| `.cube` LUT with NaN/inf crashes on UInt8 conversion | iOS | StageLut.swift:77; PR #8 |
| UIKit off-main write of `contentScaleFactor` from render path (12×/run) | iOS | SceneViewHost.swift:2376 |
| Turbulence gradient table malformed (322 vs 256 floats) | Android | ParticleRuntime.kt:718-746 |
| W26 hangs/OOM: dash `(0,0)` infinite loop; uncapped icosphere subdivisions (20·4ⁿ); instance bake uncapped by vertex budget; UINT16 index overflow on large meshes | Dart + both | proc.dart:1690 etc.; FsceneRealizer.kt:1243 (confirmed) |
| Instance bounds ignore payload-backed matrices (wrong culling) | Dart | world_bounds.dart:218-225 (confirmed) |

### P2 — grouped

- **Rendering/threading (iOS):** SCNScene mutated inside another scene's
  render callback during payload re-decode; `syncScreenSubviews` torn-pose
  race.
- **Views (Android):** stale-frame smear on view transitions; inset
  surface outside viewport never cleared; split-view siblings don't get
  background/AA/TAA/statistics changes; facing geometry re-faced only for
  host camera.
- **Streaming/payloads:** nested-lazy-prefab attachment ids unresolvable;
  upsertPayload shared-claim gap; op-added deferred textures never arm
  re-realize; `serializeScene` omits streamed prefab members.
- **LOD:** pending-mesh → LOD renderable stomp (Android), iOS starves.
- **Effects:** LUT cache unbounded (~3 MiB/entry); film-grain-off →
  banding; AE floor below −3.3 EV; flare ignored with bloom; stale LUT
  fingerprint.
- **Particles:** pause/enable destroys live particles (spec says keep
  drawing); not reattached while LOD culled; billboard basis degenerate
  top-down; flipbook `frame0` overrun; unsorted alpha; non-deterministic
  turbulence reset; ~11 iOS decode gaps (FsceneRealizer.swift:5119-5354).
- **Geometry:** ~45 distinct W26 correctness items (closed polylines,
  per-endpoint colors, normals with translation, icosphere seam/edge-key
  collisions, mirrored instance winding, cuboid −Y winding, tube caps,
  NaN on zero segments); `widthInPixels`/round caps warn-only; Dart mirror
  drops polyline resource ops.

Full thread dumps: regenerate with
`gh api repos/kingdomseed/dart-native-explore/pulls/<N>/comments`
(unresolved: #1 3/6, #8 11/11, #9 16/16, #10 58/58, #11 26/26).

### Parity gaps (documented, mostly P3)

No hardware instancing on either platform (Filament 1.71.6 Java lacks
`InstanceBuffer`); iOS BasisU KTX2; iOS EXR env limits; iOS `collide:false`
cap 24; Jolt single-point manifold; Android 8-bit layerMask; forced Vulkan
silently downgrades to GL; `DART3D_BACKEND`/`DART3D_QUALITY` are
example-only dart-defines with no plugin API.

## 4. Remaining units (W17–W34) — feasibility and decisions

| Unit | Size | Key risk | Decision needed |
|---|---|---|---|
| W17 sky/environment | M–L | Dart per-pixel scatter → 1k equirect in <200 ms on A142 doubtful; sun sweeps re-prefilter IBL each time | Generate in Dart or native? Regeneration budget? Where do sun extension fields live? |
| W19 character controller | L | Jolt `CharacterVirtual` needs JNI contact listener; iOS sweep/slide/step/snap fully hand-built | Custom `characterMove` op vs mirroring upstream's Dart `CharacterController`? |
| W20 env volumes/probes | XL | Filament: one IndirectLight per scene (no local probes); planar reflection needs custom materials | Hard switch vs crossfade; single-probe degrade; accept `SCNFloor`-only mirror on iOS? |
| W27 decals | L | **No upstream decal contract in 0.23.0**; no native decals on either engine | Define `d3:decal` now or wait? Mesh-clip vs screen-space (needs W28)? |
| W28 shader contract | XL | Translate upstream `.fmat` (Impeller-targeted) to Filament material + Metal shader modifiers; SceneKit vertex-stage limits | Cross-compile a subset vs per-platform authored materials; prototype first |
| W31 splats | XL | **W26 dependency is hollow** (CPU bake can't re-sort 100k/frame); Android needs index-buffer resort or C++ `InstanceBuffer` via the dlsym hack | Target count/budget on A142; accept C++ ABI coupling? |
| W32 audio | M iOS / L Android | Filament has no audio; Android needs Oboe/AAudio or SoundPool shim; was a formally approved exclusion | In dart3d or a sibling plugin? Android backend? |
| W33 widget/external textures | XL → split | **Widget half blocked on DartNative** (native widgets, no `toImage`, no offscreen host). externalTexture (AVPlayer / `Texture.Stream`) and semantics are feasible now | Split: ship external texture + semantics; file DartNative feature request for widget capture |
| W34 hot reload/debug views | M–L | Android is release-only (no debug engine) → needs host watcher + `adb reverse`/HTTP push | Define "dev mode"; fold shader hot reload into W28 or W34 |

Dependency-graph fixes: W32/W34 "after W21" (graph) vs "none" (headers);
W27 hard-after-W28 vs "fixed-material variant first"; W17/W20 moved from
W13 to W25 without rationale; `/tmp/flutter_scene_repo` (cited as the
parity source for W27/W28) no longer exists — **pin the upstream revision
the parity target means**.

## 5. Gaps outside the program

**Upstream flutter_scene 0.23.0 surface no unit covers:** camera
controllers (orbit/fly/follow), pointer picking + BVH, selection outline,
iOS tone-mapper choice, sprites/texture atlas, Wedge/Ring/Extrude geometry,
shadow-catcher bake mode, spot/point shadows, animation property resolver,
declarative widgets, memory/render profiling, and the `kit/` layer
(day-night, water, spring arm, camera shake, joystick, etc.). Appendix B
excludes only networking and the editor — decide in or out explicitly.

**Original PLAN.md phases:**

| Phase | Status |
|---|---|
| 1 Parser standalone | Partial — `mythic_dice_parser` 8.0.0 passes 258 tests, but the `parse → RollSpec → outcome` contract was never defined |
| 3 DartNative app shell | Not started — `mythic_dice_app` is still plain Flutter on `flutter_scene` |
| Parser ↔ dart3d | Not wired — dice readout comes from settle poses + `dice_faces.json`; physics-vs-parser reconciliation undecided |
| 8 Publish to dartpub.dev | Not started — `publish_to: 'none'`; name `dart3d` still free (404); podspec says iOS 13.0 (needs 15+); **new doc limitation: view plugins can't yet produce their own Android archive** (`dn plugin build` finds `dartnative_android` only in-tree); Filament/jolt-jni consumer resolution unproven |

**Operator demo feedback (09-17) still open:** roll doesn't pick up and
toss (horizontal sweep only); reset is an unlabeled ↻; table is a fixed
132×280 box — walls don't track screen aspect, iPad shows wood past walls,
pan breaks "edges = walls"; iPad white screen never investigated; no
in-app quality picker (dart-define only); no 3D animated DartNative logo;
Showcase mixes test lanes with demo content, no stage/table; no
side-by-side fidelity comparison with flutter_scene demos. Dice/table code
is unchanged since the initial import.

## 6. Repo hygiene

- `dart3d/android/.cxx` (211 build files incl. `.o`, user paths) is
  tracked and dirties on every build → gitignore + `git rm --cached`.
- `docs/artifacts` is 120 MB (a 55 MB mp4 over GitHub's soft limit) plus
  the root DartNativeX mp4 → move to LFS or releases.
- No CI; no iOS XCTest; 3 JVM tests; all Dart tests live in
  `example/test`, none in the package.
- Example harness: 5.3k lines of wall-clock-timed phases (73 timers,
  un-cancellable nested timers, W25/W18 overlap at +166/+170 s).
- 19 ad-hoc debug scripts in `example/tool/`; stale docs
  (`extended-surface-audit.md`, `environment-ibl-spec.md`,
  `texture-material-spec.md`, README exclusions and split-screen note).
- 10 merged `w*` branches + 10 worktrees in `../dart-native-explore-wt/`;
  unpushed `w21-android/-dart/-ios` (squashed into #1); untracked root
  `decisions.tsv`; Devin orchestration state is stale.

## 7. Proposed sequencing

**Phase A — stabilize (no new features)**
1. Hygiene: `.cxx` out of git, artifacts to LFS, prune branches/worktrees,
   add CI (`dn analyze`, `dn test`, Gradle `compileReleaseKotlin`,
   `swiftc -typecheck`), move core tests into the package.
2. Fix the P1 list (§3).
3. Triage all Codex threads: fix, won't-fix with reason, or file.
4. Verification backfill at one head: the W15/16/18/22–26/29 live lanes
   on A142 (both backends) + iOS sim, with evidence committed to
   `docs/artifacts` and `verification-matrix.md` updated.

**Phase B — re-plan**
5. Rewrite the gate honestly (what counts as "verified" when a device
   isn't available; mandatory Android Vulkan smoke at every merge head).
6. Pin the upstream parity revision; decide in/out for the §5 upstream
   surface; formally reopen or keep the W10 exclusions.
7. Resolve the §4 decisions; re-order: W28 → W27, W17, W20, W19, W34,
   W33-split, W32, W31 (last — needs a real instancing story).
8. Decide whether the no-demo rule still holds, or run the demo/dice-app
   track (parser contract, DartNative app shell, demo UX feedback,
   publish prep) in parallel with engine work.
