import 'dart:math' as math;

import 'package:dart3d/dart3d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final sideCamera = SceneCamera.perspective(
    position: Vector3(5, 0, 0),
    target: Vector3.zero(),
  );
  final sideRay = Ray.originDirection(Vector3(5, 0.5, 0), Vector3(-1, 0, 0));

  for (final (facing, camera, expectedDistance, expectedX, expectedNormalX)
      in <(String, SceneCamera, double, double, double)>[
        ('spherical', sideCamera, 5, 0, 1),
        (
          'axisY',
          SceneCamera.perspective(
            position: Vector3(5, 3, 0),
            target: Vector3.zero(),
          ),
          5,
          0,
          1,
        ),
        (
          'screen',
          SceneCamera.perspective(
            position: Vector3(5, 0, 0),
            target: Vector3(0, 1, 0),
          ),
          4.9,
          0.1,
          5 / math.sqrt(26),
        ),
      ]) {
    test('$facing billboard raycast uses its camera-facing basis', () {
      final scene = _billboardScene(facing: facing, camera: camera);

      final hit = raycastDocument(scene.document, sideRay);
      final allHits = raycastDocumentAll(scene.document, sideRay);

      expect(hit?.node, scene.billboard);
      expect(hit?.distance, closeTo(expectedDistance, 1e-5));
      expect(hit?.worldPoint.x, closeTo(expectedX, 1e-5));
      expect(hit?.worldNormal?.x, closeTo(expectedNormalX, 1e-5));
      expect(allHits.map((entry) => entry.node), [scene.billboard]);
      expect(allHits.single.distance, closeTo(expectedDistance, 1e-5));
    });
  }

  test('no camera keeps the fixed XY billboard raycast', () {
    final scene = _billboardScene();
    final hit = raycastDocument(
      scene.document,
      Ray.originDirection(Vector3(0, 0.5, -5), Vector3(0, 0, 1)),
    );

    expect(hit?.node, scene.billboard);
    expect(hit?.distance, closeTo(5, 1e-5));
  });

  test('camera override replaces the document primary for raycasting', () {
    final scene = _billboardScene(
      camera: SceneCamera.perspective(
        position: Vector3(0, 0, -5),
        target: Vector3.zero(),
      ),
    );

    expect(raycastDocument(scene.document, sideRay), isNull);
    final directHit = raycastDocument(
      scene.document,
      sideRay,
      camera: sideCamera,
    );
    final directHits = raycastDocumentAll(
      scene.document,
      sideRay,
      camera: sideCamera,
    );

    final hit = ScenePointer(
      document: scene.document,
      camera: sideCamera,
    ).pointAlong(sideRay);

    expect(directHit?.node, scene.billboard);
    expect(directHit?.distance, closeTo(5, 1e-5));
    expect(directHits.map((entry) => entry.node), [scene.billboard]);
    expect(hit?.node, scene.billboard);
    expect(hit?.distance, closeTo(5, 1e-5));
  });

  test('billboard raycast is transformed through its parent node', () {
    final doc = SceneDocument();
    final parent = doc.newId();
    final billboard = doc.newId();
    doc.addNode(
      NodeSpec(
        id: parent,
        transform: TrsTransform(
          translation: Vector3(1, 0, 2),
          rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2),
        ),
        children: [billboard],
      ),
    );
    doc.addNode(
      NodeSpec(
        id: billboard,
        components: [d3ProcMeshComponent(D3BillboardProc(size: Vector2(2, 2)))],
      ),
    );
    doc.roots.add(parent);

    final hit = ScenePointer(
      document: doc,
      camera: SceneCamera.perspective(
        position: Vector3(1, 0, 7),
        target: Vector3(1, 0, 2),
      ),
    ).pointAlong(Ray.originDirection(Vector3(1, 0.5, 7), Vector3(0, 0, -1)));

    expect(hit?.node, billboard);
    expect(hit?.distance, closeTo(5, 1e-5));
    expect(hit?.worldPoint.z, closeTo(2, 1e-5));
  });

  test('instanced billboard ignores instance rotation and scale', () {
    final scene = _instancedBillboardScene([
      Matrix4.compose(
        Vector3(2, 0, 0),
        Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2),
        Vector3(3, 4, 2),
      ),
    ]);

    final hit = ScenePointer(
      document: scene.document,
      camera: SceneCamera.perspective(
        position: Vector3(2, 0, 5),
        target: Vector3(2, 0, 0),
      ),
    ).pointAlong(Ray.originDirection(Vector3(2.75, 0, 5), Vector3(0, 0, -1)));

    expect(hit?.node, scene.billboard);
    expect(hit?.distance, closeTo(5, 1e-5));
    expect(hit?.instanceIndex, 0);
    expect(hit?.worldPoint.x, closeTo(2.75, 1e-5));
    expect(hit?.worldPoint.z, closeTo(0, 1e-5));
    expect(hit?.worldNormal?.z, closeTo(1, 1e-5));
  });

  test('instanced billboard BVH bounds follow the camera-facing plane', () {
    final scene = _instancedBillboardScene([
      Matrix4.compose(
        Vector3(2, 0, 0),
        Quaternion.identity(),
        Vector3(3, 4, 2),
      ),
      for (var index = 1; index < 9; index++)
        Matrix4.identity()..setTranslationRaw(20 + index * 3, 0, 0),
    ]);

    final hit = ScenePointer(
      document: scene.document,
      camera: SceneCamera.perspective(
        position: Vector3(7, 0, 0),
        target: Vector3(2, 0, 0),
      ),
    ).pointAlong(Ray.originDirection(Vector3(7, 0, 0.75), Vector3(-1, 0, 0)));

    expect(hit?.node, scene.billboard);
    expect(hit?.distance, closeTo(5, 1e-5));
    expect(hit?.instanceIndex, 0);
    expect(hit?.worldPoint.x, closeTo(2, 1e-5));
    expect(hit?.worldPoint.z, closeTo(0.75, 1e-5));
    expect(hit?.worldNormal?.x, closeTo(1, 1e-5));
  });

  test('ScenePointer pointAlong and pointAt carry their camera overrides', () {
    final scene = _billboardScene(
      camera: SceneCamera.perspective(
        position: Vector3(0, 0, -5),
        target: Vector3.zero(),
      ),
    );
    final overridePointer = ScenePointer(document: scene.document);
    final overrideCamera = SceneCamera.orthographic(
      position: Vector3(5, 0, 0),
      target: Vector3.zero(),
      orthoScale: 1,
    );

    final alongHit = ScenePointer(
      document: scene.document,
      camera: sideCamera,
    ).pointAlong(sideRay);
    final atHit = overridePointer.pointAt(
      100,
      100,
      200,
      200,
      overrideCamera: overrideCamera,
    );

    expect(alongHit?.node, scene.billboard);
    expect(alongHit?.distance, closeTo(5, 1e-5));
    expect(atHit?.node, scene.billboard);
    expect(atHit?.distance, closeTo(5, 1e-5));
  });

  test('SceneController mesh queries and pick pass the effective camera', () {
    final overrideScene = _billboardScene(
      camera: SceneCamera.perspective(
        position: Vector3(0, 0, -5),
        target: Vector3.zero(),
      ),
    );
    final overrideController = SceneController()
      ..loadDocument(overrideScene.document);
    final overrideCamera = SceneCamera.orthographic(
      position: Vector3(5, 0, 0),
      target: Vector3.zero(),
      orthoScale: 1,
    );

    expect(
      overrideController.raycastMesh(sideRay, camera: sideCamera)?.node,
      overrideScene.billboard,
    );

    final allHits = overrideController.raycastMeshAll(
      sideRay,
      camera: sideCamera,
    );
    final picked = overrideController.pick(
      100,
      100,
      200,
      200,
      camera: overrideCamera,
    );

    expect(allHits.map((entry) => entry.node), [overrideScene.billboard]);
    expect(allHits.single.distance, closeTo(5, 1e-5));
    expect(picked?.node, overrideScene.billboard);
    expect(picked?.distance, closeTo(5, 1e-5));
  });
}

({SceneDocument document, LocalId billboard}) _billboardScene({
  String facing = 'spherical',
  SceneCamera? camera,
}) {
  final doc = SceneDocument();
  if (camera != null) _addPrimaryCamera(doc, camera);
  final billboard = doc.newId();
  doc.addNode(
    NodeSpec(
      id: billboard,
      components: [
        d3ProcMeshComponent(
          D3BillboardProc(size: Vector2(2, 2), facing: facing),
        ),
      ],
    ),
  );
  doc.roots.add(billboard);
  return (document: doc, billboard: billboard);
}

({SceneDocument document, LocalId billboard}) _instancedBillboardScene(
  List<Matrix4> transforms,
) {
  final doc = SceneDocument();
  final billboard = doc.newId();
  doc.addNode(
    NodeSpec(
      id: billboard,
      components: [
        D3InstancesSpec(
          proc: D3CuboidProc(extents: Vector3.all(1)),
          transforms: D3InstanceTransforms.inline(transforms),
          billboard: true,
          size: Vector2(2, 2),
        ).toComponent(),
      ],
    ),
  );
  doc.roots.add(billboard);
  return (document: doc, billboard: billboard);
}

void _addPrimaryCamera(SceneDocument doc, SceneCamera camera) {
  final cameraNode = doc.newId();
  doc.addNode(
    NodeSpec(
      id: cameraNode,
      transform: lookAtTransform(camera.position, camera.target, up: camera.up),
      components: [
        ComponentSpec(
          'camera',
          properties: {
            'projection': StringValue(
              camera.isOrthographic ? 'orthographic' : 'perspective',
            ),
            'near': DoubleValue(camera.near),
            'far': DoubleValue(camera.far),
            if (camera.isOrthographic)
              'orthoScale': DoubleValue(camera.orthoScale),
            if (!camera.isOrthographic)
              'fovRadiansY': DoubleValue(camera.fovRadiansY),
          },
        ),
      ],
    ),
  );
  doc.roots.add(cameraNode);
  doc.views.add(RenderViewSpec(cameraNode: cameraNode));
}
