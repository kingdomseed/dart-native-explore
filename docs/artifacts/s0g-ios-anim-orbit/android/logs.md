# #27 / PR #29: Android re-check (Nothing A142)

- Device: Nothing A142 (`00064149A002033`), Mali-G610, release builds via
  `dn run -d 00064149A002033 --release` from `dart3d/example`.
- Builds tested:
  - **PR** `origin/s0g-ios-anim-orbit` (`7c4ad62` Dart/native code) on Vulkan
    (default) and on GL (`--dart-define=DART3D_BACKEND=opengl`).
  - **Baseline** `origin/main` (`ba39a61`) on Vulkan, for drag sensitivity only.
    This build was a sequential checkout in the same worktree, not a separate
    worktree. Same effect.
- Logcat confirms the backend each time:
  `material package ...|VULKAN compiled` / `...|OPENGL compiled`.
- Every injected input came after a foreground check
  (`dumpsys activity activities` → `topResumedActivity` must be
  `com.jasonholtdigital.dart3d_example/.MainActivity`). In the second pass,
  every touch stayed at least 100 px from all screen edges.

## Pass 1 incident (harness, not app)

In the first Vulkan pass, a calibration swipe started at x=25 px, inside
Android's edge-back zone. The OS took it as system back
(`[DN-Back] system back → OS default`) and the app went to the launcher
(`vk-dash-edge-back-sheet.png`). The foreground rule stopped input at that
point. Pass 2 redid that check with swipes at x 100→1000.

## Multi-touch injection

`input` only supports one pointer, and SELinux blocks shell writes to
`/dev/input/event2`. Pinches were injected through Android's built-in
`hid` tool (`/system/bin/hid`; the shell user is in the `uhid` group). The
tool registers a virtual 2-contact HID digitizer, and the kernel binds
`hid-multitouch`. `hidmt.py` generates the newline-delimited JSON command
stream. Device probe takes ~2.3 s, so the stream waits 5 s after `register`.
Scale: 30 reports at 16 ms each. The two contacts sit around (542, 1150) and
spread 150→300 px (pinch out) or 300→150 px (pinch in). `drag_then_pinch_out`
drags one finger 392→692 px, then lands a second finger 150 px below and
spreads to 300 px.

## Yaw rate: no double-speed rotation

Swipe: `input swipe 100 1207 1000 1207 1200` on dash, at dash's vertical
center. That is 900 px / 2.625 dpr = 343 logical px × 0.008 rad/px =
**2.74 rad ≈ 157°** at single speed (a little less after touch slop). A
doubled handler would give ~314°, which lands back near a front-quarter view.

| Build | Result | Evidence |
|---|---|---|
| PR, Vulkan | Back view, beak just visible on the left: about 160–180° by eye. Rotation is smooth and monotonic (24 frames at 10 fps) | `pr-vk-dash-before.png`, `pr-vk-dash-yaw.png`, `pr-vk-dash-yaw-sheet.png` |
| PR, GL | Same final pose | `gl-dash-before.png`, `gl-dash-yaw.png`, `gl-dash-yaw-sheet.png` |
| origin/main, Vulkan | Same final pose; the frame sequence matches the PR frame for frame | `main-dash-before.png`, `main-dash-yaw.png`, `main-dash-yaw-sheet.png` |

`yaw-compare-main-vs-pr.png` shows, left to right: the authored pose, then
the end pose on main (Vulkan), the PR (Vulkan) and the PR (GL). All three end
poses are identical. **The PR does not change Android drag sensitivity,
and no double rotation occurs.** On Android only one recognizer drives the
orbit per gesture.

## Results

| Item | Vulkan (PR) | GL (PR) | Evidence |
|---|---|---|---|
| DN logo `Spin` autoplays | PASS | PASS | `vk-logo-spin-t0/t1.png`; `gl-logo-strip.png` frames 1–2 (pose differs 0.3 s apart) |
| dash `Idle` autoplays | PASS | PASS | `vk-dash-idle-sheet.png`, `gl-dash-idle-sheet.png` (tuft, wings and beak move) |
| One-finger orbit, pitch (logo) | PASS | PASS | `vk-logo-a.png` → `vk-logo-pitch.png`; `gl-logo-strip.png` frame 3 (near top-down); swipe up restored it |
| One-finger orbit, yaw, smooth | PASS | PASS | `*-dash-yaw-sheet.png` |
| No double-speed rotation (vs origin/main) | PASS | PASS | see the yaw section above |
| Two-finger pinch zooms | PASS | PASS | `vk-logo-pinchin.png`; `gl-logo-strip.png` frame 5 (zoomed out ~2x) |
| Pinch after one-finger drag doesn't jump | PASS | PASS | `vk-logo-dragpinch-sheet.png`, `gl-logo-dragpinch-sheet.png` (10 fps): zoom grows gradually from the zoomed-out distance with no single-frame jump. It ends near the original framing, as expected for 0.5x then 2x (`vk-logo-dragpinch-end.png`, `gl-logo-strip.png` frame 6) |
| Dice tab one-finger pan | PASS | PASS | `vk-dice-0.png` → `vk-dice-pan.png`; `gl-dice-strip.png` frames 1–2 |
| Dice tab pinch zoom | PASS | PASS | `vk-dice-pinch.png`, `vk-dice-pinchin.png`; `gl-dice-strip.png` frames 3–4 |

No crashes. No Android code changed in this PR. Android does not show the
iOS-only issue (a one-finger drag delivered only through `onScaleUpdate`),
and it still orbits correctly with the new shared routing.

## Key log lines

```
I dart3d  : material package lit|false|OPAQUE|e1|s17|VULKAN compiled in 3798ms     (PR, Vulkan)
I dart3d  : material package lit|false|OPAQUE|e0|s31|OPENGL compiled in 3532ms     (PR, GL)
I dart3d  : material package lit|false|OPAQUE|e0|s31|VULKAN compiled in 3328ms     (origin/main, Vulkan)
I dartnative: dart3d: showcase — dartnative_logo: 7 nodes · 2 geo · 2 mat · 1 tex · 1 anims
I dartnative: dart3d: showcase — dash: 41 nodes · 2 geo · 2 mat · 2 tex · 1 skins · 9 anims
W dart3d  : slow frame 860ms on main: ops=1897 realize=true      (dash first load)
I dartnative: [DN-Back] system back → OS default (...)            (pass 1 harness edge swipe)
```
