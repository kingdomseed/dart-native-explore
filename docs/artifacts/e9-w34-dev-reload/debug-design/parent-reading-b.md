# Parent reading of candidate B

Read all378 lines of candidate-b/design.md, retrieving the family/lifetime section separately after output truncation. Adjacent preservation-receipt.json records all58 imported files and six locks unchanged. Its design SHA65760c207d8e01db1a8a2883fb6244e325acb04c5efcc0b881643415880ed656 matches the parent's direct hash. No production source changes or other candidate output writes.

## Provisional rubric scores

| Criterion | Score | Reason |
| --- | ---: | --- |
| Caller/API/scope | 3/3 | One immutable widget value combines a closed channel enum and independent wire flag. No document or controller debug state, and release opt-in stays usable. |
| Ownership/lifecycle | 2/3 | Current authored inputs remain authoritative; view lifetime survives content reload and avoids stale restoration. iOS attachment projection still carries significant reconciliation/handoff work; native particles have no established projection route. |
| Rendering correctness | 2/3 | Explicit sampled meanings, view-space normal, per-surface depth, family coverage and sRGB transfer. Android binds actual existing renderables and appends real edge primitives, retaining deformation owners. Submission/restore timing and particle/catcher coverage are explicitly unproven. |
| Proportionality | 2/3 | Android avoids A's per-camera geometry projection; extra LINES slots stay in existing geometry owner. iOS projection remains substantial. No extra synchronization is pre-authorized if that shape fails. |
| Proof/uncertainty | 3/3 | Explicit capability blockers and smallest next experiments, no native runtime claim, no invented performance threshold or whole-W34 pass. |

Provisional12/15. This is not a base choice; C and independent cross-judge remain outstanding.

## Parent source checks

Accepted58 iOS FsceneRealizer.swift lines5718–5737 states the native SCNParticleSystem rendering/simulation owner. Lines6119 onward create that system, line6269 assigns particleImage, and line6375 attaches it to its source node. These are not ordinary SCNMaterial mesh consumers. B correctly treats faithful live-particle projection as unestablished. This also pressures A's broader claim that every generated draw can be exposed through existing attachment owners; source does not yet establish that for SceneKit particles.

Accepted58 Android Dart3dView.kt lines5835–5884 confirms baked captures before beginFrame, due targets before screen passes, then endFrame. This supports B's proposed serial screen-only partition in principle, but does not establish when Filament snapshots changed material bindings, edge index counts or display parameters. Uniform preparation before beginFrame is a concrete existing concern from the baked-catcher correction. Any selected B implementation must prepare/upload diagnostic resources at the correct existing frame boundary, not infer that all setters are safe after beginFrame. B acknowledges this native proof gap rather than claiming a pass.

## Comparison questions retained

The API wrapper versus two flat props is minor; the meaningful difference is Android reuse of actual renderables rather than a second set of screen attachments. B's fixed d/(1+d) depth transfer and A's camera-near/far-linear transfer differ semantically; synthesis must choose one explicit rule, not expose both without a caller need. Both need a source-supported iOS isolation route that preserves existing native particles and coverage. No hidden pass-through/drop of particles is accepted.

No builds/tests/devices/external actions. A142 remains reserved. No cross-judge until all candidates complete.
