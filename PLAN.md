# Plan: general 3D scene plugin for DartNative (+ dice as first consumer)

Long-term plan. Goal: a general-purpose 3D scene API for DartNative that
anyone could use, published as a community plugin on dartpub.dev, with the
mythic dice app as the first consumer and proving ground.

## Locked decisions (from user)

- Renderer: **native plugin** — SceneKit on iOS, Filament on Android.
- Physics: **native** (SCNPhysicsBody iOS / Jolt Android). `package:scene`'s
  `PhysicsSimulation` contract is the optional Dart-side seam; validated
  pluggable (flutter_scene_rapier is the exemplar).
- Scene layer: **`package:scene` 0.3.0, adopted as a dependency** (MIT,
  pure Dart, deps: archive + vector_math). Phase 2 validated it fits.
- Transport: **`.fscene` JSON snapshot + per-payload mutations + small
  binary command protocol + batched `setTransforms` per frame** over
  `PluginMutation` bytes. NOT streamed SceneDiffs (flags-only, payload
  byte-compare cost — diffScene is a hot-reload tool, use it to *derive*
  commands on structural edits only).
- Plugin name: **`dart3d`** — unclaimed on pub.dev and dartpub.dev.
- Parser: user's existing `mythic_dice_parser` fork — pure Dart, zero port.
- Component vocabulary: dart3d defines its own codecs, mirroring upstream
  names where supported (`mesh`, `camera`, `directionalLight`/`pointLight`/
  `spotLight`, `rigidBody`, `collider`, `physicallyBased` materials) so
  `.fscene` files stay interchangeable with the flutter_scene ecosystem.

## Architecture

```
┌─ app (DartNative widgets) ────────────────────────────────┐
│  mythic_dice_parser (pure Dart, user's fork)              │
│  package:scene — scene document, stable ids, diffing      │
│  <plugin> widget + controller                             │
└──────┬────────────────────────────────────────────────────┘
       │ PluginMutation bytes (scene diffs / commands)
┌──────▼────────────────────────────────────────────────────┐
│  iOS:   DNPluginProvider → SCNView                        │
│         SCNScene ← mapped scene doc; SCNPhysicsBody rolls │
│  Android: DNAndroidPluginProvider → GLSurfaceView+Filament │
│         gltfio scene; Jolt physics                        │
└───────────────────────────────────────────────────────────┘
```

## Phases

0. **Env eval** — DONE: dn installed, playground proven on sim, skills in
   `.devin/skills/`, free license till 2026-09-17.

1. **Parser standalone (free)** — clone `mythic_dice_parser` fork into
   workspace; `dart test` with real Dart SDK. Define roll-spec contract the
   scene layer consumes: `parse(notation) → RollSpec → resolved outcome`.
   Exit: green tests, frozen API surface.

2. **Probe `package:scene` — DONE (validated by swe-2 subagents).**
   Decision: **ADOPT as dependency.** Findings:
   - SceneKit mapping: feasible-with-shims generally, feasible outright
     for dice. Near-1:1 for nodes/transforms/vertex payloads/PBR slots/
     cameras/shadowed lights/skins/HDRI. Mandatory shim: `.fscene` is
     LEFT-handed (+Y up, +Z fwd); SceneKit is right-handed — bake
     conversion into the encode step, not a root mirror. Minor shims:
     `lineStrip` topology, icosphere primitive, named tone-mapper
     approximation, multi-target RenderViewSpecs via SCNTechnique.
   - `ComponentSpec` is an open `{type, properties}` bag; `package:scene`
     ships no component codecs — the vocabulary is the engine's. dart3d
     defines/implements its own in Swift/Kotlin (mirroring upstream names).
   - Physics: `PhysicsSimulation` is a clean handle-based backend contract
     (bodies/colliders/joints/queries/stepping, `supports*` flags,
     collision event stream). `BasicSimulation` is queries-only — NO
     dynamic bodies, cannot serve dice. SceneKit `step(dt)` has no public
     API — only a problem if Dart drives stepping; SCNView-owned physics
     steps with the render loop. Jolt is portable C++ — could serve BOTH
     platforms if cross-platform determinism matters.
   - Transport: `SceneDiff`/`NodeChange` carry flags not values; don't
     stream diffs per frame. Snapshot ~5–7 KB manifest for a dice scene;
     batched `setTransforms` ~490 B/frame for 10 nodes. Pin LocalIds
     (session salts mint fresh per document — keep one allocator).

3. **App shell on trial token (free)** — `dn create <app>`; parser → UI:
   notation field, roll button, result history. Confirms trial token covers
   own-app builds. Pure DartNative widgets, no scene yet.
   Exit: working dice-logic app on sim; trial limits understood.

4. **Scene plugin v0 — iOS spike (THE proof)** — minimal plugin: `SceneView`
   widget → NativeElement → `ViewType.claim` → Swift provider → `SCNView`
   with a spinning cube/die. Exercises the entire contract end-to-end
   (templates: `docs/plugin_development.md`, `plugins/dartnative_share`).
   Exit: a native 3D view inside a DartNative widget tree on the sim.

5. **Scene document → SCNScene mapping** — wire `package:scene` docs to
   the SCNNode tree: snapshot + command protocol + batched transforms.
   LH→RH conversion at the boundary. Asset path (glTF → USDZ via ModelIO
   or build-time conversion).
   Exit: load a d20 model from Dart, drive transforms.

6. **Dice on SceneKit physics — DONE on sim (2026-09-14).** RigidBody/
   collider/physicsWorld components in `.fscene`; impulse + torque
   commands; settle detection via sleep poll → `Dart3dSetDispatcher`
   callback → Dart reads final pose and computes top face. Example
   auto-rerolls on settle. Lessons: dice torque impulses need ~1–2 N·m·s
   (4–8 spun the die off the table via friction coupling); slab depth
   matters for camera framing.
   Exit met: roll → tumble → settle → "rolled N" readout, repeatedly.

7. **Android half — DONE at dice parity on the real phone (2026-09-15,
   Nothing A142 / Mali-G610).** Filament core (procedural meshes, no
   gltfio needed yet — the glTF payload path is still open on BOTH
   platforms) + Jolt JNI physics + same wire protocol + same settle
   events → same Dart readout. Gotchas found the hard way:
   - `System.loadLibrary` must run before any eager field initializer
     that calls JNI — use companion-object `init`, not `Filament.init()`
     (empty body, stripped by R8).
   - `MaterialBuilder` needs `.platform(MOBILE)` or shaders are desktop
     GLSL.
   - Kotlin `Byte` is signed — mask `and 0xFF` in every byte→int decode;
     sign extension silently mangled LocalId sessions.
   - jolt-jni frees native peers when Java wrappers are GC'd — and R8
     strips write-only fields in release builds, so filter tables passed
     to `PhysicsSystem.init` MUST be kept alive (reachabilityFence).
   - jolt-jni's SpRelease AAR ships an empty classes.jar — use the
     platform-independent JVM jar + natives AAR.
   Exit met for the dice path: same app, same API, both platforms.
   Remaining: glTF/payload geometry, textures, shadows — phase-8 work.

8. **Generalize + publish** — clean the API for arbitrary 3D use (docs,
   examples, stable mutation protocol), publish to dartpub.dev as open
   community plugin under user's account.
   Exit: the "3D API anyone could use" exists.

9. **Subscription gate** — subscribe at dartpub.dev/framework when the
   proof justifies it (probably after phase 4–6 on trial). Then license
   key → real builds → ship path (CodePush later).

## Open questions

- Physics ownership: SCNView-owned physics (steps with render loop, less
  Dart traffic) vs Jolt on both platforms (deterministic, one codebase)
  vs Dart-side sim streaming poses. Decide in phase 6 — SceneKit first.
- Physics outcome vs parser outcome reconciliation model
- What does the dice "overlay" app actually contain beyond the scene?
- Monetization/support posture for the published plugin?

## Risks

- `package:scene` is 0.3.0 pre-1.0 — mitigated by versioned format (v5)
  with migrations and MIT license (fork is the exit ramp).
- **DartNative SDK bakes `pkg/archive` into `platform.dill`** — confirmed
  2026-09-14: `package:archive` resolves to an old SDK-vendored copy
  (non-const `GZipEncoder`) at kernel-compile time regardless of
  `pubspec.lock`. `scene.dart`'s `fsceneb.dart` export breaks every dn
  build. Fix in place: dart3d imports `package:scene`'s component `src/`
  libraries via `lib/src/scene_model.dart` and re-exports them; nothing
  reaches `fsceneb.dart`. Do NOT import `package:scene/scene.dart`
  anywhere until upstream stops shadowing archive. Upstream bug worth
  filing (also breaks `package:image` consumers).
- **Free tier covers `com.dartnative.*` demo bundle ids only.** Own-app
  builds compile/install/launch but `runApp` pauses at the license gate
  (verified: dart3d example reaches `License check failed`). Visual proof
  requires `dnk_…` key (subscription) — the phase-9 gate arrives early.
- No cross-platform determinism between SceneKit and Jolt physics —
  matters only if shared-seed/replay needed; Jolt-on-both is the fix.
- Filament+Jolt Android is the schedule risk — API shape must be settled
  on iOS first so Android is implementation, not design.
- Trial token duration unknown — check limits in phase 3.
