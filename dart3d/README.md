# dart3d

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

See `example/` for a live feature harness that exercises the surface.

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
- Feature-capability warnings: `featuresRequired`/`featuresUsed`
  documents degrade with named-workstream warnings.

## Platform deltas (documented)

Where a native facility has no faithful counterpart, dart3d ships the
closest approximation and logs once:

- iOS screen-target views: the lowest-`order` view owns `pointOfView`;
  split-screen is offscreen-only (render to textures instead).
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

Full detail lives in `docs/verification-matrix.md` and the per-
workstream specs under `docs/`.

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
4. **Mesh particles on iOS** — `SCNParticleSystem` is sprite-only;
   `meshParticleEmitter` has no native honor path. Sprite fallback is
   the documented delta if particles ship.
5. **`renderScale`/`filterQuality` fidelity** — partially folded into
   W14: both decode per stage and per view, Android applies
   `renderScale` via dynamic resolution and iOS approximates via
   `contentScaleFactor`; `filterQuality` remains decode+retain only.
   Full fidelity (temporal upscaling, sampler-quality mapping) is
   open.

## Development

Run the example harness and tests through the DartNative toolchain
(`dn`), which supplies the `dartnative_*` package resolution:

```bash
cd example
dn test          # unit + wire-contract tests
dn run           # live harness on a connected device/simulator
```

Program docs live in `../docs/` — `dart3d-completion-program.md` for
the workstream history, `extended-surface-program.md` for the W11+
follow-on program, and `verification-matrix.md` for per-platform
evidence.
