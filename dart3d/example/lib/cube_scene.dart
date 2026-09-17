import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

/// Builds the example scene: one die-sized cuboid, a camera, a key light,
/// and a ground plane — expressed as a `.fscene` document the way any
/// dart3d consumer would author it.
///
/// Coordinates are `.fscene` native: left-handed, +Y up, +Z forward,
/// meters. The camera sits at z = −4 looking down +Z toward the origin.
final class CubeScene {
  CubeScene._();

  /// The document and the ids the app needs to address afterwards.
  static ({SceneDocument document, LocalId die}) build() {
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
          'baseColor': ColorValue(0.18, 0.18, 0.22, 1.0),
          'metallic': DoubleValue(0.0),
          'roughness': DoubleValue(0.9),
        },
      ),
    );

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
        ),
        rigidBodyComponent(type: 'fixed'),
        physicsWorldComponent(gravity: Vector3(0, -9.8, 0)),
      ],
      root: true,
    );

    doc.createNode(
      name: 'camera',
      transform: TrsTransform(
        translation: Vector3(0, 2.2, -4.2),
        // Pitch down ~20° so the slab and the resting die sit in frame.
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.35),
      ),
      components: [
        ComponentSpec(
          'camera',
          properties: {
            'projection': StringValue('perspective'),
            'fovRadiansY': DoubleValue(0.9),
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
            'intensity': DoubleValue(60),
            'range': DoubleValue(12),
          },
        ),
      ],
      root: true,
    );

    return (document: doc, die: die.id);
  }
}
