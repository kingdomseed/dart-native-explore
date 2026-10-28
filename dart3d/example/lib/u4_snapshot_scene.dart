library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

NodeSpec u4SnapshotNode(SceneDocument doc, String name) =>
    doc.nodes.values.singleWhere((node) => node.name == 'u4.snapshots.$name');

MaterialResource u4SnapshotMaterial(SceneDocument doc, String name) => doc
    .resources
    .values
    .whereType<MaterialResource>()
    .singleWhere((material) => material.name == 'u4.snapshots.$name');

enum U4SnapshotTexture { t1, t2 }

TextureResource u4SnapshotTexture(
  SceneDocument doc,
  U4SnapshotTexture texture,
) => doc.resources.values.whereType<TextureResource>().elementAt(texture.index);

SceneDocument buildU4SnapshotDocument() {
  final doc = SceneDocument(allocator: IdAllocator(session: 0x753473));
  final textures = <TextureResource>[];
  for (final _ in U4SnapshotTexture.values) {
    final image = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: 2,
        height: 2,
        length: 16,
      ),
    );
    textures.add(
      doc.addResource(TextureResource(doc.newId(), payload: image.id)),
    );
  }
  for (final (name, color) in [
    ('A', const ColorValue(1, 1, 1, 1)),
    ('B', const ColorValue(0, 1, 0, 1)),
  ]) {
    doc.addResource(
      MaterialResource(
        doc.newId(),
        name: 'u4.snapshots.$name',
        type: 'unlit',
        properties: {
          'baseColor': color,
          if (name == 'A') 'baseColorTexture': ResourceRefValue(textures[0].id),
        },
      ),
    );
  }
  final a = u4SnapshotMaterial(doc, 'A');
  final b = u4SnapshotMaterial(doc, 'B');
  final geometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(1, 1, 0.02)),
    ),
  );
  for (final (name, x) in [('current', -0.7), ('snapshot', 0.7)]) {
    doc.createNode(
      name: 'u4.snapshots.$name',
      transform: TrsTransform(translation: Vector3(x, 1.5, 0)),
      components: [
        if (name == 'snapshot')
          D3InstancesSpec(
            geometry: geometry.id,
            material: a.id,
            transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
            doubleSided: true,
          ).toComponent()
        else
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(geometry.id),
              'material': ResourceRefValue(a.id),
            },
          ),
      ],
      root: true,
    );
  }
  doc.createNode(
    name: 'u4.snapshots.variants',
    components: [
      ComponentSpec(
        'materialsVariants',
        properties: {
          'variants': ListValue([const StringValue('other')]),
          'bindings': ListValue([
            MapValue({
              'node': ResourceRefValue(u4SnapshotNode(doc, 'snapshot').id),
              'primitive': const IntValue(0),
              'default': ResourceRefValue(a.id),
              'materials': MapValue({'0': ResourceRefValue(b.id)}),
            }),
          ]),
        },
      ),
    ],
    root: true,
  );
  doc.createNode(
    name: 'u4.snapshots.camera',
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
          name: 'u4.snapshots.empty',
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
    [1, 0, 0, 1, 0, 0, 1, 1],
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
    name: 'u4.snapshots',
    propertyChannels: [
      D3MaterialBaseColorChannel(
        material: a.id,
        timeline: payloads[0],
        keyframes: payloads[1],
      ),
    ],
  );
  return doc;
}

class U4SnapshotControls {
  U4SnapshotControls(this.controller, {this.log});

  final SceneController controller;
  final void Function(String)? log;

  void other() => _select('other');
  void defaults() => _select(null);

  void _select(String? variant) {
    final doc = controller.serializeScene()!;
    controller.selectMaterialVariant(
      u4SnapshotNode(doc, 'variants').id,
      variant,
    );
    log?.call('dart3d: u4-snapshots requested variant=${variant ?? "default"}');
  }

  void spriteRefresh() {
    final doc = controller.serializeScene()!;
    final original = u4SnapshotMaterial(doc, 'A');
    final sprite = D3SpriteMaterial(
      colorTexture: u4SnapshotTexture(doc, U4SnapshotTexture.t2).id,
      tint: Vector4(0.2, 0.4, 0.6, 1),
    ).toResource(original.id);
    final replacement = MaterialResource(
      original.id,
      name: original.name,
      type: sprite.type,
      properties: sprite.properties,
    );
    controller.applyCommands([
      {
        'op': 'upsertResource',
        'id': replacement.id.toToken(),
        'resource': encodeResource(replacement, (id) => id.toToken()),
      },
    ]);
    log?.call(
      'dart3d: u4-snapshots requested Sprite refresh rest=[.2,.4,.6,1] T2',
    );
  }

  void texture1() => _upsertTexturePayload(U4SnapshotTexture.t1, const [
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
  ]);

  void texture2() => _upsertTexturePayload(U4SnapshotTexture.t2, const [
    64,
    64,
    64,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    64,
    64,
    64,
    255,
  ]);

  void _upsertTexturePayload(U4SnapshotTexture texture, List<int> pixels) {
    final doc = controller.serializeScene()!;
    final payload = doc.payloads[u4SnapshotTexture(doc, texture).payload]!;
    controller.applyCommands([
      {
        'op': 'upsertPayload',
        'id': payload.id.toToken(),
        'encoding': payload.encoding.name,
        'format': payload.format,
        'width': payload.width,
        'height': payload.height,
        'length': payload.length,
        'bytes': pixels,
      },
    ]);
    log?.call('dart3d: u4-snapshots requested Texture ${texture.index + 1}');
  }
}
