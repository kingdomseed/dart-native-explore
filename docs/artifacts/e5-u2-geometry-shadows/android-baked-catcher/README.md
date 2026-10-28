# Android baked catcher implementation checks

The production implementation now passes the exercised spot-light cache
sequence on A142 OpenGL and Vulkan after upload-timing and bounds corrections.
Independent review found a directional-light selection defect and then a
tied-light mismatch in the first correction. The [OpenGL tied-light correction](directional-ties/README.md)
and stronger-noncasting-light regression now pass. Fresh independent Codex
review reports PASS for that correction. The [consumer journeys](consumers/README.md)
also pass their exercised OpenGL paths, including the reviewed camera-facing
correction. Remaining Vulkan repeats, final E5 verification, and operator
review remain open. Earlier failures below are
retained as before evidence.

## Passed checks

The A142 compiled and exported all 26 fixed material packages for OpenGL and
Vulkan. See [the bake log](parent-first-bake.log). The parent Release JVM run
passed 17 tests, including the shipped-material inventory. The three XML files
record 11 material-package tests, three settings tests, and three shipped-set
tests. [The direct Gradle log](parent-material-tests-direct.log) records the run.
An earlier wrapper invocation failed on an immutable transform workspace,
before tests. The direct cached Gradle invocation passed without cache changes.

## Failed device check

The final run used A142 OpenGL, medium quality, `DART3D_MODEL=u2-catcher`,
the default spot light, and the direct receiver path. The fixture has two
casters and a translated, yaw-rotated, nonuniformly scaled receiver.

1. [Load](opengl-spot-load.png) logs a 256-pixel capture, but no footprint is
   visible.
2. [Caster movement](opengl-spot-caster-stale.png) moves the large cuboid.
3. [Explicit same-ID refresh](opengl-spot-refresh.png) logs a new capture and
   renders the receiver as a solid black rectangle.

[The final run log](parent-opengl-uniform-run.log) records the public controls.
[The native log](parent-opengl-native.log) includes the capture and refresh
markers for PID 25656. The empty first result and black receiver require
diagnosis. They do not prove a working freeze or refresh cycle. Vulkan and
other consumer paths have not been run on this production implementation.

## Corrections before the visual check

The parent inspected the delivered patch and converted light position and
direction to world space before evaluating spot attenuation. Filament's
[getters return local values](https://github.com/google/filament/blob/v1.77.3/filament/src/LightManager.cpp#L60-L72),
while [rendering transforms them](https://github.com/google/filament/blob/v1.77.3/filament/src/details/Scene.cpp#L248-L261).

Earlier release launches failed before capture. The parent preserved the
runtime reports and corrected three adapter mistakes.

- `Scene.nForEach` could not find `accept(int)` after shrinking. Keeping only
  implementer members failed too. Keeping the callback interface and its
  implementations' method allowed that call to complete.
- The native bounding-box getter could not find the six `Box` fields. The
  consumer rules now preserve those fields. [JNI source](https://github.com/google/filament/blob/v1.77.3/android/filament-android/src/main/cpp/RenderableManager.cpp#L91-L116).
- Three-component light vectors used the float-array uniform overload, which
  expects a 16-value matrix. The two writes now use scalar three-float overloads.

The corresponding `parent-opengl-*-run.log` files retain those failures.
After these corrections, PID 25656 completed captures and the public refresh
without a fatal error. The visual failure remains separate from those crashes.

The comment audit accepted nine block deletions totaling 16 lines. No comments
were restored. The zero-shadow texture alias was named for its value. New JNI
comments document externally required names verified against the pinned source.

The app was stopped after the failed visual sequence. The parent confirmed
no app PID and the Nothing launcher in front, then stopped its logcat process.
The next check isolates capture, composition, blur, and final sampling before
changing the cache algorithm.

## Standalone-pass correction replay

The parent read the pinned engine and renderer source and applied the
two-file upload-timing correction. Surface material parameters are prepared
before a frame, so changing capture and utility parameters between ordinary
draws did not upload them. The private draws now use `renderStandaloneView`
before the screen `beginFrame`, which prepares parameters for every private
draw. This supersedes the earlier design's after-`beginFrame` placement.

[The replay](standalone-correction/parent-opengl-run.log) used the same A142
OpenGL medium fixture. PID 26171 logs a capture on load and another after the
unchanged same-ID refresh. No fatal marker occurs in
[its native log](standalone-correction/parent-opengl-native.log).

- [Load](standalone-correction/opengl-standalone-load.png) now renders a black
  rectangular region immediately, rather than an empty receiver.
- [Caster movement](standalone-correction/opengl-standalone-caster.png) changes
  the cuboid position without a new capture log.
- [Refresh](standalone-correction/opengl-standalone-refresh.png) captures again,
  but the receiver still has an incorrect black rectangular region.

The source-level timing correction is retained. The visual check still fails.
No shader, projection, filter, or weighting change accompanied this replay.
The next diagnostic must read the actual raw, composed, blurred, and final
texture data before another rendering correction. The parent stopped the app,
confirmed no PID and the launcher in front, and stopped logcat.

## Bounds correction and stage proof

The parent ran the temporary stage-readback patch on A142 OpenGL. Both load
and refresh exported zero-fill, raw-light, aggregate, horizontal-blur, and
final-bound textures. The raw capture was already wrong before composition.
The zero-fill R values were all zero. Raw and aggregate R matched at every
pixel, on both load and refresh. The blurred result retained the wrong region.

The exported receiver bounds were `0,0,0,2.1,0,2.1`, interpreted as minimum
and maximum corners. `MeshFactory.MeshData.bounds` instead stores center and
half-extents. `firstBakedCatcherReceiver` now converts that native representation
to minimum/maximum corners. The receiver record calls this field `minMaxBounds`.
The corrected readback records `-2.1,0,-2.1,2.1,0,2.1`, covering the full plane.
The texture region is now `(-2.1,2.1,1/4.2,1/4.2)`.

[Before data](stage-readbacks-before/) and [after data](stage-readbacks-after/)
contain all ten RGBA/text exports per run, unnormalized R/A PNGs, and the actual
native logs. The Dart comparison script reproduces raw-versus-aggregate checks.
The after run captures localized footprints with clear surroundings, replacing
the stretched rectangular region. On load, blur lowers maximum R from 209 to
208 and spreads the edge. These values prove stage behavior for this
single-light fixture, not general numeric parity for every light configuration.

The temporary diagnostic patch was then reversed successfully. No diagnostic
readback, export helper, BLIT_SRC addition, or target-retention machinery remains
in production source.

## Exercised spot-light behavior

OpenGL PID 26937 used the corrected bounds with temporary readbacks present.
The parent inspected these matched captures and the recording.

- [Load](stage-readbacks-after/bounds-load.png), [caster moved with stale patch](stage-readbacks-after/bounds-caster-stale.png),
  and [explicit refresh](stage-readbacks-after/bounds-refreshed.png).
- [Light moved with stale patch](stage-readbacks-after/bounds-light-stale.png)
  and [light refresh](stage-readbacks-after/bounds-light-refreshed.png).
- [Softness 0.14](stage-readbacks-after/bounds-soft.png) recaptures at 120 pixels
  and softens the visible edge. Softness zero used 256 pixels.
- [Live](stage-readbacks-after/bounds-live.png) and [return to baked](stage-readbacks-after/bounds-baked-return.png).
  The existing live Filament shadowMultiplier path does not show spot shadows;
  this check proves switching and return to the cached patch, not live spot parity.
- [The recording](https://github.com/kingdomseed/dart-native-explore/releases/download/media-e5-u2/opengl-corrected-journey.mp4) is 31.2 seconds.
  [Its contact sheet](stage-readbacks-after/opengl-contact-sheet.png) samples the
  light, refresh, softness, and mode sequence. Caster movement preceded recording
  and is covered by the matched screenshots and native log.

Vulkan PID 27676 used a clean build after removing all temporary diagnostics.
[Load](vulkan-core/clean-vulkan-load.png), [caster moved](vulkan-core/clean-vulkan-caster-stale.png),
[refresh](vulkan-core/clean-vulkan-refreshed.png), and [softness](vulkan-core/clean-vulkan-soft.png)
show the corresponding footprint changes. The native log confirms Vulkan and
capture sizes 256 and 120, with no fatal marker. This run did not repeat light
movement or mode switching. Both apps were stopped and launcher foreground
was confirmed afterward.

The clean Android Release JVM task completed 162 cases, with 147 passed and
15 existing opt-in native-physics skips, zero failures, and zero errors. See
[the task log](vulkan-core/parent-clean-unit.log). This is JVM evidence, not
execution of the skipped native physics cases.
