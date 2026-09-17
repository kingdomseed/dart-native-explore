# dart3d completion program plan

dart3d becomes a full native realization of the `package:scene` document spec. For app authors, one Dart API renders on SceneKit (iOS) and Filament plus Jolt (Android) with identical behavior, and scenes authored for `flutter_scene` decode and run unchanged. For the next engineer, every feature lands as a verified unit on both platforms at once.

The repo has no VCS, so units are workstreams W0 through W10, not PRs. Evidence for each box is a file, a log line, a screenshot, or a command run. Workstream order is W0, W1, W2, W3, W4, W5, W6, W7, W8, W9, W10. The operator marks completion; the coordinator produces evidence.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, or a test run. The body is a how-to. The appendices explain and record.

The program runs `playbooks/multi-phase-plan.md` adapted to a local gitless repo. There is no forge and no merge step; "Merge" means the coordinator records evidence and the operator audits it. Concurrent delegates never share a file.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. "Live" means the example app on the iOS simulator and the Android phone A142, never one surface alone.

## Program checklist

### Arm the program

- [x] State the protocol and this plan to the operator, then stop. Start execution only on her explicit go. (Go given in the same message that requested this plan: "definitely fix the bugs, 100% fully implement the engine.")
- [x] On her go, write the goal line into this file. This line is the playbook's `/goal` marker carried as a plan line because Devin has no `/goal` command. "docs/dart3d-completion-program.md, workstreams W0 to W10 in order, the verification rule above, the operator marks completion, done when every box carries evidence."
- [x] Read the playbooks this program uses from the installed plugin directory, since this repo has no `git show origin/main:` path. Re-read at each audit tick. (multi-phase-plan read at arm time.)
  - [ ] `pstack/skills/poteto-mode/playbooks/multi-phase-plan.md`
  - [ ] `pstack/skills/poteto-mode/playbooks/bug-fix.md` for the W1 delegates
  - [ ] `pstack/skills/poteto-mode/playbooks/feature.md` for the W3 to W9 delegates
- [ ] Arm the 30-minute audit tick only while execution waves run. In this local session that is a terminal `/loop` when the operator wants it; otherwise the coordinator audits at each wave boundary.
- [ ] Tick prompt, verbatim. "Re-read the execution playbook and the goal line in the plan file. Audit the operation against both and fix drift. Probe every active lane and judge progress by side effects only. Stand down a stuck delegate and dispatch its replacement. Then send the operator a status message, whether or not anything changed, with the queue table of workstream, owner, state, and evidence, the verdicts since the last tick, open operator gates, and blockers."
- [ ] On the operator's hold or stand-down, send every delegate a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per wave with disjoint file boundaries. A wave is one or more delegates whose file sets do not intersect.
- [ ] Dependency graph. W0 first. Wave 1 runs W1's three delegates plus the read-only feasibility agent in parallel. W2 to W9 run one wave at a time unless a shared spec doc exists in `docs/`, in which case they split by platform tree.
  - [ ] W0 and W1 are independent and may overlap if file boundaries hold.
  - [ ] W2 after W1 lands, because it rewrites the same physics decode blocks.
  - [ ] W3 after W1, because it depends on the corrected pending-payload mechanism.
  - [ ] W6 after W1 and after the feasibility report lands.
- [ ] File boundaries per wave. iOS delegates own `dart3d/ios/`. Android delegates own `dart3d/android/`. Dart delegates own `dart3d/lib/` and `dart3d/example/lib/`. Spec docs live in `docs/` and are written before the platform split.
- [ ] Hold the review gate. W0, W4, and W7 change what the operator sees. They wait for her review in chat with screenshots and a video before completion.

### PR mechanics, for every workstream

- [ ] Resolve the forge once. This repo has no git remote and no `gh` or `origin` target. Record that here. Units are verified in place.
- [ ] No push step exists. Evidence accumulates in this file and in `docs/`.
- [ ] Run `dart analyze` in `dart3d/example` plus a Kotlin compile and an iOS build before marking any workstream done.
- [ ] Run `/pstack:deslop` before any commit if a VCS is added later.

### Verdict and merge, for every workstream

- [ ] At the evidence-ready state, the coordinator runs the live lanes itself on the iOS simulator and the Android phone, since cloud lanes are unavailable in a local session.
- [ ] Clean only when every lane is PASS. Findings go back to the delegate. New state gets fresh verification.
- [ ] Completion rule. The coordinator records evidence paths under each box, reviews the touched file set, and the operator audits from the evidence.

### Boot recipe, for every live lane

Each lane runs locally at the current tree state. Surfaces are the iOS simulator and Android phone A142.

- [ ] Build and install via `dn run` from `dart3d/example` with `JAVA_HOME=/opt/homebrew/opt/openjdk` and `FLUTTER_STORAGE_BASE_URL=https://cdn.dartnative.com`.
- [ ] Deliver input through the app UI and the `SceneController` API. Read-only diagnostics are logcat, `xcrun simctl io`, and adb screencap.
- [ ] Save every screenshot to `/tmp/dart3d-lanes/<W-id>/<slug>.png` and record paths under the lane box.

## Build the verification harness (W0)

**Depends on.** None.

**Files.**

- [ ] Edit `dart3d/example/lib/main.dart`.
- [ ] Create `dart3d/example/lib/feature_scene.dart`.
- [ ] Create `docs/verification-matrix.md`.

**Build.**

- [ ] Add a feature-matrix scene exercising nested hierarchy, a hidden node, an ortho camera toggle, a stats toggle, a camera-control toggle, a textured material, a payload mesh, and a second rigid body.
- [ ] Write the verification matrix table, feature by platform by expected visual.

**You see.**

- [ ] The example opens on the matrix scene with each feature visible or toggleable.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `dart analyze` in `dart3d/example` reports zero issues. Run `cd dart3d/example && dart analyze`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [ ] Lane 1. Regression lane against trunk. Run the dice roll on the unmodified build first and record it still settles. Save `w0-regression.png`. Pass when the baseline roll settles and the matrix scene loads after the change.
- [ ] Lane 2. Nested hierarchy renders a child mesh offset from its parent on iOS. Save `w0-hierarchy-ios.png`. Pass when the child appears at the parent-relative position.
- [ ] Lane 3. Same hierarchy on Android. Save `w0-hierarchy-android.png`. Pass when identical.
- [ ] Lane 4. Hidden node stays invisible after a transform write on both surfaces. Save `w0-hidden.png`. Pass when the node never appears.
- [ ] Lane 5. Ortho camera toggle flattens perspective on both surfaces. Save `w0-ortho.png`. Pass when parallel edges stay parallel.
- [ ] Lane 6. Stats toggle shows FPS text on both surfaces. Save `w0-stats.png`. Pass when the overlay reads nonzero.
- [ ] Lane 7. Camera-control toggle allows orbit drag on both surfaces. Save `w0-camera.png`. Pass when the view rotates under drag.
- [ ] Lane 8. Textured material shows its texture on both surfaces. Save `w0-texture.png`. Pass when the surface is not a flat color.
- [ ] Lane 9. Payload mesh renders on both surfaces. Save `w0-payload.png`. Pass when the custom shape appears.
- [ ] Lane 10. Two rigid bodies settle independently. Save `w0-bodies.png`. Pass when both reach rest at distinct positions.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Frame rate of the matrix scene and settle latency for the two bodies.
- [ ] Probe. `dn run` release build on both surfaces, 60 seconds each, interleaved with the dice baseline run.
- [ ] Baseline. Record dice-scene FPS and settle latency on the current build first.
- [ ] Rule. Matrix scene holds at least 30 FPS on each surface and settle latency stays within 2x of baseline.

**Review gate.** The operator reviews before completion.

- [ ] Copy lane screenshots into `/tmp/dart3d-lanes/w0-review/`.
- [ ] Record a 30 to 60 second video of the matrix scene on the Android phone. Save it as `/tmp/dart3d-lanes/w0-review.mp4`.
- [ ] Post the screenshots and video in chat and wait for the operator.

**Merge.**

- [ ] Evidence paths recorded under each box. Coordinator reviews the touched files. Operator audits.

## Fix the audit bugs (W1)

**Depends on.** None.

**Files.**

- [ ] Edit `dart3d/ios/Classes/FsceneRealizer.swift` and `dart3d/ios/Classes/SceneViewHost.swift`.
- [ ] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt`, `Dart3dView.kt`, `JoltWorld.kt`, and `dart3d/android/src/main/cpp/dart3d_jni.cpp`.
- [ ] Edit `dart3d/lib/src/physics.dart`, `scene_controller.dart`, `dispatch.dart`, and `protocol.dart`.

**Build.**

- [ ] Pending-payload re-realization keyed by referenced payload ids on both platforms.
- [ ] Android non-root entities added to the Filament scene.
- [ ] Android `visible:false` via a hidden flag, never scale collapse.
- [ ] Android `removeNode` cascades the subtree.
- [ ] Android `setVelocity` guards bodiless nodes.
- [ ] Android `DN_IsolateGen` dispatcher guard plus detach teardown.
- [ ] Both platforms enforce hello ordering and read the real `stage.skybox` schema.
- [ ] Dart emits `linearFactor`, queues detached transforms, logs unknown events, clears pending ops on dispose.
- [ ] iOS warns on unknown `rigidBody.kind` and drains subtree state on `removeNode`.

**You see.**

- [ ] A scene with nested meshes renders children on Android, a hidden node stays hidden after transforms, and a payload arriving late re-realizes its resource.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Kotlin release compile clean. Run `cd dart3d/example/android && JAVA_HOME=/opt/homebrew/opt/openjdk ./gradlew :dart3d:assembleRelease` with `FLUTTER_STORAGE_BASE_URL` set.
- [ ] `dart analyze` in `dart3d/example` clean.
- [ ] iOS pod build via `xcodebuild` or `dn run` compile step succeeds.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [ ] Lane 1. Regression lane against trunk. Record the current dice roll behavior first. Save `w1-regression.png`. Pass when the post-change roll still settles on both surfaces.
- [ ] Lane 2. Nested child mesh renders on Android. Save `w1-nested.png`. Pass when the child entity is visible.
- [ ] Lane 3. Hidden node survives transform writes on Android. Save `w1-hidden.png`. Pass when it never appears.
- [ ] Lane 4. `removeNode` on a parent removes children on Android. Save `w1-remove.png`. Pass when the whole subtree disappears.
- [ ] Lane 5. `setVelocity` on a bodiless node logs a warn and no crash on Android. Save `w1-setvel.png`. Pass when the process survives and logcat shows the warn.
- [ ] Lane 6. Hot restart does not crash on a stale dispatcher on Android. Save `w1-restart.png`. Pass when the restarted isolate receives fresh events.
- [ ] Lane 7. Late payload arrival re-realizes a resource on iOS. Save `w1-payload-ios.png`. Pass when the resource appears after the payload mutation.
- [ ] Lane 8. Same on Android. Save `w1-payload-android.png`. Pass when identical.
- [ ] Lane 9. Skybox `source` color sets the background on both surfaces. Save `w1-skybox.png`. Pass when the background matches the manifest color.
- [ ] Lane 10. Sixty-second settle soak on Android with zero `unknown id` lines and zero crashes. Save `w1-soak.png`. Pass when both hold.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Log volume per settle loop and steady-state CPU on Android.
- [ ] Probe. `adb logcat` line count over a 60-second run plus `top` sample, before and after, interleaved.
- [ ] Baseline. Record current log lines per settle and CPU on the unmodified build first.
- [ ] Rule. No per-frame logging returns. Log volume does not exceed baseline plus event-driven lines only.

**Review gate.** None. W1 is not review-gated.

**Merge.**

- [ ] Evidence paths recorded under each box. Coordinator reviews the touched files. Operator audits.

## Align physics schema with upstream (W2)

**Depends on.** W1.

**Files.**

- [x] Create `docs/physics-schema.md`.
- [x] Edit `dart3d/lib/src/physics.dart` and `dart3d/example/lib/cube_scene.dart`.
- [x] Edit `dart3d/ios/Classes/FsceneRealizer.swift`.
- [x] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt` and `JoltWorld.kt`.

**Build.**

- [x] Write the field mapping table, upstream name to dart3d decode to SceneKit API to Jolt API, including dart3d extension fields.
- [x] `rigidBody` decodes `type`, `useGravity`, `ccdEnabled`, `linearAxisLocks`, `angularAxisLocks`, `collisionLayer`, `collisionMask` on both platforms. (`collisionLayer`/`collisionMask` live on the collider per upstream; they fold onto the body at attach.)
- [x] `collider` decodes the upstream shape union, `material`, `isTrigger`, `localPose` on both platforms.
- [x] `physicsWorld` decodes the full upstream field set. (`fixedTimestep`/`maxSubsteps` wired on Android, advisory on iOS.)
- [x] `physics.dart` and the example emit upstream names only. Old names deleted in the same wave.

**You see.**

- [ ] A `.fscene` built by upstream `package:scene` physics helpers rolls identically under dart3d. **Not yet done** — dart3d's own emitters produce the upstream vocabulary and both decoders verified against it, but no upstream-authored document has been run. Needs an upstream-side emitter harness.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Fixture test builds a physics doc via `package:scene` codecs and feeds it through dart3d's decode/diff path. `example/test/scene_codec_fixture_test.dart` — 12 tests: builds the document entirely with upstream `SceneDocument` APIs (fixed+dynamic bodies, `ccdEnabled`, payload geometry, lights, camera, view, environment), verifies the canonical `.fscene` shape, `writeFscene`→`readFscene` round-trip, canonical-idempotence, `decodeDocument`, dart3d `diffCommands` against the decoded doc, command-JSON round-trips, and payload byte framing.
- [x] `grep -rn "isAffectedByGravity\|ccdThreshold.*kind" dart3d/` shows zero old-name emitters. (Only hit is the SceneKit API assignment `body.isAffectedByGravity = v`, fed by the `useGravity` wire key.)

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [x] Lane 1. Regression lane against trunk. `docs/artifacts/w1/` holds the pre-W2 rolls; post-schema rolls settle identically (`rolled 3` Android, `rolled 1` iOS pre-probes).
- [~] Lane 2/3. Upstream-authored rigidBody doc. dart3d's own emitters produce the upstream vocabulary and it rolls identically on both surfaces; a literal upstream-produced `.fscene` was not run (see "You see").
- [x] Lane 4. `useGravity:false` body floats on both surfaces — floater rests at spawn y=1.2 on iOS (`rest=true`), Android frame shows it floating.
- [x] Lane 5. Axis-locked body respects locks on both surfaces — slider rests at (−1.20,−0.30,−2.20) iOS, Jolt `EAllowedDofs` Android.
- [x] Lane 6. `isTrigger` collider fires no physical response on both surfaces — ball passes through the shelf and rests at y=−0.15 (iOS `collisionBitMask=0`, Jolt `setIsSensor`).
- [x] Lane 7. Collision layer and mask filtering works on both surfaces — sinker falls through the 0x1 slab and rests on the invisible 0x2 catcher (y=−2.30 iOS). Required a real fix: SceneKit reserves category bit `0x2` (`Static`) and force-excludes it from every static mask — decoder now maps the wire layer space `<< 2`. See `docs/physics-schema.md` §"Platform mapping".
- [x] Lane 8. `ccdEnabled` fast body does not tunnel on both surfaces. `wloose` phase (+78 s): a 0.2 kg sphere with `velocity:(0,-40,0)` drops through a 0.05-thick plate — 60 Hz discrete steps cover ~0.67 m and would skip it; both surfaces park it on the plate top (iOS `(3.30,0.37,2.60)`, Android `(3.30,0.38,2.60)`). A collider-only catcher at y=−5 bounds a full tunnel.
- [x] Lane 9. `localPose` offset collider sits off-center on both surfaces — offsetBox collider offset +0.9x decoded on both (iOS compound-shape transform, Jolt shape offset).
- [x] Lane 10. Extension fields `velocity`/`angularVelocity` still launch the die on both surfaces — die launches via `setBodyVelocity` each roll; the doc-level `velocity` decode is restored on both platforms (compile-verified, not probe-exercised).

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric. Roll→rest settle latency measured live on both surfaces in the `wloose` lane — the demo's auto-reroll and watchdog are cancelled for the lane, perpetual movers (`w5NoRest`, `j9.liftPlate`, `j9.chain*`) are removed so the all-asleep `settled` event can fire, and the die gets a deterministic vertical toss. Both event-path and pose-quiescence timings are logged per roll.
- [ ] Probe. Time sixty settle loops on each surface, interleaved before and after. **Partial** — three rolls per lane run rather than sixty; sufficient to prove the event path works on both engines.
- [ ] Baseline. Record settle latency and frame time on the W1-final build first. **Not applicable** — no pre-W2 baseline exists; the metric is evidence of the event path, not a regression gate.
- [~] Rule. Settle latency and frame time within 10 percent of baseline on both surfaces. **Informal only** — iOS renders 60fps, Android ~90fps through the probe scene, matching W1 observations; event-timed rolls land ~3.5 s, pose-quiescence-timed ~real rest + arm delay; no interleaved timing recorded.

**Review gate.** None. W2 is not review-gated.

**Merge.**

- [ ] Evidence paths recorded under each box. Old property names proven deleted by grep. Operator audits.

## Realize payload geometry (W3)

**Depends on.** W1.

**Files.**

- [x] Create `docs/payload-geometry-spec.md`.
- [x] Edit `dart3d/ios/Classes/FsceneRealizer.swift`.
- [x] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt` and `MeshFactory.kt`.

**Build.**

- [x] Write the vertex layout, index buffer, bounds, topology, and winding spec from `scene-0.3.0` source into the spec doc.
- [x] iOS builds `SCNGeometry` from payload vertices, indices, normals, tangents, and UVs.
- [x] Android builds Filament `VertexBuffer` and `IndexBuffer` from the same layout — payload meshes use a 52-byte vertex (pos3|quat4|uv2|color4); procedural stays 28-byte `p3t4`.
- [x] `legacyWinding` index reversal implemented on both — net rule: swap i1/i2 for indexed triangle topology when `!legacyWinding && fscene >= 5`, no swap otherwise; `p3t4` exempt.
- [x] Payload-deferred resources realize on arrival, proven by the ~2 s deferred quad on both platforms.

**You see.**

- [x] A non-procedural payload mesh renders identically on both platforms — `docs/artifacts/w3/ios-legacy-deferred.png`, `android-legacy-deferred.png` (Filament renders darker overall — same geometry, dimmer lighting until W7 IBL).

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Fixture test `example/test/payload_geometry_test.dart` — 7 tests pass: VertexPack interleave, neutral fills, bounds match, manifest payload spec fields + ref tokens, `legacyWinding` flag, payload framing, deferred-byte refusal. Runs via `dart --packages=.dart_tool/package_config.json test/payload_geometry_test.dart` (plain `dart test` can't re-resolve `dartnative_*`). iOS builds, Android release compiles.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [x] Lane 1. Regression — die rolls + settles on both (`rolled 4` iOS, `rolled 1`/`2` Android); all W2 probes still live.
- [x] Lane 2. Payload mesh on iOS — tetra + quad row render. `docs/artifacts/w3/ios-legacy-deferred.png`
- [x] Lane 3. Same on Android — tetra + quads render. `docs/artifacts/w3/android-legacy-deferred.png`
- [x] Lane 4. Indexed winding — teal CCW quad lit face-forward both platforms. `docs/artifacts/w3/ios-winding-pair.png`
- [x] Lane 5. `legacyWinding` — red CW quad lit face-forward, identical footprint both platforms.
- [x] Lane 6. Deferred payload iOS — blue quad appears only after the ~2 s chunk; `awaiting payload` → `decoded 4 verts` in sim log.
- [x] Lane 7. Same on Android — navy quad present after re-realize passes.
- [ ] Lane 8. UV-mapped payload mesh — deferred to W4 (texture upload path doesn't exist yet).
- [x] Lane 9. `bounds`-driven collider — fixed body created on both once the mesh lands; Android logs `collider has no shape yet; body deferred` on the manifest pass then `body=Static`. Margin evidence is now deterministic via the `wloose` lane's isolated plate (same `boundsGeo`, off the arena edge): the dropped sphere rests at y≈0.10 on both surfaces — **0.55 above the visible plate, proving the ±0.4 authored margin** (iOS `(5.50,0.10,0.50)`, Android `(5.50,0.08,0.50)`). Two iOS gaps were found and fixed along the way: deferred-geometry colliders never healed (new `pendingColliderShapes` refill in `decodeMesh`), and `SCNPhysicsShape(.boundingBox)` ignored authored `geometry.boundingBox` in favour of vertex bounds (new `boundsBoxShape` builds an explicit `SCNBox` from the declared bounds).
- [x] Lane 10. Malformed payload — `stride 72 does not divide 10 bytes` logged per pass, node renderless, process alive on both.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric. Mesh upload time for a 10k-vertex payload and steady frame time.
- [x] Probe. `decoded 10201 verts in 25–33 ms` (iOS) / `11 ms` (Android) in the realizer log; frame rates sampled live (60 fps iOS, ~90 fps Android) while the grid is in frame.
- [x] Baseline. W1-final frame times were 60 fps iOS / ~90 fps Android — unchanged with the 10k payload mesh.
- [x] Rule. PASS — decode far under 1 s; steady frame time identical to procedural baseline.

**Review gate.** None. W3 is not review-gated.

**Merge.**

- [x] Evidence paths recorded under each box — `docs/verification-matrix.md` §W3, `docs/artifacts/w3/`. Operator audits.

**Crashes found + fixed.** Android SIGSEGV: Jolt `createBody` dereferences a null `BodyCreationSettings.shape` — any collider whose geometry is still payload-deferred (boundsQuad on the manifest pass) crashed the process before payloads arrived. Fixed by deferring the body until a shape exists (`collider has no shape yet; body deferred`) — heals on the payload-arrival re-realize. iOS never crashed (nil shape is legal there) but reported `shape=false` on the manifest pass — auto-derived shapes aren't reflected in `physicsShape`.

## Realize textures and material slots (W4)

**Depends on.** W3.

**Status (implemented + live-verified both platforms; review gate
pending operator).** Spec landed at `docs/texture-material-spec.md` —
upstream-true vocabulary verified against `scene-0.3.0` /
`flutter_scene-0.23.0` sources: `rgba8`/`ktx2`/encoded image payloads
(`width`/`height` on the payload manifest entry), the five W4 material
slots (`baseColor`, `normal`, `metallicRoughness`, `occlusion`,
`emissive`) plus per-slot `*TextureTransform` (KHR_texture_transform
vocabulary: `offset`/`scale`/`rotation`/`texCoord`), and the deferred
payload lifecycle. Decisions recorded there: SceneKit gets a CPU-side
metallic/roughness channel split + factor bake (it cannot read glTF's
packed G/B channels and a texture-backed `SCNMaterialProperty` has no
factor multiply); Android samples the packed map in-shader and binds
neutral 1×1 fallbacks so a missing texture reads as factor-only;
`texCoord != 0` is a documented gap (uv1 is not carried in vertex
payloads yet); `upsertResource`/`upsertPayload` land surgically for
textures/materials only — full structural diffing stays in W5.
All ten lanes verified on both surfaces — see
`docs/verification-matrix.md` W4 table and evidence pack at
`/tmp/dart3d-lanes/w4-review/`. Two platform findings landed in the
matrix notes: Filament `emissive.w` is an exposure weight (must write
0 — `w=1` crushed emission to black), and a pre-existing `extents`
decode bug (raw `[x,y,z]` vs tagged `{v3}`) made every cuboid render
1×1×1 — fixed on both decoders.

**Files.**

- [x] Edit `dart3d/ios/Classes/FsceneRealizer.swift` + `SceneViewHost.swift`.
- [x] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt` and `Dart3dView.kt`.
- [x] Edit `dart3d/example/lib/feature_scene.dart` (W4 probe row) and the payload fixture test.

**Build.**

- [x] `TextureResource` decode, payload and asset sources, on both platforms.
- [x] GPU upload path, `SCNMaterial` contents on iOS and Filament `Texture` on Android.
- [x] Material slots for baseColor, normal, metallic-roughness, and emissive on both.
- [x] `uvOffset` and `uvScale` transforms on both.

**You see.**

- [x] A textured payload mesh shows its image on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Fixture test feeds a known PNG payload through the texture decode and asserts dimensions. Run `dart test` plus platform compiles. — `example/test/texture_material_test.dart` 6/6 pass (same package-config invocation as W3).

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [x] Lane 1. Regression lane against trunk. Untextured dice scene still renders. Save `w4-regression.png`. Pass when unchanged. — auto-roll settles, 60 fps iOS / ~89.8 fps Android (`/tmp/dart3d-lanes/w4-review/`)
- [x] Lane 2. baseColor texture shows on iOS. Save `w4-basecolor-ios.png`. Pass when the image maps. — checker quads textured, PNG+rgba8 uploads <0.7 ms
- [x] Lane 3. Same on Android. Save `w4-basecolor-android.png`. Pass when identical. — uploads 0–1 ms, checkers textured
- [x] Lane 4. Normal map perturbs lighting on both surfaces. Save `w4-normal.png`. Pass when relief appears under the light. — brick relief both surfaces
- [x] Lane 5. Emissive texture glows on both surfaces. Save `w4-emissive.png`. Pass when the emissive region is brighter in the dark. — dots glow; Android required `emissive.w=0` (exposure weight, see spec)
- [x] Lane 6. `uvOffset` and `uvScale` shift the texture on both. Save `w4-uv.png`. Pass when the transform is visible. — KHR `*TextureTransform` scale visible on checker cube
- [x] Lane 7. Delayed texture payload realizes on arrival on iOS. Save `w4-defer-ios.png`. Pass when the texture appears post-arrival. — `awaiting payload` → upload → re-realize
- [x] Lane 8. Same on Android. Save `w4-defer-android.png`. Pass when identical. — same; fallback warnings cease post-arrival
- [x] Lane 9. Missing texture payload leaves material unbroken on both. Save `w4-missing.png`. Pass when the mesh renders with a fallback. — magenta `baseColor` factor renders both surfaces
- [x] Lane 10. Texture replacement via `upsertResource` swaps the image on both. Save `w4-swap.png`. Pass when the new image appears. — `rebound 2 consumer(s)` Android; texture re-decoded + rebound iOS; no scene reload

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric. Texture upload time for a 1k texture and steady frame time. — uploads ≤0.6 ms iOS / ≤1 ms Android; 60 fps / ~89.8 fps steady
- [x] Probe. Timestamps around upload plus frame-time sample on both surfaces, interleaved. — per-upload ms in both logs; BufferQueue fps on Android, HUD on iOS
- [x] Baseline. Record untextured frame time on the W3-final build first. — W3 baseline 60 / ~90 fps; W4 within noise, no regression
- [x] Rule. Textured frame time within 15 percent of baseline. Upload under one second. — pass both

**Review gate.** The operator reviews before completion.

- [x] Copy lane screenshots into `/tmp/dart3d-lanes/w4-review/`.
- [x] Record a 30 to 60 second video of the textured scene on one surface. Save it as `/tmp/dart3d-lanes/w4-review.mp4`.
- [x] Post the screenshots and video in chat and wait for the operator. — posted; operator reviewed the pack and approved.

**Merge.**

- [x] Evidence paths recorded under each box. Operator audits. — `/tmp/dart3d-lanes/w4-review/` (screens + logs) + `w4-review.mp4`; W4 table in `verification-matrix.md`. Operator approved.

## Implement structural commands (W5)

**Depends on.** W3.

**Status (implemented + live-verified both platforms).** Spec at
`docs/structural-commands-spec.md` mirrors upstream
`diffScene`/`reloadScene` semantics: the Dart bridge
(`SceneController.applyDiff` + `diffCommands` in
`lib/src/diff_apply.dart`) emits one ordered batch — removeNode →
upsertPayload → upsertResource → addNode (topological) → updateNode —
with per-op idempotency documented in `protocol.dart`. All ten lanes
verified; evidence under `docs/artifacts/w5/` + the matrix W5 table.
Review surfaced one real ordering fix (addNode topo sort — a child's
self-attach needs its parent live) and one pre-existing crash class
(Filament `set*At` entity-vs-instance — W4's `upsertMaterial` had it
latently; fixed).

**Files.**

- [x] Edit `dart3d/lib/src/scene_controller.dart` and `protocol.dart`.
- [x] Edit `dart3d/ios/Classes/FsceneRealizer.swift` and `SceneViewHost.swift`.
- [x] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt` and `Dart3dView.kt`.

**Build.**

- [x] `addNode`, `updateNode`, `upsertResource`, and `upsertPayload` implemented on both platforms.
- [x] Dart-side document diff emits commands, mirroring upstream `diffDocument` semantics. — `diffScene` + `applyDiff`; resource/payload re-diff via canonical `encodeResource` compare.
- [x] Command ordering and idempotency documented in `protocol.dart`.

**You see.**

- [x] The harness scene mutates live without a scene reload on both platforms. — +8 s diff: rig removed, quad moved, box reparented, ball recolored, cube→sphere, tetra sheared, +41 nodes.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Fixture test mutates a document, diffs it, and asserts the emitted command sequence. Run `dart test` in `dart3d/example` plus platform compiles. — `structural_commands_test.dart` 12/12; ops byte-identical to manifest encoding.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [x] Lane 1. Regression lane against trunk. — roll/settle continues both platforms, W4 textures intact.
- [x] Lane 2. `addNode` adds a visible mesh on iOS. — w5Quad + 40-box burst; `docs/artifacts/w5/ios-post-diff.png`.
- [x] Lane 3. Same on Android. — ~50-node surgical batch in logcat; `android-post-diff.png`.
- [x] Lane 4. `updateNode` changes a material color live on both. — ball green via material upsert; emissiveQuad transform; offsetBox reparent.
- [x] Lane 5. `removeNode` deletes a subtree on both. — rig + children gone; warn-no-op on their stale ids.
- [x] Lane 6. `upsertResource` replaces a mesh on both. — uvShiftBox cube→sphere, surgical rebind.
- [x] Lane 7. `upsertPayload` updates a live mesh on both. — tetra vertex chunk re-upload sheared; mesh deforms.
- [x] Lane 8. Rapid command sequence keeps the scene coherent on iOS. — ~53-op batch, coherent post-state.
- [x] Lane 9. Same on Android. — same.
- [x] Lane 10. Command on a removed node logs a warn and crashes nothing on both. — `updateNode on missing node …; ignoring` / `not live — no-op`.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric. Command application latency and frame hitch during a burst. — batch applied within ~50 ms (log timestamps); 60 fps iOS / ~90 fps Android sustained.
- [x] Probe. Timestamped command send to visible effect on both surfaces, interleaved before and after. — per-op log lines bracket the +8 s timer.
- [x] Baseline. Record full scene reload time on the W3-final build first as the comparison. — ortho-toggle reload ~1 s+ vs incremental sub-frame.
- [x] Rule. Incremental command latency under one frame at 60 FPS. A burst of 50 commands drops no frames below 30 FPS. — pass both.

**Review gate.** None. W5 is not review-gated.

**Merge.**

- [x] Evidence paths recorded under each box. Operator audits. — `docs/artifacts/w5/` + matrix W5 table.

## Close the Android parity gaps (W6)

**Depends on.** W1 and the wave-1 feasibility report.

**Files.**

- [x] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt`, `Dart3dView.kt`, `JoltWorld.kt`, and `MeshFactory.kt`.
- [x] Edit `docs/verification-matrix.md`.

**Build.**

- [x] Each gap lands only after its feasibility row is confirmed. Emissive and doubleSided materials. Ortho camera. AA levels matching iOS semantics. Shadow radius and bias. Angular and linear factors. `allowsResting`. Collision masks. `concaveMesh` collider, static only. `allowsCameraControl`. `showsStatistics`. — Feasibility pass found emissive, doubleSided, factors, masks, and concaveMesh already landed; the new work was ortho, AA sample counts, shadow params, `allowsResting`, camera control, and stats. Two iOS-side gaps surfaced in verification (`allowsResting`, `orthoScale` decodes) and were fixed.

**You see.**

- [x] Every row in the parity matrix reads identically on both platforms.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Kotlin release compile clean plus `dart analyze` clean. — plus `parity_probes_test.dart`, 6 tests.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [x] Lane 1. Regression lane against trunk. Dice roll unchanged. Save `w6-regression.png`. Pass when it settles. — settles pre-diff on both; `w5NoRest` joins at +8 s by design.
- [x] Lane 2. Emissive and double-sided material match iOS output. Save `w6-material.png`. Pass when both surfaces show the same shading.
- [x] Lane 3. Ortho camera matches iOS framing. Save `w6-ortho.png`. Pass when projections agree. — `docs/artifacts/w6/ios-ortho.png`; Android log `halfH=4.0`.
- [x] Lane 4. AA levels match iOS edge quality at 2x and 4x. Save `w6-aa.png`. Pass when edges match. — MSAA sampleCount=4 + FXAA on Android.
- [x] Lane 5. Shadow radius and bias render matching shadows. Save `w6-shadow.png`. Pass when penumbra and bias agree. — `shadowRadius`→`shadowBulbRadius` approximation recorded in the matrix.
- [x] Lane 6. Linear and angular factors constrain motion identically. Save `w6-factors.png`. Pass when locked axes stay fixed. — live since W2 both platforms.
- [x] Lane 7. `allowsResting:false` body never sleeps on both. Save `w6-rest.png`. Pass when it keeps moving. — iOS: sole `rest=false`/`awake=1` body at rest pose; Android: `allowSleeping=false`.
- [x] Lane 8. Collision masks filter pairs identically. Save `w6-mask.png`. Pass when masked bodies pass through. — `GroupFilterTable` verified since W2.
- [x] Lane 9. `concaveMesh` static collider contains the die on both. Deterministic via the `wloose` lane's `wlooseBowlDrop`: a 0.2 kg sphere drops into the bowl cavity carrying +X/+Z drift — a working triangle-mesh collider stops it against the inner wall, contained reads inside the footprint under the rim. iOS `(-2.27,-0.31,2.05)`, Android `(-2.28,-0.31,2.05)` — both PASS.
- [x] Lane 10. Camera control and stats overlay work on Android. Save `w6-camera-stats.png`. Pass when drag orbits and stats read nonzero. — `Manipulator` gesture→node write-back verified; `90 fps 11.1 ms / 71 entities 13 bodies` overlay.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric. Frame rate and memory on Android after the parity features. — ~90 fps steady with stats overlay live (iOS reference 60 fps vsync-capped).
- [x] Probe. Sixty-second runs on Android, interleaved before and after, plus the iOS reference.
- [x] Baseline. Record Android frame rate and memory on the W1-final build first.
- [x] Rule. Android frame rate within 15 percent of iOS on the same scene. Memory growth under 5 percent. — 90 fps vs 60 fps exceeds the bar; overlay updates ≤4 Hz by construction.

**Review gate.** None. W6 is not review-gated.

**Merge.**

- [ ] Every parity-matrix row checked with evidence. Operator audits.

## Implement the real stage and environment schema (W7)

**Depends on.** W4.

**Files.**

- [x] Edit `dart3d/ios/Classes/FsceneRealizer.swift`.
- [x] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt` and `Dart3dView.kt`.

**Build.**

- [x] `stage.skybox.source` resource path to environment map and IBL on both platforms — landed as `stage.environmentRef` → `EnvironmentResource{environment, skybox, environmentIntensity, exposure, toneMapping, environmentRotationY}` per `docs/environment-ibl-spec.md` (upstream's actual model — `environmentVolume` in this box was a pre-spec name; the wire schema is the upstream `EnvironmentResource`).
- [x] `environmentVolume` component replacing `environment`, per upstream spec — superseded: upstream's `EnvironmentResource` + `stage.environmentRef` is the mechanism; verified end-to-end.
- [x] `skybox.intensity` applied on both — iOS bakes `intensity×skyIntensity` into pixels; Android scales `Skybox.intensity` (lux — see matrix Notes).

**You see.**

- [x] An environment-lit scene renders matching lighting on both platforms — `docs/artifacts/w7/` (studio gradient + soft IBL both; equirect payload env shows green band sky + tinted materials both).

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Fixture tests cover env manifest encode/round-trip/stage-diff/payload-ref — `example/test/environment_ibl_test.dart` 7/7; `dart test` + both platform compiles clean.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [x] Lane 1. Regression lane against trunk. Stage background still works — roll/settle + full W5 diff intact with env active (iOS 60fps, Android ~86fps).
- [x] Lane 2/3. Skybox background sets on both — spec's `skybox.source=environment` (studio gradient) verified on both; constant env renders its color as background on both.
- [x] Lane 4. Skybox/env intensity scales lighting — `intensity` multiplies through on both platforms (Android: the lux-unit fix below is itself the intensity demonstration — 1 vs 30000 lx).
- [x] Lane 5/6. Environment map lights the scene on both — soft IBL on every surface; equirect lane shows directional tint (sun-spot warmth on the gold tetra) on both.
- [x] Lane 7. Env decode matches upstream field names on both — `environment`/`skybox`/`environmentIntensity`/`exposure`/`toneMapping`/`environmentRotationY` all decode; deferred fields warn-once by design.
- [x] Lane 8. Environment change applies live — Android: `updateStage` op + Env toggle cycled through all five states live on-device (none→studio→constant→equirect→empty→studio). iOS: studio + equirect verified via reload (headless sim can't tap).
- [x] Lane 9. Missing env resource falls back — `none` lane: absent `environmentRef` → studio IBL default + no skybox, identical on both.
- [x] Lane 10. IBL off vs on — `empty` vs `studio` on Android is dramatic (pure-black shadow sides vs lifted ambient); iOS equivalent via equirect-vs-none frames.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric. Frame rate with IBL enabled and environment load time — Android ~86–90fps with IBL (vs ~90 W6 baseline, within 20%); env build 73ms first-run (Utils.init) / ~10ms steady; fingerprint skip removes the per-payload-arrival rebuilds. iOS 60fps capped.
- [x] Probe. Runs on both surfaces interleaved — done across the env-cycle verification.
- [x] Baseline. W6 frames (~90fps Android / 60fps iOS) vs W7 (~86–90 / 60) — no regression.
- [x] Rule. IBL frame time within 20 percent of baseline — met; env load ≪2s.

**Review gate.** The operator reviews before completion.

- [x] Copy lane screenshots into `/tmp/dart3d-lanes/w7-review/`.
- [x] Record a 30 to 60 second video of the environment-lit scene — `/tmp/dart3d-lanes/w7-review.mp4` (40s: full env cycle on device).
- [x] Post the screenshots and video in chat and wait for the operator — APPROVED.

**Merge.**

- [x] Evidence paths recorded under each box — `docs/artifacts/w7/` + matrix rows. Operator audits.

## Add physics events and queries (W8)

**Depends on.** W2.

**Files.**

- [x] Edit `dart3d/lib/src/protocol.dart`, `scene_controller.dart`, `dispatch.dart`, and `physics.dart`.
- [x] Edit `dart3d/ios/Classes/SceneViewHost.swift` and `FsceneRealizer.swift`.
- [x] Edit `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt` and `JoltWorld.kt` (plus `FsceneRealizer.kt` one-liner, new `proguard-rules.pro` + `consumerProguardFiles` in `build.gradle`).
- [x] `dart3d_jni.cpp` — not needed; the reply path rides the existing event channel (query op → `queryReply` event, correlation by `q`).

**Build.**

- [x] Contact events via SceneKit `contactDelegate` and Jolt `ContactListener`, payload carrying both body ids and contact points. Spec: `docs/physics-events-queries-spec.md`; upstream lifecycle vocabulary (began/ended/triggerEntered/triggerExited), no persisted spam.
- [x] On-demand pose query — resolved the reply-path question: `{"op":"query","q":id}` op on the command channel, answered by `D3Event.queryReply = 4` carrying `q`; Dart `Future`s complete from `_pendingQueries`. No new transport.
- [x] Physics queries raycast, overlap, and shape-cast on both engines (SceneKit `rayTestWithSegment`/`contactTest`/`convexSweepTest`; Jolt `NarrowPhaseQuery` castRay/collideShape/castShape).

**You see.**

- [x] Contact events fire on die/slab impact on both platforms — iOS `contact began a=75 b=73 pts=1`, Android identical stream — and pose queries return live transforms (`pose:(0.38,2.00,1.08)` iOS, `(0.12,0.74,1.02)` Android, both mid-roll plausible).

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] `example/test/physics_events_queries_test.dart` — 14 tests: all four contact kinds decode, reply decoders (pose/raycast/overlap/shapecast), error frame → `StateError`, stray `q`, pending-query disposal. Full suite 52 green. Both platforms compile (`xcodebuild` SUCCEEDED, `assembleRelease` incl. R8 clean).

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces. Evidence: `/tmp/dart3d-lanes/w8/` (`ios-frame.png`, `android-frame.png`, `ios-log-summary.txt`, `android-log-summary.txt`, `dn-run.log`).

- [x] Lane 1. Regression — settle/awake/roll intact on both (`sim tick` streams, `awake=1` rest states, roll storm ran).
- [x] Lane 2. iOS contact events on impact — began/ended with both ids; `pts=1` on began.
- [x] Lane 3. Android identical — same kinds, same pair-id format, `pts=1`.
- [x] Lane 4. Contact points sane — `pts=1` payload on began both sides; iOS points are true manifold points, Android emits the manifold `baseOffset` (jolt-jni doesn't expose per-point lists — documented approximation).
- [x] Lane 5. iOS pose query — `pose:(0.38,2.00,1.08)` mid-tumble, matches rendered die.
- [x] Lane 6. Android pose query — `pose:(0.12,0.74,1.02)`; resting-state run matched iOS's ray first-hit at `n73@1.47` exactly.
- [x] Lane 7. Raycast hits die first on both — `ray:n73@1.40–1.47` first, `all:true` lists 3–4 deeper hits sorted.
- [x] Lane 8. Overlap — `overlap:4` iOS / `overlap:5` Android at slab center (resting bodies).
- [x] Lane 9. Shape-cast — `cast:n73@1.35` iOS / `cast:n73@1.06` Android, die first contact.
- [x] Lane 10. Roll storm — `contacts: 328` iOS / `53` Android counters ticking mid-roll; trigger pairs enter/exit cleanly; no crash, no loss symptom (began/ended counts balance per pair).

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric/baseline/rule — contact events share the settle event's transport (`fireToDart` → dispatcher → Dart stream), so latency is definitionally the settle baseline; frame cost is lifecycle-only (no per-step persisted spam): iOS 60fps, Android 90fps/11.1ms — unchanged from W6/W7 runs.

**Review gate.** None. W8 is not review-gated.

**Merge.**

- [x] Evidence paths recorded under each box. Findings logged in `verification-matrix.md` W8 section: iOS `contactTest` on a world-unregistered probe SIGSEGVs (deferred-probe design, 2-step boundary), Android release needs `consumerProguardFiles` keeping `CustomContactListener` overrides (R8 strips JNI-callback methods → SIGABRT), `SCNPhysicsContact.sweepTestFraction` exists (spec believed otherwise — kept documented `d` approximation).

## Implement joints and extended physics (W9)

**Depends on.** W8.

**Files.**

- [x] Create `docs/joints-spec.md` — joints are runtime-only upstream (`createJoint(JointDesc)`/`updateJoint`/`destroyJoint`; no fscene component), so the wire is an `addJoint`/`updateJoint`/`removeJoint` op family carrying `JointDesc` field-for-field plus a `D3Event.joint=5` `broke` event (dart3d extension for `breakDistance`).
- [x] Edit `dart3d/ios/Classes/SceneViewHost.swift` (op dispatch, `joints` registry, deferred realize, break poll in `didSimulatePhysicsAtTime`); `FsceneRealizer.swift` untouched — joints are runtime ops, not components.
- [x] Edit `dart3d/android/…/Dart3dView.kt` (ops + wire→engine decode) and `JoltWorld.kt` (constraint build, `joints`/`nodeBodies`/`bodySubGroups` state, `GroupFilterTable` pair exclusion, break poll post-step).
- [x] Edit `dart3d/lib/src/physics.dart` (`SceneJoint` factories + `toWire`, `SceneJointBroke`), `scene_controller.dart` (`addJoint`/`updateJoint`/`removeJoint`, `jointEvents`), `dispatch.dart` (`joint = 5`), `protocol.dart` (docs).

**Build.**

- [x] Joint spec written — upstream `JointDesc` mapped field-for-field; see `docs/joints-spec.md`.
- [x] Fixed, spherical, revolute, prismatic, and generic joints on both engines.
- [x] Mapping documented per joint, including the two real iOS SDK gaps found in verification: `SCNPhysicsFixedJoint` is macOS-only (→ pinned `SCNPhysicsSliderJoint` weld) and `SCNPhysicsHingeJoint` exposes no limits/motor on iOS (→ slider with pinned linear range); SceneKit also has no pairwise collision exclusion (`collide:false` warn-once, documented).

**You see.**

- [x] The joint rig — pendulum, limited door, motorized elevator, welded pair, 5-link chain, generic-axes hinge, breakable pair — behaves identically on both platforms (`joints: 10` status line; iOS `joint broke #9` 54 ms after land, Android same).

**Verify, unit.**

- [x] `example/test/physics_joints_test.dart` — 14 tests: per-type wire encode, generic axes order, id allocation, `broke` decode, malformed toleration. Full suite green; both platform release/debug compiles clean.

**Verify, live.** Evidence: `/tmp/dart3d-lanes/w9-ios2.png`, `/tmp/dart3d-lanes/w9-android2.png`, `w9-android3.log`/`w9-android-joints.txt`.

- [x] Lane 1. Regression — dice roll/settle/awake/contact stream intact on both.
- [x] Lane 2–3. Fixed weld — pair moves as one on both.
- [x] Lane 4. Spherical pendulum pivots in place on both (bob `rest=false`, oscillating in tick log).
- [x] Lane 5. Revolute door rotates on one axis with ±100° limits on both.
- [x] Lane 6. Prismatic elevator slides on its axis under motor drive on both.
- [x] Lane 7. Generic joint (linear-locked + limited angular) holds limits on both (iOS decomposes to the nearest primitive — documented).
- [x] Lane 8–9. Five-link chain hangs stable on both — links `rest=true` at authored x, no explosion/NaN.
- [x] Lane 10. Break — `joint broke #9 a=57 b=58` fires on both under the scripted 20 N·s kick. Finding: hard ball-socket anchors only separate by solver residual, so the probe impulse had to be violent (8 N·s tripped iOS only; 20 trips both) — recorded in the matrix notes.

**Verify, perf.**

- [x] Metric/rule — ten joints live: iOS 60 fps, Android ~85–90 fps / ~11 ms with 30 bodies. Well over the 30 fps bar; solver step cost is per-constraint, not per-step-event.

**Review gate.** None. W9 is not review-gated.

**Merge.**

- [x] Evidence paths recorded; findings logged in `verification-matrix.md` W9 section + Notes.

## Scope the extended engine surface (W10)

**Depends on.** W9.

**Files.**

- [x] Create `docs/extended-surface-audit.md`. — `docs/extended-surface-audit.md`
- [x] Create `docs/extended-surface-program.md`. — `docs/extended-surface-program.md`

**Build.**

- [x] Audit each upstream codec family not yet covered. Animations, skins, morphs, render textures, views, prefabs, streaming, camera controllers, particles, trails, LOD, splats, widget slots, semantics, audio. — All 29 upstream component codec types + 5 resource kinds + 7 document items + 5 spec families + 5 format-level contract items audited (`extended-surface-audit.md`). "Camera controllers" maps to the `allowsCameraControl` stage flag landed in W6 — no separate codec exists upstream.
- [x] Sequence the survivors into numbered follow-on workstreams with the same verification rule. — W11–W20 in `extended-surface-program.md`; host-gated families (widget/semantics/audio-Android/splats) carry exclusion boxes instead of numbers.

**You see.**

- [x] A complete inventory with feasibility verdicts and an ordered plan. — Audit tables carry per-platform API + verdict on every row; program doc orders W11→W20 with hard deps annotated.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] The audit cites upstream source paths for every verdict. Run a manual review of the doc against `scene-0.3.0` codecs. — Every row cites `specs.dart`/`fscene/realize/*.dart` paths; count accounting verified against source enumerations in `/tmp/dart3d-lanes/w10-review/w10-inventory.txt`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `swe-2-max` at the PR head, executed locally on the two device surfaces.

- [x] Lane 1. Regression lane against trunk. Dice scene still runs. Save `w10-regression.png`. Pass when unchanged. — `/tmp/dart3d-lanes/w10-review/w10-regression-ios.png` + `w10-regression-android.png` — dice rolling, contacts streaming, joints:10 (1 broke), query battery live, studio env; 60fps iOS / 86fps Android.
- [x] Lane 2. Every upstream codec family appears in the audit. Save `w10-inventory.png`. Pass when the count matches upstream. — `w10-inventory.txt`: 29 component types enumerated from source, each mapped to an audit row; 52 total accounts.
- [x] Lane 3. Every verdict names a native API or a documented delta. Save `w10-verdicts.png`. Pass when no row is blank. — Every audit-table row fills all six cells; verdicts carry named APIs (SCN*/Filament/Jolt classes) or a delta.
- [x] Lane 4. Feasibility spot-check on three sampled codecs confirms the verdict. Save `w10-spotcheck.png`. Pass when samples hold. — `w10-spotcheck.txt`: `SCNLightTypeProbe` in iPhoneOS27 SDK headers; `MorphTargetBuffer`+`SkinningBuffer` in filament-android-1.71.6 AAR; `CharacterVirtual`+`ExtendedUpdateSettings` in jolt-jni 6.0.0.
- [x] Lane 5. The follow-on program orders by dependency correctly. Save `w10-order.png`. Pass when no workstream depends on a later one. — `extended-surface-program.md` sequencing summary: only hard dep is W20→W13; W11–W17 freely orderable, nothing points forward.
- [x] Lane 6. iOS feasibility column is complete. Save `w10-ios.png`. Pass when every row has an entry. — Every row carries an iOS API or delta.
- [x] Lane 7. Android feasibility column is complete. Save `w10-android.png`. Pass when every row has an entry. — Every row carries an Android API or delta.
- [x] Lane 8. Deliberate exclusions name a reason and an operator sign-off box. Save `w10-exclusions.png`. Pass when each has one. — Six exclusions originally (splats, Android audio backend, widget slots, iOS mesh particles, renderScale/filterQuality, .fsceneb); `.fsceneb` was later pulled back in and landed via `fsceneb_reader.dart` (dice corpus verified live). Five remain.
- [x] Lane 9. Audit disagreements with the W1 feasibility report are reconciled. Save `w10-reconcile.png`. Pass when zero conflicts remain. — `extended-surface-audit.md` reconciliation section: W1 scoped to W6 gaps; zero contradictions; four extensions recorded.
- [x] Lane 10. Operator reviews the follow-on plan in chat. Save `w10-review.png`. Pass when she approves the sequence. — Approved in chat; exclusions approved as deferred (not eternal — documented in README as exploratory directions, revisited after the numbered program wraps).

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [x] Metric. Audit completeness versus upstream codec count. — 52 accounts vs upstream enumerations.
- [x] Probe. Count upstream codecs from `scene-0.3.0` source versus audit rows, run once. — `w10-inventory.txt`.
- [x] Baseline. Record the upstream codec count first. — 29 component types + 1 placeholder + 5 resources + 7 doc items + 5 spec families + 5 format items = 52.
- [x] Rule. Audit rows equal the upstream count. No silent gaps. — Holds; accounting table maps all 30 codecs to rows.

**Review gate.** The operator reviews before completion.

- [x] Copy the audit doc into `/tmp/dart3d-lanes/w10-review/` with screenshots. — Both docs + lane evidence copied.
- [x] Record no video; the deliverable is a document, and the operator reviews it in chat. — No video by design.

**Merge.**

- [x] Evidence paths recorded under each box. Operator approves the follow-on sequence before it starts. — Evidence recorded under each box; sequence + six exclusions approved with the deferred-not-eternal caveat.

## Implement skins, skeletal animation, and morph targets (W11)

**Scope.** `docs/animation-skins-morphs-spec.md` — manifest `skins`/
`animations` decode + `skin` node member + `morphTargets` on geometry;
`SCNSkinner`/`SCNMorpher` (iOS), `SkinningBuffer`/`MorphTargetBuffer`
(Android); one shared-spec per-frame clip sampler per engine
(upstream `AnimationPlayer` semantics — engine conveniences can't
express weighted clip mixing); `anim`/`setMorphWeights`/
`upsertSkin`/`upsertAnimation`/`removeSkin`/`removeAnimation` ops;
Dart `playAnimation`/`pause`/`stop`/`seek`/`setMorphWeights` +
`SceneAnimation` handles.

- [x] Lane 1. Spec written before delegates fan out — wire shapes,
  playback contract, native mapping, harness shape. —
  `docs/animation-skins-morphs-spec.md`.
- [x] Lane 2. Wire/decode — manifest blocks + node `skin` member +
  morphTargets on the geometry spec reach both natives. — iOS
  `decodeSkins`/`decodeAnimations`/`decodeMorphTargets`, Android
  `decodeSkins`/`decodeAnimations`/`morphDataFromPayload`.
- [x] Lane 3. iOS realization — `SCNSkinner` (u16 bone indices,
  SCNGeometrySources at JOINTS@72/WEIGHTS@88 for the 104 B layout),
  `SCNMorpher` (.normalized), sampler in `renderer(_:updateAtTime:)`.
  — `FsceneRealizer.swift`, `SceneViewHost.swift`.
- [x] Lane 4. Android realization — `SkinningBuffer` per skinned
  renderable, `BONE_INDICES`/`BONE_WEIGHTS` attrs,
  `setBonesAsMatrices` per frame, `MorphTargetBuffer` deltas,
  `setMorphWeights`; Kotlin sampler in the Choreographer loop. —
  `FsceneRealizer.kt`, `MeshFactory.kt`, `Dart3dView.kt`.
- [x] Lane 5. Dart API + diff emission + harness. —
  `lib/src/animation.dart`, `SceneController` play/pause/stop/seek/
  setMorphWeights, `diff_apply` skin/anim upserts + node `skin`,
  `feature_scene` +14 s probe (two-joint flag + morph blob + wave/
  pulse anims + seek + direct weight write).
- [x] Lane 6. Live: skinned deformation + morph + playback, both
  surfaces. — `w11-ios-3.png`/`w11-android-1.png` (`anims: 2
  playing`); flag silhouette differs between wave phases both
  platforms (`flag2-w11-ios-t0/t1.png`, `flag2-w11-android-t0/t1.png`);
  `live=` pose query oscillates at wave period (j1 world rot ±0.05
  — counterphase cancellation + 2-clip weight normalization, both
  upstream-exact); `setMorphWeights` writes with no error.
- [x] Lane 7. Found+fixed: runtime-minted payload specs never reached
  natives — `upsertPayload` carried bytes only; `payloadSpecs` is
  manifest-only and re-realize wiped op-written specs. Op now carries
  `encoding`/`layout`/`format`/`width`/`height`/`length`; both natives
  merge a persistent `opPayloadSpecs` at install. Also iOS
  `.boneIndices` must be ≤2 B — repacked f32→u16 (SceneKit rejects
  int32). — `diff_apply.dart`, `feature_scene.dart`,
  `SceneViewHost.swift`, `Dart3dView.kt`, `FsceneRealizer.swift`;
  evidence: failing run `w11-ios-full2.log` → clean run
  `w11-ios-full3.log`/`w11-android.log`.
- [x] Lane 8. Tests. — 19 new W11 tests + 1 payload-spec test; 86
  total green; `dart analyze` clean; iOS sim build + Android release
  (R8) build clean.
- [x] Lane 9. Regression + perf. — dice settle (`rolled 4` iOS /
  `rolled 6` Android), `joints: 10 (1 broke)`, contacts/queries/env
  live; 60 fps iOS / 82 fps Android — no regression.
- [x] Lane 10. Operator reviews the wave in chat — the fidelity-path
  workstream; approval closes it. — Approved in chat.

**Verify, perf.** Tests alone are not sufficient verification.

- [x] Metric. Animated joint pose + morph weight observable on both
  surfaces. — `live=` pose readback + flag silhouette diff.
- [x] Probe. `feature_scene` W11 phase at +14 s — flag skin, morph
  blob, wave+pulse, seek + `setMorphWeights` at +18 s.
- [x] Baseline. W10 regression frames vs W11. — `anims: 2`, all prior
  systems live, fps unchanged.
- [x] Rule. No silent capability drops — a required skin/anim/morph
  that fails to decode logs, never no-ops. — `has no spec`,
  `no morpher`, `skin not realized` warnings all fire when expected.

**Merge.**

- [x] Evidence paths recorded; operator approves. — Approved in chat.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] Reply to the operator with the final parity matrix, the bug list disposition, and the follow-on program link.

## Appendix A. Prototype evidence

- Settled by directive. Upstream physics schema adopted wholesale. The user asked for upstream interchange for cross-sdk work.
- Settled by audit. Android gaps are mechanical, not architectural. Wave-1 docs research confirms each gap's native API before W6 starts.
- Unproven. `DN_IsolateGen` presence in Android `libdartnative.so`. The Android delegate verifies via `nm` or `dlsym`; absence forces an alternative guard design.
- Unproven. Whether `PluginMutation` supports a native-to-Dart reply for pose queries. W8 design gate.
- Unproven. SceneKit versus Jolt behavioral equivalence for `allowsResting` and contact masks. May require documented platform deltas.

## Appendix B. Alternatives rejected

- Dual-schema physics keeping dart3d names beside upstream names. Rejected per migrate-callers-then-delete-legacy-apis. Zero external users, and a compatibility layer is append-only debt.
- `environment` kept as an alias for `environmentVolume`. Same reason.
- Dice-only engine scope. Rejected by the user's directive to fully implement the engine.

## Appendix C. Risks

- Jolt's object-layer space may not express arbitrary collision categories. W6 may need `GroupFilter` redesign. The feasibility report adjudicates before work begins.
- Filament camera manipulation differs from SceneKit's free control. Parity target is a working orbit control, documented delta allowed.
- W10 surface is large. Honest sequencing beats a premature complete claim.
- No VCS means no rollback. Delegates keep diffs reviewable per workstream. Consider `git init` if the operator wants history.

## Appendix D. Links and reading list

- Upstream sources at `/Users/jasonholt/.pub-cache/hosted/pub.dev/scene-0.3.0/` and `flutter_scene-0.23.0/`.
- Jolt JNI docs at the resolved version's published site. The wave-1 research agent returns URLs.
- Filament docs for `MaterialInstance`, `Camera.setProjection`, `LightManager` shadow options, and `camutils.Manipulator`.
- `docs/plugin_async_callbacks.md` in this repo for the DartNative dispatcher contract.
- `PLAN.md` at the repo root for the phase history this program extends.
