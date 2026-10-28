import 'dart:convert';

import 'package:dart3d/dart3d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('public atlas API maps padded tiles from the top left in row order', () {
    final atlas = TextureAtlas(columns: 2, rows: 2, tileSize: 2, padding: 1);

    expect(atlas.tileCount, 4);
    expect(atlas.width, 8);
    expect(atlas.height, 8);
    expect(atlas.tileBounds(0).storage, [0.125, 0.125, 0.375, 0.375]);
    expect(atlas.tileBounds(1).storage, [0.625, 0.125, 0.875, 0.375]);
    expect(atlas.tileBounds(2).storage, [0.125, 0.625, 0.375, 0.875]);
    expect(atlas.tileBounds(3).storage, [0.625, 0.625, 0.875, 0.875]);
    expect(atlas.tileUv(3, 0.25, 0.75).storage, [0.6875, 0.8125]);
    expect(atlas.tileUv(0, 0, 0).storage, [0.125, 0.125]);
    expect(atlas.tileUv(3, 1, 1).storage, [0.875, 0.875]);
  });

  test('nonsquare atlas uses separate width and height with zero gutter', () {
    final atlas = TextureAtlas(columns: 4, rows: 2, tileSize: 3);

    expect(atlas.padding, 0);
    expect(atlas.tileCount, 8);
    expect(atlas.width, 12);
    expect(atlas.height, 6);
    expect(atlas.tileBounds(3).storage, [0.75, 0, 1, 0.5]);
    expect(atlas.tileBounds(4).storage, [0, 0.5, 0.25, 1]);
    expect(atlas.tileUv(6, 0.5, 0.5).storage, [0.625, 0.75]);
  });

  test('material maps serialize as existing scene texture references', () {
    final doc = SceneDocument();
    const colorId = LocalId(7, 1);
    const mrId = LocalId(7, 2);
    const normalId = LocalId(7, 3);
    const aoId = LocalId(7, 4);
    const materialId = LocalId(7, 5);
    final atlas = TextureAtlas(
      columns: 2,
      rows: 2,
      tileSize: 2,
      baseColor: colorId,
      metallicRoughness: mrId,
      normal: normalId,
      occlusion: aoId,
    );
    final material = atlas.toMaterial(materialId);

    expect(material.id, materialId);
    expect(doc.resources, isEmpty);
    doc.addResource(TextureResource(colorId, payload: const LocalId(7, 10)));
    doc.addResource(
      TextureResource(mrId, payload: const LocalId(7, 11), content: 'data'),
    );
    doc.addResource(
      TextureResource(
        normalId,
        payload: const LocalId(7, 12),
        content: 'normal',
      ),
    );
    doc.addResource(
      TextureResource(aoId, payload: const LocalId(7, 13), content: 'data'),
    );
    doc.addResource(material);
    final wire = jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
    final resources = wire['resources'] as Map<String, dynamic>;
    final encoded =
        resources['mat:${materialId.toToken()}'] as Map<String, dynamic>;
    expect(encoded['kind'], 'material');
    expect(encoded['type'], 'physicallyBased');
    expect(encoded['properties'], {
      'metallic': {'d': 1.0},
      'roughness': {'d': 1.0},
      'baseColorTexture': {'rref': 'tex:${colorId.toToken()}'},
      'metallicRoughnessTexture': {'rref': 'tex:${mrId.toToken()}'},
      'normalTexture': {'rref': 'tex:${normalId.toToken()}'},
      'occlusionTexture': {'rref': 'tex:${aoId.toToken()}'},
    });
    final decoded = readFscene(writeFscene(doc));
    final roundTrip = decoded.resources[materialId] as MaterialResource;
    expect(roundTrip.type, 'physicallyBased');
    expect(
      (roundTrip.properties['baseColorTexture'] as ResourceRefValue).id,
      colorId,
    );
    expect(writeFscene(decoded), writeFscene(doc));
  });

  test('optional maps are omitted and each material uses its supplied id', () {
    final atlas = TextureAtlas(columns: 1, rows: 1, tileSize: 1);
    final first = atlas.toMaterial(const LocalId(8, 1));
    final second = atlas.toMaterial(const LocalId(8, 2));

    expect(first.id, const LocalId(8, 1));
    expect(second.id, const LocalId(8, 2));
    expect(first.properties.keys, unorderedEquals(['metallic', 'roughness']));
    first.properties['alphaMode'] = const StringValue('blend');
    expect(second.properties, isNot(contains('alphaMode')));
  });

  test('RGBA pixels fill content and gutters, leaving the last cell clear', () {
    final pixels = generateSolidColorAtlasPixels(
      tileColors: [
        Vector4(1, 0.5, 0, 0.25),
        Vector4(-0.2, 1.2, 0.1, 1),
        Vector4(0, 0, 1, 0.5),
      ],
      columns: 2,
      tileSize: 1,
      padding: 1,
    );
    const topRow = [
      255,
      128,
      0,
      64,
      255,
      128,
      0,
      64,
      255,
      128,
      0,
      64,
      0,
      255,
      26,
      255,
      0,
      255,
      26,
      255,
      0,
      255,
      26,
      255,
    ];
    const bottomRow = [
      0,
      0,
      255,
      128,
      0,
      0,
      255,
      128,
      0,
      0,
      255,
      128,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ];
    expect(pixels.length, 144);
    expect(pixels, [
      ...topRow,
      ...topRow,
      ...topRow,
      ...bottomRow,
      ...bottomRow,
      ...bottomRow,
    ]);
  });

  test('unpadded pixels retain straight alpha and top-left row order', () {
    expect(
      generateSolidColorAtlasPixels(
        tileColors: [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 1)],
        columns: 1,
        tileSize: 1,
      ),
      [255, 0, 0, 0, 0, 255, 0, 255],
    );
    expect(
      generateSolidColorAtlasPixels(tileColors: [], columns: 2, tileSize: 2),
      isEmpty,
    );
  });
}
