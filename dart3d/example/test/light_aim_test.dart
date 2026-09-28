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
      Vector3(-0.152, -0.507, -0.848),
      Vector3(0.074, -0.527, -0.847),
      Vector3(1, 0, 0),
      Vector3(0, 0, -1),
    ]) {
      expectTravels(d);
    }
  });

  test('example key lights all travel downward', () {
    for (final d in [
      Vector3(-0.28, -1.0, -0.22), // dice table
      Vector3(-0.152, -0.507, -0.848), // cube / imported / feature
      Vector3(0.074, -0.527, -0.847), // showcase
    ]) {
      expect(
        (aimAlong(d).asRotationMatrix() * Vector3(0, 0, 1)).y,
        lessThan(-0.4),
      );
    }
  });

  test('zero vector falls back to identity', () {
    final q = aimAlong(Vector3.zero());
    expect(q.w, closeTo(1, 1e-9));
  });
}
