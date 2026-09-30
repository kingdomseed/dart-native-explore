# P3 DR2 — dice feel: device evidence (A142)

Device: Nothing A142 (`00064149A002033`, Android 16, Mali-G610, Filament
Vulkan), 1084×2412 px = 413×919 logical. Launch:
`dn run -d 00064149A002033 --release --dart-define=DART3D_SCENE=dice`
from `dart3d/example`. Input was injected with `adb shell input`
(`swipe`, `tap`, `motionevent DOWN/MOVE/UP`), every touch ≥100 px from
the screen edges, foreground package checked before each one.
Screenshots are downscaled to 900 px tall (256-colour PNG);
`dr2_throw_strip.png` is a 7 s screen recording at 2 fps (videos stay out
of git, per `.gitignore`).

iOS: DR2 changes no native code (Swift/Kotlin untouched); the Dart is
shared and analyzer-clean. **iOS device verification is pending**
(operator rule for this run: A142 only, no simulators) — in particular
the one-finger scale path that carries drags on iOS.

## d4 reads upright

- `entry.png`: the rack — the shard's 4 now reads upright (DR1's read
  sideways: the numeral's up ran along the crystal; it now runs across
  it, so the numeral reads *along* the crystal).
- After every settle the d4 turns about the vertical (a velocity servo
  on its pose, no teleport) until its numeral is within 3° of upright.
  13 turns logged across 17 rolls, from 7° to 136°, e.g.
  `dice d4 turns 31° to read upright`; `aim_settled.png` shows the
  result (the 4 upright at the top).

## Cocked dice

Detection: up-face dot below `cos(min(8°, 0.3 × the die's smallest
face spacing))` — so a d20 balanced on an edge (dot 0.93, which
upstream's 0.9 misses) counts. Nudge: a hop of ~half a radius, a push
away from the neighbours/walls it leans on, and a spin that levels the
up face over the hop's flight; the roll is read at the next settle (up
to 3 nudges per die).

17 rolls in this session: 7 cocked dice in 4 rolls, every one flat
after one nudge, 0 settle timeouts, 0 dice outside:

```
dice cocked d4 (up 0.296) → nudge #1
dice cocked d8 (up 0.890) → nudge #1
dice settled — d4=4 (up 1.000 …) d6=6 (up 1.000 …) d8=2 (up 1.000 …) d10t=20 (up 1.000 …) d10u=5 (up 1.000 …) d12=4 (up 1.000 …) d20=4 (up 1.000 …) [2 nudges]

dice cocked d4 (up 0.925) → nudge #1
dice cocked d8 (up 0.900) → nudge #1
dice cocked d12 (up 0.967) → nudge #1
dice settled — … every die up 1.000 [3 nudges]
```

## Aim → throw from off-screen

- `aim_arrow.png`: dragging from the table draws the arrow (width and
  colour ramp with the pull, cyan → lime → amber → pink at 420 px).
- `aim_flyin.png`, `dr2_throw_strip.png`: on release the dice enter
  from beyond the screen edge behind the arrow's tail through an opened
  gate wall, fly in along it and land inside; the gate closes once all
  are in (`dice gates closed after 0.27–0.37 s`).
- Roll throws the same way along a random arrow
  (`dice roll throw — strength 0.75 dir (1, 0) gates [1]`).

## Pick up and toss

- `hold_lifted.png`: a press held still for 0.28 s lifts all seven dice
  to a hover plane (68 u) in a hex cluster under the finger, each
  turning slowly; they follow the finger.
- Release flings them with the finger's velocity (platform velocity on
  Android's pan end; our own least-squares tracker otherwise), e.g.
  `dice tossed — fling 621 px/s (platform, …) → 7.7 u/s`. A release
  without motion drops them. Scripted adb events arrive ~0.25 s apart,
  so injected flicks top out near 600 px/s; a real flick is several
  thousand (capped at upstream's 28 u/s).
- Holds of 0.45–1.0 s followed by a drag keep delivering the drag
  (Android's long-press doesn't swallow it). `input draganddrop` does
  swallow it — an injection quirk (drag-and-drop mode), not a finger.

## Sweep

- `sweep_mid.png`, `sweep_settled.png`: a drag that starts on a racked
  die shoves every die it passes (finger velocity × 0.8 plus a small
  hop) and counts as a roll (`dice sweep` → settle → readout).

## Findings (DartNative)

- `Listener` around the native `SceneView` hides the view (zero-size /
  covered), and a `Listener` on a transparent overlay above it receives
  no touches on Android. `GestureDetector` on the view works: tap-down
  arrives on touch, pan carries the release velocity, and Android also
  emits a one-finger scale stream. Input therefore goes through
  `GestureDetector` (tap-down / pan / tap-up, plus one-finger scale for
  iOS, where the scale recognizer claims one-finger drags).
- `Offset.distance` read a 228 px drag as ≥ 420 px (a full-strength
  throw); the screen computes lengths itself.

## Checks

- `dn analyze`: clean in `dart3d/example/`.
- `dn test` (`dart3d/example/`): all pass; new `dice_feel_test.dart`
  (26 tests): shard numeral frame and UVs, rack/roll uprightness, the
  yaw servo converging with lag, cocked detection (flat, wobble,
  edge-rest incl. the d20, leaning), the nudge levelling the up face
  and pushing away, fling tracker, screen→world velocity and
  unproject, toss/drop, throw plans (off-screen spawn, gates, ballistic
  touchdown inside the tray, under the ceiling, forward spin), Poisson
  and hold clusters without overlap, sweep, gesture arbitration.
