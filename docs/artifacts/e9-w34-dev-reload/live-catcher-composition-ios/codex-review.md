# PASS — bounded iOS live source-material composition

No material reachable scoped P1/P2 defect or evidence overclaim found. This verdict covers the one-assignment correction and the supplied native evidence. It does not accept whole W34, E9, Track E, T2 or T4.

## Source and preservation

Reviewed in the prepared checkout `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-f12c351b`, initially clean, at HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. Imported the authorized final66 archive and made no subsequent production edits.

Independently verified the five supplied archive/patch SHA256 values, both production manifests, all 66 archive paths and exact forward/reverse patch reconstruction. Accepted66 to final66 changes only `FsceneRealizer.swift:2436`:

```swift
m.shaderModifiers = [.fragment: "#pragma transparent\n#pragma body\n"]
```

All other 65 accepted-overlay files are byte-identical. All six locks/registrants match. Current parent files match the supplied initial 3,178-file manifest except the one corrected native file: 3,177 preserved. Every one of the review checkout's 1,873 pre-import tracked/untracked files outside the overlay was preserved. The final import remains byte-identical to its manifest.

Clean-runtime and final-production packet native bytes match exactly. The only three packet differences are `example/lib/w34_debug_main.dart`, `example/lib/w34_debug_scene.dart` and `example/test/w34_debug_scene_test.dart`. Final production restores these fixtures and removes the trace helper and calls. Worker fixed66/material-only.patch are the rejected multiply candidate; they are not evidence of the final implementation.

## Reachability, ownership and size

Read the resource decoder and initial realize/install flow; ordinary mesh/multiple-primitive and procedural consumers; instance snapshot cloning; same-ID upsert/redecode/rebind; variant/default replacement; LOD material binding; and camera-facing geometry replacement. These consumers bind or copy the decoded material. The new assignment belongs to the native live material decoder, preserves `.shadowOnly` and default alpha blending, and contains no RGB/alpha write. The shadowCatcher early return prevents generic PBR extension modifiers from being appended to this material.

Baked decoding and private bake source are unchanged. The baked registry admits only baked configurations, so it does not overwrite live source modifiers. Current screen diagnostics return a copied authored live material at the unsupported-family guard (`FsceneRealizer.swift:8463–8470`), before adding channel code. There is no reachable current duplicate-transparent/body path. Future live diagnostic integration must respect the pragmas now owned by the source material. The old experimental light-copy/private-frame path is not integrated.

The correction adds no protocol, cache, lifecycle, clock, transition, or generic composition machinery. No ownership transfer or overengineering correction is required.

## Independently checked evidence

- All 53 files listed by `evidence-sha256.json` match. The five retained SDK headers match the excerpt hashes; actual installed SCNMaterial and SCNShadable declarations support the stated blend values and transparent premultiplied source-over equation. The empty modifier leaves native fragment output untouched. General native output calibration is not established by that declaration.
- Decoded all 26 original PNGs at 402×874, recalculated every one of 21 crop comparisons and 156 samples, and matched the supplied analysis exactly. Crop `[0,70,402,580]` excludes controls. Inspected original baseline, fresh reload-only, failed multiply and clean A/B images directly.
- Baseline load/Replace match; Reload changes 22,153 crop pixels. Fresh reload-only changes 22,154. Multiply is stable but visibly blacks the whole receiver and is correctly rejected. Corrected traced/clean same-pose comparisons and the three reported traced-to-clean comparisons are zero. Corrected initial A differs from the initially correct-looking baseline at 10 pixels, maximum channel difference 61; this discrepancy remains disclosed.
- Parsed all 27 raw trace rows and matched both trace artifacts. Every row records `channel=none wireframe=false`; all 23 current-consumer rows identify slot0 snapshot clones. Reviewed the trace implementation: it filters actual `isCurrentDraw` bindings and logs their bound material, rather than the source registry material. Baseline public composition state is invariant, multiply reports blendMode3, transparent reports blendMode0 plus the fragment modifier. Object addresses are not treated as behavior evidence.
- Matched baseline and multiply source manifests to their worker archives. The traced transparent candidate differs from traced baseline only by the final assignment; traced and clean temporary Dart fixtures match. Fresh reload-only has no separate source manifest; its build/run and PID trace remain supplied provenance, not an independently authenticated executable identity.
- Read all five DN run logs: each records an Xcode build and application completion without error lines. Read the explicit full-plugin 13-file arm64 iOS15 simulator Swift typecheck command/time/exit0 receipt and empty log. These are inspected parent execution receipts; no build or typecheck was rerun.
- Recomputed the exact clean PID73378 searched-log result: no liveCatcherTrace/fatal/shader-error/transaction-warning matches. Older trace stages remain in the full log.
- Hashed, fully ffprobed with frame counting, and fully decoded all four original videos offline. Probe/decode exits are 0; original frame counts are 2514/682/686/686. Duplicate-DTS warning counts are 179/130/114/164 and their logs are retained. No uninterrupted-transition, frame-rate, latency or performance claim follows.

## Limits and retained artifacts

Reviewer native runtime, devices, simulators, builds and tests: **NOT_RUN**. No children, commits, pushes, PR actions or external mutations. Same Codex family; no provider-diversity claim.

Unknown internal SceneKit classification/cache/order cause, general receiver/material/consumer rendering coverage, physical iOS, Android, numeric RGBA/alpha calibration, performance, selected-channel dark transitions, production live diagnostics and T2/T4 remain open. Native particles retain approved unsupported status. Stable stills do not prove continuous transitions.

Non-disruptively checked the parent's generated configuration: `DN_TARGET=lib/main.dart` with no W34 defines. Simulator/app/recorder shutdown and A142 non-use remain parent-reported; no operational device check was performed.

Retained: the authorized imported 66 files, this report, four offline recomputation scripts, source/pixel/trace/stage/video JSON results, four probe JSONs and four decode warning logs under this review directory. Own patch-replay scratch was removed. Original evidence was read-only throughout.
