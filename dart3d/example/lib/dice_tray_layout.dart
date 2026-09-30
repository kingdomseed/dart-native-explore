/// The screen-fitted dice tray: a top-down camera and invisible walls
/// that follow the visible screen area (upstream "Dice Shadows": walls
/// in the camera frustum's side planes, rebuilt on every resize).
///
/// Everything here is pure geometry (no `dartnative` imports) so the
/// fit is unit-tested: the screen feeds in its size and chrome insets,
/// and writes the returned camera/wall poses as node transforms.
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

/// Vertical field of view of the tray camera (upstream: 35°). Narrow,
/// so a die's apparent size barely changes while it is in the air.
const double kTrayFovY = 35 * pi / 180;

/// Wall and ceiling slab thickness — far thicker than a die can travel
/// in one 120 Hz substep at any throw speed, so nothing tunnels.
const double kTrayWallThick = 120.0;

/// Wall slab extent along the plane (both in-plane axes). The inner
/// face is what matters; the slab only needs to cover the play volume
/// for every screen shape.
const double kTrayWallSpan = 4000.0;

/// How far the walls reach below the table surface, so a sliding die
/// finds no seam between wall and table.
const double kTrayWallSink = 40.0;

/// One upstream world unit in ours. Upstream's d6 is 0.7 units across;
/// ours is 15 — every upstream speed, gravity and height scales by this.
const double kUpstreamUnit = 15.0 / 0.7;

/// The pose of a slab: centre and rotation (document space).
typedef TrayPose = ({Vector3 position, Quaternion rotation});

/// The play area on the table (y = 0) in world units: x runs to screen
/// right, z to screen top.
typedef TrayRect = ({double xMin, double xMax, double zMin, double zMax});

/// A fitted tray for one screen size.
final class TrayLayout {
  TrayLayout._({
    required this.pxPerUnit,
    required this.cameraHeight,
    required this.ceilingHeight,
    required this.play,
    required this.walls,
    required this.ceiling,
  });

  /// Fits the tray to a [width]×[height] (logical px) view whose chrome
  /// covers [insetLeft]/[insetTop]/[insetRight]/[insetBottom] px at the
  /// edges. Dice render at [pxPerUnit] logical px per world unit on the
  /// table surface; the camera height follows from it.
  ///
  /// The camera sits over the view's centre looking straight down with
  /// screen-right = +X and screen-up = +Z. Each wall's inner face is the
  /// plane through the camera's eye and the play area's edge on the
  /// table, so a die anywhere in the tray — resting or in the air —
  /// projects inside the play area of the screen.
  factory TrayLayout.fit({
    required double width,
    required double height,
    required double pxPerUnit,
    double insetLeft = 0,
    double insetTop = 0,
    double insetRight = 0,
    double insetBottom = 0,
  }) {
    final p = pxPerUnit;
    final d = height / (2 * p * tan(kTrayFovY / 2));
    final play = (
      xMin: (insetLeft - width / 2) / p,
      xMax: (width / 2 - insetRight) / p,
      zMin: (insetBottom - height / 2) / p,
      zMax: (height / 2 - insetTop) / p,
    );
    // Upstream: ceiling at min(dist·0.55, 7 units).
    final ceilingHeight = min(d * 0.55, 7 * kUpstreamUnit);
    final eye = Vector3(0, d, 0);
    TrayPose wall(Vector3 outward, double offset) {
      final foot = outward * offset;
      final tangent = Vector3(0, 1, 0).cross(outward)..normalize();
      final up = (eye - foot)..normalize();
      final inward = up.cross(tangent)..normalize();
      if (inward.dot(outward) > 0) inward.negate();
      final x = -inward;
      final z = x.cross(up);
      // Slab centre: half a thickness outside the plane, and far enough
      // along it that the slab starts kTrayWallSink below the table.
      final start = -kTrayWallSink / up.y;
      final centre =
          foot + up * (start + kTrayWallSpan / 2) + x * (kTrayWallThick / 2);
      return (
        position: centre,
        rotation: Quaternion.fromRotation(Matrix3.columns(x, up, z)),
      );
    }

    return TrayLayout._(
      pxPerUnit: p,
      cameraHeight: d,
      ceilingHeight: ceilingHeight,
      play: play,
      walls: [
        wall(Vector3(1, 0, 0), play.xMax),
        wall(Vector3(-1, 0, 0), -play.xMin),
        wall(Vector3(0, 0, 1), play.zMax),
        wall(Vector3(0, 0, -1), -play.zMin),
      ],
      ceiling: (
        position: Vector3(0, ceilingHeight + kTrayWallThick / 2, 0),
        rotation: Quaternion.identity(),
      ),
    );
  }

  final double pxPerUnit;

  /// Camera height above the table (the table surface is y = 0).
  final double cameraHeight;
  final double ceilingHeight;
  final TrayRect play;

  /// +X, −X, +Z, −Z walls: slabs of kTrayWallThick × kTrayWallSpan ×
  /// kTrayWallSpan (local x across the slab).
  final List<TrayPose> walls;

  /// The ceiling slab: kTrayWallSpan × kTrayWallThick × kTrayWallSpan.
  final TrayPose ceiling;

  /// The camera's pose: over the origin, looking down −Y with
  /// screen-up = +Z (a +90° pitch of the +Z-forward camera).
  TrayPose get camera => (
    position: Vector3(0, cameraHeight, 0),
    rotation: Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2),
  );

  /// Screen position (logical px from the view's top-left) of a point
  /// on or above the table.
  (double, double) project(
    Vector3 p, {
    required double width,
    required double height,
  }) {
    final s = cameraHeight / (cameraHeight - p.y);
    return (width / 2 + p.x * s * pxPerUnit, height / 2 - p.z * s * pxPerUnit);
  }

  /// The point at height [y] under the screen position ([sx], [sy])
  /// (logical px from the view's top-left) — [project]'s inverse.
  Vector3 unproject(
    double sx,
    double sy, {
    required double width,
    required double height,
    double y = 0,
  }) {
    final k = _scaleAt(y) * pxPerUnit;
    return Vector3((sx - width / 2) / k, y, (height / 2 - sy) / k);
  }

  /// A screen velocity ([vx], [vy] in px/s, y down) as a world velocity
  /// on the plane at height [y].
  Vector3 screenVelocityToWorld(double vx, double vy, {double y = 0}) {
    final k = _scaleAt(y) * pxPerUnit;
    return Vector3(vx / k, 0, -vy / k);
  }

  /// Screen magnification of the plane at height [y] vs the table.
  double _scaleAt(double y) => cameraHeight / (cameraHeight - y);

  /// Outward normals of [walls], in the same order.
  static final List<Vector3> wallNormals = [
    Vector3(1, 0, 0),
    Vector3(-1, 0, 0),
    Vector3(0, 0, 1),
    Vector3(0, 0, -1),
  ];

  /// Wall [i]'s inner face, as a horizontal offset from the tray's
  /// centre line along its outward normal, at height [y]. The faces lean
  /// in toward the camera's eye.
  double wallOffsetAt(int i, double y) {
    final base = switch (i) {
      0 => play.xMax,
      1 => -play.xMin,
      2 => play.zMax,
      _ => -play.zMin,
    };
    return base * (cameraHeight - y) / cameraHeight;
  }

  /// How far [p] lies beyond wall [i]'s inner face, horizontally
  /// (negative inside). A point beyond any wall is off-screen.
  double outside(int i, Vector3 p) =>
      p.dot(wallNormals[i]) - wallOffsetAt(i, p.y);

  /// Whether a body of [radius] at [p] is fully inside every wall.
  bool holds(Vector3 p, double radius) {
    for (var i = 0; i < 4; i++) {
      if (outside(i, p) > -radius) return false;
    }
    return true;
  }

  /// Wall [i]'s pose moved [by] units outward — an open entry gate.
  TrayPose wallOpened(int i, double by) => (
    position: walls[i].position + wallNormals[i] * by,
    rotation: walls[i].rotation,
  );

  /// [p] pulled inside every wall by [margin] at its own height.
  Vector3 clampInside(Vector3 p, double margin) {
    final out = p.clone();
    for (final (axis, hi, lo) in const [(0, 0, 1), (2, 2, 3)]) {
      final top = wallOffsetAt(hi, p.y) - margin;
      final bottom = -wallOffsetAt(lo, p.y) + margin;
      final v = axis == 0 ? out.x : out.z;
      final c = bottom > top ? (top + bottom) / 2 : v.clamp(bottom, top);
      if (axis == 0) {
        out.x = c;
      } else {
        out.z = c;
      }
    }
    return out;
  }

  /// [p] pulled inside the play area by [margin] on each side (y kept).
  Vector3 clampToPlay(Vector3 p, double margin) {
    double c(double v, double lo, double hi) =>
        lo > hi ? (lo + hi) / 2 : v.clamp(lo, hi);
    return Vector3(
      c(p.x, play.xMin + margin, play.xMax - margin),
      p.y,
      c(p.z, play.zMin + margin, play.zMax - margin),
    );
  }

  /// Whether [p] (on the table) lies inside the play area, allowing
  /// [slack] beyond it.
  bool contains(Vector3 p, {double slack = 0}) =>
      p.x >= play.xMin - slack &&
      p.x <= play.xMax + slack &&
      p.z >= play.zMin - slack &&
      p.z <= play.zMax + slack;

  /// [count] rack positions (x, z) on a grid of [spacing] centred in the
  /// play area — as many columns as fit, filled screen-top first.
  List<(double, double)> rack(int count, double spacing) {
    final w = play.xMax - play.xMin, h = play.zMax - play.zMin;
    final cols = max(1, min(count, (w / spacing).floor()));
    final rows = (count / cols).ceil();
    final cx = (play.xMin + play.xMax) / 2, cz = (play.zMin + play.zMax) / 2;
    final rowGap = min(spacing, h / max(rows, 1));
    final out = <(double, double)>[];
    for (var i = 0; i < count; i++) {
      final r = i ~/ cols, c = i % cols;
      final inRow = r == rows - 1 ? count - r * cols : cols;
      out.add((
        cx + (c - (inRow - 1) / 2) * spacing,
        cz + ((rows - 1) / 2 - r) * rowGap,
      ));
    }
    return out;
  }
}
