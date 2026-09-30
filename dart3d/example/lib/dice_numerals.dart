/// The DartNative set's face atlas: one RGBA texture per die, one cell
/// per face, rasterized in Dart from Inter's outlines
/// (`dice_glyphs.g.dart`) — the look-dev's numerals (docs/design/
/// dice-lookdev.md §0.2, §3.12 as revised to black frost):
///
/// - near-white numerals, opaque, Inter Regular, stroke ≈ 12% of their
///   height, in a thin dark keyline (#090E12) that keeps them apart from
///   the glowing logo behind;
/// - a thin cyan (#03C3F0) inlay line just inside each face, broken
///   where it would touch a numeral;
/// - everything else the smoky frost body, translucent.
///
/// The same texture is the material's base colour *and* its emissive
/// map: the body is dark enough to emit next to nothing, the numerals
/// and the inlay glow — so they read in a dark room on both natives.
///
/// Pure Dart (no `dartnative` imports) so `dart test` covers it.
library;

import 'dart:io' show ZLibEncoder;
import 'dart:math';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'dice_glyphs.g.dart';
import 'dice_polyhedra.dart';

/// Texels per world unit on every face: a d20 numeral is ~39 texels
/// tall, ~1.5× its size on a phone screen (it minifies cleanly).
const double kAtlasTexelsPerUnit = 11.5;

/// The look, as 8-bit sRGB (+ alpha for the body).
final class DiceFaceLook {
  const DiceFaceLook({
    this.body = const (62, 72, 82, 234),
    this.numeral = const (237, 244, 255),
    this.keyline = const (9, 14, 18),
    this.inlay = const (3, 195, 240),
    this.keylineWidth = 0.12,
    this.inlayInset = 0.3,
    this.inlayWidth = 0.022,
    this.backing = 0.4,
    this.backingOpacity = 0.8,
  });

  /// The frost body: near-#090E12 smoke, alpha = its opacity.
  final (int, int, int, int) body;

  /// Numeral enamel (opaque).
  final (int, int, int) numeral;

  /// The keyline around each numeral (opaque).
  final (int, int, int) keyline;

  /// The inlay line (opaque).
  final (int, int, int) inlay;

  /// Keyline width, as a fraction of the face's inradius.
  final double keylineWidth;

  /// Inlay: its inset from the face edge and its width, as fractions of
  /// the face's inradius.
  final double inlayInset, inlayWidth;

  /// Denser frost behind each numeral (the look-dev's numeral band, dark
  /// for black frost): a soft band [backing] × inradius wide beyond the
  /// keyline that closes [backingOpacity] of the body's translucency, so
  /// the numeral sits on calm smoke rather than on the logo's colours.
  final double backing, backingOpacity;
}

/// A die's atlas: pixels, size, and where each face's cell sits.
final class DieAtlas {
  const DieAtlas({
    required this.pixels,
    required this.width,
    required this.height,
    required this.cellPx,
    required this.cells,
  });

  /// RGBA8, rows top-down.
  final Uint8List pixels;
  final int width, height, cellPx;

  /// Face index (in [DieGeo.faces]) → cell (column, row). Blank faces
  /// share one cell.
  final Map<int, (int, int)> cells;

  /// The UV (v down) of face-local point [local] (world units, relative
  /// to the face centre) on face [face] of [geo].
  Vector2 uv(DieGeo geo, int face, Vector2 local) {
    final (c, r) = cells[face]!;
    final s = geo.cellSpan;
    final u = (c + (local.x / s + 0.5)) * cellPx / width;
    final v = (r + (0.5 - local.y / s)) * cellPx / height;
    return Vector2(u, v);
  }
}

/// The label [text] laid out in em units: y up, centred on the ink's
/// horizontal extent and the cap height — as flat segment lists
/// (ax, ay, bx, by per segment), one list per contour.
List<Float64List> layoutLabel(String text) {
  final em = kGlyphUnitsPerEm.toDouble();
  var pen = 0.0;
  final placed = <(double, List<List<double>>)>[];
  for (final ch in text.split('')) {
    final g = kDiceGlyphs[ch];
    if (g == null) throw ArgumentError('no glyph for "$ch"');
    placed.add((pen, g.$2));
    pen += g.$1;
  }
  var minX = double.infinity, maxX = -double.infinity;
  for (final (x0, contours) in placed) {
    for (final c in contours) {
      for (var i = 0; i < c.length; i += 2) {
        minX = min(minX, c[i] + x0);
        maxX = max(maxX, c[i] + x0);
      }
    }
  }
  final cx = (minX + maxX) / 2, cy = kGlyphCapHeight / 2;
  final out = <Float64List>[];
  for (final (x0, contours) in placed) {
    for (final c in contours) {
      final n = c.length ~/ 2;
      final seg = Float64List(n * 4);
      for (var i = 0; i < n; i++) {
        final j = (i + 1) % n;
        seg[i * 4] = (c[i * 2] + x0 - cx) / em;
        seg[i * 4 + 1] = (c[i * 2 + 1] - cy) / em;
        seg[i * 4 + 2] = (c[j * 2] + x0 - cx) / em;
        seg[i * 4 + 3] = (c[j * 2 + 1] - cy) / em;
      }
      out.add(seg);
    }
  }
  return out;
}

/// Signed distance (same units as the segments) from (x, y) to the
/// outline [contours]: negative inside (non-zero winding).
double signedDistance(List<Float64List> contours, double x, double y) {
  var best = double.infinity;
  var winding = 0;
  for (final s in contours) {
    for (var i = 0; i < s.length; i += 4) {
      final ax = s[i], ay = s[i + 1], bx = s[i + 2], by = s[i + 3];
      final ex = bx - ax, ey = by - ay;
      final len2 = ex * ex + ey * ey;
      var t = len2 == 0 ? 0.0 : ((x - ax) * ex + (y - ay) * ey) / len2;
      t = t < 0 ? 0 : (t > 1 ? 1 : t);
      final dx = x - (ax + ex * t), dy = y - (ay + ey * t);
      final d = dx * dx + dy * dy;
      if (d < best) best = d;
      if (ay <= y) {
        if (by > y && ex * (y - ay) - (x - ax) * ey > 0) winding++;
      } else if (by <= y && ex * (y - ay) - (x - ax) * ey < 0) {
        winding--;
      }
    }
  }
  final d = sqrt(best);
  return winding != 0 ? -d : d;
}

/// Rasterizes [geo]'s atlas in [look].
DieAtlas buildDieAtlas(DieGeo geo, {DiceFaceLook look = const DiceFaceLook()}) {
  final cellPx = (geo.cellSpan * kAtlasTexelsPerUnit).ceil();
  // Numbered faces get a cell each; blank faces share one more.
  final numbered = [
    for (final (i, f) in geo.faces.indexed)
      if (f.value != null) i,
  ];
  final hasBlank = numbered.length < geo.faces.length;
  final count = numbered.length + (hasBlank ? 1 : 0);
  final cols = sqrt(count).ceil();
  final rows = (count / cols).ceil();
  final w = cols * cellPx, h = rows * cellPx;
  final px = Uint8List(w * h * 4);
  final cells = <int, (int, int)>{};
  for (final (k, i) in numbered.indexed) {
    cells[i] = (k % cols, k ~/ cols);
  }
  final blank = (numbered.length % cols, numbered.length ~/ cols);
  for (final (i, f) in geo.faces.indexed) {
    if (f.value == null) cells[i] = blank;
  }

  // Fill everything with the body first (the bevel strips sample the
  // cell just outside the face outline).
  final (br, bg, bb, ba) = look.body;
  for (var i = 0; i < w * h; i++) {
    px[i * 4] = br;
    px[i * 4 + 1] = bg;
    px[i * 4 + 2] = bb;
    px[i * 4 + 3] = ba;
  }
  for (final i in numbered) {
    _paintFace(px, w, cellPx, cells[i]!, geo, geo.faces[i], look);
  }
  return DieAtlas(
    pixels: px,
    width: w,
    height: h,
    cellPx: cellPx,
    cells: cells,
  );
}

void _paintFace(
  Uint8List px,
  int w,
  int cellPx,
  (int, int) cell,
  DieGeo geo,
  DieFaceGeo face,
  DiceFaceLook look,
) {
  final span = geo.cellSpan;
  final texel = span / cellPx; // world units per texel
  final rin = face.inradius;
  final glyphs = layoutLabel(face.label(geo.kind)!);
  // Glyph outline in face-local world units.
  final contours = [
    for (final s in glyphs)
      Float64List.fromList([
        for (var i = 0; i < s.length; i += 2) ...[
          face.anchor.x + s[i] * face.em,
          face.anchor.y + s[i + 1] * face.em,
        ],
      ]),
  ];
  // The face outline (for the inlay), face-local.
  final poly = [for (final p in face.points) face.local(p)];
  final edges = _edgeTable(poly);
  // The outline's centroid-based inradius sets the inlay.
  var polyRin = double.infinity;
  for (var i = 0; i < poly.length; i++) {
    polyRin = min(
      polyRin,
      _segDist(Vector2.zero(), poly[i], poly[(i + 1) % poly.length]),
    );
  }
  final keyW = look.keylineWidth * rin;
  final inlayAt = look.inlayInset * polyRin;
  final inlayHalf = max(look.inlayWidth * polyRin, texel * 0.7) / 2;
  // Glyph bounds (with the keyline and a texel of AA).
  var gx0 = double.infinity, gx1 = -double.infinity;
  var gy0 = double.infinity, gy1 = -double.infinity;
  for (final s in contours) {
    for (var i = 0; i < s.length; i += 2) {
      gx0 = min(gx0, s[i]);
      gx1 = max(gx1, s[i]);
      gy0 = min(gy0, s[i + 1]);
      gy1 = max(gy1, s[i + 1]);
    }
  }
  final backW = look.backing * rin;
  final pad = keyW + backW + 2 * texel;
  final (cc, cr) = cell;
  for (var ty = 0; ty < cellPx; ty++) {
    final y = (0.5 - (ty + 0.5) / cellPx) * span;
    for (var tx = 0; tx < cellPx; tx++) {
      final x = ((tx + 0.5) / cellPx - 0.5) * span;
      // Inside the face? (distance to the outline, positive inside)
      final inside = _insideDistance(edges, x, y);
      if (inside < -texel) continue; // bevel band / outside: body
      // Glyph distance, only near the numeral.
      var sd = double.infinity;
      if (x > gx0 - pad && x < gx1 + pad && y > gy0 - pad && y < gy1 + pad) {
        sd = signedDistance(contours, x, y);
      }
      // The inlay line — broken near the numeral (keyline + a gap).
      final inlayCov = _cov((inside - inlayAt).abs() - inlayHalf, texel);
      if (inlayCov <= 0 && sd > keyW + backW) continue; // plain body
      // Layers, bottom to top: body, backing, inlay, keyline, numeral.
      var r = look.body.$1.toDouble(), g = look.body.$2.toDouble();
      var b = look.body.$3.toDouble(), a = look.body.$4.toDouble();
      final layers = [
        (look.keyline, look.backingOpacity * _smooth(1 - (sd - keyW) / backW)),
        (look.inlay, inlayCov * (1 - _cov(sd - keyW * 1.6, texel))),
        (look.keyline, _cov(sd - keyW, texel)),
        (look.numeral, _cov(sd, texel)),
      ];
      for (final (c, cov) in layers) {
        if (cov <= 0) continue;
        r += (c.$1 - r) * cov;
        g += (c.$2 - g) * cov;
        b += (c.$3 - b) * cov;
        a += (255 - a) * cov;
      }
      final o = ((cr * cellPx + ty) * w + cc * cellPx + tx) * 4;
      px[o] = r.round().clamp(0, 255);
      px[o + 1] = g.round().clamp(0, 255);
      px[o + 2] = b.round().clamp(0, 255);
      px[o + 3] = a.round().clamp(0, 255);
    }
  }
}

/// [rgba] (rows top-down) as a PNG — the atlases travel to the natives
/// encoded (≈20× smaller: most of a cell is flat body colour); both
/// decode PNG payloads by their magic bytes and build the mips.
Uint8List encodePng(Uint8List rgba, int width, int height) {
  final raw = Uint8List(height * (width * 4 + 1));
  for (var y = 0; y < height; y++) {
    final o = y * (width * 4 + 1);
    raw[o] = 1; // Sub filter: flat runs become zeros, which deflate well.
    for (var x = 0; x < width * 4; x++) {
      final i = y * width * 4 + x;
      raw[o + 1 + x] = x < 4 ? rgba[i] : (rgba[i] - rgba[i - 4]) & 0xFF;
    }
  }
  final out = BytesBuilder(copy: false)
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final head = ByteData(4)..setUint32(0, data.length);
    out.add(head.buffer.asUint8List());
    final body = Uint8List(4 + data.length)
      ..setAll(0, type.codeUnits)
      ..setAll(4, data);
    out.add(body);
    final crc = ByteData(4)..setUint32(0, _crc32(body));
    out.add(crc.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6); // RGBA
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder(level: 6).convert(raw));
  chunk('IEND', const []);
  return out.takeBytes();
}

final Uint32List _crcTable = Uint32List.fromList([
  for (var n = 0; n < 256; n++)
    () {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      }
      return c;
    }(),
]);

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Smoothstep of [t] clamped to 0…1.
double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Coverage of a shape whose signed distance (positive outside) is [d],
/// anti-aliased over one [texel].
double _cov(double d, double texel) => (0.5 - d / texel).clamp(0.0, 1.0);

double _segDist(Vector2 p, Vector2 a, Vector2 b) {
  final e = b - a;
  final t = ((p - a).dot(e) / e.length2).clamp(0.0, 1.0);
  return (a + e * t - p).length;
}

/// Distance from (x, y) to a convex polygon's outline: positive inside,
/// negative outside. [edges] holds per edge (ax, ay, ex, ey, 1/|e|²,
/// sign of the centre's side) — see [_edgeTable]. Allocation-free: it
/// runs for every texel of every face.
double _insideDistance(Float64List edges, double x, double y) {
  var best = double.infinity;
  var inside = true;
  for (var i = 0; i < edges.length; i += 6) {
    final ax = edges[i], ay = edges[i + 1];
    final ex = edges[i + 2], ey = edges[i + 3];
    final side = ex * (y - ay) - ey * (x - ax);
    if (side * edges[i + 5] < 0) inside = false;
    var t = ((x - ax) * ex + (y - ay) * ey) * edges[i + 4];
    t = t < 0 ? 0 : (t > 1 ? 1 : t);
    final dx = x - ax - ex * t, dy = y - ay - ey * t;
    final d = dx * dx + dy * dy;
    if (d < best) best = d;
  }
  final d = sqrt(best);
  return inside ? d : -d;
}

/// [poly]'s edges for [_insideDistance] (the centre, the origin, is
/// inside).
Float64List _edgeTable(List<Vector2> poly) {
  final out = Float64List(poly.length * 6);
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    final ex = b.x - a.x, ey = b.y - a.y;
    out
      ..[i * 6] = a.x
      ..[i * 6 + 1] = a.y
      ..[i * 6 + 2] = ex
      ..[i * 6 + 3] = ey
      ..[i * 6 + 4] = 1 / (ex * ex + ey * ey)
      ..[i * 6 + 5] = (ex * -a.y - ey * -a.x).sign;
  }
  return out;
}
