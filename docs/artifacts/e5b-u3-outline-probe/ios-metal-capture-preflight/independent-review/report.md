# The initial target contour still fails, and its executed pass is unobserved

Independent verdict. The latest initial-binding control is negative. Both first Set target outputs are byte-identical to their actual Off output and miss all 267 expected contour pixels despite current 205-pixel masks. Configuring the candidate before the copying setter is insufficient. This does not identify a SceneKit defect, establish deferred activation, or establish a shared cause with synthetic alpha.

My recommendation is one bounded Metal command-capture measurement of the existing control, before another implementation. Inspect whether the ordinary target's first requested draw actually executes `u3_views_outline`, which uniform and texture it consumes, and what ultimately writes the target. The source and public documentation justify that measurement. They do not justify a preparation-based correction or require an additional render.

This was a single independent Codex investigation. No children and no provider diversity. Independent builds, tests, native execution, devices, simulator discovery, Android and performance are NOT_RUN. Offline evidence recomputation is complete. No implementation was prepared.

## Inputs and preservation

I verified HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12` in the T3-provided checkout on Jason's Mac mini. I imported only `/private/tmp/dart3d-u3-outline-first-target-control-20261028/r1/parent/runtime-source/source.tgz`, SHA256 `40110ca8e3db10d4dd057689898568ad31448cbef9fe08b11bd7e20e5716a603`. All 70 entries matched `source-sha256.json` before writing and after import. The importer rejects absolute paths, parent traversal, duplicate or unlisted files, symlinks, hard links and other nonregular files. It filters AppleDouble and `__MACOSX` members. None were present.

The runtime70 manifest also equals the published evidence manifest and the earlier worker's `final70-control/source-sha256.json`. The earlier worker report's input archive hash and older publication results describe its earlier inputs. They are not the latest runtime packet.

[source-import-preservation.json](source-import-preservation.json) retains the full before snapshot and imported manifest. All 1,873 tracked files outside the overlay retain their bytes and modes. These six actual files retain their original hashes and modes.

- `dart3d/pubspec.lock`.
- `dart3d/example/pubspec.lock`.
- `dart3d/example/dn_plugins.lock`.
- `dart3d/example/ios/Podfile.lock`.
- `dart3d/example/lib/dartnative_plugin_registrant.dart`.
- `probe/pubspec.lock`.

The final preservation receipt verifies all 70 imported files still match and the same unowned files and six locks remain unchanged. The source overlay is intentionally intact. All subsequent writes are report and recomputation receipts in this worker directory. No dependency setup, builds, source edits, worktree changes, external mutations, PR or issue operations were performed. There are no own scratch files outside the retained receipts.

I read the applicable AGENTS, poteto-mode including its native Codex section, Investigation, how, unslop, technical-writing, Attack the Premise, Fix Root Causes, verification guide, package README and program guide. The documented `dartnative/` vendor clone is absent here. No `CONTEXT.md` was found. No clone or install was attempted. The old program status is dated 2026-10-05 and is context, not live completion evidence. The explicit no-children instruction overrides skill delegation steps. Throughput checkpoint is n/a for this read-only investigation.

## Independent raw and evidence results

[recompute.py](recompute.py) reads the supplied evidence and writes only this directory. [evidence-verification.json](evidence-verification.json) verifies all 227 evidence manifest entries and the full native log and both original videos, including lengths and hashes. Both `analysis.json` files and every row of both `first-use.json` files agree with independent recomputation in [independent-raw-results.json](independent-raw-results.json).

All 42 raw textures are complete 96 by 72 images with consistent metadata and unpadded byte lengths. Targets, held reads, synthetic inputs and outputs are BGRA8 sRGB, Metal81. Masks are little-endian RGBA16Float, Metal115. The oracle scans the radius-three circular neighborhood in shader y-then-x order with strict-greater coverage selection, clamps at the edges, and converts linear RGB to sRGB bytes. It compares all four output bytes.

Both runs have the following results.

| Requested transition | Mask support | Expected contour | Target contour mismatches | Target outside RGBA changes | Private callback draws |
| --- | ---: | ---: | ---: | ---: | ---: |
| First Set | 205 | 267 | 267 | 0 | 3 |
| First Clear | 0 | 0 | 0 | 0 | 0 |
| Second Set | 205 | 267 | 0 | 0 | 3 |
| Second Clear | 0 | 0 | 0 | 0 | 0 |

Each populated mask has 94 orange pixels with linear RGBA `[1,.25,.0625,1]` and 111 blue pixels with `[.0625,.5,1,.5]`. All other mask pixels are zero. Off has 6,695 transparent pixels and 217 opaque geometry pixels. Off and first Set in both runs have the same 27,648-byte SHA256 `b330c9051c95b8c02c2acb8bbcac4443fd0e8fe1a9ddaf68de631ca8d4113388`. This is complete byte identity, not a visual comparison.

The first synthetic-alpha output in each run is exactly 6,912 black opaque pixels. It has 6,645 outside-contour mismatches and 267 contour mismatches. The next three synthetic outputs preserve outside RGBA and match their current contours. [synthetic-source-identity.json](synthetic-source-identity.json) independently confirms the complete `targetProof` suffix is byte-identical to the earlier publication-control source. No private arithmetic was substituted.

[independent-log-results.json](independent-log-results.json) reconstructs all 34 four-byte textures exactly from the complete native console rows. All 576 half-float console rows are truncated, so their complete hash-verified raw files are the evidence. The full PID logs contain 25,014 baseline rows and 25,773 control rows, matching final parent receipts. The parent's actual case-insensitive error query recomputes zero matches for both PIDs. Zero errors does not mean functional success.

There are five admitted target draws per run, initial Off plus four explicit requests, four highlight batches, and four dirty=false held readbacks equal to the immediately preceding output. There are four target private-update callbacks with 3,0,3,0 draws. At each exact encode timestamp, mask encode begins, the private callback publishes, mask encoding returns, then ordinary target encoding begins. The source puts these operations on the same command buffer. Neither CPU event strings nor final mask bytes reveal the actual fragment sampler binding.

The installation markers select false at `542658.2500000001` and true at `542739.9833333334`, both mode 2. Source lines below show the true branch binds the candidate and both branches subsequently bind `renderer.technique`. Publication remains true in both. Same-source runtime is supported by the packet/manifest and parent run record, not by extracting source code from the installed app.

[independent-screen-crops.json](independent-screen-crops.json) recomputes all eleven frozen 402 by 600 RGB crops exactly using the existing ffmpeg decoder. I inspected the Off and first Set screenshots. The two sibling screen views show the expected selected outlines. These screenshots do not show the target's raw alpha or establish motion correctness.

[video-review.json](video-review.json) checks existing full-decode receipts against hash-verified original videos. They record 3,643 baseline and 5,785 control frames, totaling 9,428, with successful full decodes and two baseline/four control duplicate-DTS warning lines. I read those warning logs. I did not repeat full video decode because it cannot distinguish technique execution from bindings in this diagnosis. No latency or performance conclusion follows.

The parent fixture log records 25 passing tests. Both published `probe.log` files are empty. The README reports successful native builds/runs and the complete PID logs establish app execution, but this packet does not independently expose full build output. The older worker's compilation and 13-test claims remain inspected worker receipts. None are independent builds or tests by me.

The parent restoration/configuration receipts state accepted66 and all 4,938 prior files restored, the four own additions removed, six locks and normal-main Pods restored, owned app/recorders/logger stopped and owned simulator shut down. These are parent receipts and statements, not my live observations. I made no device query. A142 remains RESERVED and untouched by this worker.

## Reachable contract and owner

All paths below are relative to this checkout and refer to the exact imported70 source.

1. `dart3d/lib/src/scene_controller.dart:390-424` documents and emits the public `setNodeHighlights` mutation. It copies scalar values into one command and excludes highlights from serialized state.
2. `dart3d/ios/Classes/SceneViewHost.swift:1649-1688` validates the command at native ingress and applies it to the sole `SelectionOutline` map. `SelectionOutline.swift:13-22` owns the map. The diagnostic stored read does not dirty the target.
3. `SceneViewHost.swift:5801-5811` captures selected attachments after constraints, then invokes existing target admission. `SelectionOutlineViewsProbe.swift:54-143` derives the frame from authoritative selection and presentation geometry. Marker z controls private-update publication, marker scale x controls the initial-binding experiment.
4. `RenderTargets.swift:263-295` admits a manual target only when dirty and consumes that admission once. `RenderTargets.swift:337-340` creates the persistent per-view `SCNRenderer` sharing the source scene. Camera/layer/exposure setup is local to the target encode, with restoration at lines 322-335.
5. `SelectionOutlineViewsProbe.swift:254-340` owns the detached private mask renderer. Its existing combined update-and-render at lines 321-322 publishes current private geometry through its private callback. Keep this effective publication path.
6. `RenderTargets.swift:397-422` encodes the mask, lazily creates a composite-only technique, optionally binds the candidate before assignment, always binds the installed copy, then performs exactly one ordinary render-only draw. Off removes the technique at lines 411-413. The target has already produced one real Off draw before its first technique installation.
7. `SelectionOutlineViewsProbe.swift:343-352` binds mask and mode symbols. `ToneMapping.swift:405-431` returns the base for modes below 1.5 and otherwise computes the contour. `ToneMapping.swift:548-569` owns pass definition, symbols and library. It uses `COLOR` for ordinary source/destination, disables depth reads/writes and blending, and installs the same kernel for the tested target.

The required behavior is one explicit public target request that includes the current contour in its first returned output. The remaining fault is downstream of successfully producing the current mask and upstream of the complete target result. Per-target renderer/technique lifecycle belongs in `RenderTargets.swift`. Pass definition belongs in `ToneMapping.swift`. Source scene simulation remains owned by `SceneViewHost`; neither selection ownership nor simulation should move to the target.

## Installed contracts and primary documentation

[installed-sdk-verification.json](installed-sdk-verification.json) verifies the four supplied headers against their actual installed counterparts under `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks/SceneKit.framework/Headers`. I read their applicable declarations and comments directly.

- `SCNRenderer.h:38-57,66-77` documents the device initializer, combined update-and-render, update-only and render-only entry points. Render-only deliberately omits animations, physics and particle updates. Apple's [combined render documentation](https://developer.apple.com/documentation/scenekit/scnrenderer/render(attime:viewport:commandbuffer:passdescriptor:)) likewise describes presentation-node update before drawing. It does not authorize duplicating the source owner's update.
- `SCNTechnique.h:270-299,313-316` documents symbol values, Metal library selection and a copying technique setter. Apple's [technique property](https://developer.apple.com/documentation/scenekit/scntechniquesupport/technique) confirms that property contract. It documents neither a mandatory initial Off draw nor a deferred first pass.
- Apple's [setObject documentation](https://developer.apple.com/documentation/scenekit/scntechnique/setobject(_:forkeyedsubscript:)) permits initial and infrequent symbol writes. It does not make binding after installation invalid. The negative paired control specifically rejects pre-copy initialization as sufficient, while leaving GPU-visible parameter publication unmeasured.
- `SCNSceneRenderer.h:181-196` and Apple's [synchronous preparation](https://developer.apple.com/documentation/scenekit/scnscenerenderer/prepare(_:shouldabortblock:)) and [asynchronous preparation](https://developer.apple.com/documentation/scenekit/scnscenerenderer/prepare(_:completionhandler:)) name scenes, nodes, geometry and materials as accepted content. They describe preloading geometry and material resources. They do not name `SCNTechnique`, `MTLTexture` or `SCNMaterialProperty` as direct preparation inputs or promise renderer-technique publication. Preparing a material is supported, but inserting an otherwise unused material/node merely to make an external technique sampler reachable would add an unsupported causal assumption and extra machinery.
- `SCNTechnique.h:255-262` exposes symbol callbacks. Apple's [handleBinding documentation](https://developer.apple.com/documentation/scenekit/scntechnique/handlebinding(ofsymbol:using:)) describes GLSL/OpenGL work and requires handlers to be set before installation. It supplies no demonstrated Metal `SCNTechnique` binding-readiness remedy here. I do not recommend switching to that hook or replacing the technique with an `SCNProgram`.
- `SCNTransaction.h:14-29` says transactions batch graph changes and flushing affects the calling thread's implicit transaction, with delay under nested explicit transactions. This is not a target-local readiness primitive. No global flush follows from these observations.

Therefore standard scene preparation is a legal operation but not a documented way to complete this technique's activation. No omitted required initializer was found in the installed public contracts. An undocumented internal synchronization requirement remains a hypothesis. Setting additional default flags, preparing the already-rendered source scene or invoking an update would not isolate that hypothesis.

Apple documents [capturing a Metal workload in Xcode](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-in-xcode) with device or command-queue scopes and finite command-buffer counts. The [Metal debugger](https://developer.apple.com/documentation/xcode/metal-debugger) exposes executed commands and bound resources. Its [buffer viewer](https://developer.apple.com/documentation/xcode/inspecting-buffers), [texture viewer](https://developer.apple.com/documentation/xcode/inspecting-textures) and [attachment viewer](https://developer.apple.com/documentation/xcode/inspecting-the-attachments-of-a-draw-command) can distinguish uniform bytes, sampled content and later output writes. This is the documented discrimination route, rather than another rendering API change.

Capture availability on this approved simulator/runtime has not been tested. Apple's [Simulator Metal guide](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator) says Simulator translates to the host GPU and has different limits. The docs do not establish that this exact runtime supports the proposed trace. A refusal must be retained verbatim and reported as an unavailable measurement; it is not evidence about SceneKit's cause. No physical iOS run is implicitly authorized.

The web reader returned JavaScript shell pages for direct documentation opens and `400 Unsupported content-type: text/markdown` for the offered Markdown links. Search-indexed official Apple documentation supplied the prose above; the actual installed headers independently supplied the SceneKit declarations. These are observed retrieval limitations. I did not call SceneKit or another platform tool broken.

## First-use counterexamples and competing hypotheses

`BakedShadowCatchers.swift:166-188,236-302,327-335` builds a detached capture graph, copies source presentation state and creates its camera before rendering. Its new renderer performs a combined `render(atTime:)` and no `SCNTechnique`. It demonstrates an existing first-use detached capture pattern, not successful first-use lazy technique installation on a render-only renderer. Replacing the ordinary target call with that combined operation would cross source simulation ownership.

`SceneViewHost.swift:455-492` creates/configures the source tone-map technique and assigns it before later source rendering. Lines 503-541 create/configure sibling live and diagnostic resolves and reconfigure the installed copy. `RenderTargets.swift:699-760` applies sibling state on main, commits that explicit transaction, encodes its private mask and binds the installed technique before display. Those are SCNView display/update lifecycles, with different timing and scene construction from the synchronous target render-only path. Frozen screen success is not evidence that the siblings' very first technique draw succeeded.

The synthetic renderer is a distinct cold path. `SelectionOutlineViewsProbe.swift:412-441` creates an otherwise empty scene and copied camera, then uses render-only from its first invocation. It replaces its technique on every invocation, yet invocations two through four succeed. This argues against a blanket rule that every new technique object necessarily loses its first pass. It does not prove that ordinary-target activation and synthetic-alpha failure have the same cause.

The following order ranks investigation priority, not measured probability.

| Rank | Hypothesis | Evidence and discriminator |
| --- | --- | --- |
| 1 | The lazy target installation does not produce an effective first outline pass. | Off-identical first result and later success fit this. The target renderer itself has already drawn Off. Inspect whether the first target command buffer contains the outline quad. |
| 2 | The pass executes with an ineffective GPU-visible mode or mask binding. | Pre-copy and installed-copy writes failed equally. That does not measure GPU mode bytes or the sampled texture version. Inspect buffer 0 and texture 1 at the actual quad. |
| 3 | The quad runs with correct resources but writes an intermediate attachment that is subsequently replaced, or has another pass-state issue. | Final raw output does not expose intermediate COLOR/resolve ownership. Inspect its attachment and every subsequent writer to the target. |
| Lower | A universal bad kernel, wrong authoritative selection or stale private membership. | Current masks and later exact contour outputs contradict these as sufficient explanations of this run. |

The missing fact is the actual first target command stream, including the outline draw's bound mode, bound mask content at that draw, and final destination writes. CPU setter calls, object identity, completed readbacks and zero error markers cannot supply that fact.

## Assessment of persistent identity-mode installation

A persistent target technique installed at renderer creation would fit the existing owner's lifetime. The shader already has an identity branch. It could avoid nil-to-technique transitions without creating another renderer or changing the public protocol. That makes it a plausible later lifecycle experiment, not a documented correction.

It also relocates first technique use into the existing initial Off draw. Identical Off bytes alone cannot distinguish a correctly executed identity pass from an omitted pass. If that first Off pass silently fails and the later Set succeeds, the experiment has hidden the activation failure in an output that cannot reveal it. Calling that initialization rather than warm-up would require direct evidence that the first Off pipeline ran correctly, plus a coherent persistent resource lifetime.

There is another concrete source constraint. Off currently creates the binding object but never calls `encode`; its mask/property remains nil until the first non-Off draw. Moving installation alone cannot demonstrate that a valid persistent sampler is established. Adding a mask render during Off, a dummy scene/material, or a new resource arrangement would add variables to an experiment that is supposed to isolate technique activation. A shader branch that does not sample the mask does not document valid behavior for an unbound required texture.

Any future identity candidate must preserve its first returned Off RGBA exactly, including all transparent bytes, the same five admitted target draws, four held reads, existing mask publication and first Set contour. It must show the actual first Off quad and valid required bindings and retain the same technique identity through later mode changes. Replacing the technique at Set would abandon the hypothesis. A first Off RGBA difference, extra draw, missing first Set contour or invalid sampler refutes that candidate. Off identity plus later contour success without pass/binding evidence would support only a bounded workaround, not discriminate readiness from copied parameters.

I do not recommend commissioning that candidate before the following measurement. It changes when the first pass happens while leaving the decisive pass execution unobserved.

## One finite next experiment for the parent

Use the exact existing runtime70 and existing false/true binding selector. Introduce no third treatment and no source change. The added observation is an Xcode Metal trace of already admitted target work. The positive internal comparison is the second Set draw that already exists in the prescribed sequence.

1. On the approved runtime, enable the documented Xcode GPU capture route. Before commissioning any app instrumentation, verify that its built-in command-queue capture is available for this app. Use the target's actual queue and correlate with target texture identity, 96 by 72 dimensions, timestamps and the target draw call stack. Limit the attempt to that capture route. If unavailable, retain the actual refusal and stop this measurement. Do not change hardware, add a capture framework, switch renderers or write a custom driver automatically.
2. Run baseline false first, then control true in fresh launches with publication true in both. Boot Off, two siblings, paused, no AA, manual 96 by 72 target. Retain the same Outline-empty, Set-held/request, Clear-held/request, Set-held/request, Clear-held/request order. There must still be exactly five target admissions and four highlight changes per launch. Capturing must not request a render or call an update.
3. Capture at most three existing target command buffers per launch, initial Off, first Set and second Set. Use a debugger stop before `RenderTargets.swift:391` creates the selected target command buffer, then the built-in queue capture with a finite count. The capture must include creation and commit of that command buffer. Confirm the captured buffer is the selected target buffer; a host/sibling-only trace is not a result. This is at most six captures across the two launches, with no extra target draws. If capture cannot select that existing buffer reliably, report the missing observation rather than preparing another control.
4. Keep the first actual Off output and compare full RGBA against this run's frozen baseline and the original Off bytes. The existing unmodified source predicts no target outline technique at that draw. Confirm that in the trace. Do not hide or discard the first Off result. Its failure invalidates later comparisons.
5. For first Set, recompute the actual current mask and target oracle. Require publication draws 3, current support 205 and expected contour 267 for the pinned raster, with the exact private callback/encode order. Judge actual support if the raster changes, and mark the historical reproduction invalid. Preserve all outside-contour RGBA. Retain four held dirty=false readbacks that equal their preceding output.
6. Inspect the ordinary target pass separately from sibling, private-mask and synthetic-alpha commands. Record whether a draw uses `u3_views_outline`, its viewport and pipeline, the 16 bytes for `U3OutlineParams` buffer 0, `colorSampler` texture 0, `u3Mask` texture 1, its mask contents at that command, its output attachment, and subsequent writes/resolves to the returned target. Mode 2 should have float4 bytes `00000040 00000000 00000000 00000000` in little-endian grouped hex. Verify the actual sampled mask is the current 205-support image, not merely an object with the same dimensions. Compare with the second Set's known passing draw.
7. Export traces and the relevant resource/attachment receipts before ending the run. Recompute target outputs, synthetic alpha, admission and held reads independently. The first failing Set must remain Off-identical and the second Set must pass under capture; otherwise capture changed the observed case and cannot decide its original cause. Performance is not measured.

Interpret the finite observation as follows.

- If first Set has no outline draw but second Set does, parameter copying cannot explain an absent draw. This supports a target technique activation/pass-discovery boundary. It does not identify which undocumented internal operation deferred it.
- If both execute the quad but first Set consumes a bypass mode, stale/empty mask or different resource, pass omission is refuted. The next investigation stays at target binding/publication ownership. The same CPU writes do not make their GPU effects identical.
- If the first quad has correct mode/current mask and computes a contour into an intermediate attachment that is later overwritten, both simple omission and initial parameter copying are refuted. Follow the returned target's writer/resolve path.
- If the quad, inputs and final attachment all appear correct yet the returned bytes fail, the finite trace has not settled the case. Retain the exact contradictory resource/attachment evidence and state that shader execution or capture fidelity remains unresolved. Do not add a retry or redraw.

This plan uses no additional draw, source-scene update, clock, queue, scheduler dirtying, graph recreation, renderer fork, alternate compositor or protocol change. Apple documents command capture and resource inspection, but trace availability and successful symptom reproduction remain NOT_RUN. The ordinary target stays unfixed until a later commissioned change passes its first requested output. Synthetic alpha remains a separate failure. Broader U3, W34, Track E, Android, motion, deformation, MSAA, view replacement/retirement, scaled width, T2/T4 and performance remain OPEN or NOT_RUN.

The Attack the Premise principle changed the next step from another initial-value rewrite to observing the actual first pass. The Fix Root Causes principle kept the plan at target lifecycle/binding ownership and excluded compensating draws. The how workflow supplied the owner trace, and unslop/technical-writing kept claims and their limits together.

## Retained artifacts

The retained files are `report.md`, `recompute.py`, `source-import-preservation.json`, `final-preservation.json`, `evidence-verification.json`, `independent-raw-results.json`, `independent-log-results.json`, `independent-screen-crops.json`, `video-review.json`, `installed-sdk-verification.json`, `synthetic-source-identity.json` and `delivery-sha256.json`. The delivery manifest records exact SHA256 identities for every other retained artifact. No patch, implementation file, native setup or extra control exists in this delivery.
