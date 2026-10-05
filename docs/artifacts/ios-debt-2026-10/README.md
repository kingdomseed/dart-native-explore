# iOS verification debt — 2026-10-05 (work in progress)

**Status: paused part-way** (the simulator was handed to another
project). This file is a working record; the per-lane tables are
written when the run is complete. What is still owed is at the end.

Device: iPhone 17 Pro simulator `C24F3C6D-A3A9-4FB7-978E-36E67EF55354`,
iOS 27.0, 402×874 pt. Launch: `dn run -d <udid>` from `dart3d/example`,
**debug** (plus `--dart-define=DART3D_SCENE=dice` for the dice runs).
Input: the session's iOS-simulator tool (tap, touch path). Rotation:
the app's window scene was asked for an orientation through `lldb`
(Xcode 27 has no Simulator.app and `simctl` has no rotate).

## Runs

| Run | Tree | What ran |
|---|---|---|
| `main-default` | main `63fe903` | hero, "Roll the dice", 2 Roll-button rolls, aim throw, hold-and-toss, sweep |
| `fix4-dice` | `32ab307` (main + isolate fix + shadow range and samples) | 10 rolls (6 Roll, 2 aim, 1 toss, 1 sweep), Reset, rotation to landscape, a landscape roll |
| `fix5-dice` | `19a3eff` (+ blended shadow casters) | rack, 1 roll, hold-and-toss, Reset |
| `pr55-dice` | `19a3eff` + #55 (`aa51de0`, not committed here) | rack, 10 rolls (8 Roll, 1 aim, 1 toss), rotation to landscape |

Logs: `logs/<run>.app.log` (the app's `dart3d:` lines),
`logs/<run>.native.log` (the plugin's native lines without the
per-tick ones), `logs/<run>.positions.txt` (die positions at the first
and last physics tick).

## Results so far

- **Boot.** main builds and runs in debug on the simulator.
- **Hero.** Logo and glow render (`main-hero-1.jpg`).
- **Readout (a).** `fix4-dice`: 10 rolls, 70 of 70 dice read as the
  face shown (`h-roll01`–`h-roll10`), including both d10s and the d4.
  `main-default`: 5 of 5 rolls match.
- **d4 turn (b).** Every roll logs `d4 turns N° to read upright` and a
  second readout with the same faces; the d4 reads upright in every
  screenshot. After a rotation refit the d4 is not turned again (one
  turn per roll).
- **Cocked nudge (c).** Seen without provoking it: d12 `up 0.853` →
  nudge → flat (`main-default`); d6 `up 0.770` → flat (`h-roll03`);
  d12 three nudges → flat (`h-roll07-aim`).
- **Gestures (d).** Driven: drag to aim (`h-aim-arrow.jpg`), hold to
  pick up and fling (`h-hold-lifted.jpg`, `p-hold-lifted.jpg`), sweep.
  The fling velocity is the app's own estimate (`tracked`), not the
  platform's.
- **Numerals (e), culling (f), logo (h).** Numerals inside the inlay
  line, a dot by the 6 and none by the 9, no far-side faces through
  the shells, logo centred and dim in every die (`h-roll*.jpg`).
- **Tray (g).** Portrait → landscape: refit, dice pulled inside, read
  again (`h-landscape-after-rotate.jpg`, `h-landscape-roll.jpg`).
  Landscape → portrait has not run.
- **Re-realize ordering (i).** `re-realize: restored 28 written
  transform(s)` on every dice load; the rack's first physics tick is at
  the fitted rack (rows at z 24.2 / −3.0 / −30.3, centre 3.0 = the
  fitted play area's centre; the build-time layout's is 2.67).

## Defects found and fixed

1. **The dice table was built on the UI isolate** (`507fe75`). The
   `Isolate.run` closure captured the screen's state; the spawn threw
   (`background build failed … object is unsendable`).
2. **No shadows on the dice table** (`32ab307`). SceneKit's default
   shadow range is 100 units from the camera (the table's is 316 away),
   and one shadow sample per fragment on iOS.
3. **Blended meshes cast no shadow** (`19a3eff`). The translucent dice
   had none; the opaque logo inside each cast a logo-shaped one
   (`h-hold-lifted.jpg` before, `p-hold-lifted.jpg` and
   `fix5-entry.jpg` after).

## #55 so far

With #55 applied: the rack loads at the fitted positions, 10 rolls
settle and read, the aim throw and the toss fly
(`pr55-roll06-toss.jpg`), rotation refits and reads again
(`pr55-landscape.jpg`). Without it (`fix4-dice`, `fix5-dice`) the same
holds: the restored dice are at their written poses on the first tick
and stay there, so the snap-back Codex described is not seen on main in
this scenario. No verdict yet: the two runs' logs have not been
compared in detail.

## Appearance differences seen (not defects; for the S0g light-unit work)

- Felt reads neutral dark grey on iOS, deep indigo on Android.
- The rim's gradient is pale (yellow → pink pastel) on iOS, saturated
  lime → pink on Android.
- Compare `fix5-entry.jpg` with `../p3-dartnative-set/review-rack.png`.

## Seen, not fixed

- A die at a wall can cover the rim line (already listed as open).
- The re-read after the d4 turn sometimes arrives by the 4 s timeout
  instead of a settle event (same faces).

## Still owed

- Showcase and the harness scene on iOS.
- Landscape → portrait rotation; the tray lane on the final head.
- The #55 verdict and its comparison.
- `dn analyze` / `dn test`, the docs (program-v2, AGENTS.md), the PR
  and its review.
