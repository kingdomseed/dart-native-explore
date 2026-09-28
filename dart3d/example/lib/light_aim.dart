import 'dart:io' show Platform;
import 'dart:math';

import 'package:vector_math/vector_math.dart';

/// iOS-only scale on the example's directional-light intensities.
///
/// The natives map the wire `intensity` differently: iOS passes it to
/// `SCNLight.intensity` (SceneKit PBR: 1000 ≈ unit radiance), while
/// Android converts at `DIRECTIONAL_LUX_PER_UNIT` = 10 lx per unit and
/// renders at Filament's default camera exposure (f/16, 1/125 s,
/// ISO 100 → 1 / (1.2 · 2^14.97) ≈ 2.604e-5). The same wire value is
/// therefore 1000 · 10 · 2.604e-5 ≈ 0.26× as bright on Android. The
/// example's keys (1300–2400) were only ever tuned on Android — until
/// the +Z light-axis fix every iOS key shone upward — so iOS scales
/// them down to Android's calibrated look. Integration follow-up:
/// unify the native unit mapping and delete this
/// (docs/triage/integration.md).
const double kIosDirectionalScale = 1000 * 10 * 2.604e-5;

/// [androidCalibrated] as authored for Android, scaled for iOS
/// ([kIosDirectionalScale]). [ios] overrides the platform (tests).
double keyLightIntensity(double androidCalibrated, {bool? ios}) =>
    androidCalibrated * ((ios ?? Platform.isIOS) ? kIosDirectionalScale : 1);

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
