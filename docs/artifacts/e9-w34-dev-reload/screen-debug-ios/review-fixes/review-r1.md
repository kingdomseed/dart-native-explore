# iOS W34 PBR screen-debug review

CHANGES_REQUIRED. Two material, reachable P2 source defects remain. No scoped P1 was found. This verdict covers the implemented iOS PBR screen-debug unit only. It does not accept whole W34, E9, or Track E.

The reviewed checkout is `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1` at HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`, with the exact final 66-path overlay. Source was not edited after import. Independent native execution, builds, tests, dependency operations, devices, simulator queries, and performance are NOT_RUN.

## Findings

### F1. P2. Project detached bones before constructing the diagnostic skinner

The new force unwrap at [ScreenDebugPresentation.swift:178](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/ScreenDebugPresentation.swift:178) can terminate the app for an existing supported skin lifetime.

The public path is a loaded PBR skinned mesh, `SceneController.removeNode(jointId)` on a joint outside the mesh's own subtree, followed by selecting any debug channel. A channel change that rebuilds presentation after the removal also reaches the failure. The Dart operation is defined at [scene_controller.dart:582](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/lib/src/scene_controller.dart:582). Native dispatch calls `removeSubtree` at [SceneViewHost.swift:1642](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/SceneViewHost.swift:1642).

The canonical owner deliberately retains the removed joint through the live skinner and marks its consumer pending for a later joint replacement. It does not remove the mesh or its skinner. See [SceneViewHost.swift:2091](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/SceneViewHost.swift:2091). The initial unresolved-joint path can also construct a skinner with detached identity nodes at [FsceneRealizer.swift:6769](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/FsceneRealizer.swift:6769).

Debug capture records every skinner bone identity at [ScreenDebugPresentation.swift:119](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/ScreenDebugPresentation.swift:119), but collects pose rows only by walking from `scene.rootNode` at line 138. A retained detached bone has no row. A fresh presentation allocates `nodes` only for those rows, then evaluates `skin.bones.map { nodes[$0]! }`. The missing key is therefore force-unwrapped when the diagnostic skinner is constructed. This trace does not depend on a shader, visual comparison, or an assumed race.

The broken contract is preservation of current native deformation attachments across node removal and replacement. The canonical skin owner owns missing and retained bone semantics. `ScreenDebugAttachments` owns projection of those current dependencies. The smallest bounded correction is to include the current skinner's detached bone dependencies and necessary ancestry in the existing pose packet, using their actual identities and resolved transforms. Keep those pose-only dependencies outside authored registries. Do not drop bone slots, bind live source bones into the asynchronous scene, remove the canonical missing-joint behavior, or replace a missing lookup with a new arbitrary identity node.

Evidence level is SOURCE. The app-termination consequence follows from the reachable missing dictionary key and Swift force unwrap. Independent native reproduction is NOT_RUN. A focused follow-up should remove a joint while Off, select a channel, restore that joint, and verify current deformation and Off output.

### F2. P2. Cover the authored host outside diagnostic viewport siblings

The new early return at [SceneViewHost.swift:3170](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/SceneViewHost.swift:3170) makes the authored host render through the real camera while a channel is selected. Existing viewport siblings cover only their declared rectangles. No full-host cover suppresses the authored image in the uncovered regions.

The public path is `SceneController.updateViews` with a `Dart3dRenderViewSpec` whose viewport occupies only part of the screen, followed by `SceneView(debugView: SceneDebugView(channel: SceneDebugChannel.normals))`. This uses the existing exported API at [diff_apply.dart:481](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/lib/src/diff_apply.dart:481) and [scene_controller.dart:908](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/lib/src/scene_controller.dart:908). An inset viewport or two separated viewports leave a visible region outside those rectangles.

The ordinary sibling path selects a mask-zero host camera at [SceneViewHost.swift:3180](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/SceneViewHost.swift:3180). Channel mode bypasses that code and selects the first real camera. [RenderTargets.swift:535](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/RenderTargets.swift:535) creates only the viewport-sized diagnostic `SCNView`. [RenderTargets.swift:685](/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-48b8e2b1/dart3d/ios/Classes/RenderTargets.swift:685) converts the supplied rectangle into that exact sibling frame. Black background on each sibling cannot cover pixels outside its frame.

The resulting image includes an extra full-screen authored view behind the selected diagnostic viewports. PBR meshes, authored effects, and other canonical draws can appear in those gaps. This breaks the existing viewport contract and Candidate B's requirement that the authored pass not show through the diagnostic presentation. The fixture has no viewport rectangle and cannot expose this path.

`SceneViewHost` and the existing screen-sibling lifecycle own this presentation boundary. The smallest bounded correction is a full-bounds opaque black backing beneath the diagnostic siblings, installed, resized, and removed with them. This keeps the current canonical camera available for simulation, facing, and captures. An equivalent correction may suppress only the host's visible output without changing those owners. No additional renderer, clock, or synchronization scheme is needed.

Evidence level is SOURCE. Visible leakage is the consequence of the real host camera and uncovered sibling geometry. Independent viewport pixels are NOT_RUN. A focused follow-up should compare Off, selected channel, and Off with an inset PBR viewport and a visible mesh in the uncovered host region.

## Verified source boundaries

The public data shape is one immutable `SceneDebugView` with a closed six-case enum and an independent wireframe bit. `SceneViewElement` sends tag 6 before controller attachment and compares the complete value on update. Configuration includes full explicit Off. `ScreenDebugOptions.decode` treats absence as Off and rejects malformed present values through the existing native warning path. No debug field was added to authored documents or controller state. These are source observations, not executed reconciliation tests.

The authored scene remains the simulation and capture authority. `didApplyConstraintsAtTime` runs LOD, facing, blend-proxy sync, baked captures, and authored target draws before capturing debug attachments at `SceneViewHost.swift:5756`. Derived geometry attachments own different material arrays. Materials derive from current bound occurrences, including clones and extra primitive children, rather than only the authored resource registry. Proxy exclusion uses identities supplied by the existing BlendCaster owner.

Material signatures include sampled-property contents, transforms, factors, native coverage state, and composed modifiers. New diagnostic materials append final RGB after the existing material bodies. The five expressions read mapped view-space normal, sampled metalness, sampled perceptual roughness, factored diffuse RGB, and compressed positive axial depth. The installed SceneKit header defines the surface's geometric fields in view space and its other properties as sampled colors or floats. No second texture decoder, simulation, or material-factor owner was introduced.

The identity resolve branches before artistic effects. Its camera copies neutralize the authored screen effects. Wireframe owns only `.showWireframe` and restores its prior bit without replacing other debug bits. Captures do not receive that option. Selected-channel Off clears derivatives and reconnects current authored state. Full load clears scene-local derivatives while retaining the view selection. These source traces do not establish every native consumer's output. F1 and F2 are exceptions that prevent acceptance.

Native particles are expressly excluded by the current frame, public documentation, and `program-v2.md:411`. The older judge's particle rejection is superseded only by that explicit operator scope decision. Catcher semantics, non-PBR material parity, Android, and general renderer work remain outside this review.

## Packet and preservation receipts

[packet-replay-receipt.json](packet-replay-receipt.json) records independently reproduced results.

| Item | Result |
| --- | --- |
| Required HEAD | Exact match |
| Final archive SHA256 | `d4483396e722be6b078c6d41f1393dd0895042a63a321cc42f59823ec4f337f3` |
| Accepted58 archive SHA256 | `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706` |
| Owned patch SHA256 | `7e795e648e078b41ddb3f0927340ceaaa5cd650749cd47fedee70aec1f4bb2aa` |
| Source identity lists | All 66 paths match JSON, text, path list, archive, imported checkout, and current parent bytes |
| Forward replay | Exact HEAD plus accepted58, then patch, produces all 66 final identities |
| Reverse replay | Restores the entire accepted58 baseline, including removal of newly added files |
| Owned delta | Exactly the specified 13 paths |
| Unowned preservation | All 1,926 supplied baseline identities match reconstructed baseline, forward result, and current parent |
| Locks and registrants | All six match baseline, final import, and current parent |
| Other review checkout files | Tracked files outside the imported overlay retain their pre-import bytes |

The final tar has 132 unique safe relative regular members. Sixty-six are the declared source paths. The other 66 are matching AppleDouble metadata paths with valid AppleDouble magic. I checked all members for path safety and regular-file type, then imported only the 66 declared source files. Accepted58 has 58 regular members without those metadata files. The first inventory attempt assumed 66 total tar members and stopped before import. A direct tar listing identified the metadata. The initial replay extraction also encountered the host Python's unsupported `filter` argument. The final retained script records the corrected checks. Neither preparation error changed source.

Temporary replay extraction was removed. The source overlay remains in the T3-prepared review checkout. No parent files were written.

## Independently checked offline evidence

I read the durable README and complete 60-file manifest. All 60 identities match. [evidence-manifest-receipt.json](evidence-manifest-receipt.json) retains the exact list and its own manifest identity. The worker handoff, frame, Candidate B, and judge were read as claims and constraints. No live PR or issue state was queried, and no absence or readiness claim follows from their historical lookup notes.

An independent Python implementation decoded the PNGs through ffmpeg and reproduced every field of the retained Dart pixel analysis. It did not run the supplied Dart script, which writes into the parent's evidence directory. [pixel-analysis-independent.json](pixel-analysis-independent.json) records the results.

| Encoded screenshot check | Reproduced result |
| --- | --- |
| Five R2 target-monitor comparisons after normal, metallic, roughness, depth, and wire captures | Zero changed pixels for each 80 by 115 crop |
| R3 target monitor after normal capture | Zero changed pixels |
| R3 Off restoration | Zero changed pixels in the recorded scene rectangle |
| R2 edited Off against reload and toggle Off | Zero changed pixels |
| R2 edited Off against initial Off | 40,337 changed pixels |
| R3 filled wire | 1,759 changed pixels, zero changes in the occluder-interior control |
| Literal 0.125, 0.5, 0.875 in baseColor, metallic, and roughness | RGB 100, 187, 237, versus ideal rounded sRGB 99, 188, 240 |
| R2 depth near and far | Both RGB 237 |
| R3 stronger depth control | Near RGB 211, far RGB 237 |

The restoration and wire comparisons use the supplied scene rectangle `[0,70,402,610]`, not the entire screenshot. Target comparisons establish only the recorded monitor crop. Literal differences are at most three encoded codes. These observations are approximate encoded screenshot output, not calibrated colorimetry or raw GPU readback. No numeric alpha or premultiplication accuracy is established.

The R2 fixture differs from the final source only by the documented occluder Z change from -0.4 to -3. The supplied run receipts describe R3 as a Dart hot restart with unchanged native code. R3 provides the stronger depth separation without a documented shader change. This reviewer did not inspect a running binary. I inspected both contact sheets, selected PNGs, UI action records, native events, and nine independently extracted video frames. The sheets sample selections and do not establish every short state.

One supplied observation could not be confirmed as stated. The retained R2 `13-base-blend.png` contains the three literal swatches and the blue occluder. Direct RGBA samples at the three swatch centers are `[100,100,100,255]`, `[187,187,187,255]`, and `[237,237,237,255]`. The occluder sample is `[89,150,216,255]`. The later 21 and 22 files contain those controls too. [r2-other-object-controls.json](r2-other-object-controls.json) retains the file hashes and samples. I do not infer a renderer cause or a resolved transient from the supplied omission description.

Both raw recording hashes and sizes match. Independent full ffmpeg decodes exit 0. R2 contains 25,409 decoded frames over 248.760000 seconds. R3 contains 4,485 over 37.403333 seconds. [video-receipts-independent.json](video-receipts-independent.json), the progress files, ffprobe outputs, and full decode logs retain that evidence. Both logs include nonmonotonic timestamp warnings. No timing, latency, clean-timestamp, or performance claim follows.

The parent's final example log records 330 tests passed and analysis records no issues. The worker's logs record 393 package tests, 330 example tests, three focused fixture tests, analyses without issues, an empty Swift typecheck log, and a successful generic simulator build. These are inspected historical execution receipts. None was executed by this reviewer. The initial R1 log ends with `Lost connection to device.` The R2 log, which also records hot restart, ends with `Application finished.` Operational shutdown, device-panel cleanup, and absence of A142 operations remain parent-observed. I made no device queries to verify them. The six current source locks were independently verified offline.

## Remaining proof and scope

Independent tests, builds, runtime shader compilation, simulator and device execution are NOT_RUN. The retained pixels cover the compact PBR fixture. Native skin and morph output, instances, variants, LOD, facing, late texture arrival, screen siblings, camera gestures, and view or controller recreation were source-traced where relevant but not independently executed. The two findings identify reachable defects within those PBR consumer paths, rather than treating missing fixture coverage as proof of correctness.

Other material families, catcher parity, Android, performance, final T2 and T4, and whole W34 or Track E acceptance remain outside this unit. The README's broad historical implementation status and the superseded ten-lane W34 prose do not override current program gates. The referenced vendor path `dartnative/docs/plugin_development.md` is absent in this checkout. I used the repo-local DartNative skill, existing protocol and element implementation, and installed SceneKit headers. No vendor documentation was invented.

Poteto-mode's Prove It Works principle led to direct archive, replay, screenshot-byte, and video checks. Boundary Discipline kept proposed corrections at the screen-presentation owner. The explicit no-children and read-only instructions superseded the skills' delegation and comment-edit defaults. No new comment audit, source fixes, architecture tournament, or external writer ran.

All retained outputs are enumerated in [retained-files.txt](retained-files.txt). They comprise this report, import and preservation receipts, reproducible verification scripts, source and evidence hashes, line-numbered source and SDK excerpts, inspected log summaries, independent pixel and video receipts, full decode logs, progress files, ffprobe data, and nine selected video frames. The imported source is retained separately in the named review checkout. Only temporary replay scratch was removed.
