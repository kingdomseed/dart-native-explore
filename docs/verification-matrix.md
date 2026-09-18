# dart3d verification matrix (W0)

The example app (`dart3d/example`) is the verification vehicle for the
completion program. `FeatureScene.build` emits one node per feature so a
single scene exercises the whole harness; `docs/dart3d-completion-program.md`
section W0 lists the live lanes. Durable screenshot copies live in
`docs/artifacts/w1/` (W1 feature frames) and `docs/artifacts/w2/` (W2
physics-probe frames).

Surfaces: iOS simulator (iPhone 17 Pro, `9151BBE4-8453-4F3F-8FD6-17535A25A18E`)
and Android phone A142 ("Pacman", serial `00064149A002033`).

## Matrix

| Feature | iOS sim — expected | iOS sim — observed | iOS screenshot | Android A142 — expected | Android A142 — observed | Android screenshot |
|---|---|---|---|---|---|---|
| Dice roll settles, face readout | Die drops, tumbles, rests; status reads `settled — rolled N` | pass — `rolling…`/`settled` status cycles, die mid-air in frame | `docs/artifacts/w1/ios-w1c.png` | Same | pass — `settled — rolled 2 · ball(1.70, 3.00)`; 5+ consecutive settles, zero `unknown id` | `docs/artifacts/w1/w1m.png` + `w1n/w1t` (settled `rolled 2`) |
| Nested hierarchy (`rig` → child mesh + child light) | Amber marker at (−1.5,−0.32,0.6); green box offset up-right of it; warm light pools near rig |  pass — rig children render; world pos composes | `docs/artifacts/w1/ios-w1c.png` | Identical | pass — attach log shows child entities join the scene; world pos composes | `docs/artifacts/w1/w1m.png` |
| `visible:false` torus stays hidden | No magenta torus, including after each Roll (a rotation write goes to it every throw) | pass — no magenta torus in any frame | `docs/artifacts/w1/ios-w1c.png` | Same | pass — torus excluded from scene; Roll writes its rotation and it stays out | `docs/artifacts/w1/w1m.png` |
| Second dynamic body (blue sphere) | Ball drops at (1.7,1.0,3.0), settles at a distinct rest pose; readout shows `ball(x, z)` | pass — blue sphere settles independently | `docs/artifacts/w1/ios-w1c.png` | Same | pass — readout `ball(1.70, 3.00)` after independent settle | `docs/artifacts/w1/w1m.png` |
| Ortho camera toggle | Toggle reloads the document with `projection:"orthographic"`; parallel edges stay parallel | pass — `usesOrthographicProjection` + `orthographicScale`←`orthoScale` (W6) | `docs/artifacts/w6/ios-ortho.png` | Same manifest field sent | pass — `Camera.Projection.ORTHO`, `orthoScale` half-height (W6) | `docs/artifacts/w6/android-post-diff.png` |
| Statistics toggle | SCNView stats overlay appears/disappears with the switch | pass — `60fps`, draw/triangle counts overlay bottom bar | `docs/artifacts/w1/ios-w1c.png` | `showsStatistics` config delivered | pass — `TextView` overlay, fps/ms/entities/bodies (W6) | `docs/artifacts/w6/android-post-diff.png` |
| Camera-control toggle | Drag orbits the scene while on | pass — `allowsCameraControl` on SCNView | `w0-camera.png` | `allowsCameraControl` config delivered | pass — filament-utils `Manipulator`, gesture→node write-back (W6) | `w0-camera.png` |
| Textured material (checker box) | Box at (1.5,−0.1,0.9) shows the 64px checker, not flat white | pending — manifest and PNG payload are emitted; material slots land in W4, so expect flat white today | `w0-texture.png` | Same | pending — blocked on W4 | `w0-texture.png` |
| Payload-geometry tetra | Orange tetrahedron renders at (0.6,−0.5,3.3) | pass — `p3t4` payload decodes verbatim; tetra renders mid-frame | `docs/artifacts/w3/ios-legacy-deferred.png` | Same | pass — tetra renders (dark under Filament lighting, shape correct) | `docs/artifacts/w3/android-legacy-deferred.png` |

## W2 — upstream physics schema (live-verified both platforms)

All physics components now emit the upstream vocabulary from
`docs/physics-schema.md` (`type`, `useGravity`, `ccdEnabled`,
`linearAxisLocks`, `angularAxisLocks`, collider `shape` union,
`material` map, `collisionLayer`/`collisionMask`, `isTrigger`,
`localPose`; `velocity`/`angularVelocity` kept as documented dart3d
extensions). Old wire names are deleted; both native decoders read the
new names only. Probe nodes live in `FeatureScene.build`.

| Probe | iOS sim — observed | Android A142 — observed |
|---|---|---|
| `type: fixed/kinematic/dynamic` | pass — decode log shows `SCNPhysicsBodyType` per node; dice roll + settle under new vocabulary | pass — `body=Static/Dynamic` per node; `settled — rolled 3` reached Dart |
| `useGravity:false` floater | pass — hovers at spawn y=1.2, `rest=true` while dynamic | pass — `Dynamic pos=(-2.2,1.2,2.5)` realized; frame shows box floating |
| `linearAxisLocks` slider | pass — rests on slab, horizontal locked, `p=(-1.20,-0.30,-2.20)` | pass — `Dynamic pos=(-1.2,-0.2,-2.2)`; Jolt `EAllowedDofs` |
| `collisionLayer`/`collisionMask` sinker+catcher | pass — sinker falls through the 0x1 slab, rests on the invisible 0x2 catcher at y=−2.30 | pass — pairwise-AND `GroupFilterTable`; world settles |
| `isTrigger` shelf | pass — `collisionBitMask=0`; ball passes through, rests at y=−0.15 | pass — `setIsSensor(true)`; ball settles at y=−0.15 |
| `localPose` offsetBox | pass — collider offset decoded as compound child transform | pass — offset collider realized |
| All-asleep settle event | pass — `awake=0` after all probes rest; Dart status `settled`, auto-reroll at +3 s | pass — `settled — rolled 3 · ball(1.70, 3.00)` |
| Rig solid: colliders on child + parent nodes (stacked contact) | pass — marker `sphere` and child `boundingBox` bodies at world transforms; `settled — rolled 4` cycles cleanly | pass — `body=Static pos=(-0.9,0.13,-0.6)` for the child (parent −1.5,−0.32 + local 0.6,0.45 composed by `worldMatOf`); `settled — rolled 2` |
| Screenshots | `docs/artifacts/w2/ios-probes.png`, `ios-rig.png` | `docs/artifacts/w2/android-probes.png`, `android-rig.png` |

## W3 — payload geometry (live-verified both platforms)

Payload vertex/index realization per `docs/payload-geometry-spec.md`.
Probe nodes live at the bottom of `FeatureScene.build`: a `p3t4` tetra,
an upstream `unskinned_uv1_tangent` quad row (v5 CCW + `legacyWinding`
CW twin, recoloured per probe — teal/red/blue so a culled backface
can't masquerade as an occluded sibling), a deferred quad whose vertex
chunk arrives ~2 s after the manifest, a malformed 10 B payload, an
oversized-`bounds` collider plate, and a ~10k-vertex grid.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Procedural regression | pass — dice roll/settle cycle intact under payload probes | pass — `settled — rolled 1/2`, ~90 fps |
| Payload mesh renders (tetra `p3t4` + quads) | pass — tetra + quad row draw lit | pass — same (darker under Filament lighting) |
| Indexed triangle winding (v5 CCW → mirror+swap) | pass — teal quad lit face-forward | pass — non-legacy path shared with deferred quad, which renders |
| `legacyWinding` (CW, no swap) | pass — red quad lit face-forward, identical footprint | pass — dark-red quad renders front-face (a wrong winding would be culled, not dark) |
| Deferred payload arrival | pass — blue quad pops in ~+2 s; log `awaiting payload` → `decoded 4 verts` | pass — navy quad present; log shows awaiting → re-realize pass |
| `bounds`-driven collider | pass — static body created; shape auto-derives from `geometry.boundingBox` (authored ±0.4). `physicsShape` reads nil because the shape is implicit — a reporting artifact, not a missing shape | pass — `body=Static` after re-realize; pass 1 logs `collider has no shape yet; body deferred` |
| Malformed payload | pass — `stride 72 does not divide 10 bytes`, node renderless, process alive | pass — same message, renderless, alive |
| Perf (~10k verts) | pass — 10 201 verts decoded in 25–33 ms; 60 fps steady | pass — 10 201 verts in 11 ms; ~90 fps steady |
| UV-mapped texture | deferred to W4 (needs texture upload path) | deferred to W4 |
| Unit tests | `example/test/payload_geometry_test.dart` — 7 tests pass via `dart --packages=.dart_tool/package_config.json test/payload_geometry_test.dart` (plain `dart test` can't re-resolve `dartnative_*`) | same |
| Screenshots | `docs/artifacts/w3/ios-winding-pair.png`, `ios-legacy-deferred.png` | `docs/artifacts/w3/android-legacy-deferred.png`, `android-probes.png` |

## W4 — textures and material slots (live-verified both platforms)

Texture upload + material slots per `docs/texture-material-spec.md`.
Probes: PNG-encoded checker + rgba8 checkers, brick normal+packed-MR
quad, emissive dots quad, KHR-transformed checker cube, deferred
texture quad (+3 s), missing-texture quad (magenta baseColor fallback),
and a +6 s `upsertResource` repointing `checkerTex` to an inverted
checker.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Regression vs W3 trunk | pass — auto-roll settles, 60 fps, ◆41 nodes | pass — `rolling…`→settled, ~89.8 fps steady |
| Base-color texture | pass — checker quads textured (PNG `64x64` + rgba8 `16384 B`, <0.7 ms) | pass — same uploads 0–1 ms, checkers textured |
| Normal map lighting | pass — brick quad shows relief under light; packed MR sampled | pass — identical relief (shader reads packed B=metal/G=rough) |
| Emissive texture | pass — warm dots glow on dark quad | pass — dots glow after `emissive.w=0` fix (was black: exposure attenuation crushed it) |
| KHR UV transform | pass — `baseColorTextureTransform` 0.5-scale → finer checker cells on cube | pass — same scaled cells |
| Deferred texture (+3 s) | pass — `awaiting payload` → upload → re-realize; quad textures in | pass — same, fallback warnings cease post-arrival |
| Missing texture | pass — magenta `baseColor` factor renders | pass — neutral fallback binds, factor renders |
| `upsertResource` swap (+6 s) | pass — texture re-decoded `rgba8`, consumers rebound, no reload | pass — `rebound 2 consumer(s)` in logcat, no reload |
| Upload perf | pass — all uploads ≤0.6 ms (bar: <1 s) | pass — all uploads ≤1 ms |
| Frame-time vs W3 baseline | pass — 60 fps steady (no regression) | pass — ~89.8 fps steady |
| Unit tests | `example/test/texture_material_test.dart` — 6 tests pass | same |
| Evidence | `/tmp/dart3d-lanes/w4-review/` — ios-first-pass.png, ios-post-swap.png, ios-log.txt, w4-review.mp4 (~48 s: roll → defer → swap) | android-post-swap.png, android-live.png, android-log.txt |

## W5 — structural commands (live-verified both platforms)

`addNode`/`updateNode`/`upsertResource`-geometry/`upsertPayload`-vertex
per `docs/structural-commands-spec.md` — the wire transport for
upstream `diffScene`/`reloadScene` semantics. The +8 s probe diffs a
manifest round-trip of the loaded doc (`readFscene(writeFscene(doc))`,
stable ids) and ships ~53 ops through `SceneController.applyDiff` +
one hand-appended stale op.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Regression | pass — roll/settle continues, 60 fps, W4 textures intact | pass — `rolling…`→settled post-diff, ~90 fps |
| `addNode` | pass — w5Quad + 40-box burst appear, ◆41→◆106 (net +41 adds, −3 removes + new) | pass — logcat: ~50-node surgical batch, per-node decode lines |
| `updateNode` (transform/reparent/material-color) | pass — emissiveQuad floats a row up; offsetBox reparents under `ground`; ball turns green | pass — same on device; `updateNode …: body=Dynamic pos=…` in logcat |
| `removeNode` subtree | pass — rig + children gone; follow-up ops on their ids warn + no-op | pass — subtree drain + `removeNode: not live — no-op` warn |
| `upsertResource` geometry | pass — uvShiftBox cube → sphere, rebind no reload | pass — `geometry …: rebuilt, rebound 1 consumer(s)` |
| `upsertPayload` vertices | pass — tetra `p3t4` chunk re-uploaded sheared; mesh visibly deforms | pass — `rebuilt, rebound 1 consumer(s)`; sheared tetra visible |
| Rapid ~50-op batch | pass — coherent post-state matches doc | pass — same |
| Stale op on removed node | pass — `updateNode on missing node …; ignoring`, process alive | pass — `not live — no-op`, process alive |
| Command latency | pass — batch applied within ~50 ms of send (log timestamps), no dropped frames | pass — same |
| Unit tests | `example/test/structural_commands_test.dart` — 12 tests pass (canonical order, op shapes byte-identical to manifest encoding, stale/empty/skip cases) | same |
| Evidence | `docs/artifacts/w5/ios-post-diff.png`, `ios-log.txt` | `docs/artifacts/w5/android-post-diff.png`, `android-log.txt` |

## W6 — Android parity (live-verified both platforms)

Feasibility pass found the W6 box overstated: emissive (W4),
`doubleSided`, axis locks (`EAllowedDofs`), `ccdEnabled`, collision
masks (`GroupFilterTable`), and `concaveMesh` static forcing were
already live. Genuinely missing and landed: ortho projection, AA
sample counts, shadow radius/bias, `allowsResting`, camera control,
stats overlay. Spec: `docs/android-parity-spec.md`.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Regression | pass — "settled — rolled 1" before +8 s diff (the never-sleeping `w5NoRest` joins after, by design) | pass — roll/settle fires pre-diff |
| Emissive + doubleSided | pass — emissive dots glow; backface-first quad visible via `doubleSided` | pass — same (emissive.w=0 semantic from W4) |
| Ortho camera | pass — `usesOrthographicProjection` + `orthographicScale`←`orthoScale`; flat parallel-edge frame | pass — `Camera.Projection.ORTHO`, log: `ortho projection applied: halfH=4.0 aspect=0.4494 near=0.05 far=100.0` |
| AA levels | pass — `antialiasingMode` since W1 | pass — `antialiasingMode=4 → MSAA enabled=true sampleCount=4 aa=FXAA` |
| Shadow radius/bias | pass — `shadowRadius`→SCNLight.shadowRadius, `shadowDepthBias`→shadowBias (pre-existing) | pass — `shadow options: mapSize=1024 bias=0.005 normalBias=0.0025 bulbRadius=3.0`; `shadowRadius`→`shadowBulbRadius` (PCSS penumbra approx — recorded, not equal) |
| Linear/angular factors | pass — velocityFactor/angularVelocityFactor since W2 | pass — `EAllowedDofs` axis locks since W2 |
| `allowsResting:false` | pass — after fix, `w5NoRest` sole `rest=false`/`awake=1` body parked at rest position while all others sleep | pass — `allowsResting=false → allowSleeping=false`; body never sleeps |
| Collision masks | pass — `<<2` category shift since W2 | pass — `GroupFilterTable` since W2 |
| `concaveMesh` static | pass — five-face bowl decodes as fixed concave body | pass — same; ball-in-bowl visual deferred (luck-based, like W3 margin) |
| Camera control | pass — `allowsCameraControl` (SCNView built-in) | pass — filament-utils `Manipulator`; gesture → node write-back verified live |
| Statistics | pass — SCNView HUD `60fps ◆110 ▲24.4K` | pass — `TextView` overlay `90 fps 11.1 ms / 71 entities 13 bodies` |
| Unit tests | `example/test/parity_probes_test.dart` — 6 tests pass | same |
| Evidence | `docs/artifacts/w6/ios-post-diff.png`, `ios-ortho.png` | `docs/artifacts/w6/android-post-diff.png`; delegate logcat |

## W7 — environment / IBL (live-verified both platforms)

Environment resources + `stage.environmentRef` per
`docs/environment-ibl-spec.md`. The Env toggle cycles
none→studio→constant→payload-equirect→empty→studio via document
reload. Dart bridge emits `updateStage` last in `diffCommands`; iOS
realizes via `scene.lightingEnvironment`/`scene.background`; Android
via `IBLPrefilterContext` equirect→cube→`SpecularFilter`, CPU SH3
irradiance, `IndirectLight` + `Skybox`.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Regression | pass — roll/settle intact with studio env active, 60 fps | pass — roll/settle intact, ~86 fps, 71 entities/13 bodies post-diff |
| Studio IBL | pass — soft even lighting, no flat-dark faces | pass — same after lux fix (see Notes); scene reads evenly lit |
| Environment skybox | pass — neutral studio gradient as background | pass — grey studio gradient fills the view (was black: Filament `Skybox`/`IndirectLight` intensity is in **lux**; unitless upstream intensity bound raw ≈ 15 stops under) |
| Constant env (0.25 warm) | pass — uniform warm tint ambient | pass — warm background + flat ambient, no reflections |
| Payload equirect | pass — PNG 64×32 equirect: green band sky, dark ground band, green-shifted materials, sun-spot warmth on tetra | pass — identical band structure + green-shifted IBL; cycle: studio→constant→equirect→empty→none→studio round-trips live |
| Empty env | — | pass — skybox cleared to clearColor, `indirectLight=null`: directional-only lighting, pure-black shadow sides, emissive unaffected |
| `none` (absent ref) | pass — studio IBL, `scene.background=nil` (fallback env declares no skybox) | pass — `environment default` IBL + `sb=false` — identical semantics |
| Deferred env payload | pass — claims registered, re-realize on arrival | pass — `awaiting payload` → deferred; `stageEnvDeferred` keeps old env until bytes land |
| Env rebuild cost | — (iOS rebuilds env contents per re-decode — CPU-only, small) | pass — `lastEnvFingerprint` gates rebuilds: stage+env+payload-bytes hash unchanged → skip; launch went ~8×10ms builds → 1×73ms |
| Exposure/tone mapping | pass — `exposureOffset=log2(exposure)`, `wantsHDR`; toneMapping warn-once (SCN keeps filmic — recorded approximation) | pass — `setExposure(16,1/125,100·exposure)`; `pbrNeutral`→`PBRNeutralToneMapper` |
| Environment rotation | pass — yaw baked into equirect columns | pass — baked via `filamentShifted` (z-mirror + rotation as column shift; Skybox has no rotation knob) |
| Unit tests | `example/test/environment_ibl_test.dart` — 7 tests pass | same |
| Evidence | `/tmp/w7-ios-equirect.png` (equirect lane) | `/tmp/w7-and-final.png` + env-cycle frames `w7-env{2..6}.png` |

## W8 — physics events + queries (live-verified both platforms)

Contact lifecycle events (`D3Event.contact = 3`) and query ops
(`{"op":"query","q":id}` → `D3Event.queryReply = 4`) per
`docs/physics-events-queries-spec.md`. Upstream `scene` vocabulary:
`began`/`ended`/`triggerEntered`/`triggerExited` with
`ContactPoint{p,n,imp,sep}` on began; queries pose/raycast/overlap/
shapecast resolve as `Future`s via `_pendingQueries` correlation.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Regression | pass — roll/settle/awake intact, 60 fps | pass — roll/settle intact, 90 fps / 11.1 ms |
| Contact began/ended | pass — e.g. `began a=75 b=73 pts=1`, `ended a=75 b=73`; per-manifold pairs (SceneKit can emit several per node pair) | pass — same kinds/pair ids; `pts=1` at manifold `baseOffset` (jolt-jni exposes no per-point list — documented) |
| Trigger enter/exit | pass — `triggerEntered/triggerExited a=80 b=74` on the isTrigger shelf | pass — same pair events on `isSensor` bodies |
| Pose query | pass — `pose:(0.38,2.00,1.08)` mid-tumble, matches rendered die | pass — `pose:(0.12,0.74,1.02)`; resting-state runs matched iOS first-hit distance exactly |
| Raycast | pass — `ray:n73@1.47,n95@4.37,n75@4.50,n79@6.50` (die first, sorted) | pass — `ray:n73@1.40–1.47` first, deeper hits sorted; `n` via post-hit point-collide penetration axis (Jolt raycast reports no normal) |
| Overlap | pass — `overlap:4` at slab center | pass — `overlap:5` same probe (deferred-probe `contactTest`, 2 step boundaries — synchronous probe on an unregistered body SIGSEGVs) |
| Shape-cast | pass — `cast:n73@1.35` (convexSweepTest; `d` = contact-point distance) | pass — `cast:n73@1.06` (`castShape` + `ClosestHitCastShapeCollector` — full `ShapeCastResult`) |
| Roll storm | pass — `contacts: 328` counter mid-roll, began/ended pairs balance | pass — `contacts: 53` mid-roll, trigger pairs enter/exit cleanly |
| Unit tests | `example/test/physics_events_queries_test.dart` — 14 tests pass | same |
| Evidence | `/tmp/dart3d-lanes/w8/ios-frame.png`, `ios-log-summary.txt` | `/tmp/dart3d-lanes/w8/android-frame.png`, `android-log-summary.txt`, `dn-run.log` |

## W9 — joints (live-verified both platforms)

Runtime joint ops (`addJoint`/`updateJoint`/`removeJoint` on the
`command` channel, `JointDesc` field-for-field — upstream joints are
runtime-only, no fscene component) plus a `D3Event.joint = 5` `broke`
event for the `breakDistance` extension. Spec:
`docs/joints-spec.md`. Harness rig: 15 nodes / 10 joints at +12 s
(pendulum, ±100° door, motorized elevator, weld, 5-link chain,
generic hinge, breakable pair).

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Regression | pass — roll/settle/contacts intact, 60 fps | pass — same, ~87 fps |
| Fixed weld | pass — `SCNPhysicsFixedJoint` is **macOS-only**; welded via `SCNPhysicsSliderJoint` with all limits pinned at 0 | pass — `FixedConstraint` |
| Spherical pendulum | pass — `SCNPhysicsBallSocketJoint`; bob swings, pivots in place | pass — `PointConstraint`; bob swings |
| Revolute door | pass — hinge free; with limits/motor → `SCNPhysicsSliderJoint` w/ linear pinned (iOS `SCNPhysicsHingeJoint` exposes no limits/motor) | pass — `HingeConstraint` + `setLimits` + velocity motor |
| Prismatic elevator | pass — `SCNPhysicsSliderJoint` linear limits + `motorTargetLinearVelocity` | pass — `SliderConstraint` + `EMotorState.Velocity` |
| Generic | pass — decomposed to nearest primitive by axis config (no 6DOF in SceneKit) | pass — `SixDofConstraint` full surface: per-`EAxis` limits, `MotorSettings`, `SpringSettings` |
| Chain ×5 | pass — links hang `rest=true`, no explosion | pass — same, stable |
| `collide:false` | gap — SceneKit has no pairwise exclusion; warn-once, pair still collides | pass — refcounted `GroupFilterTable.disableCollision` on the pair's sub-groups |
| `breakDistance` | pass — `joint broke #9` 54 ms after rig land (presentation-anchor poll in `didSimulatePhysicsAtTime`) | pass — `joint broke #9` (post-step anchor-separation poll in `update()`); needed the 20 N·s kick — Jolt's residual is stiffer than Bullet's |
| Unit tests | `example/test/physics_joints_test.dart` — 14 tests pass | same |
| Evidence | `/tmp/dart3d-lanes/w9-ios2.png` (`joints: 10 (1 broke)`) | `/tmp/dart3d-lanes/w9-android2.png`, `w9-android-joints.txt` |

## W10 — extended surface audit (documentation workstream)

No new runtime behavior — the deliverable is the complete upstream
codec inventory with per-platform feasibility verdicts plus the
ordered follow-on program. Docs: `docs/extended-surface-audit.md`,
`docs/extended-surface-program.md`.

| Lane | Result |
|---|---|
| Regression | pass both platforms — dice rolling, contacts, `joints:10 (1 broke)`, query battery live; `/tmp/dart3d-lanes/w10-review/w10-regression-{ios,android}.png` |
| Inventory count | pass — 29 fixed component types + placeholder + 5 resources + 7 doc items + 5 spec families + 5 format items = 52 accounts; every upstream codec maps to a row (`w10-inventory.txt`) |
| Verdicts complete | pass — every row names iOS + Android APIs or a documented delta |
| Spot-checks | pass — `SCNLightTypeProbe` (iPhoneOS27 headers), `MorphTargetBuffer`+`SkinningBuffer` (filament 1.71.6 AAR), `CharacterVirtual`+`ExtendedUpdateSettings` (jolt-jni 6.0.0); `w10-spotcheck.txt` |
| Ordering | pass — W11–W20; only hard dep is W20→W13; nothing depends on a later workstream |
| Exclusions | 6 with sign-off boxes — splats, Android audio backend, widget slots, iOS mesh particles, renderScale/filterQuality, .fsceneb |
| W1 reconcile | pass — W1 scoped to W6 gaps; zero contradictions; extensions recorded (joint components exist upstream as components, `rectAreaLight` downgraded to partial on iOS) |
| Operator review | pass — sequence + 6 exclusions approved (deferred, not eternal: README documents them as exploratory directions post-wrap) |

## W11 — skins + skeletal animation + morph targets (live-verified both platforms)

`docs/animation-skins-morphs-spec.md`. Manifest `skins`/`animations` +
node `skin` + geometry `morphTargets` decode; `SCNSkinner`/`SCNMorpher`
(iOS), `SkinningBuffer`/`MorphTargetBuffer` (Android); a per-frame clip
sampler per engine implementing upstream `AnimationPlayer` semantics
(weight-normalized clip mixing, lerp/slerp, clamp+pause or wrap,
bind-pose-once) — engine conveniences can't express the blend. Ops:
`anim` (play/pause/stop + time/timeScale/weight/loop),
`setMorphWeights`, `upsertSkin`/`upsertAnimation`/`removeSkin`/
`removeAnimation`. Dart: `playAnimation`/`pause`/`stop`/`seek`/
`setMorphWeights`, `SceneAnimation` handles, diff emits skin/anim
upserts + node `skin` member.

| Lane | Result |
|---|---|
| Spec | pass — `animation-skins-morphs-spec.md` before delegates |
| Decode | pass — `decoded 8 verts` both geometries, both platforms; IBM + timeline/keyframes chunks claimed |
| iOS skinner+morpher | pass — `SCNSkinner` attaches (u16 bone indices), `SCNMorpher` normalized mode; sampler in `updateAtTime` |
| Android skinning+morph | pass — `SkinningBuffer`/`setBonesAsMatrices` per frame, `MorphTargetBuffer`+`setMorphWeights`; sampler in Choreographer loop |
| Dart API + harness | pass — `animation.dart`, controller methods, +14 s W11 phase (flag skin, morph blob, wave+pulse) |
| Deformation live | pass — flag silhouette differs between wave phases on both platforms (`flag2-w11-{ios,android}-t{0,1}.png`); `live=` pose query on j1 oscillates at wave period (±0.05 world-z: counterphase joints + 2-clip normalization — upstream-exact) |
| Payload-spec wire fix | found+fixed — runtime-minted `upsertPayload` carried no spec; `payloadSpecs` manifest-only + re-realize wiped op specs. Op now carries encoding/layout/format/w/h/length; persistent `opPayloadSpecs` merges at install, both platforms. Also `.boneIndices`≤2 B on iOS (f32→u16) |
| Playback ops | pass — `playAnimation(loop)` + `pulse` join + `seekAnimation(0.75)` + `setMorphWeights` all land clean (`anims: 2 playing`, no native errors) |
| Tests | pass — 20 new (19 W11 + payload-spec), 86 total; `dart analyze` clean; both builds clean incl. Android R8 |
| Regression | pass — dice settle (`rolled 4`/`rolled 6`), `joints: 10 (1 broke)`, contacts/queries/env live; 60 fps iOS / 82 fps Android |
| Operator review | pass — approved in chat |

## W12 — joint components + rectAreaLight + material variants + enabled + capability warnings (live-verified both platforms)

`docs/extended-surface-program.md` W12. All five upstream joint
component types (`fixedJoint`/`sphericalJoint`/`revoluteJoint`/
`prismaticJoint`/`genericJoint`) decode on both platforms and translate
onto the W9 command-joint wire shape — one constraint path serves both
spellings, with deferral until referenced bodies are live. Absent
`otherNode` → world-anchored joint (nullable `nodeB` on the wire;
iOS a shared hidden static body, Android `Body.sFixedToWorld()`).
Generic-joint axis order `linearX..angularZ` with per-axis
`motion`/`lower`/`upper`/`motor`; absent axes default `free` (iOS was
`locked` — fixed to upstream). iOS forwards the full motor field set.
`rectAreaLight`: iOS `SCNLight` `.area` + `areaExtents`; Android a
documented four-point cluster approximation (Filament has no area-light
type on this path). `enabled` decodes and is recorded — upstream gates
component `update`/`fixedUpdate` ticks only; it does not disable light
emission, mesh drawing, camera selection, or physics. `materialsVariants`
decodes and applies to geometry material slots, with the upstream
foreign-write rebase rule; runtime `selectVariant` op reselects, null or
unknown restores the declared default. Dart emits capability warnings
for `featuresRequired`/`featuresUsed` entries the realizer doesn't
implement.

| Lane | Result |
|---|---|
| Joint components decode+realize | pass — all five types translate to `JointDesc`; deferred until bodies live, then realized (iOS `component joint ... realized`, Android same path) |
| World-anchored joints | pass — anchor body holds at spawn (2.90,1.59,0.20) while free body lands at y≈−0.35, both platforms |
| Fixed joint via component | pass — `linkA≈(−3.00,−0.35,0.20)`, `linkB≈(−2.40,−0.35,0.20)`: pair holds ~0.6 u apart, both platforms, settled at +3 s and +11 s probes |
| Generic axes + motors | pass — upstream field set on both; iOS absent-axis default corrected `.locked`→`.free`, motor fields forwarded in full |
| iOS rectAreaLight | pass — `SCNLight` `.area` with `areaExtents` |
| Android rectAreaLight | pass — 4-point corner cluster, intensity ÷4, one-time warning logged; document-authored emissive mesh still draws |
| `enabled` semantics | pass — decoded + recorded on both; light stays lit (tick-gate only, upstream-exact) |
| materialsVariants | pass — `2 variants, 1 bindings, selected=cool` decodes both platforms; initial selection applies at node land and re-applies after the deferred-resource re-realize |
| Runtime `selectVariant` | pass — native trace `selIdx=0→1→null` with `target=variant→variant→default` both platforms; visual: second-view cube renders cyan → magenta → orange (`w12-ios-var-{cool,warm,default}[-crop].png`, `w12-android-var-{cool,warm,default2}[-crop].png`) |
| Capability warnings | pass — `component_capabilities_test.dart` covers `featuresRequired`/`featuresUsed` warning computation (pure Dart) |
| Wire/model | pass — nullable `nodeB` for world-anchored joints; protocol doc lists `selectVariant` + nullable `b` |
| Tests | pass — 94 total (7 new W12 component-capability + joint-event decode updates); `dart analyze` clean both packages; Android `assembleRelease` incl. R8 clean; iOS typecheck + build clean (lipo shim) |
| Verification note | variant visuals required trace logging to close: sim stalls earlier produced stale framebuffers — `variant apply`/`selectVariant` log lines now record every selection + apply with resolved keys |

## W13 — environment effects (live-verified both platforms)

`docs/extended-surface-program.md` W13. `EnvironmentResource.effects`
decodes into a `StageEffects` value type on both platforms — 14
nested block structs at upstream defaults; a present `effects` key
(even `{}`) wholesale-replaces `host.lastEffects`, an absent key
retains it (upstream `overridesEffects` semantics — the key's
presence *is* the override flag; there is no wire field). Apply is
absolute every decode: enabled → value, disabled → the engine's off
value, so re-realization storms leave no stale state.

| Item | Status |
|---|---|
| Wire/model | pass — `effects` decoded inside `decodeStage` both platforms; absent-vs-empty-vs-populated all distinct; `overridesEffects:false` retains prior state (harness step 8) |
| iOS apply | pass — `StageEffects.swift` + `SceneViewHost.applyStageEffects` at all six `applyStageExposure` sites (SCNCamera transience); brightness composes into `exposureOffset` |
| Android apply | pass — `StageEffects.kt` + `Dart3dView.applyStageEffects`; `colorGrading` merges into the single `ColorGrading` build in `applyStageLook` (toneMapper preserved) |
| Combined stack | pass — bloom+AO+fog+DoF frame captured both platforms (`w13/ios-stack2.png`, `w13/android-stack5.png`): fog wash, bloom bleed, foreground DoF blur visible |
| Per-family toggles | pass — 8-step `w13` phase at +34 s: bloom → +AO → +fog → +DoF → vignette+CA+grading swap → grain+autoExposure → reset → `overridesEffects:false`; every step logged and applied on both surfaces |
| Platform no-ops | pass — Android logs `fx.autoExposure`/`fx.filmGrain`/`fx.gi`/`fx.godRays`/`fx.ca` (flare-scoped CA); iOS logs `fx.ssr`/`fx.gi`/`fx.godRays`/`fx.lensFlare`/`fx.fog.params`/`fx.colorGrading.lgg`; LUT assets unresolved both platforms (`fx.colorGrading.lut`) |
| iOS-only extras | film grain (`grainIntensity`), auto-exposure (`wantsExposureAdaptation` + min/max/speeds) — both applied |
| Android-only extras | lens flare via `BloomOptions` sub-stack, SSR via `ScreenSpaceReflectionsOptions`, SSCT via `groundTruth`→`ssctEnabled`, full fog (height/falloff/in-scatter) |
| TAA | iOS applied on device, simulator-gated with `fx.taa.sim` warn (known-unreliable there); Android `TemporalAntiAliasingOptions` (feedback/filterWidth only — 1.71.6 forwards nothing else) |
| Tests | pass — 97 total (3 new: effects-only diff emits `upsertResource`+`updateStage`; `overridesEffects` wire-gating; `readFscene` round-trip); `dart analyze` clean; iOS typecheck clean; Android `assembleRelease` incl. R8 clean |
| Stability | pass — post-sequence both apps alive through continued `malformedPayload` re-realizes; 0 fatals/crashes |
| Scope decision | `stage.renderScale`/`filterQuality`/`antiAliasing` folded to W14 — they're per-view config (views[] overrides), not environment look |
| Operator review | pending |

### W13 ordering note

`redecodeEnvironment` runs its applies *after* `publish` — an earlier
ordering applied `applyStageExposure` against the pre-publish
`lastEffects`, leaving the brightness→`exposureOffset` compose stale
by one decode. `applyUpdateStage`/`applyUpsertPayload`/`install`
already publish first.

## W14 — render textures + views (live-verified both platforms)

`docs/extended-surface-program.md` W14. `RenderTextureResource` → a
Filament `RenderTarget` (RGBA8 colour + DEPTH24 depth) drawn by
per-entry `View`s, or iOS `SCNRenderer` passes into `MTLTexture`s.
`views[]` entries resolve camera node + `rt:`/screen target,
`layerMask`, `order`, and the per-view quality trio.

| Item | Status |
|---|---|
| Wire/model | pass — `render`/`updateViews` ops (dart3d extensions) + `viewport:[l,b,w,h]` additive extension documented; upstream readers ignore it |
| iOS rt path | pass — `SCNRenderer`-per-texture-view inside `willRenderScene` on the view's command queue; MSAA resolve pairs; per-view `categoryBitMask` save/restore; `rendersContinuously` while scheduled rts exist |
| Android rt path | pass — per-entry `View`+`Camera` bound `setRenderTarget`; `isPostProcessingEnabled=false` avoids the intermediate blit; offscreen passes precede screen passes inside one `beginFrame`/`endFrame` |
| Update policy | pass — `everyFrame`/`interval`/`manual` scheduler; `render` op marks `dirty` (manual draws once, interval refreshes early); fresh rt's start `dirty` so a `manual` target holds a frame before its first op |
| Multi-producer | pass — two `order`-sorted views on one rt both draw; list replacement via `updateViews` rebuilds entries cleanly; reduction back to one leaves the rt live |
| Material consume | pass — `{'rref':'rt:…'}` binds `rec.colorTex` with the rt's own filter/wrap sampler; `textureConsumers` rebinds on upsert before old objects die |
| Visual | pass — rtCube's faces show rtCam's live view on both surfaces (iOS: feed changes as the die tumbles; Android: wall/dice content visible on the showcase cube, shifts on Roll) |
| Stage quality | pass — `updateStage` AA/`renderScale` resolves entry→stage→viewConfig→default per view; reset restores |
| Bring-up fixes | Android procedural meshes now emit `[pos3|quat4|uv2|color4]` (UV0+COLOR) — Filament had rejected the textured material instance (`requires UV0`); `p3t4` payloads expand to the 52-byte record instead of raw 28-byte passthrough (crashed after the stride bump) |
| Debug note | an apparent "uniform sampled colour" was a misidentified scene object — a `readPixels(RenderTarget)` probe (removed) proved the attachment held real content and texture identity matched the material's bind |
| Warnings | pass — zero `w14.*` warns on either platform across the sequence |
| Tests | pass — 108 total (+11: op encode/decode, `updateViews` replace, `viewport` ext); `dart analyze` clean; iOS typecheck clean; Android `assembleRelease` clean |
| Known deltas | iOS screen-target views: lowest `order` owns `pointOfView` (split-screen offscreen-only); Android `layerMask` truncates to 8 bits (warn-once); `filterQuality` decode+retain only |
| Operator review | pending |

## W-loose — deferred evidence lanes (live-verified both platforms)

Post-program sweep for evidence lanes that were luck-based or
missing: deterministic `ccdEnabled`, `concaveMesh` containment,
`boundsQuad` authored-margin, and a roll→rest settle-latency metric.
Harness: `wloose` phase at +78 s in `feature_scene.dart` — spawns its
own probes, cancels the demo's auto-reroll/watchdog, removes the
perpetual movers (`w5NoRest`, `j9.liftPlate`, `j9.chain*`) so the
all-asleep `settled` event can fire.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| `ccdEnabled` non-tunnel | pass — 40 m/s sphere rests on the 0.05 plate: `(3.30, 0.37, 2.60)` | pass — same: `(3.30, 0.38, 2.60)` |
| `concaveMesh` containment | pass — drop rests in the bowl: `(-2.27, -0.31, 2.05)` inside the cavity footprint | pass — `(-2.28, -0.31, 2.05)` |
| `boundsQuad` authored margin | pass — sphere rests at `(5.50, 0.10, 0.50)`, ~0.55 above the visible plate | pass — `(5.50, 0.08, 0.50)` |
| Settle latency | 3/3 rolls timed — `3148 ms` via `settled` event, 4706/4698 ms via pose-quiescence (~1.2 s rest + 3.5 s arm); event path seen | 3/3 rolls timed — `1951 ms` via `settled` event, 4668/4694 ms via pose-quiescence; event path seen |
| iOS deferred-collider gap | **fixed** — geometry-derived colliders on payload-deferred geometry attached shapeless forever (`boundsQuad`/`concaveMesh`/`convexHull`/`triMesh` kinds); `pendingColliderShapes` now refills `body.physicsShape` in `decodeMesh` on geometry arrival — mirrors Android's `body deferred` path | n/a — Android already deferred the body |
| iOS `.boundingBox` ignores authored bounds | **fixed** — `SCNPhysicsShape(.boundingBox)` derives from *vertex* bounds, not `geometry.boundingBox`; a ±0.4 authored margin over a flat ±0.2 quad produced a degenerate zero-height plate that shed a centered drop to +x every run (`(0.94,-0.35,1.2)` contested, `(6.55,-4.37,0.64)` isolated). `boundsBoxShape` now builds an explicit `SCNBox` from the declared bounds (centered via compound transform) | n/a — Jolt path reads the bounds spec directly |
| Settle-lane blockers found | demo auto-reroll re-threw the die every settle (churn forever); watchdog teleported die+ball each 10 s; `w5NoRest`/`j9.liftPlate` motor/`j9.chain` jitter kept the world awake. All quieted for the lane. On Jolt a yaw-spinning cube converts spin into lateral drift on first contact — twice ejected the die off the slab edge → falls forever; the probe now throws a pure vertical toss (latency metric, not tumble realism) | same |

## Demo-corpus conformance — upstream `.fsceneb` scenes (live-verified both platforms)

Real `flutter_scene`-pipeline artifacts, not hand-built fixtures: the
tome_keeper dice set (`assets/dice/*.glb` → upstream importer →
`scene.d4–d20.fsceneb`, FSCB v2 with `JSON` manifest + four `GZBL`
chunks each). `dart3d.dart` exports `readFsceneb` — a local container
reader (`dart:io` gzip; the patched SDK shadows `package:archive`, so
upstream's `fsceneb.dart` can't compile in-app) that hands the manifest
to upstream `readFscene` and attaches chunk bytes to `PayloadSpec`s.
Bundled into the example under `dartnative: assets:`; the Model cycler
loads each die live (`--dart-define=DART3D_MODEL=<die>` for headless).

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| `readFsceneb` in-app | pass — `imported scene — d20: 5 nodes, 4 payloads, bounds r=16.67`; gzip decode works under `dn` compile | pass — identical |
| d20 render | pass — both primitives visible (purple shell + inset numerals), settled under studio IBL, 60 fps | pass — same, mid-roll with contacts, ~70 fps |
| d4 render | (cycler covers it) | pass — 1851+2148-vert prims decoded, `body=Dynamic`, rolling |
| Tagged `primitives` decode | **fixed** — `{"list":[{"map":{geometry,material}}…]}` entries were read bare → geometry never resolved. All-or-nothing prim resolution; extras park on `d3prim:` child nodes with per-prim materials, geometryConsumers entries, morphs | **fixed** — same shape bug; `meshPrimitiveKeys` (D3Wire.kt) unwraps entries, `RenderableManager.Builder(N)` binds per-slot geometry+material; `materialConsumers` carries (entity, slot) |
| Multi-prim collider union | pass — `derivedShape` compounds `d3prim:` geometries (hull per part; union AABB for boundingBox) | pass — `aggregateGeoState` concatenates positions / re-bases indices / unions bounds for hull+trimesh |
| Deferred-payload build | pass — manifest re-realize rebuilds the mesh once all prims land | pass — `geometryConsumers` links per prim; build waits for all |
| Unit coverage | `fsceneb_reader_test.dart` — 6 tests (all 7 dice decode, GZBL bytes, header/chunk rejection) | `MeshPrimitivesTest.kt` — 5 JVM tests pinning the tagged-map shape |
| Variant bindings on multi-prim | pass — `applyVariantBinding` resolves prim geometry by index (`d3prim:i` child for i>0), writes slot 0 of that geometry | pass — `setMaterialInstanceAt(ri, b.primitive, …)` was already slot-indexed |
| Known edge | skinned multi-primitive meshes — `d3prim:` children don't carry skinners (upstream multi-material skinned glTFs are rare; single-prim skinning unaffected) | covered — Filament skinning is renderable-wide, all slots deform |

## Dice table + view quality tiers (live-verified both platforms)

The user-facing demo: seven dice as prefab instances (composeScene
host-side → one flat doc), felt-lined tray with rails inside a wooden
table, tap-select → `raycast` → `materialsVariants` swap, user-driven
rolls, face readout from bundled `dice_faces.json`. Authored mm-scale —
the imported dice are Ø23–33 units, so the world runs g=-9800 with a
120Hz `fixedTimestep`; throw energy is real-scale (~±1600 u/s lateral,
~30–60 rad/s tumble).

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Tray + physics | pass — dice spawn-drop, scatter on Roll, settle in tray; all 7 `body=Dynamic` | pass — same; contacts + settle events live |
| Shadows | pass — per-die contact shadows + rail shadows | pass — `View.ShadowType.DPCF` (PCSS ran ~300ms/frame on Mali-G610 — blocker search at mm world-scale; DPCF keeps the soft edge at fixed kernel cost) |
| `quality` viewConfig | pass — `SceneView(quality:)` → `{"quality":"low|medium|high|default"}`; 'low' suppresses authored `castsShadow` + AA off, 'medium' MSAA×2, 'high' MSAA×4 + `shadowMapSize` 2048 | pass — `quality=low → shadows=false aaSrc=0`; tier feeds the AA resolve chain at the viewConfig level (entry→stage still outrank); 'low'→**85 fps vs 24** at default |
| mm-scale settle | **fixed** — `isResting` never fired at g=9800 (fixed units/s sleep threshold vs contact noise): velocity-quiet fallback, gravity-scaled eps (lin `g·0.006`, ang `√g·0.05`, 30-tick window); `fixedTimestep` now wires `physicsWorld.timeStep` | pass — Jolt `isActive`→sleep fires as before |

`SceneQuality` is the durable API surface: `low` = no shadow maps + AA
off, `medium` = shadows 1024 + MSAA×2+FXAA, `high` = shadows 2048 +
MSAA×4+FXAA, `default`/unset = the widget's `antialiasingMode` +
per-light `castsShadow`. Boot lane: `--dart-define=DART3D_QUALITY=`.

## W21 — materials conformance + decode scheduling (live-verified both platforms)

A procedural conformance doc (`--dart-define=DART3D_MODEL=materials`)
drives ten lanes through one scene: opaque vs `alphaMode:blend` spheres
(blend shows the checker through it), a `maskThreshold` lattice quad
with real alpha holes, UV0-vs-UV1 texture transforms, a KTX2 texture
lane, and a payload-driven HDR environment (skybox + SH irradiance +
specular reflections). The env fixture is a 4×2 Radiance `.hdr` on
Android / `.exr` on iOS — deliberately hostile: tiny dimensions and
saturated primaries up to 10.0.

| Lane | iOS sim — observed | Android A142 — observed |
|---|---|---|
| Material lanes | pass — opaque/blend/mask/UV0/UV1 quads all distinct; mask discards below cutoff | pass — same |
| KTX2 texture | pass — `64x64 ktx2 (22184 B)` decodes via the iOS parse path | pass — `ktx2 64x64 ETC2_EAC_SRGBA8 levels=7` — real Basis transcode through the gltfio provider for the Mali GPU |
| HDR env (payload) | pass — `environment 4x2 upscaled to 256x128: below the radiance mip floor`; skybox + IBL live | pass — `environment …: 4×2 equirect → 256² cube + SH3 in 26ms` |
| iOS env crash | **fixed** (`786c8de`) — small equirects SIGABRT'd in `newRadianceTextureForEnvironmentTexture`: SceneKit's radiance chain builds one mip level fewer than the view range it requests (wants 3 on a 4×2's 2, 4 on an 8×4's 3 — reproduces on `MDLTexture` *and* `CGImage`). Fix: `upscaledForRadiance` bilinear floor at 256×128 (the proven-good studio size) + HDR envs bind through a 32bpc float `CGImage` (`rgbaFloatCGImage`) instead of `MDLTexture` — size was the trigger, not the wrapper | n/a |
| Env claim lifecycle | n/a | **fixed** (`5095649`) — `decodeStage`'s fingerprint early-return fired before re-registering `environmentPayloadIds`/`pendingPayloadRefs`, so the first re-realize installed a fresh Context with no env claim and the chunk arrived with nothing to claim it. Claims re-register before the skip; `applyPayload` checks env claims directly like `upsertPayload` does |
| float→half upload | n/a | **fixed** (`74cb132`) — `floatToHalfBits` shifted raw float bits without rebiasing the exponent (127→15 needs `−0x38000000`): `1.0`→`+Inf`, `0.5`→`32768`, `2.0`→`0.0`. Every texel ≥ ~0.5 poisoned the RGBA16F equirect → specular cube → white frame at *any* intensity. The studio env escaped it (sRGB8 never touches the float path) |
| Env authoring | `environmentIntensity: 1.0` | `0.08` — `Platform.isIOS` pick in the doc; saturated primaries stay visible without washing the material lanes |

### Decode scheduling (threading + the scene-switch freeze)

Two fixes landed on the realize path itself — "when does the decode
run" correctness, not visual:

| Item | iOS | Android |
|---|---|---|
| Cross-scene callback mutation | **fixed** (`fcf945a`) — `realize` built a fresh `SCNScene` inside the drain at `updateAtTime`; SceneKit's guard fires for *any* scene mutation inside another scene's callback, bound or not. The manifest path now decodes into the **bound scene in place** (the surgical ops' existing pattern) after `beginSceneReset` returns it to defaults: joint behaviors detach before the node sweep kills their bodies, `worldAnchorNode` drops, and `background`/`lightingEnvironment` contents + gravity/timestep/fog clear — a deferred env leaves both contents slots untouched, so the replaced doc's look must not linger. `install` drops the old-world joint detach (it would kill the decode's own new joints on the same world) and only retires the scene when actually swapped | n/a — Filament scene is host-owned, no equivalent guard |
| Payload-per-chunk re-realize storm | same fix — `realizePending` flag, one decode per drain (dice's 29 payloads were 29 full decodes) | **fixed** (`f93a274`) — `applyPayload`/`upsertPayload` ran a full `realize` per chunk while deferred refs remained: a doc's N chunks in one frame cost N whole-manifest decodes on the main thread. fcar's 39 chunks ≈ 7s of main-thread blocking — the user-reported scene-switch freeze. Now chunks flag `realizePending`; the drain runs one decode after all queued mutations — fcar loads in 2 realizes (32ms+188ms), zero `Skipped N frames` |

Live sweep post-fix: iOS sim — dice (7 settled, total 107) + materials,
zero `modified within a rendering callback` warnings; Android A142 —
dash→fcar→logo→dice switches instant (`realize:` logs 3–333ms each),
dice 7 settled total 42. `dn test` 150/150.

## Notes

- **Runtime-minted payloads need their spec on the op** — the W11
  bring-up bug. `upsertPayload` carried `{id, bytes}` only; the native
  `payloadSpecs` table populates from the manifest's `payloads` block
  alone, so a chunk minted at runtime (W11 harness, any future
  streaming/prefab flow) decoded bytes its consumers could never read —
  `vertices payload has no spec`, geometry unresolved forever. Worse,
  an unclaimed chunk while `deferredResourceIds` is non-empty triggers
  the full-manifest re-realize, which *rebuilt* the spec table
  manifest-only and wiped op-written specs. Fixed both halves: the op
  carries `encoding`/`layout`/`format`/`width`/`height`/`length`, and a
  persistent `opPayloadSpecs` map merges back over the manifest table
  at `install` on both platforms. `payloadStore` (the bytes) already
  survived installs — only the spec table needed the overlay.
- **SceneKit `.boneIndices` caps at 2 bytes/component** — the f32
  joint indices on the wire must repack to `uint16` for
  `SCNGeometrySource`; int32 throws `SCNSkinner: bone indices must be
  uint8 or uint16`. Filament takes the same stream as
  `BONE_INDICES` int4 without complaint.
- **Two playing clips halve each other's strength** — upstream's
  `AnimationPlayer` normalizes by Σ *all registered* clip weights
  (`animation_player.dart:127`), so `wave`+`pulse` at weight 1 each run
  at 0.5 effective. Verified in the live pose readback — expected, not
  a bug.
- **Filament IBL/skybox intensity is photometric (lux)** — the W7
  bring-up bug. `IndirectLight.Builder().intensity()` and
  `Skybox.Builder().intensity()` take lux and default to 30000; binding
  upstream's unitless `environmentIntensity` (≈1) directly put the
  skybox ~15 stops under — black background, ~invisible IBL while SH
  irradiance still contributed a faint lift. Both paths now scale by
  `× 30000` (Filament's own default/reference indoor level), so
  `environmentIntensity=1` reproduces the intended look. SceneKit has
  no photometric step — its env intensity is literal, which is why
  only Android showed the gap.
- **Env re-decode storm → fingerprint skip**: every payload arrival
  re-runs `decodeStage`, and each run rebuilt equirect→cube→SH
  (~10–70ms, ~8× at launch). `Dart3dView.lastEnvFingerprint` =
  hash(stage JSON, env resource JSON, env payload bytes) gates the
  rebuild; `upsertPayload` on the env image still rebuilds because the
  bytes hash changes. iOS has no equivalent skip — its env rebuild is
  CPU-pixel work only (small); noted for symmetry if it ever shows up.
- **iOS gaps found during W6 verification** (the parity matrix assumed
  iOS had both): `allowsResting` was never decoded — added
  `body.allowsResting` in `decodeRigidBody`; `orthoScale` was emitted
  but unread — `decodeCamera` now maps it to
  `SCNCamera.orthographicScale` (fallback `orthographicScale`), matching
  Android's field order.
- **"Duplicate body" scare resolved as a logging artifact**: logcat
  showed `allowsResting=false` under two different node keys at the same
  position. A clean single-process run shows one body; the earlier log
  interleaved two app sessions' batches (the second run's fresh session
  salt re-keys every node). Not a leak.
- `shadowRadius` → Filament `shadowBulbRadius` is a penumbra-radius
  approximation of SceneKit's blur radius; `shadowDepthBias` splits
  into Filament constant + normal bias (bias=0.005, normalBias=0.0025).
- A geometry claiming two payloads re-decodes once per `upsertPayload`
  op — `rebuilt, rebound N consumer(s)` logs once per payload, not once
  per geometry. Idempotent, spec-conformant.
- Filament `RenderableManager.set*At` and `TransformManager` calls take
  `@EntityInstance` (from `getInstance(entity)`), not the entity —
  passing the entity SIGSEGVs. W4's `upsertMaterial` had this latently
  (`setMaterialInstanceAt(entity,…)`, never exercised because the W4
  probe only upserted textures). Every `set*At`/`getInstance` call now
  resolves the instance per use — same stale-handle class as the W1
  TransformManager bug, one rule covers both.
- `addNode` self-attaches via `parent`; the Dart bridge emits added
  nodes in topological order (parents before children) since a child
  whose parent hasn't landed warns + roots rather than deferring.
  `diff.added` order alone is document insertion order — not safe.
- A geometry claims TWO payloads (`vertices` + `indices`), so
  `geometryPayloadKeys` is id→Set — wider than `texturePayloadKeys`'s
  id→id but same direction.
- SceneKit `SCNMaterial`/geometry rebinds mutate live instances, but
  the consumer maps themselves are Swift value types — a surgical
  decode that registers NEW bindings on a seeded copy must publish it
  back (a W4 texture-case publication gap fixed in W5 review).
- Filament's `material.emissive` alpha is an exposure weight:
  `attenuation = mix(1.0, getExposure(), emissive.w)`. Writing `w=1.0`
  multiplies emission by the view's exposure — under this scene's
  exposure that crushed a strength-2.0 emissive to black. dart3d
  writes `w=0` (unattenuated), matching glTF additive emissive and
  SceneKit `emission`. A custom uniform named `emissive` also shares
  the `MaterialInputs.emissive` field namespace — the factor uniform
  is `emissiveColor`.
- Pre-existing encoder/decoder mismatch found during W4 review:
  upstream `cuboid` emits `'extents': [x,y,z]` as a raw array while
  both native `d3Vec3` decoders only accepted tagged `{"v3":…}` —
  every cuboid silently rendered 1×1×1. Both `d3Vec3` now accept a
  bare 3-array (the same fallback `d3Vec2` already had).
- `layout: 'p3t4'` (position f32×3 + tangent-frame quaternion f32×4) is
  pinned in `docs/payload-geometry-spec.md` as a dart3d-local,
  native-space extension: verbatim copy, no mirror, no winding
  migration — an engine-format escape hatch upstream never emits.
- Jolt `createBody` dereferences `BodyCreationSettings.shape`
  unconditionally — a collider whose geometry is still payload-deferred
  (or failed to decode) resolves to no shape and SIGSEGVs the process.
  Android now defers the body (`node …: collider has no shape yet; body
  deferred`); the payload-arrival re-realize rebuilds it with the real
  shape. SceneKit tolerates a nil shape (auto-derives from
  `node.geometry` at attach), so iOS never crashed here — but its
  `physicsShape` property reports nil for auto-derived shapes, which
  reads as `shape=false` in the decode dump.
- SceneKit `SCNGeometryPrimitiveType.line` is a sequence of UNCONNECTED
  pairs, not a strip — `line` indices pass through as-is, `lineStrip`
  expands consecutive vertices into pairs. Both map to `.line`.
- Payload bytes always stream as separate `payload` mutations — inline
  `bytes:` on `PayloadSpec` doesn't arrive with the manifest. Every
  payload-mesh node (including collider-bearing ones like boundsQuad)
  is geometry-unresolved on the manifest pass and heals on the
  payload-arrival re-realize.
- The ortho toggle does a full `loadDocument` — `updateNode` commands are
  still native stubs, so a reload is the only camera write that exists.
  Die and ball ids are re-minted on every reload.
- The checker PNG is embedded as base64 in `feature_scene.dart`;
  `package:image`'s encoder pulls in `package:archive`, which the
  DartNative patched SDK shadows (see `lib/src/scene_model.dart`).
- Filament `TransformManager.Instance` handles are not stable across
  `engine.destroyEntity`: the component store compacts, so a cached
  instance can silently point at another (identity) transform. This made
  every static node's transform reset on re-realize — the surface went
  black on any payload retry. `NodeRec` now stores only the entity and
  resolves `transformManager.getInstance(entity)` per use. The same
  hazard applied to `removeNode` (it would have corrupted every
  surviving transform). iOS is unaffected — `SCNNode` references are
  stable object pointers.
- Filament `MaterialInstance.setParameter` throws
  `IllegalArgumentException` for an unknown uniform name — a hard JNI
  abort, not a no-op. Material decoders must only write uniforms the
  target `.mat` declares.
- SceneKit collision categories reserve bits `0x1` (`Default`) and
  `0x2` (`Static`): unlayered static bodies are auto-categorised `0x2`,
  and every static body's `collisionBitMask` force-excludes bit `0x2`.
  The response test is pairwise-AND, so a body categorised exactly
  `0x2` can never contact any static — the W2 sinker fell through its
  `0x2` catcher until the decoder remapped the wire layer space
  (`layer << 2`, `mask << 2`, absent layer → user bit 0). See
  `docs/physics-schema.md` §"Platform mapping".
- A dynamic body in permanent free-fall never sleeps, so the
  all-asleep settle event can never fire — probes that drop through
  the world need a catcher or the watchdog reports a false wedge.
- **iOS `contactTest` on a world-unregistered body SIGSEGVs** (W8):
  SceneKit crashes in `contactTestWithBody:` when the probe body hasn't
  been registered by a physics step — `updateCollisionPairs()` doesn't
  help. Overlap queries therefore run a deferred probe: attach posed
  node at query time, test in `didSimulatePhysicsAtTime` ≥2 step
  boundaries later, reply, remove. `pendingOverlaps` is NSLock-guarded
  (queries dispatch and drain on the render queue now — see the
  mutation-serialization note below — but the lock stays as a
  cheap invariant).
- **Android release builds strip `CustomContactListener` overrides**
  (W8): R8 sees no Java callers (Jolt JNI resolves them via
  `GetMethodID`) → `SIGABRT` on launch. `consumerProguardFiles` keeps
  `Custom*` names plus `-keepclassmembers` on `CustomContactListener`
  subclasses — without the latter the overrides can be dropped and the
  base no-op binds silently, losing all contact events.
- **jolt-jni manifold surface** (W8): `ContactManifold` exposes
  `baseOffset`/`worldSpaceNormal`/`penetrationDepth` only — no
  per-point contact list, no impulse. Android `began` events emit one
  point at `baseOffset` with `imp:0`, `sep:-depth` (documented
  approximation vs SceneKit's true manifold points + impulse).
- **Jolt `castRay` reports no surface normal** (W8): `RayCastResult` is
  `{bodyId, fraction, subShapeId}` only. Android `n` comes from a
  post-hit `collideShape` of a ~1 cm sphere at the hit point —
  `penetrationAxis` flipped to oppose the query direction.
- **`SCNPhysicsContact.sweepTestFraction` exists** (iOS 11+): the W8
  spec assumed it didn't; `d = fraction·|to−from|` is an easy upgrade
  over the shipped `|contactPoint − from|` approximation.
- **SceneKit joint surface is thinner than the headers suggest** (W9):
  `SCNPhysicsFixedJoint` is macOS-only (absent from the iOS SDK) and
  `SCNPhysicsHingeJoint` exposes no limits or motor knobs on iOS —
  `SCNPhysicsSliderJoint` carries both the linear AND angular
  limit/motor surface, so iOS realizes fixed as a fully-pinned slider
  and limited/motorized revolute as a slider with its linear range
  pinned at 0. Free revolute still uses the real hinge.
- **No pairwise collision exclusion on SceneKit** (W9): `collide:false`
  between jointed bodies warn-once and leaves collisions on; Jolt's
  shared `GroupFilterTable` does refcounted per-subgroup pair disables
  (`jointDisabledPairs`), which also survives body rebuilds.
- **Geometric `breakDistance` needs a violent trigger** (W9): a hard
  ball-socket/hinge constraint holds its anchors together — the
  post-step separation is solver residual only. An 8 N·s kick (~27
  m/s) tripped iOS's Bullet-backed constraint but not Jolt's stiffer
  solver; 20 N·s (~67 m/s) trips both. Probes that exercise breaking
  should kick hard; `breakDistance` semantics remain "anchor
  separation exceeds the threshold in a single post-step read."
- **Upstream joints exist as components too** (W10): beyond the
  runtime `JointDesc` API, upstream serializes `fixedJoint`/
  `sphericalJoint`/`revoluteJoint`/`prismaticJoint`/`genericJoint` as
  one-sided node components referencing `otherNode`
  (`physics_codecs.dart:855-1240`). W9's runtime ops handle the API
  surface; document-declared joints need component decode into the
  same constraint path (W12).
- **The canonical manifest already carries the extended surface**
  (W10): `loadDocument` emits upstream's full encoder output —
  `skins`, `animations`, `views`, `RenderTextureResource`, and all 29
  component types ride the wire today; the gap is native decode, not
  transport. `skin`/`anim`/`rt`/`env` id prefixes were reserved in W5.
- **Filament's `LightManager.Type` has no rectangle** (1.71.6):
  `rectAreaLight` gets an emissive-quad + point-cluster approximation
  on Android; iOS `.area` is real but its `width`/`height`/
  `areaExtents` decode was never wired — both fixed in W12.
- **All scene/physics mutation must run inside the render loop** —
  Dart deliveries used to apply straight onto SceneKit/Jolt state from
  the plugin delivery thread. iOS crashed twice from it: first in
  `btTypedConstraint` quicksort inside `solveConstraints` (a
  delivery-thread `removeBehavior` freed a constraint the solver was
  mid-sort on) and, once mutation moved onto the render queue, in
  `C3DModelValueStoragePrepareNextFrame` at `0x28` (swapping `scene`
  mid-`_update:` freed node storage the in-flight pass still walked —
  the `Assertion 'storage' failed. Null argument` fault precedes it).
  Two-layer fix: (1) every mutation enqueues and drains at the top of
  `renderer(_:updateAtTime:)` on iOS / `stepFrame` on Android — the
  pre-step window on both platforms, FIFO-preserving; (2) a
  two-generation graveyard retains replaced scenes, detached
  nodes/probes, physics bodies, skinners, morphers, geometries and
  joint behaviors for two frame drains so any pass still referencing
  them finishes first. `install` also detaches joint behaviors from
  the replaced world explicitly rather than relying on dealloc-time
  detach. Verified live: iOS sim soaked ~5 min through the W12 harness
  incl. ~18 full-scene re-realizes from the `malformedPayload`
  deferred-resource path — the exact storm that produced both prior
  crashes — zero crashes, 60 fps, variant cycle cool→warm→default and
  joint defer/rebind confirmed in trace; Android soaked 20 min under
  the same storm, 0 logcat fatals, ~70 fps SurfaceView.
