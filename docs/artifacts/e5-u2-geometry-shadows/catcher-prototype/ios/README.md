# iOS catcher capture experiments

These are throwaway SceneKit capture experiments. Production E5 code does
not contain the probe. The parent ran the isolated-scene correction on the
iPhone 17 Pro simulator and inspected all eight variants.

The original top-down cameras faced upward. Correcting their document-space
rotation to positive pi/2 made the sampled target visible. `before-camera.png`
records the empty target. Switching the capture receiver from multiply to
alpha blending removed the black receiver field, but left a gray field.
`before-isolation-alpha.png` records that partial result.

The next trial changed the shared scene background to transparent during
`willRenderScene`. `transparent-crash-system.log` records an off-main UIKit
layer mutation through `SCNView._updateOpacity` and
`ShadowCatcherProbe.beginCapture`, followed by an unrecognized selector
exception involving `SCNCamera`. The background write explains the first
fault. The cause of the later exception remains unknown.

The correction copies the capture scene and its material, light, and camera
attachments. Capture reads source poses without changing the displayed
scene. The worker's generic arm64 simulator build and example analysis
passed. `correction-report.md` records those checks and the remaining runtime
questions. A build pass does not prove a clean shadow footprint.

## Corrected capture results

The parent tightened the capture half-height from 4.6 to 2.3 and the display
half-height from `4.6 / aspect` to `2.3 / aspect` so the footprint is readable.
The `ios-<variant>-<light>.png` files show the resulting captures. The framed
directional control is `ios-control-dir-framed.png`.

| Variant | Directional light | Spot light |
|---|---|---|
| Control | Caster color and shadow visible. | Caster color and shadow visible. |
| Receiver-depth clipping | Shadow retained, caster color absent. | Shadow retained, caster color absent. |
| Caster color writes disabled | Caster color and shadow both absent. | Caster color and shadow both absent. |
| Category-cull exclusion | Shadow retained, caster color absent. | Shadow retained, caster color absent. |

Changing the display backdrop from white to red leaves red visible around
both clipped footprints. The two `ios-clip-*-red-background.png` files prove
that these captures do not contain an opaque receiver field. Their footprint
shape agrees with the corresponding control's shadow. The color-write route
is rejected because it also removes the shadow.

The category-cull captures retain shadows, but the source view's shaded caster
face also differs in those captures. This observation does not establish the
cause. Receiver-depth clipping is the current candidate for this planar
fixture; category isolation needs further review before production use.

`corrected-run.log` records all eight selections. `corrected-native.log`
contains only the corrected process, PID 76787, excluding an earlier launch of
the old installed binary. `corrected-render-errors.log` contains only its
header, with no matching off-main layer or terminating-app message for that
process. The app stayed connected through the full sequence and stopped with
`Application finished`. Parent example analysis is clean in
`parent-analyze.log`. The log capture is stopped and the simulator is shut
down.

These results establish capture for the two fixture lights. They do not
establish a frozen cache, blur, refresh, arbitrary receiver transforms,
multiple casters, or Android parity.
