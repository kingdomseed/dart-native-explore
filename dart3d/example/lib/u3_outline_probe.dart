import 'dart:typed_data';

// ignore_for_file: implementation_imports
import 'package:dart3d/src/geometry/instances.dart';
import 'package:dart3d/src/geometry/proc.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

const u3OutlineKey = 'builtin:u3-outline';
const u3BootTarget = String.fromEnvironment(
  'DART3D_U3_TARGET',
  defaultValue: 'skin',
);
const u3BootMode = String.fromEnvironment(
  'DART3D_U3_MODE',
  defaultValue: 'outline',
);
const u3BootFar = bool.fromEnvironment('DART3D_U3_FAR');
const u3BootMoving = bool.fromEnvironment('DART3D_U3_MOVING');
const u3BootPose = String.fromEnvironment(
  'DART3D_U3_POSE',
  defaultValue: '0.5',
);

SceneDocument buildU3OutlineProbe(SceneDocument doc) {
  for (final node in doc.nodes.values.toList()) {
    if ([
      'u1.target.procedural',
      'u1.target.d3proc',
      'u1.pick.marker',
    ].contains(node.name)) {
      doc.nodes.remove(node.id);
      doc.roots.remove(node.id);
    }
  }
  final payload = doc.nodes.values.singleWhere(
    (n) => n.name == 'u1.target.payload',
  );
  payload.name = 'u3.target.payload';
  payload.transform = TrsTransform(translation: Vector3(-2.3, 1.1, 0));
  final mesh = payload.components.single;
  final bar = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(1.55, 0.25, 0.35)),
    ),
  );
  payload.components[0] = ComponentSpec(
    'mesh',
    properties: {
      'primitives': ListValue([
        MapValue({
          'geometry': mesh.properties['geometry']!,
          'material': mesh.properties['material']!,
        }),
        MapValue({
          'geometry': ResourceRefValue(bar.id),
          'material': mesh.properties['material']!,
        }),
      ]),
    },
  );
  final skin = doc.nodes.values.singleWhere(
    (n) => n.name == 'u1.target.skinned',
  );
  skin.name = 'u3.target.skin';
  skin.transform = TrsTransform(translation: Vector3(0, 0.85, 0));
  final joint = doc.nodes.values.singleWhere((n) => n.name == 'u1.joint0');
  joint.transform = TrsTransform(translation: Vector3(0, 1.35, 0));
  final instances = doc.nodes.values.singleWhere(
    (n) => n.name == 'u1.target.instanced',
  );
  instances.name = 'u3.target.instances';
  instances.transform = TrsTransform(translation: Vector3(2.4, 1.1, 0));
  final material =
      instances.components.single.properties['material']! as ResourceRefValue;
  instances.components[0] = D3InstancesSpec(
    proc: D3WedgeProc(size: Vector3.all(0.13)),
    material: material.id,
    transforms: D3InstanceTransforms.inline([
      for (var i = 0; i < 130; i++)
        Matrix4.identity()
          ..setTranslationRaw((i % 13 - 6) * 0.17, (i ~/ 13 - 4.5) * 0.17, 0)
          ..scaleByDouble(i < 65 ? 1 : -1, 1, 1, 1),
    ]),
  ).toComponent();
  final blockerMaterial = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.18, 0.24, 0.29, 1),
        'roughness': const DoubleValue(0.6),
      },
    ),
  );
  final blocker = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(7.4, 0.20, 0.18)),
    ),
  );
  doc.createNode(
    name: 'u3.occluder',
    root: true,
    transform: TrsTransform(translation: Vector3(0, 1.2, -0.8)),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(blocker.id),
          'material': ResourceRefValue(blockerMaterial.id),
        },
      ),
    ],
  );
  PayloadSpec floats(List<double> values) {
    final bytes = Float32List.fromList(values).buffer.asUint8List();
    return doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.floats,
        length: bytes.length,
        bytes: bytes,
      ),
    );
  }

  final times = floats([0, 1, 2]);
  final keys = floats([0, 0.85, 0, 0.35, 1.65, 0, 0, 0.85, 0]);
  doc.addAnimation(
    AnimationSpec(
      doc.newId(),
      name: 'outline skin motion',
      channels: [
        AnimationChannelSpec(
          target: joint.id,
          property: AnimationProperty.translation,
          timeline: times.id,
          keyframes: keys.id,
        ),
      ],
    ),
  );
  doc.createNode(
    name: '__outline_probe__:$u3BootTarget:$u3BootMode',
    root: true,
  );
  doc.stage.environmentRef = doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          environment: const StudioEnvironment(),
          environmentIntensity: 0.78,
          skybox: SkyboxSpec(
            GradientSkySpec(
              zenithColor: Vector3.zero(),
              horizonColor: Vector3.zero(),
              groundColor: Vector3.zero(),
              sunColor: Vector3.zero(),
            ),
          ),
        ),
      )
      .id;
  return doc;
}
