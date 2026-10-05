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
| #49 | 4180998566, T2 gaps (Wacom harness, A142 OpenGL) | **Partly closed.** See below. |

## The T2 gaps from #49

#49 skipped the harness on the Wacom and the A142 on OpenGL. The A142
and the Wacom were lent to another project while this was being done,
so:

| Lane | State |
|---|---|
| A142, OpenGL forced, harness | Run on #50's first head (`75e9bbd`, which contains #49): to `w18 lane complete`, 0 FATAL, `GPU: Mali-G610 MC4`, `Filament engine backend: OPENGL (pref=1, tier=STANDARD)`. `docs/artifacts/s0g-android-lifetime/a142-harness-opengl.jpg` in that PR. Not run on `main` itself. |
| A142, OpenGL forced, boot / hero / dice / roll | **Not run.** |
| Wacom, harness | **Not run.** |
| Fire tablet, harness | Run on this branch: to `w18 lane complete`, 0 FATAL, `GPU: Mali-G52 MC2`, `Filament engine backend: OPENGL (pref=0, tier=LOW)`. `fire-harness.jpg`. |

From here on every native PR runs A142 Vulkan, A142 OpenGL, the Fire
tablet and the Wacom, each with the harness.

## This branch on the Fire tablet

Fresh launch, hero 30 s, dice racked 30 s, 12 rolls 3 s apart, settle;
0 FATAL. Baseline from `docs/artifacts/s0-three-device-baseline/` in
brackets.

| Hero | Dice racked | Dice rolling |
|---|---|---|
| 56.0 fps (55.0) | 44.6 fps (44.2) | 44.2 fps (43.7) |

The `submit` column of the perf log, mean of the per-window figures on
the dice screen, against a run of the old sampling point the same hour
(#50's branch, which does not touch it):

| | Old sampling point | This branch |
|---|---|---|
| Racked, p50 / p95 | 3.34 / 5.55 ms | 2.99 / 5.39 ms |
| Rolling, p50 / p95 | 1.52 / 3.33 ms | 1.42 / 3.22 ms |

One run each, so the 0.1–0.35 ms difference is an indication of what
the history read cost, not a measurement of it.

The A142 and the Wacom were not run on this branch.
`fire-hero.jpg`, `fire-dice.jpg`, `fire-settled.jpg`.

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

**The script itself was not run end to end.** On the Fire tablet `adb`
has no access to the app's external files, so the script stops at its
first `rm` there, as it did before this change; the A142, where bakes
have been run, was not available. Not exercised on a device: the
`am start` launch from the script, the wait loops, the pull and the
copy. `sh -n` passes, and the `am start` resolution is the block
`cold_start.sh` has used since #49. A rejected recipe was not provoked
on a device; `BakeProgressTest` covers the line it produces.

## Checks

- `dn analyze` and `dn test`: `dart3d` 277 tests, `dart3d/example` 227
  tests, clean (no Dart changed).
- `:dart3d:testReleaseUnitTest`: 108 tests pass, 4 new
  (`BakeProgressTest`).
- `sh -n` on both scripts.
- `:dart3d:lintRelease` still reports the eight `NewApi` errors `main`
  has in `JoltWorld.update`; #50 fixes those.
