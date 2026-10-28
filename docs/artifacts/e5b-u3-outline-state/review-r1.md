# U3 highlight state integration review

PASS. No scoped, reachable P1 or P2 defect found in the six-file highlight state, transport, and lifecycle integration.

This is an independent Codex source review of the supplied snapshot. Native dispatch, native lifecycle, rendering, and performance remain NOT_RUN. The foundation does not draw outlines. This verdict does not establish whole-U3 or Track E completion, provider diversity, or production mask capability.

## Reviewed artifact

The app-prepared review worktree is `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-e5f5b3e7`. It was clean before import and remains at HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`.

I independently verified these supplied SHA256 values:

| Artifact | SHA256 |
| --- | --- |
| `parent-source.tgz` | `646f5d269a78020fb588ea420fb2783ea9d5a998e6b8019fd8885ad365726f2d` |
| `imported-current49.tgz` | `587e6d1a99b8a563b453d9fb0cb81dfd091ef847dafbdb29db758a6dbced0495` |
| `correction.patch` | `8f32a4b74d9d8a1fdc96f0032a0893490f859ce13f826c188b0ce3bc3f9a51a7` |

All 52 imported files match `parent-source-sha256.txt`. The baseline contains exactly the 49 paths in `imported49-sha256.txt`. Applying the correction reproduces all 52 final hashes. Reversing it reproduces all 49 baseline hashes and leaves no extra source files. The correction adds lines in exactly the six authorized paths and deletes no baseline lines.

All 46 unowned snapshot paths, 1,922 unowned baseline files, and six recorded locks or registrant files match the supplied manifests. The 52 source hashes still match after review. `replay-verification.json` and the individual check logs record these reviewer-executed checks.

An initial baseline check used `current49-sha256.txt`, which describes the integrated versions of three existing files. That check failed on those three files. Checking the baseline against `imported49-sha256.txt` passes all 49 paths. The initial log is retained as `baseline-wrong-manifest-check.log`. This was a reviewer setup mistake, not a source defect.

## Contract and production paths

Line references below are relative to the review worktree. These conclusions come from reading the imported implementation and its existing callers. They are source inferences, not native execution results.

| Contract | Inspected public or production path and result |
| --- | --- |
| One public batched facade, copied scalars, no retained Dart selection | `dart3d/lib/src/scene_controller.dart:390-425` builds token and scalar lists, encodes immediately through `D3Protocol.commandBytes`, and uses `_sendOrQueue`. The encoder at `dart3d/lib/src/protocol.dart:391-392` creates bytes synchronously. The facade neither reads node membership from `_document` nor writes an authored selection map. |
| Existing transport and drain ownership | `SceneViewElement.sendMutation` at `dart3d/lib/src/scene_view.dart:205-209` emits the existing plugin mutation. Android `Dart3dView.kt:2442-2476` queues it for `stepFrame`. iOS `Dart3dPlugin.swift:59-72` queues the host command, and `SceneViewHost.swift:1113-1123` drains work. Each patch reaches the owner as one drain item. |
| JSON is typed once at native ingress | Android `Dart3dView.kt:2997-3032` and iOS `SceneViewHost.swift:1564-1599` decode node IDs and four finite float components before passing immutable `Change` values to `SelectionOutline`. Null clears, missing live IDs reject non-null assignments, and empty or omitted updates do not disturb other entries. The internal modules do not repeat wire validation. |
| Native scene owns transient colors | `SelectionOutline.kt:3-26` owns its private `HashMap<Long, LinearRgba>`. `SelectionOutline.swift:3-32` owns its private dictionary keyed by `UInt64`. Both store scalar values, not nodes, renderables, materials, or authored records. |
| Explicit replacement clears | `loadDocument` at `scene_controller.dart:268-288` sends the existing load mutation. Android `Dart3dView.kt:2570-2592` and iOS `SceneViewHost.swift:1365-1387` clear selection before explicit realization. Generic installation does not clear it. |
| Actual removal clears every actual removed ID | Public `removeNode`, `applyCommands`, and `applyDiff` reach the existing native remove dispatch. Android `Dart3dView.kt:3034-3057` computes the doomed set from live parent chains. iOS `SceneViewHost.swift:1957-1979` computes it from the actual native subtree. Both remove those colors during live removal. Neither relies on Dart's incomplete streamed-node mirror. |
| Same-ID re-add starts unselected | The live removal hooks above clear the old ID. The existing add paths at Android `Dart3dView.kt:3820-3839` and iOS `SceneViewHost.swift:2120-2147` do not assign a highlight. Re-sending add on an already-live ID remains an update and retains selection. |
| Streamed members and surviving attachments | `scene_controller.dart:591-603` confirms streamed members can be absent from `_document`. The new facade still sends their IDs. `subtree_stream.dart:398-431` reparents attachments before removing streamed roots on unload. Native removal uses the resulting hierarchy, so an attachment moved out before removal retains its color, while actual removed streamed descendants lose theirs. |
| Component and resource replacement retains | Android component/resource updates use the existing surgical context and do not call the selection removal hooks. iOS `SceneViewHost.swift:2192-2237` updates fields or clears component state on the existing node. Searches for every `selectionOutline` reference show clears only at explicit load and host teardown, removal only at actual node removal, and final pruning only after deferred replay. |
| Genuinely deferred full realization preserves then prunes | Android `Dart3dView.kt:2636-2638` arms the existing deferred-claim path. At `5481-5487`, realization completes, then `replayStreamedSubtrees()` completes, then selection is retained against final `nodesById.keys`. iOS `SceneViewHost.swift:1127-1154` follows the same sequence through `replayAfterRealize()`. Both generic install paths replace node registries without clearing the selection owner. |
| Historical removal does not erase later live selection | Android replay holds `replayingJournal` across plain journal entries, subtree replay, nested subtree records, and the final views replay at `Dart3dView.kt:3294-3355`. The live removal hook at `3053` skips historical removal. iOS `SceneViewHost.swift:1874-1947` sets `replayingOps` on both replay branches, and the removal hook at `1977` uses it. A historical remove/re-add therefore does not clear a later live color. Final absent IDs are pruned after complete replay. |
| Historical private patches cannot overwrite later colors | Highlight operations are absent from Android `journalTopLevel` at `Dart3dView.kt:2920-2989` and iOS node-op journal eligibility at `SceneViewHost.swift:1548-1562`. A raw highlight nested inside a recorded subtree envelope reaches the dispatch again during replay, but Android `3001` and iOS `1565` return under the existing replay flag. This also prevents historical nested clears from removing later colors. |
| Authored serialization excludes highlights | The facade bypasses the document fold. `dart3d/lib/src/doc_layer.dart:28-43` also excludes the highlight op from authored operations. No schema or binary tag was added. |
| Controller dispose leaves the mounted view alone | `scene_controller.dart:1080-1098` drops controller references and event handlers without sending a native clear or dispose mutation. The new facade does not alter that path. |
| Native recreation drops state | Each new native host constructs a fresh selection owner. Android `Dart3dView.kt:2245-2380` releases the host and reaches `dropDocumentState`, which clears at `2406`. iOS `SceneViewHost.swift:940-942` clears at deinitialization. Actual framework release timing remains NOT_RUN. |
| Detached ordering remains the documented policy | `scene_controller.dart:1155-1193` preserves pending FIFO order. A queued explicit load suppresses implicit reconstruction. Otherwise, a retained document causes a load after pending commands flush, superseding their highlights. The new public docs at `397-402` describe this policy. No desired-state replay was added. |

## Current49 source preservation

The correction is exactly additive relative to the verified current49 archive. I inspected the insertion context as well as the complete six-file patch.

`SceneController.sendPayload` at `scene_controller.dart:384-387` still computes payload bytes before folding metadata into the document, then sends those same bytes. `applyCommands` still validates animation metadata before fold or dispatch at `447-496`. The highlight facade sits after `sendPayload` without replacing either implementation.

The unchanged iOS after-constraints callback at `SceneViewHost.swift:5706-5713` keeps this order:

1. `updateLods()`.
2. `updateCameraFacing()`.
3. `syncBlendCasters()`.
4. `bakedShadowCatcherRegistry.renderDirty(at:host:)`.
5. `renderDueTargets(at:)`.
6. `syncScreenSubviews()`.

Android rendering at `Dart3dView.kt:5835-5881` retains its existing due-target and screen-view scheduling. Highlight state is not wired into rendering in this unit. The unchanged sprite, animation, material, realizer, and render-target files match the supplied baseline manifests. I found no concrete regression introduced into the accepted sprite or U4 source.

## Evidence inspected

These are supplied execution results whose logs and checksums I inspected. I did not rerun tests, native compilation, or typechecking in this review.

| Evidence in the current packet | Recorded result and limit |
| --- | --- |
| `parent-focused-tests.log` | `+45: All tests passed!`. Covers parent facade, U4 payload, structural, and subtree checks. |
| `parent-analysis.log` | No issues found. |
| `focused-tests.log` and result JSON | `+139: All tests passed!`, exit 0. Includes the 13 new facade tests and adjacent U4, sprite, atlas, structural, subtree, extension, target, skin, morph, and material tests. |
| `example-regressions.log` and result JSON | `+90: All tests passed!`, exit 0. |
| `dart-analysis.log` and result JSON | No issues found, exit 0 for the changed facade and tests. |
| `android-compile.log` and result JSON | `:dart3d:compileReleaseKotlin` executes and the build ends `BUILD SUCCESSFUL`, exit 0. This is compilation evidence only. Existing warnings remain. |
| `ios-typecheck.log` and result JSON | Empty diagnostics log, exit 0. The recorded single compiler invocation includes all 12 plugin Swift files. This is typechecking evidence, not 12 separate native executions or an app link. |
| `android-regressions.log` | Line 35 records `Execution failed for task ':dart3d:generateReleaseUnitTestStubRFile'.` The following failure reports that immutable workspace contents have been modified. JVM tests did not execute. |
| `android-regressions-direct-retry.log` | Lines 31-33 record the same failing task and immutable workspace error on direct retry. This remains a blocked test attempt, not a JVM-test pass. |

The new tests exercise actual facade encoding through a `SceneViewElement` mutation sink. They establish emitted bytes, scalar copying, queue order, serialization exclusion, JSON rejection, and absence of a dispose-clear mutation. They do not execute native selection or prove mounted-view lifecycle behavior.

The worker evidence manifest verifies 36 artifacts. The parent evidence manifest verifies six more listed artifacts. I checked the logs themselves rather than accepting the handoff verdicts.

## Scope, simplicity, and remaining gates

The native map and typed patch are small and keep ownership in the chosen native scene layer. I found no scoped P1 or P2 caused by unnecessary abstraction, duplicated selection ownership, or internal defensive validation. No fix is requested.

Boundary Discipline guided the ingress review. I checked that raw JSON becomes typed changes before it reaches the state owner. Prove It Works guided the evidence review. I independently checked source hashes and replay, and kept source conclusions separate from supplied executions and native NOT_RUN gates.

The remaining Android capability gate still precedes production masks. Native dispatch, actual streamed removal and reparenting, same-ID re-add, deferred realization, component/resource retention, actual host disposal, rendering, and performance remain NOT_RUN. Parent integration and runtime verification remain parent-owned.

I read the supplied AGENTS, the package README, the local DartNative skill guide, Poteto native Codex instructions, the adopted synthesis, the original handoff, and the current parent checkpoint and handoff. No `CONTEXT.md` was found by the checkout file search. The vendor guide path `dartnative/docs/plugin_development.md` named by AGENTS is absent in this checkout. No vendor API change or hand-written replacement was proposed. The existing README describes the native drain scheduling used in this trace.

The no-comments skill requires a child audit. Your explicit no-children instruction takes precedence. I skipped that duplicate audit as requested and did not alter comments or suppressions.

## Retained files and replay

The imported 52 source files remain in the isolated review worktree. No source edits followed import. No parent source was written. No children, commits, pushes, external mutations, device actions, simulator boots, dependency setup, or cache changes occurred.

Retained setup artifacts are the imported worktree source and this requested report directory. The directory contains the report, verification script, artifact hashes, manifest check logs, patch path receipt, replay JSON, and before/after git status. The temporary unpacked replay directories were removed. No package-resolution or build outputs were generated by the review.

Reproduce the artifact checks from the review worktree root:

```sh
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart /private/tmp/dart3d-e5b-outline-state-review-20261027/r1/verify_snapshot.dart
```

Throughput checkpoint is n/a for this read-only investigation.
