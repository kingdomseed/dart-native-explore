# W12 — Component parity: joint components, rectAreaLight, materialsVariants, `enabled`, feature gating

W11 verified skins/animation/morphs end-to-end. This wave closes five
small parity items from the W10 audit — all decode work riding existing
machinery. Upstream sources: `flutter_scene-0.23.0/lib/src/fscene/realize/
physics_codecs.dart` (joints), `builtin_codecs.dart` (variants, rectArea),
`component_codec.dart` (`enabled`), `scene-0.3.0/lib/src/json/fscene_json.dart`
(feature gate).

## 1. Joint components → the W9 constraint path

Upstream serializes joints as **one-sided node components** — the
component sits on body A; `otherNode` (`{'nref': token}`) names B;
absent `otherNode` anchors to the world.

Wire shape (all values tagged — `{'v3':[…]}`, `{'q':[…]}`, `{'b':…}`,
`{'d':…}`/`{'i':…}`, `{'map':{…}}`):

```json
{"type":"revoluteJoint","properties":{
  "otherNode":{"nref":"node:…"},          // absent → world anchor
  "localAnchorA":{"v3":[x,y,z]},          // body-A-local, .fscene space
  "localAnchorB":{"v3":[x,y,z]},
  "localAxisA":{"v3":[x,y,z]},            // revolute/prismatic only
  "localAxisB":{"v3":[x,y,z]},
  "lowerLimit":{"d":…},                   // optional; absent = unlimited
  "upperLimit":{"d":…},
  "motorTargetVelocity":{"d":…},          // optional; absent = no motor
  "motorMaxForce":{"d":…},
  "collisionsEnabled":{"b":false}         // default false, like the ops
}}
```

`fixedJoint`/`sphericalJoint` carry only `otherNode`, `localAnchorA/B`,
`collisionsEnabled`. `genericJoint` carries `otherNode`,
`localAnchorA/B`, `localBasisA`/`localBasisB` (`{'q':[x,y,z,w]}`), and
`axes` — a **map** keyed by `JointAxis` name
(`linearX, linearY, linearZ, angularX, angularY, angularZ`), each value
`{'map':{motion:{s},lowerLimit:{d},upperLimit:{d},motor:{map:{targetPosition,
targetVelocity,stiffness,damping,maxForce,model}}}}` — decode it into the
same six-entry list the W9 `axes` op field uses, in enum order.

**Mapping.** Feed the existing joint machinery — no second path:

- Type name: strip the `Joint` suffix — `fixedJoint`→`fixed`,
  `sphericalJoint`→`spherical`, `revoluteJoint`→`revolute`,
  `prismaticJoint`→`prismatic`, `genericJoint`→`generic`.
- `a` = the component's node key; `b` = `otherNode`'s key.
- Component fields → record fields: `localAnchorA/B`→`anchorA/B`,
  `localAxisA/B`→`axisA/B` (same body-local .fscene space — the
  existing z-mirror rules apply unchanged: revolute axis is a
  pseudovector (−x,−y,z), prismatic a direction (x,y,−z)),
  `lowerLimit`/`upperLimit`→`lower`/`upper`,
  `motorTargetVelocity`→`motorVelocity`, `motorMaxForce`→
  `motorMaxForce`, `collisionsEnabled`→`collide`,
  `localBasisA/B`→`basisA/B`. `breakDistance` is op-only — absent
  on components.
- Angular scalars flip sign under the mirror exactly as the op path
  documents (revolute limits swap/negate into Jolt's bracket, motor
  velocity negates; prismatic scalars pass through) — **reuse the op
  decode, don't re-implement it.**

**Identity + lifetime.** Components carry no joint id. Keep a
*separate* registry keyed by `(nodeKey, componentIndex)` → the record —
no id-space carving against caller-chosen op ids. Teardown: drop a
node's component joints inside the component-rebuild path
(`clearComponentState` on iOS / the components re-decode on Android)
and on `removeNode` (the existing orphan sweep also catches them via
their a/b keys). Component joints break like op joints — same event
path; a broke component joint's record is dropped.

**World anchor** (`otherNode` absent, or the ref fails to resolve —
upstream logs and anchors to world):
- iOS: single-body SceneKit inits where they exist
  (`SCNPhysicsBallSocketJoint(bodyA:anchorA:)`,
  `SCNPhysicsSliderJoint(bodyA:axisA:anchorA:)`, hinge likewise) —
  verify availability at the deployment target; otherwise a hidden
  static body pinned at the world-space anchor. `anchorB` for a world
  anchor is a **world-space** point (the world "body" has identity
  pose).
- Android: `Body.sFixedToWorld()` (confirmed in jolt-jni 6.0.0) as
  body B — `nodeKeyB` sentinel `0L` on `JointDesc` (real LocalId keys
  are session-prefixed, never 0). Body-local `anchorB` through an
  identity-pose body = the same world-space point.

**Deferral.** Joints are physics — they decode in the deferred pass
beside `rigidBody`. A missing B body (or a missing A body — the
component node may carry no rigidBody) defers exactly like W9 ops:
iOS `retryPendingJoints` on node landings; Android `realizeJoint`
retries from `addBody`. A component joint on a node with no body at
all logs once and stays deferred (upstream anchors to bodies; a
body-less A never realizes — that's the honest behavior, and the
warning makes it loud).

## 2. `rectAreaLight` — finish iOS, approximate Android

Wire: `color` `{'v3':…}` linear RGB, `intensity` `{'d'}`,
`width`/`height` `{'d'}` (panel along local X/Y, radiating +Z),
`range` `{'d'}` (0 = infinite).

- **iOS**: already dispatches `.area`; add
  `areaType = .rectangle`, `areaExtents = CGSize(width, height)`,
  `drawsArea = true` (the panel renders visible — matches upstream's
  gizmo intent), `range` → `attenuationEndDistance` when > 0.
- **Android**: Filament `LightManager` has no area type. Approximation
  (documented, log-once): a 2×2 cluster of `Type.POINT` lights at
  `±width/4, ±height/4` in the node's local plane, color applied, each
  light's intensity = `intensity × (width × height) / 4` in candela
  (area light = distributed emission; total ≈ radiance × area — tune
  the constant so a 1×1×1 panel reads ≈ a point light of `intensity`),
  `range` → `setFalloff`. Plus an unlit emissive quad sized
  w×h in the panel plane (emissive = color × intensity, clamped) so the
  source is visible — parity with iOS `drawsArea`. The quad must not
  cast into the light cluster or physics — renderable only, no
  collider.

## 3. `materialsVariants`

Wire (component, usually on a mesh node or a root):

```json
{"type":"materialsVariants","properties":{
  "variants":{"list":[{"s":"red"},{"s":"blue"}]},
  "selected":{"s":"blue"},                // optional
  "bindings":{"list":[{"map":{
     "node":{"nref":"node:…"},
     "primitive":{"i":0},
     "default":{"rref":"mat:…"},          // optional
     "materials":{"map":{"0":{"rref":"mat:…"},"1":{"rref":"mat:…"}}}
  }}]}
}}
```

`materials` keys are **indices into `variants`**. Semantics (upstream
`MaterialsVariantsCodec.realize` + `MaterialsVariantsComponent.select`):
bindings resolve **after** the node pass (upstream uses
`afterRealize`); on `selected` (or a runtime select), each binding's
primitive gets `materials[indexOf(selected)]` when mapped, else its
recorded `default` (absent → the material the primitive already
carries, captured at bind time). Deselect (selected absent/unknown)
re-applies defaults.

Upstream rebase rule (keep it): if the primitive's current material is
neither the recorded default nor any variant mapping — an explicit
reassignment landed — it wins and becomes the new default.

Native realization:
- iOS: `geometry.materials[primitive]` swap on the target node's
  `SCNGeometry`. Resolve `rref`→`SCNMaterial` through the realized
  material table.
- Android: `RenderableManager.setMaterialInstanceAt(entity, 0, mi)`
  (one primitive per renderable today — `primitive` != 0 logs once).
- Pending bindings: when the target node/mesh or a variant material
  isn't live at decode, record the binding unresolved; resolve on the
  first select that touches it and on resource/node landings (the
  existing consumer-map pattern) — or lazily at every select with a
  warn-once per unresolved binding. Either way, silent drops are a
  bug; unresolved bindings must log.

New op:

```json
{"op":"selectVariant","node":"<localId>","selected":"blue"}
```

`node` = the node carrying the `materialsVariants` component;
`selected` absent/null/unknown → reapply defaults. Dart:
`SceneController.selectMaterialVariant(LocalId node, String? name)`.

## 4. `enabled` — corrected scope

**Correction to the W10 audit framing**: upstream `Component.enabled`
gates only `update`/`fixedUpdate` ticks (`component.dart:128,135`) and
the planar-reflector capture check (`scene.dart:721`). It does **not**
gate light emission, camera selection, mesh draw, or body simulation —
a `enabled:false` light still lights upstream; a disabled rigidBody
still simulates. The audit's "light off / camera ignored / body
removed" framing was wrong; observable `enabled:false` behavior in
dart3d is *already* upstream parity for every realized component type.

What W12 actually lands:

- Decode `enabled` (`{'b':bool}`, default true) on every component on
  both platforms; store it on the native component record (or a
  per-node disabled-set) so the flag survives decode and future
  tick-gated components (W18 particles, anything `update`-driven)
  consult it.
- `logOnce` per disabled component type: "enabled:false decoded —
  upstream gates component ticks only; stored, no visual effect". No
  "unhandled property" noise.

## 5. Feature gating (Dart-side)

Upstream `decodeDocument` already refuses `featuresRequired` entries
outside `{skinning, prefabInstances, streaming, renderTextures}` — the
hard gate is free through package:scene. The residual gap: a doc
*requiring* `streaming` parses fine, then degrades silently on natives
that don't realize it.

In `SceneController.loadDocument` (and the diff path), after the
document lands:

- For each feature in `doc.featuresRequired` not in the realized set —
  `dnLog` a warning: `document requires feature 'X' that dart3d
  natives do not realize yet (planned W…); scene may be degraded`.
- `featuresUsed` (e.g. the importer's `materialsVariants` marker) —
  same pass, info-level (`used` is advisory, not a refusal).
- Realized set at W12 head: `{skinning, materialsVariants}`.
  Unrealized: `prefabInstances`→W15, `streaming`→W15,
  `renderTextures`→W14. Unknown names warn generically.
- Warn once per feature per document load.

## Harness — the W12 phase (+20 s)

In `feature_scene.dart`, a `w12Phase` the app fires at +20 s (after
W11's +14/+16/+18 sequence settles):

- `w12.pendAnchor` (static box overhead) + `w12.pendBob` (dynamic box
  below) — `revoluteJoint` **component** on `pendBob` with
  `otherNode`→pendAnchor, `localAxisA`=[0,0,1], motor on. The bob
  visibly articulates — a component-declared joint producing the same
  constraint the W9 ops built.
- `w12.tether` — dynamic ball, `sphericalJoint` component, **no
  `otherNode`** — hangs from a fixed world point and swings.
- `w12.panel` — `rectAreaLight` over a small white card; panel +
  spill visible on both platforms (Android: cluster + emissive quad).
- `w12.badge` — cube + `materialsVariants` (variants red/blue,
  binding on primitive 0, default = red). Install unselected; at
  +21.5 s a `selectVariant` op flips it blue. Screenshot shows the
  swap.
- `w12.dimBulb` — point light with `enabled:false` — still lights
  (upstream parity), logged as stored-not-gated.
- `featuresRequired: {'streaming'}` on the document — the capability
  warning must appear in the log at install.
- Status line: keep `joints:`/`anims:`; the W12 phase logs
  `dart3d: w12 phase — component joints, area light, variants`.

## Verification lanes

1. Spec first (this doc), then delegates.
2. Component joint produces a real constraint — pendulum articulates
   under the motor, tether swings from the world anchor, both
   platforms.
3. rectAreaLight: panel visible iOS (`drawsArea`), lit patch both
   platforms (Android cluster approx documented in log).
4. Variant select: badge red→blue on the op; install-time `selected`
   honored.
5. `enabled:false` decodes without noise; parity logged.
6. `featuresRequired` warning in the log at install.
7. Regression: full W5–W11 state live (dice, joints, contacts, anims).
8. Tests + analyze clean; both builds clean.
9. Perf: no frame-rate regression.
10. Operator review.

## Boundaries

- No `breakDistance` on component joints (upstream components don't
  carry it — op-only feature).
- Android rectAreaLight is an approximation — documented, not parity.
- `enabled` stores the flag; tick gating lands with the components
  that tick (W18).
- `selectVariant` addresses the component's *node*, not an index —
  one variants component per node is the supported shape (upstream
  allows N; a second component on one node warns once).
