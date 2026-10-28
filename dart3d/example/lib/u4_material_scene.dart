library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

const bool kBootU4Sheen = bool.fromEnvironment('DART3D_U4_SHEEN');

NodeSpec u4MaterialNode(SceneDocument doc, String name) =>
    doc.nodes.values.singleWhere((node) => node.name == 'u4.materials.$name');

/// Six cells, read left to right: shared pair, PBR/reference, alpha/snapshot.
SceneDocument buildU4MaterialDocument({bool sheen = kBootU4Sheen}) {
  final doc = SceneDocument(allocator: IdAllocator(session: 0x75346d));
  // Literal straight RGBA8 checker: every image alpha is opaque. TextureResource
  // has no image sampler field; retain the ordinary image filtering path.
  final image = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 2,
      height: 2,
      length: 16,
      bytes: Uint8List.fromList([
        255,
        255,
        255,
        255,
        96,
        96,
        96,
        255,
        96,
        96,
        96,
        255,
        255,
        255,
        255,
        255,
      ]),
    ),
  );
  final texture = doc.addResource(
    TextureResource(doc.newId(), payload: image.id),
  );
  final materials = <MaterialResource>[];
  for (final (name, type, color) in [
    ('shared', 'unlit', const ColorValue(0, 0, 0, 1)),
    ('pbr', 'physicallyBased', const ColorValue(0, 0, 0, 1)),
    ('reference', 'unlit', const ColorValue(1, 1, 1, 1)),
    ('alpha', 'unlit', const ColorValue(1, 0.25, 0.25, 0.25)),
  ]) {
    materials.add(
      doc.addResource(
        MaterialResource(
          doc.newId(),
          name: 'u4.materials.$name',
          type: type,
          properties: {
            'baseColor': color,
            'baseColorTexture': ResourceRefValue(texture.id),
            if (name == 'pbr') ...{
              'roughness': const DoubleValue(1),
              'metallic': const DoubleValue(0),
              if (sheen) ...{
                'alphaMode': const StringValue('BLEND'),
                'sheenColor': const ColorValue(1, 1, 1, 1),
                'sheenRoughness': const DoubleValue(1),
              },
            },
            if (name == 'alpha') 'alphaMode': const StringValue('BLEND'),
          },
        ),
      ),
    );
  }
  final backing = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'u4.materials.backing',
      type: 'unlit',
      properties: {'baseColor': const ColorValue(0.5, 0.5, 0.5, 1)},
    ),
  );
  final geometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(1.05, 1.05, 0.02)),
    ),
  );
  final frame = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(1.17, 1.17, 0.02)),
    ),
  );
  for (final (name, x, y, material) in [
    ('shared.canonical', -0.85, 2.85, materials[0]),
    ('shared.live', 0.85, 2.85, materials[0]),
    ('pbr', -0.85, 1.55, materials[1]),
    ('reference', 0.85, 1.55, materials[2]),
    ('alpha', -0.85, 0.25, materials[3]),
    ('snapshot', 0.85, 0.25, materials[0]),
  ]) {
    doc.createNode(
      name: 'u4.materials.$name',
      transform: TrsTransform(
        translation: Vector3(x, y, 0),
        rotation: name == 'pbr' && sheen
            ? Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 3)
            : Quaternion.identity(),
      ),
      components: [
        if (name == 'snapshot')
          D3InstancesSpec(
            geometry: geometry.id,
            material: material.id,
            transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
            doubleSided: true,
          ).toComponent()
        else
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(geometry.id),
              'material': ResourceRefValue(material.id),
            },
          ),
      ],
      root: true,
    );
    if (name == 'alpha' || name == 'snapshot' || (name == 'pbr' && sheen)) {
      doc.createNode(
        name: 'u4.materials.$name.backing',
        transform: TrsTransform(
          translation: Vector3(x, y, name == 'pbr' ? 0.65 : 0.06),
        ),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(frame.id),
              'material': ResourceRefValue(backing.id),
            },
          ),
        ],
        root: true,
      );
    }
  }
  doc.createNode(
    name: 'u4.materials.light',
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': const ColorValue(1, 1, 1, 1),
          'intensity': const DoubleValue(1),
          'castsShadow': const BoolValue(false),
        },
      ),
    ],
    root: true,
  );
  doc.createNode(
    name: 'u4.materials.camera',
    transform: TrsTransform(translation: Vector3(0, 0, -10)),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': const StringValue('perspective'),
          'fovRadiansY': DoubleValue(math.pi / 3),
          'near': const DoubleValue(0.1),
          'far': const DoubleValue(30),
        },
      ),
    ],
    root: true,
  );
  doc.stage.environmentRef = doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          name: 'u4.materials.empty',
          environment: const EmptyEnvironment(),
          environmentIntensity: 0,
          exposure: 1,
          toneMapping: 'linear',
          effects: EnvironmentEffectsSpec(),
        ),
      )
      .id;
  final payloads = <LocalId>[];
  for (final values in <List<double>>[
    [0, 2],
    [1, 0.25, 0.25, 1, 0.25, 0.25, 1, 1],
    [1, 0.25, 0.25, 0.25, 0.25, 0.25, 1, 0.75],
    if (sheen) [0, 0, 0, 0, 0, 0, 0, 1],
  ]) {
    final id = doc.newId();
    final bytes = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      bytes.setFloat32(i * 4, values[i], Endian.little);
    }
    doc.addPayload(
      PayloadSpec(
        id,
        encoding: PayloadEncoding.floats,
        bytes: bytes.buffer.asUint8List(),
      ),
    );
    payloads.add(id);
  }
  final clip = doc.newId();
  doc.animations[clip] = Dart3dAnimationSpec(
    clip,
    name: 'u4.materials',
    propertyChannels: [
      for (final (material, keyframes) in [
        (materials[0], payloads[1]),
        (materials[1], payloads[sheen ? 3 : 1]),
        (materials[3], payloads[2]),
      ])
        D3MaterialBaseColorChannel(
          material: material.id,
          timeline: payloads[0],
          keyframes: keyframes,
        ),
    ],
  );
  return doc;
}
