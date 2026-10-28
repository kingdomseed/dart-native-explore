# Android native shadow defaults

The [controlled A142 comparison](../catcher-prototype/android-split-culling/README.md)
shows missing directional shadow data with the current adapter options and
restored shadow data with native defaults. Source search found two zeroed
`ShadowOptions()` constructors in production, in component-light decoding and
stage-sun creation.

The installed 1.77.3 Java API exposes native option retrieval and update.
The correction builds the light, reads its native options, applies
existing authored overrides, and writes the options back. It preserves the
existing map tiers, cascade rules, bias precedence, contact fields, and softness
mapping. No copied default table, new wire command, or renderer change is needed.

## Production baseline

The parent built the current production fixture with `DART3D_MODEL=u2-catcher`,
`DART3D_CATCHER_LIGHT=directional`, and Vulkan. `before-apk.json` identifies the
saved APK. `parent-before-build.log` records the successful release build.

`before-native.log` confirms Vulkan and zeroed native option fields, including
cascade count 0, constant bias 0, and normal bias 0. The Android decoder also
warns that catcher mode and softness are unsupported. This baseline uses the
existing live catcher path; it is not Android baked-cache proof.

`before-directional-catcher.png` records the initial production view. The
landscape footer covers part of the ground area. The controlled probe is the
decisive visibility comparison; any final production image comparison must
expose the footprint rather than rely on this obscured region.

The baseline app and log capture stopped. The test-app PID was absent and
the launcher was foreground.

## Native option round trip

The first read-modify-write correction builds and runs on A142 Vulkan, but
does not preserve the native shadow rotation. A temporary diagnostic reads
the options again immediately after the setter. [The native log](roundtrip-native.log)
records `before=[0.0, 0.0, 0.0, 1.0] after=[0.0, 0.0, 1.0, 0.0]`.
The diagnostic was removed after the run. The app and log capture stopped.

The pinned [JNI setter](https://github.com/google/filament/blob/v1.77.3/android/filament-android/src/main/cpp/LightManager.cpp#L334)
passes X, Y, Z, W to a quaternion constructor whose four-scalar arguments
are [W, X, Y, Z](https://github.com/google/filament/blob/v1.77.3/libs/math/include/math/quat.h#L95).
The getter exposes X, Y, Z, W. The observed identity-to-half-turn change
matches that ordering mismatch. Both production setter sites reach this path.

Filament's [1.79.0 release notes](https://github.com/google/filament/blob/main/RELEASE_NOTES.md)
list fixes for quaternion JNI support and Java structure defaults.
The current project remains pinned to 1.77.3. The first corrected Vulkan
image has dark caster-face patches. `incorrect-roundtrip-vulkan.png` preserves
that failed intermediate result.

## Corrected transport and final replay

`ShadowOptionsAdapter.kt` reorders the transport values for the pinned JNI
setter and restores the caller's decoded rotation in `finally`. Both component
lights and the stage sun use that boundary. Existing quality and authored
overrides remain at their original owners.

The parent tested identity, a normalized non-identity quaternion, the same
non-identity quaternion again, and identity again on the physical A142.
`roundtrip-corrected-native.log` records all four native and caller values
matching their literal expected components. The temporary assertions and logs
were removed before the final release builds.

The parent built and ran final Vulkan and OpenGL APKs from the source recorded
in `source-sha256.txt`. `final-apk-sha256.txt` identifies both saved binaries.
The `after-<backend>-build.log`, `after-<backend>-run.log`, and
`after-<backend>-native.log` files record those runs. Vulkan reports `pref=2`;
OpenGL reports `pref=1`. Both report cascade count 1, constant bias 0.001,
normal bias 1, and bulb radius -1. Neither collected native log contains a
fatal marker.

`before-vulkan.png` and `after-vulkan.png` use the initial fixture pose.
The final Vulkan view shows a ground shadow and clean caster faces.
`before-opengl.png` and `after-opengl.png` also use the initial pose, but
the final OpenGL view still lacks the visible ground footprint. The missing
OpenGL footprint remains open. The footer obscures part of the receiver in
both lanes. These captures do not establish Android baked-cache behavior;
the native decoder still reports mode and softness as unsupported.

The worker's existing JVM run reports 159 tests, 144 passing and 15 expected
native-physics skips, with zero failures. `worker-android-unit-tests.log`
records that run. The parent's final builds and native round-trip checks
are separate evidence. A comment audit accepted one narrative-line deletion
and retained the verified external ABI constraint. The
[independent Codex Luna review](t3-thread://v1/thread:delegated-task:command%3Amcp%3Ad12b24be-d1fd-4c7a-88e7-3520d53747f6%3Adelegate-task%3Ae5-shadow-defaults-codex-review-luna-r1-20261026)
reports PASS with no material reachable P1 or P2 defects. The reviewer verified
all four source hashes, the pinned JNI path, and the supplied artifacts.
Independent builds and device execution were NOT_RUN. The review leaves the
missing OpenGL footprint open and identifies no scoped backend branch that
explains it.

Both app runs and log captures stopped. The app PID was absent and the
launcher was foreground. Android baking, issue #59 material capability,
the final E5 matrix, and operator review remain open.

The later [catcher material correction](../android-catcher-instancing/README.md)
reproduces the instance-color crash and restores the direct OpenGL footprint
with the corrected instancing recipe. That later result closes the missing
OpenGL footprint observation above. Android shadow-footprint caching remains
open.
