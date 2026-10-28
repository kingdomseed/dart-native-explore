# W34 iOS PBR screen debug evidence

The approved iPhone 17 Pro simulator executed the five PBR channels, filled
wireframe, current factor edits, reload, and off restoration on 2026-10-27.
Independent Codex review found two P2 defects in detached skin dependencies and
partial viewport coverage. Both failures were reproduced and corrected; the
focused simulator replay passes. Independent Codex correction review also
passes with no material reachable P1/P2 in this bounded iOS PBR unit.
See [the correction evidence](review-fixes/README.md).
Android, other material families and
consumers, performance, and whole W34 remain open. Native particles are excluded
from channel presentation under the operator's explicit scope decision.

## Observed behavior

The asymmetric normal map changes fragment colors within the quad's triangles.
Metallic, roughness, base color, and compressed axial depth render through the
actual view configuration. Wireframe preserves fill and the indexed diagonal.
The source scene remains the capture owner.

The pixel checker records these encoded screenshot observations:

| Check | Result |
| --- | --- |
| Authored-target monitor crop after normal, metallic, roughness, depth, and wire captures | Zero changed pixels against the reference for each R2 comparison |
| Final-fixture authored-target monitor after a normal capture | Zero changed pixels |
| Full off restoration without authored edits | Zero changed scene pixels |
| Off after factor edits, then reload and toggles | Zero changed scene pixels against the edited Off reference |
| Edited Off against original Off | 40,337 changed scene pixels |
| Filled wire overlay | 1,759 changed scene pixels, with zero changes inside the occluder control rectangle |
| Literal 0.125, 0.5, 0.875 in base color, metallic, and roughness | RGB 100, 187, 237 in each channel, versus ideal sRGB codes 99, 188, 240 |
| Stronger depth control | Near RGB 211, far RGB 237 |

See [pixel-analysis.json](pixel-analysis.json) for exact rectangles and samples.
These are screenshots, not raw GPU values or calibrated colorimetry. The
three-code maximum literal discrepancy remains recorded. No numeric alpha,
premultiplication, or performance claim follows from the transparency images.

The parent initially misread R2's first blend capture. Independent RGBA sampling
of that retained PNG confirms all three literal swatches and the blue occluder
are present. The later captures contain them too. No missing-object transient
or renderer cause is established by those artifacts.

## Source and runs

The worker's 12-file delta was imported over accepted58 after hash and patch
checks. The parent removed 18 comment lines across ten blocks, kept the external
SceneKit premultiplication constraint, and replaced the raw proxy-name check
with identities from the existing blend-caster owner. No comments were restored,
no suppressions changed, and no audit rerun was needed.

The initial runtime showed control-row height changes. R2 gives the two channel
rows fixed heights. R2's depth control at Z=-0.4 samples the same encoded value
as the quad. R3 changes only the fixture occluder to Z=-3 and hot-restarts Dart.
The unchanged native depth shader then shows a darker near surface. R3 is the
final source fixture. R2's native implementation is identical to R3's.

The source packet contains 66 paths and a 13-file delta against HEAD plus
accepted58, including the approved program-plan exception. Forward and reverse
replay match exactly. All 1,926 unowned baseline files and six lock/registrant
paths remain unchanged. Packet receipts and exact sources are retained at:

`/private/tmp/dart3d-w34-screen-debug-ios-20261027/r1/parent-packet/`

Host receipts include the worker's 393 package and 330 example tests, both
analyses, Swift typecheck, and generic arm64 simulator build. The parent's final
example suite passes 330 tests and analysis reports no issues. The parent also
ran the actual simulator build and three focused fixture tests. Host checks do
not establish the remaining material and consumer paths.

## Retained evidence

`r2/` contains the five-channel, capture, wire, coverage, factor-edit, and reload
screenshots. `r3/` contains the final fixture's depth control, channels, target
comparison, and off restoration. The comparison script is retained beside the
results. Full local runtime logs, UI receipts, source packets, build receipts,
and raw recordings remain under:

`/private/tmp/dart3d-w34-screen-debug-ios-20261027/r1/`

R2's recording is 248.76 seconds with 25,409 encoded frames. Its 13-cell contact
sheet samples 48 times and does not cover every short selection. Individual
PNGs and UI receipts establish those states. Decode logs retain timestamp
warnings. Neither recording supplies a timing or latency measurement.

The app, recordings, native log streams, and device session were stopped. The
simulator was shut down. Final inventory showed no open device and no booted
simulator. The A142 received no targeted operation. The source remains local
and uncommitted. Ignored build support and evidence packets are retained.

Existing screen siblings, native skin/morph output, instances, variants, LOD,
facing, late texture arrival, view/controller recreation, camera gestures,
non-PBR families, Android, final T2/T4, and whole Track E remain open.
