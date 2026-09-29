# #33: switching clips left the previous clip's pose applied

## Cause

Dash's eyes are bones, not morph targets. `Eyes` (open) and `EyesClosed`
are scaled against each other, and every one of the 9 clips drives all
105 channels, eye bones included. `Jump` and `JumpLand` start (t=0) in a
squint: `Eyes` at 0.855 and 0.842, `EyesClosed` at 1.130 and 1.135.

dart3d's `stop` matches upstream `AnimationClip.stop`: it pauses the clip
and rewinds it to 0, and the clip stays in the blend at its weight. The
showcase chip switched clips with `stop(old)` then `play(next)`, which
never lowered a weight. Each visited clip therefore stayed in the blend,
frozen at its t=0 pose, and the weights were normalized across all of
them. After one cycle, the playing clip held only 1/9 of the weight. Jump
and JumpLand's t=0 squint kept the eyes half-closed and the beak out of
place.

The bug was in the example's switcher, not in the native runtime.
SCNAnimationPlayer, morph weights, and the #29 clip carry-over are not
involved.

## Fix (upstream parity kept, program-v2 D4)

- `stop` is unchanged on both platforms: pause and rewind, and the clip
  stays in the blend at its weight.
- New `SceneController.switchAnimation({from, to, loop})` sends one
  batch built by `encodeSwitchAnimCommands`. It stops `from` and sets its
  weight to 0, then plays `to` from 0 at weight 1. Because both ops land
  in the same native drain, no frame shows the bind pose between clips.
- The showcase chip now uses `switchAnimation`.
- A weight-0 clip adds nothing, so its channels return to bind. Upstream
  gives the same result: `AnimationPlayer.update` resets each target to
  bind, and a clip at weight 0 lerps by 0. Both native samplers already
  skip `w == 0`, so no native change was needed. The W11 lane below
  confirms this on both platforms.
- On Android, the clip state and blend weights moved to `AnimClips.kt`
  without changing behavior, so they can be tested on the JVM.

## Evidence

- Before, iOS sim: `ios-before-idle-fresh.png` shows Idle on load with
  eyes open. `ios-before-idle-after-cycle.png` shows Idle again after one
  pass through all 9 clips, with eyes closed and the beak displaced.
- After, iOS sim: 27 switches (3 × 9), checked against the chip label.
  Eyes are open on every non-squint clip. Screenshots:
  `ios-after-walk.png`, `ios-after-poselib.png`,
  `ios-after-idle-27-switches.png`.
- After, A142 (release): 27 switches. Before every `adb` tap, a guard
  checked that `com.jasonholtdigital.dart3d_example` was in the
  foreground; taps were at (541, 2240) on a 1084×2412 screen. Screenshots:
  `a142-after-walk.png`, `a142-after-idle-27-switches.png`.
  `a142-after-jumpland-authored-squint.png` shows JumpLand's authored
  squint, which clears when the next clip plays.
- Lane (W11 harness, `DART3D_SCENE=harness`, +21.5 s). It uses the
  switch batch to go from wave to tilt, then stops tilt at weight 0, and
  reads the j1 world pose each time:
  - iOS: `w11 stop-rest switch PASS want=0.50rad live=(0,0,0.247,0.969)`,
    `w11 stop-rest rest PASS want=0.00rad live=(0,0,0,1)`
  - A142: same values, both PASS.
- Dart unit test: `animation_skins_morphs_test.dart` checks the switch
  batch's shape (outgoing stop + weight 0, incoming play from 0 at
  weight 1; no stop op when `from` is null or equals `to`).
- JVM unit tests: `AnimClipsTest` has 5 tests:
  - A stopped clip still blends at weight 1.
  - A weight-0 clip contributes 0.
  - A 9-clip × 3 weight-0 switch cycle leaves only the current clip.
  - A stop-only cycle dilutes the playing clip to 1/9 (the #33 shape).
  - The verb order and clamps are correct.

## Checks

- `dn analyze`: clean in `dart3d/` and `dart3d/example/`.
- `dn test`: 274/274 pass in `dart3d/`; 158/158 pass in `dart3d/example/`.
- `swiftc -typecheck -target arm64-apple-ios16.0-simulator`
  (iPhoneSimulator 27.0 SDK): clean.
- `:dart3d:testReleaseUnitTest` and `:dart3d:compileReleaseKotlin`: clean.
