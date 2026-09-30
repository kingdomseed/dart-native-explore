/// The Obsidian tray (docs/design/dice-lookdev.md §3.12, option a): a
/// deep indigo felt floor and one thin line of light in the DartNative
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

/// The rim nodes' ids, in [kRimPieces] order.
final class ObsidianTray {
  const ObsidianTray({required this.rim});
  final List<LocalId> rim;
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
  final obsidian = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        // Deep indigo felt (#23264A): visibly not black, mid-dark, so
        // the frosted dice and their white numerals still pop.
        'baseColor': ColorValue(0.0168, 0.0194, 0.0685, 1),
        'roughness': DoubleValue(0.92),
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
  return ObsidianTray(rim: ids);
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
