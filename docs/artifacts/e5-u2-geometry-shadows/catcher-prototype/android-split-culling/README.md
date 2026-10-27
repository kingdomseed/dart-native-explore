# A142 caster-culling and shadow-default comparisons

The parent ran all four R3 cases on the physical A142 with Vulkan on
2026-10-26. The RGB diagnostic now excludes caster color and camera-depth
occlusion while retaining shadow data. Native shadow defaults restore the
directional shadow that is missing with the adapter's current settings.

| Case | Screenshot | Observed result |
|---|---|---|
| Spot, separate culling, current options, DPCF | `01-cull-spot.png` | Green shadow remains; the old black caster rectangle is gone. |
| Directional, separate culling, current options, DPCF | `02-cull-directional.png` | Red receiver with no visible green shadow region. |
| Directional, separate culling, native defaults, DPCF | `03-native-defaults-dpcf.png` | A soft green shadow appears. The regular source view also gains its directional shadow. |
| Directional, separate culling, native defaults, PCF | `04-native-defaults-pcf.png` | A sharply bounded green shadow appears without caster color or a black depth rectangle. |

`state-comparison.json` verifies identical directional-light world transforms
across the three directional cases. Native logs confirm full-range clipping,
camera culling `FRONT_AND_BACK`, and shadow culling `NONE`.
The private caster material is restored before the ordinary scene draws.

The native-default cases omit `builder.shadowOptions` for the explicitly named
prototype light. Logged native defaults include near/far hints 1/100, identity
quaternion, constant bias 0.001, normal bias 1, and LiSPSM enabled. The adapter
cases overwrite these with zeroed Java fields. The experiment identifies the
initialization path as the failure boundary; it does not isolate one field as
the sole cause.

The installed Filament 1.77.3 API exposes `getShadowOptions` and
`setShadowOptions`. The next bounded adapter correction will read options from
the newly built native light, apply existing authored overrides, and write them
back. Source search found the same constructor in component-light decoding and
stage-sun creation. Both paths need the same correction.

## Evidence and limits

`apk.json` identifies the built R3 APK. The parent checked its SHA-256 against
the worker receipt and launched it through `dn run --use-application-binary`.
`run.log` records all four selectors. `native.log` confirms Vulkan `pref=2`,
runtime material compilation, actual shadow settings, and capture markers.
No material-compile failure or fatal marker appears in the collected log.

The later [OpenGL capture run](../android-opengl-capture/README.md) confirms
directional shadow data with the same native-default route and a clean PCF
footprint. It does not verify the production catcher's display path.

This is RGB capture-route evidence for the fixture. A raw scalar mask,
transparent baked display, blur, frozen cache, explicit refresh, and OpenGL
rendering remain unverified for Android. No prototype code was imported into
the production checkout.

The app and filtered log stream stopped normally. The test-app PID was absent
and the launcher was foreground. The device panel closed without powering off
the A142. No display or rotation setting changed.
