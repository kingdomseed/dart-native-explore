library;

import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

final u3ProbeAtlas = TextureAtlas(
  columns: 2,
  rows: 2,
  tileSize: 16,
  padding: 2,
);
const u3AtlasCellNames = ['0 red', '1 green', '2 blue', '3 yellow'];

MapValue _frameTransform(int frame) {
  final bounds = u3ProbeAtlas.tileBounds(frame);
  return MapValue({
    'offset': Vec2Value(Vector2(bounds.x, bounds.y)),
    'scale': Vec2Value(Vector2(bounds.z - bounds.x, bounds.w - bounds.y)),
  });
}

SceneDocument buildU3AtlasProbeDocument() {
  final doc = SceneDocument(
    documentId: DocumentId(
      Uint8List.fromList([
        0x55,
        0x33,
        0x41,
        0x54,
        0x4c,
        0x41,
        0x53,
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
    allocator: IdAllocator(session: 0x75336174),
  );
  final pixels = generateSolidColorAtlasPixels(
    tileColors: [
      Vector4(1, 0, 0, 1),
      Vector4(0, 1, 0, 1),
      Vector4(0, 0, 1, 1),
      Vector4(1, 1, 0, 1),
    ],
    columns: u3ProbeAtlas.columns,
    tileSize: u3ProbeAtlas.tileSize,
    padding: u3ProbeAtlas.padding,
  );
  for (var frame = 0; frame < 4; frame++) {
    final x0 = frame % 2 * 20 + 2;
    final y0 = frame ~/ 2 * 20 + 2;
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final white =
            (x == 1 && y >= 1 && y <= 5) || (y == 1 && x >= 1 && x <= 4);
        final black = x >= 12 && x <= 13 && y >= 12 && y <= 13;
        if (white || black) {
          final p = ((y0 + y) * u3ProbeAtlas.width + x0 + x) * 4;
          pixels[p] = pixels[p + 1] = pixels[p + 2] = white ? 255 : 0;
        }
      }
    }
  }
  final image = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: u3ProbeAtlas.width,
      height: u3ProbeAtlas.height,
      length: pixels.length,
      bytes: pixels,
    ),
  );
  final texture = doc.addResource(
    TextureResource(doc.newId(), payload: image.id),
  );
  for (final (name, y) in [('sheet', 1.65), ('selected', -0.55)]) {
    final material = doc.addResource(
      MaterialResource(
        doc.newId(),
        name: 'u3.atlas.$name',
        type: 'unlit',
        properties: {
          'baseColor': const ColorValue(1, 1, 1, 1),
          'baseColorTexture': ResourceRefValue(texture.id),
          'doubleSided': const BoolValue(true),
          if (name == 'selected')
            'baseColorTextureTransform': _frameTransform(0),
        },
      ),
    );
    doc.createNode(
      name: 'u3.atlas.$name',
      transform: TrsTransform(translation: Vector3(0, y, 0)),
      components: [
        d3ProcMeshComponent(
          D3BillboardProc(size: Vector2(1.65, 1.65)),
          material: material.id,
        ),
      ],
      root: true,
    );
  }
  doc.createNode(
    name: 'u3.atlas.camera',
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
          toneMapping: 'linear',
          effects: EnvironmentEffectsSpec(),
        ),
      )
      .id;
  return doc;
}

int nextU3AtlasFrame(SceneController controller, SceneDocument doc, int frame) {
  final next = (frame + 1) % u3ProbeAtlas.tileCount;
  final material = doc.resources.values
      .whereType<MaterialResource>()
      .singleWhere((material) => material.name == 'u3.atlas.selected');
  material.properties['baseColorTextureTransform'] = _frameTransform(next);
  controller.applyCommands([
    {
      'op': 'upsertResource',
      'id': material.id.toToken(),
      'resource': encodeResource(material, (id) => id.toToken()),
    },
  ]);
  return next;
}
