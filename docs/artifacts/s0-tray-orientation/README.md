# Dice tray follows the screen's orientation (2026-10-01)

Build: `dn run -d <serial> --release` from `dart3d/example`.
Devices: Amazon Fire KFTUWI (Android 11, 1280×800 logical, landscape
by default) and Nothing A142 (413×919 logical, portrait by default).
Rotation forced with `settings put system user_rotation`; both devices'
original settings were restored afterwards.

## Root cause

`loadScene` realizes the manifest, then each payload chunk arms a full
re-realize from that manifest. The screen's first tray fit — one
`setTransforms` for the camera, four walls, ceiling and eight rim
pieces — is sent right behind `loadDocument`, so it drains in the same
frame as the chunks and *before* the rebuild, which put every node back
at its build-time pose (a 412×915 portrait guess). The walls looked
right only because every roll rewrites them when it closes its gates.

Log, Fire tablet, with the fix (the count is the writes the rebuild
used to drop):

```
dart3d: dice tray fit 1280x800 insets EdgeInsets(l:34.0, t:80.0, r:184.0, b:82.0) → 8.72 px/u, camera 145, play x -68.6..51.4 z -35.6..35.8
I dart3d  : realize: 51ms
I dart3d  : realize: 156ms
I dart3d  : re-realize: restored 14 written transform(s)
```

The baseline screenshot agrees with a stale camera too: the build-time
camera (height 323) on an 800 px tall view gives 3.93 px/unit, and the
build-time rim (91.7 × 155.7 units) then measures 360 × 612 px — the
366 × 616 px rim in `../s0-fire-tablet-baseline/dice.png`. The dice
were drawn at 45 % of their intended size.

## After

| File | What |
|---|---|
| `tablet-landscape-rack.jpg`, `tablet-landscape-roll.jpg` | Fire tablet, cold start in landscape |
| `tablet-portrait-after-rotate.jpg`, `tablet-portrait-rack.jpg`, `tablet-portrait-roll.jpg` | Fire tablet rotated to portrait: refit, Reset, roll |
| `tablet-landscape-after-rotate.jpg` | Fire tablet rotated back |
| `phone-portrait-rack.jpg`, `phone-portrait-roll.jpg` | A142, cold start in portrait |
| `phone-landscape-after-rotate.jpg`, `phone-landscape-roll.jpg` | A142 rotated to landscape: refit, roll |
| `phone-portrait-after-rotate.jpg` | A142 rotated back |

Fit lines on rotation: tablet `800x1280 … camera 233, play x -43.8..43.8
z -54.4..63.3`; phone `871x413 … camera 145, play x -88.3..54.9
z -32.1..27.2`.

d20 size: 21 % of the view's short side by design
(`kD20ScreenFraction`); measured about 230 of 1200 px on the tablet
(19 %) — before the fix it was about 9 %.

## Rotation re-read

Dice pulled inside by a refit can land against a neighbour and tumble
to another face. When a result is on screen the table now re-arms the
settle and reads every die again. Fire tablet, rotating back to
landscape after a portrait roll (`tablet-landscape-after-rotate.jpg`):

```
dart3d: dice readout d4 2 · d6 5 · d8 8 · d12 3 · d20 8 · d% 70+4 = 100
dart3d: dice tray fit 1280x800 … play x -68.6..51.4 z -35.6..35.8
dart3d: dice refit moved 5 — reading again
dart3d: dice readout d4 2 · d6 5 · d8 8 · d12 3 · d20 20 · d% 70+4 = 112
```

## Notes

- Screenshots are JPEG, downscaled to 1280 px on the long side.
- The tablet shots except `tablet-portrait-rack.jpg` and the rotation
  re-read log are from the final build (Filament backend: Vulkan); the phone
  shots and `tablet-portrait-rack.jpg` are from the first build of this
  branch, before the rotation re-read was added
  (`phone-portrait-after-rotate.jpg` shows the stale readout it fixes).
- iOS carries the same native fix (`SceneViewHost.swift`); it
  type-checks against the iOS 27 simulator SDK but was not run on a
  device.
