# W9 — joints and extended physics

Cross-SDK spec for physics joints, modeled on upstream
`package:scene` (0.3.0) `physics/joint_desc.dart` and
`physics/simulation.dart`. **Upstream joints are runtime-only** —
`PhysicsSimulation.createJoint(JointDesc)→int`, `updateJoint`,
`destroyJoint`; no `.fscene` component encodes them. dart3d follows the
same model: joints are a command-op family carrying `JointDesc` field
for field, so upstream-authored documents need no new schema and the
interchange surface stays identical.

## Wire — joint ops (Dart → native `command` channel)

```json
{"op":"addJoint","id":7,"type":"revolute",
 "a":"<token>","b":"<token>","ca":0,"cb":0,"collide":false,
 "anchorA":[x,y,z],"anchorB":[x,y,z],
 "axisA":[x,y,z],"axisB":[x,y,z],
 "lower":-1.57,"upper":1.57,
 "motorVelocity":2.0,"motorMaxForce":50.0,
 "breakDistance":0.5}
{"op":"updateJoint","id":7, ...same fields as addJoint...}
{"op":"removeJoint","id":7}
```

- `id`: caller-chosen u32 handle (upstream's `int` return value). One
  id space per view; reuse after `removeJoint` is legal.
- `a`/`b`: node `LocalId` tokens of the joined bodies. `ca`/`cb`:
  collider index within the node (default 0) — joints attach to
  colliders in upstream; a node's colliders compose one body today so
  `0` is the norm.
- `collide`: upstream `collisionsEnabled` (default `false` — joined
  bodies don't collide with each other).
- Anchors and axes are **body-local** on the wire (upstream's
  `localAnchorA`/`localAxisA` semantics). Natives convert to whatever
  frame their engine wants at creation (Jolt settings take world-space
  at create; SceneKit takes body-local — see below).
- `updateJoint` recreates the native constraint in place when the
  engine lacks in-place update (upstream's own contract: "backends
  without in-place updates can recreate internally").
- If `a`/`b` isn't a live rigid-body node yet, the op defers like a
  payload claim — joints arriving before their bodies resolve on the
  bodies' realization (or warn-no-op if `b` is a plain missing token).
- `breakDistance` (extension, optional): see "Breaking" below.

## Wire — joint types (mirror `JointDesc` subclasses)

| `type` | JointDesc | Fields |
|---|---|---|
| `fixed` | FixedJointDesc | `anchorA`, `anchorB` |
| `spherical` | SphericalJointDesc | `anchorA`, `anchorB` |
| `revolute` | RevoluteJointDesc | `anchorA/B`, `axisA/B`, `lower`?, `upper`?, `motorVelocity`?, `motorMaxForce`? |
| `prismatic` | PrismaticJointDesc | same as revolute |
| `generic` | GenericJointDesc | `anchorA/B`, `basisA`/`basisB` quats, `axes` |

`generic.axes`: six entries in `JointAxis` order
(`linearX,linearY,linearZ,angularX,angularY,angularZ`), each:

```json
{"motion":"locked|free|limited","lower":f,"upper":f,
 "motor":{"targetPosition":f,"targetVelocity":f,"stiffness":f,
          "damping":f,"maxForce":f,"model":"acceleration|force"}}
```

`motor` may be omitted; `lower`/`upper` required when `limited`.

## Wire — joint events (native → Dart, `D3Event.joint = 5`)

```json
{"kind":"broke","id":7,"a":{"s":,"i":},"b":{"s":,"i":}}
```

Upstream has no joint events — this is a dart3d extension for the
`breakDistance` feature. Only `broke` exists today; `kind` leaves the
type open.

## Breaking (dart3d extension)

Neither engine breaks constraints natively, and SceneKit exposes no
constraint-force readout at all — so the portable semantic is
**geometric**: each physics step, the native side computes the
world-space separation of the joint's two anchors
(`|worldAnchorA − worldAnchorB|`); when it exceeds `breakDistance`,
the constraint is removed and a `joint` `broke` event fires.
Identical rule on both engines, one-line-per-joint cost. Jolt's
`Constraint.getTotalLambda*` force readout is deliberately NOT used —
engine-uniform semantics beat per-engine fidelity here.

Without `breakDistance`, joints never break (both engines hold the
constraint under overload — documented native behavior, lane 10
exercises it).

## iOS realization (SceneKit)

- `SCNPhysicsBallSocketJoint` ← spherical; `SCNPhysicsHingeJoint` ←
  revolute (`minimumAngularLimit`/`maximumAngularLimit`,
  `motorTargetAngularVelocity`/`motorMaximumTorque`);
  `SCNPhysicsSliderJoint` ← prismatic (`minimumLinearLimit`/
  `maximumLinearLimit`, `motorTargetLinearVelocity`/`motorMaximumForce`);
  `SCNPhysicsFixedJoint` ← fixed. All live under `SCNPhysicsBehavior`,
  added/removed via `scene.physicsWorld.addBehavior`/`removeBehavior`.
- **Generic has no SceneKit primitive** — decompose by axis config:
  - all six locked → `SCNPhysicsFixedJoint`
  - linear locked + exactly one angular free/limited → hinge on that
    axis
  - angular locked + exactly one linear free/limited → slider on that
    axis
  - anything else → warn once, fall back to the nearest primitive that
    covers the *free* axes (documented approximation)
- `collide` maps to removing the pair's collision when false — check
  how the realizer disables a body pair today (category/mask surgery or
  `SCNPhysicsBody.affectedBy`); if pairwise exclusion is infeasible
  post-hoc, document and keep collisions on (Jolt disables pair
  collision natively via `TwoBodyConstraint`'s creation settings).
- Break polling: in `renderer(_:didSimulatePhysicsAtTime:)` compute
  anchor world positions from body nodes; on violation →
  `removeBehavior` + event.
- Joint bookkeeping on the host: `joints: [UInt32: JointRecord]` with
  the spec'd fields retained for `updateJoint` recreate + break polling.

## Android realization (jolt-jni 6.0.0)

- `FixedConstraint` ← fixed; `PointConstraint` ← spherical;
  `HingeConstraint` ← revolute (`setLimits(min,max)`,
  `setMotorState(EMotorState.Velocity)`, `setTargetAngularVelocity`,
  `setMaxFrictionTorque` ← `motorMaxForce`); `SliderConstraint` ←
  prismatic (same shape, linear units); `SixDofConstraint` ← generic —
  per-`EAxis` limits (`EAxis.TranslationX..RotationZ` order matches the
  wire's `JointAxis` order), `MotorSettings` per axis, springs for
  stiffness/damping.
- Constraint settings take **world-space** anchors/axes at creation —
  transform wire-local anchors/axes through the bodies' current poses
  (JoltWorld keeps body poses; convert scene-space→Jolt-space with the
  same LH→RH mirror `D3Wire` uses).
- `collide:false` → the settings' pair-collision flag
  (`TwoBodyConstraint`-level). `SixDofConstraint` also needs basis
  quats converted to its constraint-space frames.
- `SwingTwistConstraint` exists but upstream has no swing-twist desc —
  out of scope, noted.
- Joints live in JoltWorld: `joints: Map<Int, JointRecord>` holding
  the `TwoBodyConstraint` + wire fields for update-recreate + break
  polling in `update()` post-step.
- `PhysicsSystem.addConstraint`/`removeConstraint`; body lookup via
  the W8 `bodyNodeKeys` map's inverse (`nodeKey→body`).

## Dart side

`physics.dart`: `SceneJointType` enum + `SceneJoint` value type
carrying the wire fields (mirroring `JointDesc` naming); no event
types beyond decoding `{"kind":"broke"}` into `SceneJointBroke` on a
new `Stream<SceneJointBroke> get jointEvents` (or fold into a sealed
`SceneJointEvent`).

`scene_controller.dart`: `addJoint(SceneJoint)→int id`,
`updateJoint(id, SceneJoint)`, `removeJoint(id)` — thin command-op
senders with a per-controller `_jointSeq` counter (no `Future` —
upstream's handle-returning API is synchronous client-side; the native
apply is async by construction).

`protocol.dart`: document the op family + `joint` event.

## Harness probes

Extend `feature_scene.dart` with a joint rig (new nodes, added by the
existing manifest so ids are stable):

- **Pendulum**: kinematic/static anchor + dynamic bob on a `spherical`
  joint — swings, pivots in place.
- **Door**: static frame + dynamic panel on a `revolute` joint, axis
  vertical, `lower`/`upper` limits ±100° — door swings and stops.
- **Elevator**: dynamic platform on a `prismatic` joint, axis vertical,
  `motorVelocity` driving it up/down — slides without rotating.
- **Welded pair**: two dynamic boxes on a `fixed` joint — move as one.
- **Chain**: 5 links of `spherical` joints — hangs, swings stably.
- **Generic**: a `generic` joint with linear-locked + one limited
  angular axis — same silhouette as a hinge, exercises the decode.
- **Breakable**: a jointed pair with `breakDistance` — a scripted
  impulse separates them; `jointEvents` logs the `broke`.

Add via a "+12s" phase (after the W8 +10s query battery) that adds the
rig through `addJoint` ops — proves the runtime-ops path, which is the
point (upstream joints are runtime objects, not document data). A
status-line joint count + `broke` log entries make the lanes readable
on screenshots.

## Deferred / approximations

- iOS generic → primitive decomposition (no 6DOF in SceneKit).
- iOS `collide:false` best-effort (pairwise post-hoc exclusion may be
  infeasible — documented if so).
- `breakDistance` is geometric, not force-based — the only semantic
  expressible on both engines.
- `JointMotor.stiffness`/`damping`/`model` (generic axes) map to Jolt
  `SpringSettings` natively; on iOS they're best-effort (hinge/slider
  motors are velocity+maxforce only) — documented.

## Verify lanes (both platforms)

1. Regression — free-body dice still settle.
2–3. Fixed joint welds two bodies — they move as one.
4. Spherical pendulum pivots in place.
5. Revolute door rotates on one axis, stops at limits.
6. Prismatic elevator slides without rotating; motor drives it.
7. Generic joint respects combined limits.
8–9. Five-link chain stays stable — no explosion, no NaN.
10. `breakDistance` joint separates under impulse; `broke` event fires.
Perf: ten-joint scene holds 30fps (easily — joints are per-constraint
cost, not per-step events).
