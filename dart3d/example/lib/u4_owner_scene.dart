library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

NodeSpec u4OwnerNode(SceneDocument doc, String name) =>
    doc.nodes.values.singleWhere((node) => node.name == 'u4.owners.$name');

MaterialResource u4OwnerMaterial(SceneDocument doc, String name) => doc
    .resources
    .values
    .whereType<MaterialResource>()
    .singleWhere((material) => material.name == 'u4.owners.$name');

SceneDocument buildU4OwnerDocument() {
  final doc = SceneDocument(allocator: IdAllocator(session: 0x75346f));
  for (final (name, color) in [
    ('A', const ColorValue(1, 1, 1, 1)),
    ('B', const ColorValue(0, 1, 0, 1)),
    ('F', const ColorValue(1, 0.5, 0, 1)),
  ]) {
    doc.addResource(
      MaterialResource(
        doc.newId(),
        name: 'u4.owners.$name',
        type: 'unlit',
        properties: {'baseColor': color},
      ),
    );
  }
  final a = u4OwnerMaterial(doc, 'A');
  final b = u4OwnerMaterial(doc, 'B');
  final geometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(1, 1, 0.02)),
    ),
  );
  for (final (name, x) in [
    ('canonical', -1.2),
    ('default', 0.0),
    ('rebind', 1.2),
  ]) {
    doc.createNode(
      name: 'u4.owners.$name',
      transform: TrsTransform(translation: Vector3(x, 1.5, 0)),
      components: [
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
    name: 'u4.owners.variants',
    components: [
      ComponentSpec(
        'materialsVariants',
        properties: {
          'variants': ListValue([const StringValue('other')]),
          'bindings': ListValue([
            for (final name in ['default', 'rebind'])
              MapValue({
                'node': ResourceRefValue(u4OwnerNode(doc, name).id),
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
    name: 'u4.owners.camera',
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
          name: 'u4.owners.empty',
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
    name: 'u4.owners',
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

class U4OwnerControls {
  U4OwnerControls(this.controller, {this.log});

  final SceneController controller;
  final void Function(String)? log;

  void other() => _select('other');
  void defaults() => _select(null);

  void _select(String? variant) {
    final doc = controller.serializeScene()!;
    controller.selectMaterialVariant(u4OwnerNode(doc, 'variants').id, variant);
    log?.call('dart3d: u4-owners requested variant=${variant ?? "default"}');
  }

  void replaceA() {
    final doc = controller.serializeScene()!;
    final original = u4OwnerMaterial(doc, 'A');
    final replacement = MaterialResource(
      original.id,
      name: original.name,
      type: 'unlit',
      properties: {'baseColor': const ColorValue(0.2, 0.4, 0.6, 1)},
    );
    controller.applyCommands([
      {
        'op': 'upsertResource',
        'id': replacement.id.toToken(),
        'resource': encodeResource(replacement, (id) => id.toToken()),
      },
    ]);
    log?.call('dart3d: u4-owners requested Replace A rest=[.2,.4,.6,1]');
  }

  void rebindF() {
    final doc = controller.serializeScene()!;
    final node = u4OwnerNode(doc, 'rebind');
    node.components.single.properties['material'] = ResourceRefValue(
      u4OwnerMaterial(doc, 'F').id,
    );
    controller.applyCommands([
      {
        'op': 'updateNode',
        'node': node.id.toToken(),
        'flags': ['components'],
        'spec': encodeNodeCommandSpec(node, doc),
      },
    ]);
    log?.call('dart3d: u4-owners requested Rebind F');
  }
}
