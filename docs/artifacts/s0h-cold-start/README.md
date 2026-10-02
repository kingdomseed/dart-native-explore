# S0h Android cold start (2026-10-02)

Time from process start to the hero's first rendered frame, release
build, `dn run -d <serial> --release` from `dart3d/example`, branched
from `0081d1c`.

## Result

| Device, backend | Launch | Before | After |
|---|---|---|---|
| A142, Vulkan | first after install | 11.15 s | 0.57 s |
| A142, Vulkan | later launches | 11.18 s | 0.57 s |
| A142, Vulkan | hero's clear-coat variant appears | 14.1 s | on the first frame |
| A142, forced OpenGL | first after install | not measured | 0.53 s |
| A142, forced OpenGL | later launches | not measured | 0.34 s |
| Fire tablet, OpenGL | first after install | 18.1 s (from S0j) | **not measured** |
| Fire tablet, OpenGL | later launches | 18.1 s (from S0j) | **not measured** |

Medians of 3 launches. "First after install" is a launch after
`pm clear`, which empties the app's data and code cache. A launch
straight after `adb install` took 11.40–11.82 s before (3 runs) and
0.73–0.74 s after (2 runs); the extra 0.17 s falls before the engine
is created.

**The Fire tablet was not measured.** Prime Video was in the foreground
from 15:01 to 15:45, every time it was checked. The power service
reported the last touch 2.5 hours earlier and the screen held on by
"stay awake while charging", so it was probably idle, but the rule is
not to launch over another app. The targets (under 3 s on first launch,
under 1.5 s later) are therefore unverified on the tablet. What is
known: in the S0j timeline 16.6 of its 18.1 s were the three lit
compiles this change removes, and the OpenGL packages it would load are
the ones the A142 loaded in the forced-OpenGL rows above. To finish it,
with the tablet on its home screen:

```
cd dart3d/example && dn run -d GN434J02409203LD --release   # then q
../tool/cold_start.sh GN434J02409203LD --fresh
../tool/cold_start.sh GN434J02409203LD
```

## Root cause

The time is filamat's optimizer. Each lit package is compiled on the
device at `Optimization.PERFORMANCE`, which runs the SPIR-V optimizer
over every shader variant. One temporary build read the optimization
level from a system property; A142, Vulkan, seconds per package:

| filamat optimization | lit MASKED | lit TRANSPARENT | First frame |
|---|---|---|---|
| PERFORMANCE (what ships) | 3.33 | 2.72 | 11.15 s |
| SIZE | 3.39 | 2.85 | 11.38 s |
| PREPROCESSOR | 0.53 | 0.43 | 2.82 s |
| NONE | 0.36 | 0.31 | 2.16 s |

Parsing, GLSL to SPIR-V and writing the package are a tenth of the
cost. It is not the driver either: with the packages in hand, the whole
first frame (pipeline or program creation included) takes 0.15–0.23 s.
The three lit packages were also compiled one after another, and a
fourth (the hero's clear-coat variant) after the first frame.

Lower optimization was not taken as the fix: it ships different shader
code, so it could change both the picture and the frame rate, and it
still leaves 1–2 s of compiling on every first launch.

## What changed

1. **Timeline log** (`ColdStart.kt`). `adb logcat -s dart3d | grep
   'start +'` gives ms since process start for each milestone.
   `tool/cold_start.sh` runs N launches and prints the medians.
2. **Packages are looked up before they are compiled**
   (`MaterialRecipe`, `MaterialStore`, `MaterialPackages`). A package is
   named by a hash of its filamat builder calls and the Filament
   version. It is looked up in memory, then in the APK's assets, then in
   a cache in the app's code-cache directory, and compiled only when all
   three miss; the compile writes the cache. Android empties that
   directory on every app update, and the hash covers the shader source
   and the Filament pin (`filamentVersion` in `android/build.gradle`),
   so a stale package cannot be loaded.
3. **The plugin ships its fixed set**: 20 packages (lit and unlit in
   three blend modes, trail, shadow catcher, two particle blends, for
   OpenGL and Vulkan). `tool/bake_materials.sh` builds them on a device
   with the same filamat the runtime uses.
4. **The example ships the hero's variant.** Lit variants depend on the
   document (extension flags × bound textures), so the set is
   open-ended and cannot ship with the plugin. An app can bake the ones
   it uses into its own assets; the same script collects them.

The runtime compiler stays as the fallback for a variant nobody baked.
That path is unchanged: it compiles in the background, the base
material shows meanwhile, and the result is cached for later launches.

## Timelines

A142, Vulkan, median of 3, ms since process start.

| Event | Before, first | Before, later | After, first | After, later |
|---|---|---|---|---|
| Engine created | 192 | 170 | 170 | 170 |
| Base materials loaded | 10317 | 10207 | 187 | 187 |
| Scene installed | 10500 | 10411 | 320 | 322 |
| First frame rendered | 11145 | 11175 | 567 | 571 |
| Clear-coat variant compiled | 14131 | 13936 | not compiled | not compiled |

A142, forced OpenGL (`--dart-define=DART3D_BACKEND=opengl`), after:

| Event | First | Later |
|---|---|---|
| Engine created | 168 | 169 |
| Base materials loaded | 182 | 183 |
| Scene installed | 230 | 228 |
| First frame submitted | 351 | 295 |
| First frame rendered | 527 | 335 |

The intermediate commit with the cache but no shipped packages: first
launch 11.50 s (it still compiles, one run), second launch 0.57 s.

## Size

| | Raw | In the APK |
|---|---|---|
| Plugin: 20 fixed packages | 2.16 MB | 0.79 MB |
| Example: hero variant, both backends | 0.67 MB | 0.25 MB |

The example's release APK went from 106,986,037 to 108,031,206 bytes
(+1.0 MB). filamat itself (8.9 MB per ABI) still ships, for the
fallback.

## Rendering is unchanged

The shipped packages are the bytes the runtime compiler produces. A
second bake, run after the packages were committed, reproduced all 22
files byte for byte (the working tree stayed clean), and the sizes
match the baseline's compile log (for example 474,499 B for lit OPAQUE
on Vulkan).

Screenshots, A142: `a142-before-hero.jpg`, `a142-after-hero.jpg` (the
logo spins, so the angle differs), `a142-before-dice.jpg`,
`a142-after-dice.jpg`. The racked dice screen is static apart from
dithering and where the dice come to rest. PSNR below the status bar:
two screenshots within one baseline launch 52.1 dB; two baseline
launches 38.7 dB; this branch against those two baseline launches 38.7
and 35.7 dB. So the branch differs from the baseline about as much as
the baseline differs from itself between launches.

## Frame rate

A142, dice racked, `dart3d.perf` log: 49.9 fps (GPU 18.4 ms) before,
52.4 fps (GPU 18.0 ms) after. The tablet's dice screen (44 fps in S0j)
was not re-measured, for the reason above.

## Checks

- `dn analyze` and `dn test` in `dart3d` (277 tests) and
  `dart3d/example` (227 tests): clean.
- `:dart3d:testReleaseUnitTest`: passes, with 22 new tests.
  `MaterialPackagesTest` covers the package sets, keys and
  fingerprints; `MaterialStoreTest` the cache (round trip, damaged and
  truncated files, eviction, export); `ShippedMaterialsTest` that the
  assets are exactly the fixed set for the current recipes and Filament
  pin.

## Open

- **Tablet numbers**, cold start and dice frame rate.
- **A variant nobody baked still takes 4–6 s on its first launch**,
  with the base material shown until it lands. PREPROCESSOR-level
  compiles (0.5 s) would shorten that at the cost of different shader
  code; not done.
- **Driver-side program creation is not warmed up.** The first frame
  spends 0.15–0.23 s in the driver. On OpenGL the driver's own shader
  cache already brings that to 0.04 s on later launches.
  `Material.compile` was not adopted: on Vulkan it only creates shader
  modules, and on OpenGL it was not measured on the tablet.
- **Opening the dice screen blocks the main thread once for about
  0.57 s** (`slow frame 565ms on main: ops=47 realize=true`). That is
  scene decoding, not materials, and was there before.
- **Baking needs a device.** `matc` from the Filament release would
  allow a host or CI bake; it was not used because it would have to be
  downloaded, and its output would have to be shown equal to filamat's.
- **Shipped packages live in git** (2.8 MB per bake that changes them).
