# W7 — Environment and image-based lighting

Status: spec. Implements `docs/dart3d-completion-program.md` W7.

The visible Android gap: Filament renders direct light only — no
ambient term — so everything not lit by the key light reads flat and
dark. iOS reads better because SceneKit still looks decent under
direct light. Upstream's realizer defaults every document to the
built-in **studio** IBL when `stage.environmentRef` is absent or
unresolvable — that default is the whole `flutter_scene` demo look.

## Wire (upstream-conformant)

`stage.environmentRef` → resource `{kind:'environment', …}`:

```jsonc
{
  "name": "…",
  "environment": { "type": "studio" },          // sealed
  "environmentIntensity": 1.0,
  "exposure": 1.0,                              // linear, pre-tonemap
  "toneMapping": "pbrNeutral",                  // operator name
  "agxWhite": 16.29, "agxContrast": 1.25,       // only when agx
  "environmentRotationY": 0.0,                  // radians
  "radianceCubeSize": 64,                       // reflection cube px
  "skybox": { "source": {...}, "intensity": 1.0 },
  "skyEnvironment": { ... },                    // procedural sky
  "effects": { ... },                           // post stack — W10
  "overridesEffects": true
}
```

`environment.type` values: `studio`, `asset` (`{ref: assetKey}`),
`payload` (`{payload: idToken}` — equirect bytes: Radiance HDR,
OpenEXR, or LDR equirect; decoder picked from magic bytes, `format`
tag informational), `constant` (`{color:[r,g,b]}` — uniform diffuse
ambient, no reflections), `empty`.

`skybox.source.type`: `environment` (draw the IBL env, optional
`blurriness`), `gradient` (zenith/horizon/ground colors + sun disk —
built-in stylized sky), `fmat` (asset path), `physical` — defer
`fmat`/`physical` with warn-once.

`skyEnvironment` (procedural sky regenerating the env) — defer,
warn-once. `effects` — implemented in W13 (`StageEffects` on both
platforms; per-block support matrix in `extended-surface-program.md`).

## The studio environment

`studio` is procedural, not a bundled asset. Port
`_generateStudioEquirectPixels` from
`flutter_scene/lib/src/material/environment.dart` **verbatim** to
both natives: 256×128 RGBA8 sRGB equirect — vertical gradient
(cool-neutral up, warm-dim down), `dirY²` ceiling softbox
(~0.85 additive), warm key lobe `pow(dot(key), 26)` ×1.1 at
`normalize(0.45, 0.55, 0.70)`, cool fill lobe `pow(dot(fill), ~4)`
at `normalize(-0.70, 0.22, -0.35)`. Row 0 = up pole (+y), standard
equirect. Keep upstream's exact constants — the point is a
pixel-identical env on both platforms.

## iOS realization

- `environment` → `scene.lightingEnvironment` — SCN accepts equirect
  `UIImage`/`MDLTexture` directly (internal cube conversion).
  `.hdr` decode via `MDLTexture(data:)`; LDR via `UIImage`;
  `.exr` — warn-once, deferred.
- `skybox.source=environment` → `scene.background` = same contents;
  `blurriness` → `background.intensity` stays 1, approximate blur by
  pre-blurring the generated/decoded pixels (box blur on the equirect
  is fine — warn-once that it's approximate).
- `environmentIntensity`/`environmentRotationY` — no native knobs:
  bake into pixels at source-build time (multiply RGB; yaw = horizontal
  wrap-shift of equirect columns — exact for rotationY).
- `constant` → `lightingEnvironment` = tiny solid equirect of the
  color (or `background` only if no skybox requested — lighting is the
  point).
- `empty` / absent-`environmentRef` → per upstream, default to
  **studio**, not empty. `empty` is an explicit black env.
- `exposure` → `camera.exposureOffset = log2(exposure)` with
  `wantsHDR = true` on the view's camera.
- `toneMapping` — iOS has no operator choice; log-once the name,
  use SCN's default filmic. Record the approximation in the matrix.

## Android realization

- Equirect bytes → texture: `.hdr` magic (`#?RADIANCE`/`#?RGBE`) →
  `HDRLoader.createTexture(engine, buffer)`; PNG/JPEG/etc →
  `BitmapFactory.decodeByteArray` → `Texture` upload (the W4
  `TextureFactory` path with linear format).
- `IBLPrefilterContext(engine)` → `EquirectangularToCubemap.run(tex)`
  → `SpecularFilter.run(cube)` → prefiltered reflections cubemap
  (sized by `radianceCubeSize` where the API allows; default 64).
- `IndirectLight.Builder().reflections(cube).irradiance(3, sh)
  .intensity(environmentIntensity × 30000).rotation(yawMat3)
  .build(engine)` → `scene.indirectLight`. `sh` = 9×3 SH3
  coefficients — port upstream's `_projectEquirectToSphericalHarmonics`
  (same source pixels; do NOT approximate with the specular map — SH
  is the upstream-true irradiance).
  **Filament measures `IndirectLight`/`Skybox` intensity in lux** and
  the C++ default is 30000 — a unitless upstream `environmentIntensity`
  bound raw reads as ~15 stops under-exposed: black skybox, ~invisible
  IBL (the W7 bring-up bug). `× 30000` is the durable mapping, not a
  fudge: the env equirect holds ~unit-range radiance and 30000 lx is
  Filament's reference indoor level.
- `skybox.source=environment` → `Skybox.Builder().environment(cube)
  .intensity(sky.intensity × environmentIntensity × 30000)`;
  `blurriness` → CPU box-blur on a dedicated equirect→cube (Filament's
  Skybox samples lod 0 — no mip knob; warn-once approximate).
- Re-decode cost: a payload arrival for any resource re-runs
  `decodeStage`, and the env build (equirect→cube→SH) is ~10–70ms.
  `Dart3dView.lastEnvFingerprint` gates the rebuild — stage JSON +
  env resource JSON + env payload bytes hash — so unchanged inputs
  skip straight past `applySkybox`/`applyEnvironment`/`applyStageLook`
  (their state is all inside the fingerprint). Payload claims persist
  across skips, so a deferred env still resolves on arrival.
- `gradient` sky → generate a small equirect (zenith/horizon/ground
  blend + sun disk via `pow(dot(sun), sunSharpness)` ×`sunColor`),
  feed the same cubemap path; a `gradient` sky does NOT light unless
  `skyEnvironment` also says so (defer).
- `constant` → `IndirectLight.Builder().irradiance(3, shOf(color))`
  where `shOf` = color × the DC coefficient (0.282095 × color per
  channel is the uniform-env SH) — no reflections map needed (or a
  1×1 cube; whichever is cheaper).
- `empty` → `scene.indirectLight = null`, black/default skybox.
- `exposure` → `camera.setExposure(exposure)` (EV form — verify the
  overload; the 3-arg physical form maps `exposure` to an EV first if
  needed). `toneMapping` → `ColorGrading.Builder().toneMapper(…)`:
  `pbrNeutral`→`ToneMapper.PBRNeutralToneMapper()`,
  `agx`→`ToneMapper.Agx()` (agxWhite/agxContrast → `Agx.AgxLook`
  where expressible, else warn-once), `filmic`→`Filmic`,
  `aces`→`ACES`, `linear`→`Linear`. Attach via
  `view.colorGrading`. Unknown names → warn-once, keep pbrNeutral.

## Stage updates

`diff.stageChanged` currently logs and skips (see
`scene_controller.dart`). Add a `stage` command op carrying the new
stage JSON; both realizers already have standalone `decodeStage` —
re-run it against the live context. Env payload pending → defer the
stage application until payload arrival (same deferred mechanism as
W4 textures), then re-run `decodeStage`.

## Harness probes (feature_scene.dart)

- Give the doc `stage.environmentRef` → a `studio` `EnvironmentResource`
  with `skybox: {source:{type:'environment'}, intensity:1}` — the
  baseline demo look on both platforms.
- An **Env** cycle toggle (like Ortho — reload, no new ops needed):
  none→studio→constant(0.25 warm)→payload-equirect→empty→studio.
  The payload env = a 64×32 PNG equirect generated in Dart (the
  `image` dev-dep already generates PNGs) with distinct up/horizon/
  ground bands so orientation is legible — sent via the existing
  payload chunk path.
- Keep everything else identical so parity regressions stay legible.

## Verify lanes (both platforms)

1. Regression — dice roll/settle unchanged with studio env active.
2. Studio IBL — surfaces read evenly lit; glossy/metal materials
   show env reflections; Android no longer flat-dark.
3. Environment skybox — the studio env visible as background.
4. Constant env — flat ambient tint, no reflections.
5. Payload equirect — bands visible in reflections/background.
6. Empty env — direct light only (the old Android look — proves the
   toggle path, not a target look).
7. `environmentIntensity`/`rotationY`/`exposure` — visible response
   on both (exact parity of rotation on iOS via column-shift).
8. `toneMapping:'pbrNeutral'` — Filament `PBRNeutralToneMapper`;
   iOS logs the name + approximates.
9. Stage update op — env swap through the diff path if landed, else
   reload path only.
10. Perf — prefilter cost logged; steady-state fps within 15 % of
    W6 baseline on the same scene.

Evidence under `docs/artifacts/w7/`; results into the matrix.

## Deferred

`skyEnvironment` procedural sky; `fmat`/`physical` sky sources;
`effects` post stack (bloom/AO/SSR/TAA/fog → W10); EXR on iOS;
environment volumes (spatial env blending).
