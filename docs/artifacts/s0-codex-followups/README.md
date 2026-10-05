# Review follow-ups on #47, #48 and #49 (2026-10-05)

Codex left inline comments on these merged PRs that never got a
verdict. Each was checked against `main` at `f6b8883`. The ones on #44
and #49's `GpuProbe` are answered in the S0g lifetime PR (#50), the
ones on #45 in the S0g re-realize PR (#52).

## Verdicts

| PR | Thread | Verdict |
|---|---|---|
| #47 | 4164283150, `submit` time includes the frame-history read | **Fixed.** The time is taken right after `render()`, before the JNI history copy and the sort. |
| #47 | 4164283141, an explicit `quality` on a low-tier device stays on OpenGL | **Dismissed, documented behaviour.** `dart3d/README.md` ("Backend: `auto` resolves to OpenGL, whatever `quality` is. Only the backend pref … overrides it") and the `SceneQuality` doc comment say so in as many words. Honouring it is not cheap: the engine, and so the backend, is built in the view's constructor, and `quality` arrives in the first `viewConfig` mutation afterwards; `createView(typeIndex)` takes no parameters. It would mean building the engine on the first mutation instead, with every field that is created from it. An app that wants Vulkan on such a device sets the backend preference. |
| #47 | 4164283143, an authored `renderScale: 1.0` treated as unset | **Already fixed** in `686bbce`: `DeviceProfile.renderScale` takes the view entry's and the stage's scale as nullable and treats any authored value as fixed, 1.0 included. One limit remains and is documented there and in the README: the upstream codec leaves a stage scale of 1.0 off the wire, so on a LOW device a stage cannot pin 1.0; a view entry's `renderScale` or a `SceneQuality` can. |
| #48 | 4166471759, `cold_start.sh` checks the foreground once | **Fixed.** The check runs before every timed launch. |
| #48 | 4166383738, `bake_materials.sh` foreground guard | Guard: **already fixed** on `main`. It still launched with `monkey`, which switches auto-rotate on: **fixed**, it resolves the launcher activity and uses `am start`, as `cold_start.sh` does. No script in `dart3d/tool` runs `monkey` now. |
| #48 | 4166383752, the bake reports success with a rejected recipe | **Fixed.** The app logs `bake: fixed set exported (N packages)` only when filamat accepted every recipe; otherwise `bake: fixed set INCOMPLETE (… filamat rejected: <keys>)` at error level. The script copies nothing and exits 1 on that line or on `bake failed`. |
| #48 | 4166383761, the pull can race a variant compile | **Fixed.** The app logs `bake: variants compiling (n in flight)` when a variant is queued and `bake: variants idle` when the lane is empty; the script waits until the last of those lines is the idle one (up to 5 minutes, then exits 1 without copying). |
| #48 | 4166383748, stale app variants | **Already fixed** on `main`: the script lists the app's `.filamat` files that the new bake did not produce (`list_stale` over the app directory). It reports and does not delete. |
| #49 | 4180998566, T2 gaps (Wacom harness, A142 OpenGL) | **Closed.** See below. |

## Review thread on this PR

| Thread | Verdict |
|---|---|
| 4184387488, `variants idle` can be logged after a newer `variants compiling` | **Real, fixed.** The count was decremented and the idle line written in two steps, so a compile queued in between could log `compiling` first and leave `idle` as the last line while it was still running; the script trusts the last line. `BakeProgress` now changes the count and writes its line under one lock, for both transitions. A test runs 400 start/finish pairs on 8 threads with one compile held in flight and checks that `idle` is never written. |
| 4184508149, a variant queued between the idle reading and the pull | **Real, fixed in the script.** Once the lane reads idle the script force-stops the app, so nothing new can start, then reads the log once more; if a compile had begun in that gap (and was cut off by the stop) it exits 1 without copying. The pull then reads a directory nothing is writing to. The failing branch was not provoked on a device. |

## The T2 gaps from #49

#49 skipped the harness on the Wacom and the A142 on OpenGL. Both are
run on this branch, which is `main` plus the changes above (and so
contains #49's GPU probe and tier rule):

| Lane | Result |
|---|---|
| A142, `DART3D_BACKEND=opengl`: boot, hero, dice, 12 rolls and settle | 0 FATAL. `GPU: Mali-G610 MC4`, `Filament engine backend: OPENGL (pref=1, tier=STANDARD)`. Hero 80.9 fps, dice racked 31.7, rolling 31.9. `a142-opengl-*.jpg`. |
| A142, `DART3D_BACKEND=opengl`: harness | To `w18 lane complete`, 0 FATAL. `a142-harness-opengl.jpg`. |
| Wacom: harness | To `w18 lane complete`, 0 FATAL, `GPU: Mali-G57 MC2`, `OPENGL (pref=0, tier=LOW)`. `wacom-harness.jpg`. |
| Fire tablet: harness | To `w18 lane complete`, 0 FATAL, `GPU: Mali-G52 MC2`, `OPENGL (pref=0, tier=LOW)`. `fire-harness.jpg`. |

**Seen on the A142's forced-OpenGL lane, first time it has been
measured:** the dice screen runs at 32 fps there against 50 on the same
phone's Vulkan. Both S0g branches measure the same 32, so it is how
the standard pipeline runs on that driver's OpenGL today, not a change
from any of these PRs. The A142 resolves to Vulkan by default, so only
a forced backend lands there. Not looked into.

From here on every native PR runs A142 Vulkan, A142 OpenGL, the Fire
tablet and the Wacom, each with the harness.

## This branch on all three devices

Fresh launch, hero 30 s, dice racked 30 s, 12 rolls 3 s apart, settle,
then the harness to completion; 0 FATAL everywhere. fps, baseline from
`docs/artifacts/s0-three-device-baseline/` in brackets.

| Device | Backend, tier | Hero | Dice racked | Dice rolling | Harness |
|---|---|---|---|---|---|
| Fire KFTUWI | OPENGL, LOW | 56.0 (55.0) | 44.6 (44.2) | 44.2 (43.7) | complete |
| Wacom DTHA116 | OPENGL, LOW | 57.8 (57.5) | 51.6 (51.2) | 44.9 (44.1) | complete |
| Nothing A142 | VULKAN (pref=0), STANDARD | 89.8 (89.7) | 49.6 (49.7) | 50.1 (50.3) | complete |
| Nothing A142, forced OpenGL | OPENGL (pref=1), STANDARD | 80.9 | 31.7 | 31.9 | complete |

The `submit` column of the perf log on the Fire tablet, mean of the
per-window figures on the dice screen, against a run of the old sampling point the same hour
(#50's branch, which does not touch it):

| | Old sampling point | This branch |
|---|---|---|
| Racked, p50 / p95 | 3.34 / 5.55 ms | 2.99 / 5.39 ms |
| Rolling, p50 / p95 | 1.52 / 3.33 ms | 1.42 / 3.22 ms |

One run each, so the 0.1–0.35 ms difference is an indication of what
the history read cost, not a measurement of it.

`fire-*.jpg`, `wacom-*.jpg`, `a142-vulkan-*.jpg`, `a142-opengl-*.jpg`
(hero, dice, settled), `*-harness*.jpg`.

## The bake script

The app's side was run on the Fire tablet with the bake tag set
(`bake-log-fire.txt`):

```
10:51:27.515 bake: exporting material packages to /storage/emulated/0/Android/data/com.jasonholtdigital.dart3d_example/files/dart3d-materials
10:51:27.684 Filament engine backend: OPENGL (pref=0, tier=LOW)
10:51:45.254 bake: variants compiling (1 in flight)
10:51:59.300 bake: variants idle
10:52:18.520 bake: fixed set exported (20 packages)
```

**End to end on the A142**, three times: before the two review fixes
above, after the first, and on the final head (`bake-run-a142.txt`):

```
tool/bake_materials.sh 00064149A002033 \
  --app-assets example/android/app/src/main/assets --wait 20
```

Exit 0 each time. It launched with `am start`, saw `variants compiling` then
`variants idle` then `fixed set exported (20 packages)`, pulled 23
files, and wrote 20 plugin packages and the app's 2 variants. **All 22
`.filamat` files came out byte-identical to the committed ones** (`git
status` shows none of them modified). The only difference was the
first line of `index.txt` and `variants.txt`, which records the source
commit (`87bf3ed` → this branch's); those two files were put back, so
nothing regenerated is committed. Auto-rotate on the phone read 1
before and after.

Not provoked on a device: a recipe filamat rejects, and a pull that
has to wait on a long variant compile. `BakeProgressTest` covers the
lines both produce. On the Fire tablet the script cannot run at all:
`adb` has no access to the app's external files there.

## Checks

- `dn analyze` and `dn test`: `dart3d` 277 tests, `dart3d/example` 227
  tests, clean (no Dart changed).
- `:dart3d:testReleaseUnitTest`: 109 tests pass, 5 new
  (`BakeProgressTest`).
- The device runs above are on `0a59fdf`'s code. The final head
  differs from it only in `BakeProgress` and the two call sites that
  are behind the bake flag, which is off unless the bake log tag is
  set, and in `bake_materials.sh`, so those runs stand for it; the
  bake itself was rerun on the final head.
- `sh -n` on both scripts.
- `:dart3d:lintRelease` still reports the eight `NewApi` errors `main`
  has in `JoltWorld.update`; #50 fixes those.
