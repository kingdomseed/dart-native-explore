# Extended surface program — follow-on workstreams (W10 deliverable 2)

The sequenced follow-on plan for the audit's survivors
(`extended-surface-audit.md`). Every workstream carries the program's
verification rule: unit + live on both device surfaces + evidence
recorded. Ordering is dependency-first, then user priority — the stated
end goal is flutter_scene demo fidelity (glTF scenes with IBL,
materials, animation), so the animation stack leads.

Dependencies listed are *hard* deps — a workstream must not start
before its deps land. All workstreams listed here depend on the W9 head
already being in place.

## W11 — Skins, skeletal animation, morph targets — SHIPPED

**Why first.** The stated fidelity target is animated glTF content;
every flutter_scene demo that matters exercises this stack.

**Status: shipped, live-verified on both platforms** —
`docs/animation-skins-morphs-spec.md` + lanes in
`dart3d-completion-program.md`; evidence `/tmp/dart3d-lanes/w11-*`.
Deviation from the plan below: engine conveniences can't express
upstream's weighted clip mixing, so both platforms implement the same
small sampler natively (upstream `AnimationPlayer` semantics — weight
normalization over registered clips, lerp/slerp, clamp+pause or wrap,
bind-pose-once) instead of `CAKeyframeAnimation`/platform animation.

- Decode manifest `skins` blocks — `SkinSpec.joints`,
  `inverseBindMatrices` payload, `skeleton` root; bind to nodes via the
  `skin` member on mesh components. **Done** — deferred binding when
  `upsertSkin` lands after `addNode`.
- Decode `animations` blocks — `AnimationChannelSpec` (target node,
  property ∈ translation/rotation/scale/weights, timeline payload,
  keyframes payload). **Done** — channels resolve by stable target id
  first, name fallback.
- iOS: `SCNSkinner` + bone geometry sources (f32 joints repacked to
  u16 — SceneKit caps `.boneIndices` at 2 B/component); `SCNMorpher`
  `.normalized`; sampler in `renderer(_:updateAtTime:)`. **Done.**
- Android: `SkinningBuffer` + `BONE_INDICES`/`BONE_WEIGHTS` vertex
  attrs; clip sampler (timeline → TRS → joint world matrices → bone
  matrices per frame) in the Choreographer loop. **Done.**
- Morph targets: `MorphTargetsSpec` deltas → absolute → `SCNMorpher`
  (iOS) / `MorphTargetBuffer` + `setMorphWeights` (Android). **Done.**
- New wire ops: `anim` play/pause/stop + time/timeScale/weight/loop
  knobs, `setMorphWeights`, skin/anim upsert+remove. **Done** —
  canonical diff ordering (removals → resources → nodes → skins →
  anims → stage).
- Dart API: `SceneAnimation` handle + play controls; `skins`/
  `animations` emit through the diff path. **Done.**
- Bonus fix: `upsertPayload` carries spec metadata + persistent
  `opPayloadSpecs` — runtime-minted chunks decode like manifest
  payloads (unblocks W15 streaming).

**Verification.** Programmatic two-joint skinned flag + morph blob +
`wave`/`pulse` clips in `feature_scene`: silhouettes differ between
wave phases on both platforms, `live=` joint pose oscillates at wave
period, seek + direct weight write land clean, `anims: 2 playing`,
60 fps iOS / 82 fps Android, full W5–W9 regression intact.

## W12 — Cheap parity wins: joint components, rectAreaLight, material variants, `enabled`, feature gating

**Why second.** All five are small; joint components close a real
interchange gap (upstream-authored documents can declare joints).

**Scope.**

- Decode the five joint component types (`fixedJoint`,
  `sphericalJoint`, `revoluteJoint`, `prismaticJoint`, `genericJoint`)
  — one-sided components with an `otherNode` ref — into the existing
  W9 constraint path on both platforms. Deferred realization when
  `otherNode` isn't live yet (same rule as W9 ops).
- iOS `rectAreaLight`: apply `width`/`height` → `areaExtents`/
  `areaType`/`drawsArea`. Android: four-point-light approximation on
  child entities at the rect corners (intensity/4, warned once) — the
  visible emitter stays document-authored (emissive mesh); Filament
  has no area-light type on this path.
- `materialsVariants`: bindings decode; `selected` applies the swaps
  (`geometry.materials[i]` / `setMaterialInstanceAt`); runtime select
  rides `updateNode` components re-decode or a `selectVariant` op.
- `enabled` universal component property — **corrected scope**:
  upstream `Component.enabled` gates `update`/`fixedUpdate` ticks and
  the planar-reflector capture check only; it does NOT gate light
  emission, camera selection, mesh draw, or physics (a `enabled:false`
  light still lights upstream). W12 decodes and stores the flag on
  both platforms — round-trip fidelity plus the hook future
  tick-gated components (W18) consult — with a logged note, not a
  visual gate.
- `featuresRequired` capability warning — the format gate fires
  Dart-side at decode; add a Dart pass that warns when a loaded
  document requires a feature (`skinning`, `streaming`,
  `renderTextures`, `prefabInstances`) natives don't yet realize, so
  degraded docs are loud instead of silent.

**Verification.** An upstream-shaped document carrying a joint
component produces the same constraint the W9 rig built via ops; a
rect-area-lit surface visible both platforms; variant swap live; a
`enabled:false` light demonstrably still ON (the flag gates component
ticks, not emission — recorded, logged once, not applied); a
skinning-required doc logs the capability warning.

**Status: shipped, live-verified both platforms** (2026-09-16). All
five joint component types decode + translate onto the W9 wire shape
and defer until bodies are live; world-anchored joints (absent
`otherNode`, nullable `b` on the wire) verified — anchor body holds at
spawn, free body lands, fixed-joint pair holds ~0.6 u. iOS generic-axis
default corrected `.locked`→`.free` to match upstream/Android; iOS
motor passthrough widened to the full upstream field set. iOS
`rectAreaLight` = `SCNLight.area` + `areaExtents`; Android = 4-point
cluster (documented approximation). `enabled` recorded not applied.
`materialsVariants` decodes + applies + runtime `selectVariant`
verified with native trace (`selIdx 0→1→null`, `target=variant→variant
→default`) and visuals (cyan→magenta→orange in the second view) on both
platforms. Capability warnings covered by `component_capabilities_test`.
94 tests green; analyze clean; Android `assembleRelease` incl. R8 clean.
Two permanent diagnostics added while verifying: pending-binding
warnings (`variant.unresolved`/`variant.norenderable`) and per-apply
`variant apply`/`selectVariant` trace lines — sim stalls made
screenshot timing unreliable, so the writes are now positively logged.
Detail in `verification-matrix.md` W12.

## W13 — Environment effects subset (implemented, live-verified)

**Why here.** Big fidelity lever; the well-mapped subset lands without
blocked fields.

**Landed.** `StageEffects` value type on both platforms — 14 nested
block structs mirroring the wire blocks at upstream defaults
(`ios/Classes/StageEffects.swift`,
`android/.../StageEffects.kt`). Decoded inside `decodeStage`; a
present `effects` key wholesale-replaces `host.lastEffects`, an
absent key retains it — the key's presence *is* `overridesEffects`
on the wire. Apply is absolute every decode (enabled → value,
disabled → off) so re-realization storms leave no stale state.
iOS applies via `SceneViewHost.applyStageEffects` at all six
`applyStageExposure` sites (SCNCamera objects are transient);
Android applies to the persistent `View`'s options objects, merging
`colorGrading` into the existing `applyStageLook` builder chain.

**Support matrix** (approx = mapped with documented approximation):

| Block | iOS SceneKit | Android Filament |
|---|---|---|
| colorGrading | approx — saturation/contrast/whiteBalance direct; brightness→`exposureOffset`; lift/gamma/gain+LUT no-op (`fx.colorGrading.*`) | applied — `contrast`/`saturation`/`whiteBalance`/`exposure(log2 brightness)`/`slopeOffsetPower`(ASC CDL); LUT no-op |
| bloom | applied — threshold/intensity/blurRadius←scatter | approx — `strength`/`highlight`/`levels`←scatter |
| lensFlare | no-op (`fx.lensFlare`) | applied — full `BloomOptions` flare sub-stack |
| vignette | applied — `vignettingIntensity`/`Power` | approx — `midPoint`/`feather`/alpha-carried intensity |
| chromaticAberration | applied — `colorFringeStrength` | flare-scoped only (`fx.ca` warns without lensFlare) |
| filmGrain | applied — `grainIntensity` | no-op (`fx.filmGrain`) |
| ambientOcclusion | applied — SSAO intensity/radius/bias | applied — full options incl. `groundTruth`→SSCT |
| screenSpaceReflections | no-op (`fx.screenSpaceReflections`) | applied — `ScreenSpaceReflectionsOptions` |
| globalIllumination | no-op | no-op |
| temporalAntiAliasing | applied (device; `fx.taa.sim` on simulator) | applied — feedback/filterWidth only |
| fog | approx — color/start/end/densityExponent; no height/in-scatter | applied — `FogOptions` incl. height/falloff/in-scatter |
| godRays | no-op | no-op |
| depthOfField | applied — wantsDoF/focusDistance/fStop/blades/samples | approx — `cocScale`/maxCoC/aperture←f/fStop/`camera.focusDistance` |
| autoExposure | applied — `wantsExposureAdaptation`+min/max/speeds | no-op (`fx.autoExposure`) |

**Scope decision.** `stage.renderScale`/`filterQuality`/
`antiAliasing` folded to W14 — per-view config (views[] overrides),
not environment look. `environmentVolume`/per-volume blending stays
W20. LUT needs an asset-resolution path — deferred, warn-once both
platforms.

**Verification.** Each effect toggled live on both surfaces via the
8-step `w13` harness phase (+34 s); combined bloom+AO+fog+DoF frames
captured at `w13/ios-stack2.png` and `w13/android-stack5.png`.

## W14 — Render textures and views

**Depends on:** W13 not required; stands alone after W9. **DONE —
live-verified both platforms.**

**Implemented.**

- `RenderTextureResource` decode: `SCNRenderer` offscreen →
  `MTLTexture` → material `contents` (iOS, driven from
  `willRenderScene` on the view's command queue — never
  `renderAtTime`); `RenderTarget` + per-entry `View` with
  `setRenderTarget` (Android). `update` scheduler: `everyFrame` /
  `interval` (`intervalMilliseconds`) / `manual`.
- `views[]` decode: each entry resolves `camera` (node ref) + `target`
  (`rt:` ref or screen), `layerMask`, `order`, per-view
  `antiAliasing`/`renderScale`/`filterQuality`. Texture-target views
  render before screen views (produce-before-consume), `order`-sorted
  per target.
- New ops (dart3d extensions, upstream has neither):
  `{"op":"render","target":"rt:…"}` triggers a `manual` rt (or forces
  an `interval` refresh); `{"op":"updateViews","views":[…]}`
  wholesale-replaces the view list at runtime (`composeScene` drops
  `views`, so install-time alone can't express a list change).
- Wire extension `"viewport":[l,b,w,h]` on view entries — additive,
  upstream readers ignore it; Android realises a real second viewport
  (Filament viewport origin is bottom-left); W24 iOS siblings lay out
  by the same rect. Texture-target entries: Android honors the
  rect; iOS ignores it and fills the rt (`w24.viewport.rt`
  warn-once). A malformed ≠4-element rect warns and drops to full
  target.
- AA resolve chain: `view.antiAliasing` → `stage.antiAliasing` →
  widget `viewConfig.antialiasingMode` → platform default. `msaa`→4x,
  `fxaa`→FXAA, `auto`→inherit; `smaa`/`taa` warn-once and inherit
  (TAA lives in the effects block). iOS `fxaa` warns + falls back to
  MSAA.
- `renderScale`: screen entries only — Android
  `DynamicResolutionOptions` (min==max pins a fixed scale); iOS
  `contentScaleFactor` (documented approximation). RT dims are
  authoritative and ignore it. `filterQuality` decodes + retains;
  warn-once — no faithful native knob on either platform.
- `layerMask`: iOS `camera.categoryBitMask` (`0xFFFFFFFF`→`UInt.max`);
  Android `setVisibleLayers` low-8 + warn-once on high bits.
- Screen-target entries: iOS lowest-`order` wins `pointOfView`
  (split-screen is offscreen-only); Android renders additional passes
  on the shared `view` with per-pass camera/viewport/layers/quality.
- Offscreen Views set `isPostProcessingEnabled = false` — a custom
  `RenderTarget` otherwise routes through an intermediate blit; the
  color attachment holds the literal pass.
- `{'rref':'rt:…'}` material slots bind the live color texture with
  the rt's own filter/wrap sampler (Android can't reuse the shared
  `textureSampler`); `textureConsumers` rebinds consumers on rt
  upsert before old textures die.

**Prerequisite fixes landed during bring-up.**

- Android procedural generators (`cuboid`/`sphere`/`plane`/`torus`)
  now emit the same 13-float `[pos3|quat4|uv2|color4]` record as the
  payload path — without UV0, Filament rejected the material instance
  and textured procedural meshes silently kept their fallback.
- `p3t4` payloads expand into the 52-byte native record (fabricated
  `[0,0]` uv + white color — iOS parity) instead of passing the raw
  28-byte wire records through; the passthrough crashed once the
  shared stride moved to 52.

**Verification.** The `w14` harness phase (+50 s): everyFrame rt →
manual rt + `render` op → second producer on one target → list
reduction → stage AA/renderScale update → reset → showcase step
(material rebind + cube front-center). Both platforms ran the full
sequence clean. The consuming cube's faces display the live rt feed —
content visibly changes as dice tumble through rtCam's view. Android
verification additionally used a `readPixels(RenderTarget)` probe
(since removed): the colour attachment held real scene content
(12+/25 quantised distinct colours) and the bound texture object
identity matched `rec.colorTex`. No `w14.*` warnings on either
platform.

## W15 — Prefabs and subtree streaming — DONE (implemented, live-verified)

**Scope.**

- Dart: `composeSceneAsync` expansion for eager `instance` prefabs
  before `loadScene` (compose.dart imports verified clean of
  `package:archive`).
- Wire ops: `loadSubtree` (composed subtree manifest + payloads — reuse
  addNode/upsertResource/upsertPayload batching) and `unloadSubtree`
  (reuse `removeNode`); lazy placeholders arrive as tagged nodes.
- `overrides`/`attachments`/`removedNodes`/`memberComponents`/
  `addedComponents` per upstream compose semantics.
- Host asset resolution for `source` AssetRef stays host-layer; dart3d
  takes resolved bytes/documents.

**Verification.** Lazy subtree streams in/out live on both platforms;
overrides apply.

**As built.** A node whose spec carries `instance` is a lazy prefab
placeholder: it rides the manifest (or an `addNode`) tagged and
contentless, and the natives record the member raw
(`instanceSpecs`/`NodeRec.instanceSpec`) without realizing content.
`SceneController.loadSubtree`/`loadSubtreeAsync` compose the
placeholder's prefab through upstream `composeScene`/`composeSceneAsync`
on a scratch document (load flipped to eager; compose's in-place
mutations stay off the tracked document) and ship the expansion as the
standard structural batch inside one envelope op —
`{"op":"loadSubtree","node":"<id>","ops":[…]}` — so the subtree lands
through the same decode paths a diff uses: payload/resource upserts
first, then the instance's own `updateNode` (an explicit
`instance: null` in the spec clears the tag — absent preserves it,
which is what keeps the reparent-only graft/ungraft updates from
stripping it), member `addNode`s parent-before-child,
`Attachment` grafts as reparent-only `updateNode`s, then
skin/animation upserts. `unloadSubtree` ships the reverse batch:
attachment targets reparent to their authored parents,
`removeSkin`/`removeAnimation` retract the pools the load upserted,
`removeNode` drops each streamed root, and a final `updateNode`
restores the placeholder spec so the node re-tags for the next
load. Upserted payloads and resources persist across unload by
design — their ids are shared per prefab document and the
vocabulary has no remove ops for them. Per-instance
ids derive from (instance id, prefab-local id) and shared
resource/payload ids from the prefab's document identity, exactly as a
pre-realize compose produces — a streamed subtree is
indistinguishable on the wire from one that arrived expanded.
`removedComponentTypes` is honored too. Nested lazy instances inside a
streamed prefab keep their `instance` member (prefab-local id space
per upstream's unremapped rule) and arrive as placeholders a later
`loadSubtree` resolves — the stream record's `placeholders` map
carries their specs since streamed members never join the tracked
document. Nested ops dispatch through the same command
handler inside one mutation-queue drain, so a subtree lands/drops
atomically between frames; repeated ops follow the carried ops'
idempotency rules. Wire contract documented in `protocol.dart` (W15
section). New API: `loadSubtree`, `loadSubtreeAsync`,
`unloadSubtree`, `loadDocumentComposed`, `encodeSubtreeLoad`,
`encodeSubtreeLoadAsync`, `encodeSubtreeUnload`, `StreamedSubtree`
(`subtree_stream.dart`, exported via the barrel).

**Evidence.** 157 `dn test` (7 new in
`example/test/subtree_stream_test.dart`: placeholder-tag encoding, the
canonical batch shape, overrides/memberComponents/addedComponents/
removedComponentTypes/attachments inside the emitted ops, nested lazy
passthrough, priorRoots replacement, the unload reversal, and the
diff bridge); `dn analyze` clean. Live lane in the example harness at
+112 s: `streamA`/`streamB` lazy placeholders for a 100-cell grid
prefab — A streams plain, B streams with a material override on the
peak, one corner cell removed, an added point light, and the `beacon`
host node grafted under the peak; the peak's vertex chunk is declared
byte-less and lands via a post-load `upsertPayload` (deferred-arrival
lane); streamA then unloads/re-streams three times for the
no-stale-nodes check. Dart logs send timestamps; both natives log
apply→first-visible-frame stamps for the manifest-to-visible metric.

## W16 — Trails and LOD

**Depends on:** none. **DONE — implemented both platforms; native
verification is compile-level only (no live device run yet).**

**Implemented.**

- `trail` component (upstream `TrailComponent` wire shape):
  `width`/`lifetime`/`minVertexDistance`/`maxPoints`/`emitting` plus
  the `widthOverTrail` curve (`{keys:[{t,v}]}`) and `colorOverTrail`
  gradient (`{stops:[{t,color}]}`) — upstream serializes no trail
  material; both natives draw a shared translucent vertex-color
  unlit double-sided default.
- iOS: a `d3trail:` child node carries a dynamic `SCNGeometry`
  ribbon — points record in world space, rebase to the child's
  local space through the inverse owner transform, and expand
  camera-facing per frame in `SceneViewHost`'s renderer callback
  (before render, same slot as skinning). Fewer than two live
  points hides the ribbon.
- Android: the trail is an unparented entity with a dynamic
  `VertexBuffer`/`IndexBuffer` (2 verts per anchor, POSITION+COLOR)
  filled world-space per frame — the verts ARE world space, so no
  rebase is needed; `stepFrame` ticks it after the camera update.
  The renderable builds `.culling(false)` — no static AABB can
  describe a per-frame ribbon, and a zero box at the unparented
  entity's identity transform would frustum-cull every off-axis
  trail.
- `lod` component (upstream `LodComponent` — which extends
  MeshComponent, so the lod owns the node's draw slot): ordered
  `levels` each carrying `geometry`+`material` refs and a
  descending `screenSize` threshold; `lodBias` scales the
  projected size. Level decode matches upstream `_levelEntries`:
  an entry drops only on a missing/mistyped geometry or material
  ref, while an absent/malformed `screenSize` decodes as `0.0` —
  the never-cull threshold. `hysteresis` is live — upstream's
  dead-band on both natives (wire default 0.1). `blendRange`
  decodes for wire parity — a documented no-op (upstream's
  cross-fade needs a per-material dither slot neither native
  carries; hard switch).
- iOS: the same explicit per-frame selection Android runs —
  level-0's local AABB (cached at rebind) transforms its 8
  corners through the node world transform into the world AABB,
  whose circumscribed sphere projects through upstream
  `lodScreenSize` (Euclidean camera distance, viewport-height
  fraction); `lodBias` scales, the `hysteresis` dead-band picks
  with the bound level as memory, `-1` culls. The bound level
  rides `node.geometry` swaps among per-level copies
  (dirty-checked; cull writes nil — children keep drawing,
  matching Android's entity unbind). SceneKit's `levelsOfDetail`
  is NOT used: probe-verified, its `screenSpaceRadius` is a
  max-projection-axis, half-viewport-diagonal metric on view
  depth (~1.5× the upstream crossing distance), and the tight
  level-0 bound isn't overridable. Level resources re-resolve
  through `lodResourceConsumers`/`pendingLodNodes` on landings.
- Android: the lod owns the node's renderable slot — per-frame
  `lodScreenSize` over the level-0 world-AABB circumscribed sphere
  selects the level (with the hysteresis dead-band), then
  `setGeometryAt`/`setMaterialInstanceAt` swap it (a foreign
  renderable is rebuilt single-primitive on takeover; a culled
  node leaves the scene until a later selection re-binds).
  mesh+lod on one node is last-write-wins, mirroring iOS's
  `node.geometry` overwrite order. Non-perspective cameras draw
  level 0, matching upstream.
- Shared Dart reference math in `dart3d/lib/src/trail_lod.dart`:
  `TrailPointBuffer` (upstream's update policy), the
  `expandTrailRibbon` port, `lodScreenSize`, `selectLodLevel`
  (now including upstream's hysteresis dead-band), and
  `decodeLodLevels` (upstream's `_levelEntries` fallback rule) —
  the natives port these verbatim; 26 pure-Dart tests cover the
  point buffer, ramps, expansion, selection thresholds, the
  dead-band arms, and the screenSize fallback.
- Harness: `w16Mover` carries `lod`+`trail`; the `w16Phase` lane
  (+140 s — staggered past W15's +112 s slot) drives it ~49.5 m
  out and back through all three thresholds and the cull floor
  with an x sway bending the ribbon.

**Verification.** `dn analyze` + `dn test` green (26 trail/lod
tests); Android `assembleRelease` builds the Kotlin path; the iOS
sources pass a syntax/typecheck pass. A trail following a moving
node and the distance-based geometry swap exercise on both
platforms via the `w16` harness lane — live device run still owed.

## W17 — skyEnvironment and physical sky

**Scope.** Port upstream's Rayleigh/Mie sky generator to equirect
pixels (pure math, like W7's studio generator); feed the existing env
pipeline both platforms; `skyEnvironment` relighting consumes it;
`PhysicalSkySpec` skybox source upgrades from the current gradient
approximation; sun direction can drive a directional light for
`skyEnvironment` parity.

**Verification.** Physical sky visible as background + IBL; sun disc
position tracks `sunDirection` on both.

## W18 — Particles

**Scope.**

- iOS `SCNParticleSystem` mapping: birthRate/lifeSpan/emitterShape/
  propertyControllers/imageSequence ≈ upstream modules; documented
  deltas — no `maxParticles` cap, no scheduled `bursts`, sprite-only
  (meshParticleEmitter falls back to sprites).
- Android: custom CPU sim → billboard `VertexBuffer` + in-app filamat
  material (compile pipeline exists); mesh particles = instanced
  renderables (cost documented).
- `fixedStep`/`maxFrameTime` determinism knobs documented where
  unmappable.

**Verification.** A fountain + a one-shot burst live on both
platforms; perf at 1000+ particles.

## W19 — Character controller

**Scope.**

- Android: `CharacterVirtual` + `ExtendedUpdateSettings`
  (`WalkStairs`/`StickToFloor`) — updated post-step in the existing
  fixed-step loop.
- iOS: kinematic capsule + sweep-and-slide over W8's
  `convexSweepTest`/`contactTest`; slope classification, autostep,
  snap-to-ground.
- Wire: `characterMove` op (desired displacement + dt); pose
  write-back to the node.

**Verification.** A capsule walks the feature scene, climbs a step,
slides on a steep slope — both platforms.

## W20 — Environment volumes and probes

**Depends on:** W13 (effects blending shares the coverage machinery).

**Scope.**

- `reflectionProbe`: iOS `SCNLightTypeProbe` radiance +
  `parallaxCorrectionEnabled` + `probeUpdateType`; Android custom
  6-face `RenderTarget` capture + `IBLPrefilterContext`.
- `irradianceVolume`: iOS irradiance probe (single-probe approx);
  Android per-object/camera-blended SH — grid semantics documented.
- `environmentVolume`: camera-in-volume coverage + crossfade; no
  native env lerp either side — preblend or hard-switch, documented.
- `priority`/`weight`/`blendDistance` semantics.

**Verification.** Walking the camera through a volume visibly changes
IBL; a reflection probe shows local reflections.

## Host-gated (not scheduled)

These depend on host-layer work outside the engine; each has an audit
row and an exclusion/sign-off box:

- **Widget slots** — needs a DartNative widget→texture bridge before
  the engine half matters.
- **Semantics** — needs the platform accessibility bridge design;
  engine contributes projection + occlusion when it lands.
- **Audio** — iOS `SCNAudioSource` could ride any later workstream;
  the Android backend is host work (asset delivery + mixer).
- **Splats** — excluded; needs dedicated renderer + asset path.
- **`.fsceneb`** — ~~excluded~~ **landed**: `fsceneb_reader.dart`
  decodes the container with `dart:io` gzip (archive shadowing only
  blocked upstream's reader file, not the format). Verified against
  the flutter_scene dice corpus on both platforms.

## Sequencing summary

```
W11 animation/skins/morphs ──┐ (user's stated fidelity target)
W12 joint components + rectArea + variants  (cheap; needs only W9)
W13 effects subset ──────────┤ feeds demo fidelity; W20 depends on it
W14 render textures + views ─┤ independent of W11-W13
W15 prefabs + streaming ─────┤ independent
W16 trails + LOD ────────────┤ independent
W17 skyEnvironment + physical sky ─┘ upgrades a W7 approximation
W18 particles ───────────────┐ largest subsystem work
W19 character controller ────┤ needs W8 queries (done)
W20 env volumes + probes ────┘ needs W13
```

No workstream depends on a later one. W11–W17 can reorder freely;
W18–W20 are subsystem-sized and deliberately last.

**Operator approval requested** — the audit, the five exclusions, and
this sequence.
