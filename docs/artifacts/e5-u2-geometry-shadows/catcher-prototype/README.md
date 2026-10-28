# Catcher capture experiments

These are throwaway capture experiments, not a baked-catcher pass.
Android code remains in isolated worktrees. None was imported
into the E5 implementation. The parent drove the real A142 app and inspected
the saved views. The runtime compiled both custom material recipes.

| Experiment | Observed result |
|---|---|
| Receiver-depth clipping, directional light | Black capture; the normal scene also lacks a clear directional shadow. |
| Receiver-depth clipping, spot light | White shadow footprint without caster color, with diagonal noise elsewhere. |
| Layer filtering, directional light | Black capture. |
| Layer filtering, spot light | Footprint gone; diagonal noise remains. |
| Full-depth control, receiver casting disabled | Spot capture contains the white footprint and orange caster; directional capture contains only the dark caster. |
| Directional full-depth control with identity shadow quaternion | Black capture. This change alone did not solve it. |
| Same directional control captured every frame | Still black. Freezing the first render is not the sole cause. |

The four `vulkan-*.png` files show the original variants. The `control-*`,
`identity-control-*` and `live-control-*` images show the parent controls.
The source scene is left; the sampled capture is right. The split viewport
stretches the source scene and lets the footer cover some of it, so it is
not a finished visual-verification fixture.

Native logs identify Vulkan and record one capture per original scene.
The live control intentionally captures every frame; its log identifies it
as `LIVE CONTROL`. These runs and log captures are stopped. OpenGL, iOS,
blur, refresh behavior, contact/AO and instanced catchers were not tested.

The installed Java `ShadowOptions()` constructor leaves fields zeroed.
Filament's pinned C++ contract requires a unit directional-shadow quaternion
and defines several nonzero defaults. The identity-quaternion experiment
did not establish this mismatch as the capture failure's cause.
See the [1.77.3 native contract](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/include/filament/LightManager.h)
and [generated Java object](https://raw.githubusercontent.com/google/filament/v1.77.3/android/filament-android/src/main/java/com/google/android/filament/LightManager.java).

The [iOS capture record](ios/README.md) records a later simulator comparison.
Its receiver-depth clipping route retains directional and spot footprints
with transparent surroundings. Android directional capture remains open.
The A142 was released after those experiments. The operator later renewed
availability, and the parent captured a [fresh RGB baseline](android-rgb-baseline/README.md).
It confirms visible spot shadow data and no visible directional shadow region
with the current adapter settings. The app is stopped while the next isolated
comparison is prepared.

The subsequent [culling and native-default comparison](android-split-culling/README.md)
retains spot shadow data without caster color or depth occlusion. Native
shadow defaults also restore directional shadow data with DPCF and PCF.
The Android production adapter correction and baked cache remain unfinished.
