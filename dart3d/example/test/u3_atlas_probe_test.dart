// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u3_atlas_probe.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

ShowcaseScene load({void Function(String)? log}) => loadShowcaseScene(
  showcaseItems.singleWhere((item) => item.label == 'u3-atlas-probe'),
  log: log,
)!;

Map stable(SceneDocument doc) {
  final wire = jsonDecode(writeFsceneWithExtensions(doc)) as Map;
  for (final resource in (wire['resources'] as Map).values.cast<Map>()) {
    if (resource['name'] == 'u3.atlas.selected') {
      (resource['properties'] as Map).remove('baseColorTextureTransform');
    }
  }
  return wire;
}

void main() {
  test(
    'public route fixes camera and independent unlit billboard inventory',
    () {
      expect(AppRoute.boot(model: 'u3-atlas-probe').screen, AppScreen.showcase);
      final logs = <String>[];
      final scene = load(log: logs.add);
      final doc = scene.document;
      expect(
        logs.single,
        contains('frame=0 expected=0 red paused fixed-camera'),
      );
      expect(scene.frameRadius, 0);
      expect(doc.nodes.values.map((n) => n.name), [
        'u3.atlas.sheet',
        'u3.atlas.selected',
        'u3.atlas.camera',
      ]);
      expect(doc.resources, hasLength(4));
      expect(doc.payloads, hasLength(1));
      final materials = doc.resources.values
          .whereType<MaterialResource>()
          .toList();
      expect(materials, hasLength(2));
      expect(materials.map((m) => m.type), ['unlit', 'unlit']);
      expect(materials[0].id, isNot(materials[1].id));
      final texture = doc.resources.values.whereType<TextureResource>().single;
      for (final material in materials) {
        final props =
            (encodeResource(material, (id) => id.toToken())
                    as Map)['properties']
                as Map;
        expect(props['baseColorTexture'], {'rref': texture.id.toToken()});
        expect(props['doubleSided'], {'b': true});
      }
      expect(
        materials[0].properties.containsKey('baseColorTextureTransform'),
        isFalse,
      );
      for (final (index, node) in doc.nodes.values.take(2).indexed) {
        expect(node.components, hasLength(1));
        final component = node.components.single;
        expect(component.type, 'd3:procMesh');
        expect(component.properties.containsKey('doubleSided'), isFalse);
        expect(
          (component.properties['shape'] as StringValue).value,
          'billboard',
        );
        expect((component.properties['size'] as Vec2Value).value.storage, [
          closeTo(1.65, 0.000001),
          closeTo(1.65, 0.000001),
        ]);
        expect(
          (component.properties['material'] as ResourceRefValue).id,
          materials[index].id,
        );
      }
      final encoded = writeFsceneWithExtensions(doc);
      expect(encoded, contains('billboard'));
      expect(encoded, isNot(contains('Light')));
      final camera = doc.nodes[scene.cameraNode]!;
      expect(camera.name, 'u3.atlas.camera');
      expect((camera.transform as TrsTransform).translation.storage, [
        0,
        0,
        -10,
      ]);
      expect(
        (camera.components.single.properties['fovRadiansY'] as DoubleValue)
            .value,
        0.8,
      );
      expect(stable(load().document), stable(doc));
    },
  );

  test(
    'image is a deterministic padded top-left RGBA grid with asymmetric marks',
    () {
      final doc = load().document;
      final image = doc.payloads.values.single;
      expect(image.encoding, PayloadEncoding.image);
      expect(image.format, 'rgba8');
      expect([image.width, image.height, image.length], [40, 40, 6400]);
      expect(
        doc.resources.values.whereType<TextureResource>().single.payload,
        image.id,
      );
      expect(image.bytes, load().document.payloads.values.single.bytes);
      List<int> pixel(int x, int y) =>
          image.bytes!.sublist((y * 40 + x) * 4, (y * 40 + x) * 4 + 4);
      const colors = [
        [255, 0, 0, 255],
        [0, 255, 0, 255],
        [0, 0, 255, 255],
        [255, 255, 0, 255],
      ];
      for (var i = 0; i < 4; i++) {
        final x = i % 2 * 20;
        final y = i ~/ 2 * 20;
        expect(pixel(x, y), colors[i]);
        expect(pixel(x + 19, y + 19), colors[i]);
        expect(pixel(x + 10, y + 10), colors[i]);
        expect(pixel(x + 3, y + 3), [255, 255, 255, 255]);
        expect(pixel(x + 6, y + 3), [255, 255, 255, 255]);
        expect(pixel(x + 3, y + 7), [255, 255, 255, 255]);
        expect(pixel(x + 14, y + 14), [0, 0, 0, 255]);
        expect(pixel(x + 15, y + 15), [0, 0, 0, 255]);
        expect(pixel(x + 6, y + 7), colors[i]);
      }
    },
  );

  test(
    'next emits exact material transforms, wraps and preserves all other state',
    () {
      final doc = load().document;
      final baseline = stable(doc);
      final pixels = Uint8List.fromList(doc.payloads.values.single.bytes!);
      final selected = doc.resources.values
          .whereType<MaterialResource>()
          .singleWhere((m) => m.name == 'u3.atlas.selected');
      final controller = SceneController()..loadDocument(doc);
      final element = RecordingElement(controller);
      controller.attachElement(element);
      addTearDown(controller.dispose);
      element.mutations.clear();
      expect(
        ((encodeResource(selected, (id) => id.toToken()) as Map)['properties']
            as Map)['baseColorTextureTransform'],
        {
          'map': {
            'offset': {
              'v2': [0.05000000074505806, 0.05000000074505806],
            },
            'scale': {
              'v2': [0.3999999761581421, 0.3999999761581421],
            },
          },
        },
      );
      var frame = 0;
      for (final (expected, u, v) in [
        (1, 0.550000011920929, 0.05000000074505806),
        (2, 0.05000000074505806, 0.550000011920929),
        (3, 0.550000011920929, 0.550000011920929),
        (0, 0.05000000074505806, 0.05000000074505806),
      ]) {
        frame = nextU3AtlasFrame(controller, doc, frame);
        expect(frame, expected);
        expect(element.mutations, hasLength(1));
        final mutation = element.mutations.removeAt(0);
        expect(mutation.tag, D3Protocol.command);
        final op = jsonDecode(utf8.decode(mutation.data)) as Map;
        expect(op.keys, unorderedEquals(['op', 'id', 'resource']));
        expect(op['op'], 'upsertResource');
        expect(op['id'], selected.id.toToken());
        final resource = op['resource'] as Map;
        expect(resource['type'], 'unlit');
        expect(resource['properties']['baseColorTextureTransform'], {
          'map': {
            'offset': {
              'v2': [u, v],
            },
            'scale': {
              'v2': [0.3999999761581421, 0.3999999761581421],
            },
          },
        });
        final mirror = controller.document!;
        expect(
          encodeResource(mirror.resources[selected.id]!, (id) => id.toToken()),
          resource,
        );
        expect(
          encodeResource(doc.resources[selected.id]!, (id) => id.toToken()),
          resource,
        );
        expect(stable(doc), baseline);
        expect(stable(mirror), baseline);
        expect(doc.payloads.values.single.bytes, pixels);
        expect(mirror.payloads.values.single.bytes, pixels);
      }
    },
  );

  test('both billboards fit above controls at 402 by 874', () {
    final scene = load();
    final camera = SceneCamera.fromDocument(
      scene.document,
      cameraNode: scene.cameraNode,
    )!;
    final bounds = documentContentBounds(scene.document)!;
    for (final y in [bounds.$1.y, bounds.$2.y]) {
      for (final x in [bounds.$1.x, bounds.$2.x]) {
        for (final z in [bounds.$1.z, bounds.$2.z]) {
          final screen = camera.worldToScreen(Vector3(x, y, z), 402, 874)!;
          expect(screen.$1, inInclusiveRange(16, 386));
          expect(screen.$2, inInclusiveRange(80, 654));
        }
      }
    }
  });
}

class RecordingElement extends SceneViewElement {
  RecordingElement(SceneController controller)
    : super(SceneViewLeaf(controller: controller));
  final mutations = <({int tag, Uint8List data})>[];
  @override
  void sendMutation(int tag, Uint8List data) =>
      mutations.add((tag: tag, data: data));
}
