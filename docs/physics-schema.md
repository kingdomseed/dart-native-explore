# Physics component schema (W2)

Source of truth: `flutter_scene` 0.23.0 `physics_codecs.dart` and
`package:scene` 0.3.0 `sim_types.dart`. dart3d adopts the upstream
vocabulary wholesale so a `.fscene` document authored for flutter_scene
realizes under dart3d without rewriting, and vice versa.

This wave renames the dart3d-local property names introduced before the
upstream codec was surveyed. Old names are deleted in the same wave —
there is no compatibility shim, per the program's no-shim rule.

## rigidBody

| Property | Type | Default | Notes |
|---|---|---|---|
| `type` | string | `dynamic` | `fixed`, `kinematic`, or `dynamic`. Replaces dart3d `kind`; `static` becomes `fixed`. |
| `mass` | number | absent | Kilograms. Absent derives mass from the colliders. |
| `linearDamping` | number | `0.0` | Per-step linear velocity damping, 0–1. |
| `angularDamping` | number | `0.0` | Per-step angular velocity damping, 0–1. |
| `useGravity` | bool | `true` | Whether world gravity accelerates the body. Replaces `isAffectedByGravity`. |
| `ccdEnabled` | bool | `false` | Continuous collision detection. Replaces `ccdThreshold` (double). **SceneKit semantic warning:** `continuousCollisionDetectionThreshold` is a per-step *distance* threshold and `0.0` means CCD DISABLED, not always-on — `ccdEnabled: true` must set a small positive threshold (use `0.001`, i.e. CCD engages once a body moves more than 1 mm per step — effectively always-on for anything that matters); `false` leaves the 0.0 default. Jolt: `true` → `EMotionQuality.LinearCast`, `false` → `Discrete`. |
| `linearAxisLocks` | vec3 | `(1,1,1)` | Per-axis linear motion factors, 1 free and 0 locked. Replaces `linearFactor`. |
| `angularAxisLocks` | vec3 | `(1,1,1)` | Per-axis angular motion factors. Replaces `angularFactor`. |

Dropped dart3d-local properties, with reasons:

- `friction`, `restitution` — upstream keeps surface material on the
  collider (`collider.material`), not the body. SceneKit's body-level
  fields were the model here; the collider is now the only site.
- `collisionCategory`, `collisionMask`, `contactMask` — upstream puts
  `collisionLayer`/`collisionMask` on the collider. `contactMask` has
  no upstream equivalent (it gates SceneKit contact-delegate callbacks);
  it returns when W8 lands contact events using the upstream model.
- `allowsResting` — no upstream equivalent. SceneKit defaults it true;
  Jolt exposes `allowSleeping` on the body. Not carried.

Kept as dart3d extension properties (upstream decoders ignore unknown
fields, so interchange is unaffected):

- `velocity` (vec3), `angularVelocity` (vec4 axis+rate) — upstream
  deliberately does not persist velocities ("live simulation state"),
  but dart3d keeps them as initial-velocity extensions so a document
  can launch a body without a follow-up command.

## collider

| Property | Type | Default | Notes |
|---|---|---|---|
| `shape` | tagged-union map | `{kind:'box', halfExtents:(0.5,0.5,0.5)}` | See shape table below. Replaces dart3d's flat `shape` string plus sibling `extents`/`radius`/`height`/`center`. |
| `material` | map | defaults below | Surface properties at contacts. |
| `collisionLayer` | int | `0xFFFFFFFF` | Bitmask identifying this collider's layer. See the platform-mapping note below. |
| `collisionMask` | int | `0xFFFFFFFF` | Bitmask of layers this collider responds to. |
| `isTrigger` | bool | `false` | No contact response — bodies pass through. Expressible today: Jolt `setIsSensor(true)`, SceneKit `collisionBitMask = 0`. Event emission lands with W8; for now the shape is a pure sensor. |
| `localPose` | matrix4 | identity | Collider pose relative to the owning node. Replaces `center` (translation-only writes become a translation matrix). |

`material` map fields: `friction` (number, 0.5), `restitution`
(number, 0.0), `density` (number, 1.0), `frictionCombine` and
`restitutionCombine` (string: `average`, `minimum`, `maximum`,
`multiply`). Combine rules are decoded and stored; iOS maps them onto
`SCNPhysicsBody` material fields where expressible, Android to Jolt's
combine mode where expressible. An inexpressible rule falls back to
`average` with a `logOnce` warning.

### Platform mapping: collision layer/mask on SceneKit

SceneKit's response test is pairwise-AND: bodies collide only when
each body's `collisionBitMask` includes the other's `categoryBitMask`.
Two category bits are reserved — `0x1` (`Default`) and `0x2`
(`Static`, which unlayered static bodies are auto-assigned) — and
every *static* body's collision mask force-excludes bit `0x2`. A body
whose category is exactly `0x2` therefore can never contact any static
body on iOS.

The decoder maps the wire space out of the reserved range:
`categoryBitMask = (layer ?? 1) << 2` and `collisionBitMask =
mask << 2`. An absent layer lands on user bit 0, so a mask of `0x1`
still reaches unlayered bodies. Android's Jolt `GroupFilterTable`
consumes the wire values directly — object layers there are indices,
not bitmasks, so no shift is needed and the wire is unchanged.

### shape union (upstream vocabulary)

| `kind` | Fields | dart3d support |
|---|---|---|
| `sphere` | `radius` (0.5) | both platforms |
| `box` | `halfExtents` (vec3) | both; note HALF extents — dart3d's old `extents` was full size, emitters halve it |
| `capsule` | `radius`, `halfHeight` | both; `halfHeight` is the cylindrical section's half length along local Y — Jolt's ctor wants exactly this, SceneKit wants total height (`2*halfHeight + 2*radius`) |
| `cylinder` | `radius`, `halfHeight` | Jolt `CylinderShape`; SceneKit `SCNPhysicsShape` cylinder |
| `convexHull` | `points` → payload token (float32 xyz triples) | W2 keeps dart3d's derived-hull behaviour: when `points` is absent, derive from the node's realized geometry (extension). Explicit payload lands with W3. |
| `triMesh` | `vertices`, `indices` → payload tokens | W2 decodes the shape; payload resolution lands with W3. iOS `concavePolyhedron`, Jolt `MeshShape` (static bodies only). |
| `heightField` | `width`, `depth`, `heights` → payload, `scale` | deferred to W3+; log once and skip |
| `compound` | `children` list of `{shape, localPose}` | decode recursively; Jolt `StaticCompoundShape`, SceneKit `SCNPhysicsShape` with child transforms |

Extension kinds (dart3d-only, inside the same union): `boundingBox`
(derive a box from the node's realized geometry — the historical
default) and `concaveMesh` (alias for `triMesh` derived from node
geometry rather than payloads; static bodies only). An upstream decoder
falls back to a unit box on these, which is acceptable degradation.

## physicsWorld

| Property | Type | Default | Notes |
|---|---|---|---|
| `backend` | string | `basic` | Upstream names a registered simulation backend. dart3d has exactly one backend per platform (SceneKit physics / Jolt); `backend` is accepted and ignored — log once when present so documents naming `rapier3d` surface the gap instead of silently running the wrong sim. |
| `gravity` | vec3 | `(0,-9.81,0)` | Already supported. |
| `fixedTimestep` | number | `1/60` | Step length in seconds. W2 stores it; the Android stepper already runs a fixed step — wire it through. iOS SceneKit runs its own internal stepping; store and document that it is advisory there. |
| `maxSubsteps` | int | `8` | Max fixed steps per frame. Same advisory caveat on iOS. |

## Decode order

Unchanged: colliders and bodies decode in the deferred physics pass
after geometry, because `boundingBox`/`convexHull`/`concaveMesh`/
`triMesh`-derived shapes read realized mesh data. `material` rides on
the collider; nothing folds onto the body any more.

## Migration notes

Emitters change signature in `dart3d/lib/src/physics.dart`; example
call sites (`feature_scene.dart`, `cube_scene.dart`) update in the same
change. `kind: 'static'` becomes `type: 'fixed'`;
`shape: 'box', extents: v` becomes `shape: {kind: 'box',
halfExtents: v * 0.5}`. The Dart emitter API keeps its ergonomic shape
(`colliderComponent(shape:'box', extents:v)`) — it translates to the
upstream map on write, so callers do not build tagged unions by hand.
