// ignore_for_file: implementation_imports
import 'package:dart3d/src/camera.dart';
import 'package:dart3d/src/scene_pointer.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('U1 showcase scene loads and ScenePointer picks all 5 targets', () {
    final item = showcaseItems.firstWhere((it) => it.label == 'u1');
    final scene = loadShowcaseScene(item);
    expect(scene, isNotNull);

    final doc = scene!.document;
    final cam = SceneCamera.fromDocument(doc, cameraNode: scene.cameraNode);
    expect(cam, isNotNull);

    const viewW = 1000.0;
    const viewH = 600.0;
    final pointer = ScenePointer(document: doc, camera: cam!);

    final targets = <(String, int?, Vector3)>[
      ('u1.target.procedural', null, Vector3(-3.2, 0.85, 0.0)),
      ('u1.target.payload', null, Vector3(-1.6, 0.85, 0.0)),
      ('u1.target.d3proc', null, Vector3(0.0, 0.85, 0.0)),
      ('u1.target.skinned', null, Vector3(1.6, 1.35, 0.0)),
      ('u1.target.instanced', 2, Vector3(3.2, 1.50, 0.0)),
    ];

    for (final (expectedName, expectedInst, worldPt) in targets) {
      final screen = cam.worldToScreen(worldPt, viewW, viewH);
      expect(screen, isNotNull, reason: 'screen projection for $expectedName');
      pointer.press(
        screenX: screen!.$1,
        screenY: screen.$2,
        viewWidth: viewW,
        viewHeight: viewH,
      );
      final hit = pointer.release(
        screenX: screen.$1,
        screenY: screen.$2,
        viewWidth: viewW,
        viewHeight: viewH,
      );
      expect(hit, isNotNull, reason: 'pick hit for $expectedName');
      expect(doc.nodes[hit!.node]?.name, equals(expectedName));
      expect(hit.instanceIndex, equals(expectedInst));
    }
  });
}
