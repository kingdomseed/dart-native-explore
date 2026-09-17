# W6 — Android parity gaps

Closes the remaining iOS↔Android semantic gaps. Feasibility was
confirmed per row against the resolved jars (Filament 1.71.6,
filament-utils 1.71.6, jolt-jni 6.0.0) — nothing here needs an
invented semantic; each row is either already correct (verify lane
only) or maps onto a named engine feature.

## Already landed — verify lanes only

| Feature | Where |
|---|---|
| Emissive material | W4 — `emissive.w=0` exposure-weight fix |
| `doubleSided` | `FsceneRealizer` material decode → `MaterialInstance.setDoubleSided` |
| `linearAxisLocks`/`angularAxisLocks` | `decodeRigidBody` → `EAllowedDofs` bitmask |
| `ccdEnabled` | `decodeRigidBody` → `EMotionQuality.LinearCast` |
| Collision layer/mask | `JoltWorld.collisionGroup` → `GroupFilterTable`, upstream symmetric rule `(a.layer & b.mask) && (b.layer & a.mask)` |
| `concaveMesh` (static only) | `meshShape` + `mustBeStatic` → forces `fixed` body |

## To implement

### Ortho camera (`projection:{s:'orthographic'}`)

- iOS: `cam.usesOrthographicProjection = true` (+ `orthographicScale`
  if/when decoded — check the camera props).
- Android: `decodeCamera` stores `cameraProps` but `applyProjection`
  ignores `projection`. Map to
  `Camera.setProjection(Projection.ORTHO, left, right, bottom, top,
  near, far)`; ortho half-extents derive from the iOS semantic —
  SceneKit's `orthographicScale` is the view half-height in world
  units, so `top=scale`, `bottom=-scale`, `left/right` by aspect. If
  the wire carries no scale field use the iOS default. Keep the FOV
  path for `s:'perspective'`.

### AA levels (`viewConfig.antialiasingMode`)

- iOS semantics: 0 = none, 2/4 = MSAA sample count.
- Android today: boolean on/off + FXAA. Extend:
  `MultiSampleAntiAliasingOptions.enabled = v>0,
  sampleCount = v` (2 or 4 pass through), keep FXAA on top as iOS
  pairs MSAA with its own filtering. Values other than 0/2/4 clamp to
  the nearest supported count with a `logOnce` note.

### Shadow radius + bias (`castsShadow`, `shadowRadius`, `shadowDepthBias`)

- iOS: `light.shadowRadius` (blur), `light.shadowBias` (depth bias).
- Android: `decodeLight` only sets `castShadows`. Add
  `LightManager.Builder.shadowOptions(ShadowOptions)`:
  `shadowDepthBias` → `constantBias` (and split a share into
  `normalBias` — document the ratio chosen); `shadowRadius` →
  `shadowBulbRadius` (PCSS penumbra driver — Filament's closest
  semantic to SceneKit's blur radius; record the approximation in the
  matrix, do not claim equality). Always set a sane `mapSize`
  (≥1024) when shadows are enabled.

### `allowsResting` (rigidBody)

- iOS: `SCNPhysicsBody.allowsResting = false` → never sleeps.
- Android: `p.tag("allowsResting").d3Bool()` →
  `bcs.setAllowSleeping(false)` when false. Default stays true.

### `allowsCameraControl` (viewConfig)

- iOS: `SCNView.allowsCameraControl` (built-in orbit/pan/zoom).
- Android: filament-utils `Manipulator` (already a dependency —
  `Manipulator.Builder(Mode.ORBIT)` / `map` modes; check jar for the
  exact builder API). Wire the view's `onTouchEvent` →
  `grabBegin/grabUpdate/grabEnd`, pinch → `scroll`, then
  `getCurrentBookmark` (eye/center/up) → write the camera node's
  transform so the per-frame `setModelMatrix` picks it up. When the
  flag is false the manipulator detaches and the camera returns to
  node-authored pose. Document in the matrix that the manipulation
  writes back through the camera node — a `setNodeTransforms` on the
  camera node while controlling fights the manipulator (same on iOS).

### `showsStatistics` (viewConfig)

- iOS: `SCNView.showsStatistics` HUD.
- Android: `Dart3dView` is a `FrameLayout` — add a `TextView` overlay
  child (top-left, translucent dark bg, monospace ~11sp), updated
  ~4×/s from the render callback: fps, frame ms, entity count,
  body count. Attach/detach with the flag.

## Harness probes (Dart)

Extend `feature_scene.dart` — prefer probes that don't disturb the
settle watchdog:

- `doubleSided`: a quad authored backface-first (visible only when
  double-sided).
- `allowsResting:false`: add via the W5 `+8 s` diff as a new body —
  it joins after settle already fired, so the settle lane stays
  clean. Verify via Jolt `isActive` logging / iOS body state.
- `concaveMesh`: a static open-top box (five-face bowl) collider the
  die can drop into — or apply it to the ground slab if the die's
  landing reads better.
- Shadow: one directional light already casts — set `shadowRadius`/
  `shadowDepthBias` on it so the lane exercises real values.
- Ortho/AA/camera-control/stats: existing viewConfig toggles and the
  Ortho button already reach the wire — no new probes needed.

## Verify

Ten lanes per the program doc. `dart analyze` + Kotlin release
compile + iOS unchanged (regression only). Save evidence under
`docs/artifacts/w6/`. Frame-rate rule: Android within 15 % of iOS on
the same scene; the stats overlay must not measurably cost frames
(update ≤4 Hz).

## Outcome (post-verification)

All lanes pass on both platforms; results in
`docs/verification-matrix.md`, evidence in `docs/artifacts/w6/`.
Corrections to this spec's assumptions found during verification:

- **iOS was not unchanged**: `allowsResting` was never decoded and
  `orthoScale` was emitted but unread. Both fixed in
  `FsceneRealizer.swift` (`body.allowsResting`, `orthoScale`/`orthographicScale`
  → `SCNCamera.orthographicScale`). The parity matrix had assumed the
  iOS side already carried them.
- **`shadowRadius` is an approximation, not a match**: Filament's
  `shadowBulbRadius` (PCSS penumbra) is the closest semantic to
  SceneKit's blur radius. `shadowDepthBias` splits into Filament
  constant + normal bias (0.005 / 0.0025).
- **The "duplicate body" log line was a logging artifact**, not a
  leak: two interleaved app sessions in the logcat buffer each ran
  their own +8 s diff; the second run's fresh session salt re-keys
  every node. A clean single-process run shows one body.
- **Lane 9 containment is deferred**: the `concaveMesh` collider
  realizes as a fixed concave body on both platforms, but a body
  resting inside the bowl is a luck-based bounce — tracked with the
  W3 margin evidence in loose ends.
