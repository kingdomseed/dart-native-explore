# Independent W34 production debug-view cross-judgment

**Reject all three as complete production architecture candidates.** An existing iOS `SCNParticleSystem` has meaningful sampled color, per-fragment depth and rendered triangle geometry, but none of A/B/C identifies a source-supported route to diagnose those live draws while preserving their existing owner. A’s instruction to enumerate generated draws does not supply that route. B and C correctly acknowledge the gap. This is a necessary reachable contract, not an optional extension or an N/A property.

**B ranks first on design merit, but is not selected as a complete base.** Its Android binding/range selection can use existing renderables without duplicating deformation or changing authored target scheduling. The source supports that shape with a precise preparation rule below. C’s explicit target route is also a real public capability, but its unqualified standalone-per-view loop changes an existing target-clear contract. A pays for per-screen attachment scenes on both platforms without resolving native particles.

This is source/design judgment. It is not whole-W34, E9 or Track E acceptance. Independent runtime, builds, tests, devices/simulators, GPU/material compilation, baking and performance: **NOT_RUN**. No provider diversity is claimed; this is an independent judgment within the Codex family.

## Rubric scores

The five criteria are copied from the original rubric. Scores assess the submitted designs, including acknowledged gaps: 3 = convincing within the source/design remit; 2 = substantial support with a bounded unresolved design detail; 1 = material contract gap or disproportionate unresolved machinery; 0 = no useful route. Acknowledging a blocker earns proof credit, not rendering completeness. Totals do not override necessary contracts.

| Original criterion | A | B | C |
| --- | --- | --- | --- |
| **1. Caller simplicity and scope** | **3** — one closed channel plus independent wire prop, existing viewConfig, release opt-in, no document pollution. | **3** — one small immutable view value expressing the same choices; no controller replay or authored state. | **3** — nullable channel plus independent wire prop, explicit private off encoding; same bounded scope. |
| **2. Ownership and lifetime** | **2** — current canonical owners and retirement are explicit; remapped pose/material packets across later main-thread screen draws require substantial synchronization. | **2** — canonical captures and current-binding restoration fit the owners; iOS packet synchronization and Android pre-frame preparation need exact implementation discipline. | **2** — completed images separate later siblings from material changes; shared skin/morph inputs and immutable image retirement remain unproved integration details. |
| **3. Rendering correctness** | **1** — sampled mesh hooks and true edges are grounded; no live native-particle attachment route; footprint-preserving live catchers add an unresolved family hook. | **1** — preserves actual Android deformation and gives explicit channel/coverage semantics; native particles and live catcher footprint access remain unresolved. | **1** — correctly distinguishes node-local skinner geometry, receiver inspection and explicit targets; native particles remain unresolved, and its proposed target loop loses current clear-once behavior. |
| **4. Implementation depth and proportionality** | **1** — deep public boundary, but per-camera presentations on both platforms, including ordinary wire-only fill, multiply attachment/pose/material work. | **2** — smallest supported Android shape, finite existing-owner changes and no new clock; appending physical edge slots across rebuild owners and iOS projection remain substantial. | **2** — fixed private output pass is coherent, but adds target/image lifetimes, composition, separate edge draws and changes authored target submission. No need for all of that has been established over B. |
| **5. Proof and uncertainty** | **2** — preserves quad limits and names useful checks, but “owners must expose generated draws” understates the specific SceneKit particle API gap. | **3** — names live native particles as a blocker and puts an emitter in the first decisive slice; does not claim Android or projection proof. | **2** — precise native-particle, transfer, vertex-color and proxy-wire caveats; treats target clearing mainly as a GPU question although the pinned source already exposes a necessary scheduling correction. |
| **Total / 15** | **9** | **11** | **10** |

References to candidates below use their original line numbers: [A](../candidate-a/design.md), [B](../candidate-b/design.md), [C](../candidate-c/design.md). All three were read end to end, including source lists and preservation sections. No parent-reading file, tracker/audit row or parent score was read.

## Source-verified findings and objections

### 1. Common blocking contract: native iOS particles are not material-bearing mesh attachments

The actual path is `FsceneRealizer.swift:6094–6375`: `decodeParticleEmitter` creates a native system, configures orientation, atlas/image/color and simulation, then attaches it with `node.addParticleSystem(sys)`. The mesh-emitter path at `:6279–6305` already degrades to native sprites. Its authored mesh material does not turn the resulting particles into ordinary `SCNMaterial` draws.

Installed iPhoneOS27.1 `SCNParticleSystem.h:197–203,310–377,406–423` exposes particle rendering configuration and simulation-property callbacks. The class conforms to `SCNAnimatable`, not `SCNShadable`. Those callbacks provide live particle property stripes; they do **not** expose the renderer’s sampled fragment color, per-fragment surface position, triangle index attachment or a material shader modifier. `emitterShape` is the birth shape, not the living particles’ rendered geometry.

Consequences for the submitted designs:

- **A, :113–116,181–183,298:** enumerating actual attachments works only where those attachments are available. Neither its source list nor generic generated-draw promise establishes a native-particle draw attachment. Reconstructing billboards from callback properties would be a new particle draw implementation, not borrowing existing geometry.
- **B, :201,263,348:** correctly admits that emitter configuration copying is not live-state projection. That admission leaves its complete scene projection contract open.
- **C, :190,263:** correctly identifies missing draw/material access. Its target texture cannot recover inaccessible per-surface inputs merely by containing ordinary particle color.

This is a blocking design-level omission for existing emitters under the requested scope. It is **not** a demonstrated GPU defect or a proof that every public SceneKit technique is impossible. N/A is legitimate for an unlit particle’s absent metallic lobe; it cannot replace its meaningful color/depth/geometry. Passing ordinary particles through unchanged, hiding them, copying their configuration into another advancing scene, or rebuilding their renderer would not close this contract.

### 2. B’s serial Android selection has a viable source route, with a preparation boundary

I checked the installed 1.77.3 Java API and downloaded pinned native source; retained copies are under [evidence/filament](evidence/filament/). The repo pin is `android/build.gradle:23`.

**Preparation and submission are different operations.** Successful swapchain `beginFrame` invokes engine preparation before returning; standalone rendering invokes preparation itself. Ordinary `render(view)` proceeds into view rendering without another engine-wide material preparation. Surface material uniforms/samplers are committed by `FEngine::prepare`, including instances not presently bound to visible primitives. See pinned [Renderer.cpp](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/src/details/Renderer.cpp), local lines 510–528,671–757; [Engine.cpp](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/src/details/Engine.cpp), local lines 759–799; and [MaterialInstance.cpp](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/src/details/MaterialInstance.cpp), local lines 215–273.

Therefore B must allocate/populate diagnostic counterparts and edge materials **before `beginFrame`**, using the existing current-input writers. Within the screen section it may select already-prepared material objects and primitive ranges. Creating or changing their surface parameters there and assuming `render()` uploads them is not supported. B’s two-destination writers permit the former; its `submitScreen` sketch must not be interpreted as permission for the latter. This is a concrete implementation condition, not a reason to reject serial binding selection outright.

The native binding setter changes a primitive’s material reference; render-command generation copies its current material, offset/count/type and morph offset. `renderInternal` submits work and finishes its jobs before returning. The source therefore supplies a route to encode authored target draws, select diagnostics for screen draws, then restore the current authored references without changing already-encoded primitive selections. It does not establish GPU pixels or transfer calibration. [RenderableManager.cpp](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/src/components/RenderableManager.cpp), local lines 866–900,971–994; [RenderPass.cpp](https://raw.githubusercontent.com/google/filament/v1.77.3/filament/src/RenderPass.cpp), local lines 674–709,1118–1127.

Zero edge count is also a real source route: installed indexed `setGeometryAt` exists, its public count permits zero, and native `FRenderPrimitive::set` retains that count. This supports B’s suppression of appended edges outside screen submission; it is stronger evidence than merely making edge materials transparent. Actual line/deformation/occlusion output remains NOT_RUN. Carrying per-primitive morph offsets and preserving authored slot indices are necessary, as B says. No source-level failure of this route was established.

### 3. C’s standalone API is valid; its unchanged authored-target clear behavior is not

C :156 moves every due authored target view to standalone submission before its diagnostic pass. The installed API supports a target-bearing standalone view outside the swapchain frame, and native preparation addresses new material uploads. A second swapchain frame is unnecessary.

There is, however, a reachable source-level mismatch in the loop as written:

1. Existing `Dart3dView.kt:1255–1262` sets renderer color clearing true.
2. `applyViews`, `:3506–3551`, allows several ordered views for one render target. Current `render`, `:5835–5860`, submits those views within one frame.
3. Pinned `Renderer.cpp:683` resets its previous-target tracking at **every standalone call**. At `:1067–1102`, first use of a target initializes clear flags; later views in the same ordinary frame retain color rather than repeating that first clear.

Thus replacing each `render(v)` with `renderStandaloneView(v)` while retaining current clear options repeats first-use color clear/discard for the same target. A later overlapping, layer-filtered view can erase earlier authored target content. Keeping order and dirty/last-render bookkeeping does not preserve that behavior.

**This is a design-level P2 for the unqualified multi-view-target route**, not an observed device failure. The smallest correction is an explicit first/subsequent-target-view color load/clear policy at the existing target owner, with ordinary screen clear state restored afterward. Depth already clears per view in the pinned renderer. This needs no new clock or renderer substitute, but C has not specified that policy. B does not require this scheduling change. Source references are the same pinned Renderer link above; use the retained file’s line numbers rather than cached web offsets.

### 4. Skinning distinguishes available inputs from proven output

The installed `SCNSkinner.h:40–48` explicitly makes node-local geometry the customization point for materials when a skinner is shared. C :136 is correct: diagnostic node geometry can be distinct without mutating the shared skinner’s `baseGeometry`. Rejecting C merely because it borrows a skinner would contradict that header. Its exact separate-scene result with live bones/morphing is still unrun.

A/B instead construct skin attachments over mapped presentation bones and current morph weights. The public constructor and readable weights/indices/IBMs/bind transform support that route; actual adapter attachment is visible at `FsceneRealizer.swift:6785–6821`. Their later main-thread sibling route explains why detached pose packets matter. It costs more than C’s synchronous explicit draw, but is not source-proven broken.

Do not graft C’s live-bone sharing blindly into A/B’s later main-thread rendering: that changes the synchronization premise. No deformed CPU mesh, second animator or second physics/particle clock is justified. Existing iOS baked-instance skin/morph omissions and Android first-primitive deformation policy remain existing behavior, not debug work to repair.

### 5. Current updates and captures are mostly well assigned

All three correctly keep view selection outside authored documents and use the existing config-before-controller-attach route (`scene_view.dart:165–193`; reattachment replay in `scene_controller.dart:1165–1183`). Full load/re-realization retires derivatives but retains applied view settings. Off must reveal current native authored state, not a saved material/stage snapshot.

The supplied authoritative source maps establish actual variants/defaults, double-sided clones, primitive children/slots, LOD, facing replacements, instance chunks, texture consumers and catcher rebinds. Each candidate explicitly follows **current bound occurrences**, rather than only the resource registry. None has implemented those connections. Current factor ownership is concrete (`MaterialColorOwner`, Swift :275–302); existing owners must feed diagnostic sinks with the same effective value. This does not authorize debug to repair unrelated pre-existing clone propagation or deformation limitations.

A/B’s detached main-thread screen attachments and C’s completed screen images structurally avoid material mutations leaking into later iOS siblings (`RenderTargets.swift:558–628`). B’s Android exception is temporal but source-supported under finding 2. Authored render targets and bake inputs must remain canonical; baked attachment copies and later modifier replacement are real consumers (`BakedShadowCatchers.swift:238–261,434–449`). C’s target-clear change is an additional constraint on that promise.

A’s ordinary wire-only projection also has to preserve authored light/environment/shadow participation, not merely current material arrays and tone settings. Its “renderables, pose nodes and view state” description does not spell out that lighting attachment policy. Existing light attachments make a route plausible, so I record this as an underspecified design obligation, not an established rendering defect. B/C retain ordinary screen fill for wire-only and avoid this extra projection obligation.

## Channel-policy decisions

The original W34 floor (`full-engine-program.md:1126–1140`) names resolved channels and filled wire overlay; it does not prescribe a depth palette, shadow-receiver coverage policy or N/A pattern. The shared grounding requires truthful sampled inputs and explicit meaning. I judge those distinctions as follows:

| Difference | Decision against the original contract |
| --- | --- |
| **A near/far-linear axial depth vs B/C fixed `d/(1+d)`** | Both inspect per-fragment forward eye depth, not radial distance or reverse-Z hardware depth. Both are valid explicit debug display choices. Prefer B/C’s fixed mapping for a bounded API: no per-camera range uniforms, consistent scene-unit scale. It must be labelled compressed axial depth, not a linearly spaced grayscale. A’s formula is not a P2 merely because it differs. |
| **A/B catcher footprint vs C opaque receiver inspection** | C’s explicit opaque receiver inspection is a valid chosen diagnostic semantic, not accidental alpha loss: the receiver has real normal/depth/topology even where shadow opacity is zero. A/B promise the existing footprint, which adds a live shadowOnly alpha-access question; ordinary PBR proof does not settle it. The original contract does not force that extra promise. These policies must not be silently combined. |
| **A captured baked diffuse RGB vs B/C catcher baseColor N/A** | The baked receiver really samples a capture texture; A truthfully labels that as captured receiver color. B/C instead define baseColor as a material base input and classify shadow tint/coverage as utility data. That explicit family definition is defensible under the unspecified original floor; it is not evidence that the texture cannot be accessed. A generic material with a meaningful base input may not be classified N/A this way. |
| **Flat magenta A/B vs magenta/gray checker C** | Both mark semantic absence. Prefer flat magenta: the checker adds pattern/screen-coordinate behavior without resolving a missing input. Neither is a capability fallback. |
| **Normals/roughness/base RGB** | All choose camera-space mapped base normals, sampled perceptual input roughness and pre-lighting factored color. These match the supplied source grounding. Ordinary SceneKit vertex-color inclusion needs C’s nonwhite control; a missing or double multiply is a risk, not a demonstrated GPU defect. |
| **Display neutralization** | All specify linear composition followed by one sRGB transfer and exclude authored lighting/effects from selected channels. The current artistic “linear” tone path and post-disable flag do not by themselves establish that transfer. C’s RGBA16F target makes the boundary explicit; A/B’s screen resolve branch can also meet it. Neither new path is calibrated by the old quad. |
| **Wire and occlusion** | All require actual triangle edges, internal diagonals and occlusion. Native iOS showWireframe is supported only to the bounded quad level by the receipt. Depth-only BLEND-proxy wire leakage and cutout behavior remain risks, not established defects. B/C’s wire-only use of the actual scene must test those proxies; A’s detached route must explicitly exclude them. |

Filament’s sampled material hook, SSR exclusion and post-lighting replacement are grounded in the accepted Android source map and freshly checked [surface_main.fs](https://raw.githubusercontent.com/google/filament/v1.77.3/shaders/src/surface_main.fs). The installed compiler exposes postLightingBlending; the repo wrapper must record it and adopted packages must use the existing fingerprint/bake process. No compiler acceptance or alternate host baking path is inferred.

## Direction, proportionality and bounded next step

**No complete base is approved. Do not integrate a mesh-only public debug feature and count native particles as deferred coverage.** B is the candidate to reconsider alone if the shared particle blocker is closed: its existing Android renderables and unchanged authored target loop are the smaller clean boundary. That ranking is not authorization for implementation or acceptance of B’s footprint promise.

Compatible small corrections are B’s explicit pre-begin material-preparation rule and C’s nonwhite vertex-color/proxy-wire controls. C’s node-local skinner fact is useful evidence, but its synchronous borrowing cannot be inserted into the asynchronous projection without proving that ownership change. No graft solves the particle gap. Reject a combined A presentation graph plus B temporary slots plus C target/image pipeline; it would retain the costs of all three. Also reject an authored-capture projection, universal G-buffer, generic modifier registry, shader translator/fork, new revision scheme, and particle reconstruction/simulation as ways to hide the gap.

**Minimum next proof: one bounded native-particle capability experiment before building the public API or broad projection.** Use one existing live native emitter beside the known indexed mapped quad. Investigate one renderer-local public `SCNTechnique` DRAW_SCENE/program route on the original native scene as a capability hypothesis (`SCNTechnique.h:26–47,108–109,178–180`). The header establishes a scene-pass mechanism; it does **not** establish that it intercepts native particle fragments or preserves their bindings. The experiment must establish that missing fact, not presume it.

A decisive result must show the same current particle population without a second simulation, sampled particle texture/tint color, axial fragment depth, and actual filled particle triangles/edges under an occluder, while an authored target remains unchanged. Simulation-property callbacks may observe population for comparison; they may not supply a new billboard renderer. If the public pass cannot expose the native draw/bindings without replacing that renderer, stop: the required scope remains blocked, and no broad material/projection implementation follows. This is a single capability answer, not another architecture tournament. No such experiment was performed here.

If that answer supplies a legal route, the next compact T3 fixture should exercise B’s preprepared screen binding switch with one authored render texture containing two ordered views, a current factor/texture edit while selected, and off to current authored state. Include the diagonal/occluder and literal RGB control already called for; do not rerun the old quad as if it proved new ownership. Existing `program-v2.md:201–235` T1/T2/T3/T4 governs later implementation. The old ten-lane swarm is superseded; no new acceptance matrix or performance gate is proposed. A142 remains reserved.

## Evidence and preservation

I verified the supplied archive SHA-256 `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706`, all 58 unique relative regular archive files against the adjacent manifest, and base HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. The prepared checkout was clean. I imported only accepted58 there as expressly authorized, then left it unchanged. No shell checkout was created. The 57 git deltas are entirely within accepted58; the remaining archive path was already byte-identical at base. All other tracked files and six locks/registrants remain unchanged.

Candidate design hashes independently match their adjacent receipts:

| Candidate | SHA-256 |
| --- | --- |
| A | `c27b074db770b117776fd3635ad842ec221346f8478e5cf75317ce815eef3e6c` |
| B | `65760c207d8e01db1a8a2883fb6244e325acb04c5efcc0b881643415880ed656` |
| C | `0e8baeae2452b4a8574bff4e656d61dac749bf4f65b79dac1a95423f0f31d3e0` |

I read the full rubric/grounding, both authoritative source maps and the bounded native-review report. The historical iOS PASS is accepted only for the original opaque quad, mapped/geometric/literal controls, actual diagonal and fixed restoration; I did not independently replay its runtime or artifact analysis. The production source is accepted58, without that removed probe. Supplied PR/Linear observations are historical context, not fresh absence claims. The repo README’s broad status paragraph and old W34 verification prose do not supersede program-v2. I also read the repo-local DartNative guide and verification guide; the referenced `dartnative/docs/plugin_development.md` is absent in this prepared checkout.

Kept: this `judge.md`; [evidence receipts and inputs](evidence/); the exact accepted58 overlay in this prepared checkout. Evidence contains the reproducible preservation script, import/source/lock/candidate hashes, line-numbered source excerpts, installed API signatures, pinned vendor source with URL/hash provenance, and final git status. Candidate directories, parent source and all imported files remain untouched after import. No scratch rendering/build/probe files were created; no scratch cleanup remains. No implementations, tests, builds, dependency/package/bake operations, device queries, commits, PR actions or external writes were performed.
