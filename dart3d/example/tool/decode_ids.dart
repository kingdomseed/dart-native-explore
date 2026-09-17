import 'dart:io';
import 'package:scene/scene.dart';

void main(List<String> args) {
  for (final path in args) {
    final doc = readFsceneb(File(path).readAsBytesSync());
    print('=== ${path.split('/').last} ===');
    for (final p in doc.payloads.values) {
      print('  idx=${p.id.index} enc=${p.encoding} layout=${p.layout} fmt=${p.format} len=${p.bytes?.length}');
    }
  }
}
