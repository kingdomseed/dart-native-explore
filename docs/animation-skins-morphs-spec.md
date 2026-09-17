# W11 — Skins, skeletal animation, morph targets (spec)

The fidelity-path workstream: upstream's `skins`/`animations` document
blocks plus `GeometryResource.morphTargets`, realized on both engines
with upstream's playback semantics. Sources:

- `scene-0.3.0`: `specs.dart:1068-1160` (SkinSpec/AnimationSpec/
  AnimationChannelSpec/AnimationProperty), `specs.dart:434-473`
  (MorphTargetsSpec), `json/fscene_json.dart:217-228,766,836-905`
  (wire shapes).
- `flutter_scene-0.23.0`: `fscene/realize/skin_animation.dart`
  (realization order, name fallback), `animation/animation_clip.dart`
  + `animation_player.dart` + `property_resolver.dart` (playback
  semantics).

## Wire surface

Everything below is already inside the canonical manifest
(`loadDocument` emits it today); the gaps are native decode plus three
new command ops. Id-key prefixes `skin:`/`anim:`/`chunk:` resolve
through the existing token rules (strip to last colon).

### Manifest blocks (decode at install + diff)

```jsonc
"skins": { "<id>": {
  "joints": ["n:<id>", …],            // joint node ids, joint order
  "inverseBindMatrices": "chunk:<id>",// f32×16 per joint
  "skeleton": "n:<id>"?               // optional root joint
}}
"animations": { "<id>": {
  "name": "…"?,
  "channels": [{
    "target": "n:<id>",
    "targetName": "…"?,               // fallback binding for clones
    "property": "translation"|"rotation"|"scale"|"weights",
    "timeline": "chunk:<id>",         // f32 seconds, keyframe times
    "keyframes": "chunk:<id>"         // vec3 / quat / flattened weights
  }]
}}
```

Node binding: `NodeSpec.skin` — the `"skin": "skin:<id>"` key already
serializes on node specs (`fscene_json.dart:766`); natives decode it on
install, `addNode`, and `updateNode` (`flags` re-decode). Weights
channels carry the flattened glTF shape — `values.length ==
times.length × targetCount`, trailing floats dropped
(`skin_animation.dart:102-112`).

### Payload encodings consumed

`matrices` (IBM: 16×f32 per joint, column-major as upstream's
`Matrix4.fromFloat32List`), `floats` (times/values). Both decoders
exist on both platforms (geometry payloads already use them).

### New command ops (all additive, `protocol.dart` command vocabulary)

```jsonc
{"op":"anim","anim":"<id>","play":true,         // or "pause"/"stop"
 "time":<s>?, "timeScale":<f>?, "weight":<f>?, "loop":<bool>?}
{"op":"upsertSkin","id":"<id>","skin":{…}}       // diff path
{"op":"upsertAnimation","id":"<id>","animation":{…}}
{"op":"removeSkin"|"removeAnimation","id":"<id>"}
{"op":"setMorphWeights","node":"<id>","weights":[f,…]} // direct write
```

`anim` is the runtime player control — play/pause/stop + seek +
timeScale + blend weight + loop, matching upstream's `AnimationClip`
knobs (`animation_clip.dart:13-59`). Default on document load:
animations exist but **do not autoplay** (upstream creates clips
paused — `animation_player.dart:22`).

## Playback semantics (one sampler, two engines)

Reproduce upstream's `AnimationPlayer`/`AnimationClip` contract
exactly — this is why we do **not** use `CAKeyframeAnimation` or any
engine-level clip player: upstream mixes concurrent clips by
normalized `weight`, seeks, time-scales, and clamps-or-loops at
endTime — CA's timing model can't express the blend.

- Each playing animation = one clip: `playing`, `playbackTime`,
  `timeScale` (default 1), `weight` clamped [0,1], `loop` (default
  false).
- `endTime` = max channel timeline last-key.
- Advance per rendered frame: `playbackTime += dt × timeScale`;
  non-looping clamps to [0, endTime] and auto-pauses at the boundary;
  looping wraps (`animation_clip.dart:115-140`).
- Weight normalization: when playing clips' weights sum > 1, each
  channel contributes `weight × (1/Σweights)`; ≤ 1 each contributes
  `weight` and the rest is the node's rest/bind pose
  (`animation_clip.dart:204-219`, `animation_player.dart`).
- Interpolation (`property_resolver.dart`): translation/scale/weights
  → linear between bracketing keys; rotation → slerp. No other modes
  exist upstream — do not add cubic/step.
- Channel binding: `target` id first, `targetName` fallback (upstream
  order, `skin_animation.dart:75-82`).
- Rest pose: a node's authored transform; a weights channel's rest is
  the mesh's `defaultWeights` (or zeros). Bind pose capture rule:
  capture once at bind, never re-capture while playing (upstream's
  corruption rule, `animation_player.dart:44-46`).

Per frame, after advancing clocks: resolve each channel → target value,
blend across clips, then write node TRS (transform path natives
already own) and morph weights (`SCNMorpher.weights` /
`RenderableManager.setMorphWeights`).

## iOS realization (SceneKit)

- **Skin**: `SCNSkinner(baseGeometry:bones:boneInverseBindTransforms:
  boneWeights:boneIndices:skeleton:)` — bones = joint `SCNNode`s,
  bone attr `SCNGeometrySource`s (`.boneWeights`/`.boneIndices`, 4
  components). Attach on the skinned node's geometry when its `skin`
  member resolves.
- **Vertex attrs**: `skinned`/`skinned_uv1_tangent` layouts already
  decode; W11 wires the JOINTS/WEIGHTS streams into the two skinner
  sources instead of dropping them (`FsceneRealizer.swift:1496-1502`).
- **Morphs**: `SCNMorpher` — targets are absolute `SCNGeometry`s
  (positions [+ normals/tangents when `hasNormalDeltas`/
  `hasTangentDeltas`]); decode converts `base + delta` per target.
  `calculationMode`: `.additive` when targets are authored as deltas
  post-conversion — match upstream's blend semantics (weights sum,
  normalized) — set `.normalized` to mirror upstream's weight
  normalization. `defaultWeights` applied at attach; `unifiesNormals`
  default.
- **Sampler**: per-frame in `SCNSceneRendererDelegate
  .renderer(_:updateAtTime:)` — the host is already the delegate
  (physics/joint ticks live there). Write sampled TRS onto joint/
  target nodes' `transform` (not `presentation`) and weights onto
  `morpher.weights`.

## Android realization (Filament)

- **Skin**: `RenderableManager.Builder.enableSkinningBuffers(true)`
  `.skinning(SkinningBuffer, boneCount, offset)`; vertex attrs
  `BONE_INDICES` (uvec4) + `BONE_WEIGHTS` (float4) into the existing
  `VertexBuffer` build (`MeshFactory.kt` already recognizes the
  layouts). Per frame after the sampler: `skinningBuffer.
  setBonesAsMatrices(engine, mats, boneCount, offset)` where
  `mats[i] = inverse(skinnedNodeGlobal) × jointGlobal[i] × IBM[i]`
  (column-major f32). Coordinate convention: same LH-wire → RH-engine
  mirror the transform path already applies.
- **Morphs**: `MorphTargetBuffer.Builder.vertexCount().count()` +
  `setPositionsAt` (+`setTangentsAt` when tangent deltas exist);
  Filament wants **absolute** positions — decode adds base+delta.
  `RenderableManager.Builder.morphing(buffer)` +
  `setMorphWeights(instance, weights)`.
- **Sampler**: Kotlin port of the same state machine, ticked inside
  the existing Choreographer loop before `renderer.render` (where the
  physics step already runs).

## Dart surface

- `SceneController.playAnimation(id, {loop, weight, timeScale,
  time})`, `pauseAnimation`, `stopAnimation`, `seekAnimation(id,
  time)` — thin wrappers over the `anim` op.
- `SceneController.setMorphWeights(node, weights)` over the
  `setMorphWeights` op.
- `SceneAnimation` info handle (id, name, channelCount, duration) —
  built from the document, no new transport.
- `diff_apply.dart`: emit `upsertSkin`/`upsertAnimation`/
  `removeSkin`/`removeAnimation` when `diff.skins`/`animations`
  change; `animationsChanged` stops being a logged no-op.
- `encodeNodeCommandSpec` emits `skin` when the node has one (W5
  already drops it — remove the drop).

## Boundaries (documented, not implemented)

- Animation drives node transforms only — a skinned/animated node is
  not a physics body; kinematic interaction is out of scope.
- No glTF importer: the harness authors the document
  programmatically. Upstream's importer is Flutter-coupled; importing
  real assets is a host-side tool concern (audit §15).
- `skeleton` root is informational; binding is by joints list + IBM.

## Harness

`feature_scene.dart` gains a scripted W11 probe (after the W9 rig):
a programmatic two-bone "flag" skinned mesh (bone chain + weights),
one morph-target mesh with two deltas, two authored animations
(wave — rotation channels on the joints; pulse — weights channel),
played via the new ops at +14s with a visible result, a seek to a
known pose, and a `setMorphWeights` write. Status line gains
`anims: n playing` and the probe logs sampled joint transforms.

## Verification shape (same rule as W8/W9)

- Unit: Dart — skin/anim upsert op emission, weights-channel
  flattening bounds, anim op encoding, diff emits skin/anim ops.
- Live lanes (both surfaces): skinned mesh deforms under joint
  animation; morph weights channel animates; play/pause/seek/loop
  verified; `setMorphWeights` direct write visible; physics +
  contacts + joints + env all still live; perf frame cost recorded.
- Docs: this spec + matrix + program checkboxes.
