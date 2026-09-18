/// The showcase loader — pure Dart (no `dartnative` imports) so the
/// upstream-corpus decode + compose path is reachable under `dart
/// test`. The screen lives in `showcase_scene.dart`, which passes
/// `loadAssetBytes` and `dnLog` in through the parameters.
// ignore_for_file: implementation_imports
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:dart3d/src/world_bounds.dart';
import 'package:vector_math/vector_math.dart';

/// One showcase entry: the cycler label, its bundle key, and the
/// capability line shown under it.
final class ShowcaseItem {
  const ShowcaseItem(this.label, this.assetKey, this.note);

  final String label;
  final String assetKey;
  final String note;
}

/// The upstream corpus bundled under `assets/showcase/` plus the dice
/// set (which keep their physics-ground load path — they roll).
const showcaseItems = [
  ShowcaseItem(
    'dash',
    'assets/showcase/dash.fsceneb',
    'skinned · 35 joints · 9 animations · 2 textures',
  ),
  ShowcaseItem(
    'fcar',
    'assets/showcase/fcar.fsceneb',
    '17 meshes · 39 geometries · 11 materials',
  ),
  ShowcaseItem(
    'logo',
    'assets/showcase/flutter_logo_baked.fsceneb',
    'textured · 1 animation',
  ),
  ShowcaseItem(
    'triangles',
    'assets/showcase/two_triangles.fsceneb',
    'minimal skinning · 2 animations',
  ),
  ShowcaseItem(
    'prefabs',
    'assets/showcase/prefab_demo.fscene',
    'upstream prefab instances (composeScene)',
  ),
  ShowcaseItem('cube', 'assets/showcase/cube.fscene', 'upstream .fscene'),
  ShowcaseItem(
    'playground',
    'assets/showcase/playground.fscene',
    'upstream .fscene',
  ),
  ShowcaseItem(
    'materials',
    kBuiltinMaterialsKey,
    'W21 lanes: alpha blend/mask · second UV set',
  ),
];

/// The synthetic asset key for the W21 materials conformance scene —
/// no bundled file; [loadShowcaseScene] builds the document
/// procedurally (see [buildMaterialsDocument]).
const String kBuiltinMaterialsKey = 'builtin:materials';

/// Dice stay in the gallery too — the [DART3D_MODEL] verification lane
/// and anyone wanting a single die on the physics slab.
bool isDiceAsset(String assetKey) => assetKey.startsWith('assets/dice/');

/// What the screen needs: the augmented document plus the camera rig
/// and a one-line capability summary.
final class ShowcaseScene {
  const ShowcaseScene({
    required this.document,
    required this.cameraNode,
    required this.cameraTarget,
    required this.cameraDir,
    required this.frameRadius,
    required this.summary,
  });

  final SceneDocument document;
  final LocalId cameraNode;
  final Vector3 cameraTarget;
  final Vector3 cameraDir;

  /// The bounds-union radius the camera framed — pinch zoom clamps
  /// around `frameRadius * 2.8` (the authored boom distance).
  final double frameRadius;
  final String summary;
}

/// Decodes [item]'s asset, expands prefabs, and injects the viewing
/// rig. Returns null when the asset is missing or fails to decode.
/// [bytesFor] overrides the bundle lookup for tests.
ShowcaseScene? loadShowcaseScene(
  ShowcaseItem item, {
  Uint8List? Function(String key)? bytesFor,
  void Function(String message)? log,
}) {
  final bytesOf = bytesFor ?? (_) => null;
  SceneDocument doc;
  try {
    if (item.assetKey == kBuiltinMaterialsKey) {
      doc = buildMaterialsDocument(bytesOf: bytesOf);
    } else {
      final bytes = bytesOf(item.assetKey);
      if (bytes == null) {
        log?.call('dart3d: showcase — missing asset ${item.assetKey}');
        return null;
      }
      doc = item.assetKey.endsWith('.fsceneb')
          ? readFsceneb(bytes)
          : readFscene(utf8.decode(bytes));
      // Prefab instances expand host-side — prefab_demo.fscene
      // references tree_prefab.fscene by bare filename.
      doc = composeScene(
        doc,
        resolve: (ref) {
          final prefabBytes = bytesOf('assets/showcase/${ref.key}');
          if (prefabBytes == null) {
            throw StateError('missing prefab ${ref.key}');
          }
          return ref.key.endsWith('.fsceneb')
              ? readFsceneb(prefabBytes)
              : readFscene(utf8.decode(prefabBytes));
        },
      );
    }
    // W21 light-units contract: upstream `n` fields translate to the
    // wire `intensity` at decode. `readFsceneb` already normalized the
    // binary path; this covers `.fscene` documents and prefab grafts —
    // the pass is idempotent.
    normalizeLightIntensity(doc);
  } catch (error) {
    log?.call('dart3d: showcase — ${item.assetKey} failed: $error');
    return null;
  }

  // Frame from the union of authored mesh bounds in world space —
  // geometry resources are local-space, so the node's world transform
  // applies before the union (imported hierarchies place meshes far
  // from their local origins). Content bounds exclude authored floor
  // slabs that would dwarf the actual subject.
  final bounds = documentContentBounds(doc);
  final bmin = bounds?.$1 ?? Vector3.zero();
  final bmax = bounds?.$2 ?? Vector3.zero();
  final hasBounds = bounds != null;
  final center = hasBounds ? (bmin + bmax) * 0.5 : Vector3.zero();
  final radius = hasBounds ? max((bmax - bmin).length * 0.5, 0.5) : 10.0;

  // A slab under the lowest bound gives the key light something to
  // throw shadows onto; visual only, no physics in the gallery.
  final slabMat = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(0.13, 0.14, 0.17, 1),
        'roughness': DoubleValue(0.92),
        'metallic': DoubleValue(0.0),
      },
    ),
  );
  final slabGeo = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(
        extents: Vector3(radius * 8, radius * 0.04, radius * 8),
      ),
    ),
  );
  doc.createNode(
    name: 'showcase.slab',
    transform: TrsTransform(
      translation: Vector3(
        center.x,
        (hasBounds ? bmin.y : 0) - radius * 0.02,
        center.z,
      ),
    ),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(slabGeo.id),
          'material': ResourceRefValue(slabMat.id),
        },
      ),
    ],
    root: true,
  );

  // The 3/4 model-viewer camera: up and south-west of center. With the
  // +Z forward convention the pose decomposes as Ry(yaw)·Rx(pitch)
  // over forward = −cameraDir.
  final cameraDir = Vector3(-0.52, 0.36, -0.77)..normalize();
  final fwd = -cameraDir;
  final pitch = -asin(fwd.y.clamp(-1.0, 1.0));
  final yaw = atan2(fwd.x, fwd.z);
  final camera = doc.createNode(
    name: 'showcase.camera',
    transform: TrsTransform(
      translation: center + cameraDir * radius * 2.8,
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), yaw) *
          Quaternion.axisAngle(Vector3(1, 0, 0), pitch),
    ),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': StringValue('perspective'),
          'fovRadiansY': DoubleValue(0.8),
          'near': DoubleValue(max(radius * 0.02, 0.01)),
          'far': DoubleValue(radius * 60),
        },
      ),
    ],
    root: true,
  );
  doc.createNode(
    name: 'showcase.key',
    transform: TrsTransform(
      rotation: Quaternion.axisAngle(
        Vector3(0.6, 0.3, 0.74)..normalize(),
        -0.85,
      ),
    ),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': ColorValue(1.0, 0.95, 0.88, 1),
          'intensity': DoubleValue(1300),
          'castsShadow': BoolValue(true),
          'shadowRadius': DoubleValue(3.0),
          'shadowDepthBias': DoubleValue(0.01),
        },
      ),
    ],
    root: true,
  );
  doc.createNode(
    name: 'showcase.fill',
    transform: TrsTransform(
      translation: center + Vector3(-radius * 2, radius * 1.6, -radius),
    ),
    components: [
      ComponentSpec(
        'pointLight',
        properties: {
          'color': ColorValue(0.62, 0.72, 1.0, 1),
          'intensity': DoubleValue(700 * radius),
          'range': DoubleValue(radius * 24),
        },
      ),
    ],
    root: true,
  );
  doc.stage.environmentRef ??= doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          environment: const StudioEnvironment(),
          environmentIntensity: 1.0,
          exposure: 1.0,
          toneMapping: 'pbrNeutral',
          skybox: SkyboxSpec(EnvironmentSkySpec()),
        ),
      )
      .id;

  var textures = 0, materials = 0, geometries = 0;
  for (final r in doc.resources.values) {
    if (r is TextureResource) textures++;
    if (r is MaterialResource) materials++;
    if (r is GeometryResource) geometries++;
  }
  final summary =
      '${doc.nodes.length} nodes · $geometries geo · $materials mat'
      '${textures == 0 ? '' : ' · $textures tex'}'
      '${doc.skins.isEmpty ? '' : ' · ${doc.skins.length} skins'}'
      '${doc.animations.isEmpty ? '' : ' · ${doc.animations.length} anims'}';
  log?.call('dart3d: showcase — ${item.label}: $summary');
  return ShowcaseScene(
    document: doc,
    cameraNode: camera.id,
    cameraTarget: center,
    cameraDir: cameraDir,
    frameRadius: radius,
    summary: summary,
  );
}

/// The W21 materials conformance scene — a procedural document (no
/// bundled asset) exercising the alphaMode + UV-set lanes. One row,
/// left to right:
///
/// - `materials.opaque` — control sphere, no alphaMode.
/// - `materials.backdrop` — opaque checker quad wall behind the blend
///   sphere, so `blend` composites against a pattern rather than the
///   slab.
/// - `materials.blend` — `alphaMode:'blend'` sphere at 0.4 alpha; the
///   lane reads "the backdrop shows through".
/// - `materials.mask` — `alphaMode:'mask'` quad sampling a generated
///   lattice texture (opaque cells over alpha-0 holes) with
///   `alphaCutoff: 0.5`; the lane reads "holes are absent, cells
///   present".
/// - `materials.uv0`/`materials.uv1` — one checker quad geometry
///   carrying both UV sets (uv0 covers the texture; uv1 collapses into
///   a single dark cell) drawn twice, the pair differing only in
///   `baseColorTextureTransform.texCoord`. The `texCoord:1` twin
///   renders flat where `texCoord:0` shows the checker.
/// - `materials.ktx2` — a quad sampling a bundled `.ktx2` payload:
///   ETC1S on Android (real Basis transcode through gltfio) and an
///   uncompressed vkFormat-37 file on iOS (the container-parse path;
///   supercompressed formats warn there until a transcoder ships).
/// - `stage.environmentRef` — a `PayloadEnvironment` carrying the
///   bundled `rgb_4x2` equirect: `.exr` on iOS (the W21 decode lane)
///   and `.hdr` on Android (the pre-existing HDR path).
///
/// [bytesOf] is the asset resolver injected by `loadShowcaseScene`;
/// when it cannot supply a file the corresponding lane node/env is
/// skipped rather than faked.
SceneDocument buildMaterialsDocument({
  Uint8List? Function(String key)? bytesOf,
}) {
  final doc = SceneDocument();
  const texSize = 64;

  // ── Shared payload geometry ─────────────────────────────────────
  // Two upright quads' worth of payloads: the plain quad (uv0 spans
  // the texture) and the two-UV-set quad (uv1 collapsed into one dark
  // checker cell). Both share one index buffer — a quad is two
  // triangles either way.
  final quadIndices = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: 'uint16',
      length: 12,
      bytes: Uint16List.fromList(const [0, 2, 1, 0, 3, 2])
          .buffer
          .asUint8List(),
    ),
  );

  void meshQuad({
    required String name,
    required Vector3 at,
    required MaterialResource material,
    List<Vector2>? uv1s,
    double half = 0.45,
  }) {
    final verts = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: 4 * VertexPack.unskinnedUv1TangentStride,
        bytes: VertexPack.unskinned(
          positions: [
            Vector3(-half, 0, -half),
            Vector3(half, 0, -half),
            Vector3(half, 0, half),
            Vector3(-half, 0, half),
          ],
          normals: List.filled(4, Vector3(0, 1, 0)),
          uvs: [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
          uv1s: uv1s,
          tangents: List.filled(4, Vector4(1, 0, 0, 1)),
        ),
      ),
    );
    final geo = doc.addResource(
      GeometryResource(
        doc.newId(),
        vertices: verts.id,
        indices: quadIndices.id,
        bounds: BoundsSpec(
          min: Vector3(-half, 0, -half),
          max: Vector3(half, 0, half),
        ),
      ),
    );
    // The quad's local frame is a face-up XZ plane; −90° about X turns
    // the +Y normal to −Z so the face fronts the authored camera.
    doc.createNode(
      name: name,
      transform: TrsTransform(
        translation: at,
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 2),
      ),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(geo.id),
            'material': ResourceRefValue(material.id),
          },
        ),
      ],
      root: true,
    );
  }

  LocalId sphereNode(String name, Vector3 at, MaterialResource material) {
    final geo = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: SphereGeometrySpec(radius: 0.45),
      ),
    );
    return doc
        .createNode(
          name: name,
          transform: TrsTransform(translation: at),
          components: [
            ComponentSpec(
              'mesh',
              properties: {
                'geometry': ResourceRefValue(geo.id),
                'material': ResourceRefValue(material.id),
              },
            ),
          ],
          root: true,
        )
        .id;
  }

  // ── Textures ────────────────────────────────────────────────────
  final checkerTex = doc.addResource(
    TextureResource(
      doc.newId(),
      payload: doc
          .addPayload(
            PayloadSpec(
              doc.newId(),
              encoding: PayloadEncoding.image,
              format: 'rgba8',
              width: texSize,
              height: texSize,
              length: texSize * texSize * 4,
              bytes: _checkerPixels(texSize, texSize),
            ),
          )
          .id,
    ),
  );
  final latticeTex = doc.addResource(
    TextureResource(
      doc.newId(),
      payload: doc
          .addPayload(
            PayloadSpec(
              doc.newId(),
              encoding: PayloadEncoding.image,
              format: 'rgba8',
              width: texSize,
              height: texSize,
              length: texSize * texSize * 4,
              bytes: _latticePixels(texSize, texSize),
            ),
          )
          .id,
    ),
  );

  // ── Materials + row layout ──────────────────────────────────────
  MaterialResource mat(
    Map<String, PropertyValue> properties,
  ) => doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: properties,
    ),
  );

  // Backdrop first — an opaque checker wall so the blend lane's
  // translucency composites against a pattern.
  meshQuad(
    name: 'materials.backdrop',
    at: Vector3(-1.1, 0.75, 0.55),
    half: 0.7,
    material: mat({
      'baseColor': ColorValue(1, 1, 1, 1),
      'baseColorTexture': ResourceRefValue(checkerTex.id),
      'roughness': DoubleValue(0.85),
      'doubleSided': BoolValue(true),
    }),
  );
  sphereNode(
    'materials.opaque',
    Vector3(-2.2, 0.5, 0),
    mat({
      'baseColor': ColorValue(0.9, 0.45, 0.15, 1.0),
      'roughness': DoubleValue(0.5),
    }),
  );
  sphereNode(
    'materials.blend',
    Vector3(-1.1, 0.55, 0),
    mat({
      'baseColor': ColorValue(0.25, 0.65, 1.0, 0.4),
      'alphaMode': StringValue('blend'),
      'roughness': DoubleValue(0.35),
    }),
  );
  meshQuad(
    name: 'materials.mask',
    at: Vector3(0, 0.55, 0),
    material: mat({
      'baseColor': ColorValue(1, 1, 1, 1),
      'baseColorTexture': ResourceRefValue(latticeTex.id),
      'alphaMode': StringValue('mask'),
      'alphaCutoff': DoubleValue(0.5),
      'doubleSided': BoolValue(true),
      'roughness': DoubleValue(0.8),
    }),
  );
  // The UV pair shares the two-UV-set geometry: uv0 covers the whole
  // checker while uv1 collapses to a point inside checker cell (1,0) —
  // an odd (dark) cell — so the texCoord:1 quad renders flat dark next
  // to texCoord:0's checker.
  final uv1s = List.filled(4, Vector2(0.19, 0.06));
  meshQuad(
    name: 'materials.uv0',
    at: Vector3(1.1, 0.55, 0),
    uv1s: uv1s,
    material: mat({
      'baseColor': ColorValue(1, 1, 1, 1),
      'baseColorTexture': ResourceRefValue(checkerTex.id),
      'baseColorTextureTransform': MapValue({
        'texCoord': IntValue(0),
      }),
      'doubleSided': BoolValue(true),
      'roughness': DoubleValue(0.8),
    }),
  );
  meshQuad(
    name: 'materials.uv1',
    at: Vector3(2.2, 0.55, 0),
    uv1s: uv1s,
    material: mat({
      'baseColor': ColorValue(1, 1, 1, 1),
      'baseColorTexture': ResourceRefValue(checkerTex.id),
      'baseColorTextureTransform': MapValue({
        'texCoord': IntValue(1),
      }),
      'doubleSided': BoolValue(true),
      'roughness': DoubleValue(0.8),
    }),
  );

  // ── KTX2 lane ─────────────────────────────────────────────────────
  // Platform-picked asset: Android decodes real ETC1S through gltfio;
  // iOS exercises its container-parse path with an uncompressed
  // vkFormat-37 file (supercompressed payloads warn-once there until a
  // transcoder ships). Missing bytes skip the node, not fake it.
  if (bytesOf != null) {
    final ktx2Bytes = bytesOf(
      Platform.isIOS
          ? 'assets/uncompressed_rgba8_64.ktx2'
          : 'assets/etc1s_srgb_mips_64.ktx2',
    );
    if (ktx2Bytes != null) {
      final ktx2Tex = doc.addResource(
        TextureResource(
          doc.newId(),
          payload: doc
              .addPayload(
                PayloadSpec(
                  doc.newId(),
                  encoding: PayloadEncoding.image,
                  format: 'ktx2',
                  bytes: ktx2Bytes,
                ),
              )
              .id,
        ),
      );
      meshQuad(
        name: 'materials.ktx2',
        at: Vector3(3.3, 0.55, 0),
        material: mat({
          'baseColor': ColorValue(1, 1, 1, 1),
          'baseColorTexture': ResourceRefValue(ktx2Tex.id),
          'doubleSided': BoolValue(true),
          'roughness': DoubleValue(0.8),
        }),
      );
    }

    // ── HDR environment lane ────────────────────────────────────────
    // iOS gets the EXR file (W21 decode lane); Android the .hdr
    // (pre-existing radiance path). 4×2 RGB is tiny but a real HDR
    // equirect — the row visibly re-lights under it. The .hdr's
    // saturated primaries run to 10.0: at Filament's 30 000 lx env
    // baseline Android authors the intensity down so the material
    // lanes stay readable under the colored IBL.
    final envBytes = bytesOf(
      Platform.isIOS ? 'assets/rgb_4x2.exr' : 'assets/rgb_4x2.hdr',
    );
    if (envBytes != null) {
      final envPayload = doc.addPayload(
        PayloadSpec(
          doc.newId(),
          encoding: PayloadEncoding.image,
          format: Platform.isIOS ? 'exr' : 'hdr',
          bytes: envBytes,
        ),
      );
      doc.stage.environmentRef = doc
          .addResource(
            EnvironmentResource(
              doc.newId(),
              environment: PayloadEnvironment(envPayload.id),
              environmentIntensity: Platform.isIOS ? 1.0 : 0.08,
              exposure: 1.0,
              toneMapping: 'pbrNeutral',
              skybox: SkyboxSpec(EnvironmentSkySpec()),
            ),
          )
          .id;
    }
  }
  return doc;
}

/// 8 px checkerboard as raw RGBA8 — near-white vs near-black cells,
/// matching feature_scene's `_checkerRgba` convention.
Uint8List _checkerPixels(int w, int h) {
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

/// Alpha-cutout lattice as raw RGBA8: 16 px cells whose centered
/// 10×10 px square is opaque leaf-green (a=255) on an alpha-0 grid —
/// the mask lane's "cut out at cutoff" pattern. Cell interiors vary
/// slightly in green so adjacent cells read as separate panels.
Uint8List _latticePixels(int w, int h) {
  const pitch = 16;
  const edge = 3; // transparent border half-width inside each cell
  final out = Uint8List(w * h * 4);
  var o = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final lx = x % pitch;
      final ly = y % pitch;
      final solid = lx >= edge && lx < pitch - edge && //
          ly >= edge && ly < pitch - edge;
      if (solid) {
        final cell = (x ~/ pitch) + (y ~/ pitch) * 7;
        out[o] = 0x30;
        out[o + 1] = 0x90 + (cell * 23 % 60);
        out[o + 2] = 0x38;
        out[o + 3] = 255;
      }
      o += 4;
    }
  }
  return out;
}

