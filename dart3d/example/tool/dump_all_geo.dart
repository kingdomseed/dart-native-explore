import 'dart:io';
import 'package:scene/scene.dart';

void main(List<String> args) {
  final doc = readFsceneb(File(args[0]).readAsBytesSync());
  for (final r in doc.resources.values) {
    if (r is! GeometryResource) continue;
    final vp = doc.payloads[r.vertices];
    print('geo ${r.id} layout=${vp?.layout} vertexLen=${vp?.bytes?.length} ${vp?.bytes != null ? (vp!.bytes!.lengthInBytes / 72) : "?"}');
  }
  // and what node references which geo
  for (final n in doc.nodes.values) {
    for (final c in n.components) {
      if (c.type != 'mesh') continue;
      print('node ${n.name}: mesh');
      final g = c.properties['geometry'];
      if (g is ResourceRefValue) print('   geometry=${g.id}');
      final prims = c.properties['primitives'];
      if (prims is ListValue) {
        for (final p in prims.values) {
          if (p is MapValue) {
            print('   prim geo=${(p.values['geometry'] as ResourceRefValue?)?.id} mat=${(p.values['material'] as ResourceRefValue?)?.id}');
          }
        }
      }
    }
  }
}
