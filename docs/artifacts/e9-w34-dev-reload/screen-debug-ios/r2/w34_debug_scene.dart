import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

SceneDocument buildW34DebugDocument() {
  final doc = SceneDocument(allocator: IdAllocator(session: 0x7734696f));
  final vertices = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.vertexBuffer,
      layout: 'unskinned_uv1_tangent',
      bytes: VertexPack.unskinned(
        positions: [
          Vector3(-1, -1, 0),
          Vector3(1, -1, 0),
          Vector3(1, 1, 0),
          Vector3(-1, 1, 0),
        ],
        normals: List.generate(4, (_) => Vector3(0, 0, -1)),
        uvs: [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
        colors: List.generate(4, (_) => Vector4(0.8, 1, 0.6, 1)),
        tangents: List.generate(4, (_) => Vector4(1, 0, 0, -1)),
      ),
    ),
  );
  final indexBytes = ByteData(12);
  for (final (i, index) in [0, 2, 1, 0, 3, 2].indexed) {
    indexBytes.setUint16(i * 2, index, Endian.little);
  }
  final indices = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: 'uint16',
      bytes: indexBytes.buffer.asUint8List(),
    ),
  );
  final quad = doc.addResource(
    GeometryResource(doc.newId(), vertices: vertices.id, indices: indices.id),
  );
  final normalBytes = Uint8List.fromList([
    for (var y = 0; y < 64; y++)
      for (var x = 0; x < 64; x++)
        ...(y < 24
            ? (x < 40 ? [128, 128, 255, 255] : [218, 128, 218, 255])
            : (x < 20 ? [128, 37, 218, 255] : [54, 201, 201, 255])),
  ]);
  final normalPayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 64,
      height: 64,
      length: normalBytes.length,
      bytes: normalBytes,
    ),
  );
  final normal = doc.addResource(
    TextureResource(doc.newId(), payload: normalPayload.id, content: 'normal'),
  );
  final mrPayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 2,
      height: 2,
      length: 16,
      bytes: Uint8List.fromList([
        255,
        64,
        32,
        255,
        255,
        128,
        192,
        255,
        255,
        192,
        128,
        255,
        255,
        255,
        255,
        255,
      ]),
    ),
  );
  final mr = doc.addResource(
    TextureResource(doc.newId(), payload: mrPayload.id, content: 'data'),
  );
  final baseBytes = Uint8List.fromList([
    for (var y = 0; y < 64; y++)
      for (var x = 0; x < 64; x++) ...[
        x < 32 ? 255 : 160,
        y < 32 ? 200 : 255,
        220,
        x < 16 ? 0 : (x < 32 ? 128 : 255),
      ],
  ]);
  final basePayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 64,
      height: 64,
      length: baseBytes.length,
      bytes: baseBytes,
    ),
  );
  final base = doc.addResource(
    TextureResource(doc.newId(), payload: basePayload.id),
  );
  final material = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'w34.mapped',
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.65, 0.42, 0.2, 1),
        'baseColorTexture': ResourceRefValue(base.id),
        'metallic': const DoubleValue(0.7),
        'roughness': const DoubleValue(0.6),
        'metallicRoughnessTexture': ResourceRefValue(mr.id),
        'normalTexture': ResourceRefValue(normal.id),
        'normalScale': const DoubleValue(1),
        'normalTextureTransform': MapValue({
          'offset': Vec2Value(Vector2(0.1, 0.08)),
          'scale': Vec2Value(Vector2(0.8, 0.84)),
          'rotation': const DoubleValue(0.13),
          'texCoord': const IntValue(0),
        }),
        'alphaMode': const StringValue('opaque'),
        'alphaCutoff': const DoubleValue(0.5),
      },
    ),
  );
  doc.createNode(
    name: 'w34.quad',
    root: true,
    transform: TrsTransform(
      translation: Vector3(0, 1.1, 0),
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.18),
      scale: Vector3.all(0.88),
    ),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(quad.id),
          'material': ResourceRefValue(material.id),
        },
      ),
    ],
  );
  final occluderMaterial = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'w34.occluder',
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.1, 0.3, 0.7, 1),
        'roughness': const DoubleValue(0.5),
        'metallic': const DoubleValue(0),
      },
    ),
  );
  doc.createNode(
    name: 'w34.occluder',
    root: true,
    transform: TrsTransform(translation: Vector3(0.35, 1.05, -0.4)),
    components: [
      d3ProcMeshComponent(
        D3CuboidProc(extents: Vector3(0.35, 0.75, 0.12)),
        material: occluderMaterial.id,
      ),
    ],
  );
  for (final (index, value) in [0.125, 0.5, 0.875].indexed) {
    final literal = doc.addResource(
      MaterialResource(
        doc.newId(),
        name: 'w34.literal.$value',
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(value, value, value, 1),
          'metallic': DoubleValue(value),
          'roughness': DoubleValue(value),
        },
      ),
    );
    doc.createNode(
      name: 'w34.literal.$value',
      root: true,
      transform: TrsTransform(
        translation: Vector3((index - 1) * 0.62, -0.25, 0),
      ),
      components: [
        d3ProcMeshComponent(
          D3CuboidProc(extents: Vector3(0.48, 0.3, 0.04)),
          material: literal.id,
        ),
      ],
    );
  }
  final camera = doc.createNode(
    name: 'w34.camera',
    root: true,
    transform: TrsTransform(translation: Vector3(0, 0, -5)),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': const StringValue('orthographic'),
          'orthoScale': const DoubleValue(2.6),
          'near': const DoubleValue(0.1),
          'far': const DoubleValue(20),
        },
      ),
    ],
  );
  doc.createNode(
    name: 'w34.light',
    root: true,
    transform: TrsTransform(
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), -0.4),
    ),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': const ColorValue(1, 1, 1, 1),
          'intensity': const DoubleValue(2),
          'castsShadow': const BoolValue(false),
        },
      ),
    ],
  );
  final target = doc.addResource(
    RenderTextureResource(
      doc.newId(),
      width: 512,
      height: 512,
      update: 'manual',
    ),
  );
  final monitorMaterial = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'w34.authoredTarget',
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(1, 1, 1, 1),
        'baseColorTexture': ResourceRefValue(target.id),
        'metallic': const DoubleValue(0),
        'roughness': const DoubleValue(1),
      },
    ),
  );
  final monitor = doc.createNode(
    name: 'w34.authoredTarget',
    root: true,
    transform: TrsTransform(translation: Vector3(0, -1.5, 0)),
    components: [
      d3ProcMeshComponent(
        D3CuboidProc(extents: Vector3(1.7, 1.7, 0.04)),
        material: monitorMaterial.id,
      ),
    ],
  );
  monitor.layers = 2;
  doc.views.addAll([
    RenderViewSpec(cameraNode: camera.id, target: target.id, layerMask: 1),
    RenderViewSpec(cameraNode: camera.id, layerMask: 3),
  ]);
  doc.stage.environmentRef = doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          environment: const EmptyEnvironment(),
          environmentIntensity: 0,
          exposure: 1,
          toneMapping: 'linear',
          effects: EnvironmentEffectsSpec(),
        ),
      )
      .id;
  return doc;
}

void editW34DebugMaterial(
  SceneController controller,
  SceneDocument document, {
  required bool edited,
  String coverage = 'opaque',
}) {
  final material = document.resources.values
      .whereType<MaterialResource>()
      .singleWhere((material) => material.name == 'w34.mapped');
  material.properties.addAll({
    'baseColor': edited
        ? const ColorValue(0.18, 0.7, 0.4, 1)
        : const ColorValue(0.65, 0.42, 0.2, 1),
    'metallic': DoubleValue(edited ? 0.25 : 0.7),
    'roughness': DoubleValue(edited ? 0.9 : 0.6),
    'normalScale': DoubleValue(edited ? 0.35 : 1),
    'alphaMode': StringValue(coverage),
  });
  controller.applyCommands([
    {
      'op': 'upsertResource',
      'id': material.id.toToken(),
      'resource': encodeResource(material, (id) => id.toToken()),
    },
  ]);
}
