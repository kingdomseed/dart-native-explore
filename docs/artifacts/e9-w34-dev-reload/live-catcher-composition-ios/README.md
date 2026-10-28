# iOS live-catcher source composition

The live-material decoder now declares SceneKit fragment transparency. In the
recorded fixture, the source view keeps the backdrop visible outside the received
shadow after initial load, same-ID material Replace and full Reload, at both
caster positions. This is an authored live-material composition change. Production
live diagnostic views and the separate dark channel-transition work remain open.

The retained production [patch](correction.patch) adds one assignment to
FsceneRealizer.Context.decodeMaterial's live shadowCatcher branch:

```swift
m.shaderModifiers = [.fragment: "#pragma transparent\n#pragma body\n"]
```

There is no fragment RGB or alpha calculation. The directive forces SceneKit's
documented premultiplied source-over composition of its own shadowOnly output.
The native lighting model, alpha blend setting, depth/culling policy, material
resource protocol and actual receiver geometry remain unchanged. The baked
branch and private baked capture material are untouched.

## Original alpha control

The baseline has the accepted native implementation plus identical source-state
logging and the existing live-probe Dart fixture. All operations stay at Off,
wire off. PID62005 records alpha blending (`blendMode=0`) on the actual bound
slot0 double-sided instance clone. Diffuse, transparent and multiply properties
are white at intensity1; transparency is1; depth reads/writes are true; modifiers
are empty. Those logged values remain unchanged across replacement and reload,
except native allocation identities.

[Initial A](baseline/00-load-A.png) and [Replace A](baseline/01-replace-A.png)
match in the scene crop. [Reload A](baseline/02-reload-A.png) adds a gray receiver
rectangle:22,153 changed pixels. A fresh process, PID65876, starts with that
rectangle and [Reload alone](baseline-reload-only/01-reload-A.png) removes it:
22,154 changed pixels relative to [fresh initial](baseline-reload-only/00-load-A.png).
The issue therefore does not require a prior Replace. No inference about an
internal SceneKit cache, ordering decision or exact opacity-classification cause
is made from identical public state and differing pixels.

## Rejected multiply candidate

The installed SCNMaterial header recommends multiply blending for shadowOnly.
The comparison changed only that live blend assignment, with the same trace and
fixture. PID67157 confirms `blendMode=3` on current bound clones across all
operations. [Initial](multiply/00-load-A.png), [Reload A](multiply/02-reload-A.png)
and [Reload B](multiply/05-reload-B.png) consistently show the entire receiver
black. Pixel stability here is an incorrect result. The multiply assignment was
reversed and is absent from the production change. This result concerns this
renderer/SDK setup, not a general platform limitation.

## Explicit transparency and clean replay

SCNShadable's installed header states that `#pragma transparent` forces
`output.rgb + (1-output.a) * destination.rgb`, with premultiplied RGB. The prior
reviewed live diagnostic experiment already used that directive. The follow-on
source candidate tests it alone with an empty modifier body and the original
alpha blend. It neither derives a shadow mask nor writes its color/coverage.
The [SDK excerpts](installed-sdk-excerpts.txt) retain the declarations and hashes.

With the trace present, PID70854 records the same state as baseline except the
fragment modifier entry. The native source footprint remains correct at
[load A](transparent/00-load-A.png), [Replace A](transparent/01-replace-A.png),
[Reload A](transparent/02-reload-A.png), [move B](transparent/03-move-B.png),
[Replace B](transparent/04-replace-B.png) and [Reload B](transparent/05-reload-B.png).
Corresponding same-pose scene crops have zero changed pixels.

The tracing helper and calls were then removed. PID73378 runs only the one-line
material change with the same temporary Dart fixture. Its
[load A](clean/00-load-A.png), [Replace A](clean/01-replace-A.png),
[Reload A](clean/02-reload-A.png), [move B](clean/03-move-B.png),
[Replace B](clean/04-replace-B.png) and [Reload B](clean/05-reload-B.png) retain
the same composition. All same-pose Replace/Reload crops match exactly. The clean
load/reload A and reload B crops also exactly match their traced counterparts.
The trace is not needed for the result.

All comparisons use original decoded402×874 PNGs and scene crop`[0,70,402,580]`,
excluding status and controls. [Pixel analysis](pixel-analysis.json) retains all
21 comparisons and per-image samples, including the rejected candidate and the
baseline inconsistencies. The corrected load A differs from the baseline's
initial correct-looking image at10 edge pixels, maximum channel difference61;
no exact before/after channel or shadow-map equivalence is claimed from that
pair. Same-state comparisons within corrected runs are the exact matches above.
These are encoded screenshot observations, not calibrated linear RGB or numeric
alpha measurements. [The Dart recomputation](pixels.dart) uses the retained
parent artifact root.

## Native state and proof boundary

[Trace analysis](trace-analysis.json) and [summary](trace-summary.json) record
phase, PID and actual current material state. Only the existing typed live-catcher
bindings/current-draw slots are read, including snapshot clones. Initial install,
accepted viewConfig and upsert/rebind checkpoints are traced; nothing logs per
frame. Each recorded trace is `channel=none wireframe=false`. Native object
addresses are allocation tokens and can be reused; differing addresses alone
are not behavior evidence. [The parser](analyze-trace.dart) retains raw lines.

The clean runtime source and final production native file have identical hashes.
Only the three temporary Dart fixture files differ between the clean runtime
packet and the final production66 packet; they were removed after recording.
[Production receipt](receipt.json) verifies the one-file delta, all65 unowned
accepted-overlay files and all3,177 pre-existing files other than the changed
native file, plus six locks/registrants,
unchanged HEAD and complete forward/reverse66-file replay. No source-light-copy,
private-frame, view lifecycle, target, simulation, clock or wire change is included.
The one added line has no comments or suppressions; the final comment audit is clean.

The clean run has a full-plugin arm64iOS15 Swift typecheck with an explicit
[command/time/exit receipt](clean/swift-typecheck-receipt.json); its empty
[log](clean/swift-typecheck.log) alone is not the receipt. Native DN build/run
transcripts are retained per stage; the clean run ends `Application finished.`
The [exact-PID log](clean/native-pid.log) and [error query](clean/error-query.log)
contain no new liveCatcherTrace, fatal, shader-error or transaction-warning match
for PID73378. This is a searched-log observation, not independent native execution.
Dart code and tests are unchanged in the production delta. No new literal/shader
assertion test or repeat of unrelated full suites is claimed for this native setting.

Four original recordings and full probe/decode receipts remain locally. The
[video receipt](video-receipts.json) identifies paths, hashes, dimensions, original
frame counts, durations, decoder exit codes and warnings. Duplicate-DTS muxer
warnings are retained rather than describing decoding as warning-free. Stable
stills do not establish uninterrupted transitions, latency or performance.
No original recording was edited, published or pushed.

The app, recorders and owned log stream were stopped. The simulator was shut down
and the Device panel/booted-simulator list checked empty. Config-only generation
restored lib/main.dart with no W34 defines. Temporary source tracing and live-probe
Dart changes are removed. Accepted source remains unchanged except the one native
assignment. Source/evidence archives, scripts, original recordings and ignored
build/Pods outputs are retained; owned replay scratch is removed. No commit,
push, PR action or A142 operation occurred.

Independent Codex review passed the bounded source correction and offline evidence
checks ([report](codex-review.md)). It independently verified the source packets,
all 21 pixel comparisons, 156 samples, native traces and four full video decodes.
Reviewer native execution, builds and tests were NOT_RUN.
General receiver/material/consumer coverage,
physical iOS, Android, calibrated coverage, performance, channel-transition work,
production live diagnostic integration and final T2/T4 remain open. Native
particles retain the approved unsupported status. This does not complete W34,
E9 or Track E.
