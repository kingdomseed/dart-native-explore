// DR2 "dice feel": the d4 shard's numerals read upright from the top-down
// camera, cocked dice are detected and nudged flat (never teleported),
// and the throw / toss / sweep math (fling velocity, aim throw from
// off-screen, hold cluster).
// ignore_for_file: implementation_imports

import 'dart:math';

import 'package:dart3d_example/dice_numerals.dart';
import 'package:dart3d_example/dice_polyhedra.dart';
import 'package:dart3d_example/dice_set.dart';
import 'package:dart3d_example/dice_settle.dart';
import 'package:dart3d_example/dice_shard_d4.dart';
import 'package:dart3d_example/dice_table_scene.dart';
import 'package:dart3d_example/dice_throw.dart';
import 'package:dart3d_example/dice_tray_layout.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// The A142 portrait dice screen (DR1 fit log).
final layout = TrayLayout.fit(
  width: 413,
  height: 919,
  pxPerUnit: trayPxPerUnit(413),
  insetLeft: 10,
  insetTop: 104,
  insetRight: 10,
  insetBottom: 134,
);

const gravity = 30 * kUpstreamUnit;

/// A rotation taking mesh-space [n] to +Y, then [yaw] about +Y.
Quaternion faceUp(Vector3 n, double yaw) =>
    Quaternion.axisAngle(Vector3(0, 1, 0), yaw) * faceUpRotation(n);

final DieGeo shardGeo = buildDieGeo('d4');

/// The shard's face map.
final DieFaceMap shardFaceMap = DieFaceMap(
  faces: [for (final f in shardGeo.numbered) DieFace(f.normal, f.value!)],
);

/// The shard's long faces as (mesh-space direction of image-right +u,
/// of image-up −v, face normal), solved from the drawn mesh's UVs on
/// each face's first flat triangle.
List<(Vector3, Vector3, Vector3)> shardFaceFrames() {
  final mesh = buildDieMesh(shardGeo, buildDieAtlas(shardGeo));
  final p = mesh.positions, t = mesh.uvs, n = mesh.normals;
  final out = <(Vector3, Vector3, Vector3)>[];
  for (final f in shardGeo.numbered) {
    for (var i = 0; i < mesh.indices.length; i += 3) {
      final a = mesh.indices[i], b = mesh.indices[i + 1];
      final c = mesh.indices[i + 2];
      if ([a, b, c].any((k) => n[k].dot(f.normal) < 0.99999)) continue;
      // Solve the linear map (du, dv) → position over the triangle.
      final e1 = p[b] - p[a], e2 = p[c] - p[a];
      final d1 = t[b] - t[a], d2 = t[c] - t[a];
      final det = d1.x * d2.y - d1.y * d2.x;
      final dPdu = (e1 * d2.y - e2 * d1.y) / det;
      final dPdv = (e2 * d1.x - e1 * d2.x) / det;
      out.add((dPdu.normalized(), (-dPdv).normalized(), f.normal));
      break;
    }
  }
  return out;
}

void main() {
  group('d4 shard reads upright', () {
    test('numerals read along the crystal: up across it, right to +X', () {
      final frames = shardFaceFrames();
      expect(frames, hasLength(4));
      for (final (right, up, n) in frames) {
        expect(up.dot(shardGlyphUp(n)), closeTo(1, 1e-5), reason: '$n');
        // Right is the long axis — the numeral's baseline runs along it.
        expect(right.dot(kShardAxis), closeTo(1, 1e-5), reason: '$n');
        // The document's screen-right convention (n × up): not mirrored.
        expect(right.dot(n.cross(up)), closeTo(1, 1e-5), reason: '$n');
      }
    });

    test('the rack pose reads upright on screen', () {
      // Racked: identity rotation, +Y (the 4) up, the +X tip screen-right.
      final (face, _) = shardFaceMap.top(Quaternion.identity());
      expect(face.value, 4);
      final up = shardGlyphUp(face.normal);
      // Screen-up is document +Z on the top-down camera.
      expect(up.z, closeTo(1, 1e-6));
      expect(shardUprightYaw(Quaternion.identity(), face.normal), 0);
    });

    test('rolling about the long axis keeps every face upright', () {
      for (var k = 0; k < 4; k++) {
        final q = Quaternion.axisAngle(kShardAxis, k * pi / 2);
        final (face, dot) = shardFaceMap.top(q);
        expect(dot, closeTo(1, 1e-6));
        expect(shardUprightYaw(q, face.normal), closeTo(0, 1e-6));
      }
    });

    test('yaw error is the numeral\'s turn from screen-up', () {
      for (final face in shardFaceMap.faces) {
        for (final yaw in [-2.9, -1.2, -0.3, 0.0, 0.5, 1.6, 3.0]) {
          final base = faceUp(face.normal, 0);
          final e0 = shardUprightYaw(base, face.normal);
          final q = Quaternion.axisAngle(Vector3(0, 1, 0), yaw) * base;
          final e = shardUprightYaw(q, face.normal);
          var diff = e - e0 - yaw;
          diff = atan2(sin(diff), cos(diff));
          expect(diff, closeTo(0, 1e-6), reason: '${face.value} $yaw');
          // Turning back by −e reads upright.
          final fixed = Quaternion.axisAngle(Vector3(0, 1, 0), -e) * q;
          expect(shardUprightYaw(fixed, face.normal), closeTo(0, 1e-6));
        }
      }
    });

    test('the turn servo settles upright from any start, with lag', () {
      for (var start = -3.1; start <= 3.1; start += 0.37) {
        // Integrate at 60 fps with two frames of pose-read latency and
        // 10% friction loss per frame.
        var yaw = start;
        final history = [yaw, yaw];
        var t = 0.0;
        var rate = 0.0;
        while (t < 2.0) {
          rate = uprightTurnRate(history.first);
          yaw += rate * 0.9 / 60;
          history
            ..removeAt(0)
            ..add(yaw);
          t += 1 / 60;
          if (rate == 0 && uprightTurnRate(yaw) == 0) break;
        }
        expect(yaw.abs(), lessThan(kUprightTolerance * 1.6), reason: '$start');
        expect(t, lessThan(1.6), reason: 'start $start took ${t}s');
      }
    });
  });

  group('cocked dice', () {
    final maps = <String, DieFaceMap>{
      'd4': shardFaceMap,
      'd6': DieFaceMap(
        faces: [
          for (final (n, v) in [
            (Vector3(0, 1, 0), 1),
            (Vector3(0, -1, 0), 6),
            (Vector3(1, 0, 0), 2),
            (Vector3(-1, 0, 0), 5),
            (Vector3(0, 0, 1), 3),
            (Vector3(0, 0, -1), 4),
          ])
            DieFace(n, v),
        ],
      ),
      'd20': _icosahedronMap(),
    };

    test('a die flat on a face is not cocked; small wobble neither', () {
      for (final MapEntry(key: label, value: map) in maps.entries) {
        for (final f in map.faces) {
          for (final tilt in [0.0, 2 * pi / 180, 5 * pi / 180]) {
            final q =
                Quaternion.axisAngle(Vector3(0.6, 0, 0.8), tilt) *
                faceUp(f.normal, 0.7);
            expect(isCocked(map, q), isFalse, reason: '$label $tilt');
          }
        }
      }
    });

    test('an edge-rest is cocked on every die — even the round d20', () {
      for (final MapEntry(key: label, value: map) in maps.entries) {
        // Resting on the edge between a face and its nearest neighbour:
        // halfway between the two normals points up.
        final a = map.faces.first;
        final b = map.faces
            .skip(1)
            .reduce(
              (x, y) => x.normal.dot(a.normal) > y.normal.dot(a.normal) ? x : y,
            );
        final mid = (a.normal + b.normal).normalized();
        final q = faceUpRotation(mid);
        expect(isCocked(map, q), isTrue, reason: label);
      }
      // Upstream's plain 0.9 threshold misses the d20 edge-rest.
      final d20 = maps['d20']!;
      expect(flatDotFor(d20), greaterThan(0.95));
    });

    test('leaning 20° on a wall or die is cocked', () {
      for (final MapEntry(key: label, value: map) in maps.entries) {
        final q =
            Quaternion.axisAngle(Vector3(1, 0, 0), 20 * pi / 180) *
            faceUp(map.faces.first.normal, 0);
        expect(isCocked(map, q), isTrue, reason: label);
      }
    });

    test('the nudge hops, pushes away and spins the up face level', () {
      final map = maps['d6']!;
      // Leaning 30° against a die to its −X side.
      final q =
          Quaternion.axisAngle(Vector3(0, 0, 1), 30 * pi / 180) *
          faceUp(map.faces.first.normal, 0);
      final p = Vector3(0, 9, 0);
      final kick = cockedNudge(
        position: p,
        rotation: q,
        faceMap: map,
        radius: 10,
        gravity: gravity,
        layout: layout,
        neighbours: [(Vector3(-15, 9, 0), 10)],
        rng: Random(1),
      );
      expect(kick.linear.y, greaterThan(0));
      expect(kick.linear.x, greaterThan(0), reason: 'away from the neighbour');
      // Over the hop's flight the spin turns the up face level.
      final flight = 2 * kick.linear.y / gravity;
      final after = Quaternion.axisAngle(kick.axis, kick.rate * flight) * q;
      final (_, dot) = map.top(after);
      expect(dot, closeTo(1, 1e-6));
      // A small hop: under a radius.
      expect(kick.linear.y * kick.linear.y / (2 * gravity), lessThan(10));
    });

    test('a die leaning on a wall is pushed back into the tray', () {
      final map = maps['d20']!;
      final q =
          Quaternion.axisAngle(Vector3(1, 0, 0), 25 * pi / 180) *
          faceUp(map.faces.first.normal, 0);
      final p = Vector3(0, 9, layout.play.zMax - 9);
      final kick = cockedNudge(
        position: p,
        rotation: q,
        faceMap: map,
        radius: 10,
        gravity: gravity,
        layout: layout,
        rng: Random(2),
      );
      expect(kick.linear.z, lessThan(0));
    });
  });

  group('fling', () {
    test('a steady drag reads its speed; a stopped finger has none', () {
      final f = FlingTracker();
      for (var i = 0; i <= 12; i++) {
        final t = i / 120;
        f.add(t, 100 + 900 * t, 500 - 1200 * t);
      }
      final v = f.velocity(12 / 120 + 0.01);
      expect(v.x, closeTo(900, 1));
      expect(v.y, closeTo(-1200, 1));
      // Lifted 100 ms after the last move: the finger had stopped.
      expect(f.velocity(12 / 120 + 0.1).length, 0);
    });

    test('only the last 100 ms count (a flick at the end)', () {
      final f = FlingTracker();
      // Slow for 400 ms, then a fast flick for 80 ms.
      for (var i = 0; i <= 48; i++) {
        f.add(i / 120, i * 1.0, 0);
      }
      for (var i = 1; i <= 10; i++) {
        f.add(0.4 + i / 120, 48 + 20.0 * i, 0);
      }
      expect(f.velocity(0.4 + 10 / 120).x, greaterThan(1800));
    });

    test('screen fling → world velocity on the hover plane', () {
      final h = hoverHeight(layout, 11.7);
      final w = layout.screenVelocityToWorld(1000, -500, y: h);
      final k = layout.cameraHeight / (layout.cameraHeight - h);
      expect(w.x, closeTo(1000 / (layout.pxPerUnit * k), 1e-4));
      // Screen-up (−y) is world +Z.
      expect(w.z, closeTo(500 / (layout.pxPerUnit * k), 1e-4));
      expect(w.y, 0);
    });

    test('unproject inverts project at any height', () {
      for (final y in [0.0, 30.0, 60.0]) {
        final p = layout.unproject(300, 200, width: 413, height: 919, y: y);
        final (sx, sy) = layout.project(p, width: 413, height: 919);
        expect(sx, closeTo(300, 1e-4));
        expect(sy, closeTo(200, 1e-4));
        expect(p.y, y);
      }
    });

    test('a toss keeps the fling heading, capped; a drop just falls', () {
      final rng = Random(3);
      final fast = tossLaunch(Vector3(2000, 0, -3000), 10, rng);
      expect(fast.linear.x / -fast.linear.z, closeTo(2000 / 3000, 1e-5));
      final flat = Vector3(fast.linear.x, 0, fast.linear.z);
      expect(flat.length, closeTo(kMaxLaunch, 1e-3));
      expect(fast.linear.y, greaterThan(0));
      // Forward roll: the spin axis is up × heading (mostly).
      final roll = Vector3(0, 1, 0).cross(flat.normalized());
      expect(fast.axis.dot(roll), greaterThan(0.5));
      final drop = tossLaunch(Vector3(5, 0, 5), 10, rng);
      expect(drop.linear.y, 0);
      expect(drop.linear.length, lessThan(10));
    });
  });

  group('aim throw', () {
    final radii = [11.7, 10.6, 11.0, 10.4, 10.4, 10.5, 9.63];

    test('strength and speed follow the pull', () {
      expect(aimStrength(10), 0);
      expect(aimStrength(kFullPull / 2), closeTo(0.5, 1e-9));
      expect(aimStrength(2000), 1);
      expect(aimSpeed(1), closeTo(26 * kUpstreamUnit, 1e-9));
      expect(aimSpeed(0), greaterThan(0));
    });

    test('Poisson cluster: no two dice overlap', () {
      for (var seed = 0; seed < 30; seed++) {
        final c = poissonCluster(radii, Random(seed));
        for (var i = 0; i < c.length; i++) {
          for (var j = i + 1; j < c.length; j++) {
            expect(
              c[i].distanceTo(c[j]),
              greaterThanOrEqualTo(radii[i] + radii[j]),
            );
          }
        }
      }
    });

    for (final (name, dir) in [
      ('up the screen', Vector2(0, 1)),
      ('down', Vector2(0, -1)),
      ('right', Vector2(1, 0)),
      ('diagonal', Vector2(-0.6, 0.8)),
    ]) {
      test('spawns off-screen behind the arrow and flies in: $name', () {
        for (var seed = 0; seed < 8; seed++) {
          final plan = planThrow(
            layout: layout,
            direction: dir,
            strength: seed / 7,
            radii: radii,
            gravity: gravity,
            rng: Random(seed),
          );
          expect(plan.dice, hasLength(radii.length));
          expect(plan.gates, isNotEmpty);
          for (final (i, d) in plan.dice.indexed) {
            final p = d.position;
            // Beyond some wall: off-screen, inside an opened gate.
            var beyond = false;
            for (var w = 0; w < 4; w++) {
              final out = layout.outside(w, p);
              if (out > radii[i]) beyond = true;
              if (out > -radii[i]) {
                expect(plan.gates.containsKey(w), isTrue);
                expect(plan.gates[w]!, greaterThan(out + radii[i]));
              }
            }
            expect(beyond, isTrue, reason: '$name die $i');
            // Moving along the arrow.
            final flat = Vector2(d.linear.x, d.linear.z);
            expect(flat.normalized().dot(dir.normalized()), greaterThan(0.8));
            // Ballistic: it touches down (y = radius) inside the tray.
            final vy = d.linear.y;
            final tLand =
                (vy + sqrt(vy * vy + 2 * gravity * (p.y - radii[i]))) / gravity;
            final land = p + Vector3(d.linear.x, 0, d.linear.z) * tLand
              ..y = 0;
            expect(
              layout.holds(land, 0),
              isTrue,
              reason: '$name die $i lands at $land',
            );
            // And never reaches the ceiling.
            final apex = p.y + vy * vy / (2 * gravity);
            expect(apex + radii[i], lessThan(layout.ceilingHeight));
          }
        }
      });
    }

    test('spin is mostly end over end along the throw', () {
      final plan = planThrow(
        layout: layout,
        direction: Vector2(0, 1),
        strength: 0.8,
        radii: radii,
        gravity: gravity,
        rng: Random(4),
      );
      var forward = 0;
      for (final d in plan.dice) {
        final w = d.angularAxis * d.angularRate;
        // Forward roll along +Z is about up × +Z = +X.
        if (w.x > 0) forward++;
      }
      expect(forward, greaterThanOrEqualTo(5));
    });
  });

  test('hold cluster: dice never overlap', () {
    final radii = [11.7, 10.6, 11.0, 10.4, 10.4, 10.5, 9.63];
    final o = holdOffsets(radii);
    expect(o, hasLength(7));
    for (var i = 0; i < o.length; i++) {
      for (var j = i + 1; j < o.length; j++) {
        expect(o[i].distanceTo(o[j]), greaterThan(radii[i] + radii[j]));
      }
    }
    expect(hoverHeight(layout, 11.7), lessThan(layout.ceilingHeight - 23));
  });

  test('sweep: hits within reach, shoves along the finger with a hop', () {
    expect(sweepHits(Vector3.zero(), Vector3(12, 5, 0), 10), isTrue);
    expect(sweepHits(Vector3.zero(), Vector3(16, 5, 0), 10), isFalse);
    final s = sweepShove(Vector3(400, 0, 0), 10, Random(5));
    expect(s.linear.x, closeTo(320, 1e-3));
    expect(s.linear.y, greaterThan(0));
    final hard = sweepShove(Vector3(0, 0, 5000), 10, Random(5));
    expect(
      Vector3(hard.linear.x, 0, hard.linear.z).length,
      closeTo(kMaxLaunch, 1e-3),
    );
  });

  group('gesture arbiter', () {
    test('a quick drag from the table aims; from a die sweeps', () {
      final g = GestureArbiter()..down(0, 100, 100, onDie: false);
      expect(g.move(0.05, 104, 103), DiceGesture.pending);
      expect(g.move(0.08, 140, 100), DiceGesture.aim);
      expect(g.up(), DiceGesture.aim);
      g.down(1, 100, 100, onDie: true);
      expect(g.move(1.05, 130, 100), DiceGesture.sweep);
      // A long hold later doesn't change a drag.
      expect(g.tick(3), DiceGesture.sweep);
    });

    test('holding still picks the dice up, anywhere', () {
      final g = GestureArbiter()..down(0, 100, 100, onDie: false);
      expect(g.tick(0.2), DiceGesture.pending);
      expect(g.move(0.25, 103, 102), DiceGesture.pending);
      expect(g.tick(kHoldDelay), DiceGesture.hold);
      // Moving now carries the dice — it stays a hold.
      expect(g.move(0.5, 300, 300), DiceGesture.hold);
      expect(g.up(), DiceGesture.hold);
      expect(g.state, isNull);
    });
  });
}

/// A d20's face map from the icosahedron's face normals (values are
/// arbitrary here; only the geometry matters).
DieFaceMap _icosahedronMap() {
  final phi = (1 + sqrt(5)) / 2;
  final v = <Vector3>[
    for (final s1 in [-1.0, 1.0])
      for (final s2 in [-1.0, 1.0]) ...[
        Vector3(0, s1, s2 * phi),
        Vector3(s1, s2 * phi, 0),
        Vector3(s2 * phi, 0, s1),
      ],
  ];
  final edge = 2.0;
  final faces = <DieFace>[];
  for (var i = 0; i < v.length; i++) {
    for (var j = i + 1; j < v.length; j++) {
      for (var k = j + 1; k < v.length; k++) {
        if ((v[i].distanceTo(v[j]) - edge).abs() > 1e-6 ||
            (v[j].distanceTo(v[k]) - edge).abs() > 1e-6 ||
            (v[i].distanceTo(v[k]) - edge).abs() > 1e-6) {
          continue;
        }
        faces.add(DieFace((v[i] + v[j] + v[k]).normalized(), faces.length + 1));
      }
    }
  }
  return DieFaceMap(faces: faces);
}
