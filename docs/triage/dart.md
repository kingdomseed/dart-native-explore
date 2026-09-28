# Dart-side stabilization triage — 2026-09-28

Scope: `dart3d/lib/**`, `dart3d/example/{lib,test,tool}/**`, and
`dart3d/test/**` on branch `stabilize/dart`. Inputs were
`docs/program-audit-2026-09-28.md` §3/§6 and every **unresolved** Codex
review thread on PRs #1, #8, #9, #10, and #11 whose file is under
`dart3d/lib/**` or `dart3d/example/**`. The threads were pulled with
`gh api …/pulls/<N>/comments` plus GraphQL `reviewThreads.isResolved`.
PR #1 has no unresolved thread on a Dart path. Nothing was posted to
GitHub.

## Cap constants (natives must mirror)

These live in `dart3d/lib/src/geometry/limits.dart`, exported from
`proc.dart` and `dart3d.dart`. Wire values are **clamped**, never
rejected, so every platform degrades to the same capped mesh.

| Constant | Value | Applies to | Native mirror |
|---|---|---|---|
| `kD3MaxProcSegments` | 512 | every tessellation count: `segments`, `rings`, `radialSegments`, `tubularSegments`, `heightSegments`, `capRings`, `segmentsX`/`segmentsZ`, tube/ribbon `stations`. The lower bound stays the existing per-shape floor (1 for plane/sphere/torus as in native `seg()`, 3 for radial counts of cylinder/cone/capsule/disc/tube, 2 for stations) | clamp in `seg()` (Kotlin `FsceneRealizer.kt:1221`, Swift `FsceneRealizer.swift:1424`) and the tube/ribbon `stations` reads |
| `kD3MaxIcosphereSubdivisions` | 6 | icosphere `subdivisions` (20·4ⁿ triangles; level 6 = 81 920 tris, 40 962 shared vertices) | clamp where `subdivisions` is read (`FsceneRealizer.kt:1243`, `FsceneRealizer.swift:1455`) |
| `kD3MaxUint16Vertices` | 65 536 | index width: a mesh with more vertices **must** use 32-bit indices. Dart always emits `Uint32List` | pick `UINT32`/`bytesPerIndex: 4` by vertex count everywhere. A capped UV sphere is 513² ≈ 263k vertices |
| `kD3MaxBakedInstances` | 16 384 | instances baked into one `d3:instances` mesh; the tail is truncated | existing `MAX_BAKED_INSTANCES` / `maxBakedInstances` |
| `kD3MaxBakedVertices` | 1 048 576 (2²⁰) | total vertices in one baked `d3:instances` mesh. Kept instances = `min(requested, 16384, max(1, 2²⁰ ÷ baseVertexCount))` (`d3BakedInstanceCount`) | apply before the bake loop |
| `kD3MaxDashSpans` | 16 384 | dashed polyline spans. If `length/(on+off) + 1` exceeds it, the line renders **solid** | same pre-check before the dash loop |
| dash validity | `on > 0 && off >= 0`, both finite (`d3DashPatternValid`) | an invalid pattern renders **solid**. `(0,0)` used to loop forever | same check before the dash loop |

Reference behavior for the native bake is `d3BakeInstances`
(`geometry/instances.dart`). It applies the caps above, transforms
normals by the inverse-transpose (never the translation), **reverses
triangle winding for a negative-determinant transform** (mirrored
instances), and multiplies the per-instance `color` into the vertex
color.

### Generator behavior the natives should mirror (Dart changed, natives not)

- Closed polylines wrap `colors`/`widths` at the seam: the closing
  segment's far end uses point 0's attributes. Natives currently fall
  back to white or default width there.
- `lineSegments.colors` is **per segment**, applied to both endpoints.
  Natives index it per endpoint.
- rgb colors pad to rgba (alpha 1).
- Closed tubes ignore `caps`.
- Ribbon normal = `across × tangent`, not raw `up`.
- Billboard corners scale by `size`, then rotate.
- Icosphere: split the seam (`u + 1` on the low side of a straddling
  triangle) and give pole vertices one copy per triangle at the mean
  `u` of the other two corners.
- The icosphere midpoint cache key needs 32 bits per index.

## Triage table

Verdicts: **FIX** (with SHA), **WON'T-FIX** (reason), **DEFER** (size).
Duplicate threads point at their twin. "Natives mirror" means the Dart
side is fixed and the same defect still exists in the Swift/Kotlin
generator, which the iOS/Android owners hold.

| PR | Comment | File:line (at review) | Summary | Verdict | SHA / reason |
|---|---|---|---|---|---|
| #8 | 4054324487 | `example/lib/feature_scene.dart:4095` | P2: Exercise the die before closing lane 10 | FIX | 48167df — W25 close-out rolls the die and reports PASS/FAIL on a settle event within 10 s |
| #8 | 4058547712 | `example/lib/feature_scene.dart:4018` | P2: Cancel nested W25 timers when replacing the scene | FIX | 48167df — all phase timers owned by `PhaseTimers`, cancelled on reload/switch/dispose |
| #9 | 4054361851 | `example/lib/feature_scene.dart:3623` | P2: Rotate the catcher plane onto the floor | WON'T-FIX | Claim is wrong for current code: both native `plane` builders are XZ facing +Y (`MeshFactory.kt:761`, `FsceneRealizer.swift:1456` "XZ +Y — the wire contract"), so the catcher is already horizontal |
| #9 | 4054616510 | `example/lib/feature_scene.dart:3728` | P2: Cancel the inner W24 phase timers | FIX | 48167df — nested W24 timers owned/cancelled; `targetPx` also checks `mounted` |
| #9 | 4058204843 | `lib/src/diff_apply.dart:419` | P2: Decode malformed viewport values defensively | FIX | 54e548b — `viewport` accepts only four finite numbers, else null |
| #9 | 4058447791 | `lib/src/doc_layer.dart:65` | P2: Add an extension-aware writer for serialized viewports | FIX | 54e548b — `writeFsceneWithExtensions`; `serializeScene` round-trips through it; showcase lane uses it |
| #10 | 4054413351 | `lib/src/world_bounds.dart:225` | P1: Decode payload matrices when computing instance bounds | FIX | d7884ff — payload `matrices` decoded from `doc.payloads` |
| #10 | 4054413375 | `lib/src/geometry/instances.dart:159` | P2: Apply the instance-level double-sided setting | WON'T-FIX | Stale: both natives read the flag (`FsceneRealizer.swift:1887`, `FsceneRealizer.kt:1676`) |
| #10 | 4054413383 | `lib/src/geometry/proc.dart:1690` | P1: Reject non-progressing dash patterns | FIX | f52e52d — `d3DashPatternValid` + `kD3MaxDashSpans`; invalid → solid. Natives must mirror |
| #10 | 4054413390 | `lib/src/geometry/proc.dart:1744` | P2: Wrap attributes when closing a polyline | FIX | f52e52d — attributes wrap modulo point count |
| #10 | 4054413406 | `lib/src/geometry/proc.dart:963` | P2: Implement the cuboid debug-color option | WON'T-FIX | Stale: `buildCuboid` emits corner colors; iOS `GeometryFactory.swift:496` and Android `MeshFactory.cuboid(…, debugColors)` read the flag |
| #10 | 4054413411 | `lib/src/geometry/proc.dart:1745` | P2: Apply one declared color to each line segment | FIX | f52e52d — per-segment color on both endpoints (Dart). Natives still index per endpoint → mirror |
| #10 | 4054413413 | `lib/src/geometry/mesh_data.dart:184` | P2: Transform normals without applying translation | FIX | f52e52d — inverse-transpose normal matrix, no translation |
| #10 | 4054413434 | `lib/src/geometry/proc.dart:730` | P2: Implement round polyline caps | DEFER (S–M) | Round caps need a cap fan in Dart and both native facing expanders; natives log `caps` as unsupported today. Tracked, not a crash |
| #10 | 4058581079 | `lib/src/geometry/proc.dart:524` | P2: Use periodic control points for closed sweeps | DEFER (M) | Periodic Catmull-Rom plus seam-corrected RMF frames must land on Dart, iOS, and Android together. A Dart-only change would diverge from the natives it mirrors |
| #10 | 4058581081 | `lib/src/geometry/proc.dart:549` | P2: Include Catmull-Rom overshoot in sweep bounds | FIX | f52e52d — `d3CatmullRomBounds` (Bézier-hull box) |
| #10 | 4058581083 | `lib/src/geometry/proc.dart:1610` | P2: Scale billboard corners before applying rotation | FIX | f52e52d — scale then rotate (Dart). Natives mirror |
| #10 | 4058581086 | `lib/src/geometry/proc.dart:1393` | P2: Split icosphere vertices at the UV seam | FIX | f52e52d — seam (u+1) and pole vertices split (Dart). Natives mirror |
| #10 | 4058581088 | `lib/src/geometry/proc.dart:1358` | P2: Use a collision-free key for icosphere edges | FIX | f52e52d — 32-bit-per-index key, plus the subdivision cap |
| #10 | 4058581091 | `lib/src/world_bounds.dart:215` | P2: Ignore overridden geometry in billboard-instance bounds | FIX | d7884ff — billboard mode ignores source geometry |
| #10 | 4058581103 | `lib/src/geometry/proc.dart:1479` | P2: Project ribbon normals off the path tangent | FIX | f52e52d — normal = across × tangent (Dart). Natives mirror |
| #10 | 4058690791 | `lib/src/world_bounds.dart:229` | P2: Pad billboard-instance bounds by half the size | FIX | d7884ff/f52e52d — pad by the half-diagonal `√(w²+h²)/2`, not `max/2`: a camera-facing or rotated quad's corner reaches the diagonal |
| #10 | 4058690794 | `lib/src/geometry/mesh_data.dart:198` | P2: Backfill colors when merging an uncolored mesh | FIX | f52e52d — white backfill |
| #10 | 4058878320 | `lib/src/world_bounds.dart:225` | P2: Decode payload-backed transforms when computing instance bounds | FIX | d7884ff — dup of 4054413351 |
| #10 | 4058878329 | `lib/src/geometry/instances.dart:35` | P2: Make instance source constructors reject null | FIX | f52e52d — non-nullable constructor parameters |
| #10 | 4059089041 | `lib/src/geometry/proc.dart:1690` | P2: Reject dash patterns that cannot advance | FIX | f52e52d — dup of 4054413383 |
| #10 | 4059089044 | `lib/src/geometry/mesh_data.dart:92` | P2: Normalize procedural colors to four components | FIX | f52e52d — rgb padded to rgba in `emit` and the polyline/segment expanders |
| #10 | 4059089046 | `lib/src/components.dart:38` | P2: Register custom features with the document decoder | FIX | 54e548b — `readFsceneWithExtensions` strips/restores `kD3ExtensionFeatures` around the upstream decode |
| #10 | 4059420366 | `lib/src/geometry/proc.dart:1546` | P2: Wrap closed-polyline attributes at the seam | FIX | f52e52d — dup of 4054413390 |
| #10 | 4059420378 | `lib/src/geometry/proc.dart:1585` | P2: Apply each line-segment color to both endpoints | FIX | f52e52d — dup of 4054413411 |
| #10 | 4062294031 | `lib/src/geometry/paths.dart:278` | P2: Return defensive copies from path point getters | FIX | f52e52d — getters return clones |
| #10 | 4062294042 | `lib/src/geometry/proc.dart:1041` | P2: Validate zero segment counts before division | FIX | f52e52d — clamp to the native `seg()` floor (1) and the cap |
| #10 | 4062294049 | `lib/src/geometry/mesh_data.dart:184` | P2: Exclude translation when transforming normals | FIX | f52e52d — dup of 4054413413 |
| #10 | 4062454678 | `lib/src/geometry/proc.dart:524` | P2: Make closed sweep frames periodic at the seam | DEFER (M) | Dup of 4058581079 |
| #10 | 4062454688 | `lib/src/geometry/proc.dart:559` | P2: Suppress end caps on closed tubes | FIX | f52e52d — `caps && !closed` (Dart). Natives mirror |
| #10 | 4062454693 | `lib/src/geometry/proc.dart:545` | P2: Include Catmull-Rom overshoot in sweep bounds | FIX | f52e52d — dup of 4058581081 (also `d3ProcShapeBounds`) |
| #11 | 4058498628 | `lib/src/particle_sim.dart:1220` | P2: Reset stateful particle modules with the system | FIX | 4ddd4cc — `ParticleModule.reset()`; the Kotlin mirror needs the same fix (Android owner) |
| #11 | 4059493130 | `example/lib/feature_scene.dart:4072` | P2: Give the iOS burst lane a nonzero birth source | DEFER → iOS owner | Root cause is iOS `decodeParticleEmitter` ignoring `bursts`. Giving the lane a steady rate would stop it testing burst-only emission on Android |

**Counts (38 threads):** 31 FIX, 3 WON'T-FIX (all three are stale or
wrong against current code), 4 DEFER. Of those 4, 3 are the same
cross-platform sweep/caps work and one belongs to the iOS owner.

## Audit items (not review threads)

| Audit item | Verdict | SHA / note |
|---|---|---|
| W26 dash `(0,0)` infinite loop | FIX | f52e52d |
| Uncapped icosphere subdivisions | FIX | f52e52d (cap 6) |
| Instance bake not capped by a vertex budget | FIX (Dart reference + constant) | f52e52d. There is no Dart-side bake on the wire path; `d3BakedInstanceCount`/`d3BakeInstances` define the contract and the natives must apply it |
| UINT16 index overflow on large sphere/torus | Dart: N/A (always `Uint32List`) | Constant `kD3MaxUint16Vertices` documents the rule. The overflow is native (`FsceneRealizer.kt:1243` path, `MeshFactory.kt`) |
| Normals transformed with translation | FIX | f52e52d |
| Icosphere edge-key collisions + UV seam | FIX | f52e52d |
| Mirrored instances not rewound | FIX (Dart builder + reference bake) | f52e52d. The native bakes (`GeometryFactory.swift:1101`, `MeshFactory.kt:1685`) still need it |
| Closed tubes get caps | FIX | f52e52d |
| Zero plane segments → NaN | FIX | f52e52d |
| Instance bounds ignore payload matrices | FIX | d7884ff |
| `kPlannedFeatures` gates W15 | FIX | f6bdc96. `prefabInstances`/`streaming` are realized. An *uncomposed eager* instance is still reported missing, because the natives only render instance nodes as placeholders |
| Dart mirror drops polyline resource ops | FIX | 54e548b (`d3ExtensionResources`) |
| `TurbulenceModule._time` not reset | FIX | 4ddd4cc |
| Tagged `shadowCasterFaces` decode | Not a Dart bug | Dart only authors a `StringValue`. The mis-decode is iOS `FsceneRealizer.swift:3384` (PR #9 thread 4054616502, iOS owner) |
| Malformed viewport TypeError | FIX | 54e548b |
| `serializeScene` + `writeFscene` drops viewport | FIX | 54e548b (`writeFsceneWithExtensions`) |
| Harness timers not cancellable; W25/W18 overlap | FIX | 48167df (W18 moved +170 s → +192 s) |
| Tests only under `example/test` | FIX | f754291. 15 files moved to `dart3d/test` and run under `dn test` from `dart3d/`. The suites that read example assets, `tool/`, or example lib stay in `example/test` |
| README stale (iOS split-screen, W15+) | FIX | 700fba9 |

## Needs another owner

- **iOS:** `shadowCasterFaces` tagged decode (`FsceneRealizer.swift:3384`).
  Burst-only emitters emit nothing (PR #11 4059493130). Mirror the
  generator list above and the caps table.
- **Android:** the Kotlin `TurbulenceModule` clock reset (PR #11
  4058498628). Mirror the generator list above and the caps table,
  including UINT32 selection on the icosphere/sphere/torus paths.
- **Hygiene/CI:** `.github/workflows/dart3d.yml` runs `dn test` only in
  `dart3d/example`. Add a `dn pub get && dn analyze && dn test` step in
  `dart3d/` for the 257 package tests.
- **Docs:** `docs/particles-spec.md:244-246`,
  `docs/extended-surface-program.md:467`, and
  `docs/verification-matrix.md:466` still say W18 fires at +170 s. It
  now fires at +192 s.

## Known limits of these fixes

- W26 procedural-shape resources held in `d3ExtensionResources` don't
  contribute to `documentWorldBounds`. The raw entry isn't converted to
  typed params.
- The W25 dice-regression close-out passes on *any* settle event
  within 10 s. The self-running auto-reroll also produces settles, so
  it proves the sim is alive, not that this particular throw landed.
- Everything here is verified by `dn analyze` plus `dn test` only. No
  device runs.

## PR #14 review threads (stabilize/dart)

| Comment | File:line | Summary | Verdict | Evidence |
|---|---|---|---|---|
| 4122294463 | `lib/src/diff_apply.dart:558` | P2: Reject unsupported procedural shape names | FIX | 25b1222. Reproduced: `isD3ExtensionResourceJson` accepted `cylnder`. Now only `kD3ProcShapes` count, and a typo gets upstream's `FsceneFormatException` |
| 4122294474 | `lib/src/diff_apply.dart:527` | P2: Preserve extension resources through prefab composition | FIX | 25b1222. Reproduced: upstream `composeScene` output had neither the resource nor an extension entry. `composeScene[Async]WithExtensions` carries and remaps them; used by `loadDocumentComposed` and `loadSubtree[Async]` |
| 4122294480 | `lib/src/geometry/mesh_data.dart:188` | P2: Preserve normals for singular instance transforms | FIX | 25b1222. Reproduced: `diag(1,1,0)` zeroed the `(0,0,1)` normal. Now uses the cofactor normal matrix and falls back to the source normal. **Natives:** the Android bake keeps the source frame when singular. The Dart cofactor result differs from that for a rotated flattening (Dart rotates the surviving normal), so natives should adopt the cofactor form |

## PR #14 review threads, round 2

| Comment | File:line | Summary | Verdict | Evidence |
|---|---|---|---|---|
| 4122712642 | `lib/src/compose_extensions.dart:81` | P2: Avoid mutating shared prefab documents during composition | FIX | 6901693. Reproduced with two concurrent `composeSceneAsyncWithExtensions` calls sharing a cached prefab and staggered loads: a sentinel cuboid leaked into one output. Placeholders now go on per-call shallow clones; inputs are never mutated |
| 4122712653 | `lib/src/geometry/instances.dart:259` | P2: Cap matrix decoding before allocating transforms | FIX | 3e375f8. Confirmed by code reading: both bounds callers decoded every matrix, then truncated. `d3DecodeMatrices` now stops at `maxCount` (default `kD3MaxBakedInstances`) |
| 4122712661 | `example/lib/main.dart:420` | P2: Stop W25's roll from rearming auto-rerolls | FIX | a17ea6f. Confirmed by code reading: `_onPhysicsEvent` re-armed the 3 s reroll on every settle. wLoose's own timed rolls already did this before W25, so the "cancelled by wLoose" comment was never true. `AutoRerollGate`: wLoose suspends it for the generation, and a reload resumes it. Not device-verified |

### Draft replies (for the coordinator to post)

- **4122712642:** "Confirmed and fixed in 6901693. I reproduced it with two concurrent `composeSceneAsyncWithExtensions` calls sharing a cached prefab: the second call saw the first call's placeholder, skipped it, and leaked a sentinel cuboid into its output. Placeholders now go on per-call shallow clones of the host and each resolved prefab, so inputs are never mutated and there's no restore step. Test: `pr14_review_test` '4122712642 — concurrent composes share a cached prefab'."
- **4122712653:** "Confirmed and fixed in 3e375f8. Both bounds callers decoded the whole payload and then truncated. `d3DecodeMatrices` now takes `maxCount` (default `kD3MaxBakedInstances`) and never allocates past it. Test: `instance_bounds_test` 'matrix decode cap'."
- **4122712661:** "Confirmed and fixed in a17ea6f. Every settle re-armed the 3 s auto-reroll, so W25's close-out roll restarted the loop before W18. wLoose's own timed rolls already did that, so the loop was never really off after +78 s. A settle now re-arms only while `AutoRerollGate` is open: wLoose closes it for the rest of the scene generation, and a reload reopens it. Unit-tested (`phase_timers_test` 'auto-reroll gate'). Not verified on a device."

## PR #14 review threads, round 3

| Comment | File:line | Summary | Verdict | Evidence |
|---|---|---|---|---|
| 4123065167 | `lib/src/compose_extensions.dart:125` | P2: Avoid confusing authored cuboids with extension sentinels | FIX | 7f2b31c. Reproduced: an authored cuboid `(-1, -1, 0.5)` was swapped for an unrelated extension resource. Placeholders are now recognized by object identity: upstream passes `procedural` through by reference, and the specs are held in an identity map |
| 4123065174 | `example/lib/feature_scene.dart:4118` | P2: Own the W25 settle subscription | FIX | 23e6ac0. Confirmed: a test shows `firstWhere(...).timeout(...)` leaves a listener after timing out. The new `PhaseTimers.firstWithin` owns the listener and cancels it on match, on timeout, and on `cancelAll`; W25 uses it |

### Draft replies (for the coordinator to post)

- **4123065167:** "Confirmed and fixed in 7f2b31c. A test composing a host that authors `CuboidGeometrySpec(extents: (-1, -1, 0.5))` showed it replaced by an extension entry. Upstream `_remapResource` passes `procedural` through by reference, so each placeholder's spec object is now the key in an identity map, and dimensions no longer matter. Test: `pr14_review_test` '4123065167 — authored cuboids are never mistaken for sentinels'."
- **4123065174:** "Confirmed and fixed in 23e6ac0. A test shows `firstWhere(...).timeout(...)` leaves `hasListener` true after the timeout. The new `PhaseTimers.firstWithin` registers the listener with the generation and cancels it on match, on timeout, and on `cancelAll`, returning null on timeout. The W25 close-out uses it. Tests: `phase_timers_test` 'firstWithin' group. Not verified on a device."
