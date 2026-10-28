# Android instanced shadow catcher

The parent reproduced [issue #59](https://github.com/kingdomseed/dart-native-explore/issues/59)
on A142 OpenGL, then verified the recipe correction on OpenGL and Vulkan.
The [independent Codex Luna review](t3-thread://v1/thread:delegated-task:command%3Amcp%3Ad12b24be-d1fd-4c7a-88e7-3520d53747f6%3Adelegate-task%3Ae5-catcher-instancing-codex-review-luna-r1-20261026)
reports PASS with no material reachable P1 or P2 defects in the GPU instancing
path. The reviewer verified all six source and asset hashes, both final APKs'
package hashes, and the supplied receipts. Independent builds, tests, and
device execution were NOT_RUN. CPU-baked instances, billboards, shadow-cache
behavior, numeric alpha calibration, and full E5 remain outside that verdict.

## Before and after

The existing `D3InstancesSpec` color path uploads `useInstanceColors` and
`instanceColors`. The old catcher recipe declares neither parameter and
does not enable instancing. `before-native.log` records the resulting
`FATAL EXCEPTION: main` and `uniform named "useInstanceColors" not found`.
`before-run.log` records the same failure after the instance-color fixture
loads. The app process exits.

The corrected recipe enables instancing, declares the existing color
parameters, and applies the selected instance color. Without a color
attribute, the shader uses white and preserves the existing catcher output.
No decoder fallback or parameter guard was added.

The boot selector `DART3D_CATCHER_PATH=instance-color` adds one white instance
color with alpha 0.65. The first corrected OpenGL run compiles the actual
catcher package on the device and stays open. `after-color-opengl.png` shows
the receiver shadow. Its native and run logs record that execution.

The final OpenGL direct run uses the existing no-color fixture.
`after-direct-opengl.png` shows a ground footprint that is absent from the
[previous direct capture](../android-shadow-defaults/after-opengl.png).
The camera, caster, light, and receiver document remain the same. The recipe
and its compiled package changed.

The final Vulkan run uses the instance-color fixture. `after-color-vulkan.png`
shows the shadow, and the app stays open. Native logs identify OpenGL
`pref=1` and Vulkan `pref=2`. Searches found no fatal marker or exception
in these three corrected native logs. The footer still obscures part of
the receiver; these images do not prove numeric alpha scaling.

## Compiled material packages

The parent ran the documented `tool/bake_materials.sh` on A142 after a licensed
`dn run`. `material-bake.log` records all 20 fixed packages exported for the
two APIs. This operation compiles Filament shaders. It does not create a
scene's baked shadow-footprint cache.

Only the catcher fingerprints changed. The two obsolete catcher packages
were removed and their replacements added. The other 18 package files are
unchanged. The material index records the new catcher keys.

| API | Previous fingerprint | New fingerprint |
|---|---|---|
| OpenGL | `1342357f473c4aab8e784cabdc800396` | `a6c36160f5f0568764dc9efb11790f06` |
| Vulkan | `77e7fda09aae89c9fb1b18c38c1e9823` | `ec4af1b844d62e3a687de67e22828147` |

Both final APKs contain the rebuilt packages. The parent compared the two
package byte hashes inside the final Vulkan APK with the repository files;
both match. `source-assets-sha256.txt` records the three changed source files,
the index, and both packages. `apk-sha256.txt` identifies the before, runtime
compile, and final saved APKs. Filament remains pinned to 1.77.3.

## Checks and remaining work

The parent ran the repository's `:dart3d:testReleaseUnitTest` task after the
package bake. All 144 active tests pass, including the 11 material-package
tests and three shipped-material tests. Fifteen opt-in native-physics tests
are skipped. `android-tests.log` and the two material test XML files record
those results. This release task did not encounter the worker's Debug
transform-cache failure; no shared cache was removed or repaired.

The selected fixture passes nine parent Dart tests and example analysis is
clean. `fixture-tests.log` and `analyze.log` record those checks. Both final
release builds pass. The comment audit reports no changed comments or
suppressions and no findings.

The app runs, log streams, and material bake have stopped. The app PID was
absent and the launcher was foreground. The Android decoder still reports
shadow-catcher mode and softness as unsupported. Android baked cache, blur,
explicit refresh, the final E5 device matrix, and operator review remain open.
