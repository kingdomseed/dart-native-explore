# iOS unlit and sprite debug evidence

The approved iPhone 17 Pro simulator exercised image-backed unlit and sprite
diagnostics, current edits, mask/blend coverage, wireframe, authored captures
and reload. Independent Codex source/evidence review passes with no scoped
reachable P1/P2. See [the report](codex-review/report.md). This is a
bounded W34 unit, not whole W34 or Track E acceptance.

## Native observations

The legacy native path reports constant materials unsupported and leaves their
authored color in selected channels. The new fixture was captured against that
path before importing the native change.

The first implementation used `_surface.geometryNormal`. Its settled normals
image shows gray/white unlit output and missing sprites; other channels render.
No shader compilation failure was found in that process log. A controlled
one-field change to `_surface.normal` produces the expected tilted-quad and
sprite normal display. This does not establish the framework's internal cause.

The final material copy sets its normal property to a solid color for non-PBR
normals. Apple documents that this disables normal mapping and uses geometric
normal information. PBR keeps its existing mapped-normal path. The final fixture
adds a normal texture to the unlit material as a control. Its settled normal
image matches the controlled no-map image exactly. The authored Off image also
matches the legacy baseline exactly in the recorded scene rectangle.
[Apple normal-property contract](https://developer.apple.com/documentation/scenekit/scnmaterial/normal?language=objc)

The first normals PNG appeared black in an image-tool preview. Independent
ffmpeg and sips decoding, then parent recomputation, show 34,950 nonblack scene
pixels and zero differences from the later capture. The encoded PNG is correct;
it does not establish a blank native frame or a transient. Both originals and a
re-encoded inspection copy are retained. The preview discrepancy is unexplained.
Two uncommitted CATransaction warnings occur in the final native log. No fatal
error or app termination was found, and the run ended `Application finished`.
Those warnings remain unexplained, not a claim of a clean warning-free run.

| Encoded screenshot check | Result |
| --- | --- |
| Legacy Off versus final Off; final Off restoration | Zero changed scene pixels |
| Controlled normal input versus final map-bearing fixture | Zero changed scene pixels |
| Authored-target monitor after capture during normals, A and edited B states | Zero changed pixels in each matched comparison |
| Filled wire | 1,789 changed main-scene pixels; zero in occluder interior |
| Factor edit | 28,989 changed main-scene pixels |
| Native sprite-color edit | 18,765 changed main-scene pixels |
| Mask versus blend in unlit rectangle | 4,251 changed nonblack support pixels |
| Edited Off versus reload, main objects | Zero changed pixels |
| Absent metallic/roughness sample | Both RGB 253,0,253 |

`pixel-analysis.json` defines every rectangle and sample. These are encoded
screenshots, not calibrated raw channel, alpha or premultiplication measurements.
The sprite rows are displayed over black. They do not independently distinguish
source-over from additive equations or measure destination alpha. Those policy
fields are preserved by source inspection; no numeric blend-parity claim follows.
The target changes on full reload because it is recreated with current authored
state; the reload comparison excludes that monitor.

Removing the texture renders an axis-aligned quad in both authored Off and the
diagnostic. Their main-scene nonblack support masks match. The diagnostic and Off
RGB differ under blend. Those observations do not establish a new geometry or
canonical-unlit-alpha correction; neither was implemented in this unit.

## Source and verification

The fresh Codex review independently verifies source tracing, all 66 identities,
exact replay/preservation, assigned pixels and four complete video decodes. It
ran no independent tests, builds or devices. Its reviewed 87-file manifest is
preserved as a historical receipt; this record adds the verdict and corrects the
image-preview claim without changing reviewed application code.

The worker changed five scoped paths over accepted66. Parent integration removed
four flagged comment lines and renamed the source sprite sample and diagnostic
reader together. The native normal-input correction and map-bearing fixture
control followed the failed native run. Existing PBR expressions, skin packets,
viewport backing, target and wire owners remain intact.

The initial baseline uses the worker's new three fixture files with accepted66
native code. The final fixture differs by its additional unlit normal-texture
control. The controlled normal-input experiment uses the unchanged first fixture.
Before/final Off equality checks the visible effect of that control; do not claim
the entire before and final documents are byte-identical.

Parent checks pass 393 package tests, 334 example tests, both analyses, explicit
arm64 iOS 15 Swift typecheck with an exit-status receipt, and the final actual
simulator build/run. Worker focused tests and generic build are separate earlier
receipts. Host tests do not prove native coverage.

The final packet has 66 paths and a five-file correction over accepted66.
Forward/reverse replay matches exactly; 1,926 unowned baseline files and all six
lock/registrant hashes are preserved. The source archive SHA256 is
`6f41a1c0ebe3e09bc92fa327a55b48bfaaa5914ca2700322739e225f536432f4`.
The correction SHA256 is
`d69d9326fc9f7c139642649b04586722a7b190d9e2ad6fe2d86d0a6ca8b892ac`.

Four recordings fully decode with exit 0 and 1,740 / 7,932 / 3,981 / 2,331 frames.
DTS warnings remain recorded. The contact sheet samples the editing sequence.
There is no frame-rate, timing, latency or performance claim.

## Retained evidence and remaining work

Screenshots, UI receipts, pixel checker, source identities, replay, tests,
typecheck and native-event excerpts are here. Full raw logs, movies, prior
source variants and export scripts remain at:

`/private/tmp/dart3d-w34-ios-material-families-20261027/r1/parent/`

The app, recorders and native logger are stopped. The simulator is shut down,
device panel empty and normal-main configuration restored. The A142 received
no targeted operation. Ignored build support and the proof packets remain.

Premultiplied render-texture sprites, calibrated coverage, other consumers and
families, catcher coverage, Android, final T2/T4 and whole W34 remain open.
Native particles retain the operator-approved exclusion. No PR or external issue
was changed.

