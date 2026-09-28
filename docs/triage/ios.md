# iOS stabilization triage — 2026-09-28

Branch `stabilize/ios` (from `stabilize/hygiene` @ `b75190f`). Scope:
`dart3d/ios/**`. Sources: `docs/program-audit-2026-09-28.md` §3 and
every Codex review thread on PRs #1, #8, #9, #10, #11 whose path is under
`dart3d/ios/`. Fetched with `gh api .../pulls/<N>/comments` plus the
GraphQL `reviewThreads.isResolved` flag. No comments were posted on GitHub.

Verdicts: **FIX** (fixed on this branch, SHA given), **ALREADY FIXED**
(the code on `stabilize/hygiene` already addresses it), **WON'T-FIX**
(reason given), **DEFER** (size given).

## Audit items

| # | Item | Verdict | SHA / note |
|---|---|---|---|
| 1 | `.cube` LUT NaN/inf traps on UInt8 conversion (StageLut.swift:77) | FIX | `0076e9f`: `parse` throws `.nonFinite`; `stripBytes` guards the conversion too (covers a non-finite `lutBlend`, and inf × blend 0 = NaN) |
| 2 | `contentScaleFactor` written off main from `applyStageQuality` | FIX | `2632287`: the write hops to main with `async`. The render queue never waits on main, so this cannot deadlock. The viewConfig `backgroundColor` write moved to main the same way. Render-path `window`/`bounds`/`UIScreen` reads use a snapshot taken on main |
| 3 | "Scene modified within a rendering callback of another scene" during payload re-decode | ALREADY FIXED (claim is stale) | The source is the Devin decisions.tsv entry from 2026-09-17. It was fixed by `fcf945a` (shipped in #1 as `60b9d3d`): `realize` decodes into the bound scene in place after `beginSceneReset`, and surgical decodes use `surgicalContext()` on `host.scene`. The live harness run on this branch logged no such warning (see Verification) |
| 4 | `syncScreenSubviews` torn-pose race | FIX | `2632287`: on the render queue, only a (presentation transform, camera copy) snapshot is taken. The main-thread poke applies it in one `SCNTransaction`, gated by build generation, right before `setNeedsDisplay` |
| 5 | Deferred-payload re-realize drops command-added `addNode` nodes | FIX (iOS half) | `5510a47`: top-level `addNode`/`updateNode`/`removeNode` go into a journal that is pruned as it grows. After the re-realize the journal replays interleaved with the subtree records by sequence number |
| 6a | `pendingLodNodes` is write-only | WON'T-FIX | This is redundant bookkeeping, not a bug. The real retry is `lodResourceConsumers` plus the frame pass. Removing it would touch the install tuple for no behavior change |
| 6b | LOD takeover leaks `materialConsumers` | FIX | `c62660c`: `bindLodLevel` purges the retired foreign geometry |
| 6c | Physics nodes pick LOD off the pre-sim pose | FIX | `c62660c`: `updateLods` moved to `willRenderScene` and uses presentation transforms |
| 7 | W18 particle decode gaps | FIX, except for the platform limits listed below | `e7c8335` |

### W18 platform limits (documented, not fixed)

- `uniformColor` is approximated as the RGB midpoint ± half the HSB/alpha
  distance. SceneKit's variation varies each dimension independently, so
  colors off the a→b segment can appear. The reference uses one correlated
  lerp.
- Bursts are emulated with timed `SCNParticleSystem` copies: `count` births
  over a 1/60 s window, `interval` through `idleDuration`, and
  `cycles`/duration end the burst by zeroing `birthRate`. SceneKit meters
  births per frame, so counts can be off by a frame's rounding.
- An fps flipbook with `frameCount` < atlas cells is driven by a sawtooth
  `.frame` controller over the mean lifespan. Per-particle lifetime
  variation shifts the wrap points, and `randomStartFrame` variation may be
  overridden by the controller.
- These have no knob and are unchanged: `seed`, `fixedStep`,
  `maxFrameTime`, `maxParticles`, `turbulence`, `randomFlipX`,
  `aspectRatio`, and sphere `hemisphere`. Mesh emitters remain a sprite
  pass.

## Codex review threads (dart3d/ios/**)

32 unresolved threads, plus 1 thread on PR #1 that is already resolved and
listed for completeness.

| PR | Comment id | file:line (review head) | Summary | Verdict | SHA / reason |
|---|---|---|---|---|---|
| 1 | 4045925291 | FsceneRealizer.swift:1206 | opaque must ignore source alpha | RESOLVED on GitHub | Already `.replace` in the opaque case |
| 1 | 4046091813 | FsceneRealizer.swift:1231 | unknown alphaMode should blend opaque (`.replace`) | FIX | `812b9f1` |
| 1 | 4046091820 | FsceneRealizer.swift:2050 | NPOT normal mips drop the odd edge row/column | FIX | `812b9f1`: full source footprint per destination texel |
| 8 | 4054179796 | StageLut.swift:77 | non-finite LUT components trap in UInt8 | FIX | `0076e9f` |
| 9 | 4054361827 | SceneViewHost.swift:2019 | restore a real camera after split views clear | ALREADY FIXED | `applyScreenViewCamera` → `restoreDocumentPov` (W24 fix-round) |
| 9 | 4054361838 | RenderTargets.swift:504 | background changes don't reach siblings | FIX | `2632287`: `applySiblingHostState` |
| 9 | 4054361842 | RenderTargets.swift:586 | viewport layout uses render scale, not device scale | FIX | `2632287`: screen scale basis (matches Android surface px) |
| 9 | 4054616502 | FsceneRealizer.swift:3384 | tagged `shadowCasterFaces` `{"s":…}` ignored | FIX | `812b9f1` |
| 9 | 4054616504 | RenderTargets.swift:503 | `showsStatistics` lost in split mode | FIX | `2632287`: shown on sibling 0 |
| 9 | 4054616505 | SceneViewHost.swift:1511 | doc camera keeps view layerMask after restore | FIX | `2632287`: `restoreDocumentPov` resets it to all layers |
| 9 | 4058204833 | RenderTargets.swift:506 | TAA not applied to siblings | FIX | `2632287`. Note that TAA is skipped on the Simulator by design (`fx.taa.sim`), so this was verified by code only |
| 9 | 4058204837 | RenderTargets.swift:481 | leading sibling keeps a replaced camera node | FIX | `2632287`: rebuilds when the resolved node changes identity or first resolves |
| 9 | 4058204845 | RenderTargets.swift:608 | inherited AA changes don't reach siblings | FIX | `2632287`: the `auto` branch applies the host's mode |
| 10 | 4054413366 | SceneViewHost.swift:4372 | billboard `facing` mode ignored | ALREADY FIXED | `FacingSpec.facing` → `billboardQuad`/`bakeBillboardInstances(facing:camPos:)` |
| 10 | 4054413440 | GeometryFactory.swift:806 | closed tubes get internal caps | FIX | `a3ca8ad` |
| 10 | 4058581069 | GeometryFactory.swift:1101 | mirrored instances keep source winding (P1) | FIX (iOS) | `a3ca8ad`. The Android bake is listed under "Needs other owner" |
| 10 | 4058581096 | GeometryFactory.swift:44 | SIMD3 16-byte stride declared as 12 (P1) | ALREADY FIXED | `floatSource(stride: MemoryLayout<SIMD3<Float>>.stride)` |
| 10 | 4058581098 | FsceneRealizer.swift:1749 | empty facing mesh force-unwraps (P1) | ALREADY FIXED + hardened | `makeGeometry` already guarded `vertexCount`. `a3ca8ad` also guards empty indices |
| 10 | 4058690793 | FsceneRealizer.swift:1998 | rebake leaves stale `materialConsumers` | FIX (iOS) | `a3ca8ad`: `dropMaterialConsumer` in procMesh/instances. The Android twin is listed under "Needs other owner" |
| 10 | 4059420382 | SceneViewHost.swift:4379 | facing basis from model, not presentation, transform | FIX | `a3ca8ad` |
| 10 | 4062294025 | FsceneRealizer.swift:1761 | procMesh/instances material that arrives late never binds | DEFER (S–M, ~2 h) | Needs a pending-material consumer registry plus a first-arrival path in `redecodeResource` (the material rebind today only replaces an existing instance). Not a crash |
| 11 | 4058498625 | FsceneRealizer.swift:4695 | particle textures not in `textureConsumers` | DEFER (M, ~3 h) | Needs a particle-system consumer kind in the texture rebind path. A late or replaced atlas stays stale until the component re-decodes |
| 11 | 4058498629 | FsceneRealizer.swift:4740 | constant/uniform `colorOverLife` ignored | FIX | `e7c8335` |
| 11 | 4058498634 | FsceneRealizer.swift:4711 | mesh tint read from `diffuse.contents` fails when textured | FIX (partial) | `e7c8335` reads the def's `baseColor`. Rebinding the tint on a later material upsert is deferred with 4058498625 |
| 11 | 4058498636 | FsceneRealizer.swift:4724 | startColor gradient animates over life | FIX | `e7c8335`: samples age 0 |
| 11 | 4058553348 | FsceneRealizer.swift:4609 | omitted shape skips the default cone | FIX | `e7c8335` (also legacy `shapeType`/`shapeRadius`/`shapeAngle`) |
| 11 | 4058553354 | FsceneRealizer.swift:4542 | `uniformCurve` ordinal zip | FIX | `e7c8335`: union-timeline resample |
| 11 | 4058553362 | FsceneRealizer.swift:4711 | incomplete mesh emitter still renders (iOS) | FIX (iOS) | `e7c8335`. The Android mirror is listed under "Needs other owner" |
| 11 | 4058553365 | FsceneRealizer.swift:4730 | legacy flat modules ignored | FIX | `e7c8335` |
| 11 | 4058717353 | FsceneRealizer.swift:3717 | `duration: 0` not normalized | FIX | `e7c8335` |
| 11 | 4059493134 | FsceneRealizer.swift:4427 | RGB variation fed as HSB | FIX (approximation) | `e7c8335`: HSB conversion, documented as an approximation above |
| 11 | 4059885220 | FsceneRealizer.swift:4503 | fps flipbook ignores `frameCount` | FIX (approximation) | `e7c8335`: `.frame` sawtooth controller |
| 11 | 4059885230 | FsceneRealizer.swift:4600 | particle angles should be radians | WON'T-FIX (false positive) | `SCNParticleSystem.h` (iPhoneSimulator 27 SDK) says `particleAngle` is "in degrees" and `particleAngularVelocity` is "in degrees per second". The ×180/π conversion is correct |

**Counts (32 unresolved):** FIX 25 (including 3 partial/approximate),
ALREADY FIXED 4, WON'T-FIX 1, DEFER 2.

## Coordinator follow-ups (from origin/stabilize/dart `docs/triage/dart.md`)

| Item | Verdict | SHA / note |
|---|---|---|
| iOS `shadowCasterFaces` tagged-value mis-decode | FIX | `812b9f1` (same fix as PR #9 4054616502) |
| Burst-only emitters emit nothing | FIX (emulated) | `e7c8335` |
| Mirror the Dart cap table (`limits.dart`) | FIX | `d62a771` covers all of these. Tessellation counts and stations are clamped to 512, and icosphere subdivisions to [0, 6]. The instance bake is limited to 16384 instances and to 2^20 vertices. A dash period ≤ 0 (the `(0,0)` hang) or a pattern with more than 16384 spans renders as a solid line. The uint16 bound needs no change because iOS always emits UInt32 indices |
| W26 native correctness: rewind mirrored instances | FIX | `a3ca8ad` |
| W26: no caps on closed tubes | FIX | `a3ca8ad` |
| W26: per-segment line colors, closed-polyline attribute wrap, ribbon normals, billboard scale-then-rotate, icosphere seam split | DEFER (M, ~half a day together) | Each one needs porting against `d3BakeInstances`/`proc.dart` on the Dart branch and a visual check. They are not crashes, so they were left for a focused W26 geometry pass |

## Verification

- `swiftc -typecheck` (iPhoneSimulator 27 SDK, arm64, target iOS 16) is
  clean at every commit.
- In `dart3d/example`, `dn analyze` reports "No issues found!" and `dn test`
  passes 321/321.
- Live runs were on the iPhone 17 Pro simulator via `dn run -d 9151…`:
  harness mode ×7 (runs 5–7 carried temporary diagnostics that were never
  committed) and default dice mode ×1. Runs 2–4 and the dice run injected
  the Main Thread Checker with
  `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=libMainThreadChecker.dylib`, and
  `vmmap` confirmed it loaded in Runner. Native logs were captured with
  `simctl spawn … log stream` (Runner process: dart3d subsystem plus
  "rendering callback" / "UI API called" messages).
  - "is modified within a rendering callback": **0** lines across all
    runs.
  - Main Thread Checker "UI API called on a background thread": **0**
    lines. **Caveat:** there was no negative control, meaning no pre-fix
    build was run under MTC on this branch. The "12 hits/run" baseline in
    the audit was not reproduced here, so zero hits are consistent with the
    fix but do not prove it.
  - W25: the LUT chunk ref deferred and then applied
    (`environment …: awaiting LUT payload`, then the Dart log "w25 LUT
    payload landed — deferred grade applies"). The asset-path LUT and
    `lutBlend 0.35` lanes ran with no crash. No non-finite LUT is exercised
    by the harness, so item 1 was verified by code and typecheck only.
  - W18: the lane completed ("fountain + streaks + mesh pool live, gated
    ran +6 s…+14 s then removed"). Logs include `particleEmitter: 1
    burst(s) emulated with timed SCNParticleSystem copies` and
    `meshParticleEmitter … realized as a sprite pass`. The emitters are
    off-frame in the harness camera, so the screenshot does not show the
    particles themselves.
  - W24: the split, inset, and layerMask lanes ran. Screenshots:
    - `w24-viewport-inset-bottom-left.png`: the lone inset view lands
      bottom-left (the wire origin) at 45% of the device-pixel target, and
      sibling 0 carries its own statistics overlay.
    - `w24-split-cam2-authored-pose.png`: in the two-view split, the right
      half shows only the background.
    - `w24-split-sibling-renders-docpose-diagnostic.png`: a temporary,
      uncommitted diagnostic posed sibling 1's proxy with the doc camera,
      and it rendered the scene. So the proxy/pose path works and the
      blank half is the harness's authored `w24.cam2` pose (see "Needs
      other owner"). The proxy-in-scene commit `b412e0f` was based on the
      wrong premise and is reverted in `ee14d15`. The main-side pov handle
      and seeding in `d47d48b` are kept as defensive changes; nothing
      showed they were required.
  - Default dice mode: roll settled (`rolled d4:3 d6:1 … total 107`);
    see `dice-default-settled.png`.
- **Not exercised live:**
  - item 5 (re-realize replay). No run logged `re-realize replay:`,
    because no deferred payload landed after a journaled top-level op in
    these runs.
  - item 6 (LOD pose timing): not visually distinguishable here.
  - item 4's race: it is a race, so it has no deterministic repro.
  - the TAA sibling propagation: TAA is skipped on the Simulator by design.

## Needs other owner

- **Android** (`dart3d/android/**`):
  - Mirrored-instance winding in the Android bake (PR #10 4058581069 names
    both native paths).
  - Instance rebake appends duplicate entity/slot consumers (PR #10
    4058690793, Android half).
  - Mesh emitter with no `material` still builds a runtime (PR #11
    4058553362, Android half).
  - The deferred re-realize addNode drop at Dart3dView.kt:2516 (audit P1,
    Android half).
- **Example** (`dart3d/example/**`): the harness `w24.cam2` pose in
  `feature_scene.dart` (translation `(-4, 2.4, -3)`, `Ry(-0.9)·Rx(0.45)`)
  does not frame the dice area on iOS, so the split lane's right half shows
  only background. Re-aim it at the dice area, for example with a
  look-at-origin rotation, and check that Android frames it the same way.
- **Dart/docs** (`dart3d/lib/**` / docs owner): `docs/particles-spec.md`
  should record the new iOS burst, flipbook, and uniformColor
  approximations listed above.
