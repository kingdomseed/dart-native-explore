// Stabilization regressions for the W26 geometry + instancing Dart
// surface (docs/program-audit-2026-09-28.md §3, docs/triage/dart.md):
// generator hangs/caps, attribute indexing, normal transforms, the
// icosphere seam, instance bounds. Each group names the defect it pins.
// ignore_for_file: implementation_imports

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/src/geometry/instances.dart';
import 'package:dart3d/src/geometry/mesh_data.dart';
import 'package:dart3d/src/geometry/paths.dart';
import 'package:dart3d/src/geometry/proc.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

Vector3 pos(D3MeshData m, int i) =>
    Vector3(m.positions[i * 3], m.positions[i * 3 + 1], m.positions[i * 3 + 2]);

Vector3 nrm(D3MeshData m, int i) =>
    Vector3(m.normals[i * 3], m.normals[i * 3 + 1], m.normals[i * 3 + 2]);

List<double> col(D3MeshData m, int i) => [
  for (var k = 0; k < 4; k++) m.colors[i * 4 + k],
];

/// Every triangle's geometric normal agrees with its vertex normals.
void expectOutwardWinding(D3MeshData m) {
  for (var t = 0; t < m.indices.length; t += 3) {
    final a = pos(m, m.indices[t]);
    final b = pos(m, m.indices[t + 1]);
    final c = pos(m, m.indices[t + 2]);
    final g = (b - a).cross(c - a);
    if (g.length2 < 1e-12) continue;
    final n =
        nrm(m, m.indices[t]) +
        nrm(m, m.indices[t + 1]) +
        nrm(m, m.indices[t + 2]);
    expect(g.dot(n), greaterThan(0), reason: 'triangle ${t ~/ 3}');
  }
}

bool allFinite(D3MeshData m) =>
    m.positions.every((v) => v.isFinite) &&
    m.normals.every((v) => v.isFinite) &&
    m.uvs.every((v) => v.isFinite);

void main() {
  group('caps (hang/OOM guards)', () {
    final line = [Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 3, 0)];

    test('dash (0,0) terminates and renders solid', () {
      final solid = buildPolyline(line, width: 0.1);
      for (final pattern in [(0.0, 0.0), (0.0, 1.0), (-1.0, 0.5)]) {
        final m = buildPolyline(line, width: 0.1, dashPattern: pattern);
        expect(m.vertexCount, solid.vertexCount, reason: '$pattern');
      }
      expect(d3DashPatternValid(0, 0), isFalse);
      expect(d3DashPatternValid(0.5, 0), isTrue);
    });

    test('a dash pattern over the span budget renders solid', () {
      final solid = buildPolyline(line, width: 0.1);
      final m = buildPolyline(line, width: 0.1, dashPattern: (1e-6, 1e-6));
      expect(m.vertexCount, solid.vertexCount);
      // A sane pattern still dashes.
      final dashed = buildPolyline(line, width: 0.1, dashPattern: (0.5, 0.5));
      expect(dashed.vertexCount, greaterThan(solid.vertexCount));
    });

    test('icosphere subdivisions clamp to kD3MaxIcosphereSubdivisions', () {
      final m = buildIcosphere(radius: 1, subdivisions: 30);
      expect(
        m.triangleCount,
        20 * math.pow(4, kD3MaxIcosphereSubdivisions).toInt(),
      );
    });

    test('icosphere edge cache stays injective at the cap (Euler V)', () {
      // V = 10·4ⁿ + 2 distinct positions; a colliding edge key reuses a
      // wrong midpoint and the count drops.
      final m = buildIcosphere(
        radius: 1,
        subdivisions: kD3MaxIcosphereSubdivisions,
      );
      final distinct = <String>{
        for (var i = 0; i < m.vertexCount; i++)
          [
            for (var k = 0; k < 3; k++) (m.positions[i * 3 + k] * 1e6).round(),
          ].join(','),
      };
      expect(
        distinct.length,
        10 * math.pow(4, kD3MaxIcosphereSubdivisions).toInt() + 2,
      );
      expect(m.vertexCount, lessThanOrEqualTo(kD3MaxUint16Vertices));
    });

    test('segment counts clamp to kD3MaxProcSegments; indices are 32-bit', () {
      final m = buildSphere(radius: 1, segments: 100000, rings: 100000);
      const cols = kD3MaxProcSegments + 1;
      expect(m.vertexCount, cols * cols);
      expect(m.vertexCount, greaterThan(kD3MaxUint16Vertices));
      expect(m.indices, isA<Uint32List>());
      expect(m.indices.reduce(math.max), m.vertexCount - 1);
      final t = buildTorus(
        radius: 1,
        tubeRadius: 0.2,
        radialSegments: 1 << 20,
        tubularSegments: 3,
      );
      expect(t.vertexCount, cols * 4);
    });

    test('zero plane/sphere/torus segments clamp instead of NaN', () {
      expect(
        allFinite(buildPlane(width: 1, depth: 1, segmentsX: 0, segmentsZ: 0)),
        isTrue,
      );
      expect(allFinite(buildSphere(radius: 1, segments: 0, rings: 0)), isTrue);
      expect(
        allFinite(
          buildTorus(
            radius: 1,
            tubeRadius: 0.2,
            radialSegments: 0,
            tubularSegments: 0,
          ),
        ),
        isTrue,
      );
      expect(D3PlaneProc(segmentsX: 0, segmentsZ: 0).build().vertexCount, 4);
    });

    test('d3BakedInstanceCount honors both the count and vertex budget', () {
      expect(d3BakedInstanceCount(100, 24), 100);
      expect(d3BakedInstanceCount(1 << 20, 4), kD3MaxBakedInstances);
      // 263k-vertex base: the 1M-vertex budget fits three copies.
      expect(d3BakedInstanceCount(1000, 263169), 3);
      expect(d3BakedInstanceCount(5, kD3MaxBakedVertices * 2), 1);
      expect(d3BakedInstanceCount(0, 24), 0);
    });
  });

  group('polyline / line-segment attributes', () {
    final square = [
      Vector3(0, 0, 0),
      Vector3(1, 0, 0),
      Vector3(1, 1, 0),
      Vector3(0, 1, 0),
    ];
    final colors = [
      [1.0, 0.0, 0.0, 1.0],
      [0.0, 1.0, 0.0, 1.0],
      [0.0, 0.0, 1.0, 1.0],
      [1.0, 1.0, 0.0, 1.0],
    ];

    test('closed polyline wraps colors/widths at the seam', () {
      final m = buildPolyline(
        square,
        width: 0.1,
        colors: colors,
        widths: [0.1, 0.2, 0.3, 0.4],
        closed: true,
      );
      // Four segments, four vertices each; the seam quad (last) runs
      // point 3 → point 0, so its far end carries color 0.
      expect(m.vertexCount, 16);
      expect(col(m, 12), colors[3]);
      expect(col(m, 13), colors[0]);
      // Seam far-end width is widths[0] = 0.1 (half-width 0.05).
      expect(pos(m, 13).distanceTo(pos(m, 15)), closeTo(0.1, 1e-6));
    });

    test('closed dashed polyline wraps attributes too', () {
      expect(
        () => buildPolyline(
          square,
          width: 0.1,
          colors: colors,
          widths: [0.1, 0.2, 0.3, 0.4],
          dashPattern: (0.3, 0.2),
          closed: true,
        ),
        returnsNormally,
      );
    });

    test('rgb colors pad to rgba (solid and dashed)', () {
      final rgb = [for (final c in colors) c.sublist(0, 3)];
      final solid = buildPolyline(square, width: 0.1, colors: rgb);
      expect(solid.colors.length, solid.vertexCount * 4);
      expect(col(solid, 0), [1.0, 0.0, 0.0, 1.0]);
      final dashed = buildPolyline(
        square,
        width: 0.1,
        colors: rgb,
        dashPattern: (0.3, 0.2),
      );
      expect(dashed.colors.length, dashed.vertexCount * 4);
    });

    test('line-segment colors apply one per segment to both endpoints', () {
      final pts = [
        Vector3(0, 0, 0),
        Vector3(1, 0, 0),
        Vector3(0, 1, 0),
        Vector3(1, 1, 0),
      ];
      final m = buildLineSegments(
        pts,
        width: 0.1,
        colors: [
          [1.0, 0.0, 0.0, 1.0],
          [0.0, 0.0, 1.0],
        ],
      );
      expect(m.vertexCount, 8);
      for (var i = 0; i < 4; i++) {
        expect(col(m, i), [1.0, 0.0, 0.0, 1.0]);
        expect(col(m, 4 + i), [0.0, 0.0, 1.0, 1.0]);
      }
    });

    test('a short attribute list falls back instead of throwing', () {
      final m = buildPolyline(
        square,
        width: 0.1,
        colors: [colors[0]],
        widths: [0.2],
      );
      expect(m.colors.length, m.vertexCount * 4);
    });
  });

  group('mesh builder', () {
    test('transform leaves normals alone under pure translation', () {
      final b = D3MeshBuilder()
        ..emit(Vector3(0, 0, 0), n: Vector3(0, 0, 1))
        ..emit(Vector3(1, 0, 0), n: Vector3(0, 0, 1))
        ..emit(Vector3(0, 1, 0), n: Vector3(0, 0, 1))
        ..tri(0, 1, 2)
        ..transform(Matrix4.translationValues(5, -3, 2));
      final m = b.build();
      for (var i = 0; i < 3; i++) {
        expect(nrm(m, i).distanceTo(Vector3(0, 0, 1)), closeTo(0, 1e-9));
      }
      expect(pos(m, 1).x, 6);
    });

    test('transform uses the inverse transpose under non-uniform scale', () {
      // A 45° slope scaled 2× in x: the true normal of the stretched
      // surface is (1, 2)/√5, not the naive scaled (2, 1)/√5.
      final b = D3MeshBuilder()
        ..emit(Vector3.zero(), n: Vector3(1, 1, 0).normalized())
        ..transform(Matrix4.diagonal3Values(2, 1, 1));
      final n = nrm(b.build(), 0);
      expect(n.distanceTo(Vector3(1, 2, 0).normalized()), closeTo(0, 1e-6));
    });

    test('a reflecting transform rewinds triangles', () {
      final b = D3MeshBuilder()..addMesh(buildCuboid(Vector3(1, 2, 3)));
      b.transform(Matrix4.diagonal3Values(-1, 1, 1));
      expectOutwardWinding(b.build());
    });

    test('addMesh backfills white for uncolored meshes', () {
      final b = D3MeshBuilder()
        ..emit(Vector3.zero(), color: [1.0, 0.0, 0.0, 1.0])
        ..addMesh(buildCuboid(Vector3.all(1)));
      final m = b.build();
      expect(m.colors.length, m.vertexCount * 4);
      expect(col(m, m.vertexCount - 1), [1.0, 1.0, 1.0, 1.0]);
    });
  });

  group('instance bake reference', () {
    test('mirrored instances keep outward winding and normals', () {
      final base = buildCuboid(Vector3(1, 2, 3));
      final m = d3BakeInstances(base, [
        Matrix4.translationValues(3, 0, 0),
        Matrix4.diagonal3Values(-1, 1, 1),
        Matrix4.diagonal3Values(1, -2, 1)..setTranslationRaw(0, 5, 0),
      ]);
      expect(m.vertexCount, base.vertexCount * 3);
      expectOutwardWinding(m);
    });

    test('translation never tilts baked normals; colors stamp', () {
      final base = buildCuboid(Vector3.all(1));
      final m = d3BakeInstances(
        base,
        [Matrix4.translationValues(10, 0, 0)],
        colors: [Vector4(0.5, 0.25, 1, 1)],
      );
      for (var i = 0; i < m.vertexCount; i++) {
        expect(nrm(m, i).distanceTo(nrm(base, i)), closeTo(0, 1e-9));
        expect(col(m, i), [0.5, 0.25, 1.0, 1.0]);
      }
    });

    test('bake truncates to the vertex budget', () {
      final base = buildSphere(radius: 1, segments: 512, rings: 512);
      final m = d3BakeInstances(base, [
        for (var i = 0; i < 10; i++) Matrix4.translationValues(i * 3.0, 0, 0),
      ]);
      expect(m.vertexCount, lessThanOrEqualTo(kD3MaxBakedVertices));
      expect(m.vertexCount, base.vertexCount * 3);
    });
  });

  group('sweeps and billboards', () {
    test('closed tubes get no end caps', () {
      final pts = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)];
      final open = D3TubeProc(points: pts, radialSegments: 8, stations: 16);
      final closed = D3TubeProc(
        points: pts,
        radialSegments: 8,
        stations: 16,
        closed: true,
      );
      expect(open.build().vertexCount, 16 * 9 + 2 * 9);
      expect(closed.build().vertexCount, 16 * 9);
    });

    test('ribbon normals are perpendicular to a climbing path', () {
      final ribbon = D3RibbonProc(
        points: [Vector3(0, 0, 0), Vector3(1, 1, 0), Vector3(2, 1.5, 1)],
        width: 0.5,
        stations: 12,
      );
      final m = ribbon.build();
      final frames = ribbon.path.evenlySpacedFrames(12);
      for (var s = 0; s < 12; s++) {
        final n = nrm(m, s * 2);
        expect(n.dot(frames[s].tangent).abs(), lessThan(1e-5));
        expect(n.y, greaterThan(0)); // still the "up" side
      }
    });

    test('billboards scale before rotating', () {
      final m = buildBillboard(
        size: Vector2(2, 1),
        rotation: math.pi / 2,
        color: const [1, 1, 1, 1],
      );
      expect(m.bounds.max.x - m.bounds.min.x, closeTo(1, 1e-6));
      expect(m.bounds.max.y - m.bounds.min.y, closeTo(2, 1e-6));
    });

    test('billboard bounds cover any rotation (half-diagonal)', () {
      final proc = D3BillboardProc(size: Vector2(2, 1), rotation: math.pi / 4);
      final mesh = proc.build();
      expect(proc.bounds.max.x, greaterThanOrEqualTo(mesh.bounds.max.x));
      expect(proc.bounds.max.y, greaterThanOrEqualTo(mesh.bounds.max.y));
      expect(proc.bounds.max.x, closeTo(math.sqrt(5) / 2, 1e-6));
    });

    test('tube/ribbon bounds include Catmull-Rom overshoot', () {
      final pts = [
        Vector3(0, 0, 0),
        Vector3(1, 1, 0),
        Vector3(2, 1, 0),
        Vector3(3, 0, 0),
      ];
      final tube = D3TubeProc(points: pts, radius: 0.01, stations: 256);
      final mesh = tube.build();
      expect(mesh.bounds.max.y, greaterThan(1.1)); // the curve overshoots
      expect(tube.bounds.max.y, greaterThanOrEqualTo(mesh.bounds.max.y));
      final wire = d3ProcComponentBounds(d3ProcMeshComponent(tube))!;
      expect(wire.max.y, greaterThanOrEqualTo(mesh.bounds.max.y));
      final ribbon = D3RibbonProc(points: pts, width: 0.02, stations: 256);
      expect(
        ribbon.bounds.max.y,
        greaterThanOrEqualTo(mesh.bounds.max.y - 0.01),
      );
    });

    test('path point getters return defensive copies', () {
      final path = CatmullRomPath([Vector3.zero(), Vector3(1, 0, 0)]);
      final before = path.length;
      path.points.first.setValues(-100, 0, 0);
      expect(path.points.first, Vector3.zero());
      expect(path.length, before);
      final poly = PolylinePath([Vector3.zero(), Vector3(1, 0, 0)]);
      poly.points.last.setValues(9, 9, 9);
      expect(poly.points.last, Vector3(1, 0, 0));
    });
  });

  group('icosphere UV seam', () {
    test('no triangle interpolates across the u seam', () {
      final m = buildIcosphere(radius: 1, subdivisions: 3);
      for (var t = 0; t < m.indices.length; t += 3) {
        final u = [for (var k = 0; k < 3; k++) m.uvs[m.indices[t + k] * 2]];
        expect(
          u.reduce(math.max) - u.reduce(math.min),
          lessThan(0.5),
          reason: 'triangle ${t ~/ 3}: $u',
        );
      }
      expectOutwardWinding(m);
    });
  });
}
