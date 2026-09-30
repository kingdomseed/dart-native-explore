/// The Obsidian tray (docs/design/dice-lookdev.md §3.12, option a): a
/// glossy near-black floor and one thin line of light in the DartNative
/// gradient running round the play area — lime-gold along the top,
/// pink along the bottom, blending down the sides. The dice stay the
/// brightest, sharpest thing on screen.
///
/// The rim is eight pieces — four straight bars (unit length, scaled to
/// the tray) and four fixed-radius corners — so a refit (rotation,
/// resize) is only transform writes ([rimPoses]).
///
/// Pure Dart (no `dartnative` imports) so `dart test` covers it.
// ignore_for_file: implementation_imports
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:vector_math/vector_math.dart';

import 'dice_numerals.dart' show encodePng;
import 'dice_tray_layout.dart';

/// The logo's gradient, pink → lime (look-dev `DN_GRADIENT`), sRGB.
const kDnGradient = [
  (0xFA, 0x60, 0xA6),
  (0xEF, 0x38, 0x8B),
  (0xE9, 0x91, 0x73),
  (0xD7, 0xBA, 0x52),
  (0xB5, 0xC7, 0x5E),
];

/// Rim line width, and its offset from the play area's edge (world
/// units; negative = inside): just inside the walls, clear of the
/// chrome above and below the tray.
const double kRimWidth = 0.9, kRimOffset = -1.2;

/// Corner radius of the rim.
const double kRimCorner = 9.0;

/// Emissive strength of the rim: bright enough to glow, low enough that
/// the tone mapper keeps its gradient (at 2.2 it washed to one peach).
const double kRimGlow = 1.3;

/// Pieces, in the order [rimPoses] returns: bars top, bottom, left,
/// right; corners top-right, top-left, bottom-left, bottom-right.
const kRimPieces = [
  'bar.top',
  'bar.bottom',
  'bar.left',
  'bar.right',
  'corner.tr',
  'corner.tl',
  'corner.bl',
  'corner.br',
];

/// The rim's pose per piece for [layout] (translation + scale).
List<({Vector3 translation, Vector3 scale})> rimPoses(TrayLayout layout) {
  final p = layout.play;
  const o = kRimOffset, r = kRimCorner, y = 0.6;
  final x0 = p.xMin - o, x1 = p.xMax + o, z0 = p.zMin - o, z1 = p.zMax + o;
  final w = max(x1 - x0 - 2 * r, 0.01), h = max(z1 - z0 - 2 * r, 0.01);
  final cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
  final one = Vector3.all(1);
  return [
    (translation: Vector3(cx, y, z1), scale: Vector3(w, 1, 1)),
    (translation: Vector3(cx, y, z0), scale: Vector3(w, 1, 1)),
    (translation: Vector3(x0, y, cz), scale: Vector3(1, 1, h)),
    (translation: Vector3(x1, y, cz), scale: Vector3(1, 1, h)),
    (translation: Vector3(x1 - r, y, z1 - r), scale: one),
    (translation: Vector3(x0 + r, y, z1 - r), scale: one),
    (translation: Vector3(x0 + r, y, z0 + r), scale: one),
    (translation: Vector3(x1 - r, y, z0 + r), scale: one),
  ];
}

/// The rim nodes' ids, in [kRimPieces] order, and the bead of light
/// that travels round it ([rimBeadAt]).
final class ObsidianTray {
  const ObsidianTray({required this.rim, required this.bead});
  final List<LocalId> rim;
  final LocalId bead;
}

/// Floor texture edge (texels) — the stone covers the whole 640-unit
/// slab; the phone sees its middle ~⅓.
const int kStoneSize = 512;

/// Seconds for the bead of light to go once round the rim: slow enough
/// to read as ambience, never as a signal.
const double kBeadLap = 11;

/// The bead's radius (it is unlit: a soft warm-white disc).
const double kBeadRadius = 3.2;

/// Where the bead is at time [t] (s): a point on the rim's centre line
/// (the rounded rectangle [rimPoses] draws), clockwise from the top.
Vector3 rimBeadAt(TrayLayout layout, double t) =>
    rimPathPoint(layout, (t / kBeadLap) % 1.0);

/// The point a fraction [s] (0…1) along the rim, clockwise from the
/// middle of the top edge, at the rim's height.
Vector3 rimPathPoint(TrayLayout layout, double s) {
  final p = layout.play;
  const o = kRimOffset, r = kRimCorner, y = 0.7;
  final x0 = p.xMin - o, x1 = p.xMax + o, z0 = p.zMin - o, z1 = p.zMax + o;
  final w = max(x1 - x0 - 2 * r, 0.0), h = max(z1 - z0 - 2 * r, 0.0);
  final arc = pi / 2 * r;
  // Segments: half top, TR corner, right, BR, bottom, BL, left, TL,
  // half top.
  final lens = [w / 2, arc, h, arc, w, arc, h, arc, w / 2];
  final total = lens.fold(0.0, (a, b) => a + b);
  var d = (s % 1.0) * total;
  Vector3 corner(double cx, double cz, double a0, double f) {
    final a = a0 - f * pi / 2;
    return Vector3(cx + r * cos(a), y, cz + r * sin(a));
  }

  for (var i = 0; i < lens.length; i++) {
    if (d > lens[i] && i < lens.length - 1) {
      d -= lens[i];
      continue;
    }
    final f = lens[i] == 0 ? 0.0 : d / lens[i];
    return switch (i) {
      0 => Vector3((x0 + x1) / 2 + f * w / 2, y, z1),
      1 => corner(x1 - r, z1 - r, pi / 2, f),
      2 => Vector3(x1, y, z1 - r - f * h),
      3 => corner(x1 - r, z0 + r, 0, f),
      4 => Vector3(x1 - r - f * w, y, z0),
      5 => corner(x0 + r, z0 + r, -pi / 2, f),
      6 => Vector3(x0, y, z0 + r + f * h),
      7 => corner(x0 + r, z1 - r, -pi, f),
      _ => Vector3(x0 + r + f * w / 2, y, z1),
    };
  }
  return Vector3((x0 + x1) / 2, y, z1);
}

/// Polished near-black stone, [n]² RGBA, covering a slab of half-extent
/// [half] world units: #090E12 with faint smoky veins (domain-warped
/// fractal noise folded into thin lines) and a soft falloff toward the
/// screen edges, baked — the table has depth and grain but stays far
/// below the dice's brightness.
Uint8List obsidianStone(int n, double half) {
  final px = Uint8List(n * n * 4);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      // World position on the slab.
      final wx = (x + 0.5) / n * 2 * half - half;
      final wz = (y + 0.5) / n * 2 * half - half;
      // Veins: thin folds of warped noise, two scales.
      final warp = _fbm(wx * 0.018, wz * 0.018, 3) * 3.2;
      final v1 = 1 - (sin(wx * 0.045 + wz * 0.021 + warp)).abs();
      final v2 = 1 - (sin(wx * -0.02 + wz * 0.07 + warp * 1.7 + 1.3)).abs();
      final vein = pow(v1, 14) * 0.9 + pow(v2, 22) * 0.55;
      // Cloudy depth in the stone.
      final cloud = _fbm(wx * 0.01 + 7.1, wz * 0.01 - 3.3, 4);
      // Soft falloff: the middle of the table a touch lighter.
      final r = sqrt(wx * wx / (80 * 80) + wz * wz / (130 * 130));
      final fall = 1.0 - 0.45 * _smoothstep(0.35, 1.25, r);
      final l = (0.9 + 0.4 * cloud + 1.9 * vein) * fall;
      // Two soft pools of the logo's colours from opposite corners
      // (pink low-left, cyan high-right), baked: light pools without
      // lights (two point lights here hung the A142's GPU).
      final pink = 11 * _pool(wx + 38, wz + 70, 62);
      final cyan = 10 * _pool(wx - 38, wz - 72, 62);
      final i = (y * n + x) * 4;
      px[i] = (9 * l + pink + 0.2 * cyan).round().clamp(0, 255);
      px[i + 1] = (14 * l + 0.25 * pink + 0.75 * cyan).round().clamp(0, 255);
      px[i + 2] = (18 * l + 2 * vein + 0.55 * pink + cyan).round().clamp(
        0,
        255,
      );
      px[i + 3] = 255;
    }
  }
  return px;
}

/// A soft round pool of light at offset (dx, dz) with [radius]: 1 at
/// its centre, fading to 0.
double _pool(double dx, double dz, double radius) {
  final t = 1 - (dx * dx + dz * dz) / (radius * radius);
  return t <= 0 ? 0 : t * t;
}

double _smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Value-noise fBm in 0…1.
double _fbm(double x, double y, int octaves) {
  var sum = 0.0, amp = 0.5, norm = 0.0;
  for (var o = 0; o < octaves; o++) {
    sum += _noise(x, y) * amp;
    norm += amp;
    x = x * 2.03 + 17.1;
    y = y * 2.03 - 9.7;
    amp *= 0.5;
  }
  return sum / norm;
}

double _noise(double x, double y) {
  final xi = x.floor(), yi = y.floor();
  final fx = x - xi, fy = y - yi;
  final ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy);
  final a = _hash(xi, yi), b = _hash(xi + 1, yi);
  final c = _hash(xi, yi + 1), d = _hash(xi + 1, yi + 1);
  return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy;
}

/// Adds the floor slab, its collider, and the rim to [doc], fitted to
/// [layout]. [collider] makes the floor's physics shape.
ObsidianTray addObsidianTray(
  SceneDocument doc,
  TrayLayout layout, {
  required ComponentSpec Function(Vector3 extents) collider,
  required ComponentSpec body,
}) {
  // Floor: a deep slab (unpassable at any throw speed), top at y = 0.
  const half = 320.0, thick = 40.0;
  final floorGeo = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(
        extents: Vector3(half * 2, thick, half * 2),
      ),
    ),
  );
  final stone = obsidianStone(kStoneSize, half);
  final stoneImg = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'png',
      width: kStoneSize,
      height: kStoneSize,
      bytes: encodePng(stone, kStoneSize, kStoneSize),
    ),
  );
  final stoneTex = doc.addResource(
    TextureResource(doc.newId(), payload: stoneImg.id),
  );
  final obsidian = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        // Polished stone, satin: a mirror finish would show the studio
        // IBL's softbox as a bright oval straight down.
        'baseColor': ColorValue(1, 1, 1, 1),
        'baseColorTexture': ResourceRefValue(stoneTex.id),
        'roughness': DoubleValue(0.5),
        'metallic': DoubleValue(0.0),
      },
    ),
  );
  doc.createNode(
    name: 'tray.top',
    transform: TrsTransform(translation: Vector3(0, -thick / 2, 0)),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(floorGeo.id),
          'material': ResourceRefValue(obsidian.id),
        },
      ),
      collider(Vector3(half * 2, thick, half * 2)),
      body,
    ],
    root: true,
  );

  // The gradient, 64 × 1: u = 0 pink … 1 lime.
  const n = 64;
  final grad = Uint8List(n * 4);
  for (var i = 0; i < n; i++) {
    final t = i / (n - 1) * (kDnGradient.length - 1);
    final k = min(t.floor(), kDnGradient.length - 2);
    final f = t - k;
    final a = kDnGradient[k], b = kDnGradient[k + 1];
    grad[i * 4] = (a.$1 + (b.$1 - a.$1) * f).round();
    grad[i * 4 + 1] = (a.$2 + (b.$2 - a.$2) * f).round();
    grad[i * 4 + 2] = (a.$3 + (b.$3 - a.$3) * f).round();
    grad[i * 4 + 3] = 255;
  }
  final gradImg = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: n,
      height: 1,
      length: grad.length,
      bytes: grad,
    ),
  );
  final gradTex = doc.addResource(
    TextureResource(doc.newId(), payload: gradImg.id),
  );
  final neon = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(0, 0, 0, 1),
        'emissive': ColorValue(1, 1, 1, 1),
        'emissiveTexture': ResourceRefValue(gradTex.id),
        'emissiveStrength': DoubleValue(kRimGlow),
        'roughness': DoubleValue(0.5),
      },
    ),
  );

  final meshes = [
    _bar(alongX: true, u0: 1, u1: 1),
    _bar(alongX: true, u0: 0, u1: 0),
    _bar(alongX: false, u0: 0, u1: 1),
    _bar(alongX: false, u0: 0, u1: 1),
    _corner(1, 1, 1),
    _corner(-1, 1, 1),
    _corner(-1, -1, 0),
    _corner(1, -1, 0),
  ];
  final poses = rimPoses(layout);
  final ids = <LocalId>[];
  for (final (i, m) in meshes.indexed) {
    final geo = _addMesh(doc, m);
    ids.add(
      doc
          .createNode(
            name: 'tray.rim.${kRimPieces[i]}',
            transform: TrsTransform(
              translation: poses[i].translation,
              scale: poses[i].scale,
            ),
            components: [
              ComponentSpec(
                'mesh',
                properties: {
                  'geometry': ResourceRefValue(geo),
                  'material': ResourceRefValue(neon.id),
                },
              ),
            ],
            root: true,
          )
          .id,
    );
  }
  // The bead: a soft disc of warm-white light (colour and alpha fall off
  // together), blended over the rim, moved by transform writes only.
  const bn = 64;
  final beadPx = Uint8List(bn * bn * 4);
  for (var y = 0; y < bn; y++) {
    for (var x = 0; x < bn; x++) {
      final dx = (x + 0.5) / bn * 2 - 1, dy = (y + 0.5) / bn * 2 - 1;
      final f = pow((1 - sqrt(dx * dx + dy * dy)).clamp(0.0, 1.0), 2.2);
      final i = (y * bn + x) * 4;
      beadPx[i] = (255 * f).round();
      beadPx[i + 1] = (246 * f).round();
      beadPx[i + 2] = (232 * f).round();
      beadPx[i + 3] = (255 * f).round();
    }
  }
  final beadImg = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: bn,
      height: bn,
      length: beadPx.length,
      bytes: beadPx,
    ),
  );
  final beadTex = doc.addResource(
    TextureResource(doc.newId(), payload: beadImg.id),
  );
  final beadMat = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'unlit',
      properties: {
        'baseColor': ColorValue(1, 1, 1, 1),
        'baseColorTexture': ResourceRefValue(beadTex.id),
        'alphaMode': StringValue('blend'),
      },
    ),
  );
  const br = kBeadRadius;
  final beadGeo = _addMesh(doc, (
    p: [
      Vector3(-br, 0, -br),
      Vector3(br, 0, -br),
      Vector3(br, 0, br),
      Vector3(-br, 0, br),
    ],
    uv: [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
    idx: [0, 1, 2, 0, 2, 3],
  ));
  final bead = doc.createNode(
    name: 'tray.rim.bead',
    transform: TrsTransform(translation: rimBeadAt(layout, 0)),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(beadGeo),
          'material': ResourceRefValue(beadMat.id),
        },
      ),
    ],
    root: true,
  );
  return ObsidianTray(rim: ids, bead: bead.id);
}

typedef _Mesh = ({List<Vector3> p, List<Vector2> uv, List<int> idx});

/// Gradient position [u] (0 pink … 1 lime) as a UV on texel centres —
/// u = 0 or 1 exactly sits on the texture's wrap seam, where filtering
/// mixes pink and lime into one peach.
Vector2 _gradUv(double u) => Vector2((0.5 + u * 63) / 64, 0.5);

/// A unit-length flat ribbon along X or Z, centred, gradient u0 → u1
/// from its −end to its +end.
_Mesh _bar({required bool alongX, required double u0, required double u1}) {
  const hw = kRimWidth / 2;
  Vector3 at(double s, double t) =>
      alongX ? Vector3(s, 0, t) : Vector3(t, 0, s);
  return (
    p: [at(-0.5, -hw), at(0.5, -hw), at(0.5, hw), at(-0.5, hw)],
    uv: [_gradUv(u0), _gradUv(u1), _gradUv(u1), _gradUv(u0)],
    idx: [0, 1, 2, 0, 2, 3],
  );
}

/// A quarter ring of radius [kRimCorner] round its centre, bulging
/// toward (sx, sz), gradient u.
_Mesh _corner(double sx, double sz, double u) {
  const hw = kRimWidth / 2, steps = 10;
  final p = <Vector3>[], uv = <Vector2>[], idx = <int>[];
  for (var i = 0; i <= steps; i++) {
    final a = i / steps * pi / 2;
    final d = Vector3(cos(a) * sx, 0, sin(a) * sz);
    p
      ..add(d * (kRimCorner - hw))
      ..add(d * (kRimCorner + hw));
    uv
      ..add(_gradUv(u))
      ..add(_gradUv(u));
    if (i > 0) {
      final b = (i - 1) * 2;
      idx.addAll([b, b + 1, b + 3, b, b + 3, b + 2]);
    }
  }
  return (p: p, uv: uv, idx: idx);
}

/// Payloads + geometry for a flat, up-facing mesh; triangles wound to
/// face +Y (the document's front-face convention).
LocalId _addMesh(SceneDocument doc, _Mesh m) {
  final idx = <int>[];
  for (var i = 0; i < m.idx.length; i += 3) {
    final a = m.p[m.idx[i]], b = m.p[m.idx[i + 1]], c = m.p[m.idx[i + 2]];
    if ((b - a).cross(c - a).y >= 0) {
      idx.addAll([m.idx[i], m.idx[i + 1], m.idx[i + 2]]);
    } else {
      idx.addAll([m.idx[i], m.idx[i + 2], m.idx[i + 1]]);
    }
  }
  final v = VertexPack.unskinned(
    positions: m.p,
    normals: [for (final _ in m.p) Vector3(0, 1, 0)],
    uvs: m.uv,
    tangents: [for (final _ in m.p) Vector4(1, 0, 0, 1)],
  );
  final ib = Uint16List.fromList(idx).buffer.asUint8List();
  final vp = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.vertexBuffer,
      layout: 'unskinned_uv1_tangent',
      length: v.length,
      bytes: v,
    ),
  );
  final ip = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: 'uint16',
      length: ib.length,
      bytes: ib,
    ),
  );
  var lo = Vector3.all(double.infinity), hi = Vector3.all(-double.infinity);
  for (final q in m.p) {
    lo = Vector3(min(lo.x, q.x), min(lo.y, q.y) - 0.1, min(lo.z, q.z));
    hi = Vector3(max(hi.x, q.x), max(hi.y, q.y) + 0.1, max(hi.z, q.z));
  }
  return doc
      .addResource(
        GeometryResource(
          doc.newId(),
          vertices: vp.id,
          indices: ip.id,
          bounds: BoundsSpec(min: lo, max: hi),
        ),
      )
      .id;
}

double _hash(int a, int b) {
  var k = (a * 374761393 + b * 668265263) & 0x7fffffff;
  k = ((k ^ (k >> 13)) * 1274126177) & 0x7fffffff;
  return (k & 0xffff) / 0xffff;
}
