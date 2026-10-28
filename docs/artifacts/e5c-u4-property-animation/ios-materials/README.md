# U4 iOS textured materials, alpha and snapshot evidence

The approved iPhone17Pro simulator ran the new `u4-materials` fixture at high
quality. Shared unlit and PBR color animation retain their checker texture;
the static reference and ordinary iOS snapshot remain unchanged. The run found
and corrected an ordinary-material alpha attenuation defect. This is a bounded
U4 lane; Android runtime and the complete U4 verification matrix remain open.

## Fixture and native observations

Read the six cells by row: shared unlit pair, PBR/static reference,
alpha/snapshot. All six textured faces use the same 2x2 opaque RGBA checker.
The shared pair binds one material; the double-sided instance uses an ordinary
iOS snapshot clone with authored black factor. Android's current GPU derivative
policy differs and is not verified here.

Temporary logging read actual drawn SCNMaterial objects, KVC factors and Metal
texture identities after the production sampler. Five literal states and826
complete observations passed `analyze-native.dart` / `native-checks.json`:

| Seek / weight | Shared unlit and PBR factor | Alpha factor |
|---|---|---|
| 0 / 1 | [1,.25,.25,1] | [1,.25,.25,.25] |
| 1 / 1 | [.625,.25,.625,1] | [.625,.25,.625,.5] |
| 2 / 1 | [.25,.25,1,1] | [.25,.25,1,.75] |
| 1 / .25 | [.15625,.0625,.15625,1] | [.90625,.25,.34375,.3125] |
| Stop / .25 | [.25,.0625,.0625,1] | [1,.25,.25,.25] |

Every observation kept the shared-pair material identity equal, snapshot
identity different, reference factor white, snapshot factor black, all six
Metal texture identities equal, and property-only TRS target count zero.
These observations precede the alpha correction; it changes only final blend
RGB, not sampling, ownership or texture bindings.

## Alpha defect and bounded correction

At Seek0, corresponding sRGB PNG samples were opaque red255, gray backing199,
and transparent red190. Positive-alpha blending should not produce a red value
below both source and backing. Removing the late ordinary fragment RGB-by-alpha
multiplication changes that transparent red to215. The original surface factor,
transparent pragma and blend/depth settings remain. Sprite's separately
constructed output is unchanged.

Raw GPU readback isolates this cause. `U4AlphaProbe.swift` copies the actual
realized ordinary unlit material into separate capture scenes, substitutes a
synthetic white diffuse input, and renders to rgba16Float. No live attachment is
modified. Seven completed GPU cases include clear/empty controls, a matching
generated opaque control, old/current fragments and explicit final-output
reference. `alpha-readback-r2.json` retains every3x3 patch and copied shader.

| Center RGBA | Observed |
|---|---|
| Destination | [.5,.5,.5,1] |
| Generated opaque source | [.559082,.139771,.139771,1] |
| Old extra multiplication | [.409912,.383545,.383545,1] |
| Corrected output | [.514648,.409912,.409912,1] |

Against each corresponding measured opaque pixel, corrected output follows
`S*a + D*(1-a)` with maximum absolute error .000152588; old output follows
`S*a*a + D*(1-a)` with error .000221253. `analyze-alpha.dart` verifies all nine
pixels, outside patches and GPU completion at tolerance .001. This proves the
double-opacity attenuation in this ordinary unlit control. It is not raw PBR,
textured-alpha or full renderer color calibration.

The first raw probe compared generated shading to an explicit constant-output
override. Those differ because SceneKit's generated shaded RGB differs from
the factor input; R2 adds the measured opaque control. An initial analysis used
its center value for all nine pixels; the final analysis correctly compares
corresponding pixels without loosening tolerance. R2's first build hit Swift's
expression typecheck budget; splitting the diagnostic calculation fixed it.

SDK basis: installed SCNShadable.h:142–145 requires premultiplied final output,
while :405/418 describes pre-lighting diffuse opacity. It does not say generated
RGB arriving at a fragment modifier is straight. See [Apple SCNShadable](https://developer.apple.com/documentation/scenekit/scnshadable?language=objc).

## Clean replay and verification

All probes and host hooks were removed. `final-clean-run.log` records the clean
build/run ending Application finished. `final-t0/t1/t2.png` show matched seeks;
the upper four faces and snapshot match their pre-fix counterparts pixel-for-
pixel. Final clean crops match the earlier correction-only candidate exactly.
`analyze-images.swift` / `image-checks.json` record these comparisons and texture
contrast samples. These PNG values are encoded screenshot observations.

The parent inspected all screenshots and both video contact sheets. The old
`material-controls.mp4` is86.2s with19 cells; the final corrected clean video
`final-material-controls.mp4` is60.8s with17 cells (48 frames sampled each).
They show seeks and playback while reference/snapshot stay fixed, not frame-rate
or latency. All six cells and footer controls fit at402x874 and were hit through
the accessibility tree.

Final parent Dart suites:282 example and380 package tests, zero failures.
Scoped fixture source review passed before the native correction. Native
correction and final evidence re-review remain pending. Existing native
capability reporting stays unadvertised; its warning is not counted as proof.

Run from dart3d/example: `dn run -d C24F3C6D-A3A9-4FB7-978E-36E67EF55354 --no-pub --dart-define=DART3D_SCENE=showcase --dart-define=DART3D_MODEL=u4-materials --dart-define=DART3D_QUALITY=high`.

## Source and cleanup

The clean45-path archive is `source.tgz`, SHA256
`6ad07da84ad7e420ab54537f6f467be6ccb2f79942affc1e73ac3f1ac832aacc`.
Five-file `correction.patch` replays on the prior reviewed43-path archive;
all40 unowned paths and five tracked locks remain unchanged. The four-file
fixture cleanup removed narrative comments and source-string tests, retaining
real document/control tests. The only production native correction deletes
the extra alpha multiplication and its obsolete comment. `source-sha256.txt`
and `replay-proof.log` identify the exact clean source. SceneViewHost matches
its reviewed8887e13b baseline; FsceneRealizer now hashes6dda8a14.

Exact executed probes/sources, failed attempts, logs, analyses, PNGs and videos
are retained privately in `/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials/`.
The repository evidence copy contains smaller receipts, not the full source
archive or videos. The initial long logging message was truncated; R2 shortened
it and supplies all complete observations. The first non-PTY run ended via its
own SIGINT; all later app runs ended normally. All own recordings/loggers/apps
are stopped and a fresh booted-device listing confirms simulator shutdown.
Replay scratch and both temporary probe integrations were removed. Task caches
and build outputs remain for subsequent checks. No commit/push, PR65 mutation,
external media upload, physical iOS use or Android input occurred.

Variants, foreign rebinds, deferred texture replacement, remaining owner
lifecycles, other light units, multi-view/RT projection, Android runtime, T2/T4
and whole-U4 acceptance are not established by this lane. High quality avoids
the already-recorded2xAA simulator failure; that failure is unchanged.
