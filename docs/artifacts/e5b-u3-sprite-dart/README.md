# Standalone sprite Dart adapter and fixture

The seven-file Dart unit passed independent Codex source review on 2026-10-27.
It adds `D3SpriteMaterial`, `D3SpriteBlendMode` and the separate `u3-sprite`
verification fixture. Existing `D3BillboardProc` remains the geometry API.
Native material implementation and runtime acceptance are separate gates.

The adapter returns a fresh `MaterialResource` with caller-owned ID and type
`d3:sprite`. It encodes linear tint, optional image/render-texture reference,
optional atlas rectangle and alpha/additive selection. It allocates no IDs and
owns no document or timing state. Tests exercise the actual writer/reader and
controller mutation channel.

The fixture includes marked alpha-zero/half/opaque texels, independent and shared
materials, an untextured control, translucent overlap, opaque occlusion and a
shadow-casting control. Manual and timed frame steps share one material-upsert
path. Scene changes and disposal cancel the caller timer. A render-texture boot
variant uses existing resources and views with ordinary source geometry.

The parent ran all six adapter and eight fixture tests successfully. After
removing five narrative comment lines and an assertion on an unrelated empty
document, the six adapter tests passed again. The worker's retained receipts
record 42 package tests, 61 example tests and clean targeted analysis. Those
receipts establish Dart behavior and transport, not native material behavior.

Independent Codex review verified all seven owned and eleven unowned hashes and
the patch hash, traced the public paths, and found no material reachable P1/P2
defect. The reviewer ran no builds, tests or devices. No provider diversity is
claimed. Both lockfiles remain unchanged.

The current integration patch is
`/private/tmp/dart3d-e5b-sprite-dart-fixture-20261027/parent-r1/owned.patch`,
relative to the supplied corrected fourteen-file baseline. SHA-256:
`b6778b05968c092e495a70e6414bdf8b1d09f3dd0f5bb1336fa780af73199466`.
The corresponding seven-file source archive SHA-256 is
`f9d9888823246d1a6b4fb568593d475cbf47e9f56b137cedf69a027108fbf30f`.
Replay proof, current hashes and parent test logs are retained beside it.

Native builds, material baking, actual UI layout, image/render-target sampling,
alpha/additive RGB and target coverage, depth, shadow exclusion/restoration,
native teardown and device verification are NOT_RUN for this unit. The public
material documentation defines the intended contract; these tests do not prove
that the native implementations satisfy it.
