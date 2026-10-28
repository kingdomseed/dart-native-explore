PASS for the bounded E9/W34 throwaway host-loopback authored-text reload prototype and its supplied iOS evidence. No scoped reachable P1/P2 defect or meaningful evidence overclaim remains. This verdict does not accept whole E9 or complete Track E.

Independent tests, analysis, builds, app execution, and device execution are NOT_RUN. I inspected parent native evidence and independently recomputed archive hashes, patch replay, authored-save deltas, image comparisons, log counts, and strict video decoding offline. No devices were queried. No host server, children, PR actions, or external writes were used. The parent checkout remained read-only.

The review checkout is `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4` at base `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. The only checkout mutation was the authorized accepted52 import followed by the final candidate overlay. Imported source remains for review.

**Source and replay evidence.**

[Archive hashes](archive-hashes.json) match every supplied exact digest, including the accepted production archive, initial blank-view archive, observed archive, cleaned candidate, full candidate patch, and cleanup patch. The tar files also contain AppleDouble metadata entries. The import excludes those entries and verifies the 52 or 57 actual source paths against the manifests.

[Import preservation](import-preservation.json) verifies all 57 candidate hashes, exactly the five requested additions relative to accepted52, unchanged accepted52 content, and all six lock/registrant hashes. All 1,876 tracked files outside the accepted overlay remain unchanged. The restored parent's accepted52 and six lock/registrant hashes also match through read-only checks, and its five probe additions are absent.

[Independent replay](replay.log) verifies forward and reverse application against temporary copies of accepted52. Forward produces exactly candidate57. Reverse restores exactly accepted52 and removes all five additions. Cleanup replay in both directions proves that the observed archive plus the supplied cleanup patch equals candidate57. The temporary replay directory was removed.

[Initial-to-observed delta](initial-to-observed.diff) contains exactly `Column.crossAxisAlignment: CrossAxisAlignment.stretch`. [Observed-to-candidate delta](observed-to-candidate.diff) contains the host comment deletion and test ownership/comment cleanup only. The receiver, entrypoint, fixture, and every host statement are unchanged from the successful native run. Reuse of that native evidence is justified for runtime behavior. No repeat native execution of the cleaned candidate is claimed.

**Reachable source path and ownership.**

The reviewed data flow is one explicit authored file, complete WebSocket text, parser output, then the existing controller load/diff path.

- [Host](</Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4/dart3d/example/tool/w34_reload_host.dart:23>) binds IPv4 loopback with a caller-supplied port. It canonicalizes the source parent, watches that directory nonrecursively, and rereads only the explicit file for matching source, rename-destination, or coalesced parent events. It sends full text and suppresses identical text. It owns file/socket lifecycle and does not parse or own scene state. The installed Dart SDK's watcher documentation explicitly describes coalesced events and split move events.
- [Receiver](</Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4/dart3d/example/lib/w34_reload_probe.dart:16>) has one connection attempt on the real entrypoint path. Decoder catches surround `readFsceneLogged` only. Load and diff application remain outside those catches. After each accepted input, the next diff reads `controller.document`; no second retained scene exists. Transport errors and closure require an explicit restart. Malformed authored input leaves the controller unchanged and later saves can recover. A temporary missing source during rename is logged and retried only by another actual filesystem event.
- [Entrypoint](</Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4/dart3d/example/lib/w34_reload_main.dart:26>) retains one controller and one view. It requires an explicit reload URL and stops the probe before disposing its controller. `stop()` sets its lifetime flag synchronously before its first await, so already queued callbacks return before reaching the disposed controller. No new behavior enters the normal application entrypoint.
- [Controller](</Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4/dart3d/lib/src/scene_controller.dart:516>) owns the accepted document and sends existing command batches. Source inspection of iOS `applyUpsertResource` and `applyUpdateStage` confirms existing renderer ownership of material/environment realization. This review does not reopen accepted U2/U3/U4 behavior.
- [Tests](</Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4/dart3d/example/test/w34_reload_transport_test.dart:251>) retain the actual disposed controller. The pending-handshake test checks that same controller's document at line 416. Shared teardown uses nullable disposal ownership instead of replacing either target with an unused controller. The tests exercise actual file/watch/socket/controller paths. They were read, not rerun.

No polling, reconnect, native protocol extension, transport envelope, revision scheme, or duplicate scene owner appears in the five-file candidate. Multiple `connect()` calls have no entrypoint caller and do not justify a new state machine. The binary-message case uses a synthetic test server; the reviewed host always sends text. These do not establish scoped defects or broader native lifecycle coverage.

**Saved iOS evidence.**

The supplied `parent-first-run.log` and `parent-first-host.log` show connection and a submitted initial load. `parent-initial-empty.png` is visibly blank, and the first native log contains only its header. This was a failed first rendering attempt, not a native reload pass.

The corrected run visibly renders the cube after the sole layout change above. `SceneView` documents a definite layout slot in `lib/src/scene_view.dart`. No prior native width was measured. The packet supports this probe correction, not a general framework root-cause claim.

[Log counts](log-counts.json) independently confirm one host connection, five sends, one receiver connection, one `loadDocument`, three `applyDiff` requests, and one decode error. The native log contains only Runner PID 41344 and one protocol hello. The run ends `Application finished.` No restart or hot-reload event appears between saves in the saved run. Source, saved logs, authored snapshots, and continuous visual evidence support the single mounted scene sequence. Individual operation names are receiver submission diagnostics, not independent native acknowledgements of every operation.

[Evidence recomputation](evidence-recomputation.json) verifies that the material snapshot changes only base color, the environment snapshot changes only exposure from 1 to 0.2 after that color edit, the malformed snapshot is literally `{`, and restoration is byte-identical to the original fixture. The saved external-write logs identify the in-place saves.

I inspected the blank first capture and all five successful-run PNGs. The cube changes red, blue, darker blue, retained darker blue, then recovered red. The viewport and cube placement stay fixed. [Independent image comparison](independent-image-comparison.json) matches the parent's JSON exactly using an independent ffmpeg RGB decoder. The crop is x in [0,402) and y in [100,700). The 9 by 9 sample begins at x 180, y 340.

| Saved state | Mean encoded RGB | Changed crop pixels against initial |
| --- | --- | --- |
| Initial red | [172, 68, 47] | 0 |
| Material blue | [47, 68, 172] | 82467 |
| Exposure 0.2 | [17, 28, 82] | 82467 |
| Malformed retained | [17, 28, 82] | 82467 |
| Recovered red | [172, 68, 47] | 0 |

Malformed versus last valid has zero changed crop pixels. Recovery versus initial also has zero. These are encoded screenshot comparisons, with no photometry, alpha, or latency claim.

The full video SHA256 matches `0bece5e937b718a05d9473ab95e4d00e26dea7a7680e8989311efe792c3fda7a`. [Independent strict decode](video-strict-decode.log) succeeds for all 2,109 frames. [Video metadata](video-probe.json) gives duration 33.795 seconds and source time base 1/600. I inspected `parent-video-contact.png` and `parent-video-final.png`. The sequential contact sheet stops before recovery and cannot prove it alone. The supplied final frame and the independently extracted [last decoded frame](independent-video-final.png) both show recovered red with the restoration diff footer. The independent extraction is a separate encoded PNG and is not claimed byte-identical to the supplied PNG.

All 65 entries in `parent-evidence-sha256.txt` match independently. Per-file results are in [parent evidence hashes](parent-evidence-hashes.json).

**Test and cleanup claims.**

The saved `parent-focused-tests.log` reports 13 passing focused tests on observed source. The saved `parent-cleanup-focused-tests.log` reports 13 passing tests after the final cleanup. The corresponding four-item and two-item analyses are clean. These are inspected parent results, not independent executions.

The worker's 60-example-test run predates the final host error-string clarification. Its 61-package-test result and generic iOS build are supporting historical evidence. None is promoted to an independent or complete exact-candidate gate.

The saved cleanup, restored-source, closeout-source, listener-after, and booted-after logs support the parent's recorded shutdown and restoration. `parent-listener-after.log` is empty, and the saved boot inventory lists no booted device. The parent reports the watcher, app, and logger stopped and the normal target restored without a reload URL. Those process/device/configuration observations were not freshly queried in this review. Only parent source52, lock hashes, and probe absence were freshly rechecked offline.

**Remaining gates.**

Android transport and rendering are NOT_RUN. A142 remains reserved. External asset and payload-byte refresh, production reload API and lifecycle, debug channels and wireframe, broader cancellation and teardown, full T1 and T2, operator T4, and latency remain open. This packet demonstrates a bounded iOS authored-text reload capability only. The previously failed iOS direct file watch is not revived or accepted. E9's larger W34 scope and the rest of Track E retain their existing gates.

Current gate references are `docs/program-v2.md` lines 200-244 and its E9 row at line 411. W34 scope remains in `docs/full-engine-program.md` at line 1126. Its old ten-lane execution procedure is superseded by program-v2. This review changes neither scope nor gate status.

**Review constraints and retained artifacts.**

I read the supplied and checkout AGENTS instructions, program goal and gates, package/example READMEs, local DartNative guide, vendor widget documentation, and installed Dart SDK watcher/WebSocket definitions. No applicable CONTEXT.md was found. Poteto-mode and its native Codex instructions were read. Boundary Discipline kept findings tied to parser and controller ownership. Prove It Works required direct archive, pixel, and video checks instead of accepting the handoff's verdict. The user-required self-review and offline restrictions superseded skill delegation and CodeRabbit execution. The completed no-comments child audit was not repeated.

Retained items are the imported accepted52 plus candidate57 source and this review directory's report, two verification scripts, JSON receipts, replay log, source-boundary diffs, strict-decode log, independently extracted final frame, final preservation receipt, and receipt hash manifest. No replay scratch, server, or task-created process remains.
