/// What happens after the dice stop: cocked-die detection and the
/// physical nudge that settles a cocked die flat, and the d4 shard's
/// turn to read upright. Pure Dart (no `dartnative` imports) so
/// `dart test` covers it; the screen (`dice_table.dart`) applies the
/// results as velocity writes — a die is never teleported.
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

import 'dice_table_scene.dart';
import 'dice_tray_layout.dart';

/// The largest tilt of a die's up face that still reads as lying flat.
/// Resting on a face, the physics leaves well under a degree.
const double kMaxFlatTilt = 8 * pi / 180;

/// The smallest angle between two of [map]'s face normals (radians).
double minFaceAngle(DieFaceMap map) {
  var best = pi;
  final f = map.faces;
  for (var i = 0; i < f.length; i++) {
    for (var j = i + 1; j < f.length; j++) {
      final d = f[i].normal.normalized().dot(f[j].normal.normalized());
      best = min(best, acos(d.clamp(-1.0, 1.0)));
    }
  }
  return best;
}

/// The up-face dot (see [DieFaceMap.top]) below which a die is cocked.
///
/// Upstream's "roll again under 0.9" misses edge-rests on round dice: a
/// d20 balanced on an edge still has its top face within 21° of up (dot
/// 0.93). So the tolerance is a fraction of the die's own face spacing,
/// capped at [kMaxFlatTilt] — an edge-rest (half the face spacing) is
/// always cocked, a flat rest never is.
double flatDotFor(DieFaceMap map) =>
    cos(min(kMaxFlatTilt, 0.3 * minFaceAngle(map)));

/// Whether a die at [rotation] rests tilted — leaning on a wall or on
/// another die, or balanced on an edge.
bool isCocked(DieFaceMap map, Quaternion rotation) =>
    map.faces.isNotEmpty && map.top(rotation).$2 < flatDotFor(map);

/// A velocity write for one die: linear velocity plus angular velocity
/// as axis and rate (the form `SceneController.setBodyVelocity` takes).
typedef BodyKick = ({Vector3 linear, Vector3 axis, double rate});

/// The nudge that settles a cocked die flat: a small hop, a push away
/// from what it leans on, and just enough spin, over the hop's flight,
/// to turn its up face level — so it lands on the opposite face.
///
/// [neighbours] are the other dice (position, radius). [attempt] counts
/// earlier nudges of this die in the same roll; each retry hops a little
/// higher.
BodyKick cockedNudge({
  required Vector3 position,
  required Quaternion rotation,
  required DieFaceMap faceMap,
  required double radius,
  required double gravity,
  required TrayLayout layout,
  Iterable<(Vector3, double)> neighbours = const [],
  int attempt = 0,
  Random? rng,
}) {
  final random = rng ?? Random();
  final up = Vector3(0, 1, 0);
  final (face, dot) = faceMap.top(rotation);
  final nWorld = rotation.asRotationMatrix() * face.normal
    ..normalize();
  final tilt = acos(dot.clamp(-1.0, 1.0));
  // Rotating n about n × up turns it toward up.
  var axis = nWorld.cross(up);
  if (axis.length < 1e-6) {
    final a = random.nextDouble() * 2 * pi;
    axis = Vector3(cos(a), 0, sin(a));
  }
  axis.normalize();

  // The hop: up to half a radius (more on a retry), and its flight time.
  final h = radius * (0.45 + 0.2 * attempt);
  final vy = sqrt(2 * gravity * h);
  final flight = 2 * vy / gravity;

  // Push away from every neighbour it touches and from the walls.
  final away = Vector3.zero();
  for (final (q, r) in neighbours) {
    final d = Vector3(position.x - q.x, 0, position.z - q.z);
    final reach = (radius + r) * 1.15;
    final len = d.length;
    if (len < 1e-6 || len > reach) continue;
    away.add(d.normalized() * (1 - len / reach + 0.2));
  }
  for (var i = 0; i < 4; i++) {
    if (layout.outside(i, position) > -radius * 1.2) {
      away.sub(TrayLayout.wallNormals[i]);
    }
  }
  if (away.length < 1e-6) {
    // Balanced on an edge in the open: tip it the way it leans.
    away.setValues(nWorld.x, 0, nWorld.z);
    if (away.length < 1e-6) {
      final a = random.nextDouble() * 2 * pi;
      away.setValues(cos(a), 0, sin(a));
    }
  }
  away.normalize();
  final vh = radius * 0.8 / flight;
  return (linear: away * vh + up * vy, axis: axis, rate: tilt / flight);
}

/// Yaw error (radians) under which the d4 counts as upright.
const double kUprightTolerance = 3 * pi / 180;

/// The spin (rad/s about world +Y) that turns the d4 toward reading
/// upright, given its numeral's current yaw error (`shardUprightYaw`);
/// 0 once it's within [kUprightTolerance]. Proportional with a floor so
/// it doesn't creep the last degrees, and a ceiling so a half-turn stays
/// a glide rather than a spin.
double uprightTurnRate(double yawError) {
  if (yawError.abs() < kUprightTolerance) return 0;
  final rate = (yawError.abs() * 6.0).clamp(1.0, 7.0);
  return -yawError.sign * rate;
}
