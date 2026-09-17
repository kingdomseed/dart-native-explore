# W8 — physics events and queries

Cross-SDK spec for contact events and physics queries, modeled on
upstream `package:scene` (0.3.0) `physics/sim_types.dart`,
`physics_world.dart`, and `flutter_scene`'s `physics/events.dart` +
`physics/queries.dart`. Native engines (SceneKit, Jolt) expose both
surfaces natively; the wire carries them through the existing channels:
events via `d3FireToDart`, queries as `command` ops answered by a new
`queryReply` event. No new transport plumbing.

## Upstream model (the semantic contract)

- **Events** (`events.dart`): `CollisionBegan{nodeA,nodeB,colliderA,
  colliderB,contacts:List<ContactPoint>}`, `CollisionEnded`,
  `TriggerEntered`, `TriggerExited`. Lifecycle only — upstream has no
  "persisted" event, so native `didUpdate`/`onContactPersisted`
  callbacks are dropped, not shipped.
- **ContactPoint** (`sim_types.dart`): `worldPosition`, `worldNormal`,
  `impulse`, `separation`.
- **Queries** (`queries.dart`): `raycast(ray)→RaycastHit?`,
  `raycastAll`, `overlapSphere(center,r)`, `overlapBox(center,…)`,
  `shapeCast(…)` → `{node, collider, worldPoint, worldNormal,
  distance}` (`OverlapHit` is just `{node, collider}`). Upstream's
  `shapeCast` supports sphere shapes only — same bound here.
- Upstream reports **all** contacts — no contact-mask field exists on
  the wire. (`docs/physics-schema.md`'s parked `contactMask` note
  resolves here: the mask concept stays out; both engines report every
  contact and the Dart stream carries them all.)

## Wire — events (native → Dart, `D3Event.contact = 3`)

One event per collider-pair lifecycle transition:

```json
{"kind":"began",
 "a":{"s":<session>,"i":<index>},"ca":<collider index>,
 "b":{"s":…,"i":…},"cb":<…>,
 "points":[{"p":[x,y,z],"n":[x,y,z],"imp":12.3,"sep":-0.01}]}
```

- `kind`: `began` | `ended` | `triggerEntered` | `triggerExited`.
  Trigger kinds replace began/ended when either collider is a sensor
  (`isTrigger` → Jolt `isSensor`, SceneKit `collisionBitMask == 0`).
- `a`/`b`: node `LocalId`s. `ca`/`cb`: the collider's index within that
  node's `components` array (upstream keys events by collider, not
  node). Best-effort on both engines — `0` when the platform can't
  disambiguate a compound.
- `points`: only on `began`, `[]` allowed. Maps `p→worldPosition`,
  `n→worldNormal`, `imp→impulse`, `sep→separation`.

## Wire — queries (Dart → native `{"op":"query",…}` command)

```json
{"op":"query","q":17,"type":"pose","nodes":["<token>","<token>"]}
{"op":"query","q":18,"type":"raycast","origin":[x,y,z],
 "direction":[x,y,z],"maxDistance":100.0,"all":false}
{"op":"query","q":19,"type":"overlap",
 "shape":{"type":"sphere","radius":0.5},
 "position":[x,y,z],"rotation":[x,y,z,w]}
{"op":"query","q":20,"type":"shapecast",
 "shape":{"type":"sphere","radius":0.5},
 "from":[x,y,z],"to":[x,y,z]}
```

- `q`: caller-chosen u32 correlation id (per-controller counter).
- `shape`: `{"type":"sphere","radius":r}` or
  `{"type":"box","extents":[x,y,z]}` (full extents — the same
  convention as collider `extents`). `rotation` optional, defaults
  identity.
- `pose` with `"nodes":["all"]` or omitted `nodes` returns every
  rigid-body node's pose.

## Wire — replies (native → Dart, `D3Event.queryReply = 4`)

```json
{"q":17,"type":"pose",
 "poses":[{"node":{"s":,"i":},"p":[x,y,z],"r":[x,y,z,w]}]}
{"q":18,"type":"raycast",
 "hits":[{"node":{"s":,"i":},"collider":0,"p":[…],"n":[…],"d":1.23}]}
{"q":19,"type":"overlap","hits":[{"node":{…},"collider":0}]}
{"q":20,"type":"shapecast","hits":[same shape as raycast]}
{"q":21,"type":"raycast","hits":[]}
{"q":22,"error":"unknown query type 'foo'"}
```

- `hits` ordered nearest-first where the backend sorts (Jolt
  collectors / SceneKit `searchMode:.closest`); miss = `[]`, not an
  error. `error` only for malformed/unknown queries.
- `n` may be absent — Jolt's raycast doesn't report a normal (see
  Android section); Dart types `worldNormal` nullable.

## iOS realization

- `SceneViewHost` implements `SCNPhysicsContactDelegate`;
  `scene.physicsWorld.contactDelegate = self` on install.
- Every realized collider body gets `contactTestBitMask = ~0` —
  upstream reports all contacts, so the delegate gate is open for every
  pair including sensors (`collisionBitMask == 0` still reports).
- `didBegin` → `began` + points from `SCNPhysicsContact.contactPoint`/
  `contactNormal`/`penetrationDistance` (`sep = -penetration`)/
  `collisionImpulse`. `didUpdate` skipped. `didEnd` → `ended`. Either
  collider a sensor → trigger kinds.
- Node→id: keep `nodeToKey: [ObjectIdentifier: UInt64]` maintained in
  `publish`/`addNode`/`removeNode` beside `nodesById` — contact
  callbacks give `SCNNode`s, not keys. `ca`/`cb` = index of the
  collider component in the node's component list (`0` fallback).
- Raycast: `physicsWorld.rayTestWithSegment(from:to:options:)` with
  `SCNPhysicsTestSearchMode` closest/all per `all`; hits carry node,
  `worldCoordinates`, `worldNormal` — compute `d = |hit−origin|`.
- Overlap: `contactTest(with:options:)` — a probe `SCNPhysicsBody`
  (kinematic, `SCNPhysicsShape` from the wire shape) on an unattached
  node at the given pose; each `SCNPhysicsContact`'s non-probe node is
  a hit. Verify the unattached-probe path empirically; if SceneKit
  requires the probe in-world, add/remove a hidden node in the same
  call.
- Shapecast: `convexSweepTest(with:from:to:options:)` — `SCNPhysicsShape`
  from the wire shape, `SCNMatrix4` endpoints. `SCNPhysicsContact`
  exposes no sweep fraction — `d` approximates as `|contactPoint −
  from.origin|`; document.
- Pose: `node.worldTransform` decomposed (presentation node when set —
  mid-animation reads should reflect the rendered pose). Rigid-body
  nodes read the same — SceneKit syncs body↔node.

## Android realization (jolt-jni 6.0.0)

- `physicsSystem.setContactListener(CustomContactListener)` in
  `JoltWorld.init`.
  - `BodyCreationSettings.setUserData(nodeKey)` (or `body.userData`
    post-create in `addBody`) — the O(1) body→node map. Keep a
    `bodyId → nodeKey` map too: `onContactRemoved` hands back a
    `SubShapeIdPair` (body ids only), not bodies.
  - `onContactAdded(b1va, b2va, manifoldVa, settingsVa)` → wrap per
    jolt-jni's VA idiom (`Body(va)`-style ctor or registry lookup —
    verify against the jar), `ContactManifold(manifoldVa)` →
    `worldSpaceNormal`, `penetrationDepth`, `baseOffset`. jolt-jni does
    not expose the manifold's per-point contact list: emit one point —
    `{p: baseOffset, n: normal, imp: 0, sep: -penetrationDepth}` —
    documented approximation (impulse unexposed).
  - `onContactPersisted` — skip (no upstream event).
  - `onContactRemoved(pairVa)` → `SubShapeIdPair(pairVa)` →
    `body1Id`/`body2Id` → node keys → `ended`/`triggerExited`.
  - `onContactValidate` → accept-all (verify the `EValidateResult`
    int constant).
  - Sensor classification: `body.isSensor` (the `isTrigger` path
    already sets it) on either body → trigger kinds.
- Queries via `physicsSystem.narrowPhaseQuery`:
  - `raycast` — `RRayCast(origin, direction·maxDistance)` +
    `castRay(rrc, RayCastResult)` (closest) or `castRay` +
    `CastRayCollector` for `all`. `RayCastResult` gives `bodyId` +
    `fraction` — `p = origin + dir·(fraction·maxDistance)`. **No
    normal** — after the hit, `collideShape` a tiny sphere (r≈1cm) at
    `p − dir·ε` and use its `penetrationAxis` as `n` (approximation,
    documented). Node = `bodyId→nodeKey`.
  - `overlap` — `collideShape(SphereShape(r)|BoxShape(extents/2),
    scale, RMat44(pose), settings, baseOffset,
    AllHitCollideShapeBodyCollector)` → `bodyId2` per hit. (Broadphase
    `collectTransformedShapes(AaBox)` is the cheap fallback only if
    collideShape proves unwieldy — it's AABB-sloppy.)
  - `shapecast` — `castShape(RShapeCast(shape, from→to), settings,
    baseOffset, ClosestHitCastShapeCollector)` → `ShapeCastResult`:
    `fraction`, `contactPointOn1/2`, `penetrationAxis`, `bodyId2` —
    full fidelity.
  - `pose` — body nodes: `body.getPositionAndRotation` (authoritative
    for dynamics); non-body nodes: the realized transform. Reply in
    scene space (the wire's canonical frame — the native mirror stays
    internal).
- Threading: `update()` and the listener fire on the view's frame
  thread — the same path `settled` events already take; `fireToDart`
  is safe there. Events are per-transition (low volume) — no batching
  layer needed; same-pair duplicates within one step are already
  impossible (Jolt fires began once per pair).

## Dart side

`dispatch.dart`: `contact = 3`, `queryReply = 4`.

`physics.dart` (new types, `Scene`-prefixed per existing convention,
fields mirroring upstream):

```dart
sealed class SceneCollisionEvent { nodeA, nodeB, colliderIndexA, colliderIndexB }
class SceneCollisionBegan  extends … { List<SceneContactPoint> contacts }
class SceneCollisionEnded  extends …
class SceneTriggerEntered  extends …
class SceneTriggerExited   extends …
class SceneContactPoint { worldPosition, worldNormal, impulse, separation }
class SceneRaycastHit { node, colliderIndex, worldPoint, worldNormal?, distance }
class SceneOverlapHit { node, colliderIndex }
```

`scene_controller.dart`:

```dart
Stream<SceneCollisionEvent> get contactEvents          // broadcast
Future<ScenePose?> poseOf(LocalId node)
Future<List<ScenePose>> poses()                        // every body
Future<List<SceneRaycastHit>> raycast({origin, direction, maxDistance, all})
Future<List<SceneOverlapHit>> overlapSphere(center, radius)
Future<List<SceneOverlapHit>> overlapBox(center, extents, {rotation})
Future<List<SceneRaycastHit>> shapeCastSphere({radius, from, to})
```

Implementation: `_querySeq` counter → `_pendingQueries:
Map<int, Completer<Map<String,Object?>>>`; a query sends a `command`
mutation, `queryReply` completes the completer (malformed/error →
completes with `error` content; a detach/`dispose` completes all
pending with an error). Events decode in `_onNativeEvent` case 3/4.

`protocol.dart`: document both new wire shapes and the `query` op.

## Harness probes (feature_scene.dart + main.dart)

- `controller.contactEvents` → on-screen `contacts: N` counter +
  `print` per event kind. The die/slab impact and the isTrigger shelf
  produce began/ended + triggerEntered/Exited live.
- A `+10s` timer (after the W5 +8s diff) fires the query battery once:
  `poseOf(die)`, `raycast` straight down through the die's rest cell,
  `overlapSphere` at the slab center, `shapeCastSphere` from above the
  die to below it. Results render in the status line and log — a fixed
  timer, not settle-driven, because `w5NoRest` keeps settle from
  re-firing post-diff.
- No new nodes needed — the existing scene hits every lane.

## Deferred / approximations (record, don't hide)

- jolt-jni manifold: no per-point contact list or impulse → one point
  at `baseOffset`, `imp:0`.
- Jolt raycast: no surface normal → `n` via post-hit point-collide
  penetration axis (approximation).
- SceneKit `convexSweepTest`: no fraction → `d` from first contact
  point distance.
- Collider indices (`ca`/`cb`): `0` when a backend can't disambiguate
  a compound shape's members.
- `shapeCast` sphere-only, matching upstream's bound.

## Verify lanes (both platforms)

1. Regression — roll/settle/awake events unchanged.
2. Contact began/ended on die↔slab — payload carries both node ids.
3. Contact points sane — on the collider surface, normal ≈ up on the
   slab hit.
4. Trigger enter/exit on the isTrigger shelf.
5. `poseOf(die)` matches the rendered position.
6. `raycast` hits the die first when cast straight down onto it;
   `all:true` lists the slab behind it.
7. `overlapSphere` at slab center returns the resting bodies.
8. `shapeCastSphere` from above the die downward reports the die/slab.
9. Roll storm — rapid Roll taps: no lost events, no crash.
10. Perf — contact-listener frame cost <2%; event→Dart latency within
    ~5ms of the settle-event baseline.
