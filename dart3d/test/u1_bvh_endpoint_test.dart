// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:dart3d/src/bvh.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('TriangleMeshBvh.raycastClosest', () {
    test('includes a hit exactly at maxT and agrees with raycastAll', () {
      final bvh = TriangleMeshBvh.build(
        positions: Float32List.fromList([
          -1, -1, 4,
          1, -1, 4,
          0, 1, 4,
        ]),
      );
      final ray = Ray.originDirection(Vector3.zero(), Vector3(0, 0, 1));

      final allHits = bvh.raycastAll(ray, maxT: 4);
      final closest = bvh.raycastClosest(ray, maxT: 4);

      expect(allHits, hasLength(1));
      expect(allHits.single.t, 4.0);
      expect(closest?.t, 4.0);
      expect(closest?.t, allHits.single.t);
    });

    test('misses when the hit lies beyond maxT', () {
      final bvh = TriangleMeshBvh.build(
        positions: Float32List.fromList([
          -1, -1, 4,
          1, -1, 4,
          0, 1, 4,
        ]),
      );
      final ray = Ray.originDirection(Vector3.zero(), Vector3(0, 0, 1));

      expect(bvh.raycastClosest(ray, maxT: 3.99), isNull);
      expect(bvh.raycastAll(ray, maxT: 3.99), isEmpty);
    });

    test('keeps the first triangle when hits have equal distance', () {
      final bvh = TriangleMeshBvh.build(
        positions: Float32List.fromList([
          -1, -1, 3,
          1, -1, 3,
          0, 1, 3,
          -1, -1, 3,
          1, -1, 3,
          0, 1, 3,
        ]),
      );
      final ray = Ray.originDirection(Vector3.zero(), Vector3(0, 0, 1));

      final allHits = bvh.raycastAll(ray, maxT: 4);
      final closest = bvh.raycastClosest(ray, maxT: 4);

      expect(allHits.map((hit) => hit.triangleIndex).toList(), [0, 1]);
      expect(closest?.triangleIndex, 0);
    });
  });
}
