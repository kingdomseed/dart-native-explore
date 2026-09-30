# P3 DR1 — dice foundation: device evidence (A142)

Device: Nothing A142 (`00064149A002033`, Android 16, Mali-G610, Filament
Vulkan default), 1084×2412 px at 420 dpi = 413×919 logical.
Launch: `dn run -d 00064149A002033 --release` from `dart3d/example`
(hero → "Roll the dice", and `--dart-define=DART3D_SCENE=dice`).
Screenshots are downscaled to ≤900 px (256-colour PNG).

iOS: `swiftc -typecheck` only. **iOS device/simulator verification is
pending** (operator rule for this run: A142 only, no simulators).

## Readout vs visible top face (portrait, default throw)

Each settle logs every die's value, how squarely it lies (`up` = dot of
the face normal with +Y) and its position. Every face visible in the
screenshot matches the log; a die hidden under another is noted.

| Shot | Settle log (readout) | Visible check |
|---|---|---|
| `p_roll01.png` | d4 3 · d6 1 · d8 4 · d12 6 · d20 18 · d% 80+5 | all match (d6 under the d4) |
| `p_roll02.png` | d4 4 · d6 1 · d8 5 · d12 4 · d20 11 · d% 60+9 | all 7 match |
| `p_roll03.png` | d4 3 · d6 3 · d8 2 · d12 2 · d20 17 · d% 10+8 | all 7 match |
| `p_roll04.png` | d4 3 · d6 5 · d8 1 · d12 2 · d20 3 · d% 90+0 | all 7 match |
| `p_roll05.png` | d4 2 · d6 1 · d8 4 · d12 6 · d20 16 · d% 80+3 | all 7 match |
| `p_roll06.png` | d4 1 · d6 1 · d8 1 · d12 10 · d20 18 · d% 30+4 | all 7 match |
| `p_roll07.png` | d4 2 · d6 5 · d8 6 · d12 3 · d20 11 · d% 70+7 | all 7 match |
| `p_roll08.png` | d4 4 · d6 5 · d8 7 · d12 8 · d20 18 · d% 30+3 | 6 match (d6 under the d10t) |
| `p_roll09.png` | d4 2 · d6 6 · d8 1 · d12 3 · d20 8 · d% 60+6 | all 7 match (d6 "6" reads as 9 upside down) |
| `p_roll10.png` | d4 3 · d6 6 · d8 1 · d12 3 · d20 3 · d% 90+1 | all 7 match |
| `final01.png` | d4 2 · d6 2 · d8 8 · d12 9 · d20 15 · d% 80+9 | all 7 match (final build, entered from the hero) |

`entry.png`: the screen as entered from the hero ("Roll the dice") on the
final build — dice racked face up in the middle of the tray, labeled Back
/ Reset / Roll, no result until the first roll.

Before the fix the same check matched 3/6 dice (iOS) and 1/5 (A142)
(`docs/triage/integration.md` §"Dice readout mismatch").

## Walls at the screen edges

Fit log (portrait): `413x919 insets EdgeInsets(l:10, t:104, r:10, b:134)
→ 3.22 px/u, camera 453, play x -61.1..61.1 z -101.2..110.5`.
Fit log (landscape, `user_rotation 1`): `871x413 insets EdgeInsets(l:34,
t:80, r:184, b:58) → 3.22 px/u, camera 204, play x -124.8..78.2 z
-46.2..39.3` (Roll moves to the right edge in landscape).

- `p_roll01.png`, `p_roll04.png`, `p_roll09.png`: dice resting against
  the left/bottom walls, i.e. at the screen edge / above the readout line.
- `p_roll08.png`: dice against the top wall, below the Back/Reset row
  (follow-up #9, "dice under the tab bar", is fixed: the top wall sits
  under the chrome row).
- `l_rotated.png`: the phone turned mid-result. The walls, ceiling and
  camera refit; dice the new walls cut off are pulled back inside with
  their orientation kept (readout unchanged, 107).
- `l_roll01–03.png`: landscape rolls; `l_roll03.png` has dice resting
  against the left wall at the screen edge. Readouts match (73, 54, 114).
- Rotation settings were restored afterwards (`accelerometer_rotation 1`,
  `user_rotation 0`).

Dice size: the d20 is 19.26 units across; at 3.22 px/u that is 62 dp,
15.0% of the 413 dp short side (measured on `p_roll02.png`: the d20's
silhouette spans ~16% including its perspective height). Constant across
rotation.

## Hard throws (no tunnelling)

Build: `--dart-define=DART3D_DICE_THROW=2.5` — 35–50 upstream units/s
(750–1070 world units/s), well past upstream's 28 u/s clamp. 8 hard
rolls: every die settled inside the play area (0 `OUTSIDE` flags, 0 settle
timeouts). One d6 rested cocked against another die (`up 0.671`, logged
`cocked`); cocked-die handling is a later phase (demo-program §5.1).

- `hard01.png`, `hard05.png`, `hard08.png` (d20=15/10/15).

## Checks

- `dn analyze`: clean in `dart3d/` and `dart3d/example/`.
- `dn test`: `dart3d/example/` all pass (new: `dice_readout_test.dart`
  — every face of every die turned up reads its value, 280 poses;
  `dice_tray_layout_test.dart` — walls in the frustum planes, projection
  onto the inset rect, rack, 15% sizing, portrait + landscape).
- `./gradlew :dart3d:compileReleaseKotlin` (JDK 21): clean.
- `swiftc -typecheck -target arm64-apple-ios16.0-simulator`
  (iPhoneSimulator 27.0 SDK) on `dart3d/ios/Classes/*.swift`: clean.
