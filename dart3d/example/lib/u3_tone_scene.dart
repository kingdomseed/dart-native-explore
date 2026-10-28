library;

import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

enum U3Tone { pbrNeutral, aces, reinhard, linear, agx }

const kBootU3Tone = String.fromEnvironment(
  'DART3D_U3_TONE',
  defaultValue: 'pbrNeutral',
);

SceneDocument buildU3ToneDocument({U3Tone tone = U3Tone.pbrNeutral}) {
  final doc = SceneDocument(
    documentId: DocumentId(
      Uint8List.fromList([
        0x55,
        0x33,
        0x54,
        0x4f,
        0x4e,
        0x45,
        0,
        0,
        0x80,
        0,
        0x40,
        0,
        0x80,
        0,
        0,
        1,
      ]),
    ),
    allocator: IdAllocator(session: 0x7533746f),
  );
  final geometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(0.72, 0.72, 0.08)),
    ),
  );
  const grays = [0.018, 0.09, 0.18, 0.5, 1.0, 2.0, 4.0, 12.0];
  const colors = [
    ColorValue(1, 0.02, 0.02, 1),
    ColorValue(0.02, 1, 0.02, 1),
    ColorValue(0.02, 0.02, 1, 1),
    ColorValue(1, 0.25, 0.02, 1),
  ];
  for (var index = 0; index < 16; index++) {
    final strength = index < 8 ? grays[index] : (index < 12 ? 2.0 : 8.0);
    final color = index < 8 ? const ColorValue(1, 1, 1, 1) : colors[index % 4];
    final material = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': const ColorValue(0, 0, 0, 1),
          'metallic': const DoubleValue(0),
          'roughness': const DoubleValue(1),
          'emissive': color,
          'emissiveStrength': DoubleValue(strength),
        },
      ),
    );
    doc.createNode(
      name: index < 8
          ? 'u3.tone.gray.$strength'
          : 'u3.tone.color.${index % 4}.$strength',
      transform: TrsTransform(
        translation: Vector3(
          (index % 4 - 1.5) * 0.88,
          2.25 - index ~/ 4 * 0.9,
          0,
        ),
      ),
      components: [
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
  }
  doc.createNode(
    name: 'u3.tone.camera',
    transform: TrsTransform(translation: Vector3(0, 0, -10)),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': const StringValue('perspective'),
          'fovRadiansY': const DoubleValue(0.8),
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
          environment: const EmptyEnvironment(),
          environmentIntensity: 0,
          exposure: 1,
          toneMapping: tone.name,
          agxWhite: 16.29,
          agxContrast: 1.25,
          effects: EnvironmentEffectsSpec(),
        ),
      )
      .id;
  return doc;
}

U3Tone u3Tone(SceneDocument doc) => U3Tone.values.byName(
  (doc.resources[doc.stage.environmentRef]! as EnvironmentResource).toneMapping,
);

void selectU3Tone(SceneController controller, SceneDocument doc, U3Tone tone) {
  final environment =
      doc.resources[doc.stage.environmentRef]! as EnvironmentResource;
  environment.toneMapping = tone.name;
  controller.applyCommands([
    {
      'op': 'upsertResource',
      'id': environment.id.toToken(),
      'resource': encodeResource(environment, (id) => id.toToken()),
    },
  ]);
}
