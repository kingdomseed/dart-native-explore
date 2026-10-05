# S0g: physics state across a re-realize, and the W25 settle lane (2026-10-05)

Release builds, `dn run -d <serial> --release` from `dart3d/example`.
"Before" is `main` at `f6b8883`; "after" is this branch.

## Result

- **A body keeps its pose, both velocities and its sleep state across a
  payload-arrival re-realize** on Android. Before, the rebuild put
  every body back at rest and awake; #45 had already restored the pose
  of bodies whose node was written by `setTransforms`, and only the
  fields that were written.
- **The harness's W25 dice close-out passes**, and wLoose's settle
  metric now comes from the `settled` event instead of its pose-polling
  fallback. Two causes, both in the harness scene, neither in the
  engine.
- Review threads on #45: the partial-mask snap is fixed on Android by
  the same change; three more are fixed on both natives (iOS
  type-checked only).

## Body state

A re-realize rebuilds every node and body from the manifest, then
replays the op journal and the written transforms. `BodyCarry` now
captures each kinematic and dynamic body's world pose, linear and
angular velocity and awake flag before the rebuild and puts them on the
rebuilt body afterwards, after the written transforms (a restored write
teleports its body to the written pose, and the body has moved since).
The node is synced from its body there too, because the per-frame sync
skips sleeping bodies. The view's awake count carries as well, so the
rebuild does not raise a second `awake` event for bodies that were
already awake.

Not carried: fixed bodies; a body whose node came back as another kind
or not at all; a node a clip drives (same rule as its written
transform); Jolt's own time-to-sleep counter, which jolt-jni does not
expose, so a body that was slowing down starts that count again.

**Measured** with a temporary probe (not committed) that forces a
re-realize every 5 s in the harness while a body is awake and logs the
die before it and one frame after. The harness always has a pending
payload (its never-arriving texture), so this is the real path.

| | Linear velocity | Angular velocity |
|---|---|---|
| `main`, before the rebuild | (0.07, −12.31, −2.05) | (−3.43, −0.99, −0.26) |
| `main`, one frame after | (0.00, 0.00, 0.00) | (0.00, 0.00, 0.00) |
| Branch, before the rebuild | (0.00, −33.61, 0.92) | (1.98, 0.00, 0.00) |
| Branch, one frame after | (0.00, −33.61, 0.92) | (1.98, 0.00, 0.00) |

`forced-rerealize-main.log`, `forced-rerealize-branch.log`. On `main`
the die keeps its position (it has a written transform) and loses its
motion; the same happens at every later forced rebuild. On the branch
position and both velocities come through unchanged, and the log line
`re-realize: restored 6 body state(s), 2 awake, fastest 33.62 u/s`
reports it.

In the app as it ships the case is narrow: on the dice screen the dice
get their bodies at the re-realize itself (their hull colliders wait
for the payload), so there is nothing to carry yet. At harness boot
three re-realizes land in the first three seconds with five bodies;
they now stay asleep through the last two (`0 awake`) instead of being
woken and settling again.

**Sleep state on the Fire tablet's harness boot:** `restored 5 body
state(s), 5 awake`, then `3 awake, fastest 0.02 u/s`, then `0 awake`.

## W25 settle lane

`dart3d: w25 lane complete — dice regression FAIL: … rolled but no
settle event within 10 s` on every surface since #14, and
`wloose settled event path: absent`.

A `settled` event needs every dynamic body asleep. Logging which bodies
were awake (`harness-main-awake-bodies.log`):

1. **`j9.breakBox` (node 58) never sleeps.** The breakable-joint lane
   kicks it at 67 m/s so the joint breaks (`joint broke #9 a=57 b=58`).
   The kick also throws it off the slab, and it has been in free fall
   since: by the wLoose phase it is at y = −8000 and falling at
   190 u/s. wLoose retires the bodies that never rest before it listens
   for `settled`, and this one was not on its list.
2. **The close-out used the demo's random roll**, which can tumble the
   die off the slab (it did in the first run after fix 1: the die at
   y = −134 inside the 10 s window). wLoose already avoids this with a
   straight-up toss, for the reason written in its comment.

Fixes, both in the example: `harnessBodyNeverRests` names the retired
bodies in one place and includes the box; the settle lanes share one
deterministic `tossDieStraightUp`. Nothing changed in how the engine
decides a body is asleep. A body that leaves the world still keeps the
world awake on both natives; there is no kill plane upstream and none
was added.

| | `main` | Branch |
|---|---|---|
| wLoose roll → rest | 4663, 4698, 4698 ms, via pose polling | 1957, 1948, 1949 ms, via the event |
| `wloose settled event path` | absent | seen |
| `w25 lane complete` | FAIL | PASS |

A142 Vulkan: `harness-main-a142-vulkan.log`, `harness-a142-vulkan.log`.
Fire tablet (OpenGL, LOW): PASS, `harness-fire.log`.

## Review threads on #45

| Thread | Verdict |
|---|---|
| 4160436716, partial mask snaps a moving body's unwritten fields | **Fixed, Android**: the whole simulated pose is restored after the written fields. **iOS**: `restoreTransformWrites` restores position and rotation for a dynamic body whatever the mask. Type-checked, not run. |
| 4160325887, iOS resets a child's body before its parent is restored | **Fixed**: fields in one pass, body resets in a second. Type-checked, not run. |
| 4160325907, a rejected `addNode`/`updateNode` still dropped the saved write | **Fixed on both**: supersession moved into the handlers, after validation. iOS type-checked, not run. |
| 4160325876, descendants of a removed node stayed tracked | Already fixed on `main`: Android `supersedeAll(doomed)` over the whole removed set, iOS `transformWrites[k] = nil` per removed node in `removeSubtree`. |
| 4160325894, a clip's output captured as a written transform | Already fixed on `main`: both captures skip nodes whose clip drives the transform. |

## iOS

Not changed for the body state, because it cannot be run. The
equivalent in `SceneViewHost.drainPendingWork`, beside
`captureTransformWrites`:

- Before `FsceneRealizer.realize`: for every node with a `.dynamic` or
  `.kinematic` body, keep `presentation.simdWorldTransform` (the model
  node for ids in `writtenThisDrain`), `physicsBody.velocity`,
  `physicsBody.angularVelocity`, `isResting`, and the view's own
  `quietTicks[id]`, which is what its awake/settled events are computed
  from. Skip clip-driven nodes.
- After `replayAfterRealize()` and `restoreTransformWrites`: for each
  one whose node has a body of the same type again, set
  `simdWorldTransform`, call `resetTransform()`, set both velocities,
  restore `quietTicks[id]`, and `setResting(true)` if it was resting.
  Carry `lastAwakeCount` across the rebuild as Android now does.
- To check on a device: whether a velocity set on a body before its
  first simulation step survives the step, and whether
  `setResting(true)` holds for a body added in the same frame.

## T2 and frame rate

**Incomplete.** The A142 and the Wacom were lent to another project
partway through; the A142 on OpenGL and the Wacom are owed, and the
A142's dice figures are from three commits before the final head.

Each device from a fresh launch: hero 30 s, dice racked 30 s, 12 rolls
3 s apart, settle; then the harness (`DART3D_SCENE=harness`) to `w18
lane complete`. Frame rates from the `dart3d.perf` log, baseline from
`docs/artifacts/s0-three-device-baseline/` in brackets.

| Device | Backend, tier | Hero | Dice racked | Dice rolling | Harness | FATAL |
|---|---|---|---|---|---|---|
| Fire KFTUWI | OPENGL, LOW | 58.5, two windows only (55.0) | 44.2 (44.2) | 44.1 (43.7) | complete, W25 PASS | 0 |
| Nothing A142 | VULKAN, STANDARD | 89.8 (89.7) | 49.7 (49.7) | 50.2 (50.3) | complete, W25 PASS | 0 |
| Nothing A142, OpenGL forced | | not run | | | not run | |
| Wacom DTHA116 | | not run | | | not run | |

- The Fire tablet's hero figure rests on two 2 s windows: the perf log
  switched on late in that run. Its dice figures have 16 and 22.
- The A142's hero/dice run was on `a4939aa`. The final head adds the
  awake-count carry, moves the transform supersession into the
  add/update handlers and adds a test; none of it runs per frame. Its
  harness run is on the final head's code.
- One attempt to install on the Wacom failed in `adb install` with no
  reason given, shortly before the device was handed over. Not
  investigated.

`fire-*.jpg`, `a142-*.jpg` (hero, dice, settled, harness).

## Checks

- `dn analyze` and `dn test`: `dart3d` 277 tests, `dart3d/example` 230
  tests (3 new), clean.
- `:dart3d:testReleaseUnitTest`: 113 tests pass, 9 new
  (`BodyCarryTest`).
- `swiftc -typecheck` of `dart3d/ios/Classes` against the iPhone
  Simulator 27.0 SDK, target iOS 16: clean.

## Open

- iOS body state, as described above; the three iOS thread fixes are
  not run on a device or simulator.
- Joints are rebuilt while their bodies are still at the manifest
  pose, before the body state goes back. A hinge's zero angle and a
  fixed joint's relative orientation are taken at that moment. For a
  joint declared in the document that is the pose it was first built
  at, so nothing changes; a joint added by a command while its bodies
  were elsewhere gets the manifest pose as its reference, as it did
  before this change.
- A body in free fall keeps the world from settling. Apps need their
  own floor or a rescue, as the harness and the dice tray have.
