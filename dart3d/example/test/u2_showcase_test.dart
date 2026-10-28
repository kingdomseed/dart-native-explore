// ignore_for_file: implementation_imports

import 'package:dart3d/src/camera.dart';
import 'package:dart3d/src/geometry/proc.dart';
import 'package:dart3d/src/physics.dart' show SceneRaycastHit;
import 'package:dart3d/src/scene_controller.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/scene_pointer.dart';
import 'package:dart3d/src/world_bounds.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u2_geometry_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('U2 geometry showcase', () {
    test('loads named geometry shapes and an inline instanced wedge', () {
      final item = showcaseItems.firstWhere((entry) => entry.label == 'u2');
      final scene = loadShowcaseScene(item);
      expect(scene, isNotNull);

      final doc = scene!.document;
      final expectedShapes = <String, String>{
        'u2.ground': 'plane',
        'u2.wedge': 'wedge',
        'u2.ring': 'ring',
        'u2.extrude.ccw': 'extrude',
        'u2.extrude.cw': 'extrude',
      };
      for (final entry in expectedShapes.entries) {
        final node = doc.nodes.values.singleWhere(
          (candidate) => candidate.name == entry.key,
        );
        final mesh = node.components.single;
        expect(mesh.type, kD3ProcMeshType, reason: entry.key);
        expect(
          (mesh.properties['shape']! as StringValue).value,
          entry.value,
          reason: entry.key,
        );
      }
      List<(double, double)> profileFor(String name) {
        final node = doc.nodes.values.singleWhere(
          (candidate) => candidate.name == name,
        );
        final profile =
            node.components.single.properties['profile']! as ListValue;
        return [
          for (final point in profile.values.cast<Vec2Value>())
            (point.value.x, point.value.y),
        ];
      }

      expect(
        profileFor('u2.extrude.cw'),
        profileFor('u2.extrude.ccw').reversed.toList(),
      );

      final instances = doc.nodes.values.singleWhere(
        (candidate) => candidate.name == 'u2.instances',
      );
      final instanceComponent = instances.components.single;
      expect(instanceComponent.type, kD3InstancesType);
      expect(
        (instanceComponent.properties['shape']! as StringValue).value,
        'wedge',
      );
      expect(
        (instanceComponent.properties['transforms']! as ListValue).values,
        hasLength(2),
      );
      expect(
        doc.nodes.values.any((node) => node.name == 'showcase.slab'),
        isFalse,
      );
      expect(
        doc.nodes.values.any((node) => node.name == 'showcase.key'),
        isFalse,
      );
      expect(
        doc.nodes.values
            .where(
              (node) => node.components.any(
                (component) => component.type == 'directionalLight',
              ),
            )
            .map((node) => node.name),
        [u2KeyLightName],
      );
      expect(scene.summary, contains('annulus ring'));
      expect(scene.summary, contains('extrude CCW/CW'));
    });

    test('left and right light updates travel in opposite X directions', () {
      final item = showcaseItems.firstWhere((entry) => entry.label == 'u2');
      final scene = loadShowcaseScene(item)!;
      final doc = scene.document;
      final cameraBefore = doc.nodes[scene.cameraNode]!.transform.toMatrix4();
      final left = u2LightUpdate(doc, U2LightMode.left);
      final right = u2LightUpdate(doc, U2LightMode.right);
      final lightId = left.node;
      final initialRotation =
          (doc.nodes[lightId]!.transform as TrsTransform).rotation;
      final initialTravel = _travelDirection(initialRotation);
      expect(initialTravel.x, greaterThan(0.5));
      expect(initialTravel.y, lessThan(-0.5));

      final controller = SceneController()..loadDocument(doc);
      controller.setNodeTransforms([
        NodeTransform(right.node, rotation: right.rotation),
      ]);
      var travel = _travelDirection(
        (controller.document!.nodes[lightId]!.transform as TrsTransform)
            .rotation,
      );
      expect(travel.x, lessThan(-0.5));
      expect(travel.y, lessThan(-0.5));
      expect(
        controller.document!.nodes[scene.cameraNode]!.transform
            .toMatrix4()
            .storage,
        cameraBefore.storage,
      );

      controller.setNodeTransforms([
        NodeTransform(left.node, rotation: left.rotation),
      ]);
      travel = _travelDirection(
        (controller.document!.nodes[lightId]!.transform as TrsTransform)
            .rotation,
      );
      expect(travel.x, greaterThan(0.5));
      expect(travel.y, lessThan(-0.5));
      expect(
        controller.document!.nodes[scene.cameraNode]!.transform
            .toMatrix4()
            .storage,
        cameraBefore.storage,
      );
    });

    test(
      'frames every fixture mesh and public pointer rays hit each shape',
      () {
        final item = showcaseItems.firstWhere((entry) => entry.label == 'u2');
        final scene = loadShowcaseScene(item)!;
        final doc = scene.document;
        final camera = SceneCamera.fromDocument(
          doc,
          cameraNode: scene.cameraNode,
        )!;
        const viewWidth = 1000.0;
        const viewHeight = 800.0;

        final perNodeBounds = meshNodeWorldBounds(doc);
        for (final node in doc.nodes.values.where(
          (candidate) => candidate.name.startsWith('u2.'),
        )) {
          final bounds = perNodeBounds[node.id];
          if (bounds == null) continue;
          for (var corner = 0; corner < 8; corner++) {
            final point = Vector3(
              corner & 1 == 0 ? bounds.$1.x : bounds.$2.x,
              corner & 2 == 0 ? bounds.$1.y : bounds.$2.y,
              corner & 4 == 0 ? bounds.$1.z : bounds.$2.z,
            );
            final screen = camera.worldToScreen(point, viewWidth, viewHeight);
            expect(screen, isNotNull, reason: '${node.name} is behind the camera');
            expect(screen!.$1, inInclusiveRange(0, viewWidth), reason: node.name);
            expect(
              screen.$2,
              inInclusiveRange(0, viewHeight * 0.60),
              reason: '${node.name} must remain above the footer',
            );
          }
        }

        final pointer = ScenePointer(document: doc, camera: camera);
        final targets = <(String, int?, Vector3)>[
          ('u2.wedge', null, Vector3(-0.92, 0.48, 0.90)),
          ('u2.ring', null, Vector3(1.37, 0.045, 0.90)),
          ('u2.extrude.ccw', null, Vector3(-0.92, 0.22, -0.24)),
          ('u2.extrude.cw', null, Vector3(0.92, 0.22, -0.24)),
          ('u2.instances', 0, Vector3(-0.42, 0.21, -1.30)),
        ];
        for (final (expectedName, expectedInstance, worldPoint) in targets) {
          final screen = camera.worldToScreen(
            worldPoint,
            viewWidth,
            viewHeight,
          );
          expect(screen, isNotNull, reason: '$expectedName projection');
          pointer.press(
            screenX: screen!.$1,
            screenY: screen.$2,
            viewWidth: viewWidth,
            viewHeight: viewHeight,
          );
          final SceneRaycastHit? hit = pointer.release(
            screenX: screen.$1,
            screenY: screen.$2,
            viewWidth: viewWidth,
            viewHeight: viewHeight,
          );
          expect(hit, isNotNull, reason: '$expectedName ray hit');
          expect(doc.nodes[hit!.node]?.name, expectedName);
          expect(hit.instanceIndex, expectedInstance);
        }
      },
    );
  });
}

Vector3 _travelDirection(Quaternion rotation) =>
    rotation.asRotationMatrix() * Vector3(0, 0, 1);
