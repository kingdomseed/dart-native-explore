# #33: switching clips left the previous clip's pose applied

## Cause

Dash's eyes are bones, not morph targets. `Eyes` (open) and `EyesClosed`
are scaled against each other, and every one of the 9 clips drives all
105 channels, eye bones included. `Blink` squashes `Eyes` to 0.64 in x and
grows `EyesClosed` to 1.11. `Jump` and `JumpLand` start (t=0) in a squint:
`Eyes` at 0.855 and 0.842, `EyesClosed` at 1.130 and 1.135.

The showcase chip switched clips with `stop(old)` then `play(next)`. The
native `stop` matched upstream `AnimationClip.stop`: it paused the clip and
rewound it to 0, but the clip stayed in the blend at weight 1. Each visited
clip therefore stayed in the blend, frozen at its t=0 pose, and the
weights were normalized across all of them. After one cycle, the playing
clip held only 1/9 of the weight. The rest was a mix of frozen t=0
poses: Jump and JumpLand's squint kept the eyes half-closed and the beak
out of place. iOS (`SceneViewHost.sampleAnimations`) and Android
(`Dart3dView.sampleAnimations`) share the same sampler, so both
platforms had the bug.

SCNAnimationPlayer, morph weights, and the #29 clip carry-over are not
involved. dart3d samples clips itself and writes node TRS every frame.

## Fix

`stop` now takes the clip out of the blend (`active = false`). A stopped
clip contributes nothing and does not count toward the weight total. Its
nodes stay recorded, so the existing per-frame write-back returns them to
bind. `play`, or a seek, puts the clip back in the blend. `pause` still
holds the pose and keeps it in the blend. The Kotlin clip state moved to
`AnimClips.kt` so it can be tested on the JVM. The showcase now sends
stop and play in one command batch, so both land in the same native
drain and no bind-pose frame shows between clips.

## Evidence

- Before, iOS sim: `ios-before-idle-fresh.png` shows Idle on load with
  eyes open. `ios-before-idle-after-cycle.png` shows Idle again after one
  pass through all 9 clips, with eyes closed and the beak displaced.
- After, iOS sim: 3 full cycles, with eyes open on every non-squint clip.
  Screenshots: `ios-after-run-cycle1.png`, `ios-after-idle-cycle1.png`,
  `ios-after-poselib-cycle3.png`, `ios-after-idle-cycle3.png`.
- After, A142 (release): 27 guarded chip taps (3 cycles).
  Screenshots: `a142-after-walk-cycle3.png`, `a142-after-idle-cycle3.png`.
  `a142-after-jumpland-authored-squint.png` shows JumpLand's authored
  squint, which clears when the next clip plays.
- Lane (W11 harness, `DART3D_SCENE=harness`, +21.5 s). It switches wave to
  tilt in one batch, then stops tilt, and reads the j1 world pose each time:
  - iOS: `w11 stop-rest switch PASS want=0.50rad live=(0,0,0.247,0.969)`,
    `w11 stop-rest rest PASS want=0.00rad live=(0,0,0,1)`
  - A142: `w11 stop-rest switch PASS want=0.50rad live=(0,0,0.247,0.969)`,
    `w11 stop-rest rest PASS want=0.00rad live=(0,0,0,1)`
- Unit: `AnimClipsTest` (5 JVM tests) covers these cases: stop leaves the
  blend; a 9-clip × 3 cycle leaves only the current clip at weight 1;
  paused clips still normalize; play or seek re-activates a stopped clip;
  stop+play in one op restarts at 0.

## Checks

- `dn analyze`: clean in `dart3d/` and `dart3d/example/`.
- `dn test`: 273/273 pass in `dart3d/`; 158/158 pass in `dart3d/example/`.
- `swiftc -typecheck -target arm64-apple-ios16.0-simulator`
  (iPhoneSimulator 27.0 SDK): clean.
- `:dart3d:testReleaseUnitTest` and `:dart3d:compileReleaseKotlin`: clean
  (all 39 JVM tests pass).
