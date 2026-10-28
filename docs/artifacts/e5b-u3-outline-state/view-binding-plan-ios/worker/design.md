# iOS U3: bind a detached selection mask to each rendered view

Recommend one **capture-owned mask and one final technique pass per actual view**. Keep the existing native selection map and lifecycle B. Bind the mask to the main screen, each screen sibling, and each texture-view renderer only when its target is due. This is a source-only sketch; its screen submission ordering and deformation behavior remain capability gates.

## Caller and current path

The caller already uses the accepted facade:

```dart
controller.setNodeHighlights({picked.node: Vector4(1, 0.65, 0, 1)});
controller.setNodeHighlights({picked.node: null});
```

`scene_controller.dart:403–428` copies scalars into one existing command mutation. `Dart3dPlugin.swift:47–77` copies incoming bytes and enqueues work; `SceneViewHost.swift:1129–1147` drains it in delivery order. `applyCommandJson`, at `1608–1643`, parses finite RGBA, ignores a non-null selection for a missing node, and calls `SelectionOutline.apply`. The only authoritative color map is `SelectionOutline.swift:13`; it currently has **no rendering read path**. The sketch adds an internal read path, without changing the facade, transport or authored document.

Keep the existing clears at explicit load (`SceneViewHost:1410`) and destruction (`965`), removal of actual removed IDs (`2021`), and retention/pruning after deferred realization (`1177`). An attachment rebuild changes derived render objects, not selection lifetime. These are current source facts and the selected [contract](/private/tmp/dart3d-e5b-outline-design-20261027/synthesis.md), not new policy decisions.

## Choose at the binding boundary

| Route | Binding and ownership | Decision |
| --- | --- | --- |
| Detached mask renderer, consumed by a final pass in each consumer's technique | Selected native draws are represented in a private scene. Each existing view runtime owns its camera, mask/depth textures and consumer technique binding. Ordinary draws keep their attachments. | **Choose.** Fits current `SCNView` and `SCNRenderer` consumers and W34's detached attachment pattern. Screen submission ordering still needs proof. |
| Detached mask followed by an explicit Metal composite into each consumer's final attachment | Keep the same selection and detached mask ownership, then append a custom Metal encoder after ordinary rendering instead of using a technique tail. | Reject at this boundary. Texture views expose their command buffer and attachments, but the screen hooks expose an active encoder/pass rather than a command-buffer handle or a documented final post-resolve attachment. Making all screens expose that boundary would require changing presentation ownership. |

Both routes retain lifecycle B. Neither changes native selection-map ownership. A complete replacement of screen presentation with a manually managed drawable pipeline is outside this binding unit.

Installed `SCNTechnique.h:25–26,97–106` documents pass order and `COLOR` inputs/outputs. Its `technique` property is **copy** (`316`). Therefore configure the technique actually installed on each consumer after assignment; do not assume updates to the original builder object update the renderer. `SCNView.h:59` and `SCNRenderer.h:24` both declare technique support. Runtime execution of the proposed texture technique is still unproven.

## Internal shape, with no implementation

These declarations describe responsibilities, not compilable additions. All live in the iOS implementation. Existing object identity is a cache key only; there is no new node ID, frame revision or wire type.

```swift
extension SelectionOutline {
    func forEachActive(_ visit: (UInt64, LinearRGBA) -> Void)
}

// Captured on the host render queue after native evaluation.
struct OutlineFrame {
    let time: TimeInterval                 // existing host callback time
    let draws: [OutlineDraw]               // derived, current-frame rows
    let poses: [OutlinePose]               // required transform/bone paths
}
struct OutlineDraw {
    let source: ObjectIdentifier           // current native draw object
    let geometry: SCNGeometry              // detached mask template
    let color: SelectionOutline.LinearRGBA
    let skin: ScreenDebugFrame.Skin?       // same data shape, mask geometry
    let morph: ScreenDebugFrame.Morph?     // sampled weights/targets
}
struct OutlinePose {
    let source: ObjectIdentifier
    let parent: ObjectIdentifier?
    let transform: SCNMatrix4
    let pivot: SCNMatrix4
    let hidden: Bool
    let opacity: CGFloat
    let category: Int
    let order: Int
}
struct OutlineCamera {
    let transform: SCNMatrix4
    let camera: SCNCamera                  // detached projection/settings
    let layerMask: UInt32
}
struct OutlinePixels {
    let width, height: Int                 // actual composite raster
    let outputWidth, outputHeight: Int     // screen physical / target texels
}

final class OutlineAttachments {
    func capture(host: SceneViewHost, selection: SelectionOutline,
                 time: TimeInterval) -> OutlineFrame
    func clear()
    // Private geometry/template caches, following native attachment identity.
}
final class OutlineViewBinding {
    private let scene: SCNScene
    private let camera: SCNNode
    private let renderer: SCNRenderer
    private var nodes: [ObjectIdentifier: SCNNode]
    private var mask, depth: MTLTexture?
    private var pixels: OutlinePixels?
    private var maskProperty: SCNMaterialProperty?
    private var installedTechnique: SCNTechnique?

    func apply(_ frame: OutlineFrame, camera: OutlineCamera)
    func encodeMask(at time: TimeInterval, pixels: OutlinePixels,
                    commandBuffer: MTLCommandBuffer)
    func bind(to installedTechnique: SCNTechnique)
    func retire(into host: SceneViewHost)
}

// Extend the existing technique builder, with an explicit composite-only case.
// nil look = no artistic resolve; it does not mean a diagnostic resolve.
extension ToneMapTechnique {
    static func makeViewTechnique(device: MTLDevice,
        look: StageResolve?, bloom: BloomChain?, outline: Bool) -> SCNTechnique?
}
```

The draw's `source` joins its pose row. Skin bones/skeleton join pose identities just as `ScreenDebugFrame.Skin` does today. Keep the original bone order. Do not generalize W34 into a shared presentation framework as a prerequisite; reuse the demonstrated data shape locally. The exact extraction and invalidation code remains unwritten.

`SceneViewHost` owns one `OutlineAttachments` producer and an optional single-screen binding. Each texture `ViewRec` gains an optional binding beside its renderer/MSAA state. The main-thread sibling tuples gain an optional binding beside their `SCNView`. Extend the existing `siblingPoseSnapshot` with `OutlineFrame?` and per-sibling camera samples; keep its existing `screenSubviewBuild` gate and single latest-snapshot behavior. Capture the leading real camera too: today's `syncScreenSubviews` deliberately omits its entry from `poses`.

These are derived native attachments. A frame may carry copied colors across the existing render-to-main handoff; no second selection map survives independently of that frame. No retained Dart map, new work queue, clock, lock or selection registry is needed.

## Attachment membership and deformation

Resolve each active existing node key through `nodesById`. Include its actual geometry, every immediate realizer-owned `d3prim:i` mesh primitive, and all geometry elements of those draws. `FsceneRealizer:5205–5246` establishes that ownership. Include the entire baked `d3:instances` geometry (`2349–2399`), including retained reflected instances; a hit's instance index does not create independent highlight membership. Do not reconstruct instances from the document or reintroduce instances already truncated by the native bake budget.

Exclude arbitrary authored descendant geometry, shadow-only blend-caster proxies, cameras and lights. Ancestors and bones enter as transform-only rows, not selected draws. A selected group without owned drawable geometry produces no silhouette. Internal primitive membership uses the existing realizer convention, not fixture names or recursive descendant selection. Other internal emitters, such as `d3trail:` ribbons, need their own native-owner membership audit before any whole-U3 claim; this unit does not silently select them by walking children.

Capture after `updateLods`, `updateCameraFacing` and `syncBlendCasters` in `didApplyConstraintsAtTime` (`SceneViewHost:5758–5764`). Thus the mask uses the native geometry currently bound, including the selected LOD and rebuilt billboard/line geometry. Current facing geometry is generated once from the host camera (`5779–5788`); this sketch matches that current ordinary draw in each view. It does not promise newly camera-specific billboard geometry for siblings or targets.

Copy geometry before installing mask materials. `SCNNode.h:88–93` says clone shares attachments; cloning nodes alone is insufficient. Capture presentation transforms, pivots, inherited visibility and current category information. Preserve ancestor visibility rather than flattening visible child geometry out of a hidden branch. Mask coverage follows the pinned flat-geometry pass, so authored fragment opacity/cutouts do not become a new mask filter. Although the attachment frame carries native opacity, whether SceneKit multiplies it into the flat shader output needs a parity check against the pinned coverage policy; copying that field alone does not establish correct coverage.

For every skinned primitive, create a private `SCNSkinner` over private geometry, private bone nodes and private skeleton. Carry bone weights/indices, inverse bind transforms and base bind transform. Keep skeleton nodes strongly in the binding: `SCNSkinner.h:28` declares `skeleton` weak. Current native primitive skin attachment is at `FsceneRealizer:6731–6822`; W34's detached reconstruction is at `ScreenDebugPresentation:288–305`.

For morphs, carry current targets, presentation weights, calculation mode and normal policy into a private morpher (`ScreenDebugPresentation:203–207,308–320`). Do not attach the live morpher or mutate its targets. Read-only stream/target storage can remain retained; private nodes, geometry material arrays, deformers and material instances cannot be concurrently mutable across bindings. Source changes replace detached templates; do not mutate a template already handed to main. Cache against actual source attachments and current values, pruning unused entries, following `ScreenDebugAttachments:141–169,233–235`. This avoids the prototype's unconditional graph reconstruction without inventing revisions.

Only the private mask scene is updated to evaluate its copied skin/morph pose, using the existing host time. It contains no copied animation players, physics bodies, actions or source delegate. The ordinary target uses its existing render-only call. `SCNRenderer.h:53–57` documents update-and-render; `73–77` explicitly says render-only does not update animation or physics. Correct copied deformation under that sequence, especially combined skin/morph, remains a runtime gate. Material-driven vertex displacement that cannot be reproduced from current native vertex attachments is an exact missing capability, not permission to draw an undeformed fallback.

## Per-view binding and queue handoffs

| Consumer | Preparation and ownership | Encode and consume |
| --- | --- | --- |
| Main screen, single-screen mode | Render queue samples the actual host point of view, effective camera mask and the latest main-thread metrics snapshot. Host binding owns the private graph and textures. | In `didApplyConstraintsAtTime`, commit mask work on the host's existing `commandQueue` before returning to its draw; the host technique reads that binding's mask in its final pass. |
| Each screen sibling | Render queue captures selected attachments plus each view's camera/layers into the existing pose snapshot. Main applies that snapshot, camera and private binding together in the existing disabled-actions transaction in `pokeScreenSubviews`. UIKit dimensions are read on main. | Main encodes and commits that sibling's private mask on **that sibling's** existing `commandQueue`, installs its mask sampler, then requests its existing on-demand draw. No host-mask sharing or assumption that sibling queues equal the host queue. |
| Each due texture view | `renderDueTargets` remains the only admission point. The corresponding `ViewRec` binding receives that camera, `layerMask`, actual target dimensions and current attachment frame. | Inside `renderTextureView`, encode mask before the ordinary renderer on the **same existing command buffer**. Its composite-only technique consumes the mask before the existing MSAA/final target store completes; commit once. |

This is one binding route with the existing owners' submission boundaries. It introduces no additional public view scheduler. The texture-target mask/composite work is inside the existing due branch (`RenderTargets:262–295`), never an unconditional per-frame target capture. `setNodeHighlights` does not mark a target dirty. Fresh targets already start dirty; existing `render` marks dirty (`SceneViewHost:3092–3104`). A clean manual target intentionally retains its old pixels, including an old contour, until its next due draw. Clear commands affect the screen now and the target on its next scheduled draw.

Use the consumer's current camera projection, near/far planes, projection direction and pose with its own aspect/dimensions. Attach the private camera to its mask scene before setting world pose. Apply the per-view layer mask to that private camera and preserve selected nodes' native categories. Do not overwrite authored node categories or borrow a reserved category bit. Keep existing per-target camera exposure save/restore behavior (`RenderTargets:318–332`) for the ordinary pass; the flat mask has neutral camera effects, no sky/fog/light contribution and transparent zero clear with independent depth cleared to one.

**Screen ordering is a hypothesis.** Metal's installed `MTLCommandQueue.h:16–18` describes a serial command-buffer queue, but it does not establish when SceneKit enqueues its hidden screen command buffer. `SCNSceneRenderer.h:245–284` exposes a current encoder/pass and queue, not a consumer command-buffer handle here. Current offscreen source comments assert frame-boundary ordering; that is not proof of the proposed producer/consumer dependency. `didRenderScene` also does not document GPU completion. The next probe must establish that each screen technique samples its matching completed mask, including on repeated set/clear and camera motion. If this enqueue order fails, this route is blocked at the screen submission boundary. Do not add synchronous waits, cross-queue signals or a replacement presentation pipeline in this unit.

Normal siblings still draw the shared live scene, while their cameras and the mask use a host snapshot. The current hooks do not guarantee that those two draws cannot straddle another host update. W34's isolated siblings have detached base attachments, which gives a stronger snapshot boundary. Exact ordinary-sibling pose/mask alignment is therefore another proof gate; a green static-camera image cannot close it.

## Composition, color and width

Build one technique definition/library containing the existing bloom/resolve functions and the outline tail. Rebuild that combined binding whenever `applyToneMap`, `applySiblingResolve`, layout, AA or debug mode replaces a view's technique. Bind samplers and uniforms to the installed technique copy. Per-view mask/depth textures, nearest/linear sampling decisions and dimensions cannot be shared accidentally through a host-only technique. Use a linear RGBA mask format capable of carrying multiple colors and fractional coverage, provisionally `rgba16Float`, plus private depth. Encoding, range and precision require GPU evidence.

For screens: ordinary draw → existing artistic resolve/bloom/grade/LUT, or W34 diagnostic identity resolve → outline tail. The outline receives the resolved image and is unaffected by artistic grading. For texture targets: ordinary existing offscreen image → outline tail → existing target store. **No artistic tone resolve is added.** `SceneViewHost:424–427` deliberately excludes targets; `RenderTargets:315–327` uses unpacked exposure and white point one. A composite-only technique must preserve that behavior. The current screen's `COLOR` read/write pattern (`ToneMapping:443–535`) supports the sketch; its use on the texture/MSAA path still needs execution proof.

Follow the pinned `flutter_scene-0.23.0` policy exactly: `object_filter.dart:165–170` passes RGB and replaces highlight alpha zero with one. Other alpha values pass through; `null` clears selection. The mask shader writes that RGBA (`flutter_scene_mask.frag:16–17`); it does not sample authored cutouts. Use overwrite rather than blending for mask values, with selected-only depth, effective winding and double-sidedness (`object_filter:109–113,158–170,208–258`). Do not copy the old probe's unconditional two-sided white material. In an UNORM attachment representable-range conversion is a separate platform behavior; do not describe the vendor encoder as explicitly clamping inputs.

The pinned composite uses a radius-three circular neighborhood, greatest neighbor coverage, center coverage below `0.001`, and neighbor coverage above `0.001`. Strict-greater comparisons determine ties in its fixed loop order. The contour writes neighbor RGB and **alpha one**; other pixels return the original RGBA (`flutter_scene_outline.frag:28–59`). Disable blend/depth for the fullscreen tail. Port its sampling policy intentionally—the pinned pass uses linear clamp sampling—rather than inheriting the old white-mask threshold or fixed gold color. Linear RGBA mask values must reach the consumer's shader working/output color convention without double sRGB conversion; installed `SCNSceneRenderer.h:224–229` explicitly requires matching shader components to `workingColorSpace`. Colored, overlapping and fractional-coverage fixtures are proof gates.

Three pixels means **three physical output pixels**, not UIKit points or three low-resolution render texels. Texture targets use target texels; `renderScale` and viewport are intentionally ignored there (`RenderTargets:225–240`). Screen viewport placement uses device scale, while rendering quality changes `contentScaleFactor` (`688–705,725–752`). Carry both actual raster and final physical dimensions. For differing resolutions, the intended circular sampling offsets are measured in output-pixel units, independently in x/y. Merely using radius three at reduced render scale gives the wrong width.

The source does not expose a proven full-physical-resolution technique stage after SCNView upscaling. Sampling the correctly sized mask in a lower-resolution tail alone cannot guarantee an exact three-pixel displayed border. Start the capability probe at render scale one. Physical width at other supported scales remains blocked on proving actual technique/output raster placement, or identifying a native post-upscale binding seam. Do not silently force render scale one in production or expand this unit into a new presenter.

## W34 isolation and retirement

When a diagnostic channel is active, keep the accepted black backing, detached `ScreenDebugPresentation`, private skin/morph/light ownership, identity resolve and wireframe behavior. Append the outline only to the visible diagnostic sibling's technique. Derive membership from original node ownership and sample both diagnostic attachments and outline attachments at the same host boundary; diagnostic material colors are not selection colors. Do not put mask geometry into the diagnostic scene, modify its cached materials, change authored light/camera attachments, or add a debug/outline operation. In normal split mode the host's blank-camera/background pass gets no contour; every visible sibling gets its own binding.

Retire bindings when existing view lists are replaced (`installViews`), targets are replaced/removed, single/split mode changes, scene install tears down target runtime, or the view detaches. Extend `retireViewRuntime` and `teardownRenderTargets` (`RenderTargets:437–462`). Main removes sibling bindings with `teardownScreenSubviews` after invalidating the existing pose snapshot; return any host retirement request through `enqueueSceneWork`. Clear attachment producer caches on scene replacement without changing lifecycle B's deferred-realization retention. Empty selection disables the consumer tail/binding so stale masks cannot appear on subsequent screen draws; a clean manual target retains its stored image as specified above.

Keep copied geometry, flat materials, skin/morph nodes, camera, sampler property, technique and old textures alive through their users. The flat mask borrows no authored color/opacity textures; its sampler property retains only its private mask texture. The current graveyard retains objects for two drains (`SceneViewHost:1032–1040,1127–1141`); it is an existing heuristic, not a GPU-completion guarantee for delayed sibling draws. Retaining command buffers retain encoded GPU resources (`MTLCommandQueue.h:29–34`), but that does not prove SceneKit CPU graph-storage lifetime. Use the existing retirement path as the initial candidate, and gate resize/rebind/detach safety on actual completion/lifetime evidence. No arbitrary longer delay, pool, retry or new retirement clock is proposed. If those users outlive the available retirement boundary, integration is blocked on a precise native completion/lifetime hook.

## Smallest next capability probe and handoff

**The current manual target cannot expose the transparent-background alpha oracle.** Every target view clears RGBA to `(0,0,0,1)` (`RenderTargets:366–385`), even successive views of the same target. Do not change this to load previous views, or infer transparency from the absence of a sky. Screen `backgroundColor` alpha is UIView state, and diagnostic siblings have an opaque black backing (`RenderTargets:535–537`); neither establishes render-attachment alpha. The current tone shader preserves its input alpha (`ToneMapping:354–400`), but cannot recover alpha already cleared to one.

Recommend the following single, disposable iOS capability instrument in a later authorized unit, without production seams or public protocol additions:

1. Use two distinct screen cameras with deliberately different silhouettes/layer membership, plus one manual texture target with its own camera and dimensions. Both screen views are siblings in this setup; also run the same instrument in existing single-screen mode to check the host binding. Use actual public `setNodeHighlights` batches and null clears for at least two independently colored logical nodes. Verify each view's mask against its camera, layers and dimensions, including an internal primitive and a baked batch without selecting an authored child.
2. Consume the target's initial dirty draw. Freeze ordinary scene inputs, set/clear highlights and advance screen frames without `render(target)`; target bytes must stay unchanged. Then use the existing public render request and verify only its due draw picks up current selection. Screens must update without waiting for target admission.
3. Capture matched off/control/outlined RGBA attachments, not just screenshots of a texture displayed over opaque UI. Outside the computed contour, compare every RGB/alpha component under the same native output representation; on a contour require the selected neighbor RGB and alpha one. The ordinary manual target checks preservation against its existing opaque-clear baseline. Include repeated camera/set/clear transitions to detect old or wrong-view masks.
4. Supply a **private compositor-only transparent input** in that disposable instrument: a known premultiplied base containing zero and fractional alpha, fed to the identical outline tail with a captured mask. Verify unchanged RGBA outside contours and alpha one on contours. This closes only the compositor arithmetic/encoding oracle. It does not prove public target transparency or full scene-to-transparent-screen composition. If the instrument cannot reach/read that input/output boundary without a production seam, stop and report the missing private RGBA capture capability. Do not add a public transparent-target feature.

Freeze pose, exposure and effects for decisive outside-contour comparisons. The default-scale three-view result cannot approve reduced-scale width, animation alignment, all skinners/morphers or retirement safety. Those remain named production gates, alongside technique-copy rebinding, texture/MSAA execution, colored coverage/working-space behavior and W34 diagnostic coexistence.

Hand off this recommendation and the receipts for independent review before any implementation. Android capability remains a prerequisite for production integration; the A142 stays reserved. Builds/tests, shader compilation/execution, GPU ordering, runtime, devices, Android, performance and whole-U3/T2/T4 are **NOT_RUN**. No provider-diversity or independent-review completion claim is made by this worker.

## Source and preservation receipts

All worktree references above mean `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-15abcc3d`, final66 imported over HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. Vendor files mean `/Users/jasonholt/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0`; installed headers mean Xcode's `iPhoneOS.sdk/System/Library/Frameworks/{SceneKit,Metal}.framework/Headers`. Exact source paths and hashes are recorded in adjacent `source-receipt.json`.

The old probe's source and `ios/README.md` in `t3-852ea54b` were read as historical, bounded evidence only. Its host-only binding, sibling refusal, recursive fixture selection, per-frame graph rebuild, synchronous wait and preserved contour alpha do not define this design. Its reported white/gold single-view result is not current66 runtime proof.

`import-receipt.json` records archive verification, all 66 file hashes and six preserved locks. `preservation-before.json` records every pre-import file; `preservation-receipt.json` records the final comparison of imported, unowned and locked paths. Imported context is retained unchanged. No production/prototype edits or scratch outputs remain in the worktree beyond that authorized overlay.
