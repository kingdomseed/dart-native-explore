/// The d4 "crystal shard": a square prism with pyramid caps that lands
/// on one of its four long faces and reads from the face pointing up —
/// unlike a tetrahedron, whose result hides on the bottom or the edges.
///
/// Geometry follows the look-dev spec (`tool/dice_lookdev/build_dice.py`
/// on the `p3-dice-lookdev` branch: section `s`, prism half-length and
/// cap length both `0.62·s`, faces 4/1/2/3 on +up/−up/±side). Numerals
/// read *along* the crystal — the baseline runs down the long axis, so a
/// shard lying across the screen reads upright ([shardGlyphUp]). The body
/// is built here in Dart as a flat-shaded payload mesh with a
/// synthesized numeral texture, so it needs no asset file; the themed
/// look-dev materials replace the texture later without touching the
/// face map.
///
/// Pure Dart (no `dartnative` imports) so `dart test` covers it.
// ignore_for_file: implementation_imports
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:vector_math/vector_math.dart';

/// Shard proportions. [section] is the square cross-section's side in
/// world units, sized against the bundled set (the look-dev d4:d6 size
/// ratio, 1.3 : 2.08, on our 15-unit d6).
const double kShardSection = 9.4;

/// Prism half-length and cap length, as multiples of [kShardSection].
const double kShardHalfRatio = 0.62, kShardCapRatio = 0.62;

/// The four numbered faces in the document's (Y-up) mesh space: the
/// look-dev map (`dice_faces.lookdev.json` — +Y 4, −Y 1, glTF −Z 2,
/// glTF +Z 3) with z mirrored into document space like every other
/// face map ([loadDiceFaceMaps]). Opposite faces sum to 5.
final List<(Vector3, int)> kShardFaces = [
  (Vector3(0, 1, 0), 4),
  (Vector3(0, -1, 0), 1),
  (Vector3(0, 0, 1), 2),
  (Vector3(0, 0, -1), 3),
];

/// The long axis (mesh space): the tips sit at ±X.
final Vector3 kShardAxis = Vector3(1, 0, 0);

/// The "up" of the numeral printed on the long face with outward normal
/// [n] (mesh space): across the crystal, `axis × n`. The numeral's
/// right runs toward the +X tip (`n × up`, the document's screen-right —
/// see [addShardD4]). Rolling about the long axis maps each face's
/// frame onto the next, so while the +X tip points screen-right every
/// face reads upright from the top-down camera.
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

/// What [addShardD4] adds to a document: the mesh component for the die
/// node and the node-origin height at which a long face rests on the
/// table.
final class ShardD4 {
  const ShardD4({
    required this.mesh,
    required this.restY,
    required this.radius,
  });

  final ComponentSpec mesh;
  final double restY;

  /// Bounding-sphere radius (the tip distance).
  final double radius;
}

/// Adds the shard's vertex/index/texture payloads, geometry and
/// material to [doc] and returns the mesh component for the die node.
ShardD4 addShardD4(SceneDocument doc) {
  const a = kShardSection / 2;
  const half = kShardSection * kShardHalfRatio;
  const tip = half + kShardSection * kShardCapRatio;

  final positions = <Vector3>[];
  final normals = <Vector3>[];
  final uvs = <Vector2>[];
  final tangents = <Vector4>[];
  final indices = <int>[];

  // Numeral cells: a 2×2 atlas, one numeral per long face. The glyph's
  // "up" runs along the crystal (+X), as in the look-dev layout.
  final cellOf = <int, (double, double)>{
    1: (0.0, 0.0),
    2: (0.5, 0.0),
    3: (0.0, 0.5),
    4: (0.5, 0.5),
  };
  for (final (n, value) in kShardFaces) {
    final up = shardGlyphUp(n);
    // Document space is left-handed (the natives z-mirror it), so a
    // face's screen-right is n × up — the mirror turns it into the
    // usual right-handed up × n on screen. Here that is +X: numerals
    // read along the crystal.
    final right = n.cross(up);
    final (cu, cv) = cellOf[value]!;
    final base = positions.length;
    // Corners: (-half..half along right = X) × (-a..a along up). The
    // cell's width spans the face's length, its height the narrower
    // section (centred, same texel scale).
    for (final (sr, su) in const [
      (-1.0, -1.0),
      (1.0, -1.0),
      (1.0, 1.0),
      (-1.0, 1.0),
    ]) {
      positions.add(n * a + right * (sr * half) + up * (su * a));
      normals.add(n.clone());
      // v runs down the image; the glyph's up runs up it.
      uvs.add(
        Vector2(cu + 0.25 + sr * 0.25, cv + 0.25 - su * 0.25 * (a / half)),
      );
      tangents.add(Vector4(right.x, right.y, right.z, 1));
    }
    _addQuad(indices, positions, base, n);
  }
  // Caps: four triangular facets at each end, blank (the atlas corner).
  for (final end in const [-1.0, 1.0]) {
    final apex = Vector3(end * tip, 0, 0);
    final ring = [
      Vector3(end * half, a, a),
      Vector3(end * half, a, -a),
      Vector3(end * half, -a, -a),
      Vector3(end * half, -a, a),
    ];
    for (var i = 0; i < 4; i++) {
      final p0 = ring[i], p1 = ring[(i + 1) % 4];
      final n = (p1 - p0).cross(apex - p0)..normalize();
      final centroid = (p0 + p1 + apex) / 3;
      if (n.dot(centroid) < 0) n.negate();
      final base = positions.length;
      for (final p in [p0, p1, apex]) {
        positions.add(p.clone());
        normals.add(n.clone());
        uvs.add(Vector2(0.01, 0.01));
        tangents.add(Vector4(0, 0, 1, 1));
      }
      _addTri(indices, positions, base, base + 1, base + 2, n);
    }
  }

  final vertexBytes = VertexPack.unskinned(
    positions: positions,
    normals: normals,
    uvs: uvs,
    tangents: tangents,
  );
  final indexBytes = Uint16List.fromList(indices).buffer.asUint8List();
  final verts = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.vertexBuffer,
      layout: 'unskinned_uv1_tangent',
      length: vertexBytes.length,
      bytes: vertexBytes,
    ),
  );
  final idx = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: 'uint16',
      length: indexBytes.length,
      bytes: indexBytes,
    ),
  );
  final geo = doc.addResource(
    GeometryResource(
      doc.newId(),
      vertices: verts.id,
      indices: idx.id,
      bounds: BoundsSpec(min: Vector3(-tip, -a, -a), max: Vector3(tip, a, a)),
    ),
  );
  final pixels = shardNumeralAtlas();
  final tex = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: kShardAtlasSize,
      height: kShardAtlasSize,
      length: pixels.length,
      bytes: pixels,
    ),
  );
  final texture = doc.addResource(
    TextureResource(doc.newId(), payload: tex.id),
  );
  final material = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(1, 1, 1, 1),
        'baseColorTexture': ResourceRefValue(texture.id),
        'roughness': DoubleValue(0.32),
        'metallic': DoubleValue(0.0),
      },
    ),
  );
  return ShardD4(
    mesh: ComponentSpec(
      'mesh',
      properties: {
        'geometry': ResourceRefValue(geo.id),
        'material': ResourceRefValue(material.id),
      },
    ),
    restY: a + 0.4,
    radius: tip,
  );
}

/// Two triangles for the quad at [base]..[base]+3, wound so the
/// standard cross product of each triangle points along [n] (the
/// document's front-face convention, as `VertexPack` payloads expect).
void _addQuad(List<int> out, List<Vector3> p, int base, Vector3 n) {
  _addTri(out, p, base, base + 1, base + 2, n);
  _addTri(out, p, base, base + 2, base + 3, n);
}

void _addTri(
  List<int> out,
  List<Vector3> p,
  int i0,
  int i1,
  int i2,
  Vector3 n,
) {
  final c = (p[i1] - p[i0]).cross(p[i2] - p[i0]);
  if (c.dot(n) >= 0) {
    out.addAll([i0, i1, i2]);
  } else {
    out.addAll([i0, i2, i1]);
  }
}

/// Atlas edge in pixels.
const int kShardAtlasSize = 256;

/// The shard's numeral atlas: amber body colour with near-black
/// numerals 1–4 in a 2×2 grid (1 top-left, 2 top-right, 3 bottom-left,
/// 4 bottom-right; image rows run top-down). Strokes are rendered as
/// anti-aliased distance fields over polyline glyphs.
Uint8List shardNumeralAtlas() {
  const n = kShardAtlasSize;
  const cell = n ~/ 2;
  final px = Uint8List(n * n * 4);
  const body = (0.93, 0.70, 0.16);
  const ink = (0.07, 0.05, 0.03);
  final glyphs = {1: _glyph1(), 2: _glyph2(), 3: _glyph3(), 4: _glyph4()};
  const origin = {1: (0, 0), 2: (1, 0), 3: (0, 1), 4: (1, 1)};
  // Glyph box: 0.44 of the cell tall (≈0.55 of the section — the cell
  // spans the face's length), centred; strokes 0.12 of the height, the
  // look-dev weight (docs/design/dice-lookdev.md §0.2 rule 2).
  const glyphH = cell * 0.44;
  const stroke = glyphH * 0.12;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final cx = x ~/ cell, cy = y ~/ cell;
      var value = 0;
      origin.forEach((v, o) {
        if (o.$1 == cx && o.$2 == cy) value = v;
      });
      // Local glyph coords: (0,0) bottom-left of the glyph box, y up.
      final lx = (x - cx * cell + 0.5 - (cell - glyphH * 0.62) / 2) / glyphH;
      final ly = ((cy + 1) * cell - y - 0.5 - (cell - glyphH) / 2) / glyphH;
      var d = double.infinity;
      for (final seg in glyphs[value]!) {
        d = min(d, _segDist(lx, ly, seg));
      }
      final dPx = d * glyphH;
      final t = ((stroke / 2 + 0.75 - dPx) / 1.5).clamp(0.0, 1.0);
      final i = (y * n + x) * 4;
      px[i] = ((body.$1 + (ink.$1 - body.$1) * t) * 255).round();
      px[i + 1] = ((body.$2 + (ink.$2 - body.$2) * t) * 255).round();
      px[i + 2] = ((body.$3 + (ink.$3 - body.$3) * t) * 255).round();
      px[i + 3] = 255;
    }
  }
  return px;
}

typedef _Seg = (double, double, double, double);

double _segDist(double px, double py, _Seg s) {
  final (ax, ay, bx, by) = s;
  final ex = bx - ax, ey = by - ay;
  final len2 = ex * ex + ey * ey;
  final t = len2 == 0
      ? 0.0
      : (((px - ax) * ex + (py - ay) * ey) / len2).clamp(0.0, 1.0);
  final dx = px - (ax + ex * t), dy = py - (ay + ey * t);
  return sqrt(dx * dx + dy * dy);
}

/// Polyline → segments.
List<_Seg> _poly(List<(double, double)> pts) => [
  for (var i = 0; i + 1 < pts.length; i++)
    (pts[i].$1, pts[i].$2, pts[i + 1].$1, pts[i + 1].$2),
];

/// Arc from [a0] to [a1] (radians, counter-clockwise when a1 > a0).
List<(double, double)> _arc(
  double cx,
  double cy,
  double r,
  double a0,
  double a1,
) => [
  for (var i = 0; i <= 16; i++)
    (
      cx + r * cos(a0 + (a1 - a0) * i / 16),
      cy + r * sin(a0 + (a1 - a0) * i / 16),
    ),
];

// Glyphs in a box 0.62 wide × 1 tall, y up.
List<_Seg> _glyph1() => [
  ..._poly([(0.14, 0.78), (0.34, 1.0), (0.34, 0.0)]),
  ..._poly([(0.12, 0.0), (0.56, 0.0)]),
];

List<_Seg> _glyph2() => _poly([
  ..._arc(0.31, 0.72, 0.25, pi * 0.95, -pi * 0.22),
  (0.06, 0.0),
  (0.58, 0.0),
]);

List<_Seg> _glyph3() => [
  ..._poly(_arc(0.30, 0.76, 0.23, pi * 0.9, -pi * 0.5)),
  ..._poly(_arc(0.30, 0.27, 0.27, pi * 0.5, -pi * 0.85)),
];

List<_Seg> _glyph4() =>
    _poly([(0.44, 0.0), (0.44, 1.0), (0.02, 0.33), (0.62, 0.33)]);
