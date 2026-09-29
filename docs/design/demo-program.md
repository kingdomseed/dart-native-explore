# dart3d demo program: matching upstream flutter_scene 0.24's demos

Status: design and planning only. No code in this change. Written 2026-09-29.
Owner track: **P** (product). `docs/program-v2.md` rule O1 applies: engine
units never polish demos, and demos never change engine behavior. A demo
that needs something the engine lacks files it as an engine ask (§7),
tagged with the unit that owns it.

Goal (operator): the dart3d example apps should show off **everything
upstream flutter_scene 0.24 can do**. That means plenty of impressive 3D,
and it explicitly includes upstream's dice roller. The screens we have
tested with so far (dice table, Showcase, harness) are a starting point,
not the finished demos.

Related: `docs/design/hero-scene-brief.md` (P4 hero, in progress),
`docs/program-v2.md` (Tracks E / P / V), `dart3d/README.md` (what works
today), `docs/triage/*.md` (known gaps).

---

> **IDs in this document:** demos are **M0–M17** (M-APP = standalone dice
> app), dice-experience phases are **DR1–DR5**. `D<n>` always means a
> program-v2 decision (D1–D9) and `R<n>` a Track R release unit.

## 1. Upstream reference

| | |
|---|---|
| Repo | `github.com/bdero/flutter_scene`, cloned to the session scratchpad |
| Master HEAD | `266781272e7092a815fe002da0abadf17aa3928c`, 2026-09-28 ("Note the cached shadow crash fix in the changelog.") |
| Latest tags | `flutter_scene-0.23.0`, `scene-0.3.0`. **No 0.24.0 / 0.4.0 tag yet.** |
| 0.24 state | Both CHANGELOGs already open with unreleased `## 0.24.0` / `## 0.4.0` sections. The pubspecs still say 0.23.0 / 0.3.0. The example app pins `^0.23.0`. |
| Other packages | rapier 0.5.1, box3d 0.2.1, soloud 0.1.2, fmod 0.1.2, net 0.2.1, input 0.1.0-dev |

Implication for V0: the program-v2 master preview (`b02c99989`, 09-27) is
now 8 commits behind. The last 15 commits are almost all dice-roller
polish and shadow/morph fixes. Re-pin when the tags ship. Until then,
this document treats master `26678127` as the demo reference.

### 1.1 What 0.24 / scene 0.4 adds (CHANGELOG summary, affects demos)

- **Orthographic cameras**, with every effect working under ortho.
  BREAKING: the `Lighting` projection fields change (V2, V7).
- **Froxel-clustered punctual lights**: no per-object light cap, up to
  255 lights per froxel (V6).
- **Point-light cube shadows**, `Node.shadowCastingMode`
  (on/off/doubleSided/shadowsOnly), per-light caster channel masks (V1, V3).
- **`DecalNode`** projected decals (V4), **`Scene.screenDistortion`**
  shockwaves (**not in any V unit**, see §7), `.fmat` additive blending,
  depth state, unlit `engine_inputs` (V5).
- Display-referred surfaces (for widgets, decision D9 / N/A), surface debug views
  (E9 / V6), `renderStats`, `renderQuality` tiers with an adaptive mode,
  runtime SMAA (V1), mediump shaders (V5).
- Progressive radiance prefilter (V6), `dfg.bin` (Impeller-internal, N/A),
  `-split<N>` mesh grid split on import (scene 0.4 utility; free through
  the importer), and glTF samplers honored.
- Kit: `rotatesToMovement`/`yaw` (V6), `DebugDraw.colliders`, SceneView
  wall clock, and audio listener following the camera (V6).

---

## 2. Upstream demo inventory, mapped to dart3d

Legend:
- **OK**: realizable today with no engine change. It may be device-unverified; see the `verification-matrix.md` row.
- **Partial**: renders, but named pieces are missing. The closing unit is in brackets.
- **Blocked**: cannot be built until a unit or decision lands.
- **N/A**: out of scope under decision D7/decision D9.

W = mostly a "wow" visual; F = mostly a feature/regression test.

The picker in `examples/flutter_app/lib/main.dart` is a flat list of about
45 entries (no groups; "Car" is the default). A shared settings sidebar
applies a tuned post-FX preset to each example.

| # | Upstream example (file, lines) | W/F | What it shows | dart3d mapping |
|---|---|---|---|---|
| 1 | **Dice Shadows** (`example_dice_shadows.dart` 3567 + `lib/dice/` 3182) | W | Upstream's dice roller. §3 covers it in depth. | **Partial / partly blocked.** Physics, shadows, PBR, particles, trails and bloom are OK. Overlay-on-widgets is blocked (§7 X1). Glass refracting widgets is blocked (decision D6). Sound needs E11, or dartnative_audio in the interim. Outline highlight needs E5b. Screen distortion is an ask (X2). |
| 2 | Car (`example_car` 249) | W | Showroom car with doors/hood/trunk, steering wheels, blurred env background | **OK (approx.)**. `fcar.fsceneb` is already in the Showcase, and door poses go through `setNodeTransforms`. Equirect IBL is OK (W7). Env blur on the background is unverified. Lens flare is approximate on iOS and ignored with bloom on Android. Contact shadows are skipped on iOS. Orbit camera needs [E2]; the Showcase boom is the interim. |
| 3 | Animation (127) | F | Skeletal clip blending | **Partial.** Clips play (W8/W30). Weighted cross-blend through `anim` ops needs checking. The declarative `SceneModel` API is N/A (decision D9). |
| 4 | Flutter Logo (91) | F | Baked logo over a grid | **Done, differently.** Replaced by the 3D DartNative logo (P4, `dn_logo.fsceneb`). |
| 5 | Multiplayer (600+245) | W/F | Server-authoritative Rapier arena | **N/A** (decision D7, networking). |
| 6 | Configurator (439) | W | Shoe on a turntable, KHR_materials_variants swatches, spot key, rim points | **OK except spot shadow [E5/U2].** Variants are realized (`selectMaterialVariant`). The asset is Khronos, CC BY 4.0 (§6). |
| 7 | Lights (148) | F | Many ranged point lights | **Partial [V6].** Filament clusters lights natively. SceneKit has a per-node light limit, so iOS needs the V6 measurement and possibly a light-culling fallback. |
| 8 | Area Lights (140) | W | Studio shot with warm key and orbiting rect rims on a glossy floor | **OK.** `rectAreaLight` is realized on both platforms (W22 area-light lane). |
| 9 | Reflection Probes (153) | F | Parallax-corrected probe | **Blocked [E8/W20].** |
| 10 | Planar Mirror (218) | F/W | Mirror floor via `.fmat` `planar_reflection` | **Blocked [E6 + E8].** An iOS `SCNFloor` stand-in is acceptable per E8. |
| 11 | Spot Shadow (313) | F | Orbiting shadow-casting spot | **Blocked [E5/U2].** |
| 12 | Cloth (590 + `cloth/` 2271) | W | CPU XPBD flag/drape/curtain | **Partial, demo-side.** The solver is example-local Dart and portable as-is. It needs a per-frame vertex update path; `upsertPayload` per frame is the only one today and has no perf number. Double-sided shadows need [V1 `shadowCastingMode`]. Ask X4. |
| 13 | Gameplay Kit (1598) | W/F | Character & camera, day/night, water and buoyancy, flocking, pooling, debug draw | **App-level (decision D7)** on top of [E4 character], [E3 sky], and [E6 water vertex `.fmat`]. Flocking, pooling and Poisson are pure Dart and portable now. |
| 14 | **Particles: campfire** (4000) | **W, flagship** | Flipbook flames, curl smoke, embers with trails, flickering light, grass, forest | **Partial.** `particleEmitter` (flipbook, curl, bursts) and trails are OK (W18/W16), as are bloom and fog. Grass and heat `.fmat` need [E6]. Point-light shadows need [V3]. God rays are a platform limit on both. iOS ignores `seed`/`bursts`/`turbulence` (W18 delta). |
| 15 | **Explosions** (576) | W | Every particle renderer, instanced debris, shockwave ring | **Partial.** Sprites, trails and bloom are OK. Mesh debris degrades to sprites on iOS, and Android is CPU-baked until [E1]. The unlit shockwave ring is OK as procedural geometry. |
| 16 | Gaussian Splats (551) | W | Strawberry and classroom captures, crop box | **Blocked [E12/W31].** |
| 17 | Geometry LOD (292) | F | Screen-size LOD field | **OK** (W16; no cross-fade). |
| 18 | SSR (424) | W/F | Reflective floor | **Partial.** Android only; SSR is a declared limit on iOS (W25). |
| 19 | Auto Exposure (403) | F | Walk from a dim room into sunlight | **OK (approx.).** Android metering is a declared limit. |
| 20 | Navigation Route (750) | W/F | Infotainment car on painted road ribbons, follow camera | **OK.** `d3:procMesh` ribbon, polyline and dashes (W26), `fcar`. Follow camera needs [E2]; a manual boom is the interim. |
| 21 | Toon (289), Raw shader (217) | F | `ShaderMaterial` frag / vert+frag | **Blocked [E6/W28].** Raw GLSL has no wire form, so dart3d would only support `.fmat`. |
| 22 | Debug views (319) | F | Surface debug channels | **Blocked [E9 + V6].** |
| 23 | Toon (.fmat) (281) | F | `.fmat` typed params, hot reload | **Blocked [E6]** (hot reload in W28). |
| 24 | Custom vertices (.fmat) (357) | W | Gerstner ocean and curved endless-runner road | **Blocked [E6]** (vertex stage). |
| 25 | Materialize (.fmat) (445) | W | DamagedHelmet: wireframe, then glass shards, then PBR | **Blocked [E6 + V5]** (additive blending, barycentrics). |
| 26 | DICOM Volume (683 + 826) | W/F | MRI raymarch MPR/MIP/DVR | **Blocked [E6]**, plus r32Float texture upload (no unit; low priority). |
| 27 | Custom Skybox (631) | W | `.fmat` gradient and Menger skies re-baked to IBL | **Blocked [E6 + E3]** (sky `.fmat` → IBL bake). |
| 28 | Audio (272) | F | Spatial music, tap plucks, buses | **Blocked [E11]**, spatial panning [V6]. |
| 29 | Widget Texture (546), Widget Input inset (258) | W / F | Live widgets on a CRT mesh | **Blocked (decision D6)**. DartNative has no offscreen widget capture. |
| 30 | External Texture (492) | F | Video/camera as material | **Blocked [E10/W33a].** |
| 31 | Accessibility (586) | F | Pickable labelled car parts, outline, semantics | **Partial.** Picking needs [E2], outline [E5b/U3], semantics [E10/W33b]. The widget panel part is blocked (decision D6). |
| 32 | Render Targets (316) | F | Minimap RT, per-view AA | **OK** (`renderTexture`, W13/W24). |
| 33 | Physics: Dash (1137 + `character/` 831) | W/F | Third-person character, stairs, platforms, plank bridge, seesaw, cloth corridor | **Blocked on [E4]** for the character. Joints are OK (W23). The cloth corridor needs X4. |
| 34 | Physics (box3d) (384) | F | Box stack, pendulum rope, kinematic spinner, tap to drop | **OK.** Backend-neutral: joints, raycast and kinematic bodies are realized (W23). |
| 35 | Car Physics (459 + `raycast_vehicle` 300) | W | Drivable raycast-wheel car through crates | **Partial.** A Dart port needs 4 raycasts per step through async queries, which is too slow for a stable 60 Hz. Needs a native vehicle (Jolt `VehicleConstraint`, `SCNPhysicsVehicle`); ask X3. |
| 36 | Shapes (850) | F | Pick a primitive, drop it with a matching collider, IBL switcher | **OK** (procedural geometry and colliders, W26/W23). |
| 37–41 | fscene, import, animated, prefab, stream | F | Document pipeline | **OK** (W15, W29, `readFsceneb`). There is no `.fsceneb` writer, so the round-trip leg is `.fscene` only. |
| 42 | Split Screen (101) | F | Two cameras with layer masks | **OK** (W24). |
| 43 | Stress Tests (1931) | F (+W presets) | About 86 Khronos sample assets, Sponza preset | **Partial.** Loads via `loadGlb` and conformance lanes (W21/W22). Per-platform extension drops apply: iridescence and diffuseTransmission on both; spec/aniso/IOR/volume/dispersion on iOS. Sponza's DDGI and god rays are limits. |
| — | `examples/scenes/*.fscene` | F | Editor sample docs | **OK.** Already copied into the Showcase assets. |
| — | smoke_render (≈50 SmokeScenes) | F | Cross-backend harness | Feeds **V8** conformance, not demos. It holds the only 0.24 decal, ortho, point-shadow and screen-distortion fixtures. |
| — | stress_bench, flutter_gpu_shim_smoke, editor_example, flutter_scene_editor_app | F | Benchmarks / web shim / editor | **N/A** (decision D7 editor; web not a DartNative target). |
| — | package examples (scene, soloud, fmod, input, net, flutter_scene) | F | 20–75-line snippets | Covered by the rows above. |

**Kit components** (`packages/flutter_scene/lib/src/kit/`) are all decision D7,
app-level. SpringArm, CameraShake, BoundsFraming, DayNight, WaterSurface,
Steering, NodePool, PoissonDisc and DebugDraw are pure Dart over node
transforms, so a demo can port the logic it needs into
`dart3d/example` (or a later `dart3d_kit`) once E2/E3/E4 land.
SoundManager and SurfaceFootstepAudio are unused upstream.

**Score (43 picker rows plus the dice roller):**
- About 14 OK or done.
- About 13 partial.
- About 14 blocked on an E unit.
- About 5 blocked on decision D6/N/A.

Most "wow" demos sit in the partial or blocked-on-E6 group, so E6 (the
`.fmat` shader contract) is the single unit that unlocks the most demos.

---

## 3. Upstream's dice roller ("Dice Shadows"), and what makes it fun

### 3.1 What it actually is

The roller is a **d6-only** game (1–6 dice, default 3) thrown *over an
ordinary Flutter "Game night" screen*: player cards, "Last roll",
"Roll history", a scalloped TOTAL sticker and a Roll pill.

The 3D view clears to transparent. An 80×80 `ShadowCatcherMaterial`
plane makes the dice cast real shadows onto the widgets underneath, and
each card and the button is also a raised physics slab. There are no
glb dice, no notation input, no d20, and no haptics. Everything visual
is procedural; the only files are 73 WAVs. Code: 7.2k lines across
`example_dice_shadows.dart` and `lib/dice/*`
(`dice_vfx`, `pop_theme`, `dice_celebration`, `dice_finishes`,
`dice_breakage`, `dice_contacts`, `dice_clock`). It took 14 commits,
09-14 → 09-25.

### 3.2 Mechanics (the numbers we will match)

- **Physics (Rapier)**
  - Gravity `-30` (≈3 g, with 1 unit = 100 logical px).
  - Fixed step 1/60, up to 8 substeps, interpolated.
  - Die collider is a plain **box** (the visual is a rounded box; `_dieHalf 0.35`).
  - Dice: `friction 0.5, restitution 0.35, angularDamping 0.3, ccd on`, linear damping 0.
  - Bounds: `friction 0.4, restitution 0.45`.
  - UI slabs: `0.55 / 0.3`, 0.12 thick.
- **Walls follow the screen.** The four walls lie in the camera
  frustum's side planes, and a ceiling sits at `min(dist*0.55, 7)`. They
  are rebuilt on every resize. The camera is top-down, `fovY 35°`, at a
  distance chosen so 1 unit = 100 px at any window size. This is exactly
  the operator's 09-17 P3 request ("table follows screen aspect, edges =
  glass walls").
- **Throw.**
  - Drag anywhere to draw an aim arrow, then release. Pulls under 24 px are ignored. Strength is `pull/420 px`.
  - Speed is `3 + pull·3` clamped to 3–28 world units/s. Lift is solved ballistically so the dice land in view.
  - Dice spawn **off-screen behind the arrow** and fly in through entry walls. Those walls are triggers that close once all dice are inside, or after 2.5 s.
  - Per-die jitter: speed ±10%, side ±1.1, lift ±18%.
  - Spin is mostly **end-over-end along the throw** (`speed·0.7–1.4`) plus random tumble 6–22.
  - Poisson spacing inside the throw cluster.
- **Sweep.** A drag that starts on a die shoves the nearby dice
  (finger velocity ×0.8 + a small hop), and the result counts as a new roll.
- **Settle and read.**
  - A die is still when `lin < 0.05`, `ang < 0.1`; the roll ends when `rollTime > 0.6 && still > 0.3`, or at a hard 8 s timeout.
  - Top face = the local axis most aligned with world up, mapped `[2,5,1,6,3,4]` for ±X ±Y ±Z.
  - There is no cocked-die handling.
- **Score.** Sum × the size of the largest matched set.

### 3.3 Look

- **10 finishes + Mix**: resin, glass (transmission 1, ior 1.5,
  attenuation, dispersion 0.12), frosted, opal (iridescence), wood
  (clearcoat), marble (specular 0.9), gold, steel (anisotropy 0.85), neon
  (emissive 5 → bloom), and clock (glass around a live clock widget).
  Glass casts a lighter shadow through a dithered `shadowsOnly` proxy.
- **3 screen looks**: Pop, Blueprint, Washi.
- **Lighting preset**:
  - Sun az 169.8° / el 46.8°, intensity 3, 2 cascades, softness 0.105.
  - Env 0.7, exposure 1.43, slight grade.
  - Bloom threshold 1.39. Lens flare 0.47. Vignette 0.3.
  - **Tilt-shift DOF** (focus at the table, so airborne dice go soft).
- **IBL**: painted at runtime from the current screen look, so metal and
  glass reflect the UI.
- **Backdrop embed**: a `WidgetTexture` of the whole screen sits under
  the dice, so glass refracts the real widgets.
- **Light handle**: a draggable sun or bulb.

### 3.4 Juice (the part that makes it fun)

- **Sound design.** SoLoud, 512-frame buffer (≈12 ms latency).
  - Impacts come from velocity deltas, not contact events.
  - An echo gate, a 25 ms per-die lockout and 20 ms merging stop flams.
  - Each hit is classified as clack (neighbour die), wall, or per-finish landing surface.
  - Volume follows a log curve (−32 dB → 0).
  - Pitch is scaled by force and by material (glass 1.3 … wood 0.88).
- **Timed scoring beats.**
  - 0.3 s pause.
  - Per-die ticks, **accelerating** (`0.26·0.92^i`) and rising in pitch, each with an outline highlight and a 22-star sparkle.
  - On a match: a 0.75 s multiplier reveal with an ember ring, shockwave and a small shake.
  - A 0.36 s cubic-ease-in **slam** of the counter into the TOTAL sticker.
  - On landing, all at once: 110 physically simulated confetti cuboids (paper flutter, they land and rest), glitter, a ring pulse, a shockwave, shake 1.0, a point-light flash, fanfare, and the total rolling up.
  - Afterglow `1.4 + (m−2)·1.6` s.
- **Anticipation.** A **0.18× slow-mo** plus chromatic aberration kicks
  in while the dice are still moving but a match is already visible.
- **Escalation per match size.**
  - ×3: fireworks.
  - ×4: "golden hour" sun sweep.
  - ×5: the matched dice hop, plus a jackpot sound.
  - ×6: every card shatters into Voronoi shards made of its own pixels, then reassembles 3.4 s later.
- **The UI is physical.** Cards press down when hit and while a die
  rests on them (`scale 1−0.04p`). Hard landings (>11) crack them. Dice
  fall into the empty socket.
- **Small constant motion.** Trails only while flying (>5 u/s), skid
  marks that fade over 2.6 s, a rocking sticker, and drifting
  background stripes.

**Why it feels good:** heavy gravity with lively restitution, spin tied
to the throw, dice arriving along *your* arrow, and every event fired
on several channels at once (outline, particles, light flash, shake,
sound). Suspense builds on a clock (accelerating ticks, a held
reveal, a wind-up slam), and rare rolls pay out much bigger.

### 3.5 Feature needs vs dart3d, per platform

| Upstream dependency | Android (Filament + Jolt) | iOS (SceneKit) | Unit / path |
|---|---|---|---|
| Rigid bodies, CCD, box colliders, 60 Hz fixed step | OK (Jolt) | OK (SCNPhysics) | — |
| Toggle a wall between trigger and solid mid-roll | `isTrigger` in the collider vocab; runtime toggle needs a check | same | P-side check; fallback is to spawn inside |
| Impact strength for audio | **Better than upstream:** W23 contact events carry impulse. Android reports one point per manifold, which is enough for audio. | contact events OK | use events, not velocity deltas |
| Settle detection | settle events exist (W23/W25). W25's settle lane is still open (S0g). | same | S0g |
| Face readout | **bug**: inverse quaternion plus mirrored face normals (`triage/integration.md`) | same | **S0g**, fix first |
| Cascaded directional shadows | fixed in #16; verify on the dice lane | OK (iOS skips cascades) | S0c T3 |
| Shadow catcher (live) | OK (W24) | OK | — |
| Point/spot shadows (lamp modes, sticker flash) | spot [E5], point [V3] | same | E5, V3 |
| `shadowsOnly` proxy for glass | [V1] `shadowCastingMode` | [V1] | V1 |
| Transmission, dispersion, ior | transmission approx; dispersion no | transmission approx; IOR/volume/dispersion dropped | limit; glass reads as alpha-blend on iOS |
| Iridescence (opal) | dropped | dropped | limit; fake it with a thin-film LUT texture |
| Clearcoat / anisotropy / specular | OK / OK / OK | OK / dropped / dropped | limit (steel reads plain metal on iOS) |
| Emissive + bloom (neon) | OK | OK | — |
| DOF tilt-shift | OK (W13/W25) | OK | tune per platform |
| Lens flare | ignored when bloom is on | approx | limit |
| Chromatic aberration (slow-mo) | platform limit | OK | limit |
| `screenDistortion` shockwave | **none** | **none** | **V6b** (0.24; see program-v2) |
| Outline highlight | [E5b/U3] | [E5b/U3] | E5b |
| Particles: bursts, stretched sparks, glitter | OK (CPU sim) | bursts/turbulence ignored (W18 delta) | limit; use one-shot emitters on iOS |
| Trails | OK (W16) | OK | — |
| Instanced confetti (110 cuboids with per-instance colour and shadows) | CPU-baked until [E1] | CPU-baked | E1, or a 110-node pool (fine at this count) |
| Runtime IBL from an image | equirect via payload (W7) | same | — |
| **Transparent SceneView over native widgets** | **no**: `SurfaceView` is opaque and would need `setZOrderOnTop` or `TextureView` | host `SCNView` is opaque (`backgroundColor = .black`) | **ask X1** |
| `WidgetTexture` backdrop (glass refracting UI) and `WidgetComponent` clock | **blocked** | **blocked** | decision D6 (W33c) |
| Screen-space shake of the whole UI | DartNative `Transform` on the stack | same | P-side |
| Low-latency pitched one-shots | [E11 `dart3d_audio`, Oboe]. Interim: `dartnative_audio` (media3 AudioPlayer; pitch control unverified) or a Dart mixer into `PcmStreamPlayer` | [E11, AVAudioEngine]; same interim | E11 / interim |
| Haptics (upstream has none) | not verified in `dartnative_system` | same | P-side; a plugin probe |

---

## 4. Demo program

### 4.1 Principles

- **Curated stages, not test lanes.** Every screen gets a set, a light
  rig, a camera move and one clear interaction. Test coverage stays in
  the harness (E-track T3 lanes and V8).
- **Every demo has a named upstream reference.** Before T4 we capture an
  upstream screenshot or video at the same framing, so the "side-by-side
  against flutter_scene" item from the 09-17 feedback is met demo by demo.
- **Native first.** Where the native engine beats upstream for free, we
  use it and say so on screen: Jolt vehicle, SceneKit physics, native
  contact impulses for audio.
- **Platform limits are shown, not hidden.** Each demo has a small
  "ⓘ what's approximated here" sheet generated from the declared limits
  (e.g. "iOS: dispersion dropped").
- **Demos never edit `dart3d/ios/**` or `dart3d/android/**`.** Needs go
  to §7 as asks against E/U/V units.

### 4.2 The demos, in build order

Sizes: S ≤ 2 d, M ≈ 1 wk, L ≈ 2 wk, XL > 2 wk, for one agent lane
including T2/T4 evidence.

| Order | Demo | Upstream refs | Engine deps | Start | Wow rationale | Size |
|---|---|---|---|---|---|---|
| **M0** | **Hero launch** (P4, in progress) | Flutter Logo, README header | none (interim boom); E2 later for drift/scrub | **now** (in progress on `p4-hero-scene`) | First frame of the app: a glossy 3D DN logo emitting its own gradient into bloom, full 360° orbit | M |
| **M1** | **Dice Roller**, replacing the dice table (§5) | Dice Shadows | S0g readout fix, W25 settle; DR3 interim audio; E5b (outline), V1 (proxy), E5/V3 (lamps), X1/X2 optional | **now** (phase DR1) | Upstream's most fun demo, beaten on dice variety (d4–d20, d%) and on real notation | L (DR1–DR3) + M (DR4–DR5) |
| **M2** | **Showroom**: Car + Configurator + Area-light studio as one turntable stage with three subjects | Car, Configurator, Area Lights | OK now; E2 orbit; E5 spot-shadow key | **now** (boom camera) | Hero-grade PBR product shots: car with animated doors, shoe variant swatches, rect-light rims on a glossy floor | M |
| **M3** | **Physics Playground**: tap to drop any primitive, box stack, pendulum rope, plank bridge, kinematic spinner, "fling" gesture | Physics (box3d), Shapes, Physics (joints part) | OK now (W23 joints, raycast, impulses); E2 picking improves it | **now** | Hundreds of native Jolt/SceneKit bodies at 60 fps on a phone; also a physics soak test | M |
| **M4** | **Road Trip**: nav route with the car on a painted ribbon road, dashed lanes, follow camera, day/night later | Navigation Route | OK now (W26 ribbons/polylines); E2 follow; E3 sky upgrade | **now** | Recognisable "real app" 3D (infotainment map); cheap to build | S–M |
| **M5** | **Campfire Night**: flipbook fire, curl smoke, embers with trails, flicker light, fog, starfield | Particles (flagship), Explosions | Partial now (W18/W16/fog/bloom); later E6 (grass/heat `.fmat`), V3 (flicker shadows), E1 (instanced debris) | **now** (v1), upgrade after E6/V3 | Upstream's flagship visual; particles plus light are the most "alive" demo | L (v1 M) |
| **M6** | **Explosions**: a tap-to-detonate button inside M5 or M3 | Explosions | as M5; mesh debris after E1 (iOS stays sprites) | after M5 v1 | Visceral one-tap payoff; reuses M1's shockwave/confetti code | S |
| **M7** | **Material Gallery**: curated Khronos glTF-Sample-Assets (FlightHelmet, ABeautifulGame, sheen/clearcoat/transmission tests, DamagedHelmet), env switcher, **upstream reference image side by side** | Stress Tests, Configurator, README "HelmetPhase2" | OK now (W21/W22 `loadGlb`); limits shown per model | **now** | Proves material fidelity; the side-by-side is the credibility piece for dartpub.dev. Doubles as V8 prep. | M |
| **M8** | **Dash Adventure**: third-person Dash, spring-arm camera, platforms, bridge, seesaw, water with buoyancy, day/night | Gameplay Kit, Physics (Dash) | **E4** (character), E2 (spring arm/follow), E3 (sky), E6 (water vertex `.fmat`) | after E4 | Playable game on a phone: the "tons of incredible 3D" moment | L |
| **M9** | **Shader Lab**: toon Dash, Gerstner ocean, endless runner, Menger sky, Materialize helmet | Toon, Custom vertices, Custom Skybox, Materialize | **E6**, V5 (additive/depth/unlit), E3 (sky → IBL) | after E6 (+V5 for Materialize) | Custom shading is what separates a 3D engine from a model viewer | L |
| **M10** | **Mirror Hall**: planar mirror floor, reflection-probe room, SSR comparison | Planar Mirror, Reflection Probes, SSR | E6 + E8 (iOS `SCNFloor` ok), SSR Android-only | after E8 | Reflections are a classic wow; also shows platform honesty | M |
| **M11** | **Splats**: strawberry macro and a room capture with a PBR sphere | Gaussian Splats | **E12** (after E1) | after E12 | Cutting-edge; README gallery shot | M |
| **M12** | **Car Physics**: drivable car through crates, on-screen joystick | Car Physics | **X3** native vehicle (or E4-era perf proof of Dart raycasts) | after X3 | Driving the showroom car is the second "game" moment | M |
| **M13** | **Cloth**: flag in wind, curtain parted by a sweeping capsule | Cloth | **X4** per-frame vertex stream; V1 doubleSided shadows | after X4 perf proof | Soft bodies on a phone; ports the example-local Dart solver unchanged | M |
| **M14** | **Sound Stage**: spatial music orbiting the listener, tap-to-pluck | Audio | **E11**, V6 spatial | after E11 | Small, but completes the "everything upstream does" list | S |
| **M15** | **Decals & Ortho** (0.24): scorch decals on M3 impacts, an ortho isometric diorama | smoke_render decal / ortho fixtures (no app example upstream) | **V4**, V2, V3 | Track V | Shows 0.24-only features; fold into M3/M4 if small | S–M |
| **M16** | **Pirate Ship on Water**: a stylized ship riding Gerstner-style waves, foam/spray particles, sky + sun, gulls | Water/buoyancy (Gameplay Kit), ocean `.fmat` | **E6** water shader (interim: X4 vertex-animated mesh), E3 sky, W18 particles; buoyancy via Jolt/SceneKit forces or scripted bob | after E6 (interim v1 after X4) | Instantly shareable "wow" scene; shows shaders + physics + particles together | L |
| **M17** | **Frankfurt Street Corner**: a stylized diorama of a Frankfurt Ostend corner with a streetcar looping through, day–night, windows lighting up, instanced people/cars | none upstream (inspired by Japanese-town dioramas on X) | E1 GPU instancing, E3 day–night, W16 curves/trails for rails, OSM footprints (ODbL) + Blender + Kenney CC0 props; **never commit the private address** | now (v1 static diorama + tram loop), E1/E3 upgrades | Personal, local and charming — the kind of scene people repost | L |

**Not planned as demos:** Multiplayer (decision D7), editor/MCP (decision D7), Widget
Texture / Widget Input / clock die (decision D6, blocked on DartNative), External
Texture (E10; add a "video on a TV" set to M2 once it lands), DICOM,
Debug views (a dev tool; E9 ships it in the harness), Split Screen / LOD
/ Render Targets / fscene (these stay harness lanes; M3 can show split
screen as a toggle).

### 4.3 Sequencing

```
now ──────────────────────────────────────────────────────────────►
M0 hero (in progress)
M1 Dice Roller DR1 → DR2 → DR3 ─┬─ DR4 (after E5b/V1/E11 or interim audio) ─ DR5 polish
M2 Showroom ─ (E2 swap-in)   │
M3 Physics Playground        │
M4 Road Trip   M7 Material Gallery
M5 Campfire v1 → M6 Explosions ─── (E6/V3/E1 upgrades)
                          after E4: M8 Dash Adventure
                          after E6: M9 Shader Lab (+V5) → M10 Mirror Hall (+E8)
                          after E12: M11 Splats   after E11: M14 Sound Stage
                          after X3/X4 approval: M12 Car Physics, M13 Cloth
M17 Street Corner v1 (static diorama + tram loop) ── (E1 instancing, E3 day–night upgrades)
                          after E6: M16 Pirate Ship (interim v1 after X4)
                          Track V: M15 Decals & Ortho, then V8 side-by-side sweep over all demos
```

Parallelism: M1 needs one lane throughout. M2–M5 and M7 are independent
screens under `dart3d/example/lib/demos/<name>/`, each on its own
`p<N>-<slug>` branch. They share one `DemoStage` scaffold (clear colour,
IBL, key/rim rig, camera boom that swaps to E2's orbit, "ⓘ limits"
sheet, loading state — this also fixes the black Showcase-while-loading
follow-up #8).


Unit numbering: see Track P in `docs/program-v2.md` (P3 dice experience, P5 all
demos M2–M17, P6 asset replacements, P7 design pass).

### 4.4 Home screen

After M0's hero, a grid of demo cards (a 3D thumbnail rendered once
through `renderTexture` → PNG). "Dice" is the first card. The existing
Harness moves under a "Developer" section so the curated demos and the
test lanes stop mixing (09-17 feedback).

---

## 5. Dice Roller plan: replace the dice table with a roller at least as good as upstream's

### 5.1 Beat, don't clone

Upstream's roller is a d6 party toy over a fake app screen. Ours is the
**Mythic dice product** (program-v2 goal 2). So we match every "feel"
lever in §3.2–3.4 and add what upstream lacks:

- **Full polyhedral set**: d4, d6, d8, d10 (tens and units → d%), d12, d20.
  We already have the "Retro Classic Recessed" `.fsceneb` set plus
  `dice_faces.json`. The overlay's "Basic Glossy / Basic Matte" sets are
  a second option.
- **Real dice notation** via `mythic_dice_parser`: `4d6!`, `2d20kh1`,
  `d%`, Mythic Fate Chart rolls. The expression evaluates over the faces
  physics produced.
- **Native contact-impulse audio** instead of a velocity-delta heuristic.
- **Haptics on hard landings**, if a DartNative haptics path exists (probe).
- **Cocked-die handling**: upstream just takes the largest-up axis. We
  detect `maxDot < 0.9` and nudge the die with a small torque impulse.

### 5.2 P1 contract (parser ↔ scene)

Recommended in program-v2 P1, and now concrete: **physics picks the faces,
the parser evaluates.**

```
parse(expr) ─► DiceExpression ─► RollSpec { dice: [ {sides, count, groupId, explode?, …} ] }
RollSpec ─► dart3d throw (one body per physical die, capped at 12 like mythic_dice_overlay)
settle events ─► faces per die (FaceReadout: fixed matrix read, cocked-die nudge)
faces ─► PreRolledDiceRoller(faces in RollSpec order) ─► DiceExpression.roll(roller) ─► RollResult
```

- `mythic_dice_parser` 8.0.0 already ships both rollers
  (`lib/src/dice_roller.dart`):
  - `PreRolledDiceRoller(Iterable<int>)` works when the expression's
    dice are known up front.
  - `CallbackDiceRoller` handles **exploding / reroll** dice, where the
    parser asks for more dice mid-evaluation. The callback suspends
    evaluation and throws **one extra physical die**, which is the fun
    "it exploded!" moment, and resumes with its face. If
    `CallbackDiceRoller` is synchronous, the fallback is to pre-roll the
    explosion dice with RNG and animate them as a follow-up throw with the
    known outcome forced visually. That is weaker, so prefer an async
    contract in P1.
- Count limit: `DiceCountLimitExceededFormatException` already exists.
  Above the physical cap (12), roll the rest with RNG and show them as a
  "+N" chip. That is the overlay's approach, and parser-only mode is the
  fallback.
- **Where it lives.** RollSpec / FaceReadout types live next to the dice scene
  (no package extraction — operator, §8); parser changes (e.g. async
  `CallbackDiceRoller`) go to `mythic_dice_parser`, a separate repo with its
  own PR flow (program-v2 operating rules). The
  dart3d side is `dice_roller_scene.dart` in the example and later the
  P2 app.

### 5.3 Reuse `mythic_dice_overlay`?

`mythic_gme_apps/packages/mythic_dice_overlay` is a Flutter +
flutter_scene 0.23 + Rapier overlay. It is **not reusable as a
package**: it imports Flutter, flutter_scene and Rapier, none of which
exist on DartNative's Zero engine. The **pure-Dart parts can be lifted
or shared**:

- `dice_physics_profile.dart`: the baseline and resin profiles. Our
  `DiceTableSpec` defaults already come from `baseline`.
- `dice_overlay_spawn_layout.dart`: spawn layout.
- `dice_roll_target.dart` / `dice_visual_roll.dart`: the
  `DiceVisualRollRequest` contract.
- `dice_overlay_settled_result.dart`: faces plus screen centres, the
  hook for "blue-fire vanish" effects.
- Face maps and the glossy/matte glb sources, if their license allows
  (in-house, so yes).

*Superseded (operator, §8): no extraction or package split is planned; the
example's dice experience and the standalone app (M-APP) are built on
dart3d directly. The file list above is kept as reference only.*

### 5.4 Scene design ("Mythic table", our take on Dice Shadows)

- **Screen-fitted tray.** Top-down camera at a fixed px-per-unit, with
  walls fitted to the frustum and rebuilt on resize and rotation.
  Ceiling included. Safe-area insets are subtracted, which fixes
  follow-up #9 (dice resting under the tab bar). This closes the P3
  "edges = glass walls, iPad shows wood past walls" feedback.
- **Two looks.**
  - (a) **Felt/wood tray**: today's synthesized walnut, now fitted to the
    screen.
  - (b) **"Over the app" overlay**: dice over the real DartNative UI with
    shadows on it. (b) needs X1. Until then, fake it by rendering the
    game-night cards *inside* the scene as flat textured slabs, drawn
    with `dartnative_skia` to RGBA and uploaded as payload textures. They
    are real colliders, shadow receivers and breakable. That route
    avoids decision D6 entirely, because the cards are 3D objects, not captured
    widgets.
- **Finishes for polyhedral dice.** Resin, glass (transmission, with the
  iOS alpha fallback), gold, steel, wood (clearcoat), neon (emissive +
  bloom), marble. Each is a material override on the imported dice
  (`upsertResource`), not a new mesh. Opal/iridescence waits for a fake
  thin-film texture.
- **Light.** Sun preset copied from upstream (el 46.8°, 2 cascades on
  Android). Once E5 lands, add a lamp mode with a draggable light handle
  (E5 spot, V3 point).

### 5.5 Phases

| Phase | Content | Depends | Size |
|---|---|---|---|
| **DR1: correct and fitted** | S0g readout fix (matrix read + z mirror) with a unit test per die type. Settle lane (W25/S0g). Frustum-fitted walls and ceiling with safe-area insets. Labeled Reset. d6/d20 regression screenshot set. | S0g readout (Dart owner) | S–M |
| **DR2: the throw** | Aim arrow (drag → release, 420 px full pull, colour/width ramp, dissolve). Off-screen spawn along the arrow with ballistic lift. End-over-end spin. Poisson cluster. Sweep-to-shove. **Pick-up-and-toss** (operator P3: long-press lifts the dice to a hover plane, the flick velocity throws them). Upstream's tuning constants retuned per die type, since d4/d20 roll very differently from d6. | DR1 | M |
| **DR3: notation and score** | P1 contract. Notation bar (`mythic_dice_parser`). Per-die tick count-up (0.26·0.92ⁱ), group/total readout, explode → extra throw, history strip. Interim audio via `dartnative_audio` (clack/table/wall sets, log volume, echo gate, driven by W23 contact impulses). | P1 | M–L |
| **DR4: juice** | Screen shake (DartNative `Transform`). Trails >5 u/s. Skid decals (sprite quads now, `DecalNode` after V4). Confetti (110-node pool, or instanced after E1). Point-light flash. Slam into a result sticker. Slow-mo on a forming crit/match (`scene.update` time-scale equivalent: a native physics time scale is needed, **ask X5**, else no slow-mo). Nat-20 / nat-1 escalation (the Mythic equivalent of upstream's ×3–×6 tiers: fireworks, golden-hour sun sweep, dice hop). Outline on counted dice after E5b; shockwave after X2. | E5b, X2, X5 (each optional; ship without) | M |
| **DR5: finishes and polish** | Finish picker, looks, quality picker (P3: auto by device + override). iPad white-screen root cause (P3). Upstream side-by-side video. T4 review. `dart3d_audio` swap-in once E11 lands. | E11 for final audio | M |

DR1–DR3 alone should already match upstream on feel (throw, physics,
sound, count-up) and beat it on dice variety and notation. DR4–DR5 match
the spectacle.

---

## 6. Assets and licensing

**Upstream code** is MIT, © 2023 Brandon DeRosier (root and package
LICENSEs; box3d/fmod/rapier/soloud are © 2025). Porting logic (throw
maths, celebration timings, cloth solver, confetti sim, kit components)
is allowed with the MIT notice. We already ship
`assets/showcase/LICENSE.flutter_scene`. Extend `ATTRIBUTION.md` to name
each ported file.

| Asset | Where | License status | Decision |
|---|---|---|---|
| Procedural dice/pips/wood/marble, VFX flipbooks, env paintings | upstream code | MIT (they are code) | **Reuse** by porting the generators |
| `dice_*.wav`, `land_*`, `celebrate_*`, `card_*`, `firework_*`, `jackpot` (≈72 WAVs) | `examples/flutter_app/assets/sounds/` | **No license or credit.** Commits call them "generated sounds", but no generator script is committed. | **Do not ship.** Ask upstream (issue) about provenance or a generator. Meanwhile, **recreate**: record our own dice (Retro Classic set on wood/felt/glass) or synthesize (modal synthesis in a small tool script), and credit our own. |
| `pluck.wav` | same | Karplus-Strong, generated in-house (commit 689e27eb). No license file, but it falls under repo MIT as generated content. | Low value; recreate (trivial) |
| `dash.glb` | `examples/assets_src` | **Undocumented** (Dash mascot; Flutter/Google trademark context) | Already in the Showcase under the MIT note. **Recommend removing it from any published demo**: dartpub.dev + DartNative branding + Flutter mascot is a trademark risk. Use a DartNative-owned or CC0 character for M8 (Quaternius / Kenney CC0 characters). |
| `fcar.glb` | same | **Undocumented** | Keep in the dev Showcase. For M2/M4/M12, ask upstream about provenance, or swap in a CC0/CC-BY car (Khronos `CarConcept`, check its license; Poly Pizza CC0). |
| `flutter_logo_baked.glb` | same | Flutter logo = Google trademark | **Already removed** from the Showcase (P4) |
| `two_triangles.glb`, `examples/scenes/*.fscene` | same | trivial / MIT | Keep |
| `little_paris_eiffel_tower.png` | `flutter_app/assets` | **Undocumented.** The name matches the Poly Haven HDRI (CC0), but that is unverified. | Pull the original from Poly Haven directly (CC0, no attribution required), not from upstream |
| `testsrc.mp4` | same | likely ffmpeg `testsrc` | Regenerate with ffmpeg if E10 needs it |
| Khronos glTF-Sample-Assets (DamagedHelmet, FlightHelmet, MaterialsVariantsShoe, ABeautifulGame, Sponza…) | downloaded at runtime | Per-model: e.g. MaterialsVariantsShoe © Shopify **CC BY 4.0** (credit on screen); DamagedHelmet CC BY 4.0; others vary | **Reuse** per model with on-screen credit plus `ATTRIBUTION.md` rows. Bundle only the few M2/M7 needs and fetch the rest at runtime. |
| Khronos glTF-Sample-Environments HDRs | runtime | per-file, mostly CC0/CC-BY | Reuse with credit; prefer Poly Haven CC0 HDRIs |
| Splats: Strawberry (danylyon), Classroom (hite404) | superspl.at, fetched by script | **CC BY 4.0** | Reuse for M11 with credit; do not commit (size) |
| Bach Goldberg Aria (Musopen) | Wikimedia | CC0 | Reuse for M14 |
| DICOM (datalad PDDL / Zenodo CC-BY-SA) | runtime | PD / share-alike | Not planned |
| `.fmat` sources (toon, ocean, road, sky, materialize, crt, cloth, scorch_decal…) | `flutter_app/assets` | MIT (text) | **Reuse** as E6/V5 test inputs and M9 content, with the MIT note |
| Our dice set ("Retro Classic Recessed"), `dice_faces.json` | `dart3d/example/assets/dice` | in-house (tome_keeper) | Keep |
| `mythic_dice_overlay` glossy/matte dice | `mythic_gme_apps` | in-house | Reusable after the `.fsceneb` conversion |
| DartNative logo | our Blender build | © Presence Network; demo use | Keep the P4 guardrails (`hero-scene-brief.md` §4) |

Upstream has **no ATTRIBUTION/CREDITS file at all**. We must not
inherit that gap: every demo asset gets an `ATTRIBUTION.md` row before
T4.

---

## 7. Engine asks raised by the demos (for the Track E/V owners)

These are **not** in program-v2's unit list. They come from demos, so by
the O1 rule they are proposals for the operator to schedule, not work a
demo lane does.

| Ask | Needed by | What | Notes |
|---|---|---|---|
| **X1: transparent SceneView** | M1 look (b); any AR-style overlay | Clear-to-alpha host view composited over DartNative widgets. Android: `TextureView` or `SurfaceView.setZOrderOnTop` + `PixelFormat.TRANSLUCENT` with a Filament clear alpha. iOS: `SCNView.backgroundColor = .clear`, `isOpaque = false`. | This is upstream's signature dice trick ("shadows on your UI"). It also needs input pass-through to the widgets underneath. Size M. Candidate for U3/E5b scope. |
| **X2: screen distortion** | M1 DR4, M6 | 0.24 `Scene.screenDistortion` pulses (a radial refraction post pass) | 0.24 surface, now tracked as **V6b** in program-v2 (realize or record an operator-approved exclusion before V8). |
| **X3: native vehicle** | M12 | `d3:vehicle` modelled on upstream's example-local raycast vehicle: Jolt `VehicleConstraint`, `SCNPhysicsVehicle` | decision D4 allows `d3:` only where upstream has no wire form; upstream's vehicle is app code, so this is an extension. Operator call. |
| **X4: streamed dynamic vertices** | M13 cloth, M8 water (CPU path) | A per-frame vertex update path (position/normal buffer replace) with a perf number on the A142 | Might already be fine through `upsertPayload`; measure first (S-sized spike). |
| **X5: physics time scale** | M1 slow-mo, M6 | Scale the physics step (Jolt substep dt, `SCNPhysicsWorld.speed`) | Small. Both natives have the knob. |
| (existing) E2, E5, E5b, E6, E11, E12, V1, V3, V4 | see §4.2 | — | Demos consume them. Priority from the demo view: **E6 > E2 > E5b > E11 > E4 > E5 > V3 > E12.** |

---

## 8. Operator decisions (2026-09-29)

1. **Dice in the example app:** yes — a *fantastic* dice experience, far
   nicer than today's dice table (§5 phases stand). **No extraction
   planning** (§5.3 is dropped for now; the operator hasn't decided whether
   or how Mythic will use it).
2. **Standalone dice-roller app (new, M-APP):** a separate, dice-rolling-only,
   mobile-only DartNative app built on dart3d, for the operator's portfolio
   (possibly published free or paid). Its own project/repo, not part of the
   example; it can grow from the example's dice experience once that's great.
   Plan it after DR3 lands in the example.
3. **Dash / fcar:** stay out of published demos. Their provenance is well
   documented online (standard flutter_scene / Flutter GPU / Flame sample
   models), but we need **solid replacements**: license-clean hero models
   (Khronos glTF samples with per-model licenses, CC0 packs such as Kenney /
   Poly Pizza, Poly Haven, or our own Blender models built reproducibly like
   the DN logo). Replace them in the Showcase before any public demo build.
4. **New flagship demo ideas** (beyond upstream's corpus):
   - **M16 Pirate ship on water** — stylized ocean (Gerstner/FFT-style waves
     via E6 shader contract, or a vertex-animated mesh via X4 until then),
     buoyant ship bobbing (physics or scripted), sky + sun (E3), foam/spray
     particles (W18). Depends on E6 (water shader) for the full look.
   - **M17 Street-corner diorama with a streetcar** — a small, stylized
     city corner in Frankfurt (Ostend) with a tram running through, in the
     spirit of the Japanese-town dioramas going around on X: buildings,
     tram with a looping route (W16 trails/curves for rails), day–night
     lighting (E3), windows lighting up, people/cars as instanced props (E1
     GPU instancing). Geometry from OpenStreetMap building footprints
     (ODbL — attribution required) + Blender procedural facades.
     **Privacy:** the exact address is the operator's own and this repo is
     public — never commit it; reference details are shared privately at
     build time.
5. **Upstream dice sounds:** not reusable (no license) — we make our own.
6. **Asset source:** the operator owns Kenney's complete asset collection
   (itch.io "All-in-1"); Kenney assets are CC0, so they're the default
   source for props and replacements (vehicles, city/town and tram-friendly
   kits, pirate kit, nature, characters, UI/audio packs). Credit Kenney in
   ATTRIBUTION.md anyway (courtesy). Local path of the pack: ask the
   operator when first needed.

Former open questions 3 (async `CallbackDiceRoller`) and 4 (X1 transparent
view) remain open for when the dice work reaches DR3/DR4.

## 9. Original open questions (answered in §8)

1. Should the dice roller stay in `dart3d/example` as the plugin demo,
   with the Mythic app (P2) reusing it? Or should it be built directly in
   P2's app with the example keeping a smaller copy?
   Recommendation: build it in the example first (DR1–DR3), then extract it
   into P2.
2. `mythic_dice_core` extraction (§5.3): yes, or copy?
3. Can `CallbackDiceRoller` be made async in `mythic_dice_parser`
   (explode → physical re-throw)?
4. Schedule X1 (transparent view)? Without it, M1 does "over the app"
   with in-scene cards, which is still physical and breakable.
5. Dash and fcar provenance: drop them from published demos, or ask
   upstream?
6. Upstream sound provenance: file an upstream issue asking for the
   generator or a license?
