# U3 outline: per-view binding preparation

Goal: finish the existing picked-node outline contract, beginning with the missing
renderer boundary. This step writes a source-grounded binding sketch only.
Production integration still waits for the selected Android capability gate.
The A142 is reserved; no devices, builds or tests belong to this sketch.

The user authorized finishing Track E, bounded units and Codex review. Existing
selection ownership is settled in
/private/tmp/dart3d-e5b-outline-design-20261027/synthesis.md. Do not reopen it.
Native SelectionOutline owns the only authoritative node-to-color map. Public
SceneController.setNodeHighlights sends a batch on the existing command path.
Actual removal/explicit scene load clear it; deferred realization retains then
prunes. Authored material, animation, physics and document ownership stay put.

Current source is the final66 packet at
/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e9-w34-dev-reload/live-catcher-ios/source/source.tgz
SHA256 f5a65f8c778846820e31a4cc6bf9d71134c608ff94eb7151cae4ca4221968fae.
Base HEAD 2f38e4e33f0b1cb678bc408a42d069c796cefc12. This packet includes accepted
W34 screen isolation, per-sibling tone resolves, current detached geometry and
native-light ownership. Parent writer remains read-only for the next worker.

Current owner map (parent explorer, source only):
- SelectionOutline.swift:13 private colors; no render-facing read path.
- SceneController:403 -> SceneViewHost:1608 public ingress; lifetime hooks at
  SceneViewHost:965,1177,1410,2021.
- SceneViewHost.didApplyConstraints:5758 samples after LOD/facing/blend proxies.
- FsceneRealizer mesh:5205 owns primitive0 + immediate d3prim:i children;
  instances:2349 owns the baked batch. Arbitrary authored descendants excluded.
- ScreenDebugPresentation:190/288 shows detached skin/morph attachment ownership.
- RenderTargets.renderDueTargets:262 owns scheduling; renderTextureView:298 owns
  each due camera/layers/dimensions/command buffer. No forced manual target draw.
- RenderTargets.syncScreenSubviews:609 captures per-view cameras/frame, then
  pokeScreenSubviews:649 applies on main before draws.
- ToneMapTechnique.make:443 and applySiblingResolve:472 build current resolves.
  Texture targets intentionally have no artistic resolve.

The old probe in t3-852ea54b proves only single-view white-mask/gold outline,
selected copied skin/primitive/130instance fixture coverage and measured3px
width. It refuses siblings, uses fixture names/recursive descendants, binds
only host.technique, preserves base alpha on contours, has no morph path,
recreates copied graphs per frame and synchronously waits. It cannot be grafted
as production. Source and evidence are under that checkout's
 docs/artifacts/e5b-u3-outline-probe/ios/README.md and
 dart3d/ios/Classes/SelectionOutlineProbe.swift.

Design task: choose one internal per-view mask/composite binding route across
main screen, every sibling and each due texture view. Keep selection state in
its reviewed module and evaluated attachments in native owners. Compare two
structurally distinct routes only at this missing binding boundary; no new
public API, wire operation, ID/revision protocol, queue/clock or retained Dart
selection map. Honor per-node primitive/instance ownership and pixel width.
Show function signatures, ownership/queue handoffs, material/texture lifetime,
resolve placement, teardown and how existing target scheduling is preserved.
Name empirical/installed-platform facts separately from assumptions. If current
hooks cannot establish an ordering/alpha/capture promise, state the exact proof.

Next candidate capability proof: two different screen cameras plus one manual
texture target; use real public set/clear; check per-camera mask, no target
refresh until due, outside-contour RGB/alpha preservation and opaque contour
alpha on transparent background. Confirm whether current target clear policy
supports that alpha oracle before promising it; do not add a public transparent
render-target feature. Leave every unrun lane NOT_RUN. This is preparation,
not production renderer approval or whole U3 completion.

Overlap check this turn: GitHub connector searches open title-outline PRs and
remote branches named outline returned none. Local outline/highlight branches
are existing probe/state/review branches. Linear dart3d lookup found only the
completed research issue MYT-1349, which was not analyzed. Linear field-notes
get_agent_context returned Tool not found; no fallback or external write used.
No PR65 list/watch/link operation occurred.
