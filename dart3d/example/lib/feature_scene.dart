import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart' show dnLog;
import 'package:vector_math/vector_math.dart';

/// Builds the W0 feature-matrix scene: the die-and-slab roll plus one
/// node per harness feature — a nested rig (child mesh + child light),
/// a `visible:false` node, a second dynamic body, a textured material,
/// a payload-geometry mesh, the W3 upstream-layout payload probes
/// (CCW + legacyWinding quads, a deferred payload, a malformed payload,
/// an oversized-bounds collider, a ~10k-vertex grid), and the W4
/// texture probes — a second upright row of quads exercising the
/// rgba8/normal/emissive/MR texture slots, a UV-transformed checker
/// box, a deferred texture payload, a never-arriving texture, and a
/// timed `upsertResource` checker swap. The W5 probe runs at +8 s: a
/// mutated copy of the loaded document is diffed and shipped as
/// `command` ops through `SceneController.applyDiff`. W6 adds the
/// parity lanes: a backface-first `doubleSided` quad, a static
/// `concaveMesh` bowl collider the die can drop into, real
/// `shadowRadius`/`shadowDepthBias` values on the key light, and an
/// `allowsResting:false` body that joins with the +8 s diff. W7 wires
/// `stage.environmentRef` to an `EnvironmentResource` — the studio
/// baseline look — with [env] selecting the none/studio/constant/
/// payload-equirect/empty lane. W8 adds no nodes: the app's
/// `contactEvents` subscription and the +10 s [queryBattery] exercise
/// the contact-event and physics-query surfaces against the existing
/// landmarks. W9 adds the joint rig through the returned `jointRig`
/// closure — fired by the app's +12 s timer — which ships the rig's
/// bodies as `addNode` ops and then one `addJoint` op per lane
/// (upstream joints are runtime-only, so the command path is the only
/// way they exist). W11 lands the skins/animation probe through the
/// returned `w11Phase` closure — fired at +14 s — which upserts a
/// two-bone skinned "flag", a two-target morph blob, and the `wave`
/// (rotation channels on the joints) + `pulse` (weights channel)
/// animations, then drives them through the `anim` and
/// `setMorphWeights` ops (+16 s pulse, +18 s seek + weight write).
/// W12 lands the component-parity probe through the returned
/// `w12Phase` closure — fired at +22 s — which ships a world-anchored
/// `sphericalJoint` (hangs) next to a free twin (falls), a
/// component-declared `fixedJoint` gluing a link pair at its facing
/// surfaces, a `materialsVariants` cube cycling cool→warm→default
/// through `selectMaterialVariant` (+5 s / +9 s), and a
/// `rectAreaLight` carrying the corrected `enabled:false` mark (it
/// still lights — upstream gates component ticks only). W13 lands
/// the environment-effects probe through the returned `w13Phase`
/// closure — fired at +34 s — which rewrites the env resource's
/// `effects` spec on a two-second cadence: bloom, then +ambient
/// occlusion, +fog, +depth of field (the combined stack), a hard
/// swap to vignette + chromatic aberration + color grading, film
/// grain + auto-exposure, an all-defaults reset, and finally the
/// same resource with `overridesEffects:false` so the `effects`
/// key leaves the wire while natives retain the all-off state.
/// W14 lands the render-texture/views probe through the returned
/// `w14Phase` closure — fired at +50 s — which mints an everyFrame
/// render texture a second camera draws the dice area into while a
/// foreground cube samples it as `baseColorTexture`, adds a `manual`
/// target refreshed by the `render` op, grows the view list to two
/// producers on one target, shrinks it back, then toggles the
/// stage's AA/renderScale through `updateStage` and restores. The
/// loose-ends lane lands the remaining live evidence through the
/// returned `wLoosePhase` closure — fired at +78 s — which spawns
/// three judged probes (a `ccdEnabled` sphere dropped through a
/// 0.05 plate at 40 m/s, a laterally-drifting drop into the
/// `concaveMesh` bowl, and a dead drop onto `boundsQuad`'s
/// oversized-bounds collider), reads their rest poses back through
/// `poseOf`, then removes `w5NoRest` so the all-asleep `settled`
/// event fires again and times three roll→rest cycles on the die.
/// W15 lands the subtree-streaming lane through the returned
/// `w15Phase` closure — fired at +112 s — which realizes two lazy
/// `streamA`/`streamB` prefab placeholders (a 100-cell grid with a
/// payload-deferred peak; B carries the override/removedNodes/
/// addedComponents/attachments delta), lands the deferred vertex
/// chunk, then drops and re-streams streamA three times for the
/// no-stale-nodes lane. Send and native-visible timestamps log for
/// the manifest-to-visible latency measurement.
///
/// [ortho] flips the camera's `projection` manifest field; the toggle
/// is a document reload, the only camera write the protocol carries
/// today. `orthoScale` rides along as a provisional field until the
/// native camera work picks a name (W6). [env] selects the
/// environment/IBL lane: 0 leaves `stage.environmentRef` null (the
/// natives default to studio), 1 studio, 2 constant, 3 payload
/// equirect, 4 empty.
final class FeatureScene {
  FeatureScene._();

  /// The document and the ids the app needs to address afterwards.
  ///
  /// When [controller] is given, the deferred vertex payload's bytes
  /// are sent ~2 s after the manifest goes out (the deferred-payload
  /// lane — the document declares it with `bytes: null`).
  static ({
    SceneDocument document,
    LocalId die,
    LocalId ball,
    LocalId hidden,
    int Function() jointRig,
    void Function(void Function(int playing) report) w11Phase,
    void Function() w12Phase,
    void Function() w13Phase,
    void Function() w14Phase,
    void Function() wLoosePhase,
    void Function() w15Phase,
  })
  build({bool ortho = false, int env = 1, SceneController? controller}) {
    final doc = SceneDocument();

    // ── Resources ─────────────────────────────────────────────────────
    final geometry = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: CuboidGeometrySpec(extents: Vector3.all(1.0)),
      ),
    );
    final material = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.85, 0.2, 0.25, 1.0),
          'metallic': DoubleValue(0.05),
          'roughness': DoubleValue(0.55),
        },
      ),
    );
    final groundGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        // Narrow depth: the front edge lands mid-scene (z ∈ [−1, 4])
        // instead of ~0.2 from the camera, so the slab's front face
        // can't occlude the die.
        procedural: CuboidGeometrySpec(extents: Vector3(8, 0.5, 5)),
      ),
    );
    final groundMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.38, 0.38, 0.44, 1.0),
          'metallic': DoubleValue(0.0),
          'roughness': DoubleValue(0.9),
        },
      ),
    );
    final ballGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: SphereGeometrySpec(radius: 0.35),
      ),
    );
    final ballMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.3, 0.55, 0.95, 1.0),
          'metallic': DoubleValue(0.0),
          'roughness': DoubleValue(0.45),
        },
      ),
    );
    final markerGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: SphereGeometrySpec(radius: 0.18),
      ),
    );
    final markerMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.75, 0.2, 1.0),
          'roughness': DoubleValue(0.5),
        },
      ),
    );
    final childGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.5)),
      ),
    );
    final childMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.3, 0.85, 0.4, 1.0),
          'roughness': DoubleValue(0.5),
        },
      ),
    );
    final hiddenGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: TorusGeometrySpec(radius: 0.55, tubeRadius: 0.18),
      ),
    );
    final hiddenMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.2, 0.9, 1.0),
          'emissive': ColorValue(0.4, 0.05, 0.35, 1.0),
          'roughness': DoubleValue(0.5),
        },
      ),
    );
    // Physics-extras resources — shared 0.4 m cube for the probe boxes
    // and a thin shelf for the trigger probe.
    final smallBoxGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.4)),
      ),
    );
    final shelfGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: CuboidGeometrySpec(extents: Vector3(1.2, 0.06, 1.2)),
      ),
    );
    MaterialResource probeMat(double r, double g, double b) => MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(r, g, b, 1.0),
        'roughness': DoubleValue(0.6),
      },
    );
    final floaterMat = doc.addResource(probeMat(0.85, 0.55, 0.95));
    final sliderMat = doc.addResource(probeMat(0.95, 0.85, 0.3));
    final sinkerMat = doc.addResource(probeMat(0.95, 0.35, 0.2));
    final triggerMat = doc.addResource(probeMat(0.4, 0.85, 0.9));
    final offsetMat = doc.addResource(probeMat(0.6, 0.6, 0.9));
    final texturedGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.8)),
      ),
    );
    // Texture slot resolves only after W4 lands; until then the node
    // renders with its baseColor, which is the intended placeholder.
    final checkerPayload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'png',
        width: 64,
        height: 64,
        bytes: base64Decode(_checkerPng),
      ),
    );
    final checkerTex = doc.addResource(
      TextureResource(doc.newId(), payload: checkerPayload.id),
    );
    final texturedMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.95, 0.95, 1.0),
          'baseColorTexture': ResourceRefValue(checkerTex.id),
          'roughness': DoubleValue(0.6),
        },
      ),
    );
    // Payload geometry realizes only after W3; the manifest and chunks
    // are well-formed today, so the node exercises the pending-payload
    // path on every load.
    final tetra = _tetrahedron();
    final tetraVerts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'p3t4',
        length: tetra.vertices.lengthInBytes,
        bytes: tetra.vertices,
      ),
    );
    final tetraIndices = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: tetra.indices.lengthInBytes,
        bytes: tetra.indices,
      ),
    );
    final tetraGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: tetraVerts.id,
        indices: tetraIndices.id,
        bounds: tetra.bounds,
      ),
    );
    final tetraMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.55, 0.2, 1.0),
          'roughness': DoubleValue(0.5),
        },
      ),
    );

    // ── W3 upstream-layout payload probes ─────────────────────────────
    // A face-up quad packed by VertexPack into the pinned
    // `unskinned_uv1_tangent` interleave. One vertex payload feeds three
    // geometries: the v5+ CCW-indexed quad, its legacyWinding twin
    // (same verts, CW index buffer), and the deferred quad whose vertex
    // bytes arrive ~2 s after the manifest.
    final quad = _quad(0.35);
    final quadVerts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: quad.vertices.lengthInBytes,
        bytes: quad.vertices,
      ),
    );
    final quadIndices = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: quad.indices.lengthInBytes,
        bytes: quad.indices,
      ),
    );
    final quadIndicesCw = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: quad.indicesCw.lengthInBytes,
        bytes: quad.indicesCw,
      ),
    );
    final quadGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: quadVerts.id,
        indices: quadIndices.id,
        bounds: quad.bounds,
      ),
    );
    // The legacyWinding lane: identical vertex payload and bounds, but
    // the CW index buffer must render face-up all the same.
    final quadGeoLegacy = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: quadVerts.id,
        indices: quadIndicesCw.id,
        bounds: quad.bounds,
        legacyWinding: true,
      ),
    );
    // Manifest-only vertex payload — `bytes` stays null in the
    // document and is attached just before sendPayload fires.
    final deferredVerts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: quad.vertices.lengthInBytes,
      ),
    );
    final deferredGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: deferredVerts.id,
        indices: quadIndices.id,
        bounds: quad.bounds,
      ),
    );
    // Malformed on purpose: 10 B is not a multiple of the 72 B stride —
    // decoders must log one error and leave the node renderless.
    final badVerts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: 10,
        bytes: Uint8List(10),
      ),
    );
    final malformedGeo = doc.addResource(
      GeometryResource(doc.newId(), vertices: badVerts.id),
    );
    // Bounds wider than the mesh (±0.4 over a ±0.2 quad): the
    // boundingBox collider on the node reads the authored bounds, so
    // bodies rest on an invisible margin around the small plate.
    final boundsQuad = _quad(0.2);
    final boundsVerts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: boundsQuad.vertices.lengthInBytes,
        bytes: boundsQuad.vertices,
      ),
    );
    final boundsGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: boundsVerts.id,
        indices: quadIndices.id,
        bounds: BoundsSpec(min: Vector3.all(-0.4), max: Vector3.all(0.4)),
      ),
    );
    // ~10k-vertex subdivided plane for the payload perf lane. uint32
    // indices are deliberate — uint16 would fit 10201 verts, so this
    // doubles as the second index-format coverage.
    final grid = _grid(segments: 100, size: 1.2);
    final gridVerts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: grid.vertices.lengthInBytes,
        bytes: grid.vertices,
      ),
    );
    final gridIndices = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint32',
        length: grid.indices.lengthInBytes,
        bytes: grid.indices,
      ),
    );
    final gridGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: gridVerts.id,
        indices: gridIndices.id,
        bounds: grid.bounds,
      ),
    );
    final quadMat = doc.addResource(probeMat(0.2, 0.85, 0.8));
    // Distinct colors for the winding/deferred pair: with identical
    // materials a culled backface is indistinguishable from an
    // occluded twin in a still frame.
    final quadMatLegacy = doc.addResource(probeMat(0.95, 0.25, 0.25));
    final quadMatDeferred = doc.addResource(probeMat(0.3, 0.4, 0.95));
    final boundsMat = doc.addResource(probeMat(0.55, 0.95, 0.35));
    final gridMat = doc.addResource(probeMat(0.5, 0.55, 0.7));

    // ── W4 texture-slot probes ──────────────────────────────────────
    // Generated rgba8 images ride the same payload stream as the
    // vertex chunks: the manifest entry carries encoding/format/
    // width/height/length and the bytes travel as `payload` chunks.
    // The probe quads below share the W3 `quadGeo` — UVs 0..1 across
    // the face, +Y normals, unit +X tangents — so the tangent frame is
    // valid for normal mapping once the quad stands upright.
    const texSize = 64;
    final normalPixels = _normalBrick(texSize, texSize);
    final normalMapPayload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: texSize,
        height: texSize,
        length: normalPixels.lengthInBytes,
        bytes: normalPixels,
      ),
    );
    final normalTex = doc.addResource(
      TextureResource(
        doc.newId(),
        payload: normalMapPayload.id,
        content: 'normal',
      ),
    );
    // glTF-packed metallic/roughness map: G = roughness, B = metallic.
    final mrPixels = _mrPatch(16, 16);
    final mrPayload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: 16,
        height: 16,
        length: mrPixels.lengthInBytes,
        bytes: mrPixels,
      ),
    );
    final mrTex = doc.addResource(
      TextureResource(doc.newId(), payload: mrPayload.id, content: 'data'),
    );
    final dotsPixels = _emissiveDots(texSize, texSize);
    final dotsPayload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: texSize,
        height: texSize,
        length: dotsPixels.lengthInBytes,
        bytes: dotsPixels,
      ),
    );
    final dotsTex = doc.addResource(
      TextureResource(doc.newId(), payload: dotsPayload.id),
    );
    // Raw-rgba8 twin of the PNG checker — the uncompressed
    // `format: 'rgba8'` decode path instead of the magic-bytes
    // container path the `textured` box exercises.
    final checkerPixels = _checkerRgba(texSize, texSize);
    final checkerRgbaPayload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: texSize,
        height: texSize,
        length: checkerPixels.lengthInBytes,
        bytes: checkerPixels,
      ),
    );
    final checkerRgbaTex = doc.addResource(
      TextureResource(doc.newId(), payload: checkerRgbaPayload.id),
    );
    // Lane-10 swap target: the inverted checker's bytes ship with the
    // document, so the +6 s `upsertResource` is a pure resource edit —
    // no payload wait on the swap itself.
    final checkerAltPixels = _checkerInv(texSize, texSize);
    final checkerAlt = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: texSize,
        height: texSize,
        length: checkerAltPixels.lengthInBytes,
        bytes: checkerAltPixels,
      ),
    );
    // Lane 7/8: manifest entry with no bytes — the chunk is attached
    // and sent ~3 s after load, and the texture's consumers rebind on
    // the payload-arrival re-realize.
    final deferredTexPayload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: texSize,
        height: texSize,
        length: texSize * texSize * 4,
      ),
    );
    final deferredTex = doc.addResource(
      TextureResource(doc.newId(), payload: deferredTexPayload.id),
    );
    // Lane 9: declared and never sent — the material keeps its
    // baseColor (the neutral-fallback lane).
    final missingTexPayload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: texSize,
        height: texSize,
        length: texSize * texSize * 4,
      ),
    );
    final missingTex = doc.addResource(
      TextureResource(doc.newId(), payload: missingTexPayload.id),
    );

    // One material per probe. Factor × texture is the contract, so
    // factors that should let the map decide sit at 1.0.
    final uvTexMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.95, 0.95, 1.0),
          'baseColorTexture': ResourceRefValue(checkerTex.id),
          'roughness': DoubleValue(0.6),
        },
      ),
    );
    final normalMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.62, 0.62, 0.68, 1.0),
          'normalTexture': ResourceRefValue(normalTex.id),
          'normalScale': DoubleValue(1.0),
          'metallicRoughnessTexture': ResourceRefValue(mrTex.id),
          // Factors at 1 let the packed G/B channels set roughness and
          // metallic outright.
          'metallic': DoubleValue(1.0),
          'roughness': DoubleValue(1.0),
        },
      ),
    );
    final emissiveMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.05, 0.05, 0.08, 1.0),
          'emissive': ColorValue(1, 1, 1, 1),
          'emissiveStrength': DoubleValue(2.0),
          'emissiveTexture': ResourceRefValue(dotsTex.id),
        },
      ),
    );
    final uvShiftMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(1, 1, 1, 1),
          'baseColorTexture': ResourceRefValue(checkerRgbaTex.id),
          // KHR_texture_transform: samples the checker's middle half —
          // offset applies after scale, so the window is [0.25, 0.75).
          'baseColorTextureTransform': MapValue({
            'offset': Vec2Value(Vector2(0.25, 0.25)),
            'scale': Vec2Value(Vector2(0.5, 0.5)),
            'rotation': DoubleValue(0),
            'texCoord': IntValue(0),
          }),
          'roughness': DoubleValue(0.6),
        },
      ),
    );
    final deferredTexMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.95, 0.95, 1.0),
          'baseColorTexture': ResourceRefValue(deferredTex.id),
          'roughness': DoubleValue(0.6),
        },
      ),
    );
    final missingTexMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          // Loud on purpose — the fallback color is the lane's
          // evidence while the texture's payload never lands.
          'baseColor': ColorValue(0.9, 0.25, 0.6, 1.0),
          'baseColorTexture': ResourceRefValue(missingTex.id),
          'roughness': DoubleValue(0.5),
        },
      ),
    );
    final uvShiftGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.6)),
      ),
    );

    // ── W6 parity-lane resources ────────────────────────────────────
    // Backface-first quad: the shared vertex payload indexed by the CW
    // buffer WITHOUT the legacyWinding flag, so its front face points
    // away from the camera and it renders only where the material's
    // `doubleSided` applies (iOS `isDoubleSided`, Android
    // `MaterialInstance.setDoubleSided`).
    final doubleSidedGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: quadVerts.id,
        indices: quadIndicesCw.id,
        bounds: quad.bounds,
      ),
    );
    final doubleSidedMat = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.6, 0.1, 1.0),
          'roughness': DoubleValue(0.6),
          'doubleSided': BoolValue(true),
        },
      ),
    );
    // concaveMesh lane: an open-top box (five-face bowl) as a payload
    // mesh — the collider derives its triangle mesh from the node's
    // realized geometry on both platforms (Jolt MeshShape, SceneKit
    // concavePolyhedron; static bodies only).
    final bowl = _openBox(half: 0.6, height: 0.45);
    final bowlVerts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: bowl.vertices.lengthInBytes,
        bytes: bowl.vertices,
      ),
    );
    final bowlIndices = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: bowl.indices.lengthInBytes,
        bytes: bowl.indices,
      ),
    );
    final bowlGeo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: bowlVerts.id,
        indices: bowlIndices.id,
        bounds: bowl.bounds,
      ),
    );
    final bowlMat = doc.addResource(probeMat(0.7, 0.75, 0.95));

    // Deferred-payload lane: loadDocument skips byte-less payloads, so
    // attach the quad bytes and push the chunk ~2 s after the manifest.
    // Armed only when the app hands over its controller.
    //
    // The +8 s diff's product document — the controller's tracked
    // `document` from that point on — so the +12 s joint rig can mint
    // node ids on it (keeps applyDiff bookkeeping and native state in
    // sync).
    SceneDocument? phaseTwoDoc;
    if (controller != null) {
      Timer(const Duration(seconds: 2), () {
        deferredVerts.bytes = quad.vertices;
        controller.sendPayload(deferredVerts);
      });
      // W4 lane 7/8 — the same deferred-payload mechanism for a
      // texture: the manifest named deferredTexPayload with no bytes,
      // so deferredTexQuad renders its material's baseColor until the
      // chunk lands and the slot binds on re-realize.
      Timer(const Duration(seconds: 3), () {
        deferredTexPayload.bytes = _checkerRgba(texSize, texSize);
        controller.sendPayload(deferredTexPayload);
      });
      // W4 lane 10 — surgical resource edit: repoint checkerTex at the
      // inverted checker without a reload, so every consumer (the
      // `textured` box and `uvTexQuad`) flips at once. Ids use the
      // manifest's `<prefix>:<base32>` token form (`tex:`/`chunk:`) —
      // the native decoders strip the prefix when parsing, matching
      // LocalId.parse.
      Timer(const Duration(seconds: 6), () {
        controller.applyCommands([
          {
            'op': 'upsertResource',
            'id': 'tex:${checkerTex.id.toToken()}',
            'resource': {
              'kind': 'texture',
              'payload': 'chunk:${checkerAlt.id.toToken()}',
              'content': 'color',
            },
          },
        ]);
      });
      // W5 — the live structural diff, fired at +8 s so it stays clear
      // of W4's +6 s texture swap. `_phaseTwo` returns a mutated copy
      // of `doc` with stable ids, so `diffScene` + `applyDiff` emit
      // every W5 lane from the real diff path: the rig subtree is
      // removed, the emissive quad moves, the offset box reparents
      // under `ground`, the ball's material recolors (material
      // upsert), the UV-shift cube becomes a sphere (geometry
      // upsert), the tetra's vertex chunk is morphed (payload
      // upsert), and a quad + 40-box strip pushes the batch to ~50
      // ops. The trailing `updateNode` targets `rig.mesh` — already
      // removed by the batch — for the stale-id lane (a diff never
      // produces one, so it is appended by hand).
      Timer(const Duration(seconds: 8), () {
        final next = _phaseTwo(doc);
        phaseTwoDoc = next;
        controller.applyDiff(diffScene(doc, next), next);
        final rigMesh = doc.nodes.values.firstWhere(
          (n) => n.name == 'rig.mesh',
        );
        controller.applyCommands([
          {
            'op': 'updateNode',
            'node': rigMesh.id.toToken(),
            'flags': ['transform'],
            'spec': encodeNodeCommandSpec(rigMesh, doc),
          },
        ]);
      });
    }

    // ── W7 environment/IBL ──────────────────────────────────────────
    // `stage.environmentRef` → an EnvironmentResource on the baseline
    // look (intensity/exposure 1, pbrNeutral, env-source skybox) with
    // only the sealed `environment` member swapped per lane
    // (docs/environment-ibl-spec.md). env 0 leaves the ref null —
    // natives default to studio — so the wire stays empty there.
    if (env != 0) {
      final EnvironmentSpec environment;
      if (env == 3) {
        // The payload lane's equirect rides the chunk stream like the
        // W3/W4 payloads — `format: 'png'` is informational, natives
        // pick the decoder from the magic bytes.
        final equirect = doc.addPayload(
          PayloadSpec(
            doc.newId(),
            encoding: PayloadEncoding.image,
            format: 'png',
            width: 64,
            height: 32,
            bytes: base64Decode(_envEquirectPng),
          ),
        );
        environment = PayloadEnvironment(equirect.id);
      } else {
        environment = switch (env) {
          2 => ConstantEnvironment(Vector3(0.25, 0.18, 0.12)),
          4 => const EmptyEnvironment(),
          _ => const StudioEnvironment(),
        };
      }
      doc.stage.environmentRef = doc
          .addResource(
            EnvironmentResource(
              doc.newId(),
              environment: environment,
              environmentIntensity: 1.0,
              exposure: 1.0,
              toneMapping: 'pbrNeutral',
              skybox: SkyboxSpec(EnvironmentSkySpec()),
              // Explicit so the W13 phase has an `effects` block on
              // the wire to toggle (the default would emit it too —
              // `overridesEffects` defaults true).
              effects: EnvironmentEffectsSpec(),
            ),
          )
          .id;
    }

    // ── Nodes ─────────────────────────────────────────────────────────
    final die = doc.createNode(
      name: 'die',
      transform: TrsTransform(translation: Vector3(0, 1.2, 0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(geometry.id),
            'material': ResourceRefValue(material.id),
          },
        ),
        colliderComponent(
          shape: 'box',
          extents: Vector3.all(1.0),
          friction: 0.5,
          restitution: 0.35,
        ),
        rigidBodyComponent(
          type: 'dynamic',
          mass: 0.5,
          linearDamping: 0.05,
          angularDamping: 0.05,
          // Dice move fast and slabs are thin — without continuous
          // collision detection a fast step can tunnel.
          ccdEnabled: true,
        ),
      ],
      root: true,
    );

    // Second dynamic body: drops beside the die and settles on its own.
    final ball = doc.createNode(
      name: 'ball',
      transform: TrsTransform(translation: Vector3(1.7, 1.0, 3.0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(ballGeo.id),
            'material': ResourceRefValue(ballMat.id),
          },
        ),
        colliderComponent(
          shape: 'sphere',
          radius: 0.35,
          friction: 0.6,
          restitution: 0.3,
        ),
        rigidBodyComponent(
          type: 'dynamic',
          mass: 0.4,
          linearDamping: 0.05,
          angularDamping: 0.05,
          ccdEnabled: true,
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'ground',
      transform: TrsTransform(translation: Vector3(0, -0.75, 1.5)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(groundGeo.id),
            'material': ResourceRefValue(groundMat.id),
          },
        ),
        colliderComponent(
          shape: 'box',
          extents: Vector3(8, 0.5, 5),
          friction: 0.7,
          restitution: 0.3,
          // An explicit layer so mask-filtered probes can exclude it.
          collisionLayer: 0x1,
        ),
        rigidBodyComponent(type: 'fixed'),
        physicsWorldComponent(gravity: Vector3(0, -9.8, 0)),
      ],
      root: true,
    );

    // Physics-extras probes — one per upstream field, kept visually
    // legible: a floater that never falls, a slider that can only move
    // on Y, a mask-filtered sinker that drops through the floor, a
    // trigger shelf the ball falls through, and a box whose collider
    // sits offset from its mesh.
    doc.createNode(
      name: 'floater',
      transform: TrsTransform(translation: Vector3(-2.2, 1.2, -2.5)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(smallBoxGeo.id),
            'material': ResourceRefValue(floaterMat.id),
          },
        ),
        colliderComponent(shape: 'box', extents: Vector3.all(0.4)),
        rigidBodyComponent(type: 'dynamic', useGravity: false),
      ],
      root: true,
    );

    doc.createNode(
      name: 'slider',
      transform: TrsTransform(translation: Vector3(-1.2, -0.2, 2.2)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(smallBoxGeo.id),
            'material': ResourceRefValue(sliderMat.id),
          },
        ),
        colliderComponent(shape: 'box', extents: Vector3.all(0.4)),
        rigidBodyComponent(
          type: 'dynamic',
          // Y stays free; horizontal axes are locked.
          linearAxisLocks: Vector3(0, 1, 0),
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'sinker',
      transform: TrsTransform(translation: Vector3(-0.4, 0.4, 2.4)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(smallBoxGeo.id),
            'material': ResourceRefValue(sinkerMat.id),
          },
        ),
        colliderComponent(
          shape: 'box',
          extents: Vector3.all(0.4),
          // Responds only to layer 0x2 — falls through the 0x1 slab,
          // then comes to rest on the invisible catcher below so the
          // scene can still settle.
          collisionLayer: 0x2,
          collisionMask: 0x2,
        ),
        rigidBodyComponent(type: 'dynamic'),
      ],
      root: true,
    );

    // Invisible catcher for the sinker — a collider-only node (no
    // mesh) on layer 0x2, just under the slab. Without it the sinker
    // falls forever and the world can never report all-asleep; placed
    // close so the sinker is still slow when it lands (a deep fall
    // would tunnel straight through a thin plate).
    doc.createNode(
      name: 'catcher',
      transform: TrsTransform(translation: Vector3(-0.4, -3.0, 2.4)),
      components: [
        colliderComponent(
          shape: 'box',
          extents: Vector3(4, 1.0, 4),
          collisionLayer: 0x2,
        ),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );

    doc.createNode(
      name: 'triggerShelf',
      transform: TrsTransform(translation: Vector3(1.7, 0.35, 3.0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(shelfGeo.id),
            'material': ResourceRefValue(triggerMat.id),
          },
        ),
        colliderComponent(
          shape: 'box',
          extents: Vector3(1.2, 0.06, 1.2),
          // Sensor — the ball drops straight through it.
          isTrigger: true,
        ),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );

    doc.createNode(
      name: 'offsetBox',
      transform: TrsTransform(translation: Vector3(2.6, -0.4, -0.6)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(smallBoxGeo.id),
            'material': ResourceRefValue(offsetMat.id),
          },
        ),
        colliderComponent(
          shape: 'box',
          extents: Vector3.all(0.4),
          // The collision volume sits 0.9 to the box's +X — bodies rest
          // on invisible ground beside the visible mesh.
          localPose: Matrix4.identity()..setTranslationRaw(0.9, 0, 0),
        ),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );

    doc.createNode(
      name: 'camera',
      transform: TrsTransform(
        translation: Vector3(0, 3.4, -6.5),
        // Pitch down ~28° to frame the whole matrix, not just the die.
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.5),
      ),
      components: [
        ComponentSpec(
          'camera',
          properties: {
            'projection': StringValue(ortho ? 'orthographic' : 'perspective'),
            if (ortho) 'orthoScale': DoubleValue(4.0),
            'fovRadiansY': DoubleValue(1.0),
            'near': DoubleValue(0.05),
            'far': DoubleValue(100),
          },
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'key',
      transform: TrsTransform(
        rotation: Quaternion.axisAngle(
          Vector3(0.7, 0.0, 0.7)..normalize(),
          -0.8,
        ),
      ),
      components: [
        ComponentSpec(
          'directionalLight',
          properties: {
            'color': ColorValue(1, 1, 1, 1),
            'intensity': DoubleValue(1400),
            'castsShadow': BoolValue(true),
            // W6 shadow lane — iOS reads these as
            // shadowRadius/shadowBias; Android maps them onto Filament
            // shadowOptions (bulbRadius + constant/normal bias).
            'shadowRadius': DoubleValue(3.0),
            'shadowDepthBias': DoubleValue(0.005),
          },
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'fill',
      transform: TrsTransform(translation: Vector3(-2, 2, -1)),
      components: [
        ComponentSpec(
          'pointLight',
          properties: {
            'color': ColorValue(0.6, 0.7, 1.0, 1),
            'intensity': DoubleValue(900),
            'range': DoubleValue(30),
          },
        ),
      ],
      root: true,
    );

    // Nested rig: the marker sphere anchors the parent position, the
    // child box sits up-right of it, and the child light floats above —
    // both children exist only through the parent's children list.
    // The colliders make the whole rig solid, so a thrown die can rest
    // stacked on a child node — collider placement must use the node's
    // world transform, not its local one.
    final rig = doc.createNode(
      name: 'rig',
      transform: TrsTransform(translation: Vector3(-1.5, -0.32, 0.6)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(markerGeo.id),
            'material': ResourceRefValue(markerMat.id),
          },
        ),
        colliderComponent(shape: 'sphere', radius: 0.18),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );
    final rigChild = doc.createNode(
      name: 'rig.mesh',
      transform: TrsTransform(translation: Vector3(0.6, 0.45, 0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(childGeo.id),
            'material': ResourceRefValue(childMat.id),
          },
        ),
        // Derived from the node's realized geometry — exercises the
        // boundingBox extension on a non-root node.
        colliderComponent(shape: 'boundingBox'),
        rigidBodyComponent(type: 'fixed'),
      ],
    );
    final rigLight = doc.createNode(
      name: 'rig.light',
      transform: TrsTransform(translation: Vector3(0, 1.0, 0.4)),
      components: [
        ComponentSpec(
          'pointLight',
          properties: {
            'color': ColorValue(1.0, 0.75, 0.45, 1),
            'intensity': DoubleValue(40),
            'range': DoubleValue(6),
          },
        ),
      ],
    );
    rig.children.addAll([rigChild.id, rigLight.id]);

    // Hidden node: bright magenta torus dead-center in frame — if it
    // ever draws, the lane fails loudly. Roll writes a rotation to it
    // so the "hidden survives transform writes" check runs every throw.
    final hidden = doc.createNode(
      name: 'hidden',
      transform: TrsTransform(translation: Vector3(-0.4, 1.3, 3.0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(hiddenGeo.id),
            'material': ResourceRefValue(hiddenMat.id),
          },
        ),
      ],
      root: true,
    );
    hidden.visible = false;

    doc.createNode(
      name: 'textured',
      transform: TrsTransform(translation: Vector3(1.5, -0.1, 0.9)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(texturedGeo.id),
            'material': ResourceRefValue(texturedMat.id),
          },
        ),
        colliderComponent(shape: 'box', extents: Vector3.all(0.8)),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );

    doc.createNode(
      name: 'payloadTetra',
      transform: TrsTransform(translation: Vector3(0.6, -0.5, 3.3)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(tetraGeo.id),
            'material': ResourceRefValue(tetraMat.id),
          },
        ),
      ],
      root: true,
    );

    // W3 payload probes, in a row on the slab's left half where the
    // camera's downward pitch keeps them in frame: the upstream-layout
    // quad beside its legacyWinding twin (the two must render face-up
    // identically), then the deferred quad that pops in ~2 s after
    // load, and the malformed payload whose node must stay renderless.
    doc.createNode(
      name: 'payloadQuad',
      transform: TrsTransform(
        translation: Vector3(-2.6, 0.35, -1.2),
        // Flat-authored quads, rotated to face the camera so winding
        // reads as lit-vs-black instead of an edge-on sliver. The row
        // floats in front of the rig so nothing occludes the pair.
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeo.id),
            'material': ResourceRefValue(quadMat.id),
          },
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'payloadQuadLegacy',
      transform: TrsTransform(
        translation: Vector3(-1.7, 0.35, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeoLegacy.id),
            'material': ResourceRefValue(quadMatLegacy.id),
          },
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'deferredQuad',
      transform: TrsTransform(
        translation: Vector3(-0.8, 0.35, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(deferredGeo.id),
            'material': ResourceRefValue(quadMatDeferred.id),
          },
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'malformedPayload',
      transform: TrsTransform(translation: Vector3(0.5, -0.45, 2.0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(malformedGeo.id),
            'material': ResourceRefValue(quadMat.id),
          },
        ),
      ],
      root: true,
    );

    // Bounds-collider lane, parked in the die's re-throw footprint. The
    // mesh is the small ±0.2 quad; the ±0.4 authored bounds turn the
    // boundingBox collider into an 0.8 m invisible box, so a die that
    // lands here rests visibly above the slab — the margin is the
    // evidence.
    doc.createNode(
      name: 'boundsQuad',
      transform: TrsTransform(translation: Vector3(0.2, -0.45, 1.1)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(boundsGeo.id),
            'material': ResourceRefValue(boundsMat.id),
          },
        ),
        colliderComponent(shape: 'boundingBox'),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );

    // Perf lane: ~10k payload verts flat near the right edge of frame.
    doc.createNode(
      name: 'payloadGrid',
      transform: TrsTransform(translation: Vector3(3.1, -0.48, 1.4)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(gridGeo.id),
            'material': ResourceRefValue(gridMat.id),
          },
        ),
      ],
      root: true,
    );

    // ── W4 texture probes, second upright row ───────────────────────
    // One row up from the W3 quads (y 1.4 vs 0.35, same z) so the two
    // rows can't occlude each other at the camera's pitch, and the same
    // stand-upright rotation so each quad faces the camera. All five
    // quads share quadGeo.
    doc.createNode(
      name: 'uvTexQuad',
      transform: TrsTransform(
        translation: Vector3(-1.2, 1.4, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeo.id),
            'material': ResourceRefValue(uvTexMat.id),
          },
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'normalQuad',
      transform: TrsTransform(
        translation: Vector3(-0.5, 1.4, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeo.id),
            'material': ResourceRefValue(normalMat.id),
          },
        ),
      ],
      root: true,
    );

    doc.createNode(
      name: 'emissiveQuad',
      transform: TrsTransform(
        translation: Vector3(0.2, 1.4, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeo.id),
            'material': ResourceRefValue(emissiveMat.id),
          },
        ),
      ],
      root: true,
    );

    // Pops a checker in ~3 s when deferredTexPayload lands.
    doc.createNode(
      name: 'deferredTexQuad',
      transform: TrsTransform(
        translation: Vector3(0.9, 1.4, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeo.id),
            'material': ResourceRefValue(deferredTexMat.id),
          },
        ),
      ],
      root: true,
    );

    // missingTexPayload never ships — this stays the material's bright
    // baseColor for the whole run (the neutral-fallback lane).
    doc.createNode(
      name: 'missingTexQuad',
      transform: TrsTransform(
        translation: Vector3(1.6, 1.4, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeo.id),
            'material': ResourceRefValue(missingTexMat.id),
          },
        ),
      ],
      root: true,
    );

    // UV-transform lane: the rgba8 checker seen through
    // offset+scale [0.25, 0.75) — a zoomed window of the board, not
    // the whole texture the other checkered nodes show.
    doc.createNode(
      name: 'uvShiftBox',
      transform: TrsTransform(translation: Vector3(2.3, 1.4, -1.2)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(uvShiftGeo.id),
            'material': ResourceRefValue(uvShiftMat.id),
          },
        ),
      ],
      root: true,
    );

    // ── W6 parity-lane probes ───────────────────────────────────────
    // Extends the W4 row one slot left. Indexed backface-first, so
    // with single-sided rendering it is invisible — it draws only
    // where the material's doubleSided applies. Clear of every node
    // the +8 s diff mutates or adds.
    doc.createNode(
      name: 'doubleSidedQuad',
      transform: TrsTransform(
        translation: Vector3(-1.9, 1.4, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(doubleSidedGeo.id),
            'material': ResourceRefValue(doubleSidedMat.id),
          },
        ),
      ],
      root: true,
    );

    // Static open-top bowl on the slab's left half — reachable on a
    // lateral bounce, clear of the die's straight drop and of the
    // slider/sinker/ball footprints. The concaveMesh collider derives
    // from the node's payload mesh (mustBeStatic → the body stays
    // 'fixed' even if authored otherwise).
    doc.createNode(
      name: 'concaveBowl',
      transform: TrsTransform(translation: Vector3(-2.6, -0.46, 1.6)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(bowlGeo.id),
            'material': ResourceRefValue(bowlMat.id),
          },
        ),
        colliderComponent(
          shape: 'concaveMesh',
          friction: 0.6,
          restitution: 0.2,
        ),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );

    // ── W15 lazy prefab placeholders ────────────────────────────────
    // Two lazy instances of the same grid prefab — tagged, contentless
    // nodes until the +112 s phase streams them (the `instance` member
    // rides the manifest and the natives record it). `streamB` carries
    // the per-instance delta lane: a material override retinting the
    // prefab's `peak` marker the die's red, one corner cell removed, a
    // point light added on the instance root, and `beacon` grafted
    // under the peak. The prefab builds in code — `resolve` closures
    // ARE the host-layer asset resolution (the same contract a bundle
    // read satisfies); no asset file needed for the harness.
    final w15 = _w15Prefab();
    // A host node grafted under streamB's peak at load time and
    // reparented home on unload — the attachment lane. Before the
    // stream lands it rests as a plain scene node above the slab.
    final beacon = doc.createNode(
      name: 'w15Beacon',
      transform: TrsTransform(translation: Vector3(0, 0.7, 0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(ballGeo.id),
            'material': ResourceRefValue(emissiveMat.id),
          },
        ),
      ],
      root: true,
    );
    final streamA = doc.addNode(
      NodeSpec(
        id: doc.newId(),
        name: 'streamA',
        transform: TrsTransform(translation: Vector3(-2.9, -0.42, 1.5)),
        instance: PrefabInstanceSpec(
          source: const AssetRef('w15-grid'),
          load: LoadPolicy.lazy,
        ),
      ),
      root: true,
    );
    final streamB = doc.addNode(
      NodeSpec(
        id: doc.newId(),
        name: 'streamB',
        transform: TrsTransform(translation: Vector3(2.9, -0.42, 1.5)),
        instance: PrefabInstanceSpec(
          source: const AssetRef('w15-grid'),
          load: LoadPolicy.lazy,
          overrides: [
            PropertyOverride(
              target: w15.peak,
              path: 'components.mesh.material',
              value: ResourceRefValue(material.id),
            ),
          ],
          removedNodes: [w15.cornerCell],
          addedComponents: [
            ComponentSpec(
              'pointLight',
              properties: {
                'color': ColorValue(1.0, 0.8, 0.5, 1),
                'intensity': DoubleValue(60),
                'range': DoubleValue(6),
              },
            ),
          ],
          attachments: [Attachment(beacon.id, parent: w15.peak)],
        ),
      ),
      root: true,
    );
    // Fired by the app's +12 s timer (after the W8 query battery). A
    // back-row of small bodies hung off static anchors — one lane per
    // joint type — shipped end to end through `command` ops: one
    // addNode batch first (the joints need live bodies to land on),
    // then one addJoint op per lane. Node ids mint on `live` — the
    // post-diff document once the +8 s phase has run — so the
    // controller's tracked document stays in sync with what natives
    // hold. Mesh refs can only name resources that survived the
    // manifest round-trip, so the rig reuses the shared probe
    // geometries/materials rather than upserting new ones.
    int addJointRig() {
      final c = controller;
      if (c == null) return 0;
      final live = phaseTwoDoc ?? doc;
      final adds = <Map<String, Object?>>[];

      ComponentSpec rigMesh(LocalId geo, LocalId mat) => ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(geo),
          'material': ResourceRefValue(mat),
        },
      );

      // One small meshed body — mesh + collider + rigidBody — and its
      // addNode op, appended to `adds`.
      LocalId body(
        String name,
        Vector3 position,
        LocalId geo,
        LocalId mat,
        ComponentSpec collider,
        ComponentSpec rigidBody,
      ) {
        final node = live.createNode(
          name: name,
          transform: TrsTransform(translation: position),
          components: [rigMesh(geo, mat), collider, rigidBody],
          root: true,
        );
        adds.add({
          'op': 'addNode',
          'node': node.id.toToken(),
          'parent': null,
          'spec': encodeNodeCommandSpec(node, live),
        });
        return node.id;
      }

      ComponentSpec fixedBody() => rigidBodyComponent(type: 'fixed');
      ComponentSpec dynamicBody({
        double mass = 0.3,
        Vector3? angularVelocityAxis,
        double? angularVelocityRate,
      }) => rigidBodyComponent(
        type: 'dynamic',
        mass: mass,
        linearDamping: 0.05,
        angularDamping: 0.05,
        // The velocity extension fields give the swing lanes a push
        // without a follow-up setVelocity op.
        angularVelocityAxis: angularVelocityAxis,
        angularVelocityRate: angularVelocityRate,
      );
      ComponentSpec sphereCollider() =>
          colliderComponent(shape: 'sphere', radius: 0.18);
      ComponentSpec boxCollider() =>
          colliderComponent(shape: 'box', extents: Vector3.all(0.4));

      // A clear row along the slab's back edge (z = 3.9), clear of the
      // die's landing zone and the W3–W6 probes; the anchors float —
      // fixed bodies need no floor.
      const z = 3.9;

      // Pendulum — spherical: a fixed marker with a bob hung ~0.55
      // below it, displaced off-vertical so gravity swings it in.
      final pendAnchor = body(
        'j9.pendAnchor',
        Vector3(-3.4, 2.5, z),
        markerGeo.id,
        markerMat.id,
        sphereCollider(),
        fixedBody(),
      );
      final pendBob = body(
        'j9.pendBob',
        Vector3(-3.26, 1.97, z - 0.05),
        markerGeo.id,
        ballMat.id,
        sphereCollider(),
        dynamicBody(),
      );

      // Door — revolute on a vertical axis, ±100° limits: the panel
      // spawns beside the frame's edge and starts spinning, so it
      // swings and bangs into its stops.
      final doorFrame = body(
        'j9.doorFrame',
        Vector3(-2.5, 1.7, z),
        smallBoxGeo.id,
        sinkerMat.id,
        boxCollider(),
        fixedBody(),
      );
      final doorPanel = body(
        'j9.doorPanel',
        Vector3(-2.1, 1.7, z),
        smallBoxGeo.id,
        childMat.id,
        boxCollider(),
        dynamicBody(
          mass: 0.4,
          angularVelocityAxis: Vector3(0, 1, 0),
          angularVelocityRate: 2.0,
        ),
      );

      // Elevator — prismatic on a vertical axis with a velocity motor:
      // the platform slides up its rail and holds at the upper limit.
      final liftRail = body(
        'j9.liftRail',
        Vector3(-1.4, 2.1, z),
        smallBoxGeo.id,
        offsetMat.id,
        boxCollider(),
        fixedBody(),
      );
      final liftPlate = body(
        'j9.liftPlate',
        Vector3(-1.4, 1.6, z),
        smallBoxGeo.id,
        triggerMat.id,
        boxCollider(),
        dynamicBody(mass: 0.5),
      );

      // Welded pair — fixed: two stacked dynamic boxes that drop onto
      // the slab's back edge and move as one.
      final weldA = body(
        'j9.weldA',
        Vector3(-0.4, 1.8, z),
        smallBoxGeo.id,
        floaterMat.id,
        boxCollider(),
        dynamicBody(),
      );
      final weldB = body(
        'j9.weldB',
        Vector3(-0.4, 2.2, z),
        smallBoxGeo.id,
        sliderMat.id,
        boxCollider(),
        dynamicBody(),
      );

      // Chain — five bodies (anchor + four links) on spherical joints,
      // hanging plumb 0.3 apart.
      final chainAnchor = body(
        'j9.chainAnchor',
        Vector3(0.6, 3.0, z),
        markerGeo.id,
        markerMat.id,
        sphereCollider(),
        fixedBody(),
      );
      final chainLinks = [
        for (var i = 1; i <= 4; i++)
          body(
            'j9.chain$i',
            Vector3(0.6, 3.0 - 0.3 * i, z),
            markerGeo.id,
            quadMat.id,
            sphereCollider(),
            dynamicBody(mass: 0.15),
          ),
      ];

      // Generic — linear locked + one limited angular axis: the same
      // silhouette as a hinge (about Z here), exercising the 6-DOF
      // decode.
      final genAnchor = body(
        'j9.genAnchor',
        Vector3(1.8, 2.7, z),
        smallBoxGeo.id,
        groundMat.id,
        boxCollider(),
        fixedBody(),
      );
      final genBox = body(
        'j9.genBox',
        Vector3(1.8, 2.3, z),
        smallBoxGeo.id,
        boundsMat.id,
        boxCollider(),
        dynamicBody(
          angularVelocityAxis: Vector3(0, 0, 1),
          angularVelocityRate: 1.5,
        ),
      );

      // Breakable — a spherical joint with `breakDistance`; a scripted
      // impulse (sent right after the joints) yanks the anchors past
      // the threshold → the `broke` event lands on `jointEvents`.
      final breakAnchor = body(
        'j9.breakAnchor',
        Vector3(2.9, 2.7, z),
        smallBoxGeo.id,
        doubleSidedMat.id,
        boxCollider(),
        fixedBody(),
      );
      final breakBox = body(
        'j9.breakBox',
        Vector3(2.9, 2.3, z),
        smallBoxGeo.id,
        quadMatLegacy.id,
        boxCollider(),
        dynamicBody(),
      );

      // Bodies first, then the joints — the natives defer addJoint
      // ops whose bodies aren't realized yet, but landing the addNode
      // batch first keeps the constraint frame the authored one.
      c.applyCommands(adds);
      var joints = 0;

      c.addJoint(
        SceneJoint.spherical(
          bodyA: pendAnchor,
          bodyB: pendBob,
          localAnchorB: Vector3(0, 0.55, 0),
        ),
      );
      joints++;

      c.addJoint(
        SceneJoint.revolute(
          bodyA: doorFrame,
          bodyB: doorPanel,
          localAxisA: Vector3(0, 1, 0),
          localAxisB: Vector3(0, 1, 0),
          localAnchorA: Vector3(0.2, 0, 0),
          localAnchorB: Vector3(-0.2, 0, 0),
          lowerLimit: -1.745,
          upperLimit: 1.745,
        ),
      );
      joints++;

      c.addJoint(
        SceneJoint.prismatic(
          bodyA: liftRail,
          bodyB: liftPlate,
          localAxisA: Vector3(0, 1, 0),
          localAxisB: Vector3(0, 1, 0),
          localAnchorB: Vector3(0, 0.5, 0),
          lowerLimit: -0.3,
          upperLimit: 0.6,
          motorTargetVelocity: 0.5,
          motorMaxForce: 60,
        ),
      );
      joints++;

      c.addJoint(
        SceneJoint.fixed(
          bodyA: weldA,
          bodyB: weldB,
          localAnchorA: Vector3(0, 0.2, 0),
          localAnchorB: Vector3(0, -0.2, 0),
        ),
      );
      joints++;

      var upper = chainAnchor;
      for (final link in chainLinks) {
        c.addJoint(
          SceneJoint.spherical(
            bodyA: upper,
            bodyB: link,
            localAnchorA: Vector3(0, -0.15, 0),
            localAnchorB: Vector3(0, 0.15, 0),
          ),
        );
        upper = link;
        joints++;
      }

      c.addJoint(
        SceneJoint.generic(
          bodyA: genAnchor,
          bodyB: genBox,
          localAnchorA: Vector3(0, -0.2, 0),
          localAnchorB: Vector3(0, 0.2, 0),
          axes: const [
            SceneJointAxisConfig.locked(),
            SceneJointAxisConfig.locked(),
            SceneJointAxisConfig.locked(),
            SceneJointAxisConfig.locked(),
            SceneJointAxisConfig.locked(),
            SceneJointAxisConfig.limited(-0.9, 0.9),
          ],
        ),
      );
      joints++;

      c.addJoint(
        SceneJoint.spherical(
          bodyA: breakAnchor,
          bodyB: breakBox,
          localAnchorA: Vector3(0, -0.2, 0),
          localAnchorB: Vector3(0, 0.2, 0),
          breakDistance: 0.15,
        ),
      );
      joints++;

      // The scripted kick has to outrun the solver: a hard ball-socket
      // constraint only separates by residual under load, so this is a
      // violent yank (~67 m/s on the 0.3 kg box) against a 0.15
      // breakDistance — enough single-step violation on both engines.
      c.applyImpulse(breakBox, Vector3(20.0, 5.0, 0));
      return joints;
    }

    // ── W11 skins + skeletal animation + morph targets ────────────
    // Fired by the app's +14 s timer (after the W9 rig). Everything
    // the lane needs mints on the live post-diff document and ships
    // through `command` ops in the diff's canonical order — chunks,
    // then the geometry resources, then the nodes (so the skin's
    // joints and the channels' targets exist), then the skin and the
    // two animations, then the playback writes. [report] feeds the
    // status line's `anims: N playing` — 1 when `wave` starts, 2
    // when `pulse` joins at +16 s.
    void addW11Phase(void Function(int playing) report) {
      final c = controller;
      if (c == null) return;
      final live = phaseTwoDoc ?? doc;
      final ops = <Map<String, Object?>>[];

      // Registers a chunk on `live` and queues its upsertPayload op.
      PayloadSpec chunk(
        PayloadEncoding encoding,
        Uint8List bytes, {
        String? layout,
        String? format,
      }) {
        final p = live.addPayload(
          PayloadSpec(
            live.newId(),
            encoding: encoding,
            layout: layout,
            format: format,
            length: bytes.lengthInBytes,
            bytes: bytes,
          ),
        );
        ops.add({
          'op': 'upsertPayload',
          'id': 'chunk:${p.id.toToken()}',
          'bytes': base64Encode(bytes),
          'encoding': p.encoding.name,
          if (p.layout != null) 'layout': p.layout,
          if (p.format != null) 'format': p.format,
          if (p.width != null) 'width': p.width,
          if (p.height != null) 'height': p.height,
          if (p.length != null) 'length': p.length,
        });
        return p;
      }

      // A node's addNode op — the W9 rig's shape; `spec.children`
      // stays inert on the wire, so children attach via `parent`.
      void addNodeOp(NodeSpec node, LocalId? parent) {
        ops.add({
          'op': 'addNode',
          'node': node.id.toToken(),
          'parent': parent?.toToken(),
          'spec': encodeNodeCommandSpec(node, live),
        });
      }

      // ── Chunks ────────────────────────────────────────────────
      // The flag's skinned vertex/index pair, its two-joint IBM slab
      // (j0 binds at the flag's origin → identity; j1 is its +0.6 X
      // child → translate(-0.6,0,0), both against the skinned mesh's
      // own transform at the same anchor), the blob's verts/indices/
      // morph deltas, and the two animations' timelines + keyframes.
      final flag = _flagStrip();
      final flagVerts = chunk(
        PayloadEncoding.vertexBuffer,
        flag.vertices,
        layout: 'skinned_uv1_tangent',
      );
      final flagIndices = chunk(
        PayloadEncoding.indexBuffer,
        flag.indices,
        format: 'uint16',
      );
      final ibm = chunk(
        PayloadEncoding.matrices,
        _f32([
          ...Matrix4.identity().storage,
          ...Matrix4.translation(Vector3(-0.6, 0, 0)).storage,
        ]),
      );
      final blob = _morphCube();
      final blobVerts = chunk(
        PayloadEncoding.vertexBuffer,
        blob.vertices,
        layout: 'unskinned_uv1_tangent',
      );
      final blobIndices = chunk(
        PayloadEncoding.indexBuffer,
        blob.indices,
        format: 'uint16',
      );
      final blobDeltas = chunk(PayloadEncoding.floats, blob.deltas);
      // The wave's channels share one 2 s timeline; j0 sways ±0.35
      // rad about Z while j1 answers ±0.55 rad in counterphase, so
      // the flag ripples root → tip.
      final waveTimes = chunk(
        PayloadEncoding.floats,
        _f32(const [0, 0.5, 1.0, 1.5, 2.0]),
      );
      const j1Angles = [0.0, -0.55, 0.0, 0.55, 0.0];
      final waveJ0 = chunk(
        PayloadEncoding.floats,
        _f32([
          for (final a in const [0.0, 0.35, 0.0, -0.35, 0.0]) ..._quatZ(a),
        ]),
      );
      final waveJ1 = chunk(
        PayloadEncoding.floats,
        _f32([for (final a in j1Angles) ..._quatZ(a)]),
      );
      final pulseTimes = chunk(PayloadEncoding.floats, _f32(const [0, 1, 2]));
      // The flattened glTF weights shape — one weight per target per
      // keyframe: [0,0] → [1,0] (puff) → [0,1] (squash).
      final pulseKeys = chunk(
        PayloadEncoding.floats,
        _f32(const [0, 0, 1, 0, 0, 1]),
      );

      // ── Resources ─────────────────────────────────────────────
      // Geometry refs inside a resource encode are always chunk ids,
      // so the `chunk:` prefix is the right idKey here.
      final flagGeo = live.addResource(
        GeometryResource(
          live.newId(),
          vertices: flagVerts.id,
          indices: flagIndices.id,
          bounds: flag.bounds,
        ),
      );
      final blobGeo = live.addResource(
        GeometryResource(
          live.newId(),
          vertices: blobVerts.id,
          indices: blobIndices.id,
          bounds: blob.bounds,
          morphTargets: MorphTargetsSpec(
            deltas: blobDeltas.id,
            targetCount: 2,
            targetNames: const ['puff', 'squash'],
            defaultWeights: const [0, 0],
          ),
        ),
      );
      for (final res in [flagGeo, blobGeo]) {
        ops.add({
          'op': 'upsertResource',
          'id': 'geo:${res.id.toToken()}',
          'resource': encodeResource(res, (id) => 'chunk:${id.toToken()}'),
        });
      }

      // ── Nodes ─────────────────────────────────────────────────
      // The joint chain roots at the flag's anchor — mid-depth back
      // of the slab, above the ball/trigger column — with j1 its
      // +0.6 X child. The skinned mesh is a sibling root at the same
      // anchor whose `skin` member binds the skin; the morph blob
      // floats left of it.
      final j0 = live.createNode(
        name: 'w11.j0',
        transform: TrsTransform(translation: Vector3(0.9, 1.3, 2.2)),
        root: true,
      );
      final j1 = live.createNode(
        name: 'w11.j1',
        transform: TrsTransform(translation: Vector3(0.6, 0, 0)),
      );
      j0.children.add(j1.id);
      final skin = live.addSkin(
        SkinSpec(
          live.newId(),
          joints: [j0.id, j1.id],
          inverseBindMatrices: ibm.id,
          skeleton: j0.id,
        ),
      );
      final flagNode = live.createNode(
        name: 'w11.flag',
        transform: TrsTransform(translation: Vector3(0.9, 1.3, 2.2)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(flagGeo.id),
              'material': ResourceRefValue(doubleSidedMat.id),
            },
          ),
        ],
        root: true,
      );
      flagNode.skin = skin.id;
      final blobNode = live.createNode(
        name: 'w11.blob',
        transform: TrsTransform(translation: Vector3(-1.8, 1.0, 2.4)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(blobGeo.id),
              'material': ResourceRefValue(triggerMat.id),
            },
          ),
        ],
        root: true,
      );
      addNodeOp(j0, null);
      addNodeOp(j1, j0.id);
      // The flag's addNode spec carries `"skin":"skin:<id>"` directly
      // — the primary manifest shape; the updateNode below exercises
      // the `skin` flag's re-decode path on top of it.
      addNodeOp(flagNode, null);
      addNodeOp(blobNode, null);

      // ── Skin + animations ─────────────────────────────────────
      ops.add({
        'op': 'updateNode',
        'node': flagNode.id.toToken(),
        'flags': ['skin'],
        'spec': encodeNodeCommandSpec(flagNode, live),
      });
      ops.add({
        'op': 'upsertSkin',
        'id': 'skin:${skin.id.toToken()}',
        'skin': encodeSkinSpec(skin, live),
      });
      final wave = live.addAnimation(
        AnimationSpec(
          live.newId(),
          name: 'wave',
          channels: [
            AnimationChannelSpec(
              target: j0.id,
              targetName: j0.name,
              property: AnimationProperty.rotation,
              timeline: waveTimes.id,
              keyframes: waveJ0.id,
            ),
            AnimationChannelSpec(
              target: j1.id,
              targetName: j1.name,
              property: AnimationProperty.rotation,
              timeline: waveTimes.id,
              keyframes: waveJ1.id,
            ),
          ],
        ),
      );
      final pulse = live.addAnimation(
        AnimationSpec(
          live.newId(),
          name: 'pulse',
          channels: [
            AnimationChannelSpec(
              target: blobNode.id,
              targetName: blobNode.name,
              property: AnimationProperty.weights,
              timeline: pulseTimes.id,
              keyframes: pulseKeys.id,
            ),
          ],
        ),
      );
      for (final anim in [wave, pulse]) {
        ops.add({
          'op': 'upsertAnimation',
          'id': 'anim:${anim.id.toToken()}',
          'animation': encodeAnimationSpec(anim, live),
        });
      }

      c.applyCommands(ops);

      // wave loops from +14 s; pulse joins at +16 s; at +18 s the
      // seek pins wave to a known mid-swing pose and a direct
      // setMorphWeights write overrides the blob's weights.
      c.playAnimation(wave.id, loop: true);
      report(1);
      final clock = Stopwatch()..start();
      var seekBase = 0.0;
      var seekMark = 0.0;
      Timer(const Duration(seconds: 2), () {
        c.playAnimation(pulse.id);
        report(2);
      });
      Timer(const Duration(seconds: 4), () {
        c.seekAnimation(wave.id, 0.75);
        c.setMorphWeights(blobNode.id, const [0.6, 0.4]);
        seekBase = 0.75;
        seekMark = clock.elapsedMilliseconds / 1000.0;
      });

      // Reference trace: the authored j1 curve sampled at the clip's
      // wall-clock playhead — the rotation the native sampler should
      // be writing. The wave's channels rotate only about Z, so an
      // angle lerp is the exact slerp path between keys.
      const times = [0.0, 0.5, 1.0, 1.5, 2.0];
      var ticks = 0;
      Timer.periodic(const Duration(milliseconds: 600), (timer) {
        final t =
            (seekBase + clock.elapsedMilliseconds / 1000.0 - seekMark) % 2.0;
        var i = 0;
        while (i + 1 < times.length && times[i + 1] <= t) {
          i++;
        }
        var angle = j1Angles[i];
        if (i + 1 < times.length) {
          final f = (t - times[i]) / (times[i + 1] - times[i]);
          angle += (j1Angles[i + 1] - angle) * f;
        }
        final q = Quaternion.axisAngle(Vector3(0, 0, 1), angle);
        // The authored sample AND the native-applied pose — the
        // `pose` query reads the live joint transform, proving the
        // sampler actually drives it rather than the curve merely
        // ticking on the Dart side.
        c.poseOf(j1.id).then((pose) {
          final live = pose == null
              ? 'null'
              : '(${pose.rotation.x.toStringAsFixed(2)},'
                    '${pose.rotation.y.toStringAsFixed(2)},'
                    '${pose.rotation.z.toStringAsFixed(2)},'
                    '${pose.rotation.w.toStringAsFixed(2)})';
          dnLog(
            'dart3d: w11 j1 rot=(${q.x.toStringAsFixed(2)},'
            '${q.y.toStringAsFixed(2)},${q.z.toStringAsFixed(2)},'
            '${q.w.toStringAsFixed(2)}) t=${t.toStringAsFixed(2)}'
            ' live=$live',
          );
        });
        if (++ticks >= 12) timer.cancel();
      });
    }

    // W12 phase (+22 s): the component-parity lanes — document-declared
    // joint components (one node↔node, one world-anchored), a
    // materialsVariants selection cycle, a rectAreaLight that also
    // carries the corrected `enabled:false` mark (upstream gates
    // component ticks only — the light still lights), and a `w12`
    // pose probe two seconds in for the joint evidence.
    void addW12Phase() {
      final c = controller;
      if (c == null) return;
      final live = phaseTwoDoc ?? doc;
      final ops = <Map<String, Object?>>[];

      void addNodeOp(NodeSpec node, LocalId? parent) {
        ops.add({
          'op': 'addNode',
          'node': node.id.toToken(),
          'parent': parent?.toToken(),
          'spec': encodeNodeCommandSpec(node, live),
        });
      }

      // ── Resources ─────────────────────────────────────────────
      final w12Geo = live.addResource(
        GeometryResource(
          live.newId(),
          procedural: CuboidGeometrySpec(extents: Vector3.all(0.3)),
        ),
      );
      final variantGeo = live.addResource(
        GeometryResource(
          live.newId(),
          procedural: CuboidGeometrySpec(extents: Vector3.all(0.4)),
        ),
      );
      final steelMat = live.addResource(
        MaterialResource(
          live.newId(),
          type: 'physicallyBased',
          properties: {
            'baseColor': ColorValue(0.55, 0.58, 0.62, 1.0),
            'metallic': DoubleValue(0.7),
            'roughness': DoubleValue(0.35),
          },
        ),
      );
      final defaultMat = live.addResource(
        MaterialResource(
          live.newId(),
          type: 'physicallyBased',
          properties: {
            'baseColor': ColorValue(0.9, 0.55, 0.15, 1.0),
            'metallic': DoubleValue(0.05),
            'roughness': DoubleValue(0.6),
          },
        ),
      );
      final coolMat = live.addResource(
        MaterialResource(
          live.newId(),
          type: 'physicallyBased',
          properties: {
            'baseColor': ColorValue(0.1, 0.65, 0.85, 1.0),
            'metallic': DoubleValue(0.05),
            'roughness': DoubleValue(0.5),
          },
        ),
      );
      final warmMat = live.addResource(
        MaterialResource(
          live.newId(),
          type: 'physicallyBased',
          properties: {
            'baseColor': ColorValue(0.85, 0.1, 0.55, 1.0),
            'metallic': DoubleValue(0.05),
            'roughness': DoubleValue(0.5),
          },
        ),
      );
      for (final res in [
        w12Geo,
        variantGeo,
        steelMat,
        defaultMat,
        coolMat,
        warmMat,
      ]) {
        ops.add({
          'op': 'upsertResource',
          'id': 'res:${res.id.toToken()}',
          'resource': encodeResource(res, (id) => 'chunk:${id.toToken()}'),
        });
      }

      // ── Joint-component nodes ─────────────────────────────────
      // `w12.anchor`: a dynamic box whose sphericalJoint omits
      // `otherNode` — upstream anchors to the world at `localAnchorB`,
      // so it hangs at its spawn point while the `w12.free` twin
      // drops to the slab.
      final anchorPos = Vector3(2.9, 1.6, 0.2);
      final anchor = live.createNode(
        name: 'w12.anchor',
        transform: TrsTransform(translation: anchorPos.clone()),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(w12Geo.id),
              'material': ResourceRefValue(steelMat.id),
            },
          ),
          colliderComponent(shape: 'box', extents: Vector3.all(0.3)),
          rigidBodyComponent(type: 'dynamic'),
          ComponentSpec(
            'sphericalJoint',
            properties: {
              'localAnchorA': Vec3Value(Vector3.zero()),
              'localAnchorB': Vec3Value(anchorPos.clone()),
            },
          ),
        ],
        root: true,
      );
      final free = live.createNode(
        name: 'w12.free',
        transform: TrsTransform(translation: Vector3(3.5, 1.6, 0.2)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(w12Geo.id),
              'material': ResourceRefValue(steelMat.id),
            },
          ),
          colliderComponent(shape: 'box', extents: Vector3.all(0.3)),
          rigidBodyComponent(type: 'dynamic'),
        ],
        root: true,
      );
      // `w12.linkA`/`linkB`: a component-declared fixedJoint gluing
      // the pair — they fall as one body. The anchors sit at the
      // facing surfaces (A's +X face, B's −X face) so the joint holds
      // the centres 0.6 apart; coincident centre anchors would force
      // the two boxes into the same pose — a degenerate constraint
      // whose solver jitter walks the pair across the slab on iOS.
      // linkB first so linkA's `otherNode` ref is real at construction.
      final linkB = live.createNode(
        name: 'w12.linkB',
        transform: TrsTransform(translation: Vector3(-2.4, 1.6, 0.2)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(w12Geo.id),
              'material': ResourceRefValue(steelMat.id),
            },
          ),
          colliderComponent(shape: 'box', extents: Vector3.all(0.3)),
          rigidBodyComponent(type: 'dynamic'),
        ],
        root: true,
      );
      final linkA = live.createNode(
        name: 'w12.linkA',
        transform: TrsTransform(translation: Vector3(-3.0, 1.6, 0.2)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(w12Geo.id),
              'material': ResourceRefValue(steelMat.id),
            },
          ),
          colliderComponent(shape: 'box', extents: Vector3.all(0.3)),
          rigidBodyComponent(type: 'dynamic'),
          ComponentSpec(
            'fixedJoint',
            properties: {
              'otherNode': NodeRefValue(linkB.id),
              'localAnchorA': Vec3Value(Vector3(0.3, 0, 0)),
              'localAnchorB': Vec3Value(Vector3(-0.3, 0, 0)),
            },
          ),
        ],
        root: true,
      );
      for (final n in [anchor, free, linkB, linkA]) {
        addNodeOp(n, null);
      }

      // ── materialsVariants ─────────────────────────────────────
      // Showcase cube floating off the slab's camera-side edge —
      // world −z faces the orbit camera (native +z), so (−4.0) puts
      // it 2.5 u in front of the eye where nothing occludes it.
      // Declared default (orange), variants cool (cyan) / warm
      // (magenta) mapped on primitive 0. The phase starts with 'cool'
      // selected; +2 s selects 'warm', +4 s selects null — each must
      // visibly rewrite the slot.
      final variantNode = live.createNode(
        name: 'w12.variant',
        transform: TrsTransform(translation: Vector3(0.0, 0.9, -4.0)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(variantGeo.id),
              'material': ResourceRefValue(defaultMat.id),
            },
          ),
        ],
        root: true,
      );
      // The binding's `node` self-ref needs the created id.
      variantNode.components.add(
        ComponentSpec(
          'materialsVariants',
          properties: {
            'variants': ListValue([StringValue('cool'), StringValue('warm')]),
            'selected': StringValue('cool'),
            'bindings': ListValue([
              MapValue({
                'node': NodeRefValue(variantNode.id),
                'primitive': IntValue(0),
                'default': ResourceRefValue(defaultMat.id),
                'materials': MapValue({
                  '0': ResourceRefValue(coolMat.id),
                  '1': ResourceRefValue(warmMat.id),
                }),
              }),
            ]),
          },
        ),
      );
      addNodeOp(variantNode, null);

      // ── rectAreaLight + enabled ────────────────────────────────
      // A warm rect panel overhead, rotated −90° about X so its
      // emission axis (−Z local) faces down. `enabled:false` exercises
      // the corrected universal property: it still lights (upstream
      // gates component ticks only) — the native logOnce records it.
      final area = live.createNode(
        name: 'w12.area',
        transform: TrsTransform(
          translation: Vector3(0, 2.2, 1.8),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -1.5708),
        ),
        components: [
          ComponentSpec(
            'rectAreaLight',
            properties: {
              'width': DoubleValue(2.0),
              'height': DoubleValue(1.0),
              'intensity': DoubleValue(240.0),
              'color': ColorValue(1.0, 0.9, 0.75, 1.0),
              'enabled': BoolValue(false),
            },
          ),
        ],
        root: true,
      );
      addNodeOp(area, null);

      c.applyCommands(ops);
      dnLog(
        'dart3d: w12 phase — joint components, variants, '
        'rectAreaLight, enabled:false',
      );

      // +3 s / +11 s: pose evidence — anchor aloft at spawn, free twin
      // grounded, link pair glued ~0.6 apart. The variant cycle runs
      // wide so each state holds for screenshot capture even under
      // event-loop stalls: 'cool' at phase start, 'warm' at +5 s,
      // null (declared default) at +9 s.
      String fmt(Vector3? p) => p == null
          ? 'null'
          : '(${p.x.toStringAsFixed(2)},${p.y.toStringAsFixed(2)},'
                '${p.z.toStringAsFixed(2)})';
      Future<void> logPoses(String tag) async {
        final a = await c.poseOf(anchor.id);
        final f = await c.poseOf(free.id);
        final la = await c.poseOf(linkA.id);
        final lb = await c.poseOf(linkB.id);
        dnLog(
          'dart3d: w12 poses[$tag] anchor=${fmt(a?.position)} '
          'free=${fmt(f?.position)} '
          'linkA=${fmt(la?.position)} linkB=${fmt(lb?.position)}',
        );
      }

      Timer(const Duration(seconds: 3), () => logPoses('3s'));
      Timer(const Duration(seconds: 5), () {
        c.selectMaterialVariant(variantNode.id, 'warm');
      });
      Timer(const Duration(seconds: 9), () {
        c.selectMaterialVariant(variantNode.id, null);
      });
      Timer(const Duration(seconds: 11), () => logPoses('11s'));
    }

    // W13 phase (+34 s): the environment-effects toggle lanes. Every
    // step rewrites the env resource's `effects` spec — the wire block
    // is absolute, the whole spec replaces rather than merges — and
    // re-ships the `upsertResource` + `updateStage` pair `diffCommands`
    // emits for a stage-affecting resource change, so natives re-run
    // decodeStage against the fresh block. Each state holds ~2 s for
    // capture: bloom → +ambientOcclusion → +fog → +depthOfField (the
    // combined stack the wave must capture), a hard swap to vignette +
    // chromaticAberration + colorGrading, filmGrain + autoExposure, an
    // all-defaults reset, then the same resource with
    // `overridesEffects:false` — the `effects` key leaves the wire and
    // natives must retain the prior (all-default) state.
    void addW13Phase() {
      final c = controller;
      if (c == null) return;
      final live = phaseTwoDoc ?? doc;

      // The env lane: env==0 leaves `stage.environmentRef` null, so
      // mint a studio EnvironmentResource for the toggles and attach
      // it; the other lanes mutate the resource the document (or its
      // phase-two copy) already carries.
      final ref = live.stage.environmentRef;
      final existing = ref == null ? null : live.resources[ref];
      final envRes = existing is EnvironmentResource
          ? existing
          : live.addResource(
              EnvironmentResource(
                live.newId(),
                environment: const StudioEnvironment(),
                effects: EnvironmentEffectsSpec(),
              ),
            );
      live.stage.environmentRef = envRes.id;

      // Manifest id keys: `env:` for the resource the stage names,
      // `chunk:` for the payload an env-3 equirect carries — the same
      // prefixes writeFscene emits (natives strip them when parsing).
      String idKey(LocalId id) =>
          '${live.resources[id] is EnvironmentResource ? 'env' : 'chunk'}'
          ':${id.toToken()}';

      void push() {
        c.applyCommands([
          {
            'op': 'upsertResource',
            'id': 'env:${envRes.id.toToken()}',
            'resource': encodeResource(envRes, idKey),
          },
          {'op': 'updateStage', 'stage': encodeStage(live.stage, idKey)},
        ]);
      }

      void setEffects(EnvironmentEffectsSpec effects, String tag) {
        envRes.effects = effects;
        envRes.overridesEffects = true;
        push();
        dnLog('dart3d: w13 $tag');
      }

      // t+0: bloom alone — modest intensity/threshold over the
      // 0.15/1.0 defaults so the wire block carries real params.
      setEffects(
        EnvironmentEffectsSpec(
          bloomEnabled: true,
          bloomIntensity: 0.4,
          bloomThreshold: 0.8,
        ),
        'bloom on',
      );
      // +2 s: ambient occlusion joins — bloom stays on.
      Timer(const Duration(seconds: 2), () {
        setEffects(
          EnvironmentEffectsSpec(
            bloomEnabled: true,
            bloomIntensity: 0.4,
            bloomThreshold: 0.8,
            ambientOcclusionEnabled: true,
          ),
          'bloom+ao on',
        );
      });
      // +4 s: exponential fog joins — a mid-gray-blue at density 0.05.
      Timer(const Duration(seconds: 4), () {
        setEffects(
          EnvironmentEffectsSpec(
            bloomEnabled: true,
            bloomIntensity: 0.4,
            bloomThreshold: 0.8,
            ambientOcclusionEnabled: true,
            fogEnabled: true,
            fogColor: Vector3(0.45, 0.55, 0.68),
            fogDensity: 0.05,
          ),
          'bloom+ao+fog on',
        );
      });
      // +6 s: depth of field completes the combined
      // bloom+AO+fog+DoF stack the wave captures.
      Timer(const Duration(seconds: 6), () {
        setEffects(
          EnvironmentEffectsSpec(
            bloomEnabled: true,
            bloomIntensity: 0.4,
            bloomThreshold: 0.8,
            ambientOcclusionEnabled: true,
            fogEnabled: true,
            fogColor: Vector3(0.45, 0.55, 0.68),
            fogDensity: 0.05,
            depthOfFieldEnabled: true,
            depthOfFieldFocusDistance: 3.0,
            depthOfFieldFStop: 2.0,
          ),
          'bloom+ao+fog+dof stack',
        );
      });
      // +8 s: a hard swap to vignette + chromatic aberration + color
      // grading INSTEAD — absolute semantics mean the fresh spec drops
      // every other family back to its default-off.
      Timer(const Duration(seconds: 8), () {
        setEffects(
          EnvironmentEffectsSpec(
            vignetteEnabled: true,
            vignetteIntensity: 0.6,
            chromaticAberrationEnabled: true,
            chromaticAberrationIntensity: 0.4,
            colorGradingEnabled: true,
            saturation: 1.6,
            temperature: 0.3,
          ),
          'swap vignette+ca+colorGrading',
        );
      });
      // +10 s: film grain + auto-exposure.
      Timer(const Duration(seconds: 10), () {
        setEffects(
          EnvironmentEffectsSpec(
            filmGrainEnabled: true,
            filmGrainIntensity: 0.5,
            autoExposureEnabled: true,
          ),
          'filmGrain+autoExposure on',
        );
      });
      // +12 s: an all-defaults spec — every family off on the wire.
      Timer(const Duration(seconds: 12), () {
        setEffects(EnvironmentEffectsSpec(), 'effects reset');
      });
      // +14 s: `overridesEffects:false` — the same resource minus the
      // `effects` key; the absent-key lane proves natives retain the
      // prior (all-default) state.
      Timer(const Duration(seconds: 14), () {
        envRes.overridesEffects = false;
        push();
        dnLog('dart3d: w13 overridesEffects:false — effects key omitted');
      });
    }

    // W14 phase (+50 s): render textures + views. The producer→consumer
    // lane — a second camera renders the dice area into a render
    // texture a foreground cube samples as `baseColorTexture`, then a
    // `manual` target refreshes through the `render` op, the view
    // list grows to two producers on one target and shrinks back, and
    // the stage's AA/renderScale toggle through `updateStage`. Every
    // step mints on `live` and ships `command` ops — `updateViews`
    // rides [SceneController.updateViews], which resolves the doc's
    // manifest id keys (`n:`/`rt:`/…) itself; the `upsertResource`
    // encodes call [manifestIdKey] fresh each step so late-minted ids
    // still prefix correctly.
    void addW14Phase() {
      final c = controller;
      if (c == null) return;
      final live = phaseTwoDoc ?? doc;

      // A node's addNode op — the W11/W12 shape.
      Map<String, Object?> addNodeOp(NodeSpec node, LocalId? parent) => {
        'op': 'addNode',
        'node': node.id.toToken(),
        'parent': parent?.toToken(),
        'spec': encodeNodeCommandSpec(node, live),
      };

      // The camera component — same projection/fov/near/far shape the
      // document's `camera` node carries.
      ComponentSpec rtCamera() => ComponentSpec(
        'camera',
        properties: {
          'projection': StringValue('perspective'),
          'fovRadiansY': DoubleValue(1.0),
          'near': DoubleValue(0.05),
          'far': DoubleValue(100),
        },
      );

      // Wholesale-replaces the view list: `live.views` tracks what the
      // op ships so the tracked document stays truthful.
      void setViews(List<RenderViewSpec> views, String tag) {
        live.views
          ..clear()
          ..addAll(views);
        c.updateViews(views);
        dnLog('dart3d: w14 $tag');
      }

      // ── t+0: the everyFrame RT, its camera, the consuming cube ──
      // rtCam sits on the main camera's side of the arena pitched
      // down ~33° toward the dice area; the cube floats off the
      // slab's camera-side edge beside W12's variant showcase.
      final rt = live.addResource(
        RenderTextureResource(
          live.newId(),
          width: 256,
          height: 256,
          update: 'everyFrame',
        ),
      );
      final rtGeo = live.addResource(
        GeometryResource(
          live.newId(),
          procedural: CuboidGeometrySpec(extents: Vector3.all(0.5)),
        ),
      );
      final rtMat = live.addResource(
        MaterialResource(
          live.newId(),
          type: 'physicallyBased',
          properties: {
            'baseColor': ColorValue(1, 1, 1, 1),
            // The `{'rref':'rt:<tok>'}` path — a material sampling a
            // render target instead of an image texture.
            'baseColorTexture': ResourceRefValue(rt.id),
            'roughness': DoubleValue(0.6),
          },
        ),
      );
      final rtCam = live.createNode(
        name: 'w14.rtCam',
        transform: TrsTransform(
          // Identity rotation — level at -Z toward the texture row.
          translation: Vector3(0, 1.4, -4.0),
        ),
        components: [rtCamera()],
        root: true,
      );
      final rtCube = live.createNode(
        name: 'w14.rtCube',
        transform: TrsTransform(translation: Vector3(-2.2, 1.0, -4.2)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(rtGeo.id),
              'material': ResourceRefValue(rtMat.id),
            },
          ),
        ],
        root: true,
      );
      // Minted in the timers below — the later steps reference them.
      late final LocalId rt2Id;
      late final LocalId rtCam2Id;

      final idKey = manifestIdKey(live);
      c.applyCommands([
        {
          'op': 'upsertResource',
          'id': 'rt:${rt.id.toToken()}',
          'resource': encodeResource(rt, idKey),
        },
        {
          'op': 'upsertResource',
          'id': 'geo:${rtGeo.id.toToken()}',
          'resource': encodeResource(rtGeo, idKey),
        },
        {
          'op': 'upsertResource',
          'id': 'mat:${rtMat.id.toToken()}',
          'resource': encodeResource(rtMat, idKey),
        },
        addNodeOp(rtCam, null),
        addNodeOp(rtCube, null),
      ]);
      setViews([
        RenderViewSpec(cameraNode: rtCam.id, target: rt.id),
      ], 'rt live');

      // +2 s: a `manual` RT plus a second view onto it — the cube's
      // material resamples the new target, then `render` forces the
      // pass (a manual target draws only when the op asks).
      Timer(const Duration(seconds: 2), () {
        final rt2 = live.addResource(
          RenderTextureResource(
            live.newId(),
            width: 256,
            height: 256,
            update: 'manual',
          ),
        );
        rt2Id = rt2.id;
        final rtCam2 = live.createNode(
          name: 'w14.rtCam2',
          transform: TrsTransform(
            translation: Vector3(-3.0, 1.5, -3.0),
            // Front-left angle on the dice area — yaw ~45° then a
            // slight downtilt.
            rotation:
                Quaternion.axisAngle(Vector3(0, 1, 0), pi / 4) *
                Quaternion.axisAngle(Vector3(1, 0, 0), 0.35),
          ),
          components: [rtCamera()],
          root: true,
        );
        rtCam2Id = rtCam2.id;
        rtMat.properties['baseColorTexture'] = ResourceRefValue(rt2.id);
        final idKey = manifestIdKey(live);
        c.applyCommands([
          {
            'op': 'upsertResource',
            'id': 'rt:${rt2.id.toToken()}',
            'resource': encodeResource(rt2, idKey),
          },
          addNodeOp(rtCam2, null),
          {
            'op': 'upsertResource',
            'id': 'mat:${rtMat.id.toToken()}',
            'resource': encodeResource(rtMat, idKey),
          },
        ]);
        setViews([
          RenderViewSpec(cameraNode: rtCam.id, target: rt.id),
          RenderViewSpec(cameraNode: rtCam2.id, target: rt2.id),
        ], 'manual view added');
        c.renderTexture(rt2.id);
        dnLog('dart3d: w14 manual render');
      });

      // +4 s: a third camera adds a second producer onto the FIRST
      // target at `order:1` — two views drawing into one RT exercise
      // the produce-consume ordering between them.
      Timer(const Duration(seconds: 4), () {
        final rtCam3 = live.createNode(
          name: 'w14.rtCam3',
          transform: TrsTransform(
            translation: Vector3(0, 5.0, 1.0),
            // Near-top-down over the slab.
            rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 1.35),
          ),
          components: [rtCamera()],
          root: true,
        );
        c.applyCommands([addNodeOp(rtCam3, null)]);
        setViews([
          RenderViewSpec(cameraNode: rtCam.id, target: rt.id),
          RenderViewSpec(cameraNode: rtCam2Id, target: rt2Id),
          RenderViewSpec(cameraNode: rtCam3.id, target: rt.id, order: 1),
        ], 'second rt producer');
      });

      // +6 s: back to the single rt view — rt2 holds its last manual
      // frame while the cube keeps sampling it.
      Timer(const Duration(seconds: 6), () {
        setViews([
          RenderViewSpec(cameraNode: rtCam.id, target: rt.id),
        ], 'views reduced');
      });

      // +8 s: stage quality lane — per-stage AA + render scale land
      // through `updateStage` (the view entries' inherit-when-absent
      // knobs read these).
      Timer(const Duration(seconds: 8), () {
        live.stage.antiAliasingMode = 'msaa';
        live.stage.renderScale = 0.75;
        c.applyCommands([
          {
            'op': 'updateStage',
            'stage': encodeStage(live.stage, manifestIdKey(live)),
          },
        ]);
        dnLog('dart3d: w14 stage quality');
      });

      // +10 s: restore the stage defaults.
      Timer(const Duration(seconds: 10), () {
        live.stage.antiAliasingMode = 'auto';
        live.stage.renderScale = 1.0;
        c.applyCommands([
          {
            'op': 'updateStage',
            'stage': encodeStage(live.stage, manifestIdKey(live)),
          },
        ]);
        dnLog('dart3d: w14 stage reset');
      });

      // +12 s: showcase — the consuming cube comes front-center at
      // 2.2× scale and resamples the everyFrame rt, so its face shows
      // rtCam's live view of the dice area (a Roll visibly moves it).
      Timer(const Duration(seconds: 12), () {
        rtCube.transform = TrsTransform(
          translation: Vector3(0.0, 1.35, -0.6),
          scale: Vector3.all(2.2),
        );
        rtMat.properties['baseColorTexture'] = ResourceRefValue(rt.id);
        c.applyCommands([
          {
            'op': 'updateNode',
            'node': rtCube.id.toToken(),
            'flags': ['transform'],
            'spec': encodeNodeCommandSpec(rtCube, live),
          },
          {
            'op': 'upsertResource',
            'id': 'mat:${rtMat.id.toToken()}',
            'resource': encodeResource(rtMat, manifestIdKey(live)),
          },
        ]);
        dnLog('dart3d: w14 showcase');
      });
    }

    // Loose-ends phase (+78 s): the live evidence the earlier lanes
    // left to luck, made deterministic. Fired after W14's last inner
    // timer (+50 s + 12 s showcase) with slack for the pose reads
    // below. Self-contained — every probe body mints here on `live`,
    // so the lane doesn't depend on where earlier phases left the
    // scene. Judged by `poseOf` reads and the `settled` event — no
    // new wire ops.
    void addWLoosePhase() {
      final c = controller;
      if (c == null) return;
      final live = phaseTwoDoc ?? doc;

      // A node's addNode op — the W11/W12/W14 shape.
      Map<String, Object?> addNodeOp(NodeSpec node) => {
        'op': 'addNode',
        'node': node.id.toToken(),
        'parent': null,
        'spec': encodeNodeCommandSpec(node, live),
      };

      // One small sphere + a loud material shared by the three probe
      // bodies — minted on `live` like W12's geos and shipped ahead
      // of the addNode ops that reference them.
      final probeGeo = live.addResource(
        GeometryResource(
          live.newId(),
          procedural: SphereGeometrySpec(radius: 0.15),
        ),
      );
      final probeMat = live.addResource(
        MaterialResource(
          live.newId(),
          type: 'physicallyBased',
          properties: {
            'baseColor': ColorValue(1.0, 0.9, 0.1, 1.0),
            'roughness': DoubleValue(0.5),
          },
        ),
      );
      ComponentSpec probeMesh() => ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(probeGeo.id),
          'material': ResourceRefValue(probeMat.id),
        },
      );
      // Grippy, dead surfaces on every probe — a restitution high
      // enough to bounce a body out of its target volume would make
      // these lanes luck-based again.
      ComponentSpec probeCollider() => colliderComponent(
        shape: 'sphere',
        radius: 0.15,
        friction: 0.7,
        restitution: 0.1,
      );

      // W2 lane 8 — `ccdEnabled` at speed. A 0.05 plate floats over
      // the slab's right edge and the sphere drops through it at
      // 40 m/s: at 60 Hz a discrete step covers ~0.67 m, so without
      // continuous detection the sphere skips the plate entirely.
      // A working CCD parks it on the plate top (y ≈ 0.375); a tunnel
      // lands it on the ground (y ≈ -0.35) or, if it also skips the
      // 0.5 ground slab, on the under-floor catcher (y ≈ -4.35).
      final ccdSlab = live.createNode(
        name: 'wlooseCcdSlab',
        transform: TrsTransform(translation: Vector3(3.3, 0.2, 2.6)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(shelfGeo.id),
              'material': ResourceRefValue(triggerMat.id),
            },
          ),
          colliderComponent(
            shape: 'box',
            extents: Vector3(1.2, 0.05, 1.2),
            friction: 0.7,
            restitution: 0.1,
          ),
          rigidBodyComponent(type: 'fixed'),
        ],
        root: true,
      );
      // Collider-only backstop like the sinker's `catcher` — keeps a
      // fully-tunneled sphere's pose finite and the world settle-able
      // for the roll→rest metric below.
      final ccdCatcher = live.createNode(
        name: 'wlooseCatcher',
        transform: TrsTransform(translation: Vector3(3.3, -5.0, 2.6)),
        components: [
          colliderComponent(shape: 'box', extents: Vector3(3.0, 1.0, 3.0)),
          rigidBodyComponent(type: 'fixed'),
        ],
        root: true,
      );
      final ccdDrop = live.createNode(
        name: 'wlooseCcd',
        transform: TrsTransform(translation: Vector3(3.3, 3.0, 2.6)),
        components: [
          probeMesh(),
          probeCollider(),
          rigidBodyComponent(
            type: 'dynamic',
            mass: 0.2,
            ccdEnabled: true,
            // The `velocity` extension field — the body spawns already
            // falling, no follow-up setVelocity op (the W9 rig launches
            // its swing lanes through the same fields).
            velocity: Vector3(0, -40, 0),
          ),
        ],
        root: true,
      );

      // W6 lane 9 — `concaveMesh` containment, made deterministic. The
      // drop lands inside the bowl's cavity carrying drift toward the
      // +X/+Z walls: a working triangle-mesh collider stops it against
      // the wall (~0.45 off-center on the floor, y ≈ -0.31); a missing
      // one lets it skid out under the wall line and roll away on the
      // ground outside the footprint.
      final bowlDrop = live.createNode(
        name: 'wlooseBowlDrop',
        transform: TrsTransform(translation: Vector3(-2.6, 0.9, 1.6)),
        components: [
          probeMesh(),
          probeCollider(),
          rigidBodyComponent(
            type: 'dynamic',
            mass: 0.2,
            velocity: Vector3(0.9, 0, 0.7),
          ),
        ],
        root: true,
      );

      // W3 lane 9 — `boundsQuad` margin evidence, made deterministic
      // and isolated. The manifest plate sits inside the die's
      // re-throw footprint, so this lane spawns a twin of it — same
      // boundsGeo (±0.4 authored bounds over the ±0.2 quad), same
      // boundingBox collider — in empty space off the slab's +X edge,
      // with a collider-only catcher under it so a miss stays bounded
      // and distinguishable (plate rest y ≈ 0.10, catcher y ≈ -4.35).
      final marginPlate = live.createNode(
        name: 'wlooseMarginPlate',
        transform: TrsTransform(translation: Vector3(5.5, -0.45, 0.5)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(boundsGeo.id),
              'material': ResourceRefValue(boundsMat.id),
            },
          ),
          colliderComponent(shape: 'boundingBox'),
          rigidBodyComponent(type: 'fixed'),
        ],
        root: true,
      );
      final marginCatcher = live.createNode(
        name: 'wlooseMarginCatcher',
        transform: TrsTransform(translation: Vector3(5.5, -5.0, 0.5)),
        components: [
          colliderComponent(shape: 'box', extents: Vector3(2.0, 1.0, 2.0)),
          rigidBodyComponent(type: 'fixed'),
        ],
        root: true,
      );
      final marginDrop = live.createNode(
        name: 'wlooseMarginDrop',
        transform: TrsTransform(translation: Vector3(5.5, 1.0, 0.5)),
        components: [
          probeMesh(),
          probeCollider(),
          rigidBodyComponent(type: 'dynamic', mass: 0.2),
        ],
        root: true,
      );

      c.applyCommands([
        {
          'op': 'upsertResource',
          'id': 'geo:${probeGeo.id.toToken()}',
          'resource': encodeResource(probeGeo, manifestIdKey(live)),
        },
        {
          'op': 'upsertResource',
          'id': 'mat:${probeMat.id.toToken()}',
          'resource': encodeResource(probeMat, manifestIdKey(live)),
        },
        addNodeOp(ccdSlab),
        addNodeOp(ccdCatcher),
        addNodeOp(ccdDrop),
        addNodeOp(bowlDrop),
      ]);
      dnLog(
        'dart3d: wloose probes spawned — '
        'ccd drop, bowl drop; margin drop waits for quiet',
      );

      String v(Vector3 p) =>
          '(${p.x.toStringAsFixed(2)},${p.y.toStringAsFixed(2)},'
          '${p.z.toStringAsFixed(2)})';

      // +3 s: rest-pose reads — every probe has landed by then (the
      // drops settle in ~1.5 s). `poseOf` is the cheapest
      // body-position surface: one `query` op per node. Each read is
      // wrapped like queryBattery's — a detached view or stale id
      // completes the future with an error, not a pose.
      Timer(const Duration(seconds: 3), () async {
        Vector3? ccdPos;
        try {
          ccdPos = (await c.poseOf(ccdDrop.id))?.position;
        } catch (e) {
          dnLog('dart3d: wloose ccd pose:err $e');
        }
        dnLog(
          'dart3d: wloose ccd pose=${ccdPos == null ? 'null' : v(ccdPos)} '
          '${ccdPos != null && ccdPos.y > 0.3 && ccdPos.y < 0.6
              ? 'PASS rests on slab'
              : 'FAIL tunneled'}',
        );

        Vector3? bowlPos;
        try {
          bowlPos = (await c.poseOf(bowlDrop.id))?.position;
        } catch (e) {
          dnLog('dart3d: wloose bowl pose:err $e');
        }
        // Bowl cavity: center (-2.6, 1.6), inner half 0.6, floor at
        // -0.46 — contained reads inside the footprint under the rim.
        final contained = bowlPos != null &&
            (bowlPos.x + 2.6).abs() < 0.5 &&
            (bowlPos.z - 1.6).abs() < 0.5 &&
            bowlPos.y > -0.45 &&
            bowlPos.y < 0.05;
        dnLog(
          'dart3d: wloose bowl '
          'pose=${bowlPos == null ? 'null' : v(bowlPos)} '
          '${contained ? 'PASS contained' : 'FAIL escaped'}',
        );

      });

      // The margin drop waits for the scene to go quiet: the demo's
      // last in-flight roll rests by ~+3 s, and the settle lane's own
      // throws target z=2.5 on the far side of the arena. The lane's
      // plate sits off the slab's +X edge — nothing else collides
      // there. Dropped at +3.5 s, read at +7 s.
      Timer(const Duration(milliseconds: 3500), () {
        c.applyCommands([
          addNodeOp(marginPlate),
          addNodeOp(marginCatcher),
          addNodeOp(marginDrop),
        ]);
        dnLog('dart3d: wloose margin drop spawned');
      });
      // Mid-window poll: +4.4 s catches whether the sphere ever rests
      // on the collider top before the +7 s verdict — discriminates a
      // plate deflection from a post-rest knock.
      Timer(const Duration(milliseconds: 4400), () async {
        try {
          final p = (await c.poseOf(marginDrop.id))?.position;
          dnLog('dart3d: wloose margin mid=${p == null ? 'null' : v(p)}');
        } catch (e) {
          dnLog('dart3d: wloose margin mid:err $e');
        }
      });
      Timer(const Duration(seconds: 7), () async {
        Vector3? marginPos;
        try {
          marginPos = (await c.poseOf(marginDrop.id))?.position;
        } catch (e) {
          dnLog('dart3d: wloose margin pose:err $e');
        }
        // A bounds-respecting rest parks the center at ≈0.10 (collider
        // top -0.05 + r 0.15); a vertex-tight collider would read
        // ≈-0.30, a miss lands on the catcher at ≈-4.35, and no
        // collider falls forever — so anything still aloft is the
        // authored-margin proof.
        final onMargin = marginPos != null &&
            marginPos.y > -0.1 &&
            (marginPos.x - 5.5).abs() < 0.5 &&
            (marginPos.z - 0.5).abs() < 0.5;
        dnLog(
          'dart3d: wloose margin '
          'pose=${marginPos == null ? 'null' : v(marginPos)} '
          '${onMargin ? 'PASS' : 'FAIL'}'
          '${marginPos == null ? '' : ' gap=${(marginPos.y + 0.45).toStringAsFixed(2)} above visual'}',
        );
      });

      // W2 metric — roll→rest wall-clock on the die. `settled` is an
      // all-asleep event, so every perpetual mover must leave first:
      // `w5NoRest` (the W6 `allowsResting:false` body the +8 s diff
      // adds) never sleeps by design, the W9 elevator's velocity motor
      // holds its plate awake against the upper stop, and the hanging
      // j9 chain micro-jitters forever under the constraint solver.
      // The joint lanes finished an hour of scene-time ago, so all
      // four exit here (the joint breaks log as SceneJointBroke).
      // main's _runWLoose also cancels the demo's auto-reroll and
      // rescue watchdog — a foreign throw mid-lane would corrupt the
      // timing. If no `settled` event arrives within 5 s of a throw,
      // the lane falls back to the die's own pose quiescence — the
      // same roll→rest quantity, and whether the event path ever
      // fired is logged at the end either way.
      final clock = Stopwatch()..start();
      var rolls = 0;
      var settledSeen = false;
      int? rollStart;
      StreamSubscription<ScenePhysicsEvent>? sub;
      Timer? fallback;
      void Function()? throwDie;

      void recordSettle(String via, Vector3? diePos) {
        final start = rollStart;
        if (start == null) return;
        rollStart = null;
        fallback?.cancel();
        rolls++;
        dnLog(
          'dart3d: wloose settle: '
          '${clock.elapsedMilliseconds - start}ms '
          '(roll $rolls via $via, die ${diePos == null ? '?' : v(diePos)})',
        );
        if (rolls < 3) {
          Timer(const Duration(milliseconds: 1500),
              () => throwDie?.call());
        } else {
          sub?.cancel();
        }
      }

      throwDie = () {
        rollStart = clock.elapsedMilliseconds;
        // Same op sequence as the app's _roll minus the rng — the
        // metric is latency, not the up-face. Pure vertical toss: a
        // tumble's first-contact lateral kick ejects the die off the
        // slab edge on Jolt (seen twice in this lane), and a body that
        // falls off the world never settles.
        c.setBodyVelocity(
          die.id,
          linear: Vector3.zero(),
          angularAxis: Vector3(0, 1, 0),
          angularRate: 0,
        );
        c.setNodeTransforms([
          NodeTransform(
            die.id,
            // z=2.5 keeps the throw clear of the margin probe's rest
            // cell (boundsQuad collider tops z∈[0.7,1.5] around
            // (0.2,1.1)) — the die would land on it every roll.
            translation: Vector3(0, 1.4, 2.5),
            rotation: Quaternion.identity(),
          ),
        ]);
        c.applyImpulse(die.id, Vector3(0, 1.4, 0));
        // No torque: Jolt converts even pure-yaw spin into lateral
        // drift on first contact — a spinning cube slid off the slab
        // edge twice in this lane. The metric is rest latency, not
        // tumble realism.
        // Fallback arm: three consecutive <2 cm pose reads = rest.
        // Rate-limited pose logging discriminates a die that never
        // rests (real motion) from a query path that keeps failing.
        var stable = 0;
        var polls = 0;
        Vector3? last;
        void poll() {
          fallback = Timer(const Duration(milliseconds: 250), () async {
            Vector3? p;
            Object? err;
            try {
              p = (await c.poseOf(die.id))?.position;
            } catch (e) {
              err = e;
            }
            polls++;
            if (polls % 8 == 0 || err != null) {
              dnLog('dart3d: wloose poll die '
                  'pose=${p == null ? (err ?? 'null') : v(p)} '
                  'stable=$stable');
            }
            final d = (p != null && last != null)
                ? (p - last!).length
                : double.infinity;
            stable = d < 0.02 ? stable + 1 : 0;
            last = p;
            if (stable >= 3) {
              recordSettle('pose-quiescence', p);
            } else {
              poll();
            }
          });
        }

        fallback = Timer(const Duration(milliseconds: 3500), poll);
      };

      Timer(const Duration(seconds: 4), () {
        final retiring = <String, LocalId>{};
        for (final n in live.nodes.values) {
          if (n.name == 'w5NoRest' ||
              n.name == 'j9.liftPlate' ||
              n.name.startsWith('j9.chain')) {
            retiring[n.name] = n.id;
          }
        }
        for (final e in retiring.entries) {
          c.removeNode(e.value);
        }
        dnLog(
          retiring.isEmpty
              ? 'dart3d: wloose no perpetual movers found — '
                  'settle events already live'
              : 'dart3d: wloose removed ${retiring.keys.join(',')} — '
                  'settle events live',
        );
        sub = c.physicsEvents.listen((event) {
          if (event is! SceneSettledEvent) return;
          settledSeen = true;
          Vector3? diePos;
          for (final p in event.poses) {
            if (p.node == die.id) diePos = p.position;
          }
          recordSettle('event', diePos);
        });
        // The removal's settle-flush gets 800 ms to land before the
        // first throw arms the metric.
        Timer(const Duration(milliseconds: 800),
            () => throwDie?.call());
      });
      // A world that can't sleep (a probe still falling despite the
      // catcher, a joint that never rests) must not leak the
      // subscription past the lane.
      Timer(const Duration(seconds: 30), () {
        if (rolls < 3) {
          dnLog('dart3d: wloose settle incomplete — $rolls/3 rolls timed');
        }
        dnLog(
          'dart3d: wloose settled event path: '
          '${settledSeen ? 'seen' : 'absent'}',
        );
        fallback?.cancel();
        sub?.cancel();
      });
    }

    // W15 phase (+112 s): the subtree-streaming lane. streamA loads
    // the 100-cell grid plain; streamB loads it with the authored
    // delta (red peak, missing corner, added light, grafted beacon).
    // The peak's vertex chunk is declared byte-less in the prefab, so
    // both peaks stay unrealized until the +2.4 s `upsertPayload`
    // lands it on every consumer at once — the post-manifest payload
    // lane. streamA then drops and re-streams three times for the
    // no-stale-nodes lane. Send-side timestamps pair with the natives'
    // `apply`/`visible` stamps for the manifest-to-visible metric.
    void addW15Phase() {
      final c = controller;
      if (c == null) return;
      // The streamed deferred chunk's wire id is the composed doc's —
      // upstream's _sharedId remap is private, so discover it by
      // running the same expansion the load runs (deterministic ids,
      // so this compose is the exact one the ops carry).
      final discovery = SceneDocument();
      discovery.addNode(
        NodeSpec(
          id: streamA.id,
          instance: streamA.instance!.copyWith(load: LoadPolicy.eager),
        ),
      );
      final peakChunk = composeScene(
        discovery,
        resolve: (ref) => _w15Resolve(w15.document, ref),
      ).payloads.values.firstWhere((p) => p.bytes == null).id;
      var loads = 0;
      var unloads = 0;
      void load(LocalId id, String label) {
        loads++;
        dnLog(
          'dart3d: w15 loadSubtree $label sent '
          't=${DateTime.now().millisecondsSinceEpoch}',
        );
        c.loadSubtree(id, resolve: (ref) => _w15Resolve(w15.document, ref));
      }

      void unload(LocalId id, String label) {
        unloads++;
        dnLog(
          'dart3d: w15 unloadSubtree $label sent '
          't=${DateTime.now().millisecondsSinceEpoch}',
        );
        c.unloadSubtree(id);
      }

      load(streamA.id, 'A#1');
      Timer(const Duration(milliseconds: 1200), () => load(streamB.id, 'B#1'));
      Timer(const Duration(milliseconds: 2400), () {
        dnLog(
          'dart3d: w15 deferred peak chunk sent '
          't=${DateTime.now().millisecondsSinceEpoch}',
        );
        c.applyCommands([
          {
            'op': 'upsertPayload',
            'id': 'chunk:${peakChunk.toToken()}',
            'bytes': base64Encode(w15.peakBytes),
            'encoding': PayloadEncoding.vertexBuffer.name,
            'layout': 'unskinned_uv1_tangent',
            'length': w15.peakBytes.lengthInBytes,
          },
        ]);
      });
      Timer(
        const Duration(milliseconds: 3600),
        () => unload(streamA.id, 'A#1'),
      );
      Timer(const Duration(milliseconds: 4800), () => load(streamA.id, 'A#2'));
      Timer(
        const Duration(milliseconds: 6000),
        () => unload(streamA.id, 'A#2'),
      );
      Timer(const Duration(milliseconds: 7200), () => load(streamA.id, 'A#3'));
      Timer(
        const Duration(milliseconds: 8400),
        () => unload(streamA.id, 'A#3'),
      );
      Timer(const Duration(milliseconds: 9600), () => load(streamA.id, 'A#4'));
      Timer(const Duration(seconds: 12), () {
        dnLog(
          'dart3d: w15 lane complete — $loads loads, $unloads unloads '
          '(3 cycles on streamA; expected final state: both grids live)',
        );
      });
    }

    return (
      document: doc,
      die: die.id,
      ball: ball.id,
      hidden: hidden.id,
      jointRig: addJointRig,
      w11Phase: addW11Phase,
      w12Phase: addW12Phase,
      w13Phase: addW13Phase,
      w14Phase: addW14Phase,
      wLoosePhase: addWLoosePhase,
      w15Phase: addW15Phase,
    );
  }

  /// The W8 query battery — fired once at +10 s by the app's timer
  /// (after the +8 s diff; `w5NoRest` keeps the world awake, so settle
  /// can't drive timing). Exercises `poseOf`, a downward `raycast`
  /// through the die's rest cell, an `overlapSphere` at the slab
  /// center, and a top-down `shapeCastSphere` through the die. Returns
  /// a one-line summary for the status line.
  static Future<String> queryBattery(
    SceneController controller,
    LocalId die,
  ) async {
    String v(Vector3 p) =>
        '(${p.x.toStringAsFixed(2)},${p.y.toStringAsFixed(2)},${p.z.toStringAsFixed(2)})';
    String hits(List<SceneRaycastHit> hs) => hs
        .map((h) => 'n${h.node.index}@${h.distance.toStringAsFixed(2)}')
        .join(',');
    final out = <String>[];

    // poseOf anchors the other probes at the die's rest cell — the
    // spawn column when the die reports no pose.
    var rest = Vector3(0, 0, 0.8);
    try {
      final pose = await controller.poseOf(die);
      if (pose != null) rest = pose.position;
      out.add('pose:${pose == null ? 'miss' : v(rest)}');
    } catch (e) {
      out.add('pose:err $e');
    }

    // Straight down through the rest cell — the die should be nearest,
    // the slab behind it on `all`.
    try {
      final hs = await controller.raycast(
        origin: rest + Vector3(0, 2, 0),
        direction: Vector3(0, -1, 0),
        maxDistance: 10,
        all: true,
      );
      out.add('ray:${hs.isEmpty ? 'miss' : hits(hs)}');
    } catch (e) {
      out.add('ray:err $e');
    }

    // The slab's volume center — at least the slab itself should hit.
    try {
      final hs = await controller.overlapSphere(Vector3(0, -0.75, 1.5), 1.5);
      out.add('overlap:${hs.length}');
    } catch (e) {
      out.add('overlap:err $e');
    }

    // Top-down through the die's rest cell to below the slab top.
    try {
      final hs = await controller.shapeCastSphere(
        radius: 0.3,
        from: rest + Vector3(0, 2, 0),
        to: rest - Vector3(0, 2, 0),
      );
      out.add('cast:${hs.isEmpty ? 'miss' : hits(hs)}');
    } catch (e) {
      out.add('cast:err $e');
    }
    return out.join(' · ');
  }

  /// A tetrahedron as interleaved `p3t4` vertex bytes (position f32×3 +
  /// tangent-frame quaternion f32×4 — the layout MeshFactory already
  /// packs) plus a uint16 index list. `p3t4` is the dart3d extension
  /// layout pinned by docs/payload-geometry-spec.md — native-space
  /// verbatim, no winding migration.
  static ({Uint8List vertices, Uint8List indices, BoundsSpec bounds})
  _tetrahedron() {
    final positions = [
      Vector3(0.0, 0.55, 0.0),
      Vector3(-0.4, 0.0, -0.25),
      Vector3(0.4, 0.0, -0.25),
      Vector3(0.0, 0.0, 0.45),
    ];
    final centroid = positions.fold<Vector3>(
      Vector3.zero(),
      (sum, p) => sum + p,
    )..scale(1.0 / positions.length);

    final verts = ByteData(positions.length * 7 * 4);
    var off = 0;
    for (final p in positions) {
      // Smooth normals (radial from centroid); the tangent frame is a
      // Filament-style TANGENTS quat built from orthonormal t, b, n.
      final n = (p - centroid).normalized();
      final ref = n.y.abs() > 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
      final t = ref.cross(n).normalized();
      final b = n.cross(t);
      final q = Quaternion.fromRotation(Matrix3.columns(t, b, n));
      for (final v in [p.x, p.y, p.z, q.x, q.y, q.z, q.w]) {
        verts.setFloat32(off, v, Endian.little);
        off += 4;
      }
    }

    final indices = Uint16List.fromList([
      0,
      2,
      1,
      0,
      1,
      3,
      0,
      3,
      2,
      1,
      2,
      3,
    ]).buffer.asUint8List();

    return (
      vertices: verts.buffer.asUint8List(),
      indices: indices,
      bounds: BoundsSpec(
        min: Vector3(-0.4, 0.0, -0.25),
        max: Vector3(0.4, 0.55, 0.45),
      ),
    );
  }

  /// The W15 streamed prefab — a 10×10 cell grid under a container
  /// root (the ~100-node perf lane) plus `peak`, a payload-geometry
  /// marker whose vertex chunk is declared byte-less: the streamed
  /// subtree's peak geometry stays unresolved until a post-load
  /// `upsertPayload` lands it (the post-manifest payload lane). The
  /// returned ids are prefab-local — overrides/attachments name them,
  /// and `peakBytes` is the chunk the phase ships under the composed
  /// id upstream's shared-resource remap produces.
  static ({
    SceneDocument document,
    LocalId peak,
    LocalId cornerCell,
    LocalId peakVerts,
    Uint8List peakBytes,
  })
  _w15Prefab() {
    final prefab = SceneDocument();
    final cellGeo = prefab.addResource(
      GeometryResource(
        prefab.newId(),
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.16)),
      ),
    );
    final cellMat = prefab.addResource(
      MaterialResource(
        prefab.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.2, 0.45, 0.95, 1.0),
          'metallic': DoubleValue(0.0),
          'roughness': DoubleValue(0.6),
        },
      ),
    );
    final peakQuad = _quad(0.3);
    final peakVerts = prefab.addPayload(
      PayloadSpec(
        prefab.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: peakQuad.vertices.lengthInBytes,
        // bytes stay null — the deferred-arrival lane.
      ),
    );
    final peakIndices = prefab.addPayload(
      PayloadSpec(
        prefab.newId(),
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: peakQuad.indices.lengthInBytes,
        bytes: peakQuad.indices,
      ),
    );
    final peakGeo = prefab.addResource(
      GeometryResource(
        prefab.newId(),
        vertices: peakVerts.id,
        indices: peakIndices.id,
        bounds: peakQuad.bounds,
      ),
    );
    final peakMat = prefab.addResource(
      MaterialResource(
        prefab.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.75, 0.2, 1.0),
          'emissive': ColorValue(0.6, 0.45, 0.08, 1.0),
          'metallic': DoubleValue(0.1),
          'roughness': DoubleValue(0.4),
        },
      ),
    );

    final cells = <NodeSpec>[];
    for (var i = 0; i < 100; i++) {
      cells.add(
        prefab.addNode(
          NodeSpec(
            id: prefab.newId(),
            name: 'w15.cell$i',
            transform: TrsTransform(
              translation: Vector3(
                (i % 10 - 4.5) * 0.26,
                0.08,
                (i ~/ 10 - 4.5) * 0.26,
              ),
            ),
            components: [
              ComponentSpec(
                'mesh',
                properties: {
                  'geometry': ResourceRefValue(cellGeo.id),
                  'material': ResourceRefValue(cellMat.id),
                },
              ),
            ],
          ),
        ),
      );
    }
    final peak = prefab.addNode(
      NodeSpec(
        id: prefab.newId(),
        name: 'w15.peak',
        transform: TrsTransform(translation: Vector3(0, 0.75, 0)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(peakGeo.id),
              'material': ResourceRefValue(peakMat.id),
            },
          ),
        ],
      ),
    );
    prefab.addNode(
      NodeSpec(
        id: prefab.newId(),
        name: 'w15.root',
        children: [for (final c in cells) c.id, peak.id],
      ),
      root: true,
    );
    return (
      document: prefab,
      peak: peak.id,
      cornerCell: cells[0].id,
      peakVerts: peakVerts.id,
      peakBytes: peakQuad.vertices,
    );
  }

  /// The W15 host-layer resolve — the built [prefab] stands in for a
  /// bundle `.fscene` read (same `PrefabResolver` contract). The doc
  /// identity matters: shared resource/payload ids derive from the
  /// prefab's `documentId`, so every resolve must return the same
  /// object or the deferred-chunk claim lands on a different id.
  static SceneDocument _w15Resolve(SceneDocument prefab, AssetRef ref) {
    if (ref.key != 'w15-grid') {
      throw FsceneFormatException('w15: unknown prefab "${ref.key}"');
    }
    return prefab;
  }

  /// A face-up quad of edge `2 * half` packed into the upstream
  /// `unskinned_uv1_tangent` layout by [VertexPack], with tight bounds
  /// and both index orders on hand: `indices` is CCW (v5+), `indicesCw`
  /// the same triples reversed for the legacyWinding lane.
  static ({
    Uint8List vertices,
    Uint8List indices,
    Uint8List indicesCw,
    BoundsSpec bounds,
  })
  _quad(double half) {
    final positions = [
      Vector3(-half, 0, -half),
      Vector3(half, 0, -half),
      Vector3(half, 0, half),
      Vector3(-half, 0, half),
    ];
    final up = Vector3(0, 1, 0);
    final white = Vector4(1, 1, 1, 1);
    final tangent = Vector4(1, 0, 0, 1);
    final vertices = VertexPack.unskinned(
      positions: positions,
      normals: [up, up, up, up],
      uvs: [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
      colors: [white, white, white, white],
      tangents: [tangent, tangent, tangent, tangent],
    );
    // CCW seen from the +Y front face; the CW list feeds legacyWinding.
    final indices = Uint16List.fromList(const [0, 2, 1, 0, 3, 2]);
    final indicesCw = Uint16List.fromList(const [0, 1, 2, 0, 2, 3]);
    return (
      vertices: vertices,
      indices: indices.buffer.asUint8List(),
      indicesCw: indicesCw.buffer.asUint8List(),
      bounds: BoundsSpec(
        min: Vector3(-half, 0, -half),
        max: Vector3(half, 0, half),
      ),
    );
  }

  /// A `segments`² subdivided flat plane in the same upstream layout —
  /// at 100×100 that's 10201 verts, the ~10k perf payload. Row-major
  /// vertices, CCW cells like the quad, tight bounds.
  static ({Uint8List vertices, Uint8List indices, BoundsSpec bounds}) _grid({
    required int segments,
    required double size,
  }) {
    final positions = <Vector3>[];
    final normals = <Vector3>[];
    final uvs = <Vector2>[];
    for (var j = 0; j <= segments; j++) {
      for (var i = 0; i <= segments; i++) {
        positions.add(
          Vector3((i / segments - 0.5) * size, 0, (j / segments - 0.5) * size),
        );
        normals.add(Vector3(0, 1, 0));
        uvs.add(Vector2(i / segments, j / segments));
      }
    }
    final vertices = VertexPack.unskinned(
      positions: positions,
      normals: normals,
      uvs: uvs,
    );
    final w = segments + 1;
    final indices = Uint32List(segments * segments * 6);
    var k = 0;
    for (var j = 0; j < segments; j++) {
      for (var i = 0; i < segments; i++) {
        final a = j * w + i;
        final b = a + 1;
        final c = a + w;
        final d = c + 1;
        indices[k++] = a;
        indices[k++] = d;
        indices[k++] = b;
        indices[k++] = a;
        indices[k++] = c;
        indices[k++] = d;
      }
    }
    return (
      vertices: vertices,
      indices: indices.buffer.asUint8List(),
      bounds: BoundsSpec(
        min: Vector3(-size / 2, 0, -size / 2),
        max: Vector3(size / 2, 0, size / 2),
      ),
    );
  }

  /// An open-top box — floor plus four zero-thickness walls — packed
  /// into the upstream `unskinned_uv1_tangent` layout with uint16
  /// indices and tight bounds; the `concaveMesh` lane's mesh. Each
  /// face's corners are ordered so the shared [0,2,1, 0,3,2] index
  /// pattern (same convention as [_quad]) makes the bowl interior the
  /// front: the floor faces +Y and each wall faces inward, so a
  /// single-sided material still reads as a container from the camera.
  /// The cavity spans `2*half` — sized for the 1 m die.
  static ({Uint8List vertices, Uint8List indices, BoundsSpec bounds}) _openBox({
    required double half,
    required double height,
  }) {
    final w = half;
    final h = height;
    final positions = <Vector3>[
      // Floor (front +Y).
      Vector3(-w, 0, -w), Vector3(w, 0, -w), Vector3(w, 0, w),
      Vector3(-w, 0, w),
      // +X wall (front -X, into the cavity).
      Vector3(w, 0, -w), Vector3(w, h, -w), Vector3(w, h, w),
      Vector3(w, 0, w),
      // -X wall (front +X).
      Vector3(-w, 0, w), Vector3(-w, h, w), Vector3(-w, h, -w),
      Vector3(-w, 0, -w),
      // +Z wall (front -Z).
      Vector3(w, 0, w), Vector3(w, h, w), Vector3(-w, h, w),
      Vector3(-w, 0, w),
      // -Z wall (front +Z).
      Vector3(-w, 0, -w), Vector3(-w, h, -w), Vector3(w, h, -w),
      Vector3(w, 0, -w),
    ];
    final normals = <Vector3>[
      for (final n in [
        Vector3(0, 1, 0),
        Vector3(-1, 0, 0),
        Vector3(1, 0, 0),
        Vector3(0, 0, -1),
        Vector3(0, 0, 1),
      ]) ...[n, n, n, n],
    ];
    final uvs = <Vector2>[
      for (var f = 0; f < 5; f++) ...[
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(1, 1),
        Vector2(0, 1),
      ],
    ];
    final vertices = VertexPack.unskinned(
      positions: positions,
      normals: normals,
      uvs: uvs,
    );
    final indices = Uint16List(5 * 6);
    var k = 0;
    for (var f = 0; f < 5; f++) {
      final base = f * 4;
      for (final i in const [0, 2, 1, 0, 3, 2]) {
        indices[k++] = base + i;
      }
    }
    return (
      vertices: vertices,
      indices: indices.buffer.asUint8List(),
      bounds: BoundsSpec(min: Vector3(-w, 0, -w), max: Vector3(w, h, w)),
    );
  }

  /// The W11 skinned "flag": a 4×2-vertex strip in the upstream
  /// `skinned_uv1_tangent` layout (26 f32/vertex — the unskinned 18
  /// plus `joints4`/`weights4`). 1.8 m wide × 0.5 m tall in the local
  /// XY plane with the front face toward −Z (the camera); the column
  /// weights ramp joint 0 → joint 1 across the strip so the wave's
  /// joint rotations read as a ripple. The mesh's node and the joint
  /// chain root share one anchor, so joint 0's inverse-bind is
  /// identity and joint 1's is its −0.6 X bind offset.
  static ({Uint8List vertices, Uint8List indices, BoundsSpec bounds})
  _flagStrip() {
    const cols = 4;
    const dx = 0.6;
    const h = 0.5;
    final positions = <Vector3>[];
    final joints = <Vector4>[];
    final weights = <Vector4>[];
    final uvs = <Vector2>[];
    for (var r = 0; r <= 1; r++) {
      for (var c = 0; c < cols; c++) {
        positions.add(Vector3(c * dx, r * h, 0));
        // Column 0 rides joint 0 only, column 3 joint 1 only.
        final tip = c / (cols - 1);
        joints.add(Vector4(0, 1, 0, 0));
        weights.add(Vector4(1 - tip, tip, 0, 0));
        uvs.add(Vector2(c / (cols - 1), r.toDouble()));
      }
    }
    final vertices = VertexPack.skinned(
      positions: positions,
      joints: joints,
      weights: weights,
      normals: [for (var i = 0; i < 8; i++) Vector3(0, 0, -1)],
      uvs: uvs,
    );
    // Front face −Z (toward the camera): each cell indexes
    // bottom-left → top-left → bottom-right, then bottom-right →
    // top-left → top-right — CCW seen from the −Z side.
    final indices = Uint16List(6 * (cols - 1));
    var k = 0;
    for (var c = 0; c < cols - 1; c++) {
      final bl = c;
      final tl = cols + c;
      final br = c + 1;
      final tr = cols + c + 1;
      for (final i in [bl, tl, br, br, tl, tr]) {
        indices[k++] = i;
      }
    }
    return (
      vertices: vertices,
      indices: indices.buffer.asUint8List(),
      bounds: BoundsSpec(
        min: Vector3(0, 0, -0.02),
        max: Vector3(dx * (cols - 1), h, 0.02),
      ),
    );
  }

  /// The W11 morph blob: an 8-vertex ±0.3 cube in the unskinned
  /// layout (radial normals — it shades like a soft blob) plus two
  /// position-delta morph targets packed target-major into one
  /// `floats` chunk, matching `MorphTargetsSpec`'s slab order:
  /// `puff` scales each vertex 1.5× out, `squash` flattens Y to a
  /// quarter.
  static ({
    Uint8List vertices,
    Uint8List indices,
    Uint8List deltas,
    BoundsSpec bounds,
  })
  _morphCube() {
    const e = 0.3;
    final positions = [
      Vector3(-e, -e, -e),
      Vector3(e, -e, -e),
      Vector3(e, e, -e),
      Vector3(-e, e, -e),
      Vector3(-e, -e, e),
      Vector3(e, -e, e),
      Vector3(e, e, e),
      Vector3(-e, e, e),
    ];
    final vertices = VertexPack.unskinned(
      positions: positions,
      normals: [for (final p in positions) p.normalized()],
    );
    // Outward faces, CCW seen from outside — same convention as the
    // v5+ index buffers above.
    final indices = Uint16List.fromList(const [
      0, 3, 1, 1, 3, 2, // -Z
      4, 5, 6, 4, 6, 7, // +Z
      1, 2, 6, 1, 6, 5, // +X
      0, 4, 7, 0, 7, 3, // -X
      3, 7, 6, 3, 6, 2, // +Y
      0, 1, 5, 0, 5, 4, // -Y
    ]).buffer.asUint8List();
    final deltas = Float32List(8 * 3 * 2);
    for (var i = 0; i < 8; i++) {
      final p = positions[i];
      deltas[i * 3 + 0] = p.x * 0.5; // puff: base × 1.5
      deltas[i * 3 + 1] = p.y * 0.5;
      deltas[i * 3 + 2] = p.z * 0.5;
      deltas[8 * 3 + i * 3 + 1] = -p.y * 0.75; // squash: Y → ¼
    }
    return (
      vertices: vertices,
      indices: indices,
      deltas: deltas.buffer.asUint8List(),
      bounds: BoundsSpec(min: Vector3.all(-e), max: Vector3.all(e)),
    );
  }

  /// [values] packed little-endian f32 — the `floats`/`matrices`
  /// chunk encoding the W11 timelines, keyframes, and IBMs ride.
  static Uint8List _f32(List<double> values) {
    final out = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      out.setFloat32(i * 4, values[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }

  /// A Z-axis rotation quaternion's wire components — the W11 `wave`
  /// channels' keyframe values.
  static List<double> _quatZ(double angle) {
    final q = Quaternion.axisAngle(Vector3(0, 0, 1), angle);
    return [q.x, q.y, q.z, q.w];
  }

  /// The W5 phase-two document: [doc] copied through a manifest
  /// round-trip — `readFscene(writeFscene(doc))` preserves every stable
  /// id and mints fresh-session ids for new nodes, while payload bytes
  /// (out-of-band in the format) are re-attached by id — then mutated
  /// so `diffScene(doc, phaseTwo)` produces every W5 lane. Returned for
  /// `SceneController.applyDiff`.
  static SceneDocument _phaseTwo(SceneDocument doc) {
    final next = readFscene(writeFscene(doc));
    for (final p in next.payloads.values) {
      p.bytes = doc.payloads[p.id]?.bytes;
    }

    NodeSpec named(String name) =>
        next.nodes.values.firstWhere((n) => n.name == name);
    LocalId meshRef(NodeSpec node, String key) =>
        (node.components.firstWhere((c) => c.type == 'mesh').properties[key]!
                as ResourceRefValue)
            .id;

    // removeNode: the rig's whole subtree (marker + child mesh +
    // child light) leaves the live scene.
    final rig = named('rig');
    for (final child in rig.children) {
      next.nodes.remove(child);
    }
    next.nodes.remove(rig.id);
    next.roots.remove(rig.id);

    // updateNode transform: the emissive quad floats a row higher.
    named('emissiveQuad').transform = TrsTransform(
      translation: Vector3(0.2, 2.2, -1.2),
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
    );

    // updateNode reparented: the offset box moves under `ground` —
    // same local transform, so it visibly relocates.
    final offset = named('offsetBox');
    next.roots.remove(offset.id);
    named('ground').children.add(offset.id);

    // upsertResource material: the ball turns green in place.
    final ballMat = meshRef(named('ball'), 'material');
    (next.resources[ballMat]! as MaterialResource).properties['baseColor'] =
        ColorValue(0.2, 0.85, 0.35, 1.0);

    // upsertResource geometry: the UV-shift box's mesh component still
    // names the same resource id, but the cube is now a sphere.
    final uvShiftGeo = meshRef(named('uvShiftBox'), 'geometry');
    next.resources[uvShiftGeo] = GeometryResource(
      uvShiftGeo,
      procedural: SphereGeometrySpec(radius: 0.45),
    );

    // upsertPayload: the tetra's `p3t4` vertex chunk re-uploads with a
    // shear on the position channel — the live mesh visibly deforms.
    final tetraVertsId =
        (next.resources[meshRef(named('payloadTetra'), 'geometry')]!
                as GeometryResource)
            .vertices!;
    final tetraVerts = next.payloads[tetraVertsId]!;
    tetraVerts.bytes = _shearP3t4Positions(tetraVerts.bytes!);

    // addNode: a lit quad in a third row, then a 40-box strip — with
    // the structural ops above the batch lands ~50 commands (the
    // lanes-8/9 burst).
    final quadGeo = meshRef(named('payloadQuad'), 'geometry');
    final quadMat = meshRef(named('payloadQuad'), 'material');
    next.createNode(
      name: 'w5Quad',
      transform: TrsTransform(
        translation: Vector3(-2.6, 2.3, -1.2),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(quadGeo),
            'material': ResourceRefValue(quadMat),
          },
        ),
      ],
      root: true,
    );
    final burstGeo = meshRef(named('floater'), 'geometry');
    final burstMat = meshRef(named('floater'), 'material');
    for (var i = 0; i < 40; i++) {
      next.createNode(
        name: 'w5Burst$i',
        transform: TrsTransform(
          translation: Vector3(
            -2.85 + (i % 20) * 0.3,
            -0.3,
            -0.55 - (i ~/ 20) * 0.3,
          ),
        ),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(burstGeo),
              'material': ResourceRefValue(burstMat),
            },
          ),
        ],
        root: true,
      );
    }

    // W6 allowsResting lane: a dynamic body that never sleeps, added
    // only by the +8 s diff so the initial settle stays clean. It
    // drops into the slab's back-left corner — clear of the die's
    // landing zone — and visibly rests while Jolt `isActive` / the
    // iOS body state keeps reporting it awake. `allowsResting` is a
    // dart3d extension property (no upstream equivalent — the schema
    // doc's dropped list), so it is set on the component directly.
    final noRestBody = rigidBodyComponent(
      type: 'dynamic',
      mass: 0.3,
      linearDamping: 0.05,
      angularDamping: 0.05,
    )..properties['allowsResting'] = BoolValue(false);
    next.createNode(
      name: 'w5NoRest',
      transform: TrsTransform(translation: Vector3(-3.3, 0.6, 3.3)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(burstGeo),
            'material': ResourceRefValue(burstMat),
          },
        ),
        colliderComponent(
          shape: 'box',
          extents: Vector3.all(0.4),
          friction: 0.6,
          restitution: 0.1,
        ),
        noRestBody,
      ],
      root: true,
    );
    return next;
  }

  /// [src] reinterpreted as `p3t4` (7 f32 per vertex: pos3 + quat4)
  /// with `x += y·0.6` applied to the position channel — the tetra
  /// leans without its ids, layout, or bounds changing.
  static Uint8List _shearP3t4Positions(Uint8List src) {
    final out = Uint8List.fromList(src);
    final f = Float32List.view(out.buffer);
    for (var i = 0; i * 7 + 2 < f.length; i++) {
      f[i * 7] += f[i * 7 + 1] * 0.6;
    }
    return out;
  }

  /// Brick/bump tangent-space normal map as raw RGBA8: a 16×8 px brick
  /// heightfield (half-offset courses, 2 px mortar grooves, small
  /// per-brick height jitter) run through a finite-difference normal.
  /// Mostly flat (128,128,255) with strong tilts at the seams, so a
  /// directional light shows obvious relief.
  static Uint8List _normalBrick(int w, int h) {
    const bw = 16;
    const bh = 8;
    const mortar = 2;
    final height = Float64List(w * h);
    for (var y = 0; y < h; y++) {
      final row = y ~/ bh;
      final off = row.isOdd ? bw ~/ 2 : 0;
      for (var x = 0; x < w; x++) {
        final lx = (x + off) % bw;
        final ly = y % bh;
        if (lx < mortar || ly < mortar) {
          height[y * w + x] = 0;
        } else {
          // Deterministic per-brick height so adjacent courses catch
          // the light differently.
          final brick = (x + off) ~/ bw + row * 37;
          height[y * w + x] = 0.7 + (brick * 29 % 7) / 28;
        }
      }
    }
    double hAt(int x, int y) => height[((y + h) % h) * w + ((x + w) % w)];
    const strength = 6.0;
    final out = Uint8List(w * h * 4);
    var o = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = (hAt(x + 1, y) - hAt(x - 1, y)) * strength;
        final dy = (hAt(x, y + 1) - hAt(x, y - 1)) * strength;
        final invLen = 1.0 / sqrt(dx * dx + dy * dy + 1.0);
        out[o] = ((-dx * invLen * 0.5 + 0.5) * 255).round();
        out[o + 1] = ((-dy * invLen * 0.5 + 0.5) * 255).round();
        out[o + 2] = ((invLen * 0.5 + 0.5) * 255).round();
        out[o + 3] = 255;
        o += 4;
      }
    }
    return out;
  }

  /// Warm dots on black, one per 16 px cell, with a linear falloff
  /// across the dot so `emissiveStrength` has a gradient to work with.
  static Uint8List _emissiveDots(int w, int h) {
    const pitch = 16;
    const radius = 3.5;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = (x % pitch) - pitch ~/ 2;
        final dy = (y % pitch) - pitch ~/ 2;
        final d = sqrt(dx * dx + dy * dy);
        final o = (y * w + x) * 4;
        if (d <= radius) {
          final t = 1.0 - d / radius;
          out[o] = 255;
          out[o + 1] = (140 + 90 * t).round();
          out[o + 2] = (40 + 60 * t).round();
        }
        out[o + 3] = 255;
      }
    }
    return out;
  }

  /// The checkerboard as raw RGBA8 — 8 px cells, near-white vs
  /// near-black — so the `format: 'rgba8'` decode path shows the same
  /// pattern the embedded PNG's magic-bytes path produces.
  static Uint8List _checkerRgba(int w, int h) {
    final out = Uint8List(w * h * 4);
    var o = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = ((x ~/ 8) + (y ~/ 8)).isEven ? 0xE8 : 0x18;
        out[o] = v;
        out[o + 1] = v;
        out[o + 2] = v;
        out[o + 3] = 255;
        o += 4;
      }
    }
    return out;
  }

  /// Channel inversion of [_checkerRgba] — the lane-10 swap payload:
  /// every cell flips light/dark, so a still frame proves the texture
  /// changed rather than merely appeared.
  static Uint8List _checkerInv(int w, int h) {
    final out = _checkerRgba(w, h);
    for (var i = 0; i < out.length; i += 4) {
      out[i] = 255 - out[i];
      out[i + 1] = 255 - out[i + 1];
      out[i + 2] = 255 - out[i + 2];
    }
    return out;
  }

  /// glTF-packed metallic/roughness map: G = roughness, B = metallic
  /// (R unused). Rough dielectric everywhere (G ≈ 0.9·255, B = 0)
  /// except the top-right quadrant, which flips to smooth metal
  /// (G = 51 ≈ 0.2, B = 255) — one bright specular patch for contrast.
  static Uint8List _mrPatch(int w, int h) {
    final out = Uint8List(w * h * 4);
    var o = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final metal = x >= w ~/ 2 && y < h ~/ 2;
        out[o] = 0;
        out[o + 1] = metal ? 51 : 230;
        out[o + 2] = metal ? 255 : 0;
        out[o + 3] = 255;
        o += 4;
      }
    }
    return out;
  }

  /// 64×32 equirect PNG for the W7 payload-environment lane: bright
  /// sky-blue top third, green horizon band, dark-brown bottom third,
  /// plus a bright yellow sun spot — the up/horizon/ground split makes
  /// env orientation legible in reflections and the skybox background.
  /// Generated offline with `package:image`'s `encodePng`, whose
  /// `package:archive` import DartNative's patched SDK shadows (see
  /// scene_model.dart), so the bytes are embedded like [_checkerPng].
  static const _envEquirectPng =
      'iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAIAAAAt/+nTAAAAkUlEQVR4nO2UwQnA'
      'IBAEJVwzNmJ6iPWklGvCOgL+00jyEILkFw+yHuy8RBB2bg9l0yt4RtABrEwhoCnm'
      'UsfeggU0xf4woDFFAxaQAs/4+5uvJSAFcqkvB67Q77SRO/6FGsPpZxGwIGdY0RlM'
      '+G8AHcAKBdBQAA0F0FAAjSz7gc5gwn8D6ABWKICGAmgogMa9wA3OahvvDokF2AAA'
      'AABJRU5ErkJggg==';

  /// 64px checkerboard PNG, generated offline. `package:image`'s PNG
  /// encoder imports `package:archive`, which DartNative's patched SDK
  /// shadows (see scene_model.dart), so the bytes are embedded instead.
  static const _checkerPng =
      'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAk0lEQVR4nO3PMRGA'
      'ABDEQIQhAP8qkIEBrqAKmcnPlyluj3vceV6v/7f++NugAPSgAPSgAPSgzwDL0NUH'
      'oPsAdB+A7v0Ay9DVB6D7AHQfgO79AMvQ1Qeg+wB0H4Du/QDL0NUHoPsAdB+A7v0A'
      'y9DVB6D7AHQfgO79AMvQ1Qeg+wB0H4Du/QDL0NUHoPsAdB+A7vWABwyRwZZC0JGd'
      'AAAAAElFTkSuQmCC';
}
