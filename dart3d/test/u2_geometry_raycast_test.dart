import 'package:dart3d/dart3d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('procMesh ring raycast misses the hole and hits the annulus', () {
    final doc = SceneDocument();
    doc.addNode(
      NodeSpec(
        id: const LocalId(21, 1),
        components: [
          d3ProcMeshComponent(
            D3RingProc(innerRadius: 0.25, outerRadius: 0.5, segments: 32),
          ),
        ],
      ),
      root: true,
    );

    final center =
        Ray.originDirection(Vector3(0, 1, 0), Vector3(0, -1, 0));
    final rim =
        Ray.originDirection(Vector3(0.35, 1, 0.1), Vector3(0, -1, 0));

    expect(raycastDocument(doc, center), isNull);
    expect(raycastDocument(doc, rim)?.distance, closeTo(1, 1e-5));
  });

  test('procMesh extrude raycast reaches its end cap', () {
    final doc = SceneDocument();
    doc.addNode(
      NodeSpec(
        id: const LocalId(21, 2),
        components: [
          d3ProcMeshComponent(
            D3ExtrudeProc(
              points: [Vector3(0, 0, -1), Vector3(0, 0, 1)],
              profile: [
                Vector2(-0.25, -0.25),
                Vector2(0.25, -0.25),
                Vector2(0.25, 0.25),
                Vector2(-0.25, 0.25),
              ],
              stations: 2,
            ),
          ),
        ],
      ),
      root: true,
    );

    final ray = Ray.originDirection(Vector3(0, 0, 2), Vector3(0, 0, -1));
    expect(raycastDocument(doc, ray)?.distance, closeTo(1, 1e-5));
  });

  test('procMesh extrude raycasts both convex profile windings', () {
    final profiles = [
      [
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(1, 2),
        Vector2(0, 2),
      ],
      [
        Vector2(0, 0),
        Vector2(0, 2),
        Vector2(1, 2),
        Vector2(1, 0),
      ],
    ];
    for (var i = 0; i < profiles.length; i++) {
      final doc = SceneDocument();
      doc.addNode(
        NodeSpec(
          id: LocalId(21, 4 + i),
          components: [
            d3ProcMeshComponent(
              D3ExtrudeProc(
                points: [Vector3(0, 0, -1), Vector3(0, 0, 1)],
                profile: profiles[i],
                stations: 2,
              ),
            ),
          ],
        ),
        root: true,
      );

      final side = Ray.originDirection(
        Vector3(1, 1, 0), Vector3(0, -1, 0),
      );
      final endCap = Ray.originDirection(
        Vector3(1, -0.5, 2), Vector3(0, 0, -1),
      );
      final startCap = Ray.originDirection(
        Vector3(1, -0.5, -2), Vector3(0, 0, 1),
      );
      expect(raycastDocument(doc, side)?.distance, closeTo(1, 1e-5));
      expect(raycastDocument(doc, endCap)?.distance, closeTo(1, 1e-5));
      expect(raycastDocument(doc, startCap)?.distance, closeTo(1, 1e-5));
    }
  });

  test('inline wedge instances are hit at their transformed position', () {
    final doc = SceneDocument();
    doc.addNode(
      NodeSpec(
        id: const LocalId(21, 3),
        components: [
          D3InstancesSpec(
            proc: D3WedgeProc(size: Vector3(2, 3, 4)),
            transforms: D3InstanceTransforms.inline([
              Matrix4.identity()..setTranslationRaw(4, 0, 0),
            ]),
          ).toComponent(),
        ],
      ),
      root: true,
    );

    final ray = Ray.originDirection(Vector3(4, 5, 0), Vector3(0, -1, 0));
    final hit = raycastDocument(doc, ray);
    expect(hit?.distance, closeTo(3.5, 1e-5));
    expect(hit?.instanceIndex, 0);

    final highRamp =
        Ray.originDirection(Vector3(4, 4, 1.5), Vector3(0, -1, 0));
    expect(raycastDocument(doc, highRamp)?.distance, closeTo(1.375, 1e-5));
  });
}
