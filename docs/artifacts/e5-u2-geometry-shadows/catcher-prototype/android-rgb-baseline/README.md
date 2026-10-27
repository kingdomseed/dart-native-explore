# A142 RGB capture baseline

The operator renewed A142 availability on 2026-10-26. The parent ran the
existing R2 capture prototype on that physical phone. Native logs confirm
Vulkan `pref=2` and DPCF. No Android baked-cache implementation is included.

| Case | Image | Observed result |
|---|---|---|
| Near/far directional | `nearfar-directional.png` | Black sampled capture. |
| Full-range directional RGB | `rgb-directional.png` | Red receiver, black caster-shaped rectangle, no visible green region. |
| Full-range spot RGB | `rgb-spot.png` | Green shadow region on the red receiver, plus the same black rectangle. |

The prototype shader writes red for front-facing lit pixels, green for
front-facing shadowed pixels, and blue for back-facing pixels. The spot result
validates that the diagnostic can expose shadow visibility. The directional
result weakens the back-facing-receiver explanation for this fixture. It does
not identify the cause of the missing directional footprint.

Both cases keep caster depth writes while disabling caster color writes.
The black rectangle is therefore not a clean shadow mask. The next isolated
comparison uses separate camera and shadow culling to remove this ambiguity.

`native.log` records the selected lights, shadow settings, ready markers, and
capture execution. R2's `positionWorld` and `directionWorld` log labels are
misleading. The pinned native getters return local values, as shown in
[Filament 1.77.3 LightManager.cpp](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/src/LightManager.cpp).
These logs do not establish failed node rotation.

## Build and binary provenance

The attempted rebuild failed at `:app:mergeReleaseNativeLibs` with
"The contents of the immutable workspace ... have been modified."
`build-cache-failure.log` preserves the exact transform paths and error.
No cache directory was deleted or repaired during this run.

The installed CLI documents `dn run --use-application-binary` for prebuilt APKs.
The parent used that option with the existing R2 APK, then navigated its
existing selectors. `apk.json` records its path and SHA-256.
`run.log` records the successful launch and selector changes.
This is GPU baseline evidence from that binary, not a successful rebuild.

The parent inspected both RGB screenshots after native ready markers.
The app and filtered log capture stopped normally. `pidof` returned no test-app
process, and the launcher was foreground when the run ended. No display or
rotation setting was changed.

The four new capture comparisons remain in preparation. Android production
baking, OpenGL proof, and the full E5 matrix remain open.
