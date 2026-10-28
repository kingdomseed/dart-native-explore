# BASIC iOS highlight-state native evidence review

PASS. No material reachable P1 or P2 defect, or blocking evidence gap, found in the bounded BASIC iOS sequence.

This is an independent Codex audit of the supplied parent execution. I executed only offline hash, patch replay, numeric, image, and video checks. I did not execute a device, simulator, build, test, or typecheck. The earlier source-review PASS is a separate source conclusion. It is not the basis for the native verdict.

## Exact source and replay

The app-prepared isolated review worktree is `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-8e741de3`. It was clean before authorized import. Its verified HEAD is `2f38e4e33f0b1cb678bc408a42d069c796cefc12`.

I recomputed these SHA256 values. All match the requested values.

| Artifact | SHA256 |
| --- | --- |
| Observed source54 archive | `981bfe5474e65993736fc927b9879b7029a354b3abebccdda9fcbc5d079edb5a` |
| Accepted production52 archive | `646f5d269a78020fb588ea420fb2783ea9d5a998e6b8019fd8885ad365726f2d` |
| Five-file diagnostic patch | `d6e2277926387e2e3e6f084bbdf0c8ab3a0efe8785eed86f7ce09da9d76d8e2a` |
| Parent video | `975cbb79c51646395a9b793f0f1e7ed4c10f9fe7a1036c08a0bbd43a715e178a` |

All 54 archive paths match `parent-observed-source-sha256.txt` after import. I checked the archive inventory against the manifest, then applied the diagnostic patch to the separately verified production52 baseline. All 54 resulting hashes match the observed archive. The delta is exactly the five paths in `owned-paths.txt`. Three existing files change and two files are added. Every other production path, 49 in total, is byte-identical.

Reverse replay restores all 52 production hashes and removes both additions. Replay scratch was removed. The imported observed source54 remains in this review worktree. No source changes followed import. The 42-entry worker artifact manifest and 34-entry parent artifact manifest also verify independently.

Receipts are [primary-artifact-sha256.txt](primary-artifact-sha256.txt), [import54-check.log](import54-check.log), [replay-verification.json](replay-verification.json), [forward54-check.log](forward54-check.log), [reverse52-check.log](reverse52-check.log), [unowned49-check.log](unowned49-check.log), [worker-artifact-check.log](worker-artifact-check.log), and [parent-artifact-check.log](parent-artifact-check.log).

## Actual public and native paths

The fixture at `dart3d/example/lib/u3_highlight_state_scene.dart:13` builds a real document. The parent lists the child in `children`, and the child is excluded from roots. The independent sentinel is a root. Camera and emissive material are ordinary document resources. This is not a Dart simulation of selection.

`runU3HighlightStep` at line 94 calls the public `SceneController` methods. Assignment and patch use `setNodeHighlights`. The transform action calls `setNodeTransforms` on the child and then patches only the sentinel. Removal calls `removeNode` on the parent. Re-addition uses `applyCommands` with two ordinary `addNode` commands and the same IDs. Explicit reselection names the child. Replacement calls `loadDocument` on a fresh same-ID document. The initial showcase path at `showcase_scene.dart:228` also uses `loadDocument`. The seven requests are manual button actions at line 1675, with no automatic post-load highlight action.

The unchanged facade at `scene_controller.dart:403` immediately encodes copied scalar values into the existing command mutation. It retains no selection map or reducer. The existing plugin dispatch at `Dart3dPlugin.swift:59` enqueues native work. The host drains it at `SceneViewHost.swift:1113`, decodes highlights at line 1564, and calls the state owner at line 1599. The observed map therefore belongs to native scene state.

I inspected the entire Swift diagnostic delta. `SelectionOutline.swift:19`, `:24`, `:29`, and `:34` only call a private logger after the existing operations. At line 37, it sorts actual private dictionary keys, reads actual stored Float RGBA values, and calls the existing `d3Log`. It adds no assignments, decisions, guards, renderer path, public getter, or query seam. Other native host and realizer files are unchanged against production52.

For removal, `SceneViewHost.swift:1957` walks actual `SCNNode.childNodes`, derives actual registered doomed IDs, and removes their colors at line 1977. Re-addition at line 2120 creates and attaches fresh nodes without assigning highlights. Explicit load clears at line 1366. These inspected paths support the specific interpretation of the observed records. They do not establish the unexecuted lifecycle cases below.

## Nine independently checked native records

I read the raw 113-line `parent-native.log`, including its non-highlight records. All Runner entries use PID90007. All nine highlight messages are unredacted. I compared every complete literal body against expectations derived from the fixture and against the handoff. I did not rely on `check-native.dart` or the supplied comparison boolean.

P, C, and S below are the actual UInt64 keys `128861903781889`, `128861903781890`, and `128861903781891`. They follow `(0x7533 << 32) | index` for indices 1, 2, and 3. Each map below lists every entry, not a subset.

| Record | Raw log line | Operation | Entire observed map |
| --- | --- | --- | --- |
| 1 | 5 | `clearScene` | Empty, count 0 |
| 2 | 24 | `apply` | P `[1,.25,0,1]`, C `[0,.5,1,.5]`, count 2 |
| 3 | 35 | `apply` | C `[0,.5,1,.5]`, S `[.25,1,0,0]`, count 2 |
| 4 | 39 | `apply` | C `[0,.5,1,.5]`, S `[.25,1,0,.25]`, count 2 |
| 5 | 42 | `removeNodes` | S `[.25,1,0,.25]`, count 1 |
| 6 | 43 | `apply` | S `[.5,1,0,.25]`, count 1 |
| 7 | 55 | `apply` | S `[.75,1,0,.25]`, count 1 |
| 8 | 63 | `apply` | C `[1,0,1,.5]`, S `[.75,1,0,.25]`, count 2 |
| 9 | 71 | `clearScene` | Empty, count 0 |

The actual count is exactly nine. Clears occur only at records 1 and 9. There is no extra clear, apply, remove, or retain record inside the run. The initial hello and node inventory precede the manual sequence. The re-addition also records `command batch: 2 ops applied in one drain` at line 52. The final load has a fresh same-ID native node inventory at lines 72 through 75.

This establishes native ingress and batched distinct-color assignment, batched clear and set, storage of the zero-alpha sentinel, omitted-child retention, and child-color retention across a real transform without rewriting that child through the observing setter. The highlighted actual descendant then disappears from the native map on parent removal. Re-adding the same IDs does not resurrect either highlight. The child returns only on explicit reselection, while the omitted sentinel retains its value. Explicit same-ID document replacement clears the map.

The successful `parent-run.log` contains readiness and exactly seven ordered requests, followed by `Application finished.` Requests alone would not prove application. Here they agree with the native map and visual inventory. Full literal lines, timestamps, PID checks, and request receipts are in [native-recomputation.json](native-recomputation.json) and [request-recomputation.json](request-recomputation.json).

## Images and full video

I inspected all eight supplied PNGs individually and both contact sheets. Three ordinary cubes remain above the footer. The center child moves upward. Removing the parent leaves only the right sentinel. Re-addition restores the two cubes, and the last screen shows the completed sequence. Highlights do not visibly recolor or outline the cubes, as required for this state-only foundation.

I read `check-images.dart` and independently decoded all eight 402 by 874 PNGs. Its loop covers RGB in `[0,100,402,650]`, excluding the footer. Every recomputed field matches `parent-image-comparison.json`.

| Capture | Changed RGB pixels against ready |
| --- | --- |
| Ready | 0 |
| Assigned | 0 |
| Patched | 0 |
| Moved | 5134 |
| Removed | 13230 |
| Re-added | 0 |
| Selected again | 0 |
| Reloaded | 0 |

These are encoded screenshot observations. They do not measure output alpha, outline rendering, latency, or performance. [image-recomputation.json](image-recomputation.json) includes the independently reproduced blue-pixel inventory as well.

The raw video's verified duration is 47.446667 seconds. An offline full sequential decode reaches all 3103 encoded frames and exits 0 with strict decoder error handling. Recreating the sequential three-second, 4 by 4 contact sheet produces exactly the parent's PNG bytes, SHA256 `819f5020e403fb2771f34943f74608084e80be53e6baeb422d22a70ecfdc61ed`. I inspected that regenerated sheet. Receipts are [video-probe.json](video-probe.json), [video-source-timebase-decode.log](video-source-timebase-decode.log), [video-cleanup-commands.json](video-cleanup-commands.json), and [reviewer-video-contact.png](reviewer-video-contact.png).

There is one reporting qualification. The actual path is `parent-runtime.md:37`, which says the video decodes "without FFmpeg errors". The evidence contract is accurate reporting of the decode log. The supplied `parent-video-decode.log` contains 267 null-output muxer DTS warning lines plus repeated-message notices. It is not clean FFmpeg output. The smallest in-scope correction is to say that full decode succeeds with output timestamp warnings, with no timing or performance inference. This is not a native-state defect or a blocking video-integrity gap. My first passthrough decode reproduced those warnings. A second full decode preserving the observed `1/600` source time base produces no error, invalid, or corruption diagnostic. The distinction is recorded in [supplied-video-log-classification.json](supplied-video-log-classification.json). Parent owns any wording correction.

One reviewer command used `-enc_time_base -1` from installed help and failed before decoding because this invocation rejected that value. I reran the underlying command directly, retained the failure receipt, and used the explicit observed source time base `1:600` for the successful full decode. This is a reviewer output-option failure, not an app or video failure.

## Supplied build and cleanup evidence

The initial parent native build failed before launch. `parent-run-missing-pod-source.log:5` says `Swift Compiler Error (Xcode): Cannot find 'SelectionOutline' in scope`. `parent-pod-install.log` then records `Generating Pods project` and completed installation. The podspec includes `Classes/**/*.swift`. I also read the current ignored Pods project, which includes `SelectionOutline.swift` as both a file reference and a source build entry. The stale generated source membership is the parent's diagnosis, consistent with these receipts. No pre-regeneration project copy is supplied for direct comparison.

The retry log records the Xcode build completing, application launch, all seven requests, and application completion. The first build failure is not a runtime failure. The unchanged Podfile.lock hash and the other five lock or registrant hashes match both the supplied manifests and my live read-only parent check. This is generated Pods project regeneration, with no evidence of a dependency pin or production generated-source change. The existing CocoaPods custom-configuration warning remains.

I read the supplied fixture tests, worker regression results, analysis, typecheck, and generic simulator build receipts. The parent fixture log ends `+3: All tests passed!`. Worker package and example logs end `+84` and `+50`, respectively. Analysis reports no issues. The supplied Swift typecheck records exit 0 for all 12 files. The generic simulator build log ends `BUILD SUCCEEDED` and its receipt records exit 0. The prior production foundation's parent log still records 45 passing tests. None of these commands was rerun here, and none replaces the actual native records. The worker's earlier missing `FLUTTER_ROOT` build attempt is retained separately from its successful generic build retry.

I inspected the supplied reversal and cleanup proof, then checked the parent's current files read-only at `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb`. All 52 production hashes still equal the accepted source-review snapshot. All six lock or registrant hashes match. Both new diagnostic files are absent, and `git diff --check` passes. Together with exact offline reverse replay, this verifies that the owned overlay is removed and the production snapshot remains unchanged after its review. No diagnostic logger, query, or fixture from this patch remains in those production files.

`parent-run.log` supports application completion. The parent reports stopping recording first, then the application, logger, and simulator. The packet does not contain an independent process inventory or simulator shutdown receipt. I therefore retain logger termination, simulator shutdown, and the exact stop ordering as parent-reported. I performed no process or device inspection. Host teardown is not proved by shutdown or by this sequence.

The parent's generated Pods project and build directory remain ignored and retained. I did not remove or regenerate them. Cleanup receipts are [parent-live-production52-check.log](parent-live-production52-check.log), [parent-live-locks6-check.log](parent-live-locks6-check.log), [parent-live-diff-check.log](parent-live-diff-check.log), and [video-cleanup-verification.json](video-cleanup-verification.json).

## Limits and retained artifacts

Component and resource retention, streamed reparenting, genuinely deferred replay, host teardown, Android, outline rendering, and performance remain NOT_RUN. Independent device execution is NOT_RUN. Whole U3 and Track E readiness are not established. Parent owns integration and all native follow-up.

I read applicable AGENTS, Poteto native Codex instructions, the adopted synthesis, the accepted source review, the packet handoff and runtime report, the local DartNative guide, package README scheduling guidance, and the verification guide. No applicable CONTEXT.md was found. The vendor `dartnative/docs/plugin_development.md` path named in AGENTS is absent in this checkout. No vendor API change or new renderer work was proposed. The dated program overview is context, not current native proof.

Prove It Works guided the independent hash, literal, replay, image, and decode checks. Unslop guided the report wording. Throughput checkpoint is n/a for this read-only investigation. The no-comments and how skills request child work, but the explicit no-children and no-duplicate-audit scope takes precedence. No children or comment edits occurred.

Retained artifacts are the authorized imported source54 in the isolated worktree and this report directory with verification scripts, logs, JSON receipts, and the regenerated contact sheet. Replay scratch is removed. No builds, tests, device actions, dependency setup, commits, pushes, external changes, or parent-source writes occurred. The review worktree's final imported hashes, locks, and status are checked in the final receipts. No provider-diversity claim is made.
