# Temporary U3 highlight state probe

The five-file diagnostic patch is ready for the parent's native iPhone 17 Pro simulator run. Native state behavior and visual layout remain NOT_RUN. The generic arm64 simulator app build succeeded. No outline renderer is included or promised.

The patch is relative to the accepted imported parent-source snapshot, not Git HEAD alone. HEAD is `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. The imported archive SHA256 is `646f5d269a78020fb588ea420fb2783ea9d5a998e6b8019fd8885ad365726f2d`. `import-check.log` verifies all 52 hashes. Apply this patch only on that snapshot.

`diagnostic.patch` owns exactly the five paths in `owned-paths.txt`. `owned-source.tgz` and `source/` contain the complete final versions of those five files. `owned-source-sha256.txt` records their hashes. The baseline archive contains the three existing files. Reversing the patch removes the two new files.

The scene contains three visible emissive cuboids and a camera. The left parent owns the center child through its real `children` list. The right cuboid is an independent sentinel. The camera remains fixed. No action runs automatically after initial showcase load. There is one stage button, and the footer labels requests without declaring success.

## Parent run

From the parent's integrated `dart3d/example` directory, use the existing authorized simulator after confirming its current ID. The following exact command uses the simulator ID recorded in project AGENTS. Replace that ID if the parent has a different current iPhone 17 Pro simulator.

```sh
/Users/jasonholt/zero/bin/dn run -d C24F3C6D-A3A9-4FB7-978E-36E67EF55354 --dart-define=DART3D_MODEL=u3-highlight-state
```

Capture the existing unified log through the parent's permitted device tooling. The logger has subsystem `com.jasonholtdigital.dart3d`, category `scene`. Filter on `U3HighlightState`. Each log reads the actual private `colors` dictionary after the named operation. Entries are sorted numerically by the real native UInt64 key. RGBA uses Swift Float formatting.

The existing `d3Log` uses OSLog's interpolated message path. If the capture presents `<private>` instead of the message, that capture is inconclusive. Obtain an unredacted simulator development log through the parent's authorized tooling before judging state. This patch does not change the logger or add an alternate query API.

Press the button once per row below. Wait for the corresponding native records before the next press. Record both the requested stage and native records. Dart request logs alone do not prove native application.

## Public calls and expected state

These expectations are literal consequences of the fixture calls. No Dart highlight map or simulated native reducer is present.

Native key names in this table are abbreviations only.

| Name | LocalId | Actual native key |
| --- | --- | --- |
| P | `(0x7533, 1)` | `128861903781889` |
| C | `(0x7533, 2)` | `128861903781890` |
| S | `(0x7533, 3)` | `128861903781891` |

| Button | Actual public calls | Expected native state and interpretation |
| --- | --- | --- |
| Initial load | Existing showcase `loadDocument(doc)` | `clearScene`, count 0. No highlight action has run. |
| 1/7 Assign two colors | `setNodeHighlights({P: (1,.25,0,1), C: (0,.5,1,.5)})` | One `apply`, count 2. Distinct RGBA values share one mutation. |
| 2/7 Clear parent, set sentinel | `setNodeHighlights({P: null, S: (.25,1,0,0)})` | One `apply`, count 2. P is absent. C remains `(0,.5,1,.5)` despite omission. S has zero alpha and remains an entry. |
| 3/7 Move child, patch sentinel | `setNodeTransforms([NodeTransform(C, translation: (1.2,1.25,0))])`, then `setNodeHighlights({S: (.25,1,0,.25)})` | `apply`, count 2. C retains its original RGBA after a transform edit without being rewritten by the observing setter. The child moves slightly upward. |
| 4/7 Remove parent and child | `removeNode(P)`, then `setNodeHighlights({S: (.5,1,0,.25)})` | `removeNodes`, count 1, contains only S with its stage 3 value. Following `apply` contains only S with its stage 4 value. P and C disappear from the scene. C was highlighted immediately before actual descendant removal. |
| 5/7 Re-add same IDs | `applyCommands([addNode(P, parent:null), addNode(C, parent:P)])` with ordinary fresh node specs, then `setNodeHighlights({S: (.75,1,0,.25)})` | `apply`, count 1, S only. P and C reappear visibly but neither regains a highlight. Only S was patched after re-add. |
| 6/7 Highlight child explicitly | `setNodeHighlights({C: (1,0,1,.5)})` | `apply`, count 2. C returns only on explicit assignment. S retains its stage 5 value despite omission. P remains absent. |
| 7/7 Load fresh same-ID scene | `loadDocument(buildU3HighlightStateDocument())` | `clearScene`, count 0. All fixture IDs are reused in a fresh document. No highlight follows the load. The button becomes disabled. |

The native log bodies must match the following literal lines for these operations. Other existing host logs may interleave.

```text
U3HighlightState op=clearScene count=0 colors={}
U3HighlightState op=apply count=2 colors={128861903781889=[1.0,0.25,0.0,1.0];128861903781890=[0.0,0.5,1.0,0.5]}
U3HighlightState op=apply count=2 colors={128861903781890=[0.0,0.5,1.0,0.5];128861903781891=[0.25,1.0,0.0,0.0]}
U3HighlightState op=apply count=2 colors={128861903781890=[0.0,0.5,1.0,0.5];128861903781891=[0.25,1.0,0.0,0.25]}
U3HighlightState op=removeNodes count=1 colors={128861903781891=[0.25,1.0,0.0,0.25]}
U3HighlightState op=apply count=1 colors={128861903781891=[0.5,1.0,0.0,0.25]}
U3HighlightState op=apply count=1 colors={128861903781891=[0.75,1.0,0.0,0.25]}
U3HighlightState op=apply count=2 colors={128861903781890=[1.0,0.0,1.0,0.5];128861903781891=[0.75,1.0,0.0,0.25]}
U3HighlightState op=clearScene count=0 colors={}
```

No deferred realization is arranged. A `retainNodes` record is not required for this sequence. Its temporary log observes the same actual map whenever the existing hook runs. Do not classify an incidental record as proof of genuinely deferred replay. Extra clears during an action can indicate scene replacement or host recreation and need investigation before accepting that action's retention evidence.

## Verification receipts

| Check | Result | Evidence |
| --- | --- | --- |
| Fixture controller behavior | 3 tests passed, including real emitted highlight JSON, transform bytes, structural batches, load bytes, deterministic hierarchy, and portrait projection bounds | `final-fixture-tests.log` |
| Existing package U3 and U4, structural and subtree regressions | 84 tests passed | `package-regressions.log` |
| Existing example U3 and U4 plus this fixture | 50 tests passed | `example-regressions.log` |
| Changed Dart source and test analysis | No issues found | `final-analysis.log` |
| All 12 plugin Swift sources | Typecheck exit 0 | `ios-typecheck-direct.log` and result JSON |
| Generic arm64 simulator app | BUILD SUCCEEDED, direct process exit 0, no boot or run | `ios-build-direct-retry.log` and result JSON |
| Forward and reverse replay | All five final hashes match. Reverse restores three baseline files and removes both new files | `replay-verification.json`, `forward-replay.log`, `reverse-replay.log` |
| Unowned preservation | 49 imported paths, 1,900 tracked paths, and six recorded locks or registrant files byte-identical | `unowned-*-check.log`, `locks-check.log` |

Projection bounds are pure-Dart evidence only. They do not establish native footer placement. The simulator build compiles and links this route and diagnostic code but does not execute the public-to-native state path.

The first build failed with `/bin/sh: /packages/flutter_tools/bin/xcode_backend.sh: No such file or directory`. The existing scheme references `FLUTTER_ROOT`. The successful direct retry sets it to `/Users/jasonholt/zero` on the command line. No project configuration was edited for that fix. Existing warnings remain in the retained log. Generated license/build define lines were redacted from exported build logs.

The first logging helper rejected its fixed-length argv before launching any command. The tests, Swift typecheck, and config command were then run directly. The corrected helper records later exact argv and exit codes. An integration helper first failed to compile because its embedded Dart interpolation was not raw. Its corrected first run used the wrong working directory and failed before writing. It then ran successfully from the checkout root. An early formatter changed unrelated showcase lines. Those formatting-only changes were removed before the final checks and package. These setup failures did not alter imported unowned source.

## Scope and cleanup

This diagnostic can establish basic ingress, batched set and clear, omitted-entry retention, retention across a transform edit, actual subtree removal, same-ID re-add, and explicit scene replacement only after the parent obtains the stated native evidence.

Streamed reparenting, genuinely deferred replay, native host teardown, Android, mask rendering, and performance remain NOT_RUN. Component and resource edit retention are also NOT_RUN by this fixture, which chooses the allowed transform-edit path. No source review verdict is native proof.

The Swift dictionary remains the sole state owner. The controller retains no diagnostic selection map. The only native source change adds deterministic logging after `apply`, `removeNodes`, `retainNodes`, and `clearScene`. It adds no decisions, guards, renderer code, public query, test seam, or realizer/host edits. The imported after-constraints ordering, animation, sprite, catcher, Android sources, and dependency locks remain unchanged.

This is a throwaway diagnostic, not a permanent production change. Parent owns the native run and removal of all five-file diagnostic changes. From a checkout containing the accepted snapshot plus this exact probe, check reversal with:

```sh
git apply --reverse --check /private/tmp/dart3d-e5b-highlight-native-probe-20261027/r1/diagnostic.patch
```

After retaining the native evidence, remove the probe with:

```sh
git apply --reverse /private/tmp/dart3d-e5b-highlight-native-probe-20261027/r1/diagnostic.patch
shasum -a 256 -c /private/tmp/dart3d-e5b-highlight-native-probe-20261027/r1/imported52-sha256.txt
```

Do not use Git HEAD as the cleanup baseline. That would discard accepted imported work. If the parent edits these five paths, reconcile those edits before reversal.

No children, device actions, simulator actions, commits, pushes, or external-system changes occurred. The isolated checkout retains the imported snapshot and five probe files. Local SDK package resolution, CocoaPods, generated configuration, and ignored app build outputs remain for reproducibility. No lockfile or registrant bytes changed. Temporary replay directories, the insertion helper, and the diagnostic Swift module cache were removed. The output directory retains the requested artifacts and replay scripts.

I read project AGENTS, the DartNative skill, installed Button documentation, installed native plugin template and guide, package README, existing fixture conventions, Poteto native Codex instructions, synthesis, parent checkpoint, and independent review. The vendor `dartnative/docs` checkout named in AGENTS is absent. No CONTEXT.md was found. The supplied original goal and source review set the bounded scope. No external PR or issue work was requested or performed.

Model the Domain guided the single enum of manual stages. Unslop guided the request labels and handoff wording. Throughput checkpoint is not applicable to this bounded diagnostic. All implementation and verification ran in this isolated checkout without children.
