# Android shadow-mask calibration

Parent device checks passed for the single-light capture and display on the
A142, using OpenGL and Vulkan. This verifies the inputs needed by the Android
baked catcher. The production cache, blur, refresh, and consumer lifecycle are
still unimplemented and unverified.

## Captured values

The four 256 by 256 RGBA readbacks are in [readbacks](readbacks/).
R stores shadow amount, `1 - LightData.visibility`. G and B match R exactly.
R spans 0 through 255 in every case. Capture alpha is 255 throughout, including
the uncovered border, so capture alpha cannot represent shadow opacity.
The outer eight pixels have R equal to zero in every image. The receiver is
4.2 units wide and the capture covers 4.6 units, leaving this border uncovered.

[final-analysis.json](final-analysis.json) records the measurements. Run
`uv run --no-project python analyze_readbacks.py readbacks` from this directory
to reproduce them. At the R >= 128 threshold, directional masks have identical
coverage across backends. Spot coverage intersection divided by union is
0.995813. Both comparisons use the same row order. Vertically flipped
comparisons differ substantially.

## Display and texture orientation

The right panel draws black with opacity sampled from R over a red background.
Red remains visible outside the shadow, including the uncovered border. The
left panel retains the ordinary scene. The parent inspected all four images.

| Light | OpenGL | Vulkan |
| --- | --- | --- |
| Directional | [Final](final-opengl-directional.png) | [Final](final-vulkan-directional.png) |
| Spot | [Final](final-opengl-spot.png) | [Final](final-vulkan-spot.png) |

The initial Vulkan display was vertically reversed despite correctly oriented
readback data. [The earlier capture](parent-vulkan-directional-before-uv.png)
preserves that failure. Both prototype display shaders now sample through
`uvToRenderTargetUV`. Filament's [pinned shader helper](https://github.com/google/filament/blob/v1.77.3/shaders/src/common_getters.glsl#L103-L121)
handles the difference between render-target texture origins. This correction
belongs at render-target sampling, including future blur and display shaders.

## Source and execution

[final-prototype-source.tgz](final-prototype-source.tgz) contains the five final
prototype files. [source-sha256.txt](source-sha256.txt) identifies their bytes.
[baseline-relativeprototype.patch](baseline-relativeprototype.patch) is the
worker's earlier patch, before the parent added the UV helper and uncovered
border. Use the final source archive to reproduce these captures.

The `parent-final-*` build, run, and native logs record the two release builds,
both gallery selections per backend, completed file writes, and actual backend.
Both runs ended with `Application finished`. The parent then confirmed no app
PID and the Nothing launcher in front. The parent stopped its logcat process.
The prototype remains separate from production source.

The capture uses PCF for calibration, native light defaults, and separate
camera and shadow culling for one caster. Multiple-light composition,
production quality filters, transformed receivers, and cache transitions are
outside this result. No full E5 completion claim follows from these checks.
