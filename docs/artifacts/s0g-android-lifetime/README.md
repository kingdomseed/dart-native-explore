# S0g: native object lifetime on Android (2026-10-05)

Release builds, `dn run -d <serial> --release` from `dart3d/example`.
"Before" is `main` at `f6b8883`; "after" is this branch. The audit
tables (every jolt-jni object and every Filament creation site, with
what was checked) are in `docs/triage/android.md` §S0g native object
lifetime.

## Result

- **`main` runs out of Java heap after 22 visits to the dice screen**
  on the Fire tablet (`OutOfMemoryError`, 128 MB limit). This branch
  completes 50 visits and 200 rolls with the Java heap at 17 MB.
- **jolt-jni: 22 creation sites never released what they own**, all on
  the scene-load path (body settings, collision groups, every shape and
  shape-settings wrapper, the three wrappers behind each
  `create().get()`, mesh triangles), plus one per raycast hit. They are
  closed deterministically now. With the framework leak below taken out
  of the picture, 50 loads and 200 rolls leave the native heap **+4.4
  MB** where `main` leaves it **+18.5 MB**.
- **Rolling never leaked**, before or after: across 200 rolls the
  native heap stays within 2.2 MB on both builds with no trend. Nothing
  owning is created per roll or per frame.
- **The real app's memory still grows per visit, and that is not
  closed.** Two causes outside the plugin's native code were found; see
  *What still grows*.
- Three Filament use-after-destroy or leak paths fixed and all 31
  builder sites fenced; no frame-rate change on the three devices
  on their default backends.

## How it was measured

`dart3d/tool/native_heap_soak.sh` (new). It drives the app with `adb
input` (hero → "Roll the dice" → Back, then the Roll button every 3 s)
and samples `dumpsys meminfo` on the hero screen every 10 loads and on
the dice screen every 25 rolls, 3 s after the last input. It waits on
the plugin's own log lines for each transition and stops if anything
but the example is in the foreground. Columns, in MB:

- **native alloc**: the `Native Heap` row's `Heap Alloc`, malloc'd
  bytes. This is where a jolt-jni or Filament leak shows.
- **Java alloc**: the `Dalvik Heap` row's `Heap Alloc`.
- **total PSS**: everything, including graphics memory and the Dart
  heap.

Device: Fire KFTUWI, Android 11 (API 30), where jolt-jni has no
Cleaner. `GPU: Mali-G52 MC2`, `Filament engine backend: OPENGL (pref=0,
tier=LOW)`.

A single sample moves by about ±4 MB of native alloc from one run to
the next (Filament's engine is built and torn down twice per visit).
The matched points are the first sample and the last one, both on the
hero screen.

## The real app

`main` (`soak-main.csv`):

| Loads | Native alloc | Java alloc | Total PSS |
|---|---|---|---|
| 0 | 66.7 | 14.5 | 408 |
| 10 | 71.5 | 63.7 | 489 |
| 20 | 78.4 | 112.7 | 610 |
| 22 | crash: `OutOfMemoryError` allocating a texture buffer | | |

This branch (`soak-after.csv`; both runs start after one earlier dice visit):

| Phase | Count | Native alloc | Java alloc | Total PSS |
|---|---|---|---|---|
| loads | 0 | 63.2 | 9.8 | 332 |
| loads | 10 | 70.1 | 11.5 | 435 |
| loads | 20 | 83.0 | 12.9 | 523 |
| loads | 30 | 84.3 | 14.3 | 566 |
| loads | 40 | 91.2 | 15.7 | 622 |
| loads | 50 | 98.0 | 17.1 | 697 |
| rolls | 0 | 100.4 | 19.7 | 720 |
| rolls | 50 | 101.5 | 19.7 | 693 |
| rolls | 100 | 101.5 | 19.8 | 687 |
| rolls | 150 | 101.2 | 19.9 | 693 |
| rolls | 200 | 101.6 | 19.9 | 688 |
| end (hero) | 50 + 200 | 104.7 | 17.3 | 684 |

Java heap: 4.9 MB per visit before, 0.15 MB after. Native alloc still
climbs about 0.7 MB per visit and total PSS about 7 MB per visit.
Neither is the plugin's own allocation; the next section isolates
that.

## The plugin's own share

A heap dump (taken in-process with `Debug.dumpHprofData` on a
temporary build, then walked for GC-root paths) shows what keeps the
released views alive:

```
android.view.SurfaceView
 <- Dart3dView
 <- DNView.mChildren
 <- DNView.mParent          (hero screen root)
 <- android.widget.ScrollView.mParent
 <- DNView.mParent          (the scroll view's content)
 <- HashMap entry
 <- DNViewRegistry.views    (static)
```

DartNative's view registry keeps the content view of the hero screen's
`SingleChildScrollView` after the screen is unmounted. Through
`mParent` that one entry holds the whole hero view tree, 31 views per
visit, including the released `Dart3dView`. `dumpsys meminfo` counted
1654 live `View`s at the end of the run above. The dice screen has no scroll view
and its trees are collected.

So the measurement was repeated on builds whose only difference from
the app is that the hero's `SingleChildScrollView` is replaced by a
`SizedBox` (not committed; the layout is identical on this tablet).
`View` count stays at 40.

| | `main`, no scroll view | This branch, no scroll view |
|---|---|---|
| Native alloc, start | 58.8 | 60.1 |
| after 10 / 20 / 30 / 40 / 50 loads | 69.2 / 67.1 / 79.4 / 81.8 / 83.6 | 63.9 / 69.5 / 65.7 / 70.3 / 71.1 |
| Least-squares slope over the loads | 0.50 MB per load | 0.20 MB per load |
| over rolls 25–200, min–max | 74.8–75.6 | 67.6–69.8 |
| End (hero again, after 50 loads and 200 rolls) | 77.3 | 64.5 |
| **End minus start** | **+18.5** | **+4.4** |
| Java alloc, start → end | 9.3 → 9.9 | 9.2 → 9.9 |
| Total PSS, start → end | 308 → 984 | 298 → 634 |

`soak-controlled-before.csv`, `soak-controlled-after.csv`.

Reading it: the +18.5 MB on `main` is the jolt-jni leak (two realizes
per visit, 13 bodies each, seven of them convex hulls). After the fix
the end state is +4.4 MB above the start, which is inside what one
sample moves by, and the first visit also loads material variants that
stay cached. A remaining slope below about 0.1 MB per load cannot be
ruled out from this data; the per-10 samples alone would suggest 0.2.
It is not flat to the precision the plan asked for, and it is not
attributed.

## What still grows

1. **The framework keeps the hero's view tree** (above). Each visit
   leaves 31 Android views and whatever native state they hold. That is
   the 0.7 MB per visit of native alloc in the real app and part of the
   PSS. The plugin's part of the cost is now small: a released view
   drops its payloads, manifest, journal and LUT buffers, which was 4.8
   MB of Java heap per hero view and what ran `main` out of memory. The
   retention itself is in DartNative (`dartnative_android` stamp
   2026-07-20-3). A newer framework build is offered by `dn upgrade`;
   it was not tried.
2. **The Dart heap grows per visit.** With no view leaking at all,
   total PSS still rises about 7 MB per visit on this branch and about
   13 MB on `main`, in `meminfo`'s `Unknown` row. `/proc/self/smaps` read
   in-process puts it in unnamed anonymous mappings whose sizes are
   multiples of 512 kB, which is the Dart VM's old-space page size.
   Disposing the scene controller in the example's screens and making
   `SceneController.dispose()` release its document (both in this PR)
   halved it. What keeps the rest is not known: a release build has no
   Dart heap tooling, and nothing in the example's code holds a screen
   after it is popped. At this rate the Fire tablet (2.9 GB) reaches 1
   GB of PSS after about 100 visits.

Both show on the A142 too: the same heap-dump path, and Java heap 11 →
46 MB over 6 visits on `main`.

## T2 and frame rate

Complete: the final head's code on all three devices, the A142 on both
backends. Each run from a fresh launch: hero 30 s, dice racked 30 s,
12 rolls 3 s apart, settle; then the harness
(`DART3D_SCENE=harness`) to `w18 lane complete`. Frame rates from the
`dart3d.perf` log, first 2 s window dropped; baseline from
`docs/artifacts/s0-three-device-baseline/` in brackets. 0 FATAL in
every run.

| Device | Backend, tier | Hero | Dice racked | Dice rolling | Harness |
|---|---|---|---|---|---|
| Fire KFTUWI (Mali-G52 MC2) | OPENGL, LOW | 55.9 (55.0) | 44.6 (44.2) | 43.9 (43.7) | complete |
| Wacom DTHA116 (Mali-G57 MC2) | OPENGL, LOW | 57.7 (57.5) | 51.6 (51.2) | 45.1 (44.1) | complete |
| Nothing A142 (Mali-G610 MC4) | VULKAN (pref=0), STANDARD | 89.6 (89.7) | 49.7 (49.7) | 50.2 (50.3) | complete |
| Nothing A142, `DART3D_BACKEND=opengl` | OPENGL (pref=1), STANDARD | 81.1 | 31.9 | 31.9 | complete |

- The Fire tablet ran `d711581`; the Wacom and the A142 ran the final
  head. The commit between them changes the soak script and three CSV
  files, nothing that ships.
- **The A142 on forced OpenGL has no baseline**: it was not measured
  before today. Its 32 fps on the dice screen is 18 fps below the same
  phone on Vulkan. The review follow-ups branch, which has none of
  this PR's code, measures the same on that lane
  (`docs/artifacts/s0-codex-followups/`), so it is how the standard
  pipeline runs on that driver's OpenGL, not something this PR did.
  Nobody is put on that path by default: the A142 resolves to Vulkan.
- An earlier head (`75e9bbd`) was also run on all three devices with
  the same results within 1 fps, the Wacom twice (hero 54.3 and 58.1).
- The harness's `w25` dice close-out reports FAIL in every run here,
  as it does on `main`; that is the other S0g unit's subject.

Screens: `fire-*.jpg`, `wacom-*.jpg`, `a142-vulkan-*.jpg`,
`a142-opengl-*.jpg` (hero, dice, settled), `*-harness*.jpg`.

## Checks

- `dn analyze` and `dn test`: `dart3d` 277 tests, `dart3d/example` 227
  tests, clean.
- `:dart3d:testReleaseUnitTest`: 118 tests pass, 14 new
  (`NativeScopeTest`, `CollisionSubGroupsTest`, `FencedTest`).
- `:dart3d:lintRelease`: 8 `NewApi` errors on `main` (the eight
  `reachabilityFence` calls in `JoltWorld.update`), 0 on this branch.
- No test covers the jolt-jni calls themselves (they need the native
  library); the device runs above are the evidence for those.

## Open

- Memory per visit in the real app, both causes above.
- A residual native slope under about 0.1 MB per load is not excluded.
- API 26 and 27 were not run: the `reachabilityFence` fix in
  `JoltWorld.update` and the fallback fence are verified by the release
  dex and by lint only.
- The Filament hazards listed as not fixed in
  `docs/triage/android.md`.
- A deliberately debuggable build cannot be used for heap dumps: the
  engine then expects a JIT snapshot and aborts at start. The dump here
  came from `Debug.dumpHprofData` in a temporary build, pulled from the
  A142 (the Fire tablet denies `adb` access to the app's external
  files).
