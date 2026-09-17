import 'dart:io';
import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/scene_model.dart';

void main(List<String> args) {
  for (final path in args) {
    final doc = readFsceneb(File(path).readAsBytesSync());
    print('== ${path.split('/').last}');
    for (final n in doc.nodes.values) {
      final t = n.transform;
      if (t is TrsTransform) {
        print('  node "${n.name}" t=${t.translation} r=${t.rotation} s=${t.scale}');
      }
    }
    for (final r in doc.resources.values) {
      if (r is GeometryResource && r.bounds != null) {
        final b = r.bounds!;
        print('  geo bounds min=${b.min} max=${b.max}');
      }
    }
  }
}
