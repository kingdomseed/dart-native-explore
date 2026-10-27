// ignore_for_file: implementation_imports
library;

import 'dart:typed_data';

import 'package:dart3d/src/geometry/instances.dart';
import 'package:dart3d/src/geometry/proc.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';

const String u2KeyLightName = 'u2.key';

enum U2LightMode { left, right }

SceneDocument buildU2GeometryDocument() {
  final doc = SceneDocument();

  MaterialResource material(
    double r,
    double g,
    double b, {
    double roughness = 0.58,
  }) => doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(r, g, b, 1),
        'roughness': DoubleValue(roughness),
        'metallic': const DoubleValue(0),
      },
    ),
  );

  void procNode(String name, Vector3 at, D3Proc proc, MaterialResource mat) {
    doc.createNode(
      name: name,
      transform: TrsTransform(translation: at),
      components: [d3ProcMeshComponent(proc, material: mat.id)],
      root: true,
    );
  }

  final groundMaterial = material(0.11, 0.12, 0.15, roughness: 0.92);
  procNode(
    'u2.ground',
    Vector3(0, 0, 0),
    D3PlaneProc(width: 3.15, depth: 3.15, segmentsX: 2, segmentsZ: 2),
    groundMaterial,
  );

  procNode(
    'u2.wedge',
    Vector3(-0.92, 0.02, 0.90),
    D3WedgeProc(size: Vector3(1.12, 0.92, 1.12)),
    material(0.96, 0.29, 0.12),
  );
  procNode(
    'u2.ring',
    Vector3(0.92, 0.045, 0.90),
    D3RingProc(innerRadius: 0.34, outerRadius: 0.66, segments: 48),
    material(0.08, 0.66, 0.80, roughness: 0.42),
  );

  final ccwProfile = [
    Vector2(-0.34, 0),
    Vector2(0.24, 0),
    Vector2(0.42, 0.22),
    Vector2(0.05, 0.45),
    Vector2(-0.26, 0.31),
  ];
  final extrudePoints = [
    Vector3(-0.58, 0, -0.12),
    Vector3(-0.24, 0, 0.20),
    Vector3(0.22, 0, -0.18),
    Vector3(0.58, 0, 0.14),
  ];
  procNode(
    'u2.extrude.ccw',
    Vector3(-0.92, 0.02, -0.24),
    D3ExtrudeProc(points: extrudePoints, profile: ccwProfile, stations: 24),
    material(0.59, 0.35, 0.91, roughness: 0.48),
  );
  procNode(
    'u2.extrude.cw',
    Vector3(0.92, 0.02, -0.24),
    D3ExtrudeProc(
      points: extrudePoints,
      profile: [...ccwProfile.reversed],
      stations: 24,
    ),
    material(0.98, 0.61, 0.14, roughness: 0.48),
  );

  final instanceMaterial = material(1, 1, 1, roughness: 0.48);
  doc.createNode(
    name: 'u2.instances',
    transform: TrsTransform(translation: Vector3(0, 0.02, -1.30)),
    components: [
      D3InstancesSpec(
        proc: D3WedgeProc(size: Vector3(0.68, 0.56, 0.72)),
        material: instanceMaterial.id,
        transforms: D3InstanceTransforms.inline([
          Matrix4.identity()
            ..setTranslationRaw(-0.42, 0, 0)
            ..scaleByDouble(0.72, 0.72, 0.72, 1),
          Matrix4.identity()
            ..setTranslationRaw(0.42, 0, 0)
            ..scaleByDouble(0.72, 0.72, 0.72, 1),
        ]),
        attributes: {
          'color': D3InstanceAttribute.inline([
            Vector4(1, 0.42, 0.18, 1),
            Vector4(0.16, 0.70, 0.98, 1),
          ]),
        },
      ).toComponent(),
    ],
    root: true,
  );

  doc.createNode(
    name: u2KeyLightName,
    transform: TrsTransform(rotation: _u2LightRotation(U2LightMode.left)),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': const ColorValue(1, 0.96, 0.90, 1),
          'intensity': const DoubleValue(0.85),
          'castsShadow': const BoolValue(false),
        },
      ),
    ],
    root: true,
  );

  final environment = doc.addResource(
    EnvironmentResource(
      doc.newId(),
      name: 'u2.environment',
      environment: const StudioEnvironment(),
      environmentIntensity: 0.42,
      exposure: 1,
      toneMapping: 'pbrNeutral',
      skybox: SkyboxSpec(EnvironmentSkySpec()),
    ),
  );
  doc.stage.environmentRef = environment.id;

  return doc;
}

SceneDocument buildU2ShadowDocument({required bool castsShadow}) {
  final doc = SceneDocument(
    documentId: DocumentId(
      Uint8List.fromList([
        0x55,
        0x32,
        0x53,
        0x48,
        0x41,
        0x44,
        0x4f,
        0x57,
        0x80,
        0x00,
        0x40,
        0x00,
        0x80,
        0x00,
        0x00,
        0x01,
      ]),
    ),
    allocator: IdAllocator(session: 0x75327368),
  );

  final receiverMaterial = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.48, 0.48, 0.48, 1),
        'roughness': const DoubleValue(0.92),
        'metallic': const DoubleValue(0),
      },
    ),
  );
  doc.createNode(
    name: 'u2.shadow.receiver',
    transform: TrsTransform(translation: Vector3.zero()),
    components: [
      d3ProcMeshComponent(
        D3PlaneProc(width: 4.2, depth: 4.2, segmentsX: 2, segmentsZ: 2),
        material: receiverMaterial.id,
      ),
    ],
    root: true,
  );

  final casterMaterial = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.82, 0.34, 0.12, 1),
        'roughness': const DoubleValue(0.56),
        'metallic': const DoubleValue(0),
      },
    ),
  );
  doc.createNode(
    name: 'u2.shadow.caster',
    transform: TrsTransform(translation: Vector3(0, 0.7, 0)),
    components: [
      d3ProcMeshComponent(
        D3CuboidProc(extents: Vector3(1.7, 1.4, 1.7)),
        material: casterMaterial.id,
      ),
    ],
    root: true,
  );

  final lightPosition = Vector3(-2, 5, 2);
  final lightTarget = Vector3.zero();
  doc.createNode(
    name: 'u2.shadow.spot',
    transform: TrsTransform(
      translation: lightPosition,
      rotation: aimAlong(lightTarget - lightPosition),
    ),
    components: [
      ComponentSpec(
        'spotLight',
        properties: {
          'color': const ColorValue(1, 1, 1, 1),
          'intensity': const DoubleValue(100),
          'range': const DoubleValue(12),
          // Android reads this vector; iOS uses the node's local -Z aim.
          'direction': Vec3Value(Vector3(0, 0, 1)),
          'innerConeAngle': const DoubleValue(0.25),
          'outerConeAngle': const DoubleValue(0.92),
          'castsShadow': BoolValue(castsShadow),
        },
      ),
    ],
    root: true,
  );

  final environment = doc.addResource(
    EnvironmentResource(
      doc.newId(),
      name: 'u2.shadow.environment',
      environment: const StudioEnvironment(),
      environmentIntensity: 0.22,
      exposure: 1,
      toneMapping: 'pbrNeutral',
      skybox: SkyboxSpec(EnvironmentSkySpec()),
    ),
  );
  doc.stage.environmentRef = environment.id;

  return doc;
}

({LocalId node, Quaternion rotation}) u2LightUpdate(
  SceneDocument doc,
  U2LightMode mode,
) {
  final node = doc.nodes.values.singleWhere(
    (candidate) => candidate.name == u2KeyLightName,
  );
  return (node: node.id, rotation: _u2LightRotation(mode));
}

Quaternion _u2LightRotation(U2LightMode mode) {
  final x = mode == U2LightMode.left ? 0.68 : -0.68;
  return aimAlong(Vector3(x, -0.70, 0.18));
}
