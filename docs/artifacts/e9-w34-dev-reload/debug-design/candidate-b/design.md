# Candidate B: view-owned debug selection, authored captures, isolated screen presentation

## Usage (caller's view)

The caller selects one material input for the whole `SceneView` and independently enables triangle edges over the filled image. The existing scene controller keeps receiving edits. A normal widget rebuild switches debugging off; there is no material restore call.

```dart
import 'package:dart3d/dart3d.dart';

SceneView(
  controller: controller,
  debugView: const SceneDebugView(
    channel: SceneDebugChannel.normals,
    wireframe: true,
  ),
);

// Filled authored rendering with edges:
SceneView(
  controller: controller,
  debugView: const SceneDebugView(wireframe: true),
);

// Current authored rendering:
SceneView(controller: controller);
```

These are proposed integrations at actual call sites, not claims that the API exists in accepted58:

1. **Authored-file reload screen:** `dart3d/example/lib/dev_reload_main.dart:26–42,59`. Keep `_reload` and its controller unchanged; add `_debugChannel` and `_wireframe` to the screen's widget state, and pass their value to the existing `SceneView`. Reload still applies the accepted library's document/diff path. Turning the channel off shows the last edit, even if several material and stage edits arrived while it was selected.

   ```dart
   SceneView(
     controller: _controller,
     quality: SceneQuality.high,
     debugView: SceneDebugView(
       channel: _debugChannel, wireframe: _wireframe,
     ),
   )
   ```

2. **Existing interactive showcase:** `dart3d/example/lib/main.dart:752–780`. Its `_cycler` and switch pattern can select the enum and wireframe boolean. The same `SceneView` already receives camera-control, statistics and quality state. Add one `debugView` value there; do not send a controller command from the button. A channel with wireframe off and wireframe with the channel `none` are both useful states.

3. **Native view attachment and controller replacement:** `dart3d/lib/src/scene_view.dart:165–193`. The element sends the current `debugView` in its existing configuration mutation before `attachElement`, and diffs it alongside quality. Replacing only the controller leaves the widget's debug choice intact. Recreating the element re-sends the choice before the controller's retained document reload. No caller replay protocol is required.

## Problem

W34 requires resolved normals, metallic, roughness, base color and per-surface depth on both platforms, with an independent filled mesh-wireframe overlay. Resolved means the native fragment's sampled/factored input, not an authored scalar or a lit framebuffer color. The difficult boundary is that screen renderers and offscreen targets share material objects, while live bindings include clones, variants, LOD and camera-facing geometry. A global registry edit would miss draws and contaminate captures. The bounded quad receipt establishes useful iOS hooks, not this production architecture.

**Decision:** use one widget setting and retain authored native resources as the capture authority. Produce debug presentation only for screen draws. On iOS, isolate material-bearing presentation attachments from the authored scene; on Android, keep the actual renderables and select derived diagnostic material bindings only during screen submission. This is a design candidate, not an implementation-ready claim for every existing consumer. The iOS particle/presentation boundary below is a factual unresolved capability issue; do not hide it behind a fallback or call this candidate full W34 acceptance.

The architect skill and runner discipline apply to this candidate only. Parent workflow phases, synthesis and implementation are outside this assignment. No other candidate or rubric was read. Same Codex model family; no provider-diversity claim.

## Shape

### Public types derived from usage

```dart
enum SceneDebugChannel {
  none, normals, metallic, roughness, baseColor, depth,
}

/// Screen presentation only; never part of SceneDocument or .fscene.
/// Available in release builds. Explicit non-default configuration opts in.
final class SceneDebugView {
  final SceneDebugChannel channel;
  final bool wireframe;
  const SceneDebugView({
    this.channel = SceneDebugChannel.none,
    this.wireframe = false,
  });

  bool operator ==(Object other) => throw UnimplementedError();
  int get hashCode => throw UnimplementedError();
}

// Proposed addition to SceneView and its existing leaf:
final SceneDebugView debugView; // default: const SceneDebugView()
```

There is one public operation, expressed as a value. No controller setter, serialized resource property, per-node override, split-view selector, backend selector, effect-stage knob, clock, revision, or public transport class is added. Existing screen views of this host receive the same selection; their own cameras still determine view-space normals and depth. This handles existing screen siblings without adding 0.24 split controls.

**Interface depth:** one setting hides native material family selection, screen/capture separation, diagnostic transfer, actual primitive coverage and lifetimes. Callers own only channel and overlay choices. `SceneViewElement` adapts a public value to private wire data; it is a necessary transport boundary, not another configuration authority. This follows interface-depth, boundary-discipline and encode-lessons-in-structure: enums disallow unknown public channels, and wire parsing happens once per native ingress.

### Private wire and state

Extend the existing tag-6 `viewConfig` JSON; do not add a command or change the upstream sealed scene schema:

```json
{
  "debugView": {"channel":"normals", "wireframe":true}
}
```

`_config()` always sends both fields, including `{"channel":"none","wireframe":false}`. Missing `debugView` means disabled for compatibility with the older Dart sender. Present values decode into a closed native enum plus boolean; malformed present objects use the existing protocol diagnostic/error convention, not an invented fallback to another channel. No per-frame JSON decoding. Update the existing protocol table, which currently also omits the already-supported quality field.

Single sources of truth:

| Invariant | Authority | Derived state |
| --- | --- | --- |
| Requested debug choice | Current `SceneView` widget configuration | Native host's applied value, as for quality; no controller copy or getter/replay store |
| Authored/current native material inputs | Existing realizer, texture consumers, factor owners and animation sampler | Screen diagnostic attachments/bindings; never write back into authored resource definitions |
| Current geometry, pose and deformation | Existing geometry/skin/morph/instance/facing owners | Presentation references or edge indices; no independent deformation calculation |
| Capture data | Existing authored scene/resources and target/bake owners | Targets may be sampled by a debug material, but are never rendered with debug inputs |
| Diagnostic display policy | Fixed private debug presentation policy | Effective screen camera/resolve settings; current authored stage settings remain retained by existing owners |

The widget and native host are producer and applied consumer, like existing view quality; they are not independent writers. No native UI changes debug selection. Authored updates never write debug configuration. Derived resources are discarded or refreshed from current inputs, not reconciled back into the source. There is no original-material snapshot to restore.

### Native interfaces (pseudocode only)

The following sketches describe ownership, not new general extension points.

```swift
// Private to W34 screen presentation. Not a public modifier registry.
struct ScreenDebugOptions: Equatable {
    enum Channel { case none, normals, metallic, roughness, baseColor, depth }
    let channel: Channel
    let wireframe: Bool
}

final class ScreenDebugPresentation {
    private var options: ScreenDebugOptions
    // Object-identity links to CURRENT source nodes/attachments, not authored IDs.
    // Only screen projection resources live here; never capture resources.
    private var attachments: [ObjectIdentifier: ScreenAttachment]

    func configure(_ options: ScreenDebugOptions) { /* not implemented */ }
    func prepareScreen(from host: SceneViewHost, at time: TimeInterval)
        -> ScreenPresentation { /* not implemented */ }
    func clearScene() { /* not implemented: release links, preserve options */ }
    func teardown() { /* not implemented: retire resources, release all */ }
}

private struct ScreenAttachment {
    weak var source: SCNNode?
    let displayed: SCNNode
    // Current native references identify replacement; no authored scene copy.
    var sourceGeometry: SCNGeometry?
    var sourceMaterials: [SCNMaterial]
}

private struct ScreenPresentation {
    let scene: SCNScene
    let screenCameras: [SCNNode] // presentation copies of existing screen cameras
}

// FsceneRealizer owns the fixed family-specific composition policy.
func makeScreenDiagnosticMaterial(from current: SCNMaterial,
    channel: ScreenDebugOptions.Channel) -> SCNMaterial {
    // TODO copy CURRENT inputs, preserve family coverage, append final RGB;
    // no read/write of .fscene; no generic parser for arbitrary authored shaders.
    fatalError("not implemented")
}
```

```kotlin
// Existing realizer's bound material data, extended locally where necessary.
// Effective inputs are sampled from their existing owner; not a new scene mirror.
internal class ScreenMaterialBinding(
    val authored: MaterialInstance,
    val diagnostic: MaterialInstance,
)

internal class ScreenDebugPresentation {
    fun configure(options: ScreenDebugOptions) { /* not implemented */ }
    fun submitScreen(host: Dart3dView, draw: () -> Unit) {
        // TODO after authored target/bake passes: bind current diagnostics,
        // apply neutral screen display; draw existing screen cameras;
        // finally rebind current authored slots and authored screen policy.
        // Execution uses the existing render thread; no cross-thread writer.
        error("not implemented")
    }
    fun clearScene() { /* not implemented: clear resources, retain options */ }
    fun teardown() { /* not implemented */ }
}

// Geometry owner, not a gltfio utility or a new renderer:
fun triangleEdges(mesh: MeshFactory.MeshData): ByteBuffer =
    error("not implemented")

// Existing recipe generator emits either normal or diagnostic specialization.
// Both use ONE sampling/factoring body; no copied vendor shader or shader fork.
fun litSpec(/* existing arguments */, diagnostic: Boolean): Spec =
    error("not implemented")
```

`ScreenMaterialBinding` is attached to the existing material/consumer owner, not indexed in a new global scene registry. It may only be built from the effective family/bindings already selected by the realizer. Changing a factor, texture, variant or chunk color goes through that owner's existing binding logic; that one calculation supplies both destinations when diagnostics exist. Do not recreate sampling from serialized JSON each frame, read back shader values into Kotlin, or add a second animation rest/effective store. Existing `AnimatedProperty.effective` is the source for animation factors.

### iOS draw isolation

Keep the authored `SCNScene`, native physics, animations, original materials and existing target/bake draws unchanged. A screen presentation projection contains native node/geometry attachments needed for the screen image, with diagnostic materials only. It is drawn on demand through the existing paused screen-sibling pattern, including the single-screen case while a channel is active. The host remains the sole scene update/physics driver; its authored pass does not show through the diagnostic presentation. Existing camera controls still mutate their existing real camera owner; the presentation receives its resolved pose. Turning off the channel removes this projection and reconnects the existing authored screen path.

This extra attachment boundary has a reachable requirement: target renderers and asynchronous screen siblings share material objects today. Modifying those objects for only the host callback cannot isolate later main-thread sibling draws. The projection is private to debug presentation, not a second importer, simulation, document graph or renderer implementation. No diagnostic object enters `materials`, `materialConsumers`, `nodesById`, `resourceDefs`, physics ownership or capture inputs.

For iOS wire-only mode, use `.showWireframe` on the existing screen renderer and each current screen sibling; channel-plus-wire uses that bit on presentation renderers. Never set it on target/bake SCNRenderers. Retain only the prior value of that owned bit per renderer, preserve all other debug bits, and restore the prior bit when relinquishing ownership; a prior-true value must stay true. The renderer's native overlay supplies actual edges over fill, including the source triangle diagonal. `.renderAsWireframe` and material line fill do not satisfy this contract.

After the host's constraints, LOD, facing and blend-proxy work, read current native attachments and presentation transforms. Keep source geometry buffers/elements, current topology and native deformation algorithms. Copy geometry attachment objects only to own distinct material arrays. Build skinning attachments from the current skinner's base streams, bone inverse binds and the resolved presentation bone hierarchy; retain native SCNSkinner evaluation. Copy current morpher targets/weights from the drawn source state; do not calculate morph positions. Never copy source physics bodies, actions, constraints or animation players into the presentation, and never step it. Extra `d3prim:` children and CPU-baked instance geometry must remain represented. Current iOS instance skin/morph omissions remain existing limitations, not debug fixes.

Structural links are derived from actual object identity. A full load clears them. Surgical geometry/skinner/morpher replacement changes identity and replaces that attachment. Every prepared screen frame reads current geometry/material binding references and values, so an LOD swap, a new material clone, a texture arrival or a rebuilt facing mesh cannot stay stuck on an old diagnostic. Reuse unchanged resource identities, but do not introduce a general generation protocol. Apply the finished presentation on the same main-thread handoff used for sibling poses; do not let the render thread mutate an attachment while its sibling is drawing. Use existing scene/render retirement conventions for resources still referenced by a submitted frame.

**Capability boundary:** that describes a complete material-bearing mesh presentation, but the inspected source does not establish a faithful live-state projection for `SCNParticleSystem`. Emitters and bursts run inside SceneKit, use `particleImage` rather than these `SCNMaterial` consumers, and mesh emitters already degrade to sprites. Copying an emitter configuration or starting another paused scene is not evidence that its currently living particles are preserved. Do not implement a second particle simulation, claim particles are ordinary material slots, or silently hide them. This remains a concrete blocker to claiming arbitrary scenes are faithfully represented by this candidate. The first slice must establish this boundary before generalizing the projection, as described below; no fresh human architecture checkpoint is requested.

For ordinary materials use native sampled `_surface` inputs and a final fragment RGB assignment after current family bodies. Keep the fixed family composition in the realizer, where masks, transparent pragmas, sprite color and sheen are already assembled. Preserve declarations/pragmas and append at the actual body end; do not blindly concatenate complete snippets or replace the dictionary. The diagnostic copy of a baked catcher must be made after the current catcher binding's geometry modifier and footprint texture are present. Authored catcher materials themselves remain pristine, so existing detached bake captures copy authored inputs.

**Rejected shortcut, verified against the installed SDK:** `SCNShadable.handleBindingOfSymbol` explicitly has no effect for shader-modifier uniforms and supports OpenGL programs only. Metal buffer callbacks belong to SCNProgram; setting a program overrides material settings/modifiers. Neither supplies a demonstrated renderer-local flag to the ordinary SceneKit material pipeline. SCNTechnique symbols bind its own pass programs, not a proven modifier-uniform namespace. Do not use any of these as an assumed isolation mechanism. [Apple SCNShadable](https://developer.apple.com/documentation/scenekit/scnshadable?language=objc), [Apple technique binding](https://developer.apple.com/documentation/scenekit/scntechnique/handlebinding%28ofsymbol%3Ausing%3A%29?language=objc).

### Android draw and wire ownership

`Dart3dView.render` already submits baked captures, then due authored render targets, then screen passes. Preserve that order and keep diagnostics unbound until the screen section. Bind diagnostic counterparts at every currently drawn entity/primitive slot, including instance chunk duplicates and effective variants. Submit the current screen cameras through the existing renderer/view, then restore authored bindings before the next frame or any further authored draw. Restoration reads the current owned binding, not a material saved when debugging was enabled. Source feasibility of this serial submission shape is supported; exact material/view snapshot timing through Filament render submission remains a decisive native check, not a proven property here.

`litSpec` retains one sampling body. Its diagnostic specialization omits SCREEN_SPACE reflection compilation, requests OPAQUE post-lighting replacement, and writes the channel after `prepareMaterial`. It retains actual bound slots, UV transforms, vertex/instance colors, double-sided normal behavior, alpha-mask input and native vertex processing. It does not use `surfaceShading`: that executes per light and cannot isolate inputs from zero/multiple lights, IBL or emissive. Do not change the normal SSR recipe to make debug work. Extend `MaterialRecipe`'s existing builder/fingerprint capture for the compiler option and regenerate the adopted shipped packages through the documented bake route later; no baking is authorized here.

Wire edges belong to the existing geometry builder. Expand indexed TRIANGLES into three edge pairs per nondegenerate triangle. Expand triangle strips with their actual winding and omit degenerate triangles. Retain internal diagonals; no silhouette extraction or AABB replacement. Repeated shared edges are acceptable in the first implementation; deduplication is unnecessary. Non-triangle native primitives have no triangle edges; filled rendering remains available.

Prefer extra LINES primitives in the **same renderable**, using the original vertex buffer and an edge index buffer. Keep authored filled primitives in their existing slots; append physical edge slots privately so authored material-consumer slot indices stay valid. Rebuild the renderable through its current geometry owner when primitive count changes, reattaching its current SkinningBuffer, MorphTargetBuffer, InstanceBuffer/count, bone ranges, weights, transforms, bounds, visibility and layer settings. Do not build a static CPU mesh copy or a separate skin/morph updater. Facing geometry continues writing its existing vertex buffer; edges reference that buffer. Each instance chunk has its own existing owner and receives the same additional primitive shape.

Edge slots must have an index draw count of **zero outside screen submission**, not merely a transparent material: otherwise shared render-target and shadow/catcher passes could still see debug geometry. The geometry owner enables their real index range only around screen rendering and resets it before returning. The public indexed `setGeometryAt(..., offset, count)` API accepts a nonnegative count; using zero to suppress all edge work is the source-supported candidate, with actual GL/Vulkan submission and capture isolation still requiring the same decisive native check as material switching. Carry each filled primitive's morph-target buffer offset to its edge slot as well as the renderable-wide morph buffer/weights. This is physical-slot bookkeeping in the existing geometry owner, not a new scene registry. [Pinned RenderableManager API](https://github.com/google/filament/blob/v1.77.3/android/filament-android/src/main/java/com/google/android/filament/RenderableManager.java), [native geometry update](https://github.com/google/filament/blob/v1.77.3/filament/src/components/RenderableManager.cpp).

The overlay recipe draws unlit edges without depth writes, with ordinary depth testing against fill and occluders. Preserve mask coverage at interpolated edge UVs. Source-supported candidate depth function is less-or-equal; coplanar edge visibility and backend line rasterization are unrun. Do not paper over a failure with always-on-top lines or an arbitrary world-space offset. If native visibility needs a bias, establish the exact supported raster state on the first quad/occluder before adopting it. Existing geometry owner teardown destroys edge indices and restores the original primitive shape; resource lifetimes follow that owner's fence/retirement path.

This does add a private physical slot distinction, a material specialization and derived index buffer. Their requirement is actual filled triangle edges on the same deformation/instance path. A generic overlay registry or gltfio AABB wire utility adds nothing needed here.

### Channel semantics and display

All definitions below are normative targets, not claims of current GPU parity. The normal convention is **view space**, right/up/negative-forward, measured by the camera drawing that screen pass. Normal mapping and native deformation precede visualization.

| Selection | Native input and exact meaning | Diagnostic linear RGB |
| --- | --- | --- |
| normals | Normalized base-lobe shading normal after normal texture, UV transform, scale, tangent frame and native deformation. iOS `_surface.normal`; Android `getWorldNormalVector()` after `prepareMaterial`, transformed by the actual view rotation. Neither geometric normal nor clear-coat normal replaces it. | `0.5 * normalize(N_view) + 0.5` |
| metallic | Sampled effective metallic input, including the actual MR B-channel texture and factor/bindings used by that native material. | Replicate `clamp(m,0,1)` |
| roughness | Sampled **perceptual material-input** roughness, including MR G-channel and factor. Excludes Filament's later BRDF squaring, minimum roughness, clear-coat adjustment and specular AA. | Replicate `clamp(r,0,1)` |
| baseColor | Resolved linear material RGB, including actual sampled texture/content decoding, texture transform, factor, vertex/instance color and runtime factor animation. Before lighting, exposure, occlusion, emissive or tone mapping. | `clamp(baseRGB,0,1)`; values above one saturate explicitly |
| depth | Positive forward eye-axis fragment distance `d = -position_view.z` in existing scene units; not Euclidean distance, main-depth texture or reverse-Z raster value. iOS `_surface.position`; Android actual world fragment position transformed by the view matrix. | Replicate `d / (1 + d)` for visible forward surfaces: camera plane black, one scene unit 0.5, three units 0.75, infinity approaches white. This is a fixed monotonic display of linear eye depth, not near/far-linearized hardware Z. |

The fixed depth transfer avoids another range-control API and works with existing perspective/orthographic cameras. The UI/doc label must disclose the one-scene-unit half-gray scale. Projection clipping is unchanged. If future usage requires near/far range controls, that is a separate change, not part of this candidate.

Channel images keep the material's existing visibility, mask discard, blend/depth-read/write policy and source coverage. Thus overlapping BLEND surfaces composite their diagnostic contributions; depth is a per-surface input, not a promise that the final pixel names one frontmost translucent surface. Invisible alpha does not become an opaque diagnostic sheet. Ordinary channel RGB receives the family's premultiplication exactly once. Additive sprite/particle behavior remains additive. A surface with a defined alpha but an undefined selected property uses the explicit N/A display below with that coverage.

For isolated channel mode, effective screen presentation uses exposure 1, no autoexposure, fog, bloom, DOF, motion blur, SSR/refraction image contribution, grading, LUT or vignette. Material transmission/coat/sheen inputs can remain sampled, but their lighting result cannot overwrite the diagnostic. Diagnostic screen backgrounds use fixed black and skip sky radiance; background is not a surface. Retain camera pose, viewport/layers, native clipping and geometry visibility. Retain selected AA; interior texels, rather than antialiased edges, are numerical proof locations. Wire-only mode uses the **latest authored display settings and filled material**, since no isolated numeric channel is being shown.

Display target: after linear-space coverage composition and AA, clamp linear RGB to [0,1], then use the standard sRGB output transfer exactly once:

```text
encode(x) = 12.92*x                         if x <= 0.0031308
            1.055*x^(1/2.4) - 0.055         otherwise
```

There is no artistic tone operator in channel mode. A scalar 0.5 therefore displays around sRGB code 188, not code 128. Interior N/A is fixed linear magenta `(1,0,1)`, documented as “no such input”; it is not a guessed metallic/roughness scalar. No heatmap or optional palette is added.

iOS must use presentation-owned camera copies and a fixed diagnostic resolve that undoes the existing SceneKit HDR packing before identity/clamp output to its sRGB drawable. Reuse the existing inverse packing math in `ToneMapping.swift`, not its wide-gamut artistic linear-tone branch. Do not double-encode in the fragment shader. The prior literal control traversed packing/resolve and is explicitly not calibrated raw RGB. Android must use a presentation camera/exposure policy and an identity diagnostic output path whose output attachment performs exactly that transfer. Merely selecting the existing 64³ `ToneMapper.Linear` LUT does not prove identity: source records residual channel errors even at that size. Disabling post processing also does not establish an output transfer by itself. **Exact Android output attachment/resolve behavior remains unproven**; literal ramp readback must settle the supported path before it is accepted. Do not add a renderer fork if that path is unavailable.

### Material-family behavior

“N/A” is an explicit selected-property meaning for families with no such input, not a backend failure fallback. Compiler failure or an inaccessible required sampled input remains a blocker, never N/A.

| Current family | Defined channels | Composition/integration requirement |
| --- | --- | --- |
| Physically based, including extension variants | All five; normal/MR describe the base lobe | Read current native inputs after existing factors. Final diagnostic replaces extension lighting, including sheen; retain masks and source coverage. Preserve native approximations already present on iOS, without promising identical authored semantics across backends. |
| Unlit mesh | baseColor, geometric surface normal, depth; metallic/roughness N/A | A geometric normal is the effective normal when no shading-normal input exists. Do not invent a normal map that this family does not consume. Preserve vertex/instance colors. |
| `d3:sprite` and unlit trails | baseColor and depth; metallic/roughness N/A; normal is the native drawn face normal if its pipeline exposes one | Sprite baseColor is texture × tint × vertex color, recovered before premultiplication. iOS custom `d3SpriteColor` cannot be omitted; Android must capture `c` before UNLIT_EXPOSURE/premultiplication. If a generated facing pipeline has no accessible normal, normal support is a capability blocker rather than flat `(0,0,1)` output. |
| Live and baked shadow catchers | receiver geometry normal and depth; baseColor/metallic/roughness N/A | Catcher shadowColor and captured shadow amount are coverage/shadow data, not a PBR base color. Diagnostic screen attachment suppresses lighting/shadow multiplication of the diagnostic; receiver footprint/coverage remains the existing family's. Native shadowOnly coverage access is unproven and must not be approximated with an opaque plane. Baked footprint inputs remain authored; captures never sample diagnostic output. |
| Android billboard/mesh particles | Billboard sampled color and fragment depth where recipe exposes them; native mesh materials follow their actual family; metallic/roughness N/A for unlit billboard recipes | Keep existing particle buffers, flipbook UV interpolation and per-particle color/coverage. Wire follows actual native triangle topology, not emitter bounds. No independent particle update. |
| iOS native particles, including current mesh-emitter sprite degradation | Required color/depth and actual face geometry access are not established by the material hook; PBR input semantics do not appear by naming an authored mesh material | This is a source-visible distinct renderer, **unresolved**, not silently passed through or removed. No claim of full scene parity until this existing consumer has a supported draw/state route. |

Per-family hooks for sprites, catchers and particles are finite additions inside their existing owners. This table is not permission to write a shader translation layer, repair existing family parity, expand the public channel set or construct a general modifier framework.

### Lifetimes and dominant access patterns

| Event | Debug lifetime and derivation | What authored/off rendering sees |
| --- | --- | --- |
| Configure before document/attach | Widget sends complete options before controller attach. Native host stores options even with no scene. No materials are synthesized for missing content. | Existing empty view until load. |
| Full `loadDocument` | Preserve host options; discard scene-local derived attachments/bindings/edge buffers with the old scene. Prepare from the newly realized graph. | New authored scene is the capture authority. Selection does not borrow setNodeHighlights' clear-on-load semantics. |
| Surgical resource/geometry re-realization | Existing owner replaces bindings; debug derivation follows actual new attachment/primitive identities. Late payloads follow the same route. | No debug bytes enter the document or resource definitions. |
| Texture/factor/animation change while selected | Read current native owner after sampler/texture landing; feed current bindings to diagnostics. Do not retain an on-entry factor. | Off reveals the latest factor, texture and authored animation state. |
| Variant/default choice | Derive from the effective material actually bound by the existing variant owner, including current fallback selection. Do not independently resolve names. | Authored restore rebinds that current effective material. |
| LOD, clones, instances, facing geometry | Enumerate active native bindings, not only registries. Keep current cloned overrides/chunk colors and chosen geometry. Edge attachment follows its geometry owner. | No undo of current LOD/facing selection; no stale material restored. |
| Stage/effect/camera change while selected | Existing authored stage owner keeps updating. Only effective screen diagnostic camera/resolve is neutral. Per-screen view transform remains current. | Off re-derives screen display from current stage; authored targets keep their existing policy throughout. |
| Existing screen siblings | Apply the host choice to every existing screen pass. iOS uses isolated presentation objects and main-thread handoff; Android serially uses each current screen camera. | No new per-screen public feature. No transient material switch on a shared asynchronous iOS scene. |
| Target or bake due, including shared cameras | iOS uses authored graph/cameras; Android submits authored bindings before screen selection. Existing bake copies only authored attachments. | Target/bake contents and dirty scheduling are independent of debug toggles. No cache invalidation merely to remove debug. |
| Channel `none`, wire true | No diagnostic material or neutral display policy. Render authored fill plus geometry edges only. | Latest authored shading/effects, captures remain clean. |
| Full off | Release screen-only derivatives and owned overlay contribution; reconnect current authored draw/display. Clear only the wire bit/edge slots this feature owns. | No saved material/stage snapshot replay. |
| Controller replacement, same view | Widget options persist. On an incoming load, clear old scene resources and derive from new content. If no load is sent, preserve existing content per current attach contract. | No special controller reset command. |
| View/native renderer recreation | New host starts disabled and receives complete current widget config before document replay; then derives resources. | No native debug state leaks across view instances. |
| Controller dispose / view teardown | Existing controller dispose does not itself destroy a mounted native view. Actual host teardown releases presentation/bindings/buffers/camera copies and weak source links using existing resource retirement. | No invented dispose semantics; no source or document mutation. |

Repeated identical config is idempotent. Channel changes rederive presentation state rather than stacking modifiers. Native replacement and config drain use existing queues. There is no additional lock, writer, timer, sequence number or generation protocol. The screen projection's handoff must fit the existing main-thread presentation ownership; if implementation needs a new shared writer, that invalidates this sketch rather than authorizing an unplanned synchronization layer.

## Module map and source evidence

Line citations refer to the prepared checkout `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-4f9aed05`, base `2f38e4e33f0b1cb678bc408a42d069c796cefc12` plus exact accepted58 overlay. “Read” below means inspected in this candidate. Additional vendor-stage facts are grounded in the two supplied source maps, not newly executed capabilities.

| Owner | Bounded proposed responsibility | Read source / reason |
| --- | --- | --- |
| `lib/src/scene_view.dart` | Public value and enum, leaf forwarding, full config serialization and value diff | `:35–99,165–221`: widget owns renderer config; sends before attach and uses explicit default quality clearing. |
| `lib/src/protocol.dart` | Document private viewConfig fields; existing encoding route only | `:18–26,48–62`: viewConfig is distinct from document resource/stage operations. No new command op. |
| `lib/src/scene_controller.dart` | No debug API or retained debug state | `:268–288,355–401,1072–1098,1165–1193`: document truth/serialization and attach replay; highlights intentionally have a different native-scene lifetime. |
| iOS `SceneViewHost.swift` + private `ScreenDebugPresentation.swift` | Applied options, authored driver preserved, screen projection scheduling/lifetime | `:361–478,1312–1363,5354–5364,5663–5713,5722–5827`: cameras/resolve, ingress, sole sampler, current LOD/facing and capture order. |
| iOS `FsceneRealizer.swift` | Fixed diagnostic family composition from current native materials | `:2416–2619,2675–2715`: catcher/sprite/PBR branches and modifier composition; `:6785–6821`: real base/extra-primitive skinning. |
| iOS `ToneMapping.swift` | Fixed diagnostic resolve using existing pack inversion; no artistic tone/grading | `:83–100,253–257,350–398,436–520`: actual packing and current resolve; identity channel display is a proposed specialization, not proven by selecting its linear mode. |
| iOS `RenderTargets.swift` | Existing authored targets; presentation-only screen sibling routing | `:5–28,310–391,490–537,558–628`: shared scenes/cameras, discarded target depth, paused siblings, deferred main-thread draw. |
| iOS `BakedShadowCatchers.swift` | Keep capture inputs pristine; screen diagnostics read latest bound catcher | `:238–261,434–449`: detached attachment capture and live binding replacing modifier dictionary. |
| Android `Dart3dView.kt` + private `ScreenDebugPresentation.kt` | Applied options, screen-only material/display selection with authored target/bake order | `:1783–1898,2487–2540,5835–5881`: exposure/grade ownership, ingress, explicit submission ordering. |
| Android `FsceneRealizer.kt` | Effective family/variant binding and live consumer updates feed diagnostics; original renderable builder appends optional edge slots | `:2100–2205,3358–3412,6444–6500`: instance duplicates/colors, real primitive bindings, native skin/morph buffers and family material construction. |
| Android `MeshFactory.kt` | Derive real edge indices from decoded geometry | `:62–85`: topology/index-width/skin/morph data already owned here. |
| Android `MaterialPackages.kt`, `MaterialRecipe.kt` | One sampling generator with diagnostic specialization, fixed family recipes and correct fingerprints | Packages `:490–587,723–821,830–936,1017–1084,1244–1255`; recipe fingerprint/compiler details additionally supplied by Android source map. |
| Example reload screen/showcase and docs | Explicit release-usable controls, selection semantics and evidence | Actual call sites above; no new reload architecture. |

Supporting artifacts read fully: [shared grounding](/private/tmp/dart3d-e9-debug-design-20261027/grounding.md), [iOS source map](/private/tmp/dart3d-e9-debug-source-20261027/ios/source-map.md), [Android source map](/private/tmp/dart3d-e9-debug-source-20261027/android/source-map.md), [bounded independent iOS review](/private/tmp/dart3d-e9-debug-native-review-20261027/r1/report.md). The maps' prior installed-API/source observations are reused with their stated limits. The review's PASS is historical bounded evidence for one opaque quad's sampled view-space normal, literal/geometric controls, filled triangle diagonal and fixed restoration. It accepts no production API, general material families, isolation or Android behavior.

Installed iPhoneOS27.1 `SCNShadable.h:49–89,283–290` was read directly to settle binding restrictions. Its fragment/surface semantics are also documented by [Apple](https://developer.apple.com/documentation/scenekit/scnshadable?language=objc). Android's post-lighting exclusion and per-light callback are grounded in pinned [Filament surface_main.fs](https://github.com/google/filament/blob/v1.77.3/shaders/src/surface_main.fs), [surface_shading_lit_custom.fs](https://github.com/google/filament/blob/v1.77.3/shaders/src/surface_shading_lit_custom.fs), and the supplied Android source map. No assertion of a vendor final-fragment callback or debug registry capability is made.

The project instruction names `dartnative/docs/plugin_development.md`, but that path is absent in this prepared checkout; it was not read or invented. The installed repo-local DartNative skill was read; the existing view/protocol implementation supplies the actual integration contract. Shared grounding records the parent's scoped PR/Linear lookup and branch context. Those are supplied historical observations, not fresh remote absence claims; this candidate makes no remote changes or live queue claim.

## Alternatives considered

These are whole ownership designs; choosing a widget instead of a setter alone would not count as a structural alternative.

### A. Runtime controller command, debug-decorated live scene, authored capture projections

Public `controller.setDebugView(options)` queues a runtime command like highlights. Native scene lifetime clears it on full load/recreation; callers wishing to keep a choice replay after each load. Debug composition affects the original live screen materials. Every authored target renders a detached clean attachment projection; baked captures explicitly strip diagnostic composition and bind latest authored material state. Material/factor/texture writers update the pristine authored binding representation and the decorated live binding. Off rebinds latest authored state. Actual screen geometry and native particles keep their original owners, while capture isolation pays the projection cost.

This is a complete alternative flow, but its closure has the same unresolved native particle-state/capture copying problem. It places the least forgiving consumer—authored texture/cache output—behind a new projection and moves clean material ownership away from the actually rendered live scene. Controller replay and two binding destinations become easy to overlook during reload. Its public method is small but shallow on lifetime: the caller must learn native load/recreation sequencing. Rejected on ownership and interface depth, not because a command is intrinsically invalid.

### B. Selected: declarative view setting, pristine authored graph, derived screen presentation

The widget retains the user's choice through reload. Source native resources remain the exact input to authored targets/bakes. iOS presentation isolates diagnostic materials; Android's existing ordered screen submission selects derived bindings without a second geometry/deformation implementation. Off reconnects current authored resources. Projection uncertainty is visible as a debug presentation limitation and cannot silently corrupt an authored render texture or bake cache. The interface hides native lifetimes and capture policy. Selected despite iOS attachment complexity; that complexity has a concrete shared-renderer requirement.

### C. Fullscreen channel resolve from main buffers

A view setting selects a postprocess pass over normal/MR/base/depth attachments, with triangle edges supplied by a separate geometry pass. A true material-input buffer producer would have to be added across every native material family; iOS currently exposes neither the required universal G-buffer nor preserved render-target depth. Sampling final COLOR cannot recover these inputs. Building that producer by replacing SceneKit shaders or forking Filament violates the requested architecture boundary and is much larger than fixed material hooks. Rejected as not source-feasible within W34, rather than weakened into authored-value or AABB output.

## Tradeoffs accepted

- We accept a view lifetime for debugging in exchange for surviving authored reloads and requiring no command replay. Highlights retain their independently documented scene lifetime.
- We accept iOS presentation attachments in exchange for pristine authored captures and no shader fork. This candidate must be rejected or revised if bounded proof shows that native deformation/particle presentation cannot be preserved without rebuilding a renderer.
- We accept fixed depth compression and clamped base RGB in exchange for an exact small public surface with no range/palette controls.
- We accept extra Android edge primitives and derived material resources only while opted in, in exchange for actual triangle topology on existing skin/morph/instance buffers.
- We accept explicit N/A for properties absent from a family in exchange for avoiding fabricated PBR inputs. Inaccessible properties that should exist remain failures, never N/A.

## Synthesis decision

This runner selects B independently. No cross-runner synthesis was performed and no other candidate was consulted. The parent decides whether to use this candidate or reject its iOS projection cost/blockers. Nothing in this file grants implementation scope or creates a new approval checkpoint.

## Open questions and risks

These are implementation evidence questions, not decisions parked for the user:

1. Can the iOS presentation attachment path preserve the actual drawn skin/morph pose and living native particles without a second simulation or scene ownership rewrite? The inspected particle path does not establish it. Resolve this with the smallest native draw/state experiment before broad projection integration; if it cannot, revise/reject this shape, not the W34 promise.
2. Can iOS shadowOnly coverage and unlit facing normals be accessed through public family hooks while preserving actual coverage? Ordinary PBR `_surface` access does not prove these cases. A required inaccessible input is a factual blocker.
3. Does Filament capture diagnostic material/neutral display state at each serial screen submission before authored rebinding, including GL/Vulkan paths? Source ordering is promising, GPU behavior is NOT_RUN.
4. Which public Android output attachment/resolve route delivers the specified identity-plus-sRGB transfer? Current Linear LUT comments and private-view post-disable examples do not settle it. Do not label an approximate current tone output calibrated channels.
5. Do appended LINES primitives preserve current instancing/skinning/morph state and show occluded/coplanar edges correctly on the pinned backend? The underlying buffer and primitive APIs exist; this exact combination has not been compiled or drawn here.

These risks are not new speculative acceptance gates. They are the narrow native facts needed for the original W34 behavior. No performance claim is made; the obvious projection/extra-draw cost remains unmeasured.

## Next implementation step and proof plan

**First slice:** add the one viewConfig value and an iOS screen-only normal-plus-wire presentation for the known normal-mapped indexed quad, with an authored render target sharing its scene/camera; keep the projection private until isolation, literal transfer and actual attachment/deformation preservation are established. Reuse the existing hook evidence; focus new work on the new ownership boundary. Include one existing native emitter alongside the mesh to settle whether the selected projection can preserve its live draw state. Failure there rejects/revises this shape before expanding native code. This does not authorize a new particle system or claim the quad closes W34.

After that decision, implement Android through the existing recipe/geometry owners: same mapped quad, actual diagonal edges and an occluder; zero versus multiple lights plus IBL/emissive changes; literal ramp to establish transfer and input invariance. Adopt the diagnostic specialization only after pinned material compiler acceptance and the authorized documented package bake. A142 remains reserved now; no alternate device is assumed available.

Then close the five fixed selections and reachable family/binding behaviors using a compact deterministic fixture, not a new Cartesian matrix. One selected-state edit sequence should include texture arrival, effective factor change, material/variant/LOD/facing binding and full replacement, followed by off to current authored rendering; use existing skin/morph/instance content to catch owner loss. Compare target pixels and catcher capture inputs off/on/off so capture contamination cannot hide behind screen screenshots. Capture initial authored, selected channel/filled wire, edited-while-selected, and final authored output; final must reflect the edit rather than match an obsolete initial image. Add meaningful Dart transport/serialization cases and focused native owner checks during implementation, without test-only production seams.

Use the current program gate (`docs/program-v2.md:201–235`) and W34's behavior floor (`docs/full-engine-program.md:1126–1165`). The old ten-lane text is superseded. T1, the existing T2 native smoke matrix and T4 visual review still apply when implementation lands; these are not replaced by this candidate or the prior quad. Parent's required Codex review remains separate. No fresh architectural/user permission checkpoint is needed by default.

**This task's verification:** source/installed-header inspection and archive preservation only. Runtime, builds, tests, material compilation/baking, device/simulator queries, GPU/channel parity, performance, CI and full W34/Track E acceptance: **NOT_RUN**.

## Red-flag screen

The public setting is deep and contains no wire types. There is no second debug API or serialized representation. Current authored material/geometry ownership remains visible at the binding owners, and diagnostics never write those inputs back. Family-specific shader composition stays with family construction; geometry edge derivation stays with geometry construction. No temporal load/validate/apply service chain, pass-through facade, generic registry, new clock or revision protocol is proposed. Enum cases are exhaustively decoded/switched; there must be no independent “supported channel” list with fallback defaults.

The material/presentation projection is the main red flag: it risks becoming a second renderer. Its allowed knowledge is current native attachment identity, resolved pose, shared streams and diagnostic material copies. Native particles expose the boundary already. Do not expand it with independent import, animation, physics or effect implementations. If those are required, this candidate fails the red-flag screen and must be redesigned, not patched with more synchronization or copied renderer code. That limitation is intentionally explicit.

## Snapshot preservation and retained artifacts

The prepared checkout was clean at the required base HEAD before import. Verified archive SHA-256 `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706`; all 58 regular relative paths matched the adjacent manifest before import and their working-file bytes after import. The manifest SHA-256 is `206fad2de1f69905ad37033021e0566a63c7f5494b72c67d70fef541214a6ade`. Only this accepted58 overlay was imported, never observed61/probe code. Parent and other candidate directories were not written.

Kept intentionally: the unchanged accepted58 overlay in the prepared checkout; this `design.md`; adjacent `accepted58-sha256.txt`, `import-receipt.json`, `preserved-locks.json`, `preservation-receipt.json` and `final-git-status.txt`. The six lock/registrant paths and their exact hashes are enumerated in `preserved-locks.json`; final preservation rechecks them and all imported files. No checkout was created in the shell, no implementation file was edited after import, and no scratch builds/renders or other leftovers were created.
