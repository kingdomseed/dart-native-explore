# U3 iOS selection-mask experiment

The parent ran this throwaway probe on the approved iPhone 17 Pro simulator on 2026-10-27. It establishes a selection-only capture route for the fixture's skinned mesh, two-primitive payload mesh, and 130 reflected/ordinary instances. This is not the production highlight API or whole-U3 completion.

## Matched observations

The app uses the existing medium-quality render path, black sky, frozen animation poses 0.5 and 1.0, and native 1206x2622 screenshots. The fixture selectors and capture counts are in `run.log` and `native.log`. The parent inspected the images directly.

- Six matched off/control pairs have zero changed pixels in the main scene region `[0,330,1206,2100]`. The comparison excludes status text and controls. This covers skin near/far at both poses, payload near, and instances near.
- `pixel-analysis.json` counts 130 separate white grid cells in the instance mask. The payload mask contains its sphere and projecting bar. Occluding geometry does not cut the mask or introduce a horizontal interior contour.
- At the straight skin edges, the border measures three physical pixels on each side at both distances and both frozen poses. Exact scan rows, mask bounds, and gold pixels are in `pixel-analysis.json`.
- The 28.3-second recording shows the skinned object moving in capture-only and outline modes. Its contact sheet is retained. The parent inspected sampled frames; no frame-by-frame latency measurement is claimed.
- After leaving the probe, the existing U2 geometry and baked-catcher scenes render without residual outlines. Their captures are `leave-u3-geometry.png` and `leave-u3-catcher.png`.

The raw motion recording remains at `/private/tmp/dart3d-e5b-outline-probe-20261027/parent-ios-r5/skin-motion.mp4`. It is not published. The fixture observation suite passed 19 checks and targeted Dart analysis reported no issues. These checks do not replace native pixel proof.

## Failed candidates retained

The first same-scene capture changed selected materials to magenta, including in capture-only control mode. Its screenshots are under `parent-ios-r3/`. Restoring the original material arrays did not preserve the main draw in that experiment.

The correction copied selected geometry, skinners, and required transform paths into a capture-owned scene. This preserved ordinary colors but enlarged and misplaced the mask, shown under `parent-ios-r4/`. The parent added the private camera to that scene before assigning its world transform. The next native build produced the matched results above. This one-line change follows the existing baked-catcher capture ownership; no internal SceneKit cause is claimed beyond the observed camera-attachment discriminator.

The capture samples source presentation transforms, preserves bone order and inverse bind matrices, and owns its copied geometry and white materials. It does not copy animation clips or mutate the active scene's materials or categories. The generic simulator app build passed and the real Metal capture and resolve executed. `source-sha256.json` records the eight probe source paths used for this run.

## Open boundaries

The single-view fixture uses a black background, one opaque gold outline, and a synchronous offscreen capture. General backgrounds, sibling views, multiple simultaneous highlight colors, morphs, cutouts, public transient selection, and production lifecycle/performance remain unverified or unimplemented. The copied graph is currently recreated each captured frame. No performance claim is made.

Android Vulkan has only the earlier first skin-outline observation. Remaining Vulkan and OpenGL checks are paused while the A142 shows an unrelated account dialog; the parent left it untouched. PR65 remains separate and still awaits Fire/Wacom. This probe changed no PR, commit, dependency, SDK pin, or lockfile. The app/log stopped and the owned simulator was shut down after the run.

Reproduce pixel analysis with `uv run --with pillow python /private/tmp/dart3d-e5b-outline-probe-20261027/analyze_ios_pixels.py`. The script records its crop and thresholds; it does not assess every runtime limitation above.

The runtime source manifest precedes six comment-only deletions accepted after the read-only Comment Sicko audit. No executable code changed after this run. The independent-review snapshot has a separate manifest at `/private/tmp/dart3d-e5b-outline-probe-20261027/review-source-sha256.json`.
