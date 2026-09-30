// Dice readout: every face of every die, oriented up, reads its own
// value — against the DartNative set's face maps and the meshes the
// natives draw.
//
// The reference rotation is the scene model's own matrix composition
// (`TrsTransform.toMatrix4`, the same TRS → matrix the natives realize),
// so the test pins `DieFaceMap.read` to how a settle pose actually turns
// the mesh — the old readout used vector_math's `Quaternion.rotated`,
// which is the *inverse* rotation (docs/triage/integration.md §"Dice
// readout mismatch").
// ignore_for_file: implementation_imports

import 'dart:math';

import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d_example/dice_numerals.dart';
import 'package:dart3d_example/dice_polyhedra.dart';
import 'package:dart3d_example/dice_set.dart';
import 'package:dart3d_example/dice_table_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// A rotation taking [n] to +Y, then [yaw] about +Y.
Quaternion faceUp(Vector3 n, double yaw) =>
    Quaternion.axisAngle(Vector3(0, 1, 0), yaw) * faceUpRotation(n);

/// World direction of the mesh-space vector [v] under [q], through the
/// scene model's TRS composition.
Vector3 world(Quaternion q, Vector3 v) =>
    TrsTransform(rotation: q).toMatrix4().rotated3(v);

DieFaceMap mapOf(DieGeo geo) => DieFaceMap(
  faces: [for (final f in geo.numbered) DieFace(f.normal, f.value!)],
);

void main() {
  final geos = {for (final k in kDieKinds) k: buildDieGeo(k)};
  final maps = {for (final e in geos.entries) e.key: mapOf(e.value)};

  test('every face of every die, turned up, reads its value', () {
    final rng = Random(7);
    var checked = 0;
    for (final MapEntry(key: label, value: map) in maps.entries) {
      for (final face in map.faces) {
        for (final yaw in [0.0, 1.1, 2.7, rng.nextDouble() * 2 * pi]) {
          final q = faceUp(face.normal, yaw);
          // The pose really puts this face on top (reference path).
          expect(world(q, face.normal).y, closeTo(1.0, 1e-5));
          final (top, dot) = map.top(q);
          expect(
            top.value,
            face.value,
            reason: '$label face ${face.value} yaw $yaw',
          );
          expect(dot, closeTo(1.0, 1e-5));
          expect(map.read(q), face.value);
          checked++;
        }
      }
    }
    // 4 + 6 + 8 + 10 + 10 + 12 + 20 faces × 4 yaws.
    expect(checked, 70 * 4);
  });

  test('a die resting slightly tilted still reads the face on top', () {
    for (final MapEntry(key: label, value: map) in maps.entries) {
      for (final face in map.faces) {
        final wobble = Quaternion.axisAngle(Vector3(0.6, 0, 0.8), 0.12);
        final q = wobble * faceUp(face.normal, 0.4);
        expect(map.read(q), face.value, reason: '$label ${face.value}');
      }
    }
  });

  test('the old inverse-rotation readout is wrong (regression guard)', () {
    final d20 = maps['d20']!;
    var disagreements = 0;
    for (final face in d20.faces) {
      final q = faceUp(face.normal, 0.9);
      var best = d20.faces.first;
      for (final f in d20.faces) {
        if (q.rotated(f.normal).y > q.rotated(best.normal).y) best = f;
      }
      if (best.value != face.value) disagreements++;
      expect(d20.read(q), face.value);
    }
    expect(disagreements, greaterThan(10));
  });

  test('face normals are flat faces of the drawn meshes', () {
    // Every face-map normal is the normal of a real flat face of the
    // mesh the natives draw — the bulk of the die's area faces that way.
    for (final MapEntry(key: label, value: geo) in geos.entries) {
      final mesh = buildDieMesh(geo, buildDieAtlas(geo));
      final p = mesh.positions, idx = mesh.indices;
      var total = 0.0;
      final byFace = <int, double>{};
      for (var t = 0; t < idx.length; t += 3) {
        final c = (p[idx[t + 1]] - p[idx[t]]).cross(p[idx[t + 2]] - p[idx[t]]);
        final area = c.length / 2;
        total += area;
        // Wound outward (the front-face convention).
        final centroid = p[idx[t]] + p[idx[t + 1]] + p[idx[t + 2]];
        expect(c.dot(centroid), greaterThanOrEqualTo(-1e-6), reason: label);
        for (final f in maps[label]!.faces) {
          if (c.normalized().dot(f.normal) > 0.9999) {
            byFace[f.value] = (byFace[f.value] ?? 0) + area;
          }
        }
      }
      final faces = maps[label]!.faces.length;
      for (final f in maps[label]!.faces) {
        expect(
          byFace[f.value] ?? 0,
          greaterThan(total / faces * (label == 'd4' ? 0.3 : 0.5)),
          reason: '$label ${f.value}',
        );
      }
    }
  });
}
