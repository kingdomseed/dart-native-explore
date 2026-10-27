# E5 geometry and shadow evidence

E5 is in progress. Wedge, Ring, and Extrude have passed source review,
parent tests, and live checks under two light directions on iOS simulator
and A142 Vulkan/OpenGL. Matched spot-shadow off/on views pass on those same
three lanes. The bounded iOS shadow-catcher bake has parent runtime evidence
and an independent source-review PASS. Android baking and its corrected
directional-light and camera-facing consumer paths have scoped Codex
source/evidence review PASS verdicts. The operator approved the PR's
before/after screenshots and cache-movement videos on 2026-10-27
(“Looks correct”). Final Fire/Wacom device smoke remains open. Its
[raw-mask calibration](android-raw-mask/README.md) passes on A142 OpenGL and
Vulkan for directional and spot lights, including border values, transparent
display, and render-target texture orientation.

[Final integrated verification](final-verification/README.md) tracks current
package tests, device smoke, and the remaining merge gates. The sections below
retain the earlier checkpoints and failing-before evidence.

## Geometry checks

The parent ran the integrated tree based on E4 merge `4a75520`.
Both Dart analyses are clean. The package suite passes 331 tests and the
example suite passes 232 tests. The matching `geometry-*.log` files record them.

The Android JVM task passes 153 tests with 15 skipped physics-native tests,
138 passing, and zero failures or errors. It does not run the opt-in Jolt
native suite. A fresh task-local Gradle cache bypassed the shared cache error.
The first actual unit run exposed the bounds helper assuming every mesh is
centered at zero. `geometry-android-test-helper-before.log` records that failure;
`geometry-android-tests.log` records the pass after subtracting the declared
bounds center. Production geometry was unchanged by that helper correction.

All ten plugin Swift sources pass `xcrun swiftc -typecheck` against the
`iPhoneSimulator27.1.sdk` at target `arm64-apple-ios15.0-simulator`.
The successful command emitted no diagnostics.

Independent Codex Luna review found three source defects. The native wedge
and ring miss the document-to-native Z reflection; reflected path frames
change asymmetric Extrude profiles; clockwise profiles keep fixed triangle
winding despite their flipped normals. Corrections and regression proof are
pending. The first Sol reviewer could not start because the model was at
capacity. The Luna review did not run tests or devices.
The comment audit accepted nine redundant native comment lines for deletion.
Device rendering, T2 smoke, U2 feature lanes, and operator review are NOT_RUN.

## Geometry reflection correction

The native builders now reflect positions, normals, tangent handedness and
triangle winding at output. Extrude restores document-space path points before
calculating frames. Both profile orders retain outward sides and caps.

Worker before-runs reproduced six Android failures and the Dart clockwise
winding failure. The corresponding `reflection-before-*.log` files retain
those results. The public raycast regression already passed before the fix;
it is route coverage, not evidence that the former winding was correct.

The parent reran the integrated correction. The package suite passes 332
tests and the example suite passes 233. The Android JVM task reports 159
tests, 144 passing, 15 expected native-physics skips and zero failures or
errors. All ten Swift plugin sources typecheck with the same simulator
SDK and target. The `reflection-parent-*.log` files record the test runs.
Two internal coordinate-handoff comment lines were removed after audit.
Fresh independent Codex Luna source review reports PASS with no material
reachable findings. It did not run tests or devices. Device rendering remains
NOT_RUN; the U2 geometry fixture is being prepared. Both parent Dart analyses
are clean (`reflection-package-analyze.log`, `reflection-example-analyze.log`).

## Geometry live feature checks

The parent inspected the same U2 inventory on iPhone 17 Pro simulator and
A142 Vulkan and OpenGL. Each lane shows the wedge slope, ring hole, closed
asymmetric Extrudes in both profile orders, and two instanced wedges.
Both lighting directions were selected through the real button. The six
`u2-<lane>-<left|right>.png` files retain those views. The native Android logs
explicitly confirm VULKAN pref2 and OPENGL pref1; neither contains fatal
exception or signal markers. The paired run logs record both light modes.

The first Android view put part of the inventory behind the footer
(`u2-framing-before.png`, captured after a manual orbit, not a camera-matched
before image). The parent raised the authored U2 viewing angle
and offset only its camera target to keep the objects above that footer.
The original framing test asserted the implementation's exact center; it
was replaced with camera projection checks for all fixture bounds corners,
retaining the public pointer-ray checks. The failing and passing focused
logs are `fixture-parent-framing-test*.log`. Final example analysis is clean
and all 236 example tests pass after the adjustment.

The [published iOS recording](https://github.com/kingdomseed/dart-native-explore/releases/download/media-e5-u2/u2-ios-geometry.mp4)
is 26.163333 seconds. `geometry-video.json` records its URL and hash.
All app runs, the recording, and native log captures are stopped.

The [review-media release](https://github.com/kingdomseed/dart-native-explore/releases/tag/media-e5-u2)
also contains the iOS spot/directional cache journeys and Android cache and
camera-facing journeys. `media.json` records all five asset URLs, byte counts,
and SHA-256 values verified against GitHub's uploaded digests.
The geometry feature checks do not complete E5. Spot-light shadows and
shadow-catcher baking are not yet verified; the full E5 T2 device matrix
and operator visual review remain open.

The independent fixture/evidence review reports PASS. Its small framing-test
gap was addressed by constraining bounds projections to the upper 60 percent
of the test viewport. The adjusted fixture passes all three tests; temporarily
restoring the original camera fails that guard at Y=500.884865 with a footer
boundary of 480. The `fixture-footer-before.log` and
`fixture-footer-after.log` files record the direct comparison. The comment
audit found no actionable new comments or suppressions.

## Spot-shadow paired views

The `u2-shadow` showcase fixture contains one cuboid, one lit receiver and
one spot light. `DART3D_U2_CAST_SHADOWS=false|true` changes only the light's
`castsShadow` property. The test compares serialized off/on documents after
removing that property. Medium quality keeps native shadow casting enabled.

The final fixture uses light position `(-2,5,2)`, intensity `100`, range `12`
and the same camera in both boots. Initial views with intensity `10` and
unbounded range did not show a useful shadow comparison. The light was
repositioned and given the final intensity and range before capturing the
matched views. Those experiments do not isolate a native-renderer defect.

The parent inspected the A142 Vulkan and OpenGL pairs. In each lane the
off view shows a lit receiver without a cast shadow; the on view adds the
cuboid's shadow on its visible side. The files are `spot-vulkan-off.png`,
`spot-vulkan-on.png`, `spot-opengl-off.png` and `spot-opengl-on.png`.
The paired `spot-<backend>-<off|on>-run.log` files record the boot flag.
Their native logs confirm Vulkan pref2 and OpenGL pref1. Both on logs
record `mapSize=1024`; no fatal exception or signal marker was found in
these four native captures. All four Android runs and captures are stopped.

The parent also inspected `spot-ios-off.png` and `spot-ios-on.png`. The
same receiver is lit in both; enabling casting adds the cuboid shadow.
`spot-ios-off-run.log` and `spot-ios-on-run.log` record the matching boots.
The iOS app was stopped and the simulator shut down after capture.

The final focused parent run passes all six geometry and shadow-fixture
tests, and example analysis is clean (`spot-parent-final-tests.log`,
`spot-parent-analyze.log`). The shadow-off selector passes its three tests
(`spot-parent-tests-off.log`). A comment audit led to one redundant comment
deletion. No native spotlight decoder changes were needed for these views.

Shadow-catcher baking, the full E5 smoke matrix, final independent review
and operator visual review remain open.

Independent Codex Luna review reports PASS for the spotlight fixture and
the six paired captures, with no material reachable P1/P2 finding. This
review inspected source and parent-produced artifacts; it did not run
another build or device check. The next step is an isolated Android
prototype of a native material-owned shadow-footprint cache. The existing
material update is the proposed explicit refresh boundary. No catcher
bake implementation has been accepted into the E5 tree yet.

The first Android capture probe is now run. Its spot-light clipping variant
captures a footprint but also noise; layer filtering drops the footprint.
Directional variants and full-depth/live controls remain unsuccessful.
The [capture experiment record](catcher-prototype/README.md) retains the
observations and controls. This is partial prototype evidence, not a baked
catcher pass. All diagnostic code stays outside the E5 implementation.

The corrected iOS capture probe now retains directional and spot footprints
without caster color. A red-backdrop comparison confirms transparent
surroundings. Color-write exclusion also removes the shadow and is rejected.
The [iOS probe record](catcher-prototype/ios/README.md) contains all eight
captures, crash evidence, and the corrected-process logs. This closes the
planar iOS capture experiment, not baked-catcher implementation or Android
capture. The app and log capture are stopped and the simulator is shut down.

The [iOS baked-catcher record](ios-baked-catcher/README.md) now contains parent
verification of frozen footprints, explicit refresh, softness, and live-mode
movement for spot and directional lights. Native runtime caught a projection
scale and U-mapping error, corrected before the final recordings. Independent
code review, Android baking, and final E5 verification remain open.
