# #27 / PR #29: Android re-check (Nothing A142, partial)

- Build: `origin/s0g-ios-anim-orbit` @ `7c4ad62`, `dn run -d 00064149A002033 --release`
  from `dart3d/example`. Vulkan is the default backend. The log shows
  `material package lit|false|OPAQUE|e1|s17|VULKAN compiled in 3798ms`.
- Every injected input came after a foreground check
  (`dumpsys activity activities` → `topResumedActivity` must be
  `com.jasonholtdigital.dart3d_example/.MainActivity`).
- **The run stopped early.** A calibration swipe started at x=25px, inside
  Android's edge-back zone. The OS took the swipe as system back and sent the
  app to the launcher (`[DN-Back] system back → OS default`; see
  `vk-dash-edge-back-sheet.png`). This was a test-harness error, not an app
  bug. Under the foreground rule, input injection stopped there. The GL
  pass and the calibrated yaw-rate check did not run.

## Multi-touch injection

`input` only supports one pointer, and SELinux blocks shell writes to
`/dev/input/event2`. Pinches were injected through Android's built-in
`hid` tool (`/system/bin/hid`; the shell user is in the `uhid` group). The
tool registers a virtual 2-contact HID digitizer, and the kernel binds
`hid-multitouch`. `hidmt.py` generates the newline-delimited JSON command
stream. Device probe takes ~2.3 s, so the stream waits 5 s after `register`.
Scale: 30 reports at 16 ms each, with the two contacts spreading 150→300 px
(pinch out) or 300→150 px (pinch in).

## Results (Vulkan)

| Item | Result | Evidence |
|---|---|---|
| DN logo `Spin` autoplays | PASS | `vk-logo-spin-t0/t1.png`: pose differs 0.3 s apart |
| dash `Idle` autoplays | PASS | `vk-dash-idle-sheet.png`: 8 frames at 2 fps, tuft and wings move |
| One-finger drag orbits (logo pitch) | PASS | `vk-logo-a.png` → `vk-logo-pitch.png` (swipe down 400px → near top-down); swipe up restored it |
| One-finger drag orbits smoothly (yaw) | PASS (qualitative) | `vk-logo-dragpinch-sheet.png` row 1: continuous orbit during the one-finger phase |
| No double-speed rotation | NOT VERIFIED | The calibrated 180° swipe was eaten by edge-back (above). |
| Pinch zooms (logo) | PASS | `vk-logo-a.png` → `vk-logo-pinchin.png` (zoomed out ~2x) |
| Pinch after one-finger drag doesn't jump | PASS | `vk-logo-dragpinch-sheet.png` (10 fps): zoom grows gradually from the zoomed-out distance, no single-frame jump. It ends near the original framing (`vk-logo-dragpinch-end.png`), as expected for 0.5x then 2x |
| Dice tab one-finger pan | PASS | `vk-dice-0.png` → `vk-dice-pan.png` (table follows the finger up-left) |
| Dice tab pinch zoom | PASS | `vk-dice-pinch.png` (in), `vk-dice-pinchin.png` (out) |
| All of the above on GL (`DART3D_BACKEND=opengl`) | NOT RUN | stopped (see above) |

## Key log lines

```
I dartnative: dart3d: showcase — dartnative_logo: 7 nodes · 2 geo · 2 mat · 1 tex · 1 anims
I dart3d  : material package lit|false|OPAQUE|e1|s17|VULKAN compiled in 3798ms
I dartnative: dart3d: showcase — dash: 41 nodes · 2 geo · 2 mat · 2 tex · 1 skins · 9 anims
W dart3d  : slow frame 860ms on main: ops=1897 realize=true      (dash first load)
I dartnative: [DN-Back] system back → OS default (...)            (harness edge swipe)
```

## To finish

- Re-run the yaw-rate check with swipes that stay out of the edge zones
  (x 100→1000 ≈ 347 logical px ≈ 159° at single speed, ~318° at double).
- Repeat the matrix with `--dart-define=DART3D_BACKEND=opengl`.
