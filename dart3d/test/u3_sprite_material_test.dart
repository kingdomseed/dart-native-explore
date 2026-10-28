import 'dart:convert';

import 'package:dart3d/dart3d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test(
    'public adapter has white alpha defaults and caller-owned fresh resources',
    () {
      final adapter = D3SpriteMaterial();
      final first = adapter.toResource(const LocalId(42, 1));
      final second = adapter.toResource(const LocalId(42, 2));
      expect(first.id, const LocalId(42, 1));
      expect(second.id, const LocalId(42, 2));
      expect(first.type, 'd3:sprite');
      expect(
        (encodeResource(first, (id) => id.toToken()) as Map)['properties'],
        {
          'baseColor': {
            'c': [1.0, 1.0, 1.0, 1.0],
          },
          'blendMode': {'s': 'alpha'},
        },
      );
      first.properties.clear();
      expect(
        second.properties.keys,
        unorderedEquals(['baseColor', 'blendMode']),
      );
    },
  );

  for (final blend in D3SpriteBlendMode.values) {
    for (final renderTexture in [false, true]) {
      test(
        '${blend.name} ${renderTexture ? "render" : "image"} ref survives real writer/reader',
        () {
          final doc = SceneDocument();
          const source = LocalId(42, 3);
          const materialId = LocalId(42, 4);
          doc.addResource(
            renderTexture
                ? RenderTextureResource(source, width: 16, height: 16)
                : TextureResource(source, payload: const LocalId(42, 5)),
          );
          final material = D3SpriteMaterial(
            colorTexture: source,
            tint: Vector4(0.25, 0.5, 0.75, 0.5),
            blendMode: blend,
            textureRect: Vector4(0.125, 0.25, 0.375, 0.75),
          ).toResource(materialId);
          doc.addResource(material);
          final wire = jsonDecode(writeFsceneWithExtensions(doc)) as Map;
          final encoded =
              wire['resources']['mat:${materialId.toToken()}'] as Map;
          expect(encoded['type'], 'd3:sprite');
          expect(encoded['properties'], {
            'baseColor': {
              'c': [0.25, 0.5, 0.75, 0.5],
            },
            'blendMode': {'s': blend.name},
            'baseColorTexture': {
              'rref': '${renderTexture ? "rt" : "tex"}:${source.toToken()}',
            },
            'baseColorTextureTransform': {
              'map': {
                'offset': {
                  'v2': [0.125, 0.25],
                },
                'scale': {
                  'v2': [0.25, 0.5],
                },
              },
            },
          });
          final decoded = readFsceneWithExtensions(
            writeFsceneWithExtensions(doc),
          );
          final loaded = decoded.resources[materialId] as MaterialResource;
          expect(loaded.type, 'd3:sprite');
          expect(
            (loaded.properties['baseColorTexture'] as ResourceRefValue).id,
            source,
          );
          final controller = SceneController()..loadDocument(decoded);
          addTearDown(controller.dispose);
          expect(
            writeFsceneWithExtensions(controller.document!),
            writeFsceneWithExtensions(doc),
          );
        },
      );
    }
  }

  test(
    'padded atlas supplies rect without changing geometry facing or allocating IDs',
    () {
      final atlas = TextureAtlas(columns: 2, rows: 2, tileSize: 2, padding: 1);
      final material = D3SpriteMaterial(
        textureRect: atlas.tileBounds(3),
      ).toResource(const LocalId(42, 6));
      expect(
        (encodeResource(material, (id) => id.toToken()) as Map)['properties'],
        {
          'baseColor': {
            'c': [1.0, 1.0, 1.0, 1.0],
          },
          'blendMode': {'s': 'alpha'},
          'baseColorTextureTransform': {
            'map': {
              'offset': {
                'v2': [0.625, 0.625],
              },
              'scale': {
                'v2': [0.25, 0.25],
              },
            },
          },
        },
      );
      for (final facing in ['spherical', 'axisY', 'screen']) {
        final component = d3ProcMeshComponent(
          D3BillboardProc(
            size: Vector2(2, 3),
            rotation: 0.5,
            facing: facing,
            color: const [0.2, 0.4, 0.6, 0.5],
          ),
          material: material.id,
        );
        expect(
          (component.properties['material'] as ResourceRefValue).id,
          material.id,
        );
        expect((component.properties['facing'] as StringValue).value, facing);
        expect((component.properties['rotation'] as DoubleValue).value, 0.5);
        expect(d3ProcComponentBounds(component), isNotNull);
      }
    },
  );
}
