# iOS highlight-state native verification

PASS for the basic state sequence on the approved iPhone 17 Pro simulator,
2026-10-27. The parent built and drove the real DartNative application. Its
public controller calls reached the native state owner and produced exactly
the nine ordered records specified before the run. No production correction
was needed. The five-file diagnostic overlay has been removed.

## Observed behavior

`parent-native-comparison.json` compares the complete native log records with
literal expectations. It reports nine actual records, nine expected records,
an exact ordered match and no extra records. The log is unredacted development
output from the existing scene subsystem, for Runner PID90007.

| Action | Actual native state |
| --- | --- |
| Initial scene load | Empty map |
| Assign two colors in one batch | Parent and child retain distinct RGBA values |
| Clear parent and set sentinel | Child retained; zero-alpha sentinel stored |
| Move child and patch sentinel only | Child's untouched color retained |
| Remove parent | Highlighted actual child removed; sentinel retained |
| Patch sentinel after removal | Sentinel only |
| Re-add the same parent/child IDs and patch sentinel only | Sentinel only; removed IDs remain unselected |
| Explicitly select the child | Child returns with new RGBA; sentinel retained |
| Load a fresh document reusing the IDs | Empty map |

The parent inspected all eight phone captures and the sequentially decoded
video contact sheet. Three cubes fit above the footer, the child moves, subtree
removal leaves the sentinel, and the two cubes reappear after re-addition.
`parent-image-comparison.json` checks the RGB scene crop `[0,100,402,650]`.
Assignment, patch, re-addition, explicit reselection and reload have zero
changed pixels against the initial scene. Movement changes 5134 pixels;
removal changes 13230. These are encoded screenshot observations, not a
calibrated visual metric. This foundation has no outline rendering.

`parent-controls.mp4` fully decodes; duration47.446667s,
SHA-256 `975cbb79c51646395a9b793f0f1e7ed4c10f9fe7a1036c08a0bbd43a715e178a`.
The recording is retained in the private pickup directory; its sequential
three-second contact sheet is copied into the repository evidence directory.
The original null-output FFmpeg command emitted267 non-monotonic DTS timestamp
warnings plus repeated-message notices. Its log is not clean. The independent
reviewer decoded all3103 frames using the observed1/600 source time base with
no corruption diagnostic. No latency, frame-rate or performance claim is made.

## Exact source and execution

The reviewed production snapshot is source52 archive646f5d26. The temporary
five-file diagnostic patch has SHA-256
`d6e2277926387e2e3e6f084bbdf0c8ab3a0efe8785eed86f7ce09da9d76d8e2a`.
It adds a separate showcase route and logs the actual private native map after
existing operations. It changes no selection decisions. The reconstructed
observed source54 archive has SHA-256
`981bfe5474e65993736fc927b9879b7029a354b3abebccdda9fcbc5d079edb5a`.
All five observed source hashes and49 unowned snapshot paths match the retained
manifests. The archive is reconstructed from the exact checked baseline and
diagnostic patch; it is not a different source revision.

The parent reran the three fixture tests successfully. The initial application
build failed with `Cannot find 'SelectionOutline' in scope`; the generated Pods
project lacked the newly added Swift source despite the podspec glob matching
it. `pod install` added its source reference. The retried `dn run` built and
launched successfully. The Podfile lock hash stayed unchanged. The failed
build, pod-install receipt, successful run and native log are all retained.
The existing CocoaPods custom-configuration warning remains; no project setting
or dependency pin was changed.

Run used `/Users/jasonholt/zero/bin/dn run -d
C24F3C6D-A3A9-4FB7-978E-36E67EF55354 --no-pub
--dart-define=DART3D_MODEL=u3-highlight-state
--dart-define=DART3D_QUALITY=high` from the writer's example package.
The high-quality define avoids the separately recorded unsupported2xMSAA issue.

## Cleanup and limits

Recording stopped before the application; `parent-run.log` ends `Application
finished`. The parent stopped its filtered logger and shut down the simulator.
A fresh inventory contained no booted simulators. Reverse patch application
restored every production52 source hash and all six recorded lock/registrant
hashes. Both temporary fixture files are absent. `git diff --check` passed.
No diagnostic query, getter, logging or fixture remains in production source.
Generated Pods project/build outputs remain ignored; the evidence is retained.

This proves basic iOS ingress, batch set/clear, omitted-entry retention,
transform retention, actual descendant removal, same-ID re-addition policy and
explicit scene replacement. Component/resource retention, streamed reparenting,
genuinely deferred replay, host teardown, Android, outline rendering and
performance remain NOT_RUN. Source review of the foundation already passed;
independent review of this runtime packet passed without scoped P1/P2 findings.
It independently recomputed all54 hashes, all nine literal records, eight PNG
comparisons, full video decode and production52 cleanup. The timestamp wording
above is corrected from the first report. Logger/simulator shutdown remains
parent-reported; the reviewer used no device. Whole U3/Track E and the remaining
Android tablet/operator gates remain open.
