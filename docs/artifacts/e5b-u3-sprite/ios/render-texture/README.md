# Render-texture sprite correction

The bounded high-quality iOS render-texture fixture now renders correctly. Independent Codex source review passed. Android, the final U3 matrix and operator approval remain open; the separate unsupported 2× MSAA failure remains recorded.

## Source and correction

The parent built and drove the iPhone 17 Pro simulator, iOS 27.0 runtime, using Xcode 27.1. All 26 source hashes match `source-sha256.txt`. The source archive is `/private/tmp/dart3d-e5b-sprite-integrated-20261027/r5/source.tgz`, SHA256 `a7be0b88186fd2d18a8f84ba26e1c1d120cef241a8d3b5ee4a4a60927e67b4ee`.

The six existing preparation calls moved together from `willRenderScene` to `didApplyConstraintsAtTime`, preserving their order: LOD, camera-facing geometry, blend casters, baked catchers, render targets, sibling-view snapshots. The target renderer still uses its existing render-only API, attachments, camera restoration and queue. No scene mirror, second simulation, new cache or wire operation was added.

The sprite binding also records whether its actual source is a live render target. That target's sampled RGB is already weighted by its alpha. The shader therefore applies only tint/vertex alpha to that RGB; image samples still receive texture × tint × vertex alpha once. The flag is native material state, recalculated by the existing binding owner. Untextured materials start with the image/straight representation.

The fixture's thin transparent box originally presented overlapping front/back image faces. It now uses one ordinary plane, and the independent reference shows the entire rendered target. The selected sprite keeps its caller-controlled atlas rectangle. This makes orientation and cropping visible without a second camera-facing source.

## Controls that separated the failures

| Control | Observed result |
| --- | --- |
| Original RT draw inside `willRenderScene` | Blended sheet, sprites and overlap controls become magenta; opaque backdrop remains normal. |
| Keep RT setup but omit encoding/commit | Ordinary sheet and untextured controls recover. Unrendered RT consumers are not judged. |
| Preconfigure source camera during install; retain encoding | Magenta remains. |
| Add combined depth/stencil attachments; retain original callback | Magenta remains. |
| Move only RT encoding after constraints | Controls recover and RT content renders; log reports no active host encoder. |
| Final ordered preparation block after constraints | Correct colors and geometry with the normal render-target implementation. |

Each control directory retains its screenshot, source identity and native/run logs. `omit-encoding/pixels.json` measures the untextured control at `(104,163,191)` and overlap at `(129,150,135)`. Camera and stencil controls instead measure `(253,0,253)` at both regions. The earlier callback restores the original values. This establishes the exercised timing correction, not a particular SceneKit internal failure mechanism.

## Actual target bytes

`raw-target/readback.json` reads the real producer texture after its existing render, using a blit in the same command buffer and a completion-handler read. Its SHA256 is `1cbb1909e97425348e5698ac312d52e9bbce89629bc1d8fa466da911df1469cb`. The exact temporary sources and hashes are retained; none of that instrumentation remains in the application.

The reported format is 81 (`BGRA8Unorm_sRGB`), and command status is 4 (`completed`), with no error. At texture coordinate `(64,57)`, the half-alpha red sample is BGRA `(0,0,188,128)`: approximately linear red 0.503 with alpha 0.502. The opaque sample is `(0,0,255,255)`, and the zero-alpha sample is `(0,0,0,0)`. Blue samples in the lower half provide the channel/orientation control. These actual bytes establish the producer's premultiplied representation on this path.

Before the source-representation correction, the half-alpha sprite's maximum encoded RGB error was 47 (`before-double-alpha.png`). Afterward, six fixed-region reports under `premultiplied-source/` have maximum errors `2,1,1,1,1,1`, within the existing tolerance of 3. They cover alpha, additive, tinted additive, tinted untextured additive, tinted untextured alpha and restoring the RT source under tinted alpha. The equations and sample boxes are unchanged from the image-backed checkpoint. PNG measurements do not prove destination coverage alpha or calibrated color accuracy.

`06-next-green.png` and the recording show atlas advance and playback on both consumers of the selected material. The full-target reference stays fixed. `07-before-type.png` and `08-restored-type.png` have identical measurements in all eight regions after an ordinary-material round trip. The recording is retained at `/private/tmp/dart3d-e5b-sprite-rt-control-20261027/premultiplied-source/controls.mp4`, SHA256 `f284d473fbb339ab7379f9ddf3d332428dae81863bf4056f417f9ab6e68fa607`; its sampled contact sheet is alongside the screenshots. Playback was paused before the material round trip; reset-on-leave was not exercised here.

## Regression and review

The final image-backed alpha/additive regression has errors 2 and 1 (`image-regression/`). The existing baked-catcher fixture captures on load, retains its old footprint after caster movement, and captures again only after explicit refresh (`catcher-regression/`); its log has exactly those two captures, and the screenshots show the refreshed footprint following the unchanged moved caster.

The parent example analysis is clean and all 17 sprite/atlas/tone fixture tests pass. Actual native runs compiled the Swift and executed the Metal shaders. Independent Codex source review verified all 26 hashes, traced material/texture/RT upserts and deferred image arrival, and found no reachable P1/P2 in this bounded correction. A separate plan review accepted the ordered hook move. The changed-comment audit found zero actionable issues and made no deletions. Reviewers did not build or operate a device.

The parent stopped every app/log it started and confirmed no simulator remained booted. The A142 was left on its unrelated account screen. Android baking/rendering, the full U3 device matrix, general render-graph coverage and performance remain NOT_RUN here. The earlier medium-quality `sampleCount (2) is not supported by device` crash is a separate existing AA limitation; these runs use high quality and make no claim to fix it.
