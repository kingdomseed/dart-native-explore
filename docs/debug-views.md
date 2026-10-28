# Screen debug views

`SceneView.debugView` owns the screen's inspection choice. The controller and
serialized document contain no debug state. The iOS presentation covers PBR
meshes, ordinary unlit meshes, `d3:sprite` materials, and baked and live shadow
catchers. The [live-catcher simulator replay](artifacts/e9-w34-dev-reload/live-catcher-ios/README.md)
covers a transformed receiver with one spot light, current light updates,
component removal, material replacement, reload and Off restoration.
The [baked-catcher simulator replay](artifacts/e9-w34-dev-reload/baked-catcher-ios/README.md)
covers the five channels, frozen-cache movement, explicit refresh, wire and Off.
Android and other material families are outside this unit. The retained PBR simulator evidence covers the five channels, authored-target
isolation, filled wireframe, and restoration to current authored state.

```dart
SceneView(
  controller: controller,
  debugView: const SceneDebugView(
    channel: SceneDebugChannel.normals,
    wireframe: true,
  ),
)
```

`SceneDebugView` is an immutable value with equality and a hash. Its default is
`channel: SceneDebugChannel.none, wireframe: false`. Wireframe is independent of
the channel. Selecting `none` with wireframe enabled keeps current authored fill
and display settings beneath triangle edges. The complete default returns to
current authored rendering, including edits made while a channel was selected.

| Channel | PBR input | Linear display RGB |
| --- | --- | --- |
| `normals` | Normalized view-space base-lobe normal after the normal map, slot transform, scale, and native deformation | `0.5 * N + 0.5` |
| `metallic` | Sampled effective metallic input, including the packed map's B channel and native factor | Clamped scalar replicated to RGB |
| `roughness` | Sampled perceptual material-input roughness, including the packed map's G channel and native factor | Clamped scalar replicated to RGB |
| `baseColor` | Factored, sampled pre-lighting linear base color | Clamped RGB |
| `depth` | Positive axial eye distance `d = -position_view.z` in scene units | `d / (1 + d)` replicated to RGB |

Depth is not radial distance or hardware depth. One scene unit maps to linear
0.5, three units to 0.75. Channel output uses identity linear composition and one
sRGB transfer. A linear 0.5 is approximately display code 188. The existing
artistic `linear` tone mapper does not define this numeric output policy.

The diagnostic camera retains pose, clipping, projection, and layers. It uses
exposure 1 with no adaptation, bloom, fog, depth of field, fringe, grain, motion
blur, grading, LUT, vignette, or TAA. The presentation background is black.
Selected MSAA remains active. Existing PBR mask discard and blend coverage stay
in the copied material path. Blend RGB is premultiplied once. Overlapping blend
surfaces composite channels; their final pixel need not identify one surface.

Wireframe uses SceneKit's `showWireframe` overlay. It draws actual triangle edges
over fill, including an indexed quad's diagonal. Each screen renderer retains
only its prior value of that bit and restores it when this feature relinquishes
ownership. Other debug bits remain untouched. Target and bake renderers never
receive this bit.

The operator approved native particles as unsupported on 2026-10-27. While a
channel is selected, native particles are outside its isolated presentation.
The authored scene remains their sole simulation owner. There is no particle
recreation, second simulation, or substitute renderer. Wireframe makes no
particle-topology promise.

Ordinary unlit meshes use sampled diffuse RGB after the current factor and
native vertex or instance color. Sprites use sampled texture RGB times the
current tint and native `d3SpriteColor`, before RGB premultiplication. The
existing texture owner identifies premultiplied render textures. Only source
texture alpha is divided out, never tint alpha or vertex alpha. Zero source
coverage stays zero. Alpha sprites keep source-over blending; additive sprites
keep their RGB-only write mask and destination coverage. Both retain native
depth behavior. Sprite diagnostics multiply their RGB by source coverage once.

Unlit and sprite normals use SceneKit's view-space `normal` with normal mapping
disabled on the diagnostic copy by a solid normal property. The authored normal
texture remains unchanged. The simulator's constant-material path did not yield
usable values from `geometryNormal`. Depth uses the same axial formula as PBR.
Metallic and roughness have no input in these families and display linear
magenta `(1,0,1)`.
Magenta does not stand for an inaccessible input or a shader compiler failure.
The [material-family simulator sequence](artifacts/e9-w34-dev-reload/material-families-ios/README.md)
exercises straight image textures, current edits, coverage modes and authored
captures. Premultiplied render-texture sprites and calibrated coverage accuracy
remain unverified. Host tests and builds alone establish neither.

Baked catchers use the actual bound constant material named `d3.shadowCatcher:<key>`.
The derived copy retains its cache texture, sampling, blend, depth, culling,
geometry modifier, and current `d3CatcherRegion` argument. That modifier maps the
receiver's model XZ positions into the cached footprint. Texture or region
replacement invalidates the existing diagnostic material signature. No resource
JSON is reparsed and no second footprint is generated.

Baked normals use the receiver's native view-space `normal` with the same solid
normal property as unlit diagnostics. Depth uses the existing axial formula.
Base color, metallic, and roughness are absent inputs and display linear magenta
`(1,0,1)`. Cached shadow RGB is coverage tint, not a PBR base-color input. Every
channel retains the existing output alpha and premultiplies diagnostic RGB once
under SceneKit's transparent modifier rule. Pending caches remain transparent.
Only the derived material replaces diagnostic RGB.

Channel and wire changes do not dirty or bake the cache. Caster or light edits
leave its footprint frozen. An explicit unchanged same-ID material upsert asks
the existing cache owner to refresh. Turning Off shows current authored state.
Live catchers use the bound `d3.shadowCatcher:<key>` material with the native
`shadowOnly` lighting model. The diagnostic copy keeps that model, source
modifiers, sampling, depth, culling, blend, and coverage ownership. Its existing
transparent/body declaration remains once. The fragment appends selected RGB
multiplied by native `_output.color.a` once, without writing alpha. Normals use
the receiver's native normal and the existing solid diagnostic normal property.
Depth uses the axial formula. Base color, metallic, and roughness are absent
inputs and use magenta under actual shadow coverage. No mask is inferred from
shadow RGB, and no opaque receiver or second footprint substitutes for coverage.
The private scene retains the host's existing depth-only stand-ins for blended
casters. Their copied materials keep the empty color-write mask and depth
writes; channel materials apply only to visible surfaces. Moving the caster
moves the same source-owned stand-in through the existing frame capture.
Other material families remain unsupported and retain copied authored materials. A shader or required-input failure is a blocker, not an
absent-input result. An opaque receiver cannot substitute for coverage proof.

The existing tag-6 view configuration always includes both fields, including
complete explicit off:

```json
{"debugView":{"channel":"none","wireframe":false}}
```

A missing `debugView` decodes as off for older senders. A present malformed
object logs a protocol warning and rejects that configuration. Native parsing
accepts only the closed channel names and a JSON boolean. No debug fields enter
`.fscene`, resources, controller state, or command operations.

The iOS host keeps the authored scene as the sole update, animation, physics,
and capture owner. Selected-channel screen siblings use detached material and
geometry attachments with current native streams. The existing sibling-pose
mailbox hands current transforms, camera copies, skinner inputs, morph
weights, node `castsShadow`, and current native light state to a main-thread-owned presentation. Unchanged attachment identities
are reused. Capture owns a weak-source identity cache of detached model-light templates.
It checks the source by reference, clears animations before publishing a template,
and never mutates a published template. Main owns a separate displayed light per
private node, copied only when the template reference changes. Current values
apply each accepted frame under the existing disabled-actions transaction.

The named native light state contains `color`, `intensity`, `castsShadow`,
`shadowMapSize`, `shadowBias`, `shadowRadius`,
`automaticallyAdjustsShadowProjection`, `orthographicScale`,
`maximumShadowDistance`, `forcesBackFaceCasters`, and `shadowSampleCount`.
`color` retains the native platform value and assigns it directly, including
immutable platform colors and CGColor. There is no component conversion or
fallback color. Node `castsShadow` is independent of light `castsShadow`.
Supplemental skin-only poses carry no light. Source-light removal clears the
private node's light and display slot; reconciliation prunes removed slots.
Existing capture clear, pruning, Off, and scene teardown release templates.

U4 intensity and restoration, quality shadow suppression, and the reused stage
sun's eleven in-place fields travel through this state. Component replacement
preserves other configuration through a new template identity. Future in-place
light writers must extend the named state. Arbitrary native light-property Core
Animation and mutable custom color objects are outside this contract. Capture
never copies a presentation light or accesses the main-owned displayed light.
The projection has no actions, constraints, physics bodies, or particle systems. Captures never borrow its materials or cameras.

Full load and native resource replacement discard scene-local derivatives while
retaining the view choice. Off reconnects current authored attachments and
current display settings. There is no saved-on-entry material restore store.

The retained entry point is `dart3d/example/lib/w34_debug_main.dart`.
`DART3D_W34_LIVE_CATCHER=true` selects the live receiver;
`DART3D_W34_LIVE_BLEND_CASTER=true` additionally makes its caster translucent.
Its default fixture
has a mapped indexed quad, an occluder, nonwhite vertex color, scalar swatches,
material-factor and coverage controls, and a shared-camera authored target. The
lower monitor samples that target and is excluded from its capture layers. In
`baseColor`, the monitor exposes the target's ordinary authored RGB instead of a
second diagnostic rendering of the captured scene. **Capture** refreshes the
manual target through the existing `SceneController.renderTexture` operation.
Capture while any channel is selected, then select `baseColor` to inspect that
retained authored image. The mode switch does not refresh the target. This is
a verification setup, not pixel proof.

Host Dart tests cover fixture topology, sampled payloads, target-camera/layer
relationships, emitted material updates, and serialized current edits. Swift
typecheck and a generic arm64 simulator build check native source integration.
The [PBR simulator evidence](artifacts/e9-w34-dev-reload/screen-debug-ios/README.md)
records native shader execution, screenshots, unchanged authored-target monitor
crops, wire occlusion, factor edits, reload, and off restoration. Literal controls
0.125, 0.5, and 0.875 produce encoded grayscale values 100, 187, and 237, compared
with ideal rounded sRGB values 99, 188, and 240. This is approximate screenshot
output after SceneKit packing, not calibrated raw channel readback. Transparency
captures do not establish numeric alpha or premultiplication accuracy.

The optional `DART3D_W34_CONSUMERS=true` fixture uses a two-bone skin and public
rig removal, restoration, pose and viewport controls. Focused simulator replay
covers channel selection with retained detached bones, restored deformation,
and inset viewport isolation in both selection orders. It does not establish
arbitrary skinning or morph output. Diagnostic siblings cover the host with a
black backing outside their viewport rectangles; turning channels off removes it.

The optional `DART3D_W34_MATERIALS=true` fixture uses the same entry point and
fixed camera. It places a tilted unlit indexed quad on the left, alpha and
additive billboards on the right, and the authored-target monitor below them.
The image has asymmetric RGB marks and zero, half, and full alpha bands. The
quad has nonwhite native vertex color. Both sprites have nonwhite native RGBA
color, a transformed texture rectangle, and a nonwhite tint with fractional
alpha. **Factors A/B** edits current unlit factors and sprite tint. **Colors A/B**
rebuilds current billboard components through `updateNode`. **Texture on/off**
rebinds the existing image through material upserts. **opaque/mask/blend** changes
only the unlit coverage policy. **Capture**, **Reload**, channel, wire, and **Off**
use their existing operations. The default PBR and consumer fixtures retain
their previous controls and document semantics.

The material fixture samples straight image textures. Its authored target is an
isolation monitor, not a premultiplied sprite source. The linked native replay
covers these image-backed channels, current edits, coverage modes, wireframe,
authored captures and reload. Render-texture sprite coverage and calibrated
channel or blend accuracy remain `NOT_RUN`.

The optional `DART3D_W34_BAKED_CATCHER=true` fixture takes precedence over the
material and consumer fixture flags in the same entry point. It reuses the direct U2 spot-light
baked catcher, including its translated, yawed, nonuniformly scaled receiver.
It keeps one caster, adds a fixed orthographic camera, and places a real opaque
PBR backdrop behind the receiver. The backdrop has a different normal and depth
so covered diagnostic fragments can be distinguished from transparent regions.
There is no manual target or **Capture** button in this mode. Material-factor,
texture, coverage-mode, and rig controls are omitted.

Load at **Off** and **Wire off** and retain the initial cached footprint.
Select **normals**, **depth**, then **baseColor**, **metallic**, and **roughness**.
The last three must show magenta only under actual cached coverage. Toggle wire
with a channel selected, select **Off**, and disable wire. Select **normals**
again and tap **Caster A** to move the caster to B. Its geometry moves but the
cached footprint must stay at A. Tap **Refresh** to emit an unchanged same-ID
material upsert. Only then must the footprint change to B. Select **Off** to
inspect current authored shading, then **Reload**. Reload keeps the authored B
position and recreates the cache through normal document loading. Channel
selection stays view-owned. Repeat with **depth** if needed to inspect coverage
independently of the normal display.

Host tests cover the real receiver document, public transform bytes, explicit
identical material upserts, current controller mirror, reload, and previous
fixture regressions. Native replay shows all five channels on the transformed
receiver, transparent surroundings, frozen footprint after caster movement,
refresh in both directions, current-state Off, and reload with selection retained.
The retained scene crops match exactly after Off and reload. Initial capture
logs contain the same cross-scene mutation and missing `d3CatcherRegion` warnings
in both baseline and corrected runs; neither is resolved by this material slice.
Numeric alpha/channel calibration, pending-cache first-frame behavior, and
baked-specific authored-target isolation remain `NOT_RUN`.

The retained `DART3D_W34_LIVE_CATCHER=true` mode takes precedence over all other
W34 fixture flags. It uses the same transformed U2 spot receiver, opaque caster,
backdrop, and fixed camera as the baked fixture. Only this mode changes that
receiver to live and adds a typed `Dart3dAnimationSpec` with a
`D3LightIntensityChannel`. Default, baked, material, and consumer documents keep
their existing behavior when the live flag is absent.

Use the existing entry point with `--dart-define=DART3D_W34_LIVE_CATCHER=true`.
The fixture checks are:

1. Retain Off with Wire off. Select normals and depth, move Caster A to B, and
   verify current coverage follows without Replace. Check baseColor, metallic,
   and roughness show magenta only under actual coverage. Compare uncovered and
   partially covered alpha as well as RGB. Toggle Wire, Off, and Wire off.
2. Toggle Light A/B. The public transform operation moves and re-aims the existing
   spot node. Toggle High/Low/High through `SceneView.quality`; observe native
   source and displayed `castsShadow` independently of node `castsShadow`.
3. Tap Dim and Bright for paused deterministic U4 seeks at 0 and 2 seconds.
   Their authored spot intensities are 20 and 160. Play loops the two-second
   linear cue; Pause freezes its current sample. Rest seeks to zero at weight 0
   and pauses, releasing the intensity owner to the current component's rest
   value. Stop alone would retain the first key at its previous weight.
4. Observe source and displayed native intensities and object identities directly
   during the cue and Rest. The original component rests at 100. New A/B toggles
   component replacement between original white/100 and blue-white/80 through
   `updateNode`, returning the cue to Rest first. Template and displayed copies
   occur for initial or changed source identities, with a distinct displayed
   light per private node. Continuous U4 samples must keep those identities.
   Shadow alpha alone cannot prove intensity transport.
5. Light on/off removes and restores the component on the surviving node through
   public component updates, returning to Rest. Confirm nil clears its display
   slot. New A/B also restores a missing light. Replace performs an unchanged
   same-ID live material upsert only. Reload performs a full document load;
   it keeps authored caster/light poses and component state, resets playback to
   Rest, and preserves the view's channel, wire, and quality choices. The footer
   reports this reset rather than retaining a stale cue label.
6. Repeat selected channels, Off, reentry, Replace, and Reload with current edits.
   Inspect copy safety, source isolation, queued-generation rejection, release
   after frame drain, and allocation/retained-light and frame costs. The reused
   stage sun's color/shadow settings require separate scene observations.
   This spot fixture does not exercise that owner.

The recorded simulator sequence shows all five channels, moving live coverage,
quality shadow suppression, current U4 values, component replacement and removal,
wire, material Replace, Reload and current-state Off. Traces show stable template
and displayed identities during changing intensity, matching current native
values, and empty template/display maps after component removal. This is finite
map-lifecycle evidence, not a native heap measurement. A separate native adapter
probe preserves an immutable extended-linear-sRGB CGColor with a component of
1.6 and verifies the eleven state assignments without changing its frozen
template. This does not calibrate rendered color, fragment alpha or coverage.
The clean replay removes all probes and tracing. Numeric alpha/color parity,
general consumers, actual stage-sun scene updates, shared-light attachments,
whole-node removal, queued-generation stress, heap retention and performance
remain `NOT_RUN`. Entry boundary flashes and broader W34 gates remain open.
Native particles retain their operator-approved unsupported status.

With no attached lights, the current authored live catcher draws its entire
receiver. The debug channels preserve that native coverage too. The separate
Off/normals control records the same full receiver before and after material
Replace and Reload, then restores the footprint when the light returns. This
existing zero-light material behavior is not corrected by the diagnostic view.

Morph output, additional material families and consumers, Android,
performance, and final T2/T4 remain `NOT_RUN` for this unit. It does not establish
whole W34 or Track E readiness.
