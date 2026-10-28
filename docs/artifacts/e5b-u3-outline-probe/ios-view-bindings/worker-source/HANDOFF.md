# Throwaway iOS per-view outline probe

Prepared in `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-886b3c86` at HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. This is an inspection/import packet for the parent. It is not production outline integration or whole U3 acceptance. Android capability remains a production prerequisite; A142 was not accessed.

Host checks pass: 7 new fixture/controller tests plus 14 W34 tests; 13 highlight regression tests; package/example analysis; full-plugin arm64 iOS15 simulator Swift typecheck; generic arm64 simulator Debug app build. No device discovery, boot, install, launch, screenshots or GPU execution occurred. All native runtime, Metal shader compilation/execution, per-view correctness, ordering, alignment, RGBA results, MSAA execution, retirement, W34 coexistence, performance and Android outcomes are **NOT_RUN**.

## Import and reversal

`correction.patch` is relative to verified final66, not Git HEAD. It changes exactly these eight paths:

- `dart3d/ios/Classes/SelectionOutline.swift`
- `dart3d/ios/Classes/SceneViewHost.swift`
- `dart3d/ios/Classes/RenderTargets.swift`
- `dart3d/ios/Classes/ToneMapping.swift`
- new `dart3d/ios/Classes/SelectionOutlineViewsProbe.swift`
- new `dart3d/example/lib/u3_outline_views_main.dart`
- new `dart3d/example/lib/u3_outline_views_scene.dart`
- new `dart3d/example/test/u3_outline_views_test.dart`

`owned-source.tgz` contains all eight complete files. `final70-source.tgz` contains coherent final66 plus those changes and four additions. `baseline66-source.tgz` is the exact supplied archive, retained unchanged. The corresponding JSON manifests hash every source path. `delivery-sha256.json` hashes delivered artifacts.

Before import, verify the parent's 66 paths against `baseline66-source-sha256.json`. From the parent worktree root, check and apply the correction:

```sh
git apply --check /private/tmp/dart3d-u3-outline-view-probe-20261028/r1/worker/correction.patch
git apply /private/tmp/dart3d-u3-outline-view-probe-20261028/r1/worker/correction.patch
```

Do not apply over unrelated changes to the owned paths. `git apply --reverse --check` followed by `git apply --reverse` restores all 66 baseline paths and removes the four new files, provided the imported probe is unchanged. Forward/reverse replay was checked in plain archive trees with repository discovery disabled, and all 70 forward/all 66 reverse hashes matched. No additional checkout was created.

The 62 unowned final66 peers and all 1,873 preexisting paths outside that overlay retain their bytes, file modes and symlink targets. All six lock/generated-source hashes are unchanged. `preservation-receipt.json`, `replay-receipt.json` and `generated-output-inventory.json` record this. The parent archive/manifest were reread unchanged at completion; no parent writes occurred. No FsceneRealizer, ScreenDebugPresentation, facade/wire, Android, normal main/loader, materials/assets, dependency/pin or repository-doc changes were authored.

## Parent boot commands

The parent owns baseline capture and the approved simulator. These commands were **not run here**. Set `APPROVED_SIMULATOR_ID` to the simulator approved by the parent; do not discover or use another device. Work from the imported parent's `dart3d/example` directory.

```sh
/Users/jasonholt/zero/bin/dn run -d "$APPROVED_SIMULATOR_ID" --debug \
  --target lib/u3_outline_views_main.dart \
  --dart-define=DART3D_U3_OUTLINE_MODE=off \
  --dart-define=DART3D_U3_OUTLINE_SINGLE=false \
  --dart-define=DART3D_U3_OUTLINE_TARGET_MSAA=false
```

Boot selectors are exact: `DART3D_U3_OUTLINE_MODE=off|control|outline`, `DART3D_U3_OUTLINE_SINGLE=false|true`, and `DART3D_U3_OUTLINE_TARGET_MSAA=false|true`. Repeat with `SINGLE=true` for the actual host single-screen route and `TARGET_MSAA=true` for the existing target MSAA4x route. The same fixture is used in all combinations. Boot Control and Outline directly as separate initial-binding cases too. Each native source branch compiles; pure-Dart tests serialize both screen routes and both target AA configurations. Only the default Off/split/no-AA entry point was app-built here.

Off uses the ordinary technique without the outline tail. Control builds/captures the mask and uses the identical tail, whose control branch returns ordinary base RGBA. Outline enables the pinned contour arithmetic. The private marker `__u3_outline_views_probe__` controls only instrumentation: its transform x is Off=0/Control=1/Outline=2, y labels the camera toggle. Selected geometry is resolved exclusively from the actual native SelectionOutline map.

There are two deliberately different screen cameras, layer masks and physical-pixel viewports: screen A `[0,0,570,570]`, layers 3; screen B `[590,140,380,430]`, layers 1. The single-screen boot omits the viewport and second screen. The manual target is 96×72, layers 3, with a third camera and explicit none/MSAA4x AA. Raster and output sizes are logged; requested scale is one. Reduced-scale three-physical-pixel parity remains unproven.

The selected orange asymmetric mesh owns two native primitives. Its separated authored cuboid child must remain unoutlined. The blue native baked batch owns three wedges, and all three are selected together. Screen B excludes that batch by layers. Colors use exactly representable floats: mesh `(1,.25,.0625,0)` tests pinned alpha-zero-to-one substitution; batch `(.0625,.5,1,.5)` tests fractional coverage. Highlight alpha is coverage, not a translucent-border promise. General skin/morph/material-displacement coverage is deferred; a selected deformer logs BLOCKED rather than receiving a rigid substitute.

## Button sequences and observations

Start paused, camera A, Off, with no highlights. Wait for the initial dirty target's `U3OV due` and `target` raw output before any selection operation. Capture the ordinary screen baseline first.

For static Off/Control/Outline preservation, keep motion paused, camera unchanged, all inputs unchanged:

1. In Off, press **Set colors**, then **Render target**. Save screen evidence and the raw `target` output as the unoutlined base.
2. Choose **control**, press **Render target**. Save `target`, `mask`, `alpha-input` and `alpha-output` files. Screen and target ordinary base must remain unchanged; the real mask must contain the two colors and owned draws.
3. Choose **outline**, press **Render target**. Save the same outputs. Compare raw base RGBA outside the mask-derived radius-three contour against Off/Control; contour pixels require the selected neighbor RGB and alpha one. Authored child geometry must not enter the mask.

Use a fresh boot for the manual admission sequence, or clear and explicitly render to establish an unoutlined baseline:

1. Choose **outline** and wait for screens, leaving the clean target unchanged.
2. Press **Set colors**, do **not** press Render target. Screens must gain outlines. `public-highlights` causes only a stored-target blit/readback, named `stored-...set...dirty=false`; compare it with the initial unoutlined target. There must be no intervening `due`, `target-mask-encode` or `target-normal-encode` for that target.
3. Press **Render target**. The public render request admits the due draw. Observe `due`, mask encoding, ordinary target encoding on the same buffer, and raw target contour appearance.
4. Press **Clear**, do **not** render. Screens must clear. The separate stored readback must still contain the previous contour, with no due/render encode events in this interval.
5. Press **Render target**. The new due draw must erase the stored contour. Save each phase separately; never collapse set and clear.

For repeated camera/set/clear and moving alignment, choose Outline, Set colors, then **Play**. The asymmetric mesh advances under existing native animation/host update; the authored child follows but stays unselected. Capture continuous screen video while toggling **Camera A/B**, Clear/Set colors, modes and **Rebind views**. Camera toggles move screen B in split mode and the actual host camera in single mode; screen A and the target remain independent in split mode. Rebind views uses public `updateViews`, replaces view runtime and must not render a clean manual target. Pause before decisive static byte comparisons. Rebind modes and view lists to exercise installed-technique replacement, not just the builder object.

`mask-encoded` and `screen-didRender` logs include binding, mode, camera case, host sample time, raster/output dimensions, sampled camera/layers and draw translations. The screen callback also samples the actual consumer camera and the actual base scene's selected native draws by identity. Those are CPU observations, not GPU completion or proof that a particular screenshot used that sample. Correlate repeated transitions and moving silhouettes in actual consumer video. Screen enqueue order remains UNKNOWN. There is no raw screen-attachment readback seam in this fence; exact screen RGBA preservation therefore stays unproven unless the parent obtains actual screen attachment evidence. Target raw RGBA is available through the actual scheduled target.

## Raw outputs and retrieval

Every due target exports its actual resolved color texture after ordinary rendering in that same command buffer. Target mask readback is rgba16Float. Highlight ingress exports the existing stored target with blit-only command buffers; this observes stored bytes without admitting a render. The opaque target clear `(0,0,0,1)`, exposure save/restore, native AA resolve/store and renderDueTargets admission remain intact.

A due Control/Outline target additionally encodes a private compositor-only alpha oracle. Three vertical regions in the supplied base contain known premultiplied RGBA8 bytes: `(0,0,0,0)`, `(32,64,16,128)`, `(48,24,80,255)`. It binds the **actual captured mask** and identical `u3_views_outline` function, mode/configuration and native destination pixel format, including MSAA resolve when requested. Only the base sampler is replaced with this private known input. `alpha-input` records its actual native-format bytes; `alpha-output` records the result. This is an arithmetic/encoding oracle only, not public transparent-target support. Unsupported alpha pixel formats log BLOCKED, with no substitute shader or public feature.

Readback is asynchronous through the submitted command buffer's completion handlers, retaining staging buffers and relevant resources. There are no waits, new queues, timers, retries or explicit post-scene Metal compositor. Each completion writes unpadded `<app data>/tmp/u3-outline-<case>.rgba` plus `.json`, and also emits independent base64 row records through existing d3Log. Labels include target/view, mode, camera case, AA samples and existing callback time. Stored reads label selected IDs/set-or-clear, dirty status and sample time. The JSON schema contains `label,width,height,pixelFormat,bytesPerPixel,bytesPerRow,origin,encoding`; bytesPerRow is packed, with no GPU alignment padding. Use actual `pixelFormat`: common Metal enum values 80/81 mean BGRA8 UNORM/sRGB, 70/71 mean RGBA8 UNORM/sRGB, 115 means little-endian RGBA16Float. Do not interpret BGRA or encoded sRGB bytes as linear RGBA.

Supported parent retrieval commands (not executed here):

```sh
# Run while the parent owns the approved simulator/app session.
xcrun simctl spawn "$APPROVED_SIMULATOR_ID" log stream --style compact --level debug \
  --predicate 'subsystem == "com.jasonholtdigital.dart3d"' > u3-outline-runtime.log

# In another shell, after desired completion callbacks:
probe_data=$(xcrun simctl get_app_container "$APPROVED_SIMULATOR_ID" com.jasonholtdigital.dart3dExample data)
mkdir -p u3-outline-raw
rsync -a --include='u3-outline-*' --exclude='*' "$probe_data/tmp/" u3-outline-raw/
```

Stop the log stream normally after capture. Files support retrieval even if unified-log privacy hides dynamic rows. Case filenames sanitize punctuation; JSON `label` retains the full case. Match each file's dimensions, format, byte count and callback time. No actual readback file exists in this host-only packet.

## Acceptance and blocked criteria

The independent review approves investigation, not success. Accept only what actual observations establish:

- Separate installed copies on the actual host, both siblings and due target; correct own camera/layers/dimensions/colors/primitive/batch membership; authored descendants excluded. Exercise replacement/rebinding as well as initial binding.
- Manual target phases observed separately, with unchanged stored bytes during clean phases and due-path encode logs establishing admission. Screens must respond during both clean-target phases.
- Same-buffer target mask-before-normal-render and composite-only technique must execute on the real scheduled target, for none and MSAA4x, preserving ordinary output away from contours. A separate compositor demonstration cannot rescue this lane.
- Screen evidence must include repeated transitions and native moving-draw/base-mask alignment. Settled static endpoints and didRenderScene alone cannot prove ordering or GPU completion.
- Private zero/fractional-alpha input must traverse the same function/configuration/encoding, preserve every outside-contour RGBA component and produce expected neighbor RGB/alpha one on contours. This closes only the private compositor boundary.
- Any missing technique/library/sampler, unsupported readback format, command-buffer error, wrong-view/stale mask, moving misalignment or inability to observe the needed boundary is BLOCKED or INCONCLUSIVE. Do not add synchronous waits, cross-queue fallback, a new clock/lock/revision scheme or the rejected explicit Metal presentation compositor.

W34 diagnostic coexistence, arbitrary deformers, reflection/hidden/opacity/overlap cases beyond the fixture, reduced-scale width, performance and whole U3 remain separate gates. Existing two-drain retirement is a heuristic; retained mask-buffer resources do not certify hidden screen-consumer lifetime. Creation/rebind/retire and command-buffer errors are instrumented. Resize/view/scene/detach repetitions can supply bounded evidence, never a lifetime guarantee. No production integration before the Android prerequisite.

## Source hooks and cleanup

SelectionOutline's internal iteration is read-only; the native map remains authoritative and lifecycle B is unchanged. The host captures after existing LOD/facing/blend updates. RenderTargets owns due admission and target encoding; its existing snapshot/main poke owns sibling handoff. ToneMapping appends the tail after existing artistic/diagnostic resolves and offers a composite-only target definition. The disposable file owns derived templates, per-binding private graph/material/camera/texture attachments, raw readback and private alpha input. It reuses detached graph entries across frames, copies no animations and borrows no W34 published attachments.

Normal-main generated configuration has been restored using `dn build ios --simulator --debug --config-only --no-codesign --target lib/main.dart`; no outline boot defines remain. SDK-generated license values are preserved and redacted from delivered build logs. The generic probe app and build outputs remain on disk, uninstalled. The next normal-main build uses `lib/main.dart`. To return an already-running parent's session to normal, stop the probe and explicitly launch the normal entry point through the parent's approved tooling.

Kept worktree outputs: imported final66 context; the eight source paths; ignored package/example `.dart_tool`, build/test outputs, CocoaPods/plugin/SPM generated files, normal-main generated config, and `dart3d/example/build/u3-outline-views-derived/Build/Products/Debug-iphonesimulator/Runner.app`. `generated-output-inventory.json` lists all generated additions and hashes/modes/symlinks. Replay scratch was removed. No generated lock changes, extra source files, commits, pushes, children or external-system writes were made. Parent owns comment audit, device proof and independent final review.
