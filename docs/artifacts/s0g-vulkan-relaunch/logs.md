# S0g: Vulkan warm relaunch (#18), A142 evidence

Device: Nothing A142 (Mali-G610), serial `00064149A002033`. Build:
`dn run -d 00064149A002033 --release` from `dart3d/example` (Vulkan =
`auto` default), and `--dart-define=DART3D_BACKEND=opengl` for GL. The
engine line confirms the backend each time: `Filament engine backend:
VULKAN (pref=0)` / `OPENGL (pref=1)`.

## Repro and cause

The crash depends on timing. On the unfixed head (`origin/main` 4e12ef3), a
Home → relaunch with a 2 s gap passed 5/5 (Dice 2, Showcase dash 3). With
a 0.3 s gap it crashed on the first iteration:

```
09-29 08:14:13.591  3859  3859 D BLASTBufferQueue: [... SurfaceView ...#12] destructor()     <- old surface gone
09-29 08:14:13.801  3859  3859 D BLASTBufferQueue: [... SurfaceView ...#14] constructor()    <- new surface
09-29 08:14:13.820  3859  3859 E AndroidRuntime: FATAL EXCEPTION: main
09-29 08:14:13.820  3859  3859 E AndroidRuntime: java.lang.RuntimeException: Postcondition
09-29 08:14:13.820  3859  3859 E AndroidRuntime: in enumerate:76
09-29 08:14:13.820  3859  3859 E AndroidRuntime: reason: enumerate size error
09-29 08:14:13.820  3859  3859 E AndroidRuntime: 	at com.google.android.filament.Renderer.nBeginFrame(Native Method)
09-29 08:14:13.820  2179  3032 I am_crash: [3859,0,com.jasonholtdigital.dart3d_example,...,java.lang.RuntimeException,Postcondition
```

No `vkCreateSwapchain` line appears before the crash. When
`onDetachedFromSurface` returned, it had only *queued* the swapchain
destroy (`engine.destroySwapChain` is asynchronous). Android then freed
the ANativeWindow. The next flush, which is the first `beginFrame` after
resume, ran the queued destroy of the old VkSwapchain/VkSurfaceKHR against
the dead window, and ran the new surface's create in the same batch. Which
error that produces depends on timing: `enumerate size error`,
`SURFACE_LOST` (-1000000000), or `NATIVE_WINDOW_IN_USE` (-1000000001).

Filament's `UiHelper` javadoc (1.71.6) makes `engine.flushAndWait()` after
`destroySwapChain` in `onDetachedFromSurface` a requirement: "otherwise
Android might destroy the Surface too early". After the fix, the new log
line shows the driver really was still busy when the callback would have
returned. Across 49 surface destroys the drain took **min 34 ms, median
72 ms, max 239 ms**.

## Fix (Dart3dView.kt)

- `destroySwapChainAndWait()`: destroys the swapchain, then calls
  `engine.flushAndWait()` and logs the drain time. `onDetachedFromSurface`,
  `onNativeWindowChanged` (for any old swapchain, before the create) and
  `release()` all use it.
- `render()` returns early unless `uiHelper.isReadyToRender`.

## Warm relaunch loops (fixed head)

Each iteration first checks that the example is the resumed activity, then
runs `input keyevent KEYCODE_HOME`, sleeps `DELAY`, runs
`monkey -p com.jasonholtdigital.dart3d_example -c android.intent.category.LAUNCHER 1`,
sleeps 5 s, and then checks the pid (same pid = warm) and the foreground.
`logcat -c` and `logcat -b events -c` are run before each loop, and both
buffers are captured for its whole duration.

Count commands (per loop capture):

```
grep -c 'Fatal signal'       logcat.txt
grep -c 'FATAL EXCEPTION'    logcat.txt
grep -c ' E AndroidRuntime'  logcat.txt
grep -c am_crash             events.txt     # adb logcat -b events
grep -c 'swapchain destroyed (surface destroyed)' logcat.txt
grep -c 'swapchain created'  logcat.txt
grep -c 'vkCreateSwapchain'  logcat.txt
```

| Loop | Backend | Scene | Gap | Relaunches (same pid, fg) | Fatal signal | FATAL EXCEPTION | E AndroidRuntime | am_crash | destroyed / created / vkCreateSwapchain |
|---|---|---|---|---|---|---|---|---|---|
| base-vk (unfixed) | Vulkan | Dice | 2 s | 2/2 | 0 | 0 | 0 | 0 | – / – / 2 |
| base-vk-dash (unfixed) | Vulkan | Showcase dash | 2 s | 3/3 | 0 | 0 | 0 | 0 | – / – / 3 |
| **base-vk-fast (unfixed)** | Vulkan | Showcase dash | 0.3 s | **0/1 (crash)** | 0 | **1** | **22** | **3**¹ | – / – / 0 |
| fix-vk-fast | Vulkan | Dice | 0.3 s | **10/10** | 0 | 0 | 0 | 0 | 10 / 10 / 10 |
| fix-vk-dash | Vulkan | Showcase dash | 2 s | **10/10** | 0 | 0 | 0 | 0 | 10 / 10 / 10 |
| fix-vk-dash-fast | Vulkan | Showcase dash | 0.3 s | **10/10** | 0 | 0 | 0 | 0 | 9² / 10 / 10 |
| fix-gl-fast | GL | Dice | 0.3 s | **10/10** | 0 | 0 | 0 | 0 | 10 / 10 / n/a |
| fix-gl-dash | GL | Showcase dash | 2 s | **10/10** | 0 | 0 | 0 | 0 | 10 / 10 / n/a |

¹ The count is 3 lines because one multi-line `am_crash` record is split
across 3 lines; it is one crash.
² In iteration 4, the capture is missing the `swapchain destroyed` line and
also Android's own `BLASTBufferQueue ... destructor()` line from the same
millisecond, so logcat dropped those lines. The destroy did run: the
following `swapchain created` has no `(native window changed)` destroy in
front of it, so `swapChain` was already null. That iteration relaunched
warm with no crash.

Excerpt (fix-vk-fast, iteration 1):

```
09-29 08:16:23.342 ActivityTaskManager: START ... cat=[android.intent.category.HOME] ...
09-29 08:16:23.839 dart3d  : dart3d view 3 swapchain destroyed (surface destroyed); driver drained in 57ms
09-29 08:16:23.977 ActivityTaskManager: START ... cat=[android.intent.category.LAUNCHER] ...
09-29 08:16:24.014 dart3d  : dart3d view 3 swapchain created
09-29 08:16:24.065 Filament: vkCreateSwapchain: 1084x2412, 37, 0, swapchain-size=8, ...
```

Screenshots after relaunch (the scene renders): `vk-dice-relaunch-01.png`,
`vk-dice-relaunch-10.png`, `vk-dash-relaunch-10.png`,
`gl-dice-relaunch-10.png`, `gl-dash-relaunch-10.png`.

## T2 smoke (fixed head, fresh `dn run` per backend)

The run boots to Dice, then switches to Harness and waits for
`w18 lane complete`, then switches to Dice and taps ROLL, then switches to
Showcase (dash). The tab switches also exercise the view release path:
`uiHelper.detach()` → `onDetachedFromSurface` → drain.

| Backend | w18 lane complete | Dice roll result | Dash | Fatal signal | FATAL EXCEPTION | E AndroidRuntime | am_crash | `E dart3d` |
|---|---|---|---|---|---|---|---|---|
| Vulkan | 08:34:54.367 | `rolled d4:3 d6:5 d8:1 d10t:50 d10u:8 d12:9 d20:14 d%:58 · total 90` | `showcase — dash: 41 nodes · 2 geo · 2 mat · 2 tex · 1 skins · 9 anims` | 0 | 0 | 0 | 0 | 0 |
| GL | 08:28:19.934 | `rolled d4:3 d6:2 d8:3 d10t:70 d10u:1 d12:3 d20:18 d%:71 · total 100` | same | 0 | 0 | 0 | 0 | 0 |

The `rolled` line is logged when the die settles. The harness's W25
close-out still reports `dice regression FAIL: ... no settle event within
10 s`. That result is known and pre-existing
(`docs/triage/integration.md`, "W25 dice-regression close-out FAILs on
every surface") and is unrelated to this change.

Screenshots: `t2-{vk,gl}-harness-w18.png`, `t2-{vk,gl}-dice-roll.png`,
`t2-{vk,gl}-dash.png`.

## Not run

- **Rotation:** this needs `settings put system user_rotation`, which is a
  change to system settings on the device, so it was not done.
- **Screen off/on:** the A142 keyguard is secure (`dumpsys window`:
  `secure=true`). Waking the device would leave it on a PIN lock screen that
  the agent cannot dismiss, so this was not done.

Both paths go through the same `surfaceDestroyed` → `onDetachedFromSurface`
→ `surfaceCreated` → `onNativeWindowChanged` sequence that the relaunch
loops cover above.

## T1

- `dn analyze`: clean in `dart3d/` and `dart3d/example/`.
- `dn test`: 273/273 in `dart3d/` and 126/126 in `dart3d/example/`.
- `./gradlew :dart3d:compileReleaseKotlin --rerun` (from
  `dart3d/example/android`, `FLUTTER_STORAGE_BASE_URL=https://cdn.dartnative.com`):
  BUILD SUCCESSFUL. The only warning is the existing `filterWidth`
  deprecation at Dart3dView.kt:1486, which this change does not touch.
