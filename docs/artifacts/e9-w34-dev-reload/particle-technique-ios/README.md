# Native iOS particle scene-pass experiment

The tested SCNTechnique DRAW_SCENE Metal override does not replace this fixture's visible native particle output. In the decisive r2 run, both mesh controls become constant magenta while the frozen native particles remain green. [Independent Codex review passed for this bounded negative conclusion](review/report.md), with no material in-scope P1/P2 or evidence overclaim. This rejects the visible-override premise of this tested route; it does not identify the particle's private GPU program or prove that every public SceneKit route is impossible, nor whole-W34 acceptance.

## Decisive r2 observation

Approved iPhone 17 Pro simulator C24F3C6D-A3A9-4FB7-978E-36E67EF55354, iOS27.0, Runner PID61329. One original scene, one native SCNParticleSystem created by the ordinary public emitter path, one indexed normal-mapped mesh and an opaque bar. No duplicate scene/emitter, alternate particle renderer, callback-based geometry, second simulation or public debug API was added.

| Capture under parent-runtime-r2 | Observation |
| --- | --- |
| 00-live.png | Ordinary mesh/bar and moving native green particles. |
| 01-frozen-off.png | Same original system frozen by speedFactor=0 and birthRate=0. |
| 02-constant.png | Mesh and bar become magenta; native particle interiors remain green. This is the positive mesh witness and negative particle-interception result. |
| 03-off-return.png | Full scene crop matches frozen Off exactly. |
| 04-resumed.png | Original simulation values restored on the same attached system; particle image changes while mesh stays fixed. |

`analyze-images.dart` decodes PNG RGB with FFmpeg. Crop [0,100,402,620] excludes status/footer. Frozen Off versus returned Off has **zero changed scene pixels**. A mesh interior sample at (80,360) changes [71,57,39] → [255,0,255] → [71,57,39]. The bar sample at (300,360) likewise becomes magenta. Constant has 21,320 magenta scene pixels. Of 10,361 green particle interior pixels selected from the frozen baseline (3×3 uniform interiors in region [220,180,160,380]), **all10,361 remain green, zero become magenta, maximum RGB-channel difference is1**. These are encoded screenshot measurements, not raw color/normal calibration or a particle count. The pass background changes to gray; no full-scene Off/Constant identity is claimed.

`native.log` records Metal library creation, the two named functions and assigned w34_particle_scene pass. Actual r2 depthStates show enableRead=false, enableWrite=true, clear=true and greaterEqual. Both frozen and Constant records have original system ObjectIdentifier(0x0000000108d9bc00), attached=true, speedFactor0/birthRate0. Off restores d3_resolve. Resume restores speedFactor1/birthRate8 on that same object. Request labels are not treated as applied state. Source and native records explicitly state population/positions unavailable, callbacks not installed and pipeline unobserved; rendered mesh pixels supply the pipeline witness. Same-population evidence is the preserved native object and exact frozen Off restoration, not an invented count or callback measurement.

The marked16×16 image is bound as MTLSimTexture and nonwhite tint is logged. The baseline visibly shows green rectangles, not an established asymmetric L/amber/blue pattern. This instrument does **not** prove sampled particle texture/tint access or diagnose that appearance. It tests whether the constant override affects the actual native particle draws.

## Earlier r1 candidate

`parent-runtime/` preserves the first run, Runner PID56848, source archive parent-source.tgz. The constant library and technique were created, but with depth reads enabled the mesh and bar disappeared. That candidate is **inconclusive for interception**, because the positive mesh witness failed. Ordinary Off restoration, original-system freeze/resume and the native mesh wire diagonal were observed. Particle wire edges were not visually established. No general particle-wire or occlusion support is claimed.

R2 changes only the pass's depth-read state to false plus logging of actual depthStates. Vertex and fragment shaders are unchanged. The successful r2 mesh control therefore removes the first candidate's depth rejection from the interception question. The exact reverse-Z/clear/comparison interaction was not investigated. Disabling depth testing is a synthetic control, **not** a production depth/occlusion fix or proof. Neither run proves resolved particle color, axial depth, actual particle edges or authored-target isolation.

## Source identity and preparation

Accepted production-intended baseline58 is archive6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706. Worker packet is `worker/HANDOFF.md` with command/results, four-file patch and coherent runtime archive. Parent read all files and checked packet/import hashes. Source remains the original adapter path and four temporary files only.

| Observed source | Archive SHA256 | Probe patch SHA256 |
| --- | --- | --- |
| r1 parent-source.tgz | 560cbe5d93d83b8bd96c659002e6d71d98ab1a304468dd0f7b5a811c79af9294 | 4b67a86525f3bcb961bb9307d51f541e4b9e6b72b54653776fe996d35ce22620 |
| r2 parent-r2-source.tgz | ad36f3cb97f394bc56324e9bd0f211d3ea6e7225132c594436f54049764d6ecb | 2709b22236ef3f9867e554105b81deb78c147ffe0f088e84269dae58564e1d46 |

Both61-path snapshots have post-run source checks. All57 unowned baseline sources and six locks/registrants were preserved during packaging. Parent split verbose state logging, used actual renderer usesReverseZ for the initial comparison, and removed two audited narrative comments before r1. No measured production fix is claimed from those preparation edits. The external position-semantic comment was retained with installed-header proof; no suppressions, comment restores, reruns, encodings or architecture changes.

Worker targeted Dart analysis, full Swift typecheck and adapter compilation passed. Parent targeted analysis/typecheck passed after its preparation edits. Actual documented dn run builds passed (r1 27.7s, r2 8.7s) and both transcripts end Application finished. These durations are build receipts, not latency/performance measurements. The embedded Metal library and program path executed during these runs; only the mesh witness establishes visible custom-program output.

## Video

Recording start completed before the control sequence in both runs. R2 raw `parent-runtime-r2/interception.mp4` is HEVC1206×2622,89.848333seconds,5476frames. Full FFmpeg decode exits0 and reaches5476frames;88 retained null-muxer timestamp-warning lines mean this is not clean timing/latency proof. The8-cell contact sheet samples0,5,12,30,60,75,82,88seconds and shows live/frozen ordinary, sustained magenta meshes with green particles, Off restoration and resume. Raw video hashes are in video-sha256.txt. R1's raw movie is retained as the earlier inconclusive candidate; no parent full-decode claim is made for it.

## Cleanup and remaining work

Stopped recorder, app and logger for each run. After saving r2 source, reversed only parent-r2-probe.patch. `restored58.txt` verifies all accepted58 sources, including the accepted reload library; three probe additions are absent. Restored normal DN_TARGET=lib/main.dart with no reload/probe selector, and regenerated Pods to remove the deleted Swift build reference. Six locks/registrants remain unchanged after Pods. `cleanup-check.txt`, restore logs and final device inventory retain these observations. Simulator shut down, no open device. A142 had no targeted operation.

Kept source archives/patches, two raw recordings, PNGs/native/run logs, compile and hash receipts, analysis scripts/contact sheet, and ignored existing build/resolution outputs. Contact-sheet scratch was removed. The installed example app is stopped; no claim that its last installed binary was replaced is made. Small images/logs and this manifest are copied to repository evidence; raw recordings/source packets remain at this private packet pending any later release publication. No commit, push, PR or external issue change occurred.

This experiment stops here. No sampled-color/depth pipeline, projection implementation or particle replacement follows from a failed interception premise. B remains a design ranking, not an accepted full production base. Other possible public routes are untested. Existing W34/Track E scope, platform gates and operator review remain open.

The reviewer independently verified both source replays, all screenshot computations and the full5476-frame r2 decode offline. Independent native runtime/builds/tests were NOT_RUN. This final checkpoint updates the narrative only; native evidence remains byte-identical to the reviewed private packet.
