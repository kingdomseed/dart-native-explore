# DartNative 3D

> Package: `dart3d` · a community plugin for [DartNative](https://dartnative.com).
> Not affiliated with or endorsed by Presence Network / DartNative;
> "DartNative" and the DartNative logo belong to their respective owners.

A general-purpose 3D scene plugin for DartNative applications. Apps
describe scenes as `.fscene` documents — the same engine-agnostic
document model upstream `package:scene` (flutter_scene) uses — and
dart3d renders them with fully native renderers:

- **iOS:** SceneKit on Metal.
- **Android:** Filament for rendering, Jolt Physics through JNI.

There is no Flutter widget tree on the 3D path and no game-engine
runtime; the document model, wire vocabulary, and command ops are the
portable contract, and each platform realizes them natively.

## Usage

```dart
import 'package:dart3d/dart3d.dart';

final controller = SceneController();

// In the widget tree:
SceneView(controller: controller)

// Load a document built with the upstream spec types:
controller.loadDocument(mySceneDocument);
```

`SceneDocument`, `NodeSpec`, `ComponentSpec`, resource specs, and the
`.fscene` JSON codecs are the upstream `package:scene` types — dart3d
re-exports them, so a document authored for any conforming reader loads
here unchanged. `readFsceneb` (in `dart3d.dart`) loads the binary
`.fsceneb` container directly — FSCB header, `JSON`/`BLOB`/`GZBL`
chunks — decoded in-app without `package:archive` (the DartNative SDK
shadows it, so upstream's `fsceneb.dart` can't compile here; the local
reader uses `dart:io` gzip instead). `SceneController` also exposes the
runtime surface: `applyCommands` for the raw op stream, plus typed
helpers (`addNode`, `updateNode`, `setBodyVelocity`,
`selectMaterialVariant`, `renderTexture`, `updateViews`, physics
queries, animation control).

dart3d adds a few document extensions upstream's codec doesn't carry
(a view `viewport`, W26 procedural shapes as geometry resources, and
`featuresRequired` names such as `d3Instances`). Read and write
`.fscene` text with `readFsceneWithExtensions` /
`writeFsceneWithExtensions` (or `SceneController.loadFscene`) to keep
them; plain upstream `readFscene`/`writeFscene` drops or refuses them.

See `example/` for a live feature harness that exercises the surface.

## Verification status

Everything below is implemented and covered by Dart unit/wire-contract
tests, but live device evidence is uneven. W21 and W30 have recorded
device runs; W15's was taken before its last fix round; W16, W18,
W22–W26, and W29 have none recorded yet. Known open defects are
tracked in `../docs/program-audit-2026-09-28.md` §3. One of them
matters for anything shadow-related: Android directional shadows are
currently inert.

## What's implemented

- Document load + structural diffs (`addNode`/`removeNode`/`updateNode`,
  `upsertResource`, `upsertPayload`, `updateStage`, payload-deferred
  resources that realize on arrival).
- `.fsceneb` binary scenes via `readFsceneb` — verified against the
  `flutter_scene` importer's converted dice corpus (d4–d20, gzipped
  `GZBL` chunks, `unskinned_soa_uv1_tangent` vertex payloads).
- Multi-primitive meshes — upstream's `primitives` list emits a
  per-primitive (geometry, material) pair: Android builds a
  `RenderableManager` primitive per entry, iOS parks extras on
  `d3prim:` child nodes; collider shapes and consumer rebinds cover
  the whole primitive set.
- Procedural and payload geometry, textured materials, texture
  transforms, material variants, `enabled:false` components.
- Cameras, lights (incl. `rectAreaLight`), environment/IBL, and the
  `effects` post stack (bloom, AO, fog, DoF, color grading, exposure,
  TAA — per-platform support in `docs/`).
- Rigid bodies, colliders (incl. `concaveMesh`), joints, physics
  events and queries, `ccdEnabled`, axis locks.
- Skins, skeletal animation, morph targets, runtime `anim` ops.
- Render textures + multi-view rendering: `renderTexture` resources
  with `everyFrame`/`interval`/`manual` scheduling, the `render` and
  `updateViews` ops, per-view camera/layerMask/order/AA/renderScale,
  and material consumption via `{"rref":"rt:…"}`.
- Particles: `particleEmitter` (billboard sprites — flipbook atlas,
  alpha/additive, spherical/axisLocked/velocityStretched facing,
  modules incl. curl turbulence, bursts, fixed-step sim) and
  `meshParticleEmitter` (per-particle mesh pool). iOS maps onto
  `SCNParticleSystem`; Android runs a Kotlin port of upstream's CPU
  sim feeding a Filament vertex-expanded billboard batch — see
  `../docs/particles-spec.md`.
- Prefab instances and subtree streaming (W15):
  `loadDocumentComposed` expands eager instances with upstream
  `composeSceneAsync` before the manifest goes out. Lazy instances
  arrive as placeholders that `loadSubtree`/`loadSubtreeAsync`/
  `unloadSubtree` stream in and out. The natives never compose, so an
  eager instance sent through plain `loadDocument` renders empty (and
  `strictFeatures` refuses it).
- Trails and LOD (W16): `trail` ribbons and `lod` level switching with
  hysteresis. `blendRange` decodes but doesn't cross-fade, and LOD
  selects against the primary view only.
- glTF material extensions (W21/W22): KTX2 textures (iOS decodes only
  non-supercompressed KTX2; BasisU logs a warning) and the
  KHR_materials set, with per-platform drops listed in
  `../docs/verification-matrix.md`. Neither platform renders
  iridescence or diffuseTransmission. iOS also drops specular,
  anisotropy, IOR, volume, and dispersion.
- Physics events, queries, and joints (W23): contact/trigger events,
  raycast/overlap/shape-cast queries, joint break events. Android
  reports a single contact point per manifold, and sends contact events
  from inside the physics step, before that step's transforms reach the
  nodes. See
  `../docs/joints-spec.md` for how joints map to native constraints.
- Split-screen views and shadow breadth (W24): per-view `viewport`
  rects (iOS realizes screen splits as sibling `SCNView`s, Android as
  Filament viewports), directional-shadow options, and a
  `shadowCatcher` material (live mode only, with no baked mode).
- Stage effects (W25): a `.cube` LUT via asset path or payload chunk,
  lift/gamma/gain, film grain, auto-exposure, SSR, lens flare, god
  rays, chromatic aberration. Unsupported pieces log a declared
  limit: on iOS SSR, GI, and god rays (and lift/gamma/gain currently
  has no effect there); on Android CA, GI, god rays, and metering.
- Expanded geometry and instancing (W26): `d3:procMesh` shapes
  (cylinder, cone, capsule, disc, tube, ribbon, camera-facing
  polyline/lineSegments/billboard, a real icosphere) and
  `d3:instances`. Instancing is **CPU-baked** into one mesh on both
  platforms (no hardware instancing, because Filament's Java binding
  lacks `InstanceBuffer`). Tessellation, subdivision, instance, and
  dash counts are capped (`lib/src/geometry/limits.dart`,
  `../docs/triage/dart.md`).
- Document layer (W29): `SceneController.serializeScene` (the live
  graph, including runtime ops, as a `SceneDocument`), `.fscene`
  version migration on load, and runtime `.glb`/`.gltf` import
  (`loadGlb`/`loadGltf`). There is no `.fsceneb` writer.
- Android Vulkan (W30): Filament's Vulkan backend with a GL fallback.
  The example selects it with `--dart-define=DART3D_BACKEND=`, but
  there is no plugin-level API yet, and a forced Vulkan request that
  fails falls back to GL without telling you.
- Android low-end devices differ in two ways, decided separately. A
  device is low-end when its GPU is in a short list of fill-rate-bound
  families (Mali-G31/G51/G52/G57, Mali-T and Mali-4xx, Adreno 3xx, 4xx,
  50x, 51x and 61x, PowerVR GE8xxx; `DeviceTier.kt`), or when it has
  under about 3 GB of memory. Only Mali-G52 and Mali-G57 are measured:
  `../docs/artifacts/s0-tablet-frame-rate/` and
  `../docs/artifacts/s0-three-device-baseline/`.
  - Backend: `auto` resolves to OpenGL, whatever `quality` is. Only the
    backend pref (`Dart3dSetBackend`, the example's `DART3D_BACKEND`)
    overrides it.
  - Pipeline: with no `SceneQuality` set, the view renders with
    hard-edged shadows, FXAA in place of MSAA, and dynamic resolution
    (down to half scale). Setting `quality` restores the tier's
    pipeline; it does not change the backend. A `renderScale` authored
    on a view entry, or a stage `renderScale` other than 1.0, stays
    fixed.
- Android frame timings: `adb shell setprop log.tag.dart3d.perf DEBUG`
  makes each view log a `perf` line every 2 s (frame interval, GPU time,
  physics and submit cost, median and p95) under the `dart3d` tag.
- Android material packages. Filament materials are compiled ahead of
  time, because compiling one on a phone takes 3–6 s. The plugin ships
  its fixed set (lit and unlit in three blend modes, trail, shadow
  catcher, particles) for OpenGL and Vulkan, so a scene of plain PBR
  materials starts without compiling anything.
  - A material that uses a `KHR_materials_*` extension needs its own
    package (one per combination of extensions and bound textures). The
    first time an install meets one, it is compiled in the background
    (the base material shows meanwhile) and cached on the device; later
    launches load it from the cache.
  - To skip that first compile, ship the variants your app uses: run
    `tool/bake_materials.sh <adb-serial> --package <your.app.id>
    --app-assets <your app>/android/app/src/main/assets --wait 60` and
    open the screens that show those materials during the wait. The
    example ships the hero's clear-coat variant this way.
  - Packages are named by a hash of their recipe and the Filament
    version, so one built for other shaders or another Filament is never
    loaded. After changing a recipe in `MaterialPackages.kt` or the
    Filament pin, re-run the script; `ShippedMaterialsTest` fails until
    the shipped set matches.
  - `adb logcat -s dart3d | grep 'start +'` shows the cold-start
    timeline in ms since process start; `tool/cold_start.sh
    <adb-serial> [--fresh]` times several launches and prints the
    medians. Measured in `../docs/artifacts/s0h-cold-start/`.
- Feature-capability warnings: unrealized `featuresRequired`/
  `featuresUsed` names log warnings, and `strictFeatures: true`
  refuses them.

## Platform deltas (documented)

Where a native facility has no faithful counterpart, dart3d ships the
closest approximation and logs once:

- iOS screen-target views: one screen view with no `viewport` drives
  the host `SCNView`'s `pointOfView`. Two or more screen views, or any
  `viewport` rect, realize as sibling `SCNView`s over the host, one per
  view (W24). iOS logs and skips directional cascades and contact
  shadows.
- Android `layerMask` uses the low 8 bits (Filament layer limit);
  high bits warn.
- `filterQuality` decodes and is retained but has no faithful native
  knob on either platform.
- `renderScale`: Android applies it via dynamic resolution; iOS via
  `contentScaleFactor` (approximation). Render-texture dimensions are
  authoritative and ignore it.
- Physics contact points/impulses are approximated on Android; joints
  map to the nearest native constraint per platform
  (`docs/joints-spec.md`).
- Particles (`docs/particles-spec.md`): iOS runs SceneKit's own
  render-clock sim, so `seed`/`fixedStep`/`maxFrameTime`/
  `maxParticles`/`bursts`/`turbulence`/`randomFlipX`/`aspectRatio`
  decode but warn once (no `SCNParticleSystem` counterpart); Android
  honors them all. `meshParticleEmitter` degrades to a sprite pass on
  iOS and renders as a baked per-particle renderable pool on Android
  — the Filament Java binding has no `InstanceBuffer`.

Full detail lives in `docs/verification-matrix.md` and the per-
workstream specs under `docs/`.

## Scheduling + threading

Scene/physics mutations only run inside each platform's pre-step
window — iOS drains queued work at `renderer(_:updateAtTime:)`,
Android at `stepFrame`'s top — because the solver and the in-flight
render pass walk native state with no external lock. Two consequences
worth knowing:

- iOS decodes replacement documents **into the bound scene in place**
  (reset to defaults first): SceneKit forbids mutating one scene
  inside a rendering callback of another, so a fresh `SCNScene`
  cannot be built inside the drain.
- Payload-driven re-realizes **coalesce to one per drain** on both
  platforms: a document's N payload chunks cost one decode, not N —
  this is what keeps multi-chunk scenes (dozens of deferred geometry
  buffers) from blocking the frame loop on load.

Both behaviors are load-bearing; `docs/verification-matrix.md` (W21)
has the failure modes they replaced.

## Exploratory directions (deferred exclusions)

Five upstream surface areas were deliberately excluded from the
numbered workstream program. They are **deferred, not eternal** — the
wire never blocks them, and each can be pulled back into a workstream:

1. **Gaussian splats (`splat`)** — no SceneKit or Filament facility;
   needs a dedicated decode→pack→sort→rasterize renderer on both
   platforms plus an asset→bytes delivery path.
2. **Audio engine backend on Android** — Filament has no audio; an
   Oboe/AAudio mixer is host-app work. iOS `SCNAudioSource` support
   can still land independently.
3. **Widget slots** — upstream binds Flutter widgets to world-anchored
   quads; needs a DartNative host bridge before the engine half
   (texture-on-quad + input routing) matters.
4. **Mesh particles on iOS** — landed as the documented delta:
   `SCNParticleSystem` is sprite-only, so `meshParticleEmitter`
   renders as an untextured sprite pass tinted by the material's
   baseColor (W18). True mesh particles on iOS would need a custom
   instanced-geometry path — still excluded.
5. **`renderScale`/`filterQuality` fidelity** — partially folded into
   W14: both decode per stage and per view, Android applies
   `renderScale` via dynamic resolution and iOS approximates via
   `contentScaleFactor`; `filterQuality` remains decode+retain only.
   Full fidelity (temporal upscaling, sampler-quality mapping) is
   open.

## Development

Run the example and tests through the DartNative toolchain (`dn`),
which supplies the `dartnative_*` package resolution:

```bash
dn test          # package tests (test/): codecs, geometry, physics, …
cd example
dn test          # harness-level tests (assets, tool/, example lib)
dn run           # the example app (hero → Dice / Showcase)
dn run --dart-define=DART3D_SCENE=harness   # the verification harness
```

Program docs live in `../docs/` — `dart3d-completion-program.md` for
the workstream history, `extended-surface-program.md` for the W11+
follow-on program, and `verification-matrix.md` for per-platform
evidence.
