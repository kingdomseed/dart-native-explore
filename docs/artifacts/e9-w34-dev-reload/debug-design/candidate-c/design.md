# Candidate C: view-owned selection, isolated diagnostic presentation

## Usage (caller's view)

```dart
import 'package:dart3d/dart3d.dart';

// Both switches are explicit opt-ins, including in an Android release build.
SceneView(
  controller: controller,
  debugChannel: SceneDebugChannel.normals,
  wireframeOverlay: true,
)

// Ordinary rendering, with the latest scene/material state:
SceneView(controller: controller)
```

The choice belongs to the displayed view. Reloading its document keeps the choice. A null channel means ordinary filled rendering; wireframe is independent. There is no controller setter for the same operation, no scene property, and no implicit enablement by build mode.

Three adaptations of real current call sites establish the lifetime:

1. **Authored reload target:** `dart3d/example/lib/dev_reload_main.dart:27–76` already starts `DevSceneReload` in `initState` and builds its `SceneView` at line 59. Add screen state `SceneDebugChannel? channel` and `bool wire = false`; pass them to that widget. A selector callback calls `setState(() => channel = SceneDebugChannel.baseColor)`. The existing reload object continues preparing and applying document changes independently. The selector does not resend material resources or restart the watcher.
2. **Showcase material/animation inspection:** `dart3d/example/lib/showcase_scene.dart:1394–1405` builds a direct view for the material, sprite, atlas and tone fixtures. Pass the same screen's `channel`/`wire` fields there. Existing material edits and animation continue through `_controller`; selecting roughness does not pause them. Returning `channel` to null reveals their current values. This is an adaptation proposal, not a claim that these controls exist already.
3. **Gesture-driven showcase:** the other actual `SceneView` at `showcase_scene.dart:1423–1436` sits inside camera gestures and already opts into statistics through a compile-time value. Pass `channel`/`wire` to this call too. Camera movement changes the view-space normal display and depth without changing the selection. Both branches must receive the props; changing only the direct fixture branch would miss the ordinary showcase path.

A caller can set these props before loading anything, keep them while replacing the controller on that widget, and build them again after view recreation. Setting `debugChannel: null` while retaining `wireframeOverlay: true` restores ordinary fill while keeping edges. No caller manages native material restoration, render targets, or shader packages.

## Problem and recommendation

W34 requires five resolved per-surface channels and filled triangle wireframe. The existing view configuration route already has the right ownership and mount ordering. The hard part is isolating diagnostic material output from existing render textures, catcher bakes and independently scheduled screen siblings that share the same scene objects. Material-registry replacement cannot satisfy that constraint. [S1–S6]

Choose **view configuration plus a private diagnostic presentation pass**, derived from actual bound draw attachments after the existing animation/physics/LOD/facing work. Keep the authored scene as the simulation, resource and capture authority. Only screen presentation consumes diagnostic images. The extra attachments borrow existing geometry/deformation resources; they do not decode another scene, simulate another world, or implement another renderer. This costs a diagnostic draw while enabled, but establishes isolation structurally instead of relying on the timing of shared-material mutations.

This is a proposed architecture, not production acceptance. In particular, the current iOS native particle path exposes a capability gap described below. That gap prevents claiming general W34 completeness; it is not permission to replace the particle renderer or silently exclude it.

## Shape: types and signatures

Public Dart sketch, intentionally unimplemented:

```dart
enum SceneDebugChannel { normals, metallic, roughness, baseColor, depth }

class SceneView extends StatefulWidget {
  final SceneController controller;
  final SceneDebugChannel? debugChannel; // null = ordinary fill
  final bool wireframeOverlay;          // default false
  // Existing configuration fields remain here.
  const SceneView({
    super.key,
    required this.controller,
    this.debugChannel,
    this.wireframeOverlay = false,
    /* existing named parameters */
  });
  State<SceneView> createState() => throw UnimplementedError();
}
```

Mirror the two fields through the existing leaf/element. Extend its existing diff and `_config`; do not add a debug controller, notifier, stream, acknowledgement, revision or replay queue. Export the enum with the existing view exports. `SceneController`, `SceneDocument`, authored extension codecs and `commandAffectsDocument` gain no diagnostic state. This is a deep interface: two properties hide channel evaluation, pass isolation, actual-consumer binding and restoration. Callers still choose the diagnostic and independently choose edges; they learn no rendering stages. Per `boundary-discipline` and `single-source-of-truth`, native parses once and downstream code consumes typed selection.

Private viewConfig payload, always explicit:

```json
{
  "debugChannel": "normals",
  "wireframeOverlay": true
}
```

Ordinary defaults are `"debugChannel":"off","wireframeOverlay":false`, never null/absence as the clear operation. This follows the existing explicit quality reset, important because Android JSONObject drops null. Existing tag 6 remains the transport. On initial configuration from an older caller, absence initializes off/false; there is no second command op. Native decoding accepts exactly off plus the five channel names and a boolean; an invalid new value is a boundary diagnostic, not an unknown channel coerced into a plausible image.

Private native sketches illustrate responsibility, not a portable framework to introduce:

```text
DebugSelection = { channel: DebugChannel?, wireframe: Bool }

SceneViewHost / Dart3dView
  selection: DebugSelection                  // applied view setting
  debugPresentation: DebugPresentation?       // derived GPU attachments
  applyViewConfig(bytes) -> void              // existing boundary
  render...                                  // existing frame owner

DebugPresentation                             // one private platform module
  prepare(actual bound draws, selection) -> void [not implemented]
  render(active screen camera/viewports, existing time) -> screen images
                                                 [not implemented]
  releaseSceneAttachments() -> void            [not implemented]
  release() -> void                            [not implemented]

BoundDiagnosticDraw                            // owned beside its real draw
  borrowed geometry attachment
  borrowed skin / morph / instance attachment
  current material attachment owned by the same material/binding producer
  private diagnostic fill attachment
  private triangle-edge attachment when needed

Native material producer
  make/bind ordinary material and optional diagnostic companion
                                                [not implemented]
  // The same slot/factor setter writes both destinations.
  // There is no second owner of the effective value.
```

These names are private sketches. Swift types are `internal`/`fileprivate` as appropriate and Kotlin types `internal`/`private`; Dart wire maps remain in the existing internal protocol route. Do not export a generic `BoundDiagnosticDraw` API or a pluggable modifier registry. Material family and output purpose are closed private enums at existing material producers, not extensible public renderer options.

### Dominant data access patterns

* **Change the selection:** the widget diff sends one viewConfig; native updates one setting. Channel switches change diagnostic output selection, not authored resources. Lazily create presentation attachments when needed; off releases them through existing retirement rules. Native state is the applied value, not an independent user preference store.
* **Prepare a diagnostic frame:** enumerate the host's actual bound draw occurrences, including extra primitives, LOD attachments and instance chunks. Read transforms and deformation from their current owners, after their normal frame work. Keep derived GPU handles beside those occurrences. Do not walk only `materials`, and do not discover arbitrary renderable relationships later through a parallel global index.
* **Material change:** the existing material/texture/factor owner writes ordinary and diagnostic sinks with the same accepted value. A replacement binding replaces its companion in the same call. Neither debug selection nor the presentation module writes an effective base-color factor, texture-consumer table, variant choice or animation value.
* **Off:** remove diagnostic screen presentation and owned wire bits/attachments. There is no saved authored material snapshot to restore. The ordinary scene has continued receiving every update.

The only per-occurrence correspondence is the owned diagnostic attachment field. It is needed because one material resource can have different effective per-instance colors and double-sided clones. There is no node-ID scheme, authored schema addition, generation number, generic registry or new cache invalidation protocol.

## Module map and concrete integration

| Existing/new owner | Proposed bounded responsibility |
| --- | --- |
| `lib/src/scene_view.dart`, existing export in `lib/dart3d.dart` | Enum, two props, leaf forwarding, update comparison and explicit configuration defaults. Mount still sends configuration before controller attachment. |
| `lib/src/protocol.dart` | Document the two private viewConfig fields. No debug `command` and no authored serialization changes. |
| `ios/Classes/SceneViewHost.swift` | Parse selection in `applyViewConfig`; retain through scene installation; prepare diagnostic presentation after constraints/LOD/facing and after authored captures. Bind completed images to host and existing screen siblings. Own teardown. |
| `ios/Classes/DebugPresentation.swift` (new) | Private diagnostic SCNRenderer and attachment projection; detached material copies, copied display cameras, diagnostic target and lifetime management. Its delegate does not run simulation. |
| `ios/Classes/FsceneRealizer.swift` and current material/geometry bind sites | Family-aware diagnostic material construction beside ordinary construction; preserve all input/coverage/deformation behavior. Refresh companions where the actual binding changes, including catcher rebind. No generic modifier string parser. |
| `ios/Classes/ToneMapping.swift`, screen portions of `RenderTargets.swift` | Final screen selection between ordinary resolve and diagnostic texture, plus existing sibling delivery. Texture-target renderer and bake code continue consuming only the authored scene. |
| `android/.../Dart3dView.kt` | Parse selection; retain across scene installs; schedule diagnostic presentation outside `beginFrame/endFrame`; screen-only presentation/composition after authored target passes. |
| `android/.../DebugPresentation.kt` (new) | Private Filament scene/view/target with diagnostic draw occurrences borrowing existing buffers. Own only new renderables, diagnostic materials and edge index buffers. |
| `android/.../FsceneRealizer.kt` | Attach companions at existing primitive/chunk material and geometry binding owners; share skin/morph/instance resources and feed the same live weights. |
| `android/.../MaterialPackages.kt`, `MaterialRecipe.kt` | Closed diagnostic output branch of existing family recipes, same input sampling/bindings. Record post-lighting blend in recipe fingerprints. Omit SSR reflection mode in diagnostic lit packages. |
| `android/.../MeshFactory.kt` / `GpuMesh` owner | Derive optional edge indices from actual topology/indices once per existing geometry lifetime. Never replace the original vertex buffer. |

### iOS rendering boundary

The ordinary host retains its actual scene, point of view, delegate and simulation. Do **not** replace `host.scene` with a diagnostic clone; that would move physics/particle stepping. After `didApplyConstraintsAtTime` has updated LOD, facing geometry, blend proxies, dirty catcher bakes and due render targets, prepare a private attachment scene and draw it with explicit `SCNRenderer.render(atTime:viewport:commandBuffer:passDescriptor:)`, using that same frame time. The repository already uses this explicit render boundary for captures. [S3, S5]

The projection contains draw attachments, not a copied resource model. A mesh occurrence gets a shallow geometry wrapper retaining its current sources/elements, with detached diagnostic materials. Copy current presentation transforms, effective visibility/category, render ordering, and current binding; no actions, physics bodies, constraints, animation players, lights or emitter simulations. Preserve the real morpher and skinner inputs. `SCNSkinner.h` explicitly says per-node geometry is the material customization point; its baseGeometry affects all sharing nodes. Therefore never change the original skinner's baseGeometry. A diagnostic node can share the skinner and hold its own material-bearing geometry; that precise combination with the live presentation bones/morpher is an unrun capability check, not an established deformed-rendering result. If native sharing does not honor those per-node attachments, this slice is blocked there; do not bake deformed vertices on the CPU. [S7]

Each active screen camera is copied for projection/exposure isolation, with its current projection and pose. The projection retains the adapter's already selected LOD and camera-facing geometry, including its current primary-camera limitations. It does not add per-view LOD or regenerate a different billboard basis for each sibling. [S3, S6]

The host and existing siblings display completed diagnostic textures through their final screen technique, bypassing authored tone/effects for channel mode. Carry textures with the existing sibling pose delivery/build identity; keep a published texture immutable until all referencing encoders retire it, rather than rewriting one target underneath a later sibling draw. Use existing retirement and sibling generation machinery; no new revision protocol. A channel image and its camera pose must be published together. Texture and bake renderers never receive this presentation selection. [S4–S6]

For **wire-only**, iOS can own only `showWireframe` on the actual host/screen renderers. It overlays fill and is renderer-local; preserve all other debug bits. For channel plus wire, set it on the diagnostic renderer. Do not set `renderAsWireframe` or material fillMode lines. Restore each renderer's prior owned bit when it leaves this role, including newly created siblings. The opaque quad receipt supports this hook only in its bounded case. [S8]

### Material construction without stale snapshots

Diagnostic materials are private draw attachments, never replacements in the authored resource dictionaries. Keep material-family construction at the existing realizer. Add a closed private output-purpose branch to its current construction/composition code. Ordinary and diagnostic outputs reuse the same sampling, UV transforms, current factor setters and alpha/discard logic. Final diagnostic RGB replaces lighting/sheens/emissive contributions; it must follow the existing surface factor application. Preserve geometry modifiers, including sprite varying capture and baked-catcher projected UVs. Do not append a declaration-bearing string to an arbitrary existing body or replace a modifier dictionary blindly. [S2]

The current iOS `MaterialColorOwner.effective` and `copyFactor(to:)` provide the exact factor source; extend that owner's destination handling rather than reconstructing the factor from authored JSON. The material producer that writes a sheen texture argument or sprite premultiplication flag must write its diagnostic attachment there too. Share each setter/body construction, rather than maintaining a second list of custom uniforms to copy. Shader family construction remains in the realizer; DebugPresentation owns draw/presentation lifetime only. This is an extension of the current binding owner, not migration of resource ownership into the debug module.

For Android, evaluated texture channels cannot be read back from a MaterialInstance. Build companions from the same family recipes and bind them from the same material owner. Existing texture-consumer updates include the companion when allocated, remove it on teardown, and retain the same textures/samplers, including render-target-backed textures. Instance chunks retain their actual color arrays and double-sided policy. A companion must not be copied from the base resource while ignoring the current bound chunk/variant. [S9–S11]

### Android rendering and wire boundary

Create private diagnostic renderables using the original draw's VertexBuffer, IndexBuffer, MorphTargetBuffer, SkinningBuffer and InstanceBuffer, not a second geometry decoder. `GpuMesh`, `NodeSkin`, node morph weights and instance chunk records already retain these resources. Transform/culling/primitive-slot changes update the corresponding diagnostic occurrence at the existing binding site. The existing morph sampler sends its same array to the companion; bone uploads remain single writes to the shared SkinningBuffer. Diagnostic destruction must never destroy borrowed buffers. Remove companion draws before existing owners destroy/rebuild those resources. [S9, S10]

Render with the existing renderer on its existing engine thread. When diagnostic presentation is active, draw due authored render-target views through `renderStandaloneView` before the private diagnostic view, then enter the one ordinary screen `beginFrame/render/endFrame` block. Every standalone view must have its associated RenderTarget, and every standalone call stays outside that block. Keep target order, due checks and dirty/last-render bookkeeping in the existing target owner; only its submission boundary changes while diagnostics need those inputs. Off keeps the current scheduling route. This preserves current-frame render-texture inputs without a second swapchain frame or a new clock. The pinned Java contract supports standalone target views, and native source prepares/submits each standalone pass. Actual same-tick texture visibility, target clearing and screen output are still GPU checks, not proven by this source reading. [S11, V2]

Use existing lit sampling through `prepareMaterial`, then write the channel into postLightingColor with OPAQUE post-lighting replacement. Diagnostic packages omit `reflectionMode(SCREEN_SPACE)`, since the pinned final-fragment source excludes replacement when MATERIAL_HAS_REFLECTIONS is defined. Keep alpha masking and actual normal preparation. A per-light `surfaceShading` return is rejected. [S11, V1]

For triangle wire, derive `(a,b),(b,c),(c,a)` from each actual indexed triangle; expand strips with their alternating order and omit repeated-index degenerate triangles. Duplicate shared edges are acceptable in the first slice; no adjacency/dedup framework. Original lines/points have no additional triangle edges. The line renderable borrows the same vertex, morph, skin and instance resources and current transforms; its index buffer alone is derived. Reflected instance chunks use their actual reflected vertex attachment and current winding/index source. Draw depth-tested LINES over fill, including the quad's internal diagonal. gltfio Wireframe is AABBs and is not used. [S9, S11]

For wire-only Android presentation, the private pass first establishes ordinary opaque/MASK occluder depth using the same coverage, then draws edges into a transparent overlay; final screen composition adds that overlay over ordinary fill. BLEND keeps its existing no-depth-write policy. Do not sample the discarded main/render-target depth. Start with the engine's nearer-or-equal depth test on coincident edge geometry; establish coplanar stability on GL and Vulkan. Polygon offset is not presumed to fix LINES. A failed coincident-edge check is a bounded native rendering problem, not permission to ship AABBs, x-ray edges or a CPU-deformed surrogate.

## Supported channel semantics

These are the proposed contract, not a claim that the current code implements it.

Let `C` be the resolved **linear RGB material input**, `N` the normalized base-lobe shading normal in **right-handed camera/view space**, and `z = -positionView.z` the forward axial depth in scene units. View +X is camera right, +Y up, +Z toward the viewer. Camera rotation changes normal RGB. The base normal includes the currently realized normal map, normal scale, native deformation and double-sided treatment; clearcoat/bent normals are not substituted.

| Channel | Diagnostic linear RGB before display transfer | Native evaluation |
| --- | --- | --- |
| normals | `0.5 * N + 0.5` | iOS `_surface.normal`; Android normalized view rotation of `getWorldNormalVector()` after prepareMaterial. No object-space or tangent-space display. |
| metallic | `(m,m,m)` | Sampled base-material metallic after current factors. iOS `_surface.metalness`, including its adapter-split/factored MR texture; Android MR blue × effective metallic. |
| roughness | `(r,r,r)` | Sampled **perceptual material-input roughness** after current factors. iOS `_surface.roughness`; Android MR green × roughness before minimum clamps, anti-alias adjustment, coat remap or squaring into BRDF roughness. |
| baseColor | `clamp(C,0,1)` | Texture sample under its actual color-content decoding × effective factor × applicable vertex/instance/sprite tint. No lighting, emission, AO, sheen or environment. |
| depth | `(d,d,d)`, `d = z / (z + 1 scene unit)` | Positive per-fragment axial view depth, from iOS `_surface.position` or Android world position transformed by the actual active camera. Nearer surfaces are darker; one scene unit is 0.5 linear intensity. This explicit bounded transfer needs no far-plane assumption or new range API. It is neither hardware reverse-Z nor radial distance. |

Non-color scalar/normal textures retain their actual resource content tags and samplers; the slot name does not change a wrongly tagged resource's current native decoding. Do not show a corrected idealized material while labeling it the current resolved input. [S11]

For ordinary iOS vertex-colored materials, `_surface.diffuse` alone is not accepted as proof of vertex-color inclusion. Preserve/capture the existing vertex color at its current geometry stage and combine it exactly once with the sampled/factored input, while preventing a later automatic multiply from applying it again. The current sprite already has a varying for this purpose. A nonwhite vertex-color control must settle SceneKit's ordinary-path ordering before that channel is accepted; do not multiply twice based on an assumption. [S2, S7]

### Families and coverage

| Current native family | Meaningful channels and required behavior |
| --- | --- |
| Physically based, including existing material-extension approximations | All five; base-lobe inputs only. Variants use the actual currently bound family and parameters. Diagnostic final color discards lighting/reflection/refraction contributions, not their authored input bindings. Extension compiler combinations remain unrun. |
| Unlit mesh | Base color, geometric/native normal and depth. Metallic/roughness have no evaluated PBR meaning. Show a fixed magenta/gray N/A checker on that surface with the same coverage, documented as absent input; never invent metallic=0 or roughness=1. |
| `d3:sprite` / billboards / trails | Resolved tint/sample/vertex color and depth; geometric shading normal for their actual realized surface, not an invented normal map. Metallic/roughness are N/A. Preserve the sprite's actual atlas sampling, current tint and source-premultiplication policy. Straight base color is inspected before blend premultiplication; zero-alpha fragments contribute no visible color. Trails use current expanded geometry/color. |
| Android billboard particles | Inspect current packed vertices, UV0/UV1 flipbook interpolation and particle color produced by the existing particle runtime, with no extra tick. Base color, geometric normal and depth; MR N/A. Mesh particles use their actual bound mesh material family. |
| iOS native particles, including current mesh-emitter sprite approximation | Base color/depth/geometric quad edges would be meaningful, but the inspected SCNParticleSystem path supplies no established shader-modifier/material access or exact rendered draw attachment. This is a capability blocker, **not N/A**, and not covered by the ordinary mesh projection. See risks. |
| Live/baked shadow catchers | Receiver normal/depth and actual receiver triangle edges are meaningful. Base color/metallic/roughness are N/A: shadow coverage/tint is not a base-color material input. Normal/depth and N/A inspect the receiver mesh as an opaque surface, including receiver regions with zero shadow opacity; they are not a view of shadow coverage. This explicit catcher-only diagnostic policy avoids inventing base-color inputs or depending on diagnostic lighting. Wire-only keeps ordinary catcher fill/depth behavior. Baked output binding remains authoritative and is never rebaked from diagnostics. |
| Depth-only blend proxies, capture utility draws, sky/background | Not color-bearing authored surfaces. Never visualize blend-shadow proxy geometry as an extra surface. Channel background is black. Capture utilities remain outside diagnostic presentation. |

N/A denotes a semantically absent material input. It is not a substitute for a failed GPU hook, missing consumer integration or unimplemented meaningful channel. The checker is a specified debug display choice; production tooling must document it alongside channel names. No general capability registry is added.

For ordinary color-bearing families, retain actual opaque/MASK/BLEND/additive coverage and ordering; catcher surface inspection follows its explicit receiver policy above. MASK discard survives. BLEND retains alpha and no depth writes; transparent channel RGB/depth composites according to that surface's actual blend policy, so a translucent screen pixel is not a measurement of a single underlying surface. For a premultiplied source, recover the straight sampled base input before applying the current tint/vertex factors, then apply the family's premultiplication only once at output. Wire is geometric topology, not alpha-contour extraction; it must depth-test against occluders. Alpha-cutout interaction with SceneKit's native wire overlay remains unrun.

### Exact display contract

The channel image is composed in linear RGB with the original family coverage; the final screen applies one standard sRGB OETF:

`S(x)=12.92*x` for `x<=0.0031308`; otherwise `S(x)=1.055*x^(1/2.4)-0.055`, after clamping the final linear component to [0,1]. Depth/metallic/roughness values therefore use the same transfer as normal RGB. The N/A checker uses linear RGB magenta `(1,0,1)` and gray `(0.25,0.25,0.25)`.

Use a private linear RGBA16F diagnostic target, linear blend math, neutral diagnostic camera exposure and no tone curve, grading/LUT, fog, bloom, AO, DoF or temporal post history. The screen's diagnostic presentation shader performs this OETF into a non-sRGB target, or lets an sRGB output attachment perform it, **exactly once as established by the native control**. That is an implementation choice with one numeric contract, not two user APIs. Never run the resulting image through the ordinary stage resolve again. For wire-only, retain the ordinary stage look and composite edges at the final screen boundary.

On iOS, copied diagnostic cameras must bypass existing HDR packing/whitePoint/exposure adaptation; do not alter the shared authored camera. Whether the exact private render target path permits an uncurved linear result with these shader modifiers is still unproven. On Android, the post-lighting overwrite occurs after material evaluation/exposure and before fog; use a post-disabled, fog-disabled private view, then the explicit screen transfer. Neither the historical quad RGB nor `ToneMapper.Linear()` is numeric calibration. A literal three-component control and transparent-over-background control decide these paths. [S3, S11, V1]

## Lifecycle and single source of truth

The widget value owns user intent; the native host owns only its applied configuration and derived attachments. Existing scene/material owners continue owning authored and effective runtime data. DebugPresentation never feeds data back into them.

| Event | Required transition |
| --- | --- |
| Attach before first load | Mount sends explicit debug config before controller attachment flushes queued scene work. Empty scene has no diagnostic draws; first realized draw gets the current view selection. No reset-to-off in loadScene. |
| Full loadDocument replace | Drop outgoing diagnostic occurrences before retiring their borrowed resources; retain host selection. Realize new scene normally, then derive presentation from its actual bindings. No replay command or stale material restoration. |
| Deferred-payload full re-realization / surgical replay | Keep selection outside scene installation/reset state. Discard all derived handles tied to the discarded graph; reattach during the same existing rebuild/replay. The new canonical graph, not old local IDs, determines draws. |
| Material/texture/payload upsert while selected | Current owners rebind their ordinary and diagnostic destinations together, including every primitive and texture consumer. Input is sampled on GPU from the newly bound texture; no CPU approximation. |
| Base-color animation/factor update | Existing owner samples once and sets the same effective factor on each actual bound attachment and its companion. No polling a stale authored factor and no second clock. |
| Variant/default selection, LOD, double-sided/colored instance clone | At the actual slot/chunk bind, replace the diagnostic material/geometry attachment from that exact occurrence. Hidden/cull-floor LOD draws leave the diagnostic scene too. |
| Camera-facing/trail/particle buffer update | Borrow current updated geometry buffers after their existing update; iOS replaces its shallow wrapper when the source geometry attachment changes. Never re-expand from authored geometry with a second algorithm. Native iOS particles remain the stated blocker. |
| Camera/viewports/shared screen siblings change | Generate diagnostic image using each current active screen camera/layers/viewport; publish it with that screen pose through existing sibling delivery. No new per-node/split feature. No diagnostic image assigned to texture-target views. |
| updateStage while selected | Apply authored exposure/effects/environment to the ordinary scene as today. Channel projection continues its fixed display transfer. Off reveals the newly authored stage without restoring an earlier snapshot. |
| Controller replacement on same widget | Keep view selection; detach/attach existing controllers as today. Rebuild derived draws from whichever scene is now installed. The old controller stores no preference to replay. |
| Native view/element recreation | Fresh native off defaults are replaced by the widget's initial viewConfig before implicit document replay. New widget with default props is off. |
| Channel off, wire retained | Unpublish channel textures and release channel attachments; enable only screen wire presentation. Ordinary fill already has latest state. |
| Both off | Remove screen diagnostic texture/overlay and restore only owned renderer debug bits; use current ordinary resolve. Release private attachments/targets with existing in-flight retirement, never restore old authored objects. |
| Teardown | Unpublish sibling images on their existing queue; retire diagnostic materials/renderables/targets before borrowed resources die. Release only owned buffers (edge IBs), not shared geometry/skin/morph/instance buffers. No external files or persisted preference. |

### Captures and shared consumers

Render-texture inputs always use the canonical scene, even while their consumer surface is shown diagnostically. This means baseColor legitimately samples the current ordinary render texture. Catcher bakes clone only canonical attachments, then bind their latest output as usual. Diagnostic geometry/material attachments are never put into that canonical root or resource registry, so bake capture cannot copy diagnostic shaders. Screen siblings receive a screen image rather than material changes, so their later main-thread draw cannot leak debug state into a target renderer. This is why the extra diagnostic projection exists. [S4–S6]

Authored objects remain writable by their existing owners while diagnostics are selected. Derived attachments must be retired using the existing host lifetimes; creating another generic ownership/locking system would violate this design. Existing sibling locks/build identity remain the communication boundary, not a new synchronization scheme.

## Alternatives considered

These are complete alternatives within this candidate, not comparisons with other runners.

| Whole shape | Caller and lifetime | How it handles material/capture rendering | Why selected/rejected |
| --- | --- | --- | --- |
| **A. Controller runtime command with native-scene lifetime** | `controller.setDebugView(channel, wire)`, queued like highlights; loadScene/native recreation clears it. No retained Dart debug preference. | Still requires isolated diagnostic attachments for shared renderers, or an independently proven safe draw-local material mechanism. | A complete viable runtime tool shape, but callers must reselect after authored reload/recreation or coordinate replay timing. Highlights deliberately choose this lifetime; view diagnostics describe how to display whichever scene is loaded. Similar interface size hides less lifecycle complexity for real reload callers. Rejected. |
| **B. ViewConfig plus reversible overrides on actual shared materials** | Same two widget props and durable view lifetime as selected design. | Mutate actual bound material shaders/uniforms for screen draws; suspend overrides for target/bake draws; preserve current authored bindings separately. | Smaller initial implementation, same interface depth in Dart, but weak native boundary. iOS screen siblings encode later on main; the fragment modifier belongs to shared materials. Safe implementation would need serialized draw control across those existing queues or detached attachments anyway. The apparent simplicity is hidden temporal coupling and a stale-restoration risk. Rejected. |
| **C. ViewConfig plus private diagnostic presentation** | Two widget props; survives loads; ordinary serialization unchanged. | Actual binding owners produce isolated diagnostic companions; private draws use existing geometry/pose resources. Only final screen presentation reads the result. | Selected. Larger private implementation and enabled cost buy a structural capture boundary and off-with-current-state behavior. Public interface remains small and hides native isolation policy. |

A fourth tempting shape, a generic renderer modifier/registry stack, does not solve a new reachable requirement. It adds public sequencing and hand-maintained registries around the same native constraints. Likewise a full renderer/particle rewrite or W28 shader translation is outside W34.

## Synthesis decision

Candidate-local selection is C, for capture isolation and view lifetime. No other candidate or rubric was read. Parent owns cross-candidate synthesis; nothing here claims that process has happened. This runner uses the Codex model family and makes no provider-diversity claim.

## Tradeoffs accepted

* We accept an additional diagnostic draw and private targets while enabled in exchange for leaving authored materials/captures untouched. No performance claim is made.
* We accept small per-occurrence attachments in exchange for preserving chunk/primitive-specific binding and native deformation owners. We do not duplicate an authored scene model.
* We accept an explicit N/A display for absent material inputs in exchange for avoiding fabricated PBR values on unlit/catcher surfaces.
* We accept an early native scheduling/deformation investigation in exchange for avoiding an API whose apparent success on one quad hides unsupported consumers. Full W34 remains open until its meaningful cases are resolved.

## Open questions, factual blockers and proof plan

These are implementation/proof questions for the parent workflow, not requests for a new human checkpoint.

1. **Can iOS diagnostic attachments share the current skinner/morpher and retain exact live pose/material binding?** Headers support node-local material customization and the source exposes the attachments. The inspected capture copy code does not establish skinned/morphed diagnostic output. One posed mesh with a changed morph weight and a colored material factor decides this; a static copy is not a substitute.
2. **Can the native iOS particle renderer expose its actual sampled base color, per-fragment depth and rendered triangle geometry without another simulation/render implementation?** Current `decodeParticleEmitter` creates SCNParticleSystem, including the mesh-emitter-to-sprite approximation. Its inspected header offers simulation modifiers but no SCNMaterial/shader-modifier interface for its fragments. That is a source-level missing integration point, not proof that every possible native route is impossible. Do not label these channels N/A, ignore emitters, or copy the emitter into another advancing scene. This candidate does not claim a source-supported solution yet; full-scope acceptance is blocked on a bounded capability answer. [S12]
3. **Does Android standalone target → diagnostic → single screen-frame submission retain fresh target pixels and existing target clear/ordering behavior?** The pinned API supports this source-level order, so a second screen beginFrame is unnecessary. Use one render-texture-backed quad and a screen view to verify actual visibility. Do not replace a failed ordering check with a clock or one-frame fallback. [S11, V2]
4. **Does the fixed display transfer survive the exact native target/output path?** Compare literal linear values `(0.125,0.5,0.875)` and known depth planes against the stated OETF, with stage exposure/LUT/bloom changes during selection. No inference from the earlier packed SceneKit screenshot suffices.
5. **Do actual triangle edges stay coincident with skin/morph/instance/facing draws and depth occlusion?** Start with the known indexed quad plus occluder; show the diagonal. Then use one existing deformed/chunk fixture, not a new general matrix. GL/Vulkan line depth and SceneKit cutout overlay behavior remain unrun. iOS wire-only uses the native renderer bit on the real scene, so specifically verify that depth-only blend proxies do not acquire a visible overlay: the quad receipt does not establish that. A proxy leak would block that native-hook integration; it must not be waved away because ordinary color writes are disabled.

The proportionate first implementation slice is the **two-prop viewConfig contract and isolated normal-plus-wire presentation on the same indexed mapped quad**, including off → factor/texture update → off and one existing render-texture/bake/sibling consumer check. On Android, verify standalone target ordering and compile the exact SSR-free diagnostic recipe before extending material companions. On iOS, establish neutral transfer and skinner/material attachment sharing before broad attachment wiring. Native particles are an explicit unresolved consumer, not deferred invisibly behind an otherwise-green API.

After that slice, add metallic, roughness, baseColor and the exact axial depth expression in the same output selector, integrate current family/binding owners, then run the existing W34 behavior checks. The existing program-v2 T1–T4 obligations remain; the old ten-lane block is superseded. This proposal creates no additional acceptance matrix and does not waive reserved/unavailable devices. A142 remains reserved here. Baking must follow the current pinned Android tool when separately authorized; recipe fingerprinting and regenerated shipped package files accompany its eventual implementation. [S11, S13]

Source feasibility: ordinary mesh input hooks and actual geometry/buffer ownership are identified. Runtime correctness of this private presentation design, Android compilation/GPU output, family coverage, capture isolation, line quality, native particles and general platform parity are not established. The independent iOS report is a bounded historical PASS for hook/control/restoration on one opaque quad; it does not prove these new paths. [S8]

**Runtime, builds, tests, device/simulator queries, material baking and performance: NOT_RUN.** No code implementation, commit, push, PR or external write was performed.

## Next implementation step

Build the two-prop viewConfig path and the private mapped-quad normal/wire slice, starting with native transfer and target-order checks before extending companions to other bindings.

## Design red-flag screen

* **Shallow module / pass-through chain:** no new public coordinator. Widget → existing config → native host is the control path. Existing binding owners call one private presentation owner for render lifetime; no forwarding service stack.
* **Information leakage / importable internals:** public API is an enum and two props. Native buffers, material families, output recipes, private JSON and target scheduling are not public types.
* **Temporal decomposition:** resource/binding changes stay with their current owners. Prepare/render/release are private lifecycle operations of one diagnostic presentation module, not independent pipeline services carrying copies of state.
* **Split ownership:** one view owns selection; current material/animation/geometry owners own effective inputs. Diagnostic sinks are derived. No off snapshot overwrites current inputs. A debug subsystem writing factors would fail this design.
* **Two ways to do one task:** no typed controller setter, raw debug op or authored property in parallel with the widget props. Existing arbitrary command transport is not given a debug operation.
* **Hand-synced lists:** existing family sampling and setters produce both output purposes. Do not add a second slot-name/uniform list in DebugPresentation. The five channel names are a closed cross-language wire vocabulary, checked exhaustively in native decoders and focused future wire checks, rather than a registry duplicated across unrelated modules.
* **Over-engineering:** extra rendering is justified by reachable shared-material captures and asynchronous siblings. A generic modifier engine, persistent snapshot model, new clock, locks or revision scheme is not. If safe native per-renderer material selection becomes source-supported, subtract the private projection rather than retain both routes.

## Sources read

Paths below refer to this runner's imported accepted58 checkout, `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9bdedd09`, unless absolute. Ranges identify the inspected call paths, not new implementation.

* **S1:** `dart3d/lib/src/scene_view.dart:154–220`; `scene_controller.dart:268–290,390–429,1165–1194`; `protocol.dart:14–29`. Actual config-before-attach, highlight scene lifetime and controller reattachment. Also the three call sites cited in Usage.
* **S2:** `dart3d/ios/Classes/FsceneRealizer.swift:275–305,2416–2620,2678–2720,2895–2950`; `/private/tmp/dart3d-e9-debug-source-20261027/ios/source-map.md`. Actual PBR/sprite/alpha/modifier/material-color paths and current MR split/texture semantics.
* **S3:** `dart3d/ios/Classes/SceneViewHost.swift:361–482,1312–1358,5350–5370,5663–5701,5706–5827`. Exposure, tone, config and final-pose owners.
* **S4:** `dart3d/ios/Classes/RenderTargets.swift:320–390,500–550,603–628`. Shared scenes, discarded target depth, on-demand clockless siblings, and later main-thread draws.
* **S5:** `dart3d/ios/Classes/BakedShadowCatchers.swift:238–261,300–359,434–449`. Detached capture attachments, explicit render and later catcher modifier/binding replacement.
* **S6:** `dart3d/ios/Classes/FsceneRealizer.swift:2047–2065,2310–2374,6785–6821`; host LOD/facing ranges in S3. Actual instance clones, CPU-baked instance limitations and primitive skinners. The projection preserves current behavior; it does not repair pre-existing deformation limits.
* **S7:** installed `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNShadable.h:35–89,175–176,364–454,537–577`, `SCNSkinner.h:33–76`, and `SCNTechnique.h` (dictionary/input/program and symbol sections). Render-time OpenGL binding explicitly has no effect on shader-modifier symbols; the Metal buffer callback is on SCNProgram, which replaces standard material rendering. It is not a free renderer-local material-modifier switch.
* **S8:** `/private/tmp/dart3d-e9-debug-native-review-20261027/r1/report.md`, read in full; installed `SCNSceneRenderer.h` wireframe contract as mapped in the iOS source map. Historical one-quad evidence only; no probe imported.
* **S9:** `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt:95–125,708–787,2083–2210,3335–3440,4170–4265,6444–6635`. Actual GPU/slot/chunk/material/skin/morph ownership.
* **S10:** same Android directory, `Dart3dView.kt:4961–4980,5165–5171,5359–5410,5460–5590,5770–5881`. Existing weights, bone uploads, frame rebuild and draw scheduling.
* **S11:** `/private/tmp/dart3d-e9-debug-source-20261027/android/source-map.md`, read in full; `MaterialPackages.kt:725–815,834–1094,1253–1270`; `MaterialRecipe.kt:19–106`; `Dart3dView.kt:1802–1898,2487–2590`; documented `tool/bake_materials.sh` contract in the map. Pinned compiler and shader stages, current package fingerprints and standalone constraints. Map statements are source evidence, not executed GPU proof.
* **S12:** `dart3d/ios/Classes/FsceneRealizer.swift:6094–6325` and installed `SCNParticleSystem.h`, rendering and modifier sections. Current native particle owner and mesh-emitter approximation.
* **S13:** shared `/private/tmp/dart3d-e9-debug-design-20261027/grounding.md`, read fully; `docs/program-v2.md:200–235,411`; `docs/full-engine-program.md:1126–1140`; `dart3d/README.md:1–95`. Grounding records the parent's scoped PR/Linear searches and tracker; those are supplied context, not fresh absence claims by this candidate. README's broad verification-status paragraph is an older snapshot; it does not override the current program gate or bounded proof receipt.
* **V2:** freshly read pinned [Renderer.java standalone contract](https://raw.githubusercontent.com/google/filament/v1.77.3/android/filament-android/src/main/java/com/google/android/filament/Renderer.java) and [native Renderer.cpp](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/src/details/Renderer.cpp), standalone and renderInternal sections. Standalone requires a target, the engine thread and no open swapchain frame; its implementation prepares engine state and submits that render. This resolves the scheduling shape at source level, not its GPU result.
* **V1:** freshly read pinned Filament [surface_main.fs](https://raw.githubusercontent.com/google/filament/v1.77.3/shaders/src/surface_main.fs) and [surface_getters.fs](https://raw.githubusercontent.com/google/filament/v1.77.3/shaders/src/surface_getters.fs). Replacement follows material evaluation and alpha masking, precedes fog and excludes reflection variants. Public getters supply world position and mapped normal; normalized viewport depth is reversed. These support the selected stage/measurement distinction, not native output acceptance.

Architect instructions and `runner-prompt.md`, `rationale-template.md`, `design-red-flags.md` were read in full. The parent runs the workflow; no arena, children, implementation or agreement phase was started here. `~/.agents/docs/verification.md` was read. The repo's referenced `dartnative/docs/plugin_development.md` is absent in this prepared checkout; no claim is based on that missing file.

## Preservation and retained artifacts

The prepared checkout was clean at base HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. Verified the supplied archive SHA-256 `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706`, all 58 unique regular relative archive paths and every adjacent manifest hash before import. Imported accepted58 only into this already prepared checkout. No new checkout was made and no imported file was edited afterward. Final receipts recheck every imported hash and git-status path against that exact import.

Preserved lock/registrant files are `dart3d/pubspec.lock`, `dart3d/example/pubspec.lock`, `dart3d/example/dn_plugins.lock`, `dart3d/example/ios/Podfile.lock`, `dart3d/example/lib/dartnative_plugin_registrant.dart`, and the unrelated `probe/pubspec.lock`. No dependency operation was run. The parent checkout, source archive/manifest, source maps, proof packet and other candidate directories were not written.

Retained here: `design.md`, `accepted58-sha256.txt`, `import-receipt.json`, `preservation-receipt.json`, and `final-git-status.txt`. The exact accepted58 import remains in this runner's prepared checkout as authorized source evidence; it is not an implementation diff. No scratch render, probe, source patch, build output or test artifact was created.
