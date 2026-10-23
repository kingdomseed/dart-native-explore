import 'dart:math' as math;

import 'package:dart3d/src/camera.dart';
import 'package:dart3d/src/camera_controllers.dart';
import 'package:dart3d/src/scene_controller.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/world_bounds.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('camera regressions', () {
    test('toNodeTransform and applyToScene preserve composed forward', () {
      final eye = Vector3(0, 2, -6);
      final target = Vector3.zero();
      final doc = SceneDocument();
      final cameraId = doc.newId();
      doc.addNode(NodeSpec(id: cameraId));
      doc.roots.add(cameraId);

      final cameraController = _StaticCameraController(
        camera: SceneCamera.perspective(position: eye, target: target),
        cameraNode: cameraId,
      );
      final nodeTransform = cameraController.toNodeTransform(cameraId);
      final local = Matrix4.compose(
        nodeTransform.translation!,
        nodeTransform.rotation!,
        Vector3.all(1),
      );
      final expectedForward = Vector3(0, -1 / math.sqrt(10), 3 / math.sqrt(10));
      final localForward = Vector3(
        local.entry(0, 2),
        local.entry(1, 2),
        local.entry(2, 2),
      );
      expect(localForward.x, closeTo(expectedForward.x, 1e-5));
      expect(localForward.y, closeTo(expectedForward.y, 1e-5));
      expect(localForward.z, closeTo(expectedForward.z, 1e-5));

      final scene = SceneController()..loadDocument(doc);
      expect(cameraController.applyToScene(scene), isTrue);
      final world = computeWorldTransforms(doc)[cameraId]!;
      final worldForward = Vector3(
        world.entry(0, 2),
        world.entry(1, 2),
        world.entry(2, 2),
      );
      expect(worldForward.x, closeTo(expectedForward.x, 1e-5));
      expect(worldForward.y, closeTo(expectedForward.y, 1e-5));
      expect(worldForward.z, closeTo(expectedForward.z, 1e-5));
    });

    test('direct orbit distance writes clamp and update the camera', () {
      final orbit = OrbitCameraController(
        distance: 5,
        minDistance: 2,
        maxDistance: 8,
        damping: 0.5,
      );

      orbit.distance = 20;
      expect(orbit.distance, 8);
      expect((orbit.camera.position - orbit.target).length, closeTo(8, 1e-5));

      orbit.distance = 0.5;
      expect(orbit.distance, 2);
      expect((orbit.camera.position - orbit.target).length, closeTo(2, 1e-5));
    });

    test(
      'damped orbit distance converges and direct writes replace its goal',
      () {
        final orbit = OrbitCameraController(
          distance: 10,
          minDistance: 1,
          maxDistance: 20,
          damping: 0.5,
        );
        orbit.zoomByFactor(0.5);
        orbit.update(1 / 60);
        expect(orbit.distance, closeTo(7.5, 1e-5));
        for (var i = 0; i < 60; i++) {
          orbit.update(1 / 60);
        }
        expect(orbit.distance, closeTo(5, 1e-3));
        expect((orbit.camera.position - orbit.target).length, closeTo(5, 1e-3));

        orbit.distance = 3;
        expect((orbit.camera.position - orbit.target).length, closeTo(3, 1e-5));
        for (var i = 0; i < 60; i++) {
          orbit.update(1 / 60);
        }
        expect(orbit.distance, closeTo(3, 1e-5));
        expect((orbit.camera.position - orbit.target).length, closeTo(3, 1e-5));
      },
    );

    test('follow targetPose offsets use composition-convention rotation', () {
      final follow = FollowCameraController(
        targetPose: () => (
          Vector3.zero(),
          Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2),
        ),
        offset: Vector3(0, 0, -6),
        lookAtOffset: Vector3(0, 0, -1),
        rotateOffsetWithTarget: true,
        positionSmoothing: 0,
        targetSmoothing: 0,
      );

      expect(follow.camera.position.x, closeTo(-6, 1e-5));
      expect(follow.camera.position.y, closeTo(0, 1e-5));
      expect(follow.camera.position.z, closeTo(0, 1e-5));
      expect(follow.camera.target.x, closeTo(-1, 1e-5));
      expect(follow.camera.target.y, closeTo(0, 1e-5));
      expect(follow.camera.target.z, closeTo(0, 1e-5));
    });

    test('follow target node canonicalizes an X-reflected world pose', () {
      final doc = SceneDocument();
      final targetId = doc.newId();
      final rotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
      doc.addNode(
        NodeSpec(
          id: targetId,
          transform: TrsTransform(
            rotation: rotation.clone(),
            scale: Vector3(-1, 1, 1),
          ),
        ),
      );
      doc.roots.add(targetId);

      final byNode = FollowCameraController(
        targetNode: targetId,
        document: doc,
        offset: Vector3(0, 0, -5),
        lookAtOffset: Vector3(0, 0, -1),
        positionSmoothing: 0,
        targetSmoothing: 0,
      );
      final byPose = FollowCameraController(
        targetPose: () => (Vector3.zero(), rotation),
        offset: Vector3(0, 0, -5),
        lookAtOffset: Vector3(0, 0, -1),
        positionSmoothing: 0,
        targetSmoothing: 0,
      );

      expect(byNode.camera.position.x, closeTo(-5, 1e-5));
      expect(byNode.camera.position.y, closeTo(0, 1e-5));
      expect(byNode.camera.position.z, closeTo(0, 1e-5));
      expect(byNode.camera.target.x, closeTo(-1, 1e-5));
      expect(byNode.camera.target.y, closeTo(0, 1e-5));
      expect(byNode.camera.target.z, closeTo(0, 1e-5));
      expect(byNode.camera.position.x, closeTo(byPose.camera.position.x, 1e-5));
      expect(byNode.camera.position.y, closeTo(byPose.camera.position.y, 1e-5));
      expect(byNode.camera.position.z, closeTo(byPose.camera.position.z, 1e-5));
      expect(byNode.camera.target.x, closeTo(byPose.camera.target.x, 1e-5));
      expect(byNode.camera.target.y, closeTo(byPose.camera.target.y, 1e-5));
      expect(byNode.camera.target.z, closeTo(byPose.camera.target.z, 1e-5));
    });

    test('follow target node resolves a reflected parent world pose', () {
      final doc = SceneDocument();
      final parentId = doc.newId();
      final targetId = doc.newId();
      final rotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
      doc.addNode(
        NodeSpec(
          id: parentId,
          transform: TrsTransform(
            translation: Vector3(1, 2, 3),
            rotation: rotation,
            scale: Vector3(-1, 1, 1),
          ),
          children: [targetId],
        ),
      );
      doc.addNode(NodeSpec(id: targetId));
      doc.roots.add(parentId);

      final follow = FollowCameraController(
        targetNode: targetId,
        document: doc,
        offset: Vector3(0, 0, -5),
        lookAtOffset: Vector3(0, 0, -1),
        positionSmoothing: 0,
        targetSmoothing: 0,
      );

      expect(follow.camera.position.x, closeTo(-4, 1e-5));
      expect(follow.camera.position.y, closeTo(2, 1e-5));
      expect(follow.camera.position.z, closeTo(3, 1e-5));
      expect(follow.camera.target.x, closeTo(0, 1e-5));
      expect(follow.camera.target.y, closeTo(2, 1e-5));
      expect(follow.camera.target.z, closeTo(3, 1e-5));
    });

    test(
      'parented camera writes representable local TRS and keeps world pose',
      () {
        final fixture = _cameraUnder(
          TrsTransform(
            translation: Vector3(3, -2, 5),
            rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.7),
            scale: Vector3.all(2),
          ),
        );
        final eye = Vector3(4, 1, -7);
        final target = Vector3(0, 1, 0);
        final cameraController = _StaticCameraController(
          camera: SceneCamera.perspective(position: eye, target: target),
          cameraNode: fixture.cameraId,
        );

        expect(cameraController.applyToScene(fixture.scene), isTrue);
        final local = fixture.doc.nodes[fixture.cameraId]!.transform;
        expect(local, isA<TrsTransform>());
        expect((local as TrsTransform).scale.x, closeTo(0.5, 1e-5));

        final actual = computeWorldTransforms(fixture.doc)[fixture.cameraId]!;
        final expected = Matrix4.compose(
          eye,
          lookAtRotation(eye, target),
          Vector3.all(1),
        );
        for (var i = 0; i < 16; i++) {
          expect(actual.storage[i], closeTo(expected.storage[i], 1e-5));
        }
      },
    );

    test('parented camera refuses a required local shear without mutation', () {
      final fixture = _cameraUnder(
        TrsTransform(
          rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4),
          scale: Vector3(2, 1, 1),
        ),
      );
      final before = fixture.doc.nodes[fixture.cameraId]!.transform
          .toMatrix4()
          .storage
          .toList();
      final cameraController = _StaticCameraController(
        camera: SceneCamera.perspective(
          position: Vector3.zero(),
          target: Vector3(0, 0, 1),
        ),
        cameraNode: fixture.cameraId,
      );

      expect(cameraController.applyToScene(fixture.scene), isFalse);
      expect(
        fixture.doc.nodes[fixture.cameraId]!.transform.toMatrix4().storage,
        equals(before),
      );
    });

    test('singular parent rejects camera writes without mutation', () {
      final fixture = _cameraUnder(TrsTransform(scale: Vector3(0, 1, 1)));
      final before = fixture.doc.nodes[fixture.cameraId]!.transform
          .toMatrix4()
          .storage
          .toList();
      final cameraController = _StaticCameraController(
        camera: SceneCamera.perspective(
          position: Vector3(0, 0, -2),
          target: Vector3.zero(),
        ),
        cameraNode: fixture.cameraId,
      );

      expect(cameraController.applyToScene(fixture.scene), isFalse);
      expect(
        fixture.doc.nodes[fixture.cameraId]!.transform.toMatrix4().storage,
        equals(before),
      );
    });

    test('projection defaults and extraction match native camera fields', () {
      expect(SceneCamera.perspective().fovRadiansY, closeTo(math.pi / 3, 1e-6));
      expect(SceneCamera.orthographic().orthoScale, 1);
      expect(
        OrbitCameraController().camera.fovRadiansY,
        closeTo(math.pi / 3, 1e-6),
      );

      final perspective = _cameraFromProperties({
        'projection': const StringValue('perspective'),
        'fovY': const DoubleValue(0.2),
      });
      expect(perspective.fovRadiansY, closeTo(math.pi / 3, 1e-6));
      final projected = perspective.worldToScreen(Vector3(0.5, 0, 0), 100, 100);
      expect(projected, isNotNull);
      expect(projected!.$1, closeTo(58.660254, 1e-4));

      final orthographic = _cameraFromProperties({
        'projection': const StringValue('orthographic'),
      });
      expect(orthographic.orthoScale, 1);
      final orthoProjected = orthographic.worldToScreen(
        Vector3(0.5, 0, 0),
        100,
        100,
      );
      expect(orthoProjected, isNotNull);
      expect(orthoProjected!.$1, closeTo(75, 1e-5));
    });

    test('both native orthographic scale property names are extracted', () {
      final orthoScale = _cameraFromProperties({
        'projection': const StringValue('orthographic'),
        'orthoScale': const DoubleValue(2),
      });
      final orthographicScale = _cameraFromProperties({
        'projection': const StringValue('orthographic'),
        'orthographicScale': const DoubleValue(3),
      });

      expect(orthoScale.orthoScale, 2);
      expect(orthographicScale.orthoScale, 3);
    });
  });
}

({SceneDocument doc, SceneController scene, LocalId cameraId}) _cameraUnder(
  TransformSpec parentTransform,
) {
  final doc = SceneDocument();
  final parentId = doc.newId();
  final cameraId = doc.newId();
  doc.addNode(
    NodeSpec(id: parentId, transform: parentTransform, children: [cameraId]),
  );
  doc.addNode(NodeSpec(id: cameraId));
  doc.roots.add(parentId);
  return (
    doc: doc,
    scene: SceneController()..loadDocument(doc),
    cameraId: cameraId,
  );
}

SceneCamera _cameraFromProperties(Map<String, PropertyValue> properties) {
  final doc = SceneDocument();
  final cameraId = doc.newId();
  doc.addNode(
    NodeSpec(
      id: cameraId,
      transform: lookAtTransform(Vector3(0, 0, -5), Vector3.zero()),
      components: [ComponentSpec('camera', properties: properties)],
    ),
  );
  doc.roots.add(cameraId);
  return SceneCamera.fromDocument(doc)!;
}

class _StaticCameraController extends CameraController {
  _StaticCameraController({required super.camera, super.cameraNode});

  @override
  void update(double dt) {}
}
