/// The DartNative set's dice geometry — the look-dev polyhedra
/// (`tool/dice_lookdev/build_dice.py` on `p3-dice-lookdev`, §1.1 of
/// docs/design/dice-lookdev.md) ported to Dart: the same point sets,
/// sizes, numbering (opposite faces sum to n+1; the d10s' odd numbers
/// around one pole), numeral frames and font sizes. Built procedurally,
/// so the example ships no dice meshes.
///
/// The look-dev works in Blender's right-handed Z-up centimetres; this
/// file does too and converts once, at the end, to the document's
/// left-handed Y-up world units: `(x, y, z) → (x, z, y)·scale`. That
/// mirror keeps each die's chirality as rendered (the natives mirror z
/// back), and it turns the look-dev's numeral right `up × n` into the
/// document's `n × up` (see `dice_shard_d4.dart`).
///
/// Pure Dart (no `dartnative` imports) so `dart test` covers it.
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

import 'dice_shard_d4.dart' show shardGlyphUp;

/// The dice, in rack order.
const kDieKinds = ['d4', 'd6', 'd8', 'd10t', 'd10u', 'd12', 'd20'];

const double _phi = 1.6180339887498949;

/// Look-dev size parameters (cm, before [_sizeScale]): size, bevel,
/// numeral em as a multiple of the face inradius.
const _params = {
  'd4': (size: 1.00, bevel: 0.07, em: 1.78),
  'd6': (size: 1.60, bevel: 0.13, em: 1.67),
  'd8': (size: 1.05, bevel: 0.07, em: 1.76),
  'd10u': (size: 1.00, bevel: 0.06, em: 1.65),
  'd10t': (size: 1.00, bevel: 0.06, em: 1.54),
  'd12': (size: 0.66, bevel: 0.07, em: 1.67),
  'd20': (size: 1.18, bevel: 0.055, em: 1.60),
};
const double _sizeScale = 1.3;

/// Blender's text size in font ems: the look-dev's `em` is a Blender
/// text-object size, and its readability table measures the numerals at
/// ≈0.41 of the face's inscribed width — Inter's cap height at 0.70 of
/// the size (calibrated against docs/design/dice-lookdev.md §0.2).
const double kBlenderTextEm = 0.70;
const double _shardHalf = 0.62, _shardCap = 0.62;

/// World units per look-dev centimetre: the d20 spans [kD20Span].
const double kD20Span = 19.26;
final double kWorldPerCm = kD20Span / (2 * _d20Circumradius());

double _d20Circumradius() {
  final edge = _params['d20']!.size * _sizeScale;
  return edge * sin(2 * pi / 5);
}

/// Values for the upper hemisphere's faces (sorted top-down, then by
/// angle); the opposite face gets `sum − v` (look-dev `SEEDS`).
const _seeds = {
  'd8': ([8, 3, 5, 2], 9),
  'd10u': ([1, 7, 3, 9, 5], 9),
  'd10t': ([10, 70, 30, 90, 50], 90),
  'd12': ([12, 2, 10, 4, 8, 6], 13),
  'd20': ([20, 8, 14, 2, 18, 4, 12, 6, 16, 10], 21),
};

/// Opposite faces sum to this.
const kOppositeSum = {
  'd4': 5,
  'd6': 7,
  'd8': 9,
  'd10u': 9,
  'd10t': 90,
  'd12': 13,
  'd20': 21,
};

/// One face of a die, in document space and world units.
final class DieFaceGeo {
  DieFaceGeo({
    required this.points,
    required this.normal,
    required this.centre,
    required this.value,
    required this.up,
    required this.right,
    required this.anchor,
    required this.inradius,
    required this.em,
  });

  /// The face polygon, counter-clockwise seen from outside (in the
  /// look-dev's right-handed frame; document winding is mirrored).
  final List<Vector3> points;
  final Vector3 normal, centre;

  /// The number on the face; null on the d4 shard's blank cap facets.
  final int? value;

  /// The numeral's frame in the face plane: [up], and [right] (= n × up,
  /// the document's screen-right).
  final Vector3 up, right;

  /// Where the numeral is centred, in (right, up) face coordinates
  /// relative to [centre] — off-centre on the d10 kites.
  final Vector2 anchor;

  /// Distance from [anchor] to the nearest face edge.
  final double inradius;

  /// The numeral's font size (em), world units.
  final double em;

  /// The label printed: "00" on the tens die, and "6." where a 6 could be
  /// misread upside down as a 9 (the dot marks the 6, so a 9 needs none).
  String? label(String kind) {
    final v = value;
    if (v == null) return null;
    if (kind == 'd10t') return v == 0 ? '00' : '$v';
    if (v == 6 && const {'d10u', 'd12', 'd20'}.contains(kind)) {
      return '$v.';
    }
    return '$v';
  }

  /// [p]'s coordinates in the face's (right, up) frame, relative to
  /// [centre].
  Vector2 local(Vector3 p) {
    final d = p - centre;
    return Vector2(d.dot(right), d.dot(up));
  }
}

/// A die's geometry: every face (numbered and blank) and its size.
final class DieGeo {
  DieGeo({
    required this.kind,
    required this.faces,
    required this.bevel,
    required this.cellSpan,
  });

  final String kind;
  final List<DieFaceGeo> faces;

  /// Edge bevel width, world units.
  final double bevel;

  /// The side of the square face patch one atlas cell covers (world
  /// units) — the same for every face of the die, so numerals share one
  /// texel scale.
  final double cellSpan;

  Iterable<DieFaceGeo> get numbered => faces.where((f) => f.value != null);

  /// The hull's vertices.
  List<Vector3> get vertices {
    final out = <Vector3>[];
    for (final f in faces) {
      for (final p in f.points) {
        if (!out.any((q) => q.distanceTo(p) < 1e-6)) out.add(p);
      }
    }
    return out;
  }

  /// Bounding-sphere radius about the origin.
  double get radius => vertices.fold(0.0, (m, p) => max(m, p.length));

  /// The distance from the centre to the nearest numbered face.
  double get inradius =>
      numbered.fold(double.infinity, (m, f) => min(m, f.normal.dot(f.centre)));
}

/// Builds [kind]'s geometry (look-dev §1.1), in document space.
DieGeo buildDieGeo(String kind) {
  final p = _params[kind]!;
  final pts = _rawPoints(kind);
  final hull = convexHullFaces(pts);
  final faces = <_Face>[
    for (final poly in hull) _Face(poly, _normalOf(poly), _centroid(poly)),
  ];
  _number(kind, faces);

  // Numeral frames and sizes (look-dev `die_spec`), in Blender space.
  for (final f in faces) {
    f.up = _frameUp(kind, f);
    f.right = f.up.cross(f.n)..normalize();
    final p2 = [for (final q in f.pts) f.local(q)];
    var anchor = Vector2.zero();
    if (kind == 'd10u' || kind == 'd10t') {
      // Kite: the numeral sits toward the wide (equator) end.
      final far = p2.reduce((a, b) => a.y < b.y ? a : b);
      anchor = far * 0.16;
    }
    f.anchor = anchor;
    f.rin = _polygonInradius([for (final q in p2) q - anchor]);
  }
  var extent = 0.0;
  for (final f in faces) {
    for (final q in f.pts) {
      extent = max(extent, f.local(q).length);
    }
  }

  // To the document: (x, y, z) → (x, z, y), cm → world units.
  final s = kWorldPerCm;
  Vector3 doc(Vector3 v) => Vector3(v.x, v.z, v.y) * s;
  Vector3 dir(Vector3 v) => Vector3(v.x, v.z, v.y)..normalize();
  final out = <DieFaceGeo>[];
  for (final f in faces) {
    final n = dir(f.n);
    // The document's numeral right is n × up: the mirror flips `up × n`.
    var up = dir(f.up);
    if (kind == 'd4' && f.value != null) {
      // The shard reads along the crystal (dice_shard_d4.dart).
      up = shardGlyphUp(n);
    }
    final right = n.cross(up)..normalize();
    out.add(
      DieFaceGeo(
        points: [for (final q in f.pts) doc(q)],
        normal: n,
        centre: doc(f.c),
        value: f.value,
        up: up,
        right: right,
        anchor: f.anchor * s,
        inradius: f.rin * s,
        em: p.em * kBlenderTextEm * f.rin * s,
      ),
    );
  }
  if (kind == 'd4') {
    // The shard's numeral frame turned 90° in its face: re-measure.
    for (var i = 0; i < out.length; i++) {
      final f = out[i];
      if (f.value == null) continue;
      final p2 = [for (final q in f.points) f.local(q)];
      final rin = _polygonInradius(p2);
      out[i] = DieFaceGeo(
        points: f.points,
        normal: f.normal,
        centre: f.centre,
        value: f.value,
        up: f.up,
        right: f.right,
        anchor: Vector2.zero(),
        inradius: rin,
        em: p.em * kBlenderTextEm * rin,
      );
    }
  }
  return DieGeo(
    kind: kind,
    faces: out,
    bevel: p.bevel * _sizeScale * s,
    cellSpan: 2 * extent * 1.1 * s,
  );
}

/// Mutable face while building (Blender space).
final class _Face {
  _Face(this.pts, this.n, this.c);
  final List<Vector3> pts;
  final Vector3 n, c;
  int? value;
  Vector3 up = Vector3(0, 1, 0), right = Vector3(1, 0, 0);
  Vector2 anchor = Vector2.zero();
  double rin = 0;

  Vector2 local(Vector3 p) {
    final d = p - c;
    return Vector2(d.dot(right), d.dot(up));
  }
}

List<Vector3> _rawPoints(String kind) {
  final s = _params[kind]!.size * _sizeScale;
  switch (kind) {
    case 'd4':
      final a = s / 2, l = s * _shardHalf, c = s * _shardCap;
      return [
        for (final x in [-l, l])
          for (final y in [-a, a])
            for (final z in [-a, a]) Vector3(x, y, z),
        Vector3(-(l + c), 0, 0),
        Vector3(l + c, 0, 0),
      ];
    case 'd6':
      final h = s / 2;
      return [
        for (final x in [-1.0, 1.0])
          for (final y in [-1.0, 1.0])
            for (final z in [-1.0, 1.0]) Vector3(x, y, z) * h,
      ];
    case 'd8':
      return _faceUp(
        [
          Vector3(1, 0, 0),
          Vector3(-1, 0, 0),
          Vector3(0, 1, 0),
          Vector3(0, -1, 0),
          Vector3(0, 0, 1),
          Vector3(0, 0, -1),
        ].map((v) => v * s).toList(),
      );
    case 'd10u' || 'd10t':
      final r = s, h = s * 1.08;
      final c36 = cos(36 * pi / 180);
      final z0 = h * (1 - c36) / (1 + c36);
      return [
        Vector3(0, 0, h),
        Vector3(0, 0, -h),
        for (var k = 0; k < 5; k++) ...[
          Vector3(r * cos(72 * k * pi / 180), r * sin(72 * k * pi / 180), z0),
          Vector3(
            r * cos((72 * k + 36) * pi / 180),
            r * sin((72 * k + 36) * pi / 180),
            -z0,
          ),
        ],
      ];
    case 'd12':
      const ip = 1 / _phi;
      final pts = <Vector3>[
        for (final x in [-1.0, 1.0])
          for (final y in [-1.0, 1.0])
            for (final z in [-1.0, 1.0]) Vector3(x, y, z),
        for (final a in [-1.0, 1.0])
          for (final b in [-1.0, 1.0]) ...[
            Vector3(0, a * ip, b * _phi),
            Vector3(a * ip, b * _phi, 0),
            Vector3(a * _phi, 0, b * ip),
          ],
      ];
      return _faceUp([for (final q in pts) q * s]);
    case 'd20':
      final pts = <Vector3>[
        for (final a in [-1.0, 1.0])
          for (final b in [-1.0, 1.0]) ...[
            Vector3(0, a, b * _phi),
            Vector3(a, b * _phi, 0),
            Vector3(a * _phi, 0, b),
          ],
      ];
      return _faceUp([for (final q in pts) q * (s / 2)]);
  }
  throw ArgumentError(kind);
}

/// [pts] turned so one hull face points +Z (the die rests on a face in
/// its canonical pose). The face is the one most aligned with a fixed,
/// generic direction, so the pick is deterministic.
List<Vector3> _faceUp(List<Vector3> pts) {
  final faces = convexHullFaces(pts);
  final probe = Vector3(0.11, 0.23, 1)..normalize();
  final n = faces
      .map(_normalOf)
      .reduce((a, b) => a.dot(probe) >= b.dot(probe) ? a : b);
  // (vector_math's `Quaternion.rotated` is the inverse rotation.)
  final m = Quaternion.fromTwoVectors(n, Vector3(0, 0, 1)).asRotationMatrix();
  return [for (final p in pts) m * p];
}

void _number(String kind, List<_Face> faces) {
  (int, int, int) key(Vector3 n) => (n.x.round(), n.y.round(), n.z.round());
  switch (kind) {
    case 'd4':
      const table = {(0, 0, 1): 4, (0, 0, -1): 1, (0, 1, 0): 2, (0, -1, 0): 3};
      for (final f in faces) {
        final k = key(f.n);
        // Only the axis-aligned long faces carry a number.
        final axis = (f.n.x.abs() < 1e-6) ? table[k] : null;
        f.value = axis;
      }
    case 'd6':
      const table = {
        (0, 0, 1): 1,
        (0, 0, -1): 6,
        (0, -1, 0): 2,
        (0, 1, 0): 5,
        (1, 0, 0): 3,
        (-1, 0, 0): 4,
      };
      for (final f in faces) {
        f.value = table[key(f.n)];
      }
    default:
      final (seeds, total) = _seeds[kind]!;
      final upper = faces.where((f) => f.n.z > 1e-4).toList()
        ..sort((a, b) {
          final dz = (b.n.z * 1e4).round() - (a.n.z * 1e4).round();
          if (dz != 0) return dz;
          return _angle(a.n).compareTo(_angle(b.n));
        });
      assert(upper.length * 2 == faces.length);
      for (final (i, f) in upper.indexed) {
        f.value = seeds[i];
        final opp = faces.reduce((a, b) => a.n.dot(f.n) < b.n.dot(f.n) ? a : b);
        opp.value = total - seeds[i];
      }
  }
}

double _angle(Vector3 n) {
  final a = atan2(n.y, n.x);
  return a < 0 ? a + 2 * pi : a;
}

/// The numeral's up in the face plane (look-dev `_face_frame`).
Vector3 _frameUp(String kind, _Face f) {
  Vector3? proj(Vector3 v) {
    final w = v - f.n * v.dot(f.n);
    return w.length > 1e-6 ? w.normalized() : null;
  }

  if (kind == 'd10u' || kind == 'd10t') {
    final pole = f.pts.reduce((a, b) => a.z.abs() >= b.z.abs() ? a : b);
    return proj(pole - f.c)!;
  }
  if (kind == 'd4') {
    // Caps (the long faces are re-framed in document space).
    return proj(Vector3(1, 0, 0)) ??
        proj(f.pts.reduce((a, b) => a.x.abs() >= b.x.abs() ? a : b) - f.c)!;
  }
  final ref = proj(Vector3(0, 0, 1)) ?? Vector3(0, 1, 0);
  if (kind == 'd6') return ref;
  final best = f.pts.reduce(
    (a, b) => (a - f.c).dot(ref) >= (b - f.c).dot(ref) ? a : b,
  );
  return proj(best - f.c)!;
}

double _polygonInradius(List<Vector2> p) {
  var best = double.infinity;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    final e = b - a;
    final t = ((-a).dot(e) / e.length2).clamp(0.0, 1.0);
    best = min(best, (a + e * t).length);
  }
  return best;
}

Vector3 _centroid(List<Vector3> pts) {
  final c = Vector3.zero();
  for (final p in pts) {
    c.add(p);
  }
  return c / pts.length.toDouble();
}

Vector3 _normalOf(List<Vector3> pts) {
  final c = _centroid(pts);
  final n = (pts[1] - pts[0]).cross(pts[2] - pts[0])..normalize();
  return n.dot(c) > 0 ? n : -n;
}

/// The faces of the convex hull of [pts] (a few dozen points at most):
/// each a polygon ordered counter-clockwise seen from outside, coplanar
/// triangles merged. Brute force — every supporting plane through three
/// points.
List<List<Vector3>> convexHullFaces(List<Vector3> pts, {double eps = 1e-5}) {
  final centre = _centroid(pts);
  final planes = <(Vector3, double)>[];
  final faces = <List<Vector3>>[];
  for (var i = 0; i < pts.length; i++) {
    for (var j = i + 1; j < pts.length; j++) {
      for (var k = j + 1; k < pts.length; k++) {
        final n = (pts[j] - pts[i]).cross(pts[k] - pts[i]);
        if (n.length < eps) continue;
        n.normalize();
        var d = n.dot(pts[i]);
        if (n.dot(centre) > d) {
          n.negate();
          d = -d;
        }
        if (pts.any((p) => n.dot(p) > d + eps)) continue;
        if (planes.any((pl) => pl.$1.dot(n) > 1 - 1e-6)) continue;
        planes.add((n, d));
        final on = [
          for (final p in pts)
            if ((n.dot(p) - d).abs() <= eps * 10) p,
        ];
        final c = _centroid(on);
        final u = (on.first - c)..normalize();
        final v = n.cross(u);
        on.sort((a, b) {
          final da = a - c, db = b - c;
          return atan2(
            da.dot(v),
            da.dot(u),
          ).compareTo(atan2(db.dot(v), db.dot(u)));
        });
        faces.add(on);
      }
    }
  }
  return faces;
}
