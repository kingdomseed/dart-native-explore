# W29 — document layer completion

Closes the `.fscene` round trip: a live scene serializes back to a
document, older schema versions upgrade on load, capability
negotiation follows upstream semantics, and a `.glb`/`.gltf` imports
at runtime without an offline cook.

## The document is the live graph

dart3d has no Dart-side `Node` tree — the live scene is the tracked
`SceneDocument` the controller holds plus every structural op sent
since it loaded. `serializeScene` therefore serializes that mirror
rather than reading state back from natives (there is no readback
API, same as upstream, whose `serializeScene(Node root)` walks the
Dart-side graph it already has).

The mirror stays truthful because `SceneController` folds each
outgoing mutation into it (`lib/src/doc_layer.dart`):

- `applyCommands` ops in `commandAffectsDocument`'s set — `addNode`,
  `removeNode`, `updateNode`, `upsertResource`, `upsertPayload`,
  `updateStage`, `upsertSkin`/`removeSkin`,
  `upsertAnimation`/`removeAnimation`, `updateViews` — apply to the
  document before they send. Fold semantics track the wire contract:
  `addNode` on a live id is a full update, `updateNode` applies only
  its `flags` fields, a node's children are whoever named it as
  `parent` (`spec.children` is inert), and ops on missing ids no-op.
  A fold that can't decode an op logs and drops just the mirror
  update — the send always goes out.
- `setNodeTransforms` writes fold absent-fields-keep-previous, with a
  `MatrixTransform` base decomposed first.
- `sendPayload` deliveries replace the payload spec under their id.
- `applyDiff` skips the fold entirely — `newDoc` is already the
  post-op state.
- Ops the format doesn't model (`anim`, `setMorphWeights`, physics,
  `query`, …) pass through untouched. Animation playheads, physics
  poses and morph weights are runtime state upstream doesn't
  serialize either.

Entry decoders stay private upstream, so the fold decodes each op's
spec by wrapping it as a one-entry document skeleton through the
public `decodeDocument` — a spec folded by the mirror decodes
exactly as it does in a manifest.

`SceneController.serializeScene()` returns a *detached* snapshot:
the document re-encoded and re-decoded through the canonical codec,
with payload bytes copied back (bytes ride the binary channel and so
never appear in the JSON tree). Later live edits can't reach into a
snapshot; serializing then re-realizing reproduces the scene.

## Load paths and migration

- `loadDocument(SceneDocument)` — unchanged entry; the document
  becomes the mirror.
- `loadFscene(String)` — `readFscene` then `loadDocument`. Upstream's
  `readFscene` runs the `migrateFscene` chain, so v1–v4 documents
  upgrade to `currentFsceneVersion` (5) on load: v1's left-handed
  stage fields drop, v4 indexed geometry gains `legacyWinding`, and
  right-handed v1 or newer-than-supported versions refuse with
  `FsceneVersionException`. JSONC comments and trailing commas parse.
  dart3d reuses upstream's migration untouched — no reimplementation.
- `loadGlb(Uint8List)` — the `Node.fromGlbBytes` equivalent; imports
  then loads.
- `loadGltf(Uint8List, resolveUri: …)` — multi-file JSON plus a URI
  resolver for external `.bin`/image resources; the result is
  self-contained.

## Feature negotiation

Three gates, matching upstream's semantics plus the engine's
realized set:

1. Upstream `decodeDocument` rejects a `featuresRequired` name
   outside `supportedFeatures` with
   `FsceneUnsupportedFeatureException` — required means refuse, at
   parse time.
2. `missingRequiredFeatures(doc)` = `featuresRequired` ∖
   `kRealizedFeatures` — features the *format* supports but this
   engine doesn't (`streaming`, `prefabInstances` today; see
   `kPlannedFeatures` for the workstream each lands in). The default
   is warn-only: every unrealized required name logs, used-only
   names log as advisories.
3. `loadDocument`/`loadFscene`/`loadGlb`/`loadGltf` take
   `strictFeatures: true` to promote gate 2 to refuse — the same
   `FsceneUnsupportedFeatureException` type, now thrown for
   unrealized-but-known capabilities.

## Runtime glTF/GLB import

`lib/src/glb_import.dart` + `lib/src/gltf/` port flutter_scene
0.23.0's in-memory importer (MIT, Brandon DeRosier — attribution in
the file headers). Everything runs in memory: no `dart:io`, no GPU,
no added dependencies.

Pipeline: GLB container parse (`glb.dart`) or `.gltf` JSON +
external-resource normalization → `parser.dart` →
`EXT_meshopt_compression` decode (`meshopt_decoder.dart`) →
primitive packing + bounds baking + coordinate conversion →
`SceneDocument` emission (`fscene_emitter.dart`) with payload bytes
attached, ready for `loadDocument` or `writeFscene`.

Upstream-fidelity adaptations:

- Imports land on dart3d's `scene_model.dart` component barrel, not
  `package:scene/scene.dart` (the upstream barrel transitively pulls
  the vendored-archive `.fsceneb` reader, which cannot compile under
  the DartNative kernel).
- `importGlbToFscenebBytes` is not ported — `.fsceneb` *writing*
  lives in the same archive-dependent file. Serialize with
  `writeFscene`.
- The `compressTextures` cooking option is not ported (no `package:
  image`/`ktx` encoder). Embedded images carry their encoded
  container bytes verbatim into `image` payloads — iOS's `UIImage`
  and Android's `BitmapFactory` paths sniff the container natively,
  so PNG/JPEG/WebP realize without a Dart decode.
- Draco is not ported. `KHR_draco_mesh_compression` in
  `extensionsRequired` throws `UnsupportedRequiredExtensionException`
  at parse; a Draco-compressed primitive under `extensionsUsed` fails
  loudly with `FormatException` at pack time rather than emitting
  garbage geometry.

Other negotiation: an `extensionsRequired` name the importer lacks
refuses loudly; an unrecognized `extensionsUsed` name routes to the
`onWarning` callback (or prints without one). Parsed material
extensions follow the glTF spec — `sheenRoughnessTexture`,
`specularFactor` defaulting to 1.0, etc.

## Deferred

- `EXT_meshopt_compression` sources that point at a non-primary
  buffer (`meshopt-multi-buffer` in `meshopt_decoder.dart`) — the
  codec as shipped feeds the decoder a single blob.
- The meshopt `COLOR` filter (`meshopt-color-filter`) — not defined
  by the extension version this decodes.
- Draco decode — needs a decoder port or a documented
  native-side dependency; refused loudly until then.
- `.fsceneb` writing — blocked on the DartNative
  `package:archive` shadowing, same as the barrel.
- Prefab-instance features inside imported scenes — the doc model
  still doesn't compose prefabs at import time.
