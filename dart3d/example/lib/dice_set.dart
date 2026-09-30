/// The DartNative dice set (docs/design/dice-lookdev.md §3.12, black
/// frost revision): smoky near-black frosted dice with the 3D DartNative
/// logo suspended inside each, glowing its own gradient, and near-white
/// numerals in thin dark keylines.
///
/// Each die is built here from its look-dev polyhedron
/// (`dice_polyhedra.dart`): a bevelled mesh (single-segment chamfer whose
/// strips carry both faces' normals, so the edges shade round) mapped
/// onto the die's face atlas (`dice_numerals.dart`), and one material.
///
/// Pure Dart (no `dartnative` imports) so `dart test` covers it.
// ignore_for_file: implementation_imports
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:vector_math/vector_math.dart';

import 'dice_numerals.dart';
import 'dice_polyhedra.dart';
import 'dice_table_scene.dart' show DieFace, DieFaceMap, faceUpRotation;

/// The shell's material knobs. Both natives draw the shell the same
/// way: alpha-blended smoke over the logo (SceneKit has no refraction,
/// and one path keeps the platforms alike), a rough frosted finish (no
/// clear coat by default), the atlas as base colour and as emissive map.
final class DiceShellLook {
  const DiceShellLook({
    this.roughness = 0.58,
    this.clearcoat = 0.0,
    this.clearcoatRoughness = 0.18,
    this.emissive = 1.0,
    this.face = const DiceFaceLook(),
  });

  final double roughness, clearcoat, clearcoatRoughness;

  /// Emissive strength of the atlas (numerals and inlay glow; the dark
  /// body emits next to nothing).
  final double emissive;
  final DiceFaceLook face;
}

/// A built die: its mesh component, its face map, the pose it racks
/// in, and its size.
final class DartNativeDie {
  const DartNativeDie({
    required this.kind,
    required this.mesh,
    required this.faceMap,
    required this.restY,
    required this.restRotation,
    required this.radius,
    required this.inradius,
    required this.material,
  });

  final String kind;
  final ComponentSpec mesh;
  final DieFaceMap faceMap;
  final double restY;
  final Quaternion restRotation;
  final double radius;

  /// Centre-to-face distance — sizes the logo inside.
  final double inradius;

  /// The shell material resource (for live tuning).
  final LocalId material;
}

/// The mesh of [geo] mapped onto [atlas].
({
  List<Vector3> positions,
  List<Vector3> normals,
  List<Vector2> uvs,
  List<Vector4> tangents,
  List<int> indices,
})
buildDieMesh(DieGeo geo, DieAtlas atlas) {
  final positions = <Vector3>[];
  final normals = <Vector3>[];
  final uvs = <Vector2>[];
  final tangents = <Vector4>[];
  final indices = <int>[];
  final b = geo.bevel;

  int vert(int face, Vector3 p, Vector3 n) {
    final f = geo.faces[face];
    positions.add(p);
    normals.add(n.normalized());
    uvs.add(atlas.uv(geo, face, f.local(p)));
    tangents.add(Vector4(f.right.x, f.right.y, f.right.z, 1));
    return positions.length - 1;
  }

  void tri(int i0, int i1, int i2) {
    final a = positions[i0], p1 = positions[i1], p2 = positions[i2];
    final c = (p1 - a).cross(p2 - a);
    // Outward (the solid is convex about the origin): the document's
    // front-face convention.
    final out = a + p1 + p2;
    if (c.dot(out) >= 0) {
      indices.addAll([i0, i1, i2]);
    } else {
      indices.addAll([i0, i2, i1]);
    }
  }

  // Inset corners: each face's polygon pulled in by the bevel width.
  String key(Vector3 p) =>
      '${p.x.toStringAsFixed(3)},${p.y.toStringAsFixed(3)},${p.z.toStringAsFixed(3)}';
  final inset = <(int, String), Vector3>{};
  for (final (fi, f) in geo.faces.indexed) {
    final pts = f.points;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final prev = (pts[(i - 1 + pts.length) % pts.length] - p)..normalize();
      final next = (pts[(i + 1) % pts.length] - p)..normalize();
      final bis = (prev + next)..normalize();
      final half = acos(prev.dot(next).clamp(-1.0, 1.0)) / 2;
      inset[(fi, key(p))] = p + bis * (b / sin(half));
    }
  }

  // Main faces: the inset polygon, fanned from its centre.
  for (final (fi, f) in geo.faces.indexed) {
    final ring = [for (final p in f.points) inset[(fi, key(p))]!];
    final c = vert(fi, f.centre, f.normal);
    final ids = [for (final q in ring) vert(fi, q, f.normal)];
    for (var i = 0; i < ids.length; i++) {
      tri(c, ids[i], ids[(i + 1) % ids.length]);
    }
  }

  // Edge strips, split along their midline so each half samples its own
  // face's cell.
  final facesAt = <String, List<int>>{};
  for (final (fi, f) in geo.faces.indexed) {
    for (final p in f.points) {
      (facesAt[key(p)] ??= []).add(fi);
    }
  }
  final mids = <String, Vector3>{}; // (edge-vertex, face pair) → midpoint
  for (final (fi, f) in geo.faces.indexed) {
    final pts = f.points;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], c = pts[(i + 1) % pts.length];
      final ka = key(a), kc = key(c);
      final gi = facesAt[ka]!.firstWhere(
        (g) => g != fi && facesAt[kc]!.contains(g),
      );
      if (gi < fi) continue;
      final g = geo.faces[gi];
      final nm = f.normal + g.normal;
      final fa = inset[(fi, ka)]!, fc = inset[(fi, kc)]!;
      final ga = inset[(gi, ka)]!, gc = inset[(gi, kc)]!;
      final ma = (fa + ga) / 2, mc = (fc + gc) / 2;
      mids['$ka|$fi|$gi'] = ma;
      mids['$kc|$fi|$gi'] = mc;
      // f's half.
      final q0 = vert(fi, fa, f.normal), q1 = vert(fi, fc, f.normal);
      final q2 = vert(fi, mc, nm), q3 = vert(fi, ma, nm);
      tri(q0, q1, q2);
      tri(q0, q2, q3);
      // g's half.
      final r0 = vert(gi, ma, nm), r1 = vert(gi, mc, nm);
      final r2 = vert(gi, gc, g.normal), r3 = vert(gi, ga, g.normal);
      tri(r0, r1, r2);
      tri(r0, r2, r3);
    }
  }

  // Corner caps: around each vertex, a fan from the caps' centre.
  for (final MapEntry(key: kv, value: around) in facesAt.entries) {
    final v = geo.faces[around.first].points.firstWhere((p) => key(p) == kv);
    final dir = v.normalized();
    // Order the faces around the vertex.
    final ref = (geo.faces[around.first].centre - v)
      ..sub(dir * (geo.faces[around.first].centre - v).dot(dir))
      ..normalize();
    final side = dir.cross(ref);
    double ang(int fi) {
      final d = geo.faces[fi].centre - v;
      return atan2(d.dot(side), d.dot(ref));
    }

    final ring = [...around]..sort((a, c) => ang(a).compareTo(ang(c)));
    final pts = [for (final fi in ring) inset[(fi, kv)]!];
    final centre = Vector3.zero();
    for (final p in pts) {
      centre.add(p);
    }
    centre.scale(1 / pts.length);
    for (var j = 0; j < ring.length; j++) {
      final fi = ring[j], gi = ring[(j + 1) % ring.length];
      final lo = min(fi, gi), hi = max(fi, gi);
      final m = mids['$kv|$lo|$hi'] ?? (pts[j] + pts[(j + 1) % pts.length]) / 2;
      final f = geo.faces[fi], g = geo.faces[gi];
      final nm = f.normal + g.normal;
      tri(vert(fi, centre, dir), vert(fi, pts[j], f.normal), vert(fi, m, nm));
      tri(
        vert(gi, centre, dir),
        vert(gi, m, nm),
        vert(gi, pts[(j + 1) % pts.length], g.normal),
      );
    }
  }
  return (
    positions: positions,
    normals: normals,
    uvs: uvs,
    tangents: tangents,
    indices: indices,
  );
}

/// Adds die [kind] to [doc]: geometry, atlas texture, shell material.
/// Racks with its highest number up and reading upright on screen.
DartNativeDie addDartNativeDie(
  SceneDocument doc,
  String kind, {
  DiceShellLook look = const DiceShellLook(),
}) {
  final geo = buildDieGeo(kind);
  final atlas = buildDieAtlas(geo, look: look.face);
  final mesh = buildDieMesh(geo, atlas);
  final vbytes = VertexPack.unskinned(
    positions: mesh.positions,
    normals: mesh.normals,
    uvs: mesh.uvs,
    tangents: mesh.tangents,
  );
  final ibytes = Uint16List.fromList(mesh.indices).buffer.asUint8List();
  final vp = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.vertexBuffer,
      layout: 'unskinned_uv1_tangent',
      length: vbytes.length,
      bytes: vbytes,
    ),
  );
  final ip = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: 'uint16',
      length: ibytes.length,
      bytes: ibytes,
    ),
  );
  final r = geo.radius;
  final geometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      vertices: vp.id,
      indices: ip.id,
      bounds: BoundsSpec(min: Vector3.all(-r), max: Vector3.all(r)),
    ),
  );
  final img = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      // PNG, not raw rgba8: ~20× smaller to hand to the natives.
      format: 'png',
      width: atlas.width,
      height: atlas.height,
      bytes: encodePng(atlas.pixels, atlas.width, atlas.height),
    ),
  );
  final tex = doc.addResource(TextureResource(doc.newId(), payload: img.id));
  final material = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: shellMaterialProperties(tex.id, look),
    ),
  );

  final faceMap = DieFaceMap(
    faces: [for (final f in geo.numbered) DieFace(f.normal.clone(), f.value!)],
  );
  // Rack pose: the highest number up, its numeral upright on screen.
  final top = geo.numbered.reduce((a, c) => a.value! >= c.value! ? a : c);
  final tilt = faceUpRotation(top.normal);
  final g = tilt.asRotationMatrix() * top.up;
  final rest = Quaternion.axisAngle(Vector3(0, 1, 0), -atan2(g.x, g.z)) * tilt;
  final m = rest.asRotationMatrix();
  var minY = double.infinity;
  for (final p in geo.vertices) {
    minY = min(minY, (m * p).y);
  }
  return DartNativeDie(
    kind: kind,
    mesh: ComponentSpec(
      'mesh',
      properties: {
        'geometry': ResourceRefValue(geometry.id),
        'material': ResourceRefValue(material.id),
      },
    ),
    faceMap: faceMap,
    restY: -minY + 0.2,
    restRotation: rest,
    radius: r,
    inradius: geo.inradius,
    material: material.id,
  );
}

/// The shell material's properties for atlas texture [tex].
Map<String, PropertyValue> shellMaterialProperties(
  LocalId tex,
  DiceShellLook look,
) => {
  'baseColor': ColorValue(1, 1, 1, 1),
  'baseColorTexture': ResourceRefValue(tex),
  'emissive': ColorValue(1, 1, 1, 1),
  'emissiveTexture': ResourceRefValue(tex),
  'emissiveStrength': DoubleValue(look.emissive),
  'roughness': DoubleValue(look.roughness),
  'metallic': DoubleValue(0),
  if (look.clearcoat > 0) ...{
    'clearcoat': DoubleValue(look.clearcoat),
    'clearcoatRoughness': DoubleValue(look.clearcoatRoughness),
  },
  'alphaMode': StringValue('blend'),
  // Cull the far side: blended surfaces don't write depth, so a
  // double-sided shell would lay its back faces over the top numerals.
  'doubleSided': BoolValue(false),
};
