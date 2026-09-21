// W26 checks: the expanded geometry vocabulary (CPU generators, bounds,
// wire encoding) plus the Catmull-Rom path helper and the `d3:instances`
// component — pinned by briefs/w26-instancing.md. Same constraint as the
// W3–W12 tests: package:dart3d/dart3d.dart is unreachable under `dart
// test` (the barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly.
// ignore_for_file: implementation_imports

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/geometry/instances.dart';
import 'package:dart3d/src/geometry/mesh_data.dart';
import 'package:dart3d/src/geometry/paths.dart';
import 'package:dart3d/src/geometry/proc.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/world_bounds.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// Vertex i of a mesh as a Vector3.
Vector3 vertex(D3MeshData m, int i) =>
    Vector3(m.positions[i * 3], m.positions[i * 3 + 1], m.positions[i * 3 + 2]);

void main() {
  group('icosphere (real subdivided icosahedron)', () {
    test('subdivision 0 is the base icosahedron', () {
      final m = buildIcosphere(radius: 1.0, subdivisions: 0);
      expect(m.vertexCount, 12);
      expect(m.triangleCount, 20);
    });

    test('each subdivision quadruples faces via midpoint splits', () {
      // Euler characteristic: V1 = 12 + 30 edges, V2 = 42 + 120.
      final s1 = buildIcosphere(radius: 1.0, subdivisions: 1);
      expect(s1.vertexCount, 42);
      expect(s1.triangleCount, 80);
      final s2 = buildIcosphere(radius: 1.0, subdivisions: 2);
      expect(s2.vertexCount, 162);
      expect(s2.triangleCount, 320);
    });

    test('every vertex lies on the radius — not a UV-sphere banding', () {
      const radius = 0.7;
      final m = buildIcosphere(radius: radius, subdivisions: 2);
      for (var i = 0; i < m.vertexCount; i++) {
        expect(vertex(m, i).length, closeTo(radius, 1e-6));
      }
      expect(m.bounds.min.x, closeTo(-radius, 1e-6));
      expect(m.bounds.max.y, closeTo(radius, 1e-6));
      // A UV sphere's normals tilt off-radial at non-pole verts; a
      // geodesic's normal IS its position direction everywhere.
      for (var i = 0; i < m.vertexCount; i++) {
        final v = vertex(m, i);
        final n = Vector3(
          m.normals[i * 3],
          m.normals[i * 3 + 1],
          m.normals[i * 3 + 2],
        );
        expect(n.distanceTo(v / radius), closeTo(0, 1e-6));
      }
    });
  });

  group('primitive generators', () {
    test('cylinder emits side grid plus both caps', () {
      // (1+1) rings × 9 cols = 18 side verts; each cap = 1 + 9.
      final m = buildCylinder(
        bottomRadius: 0.5,
        topRadius: 0.5,
        height: 2.0,
        radialSegments: 8,
        heightSegments: 1,
        bottomCap: true,
        topCap: true,
      );
      expect(m.vertexCount, 18 + 2 * 10);
      expect(m.triangleCount, 16 + 8 + 8);
      expect(m.bounds.min.y, closeTo(-1.0, 1e-6));
      expect(m.bounds.max.y, closeTo(1.0, 1e-6));
      // Side normals tilt outward (a straight cylinder → pure radial).
      final sideNormal = Vector3(m.normals[0], m.normals[1], m.normals[2]);
      expect(sideNormal.y, closeTo(0, 1e-6));
      expect(sideNormal.length, closeTo(1, 1e-6));
    });

    test('cone drops the apex degenerate tris and the top cap', () {
      final m = D3ConeProc(radius: 0.5, height: 1, radialSegments: 8).build();
      // Side grid is the same 18 verts; apex row collapses so only the
      // 8 lower-fan tris emit; bottom cap adds 10 verts + 8 tris.
      expect(m.vertexCount, 28);
      expect(m.triangleCount, 16);
      // The apex y is at +height/2.
      expect(m.bounds.max.y, closeTo(0.5, 1e-6));
    });

    test('capsule shares equator rings between hemispheres', () {
      // 2 cap rings per hemisphere → 3 + 3 = 6 ring rows × 9 cols.
      final m = buildCapsule(
        radius: 0.5,
        height: 1.0,
        radialSegments: 8,
        capRings: 2,
      );
      expect(m.vertexCount, 54);
      expect(m.triangleCount, 5 * 8 * 2);
      // Total height = height + 2*radius.
      expect(m.bounds.min.y, closeTo(-1.0, 1e-6));
      expect(m.bounds.max.y, closeTo(1.0, 1e-6));
    });

    test('disc is a fan in the XZ plane facing +Y', () {
      final m = buildDisc(radius: 2.0, segments: 8);
      expect(m.vertexCount, 10);
      expect(m.triangleCount, 8);
      for (var i = 0; i < m.vertexCount; i++) {
        expect(m.normals[i * 3 + 1], closeTo(1.0, 1e-6));
      }
      expect(m.bounds.max.x, closeTo(2.0, 1e-6));
      expect(m.bounds.min.y, 0.0);
      expect(m.bounds.max.y, 0.0);
    });

    test('plane lies in XZ and winds facing +Y', () {
      // The wire contract: width spans X, depth spans Z, the sheet
      // sits at y=0 and its front face is +Y — the winding must agree
      // with the attribute normal (the old XY/+Z SCNPlane shape
      // silently produced an edge-on ground lane).
      final m = buildPlane(width: 4.0, depth: 2.0, segmentsX: 2, segmentsZ: 1);
      expect(m.vertexCount, 6);
      expect(m.triangleCount, 4);
      for (var i = 0; i < m.vertexCount; i++) {
        expect(m.positions[i * 3 + 1], 0.0);
        expect(m.normals[i * 3 + 1], closeTo(1.0, 1e-6));
      }
      expect(m.bounds.min.x, closeTo(-2.0, 1e-6));
      expect(m.bounds.max.x, closeTo(2.0, 1e-6));
      expect(m.bounds.min.z, closeTo(-1.0, 1e-6));
      expect(m.bounds.max.z, closeTo(1.0, 1e-6));
      // Every triangle's geometric normal is +Y — cross(e1, e2) of
      // quad(a, a+cols, a+1, a+cols+1) rows.
      for (var t = 0; t < m.triangleCount; t++) {
        final a = vertex(m, m.indices[t * 3]);
        final b = vertex(m, m.indices[t * 3 + 1]);
        final c = vertex(m, m.indices[t * 3 + 2]);
        final n = (b - a).cross(c - a);
        expect(n.x, closeTo(0.0, 1e-6), reason: 'tri $t');
        expect(n.y, greaterThan(0.0), reason: 'tri $t faces +Y');
        expect(n.z, closeTo(0.0, 1e-6), reason: 'tri $t');
      }
    });

    test('cuboid debugColors keys vertex color to corner sign bits', () {
      final m = D3CuboidProc(
        extents: Vector3(2, 2, 2),
        debugColors: true,
      ).build();
      expect(m.vertexCount, 24);
      expect(m.colors.length, m.vertexCount * 4);
      for (var i = 0; i < m.vertexCount; i++) {
        final p = vertex(m, i);
        // The position's sign bits map to rgb — the same corner
        // convention both native ports implement.
        expect(m.colors[i * 4], p.x >= 0 ? 1.0 : 0.0, reason: 'v$i r');
        expect(m.colors[i * 4 + 1], p.y >= 0 ? 1.0 : 0.0, reason: 'v$i g');
        expect(m.colors[i * 4 + 2], p.z >= 0 ? 1.0 : 0.0, reason: 'v$i b');
        expect(m.colors[i * 4 + 3], 1.0, reason: 'v$i a');
      }
    });

    test('tube sweeps rings along the path and fans both caps', () {
      final path = PolylinePath([Vector3(0, 0, 0), Vector3(0, 0, 2)]);
      final m = buildTube(
        path,
        radius: 0.25,
        radialSegments: 6,
        stations: 4,
        caps: true,
      );
      // 4 rings × (6+1) verts + 2 caps × (1+6).
      expect(m.vertexCount, 28 + 14);
      // 3 spans × 6 quads × 2 tris + 6 fan tris per cap.
      expect(m.triangleCount, 36 + 12);
      // Ring radius is honored: max |xy| distance from the z axis ≈ r.
      var maxR = 0.0;
      for (var i = 0; i < 28; i++) {
        final v = vertex(m, i);
        maxR = math.max(maxR, math.sqrt(v.x * v.x + v.y * v.y));
      }
      expect(maxR, closeTo(0.25, 1e-6));
    });

    test('ribbon is a two-vert-per-station strip', () {
      final path = CatmullRomPath([
        Vector3(0, 0, 0),
        Vector3(1, 0, 0),
        Vector3(2, 0, 0),
      ]);
      final m = buildRibbon(
        path,
        width: 0.5,
        stations: 4,
        up: Vector3(0, 1, 0),
      );
      expect(m.vertexCount, 8);
      expect(m.triangleCount, 6);
      // The strip lies across the path — normals follow `up`.
      for (var i = 0; i < 8; i++) {
        expect(m.normals[i * 3 + 1], closeTo(1.0, 1e-6));
      }
    });

    test('billboard emits one quad at the origin', () {
      final m = buildBillboard(
        size: Vector2(2, 1),
        rotation: 0,
        color: const [1, 1, 1, 1],
      );
      expect(m.vertexCount, 4);
      expect(m.triangleCount, 2);
      expect(m.bounds.max.x, closeTo(1.0, 1e-6));
      expect(m.bounds.max.y, closeTo(0.5, 1e-6));
    });
  });

  group('polyline expansion', () {
    test('a solid 3-point line emits one quad per span', () {
      final m = buildPolyline([
        Vector3(0, 0, 0),
        Vector3(1, 0, 0),
        Vector3(2, 0, 0),
      ], width: 0.1);
      expect(m.vertexCount, 8);
      expect(m.triangleCount, 4);
    });

    test('closed repeats the first point for the wrap span', () {
      final m = buildPolyline(
        [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)],
        width: 0.1,
        closed: true,
      );
      expect(m.vertexCount, 12); // three spans, three quads
      expect(m.triangleCount, 6);
    });

    test('dashes walk arc length across segment boundaries', () {
      // Length-10 line, dashes (2, 1): on spans [0,2] [3,5] [6,8]
      // [9,10] → four quads.
      final m = buildPolyline(
        [Vector3(0, 0, 0), Vector3(10, 0, 0)],
        width: 0.1,
        dashPattern: (2.0, 1.0),
      );
      expect(m.vertexCount, 16);
      expect(m.triangleCount, 8);
      // Quad i covers x ∈ [spanStart, spanEnd] — collect each quad's
      // min/max x and compare to the expected dash boundaries.
      final spans = <(double, double)>[];
      for (var q = 0; q < 4; q++) {
        var lo = double.infinity, hi = -double.infinity;
        for (var v = 0; v < 4; v++) {
          final x = m.positions[(q * 4 + v) * 3];
          lo = math.min(lo, x);
          hi = math.max(hi, x);
        }
        spans.add((lo, hi));
      }
      const expected = [(0.0, 2.0), (3.0, 5.0), (6.0, 8.0), (9.0, 10.0)];
      for (var i = 0; i < 4; i++) {
        expect(spans[i].$1, closeTo(expected[i].$1, 1e-5));
        expect(spans[i].$2, closeTo(expected[i].$2, 1e-5));
      }
    });

    test('the dash cursor carries across vertices', () {
      // Two 1.5-unit segments, dashes (2, 1): the on span [0,2]
      // crosses the vertex at 1.5 — one quad per segment touched,
      // both inside the same dash.
      final m = buildPolyline(
        [Vector3(0, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, 3.0)],
        width: 0.1,
        dashPattern: (2.0, 1.0),
      );
      expect(m.vertexCount, 8);
      expect(m.triangleCount, 4);
      var hi = -double.infinity;
      for (var i = 0; i < 8; i++) {
        hi = math.max(hi, m.positions[i * 3 + 2].toDouble());
      }
      // The second quad stops mid-segment at the dash boundary —
      // a cursor reset at the vertex would draw the whole span.
      expect(hi, closeTo(2.0, 1e-5));
    });

    test('line segments emit independent quads', () {
      final m = buildLineSegments([
        Vector3(0, 0, 0),
        Vector3(1, 0, 0),
        Vector3(0, 1, 0),
        Vector3(0, 1, 1),
      ], width: 0.1);
      expect(m.vertexCount, 8);
      expect(m.triangleCount, 4);
    });
  });

  group('CatmullRomPath', () {
    final curve = CatmullRomPath([
      Vector3(0, 0, 0),
      Vector3(1, 1, 0),
      Vector3(2, 1, 0),
      Vector3(3, 0, 0),
    ]);

    test('interpolates every control point at its natural parameter', () {
      for (var i = 0; i < 4; i++) {
        final p = curve.positionAt(i / 3);
        expect(p.x, closeTo(curve.points[i].x, 1e-6));
        expect(p.y, closeTo(curve.points[i].y, 1e-6));
        expect(p.z, closeTo(curve.points[i].z, 1e-6));
      }
    });

    test('arc length exceeds the chord for a bent path', () {
      // The curve bends up and back — its arc length overshoots the
      // straight 3.0 endpoint distance.
      expect(curve.length, greaterThan(3.0));
      expect(curve.length.isFinite, isTrue);
    });

    test('a straight polyline measures its exact length', () {
      final line = PolylinePath([Vector3(0, 0, 0), Vector3(0, 0, 5)]);
      expect(line.length, closeTo(5.0, 1e-6));
      expect(line.positionAtDistance(2.5).z, closeTo(2.5, 1e-5));
    });

    test('frames are orthonormal and rotation-minimizing', () {
      for (final f in curve.evenlySpacedFrames(9)) {
        expect(f.tangent.length, closeTo(1, 1e-5));
        expect(f.normal.length, closeTo(1, 1e-5));
        expect(f.binormal.length, closeTo(1, 1e-5));
        expect(f.tangent.dot(f.normal).abs(), lessThan(1e-4));
        expect(f.tangent.dot(f.binormal).abs(), lessThan(1e-4));
      }
    });

    test('arc-length parameterization spaces samples evenly', () {
      final line = PolylinePath([
        Vector3(0, 0, 0),
        Vector3(0, 0, 1),
        Vector3(0, 0, 4),
      ]);
      final samples = line.sample(5, evenlySpaced: true);
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i].distanceTo(samples[i - 1]), closeTo(1.0, 1e-5));
      }
    });
  });

  group('d3:instances', () {
    test('the component carries shape, transforms and attributes', () {
      final spec = D3InstancesSpec(
        proc: D3SphereProc(radius: 0.1),
        transforms: D3InstanceTransforms.inline([
          Matrix4.identity()..setTranslationRaw(1, 0, 0),
          Matrix4.identity()..setTranslationRaw(-1, 0, 0),
        ]),
        attributes: {
          'color': D3InstanceAttribute.inline([
            Vector4(1, 0, 0, 1),
            Vector4(0, 1, 0, 1),
          ]),
        },
      );
      final comp = spec.toComponent();
      expect(comp.type, kD3InstancesType);
      expect(comp.properties['shape'], isA<StringValue>());
      final transforms = comp.properties['transforms'] as ListValue;
      expect(transforms.values, hasLength(2));
      expect(transforms.values.first, isA<Matrix4Value>());
      final attrs = comp.properties['attributes'] as MapValue;
      expect(attrs.values['color'], isA<ListValue>());
      expect(spec.count, 2);
    });

    test('exactly one of geometry/proc is required', () {
      expect(
        () => D3InstancesSpec(
          transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
        ).toComponent(),
        throwsA(anything),
      );
      expect(
        () => D3InstancesSpec(
          geometry: const LocalId(9, 9),
          proc: D3SphereProc(),
          transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
        ).toComponent(),
        throwsA(anything),
      );
    });

    test('billboard mode carries size and rotation', () {
      final comp = D3InstancesSpec(
        proc: D3BillboardProc(),
        transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
        billboard: true,
        size: Vector2(0.5, 0.25),
        rotation: 0.5,
      ).toComponent();
      expect(comp.properties['billboard'], const BoolValue(true));
      expect(comp.properties['size'], isA<Vec2Value>());
      expect(comp.properties['rotation'], isA<DoubleValue>());
    });

    test('payload encoders pack column-major f32', () {
      final m = Matrix4.identity()..setTranslationRaw(4, 5, 6);
      final mp = d3MatricesPayload(const LocalId(1, 1), [m]);
      expect(mp.encoding, PayloadEncoding.matrices);
      expect(mp.bytes!.length, 64);
      final floats = Float32List.view(mp.bytes!.buffer);
      expect(floats[12], closeTo(4, 1e-6)); // column-major translation
      expect(floats[13], closeTo(5, 1e-6));
      expect(floats[14], closeTo(6, 1e-6));

      final fp = d3FloatsPayload(const LocalId(1, 2), [Vector4(1, 2, 3, 4)]);
      expect(fp.encoding, PayloadEncoding.floats);
      final vf = Float32List.view(fp.bytes!.buffer);
      expect(vf.toList(), [1.0, 2.0, 3.0, 4.0]);
    });

    test('bounds union the geometry AABB over every transform', () {
      final spec = D3InstancesSpec(
        proc: D3SphereProc(radius: 0.5),
        transforms: D3InstanceTransforms.inline([
          Matrix4.identity()..setTranslationRaw(10, 0, 0),
          Matrix4.identity()..setTranslationRaw(-10, 0, 0),
        ]),
      );
      final b = spec.bounds(null)!;
      expect(b.min.x, closeTo(-10.5, 1e-6));
      expect(b.max.x, closeTo(10.5, 1e-6));
      expect(b.max.y, closeTo(0.5, 1e-6));
    });
  });

  group('component wire flow', () {
    test('d3:procMesh encodes through the manifest node codec', () {
      final doc = SceneDocument();
      final node = doc.addNode(
        NodeSpec(
          id: const LocalId(7, 1),
          components: [
            d3ProcMeshComponent(D3CylinderProc(radialSegments: 12, height: 2)),
          ],
        ),
        root: true,
      );
      final spec = encodeNodeCommandSpec(node, doc);
      final comps = spec['components']! as List;
      final comp = comps.single as Map;
      expect(comp['type'], 'd3:procMesh');
      final props = comp['properties'] as Map;
      expect(props['shape'], {'s': 'cylinder'});
      expect(props['radialSegments'], {'i': 12});
      expect(props['height'], {'d': 2.0});
    });

    test('points lists encode as tagged v3 entries', () {
      final doc = SceneDocument();
      final node = doc.addNode(
        NodeSpec(
          id: const LocalId(7, 2),
          components: [
            d3ProcMeshComponent(
              D3PolylineProc(
                points: [Vector3(0, 0, 0), Vector3(1, 2, 3)],
                width: 0.1,
                dashPattern: (0.5, 0.25),
              ),
            ),
          ],
        ),
        root: true,
      );
      final props =
          (encodeNodeCommandSpec(node, doc)['components']! as List).single
              as Map;
      final bag = props['properties'] as Map;
      expect(bag['shape'], {'s': 'polyline'});
      expect(bag['dashes'], {
        'v2': [0.5, 0.25],
      });
      expect(bag['points'], {
        'list': [
          {
            'v3': [0.0, 0.0, 0.0],
          },
          {
            'v3': [1.0, 2.0, 3.0],
          },
        ],
      });
    });

    test('d3:instances encodes inline matrices and attributes', () {
      final doc = SceneDocument();
      final node = doc.addNode(
        NodeSpec(
          id: const LocalId(7, 3),
          components: [
            D3InstancesSpec(
              proc: D3DiscProc(radius: 1),
              transforms: D3InstanceTransforms.inline([
                Matrix4.identity()..setTranslationRaw(0, 0, 5),
              ]),
              attributes: {
                'color': D3InstanceAttribute.inline([Vector4(1, 0, 0, 1)]),
              },
            ).toComponent(),
          ],
        ),
        root: true,
      );
      final comp =
          (encodeNodeCommandSpec(node, doc)['components']! as List).single
              as Map;
      expect(comp['type'], 'd3:instances');
      final props = comp['properties'] as Map;
      expect(props['shape'], {'s': 'disc'});
      final transforms = props['transforms'] as Map;
      expect(transforms['list'], hasLength(1));
      expect((transforms['list']! as List).single, {
        'm4': (Matrix4.identity()..setTranslationRaw(0, 0, 5)).storage.toList(),
      });
      expect(props['attributes'], {
        'map': {
          'color': {
            'list': [
              {
                'v4': [1.0, 0.0, 0.0, 1.0],
              },
            ],
          },
        },
      });
    });
  });

  group('bounds', () {
    test('every vocabulary shape resolves local bounds', () {
      final shapes = <D3Proc>[
        D3CuboidProc(extents: Vector3(2, 2, 2)),
        D3PlaneProc(width: 4, depth: 4),
        D3SphereProc(radius: 1),
        D3TorusProc(radius: 1, tubeRadius: 0.2),
        D3IcosphereProc(radius: 1),
        D3CylinderProc(height: 2),
        D3ConeProc(height: 2),
        D3CapsuleProc(height: 2),
        D3DiscProc(radius: 1),
        D3TubeProc(points: [Vector3(0, 0, 0), Vector3(2, 0, 0)]),
        D3RibbonProc(points: [Vector3(0, 0, 0), Vector3(2, 0, 0)]),
        D3PolylineProc(points: [Vector3(0, 0, 0), Vector3(2, 0, 0)]),
        D3LineSegmentsProc(points: [Vector3(0, 0, 0), Vector3(2, 0, 0)]),
        D3BillboardProc(),
      ];
      for (final proc in shapes) {
        final b = d3ProcShapeBounds(proc.shape, proc.props);
        expect(b, isNotNull, reason: '${proc.shape} bounds');
        expect(b!.min.x, lessThanOrEqualTo(b.max.x));
        expect(b.min.y, lessThanOrEqualTo(b.max.y));
        expect(b.min.z, lessThanOrEqualTo(b.max.z));
      }
      // The set is the whole vocabulary — a new shape without a
      // bounds entry fails this test.
      expect(shapes.map((p) => p.shape).toSet(), kD3ProcShapes);
    });

    test('generated meshes stay inside their declared bounds', () {
      for (final proc in [
        D3CylinderProc(radialSegments: 16, height: 2),
        D3ConeProc(radialSegments: 16),
        D3CapsuleProc(radialSegments: 16, capRings: 4),
        D3IcosphereProc(radius: 0.5, subdivisions: 2),
        D3DiscProc(radius: 1.5, segments: 16),
      ]) {
        final mesh = proc.build();
        final b = proc.bounds;
        const eps = 1e-4;
        expect(
          mesh.bounds.min.x,
          greaterThanOrEqualTo(b.min.x - eps),
          reason: proc.shape,
        );
        expect(
          mesh.bounds.min.y,
          greaterThanOrEqualTo(b.min.y - eps),
          reason: proc.shape,
        );
        expect(
          mesh.bounds.min.z,
          greaterThanOrEqualTo(b.min.z - eps),
          reason: proc.shape,
        );
        expect(
          mesh.bounds.max.x,
          lessThanOrEqualTo(b.max.x + eps),
          reason: proc.shape,
        );
        expect(
          mesh.bounds.max.y,
          lessThanOrEqualTo(b.max.y + eps),
          reason: proc.shape,
        );
        expect(
          mesh.bounds.max.z,
          lessThanOrEqualTo(b.max.z + eps),
          reason: proc.shape,
        );
      }
    });

    test('the w26 showcase loads procedurally with the instance field', () {
      final item = showcaseItems.firstWhere((i) => i.label == 'w26');
      final scene = loadShowcaseScene(item)!;
      final doc = scene.document;
      final types = <String>{};
      var procNodes = 0, instanceNodes = 0;
      for (final node in doc.nodes.values) {
        for (final comp in node.components) {
          types.add(comp.type);
          if (comp.type == kD3ProcMeshType) procNodes++;
          if (comp.type == kD3InstancesType) instanceNodes++;
        }
      }
      // The 13 authored procMesh nodes + the two instance nodes.
      expect(procNodes, 13);
      expect(instanceNodes, 2);
      // The 1000-matrix field ships as payload chunks.
      final matrices = doc.payloads.values.where(
        (p) => p.encoding == PayloadEncoding.matrices,
      );
      expect(matrices.single.bytes!.length, 1000 * 64);
      // One transform payload + one color payload defer until the
      // natives' upsertPayload — refs resolve, so nothing stays
      // deferred in the authored doc.
      expect(types, containsAll(['d3:procMesh', 'd3:instances']));
      expect(scene.frameRadius, greaterThan(1));
    });

    test('documentWorldBounds covers procMesh and instances nodes', () {
      final doc = SceneDocument();
      doc.addNode(
        NodeSpec(
          id: const LocalId(8, 1),
          transform: TrsTransform(translation: Vector3(5, 0, 0)),
          components: [d3ProcMeshComponent(D3SphereProc(radius: 1))],
        ),
        root: true,
      );
      doc.addNode(
        NodeSpec(
          id: const LocalId(8, 2),
          transform: TrsTransform(translation: Vector3(0, 0, 9)),
          components: [
            D3InstancesSpec(
              proc: D3DiscProc(radius: 1),
              transforms: D3InstanceTransforms.inline([
                Matrix4.identity()..setTranslationRaw(0, 0, 0),
                Matrix4.identity()..setTranslationRaw(2, 0, 0),
              ]),
            ).toComponent(),
          ],
        ),
        root: true,
      );
      final b = documentWorldBounds(doc)!;
      expect(b.$1.x, closeTo(-1.0, 1e-6)); // instances disc at x=-1..3
      expect(b.$2.x, closeTo(6.0, 1e-6)); // sphere node at x=5 r=1
      expect(b.$1.z, closeTo(-1.0, 1e-6));
      expect(b.$2.z, closeTo(10.0, 1e-6));
    });
  });
}
