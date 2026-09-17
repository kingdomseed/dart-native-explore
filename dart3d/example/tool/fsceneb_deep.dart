import 'dart:io';
import 'package:scene/scene.dart';

void main(List<String> args) {
  final doc = readFsceneb(File(args.single).readAsBytesSync());
  for (final n in doc.nodes.values) {
    print('node "${n.name}" id=${n.id}');
    for (final comp in n.components) {
      print('  component ${comp.type}:');
      comp.properties.forEach((k, v) => print('    $k = $v'));
    }
    print('  transform: ${n.transform}');
  }
  for (final e in doc.resources.entries) {
    final r = e.value;
    print('resource ${r.runtimeType} id=${e.key}');
    if (r is GeometryResource) {
      print('  vertices=${r.vertices} indices=${r.indices} bounds=${r.bounds}');
      print('  procedural=${r.procedural}');
    }
    if (r is MaterialResource) {
      print('  type=${r.type}');
      r.properties.forEach((k, v) => print('    $k = $v'));
    }
  }
  for (final p in doc.payloads.entries) {
    print('payload ${p.key}: enc=${p.value.encoding} layout=${p.value.layout} fmt=${p.value.format} ${p.value.width}x${p.value.height} len=${p.value.length}');
  }
}
