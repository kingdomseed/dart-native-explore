# Host-owned reload: iOS capability experiment

PASS for this single-file prototype on the approved iPhone17Pro simulator,
2026-10-27. The Mac watched an explicit authored file and delivered its complete
text over one loopback WebSocket. The real app loaded the initial scene, applied
incremental material and exposure changes, retained the last valid scene on
malformed JSON, and recovered on a valid save. All five temporary source files
are removed; accepted production52 is restored. This does not complete E9.

## Actual run and visible states

The host bound `127.0.0.1:49334`, reported one connection and five sends. The
app reported one connection, one `loadDocument`, three `applyDiff` requests and
one decode error. Native logs use Runner PID41344 throughout, with one protocol
hello. No second document-load request was submitted. Existing native resource
and node owners applied the changes; no native protocol was added.

| Save | Observed operations | Visible result; front-face RGB sample |
| --- | --- | --- |
| Initial | `loadDocument` | Red cube; `[172,68,47]` |
| Material only | `upsertResource, updateNode` | Blue cube; `[47,68,172]` |
| Exposure only,1→0.2 | `upsertResource, updateStage` | Darker blue; `[17,28,82]` |
| Malformed JSON `{` | Decode error, no apply request | Prior darker blue retained |
| Restore exact original text | Two resources, node, stage | Original red restored |

The parent inspected all five matched phone captures. The camera, IDs and
viewport stay fixed; authored saves change only the specified material or
environment values. The malformed-save scene crop `[0,100,402,700]` matches
the prior valid frame exactly, with zero changed RGB pixels. Recovery matches
the initial scene crop exactly. The material and exposure frames each differ
from initial at82467 scene pixels. The9x9 sample at `[180,340]` above is an
encoded screenshot observation, not photometry or an alpha measurement.
`check-images.dart` and `parent-image-comparison.json` reproduce these values.

The recording fully decodes2109 frames with strict error detection and the
observed1/600 source time base. Duration33.795s; SHA-256
`0bece5e937b718a05d9473ab95e4d00e26dea7a7680e8989311efe792c3fda7a`.
The sequential three-second contact sheet samples the sequence before recovery;
the separately inspected final video frame shows recovered red. The full clip
and final frame are retained. No first-frame latency or performance inference
is made from host/send/request timestamps or recording duration.

## Source and corrected probe layout

The worker's five-file patch passed parent hash verification. The parent added
operation-name logging to the receiver's existing applyDiff result. The first
app connected and received the initial document, but the scene area was blank.
The failed capture, run/host/native logs and source archive remain under
`parent-first-*` and `parent-initial-empty.png`.

The parent then added `crossAxisAlignment: CrossAxisAlignment.stretch` to the
temporary entrypoint's Column. The SceneView has no intrinsic width and its
documented contract requires a definite slot. With this one layout change,
the rerun mounted the native view and showed the red cube. No previous native
width was measured; the recorded result establishes the correction in this
probe, not a general framework layout diagnosis. Host, receiver and native
scene decisions were unchanged. No file saves preceded the visible initial
scene in the successful run.

Final observed source57 archive SHA-256:
`eb7239a2c3d8366d5d0baee9797ba84cd82d40750798bf9e90d5ece5b49d43e1`.
Final five-new-file parent patch SHA-256:
`66f69e772c63f0c175a78da134fb69af201bfb5e64c51ab3c07aca32862de37f`.
The initial empty-view archive is `parent-first-source.tgz`, SHA-256
`c6377d4960ad093f593ee63f91fb4f548c5724f1c8920fa9e673e402c9025723`.
Forward/reverse replay reproduces final57 and restores production52. All52
accepted source files and six lock/registrant hashes remain unchanged.

Parent13 focused real-file/socket/controller tests and analysis passed. The
worker's13 focused,60 example,61 package checks and generic build are supplied
evidence; the60-test run predates a host error-message clarification, explicitly
recorded in its handoff. Parent native execution uses final source57 above.
The first successful native build emitted a nonfatal device-discovery warning
for `sdk gphone64 arm64`; no Android target was launched or driven. The rerun
build succeeded and `parent-run.log` ends `Application finished`.

## Post-run test and comment cleanup

The read-only no-comments audit found two misleading comments and a real test
ownership flaw: two lifecycle tests replaced an already disposed controller
with an unused new controller, weakening later assertions. The parent removed
both comments and gave shared teardown an explicit nullable controller owner.
The two tests now retain and inspect the actual disposed target. All13 focused
tests and targeted analysis pass after this correction.

The observed source57 archive above remains immutable. Cleaned candidate57
archive SHA-256 is
`e7f294f5668e3f51eeb03f1180260405bf60cd0d767d6a8a97022ebeb8ab56cf`;
its full probe patch is
`9817152232e53f26e5da3a06af069a4f6ce1b41889c8dc02fe9b50eb88263c79`.
`post-run-cleanup.patch`, SHA-256
`118a2b3d977d24730a44d7d77a6db39f7c8dbf2786b668960fcfbcf79f1409c9`,
changes exactly the host comment and the test file. The receiver, entrypoint,
fixture and all host statements are byte-identical to the native run. These
test/comment-only edits cannot affect that recorded native sequence; no repeat
device run is claimed. Candidate forward/reverse replay passes. The candidate
probe was then removed from the parent and production52 checked again.

## Cleanup and remaining gates

Recording stopped before the app. The app's peer close ended the host process;
the parent's host session returned exit0. Its terminal `error peer closed;
restart required` is the expected one-consumer experiment shutdown message.
`parent-listener-after.log` is empty and lsof returned1: no process held port49334.
The logger was stopped, and the simulator was shut down; fresh boot inventory
is retained. These are parent observations, not independent device review.

The exact final patch was reversed. All five additions and the empty
task-created fixture directory are absent. Normal-main generated build
configuration was restored, with no reload URL; other defines are undisclosed.
All52 production and six lock/registrant hashes match, and diff check passes.
`parent-cleanup.log` records the checks. Evidence, authored save snapshots,
archives and ignored build/package outputs are retained. No host process or
watcher remains. No A142-targeted query, launch or input occurred; it remains
reserved for Jason.

Independent source/evidence review passed for this bounded prototype. The
reviewer verified the source archives, forward/reverse replay, all five image
comparisons, and all 2,109 video frames offline. The report and receipts are
in [review/report.md](review/report.md). Independent tests, builds and device
execution were NOT_RUN. This review does not complete E9.

Android transport/backend runs,
external asset/payload-byte refresh, production reload API/lifecycle, debug
channels/wireframe, full device smoke, operator review and latency remain open.
Device cancellation/teardown edge cases were not exercised beyond observed
peer disconnect; the host integration tests are a separate evidence level.
The raw video stays in the private pickup until a future PR's media release;
small PNGs, logs, source hashes and receipts are copied into repository evidence.
