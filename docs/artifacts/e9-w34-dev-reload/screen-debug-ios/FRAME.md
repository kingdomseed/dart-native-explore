# W34 mesh/material debug views

The operator approved finishing W34 mesh/material views with native particles
explicitly unsupported on 2026-10-27. This resolves the particle scope question,
not the native implementation or verification gates. Native particle rendering
is excluded from the isolated channel presentation. Do not create another
particle simulation or renderer. Wireframe makes no particle-topology promise.

Use Candidate B from `/private/tmp/dart3d-e9-debug-design-20261027/candidate-b/design.md`
with the cross-judge's pre-begin Android material preparation rule. The design
exploration is complete. No new architecture tournament is needed.

The view owns one `SceneDebugView` value with a closed `SceneDebugChannel` enum
and an independent wireframe boolean. Use the existing tag-6 view configuration.
Keep settings out of documents and controllers. Full off shows current authored
state. Authored render targets and baked captures remain canonical.

The first implementation unit is iOS screen isolation for a normal-mapped PBR
mesh, all five channels, and filled wireframe. Prove the new ownership boundary
with an authored render target that shares the live scene and camera. The
parent owns simulator pixels, transfer checks and independent Codex review.
Do not claim full family coverage from this unit.

Channel semantics follow B. Normals are resolved view-space normals mapped by
`0.5*N+0.5`. Metallic and perceptual roughness are sampled material inputs.
Base color is the factored, pre-lighting input. Depth is positive axial eye
distance `d` displayed as `d/(1+d)`. Numeric channels use a fixed identity
linear output with one sRGB transfer, with artistic screen effects disabled.
Wire-only uses current authored fill and display settings.

For later catcher coverage, use explicit opaque receiver inspection for normal,
depth and topology, with absent PBR inputs marked magenta. The cross-judge
accepted that semantic under W34's original floor. Do not inherit B's unproven
promise to preserve shadowOnly footprint alpha in diagnostics. Ordinary masks,
blend and sprite coverage remain required by their actual material families.

Keep the authored iOS scene as the only simulation owner. Screen-only material
attachments must not mutate authored material arrays, lights, cameras, skinners,
morphers, background, or captures. Use current native attachment identities and
presentation transforms. No per-frame clone of the entire import/simulation,
new synchronization system, shader translator, renderer fork, generic modifier
registry, or saved-on-entry material restore store.

A142 is reserved for the operator. No Android or physical iOS device use.
The approved simulator is parent-owned and currently shut down. Workers must
not boot, query, open, drive, or record any device. Host-only builds are allowed.
PR65, tablet checks, final T2/T4, and whole-Track-E completion remain open.
