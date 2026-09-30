// The DartNative set's procedural dice: the look-dev polyhedra, their
// numbering and numeral frames (dice_polyhedra.dart).

import 'package:dart3d_example/dice_polyhedra.dart';
import 'package:dart3d_example/dice_shard_d4.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const faceCounts = {
  'd4': 12,
  'd6': 6,
  'd8': 8,
  'd10t': 10,
  'd10u': 10,
  'd12': 12,
  'd20': 20,
};

const values = {
  'd4': [1, 2, 3, 4],
  'd6': [1, 2, 3, 4, 5, 6],
  'd8': [1, 2, 3, 4, 5, 6, 7, 8],
  'd10u': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  'd10t': [0, 10, 20, 30, 40, 50, 60, 70, 80, 90],
  'd12': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  'd20': [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, //
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  ],
};

void main() {
  for (final kind in kDieKinds) {
    group(kind, () {
      final geo = buildDieGeo(kind);

      test('faces, values and opposite sums', () {
        expect(geo.faces, hasLength(faceCounts[kind]));
        final v = geo.numbered.map((f) => f.value!).toList()..sort();
        expect(v, values[kind]);
        for (final f in geo.numbered) {
          final opp = geo.numbered.reduce(
            (a, b) => a.normal.dot(f.normal) < b.normal.dot(f.normal) ? a : b,
          );
          expect(opp.normal.dot(f.normal), lessThan(-0.999));
          expect(f.value! + opp.value!, kOppositeSum[kind]);
        }
      });

      test('a convex solid around the origin', () {
        final verts = geo.vertices;
        for (final f in geo.faces) {
          expect(f.normal.length, closeTo(1, 1e-6));
          final d = f.normal.dot(f.centre);
          expect(d, greaterThan(0));
          for (final p in verts) {
            expect(f.normal.dot(p), lessThanOrEqualTo(d + 1e-4));
          }
          for (final p in f.points) {
            expect(f.normal.dot(p), closeTo(d, 1e-4));
          }
        }
      });

      test('numeral frames lie in the face, right = n × up', () {
        for (final f in geo.numbered) {
          expect(f.up.length, closeTo(1, 1e-6));
          expect(f.up.dot(f.normal), closeTo(0, 1e-6));
          expect(f.right.dot(f.normal.cross(f.up)), closeTo(1, 1e-6));
          expect(f.inradius, greaterThan(0));
          expect(f.em, greaterThan(f.inradius));
          expect(f.label(kind), isNotNull);
          // The cell covers the whole face.
          for (final p in f.points) {
            final l = f.local(p);
            expect(l.x.abs(), lessThan(geo.cellSpan / 2));
            expect(l.y.abs(), lessThan(geo.cellSpan / 2));
          }
        }
      });
    });
  }

  test('sized to the d20 span; the shard reads along its crystal', () {
    final d20 = buildDieGeo('d20');
    expect(d20.radius * 2, closeTo(kD20Span, 1e-3));
    final d4 = buildDieGeo('d4');
    for (final f in d4.numbered) {
      expect(f.up.dot(shardGlyphUp(f.normal)), closeTo(1, 1e-6));
      expect(f.right.dot(kShardAxis).abs(), closeTo(1, 1e-6));
    }
    expect(
      d4.numbered.firstWhere((f) => f.value == 4).normal.y,
      closeTo(1, 1e-6),
    );
  });

  test('labels: 00 on the tens die, a dot under 6 and 9', () {
    final d10t = buildDieGeo('d10t');
    expect(d10t.numbered.firstWhere((f) => f.value == 0).label('d10t'), '00');
    final d20 = buildDieGeo('d20');
    expect(d20.numbered.firstWhere((f) => f.value == 9).label('d20'), '9.');
    final d8 = buildDieGeo('d8');
    expect(d8.numbered.firstWhere((f) => f.value == 6).label('d8'), '6');
  });

  test('hull of a cube: six square faces', () {
    final cube = convexHullFaces([
      for (final x in [-1.0, 1.0])
        for (final y in [-1.0, 1.0])
          for (final z in [-1.0, 1.0]) Vector3(x, y, z),
    ]);
    expect(cube, hasLength(6));
    expect(cube.every((f) => f.length == 4), isTrue);
  });
}
