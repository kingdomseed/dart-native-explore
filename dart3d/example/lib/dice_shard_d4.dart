/// The d4 "crystal shard": a square prism with pyramid caps that lands
/// on one of its four long faces and reads from the face pointing up —
/// unlike a tetrahedron, whose result hides on the bottom or the edges.
/// Its geometry is the look-dev's (`dice_polyhedra.dart`); this file
/// holds how its numerals read.
///
/// Numerals read *along* the crystal — the baseline runs down the long
/// axis, so a shard lying across the screen reads upright
/// ([shardGlyphUp]); after a roll the die turns until it does
/// ([shardUprightYaw], `dice_settle.dart`).
///
/// Pure Dart (no `dartnative` imports) so `dart test` covers it.
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

/// The long axis (mesh space): the tips sit at ±X.
final Vector3 kShardAxis = Vector3(1, 0, 0);

/// The "up" of the numeral printed on the long face with outward normal
/// [n] (mesh space): across the crystal, `axis × n`. The numeral's
/// right runs toward the +X tip (`n × up`, the document's screen-right).
/// Rolling about the long axis maps each face's frame onto the next, so
/// while the +X tip points screen-right every face reads upright from
/// the top-down camera.
Vector3 shardGlyphUp(Vector3 n) => kShardAxis.cross(n)..normalize();

/// How far the up face's numeral is turned from upright on screen, for
/// a shard at world [rotation] with face [faceNormal] (mesh space) up:
/// the signed yaw (radians, −π..π) about world +Y from screen-up (+Z)
/// to the numeral's up. Turning the die by `−shardUprightYaw(...)`
/// about +Y makes it read upright.
double shardUprightYaw(Quaternion rotation, Vector3 faceNormal) {
  final up = rotation.asRotationMatrix() * shardGlyphUp(faceNormal);
  if (up.x * up.x + up.z * up.z < 1e-12) return 0;
  return atan2(up.x, up.z);
}
