import 'dart:io';
import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/scene_model.dart';

void main(List<String> args) {
  for (final path in args) {
    final doc = readFsceneb(File(path).readAsBytesSync());
    print('== ${path.split('/').last}');
    for (final n in doc.nodes.values) {
      final t = n.transform;
      print('  node "${n.name}" transform=$t');
    }
    for (final r in doc.resources.values) {
      if (r is GeometryResource) {
        print('  geo bounds=${r.bounds}');
      }
    }
  }
}
