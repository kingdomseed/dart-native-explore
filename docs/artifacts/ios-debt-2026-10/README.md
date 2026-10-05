# iOS verification debt — 2026-10-05

Nothing had run on iOS since about 2026-09-29. This is the run that
pays that debt on the one simulator the operator re-enabled.

- **Device:** iPhone 17 Pro simulator
  `C24F3C6D-A3A9-4FB7-978E-36E67EF55354`, iOS 27.0, 402×874 pt.
- **Launch:** `dn run -d <udid>` from `dart3d/example`, **debug** (the
  only mode `dn run` builds for the simulator), with
  `--dart-define=DART3D_SCENE=dice|harness|showcase` where noted.
- **Input:** the session's iOS-simulator tool (taps and timed touch
  paths). No finger touched it.
- **Rotation:** the app's window scene was asked for landscape through
  `lldb`. A later attempt to rotate back was refused by the session's
  permission system, so landscape → portrait did not run.
- **Not a physical device:** no frame-rate claim beyond the HUD's
  60 fps, and TAA is skipped on the simulator by design.

## Runs

| Run | Tree | What ran |
|---|---|---|
| `main-default` | main `63fe903` | hero → "Roll the dice", 2 Roll rolls, aim throw, hold-and-toss, sweep |
| `fix4-dice` | `32ab307` | 10 rolls (6 Roll, 2 aim, 1 toss, 1 sweep), Reset, rotation to landscape, a landscape roll |
| `fix5-dice` | `19a3eff` | rack, a roll, hold-and-toss, Reset |
| `pr55-dice` | `19a3eff` + #55 (`aa51de0`) | rack, 10 rolls (8 Roll, 1 aim, 1 toss), rotation to landscape |
| `head-harness` | `19a3eff` | the harness to its last lane |
| `base-harness` | `19a3eff` with main's `dart3d/ios/Classes` | the same, as the baseline for the native changes |
| `head-showcase` | `19a3eff` | Showcase (materials, glb, playground, cube, prefabs, triangles, fcar, dash) → Back → hero → dice, 2 rolls |

`32ab307` is main plus the isolate fix and the shadow range and
samples; `19a3eff` adds the blended shadow casters. The code on this
branch after `19a3eff` is docs and evidence only.

Per run under `logs/`: `<run>.app.log` (the app's `dart3d:` lines),
`<run>.native.log` (the plugin's and SceneKit's lines, without the
per-tick ones), `<run>.positions.txt` (die positions at the first and
last physics tick), and for two runs `<run>.speeds.txt`.

## T2

| Check | Result | Evidence |
|---|---|---|
| main builds and boots | pass | `main-default`, first build |
| Hero: logo orbits, glow | pass | `main-hero-1.jpg`; `head-hero-a.jpg` and `-b.jpg` are 3 s apart |
| Dice screen, rolls settle and read | pass | tables below |
| Showcase | pass | `showcase-materials.jpg` (matches `../w22-review-materials-row.png`), `showcase-fcar.jpg`, `showcase-dash.jpg`, `showcase-next1.jpg` (glb), `showcase-prev1.jpg` (playground); 60 fps on the HUD in each |
| Harness to completion | pass | `logs/head-harness.app.log`: every lane through `w18 lane complete`; `w25 … dice regression PASS`, wLoose 3 of 3 PASS, w11 2 of 2 PASS |
| No crash or error lines | pass, with the lines below | |

Log scan (`fatal`, `crash`, `exception`, `sigabrt`, `sigsegv`,
`lost connection`, "rendering callback", "background thread"): **0** in
every run's `dn` output and native log.

Three SceneKit or CoreAnimation lines appear, in the harness only:

| Line | `head-harness` | `base-harness` |
|---|---|---|
| `SceneKit] Error: can not render without programs, using default` (W16) | 1 | 1 |
| `SceneKit] Assertion 'technique' failed. Null argument` (W25) | 1 | 1 |
| `coreanimation … deleted thread with uncommitted CATransaction` (W16) | 1 | 0 |

The first two are on main as well. The third appeared once, in one of
two harness runs; it did not appear in the dice or Showcase runs that
use the same new code every frame. Not explained.

## Dice lanes

| Lane | Result | Notes |
|---|---|---|
| (a) readout = the face shown | pass | 10 rolls on `32ab307`, 70 of 70 dice (`h-roll01`–`h-roll10`); 5 of 5 rolls on main; 2 of 2 on `19a3eff` (`head-roll01`, `-02`). Both d10s and the d4 checked in each |
| (b) d4 turns upright, result read again | pass | every roll logs `d4 turns N°` and a second readout with the same faces. After a rotation refit the d4 is not turned again (one turn per roll) |
| (c) cocked die nudged flat | pass | unprovoked: d12 `up 0.853` → flat; d6 `up 0.770` → flat (`h-roll03`); d12 three nudges → flat (`h-roll07-aim`); d6 three nudges (`fix5-dice`) |
| (d) gestures | pass, scripted | aim (`h-aim-arrow.jpg`), hold and fling (`h-hold-lifted.jpg`, `p-hold-lifted.jpg`), sweep (`h-roll09-sweep.jpg`). The fling velocity is the app's own estimate (`tracked`), never the platform's |
| (e) numerals | pass | inside the inlay line on every die, no shadow band, a dot by the 6 and none by the 9, near-white on the frost, readable from the top-down camera |
| (f) culling parity | pass | no far-side faces or numerals through the shells in any shot |
| (g) tray | pass one way | the rim sits on the walls; portrait → landscape refits, pulls 6 dice inside and reads again (`h-landscape-after-rotate.jpg`), and a landscape roll reads correctly (`h-landscape-roll.jpg`). **Landscape → portrait: not run** — it needs the operator to rotate the simulator, or a permitted rotation method |
| (h) logo | pass | centred and dim in every die |
| (i) re-realize ordering | pass | every dice load logs `re-realize: restored 28 written transform(s)`, and the first physics tick is at the fitted rack: rows at z 24.2 / −3.0 / −30.3, centre 3.0, the fitted play area's centre (the build-time layout's is 2.67) |

Readouts, `fix4-dice` (each matches its screenshot):

| Shot | Throw | Readout |
|---|---|---|
| `h-roll01` | Roll | d4 4 · d6 4 · d8 2 · d12 1 · d20 20 · d% 30+4 = 65 |
| `h-roll02` | Roll | d4 4 · d6 5 · d8 6 · d12 11 · d20 18 · d% 50+1 = 95 |
| `h-roll03` | Roll | d4 1 · d6 2 · d8 8 · d12 3 · d20 14 · d% 30+6 = 64 (d6 nudged) |
| `h-roll04` | Roll | d4 3 · d6 2 · d8 8 · d12 6 · d20 17 · d% 20+8 = 64 |
| `h-roll05` | Roll | d4 1 · d6 3 · d8 8 · d12 2 · d20 15 · d% 20+1 = 50 |
| `h-roll06` | Roll | d4 2 · d6 6 · d8 5 · d12 4 · d20 7 · d% 70+5 = 99 |
| `h-roll07-aim` | aim | d4 4 · d6 1 · d8 2 · d12 3 · d20 10 · d% 70+1 = 91 (d12 nudged ×3) |
| `h-roll08-toss` | hold and fling | d4 3 · d6 4 · d8 4 · d12 10 · d20 7 · d% 40+3 = 71 |
| `h-roll09-sweep` | sweep | d4 4 · d6 4 · d8 2 · d12 7 · d20 9 · d% 20+7 = 53 |
| `h-roll10` | Reset, Roll | d4 4 · d6 2 · d8 8 · d12 6 · d20 9 · d% 30+7 = 66 |

A 00 + 0 roll read as 100 (`main-default`, total 139).

## Defects found and fixed

1. **The dice table was built on the UI isolate** (`507fe75`). The
   `Isolate.run` closure sat inside the screen's state and carried it
   along; the spawn threw (`background build failed … object is
   unsendable`) and the build fell back inline. Now a top-level
   function, with a test.
2. **No shadows on the dice table** (`32ab307`). SceneKit stops drawing
   shadows 100 units from the camera (the table's camera is 316 away)
   and takes one shadow sample per fragment on iOS. The range is
   lifted and a shadow-casting light takes 16 samples.
3. **Blended meshes cast no shadow** (`19a3eff`). A blend material
   leaves depth writes off and SceneKit's shadow pass is a depth pass.
   With fix 2 alone each translucent die had no shadow and the opaque
   logo inside it cast a logo-shaped one. Each blended mesh now has a
   depth-only stand-in for the shadow pass.
   `pair-shadows-before-after.jpg`: held dice before (logo shadows) and
   after.

How fix 3 was checked beyond the dice: the harness reaches the same
end frame as the baseline (`head-harness-end.jpg`,
`base-harness-end.jpg`: 60 fps and 302 draws in both); the blended
sphere and panels on Showcase's materials row still show what is
behind them; fcar's glass still shows its interior; no doubled
shadows or z-fighting seen. Not covered: a skinned or morphed blended
mesh (left out of the fix), and any frame-time cost below what a
60 fps HUD on a simulator shows.

## #55 (`s0g-ios-dynamic-body-reseat`)

The same scenario with (`pr55-dice`) and without (`fix4-dice`,
`fix5-dice`): load with the dice placed, rolls, an aim throw, a
hold-and-toss, a rotation refit.

| | Without #55 | With #55 |
|---|---|---|
| Restore on load | `restored 28 written transform(s)` | the same |
| Dice at the first tick after the restore | at the fitted rack, within 0.15 units (`fix5-dice.positions.txt`) | at the fitted rack, within 0.01 |
| Rack once asleep | d4 −26.84, d10u 0.51, d20 0.24 … | −26.83, 0.50, 0.24 … (the same settle) |
| Snap back to the manifest pose | not seen | not seen |
| Rolls that settled and read | 10 of 10 | 10 of 10 |
| Peak speed per unit of throw strength, 8 and 9 throws | 641–710, mean 681 | 583–716, mean 658 |
| Toss commanded at 15.9 u/s (341 units/s): peak median speed | 319 | 339 |
| Dice while held | follow the finger, about 2 units/s of drift | the same |
| Rotation refit | moved 6, read again | moved 7, read again |

Speeds are from consecutive physics-tick positions
(`logs/*.speeds.txt`); the throws use the app's random spread, so the
ranges overlap rather than match.

**Verdict: merge.** It behaves the same as main in every case run, the
throw still flies at the same speed, and the restore works. The
snap-back Codex described is not observable on main here — but that is
one simulator on one OS, and Apple documents `resetTransform()` as
required after moving a node with a body, so #55 replaces behaviour
that happens to work with the documented call. Limits of this verdict:
readouts under #55 were checked from the log and one screenshot
(`pr55-roll06-toss.jpg`), landscape → portrait did not run, and #55 was
applied on top of this branch (it merges cleanly) rather than on main
alone.

## Appearance differences (not defects; for the S0g light-unit work)

| | iOS (SceneKit) | Android (Filament) | Pair |
|---|---|---|---|
| Felt | neutral dark grey | deep indigo | `pair-rack-ios-android.jpg`, `pair-roll-ios-android.jpg` |
| Rim gradient | pale yellow → pale pink | saturated lime → pink | the same pairs; landscape in `pair-landscape-ios-android.jpg` |
| Die shells | lighter, greyer | darker, bluer | the same pairs |
| Shadows | present after the fixes above; shorter and lighter than Android's | longer, darker | the same pairs |

In each pair iOS is on the left. The Android halves are the existing
captures in `../p3-dartnative-set/` and `../s0-tray-orientation/`.
The landscape pair's iOS half predates fix 3 (it shows the logo-shaped
shadows).

## Seen, not fixed

- A die resting against a wall or in a corner covers the rim line
  (`h-roll04.jpg`, `h-roll05.jpg`). Already listed as open.
- The second read after the d4 turn sometimes arrives by the 4 s
  timeout instead of a settle event; the faces are the same.
- A die can come to rest on top of another (`main-default`, the sweep);
  it is read as it lies.
- One Roll in `fix5-dice` was not sent by this run (the simulator's
  live panel was open to the operator).

## Still owed

- Landscape → portrait on iOS.
- A real finger, and the platform's fling velocity.
- A physical iOS device: frame rate, TAA, a real GPU.
- Shadows of skinned or morphed blended meshes on iOS.
- Body state across a re-realize on iOS (not built).
