# GPU command capture is unavailable through the CLI preflight

No GPU trace was captured. The existing outline failure remains unresolved.
The app was launched with `MTL_CAPTURE_ENABLED=1`, but Apple's installed
`gpucapture` did not discover the simulator process. No Set/Clear experiment or
additional rendering control was run in this attempt.

The [independent source/evidence investigation](independent-review/report.md)
reproduces both prior first-target failures and recommends observing executed
commands rather than another initial-value rewrite. Its report SHA256 is
`9988d687b100340c8887fdf44a049d179e10a0910604c955585e70b9c46edc92`.
All delivery hashes were verified before copying. That review does not supply
a new correction or GPU command observation.

## Capture readiness and the actual refusal

This Mac runs macOS 27.0.1 with `/usr/bin/gpucapture` and `/usr/bin/gpudebug`.
The installed man pages are retained. Apple's
[capture skill](https://github.com/apple/game-porting-toolkit/blob/main/game-porting-skills/skills/using-gpucapture/SKILL.md)
describes the source-free CLI route and its launch environment requirement.
The DartNative CLI's installed simulator launcher uses `simctl launch`, whose
help documents the `SIMCTL_CHILD_` environment prefix. No app source or plist
change was made to enable capture.

The parent launched the approved iPhone 17 Pro simulator and the unchanged
runtime70 with `SIMCTL_CHILD_MTL_CAPTURE_ENABLED=1`. The native build and launch
completed. PID88275's filtered process environment confirms
`MTL_CAPTURE_ENABLED=1` in [capture-readiness.json](baseline/capture-readiness.json).
The native log records creation of GPU Tools capture and telemetry services,
plus a warning about marking graphics memory with kernel error 0x8. No causal
conclusion follows from that warning.

`gpucapture list` reports `error: no capturable processes available`.
`gpucapture boundaries --pid 88275` reports `error: invalid PID 88275`.
`gpucapture --list-devices` lists only the local Mac, then reports
`Remote device browsing requires Xcode to be running`. The existing Xcode
process was running during this query. The CLI did not expose a simulator target
or selectable target queue. Exact outputs are in the baseline folder. CLI exit
status alone is not treated as success when its output reports an error.

The parent also inspected Xcode through background cua-driver observations.
Its off-screen main window returned no accessible controls and a gray image.
A separate existing dialog said the application could not launch because a
Developer App Certificate was not trusted. The project/run owning that dialog
was not established. It was not dismissed, and no certificate trust or security
setting was changed. These are parent UI observations in the tool transcript,
not a simulator capture refusal or an established cause of CLI discovery failure.

A read-only `vmmap` readiness query produced no output and used zero CPU for
75 seconds. The parent interrupted only its own query and retained exit -2.
The process-environment result remains valid and independently available.
No memory map, Metal command capture, LLDB attachment or GPU replay was obtained.

## What this attempt does establish

Only the initial Off target drew. It has the exact previous Off hash
`b330c9051c95b8c02c2acb8bbcac4443fd0e8fe1a9ddaf68de631ca8d4113388`,
6,695 transparent pixels and 217 opaque geometry pixels. See
[initial-off.json](initial-off.json) and the complete raw pair in baseline/raw/.
The log has one admitted target draw, zero highlight batches and zero target
technique-install events. No first-Set, second-Set, mask, contour or alpha-test
result is claimed under the capture environment.

The actual runtime70 packet in runtime-source/ has SHA256
`b9fbf45eafe20d36679354b1fb7833324ae203e1c1e665f075cb2398ec99e83c`.
Its file identities match the existing installation-control source. The packet
was repacked without executable changes. The full native log remains at the
hashed local path in [local-originals.json](local-originals.json). No .gputrace
or video was produced.

## Cleanup and next permission boundary

Accepted final66 and all 5,166 pre-existing files are restored. The four own
probe additions are removed. Normal-main configuration and generated Pod source
list are restored. Six locks/registrants are unchanged. App and logger are
stopped, and the owned simulator is shut down. The A142 remains reserved and
untouched. No source, shader, public API, extra draw, scheduler or simulation
ownership correction was made.

Foreground Xcode control still needs the operator's explicit approval under
AGENTS.md and the cua-driver skill. The earlier foreground question remains
pending; the CLI preflight did not provide the hoped-for alternative. Approval
would permit inspection of capture controls, not certificate trust changes or
use of another device. Until then the actual first target command stream remains
unobserved. This is a tooling measurement gap, not proof of a SceneKit limitation.
The first target failure, separate synthetic-alpha failure and broader U3/Track E
gates remain open.
