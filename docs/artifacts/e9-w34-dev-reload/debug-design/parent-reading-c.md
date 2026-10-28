# Parent reading of candidate C

Read all318 lines of candidate-c/design.md. Retrieved risks/sources separately after initial output truncation. Its direct SHA0e8baeae2452b4a8574bff4e656d61dac749bf4f65b79dac1a95423f0f31d3e0 matches preservation-receipt.json. The receipt records unchanged58 import and six locks; this remains runner-produced preservation evidence. No implementation or device use.

## Provisional rubric scores

| Criterion | Score | Reason |
| --- | ---: | --- |
| Caller/API/scope | 3/3 | Closed enum and two widget props, explicit off wire defaults, no scene/controller pollution or second debug API. |
| Ownership/lifecycle | 2/3 | Canonical owners remain current; diagnostic companions are attached at actual bindings. Explicit offscreen drawing and immutable screen-image handoff avoid shared material mutation. Borrowed deformation and per-draw lifecycle still require implementation proof. |
| Rendering correctness | 2/3 | Exact sampled meanings and transfer, real triangle edges and explicit capability blockers. Native particles remain unresolved; catcher opacity semantics deliberately differ from A/B. |
| Proportionality | 2/3 | Explicit target draws reuse existing renderer/capture APIs and may avoid copying whole skin/bone hierarchies. Android adds companion draws/private targets and moves due target submission while enabled, which must earn its cost against B's smaller binding route. |
| Proof/uncertainty | 3/3 | Names exact transfer/deformation/target-order/wire-proxy questions and never promotes the quad to production parity. No new performance number or general renderer rewrite. |

Provisional12/15, tied with B. No base selected; independent cross-judge next.

## Parent source check and comparison

Installed SCNSkinner.h explicitly states that baseGeometry changes affect all sharing nodes and per-node geometry is the material customization point. This supports C's proposed node-local diagnostic geometry with a shared skinner as a source-level route worth proving. It does not establish live pose/material sharing in a second renderer. That factual route is smaller than immediately reconstructing a copied hierarchy, but must not be treated as an existing GPU pass.

C uses explicit SCNRenderer target rendering and publishes completed screen textures, unlike A/B's direct diagnostic SCNView attachment scenes. Android C prepares standalone target draws outside the one swapchain frame; B proposes temporarily selecting current renderable materials/edge ranges during serial screen submission. These are structural differences, not enum naming differences. Judge must check actual pinned submission/upload semantics before preferring either.

Semantics still need synthesis: A depth is near/far normalized, B/C d/(1+d). A/B preserve shadow-catcher footprint coverage; C deliberately inspects an opaque receiver and uses a checker N/A instead of flat magenta. Ordinary off behavior is preserved in all sketches, but these debug policies are not interchangeable or runtime-proven. Don't silently combine them or label an inaccessible input absent.

C additionally calls out ordinary vertex-color ordering and native wire overlay on depth-only blend proxies as specific unproven paths. These are existing reachable owners, not permission for a new family renderer or broad acceptance matrix. All candidates acknowledge native particles; A's generic generated-draw language is less specific than B/C's actual SCNParticleSystem boundary.

All three converge on view-owned selection with canonical authored captures. Generation diversity is within the same Codex family. Cross-judge receives original rubric/candidates without parent provisional score files, to avoid anchoring.
