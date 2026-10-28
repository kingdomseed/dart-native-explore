# W34 candidate A: view-owned diagnostics with screen-only draw attachments

## Usage (caller’s view, written before the types)

The caller selects one channel on `SceneView`, independently selects filled mesh edges, and rebuilds the widget. Returning both settings to their defaults reveals the latest authored rendering. Loading or editing a document does not reset the view’s diagnostic choice. These are proposed APIs, not implemented APIs.

```dart
import 'package:dart3d/dart3d.dart';

SceneView(
  controller: controller,
  debugChannel: SceneDebugChannel.normals,
  showsMeshWireframe: true,
);
```

Three actual integration sites, with proposed edits illustrated:

1. `dart3d/example/lib/dev_reload_main.dart:67`: the existing reload screen keeps its `DevSceneReload` and controller. Its `SceneView` receives local UI selections. `DevSceneReload` still applies authored documents/diffs; it neither stores nor resets diagnostics.

```dart
// In _ReloadScreenState; picker callbacks use ordinary setState.
SceneDebugChannel _channel = SceneDebugChannel.off;
bool _wire = false;
// Existing build's SceneView:
SceneView(controller: _controller, quality: SceneQuality.high,
  debugChannel: _channel, showsMeshWireframe: _wire);
// Reload arrives while this shows roughness: roughness remains selected.
// Selecting off / false shows the newly reloaded scene.
```

2. `dart3d/example/lib/main.dart:775`: the existing harness view already receives `_cameraControl`, `_stats` and quality. Add the same two props beside them. A channel selection never calls `upsertResource`, mutates the document, or needs a camera/light setup command.

```dart
SceneView(controller: _controller,
  allowsCameraControl: _cameraControl, showsStatistics: _stats,
  quality: widget.quality, debugChannel: _channel,
  showsMeshWireframe: _wire);
```

3. `dart3d/example/lib/showcase_scene.dart:1400,1423`: both the direct material/sprite/owner showcase branch and the gesture-wrapped branch must receive the same props. An explicit launch define can select a channel in release verification; this is example tooling policy, not a second plugin API.

```dart
// Example-only opt-in, used in either existing SceneView branch.
const requested = String.fromEnvironment('DART3D_DEBUG_CHANNEL');
final channel = switch (requested) {
  'normals' => SceneDebugChannel.normals,
  'metallic' => SceneDebugChannel.metallic,
  'roughness' => SceneDebugChannel.roughness,
  'baseColor' => SceneDebugChannel.baseColor,
  'depth' => SceneDebugChannel.depth,
  _ => SceneDebugChannel.off,
};
SceneView(controller: _controller, debugChannel: channel,
  showsMeshWireframe:
    const bool.fromEnvironment('DART3D_MESH_WIREFRAME'));
```

Explicit non-default props are the opt-in. There is no `kDebugMode` gate, global activation switch, controller setter, or serialized scene extension for this operation. Ordinary shipping callers retain both defaults. The plugin does not supply a picker UI in this slice.

## Problem

W34 requires resolved normals, metallic, roughness, base color and per-surface depth, with independent filled triangle-edge overlay. Actual draws include material clones, primitive slots, variant selections, LOD, native instancing, facing replacements, skin/morph streams and generated particles/trails. The same authored objects also feed render textures, baked shadow capture and existing screen siblings. A material-registry override can miss active draws and contaminate data later sampled by those draws. The bounded iOS opaque-quad result proves useful hooks, not these ownership contracts. The design must keep accepted reload/content ownership intact while hiding this native complexity behind two view props.

## Grounded architecture: overview and boundaries

Read source in the prepared checkout at HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`, with the verified accepted58 overlay. Bracketed references below identify source read in this run; source-map statements are attributed separately.

`SceneViewElement.mount` sends hello and view configuration before controller attachment; update diffs view fields before handling a controller swap [S1]. The controller owns document/payload preparation, queues operations before attachment, and reloads its live document on reattachment [S2]. Highlights deliberately clear with native scene lifetime [S2]. This justifies the transport precedent but not adopting that shorter lifetime for a persistent diagnostic viewing choice.

The iOS host drains mutations and samples animation before physics, then finalizes LOD/facing, captures baked catchers, renders texture targets and schedules screen siblings after constraints [S3]. Siblings already draw on demand, without another simulation clock; their main-thread execution is later than the host render callback [S4]. Android updates owners and bakes catchers before `beginFrame`, draws offscreen views first and screen passes second [S5]. Its current screen view is reused across camera/viewport passes. These orderings rule out a global material toggle assumed to be private to one screen draw.

Existing material and geometry owners remain authoritative. Diagnostic presentation reads their effective results. No second document, animation player, material-factor resolver, physics simulation, file reload path or revision protocol is introduced.

## Shape

### Public types and private wire

```dart
// In scene_view.dart, added to dart3d.dart's existing selective export.
enum SceneDebugChannel { off, normals, metallic, roughness, baseColor, depth }

class SceneView extends StatefulWidget {
  final SceneDebugChannel debugChannel; // default off
  final bool showsMeshWireframe;         // default false
  // Existing fields and constructor remain; bodies not implemented here.
}
// SceneViewLeaf carries the same two values, as it carries quality today.
```

`SceneViewElement._config()` always emits both values, including off/false, and update compares both. They travel in existing tag 6 `viewConfig` JSON:

```json
{"debugChannel":"off","showsMeshWireframe":false}
```

This is a partial illustration of the existing configuration object, not a new opcode. Native `applyViewConfig` parses strings once into a private enum and booleans into typed host configuration. Absence from an older sender leaves the default/current value, matching existing partial-config semantics. An unknown channel is a malformed diagnostic request: log rejection and keep the current valid choice; do not silently substitute another channel. No wire symbols are exported. Do not extend upstream scene schema, document serialization, `applyCommands` or highlights.

`SceneController.sendViewConfig(Map)` already exists [S2]. Do not add debug convenience methods there or advertise it as an alternative debug API. It remains the existing low-level escape hatch for unrelated settings; diagnostic selection is owned by widget configuration. Its raw map does not become retained diagnostic truth, just as it is not retained widget quality truth today. Source edits to add a second writer should fail review.

### Single source of truth and data access

The current widget props are desired state. Native host fields are their applied transport values, like quality today, not an independently editable selection model. Derived draw attachments are disposable output. The authored resource/instance owners remain the sole mutable source of material, texture, deformation and stage data.

For each active screen camera while diagnostics are enabled, build a **screen-only presentation scene** of draw attachments from the current realized owners. It is not decoded from authored JSON. The source scene continues to run animation/physics and supply offscreen views/captures. Presentation includes only renderable nodes/entities, required pose/bone nodes and view state; it does not copy bodies, constraints, actions, emitters or samplers. With wire-only, retain the current authored material appearance in presentation and add edges. With a selected channel, use diagnostic derivatives of those current material bindings. With both off, use the existing authored screen route and retire presentation.

The reachable reason for these copies is isolation, not speculative caching: SceneKit shader modifiers are material-owned, and screen siblings overlap offscreen/material lifetimes. SDK `SCNShadable.h:74–80` explicitly says custom symbol binding has no effect for shader-modifier symbols and is OpenGL/GLES-only. `SCNProgram` overrides material settings and modifiers. Therefore a purported Metal renderer-local modifier uniform is not a source-supported shortcut [S10].

Presentation is per active screen camera, so near/far, display camera settings and material uniforms never race between screen passes. All existing screen views of a host receive the same two diagnostic choices; their camera, viewport and layer masks continue to differ. This handles existing consumers without adding split controls.

Dominant reads:

* Frame: read the post-animation/post-physics current draw attachments and pose once, including extra primitive children, native instance chunks, particles and trail draws. Derive screen attachments from these owners, not just `materials` or `nodesById` lookups. Wire topology follows the effective geometry selected for this frame.
* Resource update: existing decode/bind/texture-consumer/animation owners continue to update canonical data. On the next presentation synchronization, use the resulting effective material and bindings. Never restore a captured old material when disabling diagnostics.
* Geometry bind: the mesh/LOD/facing/instance owner supplies its exact active streams, primitive ranges, transforms and deformation bindings. Screen attachments borrow immutable streams or the owner-updated GPU buffers. They do not regenerate positions from document parameters.
* Retirement: dispose presentation consumers before their borrowed resources can be destroyed. Existing component/resource teardown calls presentation retirement first and uses the existing graveyard/fence mechanism for in-flight work. No new clock, revision number or generic invalidation bus.

### Native signature sketch (all unimplemented)

These sketches state responsibilities; implementation should keep platform-specific types internal. `ScreenDebugPresentation` is a bounded W34 owner, not a renderer modifier framework.

```swift
// New ScreenDebugPresentation.swift, internal to native plugin.
struct DebugViewSettings: Equatable {
    var channel: DebugChannel
    var wire: Bool
}
final class ScreenDebugPresentation {
    // Called after existing pose/LOD/facing owners, on host render queue.
    func prepareScreenAttachments(host: SceneViewHost) {
        fatalError("not implemented")
        // Read current authored draw bindings; copy attachment state.
        // Publish detached render-only attachment/pose packet through the
        // existing generation-gated screen main-thread handoff.
    }
    // Existing component/resource teardown calls before freeing bindings.
    func retireScene(host: SceneViewHost) { fatalError("not implemented") }
}
// FsceneRealizer owns this exact material-family knowledge.
func makeDebugMaterial(current: SCNMaterial,
                       channel: DebugChannel,
                       clip: SIMD2<Float>) -> SCNMaterial {
    fatalError("not implemented")
    // Copy current resolved properties; compose known modifier sections.
}
```

```kotlin
// New ScreenDebugPresentation.kt, internal to native plugin.
internal class ScreenDebugPresentation {
    fun synchronize(host: Dart3dView) = TODO("not implemented")
    fun retireScene(host: Dart3dView) = TODO("not implemented")
    // Existing renderable/component teardown must release borrowed references
    // before its canonical vertex/skin/morph/instance buffers are destroyed.
}
// Extend existing recipe builder privately, not a new shader authoring API.
internal fun diagnosticLitSpec(/* existing recipe selectors, */
    channel: DebugChannel): MaterialPackages.Spec = TODO("not implemented")
// Edge topology is derived at the existing geometry owner boundary.
internal fun triangleEdgeIndices(indices: IntArray,
    topology: MeshFactory.Topology): IntArray = TODO("not implemented")
```

Private records directly retain the source native attachment identity, primitive slot/range, borrowed streams and owned diagnostic material/line resources for that screen. A per-screen source-identity association is needed to reconcile draw attachment replacement; it is owned solely by this presentation owner, not a new global material registry. Do not key by authored material ID: one resource may have multiple live per-instance material derivatives. No public `DrawBinding` abstraction is needed. Mutable value transfer stays in the original material/geometry owners instead of inspecting native parameter getters to guess source intent.

### iOS integration

Use existing `RenderTargets.swift` screen-sibling infrastructure for a paused presentation view even for the default single-screen camera while active. The canonical host keeps its scene, clock and delegate; its blank-camera machinery prevents an ordinary screen image from showing behind presentation. The default-camera route must be supplied explicitly when there are no authored screen view records. Preserve native camera control by keeping the leading control camera bound to the canonical owner; copy its current pose to the presentation camera. Picking remains against canonical nodes. Disabling diagnostics restores the existing single/multiscreen routing for the current document.

Extend the existing screen handoff with render-only attachment snapshots. Canonical render-queue state is never mutated from main. Presentation scenes and their skin/morph attachments are owned on main, where sibling redraws already occur; do not write them from the host render queue during a sibling draw. Build detached data on the host side and apply through the existing handoff. Reuse its existing scene/subview generation protection, not another revision scheme.

Copy geometry attachments using the capture precedent [S9], sharing their sources/elements; copy current bound materials, compose diagnostics only on these copies. Preserve all primitives and geometry modifiers. Reconstruct `SCNSkinner` with the exact canonical weights/indices, IBMs and skeleton but map bones onto presentation pose nodes; preserve its base-geometry bind settings. Copy the morpher’s targets, calculation mode and current weights. No deformed CPU vertex extraction or geometric-normal substitute. Bone/pose nodes receive canonical presentation transforms after constraints. Canonical SceneKit skinning still defines deformation inputs; the presentation uses SceneKit’s same skin/morph mechanisms without stepping simulation. Source supports constructing these attachments [S8]; exact deformed output through presentation remains a GPU proof obligation.

Compose diagnostic RGB after existing material surface/factor and fragment coverage logic. Consolidate known argument/varying/body sections inside the existing material owner; blind concatenation of pragma-bearing strings is forbidden. Sprite tint/color and premultiplication get their existing family path. Baked catcher copies use their actual current captured material, including its geometry modifier. Late rebinds are observed on the next snapshot, not intercepted by a parallel registry.

Set `showWireframe` only on diagnostic screen renderers; its native hook overlays actual active triangles over fill. Retire these renderers on off instead of altering canonical debug bits. Texture SCNRenderers and bake sources never receive presentation scenes or materials.

### Android integration

Keep authored `host.scene` and all offscreen views/catcher capture unchanged. In the existing frame function, after canonical skin/morph/instance/facing updates, derive screen presentation scenes; draw them through dedicated screen Views/camera copies. This is the existing screen draw schedule, not a replacement engine or a second simulation loop. Wire-only views use the latest authored stage look; selected-channel views use diagnostic display policy below. Existing screen view camera, layer mask, viewport and quality precedence still apply.

At existing renderable attach/rebind points, retain sufficient native binding data with that owner: exact vertex/index buffers, active primitive ranges/topology, SkinningBuffer and bone range, MorphTargetBuffer/current weights, InstanceBuffer/chunk color arrays, reflection/winding-specific streams and bounds. `NodeRec`, `GpuMesh` and `NodeSkin` already hold most of this [S6,S7]; do not fabricate it by replaying `MeshFactory` later. Generated particle/trail owners must expose their actual draw bindings directly too; omitting their draws is not allowed. Presentation renderables borrow those buffers, take the canonical world transform/visibility and use private material instances. Source buffer owners stay owners of allocation and mutation.

Diagnostic recipes reuse the existing material-body generation and parameter/texture binding logic, with a private diagnostic purpose selector at that owner. They are not a pasted shader library. A lit diagnostic recipe omits SCREEN_SPACE reflection and requests OPAQUE post-lighting replacement, writing its isolated color after `prepareMaterial`. It also omits refraction evaluation in diagnostic output while preserving material-input sampling and coverage. This avoids the pinned reflection bypass; per-light `surfaceShading` is rejected. Extend `MaterialRecipe` with the actual `postLightingBlending` builder operation so fingerprints cover it. Unlit/sprite/catcher diagnostic recipes use their respective input/coverage code without inventing PBR lobes. All recipe/package changes must use the existing versioned fingerprint and shipped baking route [S7]; no runtime fallback to an ordinary shaded package may be reported as successful diagnostics.

`MaterialInstance.duplicate` cannot turn an authored package into a different diagnostic package. Bind diagnostic instances from the same effective factor/texture owner inputs at creation and update. Existing texture-consumer and property-animation writers continue owning effective values; presentation reads them at synchronization. Any narrow factor/slot extraction needed belongs beside those existing writers, not a generic second mirror of JSON properties.

Wire uses actual indexed triangle edges in a LINES renderable: expand triangle lists/strips, omit degenerate triangles, produce edge pairs for each surviving triangle including internal diagonals, and use the effective primitive range. Deduplication is optional only if it does not erase triangle boundaries. Reuse the same vertex, skin, morph, instance/chunk and transform bindings as fill; retain original morph vertex indices. Lines use a fixed visible unlit edge color, depth test against fill, no depth writes, and a small toward-camera bias to avoid coplanar loss. Occluded edges remain hidden; do not substitute AABBs, silhouette-only edges, or whole-renderable bounds. GL/Vulkan line/deformation/depth-bias behavior is explicitly unproven. Non-triangle source primitives have no additional triangle edges; triangle-expanded billboards/ribbons do.

## Supported channel semantics

One normal space: **right-handed native camera/view space, camera forward −Z**, after the base shading normal map and actual deformation/face policy. Android transforms normalized `getWorldNormalVector()` by the active camera’s view rotation after `prepareMaterial`; iOS reads normalized `_surface.normal`. No world normal display or geometric-normal public mode. The original authored left/right reflection adapters stay in charge; validate orientation with a known camera/mesh, not a guessed sign flip. Clearcoat/bent normals are not this channel.

| Channel | Value before diagnostic display |
|---|---|
| normals | `0.5 * normalize(Nview) + 0.5`, componentwise RGB. Normal textures, normal scale, slot transform and native face/deformation rules remain effective. |
| metallic | Grayscale sampled base-lobe metallic input multiplied by current effective factor. iOS reads `_surface.metalness`; Android reads the material input after its B-channel MR sample/factor. |
| roughness | Grayscale sampled perceptual material roughness × current effective factor. iOS `_surface.roughness`; Android `material.roughness` before BRDF clamping, coat remapping, specular AA or squaring. |
| baseColor | Linear RGB material base input after actual texture sampling/decoding, UV transform, authored/runtime factor, vertex color and instance color. It excludes lighting, emissive, AO, transmission and sheen contributions. Use family-specific existing tint/premultiplication logic. |
| depth | `d = -Pview.z` per surviving fragment; `x = clamp((d - near)/(far - near), 0, 1)` from that screen camera’s actual finite authored/effective clipping range, display grayscale x (near black, far white). Same formula for perspective/orthographic. It is neither hardware/reverse-Z depth nor radial distance. |

Depth clip values are copied with the presentation camera and supplied to that camera’s private diagnostic materials. Existing finite camera defaults are near .05/far 1000 on Android [S11]; honor each actual iOS camera instead of assuming those defaults. No depth-texture readback requirement is introduced. Existing blend-depth proxies are capture/shadow helpers and excluded from presentation channel draws. Keep real alpha discard/depth testing and ordinary transparency composition: blended/additive surfaces contribute their per-fragment diagnostic values through their authored coverage. A composited pixel is not promised to represent one frontmost surface’s raw numeric value.

Material families:

* PBR, extensions and instance clones: inspect the actual base inputs as above. Extensions do not substitute clearcoat roughness/normal, sheen or final lit output. Preserve actual slot/culling/coverage policies.
* Ordinary unlit: baseColor, geometric shading normal and depth remain meaningful; there is no metallic/roughness lobe. Those two channels show a documented **not-applicable magenta marker** through that surface’s existing coverage, not invented zero/one material values.
* Sprites/particle sprites: baseColor is sampled straight color × tint × vertex/instance color, before exposure or premultiplication. For premultiplied source textures, recover straight RGB only at nonzero alpha; zero-alpha samples contribute no coverage. Normals show the billboard/ribbon’s real geometric shading normal; MR is not applicable. Mesh particles inherit their material family. No new particle simulation.
* Live shadow-only catchers: no base-color/PBR input exists; baseColor/MR show the same not-applicable marker. Baked catchers’ baseColor shows their actual captured diffuse RGB sample and its current binding, explicitly labelled captured receiver color; MR is not applicable. Normal/depth use actual receiver geometry. Preserve shadow/capture alpha footprint rather than painting an opaque receiver rectangle. Whether SceneKit shadow-only modifiers expose that alpha at the needed stage is a bounded capability blocker, not proven here.

These markers explain semantic absence; a broken compiler, missing diagnostic package, unsupported deformation or missing draw is an implementation failure and must be reported, never rendered as an N/A material or an ordinary-shaded success.

### Exact display contract

For selected channels, clamp the channel RGB to [0,1] as linear diagnostic color, preserve existing coverage and blend in linear space over diagnostic black. Output standard sRGB: `12.92*x` for `x <= .0031308`, otherwise `1.055*pow(x,1/2.4)-.055`. A .5 scalar therefore displays near byte 188, not 128. Background has no surface and stays black. N/A is linear (1,0,1). AA may mix edge samples; numeric checks use interiors. Wire uses fixed contrasting edges over either this image or ordinary fill when the channel is off.

Disable stage lighting-dependent post effects, fog, SSR/SSAO, bloom, grading/LUT, vignette, nonlinear tone operators and auto-exposure for channel presentation only; use exposure 1. Canonical cameras/stage state stay current. Wire-only retains authored display settings. iOS presentation cameras retain the existing HDR packing constants; add a narrow diagnostic resolve branch in `ToneMapping.swift` that inverts packing and applies only the sRGB function, bypassing its Rec2020/tone/effect path. The ordinary `linear` tone option alone is not the numeric contract. Android diagnostic screen Views use identity exposure and linear tone/output conversion without grading/effects, and must establish the actual final transfer with a literal RGB control; merely disabling post-processing does not prove sRGB output. Any needed narrow resolve must live with the existing display owner, not a shader fork. No RGB calibration claim follows from the prior probe’s packed screenshot.

## Lifecycle table

| Trigger | Required behavior / owner |
|---|---|
| View attaches before a scene, or controller queued a load before mount | View config lands first; retain typed native settings while no geometry exists. Attachment/load supplies authored draws, then presentation derives from them. No empty-state fake geometry. |
| Full `loadDocument` replacement | Retire outgoing presentation attachments before native owners tear down; retain host debug configuration. New scene produces new attachments. Highlight reset remains independent. |
| Surgical re-realization / payload arrival | Existing owners change canonical bindings; reconcile affected presentation attachment identities/material values on the next frame. Never reapply an old saved material. |
| Controller changes within the same SceneView element | View selection stays. Attach controller’s scene through existing path; retire old presentation on actual scene replacement. No selection replay from either controller. |
| Widget/view recreated | New mount sends current widget props before controller reload. A widget newly created with defaults is off, regardless of former native state. |
| Material/texture/factor/animation/stage updates while selected | Apply to canonical owners normally; refresh diagnostic inputs from current effective values. Stage changes remain available immediately for off/wire-only. Captures use current authored data throughout. |
| Variant/default/LOD/material clone or primitive bind | Derive from actual current bound material and geometry, including chunk duplicates; replace only matching screen attachments. Defaults are not restored from pre-debug snapshots. |
| Facing/trail/particle updates | Read after their existing update. Borrow updated Android buffers; copy current SceneKit attachment/pose state safely. Include actual generated draws, not only document meshes. |
| Channel off but wire still true | Rebuild screen materials from current authored bindings/display; retain edge overlay. No forced channel. |
| Wire false but channel still selected | Retire line attachments / clear presentation-only wire bit; retain channel. |
| Both off | Remove diagnostic screen presentation, return to the current authored screen routes/cameras/look. Canonical state has never been overwritten. |
| Surface detach/native host teardown | Release presentation consumers first through existing safe retirement, then canonical resources. No persistent selection in controller, resource table or serialized document. |

## Module map and interface depth

| Proposed owner | Change / source responsibility |
|---|---|
| `lib/src/scene_view.dart`, `lib/dart3d.dart` | Two props, six-state enum, leaf equality/diff and explicit viewConfig fields. Public interface contains intent only. |
| Native `SceneViewHost.swift` / `Dart3dView.kt` | Parse config; retain view lifetime; schedule synchronization after canonical update; keep canonical capture route; arrange safe retirement. |
| New native `ScreenDebugPresentation.swift/.kt` | Own only screen draw derivatives and their lifetimes. Reuse existing screen camera/viewport/handoff/draw routing. No simulation or authored-data mutation. |
| Existing `FsceneRealizer` material and bind owners | Build family-correct material derivatives from current effective inputs and expose exact draw bindings beside their attach/teardown paths. Preserve variants, clones and texture consumer ownership. |
| Existing Android `MaterialPackages.kt`, `MaterialRecipe.kt`, bake tool | One recipe generator with diagnostic purpose, exact post-lighting option/fingerprint; existing package production route. No second handwritten lit shader. |
| Existing `MeshFactory`/`GpuMesh`/renderable owners | Triangle-edge topology and borrowed geometry/deformation bindings, including component-owned and generated buffers. |
| Existing `RenderTargets.swift/.kt`, `ToneMapping.swift`/Android stage-display owner | Screen-only routing and numeric resolve; texture-target and catcher routes continue using canonical data. |

Interface depth is high: two widget fields hide native channel sampling, material families, deformation-preserving attachments, screen/capture separation and display transfer. Callers learn only the channel meanings and that selection is view configuration. Native knowledge stays beside its existing owner (boundary-discipline); derived attachments avoid second mutable authored truth (single-source-of-truth); enum plus independent Boolean encode mutually exclusive channels and independent overlay (encode-lessons-in-structure). Do not add one pass-through facade per native stage.

## Alternatives considered

### A. Screen-only presentation derived from authored native draws — selected

Two view props and no commands. Keep all canonical attachments authored; create render-only screen attachments while active. Captures are safe by object separation, including asynchronously drawn iOS siblings. This accepts real attachment/deformation-copy work instead of exposing capture ordering to the caller. Shared geometry data and the existing frame loop remain in place. The scope cost is visible and confined to the W34 private presenter and existing attachment owners.

### B. Controller command, decorated canonical screen materials, authored offscreen projections

A complete opposite partition is `controller.setDebugView(channel, wire)`, queued like highlights and cleared on full load/native recreation. Canonical scene draws use instrumented materials; offscreen targets and bake sources instead get retained authored-only material/geometry projections. Resource/factor changes update authored originals and regenerate canonical diagnostic derivatives; off restores latest authored bindings. Every existing texture renderer must use the authored projection and bake cloning must explicitly start from it, not the decorated scene. Screen siblings can share decorated materials because all screens use one command selection.

This also can isolate output without draw-time toggles, but makes the capture pipeline depend on debug’s material bookkeeping, even though captures must be unaffected. It exposes ordering/replay complexity to reload callers: changing documents clears their viewing choice. The command’s small signature hides less policy because callers must know scene lifetime, unlike a view setting. More canonical bind paths must understand diagnostic state. It loses on source-of-truth visibility and interface depth, not just implementation effort.

### C. In-place draw-time override and restore with renderer-local uniforms

Keep widget configuration but decorate shared materials, set channel uniforms around each draw and restore for captures. This would avoid attachment copies and preserve native deformation directly. To be complete it must serialize *all* shared-scene screen sibling and offscreen draws and make material/display changes part of that serialized boundary; Android’s ordered frame alone does not solve iOS’s later main-thread sibling draws. SceneKit’s public modifier API does not supply the presumed Metal per-renderer binding callback [S10]. Replacing it with SCNProgram loses native material processing; adding a cross-renderer scheduler/locks or copied shader pipeline exceeds this bounded feature. Rejected on a concrete isolation failure and missing API support. No inferred per-draw uniform support is used in A.

## Synthesis decision

Candidate A is this runner’s independently selected base. Parent synthesis is not performed here. No other candidate or rubric was read, and nothing was borrowed from another runner. Same Codex model family; no provider-diversity claim. A parent may reject its private presentation cost, but should then identify a source-supported renderer-local isolation mechanism rather than quietly falling back to C.

## Tradeoffs accepted

* We accept extra render attachments and per-frame pose/material synchronization while diagnostics are active in exchange for leaving authored resources and capture data untouched.
* We accept native-specific implementations behind one public selection contract in exchange for retaining SceneKit/Filament material and deformation pipelines.
* We accept N/A markers for material channels absent from non-PBR families in exchange for truthful semantics; no invented metallic/roughness is claimed.
* We accept that blended pixels composite per-surface values in exchange for preserving real coverage/depth/blend behavior. Depth does not become a new nearest-transparent-surface renderer.
* We accept a bounded new diagnostic resolve branch and recipe options in exchange for a specified numeric transfer; no shader translation/reload or renderer fork.

## Red-flag screen

* Shallow module: caller does not coordinate enable/load/restore calls; two fields cover the operation.
* Information leakage: public enum names intent, not Filament packages, SCN shader stages, protocol strings, clip uniforms or native objects.
* Temporal decomposition/pass-throughs: existing realizer owns input meaning; presenter owns only screen derivative lifetime; host owns frame routing. Do not split these into load/validate/transform controllers.
* Split ownership: authored inputs have their existing writers. Presentation is derived, never a second resource registry or serialized truth. Effective-value binding extraction belongs beside those writers.
* Two ways: no new controller selector alongside widget props; no authored `d3:debug` extension. Existing raw configuration escape hatch is not an endorsed competing API.
* Importable internals: export only `SceneDebugChannel` with existing `SceneView`; native implementations and wire stay private.
* Hand-synced lists: one Dart channel enum is the public vocabulary; native protocol decoding necessarily mirrors the six wire strings, checked by a focused codec contract check. One recipe generator supplies ordinary/diagnostic sampling, not hand-copied channel sampler lists. Family switches stay in existing family owners.
* Over-engineering check: no registry/modifier framework, new clock, revision protocol, shader fork or renderer rewrite. Attachment isolation is required by current reachable targets/siblings; its cost is the primary risk to pressure during implementation.

## Open questions and risks

These are implementation proof questions, not a new permission checkpoint.

1. Can SceneKit presentation attachment copies, with explicitly remapped skin/morph/bind state, reproduce a known deformed primitive at the same pose without a second simulation step? The public attachment constructors support the route; the opaque-quad receipt does not answer it.
2. Does SceneKit’s live shadow-only path provide the same footprint alpha when diagnostic RGB replaces the final fragment? If not, what narrow family-owned hook exposes the real footprint without copying the shadow renderer? Do not paint a generic opaque receiver or declare parity. This can block completion of that family.
3. Does the Android post-lighting diagnostic recipe compile with the required alpha/material variants when SSR/refraction output is omitted, and remain invariant under zero/multiple lights and IBL/emissive changes? Installed/pinned APIs support the proposed stage; GPU/compiler acceptance is NOT_RUN.
4. Do Filament LINES preserve skin/morph/native-instance positions and occlusion with the chosen small bias on GL and Vulkan? Actual edges and bindings are source-feasible, but line raster behavior is unproven.
5. Can the numeric resolve meet literal RGB controls through current camera/output formats? Neither the iOS historical packed output nor `postProcessingEnabled=false` alone answers this.
6. Can existing generated particle/trail owners supply exact live draw bindings without a broad rendering abstraction? They must be integrated at their native owners; a document mesh-only enumeration would be a reachable omission.

Android packages are a concrete delivery dependency: `MaterialRecipe` currently lacks the wrapper for the installed compiler’s post-lighting blending operation; diagnostic recipes change package fingerprints and require shipped packages through the documented device baking tool [M2]. A142 is reserved and no alternative device use is authorized here. This design performs no bake and claims no host-compiler substitute. These are capability/delivery constraints, not reasons to widen W34.

## Next implementation step and decisive proof

First build a vertical slice of the two widget fields, typed native view config, and **one opaque mapped PBR quad’s screen-only normal presentation plus independent triangle wire overlay on both platforms**, retaining canonical authored material/capture data. Include the internal diagonal and a literal RGB control. This is the first proportionate slice of W34, not a reduced definition of W34 completion. No fresh architecture approval gate is required.

Decisive checks, to run later under parent authorization and existing program gates:

1. Verify mapped regions differ from a geometric-normal control and agree with chosen view-space orientation. Change direct lights from zero to multiple and alter IBL/emissive; selected-channel pixels must remain invariant. Use literal .125/.5/.875 interiors to establish the stated transfer, rather than interpreting packed screenshots as raw values.
2. Render one authored texture target and refresh a baked capture while channel/wire is selected; compare their bytes/output with debug-off under the same canonical state. Exercise an existing additional screen camera. This directly decides isolation instead of assuming it from main-screen pixels.
3. While selected, update a factor/texture and replace the document; then off must match a direct ordinary render of the latest authored state. Check one skinned/morphed primitive, one native instance chunk and one LOD/facing replacement with an occluder; wire follows actual triangles. Extend the same route to the remaining four channels and existing families, including mask/sprite/catcher coverage, to close the original W34 floor.

These are focused T3 behavior proofs. Existing T1/T2 and operator T4 in `docs/program-v2.md:201–245` still apply to landing. No invented ten-lane matrix, no new perf acceptance number, and no claim that one quad discharges native integration. Current task results: source feasibility/design review only; runtime, build, tests, device/simulator queries, GPU compilation, material baking and performance **NOT_RUN**. No production API, E9 or Track E acceptance.

## Source citations and evidence status

Repository references are to this prepared checkout with accepted58 imported unchanged. Line ranges identify the inspected owner; proposed new code has no source acceptance implied.

* [S1] `dart3d/lib/src/scene_view.dart:45–246`: public configuration, mount-before-attach, update diff and explicit quality clearing.
* [S2] `dart3d/lib/src/scene_controller.dart:268–291,397–415,575–579,1165–1204`: full load, highlight lifetime, raw view config and attach/reload behavior; `lib/src/protocol.dart:25,306,402`: existing viewConfig transport.
* [S3] `dart3d/ios/Classes/SceneViewHost.swift:1312–1390,5354–5370,5706–5721,5726–5827`: native config, mutation/animation frame, capture/target/screen ordering and facing geometry.
* [S4] `dart3d/ios/Classes/RenderTargets.swift:445–628`: screen modes, blank-host/sibling infrastructure, paused on-demand siblings, main-thread handoff and camera rebind. Current code shares canonical scene; screen-only projection is proposed.
* [S5] `dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt:2487–2543,5835–5884`: native config and canonical offscreen-before-screen schedule.
* [S6] Android `FsceneRealizer.kt:95–130,700–793,2083–2210,3310–3415`: GPU mesh ownership, node/chunk buffers, actual material consumers and skin/morph renderable attach. `Dart3dView.kt:623–632`: shared owned skin buffer.
* [S7] Android `MaterialPackages.kt:840–965,1017–1094,1253–1268`: recipe setup, actual sample/factor and prepare ordering; `MaterialRecipe.kt:19–112`: fingerprinted builder operations. Sampling is actual renderer input, not a second CPU decode.
* [S8] iOS `FsceneRealizer.swift:2430–2619,6755–6826`: actual material families, sprite coverage/tint, PBR factors, modifier composition and primitive skinners.
* [S9] iOS `BakedShadowCatchers.swift:238–269`: detached geometry/material/camera attachment copies; `SceneViewHost.swift:361–482` and `ToneMapping.swift:349–407,436–520`: camera packing, current shared-camera effects and screen resolve. Copy precedent does not itself prove skinned diagnostic projection.
* [S10] Installed `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNShadable.h:39–80,96–185,408–577`: binding limitation, modifier order/semantics, view transforms and resolved fields. New finding used to reject renderer-local uniform shortcut.
* [S11] Android `RenderTargets.kt:1–20,65–155`: screen View reuse, per-view records and camera clipping/projection specs.
* [M1] `/private/tmp/dart3d-e9-debug-source-20261027/ios/source-map.md`, read in full: SDK wireframe hook, actual clone/LOD/catcher/material-sharing owners and source fingerprints. Its NOT_RUN statements concern that investigation; use the later bounded receipt below for the quad only.
* [M2] `/private/tmp/dart3d-e9-debug-source-20261027/android/source-map.md`, read in full: installed Filament/filamat 1.77.3 APIs, pinned vendor stages/reflection bypass, gltfio AABB limitation, package/bake route. These are imported source-grounding facts, not fresh runtime observations.
* [E1] `/private/tmp/dart3d-e9-debug-native-review-20261027/r1/report.md`, read in full: independent offline review PASS for the opaque-quad mapped/geometric/literal controls, filled triangle diagonal and fixed-state restoration. Runtime was parent-produced. No cross-family/current-update/capture/projection proof is inferred.
* [G1] `/private/tmp/dart3d-e9-debug-design-20261027/grounding.md`, read in full: shared scope and source identity. Its scoped PR/Linear searches are parent-supplied historical grounding, not independently refreshed claims of absence here. No external query/write was performed.
* [P1] `docs/full-engine-program.md:1126–1140`, `docs/program-v2.md:201–245,411`: exact W34 behavior floor, superseding verification gate and E9 versus W28 boundary.

The architect skill and runner, rationale-template and red-flags references were read in full. The parent owns the workflow: this runner performed no arena, child delegation, agreement phase, implementation or synthesis across candidates. The shared grounding supplies the subsystem explanation; additional source inspection above checks the load-bearing ownership. No historical architectural motive is asserted.

## Snapshot preservation and retained artifacts

Archive SHA-256 independently matched `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706`. The prepared worktree was clean at the required base before import. Only the supplied accepted58 archive was extracted there; all 58 adjacent-manifest hashes checked OK immediately. The imported files were not edited afterward. No temporary probe source was imported. The parent checkout and other candidate directories were not written or inspected.

Retain the accepted58 overlay in this prepared worktree for parent inspection. Retain only this `design.md` and adjacent `import-sha256.txt`, `locks-sha256.txt`, `preservation.txt` and `design-sha256.txt` in candidate-a. The six preserved lock/registrant files are `dart3d/pubspec.lock`, `dart3d/example/pubspec.lock`, `dart3d/example/dn_plugins.lock`, `dart3d/example/lib/dartnative_plugin_registrant.dart`, `dart3d/example/ios/Podfile.lock`, and `probe/pubspec.lock`; none is part of the accepted58 archive. No dependency command ran. Final checks and the artifact hash are in adjacent receipts. No scratch source, generated packages, preview, process, build output, commit or external write was created.
