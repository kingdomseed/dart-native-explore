# Extended surface audit — every upstream codec family (W10)

The W10 deliverable: a complete inventory of the upstream `.fscene`
codec surface — every component codec type, every resource kind, every
document-level block — with a native feasibility verdict on both
platforms and a disposition (already realized, follow-on workstream, or
deliberate exclusion). The follow-on workstreams themselves are
sequenced in `extended-surface-program.md`.

## Sources and method

Upstream baseline:

- `scene-0.3.0` — the document model and JSON codec:
  `lib/src/specs.dart`, `lib/src/scene_document.dart`,
  `lib/src/json/fscene_json.dart`, `lib/src/physics/joint_desc.dart`,
  `lib/src/physics/queries.dart`, `lib/src/physics/events.dart`.
- `flutter_scene-0.23.0` — the component codec registry and runtime
  realization layer: `lib/src/fscene/realize/*.dart`.

dart3d coverage was verified against
`dart3d/ios/Classes/FsceneRealizer.swift`,
`dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt`,
and `dart3d/lib/src/*.dart` at the W9 head.

Counting rule (program perf probe): one audit row per upstream codec
family — the 29 fixed component codec types plus the resource/spec
families and document-level items that serialize through
`fscene_json.dart`. The placeholder codec (`PlaceholderCodec`,
`fscene/realize/placeholder_codec.dart:37`) is upstream's
unknown-component fallback, not a family — it is counted once as row 30
with the disposition "already realized" (both dart3d realizers already
log-and-skip unknown types, matching its contract).

## What already travels on the wire

`SceneController.loadDocument` sends the **canonical upstream manifest**
produced by upstream's own `fscene_json` encoder
(`scene_controller.dart:94`). Every manifest block upstream writes —
`nodes`, `resources`, `payloads`, `skins`, `animations`, `views`,
`stage` — is already on the wire when a document carries it; the Dart
document model is `package:scene` itself, so `SkinSpec`,
`AnimationSpec`, `MorphTargetsSpec`, `RenderViewSpec`, and
`RenderTextureResource` already parse and serialize end-to-end. The
diff layer reserves their id prefixes (`n`/`geo`/`mat`/`tex`/`rt`/
`env`/`skin`/`anim`/`chunk`, `diff_apply.dart:160`) and already ships
morph-target delta payloads (`_resourcePayloads`,
`diff_apply.dart:248`).

So for most families below the gap is **native decode + realize**, not
transport. Rows mark wire status explicitly where that differs.

## Format-level surface

Things that are not codec families but ride the format contract:

| Item | Upstream | dart3d status |
|---|---|---|
| `featuresRequired`/`featuresUsed` gate | `fscene_json.dart:16-21,886-888` — docs listing a feature outside `{skinning, prefabInstances, streaming, renderTextures}` are refused at decode | **inherited on the Dart side** — dart3d parses via upstream's decoder, so refusal fires in Dart before natives see the manifest. Residual gap: a doc *requiring* `skinning` parses (it is a supported feature) then silently drops skins on natives. A capability-warning pass (required features vs realized set) is a small row — folded into W12. |
| `.fsceneb` binary container | `fsceneb.dart` — `FSCB` magic, `JSON`+`BLOB`/`GZBL` chunks | **realized** — `lib/src/fsceneb_reader.dart` reads the container locally (`dart:io` gzip for `GZBL`; the patched SDK still shadows `package:archive`, so upstream's `fsceneb.dart` itself stays unimportable — `scene_model.dart:1-18`). Verified against the importer's converted dice corpus (d4–d20) on both platforms. |
| JSONC + migrations | `stripJsonc` + `_builtInMigrations` v1→v5 (`fscene_json.dart:30-46,140-152`) | **inherited** — upstream's decoder runs on the Dart side; migrations and comment-stripping come free. |
| Vertex layouts | `interleaved_layout.dart:146-148` — `unskinned_soa_uv1_tangent`, `unskinned_uv1_tangent`, `skinned_uv1_tangent`, legacy `unskinned_soa`/`skinned`/`unskinned` | all six accepted on both platforms; skinned layouts decode but joint/weight attrs are dropped pending W11. `p3t4` is a dart3d-native extension, not upstream. |
| `enabled` (universal component property) | applied by the registry around every codec (`component_codec.dart:64-71,202-205`) | **not decoded on either platform** — a disabled light/camera still activates. Small fix; folded into W12. |
| `placeholder` contract | changelog claims lossless `ForeignComponent` round-trip; **code drops unregistered types** (`component_codec.dart:200-207`, `realize.dart:160-165`) — lossless placeholders only exist when a tool registers a `PlaceholderComponentCodec` | dart3d's log-and-skip matches upstream's actual load behavior, not the changelog claim. Realized. |

## Realized today (both platforms)

Component codecs — decoded and realized in `decodeComponent` on both
realizers (Android `FsceneRealizer.kt:648-662`, iOS
`FsceneRealizer.swift:1216-1235`):

| Upstream type | dart3d status |
|---|---|
| `mesh` | realized both platforms (procedural + payload geometry, materials, primitives) |
| `camera` | realized both platforms (perspective + ortho, W6) |
| `directionalLight` / `pointLight` / `spotLight` | realized both platforms |
| `rectAreaLight` | iOS realized (`SCNLightType.area`); Android logs "not implemented" — row in the audit table |
| `rigidBody` / `collider` / `physicsWorld` | realized both platforms (W2, W6 parity) |
| placeholder (unknown types) | realized contract — both platforms log-and-skip |

Resource kinds (`specs.dart:278` `ResourceSpec` hierarchy):

| Kind | dart3d status |
|---|---|
| `GeometryResource` | realized — procedural (cuboid/plane/sphere/torus/icosphere) + payload vertices/indices; morph-delta payloads ship but morph decode is an audit row |
| `TextureResource` | realized (payload + asset paths) |
| `MaterialResource` | realized (PBR + unlit, emissive/doubleSided W6); W24 adds the `shadowCatcher` type — iOS `.shadowOnly` lighting model, Android unlit + `shadowMultiplier` filamat — both with logged per-field deltas |
| `EnvironmentResource` | realized (W7) minus two deferred members — `effects` and `skyEnvironment`, both audit rows |
| `RenderTextureResource` | **not realized** — audit row |

Document-level blocks:

| Block | dart3d status |
|---|---|
| `nodes` (transform/components/children/layers/visible) | realized + structural ops (W5) |
| `payloads` | realized (W3) + `upsertPayload` (W5) |
| `stage` (`environmentRef`, AA, camera) | realized (W1/W6/W7); `renderScale`/`filterQuality` audit row |
| `views` (`RenderViewSpec` list) | realized — rt-targeted entries W14; screen entries W24 (iOS sibling `SCNView` split, Android per-view `Viewport` passes). dart3d `viewport:[l,b,w,h]` extension rides a `Dart3dRenderViewSpec` subclass end-to-end |
| `skins` (`SkinSpec`) | manifest carries it; not decoded — audit row |
| `animations` (`AnimationSpec`) | manifest carries it; not decoded — audit row |
| prefab `instance` field (`PrefabInstanceSpec`) | not emitted by dart3d's diff (document model has no compose) — audit row |

Runtime surface beyond the document (W8/W9): contact events, pose/
raycast/overlap/shape-cast queries, `addJoint`/`updateJoint`/
`removeJoint` ops carrying `JointDesc` field-for-field, joint `broke`
events.

## Audit table — remaining upstream families

Rows: upstream family → upstream source → wire status today → iOS
native path → Android native path → verdict + disposition. The
dispositions feed `extended-surface-program.md`.

Verdict legend: **supported** — native API covers upstream semantics,
work is decode+glue; **partial** — some fields/behaviors unmappable
(named delta); **not feasible** — no native facility and no reasonable
approximation; **out-of-engine** — belongs to the host layer, engines
consume a texture/pose. Effort: small = decode + wire to an existing
knob; medium = real per-platform logic, no new subsystem; large = new
rendering/simulation subsystem.

### Rendering and animation

| Family | Upstream source | Wire today | iOS path | Android path | Verdict / effort |
|---|---|---|---|---|---|
| Skeletal animation + skins | `specs.dart:1068-1158` `SkinSpec`/`AnimationSpec`; realized `skin_animation.dart` | manifest `skins`/`animations` blocks carried, undecoded | `SCNSkinner` + bone attr `SCNGeometrySource`s; channels → `CAKeyframeAnimation` on joint keypaths | `SkinningBuffer` + `RenderableManager.skinning`, `BONE_INDICES`/`BONE_WEIGHTS` attrs; no clip player — custom sampler | **partial** — iOS medium, Android large; needs play/pause/seek op |
| Morph targets | `specs.dart:434-473` `MorphTargetsSpec` on `GeometryResource` | delta payloads already ship; weights/morph decode missing | `SCNMorpher` (targets, weights, calculationMode); delta→absolute CPU pass | `MorphTargetBuffer` + `RenderableManager.morphing`/`setMorphWeights`; same conversion | **supported** — medium; weight animation shares the skinning clock |
| Particles | `particle_emitter_codec.dart` (emitter, shape, modules, bursts) | component; arrives, hits unhandled | `SCNParticleSystem` — birthRate/lifeSpan/emitterShape/propertyControllers/flipbook ≈ most fields; no `maxParticles` cap, no scheduled `bursts`, no mesh particles | none — custom CPU sim → dynamic `VertexBuffer` + in-app filamat material (pipeline exists, `Dart3dView.kt:310`) | **partial iOS / not-stock Android** — iOS medium, Android large |
| Trails | `render_extras_codecs.dart:26-120` `TrailCodec` | component; unhandled | none native — dynamic `SCNGeometry` ribbon on a persistent `MTLBuffer`, per-frame via `SCNSceneRendererDelegate` | none native — dynamic `VertexBuffer` + strip `IndexBuffer` + custom material | **supported (custom)** — medium both |
| LOD | `render_extras_codecs.dart:124-308` `LodCodec` (`levels`+`screenSize`, `lodBias`, `hysteresis`, `blendRange`) | component; decoded | per-frame `lodScreenSize` selection (Android's algorithm ported — `SCNLevelOfDetail`'s metric is probe-verified incompatible) + `node.geometry` swap per level; hysteresis live; no blend | per-frame camera test + geometry/entity swap; hysteresis live; no blend | **supported (custom)** — done both; `blendRange` cross-fade is the remaining no-op |
| Gaussian splats | `render_extras_codecs.dart:349-522` `SplatCodec` (assetRef `.ply`/`.splat`, shDegree, crop) | **asset key, not a document resource** — needs asset→bytes path | none — `SCNProgram`/Metal or `SCNTechnique` dedicated renderer | none — custom material + sorted instanced quads | **not feasible stock** — large both; asset delivery is a prerequisite |
| Rect area light | `builtin_codecs.dart:1628-1697` | component; iOS decodes, Android logs | `.area` set today but `width`/`height`/`areaExtents` never applied — ~4 lines to finish | `LightManager.Type` 1.71.6 has no rectangle — emissive-quad + point cluster approximation | **partial** — iOS small, Android medium |
| Material variants | `builtin_codecs.dart:1350-1537` (`variants`, `selected`, `bindings`) | component; unhandled | `geometry.materials[i]` swap per binding | `RenderableManager.setMaterialInstanceAt` | **supported** — small-medium; `select` rides `updateNode` or a new op |
| Render textures | `specs.dart:498-531` `RenderTextureResource` (`width`/`height`/`updatePolicy`/`filter`/`wrap`) | resource spec carries; decode logs unimplemented | `SCNRenderer` offscreen → `MTLTexture` → `SCNMaterialProperty.contents`; scheduler per updatePolicy | `RenderTarget` + `View.setRenderTarget` + sample `Texture`; same scheduler | **supported** — medium both; manual policy needs a trigger op |
| Views (multi-view) | `specs.dart:1531-1570` `RenderViewSpec`; `scene_document.dart:79` | **realized W14+W24** — rt entries W14; screen entries land W24 | sibling `SCNView`s layered over the host (blank-camera host pass in split mode), `viewport` rects converted bottom-left→UIKit top-left, paused + poked from the host's render delegate | screen entries share `view` — per-pass camera/`Viewport`/layerMask/quality; `viewport` native (Filament is bottom-left too) | **landed** — sibling-vs-composited split is the documented platform delta; `layerMask` truncates to 8 bits on Filament |

### Environment and post-processing

| Family | Upstream source | Wire today | iOS path | Android path | Verdict / effort |
|---|---|---|---|---|---|
| `effects` post stack | `specs.dart:649-783+` `EnvironmentEffectsSpec` — grading/LUT, bloom+lensFlare, vignette, CA, filmGrain, AO, SSR, GI, TAA, fog, godRays, DoF, autoExposure | rides env resource; both log deferred | `SCNCamera` bloom/vignette/colorFringe/SSAO/DoF/exposure-adapt/LUT + `SCNScene.fog*` + `temporalAntialiasingEnabled`; no SSR/GI/godRays/lensFlare/filmGrain | `View` options: Bloom(+lensFlare/ghosts/halo/CA), AO(+SSCT), SSR, TAA, Fog, DoF, Vignette, `ColorGrading`; no filmGrain/standalone CA/autoExposure/GI | **partial** — medium subset, large full parity; no per-volume blending either side |
| `skyEnvironment` relighting | `EnvironmentResource.skyEnvironment` (`specs.dart:632`) | carried; both log deferred | procedural-sky pixels → `lightingEnvironment` (equirect synth exists) | procedural sky → `Skybox`+`IBLPrefilterContext` | **supported** — medium (generator port) |
| Physical sky | `specs.dart:1355-1404` `PhysicalSkySpec` | skybox source `physical` already decodes → gradient approx today | port Rayleigh/Mie generator → equirect (plumbing exists) | same → `Skybox` + prefilter | **supported** — medium; upgrades an existing approximation |
| environmentVolume | `builtin_codecs.dart:77-198` (`environment` ref, shape, extents, blendDistance, priority) | component; unhandled | no native env-volume blending — camera-in-volume test + `lightingEnvironment` crossfade (no native lerp) | one `IndirectLight` per `Scene` — volumes = custom captures + blend | **partial** — large |
| irradianceVolume | `builtin_codecs.dart:1700-1746` (SH probe grid) | component; unhandled | `SCNLightTypeProbe` irradiance — single probe approx, grid not native | custom SH eval / per-object SH — no facility | **partial** — large |
| reflectionProbe | `builtin_codecs.dart:1547-1625` (extents, faceResolution, captureOnActivate, parallax box) | component; unhandled | `SCNLightTypeProbe` radiance + `probeUpdateType` + `parallaxCorrectionEnabled` — maps well | 6-face `RenderTarget` capture + `IBLPrefilterContext` — custom | **partial** — iOS medium, Android large |

### Physics and gameplay

| Family | Upstream source | Wire today | iOS path | Android path | Verdict / effort |
|---|---|---|---|---|---|
| Joint components ×5 | `physics_codecs.dart:855-1240` — `fixedJoint`/`sphericalJoint`/`revoluteJoint`/`prismaticJoint`/`genericJoint` (one-sided, `otherNode` ref) | components; unhandled — but W9 constraint machinery exists | decode → synthesize the W9 `addJoint` path (anchors on this node + otherNode) | same → Jolt constraint path | **supported** — small; decode-only, machinery done in W9 |
| characterController | `physics_codecs.dart:1244-1364` (up, offset, slide, slope angles, autostep, snapToGround, mass) | component; unhandled | none — kinematic capsule + sweep-and-slide on W8 queries (`convexSweepTest`) | Jolt `CharacterVirtual` + `ExtendedUpdateSettings`/`WalkStairs`/`StickToFloor` (AAR-verified) | **partial** — iOS large, Android medium; needs `move` op + pose writeback |
| Prefabs + streaming | `specs.dart:70-195` `PrefabInstanceSpec`; `compose.dart`; `lazy_subtree.dart` | `instance` field not emitted by dart3d diff; model supports it | `SCNNode` add/remove + `composeScene` Dart-side expansion; lazy → `loadSubtree`/`unloadSubtree` ops | same — entity add/remove | **supported** — medium; `load`/`unload` ops + host asset resolution |
| physicsWorld (remaining) | `physics_codecs.dart:448-516` (`backend`, gravity, fixedTimestep, maxSubsteps) | realized W2/W6 | `backend` logged-ignored (always SceneKit); substep knobs advisory | always Jolt; realized | **supported** — done; residual deltas documented |

### Host-layer families

| Family | Upstream source | Wire today | iOS path | Android path | Verdict / effort |
|---|---|---|---|---|---|
| Widget slots | `ui_codecs.dart:97-219` (`slot` name, size, updatePolicy, input, occlusionHiding) | component; unhandled | engine consumes a texture — host `UIView`/`CALayer`→`MTLTexture` bridge + input routing | `View.draw`→bitmap/`SurfaceTexture`; same host bridge | **out-of-engine** — medium-large; DartNative widget→texture feasibility is a host question |
| Semantics | `ui_codecs.dart:239-335` (`label`, `value`, `hint`, `button`, sortOrder) | component; unhandled | `UIAccessibilityElement` tree on the `SCNView`; engine supplies world→screen projection | `AccessibilityNodeProvider` virtual tree | **out-of-engine** — medium; engine contributes projection + occlusion |
| Audio ×3 | `audio_codecs.dart:91-340` — audioSource (asset, attenuation, doppler, bus), audioListener, audioEngine | components; unhandled | `SCNAudioSource`/`SCNAudioPlayer` + `audioListener`/`audioEnvironmentNode` — attenuation maps; no `dopplerFactor`, `pitch`→`rate` approx | none in Filament — Oboe/AAudio mixer or Media3 backend | **partial iOS / out-of-engine Android** — iOS medium, Android large; asset delivery prerequisite |

## Codec count accounting (perf probe)

Upstream fixed component codec types = **29** (each `String get type`
in `fscene/realize/*.dart`); the dynamic `PlaceholderCodec` is counted
separately as the unknown-type fallback. Every one maps to a row above:

| # | Component type | Audit row |
|---|---|---|
| 1 | `mesh` | realized |
| 2 | `camera` | realized |
| 3 | `directionalLight` | realized |
| 4 | `pointLight` | realized |
| 5 | `spotLight` | realized |
| 6 | `rectAreaLight` | realized iOS / audit row for finish+Android |
| 7 | `rigidBody` | realized |
| 8 | `collider` | realized |
| 9 | `physicsWorld` | realized |
| 10 | `fixedJoint` | joint components row |
| 11 | `sphericalJoint` | joint components row |
| 12 | `revoluteJoint` | joint components row |
| 13 | `prismaticJoint` | joint components row |
| 14 | `genericJoint` | joint components row |
| 15 | `characterController` | physics/gameplay table |
| 16 | `particleEmitter` | particles row |
| 17 | `meshParticleEmitter` | particles row (iOS sprite-only; both need mesh path) |
| 18 | `trail` | rendering table |
| 19 | `lod` | rendering table |
| 20 | `splat` | rendering table |
| 21 | `materialsVariants` | rendering table |
| 22 | `environmentVolume` | environment table |
| 23 | `irradianceVolume` | environment table |
| 24 | `reflectionProbe` | environment table |
| 25 | `widget` | host-layer table |
| 26 | `semantics` | host-layer table |
| 27 | `audioEngine` | audio row |
| 28 | `audioListener` | audio row |
| 29 | `audioSource` | audio row |
| 30 | placeholder (dynamic) | realized contract — log-and-skip |

Resource kinds = **5**: `GeometryResource`, `TextureResource`,
`MaterialResource`, `EnvironmentResource` realized;
`RenderTextureResource` in the audit table.

Document-level items = **7**: the six serializing blocks beyond
resources — `stage` realized (its `renderScale`/`filterQuality` are an
audit row), `nodes` realized, `payloads` realized, `views`/`skins`/
`animations` in the audit table (`scene_document.dart:53-79`) — plus
the node-level `instance` field (`PrefabInstanceSpec`), also in the
audit table.

Spec families without their own wire block = **5**: `MorphTargetsSpec`
(member of `GeometryResource` — audit row), `EnvironmentSpec` variants
(all five realized, W7), `SkySourceSpec` variants (all decode; `fmat`
+`physical` are gradient approximations — physical sky is an audit row
to upgrade), `TransformSpec` variants (both realized), `JointDesc`
runtime ops (realized W9) and physics events/queries (realized W8).

Format-level contract items = **5**: `featuresRequired` gate, `.fsceneb`
container, JSONC/migrations, vertex layouts, `enabled` universal
property — each rowed in the format table above.

**Total upstream accounts: 29 component types + 1 placeholder + 5
resources + 7 document items + 5 spec families + 5 format items = 52.**
No silent gaps.

## Deliberate exclusions (approved, not eternal)

Each exclusion names the reason and carries an operator sign-off box.
The operator approved all six on the W10 review — with the explicit
directive that these are **deferred, not eternal**: they get documented
in the README as exploratory directions and revisited after the
numbered program wraps. Any can be pulled back into a numbered
workstream at any time — the wire never blocks them.

1. **Gaussian splats (`splat`)** — no SceneKit or Filament facility;
   a dedicated decode→pack→sort→rasterize renderer on both platforms
   plus an asset→bytes delivery path. Effort is large and the fidelity
   target (flutter_scene demos) doesn't exercise it. *Excluded — operator-approved, deferred to post-program exploration:* ☒
2. **Audio engine backend on Android** — Filament has no audio;
   upstream's `audioEngine` codec expects a pluggable backend. Building
   an Oboe/AAudio mixer is host-app work, not scene-layer work. iOS
   `SCNAudioSource` support can still land. *Excluded — operator-approved, deferred to post-program exploration:* ☒
3. **Widget slots** — upstream binds registered Flutter widgets to
   world-anchored quads; dart3d has no Flutter widget tree. The engine
   half (texture-on-quad + input routing) only matters once a
   DartNative host bridge exists. *Excluded — operator-approved, deferred to post-program exploration:* ☒
4. **Mesh particles on iOS** — `SCNParticleSystem` is sprite-only;
   `meshParticleEmitter` can't be honored natively. Sprite fallback is
   the documented delta if particles ship. *Excluded — operator-approved, deferred to post-program exploration:* ☒
5. **`renderScale`/`filterQuality` stage+view knobs** — dynamic
   resolution scaling is a perf knob upstream carries but no current
   consumer needs; folded into the views workstream if views land,
   otherwise excluded. *Excluded — operator-approved, deferred to post-program exploration:* ☒
6. **`.fsceneb` binary container** — ~~unreachable on DartNative~~
   **resolved post-program**: `fsceneb_reader.dart` decodes the FSCB
   container + `GZBL` gzip chunks locally (no `package:archive`), then
   hands the manifest to upstream `readFscene`. Live-verified loading
   the real `flutter_scene`-importer dice corpus on both platforms.
   *Pulled back in — no longer excluded.*

## Reconciliation with the W1 feasibility report

The W1 report (Android parity audit, wave-1 read-only agent) was scoped
to the W6 gap list, not the extended surface. Its verdicts that overlap
this audit's territory:

- `showsStatistics` — W1 verdict "no native equivalent; hand-rolled
  TextView with reduced metric set." Landed in W6 as the stats overlay;
  consistent — no conflict.
- `shadowRadius` — W1 "no 1:1 Filament knob; VSM approximation."
  Landed W6 with the documented approximation; no conflict.
- `linearFactor`/`angularFactor` — W1 "no per-body velocity factor;
  binary axis locks only." Landed W6 with the documented restriction;
  no conflict.
- `concaveMesh` — W1 "static-only in Jolt; enforced." Landed W6; no
  conflict.
- `DN_IsolateGen` — W1 "export unverified." The stale-dispatch guard
  landed in W1 itself; orthogonal to this audit.

New verdicts in this audit that extend W1 findings (no W1 verdict is
contradicted — the report scoped to the W6 gap list):

- **Joint components** — W9 shipped runtime `addJoint`/`updateJoint`/
  `removeJoint` ops carrying `JointDesc`, because upstream `JointDesc`
  is runtime-only. The audit finds upstream *also* serializes joints as
  one-sided node components (`physics_codecs.dart:855-1240`,
  `otherNode` reference). Not a conflict — a complementary decode row:
  document-declared joints realize through the same W9 constraint path.
- **`rectAreaLight`** — listed as realized (iOS dispatches `.area`),
  but the audit found `decodeLight` never applies `width`/`height`/
  `areaExtents` (`FsceneRealizer.swift:1758-1786`). Downgraded to
  partial; finishing is ~4 lines, Android gets the emissive-quad
  approximation.
- **W1's deferred `contactMask` note** — resolved by W8: upstream has
  no contact mask, so the wire has none. Recorded, no action.
- **`skin`/`anim`/`rt` id prefixes** — reserved in the wire since W5
  (`diff_apply.dart:160`); the audit confirms all three blocks already
  serialize in the canonical manifest.

## W21 landed — Dart-side semantics

Recorded where the Dart half of the materials/textures conformance
workstream settled; platform-row edits belong to the integrator.

- **Light field `n` → `intensity`** — upstream importer manifests carry
  `n = photometric / (683 · luminance)` on punctual lights;
  `fsceneb_reader.dart`'s `normalizeLightIntensity` inverts it at
  decode (`n · 683 · luminance · kGltfToSceneKitLightScale`, constant
  `1000.0`) for `.fsceneb`, and `showcase_loader.dart` applies the same
  pass to `.fscene` documents + prefab grafts. Authored `intensity`
  wins; `n` is preserved (idempotent). Full contract:
  `android-parity-spec.md` §Light units.
- **uv1 vertex channel** — `VertexPack.unskinned`/`skinned` accept
  `uv1s`; the `unskinned_uv1_tangent` interleave now carries a real
  second UV set for `texCoord: 1` materials (was always zero-filled).
- **`materials` showcase lane** — builtin procedural scene
  (`kBuiltinMaterialsKey` in `showcase_loader.dart`): blend sphere over
  a checker backdrop, mask quad on a generated alpha-lattice rgba8
  payload (`alphaCutoff 0.5`), and a two-UV-set quad pair differing only
  in `baseColorTextureTransform.texCoord`. No KTX2 sample asset exists —
  that lane stays a manifest-level gap pending a bundled `.ktx2`.

## W24 landed — views breadth and shadow breadth

Where the views/shadow workstream settled. Verification: `dn test`
(207 pass incl. 10 new `views_viewport_test.dart` cases), `dn analyze`
(13 pre-existing `example/tool` findings only), iOS
`swiftc -typecheck -target arm64-apple-ios16.0-simulator` clean,
Android `:dart3d:compileReleaseKotlin` green. No device run — the
harness phase is the driveable lane.

- **`viewport` wire extension** — upstream `RenderViewSpec` is
  final-shaped with no rect field; `Dart3dRenderViewSpec`
  (`diff_apply.dart:358`) subclasses it and adds
  `viewport:[left,bottom,width,height]` in target-pixel units,
  bottom-left origin. `encodeViewSpec`/`decodeViewSpec` preserve the
  upstream field set; `readFsceneWithExtensions` +
  `applyViewExtensions` re-decode `doc.views` so `.fscene`,
  `.fsceneb`, showcase, and `loadSceneBytes` all keep the member, and
  `updateViews` re-encodes it.
- **iOS split-screen** — ≥2 screen views, or any screen view with a
  `viewport`, swaps the host into a blank-camera pass (category mask 0)
  and layers one sibling `SCNView` per entry in `order`. Siblings share
  the scene, stay `isPlaying = false`, get their cameras synchronized
  in `willRenderScene`, and are poked (`setNeedsDisplay`) in
  `didRenderScene`. A single full-frame screen view keeps the original
  host `SCNView` path. The lowest-order view drives the real camera
  node; later views get detached proxy cameras.
- **Android screen views** — each screen entry is a pass on the shared
  Filament `View`: camera, `Viewport` (Filament's origin is
  bottom-left, same as the wire), `setVisibleLayers`, AA, and
  renderScale pushed per render, in `order`. Composited-pass
  equivalent of iOS's siblings.
- **Android `layerMask` is 8-bit** — the wire mask is 32-bit; Filament
  `setVisibleLayers`/`layerMask` take uint8. Both the view entries and
  node `layers` truncate `and 0xFF` at build and `warnOnce` when high
  bits are set (`RenderTargets.kt:274-281`,
  `FsceneRealizer.kt:1110-1117`). Layer bit ≥8 is iOS-visible only.
- **Directional shadow vocabulary** — the harness re-decodes `key`
  with the upstream `DirectionalLightCodec` field set plus three
  dart3d wire extensions upstream keeps on
  `stage.skyEnvironment.sunLight` (`SunLightSpec`:
  `contactShadows`/`contactShadowDistance`/`angularRadius`). The sun
  block stays deferred on both platforms (the `skyEnvironment`
  relighting row above), so dart3d accepts the fields on the light
  component instead — decode sites mark them extensions. Upstream's
  `priority`/`localDirection` members stay unmapped and warn once on
  receipt both platforms. iOS maps `shadowMapResolution`→
  `shadowMapSize`, `shadowSoftness`→`shadowRadius`,
  `shadowMaxDistance`→`orthographicScale` (auto-fit off),
  `shadowCasterFaces 'back'`→`forcesBackFaceCasters`; cascades, split
  lambda, fade range, ambient strength, normal bias, cacheStatic,
  the three sun extensions, and non-rotatedPoisson filters `logOnce`
  per field — SceneKit renders one shadow map per directional
  (`FsceneRealizer.swift:3342-3433`). Android maps
  `shadowCascadeCount`/`shadowCascadeSplitLambda` (computed split
  positions), `shadowMaxDistance`, `shadowNormalBias`,
  `contactShadows`→`screenSpaceContactShadows`, `shadowSoftness`→
  `shadowBulbRadius` (DPCF approximation), `angularRadius`→
  `sunAngularRadius`; fade/ambient/caster-faces/cacheStatic/
  `contactShadowDistance`/`shadowFilter` warn once
  (`FsceneRealizer.kt:1618-1708`).
- **`shadowRadius` vs `shadowSoftness` precedence** — both write the
  same native knob (`light.shadowRadius` iOS, `shadowBulbRadius`
  Android). The W24 field decodes second in `decodeDirectionalShadow`
  and wins when a document authors both; the `key` re-decode
  exercises it on purpose (3.0 then 0.08).
- **`shadowCatcher` material** — dart3d extension `type` on
  `MaterialResource`, upstream `ShadowCatcherMaterial`'s live mode:
  the surface draws only its received shadow. iOS realizes
  `SCNLightingModel.shadowOnly` (the light's `shadowColor` drives the
  catch — material-level `shadowColor`/`shadowIntensity`/`aoStrength`/
  `softness`/`fade*`/`mode` log once). Android compiles an unlit
  `shadowMultiplier` filamat at runtime — fragment emits
  `(shadowColor·a, a)`, `a = intensity·(1−visibility)` — with the same
  unsupported-field warnings (`Dart3dView.kt:643-675`,
  `FsceneRealizer.kt:3260-3285`).
- **Harness** — `w24Phase` fires at +126 s: arms the shadow vocabulary
  on `key`, drops a catcher plane and a layer-bit-8 marker, then walks
  `updateViews` through a two-view split, a single inset-rect view,
  and a high-bit layerMask pair before restoring the pre-phase list
  for the dice-regression tail.
