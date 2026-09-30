# P3 DartNative dice set — device evidence (A142)

Device: Nothing A142 (`00064149A002033`, Android 16, Mali-G610, Filament
Vulkan), 1084×2412 px = 413×919 logical. Launch:
`dn run -d 00064149A002033 --release --dart-define=DART3D_SCENE=dice`
from `dart3d/example`. Input via `adb shell input` (≥100 px from the
edges, foreground package checked first). `rack.png` / `roll*.png` are
900 px tall (256 colours); `rack_1to1.png` is an unscaled crop (device
pixels) of the racked set.

iOS: the Swift natives are unchanged; the Dart is shared and
analyzer-clean. **iOS device verification is pending** (A142 only for
this run).

## The set

- Procedural dice from the look-dev geometry (d4 crystal shard, d6, d8,
  d10 ×2, d12, d20), bevelled, numbered like the look-dev (opposite
  faces sum to n+1), numerals from Inter Regular outlines at the
  look-dev size (≈0.41 of the face's inscribed width).
- Shell: smoky frosted glass (alpha-blended, rough, no clear coat) —
  more frost per the operator; the P4 logo inside each die, held level
  as a soft, dim glow; near-white numerals in thin dark keylines on a
  denser-frost band, so they dominate.
- Size: the d20 is 21% of the short side (was 15%).
- Tray: deep-indigo felt (#23264A) with the DartNative gradient rim.

## Readability (on device)

- `rack.png`, `rack_1to1.png`: racked highest-number-up, upright. Every
  numeral sits fully inside its face, crisp: d10 "90" and "9.", d12
  "12", d20 "20" (the d10 veil in earlier builds was the shell's far
  side showing through — see below).
- `roll1–3.png`: three rolls; every top numeral reads at phone size.

```
roll throw — strength 0.62 … cocked d6/d10t/d12/d20 → nudge #1
d4 turns -7° to read upright
settled — d4=3 … d20=3 [4 nudges]   readout … = 115
settled — (re-read after the d4 turn, same faces)   readout … = 115
aim throw — strength 0.59 …  d4 turns -8° …  readout … = 98 (re-read: 98)
roll throw — strength 0.81 …  d4 turns -157° …  readout … = 65 (re-read: 65)
```

DR2's merged behaviour on this build: the d4 turns only once flat after
a real settle, and the dice are re-read afterwards with the same result.

## Findings

- **Back faces on blended materials (Android).** `setDoubleSided(false)`
  left the blended variants unculled on the A142: the far side of each
  translucent die (numerals, bevels) was drawn over its top face.
  Fixed in `FsceneRealizer.kt` by setting `CullingMode.BACK` explicitly
  for single-sided materials.
- **Point lights hang the GPU here.** Two small unshadowed point lights
  over the tray made every frame take ~60 s (Vulkan fence timeout,
  `fps=0.02`); without them the scene runs at ~50 fps. Not used.
- **No refraction.** The frost is alpha-blended smoke on both natives
  (SceneKit has none; one path keeps the platforms alike), so the logo
  reads dim and sharp rather than frost-blurred. Filament screen-space
  transmission is the upgrade path on Android.
- **Cold start.** The dice build (atlases + meshes, ~0.5 s on a Mac)
  runs off the UI isolate and overlaps the view's first-launch material
  compile (~10 s of base Filament packages, pre-existing).

## Checks

- `dn analyze` (dart3d/example): clean.
- `dn test` (dart3d/example): all pass — new `dice_polyhedra_test.dart`
  (faces, values, opposite sums, convexity, numeral frames, labels);
  `dice_readout_test.dart` rewritten for the procedural set (every face
  up reads its value; face-map normals are flat faces of the drawn
  mesh, wound outward); `dice_table_test.dart` (seven dice, one shared
  logo mesh held level, racked highest-up).
