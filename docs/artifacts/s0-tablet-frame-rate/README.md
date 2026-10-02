# Fire tablet frame rate (2026-10-02)

Device: Amazon Fire KFTUWI, Android 11, MT8169, Mali-G52 MC2 (driver
r26p0), 2.9 GB, 60 Hz. It sat in portrait, so the scene view rendered at
1200×1920 (the baseline run was landscape; the pixel count is the same).
Build: `dn run -d GN434J02409203LD --release` from `dart3d/example`,
branched from `ccf30c1`.

## Result

| Screen | Before | After |
|---|---|---|
| Hero | 33.7 fps (frame p50 33.3 / p95 34.0 ms) | 55.3 fps (p50 16.6 / p95 33.3 ms) |
| Dice, racked | 8.7 fps (p50 116.4 / p95 116.8 ms) | 44.2 fps (p50 16.7 / p95 33.3 ms) |
| Dice, rolling | 8.8 fps (p50 116.4 / p95 133.5 ms, worst 166) | 43.4 fps (p50 16.7 / p95 33.3 ms, worst 67) |

The target was 30 fps sustained while rolling and as near 60 at rest as
the GPU allows. Rolling holds above 30: the slowest 2-second window in
36 s of back-to-back rolls was 39.7 fps. Rest does not reach 60. With the
resolution at its floor (half scale) the GPU still needs 22.5 ms a dice
frame, so frames alternate between one and two vsyncs. That is the
ceiling for this scene on this GPU without taking more away from the
picture.

The look changed on the tablet: shadows are hard-edged instead of soft,
and the 3D layer renders at half resolution on the dice screen
(`tablet-before-*.jpg`, `tablet-after-*.jpg`). Numerals stay readable.
The A142 renders through the same pipeline as before.

## How it was measured

Three sources, all read with the app in release mode.

1. **In-plugin frame log** (`FramePerf.kt`, new). Off by default; on with
   `adb shell setprop log.tag.dart3d.perf DEBUG`. Every 2 s the view logs
   one `perf` line to logcat with, per rendered frame, the median and p95
   of:
   - `frame`: interval between rendered frames, from Choreographer vsync
     timestamps. It quantizes to 16.6 ms steps.
   - `gpu`: Filament's GPU time for the frame
     (`Renderer::getFrameInfoHistory`, reached through the JNI shim
     because 1.71.6 has no Java binding). Not quantized.
   - `backend`: wall time on Filament's driver thread.
   - `sim` and `physics`: main-thread time before the draw, and the Jolt
     step inside it.
   - `submit`: main-thread `beginFrame`…`endFrame`.
   - `skipped`: Choreographer callbacks where Filament's frame pacing
     declined to draw.

   On enable it also logs one `perf view` line with the settings in
   effect, read back from the Filament view.
2. **SurfaceFlinger** as a cross-check:
   `dumpsys SurfaceFlinger --latency <SurfaceView layer>`, interval
   between actual present times over the last 127 frames (about 3 s).
   At rest it agreed with the `frame` column to within 1 fps.
3. **Screens.** Hero: 30 s. Dice racked: 30 s. Dice rolling: the Roll
   button tapped every 3 s for 24–36 s. The first 2 s window after a
   change is dropped. "fps" is rendered frames over wall time; "p95" is
   the median of the per-window p95s; "worst" is the longest single
   interval.

**GPU time exists only on OpenGL on this tablet.** On Vulkan, Filament's
frame history stays empty on this driver, so the Vulkan rows carry frame intervals only. The attribution
below was therefore run on the OpenGL backend
(`--dart-define=DART3D_BACKEND=opengl`), where the baseline is the same
order: 125.8 ms GPU, 8.0 fps, against 116.4 ms intervals and 8.7 fps on
Vulkan.

## Baseline settings (read from the view)

`perf view` on the dice screen before the change:

```
backend=VULKAN viewport=1200x1920 msaa=4 aa=FXAA post=true hdr=HIGH
bloom=true(levels=7 res=384 q=LOW) ssao=false taa=false ssr=false
dsr=false dither=TEMPORAL quality=default physics=120Hzx4
entities=31 bodies=13
```

Shadows: one directional light, DPCF, 1024 map, one cascade. Tone
mapper: PBR Neutral. Render scale 1.0. Main-thread cost was small (sim
0.3 ms, submit 2.4 ms at rest), so the screen was GPU-bound, except
while rolling, when main-thread sim took 12.4 ms median and 48.7 ms p95
(the Jolt step alone, timed later: 5.1 and 36 ms).

## Attribution

Dice racked, OpenGL, one change at a time from the baseline, GPU ms per
frame (median). Toggles were applied at run time through a temporary,
uncommitted hook that read `debug.d3.*` system properties and wrote the
corresponding Filament view option.

| Change | GPU ms | Saved |
|---|---|---|
| Baseline | 126.7 | |
| Hide the tray (floor + rim) | 41.5 | 85.2 |
| Render scale 0.5 | 41.9 | 84.8 |
| Shadows off | 57.0 | 69.7 |
| Shadows PCF instead of DPCF | 78.6 | 48.1 |
| Render scale 0.75 | 82.7 | 44.0 |
| Hide dice shells and logos | 102.5 | 24.2 |
| MSAA off | 103.8 | 22.9 |
| HDR buffer LOW (R11G11B10F) | 106.7 | 20.0 |
| Hide dice shells (translucent) | 112.5 | 14.2 |
| Post-processing off | 114.0 | 12.7 |
| Hide logos (emissive, opaque) | 118.5 | 8.2 |
| Bloom off | 119.9 | 6.8 |
| FXAA off | 123.8 | 2.9 |
| Dithering off | 125.0 | 1.7 |
| MSAA ×2 instead of ×4 | 126.7 | 0 |
| Screen-space refraction off | 127.1 | 0 |
| Hide everything | 22.5 | 104.2 |

What it says:

- The cost is per pixel. The tray's floor is one lit, shadowed surface
  over the whole screen, and it alone is two thirds of the frame.
- Shadow filtering is the biggest single setting: DPCF costs 48 ms over
  PCF, and PCF another 22 ms over none.
- The translucent shells and the emissive logos are minor (14 and 8 ms).
- With nothing drawn the pipeline still costs 22.5 ms at full
  resolution, so 60 fps was out of reach before any scene content.
- Light count was not toggled: the dice scene has one directional light
  and an IBL.

Shadow type at render scale 0.5 with MSAA off:

| Shadows | GPU ms | Note |
|---|---|---|
| DPCF | 33.2 | the designed soft look |
| PCF | 22.5 | hard edge |
| PCFd | 22.5 | |
| VSM | 24.6 | hard edge without blur |
| VSM, 256 map, blur 10 | 25.9 | shadows all but vanish |
| VSM, 512 map, blur 20 | 35.9 | |
| VSM, 1024 map, blur 40 | 99.8 | |
| PCF, 256 map | 22.3 | acne stripes on the floor |
| PCSS | 58.0 | |
| off | 18.3 | |

No cheap soft shadow was found; PCF is the only filter that pays.

Physics, dice rolling, main-thread ms per frame for the Jolt step:

| Jolt job system | median | p95 |
|---|---|---|
| Thread pool, 8 workers (before) | 5.1 | 36.0 |
| 4 workers | 7.0 | 33.1 |
| 2 workers | 2.9 | 17.1 |
| 1 worker | 3.0 | 11.2 |
| Single-threaded | 1.1 | 6.9 |

The step rate (120 Hz, up to 4 substeps a frame) was left alone.

Dynamic resolution (`View.DynamicResolutionOptions`, 0.5–1.0) with PCF,
no MSAA, HDR LOW:

| Backend | Frame-rate target | Scale it settled at | Result |
|---|---|---|---|
| OpenGL | 60 | 0.5 (floor) | 22.5 ms GPU, 43 fps |
| OpenGL | 30 | 0.66 | 33.2 ms GPU, steady 33.3 ms frames |
| Vulkan | 60 | 1.0 (never moves) | 50 ms frames, 21 fps |

Fixed scales on Vulkan with the same settings gave 15.3 fps at 1.0,
23.7 at 0.75, 28.0 at 0.67, 31.9 at 0.6 and 35.6 at 0.5.

## Changes

1. **Frame-time log** — the measurement above. No effect unless the log
   tag is set.
2. **Jolt steps on the calling thread.** Rolling physics 5.1 → 1.1 ms
   median and 36 → 6.9 ms p95 on the tablet; 1.3 → 0.6 ms and 6.5 →
   2.5 ms on the A142.
3. **Device profile for low-end Android.** When the app sets no
   `SceneQuality`, a device with under 3.2 GB of memory (or the system's
   low-RAM flag) renders with PCF shadows, FXAA without MSAA, the LOW
   HDR buffer and dynamic resolution between 0.5 and 1.0, and its `auto`
   backend resolves to OpenGL, the one on which dynamic resolution has
   GPU timings. An explicit `quality:` opts out. Everything else keeps
   the previous pipeline. Memory is a proxy for the GPU; see *Open*.

After the change, `perf view` on the tablet's dice screen:

```
backend=OPENGL viewport=1200x1920 msaa=0 aa=FXAA post=true hdr=LOW
bloom=true(levels=7 res=384 q=LOW) ssao=false taa=false ssr=false
dsr=true(0.5..1.0) dither=TEMPORAL quality=default physics=120Hzx4
```

| Screen | fps | frame p50 / p95 / worst | GPU p50 | sim p50 / p95 |
|---|---|---|---|---|
| Hero | 55.3 | 16.6 / 33.3 / 50.0 | 16.5 | 0.2 / 3.7 |
| Dice, racked | 44.2 | 16.7 / 33.3 / 34.1 | 22.5 | 0.3 / 0.5 |
| Dice, rolling | 43.4 | 16.7 / 33.3 / 66.6 | 22.5 | 1.5 / 6.1 |

The harness scene (`DART3D_SCENE=harness`) ran its lanes on the tablet
under the new profile at 42 fps with no FATAL (`tablet-after-harness.jpg`).

## A142 (Nothing A142, 90 Hz)

Smoke on the final build: boot, dice, eight rolls, settle, 0 FATAL.
`perf view` reports the old pipeline (`backend=VULKAN msaa=4 aa=FXAA
hdr=HIGH dsr=false`, DPCF, tier STANDARD). GPU frame times do arrive on
its Vulkan driver.

| Screen | fps | frame p50 | GPU p50 |
|---|---|---|---|
| Hero | 89.0 | 11.1 | 9.6 |
| Dice, racked | 49.6 | 22.2 | 18.5 |
| Dice, rolling | 50.5 | 22.2 | 18.4 |

Screenshots: `a142-hero.jpg`, `a142-dice.jpg`, `a142-roll-settled.jpg`.

## Cold start (for S0h)

Fresh install, tablet, seconds from process start.

| Event | Before (Vulkan) | After (OpenGL) |
|---|---|---|
| Filament engine created | 0.37 | 0.28 |
| Swapchain created | 0.61 | 0.44 |
| Activity displayed (hero copy over an empty stage) | 0.99 | 0.56 |
| `lit OPAQUE` package compiled | 5.83 (5.34 s) | 6.10 (5.76 s) |
| `lit MASKED` compiled | 11.52 (5.69 s) | 12.08 (5.98 s) |
| `lit TRANSPARENT` compiled | 16.08 (4.55 s) | 16.92 (4.84 s) |
| Unlit ×3 and trail compiled | 16.98 (0.90 s) | 17.88 (0.95 s) |
| Base materials ready | 17.05 | 17.90 |
| Scene realized, first frame follows | 17.28 | 18.09 |
| Hero's `lit OPAQUE e1` variant compiled (logo glow shader swaps in) | not captured | 23.58 (5.66 s) |

Three lit packages compiled one after another account for 15.6 of the
17.3 s (16.6 of 18.1 s on OpenGL). Nothing here changes that.

## Open

- **60 fps at rest on the dice screen is not reached** (44 fps). The
  floor of 0.5 scale is a choice; a lower floor or no shadows would buy
  frames at the picture's expense.
- **Hard shadows on the low profile** are a visible departure from the
  designed soft ones.
- **The tier is decided by memory.** A device with 4 GB or more and a
  weak GPU keeps the full pipeline and stays slow. The A142 itself
  spends 18.5 ms of GPU on a dice frame and shows 45–50 fps on its 90 Hz
  panel; dynamic resolution would help it but would change its picture.
- **Vulkan has no GPU frame timing on this tablet**, which is why the low
  profile moves to OpenGL. Not tested on other Mali drivers.
- **Untextured materials still sample five 1×1 fallback textures.** A
  slot-pruned material was not measured; each new variant costs about
  5 s of compile here, which ties it to S0h.
- **The racked dice redraw every vsync** although nothing moves.
- **Single long frames while rolling** (one of 67–83 ms per run) were
  not traced.
- **The frame-info bridge mirrors Filament 1.71.6 struct layouts** and
  must be re-checked when the pin moves.
- A142 on the OpenGL backend and iOS were not run. iOS code is untouched.
