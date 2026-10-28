# External sidecar reload on iOS

PASS for the fixed RGBA8 image fixture on the approved iPhone17Pro simulator,
2026-10-27. This is the first native proof of the selected dev reload library.
The authored scene stayed byte-identical while external sidecar pixels changed.
The mounted quad updated, malformed sidecar bytes retained the last valid image,
and a later valid save restored the initial image without restarting the app.
Independent source/evidence review passed for this bounded integration and
fixture. The reviewer verified the 58-file source, replay, saved inputs,
image comparisons and all 1767 video frames offline. See
[the review report](review/report.md). Independent tests, builds and device
execution were NOT_RUN. This does not complete E9.

## Source and actual public path

The worker's six-file patch and artifact hashes were checked before integration.
Parent reproduced its 28 integration tests, added one direct invalid-UTF8 file
recovery test, and applied the accepted comment-audit ownership correction.
All 29 integration tests and both package analyses pass after that correction.
The worker's 86 package and 53 example regressions are prior worker execution,
not a claim of a full current-tree T1 run.

Runtime source58 archive SHA256 is
`6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706`.
The complete six-file parent patch SHA256 is
`05353c6b6f383a2dc4264dbcef0fc25d8d2609a20047390d257458f3dea3bbea`.
The source manifest matches after the run. Accepted52 and six lock/registrant
hashes remain unchanged. The six production additions remain integrated.

The explicit `dev_reload_main.dart` caller imports `package:dart3d/dev_reload.dart`.
The Mac host watches the authored parent and sends raw text over `/scene`.
The app reads `payloadSource`, fetches the sidecar through same-port `/payload`,
validates and attaches its bytes to a detached candidate, then calls the existing
controller load/diff path. No native file, permission, protocol or ordinary-main
change was made. The simulator boot load was allowed to settle before building.
The actual `dn run` Xcode build succeeded; its build duration is not reload latency.

## Fixed input and visible sequence

The authored file SHA256 was the same in all four saved snapshots:
`5261ff0059f72616c8dc0e69bc97d965a2e004ff7e3fda5f45325ed32b5ca611`.
The file is 2397 UTF8 characters. Its existing `payloadSource` is `pixels.fsceneb`.
Image LocalId(0x7734,0), image/rgba8/2x2/length16, path, material, camera and
authored document IDs stayed fixed. Only sidecar content was edited.

| Save | Sidecar bytes | App observation | Visible state |
| --- | ---: | --- | --- |
| Initial A | 2472 | `loadDocument` | Red/green image |
| B | 2472 | `upsertPayload, upsertResource, upsertResource, updateNode` | Blue/yellow image |
| Malformed | 3 | Input error, truncated container, no apply request | Previous blue/yellow retained |
| Restore A | 2472 | Same four incremental operations | Initial red/green restored |

A sidecar SHA256 is
`82facd2365dffe257b04452231a4c6fbea3605182d9511f8df6ed43dfb4c8f81`.
B is `c7bbe700d89ba4fac131fb0031460bed953b2be4a918b7ca093af1ea83f498a4`.
The malformed file is the literal bytes `[0,1,2]`. Recovered A matches initial
sidecar bytes exactly. Saved inputs and save logs remain in the private pickup.

The host log records one connection, four full-text sends and four HTTP responses
of the sizes above. The app log records one connection, one load, two applyDiff
requests and one input rejection. Native subsystem logs use Runner PID7464 and
one protocol hello. No hot reload or app restart occurred between saves.
Operation names are controller submission diagnostics, not native acknowledgments
of each individual operation. Native pixel changes supply the visible proof.

The parent inspected all four 402x874 captures. The quad fills the viewport width;
its left/right edges are clipped by the fixed camera. The same framing is used
throughout, and the color regions remain visible above the status footer.

## Pixel and video receipts

`check-evidence.dart` decodes saved PNGs to RGB with ffmpeg. In scene crop
`[0,100,402,740]`, B differs from A at 184116 pixels. Malformed versus B has zero
changed pixels. Recovered A versus initial A also has zero. The crop excludes
the changing clock and status footer. The 9x9 samples starting at (40,200) and
(350,200) are recorded in `image-comparison.json`.

| State | Left encoded RGB | Right encoded RGB |
| --- | --- | --- |
| A | [253,30,20] | [20,237,70] |
| B | [20,80,253] | [253,223,20] |
| Malformed retained | [20,80,253] | [253,223,20] |
| Recovered A | [253,30,20] | [20,237,70] |

These are encoded screenshot observations. They are not raw texture calibration,
alpha measurements, photometry, or latency/performance results.

The recorded video is 29.161667s at source timebase 1/600. Strict decoding succeeds
for all 1767 frames. SHA256:
`0693e2aeb703caf8a6eb7d3e3d960ddc6dd8e119be189cea9e6c5550bf0d1512`.
Recording startup had not completed before the B edit, so its first decoded
frame is already B. Do not claim this video contains the initial A-to-B change.
The matched initial/B PNGs and input/command receipts establish that change.
The continuous clip covers B, malformed-input retention, and restoration to A.
The parent inspected the five-second sequential contact sheet, first frame and
final frame. The sheet has six sampled cells plus padding; black unused cells
are tile padding, not black native frames. The final frame shows restored A.

## Integration correction and failed test wrapper

The initial extra invalid-UTF8 test used a custom async zone and timed out.
This is a failed test wrapper, not a production red baseline. Installed SDK
`file_impl.dart:699–715` wraps UTF8 failure in FileSystemException, already caught
by the host. The direct real-file test passes without changing host behavior.
Its one retained deterministic temp fixture was identified by both file hashes
and the failed test interval, then removed. The final temp inventory is empty.

No-comments accepted three deletions, zero restorations or reruns, and one
implementation ownership correction. Reception now owns its handled nullable
candidate future; stop joins it without separately swallowing the same input
FormatException. Unexpected application errors still propagate. The agreed
active-preparation drain remains. No new public API or transport was added.
The sketch and parent integration report preserve that boundary.

## Cleanup and remaining work

Recording stopped before app quit. App and host sessions returned exit0, and
`run.log` ends `Application finished`. Peer close shut down the host. Port49334
has no listener in the saved lsof check. The logger was stopped and the simulator
shut down. Fresh inventory lists no booted iOS device and no open panel.
Normal main generated configuration is restored with no reload URL; other defines
are undisclosed. Source58 and six locks match, and the external fixture directory
is removed after comparison with the saved recovery. All kept inputs, receipts,
source archives and raw video are deliberate evidence. Ignored build outputs stay.
These are parent observations inspected by the independent reviewer. The
reviewer did not repeat device, process or listener queries.

A142 received no targeted query, launch or input and remains reserved. Android,
other asset categories, native pending-read cancellation, broader lifecycle,
debug channels/wireframe, full T1/T2, operator T4 and write-to-first-frame latency
remain open. Existing package/controller tests prove their own level only.
Raw video and full archives stay in private pickup until a future media release;
small PNGs/logs/JSON/source manifests and scripts are copied to repo evidence.
