// W16 checks: the `trail`/`lod` component wire shapes plus the
// pure-Dart reference math both natives port — the point-buffer
// policy (head-follow, distance anchors, lifetime/capacity expiry)
// and the LOD screen-size metric with threshold selection (cull floor
// included). Same constraint as the W3–W12 tests: the barrel is
// unreachable under `dart test`, so this pulls the pure-Dart library
// directly.
// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/trail_lod.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const geoId = LocalId(3, 7);
  const matId = LocalId(3, 8);

  group('trailComponent', () {
    test('emits upstream field names with defaults', () {
      final c = trailComponent();
      expect(c.type, 'trail');
      expect((c.properties['width'] as DoubleValue).value, 0.25);
      expect((c.properties['lifetime'] as DoubleValue).value, 0.6);
      expect((c.properties['minVertexDistance'] as DoubleValue).value, 0.05);
      expect((c.properties['maxPoints'] as IntValue).value, 48);
      expect((c.properties['emitting'] as BoolValue).value, isTrue);
      // Upstream's TrailCodec serializes no trail material — the
      // natives draw the translucent vertex-color default.
      expect(c.properties.containsKey('material'), isFalse);
    });

    test('ramps serialize inside upstream curve/gradient maps', () {
      final c = trailComponent(
        widthOverTrail: const [TrailStop(0, 1), TrailStop(1, 0)],
        colorOverTrail: const [
          TrailColorStop(0, ColorValue(1, 1, 1, 1)),
          TrailColorStop(1, ColorValue(1, 0, 0, 0)),
        ],
      );
      // widthOverTrail is upstream's ParticleCurve shape:
      // `{keys: [{t, v}, …]}` — not a bare stop list.
      final w = (c.properties['widthOverTrail'] as MapValue).values;
      final keys = (w['keys'] as ListValue).values;
      expect((keys[0] as MapValue).values.keys, containsAll(['t', 'v']));
      // colorOverTrail is upstream's ColorGradient shape:
      // `{stops: [{t, color}, …]}`.
      final col = (c.properties['colorOverTrail'] as MapValue).values;
      final stops = (col['stops'] as ListValue).values;
      expect(((stops[1] as MapValue).values['color'] as ColorValue).a, 0);
    });
  });

  group('lodComponent', () {
    test('levels carry geometry+material refs and screenSize', () {
      final c = lodComponent(
        levels: [
          LodLevel(geometry: geoId, material: matId, screenSize: 0.3),
          LodLevel(geometry: geoId, material: matId, screenSize: 0.0),
        ],
        lodBias: 2.0,
        hysteresis: 0.1,
        blendRange: 0.2,
      );
      expect(c.type, 'lod');
      final levels = (c.properties['levels'] as ListValue).values;
      expect(levels, hasLength(2));
      final l0 = (levels[0] as MapValue).values;
      expect((l0['geometry'] as ResourceRefValue).id, geoId);
      // Upstream requires a material ref on every level — a
      // material-less entry is skipped by its codec.
      expect((l0['material'] as ResourceRefValue).id, matId);
      expect((l0['screenSize'] as DoubleValue).value, 0.3);
      expect((c.properties['lodBias'] as DoubleValue).value, 2.0);
      // hysteresis is upstream's dead-band (the natives apply it);
      // blendRange stays a documented no-op — decoded for parity.
      expect((c.properties['hysteresis'] as DoubleValue).value, 0.1);
      expect((c.properties['blendRange'] as DoubleValue).value, 0.2);
    });
  });

  group('decodeLodLevels', () {
    test('an absent screenSize survives as the 0.0 never-cull '
        'threshold', () {
      // Upstream LodCodec._levelEntries drops a level only for a
      // missing/mistyped geometry or material ref — an absent
      // screenSize decodes as 0.0. The natives port this rule;
      // dropping the level instead would turn the previous
      // threshold into a cull floor upstream never has.
      final levels = decodeLodLevels({
        'levels': ListValue([
          MapValue({
            'geometry': ResourceRefValue(geoId),
            'material': ResourceRefValue(matId),
            'screenSize': DoubleValue(0.3),
          }),
          MapValue({
            'geometry': ResourceRefValue(geoId),
            'material': ResourceRefValue(matId),
          }),
        ]),
      });
      expect(levels, hasLength(2));
      expect(levels[1].screenSize, 0.0);
      // The 0.0 tail threshold never culls, however small the
      // projected size reads.
      expect(selectLodLevel(0.001, [for (final l in levels) l.screenSize]), 1);
    });

    test('a malformed screenSize falls back to 0.0; bad refs still '
        'drop the level', () {
      final levels = decodeLodLevels({
        'levels': ListValue([
          MapValue({
            'geometry': ResourceRefValue(geoId),
            'material': ResourceRefValue(matId),
            // Mistyped (non-numeric) — upstream's `_ => 0.0` arm.
            'screenSize': StringValue('wide'),
          }),
          MapValue({
            'geometry': ResourceRefValue(geoId),
            // No material ref — the entry drops like upstream.
            'screenSize': DoubleValue(0.5),
          }),
          MapValue({
            'geometry': IntValue(4), // not a ResourceRefValue
            'material': ResourceRefValue(matId),
            'screenSize': DoubleValue(0.5),
          }),
        ]),
      });
      expect(levels, hasLength(1));
      expect(levels.single.screenSize, 0.0);
      expect(levels.single.geometry, geoId);
    });
  });

  group('TrailPointBuffer', () {
    TrailPointBuffer buffer({
      double lifetime = 0.6,
      double minVertexDistance = 0.05,
      int maxPoints = 48,
    }) => TrailPointBuffer(
      lifetime: lifetime,
      minVertexDistance: minVertexDistance,
      maxPoints: maxPoints,
    );

    test('first update anchors; the head then follows continuously', () {
      final b = buffer();
      b.update(0.016, Vector3(0, 0, 0));
      expect(b.length, 1);
      b.update(0.016, Vector3(0.01, 0, 0));
      // length==1 forces the anchor — the moving head splits into a
      // follower plus the previous position.
      expect(b.length, 2);
      // Under minVertexDistance the head tracks without anchoring.
      b.update(0.016, Vector3(0.02, 0, 0));
      expect(b.length, 2);
      expect(b.points.first.x, closeTo(0.02, 1e-9));
    });

    test('a new anchor drops once minVertexDistance is traveled', () {
      final b = buffer();
      b.update(0.016, Vector3(0, 0, 0));
      b.update(0.016, Vector3(0.01, 0, 0));
      b.update(0.016, Vector3(0.08, 0, 0)); // 0.07 past the anchor
      expect(b.length, 3);
      // The newest anchor records the crossing position — the head at
      // insert time — and the previous anchor stays behind it.
      expect(b.points.first.x, closeTo(0.08, 1e-6));
      expect(b.points[1].x, closeTo(0.08, 1e-6));
      expect(b.points[2].x, closeTo(0.01, 1e-6));
    });

    test('points older than lifetime expire from the tail', () {
      final b = buffer(lifetime: 0.5);
      b.update(0.0, Vector3(0, 0, 0));
      b.update(0.4, Vector3(1, 0, 0));
      expect(b.length, greaterThan(1));
      // Stepping past lifetime retires everything but the head.
      b.update(0.6, Vector3(1, 0, 0));
      expect(b.length, 1);
    });

    test('maxPoints bounds the buffer, oldest first', () {
      final b = buffer(maxPoints: 4, lifetime: 100);
      var x = 0.0;
      for (var i = 0; i < 10; i++) {
        x += 0.1;
        b.update(0.016, Vector3(x, 0, 0));
      }
      expect(b.length, 4);
      expect(b.points.first.x, closeTo(x, 1e-9));
      // The tail is the oldest kept anchor, not the origin.
      expect(b.points.last.x, greaterThan(0.5));
    });

    test('emitting:false freezes recording while the path ages', () {
      final b = buffer(lifetime: 0.3);
      b.update(0.0, Vector3(0, 0, 0));
      b.update(0.1, Vector3(1, 0, 0));
      final count = b.length;
      b.emitting = false;
      b.update(0.1, Vector3(5, 0, 0));
      expect(b.length, count); // no new anchor while paused
      expect(b.points.first.x, isNot(5)); // head stops following too
      b.update(0.4, Vector3(9, 0, 0));
      expect(b.length, 0); // lifetime drains the remainder
    });

    test('clear forgets the path', () {
      final b = buffer();
      b.update(0.0, Vector3(0, 0, 0));
      b.update(0.1, Vector3(1, 0, 0));
      b.clear();
      expect(b.length, 0);
    });
  });

  group('sampleTrailStops', () {
    const stops = [TrailStop(0, 1), TrailStop(0.5, 0.5), TrailStop(1, 0)];

    test('absent ramp is the upstream taper 1−t', () {
      expect(sampleTrailStops(const [], 0.25), closeTo(0.75, 1e-9));
    });

    test('piecewise-linear between stops, clamped at the ends', () {
      expect(sampleTrailStops(stops, 0), 1);
      expect(sampleTrailStops(stops, 0.25), closeTo(0.75, 1e-9));
      expect(sampleTrailStops(stops, 0.75), closeTo(0.25, 1e-9));
      expect(sampleTrailStops(stops, -1), 1);
      expect(sampleTrailStops(stops, 2), 0);
    });
  });

  group('sampleTrailColorStops', () {
    const stops = [
      TrailColorStop(0, ColorValue(1, 1, 1, 1)),
      TrailColorStop(1, ColorValue(1, 0, 0, 0)),
    ];

    test('absent gradient is the upstream white fade', () {
      final c = sampleTrailColorStops(const [], 0.25);
      expect(c.r, 1);
      expect(c.a, closeTo(0.75, 1e-9));
    });

    test('lerps rgba between stops, clamped at the ends', () {
      final mid = sampleTrailColorStops(stops, 0.5);
      expect(mid.g, closeTo(0.5, 1e-9));
      expect(mid.a, closeTo(0.5, 1e-9));
      expect(sampleTrailColorStops(stops, -1).a, 1);
      expect(sampleTrailColorStops(stops, 2).a, 0);
    });
  });

  group('expandTrailRibbon', () {
    test('offsets perpendicular to tangent and view', () {
      // Straight path along +X, camera above on +Z: the ribbon widens
      // along ±Y (the axis perpendicular to both).
      final verts = expandTrailRibbon(
        [Vector3(1, 0, 0), Vector3(0, 0, 0)],
        [0.4, 0.4],
        Vector3(0, 0, 5),
      );
      expect(verts, hasLength(4));
      for (var i = 0; i < 2; i++) {
        final l = verts[i * 2];
        final r = verts[i * 2 + 1];
        expect(l.y, closeTo(-0.2, 1e-6));
        expect(r.y, closeTo(0.2, 1e-6));
        expect(l.x, closeTo(i == 0 ? 1 : 0, 1e-9));
      }
    });

    test('zero-width tail points collapse to the anchor', () {
      final verts = expandTrailRibbon(
        [Vector3(1, 0, 0), Vector3(0, 0, 0)],
        [0.4, 0.0],
        Vector3(0, 0, 5),
      );
      expect(verts[2], equals(Vector3(0, 0, 0)));
      expect(verts[3], equals(Vector3(0, 0, 0)));
    });
  });

  group('lodScreenSize', () {
    test('fraction of viewport height for a perspective camera', () {
      // radius 0.5 sphere, 10 units out, 60° vertical fov:
      // 0.5 / (10 · tan30°) ≈ 0.0866.
      final s = lodScreenSize(
        center: Vector3(0, 0, 0),
        radius: 0.5,
        cameraPosition: Vector3(0, 0, 10),
        fovRadiansY: math.pi / 3,
      );
      expect(s, closeTo(0.5 / (10 * math.tan(math.pi / 6)), 1e-9));
    });

    test('a camera inside the sphere reads infinity (max detail)', () {
      final s = lodScreenSize(
        center: Vector3(0, 0, 0),
        radius: 2,
        cameraPosition: Vector3(0, 0, 1),
        fovRadiansY: math.pi / 3,
      );
      expect(s, double.infinity);
    });
  });

  group('selectLodLevel', () {
    const thresholds = [0.3, 0.1, 0.0];

    test('picks the first level whose threshold the size meets', () {
      expect(selectLodLevel(0.5, thresholds), 0);
      expect(selectLodLevel(0.3, thresholds), 0);
      expect(selectLodLevel(0.15, thresholds), 1);
      expect(selectLodLevel(0.05, thresholds), 2);
    });

    test('a last threshold of 0 never culls', () {
      expect(selectLodLevel(0.001, thresholds), 2);
    });

    test('below a positive floor culls', () {
      expect(selectLodLevel(0.05, const [0.3, 0.1]), -1);
      expect(selectLodLevel(0.1, const [0.3, 0.1]), 1);
    });

    test('lodBias scales the size before selection', () {
      expect(selectLodLevel(0.05, const [0.3, 0.1], lodBias: 3), 1);
      expect(selectLodLevel(0.6, thresholds, lodBias: 0.1), 2);
    });

    test('hysteresis holds an adjacent crossing inside the dead-band', () {
      // thresholds [0.3, 0.1, 0.0], hysteresis 0.1: the coarser arm
      // watches the CURRENT level's lower boundary — level 1 holds
      // until size < 0.1·(1−0.1) = 0.09.
      expect(
        selectLodLevel(0.095, thresholds, hysteresis: 0.1, currentLevel: 1),
        1,
      );
      expect(
        selectLodLevel(0.089, thresholds, hysteresis: 0.1, currentLevel: 1),
        2,
      );
      // The finer arm watches the upper boundary: level 1 holds until
      // size ≥ 0.3·(1+0.1) = 0.33.
      expect(
        selectLodLevel(0.31, thresholds, hysteresis: 0.1, currentLevel: 1),
        1,
      );
      expect(
        selectLodLevel(0.33, thresholds, hysteresis: 0.1, currentLevel: 1),
        0,
      );
    });

    test('hysteresis gates the cull floor both ways', () {
      const t = [0.3, 0.1];
      // Level 1 (the last) holds until size < 0.1·(1−h) = 0.09.
      expect(selectLodLevel(0.095, t, hysteresis: 0.1, currentLevel: 1), 1);
      expect(selectLodLevel(0.08, t, hysteresis: 0.1, currentLevel: 1), -1);
      // Culled: the last level re-binds only past 0.1·(1+h) = 0.11
      // (the float product lands a hair above the literal — use a
      // clearly-crossing size).
      expect(selectLodLevel(0.105, t, hysteresis: 0.1, currentLevel: -1), -1);
      expect(selectLodLevel(0.115, t, hysteresis: 0.1, currentLevel: -1), 1);
    });

    test('a multi-level jump switches immediately through the band', () {
      expect(
        selectLodLevel(0.5, thresholds, hysteresis: 0.1, currentLevel: 2),
        0,
      );
      expect(
        selectLodLevel(0.001, thresholds, hysteresis: 0.1, currentLevel: 0),
        2,
      );
    });
  });
}
