import 'package:dart3d_example/light_aim.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// Upstream flutter_scene 0.23 lights travel along node-local +Z
/// (`DirectionalLightComponent.worldDirection = rotation × (0,0,1)`).
///
/// Checked through the rotation *matrix* (what `Matrix4.compose` and
/// upstream's `globalTransform.getRotation()` use). vector_math's
/// `Quaternion.rotated` applies the inverse rotation, so it is NOT the
/// wire semantics and must not be used to check light aims.
void main() {
  void expectTravels(Vector3 dir) {
    final travel = aimAlong(dir).asRotationMatrix() * Vector3(0, 0, 1);
    final want = dir.normalized();
    expect(travel.x, closeTo(want.x, 1e-5), reason: '$dir');
    expect(travel.y, closeTo(want.y, 1e-5), reason: '$dir');
    expect(travel.z, closeTo(want.z, 1e-5), reason: '$dir');
  }

  test('aimAlong points node-local +Z along the travel direction', () {
    for (final d in [
      Vector3(0, -1, 0),
      Vector3(-0.28, -1.0, -0.22),
      Vector3(0.152, -0.507, 0.848),
      Vector3(0.3, -0.8, 0.5),
      Vector3(1, 0, 0),
      Vector3(0, 0, -1),
    ]) {
      expectTravels(d);
    }
  });

  test('example key lights all travel downward', () {
    for (final d in [
      Vector3(-0.28, -1.0, -0.22), // dice table
      Vector3(0.152, -0.507, 0.848), // cube / imported / feature
      Vector3(0.3, -0.8, 0.5), // showcase
    ]) {
      expect(
        (aimAlong(d).asRotationMatrix() * Vector3(0, 0, 1)).y,
        lessThan(-0.4),
      );
    }
  });

  test('example keys travel with the camera (front-lit, not back-lit)', () {
    // Cameras look along their +Z too: the cube/imported/feature
    // cameras sit at −Z pitched about X; the showcase camera looks
    // along −cameraDir.
    final pitchedFwd =
        Quaternion.axisAngle(Vector3(1, 0, 0), 0.5).asRotationMatrix() *
        Vector3(0, 0, 1);
    final showcaseFwd = -(Vector3(-0.52, 0.36, -0.77)..normalize());
    for (final (key, fwd) in [
      (Vector3(0.152, -0.507, 0.848), pitchedFwd),
      (Vector3(0.3, -0.8, 0.5), showcaseFwd),
    ]) {
      final travel = aimAlong(key).asRotationMatrix() * Vector3(0, 0, 1);
      expect(travel.dot(fwd), greaterThan(0.3), reason: '$key');
    }
  });

  test('keyLightIntensity scales only on iOS', () {
    expect(keyLightIntensity(2400, ios: false), 2400);
    expect(keyLightIntensity(2400, ios: true), closeTo(2400 * 0.2604, 1e-6));
  });

  test('zero vector falls back to identity', () {
    final q = aimAlong(Vector3.zero());
    expect(q.w, closeTo(1, 1e-9));
  });
}
