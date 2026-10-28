# iOS debug-channel transitions

The iPhone simulator replay no longer blanks the scene when switching between
selected debug channels. The correction keeps the private screen views and
changes their frame content through the existing snapshot path. Entering or
leaving debug mode still rebuilds the presentation. Brief dark frames when
entering debug mode remain in both corrected recordings.

The production [patch](production/correction.patch) changes one expression in
`SceneViewHost.applyViewConfig`:

```swift
let changesPresentation = (screenDebugOptions.channel == .none)
    != (debug.channel == .none)
```

The old expression compared channel enum values. Every selected-channel change
therefore called `updateScreenSubviews`, removed the current sibling views and
black backing, and constructed a new presentation. The existing
`syncScreenSubviews` / `pokeScreenSubviews` path already captures the current
channel, invalidates derived materials by channel, applies current geometry and
camera poses, updates wireframe, and requests a sibling draw. The correction
changes neither that path nor the independent camera/view rebuild paths.
No new state, renderer, queue, protocol, cache or clock is added.

## Native comparison

All three runs use the retained `w34_debug_main.dart` PBR fixture, fixed camera
and unchanged Dart source. Each starts at Off with wireframe disabled, then
performs the same eleven selections:

1. Normals.
2. Metallic.
3. Roughness.
4. Base color.
5. Depth.
6. Normals again.
7. Enable wireframe.
8. Depth with wireframe.
9. Off with wireframe.
10. Disable wireframe.
11. Re-enter base color.

The actual native option log records every selection. Two temporary logs in
`updateScreenSubviews` record rebuild generations and installed view identities.
They are present in baseline PID85554 and corrected PID91403, then removed for
clean PID95227. Allocation addresses may be reused; rebuild generations and the
executed construction path establish the repeated rebuilds.

| Observed state | Baseline | Corrected with tracing | Clean correction |
| --- | --- | --- | --- |
| Native option changes | 11 | 11 | 11 |
| Selected-to-selected channel changes | 6 | 6 | 6 |
| Those changes invoking a view rebuild | 6 | 0 | Not instrumented |
| Recorded dark-region intervals between selected channels | 6 | 0 | 0 |
| Dark-region intervals entering debug mode | 2 | 2 | 2 |

The [native events](native-events.json) retain raw lines and per-event grouping.
The clean rebuild fields are null because the logs were removed; absence of a
trace is not treated as proof of zero rebuilds.
The [baseline contact strip](baseline/flash-contact.png) shows the normals view,
the blank scene during its switch, and the metallic view afterward.

All 33 original PNGs are retained. Eleven baseline-to-corrected and eleven
baseline-to-clean comparisons have zero changed pixels in scene crop
`[0,70,402,580]`, excluding status and controls. This includes all five channels,
wireframe, Off and re-entry. The [comparison JSON](still-comparisons.json) and
[recomputation script](compare-stills.dart) retain every result. The
[clean contact sheet](clean/states-contact.png) shows all eleven settled states.
These exact screenshot comparisons do not calibrate channel values or coverage.

## Recording analysis

Three original videos remain at the paths in each stage's `video-receipt.json`.
Their retained frame counts are 3968 baseline, 2806 corrected and 2495 clean.
All were fully probed and decoded. Commands, exit codes, hashes and original
timestamps are recorded. The clean rawvideo decode reports duplicate-DTS muxer
warnings; its original frame/time counts still match. No warning-free decode,
frame-rate, speedup or app-latency claim is made.

The analysis scales each video frame to 402×874 and reads the fixed middle
literal swatch at `[180,360,42,35]`. The swatch remains visible in every selected
channel and authored mode. A frame is marked dark only when every RGB byte in
that region is below 20. This finite recording check identifies the observed
blank scene, rather than treating the fixture's black background or the black
metallic occluder as a failure. The threshold and every per-frame mean, maximum
and original timestamp are retained in each stage's `roi-analysis.json`.

Baseline contains eight dark intervals, including six between selected channels.
The corrected and clean videos each retain only the first entry and re-entry
intervals. The recordings have different durations and input pacing; counts are
observations of the repeated sequence, not a performance benchmark. This does
not establish uninterrupted rendering at every boundary or on other fixtures.
`decode-video.dart` and `analyze-roi.dart` use the retained parent artifact root.

## Source, checks and cleanup

[The production receipt](production/receipt.json) verifies a one-file delta
against the accepted source-composition unit. Its baseline66 contents match that
unit's reviewed final66. All 65 other overlay files, 3232 pre-existing files
other than the changed host source, six locks/registrants and HEAD are unchanged.
The pre-existing-file count includes the preserved overlay files.

Clean runtime and final production match across all 66 source files. The only
baseline/corrected instrumentation is in `RenderTargets.swift`; its two temporary
logging statements are absent from the clean run and restored production source.
No Dart fixture change is included. Complete forward and reverse patch replay
passes. Replay scratch was removed. Source packets and recomputation scripts
remain under `/private/tmp/dart3d-w34-ios-channel-transitions-20261028/r1/parent/`.

Each run log records its native Xcode build and ends with application completion.
The final full-plugin 13-file arm64 iOS15 Swift typecheck passed, with an explicit
[command/time/exit receipt](clean/swift-typecheck-receipt.json). The unchanged
fixture's focused test run passed ten tests ([log](clean/fixture-tests.log)).
No new tests mirror the native predicate, and no unrelated full-suite result is
claimed for this correction. Exact-PID error searches retain zero matches for
the named fatal, shader, cross-scene-mutation and transaction terms. This is a
searched-log observation. The final scoped comment audit found no comments,
suppressions or deletions.

All three recorders and app runs were stopped. The owned log stream exited after
SIGINT. The app session was closed and the approved simulator shut down; the
Device panel and booted-simulator inventory were empty. Config-only generation
restored `lib/main.dart` without W34 defines. No A142 operation, commit, push or
PR action occurred. Original captures, videos, source packets, scripts and ignored
build/Pods outputs are retained. No owned replay scratch remains.

Independent Codex review passed this bounded correction and the supplied source
and offline evidence ([report](codex-review.md)). It independently reproduced all
22 still comparisons and every video ROI row, and checked raw native events and
exact source replay. Reviewer native runtime, builds and tests were NOT_RUN.
Live-catcher diagnostic integration, broader
consumer and viewport/camera runtime coverage, Android, physical iOS, calibrated
output, performance and final T2/T4 remain open. Native particles retain the
approved unsupported status. This does not complete W34, E9 or Track E.
