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
  the same change. Two ordering fixes are in for iOS, type-checked
  only. The iOS changes that alter how a dynamic body is moved are not
  in this PR; they wait for an iOS run in
  `s0g-ios-dynamic-body-reseat`.

## Body state

A re-realize rebuilds every node and body from the manifest, then
replays the op journal and the written transforms. `BodyCarry` now
captures each kinematic and dynamic body's world pose, linear and
angular velocity and awake flag before the rebuild and puts them on the
rebuilt body afterwards, after the written transforms (a restored write
teleports its body to the written pose, and the body has moved since).
The nodes are then synced from their bodies, parents before children,
because the per-frame sync skips sleeping bodies and a node's local
transform is derived from its parent's world transform. The view's awake count carries as well, so the
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
A142 OpenGL, Fire tablet and Wacom: PASS, `harness-a142-opengl.log`,
`harness-fire.log`, `harness-wacom.log`.

## Review threads on #45

| Thread | Verdict |
|---|---|
| 4160436716, partial mask snaps a moving body's unwritten fields | **Fixed on Android**: the whole simulated pose is restored after the written fields. **iOS: not in this PR.** Restoring a dynamic body's whole pose there changes how dice are placed after a load, so it is in `s0g-ios-dynamic-body-reseat` until it has run on iOS. |
| 4160325887, iOS resets a child's body before its parent is restored | **Fixed**: fields in one pass, body resets in a second. Type-checked, not run. |
| 4160325907, a rejected `addNode`/`updateNode` still dropped the saved write | **Fixed on both**: supersession moved into the handlers, after validation. iOS type-checked, not run. |
| 4160325876, descendants of a removed node stayed tracked | Already fixed on `main`: Android `supersedeAll(doomed)` over the whole removed set, iOS `transformWrites[k] = nil` per removed node in `removeSubtree`. |
| 4160325894, a clip's output captured as a written transform | Already fixed on `main`: both captures skip nodes whose clip drives the transform. |

## Review threads on this PR

| Thread | Verdict |
|---|---|
| 4183372933, a child body synced before its parent is restored | **Real, fixed.** Nothing stops a document putting a body on a node under another body's node, the bodies come out of a `HashMap`, and `syncBody` computes a node's local transform from its parent's current world transform, so a child handled first was placed against the parent's manifest pose; asleep, it stayed there. Now every body is restored first (world space, order-free) and the nodes are synced in depth order (`BodyCarry.parentsFirst`, three new tests). Not reproduced on a device: neither the dice scene nor the harness nests bodies. |
| 4183372939, iOS restores a dynamic body's node without `resetTransform()` | **Valid; the fix is not in this PR.** Apple's reference says the call is required after moving a node with a dynamic body, and iOS skips it for dynamic bodies on restore and in `applySetTransforms` (the exclusion dates from #36, type-checked only; die teleports did work on the simulator without it). The fix calls it for every body type and writes a dynamic body's velocities back. It changes the roll path and cannot be judged from Android, so it is in `s0g-ios-dynamic-body-reseat` and must run on a simulator or device first. |

## iOS

**In this PR**, both pure ordering, type-checked only:

- `restoreTransformWrites` restores every written field first and
  resets the static and kinematic bodies in a second pass (#45 thread
  4160325887). Same fields, same bodies, same calls as before; only
  the order differs.
- A saved transform is superseded inside `applyAddNode` and
  `applyUpdateNode`, after their validation, instead of before the
  dispatch (#45 thread 4160325907). `removeNode` already cleared per
  removed node.

**Moved to `s0g-ios-dynamic-body-reseat`** (draft, based on this
branch, not to merge before an iOS run of the dice screen, rolls and a
rotation refit):

- `reseat(_:)`: `resetTransform()` for dynamic bodies too, with their
  velocities written back, on restore and in `applySetTransforms`.
- Restoring position and rotation for a dynamic body whatever its
  write mask.

Not built at all: the body state itself. It was not changed, because it cannot be run. The
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

Complete on Android. The three devices ran this PR's Android code:
the tablets on `2958168`, the A142 on the commit after it, which only
takes the two iOS changes above back out (no Android file differs).

Each device from a fresh launch: hero 30 s, dice racked 30 s, 12 rolls
3 s apart, settle; then the harness (`DART3D_SCENE=harness`) to `w18
lane complete`. Frame rates from the `dart3d.perf` log, baseline from
`docs/artifacts/s0-three-device-baseline/` in brackets.

| Device | Backend, tier | Hero | Dice racked | Dice rolling | Harness | FATAL |
|---|---|---|---|---|---|---|
| Fire KFTUWI | OPENGL, LOW | 56.0 (55.0) | 44.5 (44.2) | 44.1 (43.7) | complete, W25 PASS | 0 |
| Wacom DTHA116 | OPENGL, LOW | 57.4 (57.5) | 50.6 (51.2) | 45.2 (44.1) | complete, W25 PASS | 0 |
| Nothing A142 | VULKAN (pref=0), STANDARD | 89.7 (89.7) | 49.7 (49.7) | 50.3 (50.3) | complete, W25 PASS | 0 |
| Nothing A142, `DART3D_BACKEND=opengl` | OPENGL (pref=1), STANDARD | 80.8 | 31.5 | 32.0 | complete, W25 PASS | 0 |

- **The A142 on forced OpenGL has no baseline.** It was never measured
  before today. 31.5 fps on the dice screen is 18 fps under the same
  phone on Vulkan. The lifetime and review-follow-ups branches,
  neither of which has this PR's code, measure the same 32 fps there
  (31.9 and 31.7), so it is how the standard pipeline runs on that
  driver's OpenGL today and not this PR. Not looked into; the A142
  resolves to Vulkan by default.
- Both tablets were also run on `325cb4f`, before the review fixes,
  with the same results within 1 fps (Wacom 57.7 / 51.4 / 45.4).
- One earlier attempt to install on the Wacom failed in `adb install`
  with an empty reason. The tablet's log shows the install session
  opened at 09:56:23 and abandoned 1.7 s later with no
  `INSTALL_FAILED` code, no signature or storage complaint (97 GB
  free, same signing key as the build already on it). So the device
  refused nothing; the transfer stopped on the host side. Three
  `dn run` sessions and two log streams were using adb at that moment.
  Why it stopped is not known. The same APK path installed first time
  on every later run, with one device at a time, and nothing on the
  tablet was changed to get there.

`fire-*.jpg`, `wacom-*.jpg`, `a142-vulkan-*.jpg`, `a142-opengl-*.jpg`
(hero, dice, settled), `*-harness*.jpg`; `harness-*.log`.

## Checks

- `dn analyze` and `dn test`: `dart3d` 277 tests, `dart3d/example` 230
  tests (3 new), clean.
- `:dart3d:testReleaseUnitTest`: 116 tests pass, 12 new
  (`BodyCarryTest`).
- `swiftc -typecheck` of `dart3d/ios/Classes` against the iPhone
  Simulator 27.0 SDK, target iOS 16: clean.

## Open

- iOS: the body state (not built), and a simulator or device run of
  the two ordering fixes that are in this PR.
- Joints are rebuilt while their bodies are still at the manifest
  pose, before the body state goes back. A hinge's zero angle and a
  fixed joint's relative orientation are taken at that moment. For a
  joint declared in the document that is the pose it was first built
  at, so nothing changes; a joint added by a command while its bodies
  were elsewhere gets the manifest pose as its reference, as it did
  before this change.
- A body in free fall keeps the world from settling. Apps need their
  own floor or a rescue, as the harness and the dice tray have.
