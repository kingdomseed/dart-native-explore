# Directional-light ties

A142 OpenGL medium reproduces and corrects the tied-light mismatch.
The bake now retains every directional light during one directional capture.
Filament chooses the dominant light itself, including its native tie behavior.
Spot lights still use separate captures.

## Before and after

`DART3D_CATCHER_LIGHT=directional-tied` builds three white directional lights
with equal intensity 3. In scene order, only the third light casts shadows.

- PID 30019 [before baked](before-baked.png) misses the footprint.
- The same process in [live mode](before-live.png) shows a footprint left of
  the large cuboid.
- PID 30382 [after baked](after-baked.png) shows that footprint too.
- PID 30672 repeats `directional-primary-unshadowed` with the new correction.
  [Its baked result](unequal-baked.png) has no footprint, preserving the
  previous stronger-noncasting-light correction.

All three native logs confirm `OPENGL (pref=1)` and a 256-pixel capture.
The parent inspected the four images. No fatal marker occurs in these logs.
This is visual proof for these OpenGL configurations, not numeric pixel
parity or a Vulkan result.

The original launch happened before the new APK build finished. Its run log
reported `directional`, so it was rejected before screenshots. The private
`invalid-old-apk-*` logs are excluded from this evidence set. The valid before
run above explicitly reports `directional-tied` after the build completed.

## Correction and verification

[The correction](correction.patch) removes Kotlin's maximum-intensity winner
selection. The pass queues one directional capture and preserves all scene
directionals during that draw. The existing capture shader uses native
`LightData.visibility`. Extra directionals have visibility 1, so they add no
occlusion. [Pinned Filament directional shader](https://github.com/google/filament/blob/v1.77.3/shaders/src/surface_light_directional.fs#L90-L131).
This avoids reproducing the renderer's unstable partial sort.

The fixture test passes 11 cases with the tied boot selector.
Example analysis reports no issues. The full Android Release JVM run records
162 cases, 147 passed, 15 existing opt-in native-physics skips, and no failures
or errors. The changed-comment audit reports zero findings and zero edits.

The parent stopped both app runs normally and stopped its logcat processes.
The final app PID is absent and the Nothing launcher is foreground.
The fresh Codex recheck reports PASS with no material reachable P1 or P2
defect in this correction. It verified the 57 source hashes and four-file
delta and inspected these parent-produced images and logs. Independent
reviewer tests and device runs were NOT_RUN.
Remaining consumer journeys, Vulkan repeats, final E5 verification, and
operator approval remain open.
