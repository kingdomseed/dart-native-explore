// The screen-fitted tray: walls in the camera frustum's side planes,
// inset by the chrome, so a die anywhere inside them is on screen and
// clear of the Back/Reset row and the Roll pill.

import 'dart:math';

import 'package:dart3d_example/dice_table_scene.dart';
import 'package:dart3d_example/dice_tray_layout.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// The A142 (1084×2412 px at 2.625) in logical px, with the dice
/// screen's chrome insets: portrait and landscape.
final portrait = (
  w: 413.0,
  h: 919.0,
  l: 4.0,
  t: 24.0 + 52,
  r: 4.0,
  b: 24.0 + 96,
);
final landscape = (w: 919.0, h: 413.0, l: 40.0, t: 36.0 + 52, r: 40.0, b: 96.0);

TrayLayout fitOf(
  ({double w, double h, double l, double t, double r, double b}) s,
) => TrayLayout.fit(
  width: s.w,
  height: s.h,
  pxPerUnit: trayPxPerUnit(min(s.w, s.h)),
  insetLeft: s.l,
  insetTop: s.t,
  insetRight: s.r,
  insetBottom: s.b,
);

/// Inner face plane of a wall slab: (point, inward normal).
(Vector3, Vector3) innerPlane(TrayPose wall) {
  final x = wall.rotation.asRotationMatrix() * Vector3(1, 0, 0);
  final point = wall.position - x * (kTrayWallThick / 2);
  return (point, -x);
}

void main() {
  for (final (name, screen) in [
    ('portrait', portrait),
    ('landscape', landscape),
  ]) {
    group(name, () {
      final layout = fitOf(screen);
      final eye = layout.camera.position;

      test('d20 renders at 15% of the short side', () {
        final d20Px = kD20Diameter * layout.pxPerUnit;
        expect(d20Px / min(screen.w, screen.h), closeTo(0.15, 1e-3));
      });

      test('the play area projects exactly onto the inset screen rect', () {
        final p = layout.play;
        final (x0, y0) = layout.project(
          Vector3(p.xMin, 0, p.zMax),
          width: screen.w,
          height: screen.h,
        );
        final (x1, y1) = layout.project(
          Vector3(p.xMax, 0, p.zMin),
          width: screen.w,
          height: screen.h,
        );
        expect(x0, closeTo(screen.l, 1e-3));
        expect(y0, closeTo(screen.t, 1e-3));
        expect(x1, closeTo(screen.w - screen.r, 1e-3));
        expect(y1, closeTo(screen.h - screen.b, 1e-3));
      });

      test('camera looks straight down with screen-up = +Z', () {
        final m = layout.camera.rotation.asRotationMatrix();
        final fwd = m * Vector3(0, 0, 1), up = m * Vector3(0, 1, 0);
        expect(fwd.y, closeTo(-1, 1e-3));
        expect(up.z, closeTo(1, 1e-3));
      });

      test('each wall face contains the eye and its play edge', () {
        final p = layout.play;
        final feet = [
          Vector3(p.xMax, 0, 0),
          Vector3(p.xMin, 0, 0),
          Vector3(0, 0, p.zMax),
          Vector3(0, 0, p.zMin),
        ];
        for (final (i, wall) in layout.walls.indexed) {
          final (point, inward) = innerPlane(wall);
          expect(
            (eye - point).dot(inward),
            closeTo(0, 1e-3),
            reason: 'wall $i eye',
          );
          expect(
            (feet[i] - point).dot(inward),
            closeTo(0, 1e-3),
            reason: 'wall $i foot',
          );
          // The table centre is inside; the slab reaches under the table.
          expect((Vector3.zero() - point).dot(inward), greaterThan(0));
          // The inner face's lower edge sits kTrayWallSink under the table.
          final bottom =
              point.y -
              (wall.rotation.asRotationMatrix() * Vector3(0, 1, 0)).y *
                  kTrayWallSpan /
                  2;
          expect(bottom, closeTo(-kTrayWallSink, 1e-3));
        }
      });

      test('anything inside the walls and under the ceiling is on screen', () {
        final rng = Random(3);
        final planes = layout.walls.map(innerPlane).toList();
        var inside = 0;
        for (var i = 0; i < 20000; i++) {
          final q = Vector3(
            (rng.nextDouble() - 0.5) * 400,
            rng.nextDouble() * layout.ceilingHeight,
            (rng.nextDouble() - 0.5) * 400,
          );
          if (!planes.every((pl) => (q - pl.$1).dot(pl.$2) >= 0)) continue;
          inside++;
          final (sx, sy) = layout.project(q, width: screen.w, height: screen.h);
          expect(
            sx,
            inInclusiveRange(screen.l - 1e-3, screen.w - screen.r + 1e-3),
          );
          expect(
            sy,
            inInclusiveRange(screen.t - 1e-3, screen.h - screen.b + 1e-3),
          );
        }
        expect(inside, greaterThan(500));
      });

      test('ceiling: upstream min(dist·0.55, 7 units), below the camera', () {
        expect(
          layout.ceilingHeight,
          closeTo(min(layout.cameraHeight * 0.55, 7 * kUpstreamUnit), 1e-3),
        );
        expect(
          layout.ceiling.position.y - kTrayWallThick / 2,
          closeTo(layout.ceilingHeight, 1e-3),
        );
      });

      test('seven dice rack inside the play area without touching', () {
        const spacing = 38.0;
        final slots = layout.rack(7, spacing);
        expect(slots, hasLength(7));
        for (final (x, z) in slots) {
          expect(
            layout.contains(Vector3(x, 0, z), slack: -16),
            isTrue,
            reason: '($x, $z)',
          );
        }
        for (var i = 0; i < slots.length; i++) {
          for (var j = i + 1; j < slots.length; j++) {
            final dx = slots[i].$1 - slots[j].$1,
                dz = slots[i].$2 - slots[j].$2;
            expect(sqrt(dx * dx + dz * dz), greaterThan(33));
          }
        }
      });
    });
  }

  test('clampToPlay pulls a die back inside by its radius', () {
    final layout = fitOf(portrait);
    final out = Vector3(layout.play.xMax + 50, 9, layout.play.zMin - 50);
    final c = layout.clampToPlay(out, 10);
    expect(c.x, closeTo(layout.play.xMax - 10, 1e-3));
    expect(c.z, closeTo(layout.play.zMin + 10, 1e-3));
    expect(c.y, 9);
    expect(layout.contains(c), isTrue);
  });

  test('rotation keeps the dice the same size on screen', () {
    expect(fitOf(portrait).pxPerUnit, fitOf(landscape).pxPerUnit);
  });
}
