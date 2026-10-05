# Three-device baseline and GPU-aware device tier (2026-10-05)

Release build, `dn run -d <serial> --release` from `dart3d/example`,
branched from `17b2bbf`. "Before" is `17b2bbf` itself; "after" is this
branch. Cold starts are `dart3d/tool/cold_start.sh`, median of 3, ms
since process start. Frame rates are the `dart3d.perf` log: hero 30 s,
dice racked 30 s, dice rolling with the Roll button tapped every 3 s
for 36 s, first 2 s window dropped.

## Result

| Device | GPU | Tier, backend | Cold start, first / later | Hero | Dice racked | Dice rolling |
|---|---|---|---|---|---|---|
| Fire KFTUWI | Mali-G52 MC2 | LOW, OpenGL (unchanged) | 1.25 s / 0.89 s | 55.0 fps | 44.2 fps | 43.7 fps |
| Wacom DTHA116, before | Mali-G57 MC2 | STANDARD, Vulkan | 0.80 s / 0.74 s | 49.3 fps | 13.1 fps | 13.2 fps |
| Wacom DTHA116, after | Mali-G57 MC2 | LOW, OpenGL | 0.83 s / 0.56 s | 57.5 fps | 51.2 fps | 44.1 fps |
| Nothing A142 | Mali-G610 MC4 | STANDARD, Vulkan (unchanged) | 0.57 s / 0.52 s | 89.7 fps | 49.7 fps | 50.3 fps |

- **S0h closes on the Fire tablet.** First launch 18.1 s → 1.25 s, later
  launches 18.1 s → 0.89 s. The targets were under 3 s and under 1.5 s.
- **The Wacom was slow on the standard tier**, as its GPU predicted:
  13 fps on the dice screen with 8 GB of memory. The tier is now chosen
  from the GPU's name first, and the tablet runs the dice at 44–51 fps.
- **The A142 and the Fire tablet resolve as before** and measure the
  same within run-to-run noise.

## Fire tablet KFTUWI

Android 11, MT8169, Mali-G52 MC2 (driver r26p0), 2.9 GB, 1200×1920,
60 Hz, portrait. `GPU: Mali-G52 MC2`, `Filament engine backend: OPENGL
(pref=0, tier=LOW)`, `perf view: backend=OPENGL msaa=0 aa=FXAA hdr=LOW
dsr=true(0.5..1.0)`.

Cold start:

| Event | Before S0h (S0j run) | `17b2bbf`, first | `17b2bbf`, later | After, first | After, later |
|---|---|---|---|---|---|
| Engine created | 280 | 218 | 212 | 218 | 210 |
| Base materials loaded | 17900 | 237 | 233 | 237 | 229 |
| Scene installed | | 396 | 386 | 393 | 392 |
| First frame submitted | | 712 | 511 | 703 | 526 |
| First frame rendered | 18090 | 1277 | 894 | 1248 | 893 |

Individual first launches: 1351, 1233, 1277 ms on `17b2bbf`. About
0.55 s of a first launch falls between submitting the first frame and
the driver finishing it; on later launches the driver's shader cache
brings that to 0.37 s.

Frame rate:

| Screen | S0j (2026-10-02) | `17b2bbf` | After | Frame p50 / p95 / worst | GPU p50 |
|---|---|---|---|---|---|
| Hero | 55.3 | 55.6 | 55.0 | 16.6 / 33.3 / 50.0 | 16.7 |
| Dice, racked | 44.2 | 44.6 | 44.2 | 16.7 / 33.3 / 33.9 | 22.5 |
| Dice, rolling | 43.4 | 43.5 | 43.7 | 16.7 / 33.3 / 66.6 | 22.5 |

The frame columns are the "after" run. Slowest 2 s window while
rolling: 42.7 fps. On `17b2bbf` one rolling frame took 100 ms.

Smoke: boot, hero, dice, 12 rolls settle, 0 FATAL. `fire-hero.jpg`,
`fire-dice.jpg`, `fire-settled.jpg`.

## Wacom DTHA116 ("RosePlus")

Android 14, MT8781 (`ro.soc.model` MT8781V/NA), Mali-G57 MC2 (driver
r32p1), 8 GB (7.7 GB reported), 1440×2200, 60 Hz. First dart3d run on
this device.

Before, `17b2bbf`: `Filament engine backend: VULKAN (pref=0,
tier=STANDARD)`, MSAA ×4, DPCF shadows, HDR HIGH, full resolution.
After: `GPU: Mali-G57 MC2`, `Filament engine backend: OPENGL (pref=0,
tier=LOW)`, `perf view: backend=OPENGL msaa=0 aa=FXAA hdr=LOW
dsr=true(0.5..1.0)`.

Cold start:

| Event | Before, first | Before, later | After, first | After, later |
|---|---|---|---|---|
| Engine created | 213 | 190 | 229 | 201 |
| Base materials loaded | 240 | 215 | 249 | 219 |
| Scene installed | 396 | 353 | 404 | 357 |
| First frame submitted | 543 | 476 | 577 | 466 |
| First frame rendered | 802 | 742 | 825 | 559 |

Frame rate:

| Screen | Before (STANDARD, Vulkan) | After (LOW, OpenGL) | LOW pipeline on forced Vulkan |
|---|---|---|---|
| Hero | 49.3 fps, GPU 19.9 ms | 57.5 fps, GPU 11.5 ms | 59.5 fps, GPU 10.4 ms |
| Dice, racked | 13.1 fps, GPU 75.4 ms | 51.2 fps, GPU 19.0 ms | 55.3 fps, GPU 17.3 ms |
| Dice, rolling | 13.2 fps, GPU 75.6 ms | 44.1 fps, GPU 23.1 ms | 57.0 fps, GPU 17.0 ms |

"Before" frames arrive every 83.7 ms (five vsyncs). "After", frames
alternate between one and two vsyncs (p50 16.7, p95 33.5, worst
33.6 ms); the slowest 2 s window while rolling was 40.8 fps. The
"before" column was measured in portrait and the other two in
landscape; the pixel count is the same. A portrait run of the "after"
build gave 57.9, 52.1 and 47.4 fps.

The last column is `--dart-define=DART3D_BACKEND=vulkan` on the "after"
build: the backend pref still overrides the tier's OpenGL choice, the
log reads `VULKAN (pref=2, tier=LOW)`, and GPU frame times do arrive on
this driver, so dynamic resolution works there too. Vulkan is the
faster backend for the low pipeline on this tablet. See *Open*.

Smoke on the "after" build: boot, hero, dice, 12 rolls and a settle in
portrait, rotation to landscape with the tray re-laid out, 8 more rolls
and a settle, 0 FATAL. The picture changes as it did on the Fire tablet: hard-edged
shadows and a softer 3D layer; numerals stay readable.
`wacom-before-dice.jpg`, `wacom-before-settled.jpg` (portrait),
`wacom-after-hero.jpg`, `wacom-after-dice.jpg`,
`wacom-after-settled.jpg` (landscape).

Seen on this device, not looked into: in portrait the two settled
rolls that were captured, one per build, ended with the dice heaped in
one corner and one die resting on another
(`wacom-before-settled.jpg`). The landscape ones spread out.

## Nothing A142

Android 16, MT6886, Mali-G610 MC4 (driver r38p1), 7.6 GB reported,
1084×2412, 90 Hz. `GPU: Mali-G610 MC4`, `Filament engine backend:
VULKAN (pref=0, tier=STANDARD)`, `perf view: backend=VULKAN hdr=HIGH
dsr=false` on both builds.

| | Before | After |
|---|---|---|
| Cold start, first: engine / materials / first frame | 182 / 200 / 580 | 184 / 202 / 572 |
| Cold start, later | 173 / 190 / 516 | 176 / 192 / 516 |
| Hero | 89.6 fps, GPU 10.1 ms | 89.7 fps, GPU 10.1 ms |
| Dice, racked | 50.5 fps, GPU 18.3 ms | 49.7 fps, GPU 18.4 ms |
| Dice, rolling | 50.4 fps, GPU 18.4 ms | 50.3 fps, GPU 18.4 ms |

Smoke: boot, hero, dice, 12 rolls settle, 0 FATAL. The racked dice
screenshot before against after: 35.2 dB PSNR below the status bar
(on the 1280 px JPEGs), which is what two launches of one build gave in
S0h (35.7–38.7 dB). `a142-hero.jpg`, `a142-dice.jpg`,
`a142-settled.jpg`.

## The tier rule

Before, the tier was memory alone: under 3.2 GB, or the system's
low-RAM flag, is LOW. Through the standard pipeline a dice frame costs:

| Device | GPU | Memory | Pixels | GPU ms | Tier wanted |
|---|---|---|---|---|---|
| Fire KFTUWI | Mali-G52 MC2 | 2.9 GB | 2.30 M | 125 | LOW |
| Wacom DTHA116 | Mali-G57 MC2 | 7.7 GB | 3.17 M | 75 | LOW |
| Nothing A142 | Mali-G610 MC4 | 7.6 GB | 2.61 M | 18 | STANDARD |

Memory cannot separate the Wacom from the A142. The GPU's name can, so
`DeviceTier.classify` now takes it as a third input:

1. the low-RAM flag → LOW;
2. under 3.2 GB → LOW;
3. the GPU is in `DeviceTier.FILL_BOUND_GPUS` → LOW;
4. otherwise STANDARD.

The table is four patterns over the `GL_RENDERER` string: Mali-4xx and
Mali-T, Mali-G31/G51/G52/G57, Adreno 3xx/4xx/50x/51x/61x, and PowerVR
Rogue GE8xxx. **Only Mali-G52 and Mali-G57 are measured.** The others
are listed by market class, at or below those two. A three-digit model
(Mali-G310, G510, G610) does not match its two-digit prefix, and a GPU
the table does not name is decided by memory, as before.

**Where the name comes from.** The backend is chosen before the
Filament engine is built, and the engine is what would otherwise name
the GPU. `GpuProbe` asks the GL driver directly: a 1×1 pbuffer EGL
context, `glGetString(GL_RENDERER)`, context destroyed, once per
process. The string names the GPU whichever backend the engine then
uses. In the logs the `GPU:` line follows `plugin registered` by
12–17 ms on the Wacom and the A142, which bounds the probe's cost; the
"engine created" medians moved by 0–16 ms. `Build.SOC_MODEL` was not
used: it needs API 31 (the Fire tablet is API 30) and a table from SoC
to GPU.

**What it does not consider.**

- Screen size. A weak GPU on a small panel may manage the standard
  pipeline. Filed LOW it loses MSAA, soft shadows and the large HDR
  buffer, but keeps full resolution, because the scale only drops while
  frames run long.
- Core count. Mali-G57 MC4 and MC5 file as LOW with the MC2.
- A calibration run was not built. It would have to change the picture
  after the first frames or store a verdict on disk, and three devices
  are separated by the name alone.

`quality:` and the backend pref override as before (`DeviceProfile` is
unchanged; the forced-Vulkan column above is the backend pref on a LOW
device).

## Also changed

`tool/cold_start.sh` launched the app with `monkey -p`. Monkey switches
auto-rotate on when it exits: on the Wacom, which its owner keeps
locked in landscape (`accelerometer_rotation=0`, `user_rotation=1`),
one monkey launch left `accelerometer_rotation=1`. The script now
resolves the launcher activity and uses `am start`, after which the
setting stayed put. The lock was restored with `wm user-rotation lock
1` and the settings read back as found. `tool/bake_materials.sh` still
uses monkey; it was not run here.

## Checks

- `dn analyze` and `dn test` in `dart3d` (277 tests) and
  `dart3d/example` (227 tests): clean.
- `:dart3d:testReleaseUnitTest`: passes. `DeviceTierTest` has a case
  for each device's real renderer string and memory size, the listed
  families, the three-digit Mali models and the fall back to memory.
- `GpuProbe` itself is covered on the three devices only (the `GPU:`
  log lines above); it has no JVM test.

## Open

- **LOW always takes OpenGL**, because Vulkan gives no GPU frame times
  on the Fire tablet's r26 driver. On the Wacom's r32 driver it does,
  and Vulkan runs the low pipeline 8 % faster racked and 29 % faster
  rolling. Telling the two apart before the engine exists would take a
  driver-version rule resting on two data points; not done.
- **The table's unmeasured rows** (Adreno, PowerVR, older Mali) rest on
  market class.
- **60 fps at rest on the dice screen is still not reached** on either
  tablet (44 and 51 fps, GPU 22.5 and 19.0 ms a frame).
- **The A142 spends 18.4 ms of GPU on a dice frame** and shows 50 fps
  on its 90 Hz panel. Unchanged; it stays on the standard pipeline.
- **`bake_materials.sh` launches with monkey** and will unlock a
  rotation-locked device.
- **Dice heaping in a corner on the Wacom in portrait**, above.
- The harness scene (`DART3D_SCENE=harness`) was not run on the Wacom,
  and forced OpenGL was not re-run on the A142.
