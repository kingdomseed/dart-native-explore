# Run the native particle interception probe

The throwaway instrument is ready for parent integration. It does not answer the native interception question yet. Dart analysis, Swift typecheck, adapter compilation, source preservation, and archive replay pass. Runtime, Metal compilation and execution, devices, pixels, interaction, and performance are NOT_RUN.

## Integrate the four-file instrument

Use the prepared checkout at `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-7a4f9ea5`, or replay the packet over the same accepted58 baseline. The worker did not edit `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb`.

The checkout started clean at `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. The accepted58 archive SHA256 is `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706`. Every unique relative regular archive entry matched the adjacent parent manifest before import. Only that archive was imported. The earlier mapped-quad archive was read as a fixture reference. Its native hook, old main, and patch were not imported.

`probe.patch` is relative to base HEAD plus accepted58, not bare HEAD. It changes exactly these four paths.

- `dart3d/ios/Classes/ParticleDebugProbe.swift` contains the one renderer-local scene technique and disposable state.
- `dart3d/ios/Classes/SceneViewHost.swift` owns the optional probe, accepts private viewConfig fields, applies requests after the existing mutation drain, and restores state on explicit removal, scene load, and host destruction.
- `dart3d/example/lib/w34_particle_probe_scene.dart` builds the fixed scene with existing document APIs.
- `dart3d/example/lib/w34_particle_probe_main.dart` registers plugins, loads through `SceneController.loadDocument`, and sends viewConfig requests from four buttons.

Use `owned-source.tgz` for complete contents of those four files. Use `runtime-source.tgz` for the coherent accepted58 plus probe overlay. Its 61 paths include 57 unchanged accepted files, the changed host, and three new probe files. Verify either archive with its adjacent `-sha256.txt` manifest. The runtime archive intentionally contains accepted Android sources unchanged from accepted58. The worker made no Android changes.

`owned-baseline.tgz` contains the original accepted58 host. `owned-baseline.json` records its hash and the absence of the three new paths. `accepted58-sha256.txt` retains the exact input manifest. `artifact-sha256.txt` hashes the packet and retained adapter product.

## Launch the fixed target

From `dart3d/example`, run the target on the parent's approved simulator after the parent checks availability.

```sh
/Users/jasonholt/zero/bin/dn run --debug -d <parent-approved-simulator-id> --target lib/w34_particle_probe_main.dart
```

No extra defines, asset generation, material baking, package upgrades, or scheme edits are needed by the instrument. The parent owns actual app build and native execution. The worker did not run a Runner build or dn run. The historical manual Runner failure involved its scheme pre-action requiring FLUTTER_ROOT. This packet does not repeat that build or claim to resolve it.

The footer reserves 112 points outside the Expanded SceneView and inside SafeArea. Its header reports requests, not applied native success. Button labels use the installed DartNative `Button(title:, onPressed:)` API. Layout and visibility remain NOT_RUN.

## Observe in this order

1. Keep initial **Off**, wire off, and the population live. Wait about four seconds for the native emitter to populate. Capture the moving marked sprites and ordinary mapped mesh. If particles or the mesh are already missing, the premise cannot be judged.
2. Tap **Freeze**. Capture Off again after motion has stopped. Keep the same camera and viewport. Check the native `applied` record for the same `system`, `attached=true`, `speedFactor=0`, and `birthRate=0`. The record alone does not prove frozen visible population.
3. Tap **Constant**. Retain the complete console, library diagnostics, native state record, and matched image. The left mesh must retain its projected shape and become conspicuous magenta. That mesh is the shader and node-binding witness.
4. Tap **Off**. Confirm the ordinary mesh and the same frozen marked sprites return at the same positions. Preserve these matched images before testing wire.
5. Tap **Wire on** while Off and frozen. Capture ordinary filled geometry with native wire. Look for the mesh's internal index diagonal. Record particle edges and occlusion as observations, not as assumed support.
6. Tap **Constant** with wire still requested. Capture the result separately. A working mesh witness without wire from step 3 remains the decisive interception comparison.
7. Tap **Wire off**, then **Off**. Capture restoration against the frozen Off image.
8. Tap **Resume**. Check that the same system remains attached and that speed and birth rate return to their saved values. Confirm visible motion separately.

Do not reload or rebuild the scene between these comparisons. Freeze sets the existing native system's speedFactor and birthRate to zero. Resume restores the values saved from that same object. The instrument never calls reset, removes or reattaches a system, or creates another particle simulation.

If Freeze itself makes ordinary particles disappear, retain that result and use the live Off and Constant comparison only as a weaker observation. Do not claim matched-population proof. Stop rather than constructing a replacement renderer.

## Interpret the mesh and particles separately

The left control is an opaque, indexed, normal-mapped quad with four original vertices, uint16 indices `[0,2,1,0,3,2]`, and the internal 0-to-2 diagonal. It retains the earlier fixture's normals, tangents, asymmetric 64x64 normal payload, and normal-texture transform. Its ordinary PBR factor is `(0.65,0.42,0.2,1)`, metallic 0.15, and roughness 0.6. It has a fixed 0.18-radian Y rotation and scale 0.65.

The right emitter is a normal `particleEmitterComponent`. The existing native realizer constructs and attaches its original `SCNParticleSystem`. It emits eight sprites per second, with four-second lifetime, speed 0.6, size 0.26, and no modules or gravity. A 16x16 texture has a transparent border, an asymmetric white L, an amber field, and a blue corner. Nonwhite startColor is `(0.45,0.9,0.65,1)`. The opaque blue bar is closer to the camera than the emitter. All three objects are authored above the footer in the separate scene area; actual framing is unverified.

The one technique pass is `DRAW_SCENE`. Its custom vertex reads position at attribute 0, the inspected public SCNVertexSemanticPosition value, and the documented `scn_node.modelViewProjectionTransform`. The runtime source needs only metal_stdlib and does not depend on an SDK framework include. Its fragment returns constant `half4(1,0,1,1)`. It does not sample particle color, alpha, normal, depth, or texture. It can therefore fill a sprite's transparent texture border if it intercepts that draw. That footprint change is evidence to record, not a sampled-alpha claim.

Interpret the result using these criteria.

- If the projected mesh is missing, malformed, or unchanged, compilation or binding is unresolved. Preserve exact diagnostics. The particle question stays open.
- If the projected mesh becomes magenta and the original particles remain textured and tinted, this route fails the interception premise.
- If the mesh becomes magenta and particles disappear, this route also fails the requested premise. Do not add another renderer to make it pass.
- If the mesh becomes magenta and the original visible particle draws also become magenta, record interception only. Compare frozen Off and Constant and retain system identity records. This does not prove sampled color or tint, axial fragment depth, actual particle triangle edges, display calibration, target isolation, or whole-W34 success.

Native showWireframe is an independent public diagnostic. Visible wire on a mesh does not prove the custom Metal program intercepts particles. Wire behavior under the occluder is an observation for this fixture, not general edge or depth acceptance.

## Read actual native state

All instrument records use `W34ParticleProbe` through existing d3Log. There is no per-frame log stream.

`request` records `mode`, `wire`, `frozen`, and `binding=notYetObserved`. Do not treat this as applied state.

`bound` records renderer, original scene, emitter node, and original system identities. It records systemCount, mesh identity, element and primitive counts, and the actual normal texture. It records `population=unavailable`, `positions=unavailable`, and `callbacks=notInstalled`.

`library` records the actual MTLLibrary identity, device name, exported functions, and the resolved vertex and fragment function types. `techniqueCreated` records the created technique identity and `libraryAttached`. These records establish object creation only after native execution. They do not establish pipeline binding or pixels.

`applied` and `removed` record the actual host technique identity, sequence in `passes`, actual library identity and function names, requested and actual wire, current debugOptions, requested freeze, system identity, attachment, actual speedFactor and birthRate, saved simulation values, actual image, and tint. A `removed` record is written before saved fields are cleared, after actual values are restored. The request fields in that record still describe the preceding request.

Error keys are `requestError`, `libraryError`, `functionError`, `techniqueError`, and `stateError`. Metal library errors include NSError domain, code, localized description, and userInfo. A failed library creation leaves the ordinary technique active; the request can still say constant. Retain the error and inspect actual `passes` instead of reading the request as success.

SceneKit's subsequent pipeline and binding diagnostics are not exposed as a public SCNTechnique error callback in the inspected interface. Capture SceneKit's console diagnostics. `pipeline=unobserved` is deliberately emitted even after assigning a technique. No missing binding is suppressed or replaced by another shader route. Library creation is attempted once per probe activation. Relaunch to retry after an error.

The private transport requires `_w34ParticleFixture` equal to `w34.particle-technique.r1` and `_w34ParticleEnabled=true`. The fields `_w34ParticleMode`, `_w34ParticleWire`, and `_w34ParticleFrozen` carry the full request. Binding also requires exact fixture mesh and emitter node names and one attached native system. No public debug API, opcode, serializer, schema, material recipe, or selection implementation changes.

## Respect the proof limits

The probe preserves the technique captured at fixture binding and only its contribution to showWireframe. Other debugOptions bits remain current. Off restores the captured ordinary technique. The stage is fixed, so there is no current-stage-update promise. The ordinary tone/HDR camera setup remains in place while Constant replaces the host's technique. A constant magenta result has no calibrated transfer meaning.

There is one original scene and host presentation. No authored render target, sibling isolation experiment, copied scene, custom billboard geometry, particle reconstruction, material SCNProgram, callbacks that write data, second clock, global registry, new lock, or fallback renderer is included. Native callbacks are not installed. Population counts and positions have not been measured, even though the public particle API supports observation callbacks.

Source grounding is retained in `source-api-evidence.txt`. The installed iPhoneOS27.1 headers document the scene-pass mechanism and automatic node semantics, but do not promise particle interception. SCNParticleSystem conforms to SCNAnimatable rather than SCNShadable. ToneMapTechnique supplies the existing public MTLLibrary attachment precedent. The Apple page fetch returned JavaScript-required content. The repo-local DartNative skill was read fully. Its referenced vendored plugin guide is absent in this checkout; installed headers and Button source were inspected directly.

## Check preparation receipts

`command-results.json` records exact commands, working directories, return codes, and log paths.

- `example-pub-get.log` records successful dependency resolution using dn. No tracked lock or registrant changed.
- `dart-analysis.log` records final targeted dn analysis with no issues, exit 0.
- `swift-typecheck.log` records final full adapter Swift typecheck, exit 0, with an empty log. The earlier successful typecheck is retained as `swift-typecheck-first.log`.
- `swift-adapter-compile.log` records full adapter compilation, exit 0, with an empty log. The retained `adapter/libdart3d.dylib` is arm64 and reports platform IOSSIMULATOR, minimum iOS 16.0, and SDK 27.1 in `adapter-product.log`.
- `swift-adapter-compile-first.log` retains the successful first compile's incompatible-sysroot warning. The final compile uses an explicit simulator SDKROOT. No machine setting or shared cache was repaired.
- `diff-check.log` records an empty successful git diff check.
- `replay-proof.txt` records successful forward check and apply, owned-byte comparison, reverse check and apply, and both archive replays.

The compile does not compile the embedded Metal source or build the app kernel. Device queries and use, simulator boot, runtime, Metal library compilation, pipeline execution, pixels, performance, material baking, tests, full suites, and whole-W34 acceptance are NOT_RUN. No children, commits, pushes, PRs, external writes, or shared-cache deletion occurred.

## Reverse and clean up

While the fixture is alive, send the existing viewConfig route with the exact fixture tag and `_w34ParticleEnabled=false` to restore technique, wire contribution, speed, and birth rate. The dedicated screen sends that request on dispose. Host destruction also restores the saved system values. A stopped render loop may not drain a dispose request before destruction; this instrument makes no teardown-time runtime guarantee.

Before removing source, ensure no later edits overlap the four owned paths. Run `git apply --reverse --check /private/tmp/dart3d-e9-particle-technique-probe-20261027/r1/worker/probe.patch`, then reverse the patch. Reversal restores the accepted58 host and removes only the three new probe files. Do not reset the imported accepted sources or restore the host from bare HEAD.

Replay exported base plus accepted58 into packet-owned scratch without making a checkout or index. Forward replay preserved all 1,933 unowned paths and six locks. Reverse replay restored all 1,934 baseline paths and accepted58. Both complete-source archives reproduced the final tree. `preservation.json`, `unowned-sha256.txt`, and the baseline and final snapshot files retain hashes. Only the owned replay scratch was removed.

Retained outputs are the imported accepted58 overlay, the four instrument files, this packet with the adapter product, and generated ignored dependency/configuration outputs listed in `ignored-generated-retained.txt`. Those include example `.dart_tool`, plugin metadata, Android local.properties, example build output, and iOS DartNative generated configuration and ephemeral files. They are excluded from source archives. All six tracked lock and registrant entries remain byte-identical. No replay scratch, old native hook, old main, or superseded patch was left in the checkout.
