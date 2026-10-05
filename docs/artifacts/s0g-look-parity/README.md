# S0g: one document, one picture — look parity between iOS and Android

Measured on the iPhone 17 Pro simulator (`C24F3C6D-A3A9-4FB7-978E-36E67EF55354`, iOS 27.0) and the Nothing A142 (`00064149A002033`, Vulkan and forced OpenGL), with T2 smoke and harness runs across the A142, the Amazon Fire KFTUWI (`GN434J02409203LD`) and the Wacom DTHA116 (`5FL21V6001199`).

## Result

- **One document now produces the same picture on iOS and Android within stated per-patch tolerances** (8 out of 255 for unlit, emissive, textured and sky patches; 16 out of 255 for lit surfaces, spheres, light cards and shadows) across all 12 variants of the look-reference board (`--dart-define=DART3D_SCENE=lookref`, `tool/look_capture.sh`, `tool/look_compare.py`).
- **Every per-platform lighting or stage stopgap is deleted from the example:** `kIosDirectionalScale`, `keyLightIntensity`, `DnLogoStage.heroIos` / `heroAndroid` (now one `DnLogoStage.hero`), and the showcase's per-platform environment intensity.
- **Dice tray and hero match across platforms:** on iOS the dice tray felt was grey and the rim pale (`docs/artifacts/ios-debt-2026-10/`); now the felt reads deep indigo `(0, 2, 31)` on iOS against `(4, 5, 34)` on the A142, the lime and pink rim endpoints read `(199, 217, 95)` and `(255, 96, 177)` on iOS against `(199, 221, 96)` and `(255, 97, 179)` on the A142 (`img/pair-dice2.jpg`), and the hero logo and backdrop read `(156, 145, 106)` / `(4.4, 10.9, 19.0)` on iOS against `(150, 138, 98)` / `(5.9, 11.9, 15.4)` on the A142 (`img/pair-hero4.jpg`).

## Causes found and fixed

Per-step tables from `tool/look_compare.py` live under `tables/`:

| # | Commit | Cause and fix | Measured effect on the board (iOS vs A142, mean abs diff / 255) | Table |
|---|---|---|---|---|
| 0 | `23500e7` | **Baseline look-reference board** (`DART3D_SCENE=lookref`, 12 variants, 48 patches). | Worst patch per kind: unlit `71.8`, emissive `254.7`, directional lit `165.5`, point `163.2`, spot `254.7`, constant IBL `47.7`, shadow `39.7`, sky `13.6`. | `tables/0-baseline.md` |
| 1 | `c00b9c3` | **iOS decoded linear wire colours as sRGB.** `UIColor(red:green:blue:)` tags values as sRGB, so SceneKit decoded them a second time (`0.18` grey became `0.027`). Base, emissive, light and particle colours now use `extendedLinearSRGB`, and texture factor baking decodes sRGB before scaling. | Unlit greys `0.02 / 0.05 / 0.18 / 0.5`: `33.7 / 50.4 / 71.8 / 60.9` → `0.3 / 0.4 / 0.2 / 0.1`; indigo `44.7` → `0.3`. | `tables/1-ios-linear-colours.md` |
| 2 | `fdcb9e7` | **Light and environment units differed between natives.** Both natives now implement upstream `flutter_scene` 0.23 units (`docs/android-parity-spec.md` §Light units): directional `I` puts `I/π` on a normal surface, point/spot `I/d²`, `environmentIntensity` scales radiance directly, and `exposure` is one linear multiplier. | Directional lit `165.5` → `1.5`; point `163.2` → `0.2`; spot centre `254.7` → `0.3`; constant IBL `47.7` → `10.5`; sky `13.6` → `0.5`. | `tables/2-upstream-units.md` |
| 3 | `12feb8d` | **iOS left `wantsExposureAdaptation` on (`true` by default)** when a document had no environment or no `effects` block, auto-metering toward mid-grey. | `default-stage` unlit grey `0.5`: `171` → `181`; lit grey `0.5`: `179` → `189`. | `tables/3-ios-exposure-adaptation.md` |
| 4 | `fba8530` | **iOS ignored `toneMapping` and sampled the grading LUT in linear light before tone mapping.** Added the `SCNTechnique` resolve pass (`ToneMapping.swift`) implementing `pbrNeutral`, `aces`, `reinhard`, `linear` and `agx` (evaluating `pbrNeutral`/`reinhard`/`linear` in Rec. 2020 primaries to match Filament's colour grading) and post-tone-map sRGB LUT sampling. | `unlit-neutral` worst `29.2` → `6.8` (indigo `25.2` → `0.4`); `all` lit `21.0` → `10.8`, spheres `19.3` → `3.8`, light cards `16.3` → `1.8`. | `tables/4-ios-tone-map.md` |
| 5 | `b01d46b`, `6a64281`, `394c04d` | **Android ignored exposure on emission and unlit materials, dropped bare emissive factors without a texture, and mapped `aces` to unscaled `ACES` instead of `ACESLegacy` (1/0.6 input gain).** Rebuilt the 20 shipped material packages + hero variants. | Emissive under `linear` `254.7` → `6.9`; `unlit-exposure2` grey `0.5` `67.1` → `6.9`; `unlit-aces` worst `41.3` → `7.0`. | `tables/5-android-emissive-exposure-aces.md` |
| 6 | `219a922` | **In an `SCNView`, SceneKit clamps the `SCNTechnique` input to `0..1`.** Set camera `whitePoint = 16` so SceneKit packs `0..16` through its extended Reinhard curve `x(1 + x/w²)/(1 + x)`, then inverted that curve in the resolve pass before upstream colour grading, tone mapping and vignette. | Emissive worst under `pbrNeutral` `27.5` → `6.2`, `all` `27.7` → `5.3`, `aces` `16.9` → `7.1`. | `tables/6-ios-resolve-keeps-hdr.md` |
| 7 | `0080033` | **iOS `MTKTextureLoader` ignored `.SRGB: true` on 8-bit `CGImage` inputs** (`bgra8Unorm` instead of `bgra8Unorm_srgb`), sampling colour textures without sRGB decode. Now creates an sRGB pixel-format view and regenerates mipmaps through it. | Unlit texture under `linear` `46.3` → `0.7`; emissive texture `49.7` → `0.3`; worst textured patch under `all` `80.4` → `6.2`. | `tables/7-before-ios-srgb-textures.md`, `tables/7-ios-srgb-textures.md` |
| 8 | `53c16b2` | **SceneKit's bloom gated on luminance at threshold and added the whole colour; Filament blooms only the channel excess above 1 through a half-size pyramid.** Implemented Filament's bloom pyramid (threshold, downsample chain from 384 px on the short side, tent upsample chain, pre-tone-map add) in `ToneMapping.swift`. | `all-bloom` worst emissive `30.7` → `5.2`, unlit `14.5` → `7.6`, lit `17.4` → `8.3`. | `tables/8-ios-bloom.md` |
| 9 | `eed62be`, `c0e920c` | **Android dimmed a gradient sky by `environmentIntensity` whenever an `IndirectLight` was bound, and iOS lost dark precision in 8-bit sky/environment images and the 8-bit technique input.** Android divides float gradient sky pixels by `environmentIntensity`; iOS uploads float sky images, keeps environment intensity on `lightingEnvironment.intensity`, and applies an 8× camera packing gain before the resolve pass divides it out. | `ibl-studio` sky matches `intensity: 1` (`(89, 124, 170)` vs `(88, 124, 169)`); hero backdrop `(0, 14, 23)` → `(4, 11, 19)` on iOS vs `(6, 12, 15)` on the A142. | `tables/9-ios-environment-precision.md` |
| 10 | `ac6af4b`, `a992082` | **iOS spot light cone falloff was wider than upstream's squared cosine ramp; Android cleared a sky-less view to `(0.06, 0.06, 0.08)` instead of black and used a 32³ LUT for `linear` tone mapping.** iOS projects upstream's ramp as a float gobo on spot lights; Android clears to black and uses `QualityLevel.ULTRA` (64³ LUT) for `linear`. | `spot.penumbra` `30.2` → `0.7`; `default-stage` sky `47.2` → `0.1`; `unlit-linear` worst unlit patch `14.9` → `1.4`. | `tables/10-spot-cone-and-linear-lut.md` |

## What does not match (residuals for S1)

1. **The environment's diffuse term** (up to ~10 sRGB codes on dark/mid lit cards under IBL): Filament prefilters diffuse irradiance into 3-band spherical harmonics (`libs/iblprefilter`); SceneKit samples its own irradiance map from `lightingEnvironment.contents`.
2. **Highlights through Filament's 3D colour-grading LUT** (~4–6 codes near 255 under `pbrNeutral`/`aces`): Filament bakes grading + tone mapping into a 32³ log-domain LUT (`ColorGrading`), which slightly softens the shoulder near 1.0 compared with evaluating the analytic curve per fragment on iOS.
3. **Shadow filtering:** SceneKit uses a 16-sample PCF kernel on iOS; Android uses PCF on the low tier and VSM/DPCF per quality profile. Umbra levels match within 7–8 codes; penumbra softness differs slightly.
4. **Tone-mapper coverage on Android:** `reinhard` is implemented on iOS only (Filament has no Reinhard tone mapper; Android logs once and uses `pbrNeutral`). `agx` evaluates upstream's inset/outset curve on iOS and Filament's built-in `AgX` on Android.
5. **Three Android / Filament 1.71 findings documented, not changed here:**
   - Under an orthographic projection, Filament 1.71 clips an off-axis point or spot light to a cross of froxels (`img/filament-ortho-point-light-a142.jpg` vs `img/filament-ortho-point-light-ios.jpg`), which is why the look-reference board uses a narrow perspective lens.
   - Filament's default light fade begins attenuating punctual lights toward 100 units from the camera.
   - Filament clamps its bloom highlight limit to at least 10, so `bloomThreshold` values below 10 have no effect on Android.
6. **Physical iOS device and KTX2 colour textures on iOS:** Look parity was measured on the simulator (8-bit sRGB screenshots and 8-bit `SCNView` drawable before the resolve pass); physical iOS P3 drawables and KTX2 colour textures (which take a separate loader path from `MTKTextureLoader`'s `CGImage` path) remain in *Verification debt* (`docs/program-v2.md`).

## Review threads on #57

| Thread | Finding | Verdict |
|---|---|---|
| `4188023074` (`SceneViewHost.swift:424`) | Split-screen sibling views reused the host view's `BloomChain`, stretching bloom when a sibling's viewport aspect differed from the host's. | **Fixed.** `applySiblingResolve` builds a `BloomChain` sized from each sibling's own `bounds.size`, and `layoutSubviews` refreshes sibling resolve passes alongside the host's. |
| `4188023088` (`look_compare.py:134`) | Missing requested captures were silently skipped and an empty comparison exited `0`. | **Fixed.** Exits `2` when any variant named in `--variants` is absent from either directory, or when `compared == 0`. |
| `4188023097` (`docs/android-parity-spec.md:156`) | Spec listed `reinhard` as supported without noting that Android has no Reinhard mapper and substitutes `pbrNeutral`. | **Fixed.** `docs/android-parity-spec.md` states that `reinhard` is implemented on iOS only and Android logs and uses `pbrNeutral`, and records the `agx` difference. |
| `4188023102` (`FsceneRealizer.swift:3288`) | Premultiplied sRGB colour texels were passed straight into the sRGB lookup table without unpremultiplying alpha first. | **Fixed.** Unpremultiplies RGB by texel alpha before the `srgbScaleTable` lookup, then re-multiplies by `alpha / 255 * alphaFold`. |
| `4188023111` (`ToneMapping.swift:388`) | `smoothness: 0` on an enabled vignette gave `smoothstep(r, r, dist)` with equal edges. | **Fixed.** Clamps the transition width to `max(params.d3Vignette.z, 1e-4)`. |

## T2 and frame rate

Every surface ran hero, dice racked, dice rolling/settled, and the full verification harness (`DART3D_SCENE=harness`) through `w18 lane complete`. The review-fix commit (`0f9ac1c`) touches only `dart3d/ios/Classes/**`, `dart3d/tool/look_compare.py` and `docs/**` (zero Android files changed after `a992082`), so the Android T2 and harness runs from `a992082` cover the final Android code and the iOS simulator ran `lookref` (`ios-c14`) and T2 (`ios-t2-*`) on the final head.

| Surface | Backend, tier | Hero | Dice racked | Dice rolling | Harness | FATAL / crash |
|---|---|---|---|---|---|---|
| iPhone 17 Pro sim (iOS 27.0, debug) | Metal (SceneKit) | pass (`img/ios-hero.jpg`) | pass (`img/ios-dice.jpg`) | pass (W25 + #56 lanes) | complete, w11/wLoose/w15/w24/w25/w18 PASS (`img/ios-harness.jpg`, `logs/ios-harness.log`) | 0 |
| Nothing A142 | VULKAN (pref=0), STANDARD | 89.7 fps (`img/a142-vulkan-hero.jpg`) | 49.6 fps (`img/a142-vulkan-dice.jpg`) | 50.0 fps (`img/a142-vulkan-settled.jpg`) | complete, W25 PASS (`img/a142-vulkan-harness.jpg`, `logs/h-a142-vk.out`) | 0 (`logs/t2b-a142-vk.out`) |
| Nothing A142 (`DART3D_BACKEND=opengl`) | OPENGL (pref=1), STANDARD | 83.9 fps (`img/a142-opengl-hero.jpg`) | 32.1 fps (`img/a142-opengl-dice.jpg`) | 32.4 fps (`img/a142-opengl-settled.jpg`) | complete, W25 PASS (`img/a142-opengl-harness.jpg`, `logs/h-a142-gl.out`) | 0 (`logs/t2b-a142-gl.out`) |
| Amazon Fire KFTUWI | OPENGL (pref=0), LOW | 57.2 fps (`img/fire-hero.jpg`) | 44.8 fps (`img/fire-dice.jpg`) | 44.6 fps (`img/fire-settled.jpg`) | complete, W25 PASS (`img/fire-harness.jpg`, `logs/h-fire.out`) | 0 (`logs/t2b-fire.out`) |
| Wacom DTHA116 | OPENGL (pref=0), LOW | 58.8 fps (`img/wacom-hero.jpg`) | 51.1 fps (`img/wacom-dice.jpg`) | 43.9 fps (`img/wacom-settled.jpg`) | T2 pass (`logs/t2b-wacom.out`) | 0 |

## Checks (T1)

- `dn analyze` + `dn test` in `dart3d/`: 0 issues, 277/277 tests pass.
- `dn analyze` + `dn test` in `dart3d/example/`: 0 issues, 231/231 tests pass (8 new in `test/look_reference_test.dart`).
- `:dart3d:testReleaseUnitTest`: BUILD SUCCESSFUL.
- `xcrun swiftc -typecheck` of `dart3d/ios/Classes/*.swift` against `iPhoneSimulator27.0.sdk` (`arm64-apple-ios16.0-simulator`): 0 errors.
