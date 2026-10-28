import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';

const u3OutlineMarker = '__u3_outline_views_probe__';
const u3OutlineMesh = LocalId(0x75336f76, 1);
const u3OutlineBatch = LocalId(0x75336f76, 2);
const u3OutlineChild = LocalId(0x75336f76, 3);
const u3OutlineControl = LocalId(0x75336f76, 4);
const u3OutlineCameraA = LocalId(0x75336f76, 5);
const u3OutlineCameraB = LocalId(0x75336f76, 6);
const u3OutlineCameraTarget = LocalId(0x75336f76, 7);

enum U3OutlineMode { off, control, outline }

SceneDocument buildU3OutlineViewsDocument({
  bool single = false,
  bool targetMsaa = false,
  bool publishInUpdate = false,
  bool bindBeforeInstall = false,
  U3OutlineMode mode = U3OutlineMode.off,
}) {
  final doc = SceneDocument(allocator: IdAllocator(session: 0x75337072));
  final material = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'unlit',
      properties: {'baseColor': const ColorValue(0.36, 0.46, 0.62, 1)},
    ),
  );
  GeometryResource triangle(List<Vector3> positions) {
    final vertices = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        bytes: VertexPack.unskinned(
          positions: positions,
          normals: List.generate(3, (_) => Vector3(0, 0, -1)),
          uvs: [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)],
          colors: List.generate(3, (_) => Vector4.all(1)),
          tangents: List.generate(3, (_) => Vector4(1, 0, 0, -1)),
        ),
      ),
    );
    final indexData = ByteData(6)
      ..setUint16(0, 0, Endian.little)
      ..setUint16(2, 2, Endian.little)
      ..setUint16(4, 1, Endian.little);
    final indices = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        bytes: indexData.buffer.asUint8List(),
      ),
    );
    return doc.addResource(
      GeometryResource(doc.newId(), vertices: vertices.id, indices: indices.id),
    );
  }

  final lower = triangle([
    Vector3(-0.65, -0.5, 0),
    Vector3(0.6, -0.5, 0),
    Vector3(-0.65, 0.7, 0),
  ]);
  final wing = triangle([
    Vector3(-0.65, 0.7, 0),
    Vector3(0.6, -0.5, 0),
    Vector3(0.95, 0.2, 0.55),
  ]);
  doc.addNode(
    NodeSpec(
      id: u3OutlineMesh,
      name: 'outline.asymmetric',
      transform: TrsTransform(translation: Vector3(-0.85, 0.2, 0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'primitives': ListValue([
              for (final geometry in [lower, wing])
                MapValue({
                  'geometry': ResourceRefValue(geometry.id),
                  'material': ResourceRefValue(material.id),
                }),
            ]),
          },
        ),
      ],
      children: [u3OutlineChild],
    ),
  );
  doc.roots.add(u3OutlineMesh);
  doc.addNode(
    NodeSpec(
      id: u3OutlineChild,
      name: 'outline.authored-child-unselected',
      transform: TrsTransform(translation: Vector3(0, 1.1, 0)),
      components: [
        d3ProcMeshComponent(
          D3CuboidProc(extents: Vector3(0.3, 0.3, 0.3)),
          material: material.id,
        ),
      ],
    ),
  );
  doc.addNode(
    NodeSpec(
      id: u3OutlineBatch,
      name: 'outline.native-batch',
      layers: 2,
      transform: TrsTransform(translation: Vector3(0.9, -0.4, 0.3)),
      components: [
        D3InstancesSpec(
          proc: D3WedgeProc(size: Vector3(0.5, 0.7, 0.45)),
          material: material.id,
          transforms: D3InstanceTransforms.inline([
            Matrix4.identity()..setTranslationRaw(-0.4, 0, 0),
            Matrix4.identity()..setTranslationRaw(0.45, 0.3, 0.5),
            Matrix4.identity()..setTranslationRaw(0, -0.6, -0.4),
          ]),
        ).toComponent(),
      ],
    ),
  );
  doc.roots.add(u3OutlineBatch);
  doc.addNode(
    NodeSpec(
      id: u3OutlineControl,
      name: u3OutlineMarker,
      transform: TrsTransform(
        translation: Vector3(mode.index.toDouble(), 0, publishInUpdate ? 1 : 0),
        scale: Vector3(bindBeforeInstall ? 2 : 1, 1, 1),
      ),
    ),
  );
  doc.roots.add(u3OutlineControl);
  for (final (id, position) in [
    (u3OutlineCameraA, Vector3(0, 0.2, -6)),
    (u3OutlineCameraB, Vector3(4.2, 2.4, -4.2)),
    (u3OutlineCameraTarget, Vector3(-3, 1.2, -5)),
  ]) {
    doc.addNode(
      NodeSpec(
        id: id,
        name: 'outline.camera.${id.index}',
        transform: TrsTransform(
          translation: position,
          rotation: aimAlong(Vector3(0, 0.2, 0) - position),
        ),
        components: [
          ComponentSpec(
            'camera',
            properties: {
              'projection': const StringValue('orthographic'),
              'orthoScale': const DoubleValue(3.8),
              'near': const DoubleValue(0.1),
              'far': const DoubleValue(30),
            },
          ),
        ],
      ),
    );
    doc.roots.add(id);
  }
  final target = doc.addResource(
    RenderTextureResource(doc.newId(), width: 96, height: 72, update: 'manual'),
  );
  doc.views.addAll([
    RenderViewSpec(
      cameraNode: u3OutlineCameraTarget,
      target: target.id,
      layerMask: 3,
      antiAliasingMode: targetMsaa ? 'msaa' : 'none',
    ),
    Dart3dRenderViewSpec(
      cameraNode: u3OutlineCameraA,
      layerMask: 3,
      antiAliasingMode: 'none',
      renderScale: 1,
      viewport: single ? null : [0, 0, 570, 570],
    ),
    if (!single)
      Dart3dRenderViewSpec(
        cameraNode: u3OutlineCameraB,
        layerMask: 1,
        antiAliasingMode: 'none',
        renderScale: 1,
        order: 1,
        viewport: [590, 140, 380, 430],
      ),
  ]);
  PayloadSpec floats(List<double> values) {
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      data.setFloat32(i * 4, values[i], Endian.little);
    }
    return doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.floats,
        bytes: data.buffer.asUint8List(),
      ),
    );
  }

  final times = floats([0, 1.5, 3]);
  final positions = floats([-0.85, 0.2, 0, -0.35, 0.7, 0.3, -0.85, 0.2, 0]);
  doc.addAnimation(
    AnimationSpec(
      doc.newId(),
      name: 'outline.native-motion',
      channels: [
        AnimationChannelSpec(
          target: u3OutlineMesh,
          property: AnimationProperty.translation,
          timeline: times.id,
          keyframes: positions.id,
        ),
      ],
    ),
  );
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

void setU3OutlineColors(SceneController controller) =>
    controller.setNodeHighlights({
      u3OutlineMesh: Vector4(1, 0.25, 0.0625, 0),
      u3OutlineBatch: Vector4(0.0625, 0.5, 1, 0.5),
    });

void clearU3OutlineColors(SceneController controller) =>
    controller.setNodeHighlights({u3OutlineMesh: null, u3OutlineBatch: null});

void setU3OutlineMode(
  SceneController controller,
  U3OutlineMode mode, {
  required bool cameraB,
  bool publishInUpdate = false,
  bool bindBeforeInstall = false,
}) => controller.setNodeTransforms([
  NodeTransform(
    u3OutlineControl,
    translation: Vector3(
      mode.index.toDouble(),
      cameraB ? 1 : 0,
      publishInUpdate ? 1 : 0,
    ),
    scale: bindBeforeInstall ? Vector3(2, 1, 1) : null,
  ),
]);

void setU3OutlineCameraPose(
  SceneController controller, {
  required bool alternate,
  bool single = false,
}) {
  final position = alternate
      ? Vector3(2.2, 1.7, -5.2)
      : single
      ? Vector3(0, 0.2, -6)
      : Vector3(4.2, 2.4, -4.2);
  controller.setNodeTransforms([
    NodeTransform(
      single ? u3OutlineCameraA : u3OutlineCameraB,
      translation: position,
      rotation: aimAlong(Vector3(0, 0.2, 0) - position),
    ),
  ]);
}
