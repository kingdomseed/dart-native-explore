# W18 — Particles: `particleEmitter` + `meshParticleEmitter`

Upstream sources: `flutter_scene-0.22.2` — `lib/src/fscene/realize/
particle_emitter_codec.dart` (wire), `lib/src/particles/*` (the CPU
sim), `lib/src/geometry/billboard_geometry.dart` +
`shaders/flutter_scene_billboard.vert` (the sprite expansion),
`lib/src/components/particle_emitter_component.dart` and
`mesh_particle_emitter_component.dart` (repack + facing/orientation).

Three twin implementations decode the same tagged property maps:

- **Dart** — `lib/src/particles.dart` (the component/spec builders)
  and `lib/src/particle_sim.dart` (the reference CPU sim — a
  line-for-line port used by tests and as the contract both natives
  mirror).
- **iOS** — `SCNParticleSystem` mapping in `FsceneRealizer.swift`'s
  `decodeParticleEmitter`; SceneKit runs the sim on the render clock.
- **Android** — `ParticleRuntime.kt`: the Kotlin port of the CPU sim,
  plus the Filament render binding (CPU-expanded billboard vertices
  for sprites; a baked per-particle renderable pool for meshes).

## Wire contract

Both component types carry the shared `ParticleSystem` block plus
per-renderer fields. All values are tagged (`{'d':…}`, `{'i':…}`,
`{'b':…}`, `{'s':…}`, `{'v3':[…]}`, `{'c':[r,g,b,a]}`,
`{'map':{…}}`, `{'list':[…]}`, `{'rref':'tex:…'}`/`'res:…'`).

System properties (both types):

```json
{"type":"particleEmitter","properties":{
  "maxParticles":{"i":512},
  "emitRate":{"d":32.0},
  "bursts":{"list":[{"map":{"time":{"d":0},"count":{"i":20},
                   "interval":{"d":1.4},"cycles":{"i":3}}}]},
  "shape":{"map":{"kind":{"s":"cone"},"radius":{"d":0.25},
                  "angle":{"d":0.3}}},
  "modules":{"list":[{"map":{"kind":{"s":"sizeOverLife"},…}},…]},
  "lifetime":…, "startSpeed":…, "startSize":…, "startRotation":…,
  "startAngularVelocity":…,          // FloatDistribution maps
  "startColor":…,                    // ColorDistribution map
  "gravity":{"v3":[0,0,0]},
  "looping":{"b":true},
  "duration":{"d":5.0},
  "fixedStep":{"d":0.0167},
  "maxFrameTime":{"d":0.25},
  "seed":{"i":0},
  "prewarm":{"d":0.0},
  "paused":{"b":false},
  "enabled":{"b":true}               // the universal component gate
}}
```

`particleEmitter` adds the sprite-render fields:

```json
"blendMode":{"s":"alpha"},           // alpha | additive
"facing":{"s":"spherical"},          // spherical | axisLocked
                                   // | velocityStretched
"velocityStretch":{"d":0.0},         // world units added per unit speed
"flipbookColumns":{"i":1}, "flipbookRows":{"i":1},
"flipbookBlend":{"b":false},
"randomFlipX":{"b":false},
"aspectRatio":{"d":1.0},             // width as a multiple of size
"texture":{"rref":"tex:…"}           // absent → flat-color sprites
```

`meshParticleEmitter` adds:

```json
"geometries":{"list":[{"rref":"res:…"},…]},  // per-particle bucket pick
"material":{"rref":"res:…"},
"facing":{"s":"tumble"}              // tumble | velocityAligned
```

Distributions and modules use upstream's `{'kind':…}` tagged maps —
`constant`/`uniform`/`curve`/`uniformCurve` floats,
`constant`/`uniform`/`gradient` colors, `point`/`sphere`/`box`/`cone`
shapes, `acceleration`/`linearDrag`/`sizeOverLife`/`colorOverLife`/
`flipbook`/`turbulence`/`rotation` modules, `{time,count,interval?,
cycles?}` bursts. `lib/src/particles.dart` has a typed builder per
shape; the doc defaults live there (`kParticle*`).

## Simulation contract

`particle_sim.dart` and `ParticleRuntime.kt` run the same step:

1. Clamp the frame delta to `maxFrameTime`.
2. Accumulate into `fixedStep` quanta; run whole steps.
3. Per step: spawn (rate + due bursts), apply modules in list order,
   add gravity, integrate `pos += vel·dt`, age and cull.
4. Advance system time; non-looping systems stop emitting at
   `duration` (live particles finish their lives).

`seed` seeds each engine's own PRNG (`math.Random` / `java.util.Random`)
— the streams differ across engines but each is self-consistent, which
is the contract `seed` sells. `randomFor(index, salt)` — the stable
per-particle random used by `uniformCurve` blends and mesh bucket
picks — is the same `sin`-hash on both ports.

**`enabled` is the first real tick gate.** Upstream's
`Component.update` does `if (!enabled) return; if (!paused) step;
repack` — `enabled:false` suppresses both the sim and the repack. The
native equivalent is no runtime at all: `enabled:false` skips
`SCNParticleSystem` attachment on iOS and runtime creation on Android
at decode, so a later `components` updateNode flipping it on creates
the system fresh. `paused` instead holds the sim while the last
repacked state keeps drawing — iOS maps it to `speedFactor = 0`,
Android skips `system.step` but still repacks.

## iOS — `SCNParticleSystem`

Direct knobs: `birthRate`, `particleLifeSpan`±`Variation`,
`particleVelocity`/`Size`/`Angle`/`AngularVelocity`±`Variation`
(uniform distributions map exactly; curves fold to their t=0 value
for the base and to mid±|b−a|/2 for `uniformCurve`), `emitterShape`
(point→direction only, sphere→`SCNSphere` + `birthLocation`/
`surfaceNormal`, box→`SCNBox`, cone→`SCNCylinder` disc +
`spreadingAngle`), `gravity`+`acceleration` modules→`acceleration`,
`linearDrag`→`dampingFactor`, `sizeOverLife`/`colorOverLife`→
`SCNParticlePropertyController` keyframes (`inputMode = .overLife`),
`flipbook`→`imageSequence*` knobs (fps → `frameRate`; absent fps →
once-over-life `.clamp`; `randomStartFrame` →
`initialFrameVariation`), `blendMode`→`.alpha`/`.additive`
(alpha also gets `sortingMode = .projectedDepth`), `facing`→
`orientationMode` (`billboardViewAligned` for spherical AND
velocity-stretched — SceneKit's `stretchFactor` carries the
stretching; `billboardYAligned` for axis-locked), `looping`/
`duration`→`loops`+`emissionDuration`, `prewarm`→`warmupDuration`,
`texture`→`particleImage`, flipbook grid→`imageSequenceColumnCount`/
`RowCount`. `isLocal = true` — upstream simulates in node space.

Logged deltas (decode-and-report, `logOnce` each):

- `fixedStep`/`maxFrameTime`/`seed`/`maxParticles`/`bursts` — the
  render clock drives the sim; no SceneKit counterpart.
- `turbulence` module — skipped.
- `randomFlipX`, `aspectRatio` — no counterpart; sprites stay square
  and unmirrored.
- `sphere.hemisphere` — full sphere.
- Per-particle spread under a `sizeOverLife` controller is lost —
  the controller writes absolute sizes, so it bakes against the mean
  `startSize`.
- `meshParticleEmitter` degrades to an **untextured sprite pass**
  tinted by the material's baseColor — `SCNParticleSystem` is
  sprite-only (the long-standing documented exclusion).

## Android — CPU sim + Filament

`ParticleRuntime.kt` runs the contract sim in Filament's right-handed
space: directional spec inputs (shape directions, gravity,
acceleration, turbulence scroll) are z-mirrored at decode and
shape-generated outputs negate z on write; the tumble axis maps like
a quaternion (−x,−y,z). `tick` runs inside `stepFrame` after physics
and before render — billboards face the settled camera pose.

**Sprites.** One dedicated entity per emitter (a `mesh` component can
co-exist on the same node). Its `VertexBuffer` carries
`capacity×4` verts — `[pos3 | uv0 | color4 | uv1 | frameBlend]` = 48 B —
repacked each frame by the CPU port of `flutter_scene_billboard.vert`:
world center from the node's world matrix, per-particle `to_eye`,
spherical / axis-locked / velocity-stretched bases (the low-speed
stretch path falls back to the camera-facing basis; rotation is
skipped under stretching), in-plane rotation for the other modes,
corner expansion `right·sx + up·sy` in world space
(`vertexDomain: WORLD` passes positions through; the renderable
transform is a no-op), flipbook cell UVs on `uv0`/`uv1` with the
crossfade factor on `CUSTOM0`. The quad layout (corner↔uv pairing,
`0,1,2 / 2,1,3` indices) is upstream's shared unit quad verbatim.

The material compiles in-app through `filamat` — unlit,
`mix(texture(particleMap, getUV0()), texture(particleMap, getUV1()),
variable_blendData.x) * getColor()`; `TRANSPARENT` vs `ADD` are two
compiled variants (Filament bakes blending into the material). `ADD`
is ONE/ONE so the fragment premultiplies by alpha to let particle
alpha attenuate the contribution. `flipUV(false)` keeps v=0 on the
uploaded image's top row (upstream quad UVs are authored v-top).
`texture` absent → the shared white fallback and the flat-color path;
a texture `upsertResource`/`upsertPayload` rebinds the live instance
through the same `(instance, param)` consumer contract mesh materials
use.

**Meshes — the `InstanceBuffer` deviation.** Filament's Java binding
(1.71.6) exposes `RenderableManager.Builder.instances` but no
`InstanceBuffer`, so true instanced mesh particles are unreachable
from Java. `MeshParticleRuntime` bakes instead: a lazily-grown pool of
per-bucket child entities of the emitter node, each holding the
bucket's `GpuMesh` buffers and the shared material instance. Per frame
the repack assigns `bucket = floor(random01·buckets)` (stable per
particle), writes the pool slot's local TRS — particle position,
`orient` rotation, uniform `size` scale — and collapses stale slots
to a 1e-6-scale transform at y=−1e5 (upstream's `_hiddenTransform`
approach; `culling(false)` keeps a stale box from under-culling).
`orient` is upstream verbatim: `tumble` = axis-angle around the
particle's random unit axis; `velocityAligned` rotates +Y onto the
normalized velocity (antiparallel → π flip around X; <1e-5 speed →
tumble-axis fallback), then spins around the velocity by `rotation`.
Pool slots register as `(entity, 0)` material consumers and rebind on
`onGeometryRebound` (pending-geometry payloads heal mid-life). The
cost is the documented delta: N live particles cost N renderable
entities and N transform writes per frame rather than one instanced
draw — fine at harness counts, not a 10k-particle path.

## Lifecycle

- `enabled:false` at decode → nothing is created (first `enabled`
  consumer; the upstream tick gate made real).
- `components` `updateNode` → teardown destroys the old runtime and
  the re-decode builds the new one — spec edits and the `enabled`
  flip both ride this path.
- `visible` `updateNode` → `setSceneVisible` moves the runtime's
  entities in/out of the scene (they're runtime-owned, so the node
  entity's component test doesn't cover them).
- `layers` `updateNode` → `applyLayers` retargets the layer mask on
  the sprite entity / every pooled mesh entity.
- `removeNode`, full-scene `install`, view detach → `destroy()`
  returns the entities, vertex/index buffers, and the sprite's
  `MaterialInstance` (the shared compiled materials die with the
  view); consumer-map entries prune so a later upsert can't write a
  dead instance.

## Support matrix

| Spec field | iOS | Android |
|---|---|---|
| `emitRate`, `lifetime`, `startSpeed`, `startSize`, `startRotation`, `startAngularVelocity`, `startColor` | ✓ (uniform exact; curves fold to t=0/midpoint for the base; full curves live on the over-life controllers) | ✓ full distributions |
| `shape` point/sphere/box/cone | ✓ (`hemisphere` → full sphere, logged) | ✓ |
| `modules`: acceleration / linearDrag / sizeOverLife / colorOverLife / flipbook / rotation | ✓ (size/color via property controllers; `rotation` is native integration) | ✓ (same module list, in order) |
| `modules`: turbulence | skipped — logged | ✓ curl-noise advection |
| `bursts` | skipped — logged | ✓ scheduled + repeating |
| `maxParticles`, `fixedStep`, `maxFrameTime`, `seed`, `prewarm` | render-clock sim — logged | ✓ (capacity cap, fixed-step accumulator, seeded stream, warmup steps) |
| `looping`/`duration` | ✓ `loops`+`emissionDuration` | ✓ |
| `paused` | ✓ `speedFactor=0` | ✓ sim holds, repack continues |
| `enabled` | ✓ nothing attached | ✓ no runtime created |
| `blendMode` alpha/additive | ✓ | ✓ (two compiled variants) |
| `facing` spherical/axisLocked/velocityStretched | ✓ orientationMode + `stretchFactor` | ✓ CPU expansion verbatim |
| `flipbookColumns`/`Rows`/`Blend`, `flipbook` module | ✓ imageSequence (no crossfade blend — cells snap) | ✓ incl. blend crossfade |
| `randomFlipX`, `aspectRatio` | skipped — logged | ✓ |
| `texture` | ✓ `particleImage` | ✓ `particleMap` sampler, live-rebinds |
| `meshParticleEmitter` | sprite-pass degrade — logged | ✓ baked renderable pool (no `InstanceBuffer`) |
| per-particle color on meshes | n/a (degraded) | inert — upstream parity |

## Harness — the W18 phase (+170 s)

`feature_scene.dart` `w18Phase` (fired from `main.dart` at +170 s —
after W15's +112 s lane closes and the auto-reroll is parked) adds:

- `w18.fountain` — spherical flipbook sprite emitter on a generated
  2×2 rgba8 atlas (disc/ring/diamond/spark cells): `sizeOverLife`,
  `colorOverLife`, `flipbook` with `randomStartFrame`, `turbulence`,
  `randomFlipX`, steady `emitRate`.
- `w18.streaks` — additive `velocityStretched` emitter on the
  untextured flat-color path, driven by a repeating `bursts`
  schedule under gravity.
- `w18.mesh` — two-bucket `meshParticleEmitter` (shard cuboid +
  pebble sphere) with `tumble` facing and `startAngularVelocity`
  spread.
- `w18.gated` — `enabled:false` `axisLocked` emitter: nothing
  attaches until the +6 s `components` updateNode flips `enabled`,
  then +9 s/+11 s `visible` toggles on the streaks node exercise
  scene membership, and +14 s `removeNode` on the gated node
  exercises runtime teardown.

## Boundaries

- No true instanced mesh draw on Android — `InstanceBuffer` is absent
  from the Filament Java binding; the baked pool is the documented
  approximation (per-particle entities, per-frame transform writes).
- iOS sim fidelity is SceneKit's — determinism knobs decode and warn
  but don't gate; scheduled bursts don't exist there.
- Sprite shadows off on Android (`castShadows(false)`); mesh pool
  slots cast/receive.
- The billboard quad ignores node-local non-uniform scale on the
  facing basis (positions transform by the node matrix; the basis is
  built in world space — upstream's shader does the same).
