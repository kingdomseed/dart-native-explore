# Binding before installation does not fix the first target contour

The default-off installation control fails. Both matched runs have current masks,
but their first outlined target output misses all 267 contour pixels. Binding
initial mask and mode values before installing the technique is not sufficient.
No production correction is accepted.

The parent ran the approved iPhone 17 Pro simulator on 2026-10-28. Both launches
used identical runtime70 source, SHA256
`40110ca8e3db10d4dd057689898568ad31448cbef9fe08b11bd7e20e5716a603`.
Its 70 source identities match the worker packet. Repacking accounts for the
different archive hash. No parent source edits were made.

Both runs keep `DART3D_U3_OUTLINE_PUBLISH_IN_UPDATE=true`. Only
`DART3D_U3_OUTLINE_BIND_BEFORE_INSTALL=false|true` changes. The true branch binds
the candidate's initial mask and mode before assigning `renderer.technique`,
then performs the original installed-copy binding and single ordinary render.
The synthetic-alpha path, shaders, source simulation and manual scheduling remain
unchanged. [Worker report](worker/report.md) records the hypothesis and SDK basis.

## The control executes but the first contour remains absent

| Request | Baseline mask support | Control mask support | Baseline contour mismatches | Control contour mismatches |
| --- | ---: | ---: | ---: | ---: |
| First Set | 205 | 205 | 267 | 267 |
| First Clear | 0 | 0 | 0 | 0 |
| Second Set | 205 | 205 | 0 | 0 |
| Second Clear | 0 | 0 | 0 | 0 |

The installation log records the false branch at target time 542658.2500000001
and true at 542739.9833333334. Both have mode 2. Each first Set mask contains
205 selected pixels, with 267 contour pixels under the pinned radius-three
oracle. Both first target outputs are byte-identical to their actual Off output.
This refutes the prepared control as sufficient. It does not establish why
SceneKit omits the initial contour or prove that initial parameter values are
the only relevant technique state.

The next three outputs in each run match their actual masks exactly. Every
target output preserves all outside-contour RGBA bytes. The separate private
alpha test still returns 6,912 black opaque pixels on its first invocation in
both runs, then passes the next three invocations. A shared cause is unconfirmed.

See [baseline analysis](baseline/analysis.json), [control analysis](control/analysis.json),
and each run's `first-use.json`. Complete raw bytes and format/label metadata are
under each `raw/` directory. The targets are BGRA8 sRGB, Metal81. Masks are
RGBA16Float, Metal115. `analyze.dart` retains the native pixel oracle.

## Scheduling and screens remain unchanged

Each run has five admitted target draws, the initial draw plus four explicit
requests. Each has four highlight batches and four private-update callbacks with
current membership, time and encode ordering. All four held dirty=false reads
per run are byte-identical to their previous target output. No extra target draw,
update, wait, retry, source-scene update or dirtying was introduced.

All eleven matched frozen RGB screen crops are exact in
[pixel-comparisons.json](pixel-comparisons.json). These are static screenshot
observations, not proof of moving alignment or screen alpha. The 42 raw textures
are from the actual native targets and private synthetic test, not screenshots.

Full native log and two original videos remain at the hashed paths in
[local-originals.json](local-originals.json). Both videos fully decode, totaling
9,428 frames. FFmpeg reports two duplicate-DTS warnings for baseline and four
for control. Original stderr and [video receipts](video-receipts.json) are retained.
Encoded duration does not establish interaction latency or performance.

## Execution, cleanup and remaining investigation

The parent reran 25 fixture/W34 tests. Both native builds/runs completed. Baseline
PID71924 and control PID75848 have zero matches for the retained error-marker
query after the logger stops. Functional output still fails. The worker's 13
highlight tests, analyses, Swift typecheck and generic build are inspected worker
receipts in [verification.md](worker/verification.md), not additional parent runs.
The changed patch adds no comments or suppressions. The comment audit found zero
actionable findings and made zero deletions.

Accepted final66 and all 4,938 pre-existing files are restored. The four own
probe additions are removed. Normal-main configuration and generated Pod source
list are restored. Six locks/registrants are unchanged. App, recorder and logger
are stopped, and the owned simulator is shut down. See
[restoration](restore-receipt.json) and [final configuration](final-config-receipt.json).
The A142 remains reserved and untouched.

Parent helper mistakes were corrected without changing native code. An analysis
invocation omitted the example package configuration and was rerun with it.
The combined first-use helper was invoked before control raw files existed and
was rerun after capture. The baseline CLI lacked writable stdin, so agent-device
closed the app. A restore-time pod install ran from the repository root, reported
no Podfile, and succeeded when rerun from example/ios. These do not explain the
reproduced GPU output. Their retained logs are local in the parent artifact folder.

Next investigation must distinguish initial technique activation or resource
readiness from parameter copying. It must keep the synthetic-alpha cause separate
and preserve sole source-simulation ownership. No automatic warm-up draw, second
draw or scheduler change is accepted. Motion/deformation, single host, MSAA,
view replacement, retirement, W34 coexistence, scaled width, Android, performance,
T2/T4, whole-U3 and Track E acceptance remain NOT_RUN.
