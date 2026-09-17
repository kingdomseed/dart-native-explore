import 'dart:io';
import 'package:scene/scene.dart';

void main(List<String> args) {
  for (final path in args) {
    final doc = readFsceneb(File(path).readAsBytesSync());
    print('=== ${path.split('/').last} ===');
    for (final r in doc.resources.values) {
      if (r is! MaterialResource) continue;
      print('  mat ${r.id} type=${r.type}');
      for (final e in r.properties.entries) {
        print('    ${e.key}: ${e.value.runtimeType} ${e.value}');
      }
    }
    for (final r in doc.resources.values) {
      if (r is! TextureResource) continue;
      print('  tex ${r.id} payload=${r.payload} asset=${r.asset} content=${r.content}');
    }
  }
}
