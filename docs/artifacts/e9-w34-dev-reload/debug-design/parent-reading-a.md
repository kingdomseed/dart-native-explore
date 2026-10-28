# Parent reading of candidate A

Read candidate-a/design.md end to end, including the middle Android/channel/display/lifecycle sections retrieved separately after initial output truncation. Verified design-sha256.txt. Read preservation.txt; source preservation is runner-produced evidence, not a fresh parent runtime/build pass. No other candidate was read or selected in this checkpoint.

## Provisional rubric scores

| Criterion | Score | Reason |
| --- | ---: | --- |
| Caller/API/scope | 3/3 | Two view props, one closed channel enum, no document mutation, no second typed controller API. Real caller sites and release opt-in are explicit. |
| Ownership/lifecycle | 2/3 | View lifetime and latest-authored restoration are coherent. Derived screen attachments isolate canonical data. Borrowed buffer retirement, per-camera material snapshots and main/render queue handoff are still proposed integration work. |
| Rendering correctness | 2/3 | Actual sampled inputs, view-space normals, linear surface depth and display transfer are precise. Real triangle-edge requirement and family semantics are explicit. Shadow-only coverage, copied skin/morph equivalence and Android recipe/line behavior remain capability questions. |
| Proportionality | 1/3 | Per-camera presentation scenes, attachment/bone reconstruction, material synchronization and single-screen-to-sibling routing are substantial machinery. Reachable shared-renderer isolation motivates separation, but this cost needs comparison against a simpler source-supported alternative before acceptance. |
| Proof/uncertainty | 3/3 | Separates the reviewed quad from proposed production routes. Names decisive capture/current-update/deformation checks and Android bake dependency; no runtime pass or new performance number. |

Provisional 11/15, not a base choice or implementation authorization. No inference about B/C.

## Load-bearing facts checked by parent

Installed SCNShadable.h lines39–86 confirms handleBindingOfSymbol has no effect for shader-modifier symbols and its binding-block route is OpenGL/GLES-only. This supports rejecting that specific renderer-local uniform shortcut; it does not prove every possible simpler isolation design impossible.

Current accepted58 RenderTargets.swift lines445–628 confirms sibling SCNViews share the canonical scene, paused/on-demand; construction and pokes go to main after the host frame; an existing generation and camera-pose handoff protects replacements. This makes an assumed global material swap around one host draw unsafe for those actual later draws. Reusing the handoff for all diagnostic attachment data is candidate A's proposal, not proven existing capability.

## Questions for later comparison

Can another candidate preserve canonical capture input without mirroring every draw/camera? Does it identify an actual safe render boundary rather than promise temporary shared-material restoration? Does it keep current authored factors, texture arrivals, clones and variants authoritative? Does it preserve skin/morph/instances using current native draw owners rather than duplicate their resolution?

No source changes, tests/builds/devices or external actions. A142 remains reserved. Wait for other candidate completions; cross-judge only after all outputs are complete.
