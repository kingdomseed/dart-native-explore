# Design selection rubric

Score each candidate 0–3 on five criteria; cite concrete source paths and sketch behavior.

1. Caller simplicity and scope. One coherent channel/independent wire API, clear semantics, no authored pollution or 0.24/W28 expansion.
2. Ownership and lifetime. Single source of truth, attach/load/recreate/update/off/dispose policy fits actual existing routes without snapshot staleness.
3. Rendering correctness. Sampled inputs, explicit normal/depth/display meaning, actual mesh edges; addresses reachable material consumers and offscreen isolation with source-backed boundaries.
4. Implementation depth and proportionality. Existing owners do the work, small public surface, no speculative registry/protocol/framework or duplicate renderer architecture. Flags from architect references are resolved.
5. Proof and uncertainty. Separates actual one-quad proof from source feasibility, gives decisive bounded next native checks and acknowledges Android/other-path blockers without inventing a pass.

Prefer the smaller clean ownership boundary at a tie. Compare structurally different complete alternatives before selection. Candidate generation diversity is within the Codex family, not provider diversity.
