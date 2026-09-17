/// The upstream-interchange lane: loads a `.fsceneb` artifact produced
/// by the upstream importer (`dart run flutter_scene:import` on the
/// glb sources in the tome_keeper project — the dice set bundled under
/// `assets/dice/`), then augments the foreign document in place with
/// a camera, lights, a studio environment and a physics ground sized
/// from the imported geometry's authored bounds.
///
/// The imported root also gets a dynamic `rigidBody` plus a
/// `convexHull` collider — the collider derives from the mesh's
/// payload-backed geometry through the deferred-shape path, so the
/// loaded die rolls under native physics on both platforms.
///
/// Augmented nodes mint their ids through the foreign document's own
/// allocator (`doc.createNode`), so they can't collide with the
/// importer's id space.
library;

import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart';

/// One loadable upstream asset: the cycler label plus its bundle key.
final class ImportedModel {
  /// Creates an entry pairing [label] with the bundled [assetKey].
  const ImportedModel(this.label, this.assetKey);

  /// The cycler's display label.
  final String label;

  /// The `dartnative: assets:` key, e.g. `assets/dice/scene.d6…fsceneb`.
  final String assetKey;
}

/// The bundled dice set — `flutter_scene_generated/` in tome_keeper,
/// converted from `assets/dice/*.glb` by the upstream importer.
const importedDice = [
  ImportedModel('d4', 'assets/dice/scene.d4.dbe53cde.fsceneb'),
  ImportedModel('d6', 'assets/dice/scene.d6.dbe505b8.fsceneb'),
  ImportedModel('d8', 'assets/dice/scene.d8.dbe51f72.fsceneb'),
  ImportedModel('d10t', 'assets/dice/scene.d10t.862039c2.fsceneb'),
  ImportedModel('d10u', 'assets/dice/scene.d10u.86203b0d.fsceneb'),
  ImportedModel('d12', 'assets/dice/scene.d12.a5cbecd0.fsceneb'),
  ImportedModel('d20', 'assets/dice/scene.d20.a5fdb0b1.fsceneb'),
];

/// Loads [model]'s `.fsceneb` bytes and returns the augmented document,
/// the imported mesh node's id (for the Roll button and watchdog), the
/// camera rig ([cameraNode] + [cameraOffset], the target→camera vector
/// whose length is the authored boom distance), and the bounds-derived
/// [center]/[radius] so callers can scale throws and probes to the
/// model's units.
/// Returns null when the asset isn't bundled or fails to decode.
({
  SceneDocument document,
  LocalId meshNode,
  LocalId cameraNode,
  Vector3 center,
  Vector3 cameraOffset,
  double radius,
})? loadImportedScene(
  ImportedModel model,
) {
  final bytes = loadAssetBytes(model.assetKey);
  if (bytes == null) {
    dnLog('dart3d: imported scene — missing asset ${model.assetKey}');
    return null;
  }
  final SceneDocument doc;
  try {
    doc = readFsceneb(bytes);
  } catch (error) {
    dnLog('dart3d: imported scene — ${model.assetKey} failed: $error');
    return null;
  }

  // The mesh-bearing node — the imported docs are single-root, but
  // find the component carrier rather than assuming the root holds it.
  NodeSpec? meshNode;
  for (final node in doc.nodes.values) {
    if (node.components.any((c) => c.type == 'mesh')) {
      meshNode = node;
      break;
    }
  }
  if (meshNode == null) {
    dnLog('dart3d: imported scene — ${model.assetKey} has no mesh node');
    return null;
  }

  // Frame from the union of the document's authored mesh bounds in
  // world space — the node's transform applies to its geometry's
  // local-space bounds. Content bounds skip floor-like slabs.
  final bounds = documentContentBounds(doc);
  if (bounds == null) {
    dnLog('dart3d: imported scene — ${model.assetKey} has no bounds');
    return null;
  }
  final (bmin, bmax) = bounds;
  final center = (bmin + bmax) * 0.5;
  final radius = (bmax - bmin).length * 0.5;

  // The imported mesh becomes a dynamic body resting on the slab.
  // Damping matches the dice table — light damping keeps the drop
  // lively at mm-scale gravity.
  meshNode.components.addAll([
    colliderComponent(
      shape: 'convexHull',
      friction: 0.5,
      restitution: 0.35,
    ),
    rigidBodyComponent(
      type: 'dynamic',
      mass: 1.0,
      linearDamping: 0.1,
      angularDamping: 0.2,
      ccdEnabled: true,
    ),
  ]);

  // Ground: a slab under the bounds' lowest point.
  final groundGeo = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(radius * 5, 0.5, radius * 5)),
    ),
  );
  final groundMat = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(0.16, 0.17, 0.19, 1),
        'roughness': DoubleValue(0.9),
        'metallic': DoubleValue(0.0),
      },
    ),
  );
  doc.createNode(
    name: 'ground',
    transform: TrsTransform(
      translation: Vector3(center.x, bmin.y - 0.5, center.z),
    ),
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
        extents: Vector3(radius * 5, 0.5, radius * 5),
        friction: 0.8,
        restitution: 0.16,
      ),
      rigidBodyComponent(type: 'fixed'),
      // Matches the dice table's screen-feel gravity — ~⅓ mm-scale so
      // a thrown die arcs instead of slamming.
      physicsWorldComponent(
        gravity: Vector3(0, -3600, 0),
        fixedTimestep: 1.0 / 120.0,
        maxSubsteps: 4,
      ),
    ],
    root: true,
  );

  // Camera + lights + studio environment — the injected support rig,
  // all minted in the document's own id space. The boom direction the
  // screen rewrites along is the authored target→camera vector.
  final cameraOffset = Vector3(0, radius * 0.85, -radius * 2.6);
  final camera = doc.createNode(
    name: 'camera',
    transform: TrsTransform(
      translation: Vector3(
        center.x,
        center.y + radius * 0.85,
        center.z - radius * 2.6,
      ),
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.32),
    ),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': StringValue('perspective'),
          'fovRadiansY': DoubleValue(0.9),
          'near': DoubleValue(max(radius * 0.02, 0.01)),
          'far': DoubleValue(radius * 40),
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
          'shadowRadius': DoubleValue(3.0),
          'shadowDepthBias': DoubleValue(0.005),
        },
      ),
    ],
    root: true,
  );
  doc.createNode(
    name: 'fill',
    transform: TrsTransform(
      translation: Vector3(center.x - radius * 2, center.y + radius * 2, center.z - radius),
    ),
    components: [
      ComponentSpec(
        'pointLight',
        properties: {
          'color': ColorValue(0.6, 0.7, 1.0, 1),
          'intensity': DoubleValue(900 * radius),
          'range': DoubleValue(radius * 20),
        },
      ),
    ],
    root: true,
  );
  doc.stage.environmentRef = doc
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

  dnLog(
    'dart3d: imported scene — ${model.label}: ${doc.nodes.length} nodes, '
    '${doc.payloads.length} payloads, bounds r=${radius.toStringAsFixed(2)}',
  );
  return (
    document: doc,
    meshNode: meshNode.id,
    cameraNode: camera.id,
    center: center,
    cameraOffset: cameraOffset,
    radius: radius,
  );
}
