# iOS live-catcher coverage experiment

The source-light-copy candidate renders receiver normals and depth under the
native live shadow footprint in this fixture. Base color, metallic and roughness
are absent inputs and render magenta within that coverage. Caster motion moves
the footprint without a material replacement or baked refresh. This establishes
a route to native coverage for one spot-light planar receiver and opaque caster.
It does not establish production live-catcher support or whole W34 acceptance.

The prototype was removed after recording. The writer's 66 accepted source files
match the previously reviewed baked-catcher packet exactly. No live probe remains
in production source. The immutable candidate and failing-source packets are
retained locally for independent review and reconstruction.

## Failed first candidate

The first native candidate copies `source.presentation.light`. Selecting normals
terminated PID40349 with EXC_BAD_ACCESS/SIGSEGV. The
[crash summary](failed-presentation-copy/crash-summary.json) and original
[IPS report](failed-presentation-copy/Runner-2026-10-28-004839.ips) put the fault in
`SCNLight.copyWithZone` → `setIESProfileURL:`, called from
`ScreenDebugAttachments.capture` at its light-copy expression. There is no
successful diagnostic PNG from that process. [Its Off capture](failed-presentation-copy/00-off-A.png)
and [run log](failed-presentation-copy/run.log) are retained.

The parent changed that expression to `source.light?.copy()`, the existing
model-attachment copy route used by BakedShadowCatchers.swift. The private copy
still has its animations removed; node transforms still use presentation poses.
The subsequent PID41819 run survives all recorded selections and operations.
The reason the presentation-light copy contains an invalid IES reference is
unresolved. No general SceneKit limitation or animated-light parity is claimed.
One redundant new comment was deleted after the read-only comment audit.

## Native observations

The matched baseline uses only the three new Dart fixture files with accepted
native code (PID36427). Its selected-channel view logs shadowOnly as unsupported
and draws the copied receiver white. The source-light candidate adds the native
light/castsShadow packet fields and live material RGB-under-alpha branch. It does
not introduce a cache, render pass, analytic mask or replacement receiver.

| View | Baseline | Source-light-copy candidate |
| --- | --- | --- |
| Normals A | [white receiver](before/01-normals-A.png) | [native covered normal](model-copy/01-normals-A.png) |
| Depth A | [white receiver](before/02-depth-A.png) | [native covered depth](model-copy/02-depth-A.png) |
| Base color A | not captured | [absent-input magenta](model-copy/03-basecolor-A.png) |
| Metallic A | not captured | [absent-input magenta](model-copy/04-metallic-A.png) |
| Roughness A | not captured | [absent-input magenta](model-copy/05-roughness-A.png) |

The PBR backdrop remains visible outside the diagnostic footprint. The receiver
is the actual translated, yawed and nonuniformly scaled U2 plane. Its shader
alpha comes from SceneKit's live shadowOnly computation, not a baked texture or
a hand-authored footprint. Encoded screenshots show the contribution but do not
calibrate alpha, linear RGB, or exact shadow-map equivalence.

[06](model-copy/06-normals-A.png) → [07](model-copy/07-normals-B.png) moves caster
and coverage to B without Replace. [08](model-copy/08-depth-B.png) →
[09](model-copy/09-depth-A.png) returns them to A in depth. In the band
`[100,405,290,45]`, below both caster positions, these change 4,578 and 4,116
pixels respectively. The native log has no baked capture or explicit refresh
event in this live run. No latency or frame-rate claim follows from the samples.

[10](model-copy/10-depth-wire.png) retains fill and actual edges.
[11](model-copy/11-off-wire-A.png) turns the channel Off with wire retained;
[12](model-copy/12-off-restored-A.png) removes wire and matches the initial
source-light Off capture exactly in scene crop `[0,70,402,580]`.
[14](model-copy/14-normals-B.png), [15](model-copy/15-normals-B-replace.png), and
[16](model-copy/16-normals-B-reload.png) have zero changed scene pixels after
same-ID Replace and Reload at B. [17](model-copy/17-off-B.png) matches the
baseline's authored B crop exactly; [18](model-copy/18-off-A-final.png) matches
the baseline's authored A crop exactly.

## Authored-view discrepancy remains open

The initial source-light Off image has a transparent receiver outside its shadow,
while the baseline and the later Off images after Replace/Reload show a gray
receiver rectangle. Initial and final source-light A crops differ in 22,154
pixels, with maximum encoded channel difference62. The source-light initial
image also differs from baseline B; this is not explained by relabeling its pose.
The source-light Off-after-wire crop matches its own initial image, and its
post-replacement/reload A and B crops match the baseline. These are observations,
not a diagnosed cause. The sequence does not isolate Replace from Reload. No
source-owner correction, general Off parity or production readiness is claimed.

[Pixel analysis](pixel-analysis.json) retains every comparison, including the
nonzero ones, and original per-image samples. [Its Dart script](pixels.dart)
uses the retained parent artifact root. Original PNGs were decoded before
asserting missing or black output; no preview-only inference is used. UI labels
and accessibility snapshots can represent different points during the update;
scene crops establish the stated scene observations, not UI or rendering latency.

## Execution and cleanup

The parent ran [31 focused fixture tests](focused-tests.log), clean
[example analysis](example-analyze.log), full-plugin arm64iOS15 Swift typecheck,
and the native DN builds/runs. The empty typecheck log alone is not an exit-code
receipt; [execution receipt](execution-receipt.json) explicitly records the tool
result and exact command. The worker independently ran its host checks, not a
native session. Full suites were not repeated for this throwaway probe; the
accepted source's previous full-suite result is not promoted to this candidate.

The final [native excerpt](model-copy/native-relevant.log) has channel/wire
selections and no fatal, shader-compilation failure or transaction warning was
identified for PID41819. The failed PID40349 has the separate crash above.
The 76.636667-second recording has8,047 original frames at1206×2622. Its complete
ffprobe read and passthrough decode exit0; the muxer emits duplicate-DTS warnings.
[Video receipt](video-receipt.json) retains its local path and hash. The failed
candidate recording also remains locally; neither video was pushed or published.

The app, both recordings and owned log stream were stopped. The simulator was
shut down; Device panel and booted-simulator list were verified empty. Normal
`lib/main.dart` configuration and no W34 defines were restored. The A142 was not
targeted. The five-file candidate was exported then reversed after an exact check.
All66 accepted hashes and six locks/registrants are preserved. Only owned replay
and extracted scratch is removed; source/evidence archives, scripts, logs, ignored
build/Pods outputs and original recordings remain.

Independent [Codex review](review/report.md) passed for the bounded throwaway
capability and evidence claims. It verified packets/replay/preservation, all26
PNGs, numeric comparisons, both original videos and native crash evidence. It ran
no tests, builds or native sessions. It also detected eight brief dark scene
intervals during channel changes, longest0.28 recording seconds. These are
recording observations, not measured application latency; their cause and
transition behavior remain open. The review does not approve production support.
Live light mutation, animated attachments, general
consumer/material behavior, authored render-target isolation, source-view
opacity discrepancy, performance, Android and full T2/T4 remain OPEN. Native
particles retain the approved unsupported status. This is a capability experiment.
