import 'dart:io';
import 'package:scene/scene.dart';

void main(List<String> args) {
  for (final path in args) {
    final doc = readFsceneb(File(path).readAsBytesSync());
    print('=== ${path.split('/').last} ===');
    var shown = 0;
    for (final n in doc.nodes.values) {
      for (final c in n.components) {
        if (c.type != 'mesh') continue;
        if (shown++ > 2) { print('  ...(more mesh nodes)'); break; }
        print('  node ${n.name}: mesh props keys=${c.properties.keys.toList()}');
        for (final e in c.properties.entries) {
          final v = e.value;
          print('    ${e.key}: ${v.runtimeType} ${_summarize(v)}');
        }
        if (n.skin != null) print('    SKIN=${n.skin}');
      }
    }
    var gshown = 0;
    for (final r in doc.resources.values) {
      if (r is! GeometryResource) continue;
      if (gshown++ > 3) break;
      print('  geo ${r.id}: verts=${r.vertices} idx=${r.indices} topo=${r.topology} bounds=${r.bounds != null} morph=${r.morphTargets != null} legacyWinding=${r.legacyWinding}');
    }
    for (final p in doc.payloads.values.take(6)) {
      print('  payload ${p.id}: kind=${p.encoding} fmt=${p.format} len=${p.length} layout=${p.layout}');
    }
    print('  skins: ${doc.skins.length}  anims: ${doc.animations.length}  views: ${doc.views.length}');
  }
}

String _summarize(PropertyValue v) {
  if (v is ListValue) return 'list[${v.values.length}] ${v.values.isEmpty ? "" : v.values.first.runtimeType}';
  if (v is MapValue) return 'map{${v.values.keys.take(6).join(",")}}';
  final s = v.toString();
  return s.length > 90 ? s.substring(0, 90) : s;
}
