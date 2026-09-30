/// How the dice leave your hand (demo-program §5.5 DR2): the aim arrow
/// and the throw it plans (dice spawn off-screen behind the arrow and
/// fly in along it), pick-up-and-toss (a long press lifts the dice to a
/// hover plane; the release flings them with the finger's velocity), and
/// the sweep (a drag that starts on a die shoves the dice it passes).
///
/// Pure Dart (no `dartnative` imports) so `dart test` covers the math;
/// the screen (`dice_table.dart`) feeds in pointer samples and writes
/// the results as transforms and velocities. Distances are world units,
/// times seconds; upstream's constants (in its own units) scale by
/// [kUpstreamUnit].
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

import 'dice_tray_layout.dart';

/// Finger travel (logical px) that turns a press into a drag.
const double kDragSlop = 10;

/// A press held this long without moving picks the dice up.
const double kHoldDelay = 0.28;

/// Aim pulls under this many px are ignored (upstream).
const double kMinPull = 24;

/// The pull (px) that throws at full strength (upstream).
const double kFullPull = 420;

/// Aim strength for a pull of [pullPx]: 0 below [kMinPull], 1 at
/// [kFullPull].
double aimStrength(double pullPx) =>
    pullPx < kMinPull ? 0 : (pullPx / kFullPull).clamp(0.0, 1.0);

/// Launch speed (world u/s) for an aim [strength]: upstream's 3–28 u/s
/// range, floored at 8 so a gentle pull still carries the dice in.
double aimSpeed(double strength) =>
    (8 + 18 * strength.clamp(0.0, 1.0)) * kUpstreamUnit;

/// The fastest a toss or sweep may launch a die (upstream's 28 u/s).
const double kMaxLaunch = 28 * kUpstreamUnit;

/// Estimates a finger's velocity from its recent samples — a least-
/// squares line through the last [window] seconds, like Flutter's
/// VelocityTracker. A finger that stopped before lifting has no fling.
final class FlingTracker {
  FlingTracker({this.window = 0.1, this.stopAfter = 0.06});

  /// How far back (s) samples count.
  final double window;

  /// A gap (s) between the last move and the release that means the
  /// finger stopped: the fling is zero.
  final double stopAfter;

  final _t = <double>[];
  final _x = <double>[];
  final _y = <double>[];

  void reset() {
    _t.clear();
    _x.clear();
    _y.clear();
  }

  /// How many samples are held, and the time of the last (s).
  int get samples => _t.length;
  double get lastTime => _t.isEmpty ? double.negativeInfinity : _t.last;

  /// Records the finger at ([x], [y]) px at time [t] s.
  void add(double t, double x, double y) {
    _t.add(t);
    _x.add(x);
    _y.add(y);
    // Keep a little more than the window.
    while (_t.length > 2 && _t.first < t - window * 2) {
      _t.removeAt(0);
      _x.removeAt(0);
      _y.removeAt(0);
    }
  }

  /// The velocity (px/s) at time [now] — the release.
  Vector2 velocity(double now) {
    if (_t.length < 2 || now - _t.last > stopAfter) return Vector2.zero();
    final from = _t.last - window;
    var n = 0;
    var st = 0.0, sx = 0.0, sy = 0.0, stt = 0.0, stx = 0.0, sty = 0.0;
    for (var i = 0; i < _t.length; i++) {
      if (_t[i] < from) continue;
      final t = _t[i] - _t.last;
      n++;
      st += t;
      sx += _x[i];
      sy += _y[i];
      stt += t * t;
      stx += t * _x[i];
      sty += t * _y[i];
    }
    final den = n * stt - st * st;
    if (n < 2 || den.abs() < 1e-12) return Vector2.zero();
    return Vector2((n * stx - st * sx) / den, (n * sty - st * sy) / den);
  }
}

/// One die's launch: where it starts, how it's turned, and its
/// velocities (angular as axis and rate, like `setBodyVelocity`).
final class DieLaunch {
  const DieLaunch({
    required this.position,
    required this.rotation,
    required this.linear,
    required this.angularAxis,
    required this.angularRate,
  });

  final Vector3 position;
  final Quaternion rotation;
  final Vector3 linear;
  final Vector3 angularAxis;
  final double angularRate;
}

/// A planned aim throw: the launches, in the order of the radii passed
/// to [planThrow], and the walls to open (index → how far outward) so
/// the dice can fly in from beyond the screen edge.
final class ThrowPlan {
  const ThrowPlan({required this.dice, required this.gates});

  final List<DieLaunch> dice;
  final Map<int, double> gates;
}

/// Offsets (x, z) of [radii].length dice in a loose Poisson cluster: no
/// two closer than their radii plus [gap], packed as tightly as random
/// placement allows. Deterministic for a given [rng].
List<Vector2> poissonCluster(
  List<double> radii,
  Random rng, {
  double gap = 2.0,
}) {
  if (radii.isEmpty) return const [];
  final maxR = radii.reduce(max);
  var extent = maxR * 1.4 * sqrt(radii.length);
  while (true) {
    final out = <Vector2>[];
    var ok = true;
    for (final r in radii) {
      Vector2? placed;
      for (var attempt = 0; attempt < 80 && placed == null; attempt++) {
        final a = rng.nextDouble() * 2 * pi;
        final d = sqrt(rng.nextDouble()) * extent;
        final c = Vector2(cos(a) * d, sin(a) * d);
        var clear = true;
        for (var j = 0; j < out.length; j++) {
          if (c.distanceTo(out[j]) < r + radii[j] + gap) {
            clear = false;
            break;
          }
        }
        if (clear) placed = c;
      }
      if (placed == null) {
        ok = false;
        break;
      }
      out.add(placed);
    }
    if (ok) return out;
    extent *= 1.15;
  }
}

/// A uniformly random rotation.
Quaternion randomRotation(Random rng) {
  final u1 = rng.nextDouble(), u2 = rng.nextDouble(), u3 = rng.nextDouble();
  final a = sqrt(1 - u1), b = sqrt(u1);
  return Quaternion(
    a * sin(2 * pi * u2),
    a * cos(2 * pi * u2),
    b * sin(2 * pi * u3),
    b * cos(2 * pi * u3),
  )..normalize();
}

/// Plans an aim throw along [direction] (world x/z, any length) at
/// [strength] 0–1, upstream-style: the dice spawn as a Poisson cluster
/// off-screen behind the arrow's tail, low over the table, and fly in
/// along the arrow — speed per [aimSpeed] ±10%, a little sideways
/// scatter, a lift solved ballistically so they touch down inside the
/// tray (deeper for a harder pull), and spin that is mostly end over end
/// along the throw plus a random tumble.
///
/// [spinScales] retunes the spin per die (round dice roll on their own;
/// the d4 shard needs more); [longAxes] adds a spin about a die's long
/// axis (mesh space) — the shard rolls about it much more readily than
/// end over end.
ThrowPlan planThrow({
  required TrayLayout layout,
  required Vector2 direction,
  required double strength,
  required List<double> radii,
  required double gravity,
  required Random rng,
  List<double>? spinScales,
  List<Vector3?>? longAxes,
}) {
  final up = Vector3(0, 1, 0);
  final d2 = direction.length < 1e-9 ? Vector2(0, 1) : direction.normalized();
  final dir = Vector3(d2.x, 0, d2.y);
  final side = up.cross(dir); // screen-left of the throw
  final play = layout.play;
  final centre = Vector3(
    (play.xMin + play.xMax) / 2,
    0,
    (play.zMin + play.zMax) / 2,
  );
  // Where a line from the centre back along −dir leaves the play area,
  // and where it leaves forward — the throw's lane across the tray.
  double exitAlong(Vector3 d) {
    var t = double.infinity;
    if (d.x > 1e-9) t = min(t, (play.xMax - centre.x) / d.x);
    if (d.x < -1e-9) t = min(t, (play.xMin - centre.x) / d.x);
    if (d.z > 1e-9) t = min(t, (play.zMax - centre.z) / d.z);
    if (d.z < -1e-9) t = min(t, (play.zMin - centre.z) / d.z);
    return t;
  }

  final back = exitAlong(-dir), ahead = exitAlong(dir);
  final entry = centre - dir * back;
  final lane = back + ahead;

  final maxR = radii.reduce(max);
  final h0 = maxR * 1.6;
  final cluster = poissonCluster(radii, rng);
  // Cluster offsets, with the cluster's own extent along the throw.
  final offsets = [for (final c in cluster) Vector3(c.x, 0, c.y)];
  var reach = 0.0;
  for (final (i, o) in offsets.indexed) {
    reach = max(reach, o.length + radii[i]);
  }
  // Back the cluster off until every die is beyond a wall — off-screen.
  var spawn = entry - dir * (reach + maxR);
  bool offScreen(Vector3 c) {
    for (final (i, o) in offsets.indexed) {
      final p = c + o
        ..y = h0;
      var beyond = false;
      for (var w = 0; w < 4; w++) {
        if (layout.outside(w, p) > radii[i] * 1.1) beyond = true;
      }
      if (!beyond) return false;
    }
    return true;
  }

  for (var k = 0; k < 40 && !offScreen(spawn); k++) {
    spawn = spawn - dir * (maxR * 0.5);
  }
  spawn.y = h0;

  // Walls in the way: open each far enough to clear the whole cluster.
  final gates = <int, double>{};
  for (final (i, o) in offsets.indexed) {
    final p = spawn + o;
    for (var w = 0; w < 4; w++) {
      final out = layout.outside(w, p);
      if (out > -radii[i] * 1.5) {
        gates[w] = max(gates[w] ?? 0, out + radii[i] * 3 + 10);
      }
    }
  }

  final s = strength.clamp(0.0, 1.0);
  // The cluster's centre touches down past its own reach from the
  // entry edge — deeper for a harder pull — so its trailing dice land
  // inside too.
  final room = max(lane - 2 * reach, 0.0);
  final touchdown = entry + dir * (reach + maxR + room * (0.1 + 0.35 * s));
  final ceilingClear = layout.ceilingHeight - maxR * 2.2;
  final launches = <DieLaunch>[];
  for (final (i, o) in offsets.indexed) {
    final p = spawn + o;
    final speed = aimSpeed(s) * (0.9 + rng.nextDouble() * 0.2);
    final target = touchdown + o;
    final flat = Vector3(target.x - p.x, 0, target.z - p.z);
    final dist = max(flat.length, maxR);
    final t = dist / speed;
    final g = gravity;
    // Lift that touches down (centre one radius up) at `target` after
    // `t`, jittered 0–15% longer (never short: the lane's entry edge is
    // right behind), never reaching the ceiling.
    var vy =
        (0.5 * g * t * t - (h0 - radii[i])) / t * (1 + rng.nextDouble() * 0.15);
    vy = vy.clamp(0.0, sqrt(2 * g * max(ceilingClear - h0, 1.0)));
    final heading = flat.normalized();
    final scatter = (rng.nextDouble() - 0.5) * 2.2 * kUpstreamUnit;
    final v = heading * speed + side * scatter + up * vy;
    // End over end along the throw (a forward roll: up × dir) at
    // speed·0.7–1.4 rad/s (upstream units), plus a 6–22 rad/s tumble.
    final roll = up.cross(heading)..normalize();
    final upSpeed = speed / kUpstreamUnit;
    final tumble = Vector3(
      rng.nextDouble() - 0.5,
      rng.nextDouble() - 0.5,
      rng.nextDouble() - 0.5,
    )..normalize();
    final rot = randomRotation(rng);
    final w =
        roll * (upSpeed * (0.7 + rng.nextDouble() * 0.7)) +
        tumble * (6 + rng.nextDouble() * 16);
    final long = longAxes?[i];
    if (long != null) {
      final axisWorld = rot.asRotationMatrix() * long;
      w.add(axisWorld.normalized() * (8 + rng.nextDouble() * 8));
    }
    w.scale(spinScales?[i] ?? 1.0);
    launches.add(
      DieLaunch(
        position: p,
        rotation: rot,
        linear: v,
        angularAxis: w.normalized(),
        angularRate: w.length,
      ),
    );
  }
  return ThrowPlan(dice: launches, gates: gates);
}

/// Where the held dice ride, relative to the finger: a hex cluster
/// (centre, then rings) spaced by the largest die plus [gap].
List<Vector3> holdOffsets(List<double> radii, {double gap = 1.5}) {
  if (radii.isEmpty) return const [];
  final pitch = radii.reduce(max) * 2 + gap;
  final out = <Vector3>[Vector3.zero()];
  for (var ring = 1; out.length < radii.length; ring++) {
    // A hex ring of 6·ring slots.
    for (var k = 0; k < 6 * ring && out.length < radii.length; k++) {
      final corner = k ~/ ring, step = k % ring;
      final a0 = corner * pi / 3, a1 = (corner + 1) * pi / 3;
      final p0 = Vector3(cos(a0), 0, sin(a0)) * (ring * pitch);
      final p1 = Vector3(cos(a1), 0, sin(a1)) * (ring * pitch);
      out.add(p0 + (p1 - p0) * (step / ring));
    }
  }
  return out;
}

/// The height the dice hover at while held: well clear of the table,
/// well under the ceiling.
double hoverHeight(TrayLayout layout, double maxRadius) =>
    min(layout.ceilingHeight * 0.45, maxRadius * 6);

/// The launch of a held die released with the finger's world velocity
/// [fling]: the fling (capped at [kMaxLaunch]) with a little extra lift,
/// and a forward roll that matches it. A release with next to no
/// velocity is a drop — the dice fall with a gentle tumble.
({Vector3 linear, Vector3 axis, double rate}) tossLaunch(
  Vector3 fling,
  double radius,
  Random rng,
) {
  final up = Vector3(0, 1, 0);
  final flat = Vector3(fling.x, 0, fling.z);
  var speed = flat.length;
  final tumble = Vector3(
    rng.nextDouble() - 0.5,
    rng.nextDouble() - 0.5,
    rng.nextDouble() - 0.5,
  )..normalize();
  if (speed < 1.5 * kUpstreamUnit) {
    // A drop: straight down, spinning a little.
    final w = tumble * (4 + rng.nextDouble() * 6);
    return (linear: flat, axis: w.normalized(), rate: w.length);
  }
  if (speed > kMaxLaunch) {
    flat.scale(kMaxLaunch / speed);
    speed = kMaxLaunch;
  }
  final heading = flat.normalized();
  final roll = up.cross(heading)..normalize();
  final w =
      roll * (speed / kUpstreamUnit * (0.8 + rng.nextDouble() * 0.5)) +
      tumble * (4 + rng.nextDouble() * 10);
  return (
    linear: flat + up * (speed * 0.12),
    axis: w.normalized(),
    rate: w.length,
  );
}

/// The finger's reach, beyond a die's radius, for a sweep to hit it.
const double kSweepReach = 5.0;

/// Whether a sweep with the finger over table point [finger] hits a die
/// of [radius] at [position] (horizontal distance).
bool sweepHits(Vector3 finger, Vector3 position, double radius) {
  final dx = position.x - finger.x, dz = position.z - finger.z;
  return dx * dx + dz * dz < pow(radius + kSweepReach, 2);
}

/// The shove a sweep gives a die (upstream: finger velocity ×0.8 plus a
/// small hop), capped at [kMaxLaunch], with a matching forward roll.
({Vector3 linear, Vector3 axis, double rate}) sweepShove(
  Vector3 fingerVelocity,
  double radius,
  Random rng,
) {
  final up = Vector3(0, 1, 0);
  final flat = Vector3(fingerVelocity.x, 0, fingerVelocity.z) * 0.8;
  if (flat.length > kMaxLaunch) flat.scale(kMaxLaunch / flat.length);
  final heading = flat.length < 1e-6 ? Vector3(0, 0, 1) : flat.normalized();
  final roll = up.cross(heading)..normalize();
  final tumble = Vector3(
    rng.nextDouble() - 0.5,
    rng.nextDouble() - 0.5,
    rng.nextDouble() - 0.5,
  )..normalize();
  final w =
      roll * (flat.length / radius * 0.5) + tumble * (3 + rng.nextDouble() * 6);
  return (
    linear: flat + up * (3 * kUpstreamUnit),
    axis: w.normalized(),
    rate: w.length,
  );
}

/// What a touch is doing.
enum DiceGesture {
  /// Down, not yet a drag or a hold.
  pending,

  /// Drawing the aim arrow (started off the dice).
  aim,

  /// Shoving the dice (started on a die).
  sweep,

  /// Holding the dice up (a long press), to toss on release.
  hold,
}

/// Decides what a touch is: a press that moves past [kDragSlop] is an
/// aim (from the table) or a sweep (from a die); one held still for
/// [kHoldDelay] picks the dice up.
final class GestureArbiter {
  DiceGesture? _state;
  double _t0 = 0;
  double _x0 = 0, _y0 = 0;
  bool _onDie = false;

  DiceGesture? get state => _state;

  /// Where the touch went down (px).
  (double, double) get origin => (_x0, _y0);

  void down(double t, double x, double y, {required bool onDie}) {
    _state = DiceGesture.pending;
    _t0 = t;
    _x0 = x;
    _y0 = y;
    _onDie = onDie;
  }

  /// A move; returns the state after it.
  DiceGesture? move(double t, double x, double y) {
    if (_state == DiceGesture.pending) {
      final dx = x - _x0, dy = y - _y0;
      if (dx * dx + dy * dy > kDragSlop * kDragSlop) {
        _state = _onDie ? DiceGesture.sweep : DiceGesture.aim;
      } else {
        tick(t);
      }
    }
    return _state;
  }

  /// Time passing with the finger down; returns the state.
  DiceGesture? tick(double t) {
    if (_state == DiceGesture.pending && t - _t0 >= kHoldDelay) {
      _state = DiceGesture.hold;
    }
    return _state;
  }

  /// The finger lifted (or the gesture was cancelled): returns what it
  /// was and ends it.
  DiceGesture? up() {
    final s = _state;
    _state = null;
    return s;
  }
}
