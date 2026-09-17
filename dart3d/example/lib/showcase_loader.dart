/// The showcase loader — pure Dart (no `dartnative` imports) so the
/// upstream-corpus decode + compose path is reachable under `dart
/// test`. The screen lives in `showcase_scene.dart`, which passes
/// `loadAssetBytes` and `dnLog` in through the parameters.
// ignore_for_file: implementation_imports
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/scene_model.dart';
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
];

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
  final bytes = bytesOf(item.assetKey);
  if (bytes == null) {
    log?.call('dart3d: showcase — missing asset ${item.assetKey}');
    return null;
  }
  SceneDocument doc;
  try {
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

