# Android catcher consumer journeys

These parent-driven checks use A142 OpenGL, medium quality, and the reviewed
production source. No production changes were needed during these checks.
Seven consumer journeys pass below. The camera-facing failure is retained
as before evidence and its [corrected production replay](facing-correction/README.md)
now passes the exercised OpenGL load, freeze, and refresh sequence. Fresh
independent Codex source/evidence review reports PASS for that correction.

| Path | Observed result | Decisive captures |
| --- | --- | --- |
| `type-upsert` | Same-ID ordinary-to-baked upsert replaces the solid receiver with a footprint. The return-to-ordinary command also completes without a fatal log. | [ordinary](type-upsert-ordinary.png), [baked](type-upsert-baked.png) |
| `geometry-upsert` | After caster movement, geometry replacement preserves the old cached patch. Explicit refresh captures the new footprint. | [rebuilt, stale](geometry-rebuilt-stale.png), [refreshed](geometry-refreshed.png) |
| `variant-default` | A default material converts to baked. Refresh while the blue ordinary variant is selected preserves that selection. Returning to default captures the current footprint. Converting the default back to ordinary preserves both selections. | [baked default](variant-default-baked.png), [hidden refresh](variant-default-hidden-refresh.png), [default restored](variant-default-restored.png), [ordinary restored](variant-default-ordinary-restored.png) |
| `variant` | Selecting the mapped catcher captures its footprint. Caster movement and refresh update it. Returning through ordinary default to the catcher preserves that cache. | [restored catcher](variant-restored.png) |
| `component-rebuild` | Three rebuilds after caster movement preserve the old patch. Refresh updates it. | [rebuilt, stale](component-rebuilt-stale.png), [refreshed](component-refreshed.png) |
| `remove-rebuild` | Three public removeNode/addNode cycles preserve the patch. Refresh still captures the moved caster. | [restored, stale](remove-restored-stale.png), [refreshed](remove-refreshed.png) |

The `variant-default` screenshots use one manual camera orbit before material
conversion so the footprint is easier to see. The camera stays fixed through
that conversion and selection sequence. These results do not measure retained
material objects or establish numeric texture parity.

The matching `*-run.log` files record public control actions. Native logs
identify OpenGL and record these captures, with no fatal marker.

| Path | PID | Capture count |
| --- | --- | --- |
| type-upsert | 31411 | 1 |
| geometry-upsert | 31748 | 2 |
| variant-default | 32038 | 2 |
| variant | 1022 | 2 |
| component-rebuild | 1759 | 2 |
| remove-rebuild | 2741 | 2 |

The hidden default refresh remains pending until that default becomes active.
The second capture occurs on returning to it, matching the lazy-cache policy.
Rebuilds and removal do not schedule extra captures. Repeated visual reuse is
not a native allocation or leak measurement.

Each APK was built with `dn build apk --release --no-pub --target-platform
android-arm64`, `DART3D_MODEL=u2-catcher`, `DART3D_BACKEND=opengl`,
`DART3D_QUALITY=medium`, and its `DART3D_CATCHER_PATH` selector.
The parent launched through `dn run --release -d 00064149A002033
--use-application-binary=<built-apk>` and used snapshot-backed agent-device
buttons. Apps and logcat sessions were stopped after every journey.

Remaining work includes final Vulkan and OpenGL feature checks, the full E5
device matrix, and operator review.

## Camera-facing failure

PID 3472 loads the single-billboard receiver and logs a 256-pixel capture,
but [load](camera-facing-load.png) and [explicit refresh](camera-facing-refreshed.png)
have no visible footprint. The parent inspected those images. Camera zoom
was used to check visibility, so load and refresh are not camera-matched
images. Neither is counted as a passing capture.

The temporary diagnostic in PID 4573 reports this actual state.

```text
baked facing registered=false decoded=0.0,0.0,0.0,1.8,1.2,0.0 renderedMin=-1.8,-1.2,0.0 renderedMax=1.8,1.2,0.0
```

The decoder registers the billboard's live vertex buffer before calling
`Context.install`. `Dart3dView.install` then clears the host registry during
old-scene teardown. The same clear is present at base `4a75520`.
The billboard therefore retains its initial XY geometry with zero Z extent.
The cache also reads decode-time CPU bounds, which would remain stale after
camera-facing expansion. Both owners must supply the actual installed
receiver before this consumer can pass.

[The diagnostic patch](camera-facing-diagnostic.patch) changes only logging
inside `firstBakedCatcherReceiver`. Its first version gated on the missing
registry entry and produced no bounds line. The second version gates on the
billboard component and records the values above in
[camera-facing-diagnostic-r2-native.log](camera-facing-diagnostic-r2-native.log).
The parent removed the probe and verified all 57 source hashes match the
reviewed snapshot again. No fix or passing billboard runtime result is
claimed by this checkpoint.

## LOD geometry selection

PID 5000 uses the existing `lod` fixture and real `gesture pinch` input.
Its load captures 256 pixels. Softness 0.14 captures 120 pixels for the large
4.2-unit receiver. Pinching inward by 1.4 crosses the 0.35 LOD threshold.
Explicit Refresh then captures 35 pixels for the small 1.2-unit receiver.
Pinching outward by 0.72 returns to the large geometry and Refresh captures
120 pixels again. No capture occurs between a pinch and its explicit refresh.
These dimensions follow the production softness/resolution formula and show
which geometry supplies the footprint. They are not performance measurements.

[Near after refresh](lod-near-refreshed.png) shows the close view. The small
receiver lies beneath the caster, so this image does not prove a visible
small-plane footprint. [Returning before refresh](lod-return-stale.png) keeps
the old cache. [Returning after refresh](lod-return-refreshed.png) shows the
large footprint again. The parent inspected the near and refreshed return
images. The native log records sizes 256, 120, 35, 120 and no fatal marker.

The LOD app and parent logcat are stopped. The app PID is absent and the
Nothing launcher is foreground. All production source hashes still match
the reviewed 57-file snapshot after removing the camera-facing probe.
