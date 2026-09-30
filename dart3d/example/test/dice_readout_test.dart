// Dice readout: every face of every die, oriented up, reads its own
// value — against the real bundled face maps and meshes.
//
// The reference rotation is the scene model's own matrix composition
// (`TrsTransform.toMatrix4`, the same TRS → matrix the natives realize),
// so the test pins `DieFaceMap.read` to how a settle pose actually turns
// the mesh — the old readout used vector_math's `Quaternion.rotated`,
// which is the *inverse* rotation (docs/triage/integration.md §"Dice
// readout mismatch").
// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d_example/dice_shard_d4.dart';
import 'package:dart3d_example/dice_table_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

Uint8List? bytesFromDisk(String key) {
  final file = File(key);
  return file.existsSync() ? file.readAsBytesSync() : null;
}

/// A rotation taking [n] to +Y, then [yaw] about +Y.
Quaternion faceUp(Vector3 n, double yaw) {
  final up = Vector3(0, 1, 0);
  final axis = n.cross(up);
  final Quaternion tilt;
  if (axis.length < 1e-9) {
    tilt = n.y > 0
        ? Quaternion.identity()
        : Quaternion.axisAngle(Vector3(1, 0, 0), pi);
  } else {
    tilt = Quaternion.axisAngle(
      axis.normalized(),
      acos(n.normalized().dot(up).clamp(-1.0, 1.0)),
    );
  }
  return Quaternion.axisAngle(up, yaw) * tilt;
}

/// World direction of the mesh-space vector [v] under [q], through the
/// scene model's TRS composition.
Vector3 world(Quaternion q, Vector3 v) =>
    TrsTransform(rotation: q).toMatrix4().rotated3(v);

/// Each die's face-value set and opposite-face sum.
const expected = {
  'd4': (4, 1, 5),
  'd6': (6, 1, 7),
  'd8': (8, 1, 9),
  'd10u': (10, 0, 9),
  'd10t': (10, 0, 90),
  'd12': (12, 1, 13),
  'd20': (20, 1, 21),
};

Map<String, DieFaceMap> allMaps() => {
  ...loadDiceFaceMaps(bytesFor: bytesFromDisk)..remove('d4'),
  'd4': shardFaceMap,
};

/// Triangle normals (area-weighted) of a geometry's vertex payload —
/// SoA (`unskinned_soa_uv1_tangent`, the importer's) or interleaved
/// (`unskinned_uv1_tangent`, VertexPack's).
List<(Vector3, double)> triangles(SceneDocument doc, GeometryResource geo) {
  final vp = doc.payloads[geo.vertices]!;
  final ip = doc.payloads[geo.indices]!;
  final bd = ByteData.sublistView(vp.bytes!);
  final soa = vp.layout == 'unskinned_soa_uv1_tangent';
  expect(soa || vp.layout == 'unskinned_uv1_tangent', isTrue);
  Vector3 pos(int i) {
    final o = soa ? i * 12 : i * 72;
    return Vector3(
      bd.getFloat32(o, Endian.little),
      bd.getFloat32(o + 4, Endian.little),
      bd.getFloat32(o + 8, Endian.little),
    );
  }

  final List<int> idx = ip.format == 'uint32'
      ? Uint32List.sublistView(ip.bytes!)
      : Uint16List.sublistView(ip.bytes!);
  final out = <(Vector3, double)>[];
  for (var t = 0; t + 2 < idx.length; t += 3) {
    final a = pos(idx[t]), b = pos(idx[t + 1]), c = pos(idx[t + 2]);
    final cr = (b - a).cross(c - a);
    final area = cr.length / 2;
    if (area < 1e-9) continue;
    out.add((cr / (area * 2), area));
  }
  return out;
}

void main() {
  final maps = allMaps();

  test('face maps: values and opposite sums per die', () {
    expect(maps.keys, containsAll(expected.keys));
    for (final MapEntry(key: label, value: map) in maps.entries) {
      final (count, lowest, oppositeSum) = expected[label]!;
      final values = map.faces.map((f) => f.value).toList()..sort();
      final step = label == 'd10t' ? 10 : 1;
      expect(values, [
        for (var i = 0; i < count; i++) lowest + i * step,
      ], reason: label);
      for (final f in map.faces) {
        expect(f.normal.length, closeTo(1.0, 0.01), reason: label);
        final opposite = map.faces.reduce(
          (a, b) => a.normal.dot(f.normal) < b.normal.dot(f.normal) ? a : b,
        );
        expect(opposite.normal.dot(f.normal), lessThan(-0.99), reason: label);
        expect(
          f.value + opposite.value,
          oppositeSum,
          reason: '$label ${f.value}',
        );
      }
    }
  });

  test('every face of every die, turned up, reads its value', () {
    final rng = Random(7);
    var checked = 0;
    for (final MapEntry(key: label, value: map) in maps.entries) {
      for (final face in map.faces) {
        for (final yaw in [0.0, 1.1, 2.7, rng.nextDouble() * 2 * pi]) {
          final q = faceUp(face.normal, yaw);
          // The pose really puts this face on top (reference path).
          expect(world(q, face.normal).y, closeTo(1.0, 1e-6));
          final (top, dot) = map.top(q);
          expect(
            top.value,
            face.value,
            reason: '$label face ${face.value} yaw $yaw',
          );
          expect(dot, closeTo(1.0, 1e-6));
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
    // A d20 turned by a rotation that is not its own inverse:
    // `Quaternion.rotated` (conj(q)·v·q) picks a different face.
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

  test('face normals are flat faces of the rendered meshes', () {
    // Every face-map normal (after the JSON's z mirror into document
    // space) must be the normal of a real flat face of the mesh the
    // natives draw — substantial triangle area facing exactly that way.
    // (These dice are mirror-symmetric in z, so geometry alone can't
    // tell the mirror apart; the device readout-vs-visible check does.)
    const assets = {
      'd6': 'assets/dice/scene.d6.dbe505b8.fsceneb',
      'd8': 'assets/dice/scene.d8.dbe51f72.fsceneb',
      'd10t': 'assets/dice/scene.d10t.862039c2.fsceneb',
      'd10u': 'assets/dice/scene.d10u.86203b0d.fsceneb',
      'd12': 'assets/dice/scene.d12.a5cbecd0.fsceneb',
      'd20': 'assets/dice/scene.d20.a5fdb0b1.fsceneb',
    };
    void check(String label, SceneDocument doc, GeometryResource body) {
      final tris = triangles(doc, body);
      final total = tris.fold(0.0, (s, t) => s + t.$2);
      for (final face in maps[label]!.faces) {
        var area = 0.0;
        for (final (n, a) in tris) {
          if (n.dot(face.normal) > 0.999) area += a;
        }
        expect(
          area / total,
          greaterThan(0.25 / maps[label]!.faces.length),
          reason: '$label face ${face.value}',
        );
      }
    }

    for (final MapEntry(key: label, value: key) in assets.entries) {
      final doc = readFsceneb(bytesFromDisk(key)!);
      // The body is the geometry with the larger bounds (the other is
      // the numeral inlay).
      final geos = doc.resources.values.whereType<GeometryResource>().toList()
        ..sort(
          (a, b) => (b.bounds!.max - b.bounds!.min).length.compareTo(
            (a.bounds!.max - a.bounds!.min).length,
          ),
        );
      check(label, doc, geos.first);
    }
    final doc = SceneDocument();
    addShardD4(doc);
    check('d4', doc, doc.resources.values.whereType<GeometryResource>().single);
  });

  group('shard d4', () {
    test('lands on a long face: the numbered faces are the long ones', () {
      final doc = SceneDocument();
      final shard = addShardD4(doc);
      final geo = doc.resources.values.whereType<GeometryResource>().single;
      final tris = triangles(doc, geo);
      // Front faces point outward (payload winding matches normals).
      for (final (n, _) in tris) {
        expect(n.length, closeTo(1, 1e-6));
      }
      final longArea = <int, double>{};
      for (final face in shardFaceMap.faces) {
        longArea[face.value] = tris
            .where((t) => t.$1.dot(face.normal) > 0.999)
            .fold(0.0, (s, t) => s + t.$2);
      }
      // Each long face is a section × prism-length rectangle.
      const expectArea = kShardSection * kShardSection * kShardHalfRatio * 2;
      for (final a in longArea.values) {
        expect(a, closeTo(expectArea, 1e-3));
      }
      // It rests on a long face at its half-section.
      expect(shard.restY, closeTo(kShardSection / 2 + 0.4, 1e-9));
      expect(shard.radius, closeTo(kShardSection * 1.24, 1e-9));
    });

    test('triangle winding faces outward', () {
      final doc = SceneDocument();
      addShardD4(doc);
      final geo = doc.resources.values.whereType<GeometryResource>().single;
      final vp = doc.payloads[geo.vertices]!;
      final bd = ByteData.sublistView(vp.bytes!);
      final ip = doc.payloads[geo.indices]!;
      final idx = Uint16List.sublistView(ip.bytes!);
      Vector3 read(int i, int off) => Vector3(
        bd.getFloat32(i * 72 + off, Endian.little),
        bd.getFloat32(i * 72 + off + 4, Endian.little),
        bd.getFloat32(i * 72 + off + 8, Endian.little),
      );
      for (var t = 0; t < idx.length; t += 3) {
        final a = read(idx[t], 0), b = read(idx[t + 1], 0);
        final c = read(idx[t + 2], 0);
        final n = read(idx[t], 12);
        final cr = (b - a).cross(c - a);
        expect(cr.dot(n), greaterThan(0), reason: 'triangle ${t ~/ 3}');
        expect(((a + b + c) / 3).dot(n), greaterThan(0));
      }
    });

    test('numeral atlas: one glyph per quadrant', () {
      final px = shardNumeralAtlas();
      const n = kShardAtlasSize;
      expect(px.length, n * n * 4);
      int inked(int qx, int qy) {
        var count = 0;
        for (var y = qy * n ~/ 2; y < (qy + 1) * n ~/ 2; y++) {
          for (var x = qx * n ~/ 2; x < (qx + 1) * n ~/ 2; x++) {
            if (px[(y * n + x) * 4] < 60) count++;
          }
        }
        return count;
      }

      for (final (qx, qy) in [(0, 0), (1, 0), (0, 1), (1, 1)]) {
        expect(inked(qx, qy), greaterThan(300), reason: 'cell $qx,$qy');
      }
      // The cap facets sample the atlas corner — blank body colour.
      expect(px[0], greaterThan(200));
    });
  });
}
