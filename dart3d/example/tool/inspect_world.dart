import 'dart:io';
import 'package:scene/scene.dart';
import 'package:vector_math/vector_math.dart';

void main(List<String> args) {
  for (final path in args) {
    final doc = readFsceneb(File(path).readAsBytesSync());
    print('=== ${path.split('/').last} ===');
    // world-transform walk
    final worldBoundsMin = Vector3.all(double.infinity);
    final worldBoundsMax = Vector3.all(-double.infinity);
    var boundCount = 0;

    void walk(LocalId id, Matrix4 parent, int depth) {
      final n = doc.nodes[id];
      if (n == null) return;
      final world = parent * n.transform.toMatrix4();
      for (final c in n.components) {
        if (c.type != 'mesh') continue;
        // collect geometry refs: 'geometry' prop or primitives list
        final refs = <LocalId>[];
        final g = c.properties['geometry'];
        if (g is ResourceRefValue) refs.add(g.id);
        final prims = c.properties['primitives'];
        if (prims is ListValue) {
          for (final p in prims.values) {
            if (p is MapValue) {
              final pg = p.values['geometry'];
              if (pg is ResourceRefValue) refs.add(pg.id);
            }
          }
        }
        for (final gid in refs) {
          final geo = doc.resources[gid];
          if (geo is! GeometryResource) continue;
          final b = geo.bounds;
          if (b == null) continue;
          boundCount++;
          for (var i = 0; i < 8; i++) {
            final corner = Vector3(
              (i & 1) == 0 ? b.min.x : b.max.x,
              (i & 2) == 0 ? b.min.y : b.max.y,
              (i & 4) == 0 ? b.min.z : b.max.z,
            );
            final w = world.transform3(corner);
            Vector3.min(worldBoundsMin, w, worldBoundsMin);
            Vector3.max(worldBoundsMax, w, worldBoundsMax);
          }
        }
      }
      for (final ch in n.children) walk(ch, world, depth + 1);
    }

    for (final r in doc.roots) walk(r, Matrix4.identity(), 0);

    // dump per-node local transforms for mesh nodes
    for (final n in doc.nodes.values) {
      final t = n.transform;
      final hasMesh = n.components.any((c) => c.type == 'mesh');
      if (!hasMesh && n.children.isEmpty) continue;
      String ts;
      if (t is TrsTransform) {
        ts = 't=${t.translation.storage.map((e) => e.toStringAsFixed(1)).join(",")} s=${t.scale.storage.map((e) => e.toStringAsFixed(2)).join(",")}';
      } else if (t is MatrixTransform) {
        final m = t.matrix;
        ts = 'M[${m.entry(0, 0).toStringAsFixed(2)}..] t=${m.getTranslation().storage.map((e) => e.toStringAsFixed(1)).join(",")}';
      } else {
        ts = t.runtimeType.toString();
      }
      print('  ${hasMesh ? "M" : " "} ${n.name.isEmpty ? n.id.toString() : n.name} kids=${n.children.length} $ts');
    }
    print('meshed bounds: $boundCount');
    if (boundCount > 0) {
      print('world min=${worldBoundsMin.storage.map((e) => e.toStringAsFixed(1)).join(",")}');
      print('world max=${worldBoundsMax.storage.map((e) => e.toStringAsFixed(1)).join(",")}');
      final sz = worldBoundsMax - worldBoundsMin;
      print('world size=${sz.storage.map((e) => e.toStringAsFixed(1)).join(",")}  r=${(sz.length * 0.5).toStringAsFixed(1)}');
    }
    // local-only union (the current buggy approach) for comparison
    final lmin = Vector3.all(double.infinity);
    final lmax = Vector3.all(-double.infinity);
    for (final r in doc.resources.values) {
      if (r is! GeometryResource) continue;
      final b = r.bounds;
      if (b == null) continue;
      Vector3.min(lmin, b.min, lmin);
      Vector3.max(lmax, b.max, lmax);
    }
    if (lmin.x.isFinite) {
      final sz = lmax - lmin;
      print('local union r=${(sz.length * 0.5).toStringAsFixed(1)} center=${((lmin + lmax) * 0.5).storage.map((e) => e.toStringAsFixed(1)).join(",")}');
    }
  }
}
