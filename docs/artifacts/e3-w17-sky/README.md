# E3 (W17) — Physical sky, `skyEnvironment` relighting, `sunLight`, and progressive IBL prefiltering

Evidence for **Unit E3 (`W17 sky / environment`)** across **A142 Vulkan**, **A142 OpenGL**, and **iPhone 17 Pro simulator**.

## 1. Summary of implementation

- **Native physical-sky equirect generator (`EnvironmentFactory.kt`, `FsceneRealizer.swift`, `sky_generator.dart`):**
  - Ports upstream `flutter_scene_sky_physical.frag` (analytic Preetham single-scattering Rayleigh + Mie daylight model with zenith optical mass, low-sun extinction re-saturation, horizon ground fade, and atmospheric-attenuated HDR sun disk).
  - Hoists row-invariant optical mass / extinction and column-invariant longitude trig so a `1024×512` (1k) float equirect generates in **`91.51 ms` (Vulkan)** / **`129.22 ms` (OpenGL)** on A142 (budget: `< 200 ms`).
- **`skyEnvironment` relighting & `sunLight` (`SunLightSpec`) directional light:**
  - When `skyEnvironment` is present with a `"physical"` or `"gradient"` sky source, it drives the scene's image-based lighting (`IndirectLight` + SH3 on Android; `scene.lightingEnvironment` on iOS), overriding `environment`. When `skyEnvironment` is absent (`override` mode), the stage's `environment` takes precedence.
  - When `skyEnvironment.sunLight` (`SunLightSpec`) is present, both platforms drive a stage-owned shadow-casting directional sun light aimed opposite `sunDirection` (`-normalize(sunDirection)`) with upstream's derived sun color and intensity (`3.0 * energy * intensityScale` for `PhysicalSkySpec`; `peak * intensityScale` for `GradientSkySpec`).
- **Rate-limited + 3-step progressive IBL prefiltering during sun sweeps:**
  - On Android, background worker thread `skyBakeExecutor` prepares `EnvPixels`, `filamentShifted`, `projectEquirectSH`, and cubemap mip `HALF` buffers off the UI thread (`32²` step 1 → `64²` step 2 → `128²` step 3), uploading at most one bounded step per frame (`0.10–0.76 ms` on the render thread) and retiring replaced GPU handles 4 frames later.
  - On iOS, `SceneViewHost.advanceProgressiveSkyEnv` advances `64×32` (step 1) → `128×64` (step 2) → `256×128` (step 3) across frames.

## 2. Sun-sweep frame time & 1k generation perf (A142 `00064149A002033`)

| Metric | A142 Vulkan | A142 OpenGL | Budget / Gate |
|---|---|---|---|
| **1k (`1024×512`) physical-sky equirect generation** | **`91.51 ms`** | **`129.22 ms`** | `< 200 ms` |
| **Sun-sweep steady FPS (60 steps)** | **`89.3–89.8 fps`** (`0` skipped) | **`89.3–89.9 fps`** (`0` skipped) | Smooth 90 Hz |
| **Sun-sweep frame `p50 / p95 / max`** | **`11.1 / 11.2 / 22.3 ms`** | **`11.1 / 11.2 / 22.3 ms`** | `max <= 33.0 ms` |
| **Main-thread step upload (`step 1 / 2 / 3`)** | **`0.15 / 0.38 / 0.28 ms`** | **`0.15 / 0.39 / 0.35 ms`** | Non-blocking |

## 3. Progressive prefilter 3-step convergence (MAE vs full-prefilter `day` reference)

| Step | Resolution | A142 Vulkan MAE | A142 OpenGL MAE | iOS Sim MAE |
|---|---|---|---|---|
| **Step 1 (`step1`)** | `64×32` (`32²` cube + SH3) | `2.619 / 255` (`1.03%`) | `2.629 / 255` (`1.03%`) | `0.044 / 255` (`0.02%`) |
| **Step 2 (`step2`)** | `128×64` (`64²` cube + SH3) | `0.781 / 255` (`0.31%`) | `0.780 / 255` (`0.31%`) | `0.015 / 255` (`0.01%`) |
| **Step 3 (`step3`)** | `256×128` (`128²` cube + SH3) | **`0.121 / 255` (`0.05%`)** | **`0.121 / 255` (`0.05%`)** | **`0.000 / 255` (`0.00%`)** |

## 4. Artifact manifest

- **A142 Vulkan:** `a142-vulkan-{day,lowsun,override,step1,step2,step3,sweep-final,dice}.png`, `a142-vulkan-w17-{run,native}.log`, `a142-vulkan-dice-{run,native}.log`
- **A142 OpenGL:** `a142-opengl-{day,lowsun,override,step1,step2,step3,sweep-final,dice}.png`, `a142-opengl-w17-{run,native}.log`, `a142-opengl-dice-{run,native}.log`
- **iOS Simulator (`C24F3C6D-A3A9-4FB7-978E-36E67EF55354`):** `ios-sim-{day,lowsun,override,step1,step2,step3,sweep-final,dice}.png`, `ios-sim-w17-run.log`, `ios-sim-dice-run.log`
