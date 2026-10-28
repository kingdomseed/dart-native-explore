# iOS sprite blending

Image-backed sprite blending passes the bounded native sequence. The later [render-texture correction](render-texture/README.md) also passes its high-quality iOS fixture. This does not complete U3 or its Android/device matrix.

## Image-backed checkpoint (R3)

The parent built and drove the iPhone 17 Pro simulator on iOS 27.0. The 25-file source snapshot is identified by `source-sha256.txt`; its archive SHA256 is `0ab3c79167c2e9e855700e156f5e0753eb367aebb9fc2ae887021930179b1f15`. The archive is retained at `/private/tmp/dart3d-e5b-sprite-integrated-20261027/r3/source.tgz`.

## Visible correction

The original additive output disappeared in the real host (`before-additive-disappeared.png`). The corrected output remains visible (`01-additive.png`). The original tinted untextured sprite applied vertex alpha twice (`before-double-vertex-alpha.png`); `04-alpha-tinted-untextured.png` shows the correction.

The material now carries raw vertex color through a geometry varying, neutralizes SceneKit's built-in vertex-color application, and multiplies texture, tint and vertex color once before premultiplying RGB. Alpha mode uses `.alpha`. Additive mode uses `.add` and writes RGB only, preserving the existing destination alpha. No probe code remains in the shipping source.

The six retained comparison reports measure eight fixed 9×9 PNG regions. Their maximum encoded RGB errors are 2, 1, 1, 1, 1 and 2 against the fixture's linear source-over/additive equations, encoded with the sRGB transfer function; the tolerance is 3. These are screenshot observations, not a color calibration. PNG alpha is opaque and supplies no coverage-alpha proof. `measure.dart`, `compare.dart` and `regions.json` retain the calculation.

`05-alpha-tinted-untextured-crossed.png` also checks reversed translucent depth order. `06-ordinary-type.png` and `07-restored-sprite.png` record same-ID material type replacement and restoration. `08-next-green.png` shows manual frame advance. The recording shows both shared selected-material consumers changing frames while the separate reference stays red, followed by playback and pause. The final paused label remained at frame 1 on a later snapshot. Reset-on-leave was not exercised in this run.

The unedited recording is retained at `/private/tmp/dart3d-e5b-sprite-integrated-20261027/r3/ios/material-controls.mp4` (SHA256 `b755928d63778fdab6b26a39f1fbe690ef1ffbddef62c2e38995c7dbeef48eee`). `material-controls-sheet.png` samples that 126.9-second recording. Numeric shadow-casting/receiving isolation was not measured; the ordinary caster/receiver and front occluder are visual controls only.

## Destination alpha

`blend-readback/readback.json` is an actual RGBA16Float GPU readback, SHA256 `699a7ad011821b21e3ccdfdd80d0930ae00c40d917a78c8fc97ac5e02b3962d3`. Its frozen executed probe sources and hashes are alongside it. The probe uses private copied scene attachments, seeds a target, loads that target during rendering, waits for completion and reads center/outer 3×3 patches. It is diagnostic code, removed from the shipping tree.

The retained destination was `(0.02000427, 0.02999878, 0.04000854, 0.25)`. For source RGB `(0.2, 0.6, 0.9)` and alpha `0.5`, the selected `.add`/premultiplied RGB/coverage-alpha/RGB-write-only candidate produced `(0.11999512, 0.32983398, 0.48999023, 0.25)`. It matches `sourceRGB × sourceAlpha + destinationRGB` and unchanged destination alpha within `0.000165`. The source-over control matched within `0.000058`. All 11 commands completed without GPU errors, and every outer sample retained the baseline.

The alpha-zero candidates worked in this private capture even though alpha-zero output disappeared in the earlier real host. That discrepancy's cause remains unknown. The selected correction has separate real-host proof above; the private probe alone does not prove host behavior or multisample behavior.

## Initial render-texture failures retained

The medium-quality render-texture run crashed: `MTLTextureDescriptor sampleCount (2) is not supported by device.` The unchanged `RenderTargets.swift` selects two samples from medium quality. The crash report remains at `/private/tmp/dart3d-e5b-sprite-integrated-20261027/r3/ios/render-texture-medium-crash.ips`.

High quality avoided that crash but rendered blended constant materials magenta, including the ordinary image sheet and untextured sprites (`10-render-texture-high-alpha.png`, `11-render-texture-high-additive.png`). The opaque constant backdrop remained normal. Low quality also showed magenta (`12-render-texture-low-alpha.png`). High quality without the render-texture route rendered normally (`14-image-high-control.png`). The matching run logs retain that failure. The subsequent controls and correction are recorded in the linked render-texture checkpoint.

## Checks and review

- Parent focused package tests: 12 passed (`package-tests.log`).
- Parent sprite/atlas/tone fixture tests: 17 passed (`example-tests.log`).
- Parent example analysis: no issues (`example-analysis.log`).
- Actual native image-backed build/run succeeded; the initial build receipt is transcribed in `image-medium-run-receipt.txt`, and the raw high-quality control transcript is retained.
- Independent Codex source/evidence review passed the bounded material correction. It verified all 25 source hashes and both probe-source hashes, recomputed every private readback patch and all six screenshot comparisons, and inspected the recording contact sheet. It did not build or operate a device. Its verdict excludes unresolved render-texture output and whole-U3 readiness.
- The read-only changed-comment audit found zero actionable findings and made no deletions. The retained comment explains SceneKit's externally owned additive-alpha behavior, confirmed by the readback.

Android material baking, Android GPU rendering, native shadow/depth measurement beyond the retained controls, final U3 matrix and operator approval remain open. The parent stopped its apps and log stream, closed the device panel, and confirmed that no simulator remained booted after this sequence. The A142 was left untouched on its unrelated account screen.
