import 'dart:math';

import 'package:vector_math/vector_math.dart';

/// A rotation whose node-local +Z points along [dir] — the travel
/// direction of a directional (or spot) light on that node.
///
/// Upstream flutter_scene 0.23 `DirectionalLightComponent.worldDirection`
/// is `rotation × (0, 0, 1)`: lights travel along node-local **+Z**, the
/// same forward axis as cameras. Both natives follow it (iOS #15,
/// Android #16), so author a light by the way it should *travel*
/// (e.g. `(0, -1, 0)` shines straight down).
///
/// Decomposed as `Ry(yaw) · Rx(pitch)` — the same yaw/pitch split the
/// showcase camera uses. [dir] need not be normalized; a zero vector
/// returns the identity (travel along +Z).
Quaternion aimAlong(Vector3 dir) {
  if (dir.length2 == 0) return Quaternion.identity();
  final fwd = dir.normalized();
  final pitch = -asin(fwd.y.clamp(-1.0, 1.0));
  final yaw = atan2(fwd.x, fwd.z);
  return Quaternion.axisAngle(Vector3(0, 1, 0), yaw) *
      Quaternion.axisAngle(Vector3(1, 0, 0), pitch);
}
