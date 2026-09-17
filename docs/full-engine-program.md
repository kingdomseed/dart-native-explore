# dart3d full-engine program plan

dart3d grows from a verified core engine to full `flutter_scene`-surface parity. For app authors, every upstream document feature, material path, and platform capability works on SceneKit and Filament+Jolt with the same behavior. For the next engineer, every remaining feature lands as a verified unit on both platforms. Workstreams W15 through W34 run in dependency order, each as one PR on the public repo.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

The program runs `pstack/skills/poteto-mode/playbooks/orchestrate.md`. Workstream owners open PRs against `main` on `kingdomseed/dart-native-explore`. The operator lands each PR after a clean verdict. The older W11 to W20 scopes in `extended-surface-program.md` carry over verbatim where noted.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### Arm the program

- [x] State the protocol and this plan to the operator, then stop. Start execution only on her explicit go. (Go given 2026-09-17: "Approved. Good luck Commander.")
- [x] On her go, write the goal line into this file with this exact text. "docs/full-engine-program.md, workstreams W15 through W34 in the dependency order below, the verification rule above, the operator lands each PR, done when every box carries evidence." This line is the playbook's `/goal` marker carried as a plan line.
- [ ] Read these from trunk at program start. Re-read them at every tick. When pstack is not vendored in this repo, read them from the installed plugin directory at `~/.local/share/devin/cli/plugins/cache/github.com_kingdomseed_pstack-devin_plugins_pstack-26c983c8/0.15.2/` instead of `git show origin/main:`.
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/orchestrate.md`
  - [ ] `git show origin/main:pstack/skills/swarm/SKILL.md`
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/opening-a-pr.md`
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/feature.md` for the workstream owners
- [ ] Arm the 30-minute audit tick as a terminal `/loop` while execution waves run.
- [ ] Tick prompt, verbatim. "Re-read the execution playbook and the goal line in the plan file. Audit the operation against both and fix drift. Probe every active lane and judge progress by side effects only. Stand down a stuck lane and dispatch its replacement. Then send the operator a status message, whether or not anything changed, with the queue table of workstream, owner, state, and evidence, the verdicts since the last tick, open operator gates, and blockers."
- [ ] On the operator's hold or stand-down, send every owner a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per workstream with disjoint file boundaries. iOS owners touch only `dart3d/ios/`, Android owners `dart3d/android/`, Dart owners `dart3d/lib/` and `dart3d/example/`, spec owners `docs/`. A workstream needing both platforms runs as one wave of two platform owners plus one spec owner.
- [ ] Follow this dependency graph.
  - [ ] W21, W22, W23, W24, W25, W26, W29, W30 are independent and first. All branch from `main`.
  - [ ] W15, W16, W18, W19 are independent and may start any time.
  - [ ] W17 after W25, since `skyEnvironment` relighting consumes the effects groundwork.
  - [ ] W20 after W25, since per-volume blending shares the effects machinery.
  - [ ] W27 after W28, since decal materials ride the shader contract.
  - [ ] W28 after W21 and W22, since the material contract must be settled first.
  - [ ] W31 after W26, since the splat renderer uses instanced quads.
  - [ ] W33 after W14, already landed, plus the host widget-to-texture bridge named in its scope.
  - [ ] W32 and W34 may start any time after W21.
- [ ] Hold the review gate. W21, W22, W24, W25, W17, W18, W26, W27, W31, and W34 change what the operator sees. They wait for her review in chat with screenshots and a video before merge.

### PR mechanics, for every workstream

- [ ] Branch `w<N>-<slug>` from `main`, open the PR ready with `gh pr create --base main`, push with hooks on.
- [ ] Run `dn analyze` and `dn test` in `dart3d/example` once before the PR-facing push.
- [ ] Run `/pstack:deslop` before each commit and `/pstack:no-comments` before review.
- [ ] Triage every Devin Review comment per `pstack/references/bugbot-triage.md`.
- [ ] Rebase onto current `main` before the merge-ready report.

### Verdict and merge, for every workstream

- [ ] At the merge-ready head SHA, run the swarm. One gates lane. The ten live lanes from the workstream's "Verify, live" block. The perf lane from its "Verify, perf" block. One audit lane that reads the diff and the receipts and distrusts the PR body.
- [ ] Clean only when every lane is PASS. Findings go back to the owner. A new head gets a fresh swarm.
- [ ] The operator squash-merges after the clean verdict and, for gated workstreams, her in-chat sign-off.

### Boot recipe, for every live lane

Each live lane drives the real surfaces. Android lanes use the phone A142 (`adb -s 00064149A002033`). iOS lanes use the iPhone simulator; the physical iPad is optional extra coverage when the operator is free. The control surface is the example app's harness lane, `dn run --dart-define=DART3D_SCENE=harness`, plus adb `input` taps, `uiautomator dump`, and `screencap`.

- [ ] `git fetch origin <branch> && git checkout <head SHA>`.
- [ ] `cd dart3d/example && dn run -d 00064149A002033 --dart-define=DART3D_SCENE=harness` and wait for the `harness` log line.
- [ ] Drive input only through adb taps and swipes or the harness's `--dart-define` phases. Read `dn` output and `logcat -s dart3d` for diagnostics.
- [ ] Save every screenshot to `/tmp/swarm-w<N>/lane-<n>/<slug>.png` and return the paths with the report.

## W21. Land materials and textures conformance

**Depends on.** None. Branches from `main`.

**Files.**

- [ ] Edit `dart3d/ios/Classes/FsceneRealizer.swift` (alphaMode, UV-set selection, mip renormalization, EXR decode).
- [ ] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt` (alphaMode, UV sets) and `TextureFactory.kt` (KTX2).
- [ ] Edit `dart3d/ios/Classes/TextureDecode.swift` or the texture block of `FsceneRealizer.swift` for KTX2 and EXR.
- [ ] Edit `docs/texture-material-spec.md` and `docs/environment-ibl-spec.md` to record the realized semantics.

**Build.**

- [ ] Realize `alphaMode` `mask` with `alphaCutoff` and `blend` on both platforms. iOS uses `SCNMaterial` blendMode plus transparency; Filament uses `BlendingMode` masked and blended.
- [ ] Decode `ktx2` texture payloads on both platforms. Android uses Filament's `KTX2Reader`. iOS uses `MTKTextureLoader` on the decoded basis or falls back to CPU transcode with a documented note.
- [ ] Honor `texCoord` for every texture slot, selecting the second UV set when present on both platforms.
- [ ] Decode `.exr` environment payloads on iOS, matching the Android `.hdr` path.
- [ ] Renormalize mipmaps on iOS when sRGB source textures ship without full chains.
- [ ] Normalize light intensity units across platforms. Filament reads candela and SceneKit reads a unitless multiplier, so pick one semantic, document it in the spec, and convert at decode on the platform that differs. Replace the Android directional `×10` heuristic with the conversion.

**You see.**

- [ ] A document with `alphaMode:blend` foliage or glass renders transparent on both platforms, not opaque.
- [ ] A KTX2-authored texture displays on both platforms.
- [ ] A two-UV-set model lights its second UV set where the document says so.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Add alphaMode/KTX2/UV-set fixture cases to `dart3d/example/test/` asserting decode emits the realized semantics. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run the showcase tour on trunk and head. Save `w21-lane1.png`. Pass when every trunk-verified scene still renders on head.
- [ ] Lane 2. A blend-mode quad renders translucent on Android. Save `w21-android-blend.png`. Pass when the quad shows the scene through it.
- [ ] Lane 3. The same on the iOS simulator. Save `w21-ios-blend.png`. Pass when identical.
- [ ] Lane 4. A masked foliage texture cuts out on Android. Save `w21-android-mask.png`. Pass when texels below `alphaCutoff` are absent.
- [ ] Lane 5. A KTX2 texture decodes and displays on Android. Save `w21-android-ktx2.png`. Pass when the texture is visible.
- [ ] Lane 6. The same KTX2 texture on iOS. Save `w21-ios-ktx2.png`. Pass when identical.
- [ ] Lane 7. A second-UV-set model shades from UV1 on both. Save `w21-uv1.png`. Pass when the light map reads from the second set.
- [ ] Lane 8. An EXR environment lights a scene on iOS. Save `w21-ios-exr.png`. Pass when the IBL visibly responds.
- [ ] Lane 9. Light units, one directional light at a spec-declared intensity, match brightness across platforms. Save `w21-units.png`. Pass when exposures match within a stop.
- [ ] Lane 10. The dice table still rolls and settles on Android. Save `w21-dice.png`. Pass when a settle event fires and dice rest in the tray.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time on the dash scene, ms per frame.
- [ ] Probe. `logcat` Choreographer frame timing on Android and the iOS stats overlay, interleaved trunk then head.
- [ ] Baseline. Record trunk dash frame time first.
- [ ] Rule. Head within 10 percent of trunk. A regression beyond that fails.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w21-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of a blend, a mask, and a KTX2 scene. Save it as `docs/artifacts/w21-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W22. Add glTF material extensions and the conformance harness

**Depends on.** None. Pairs naturally after W21.

**Files.**

- [ ] Edit both realizers for the `KHR_materials_*` family.
- [ ] Create `dart3d/example/tool/conformance_runner.dart` or the harness phase that walks a catalog.
- [ ] Create `dart3d/example/test/material_extensions_test.dart`.
- [ ] Edit `docs/texture-material-spec.md`.

**Build.**

- [ ] Realize clearcoat, sheen, specular color, anisotropy, iridescence, transmission with roughness, volume attenuation, dispersion, diffuse transmission, IOR, and `KHR_texture_transform` where each platform's material system supports them, approximations logged where not. Filament exposes most of these. SceneKit exposes fewer, so the spec table names each mapping or its documented approximation.
- [ ] Vendor the Khronos glTF-Sample-Assets manifest subset into the harness and run the 86-asset catalog through the importer, asserting each document realizes without a warn-once.
- [ ] Golden-image the 37 upstream `smoke_render` scene equivalents that apply to dart3d's surface.

**You see.**

- [ ] The Khronos catalog entries that exercise each extension render their distinguishing feature, not a fallback gray.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] The catalog runner emits a per-asset pass or warn matrix as a test artifact. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w22-lane1.png`. Pass when trunk scenes still render.
- [ ] Lane 2. `TransmissionTest`-style glass transmissive on Android. Save `w22-android-transmission.png`. Pass when the background shows through the object.
- [ ] Lane 3. Same on iOS or the documented approximation logged. Save `w22-ios-transmission.png`. Pass when rendered or logged.
- [ ] Lane 4. Clearcoat highlights on both. Save `w22-clearcoat.png`. Pass when the second specular layer is visible.
- [ ] Lane 5. Sheen on cloth on both. Save `w22-sheen.png`. Pass when the fabric rim lights.
- [ ] Lane 6. Iridescence hue shift on both. Save `w22-iridescence.png`. Pass when color varies with angle.
- [ ] Lane 7. Texture transform offsets a base map on both. Save `w22-uvtransform.png`. Pass when the map shifts per spec.
- [ ] Lane 8. The catalog matrix shows zero unhandled-extension warnings on previously-realized assets. Save `w22-catalog.png`. Pass when the matrix is green for prior assets.
- [ ] Lane 9. Golden images for three smoke scenes match within tolerance on both. Save `w22-golden.png`. Pass when diffs sit under the threshold.
- [ ] Lane 10. Dice still roll on Android. Save `w22-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. fcar showcase frame time.
- [ ] Probe. Same frame-timing path, trunk then head.
- [ ] Baseline. Record trunk fcar frame time.
- [ ] Rule. Head within 10 percent of trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w22-review-<slug>.png`.
- [ ] Record a video cycling four extension scenes. Save it as `docs/artifacts/w22-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W23. Close physics fidelity gaps

**Depends on.** None.

**Files.**

- [ ] Edit `dart3d/ios/Classes/SceneViewHost.swift` (joint approximations, sweep upgrade, pairwise exclusion attempt).
- [ ] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/JoltWorld.kt` (raycast normals, contact manifold).
- [ ] Edit `docs/physics-schema.md` and `docs/android-parity-spec.md` with final semantics.

**Build.**

- [ ] Replace iOS joint approximations with the nearest faithful SceneKit construction, or document the exact divergence where none exists. `fixed` uses `SCNPhysicsBallSocketJoint` with zero limits or a welded constraint pair. `revolute` limits and motors get a custom per-frame enforcement if SceneKit cannot express them. `generic` maps to the closest primitive with the divergence logged.
- [ ] Attempt `collide:false` pairwise exclusion on iOS via category masks. If SceneKit cannot express per-pair exclusion, document it as a permanent platform limit and keep the warn-once.
- [ ] Give iOS multi-primitive skinned meshes skinners on every `d3prim:` child.
- [ ] Upgrade the iOS shapecast distance to `SCNPhysicsContact.sweepTestFraction` semantics.
- [ ] Improve Android raycast normals beyond the sphere-probe approximation and expose more than one contact manifold point where Jolt's JNI exposes them.
- [ ] Document `clearForces` as permanently infeasible on Jolt in the spec, closing the deferred item.

**You see.**

- [ ] A hinged door limited by a `revoluteJoint` stops at its limit on iOS the same as Android.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Joint semantics cases in `dart3d/example/test/` for the new mappings. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Dice roll plus joint harness both sides. Save `w23-lane1.png`. Pass when existing joints behave identically.
- [ ] Lane 2. A limited revolute joint holds its limit on iOS. Save `w23-ios-hinge.png`. Pass when the body stops at the limit angle.
- [ ] Lane 3. Same on Android. Save `w23-android-hinge.png`. Pass when identical.
- [ ] Lane 4. A fixed joint holds two bodies rigid on iOS. Save `w23-ios-fixed.png`. Pass when the pair moves as one.
- [ ] Lane 5. A `collide:false` pair passes through each other on iOS or logs the platform limit. Save `w23-ios-exclude.png`. Pass when either exclusion works or the documented warn fires.
- [ ] Lane 6. Multi-prim skinned mesh deforms on all prims on iOS. Save `w23-ios-multiprim.png`. Pass when every prim follows the skeleton.
- [ ] Lane 7. Shapecast distance reports the sweep fraction on iOS. Save `w23-ios-sweep.png`. Pass when the query distance matches the cast.
- [ ] Lane 8. Android raycast normals match surface normals within tolerance. Save `w23-android-normal.png`. Pass when the reported normal is within tolerance of the face normal.
- [ ] Lane 9. Android contact event carries more than one manifold point where Jolt exposes them. Save `w23-android-manifold.png`. Pass when the log shows multiple points or the Jolt limit is documented.
- [ ] Lane 10. The dice table still settles cleanly on Android. Save `w23-dice.png`. Pass when a settle fires and dice rest.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Dice roll settle time and frame time during a roll.
- [ ] Probe. Harness roll on trunk then head, interleaved.
- [ ] Baseline. Record trunk settle time.
- [ ] Rule. Head within 10 percent of trunk on both metrics.

**Review gate.** None. W23 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W24. Close the views and shadow breadth gaps

**Depends on.** None.

**Files.**

- [ ] Edit `dart3d/ios/Classes/RenderTargets.swift` (split-screen, viewport) and the shadow blocks of `FsceneRealizer.swift`.
- [ ] Edit `dart3d/android/.../RenderTargets.kt` and light decode for shadow breadth.
- [ ] Edit `docs/extended-surface-audit.md` status rows.

**Build.**

- [ ] Realize iOS split-screen through multiple `SCNView` siblings or a custom composited pass, and honor `viewport` on screen-target views.
- [ ] Add directional shadow cascades where each platform supports them, contact shadows, and a shadow-catcher material path. Filament exposes shadow options per light. SceneKit needs a blended shadow-only material for the catcher.
- [ ] Investigate the Android `layerMask` 8-bit truncation and widen if Filament supports more layers.

**You see.**

- [ ] Two cameras render side by side on iOS, matching Android's existing split-screen.
- [ ] A transparent plane catches a shadow over DartNative UI on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] View decode cases covering viewport and order in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase plus the W14 render-texture phase on both. Save `w24-lane1.png`. Pass when the W14 sequence still passes.
- [ ] Lane 2. iOS renders two screen views at once. Save `w24-ios-split.png`. Pass when both viewports show their cameras.
- [ ] Lane 3. iOS honors a `viewport` rect on a screen view. Save `w24-ios-viewport.png`. Pass when the image occupies only the rect.
- [ ] Lane 4. Android split-screen still correct after shared changes. Save `w24-android-split.png`. Pass when both views render.
- [ ] Lane 5. Directional cascades distribute shadows on Android. Save `w24-android-cascade.png`. Pass when near and far shadows both resolve.
- [ ] Lane 6. The same intent on iOS or a documented SceneKit mapping. Save `w24-ios-cascade.png`. Pass when shadows resolve or the divergence is documented.
- [ ] Lane 7. A shadow catcher shows a shadow on invisible geometry on Android. Save `w24-android-catcher.png`. Pass when the shadow appears without the plane.
- [ ] Lane 8. Same on iOS. Save `w24-ios-catcher.png`. Pass when identical.
- [ ] Lane 9. A layerMask above 8 bits filters objects on Android or logs the platform limit. Save `w24-android-layers.png`. Pass when the mask applies or the limit is documented.
- [ ] Lane 10. Dice still roll on Android. Save `w24-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time on a shadowed scene.
- [ ] Probe. Frame timing trunk then head.
- [ ] Baseline. Record trunk frame time.
- [ ] Rule. Head within 10 percent of trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w24-review-<slug>.png`.
- [ ] Record a video of split-screen and the shadow catcher. Save it as `docs/artifacts/w24-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W25. Finish the stage-effects matrix

**Depends on.** None.

**Files.**

- [ ] Edit `dart3d/ios/Classes/StageEffects.swift` and `SceneViewHost.swift` effect application.
- [ ] Edit `dart3d/android/.../StageEffects.kt`.
- [ ] Create a LUT asset-resolution path in `dart3d/lib/`.
- [ ] Edit `docs/extended-surface-program.md` support matrix.

**Build.**

- [ ] Replace every remaining effect no-op with a realization or a documented permanent platform limit. iOS gains lensFlare, SSR, GI, godRays, and LUT where SceneKit can express them, else custom passes or documented limits. Android gains filmGrain, autoExposure, standalone chromatic aberration, GI, godRays, and LUT on the same rule.
- [ ] Build the `.cube` LUT asset path through payload or asset refs, then apply on both platforms.
- [ ] Add per-volume blending groundwork in the effects value type for W20 to consume.

**You see.**

- [ ] The support matrix has no silent no-ops. Every cell reads applied, approximated, or documented platform limit.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Effect decode cases for each newly-realized block. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. The W13 eight-step effects phase both sides. Save `w25-lane1.png`. Pass when the phase still passes.
- [ ] Lane 2. A LUT visibly regrades a scene on Android. Save `w25-android-lut.png`. Pass when the grade applies.
- [ ] Lane 3. Same LUT on iOS. Save `w25-ios-lut.png`. Pass when identical.
- [ ] Lane 4. Android film grain visible. Save `w25-android-grain.png`. Pass when grain appears.
- [ ] Lane 5. Android auto exposure adapts to a dark scene. Save `w25-android-ae.png`. Pass when exposure shifts.
- [ ] Lane 6. iOS SSR or its documented limit. Save `w25-ios-ssr.png`. Pass when reflections appear or the limit is logged.
- [ ] Lane 7. iOS lens flare on a bright light or documented limit. Save `w25-ios-flare.png`. Pass when rendered or logged.
- [ ] Lane 8. God rays on one platform where feasible, else the documented limit. Save `w25-godrays.png`. Pass when rendered or logged.
- [ ] Lane 9. Android standalone chromatic aberration without lensFlare. Save `w25-android-ca.png`. Pass when fringing applies.
- [ ] Lane 10. Dice still roll on Android. Save `w25-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time with the full effect stack enabled.
- [ ] Probe. Frame timing trunk then head.
- [ ] Baseline. Record trunk stacked-effects frame time.
- [ ] Rule. Head within 15 percent of trunk. New passes cost something, so the bound is looser.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w25-review-<slug>.png`.
- [ ] Record a video cycling each new effect. Save it as `docs/artifacts/w25-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W26. Expand geometry and add instancing

**Depends on.** None.

**Files.**

- [ ] Edit procedural geometry in both realizers and `dart3d/lib/src/vertex_pack.dart`.
- [ ] Create instancing support in `dart3d/android/.../MeshFactory.kt` or a new `Instancing.kt`, and the iOS equivalent in `FsceneRealizer.swift`.
- [ ] Edit `docs/payload-geometry-spec.md`.

**Build.**

- [ ] Add the remaining upstream primitives. `Cylinder`, `Capsule`, `Cone`, `Disc`, and `Tube` join cuboid, sphere, icosphere, plane, and torus on both platforms.
- [ ] Replace the icosphere UV-sphere approximation with a real subdivided icosahedron on both platforms.
- [ ] Realize `LineSegmentsGeometry`, `RibbonGeometry`, `PolylineGeometry` with solid and dashed, and `BillboardGeometry` where each platform supports them. Filament line primitives are thin, so thick lines use camera-facing ribbons.
- [ ] Realize instanced meshes with per-instance attributes. iOS uses `SCNGeometry` copies with per-instance data or `MTLBuffer` offsets. Android uses Filament instanced renderables.
- [ ] Catmull-Rom path helper in Dart for the navigation-route use case.

**You see.**

- [ ] Ten primitive shapes render identically on both platforms.
- [ ] A 1000-instance field draws in one node on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Primitive bounds and instancing decode cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w26-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. All five new primitives render on Android. Save `w26-android-prims.png`. Pass when each shape is correct.
- [ ] Lane 3. Same on iOS. Save `w26-ios-prims.png`. Pass when identical.
- [ ] Lane 4. A real icosphere shows geodesic facets on both. Save `w26-icosphere.png`. Pass when triangulation is geodesic.
- [ ] Lane 5. A thick dashed polyline renders on Android. Save `w26-android-line.png`. Pass when dashes show at width.
- [ ] Lane 6. Same on iOS. Save `w26-ios-line.png`. Pass when identical.
- [ ] Lane 7. A billboard quad faces the camera through an orbit on both. Save `w26-billboard.png`. Pass when the quad tracks.
- [ ] Lane 8. A 1000-instance field renders on Android with per-instance colors. Save `w26-android-inst.png`. Pass when instances vary.
- [ ] Lane 9. Same on iOS. Save `w26-ios-inst.png`. Pass when identical.
- [ ] Lane 10. Dice still roll on Android. Save `w26-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time on the 1000-instance scene.
- [ ] Probe. Frame timing trunk then head. Trunk lacks instancing, so also set the absolute budget.
- [ ] Baseline. Record the closest trunk equivalent, 1000 sibling nodes, first.
- [ ] Rule. Head instanced draw stays under 16 ms per frame on the A142.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w26-review-<slug>.png`.
- [ ] Record a video of the primitive sweep and the instance field. Save it as `docs/artifacts/w26-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W15. Land prefab subtree streaming

**Depends on.** None. Scope carries over from `extended-surface-program.md` W15.

**Files.**

- [ ] Edit `dart3d/lib/` for `composeSceneAsync` and the new ops.
- [ ] Edit both realizers for lazy placeholder handling.
- [ ] Edit `docs/extended-surface-program.md` status.

**Build.**

- [ ] Wire ops `loadSubtree` and `unloadSubtree`, reusing addNode, upsertResource, upsertPayload, and removeNode batching.
- [ ] Lazy placeholders arrive as tagged nodes and resolve when their subtree lands.
- [ ] `overrides`, `attachments`, `removedNodes`, `memberComponents`, and `addedComponents` follow upstream compose semantics.

**You see.**

- [ ] A lazy subtree streams in on demand and out on unload on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Compose override cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w15-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A lazy placeholder loads on `loadSubtree` on Android. Save `w15-android-load.png`. Pass when the subtree appears.
- [ ] Lane 3. Same on iOS. Save `w15-ios-load.png`. Pass when identical.
- [ ] Lane 4. `unloadSubtree` removes it on Android. Save `w15-android-unload.png`. Pass when the subtree disappears.
- [ ] Lane 5. Same on iOS. Save `w15-ios-unload.png`. Pass when identical.
- [ ] Lane 6. A per-instance override applies on Android. Save `w15-android-override.png`. Pass when the override renders.
- [ ] Lane 7. Same on iOS. Save `w15-ios-override.png`. Pass when identical.
- [ ] Lane 8. Payloads arriving after the subtree manifest still resolve. Save `w15-payload.png`. Pass when deferred decode lands.
- [ ] Lane 9. A reload cycle leaves no stale nodes. Save `w15-cycle.png`. Pass when three cycles show identical state.
- [ ] Lane 10. Dice still roll on Android. Save `w15-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Subtree load latency, manifest to visible.
- [ ] Probe. Timestamped log lines at send and first frame, trunk then head.
- [ ] Baseline. Trunk lacks streaming, so record the absolute latency on head.
- [ ] Rule. A 100-node subtree loads under 500 ms on the A142.

**Review gate.** None. W15 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W16. Add trails and LOD

**Depends on.** None. Scope carries over from `extended-surface-program.md` W16.

**Files.**

- [ ] Edit both realizers for `trail` and `lod` components.
- [ ] Create the Android ribbon mesh path.

**Build.**

- [ ] `trail` as a camera-facing ribbon with `width`, `lifetime`, `minVertexDistance`, `maxPoints`, and `widthOverTrail` on both platforms.
- [ ] `lod` via `SCNGeometry.levelsOfDetail` on iOS and a per-frame camera test on Android. `hysteresis` and `blendRange` documented as no-ops.

**You see.**

- [ ] A moving node leaves a fading ribbon and geometry visibly swaps with distance on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Trail point-buffer and LOD-threshold cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w16-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A trail follows a moving node on Android. Save `w16-android-trail.png`. Pass when the ribbon trails.
- [ ] Lane 3. Same on iOS. Save `w16-ios-trail.png`. Pass when identical.
- [ ] Lane 4. Trail width tapers per `widthOverTrail` on both. Save `w16-taper.png`. Pass when taper shows.
- [ ] Lane 5. LOD swaps geometry at distance on Android. Save `w16-android-lod.png`. Pass when the mesh changes.
- [ ] Lane 6. Same on iOS. Save `w16-ios-lod.png`. Pass when identical.
- [ ] Lane 7. LOD returns when zooming in on both. Save `w16-lod-return.png`. Pass when the fine mesh returns.
- [ ] Lane 8. A trail expires points by `lifetime`. Save `w16-expire.png`. Pass when old points fade out.
- [ ] Lane 9. Trails survive an orbit gesture on Android. Save `w16-orbit.png`. Pass when the ribbon stays world-anchored.
- [ ] Lane 10. Dice still roll on Android. Save `w16-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time with ten active trails.
- [ ] Probe. Frame timing trunk then head. Trunk lacks trails, so set an absolute budget.
- [ ] Baseline. Record trunk frame time on the same scene without trails.
- [ ] Rule. Head stays under 16 ms per frame on the A142 with ten trails.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w16-review-<slug>.png`.
- [ ] Record a video of a trail and a LOD swap. Save it as `docs/artifacts/w16-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W17. Realize skyEnvironment and physical sky

**Depends on.** W25 for the relighting groundwork. Scope carries over from `extended-surface-program.md` W17.

**Files.**

- [ ] Create the Rayleigh-Mie sky generator in `dart3d/lib/` or shared per-platform code.
- [ ] Edit both environment paths to consume it.
- [ ] Edit `docs/environment-ibl-spec.md`.

**Build.**

- [ ] Port upstream's physical-sky generator to equirect pixels, pure math like the W7 studio generator.
- [ ] `skyEnvironment` relighting consumes the generated map on both platforms.
- [ ] `PhysicalSkySpec` skybox upgrades from the gradient approximation. Sun direction can drive a directional light.

**You see.**

- [ ] A procedural sky renders as background and lights the scene, sun disc tracking `sunDirection` on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Generator output cases, sun position and horizon color, in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w17-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A physical sky renders on Android. Save `w17-android-sky.png`. Pass when the gradient has horizon falloff.
- [ ] Lane 3. Same on iOS. Save `w17-ios-sky.png`. Pass when identical.
- [ ] Lane 4. The sun disc sits at `sunDirection` on Android. Save `w17-android-sun.png`. Pass when the disc tracks the vector.
- [ ] Lane 5. Same on iOS. Save `w17-ios-sun.png`. Pass when identical.
- [ ] Lane 6. `skyEnvironment` relights a scene on Android. Save `w17-android-relight.png`. Pass when ambient color follows the sky.
- [ ] Lane 7. Same on iOS. Save `w17-ios-relight.png`. Pass when identical.
- [ ] Lane 8. A low-sun scene tints warm on both. Save `w17-lowsun.png`. Pass when the horizon warms.
- [ ] Lane 9. An asset environment still overrides the sky on both. Save `w17-asset-env.png`. Pass when precedence holds.
- [ ] Lane 10. Dice still roll on Android. Save `w17-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Sky generation time, ms per equirect.
- [ ] Probe. Timestamped generation log, trunk then head.
- [ ] Baseline. Trunk lacks the generator, so record head absolute.
- [ ] Rule. A 1k equirect generates under 200 ms on the A142.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w17-review-<slug>.png`.
- [ ] Record a video sweeping `sunDirection`. Save it as `docs/artifacts/w17-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W18. Realize particles

**Depends on.** None. Scope carries over from `extended-surface-program.md` W18.

**Files.**

- [ ] Edit `dart3d/ios/Classes/` for `SCNParticleSystem` mapping.
- [ ] Create the Android CPU particle sim and billboard renderer.
- [ ] Edit `docs/` for the particle spec.

**Build.**

- [ ] iOS maps `birthRate`, `lifeSpan`, `emitterShape`, property controllers, and `imageSequence` onto `SCNParticleSystem`, with deltas documented.
- [ ] Android runs a custom CPU sim writing a billboard `VertexBuffer`, with a filamat material. Mesh particles are instanced renderables.
- [ ] `enabled` now gates particle ticking on both platforms, its first real consumer.
- [ ] `fixedStep` and `maxFrameTime` semantics documented where unmappable.

**You see.**

- [ ] A fountain and a one-shot burst run on both platforms at 1000-plus particles.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Emitter decode and sim-step cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w18-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A fountain runs on Android. Save `w18-android-fountain.png`. Pass when particles emit continuously.
- [ ] Lane 3. Same on iOS. Save `w18-ios-fountain.png`. Pass when identical.
- [ ] Lane 4. A burst fires once on Android. Save `w18-android-burst.png`. Pass when the burst clears.
- [ ] Lane 5. Same on iOS. Save `w18-ios-burst.png`. Pass when identical.
- [ ] Lane 6. `enabled:false` freezes emission on both. Save `w18-enabled.png`. Pass when the emitter stops.
- [ ] Lane 7. A flipbook animates frames on iOS. Save `w18-ios-flipbook.png`. Pass when frames advance.
- [ ] Lane 8. Mesh particles instance on Android. Save `w18-android-mesh.png`. Pass when mesh shapes emit.
- [ ] Lane 9. 1000-plus particles hold 60 fps on the A142. Save `w18-perf.png`. Pass when the frame rate holds.
- [ ] Lane 10. Dice still roll on Android. Save `w18-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time at 1000 live particles.
- [ ] Probe. Frame timing trunk then head. Trunk lacks particles, so set an absolute budget.
- [ ] Baseline. Record trunk frame time on the same scene without emitters.
- [ ] Rule. Head stays under 16 ms per frame on the A142 at 1000 particles.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w18-review-<slug>.png`.
- [ ] Record a video of fountain and burst. Save it as `docs/artifacts/w18-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W19. Realize the character controller

**Depends on.** None. Scope carries over from `extended-surface-program.md` W19.

**Files.**

- [ ] Edit `dart3d/android/.../JoltWorld.kt` for `CharacterVirtual`.
- [ ] Edit `dart3d/ios/Classes/` for the kinematic sweep controller.
- [ ] Edit `dart3d/lib/src/protocol.dart` for the `characterMove` op.

**Build.**

- [ ] Android `CharacterVirtual` with `ExtendedUpdateSettings` stair and stick-to-floor behavior inside the fixed-step loop.
- [ ] iOS kinematic capsule with sweep-and-slide over the W8 query path, slope classification, autostep, snap-to-ground.
- [ ] The `characterMove` op takes desired displacement plus dt and writes the pose back to the node.

**You see.**

- [ ] A capsule walks the feature scene, climbs a step, and slides on a steep slope on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Move-op decode and slope cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Dice and showcase both sides. Save `w19-lane1.png`. Pass when both still work.
- [ ] Lane 2. A capsule walks forward on Android. Save `w19-android-walk.png`. Pass when it displaces.
- [ ] Lane 3. Same on iOS. Save `w19-ios-walk.png`. Pass when identical.
- [ ] Lane 4. The capsule climbs a step on Android. Save `w19-android-step.png`. Pass when it mounts the step.
- [ ] Lane 5. Same on iOS. Save `w19-ios-step.png`. Pass when identical.
- [ ] Lane 6. The capsule slides down a steep slope on both. Save `w19-slope.png`. Pass when it slides, not climbs.
- [ ] Lane 7. The capsule pushes a dynamic die on Android. Save `w19-android-push.png`. Pass when contact transfers force.
- [ ] Lane 8. The capsule does not fall through the floor after ten seconds on both. Save `w19-stable.png`. Pass when the pose stays grounded.
- [ ] Lane 9. `characterMove` composes with gravity on both. Save `w19-gravity.png`. Pass when jumps land.
- [ ] Lane 10. Dice still roll on Android. Save `w19-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Physics step time with a live character.
- [ ] Probe. Step timing trunk then head. Trunk lacks the controller, so set an absolute budget.
- [ ] Baseline. Record trunk step time on the same scene.
- [ ] Rule. Head stays under 8 ms per physics step on the A142.

**Review gate.** None. W19 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W20. Realize environment volumes and probes

**Depends on.** W25 for the effects blending machinery. Scope carries over from `extended-surface-program.md` W20.

**Files.**

- [ ] Edit both realizers for `reflectionProbe`, `irradianceVolume`, and `environmentVolume`.
- [ ] Edit `docs/environment-ibl-spec.md`.

**Build.**

- [ ] `reflectionProbe` as `SCNLightTypeProbe` on iOS and a six-face `RenderTarget` capture plus `IBLPrefilterContext` on Android.
- [ ] `irradianceVolume` as irradiance probe on iOS and per-object or camera-blended SH on Android, grid semantics documented.
- [ ] `environmentVolume` camera-in-volume coverage with crossfade or documented hard-switch, honoring `priority`, `weight`, and `blendDistance`.
- [ ] `PlanarReflectorComponent` planar mirror where each platform supports it, else documented limit.

**You see.**

- [ ] Walking the camera through a volume visibly changes IBL and a reflection probe shows local reflections on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Volume coverage and priority cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w20-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A reflection probe shows local reflections on Android. Save `w20-android-probe.png`. Pass when reflections appear.
- [ ] Lane 3. Same on iOS. Save `w20-ios-probe.png`. Pass when identical.
- [ ] Lane 4. Camera entering a volume changes IBL on Android. Save `w20-android-volume.png`. Pass when the ambient shifts.
- [ ] Lane 5. Same on iOS. Save `w20-ios-volume.png`. Pass when identical.
- [ ] Lane 6. Two overlapping volumes resolve by `priority` on both. Save `w20-priority.png`. Pass when the higher priority wins.
- [ ] Lane 7. A `blendDistance` crossfades or hard-switches per the documented rule. Save `w20-blend.png`. Pass when the transition follows the spec.
- [ ] Lane 8. A planar mirror reflects the scene where feasible, else the documented limit. Save `w20-mirror.png`. Pass when rendered or logged.
- [ ] Lane 9. Probe parallax correction shifts reflections correctly on iOS. Save `w20-ios-parallax.png`. Pass when reflections track position.
- [ ] Lane 10. Dice still roll on Android. Save `w20-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time with one live probe.
- [ ] Probe. Frame timing trunk then head. Trunk lacks probes, so set an absolute budget.
- [ ] Baseline. Record trunk frame time on the same scene.
- [ ] Rule. Head stays under 16 ms per frame on the A142.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w20-review-<slug>.png`.
- [ ] Record a video walking through a volume. Save it as `docs/artifacts/w20-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W27. Add decals

**Depends on.** W28 for the engine-input shader path, or ship the fixed-material variant first and note the `.fmat` upgrade in its scope.

**Files.**

- [ ] Edit both realizers for `DecalNode` or the decal component shape.
- [ ] Create the decal projection path in the material layer.
- [ ] Edit `docs/extended-surface-audit.md`.

**Build.**

- [ ] Project a decal into a unit box on both platforms. iOS uses a second render pass or a decal material trick. Android uses a Filament decal projection or screen-space approach, documented per platform.
- [ ] Honor decal ordering and fade semantics where the document declares them.

**You see.**

- [ ] A scorch decal lands on a surface and follows its orientation on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Decal decode cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w27-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A decal projects on a flat surface on Android. Save `w27-android-flat.png`. Pass when the decal shows.
- [ ] Lane 3. Same on iOS. Save `w27-ios-flat.png`. Pass when identical.
- [ ] Lane 4. A decal wraps a curved surface on Android. Save `w27-android-curved.png`. Pass when it follows the curve.
- [ ] Lane 5. Same on iOS. Save `w27-ios-curved.png`. Pass when identical.
- [ ] Lane 6. Decal orientation follows the node on both. Save `w27-orient.png`. Pass when rotation applies.
- [ ] Lane 7. Two decals order correctly on both. Save `w27-order.png`. Pass when stacking matches spec.
- [ ] Lane 8. A decal outside its box clips on both. Save `w27-clip.png`. Pass when no projection leaks.
- [ ] Lane 9. Decals survive scene reload on both. Save `w27-reload.png`. Pass when state resets clean.
- [ ] Lane 10. Dice still roll on Android. Save `w27-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time with ten decals.
- [ ] Probe. Frame timing trunk then head. Trunk lacks decals, so set an absolute budget.
- [ ] Baseline. Record trunk frame time on the same scene.
- [ ] Rule. Head stays under 16 ms per frame on the A142.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w27-review-<slug>.png`.
- [ ] Record a video of decal projection. Save it as `docs/artifacts/w27-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W28. Settle the custom shader contract

**Depends on.** W21 and W22. The material contract must be settled first.

**Files.**

- [ ] Create `docs/custom-shader-spec.md` describing the `.fmat` subset dart3d supports.
- [ ] Edit both material paths for `ShaderMaterial` or the chosen equivalent.
- [ ] Create the shader compile path per platform.

**Build.**

- [ ] Decide the contract. Options are a dart3d `.fmat` subset cross-compiled to both backends, or per-platform custom materials behind one document type. The spec records the choice with the linear-HDR premultiplied input contract upstream uses.
- [ ] Realize engine-provided inputs the chosen contract supports, including `decal_inverse` and `planar_reflection` if in scope.
- [ ] Hot-reload shaders where each platform's pipeline allows it.

**You see.**

- [ ] A document-authored custom material renders on both platforms with identical semantics.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Shader compile and decode cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w28-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A toon-shaded model renders on Android. Save `w28-android-toon.png`. Pass when banding shows.
- [ ] Lane 3. Same on iOS. Save `w28-ios-toon.png`. Pass when identical.
- [ ] Lane 4. A procedural sky `.fmat` renders on Android. Save `w28-android-sky.png`. Pass when the sky draws.
- [ ] Lane 5. Same on iOS. Save `w28-ios-sky.png`. Pass when identical.
- [ ] Lane 6. A custom vertex stage displaces geometry on Android. Save `w28-android-vertex.png`. Pass when the mesh deforms.
- [ ] Lane 7. Same on iOS or documented limit. Save `w28-ios-vertex.png`. Pass when identical or logged.
- [ ] Lane 8. A shader hot-reloads without scene reload where feasible. Save `w28-hotreload.png`. Pass when the new shader appears.
- [ ] Lane 9. Engine input `decal_inverse` reaches the shader if in contract scope. Save `w28-input.png`. Pass when the value binds.
- [ ] Lane 10. Dice still roll on Android. Save `w28-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time on a custom-shader scene.
- [ ] Probe. Frame timing trunk then head.
- [ ] Baseline. Record trunk frame time on the same scene with a stock material.
- [ ] Rule. Head stays under 16 ms per frame on the A142.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w28-review-<slug>.png`.
- [ ] Record a video of the custom material running. Save it as `docs/artifacts/w28-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W29. Complete the document layer

**Depends on.** None.

**Files.**

- [ ] Edit `dart3d/lib/` for `serializeScene`, `migrateFscene`, `supportedFeatures` negotiation, and runtime GLB.
- [ ] Create the runtime glTF importer or a bridge to the upstream importer running in-process.
- [ ] Edit `docs/` for the document-layer spec.

**Build.**

- [ ] `serializeScene` writes the live graph back to a document, closing the round trip.
- [ ] `migrateFscene` upgrades older schema versions on load.
- [ ] `supportedFeatures` negotiation warns or rejects per upstream semantics when a document needs missing features.
- [ ] Runtime `.glb` import, the `Node.fromGlbBytes` equivalent, by porting the upstream importer to run in-process or shipping a documented offline-only decision.

**You see.**

- [ ] A document builds, serializes, and re-realizes identically, and a `.glb` loads at runtime without the offline step if the importer lands.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Round-trip and migration cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w29-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A built scene serializes and reloads identically on Android. Save `w29-android-roundtrip.png`. Pass when the reload matches.
- [ ] Lane 3. Same on iOS. Save `w29-ios-roundtrip.png`. Pass when identical.
- [ ] Lane 4. An older-schema document migrates on load on both. Save `w29-migrate.png`. Pass when it realizes.
- [ ] Lane 5. A `featuresRequired` doc the engine lacks warns loudly on both. Save `w29-features.png`. Pass when the warning fires.
- [ ] Lane 6. A runtime `.glb` renders on Android if the importer lands. Save `w29-android-glb.png`. Pass when the model renders.
- [ ] Lane 7. Same on iOS. Save `w29-ios-glb.png`. Pass when identical.
- [ ] Lane 8. A skinned `.glb` animates at runtime on both if the importer lands. Save `w29-skinned.png`. Pass when the clip plays.
- [ ] Lane 9. Serialized output byte-compares equal across repeated saves on both. Save `w29-stable.png`. Pass when output is stable.
- [ ] Lane 10. Dice still roll on Android. Save `w29-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Runtime `.glb` import time for a 5 MB asset.
- [ ] Probe. Timestamped import log, head only since trunk lacks it.
- [ ] Baseline. Record head absolute.
- [ ] Rule. Import under 3 seconds on the A142 for the test asset.

**Review gate.** None. W29 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W30. Migrate Filament to the Vulkan backend

**Depends on.** None. Independent of the feature workstreams.

**Files.**

- [ ] Edit `dart3d/android/` Filament engine init and `build.gradle` for the Vulkan backend.
- [ ] Edit `docs/android-parity-spec.md`.

**Build.**

- [ ] Switch the Filament `Engine` backend from OpenGL to Vulkan on the A142, keeping a GL fallback flag for devices without Vulkan.
- [ ] Verify every realized feature under Vulkan. Filament feature parity between backends is high, but shadows, dynamic resolution, and render targets get explicit re-verification.

**You see.**

- [ ] The app renders through Vulkan on the A142 with identical output and better or equal frame times.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] No unit surface change. The Android unit suite still runs. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Full showcase tour on GL trunk and Vulkan head. Save `w30-lane1.png`. Pass when every scene renders identically.
- [ ] Lane 2. Dash animates under Vulkan. Save `w30-dash.png`. Pass when the pose changes between frames.
- [ ] Lane 3. IBL environment renders under Vulkan. Save `w30-ibl.png`. Pass when lighting is unchanged.
- [ ] Lane 4. Shadows render under Vulkan. Save `w30-shadow.png`. Pass when shadows land.
- [ ] Lane 5. A render texture feeds a material under Vulkan. Save `w30-rt.png`. Pass when the W14 scenario still works.
- [ ] Lane 6. Split-screen views render under Vulkan. Save `w30-split.png`. Pass when both views draw.
- [ ] Lane 7. The dice table rolls and settles under Vulkan. Save `w30-dice.png`. Pass when a settle fires.
- [ ] Lane 8. Skinning deforms under Vulkan. Save `w30-skin.png`. Pass when dash skinning plays.
- [ ] Lane 9. Ten-minute soak under Vulkan shows no crash or leak growth. Save `w30-soak.png`. Pass when memory stays flat.
- [ ] Lane 10. The GL fallback flag still renders on a forced-GL run. Save `w30-gl.png`. Pass when the fallback works.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time and CPU render-thread time on the showcase tour.
- [ ] Probe. Frame timing plus `adb shell dumpsys gfxinfo` equivalent, interleaved GL trunk then Vulkan head.
- [ ] Baseline. Record trunk GL numbers first.
- [ ] Rule. Vulkan head must be equal or faster on frame time. If it is slower, the PR lands behind the flag with the numbers recorded instead of flipping the default.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w30-review-<slug>.png`.
- [ ] Record a video of the showcase tour under Vulkan. Save it as `docs/artifacts/w30-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W31. Realize Gaussian splats

**Depends on.** W26 for instanced quad rendering. Previously excluded; now scheduled per the operator's full-surface instruction.

**Files.**

- [ ] Create the splat renderer on both platforms.
- [ ] Create the `.splat` or `.ply` asset path in `dart3d/lib/`.
- [ ] Edit `docs/extended-surface-audit.md` to lift the exclusion.

**Build.**

- [ ] Decode splat asset payloads into per-splat buffers.
- [ ] Render splats as sorted instanced quads with per-splat covariance and color. iOS uses Metal-backed custom geometry or `SCNProgram`. Android uses Filament instanced renderables with a custom material.
- [ ] The GPU crop box from upstream maps or is documented.

**You see.**

- [ ] A real splat capture renders recognizably on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Splat decode cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w31-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A splat capture renders on Android. Save `w31-android-splat.png`. Pass when the capture is recognizable.
- [ ] Lane 3. Same on iOS. Save `w31-ios-splat.png`. Pass when comparable.
- [ ] Lane 4. Splats sort correctly through an orbit on Android. Save `w31-android-sort.png`. Pass when depth orders right.
- [ ] Lane 5. Same on iOS. Save `w31-ios-sort.png`. Pass when identical.
- [ ] Lane 6. A splat occludes correctly against PBR geometry on both. Save `w31-occlusion.png`. Pass when depth interop holds.
- [ ] Lane 7. The crop box clips splats on both. Save `w31-crop.png`. Pass when cropping applies.
- [ ] Lane 8. A 100k-splat scene holds interactive frame rate on Android. Save `w31-perf.png`. Pass when it stays interactive.
- [ ] Lane 9. Splat assets hot-swap via `upsertResource` on both. Save `w31-swap.png`. Pass when the capture changes.
- [ ] Lane 10. Dice still roll on Android. Save `w31-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time at 100k splats.
- [ ] Probe. Frame timing, head only since trunk lacks splats.
- [ ] Baseline. Record head absolute.
- [ ] Rule. Under 33 ms per frame on the A142 at 100k splats, interactive not cinematic.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w31-review-<slug>.png`.
- [ ] Record a video orbiting a splat capture. Save it as `docs/artifacts/w31-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W32. Realize audio

**Depends on.** None in the engine. The Android backend needs host-layer asset delivery, named in scope. Previously host-gated; now scheduled.

**Files.**

- [ ] Create `dart3d/lib/src/audio.dart` or equivalent for the audio component surface.
- [ ] Edit iOS for `SCNAudioSource` positional audio.
- [ ] Create or bridge the Android audio backend.
- [ ] Edit `docs/` for the audio spec.

**Build.**

- [ ] Decode `audioSource`, `audioListener`, and `audioEngine` components.
- [ ] iOS maps to `SCNAudioSource` with positional attenuation and the listener following the camera.
- [ ] Android gets a real backend decision. Options are Oboe through the existing JNI layer or a documented host-managed player. The spec records the choice.
- [ ] `AudioBus` and clip handles follow the upstream contract shape.

**You see.**

- [ ] A positional sound pans and attenuates with camera position on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Audio decode and routing cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w32-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A clip plays on Android. Save `w32-android-play.png`. Pass when the log confirms playback.
- [ ] Lane 3. Same on iOS. Save `w32-ios-play.png`. Pass when identical.
- [ ] Lane 4. Positional attenuation changes volume with distance on both. Save `w32-attenuation.png`. Pass when level tracks distance.
- [ ] Lane 5. Listener follows the camera node on both. Save `w32-listener.png`. Pass when panning follows the camera.
- [ ] Lane 6. Looping sustains on both. Save `w32-loop.png`. Pass when the clip repeats.
- [ ] Lane 7. Stop and seek apply on both. Save `w32-seek.png`. Pass when the ops land.
- [ ] Lane 8. Audio survives scene reload on both. Save `w32-reload.png`. Pass when no zombie playback remains.
- [ ] Lane 9. Two sources mix on both. Save `w32-mix.png`. Pass when both are audible.
- [ ] Lane 10. Dice still roll on Android. Save `w32-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Audio callback underruns during playback.
- [ ] Probe. Platform audio diagnostics on a looped scene, head only.
- [ ] Baseline. Record head absolute.
- [ ] Rule. Zero underruns over a 60-second loop.

**Review gate.** None. W32 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W33. Realize widget and external textures plus semantics

**Depends on.** The DartNative host bridge for widget-to-texture, named in scope. Previously host-gated; now scheduled.

**Files.**

- [ ] Create the widget-to-texture bridge in the DartNative layer or `dart3d/lib/`.
- [ ] Edit both realizers for `widget`, `externalTexture`, and `semantics` components.
- [ ] Edit `docs/` for the integration spec.

**Build.**

- [ ] `widget` renders a DartNative subtree to texture on both platforms with pointer forwarding at the correct UV coordinates.
- [ ] `externalTexture` binds a platform texture id into a material slot on both platforms, for video and camera sources.
- [ ] `semantics` exposes node semantics to the platform accessibility tree with `occlusionHiding` honored.

**You see.**

- [ ] A live DartNative widget maps onto curved geometry and takes input, and a video texture plays on a surface on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Bridge decode and UV-mapping cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w33-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. A widget texture renders on Android. Save `w33-android-widget.png`. Pass when the subtree shows on the mesh.
- [ ] Lane 3. Same on iOS. Save `w33-ios-widget.png`. Pass when identical.
- [ ] Lane 4. A tap on the widget texture hits the right control on Android. Save `w33-android-input.png`. Pass when the tapped control responds.
- [ ] Lane 5. Same on iOS. Save `w33-ios-input.png`. Pass when identical.
- [ ] Lane 6. An external texture plays video on Android. Save `w33-android-video.png`. Pass when frames advance.
- [ ] Lane 7. Same on iOS. Save `w33-ios-video.png`. Pass when identical.
- [ ] Lane 8. Semantics nodes appear in the accessibility tree on Android. Save `w33-android-semantics.png`. Pass when `uiautomator` sees them.
- [ ] Lane 9. Same on iOS via the accessibility inspector. Save `w33-ios-semantics.png`. Pass when the nodes expose labels.
- [ ] Lane 10. Dice still roll on Android. Save `w33-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame time with a live widget texture.
- [ ] Probe. Frame timing trunk then head.
- [ ] Baseline. Record trunk frame time on the same scene.
- [ ] Rule. Head stays under 16 ms per frame on the A142.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w33-review-<slug>.png`.
- [ ] Record a video of widget input and a video texture. Save it as `docs/artifacts/w33-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## W34. Land hot reload and debug views

**Depends on.** None hard. Easier after W29.

**Files.**

- [ ] Create the hot-reload path in `dart3d/lib/` watching authored `.fscene` and asset changes.
- [ ] Create the debug-view channel surface in both realizers.
- [ ] Edit `docs/` for the tooling spec.

**Build.**

- [ ] Scene, material, and environment hot reload through `loadDocument` or the diff path on file change, dev-mode only.
- [ ] Debug channel views showing resolved normals, metallic, roughness, base color, and depth per surface on both platforms, plus wireframe overlay.

**You see.**

- [ ] Editing an authored scene reloads it in place and a debug view isolates a channel on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Reload-watch and channel-selection cases in `dart3d/example/test/`. Run `dn test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Showcase tour both sides. Save `w34-lane1.png`. Pass when all scenes still render.
- [ ] Lane 2. Editing a scene file reloads it on Android. Save `w34-android-reload.png`. Pass when the change appears.
- [ ] Lane 3. Same on iOS. Save `w34-ios-reload.png`. Pass when identical.
- [ ] Lane 4. A normal debug view renders on Android. Save `w34-android-normals.png`. Pass when normals visualize.
- [ ] Lane 5. Same on iOS. Save `w34-ios-normals.png`. Pass when identical.
- [ ] Lane 6. A metallic channel view renders on both. Save `w34-metallic.png`. Pass when the channel isolates.
- [ ] Lane 7. Wireframe overlay draws on Android. Save `w34-android-wire.png`. Pass when edges show.
- [ ] Lane 8. Same on iOS. Save `w34-ios-wire.png`. Pass when identical.
- [ ] Lane 9. A material edit hot-swaps without scene reload on both. Save `w34-matedit.png`. Pass when the material changes.
- [ ] Lane 10. Dice still roll on Android. Save `w34-dice.png`. Pass when a settle fires.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Hot-reload latency from file write to first frame.
- [ ] Probe. Timestamped watch and render logs, head only.
- [ ] Baseline. Record head absolute.
- [ ] Rule. Reload under 1 second for a small scene.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane screenshots into `docs/artifacts/w34-review-<slug>.png`.
- [ ] Record a video of a live reload and a debug view. Save it as `docs/artifacts/w34-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Devin Review triage done.
- [ ] Rebased onto `main` after the verdict. Operator squash-merges.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] The README records the final exclusion list and platform notes.
- [ ] The demo program starts only after this program closes, per the operator's no-demo-work rule.
- [ ] Reply to the operator with the report the execution playbook names.

## Appendix A. Prototype evidence

None required to arm. W28's shader contract and W30's Vulkan migration carry open design questions that prototype on their own branches inside their workstreams.

## Appendix B. Alternatives rejected

- Networking replication, upstream `flutter_scene_net`, is out of scope. It is a product feature over the physics contract, not an engine surface, and no downstream app needs it.
- The editor and MCP stack, upstream `flutter_scene_editor` and `flutter_scene_mcp`, is out of scope. It is a tool built on the engine, not engine capability.
- Raw OpenGL ES or Vulkan instead of Filament loses the renderer. The audit trail is in the Android landscape research, and the user already accepted Filament.
- Sceneform or SceneView for Android is dead or Filament-wrapped. Filament direct is strictly better.
- Jetpack SceneCore is XR-only and throws on phones. Not an option for this engine's targets.

## Appendix C. Risks

- iOS cannot express per-pair collision exclusion or joint limits and motors natively. W23 either finds a construction or lands the documented limit, and the spec records which.
- Filament Vulkan gains are probable but unproven on Mali-G610. W30 lands behind a flag if it is slower.
- KTX2 on iOS may need a CPU transcode path if `MTKTextureLoader` coverage is thin. W21 documents whichever lands.
- The widget-to-texture bridge in W33 depends on DartNative host capability that may not exist yet. If the bridge is infeasible, W33 splits and the engine half waits behind a documented gate.
- SceneKit particle limits cap W18's parity. The spec table records the deltas instead of pretending equivalence.

## Appendix D. Links and reading list

- `docs/extended-surface-audit.md` is the feature census this plan closes out.
- `docs/extended-surface-program.md` carries the original W15 through W20 scopes.
- `docs/verification-matrix.md` records what W0 through W14 already proved.
- `docs/dart3d-completion-program.md` is the program that landed the core.
- Upstream coverage source is the flutter_scene monorepo at `/tmp/flutter_scene_repo` and `scene-0.3.0` in the pub cache.
- W28 gets `/pstack:how` and `/pstack:interrogate` before its contract lands. W30 gets `/pstack:how` for the backend migration.
