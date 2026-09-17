import 'dart:io';
import 'package:scene/scene.dart';

void main(List<String> args) {
  for (final path in args) {
    final doc = readFsceneb(File(path).readAsBytesSync());
    print('=== ${path.split('/').last} ===');
    for (final p in doc.payloads.values) {
      print('  ${p.id} enc=${p.encoding} layout=${p.layout} fmt=${p.format} ${p.width}x${p.height} len=${p.length} bytes=${p.bytes?.length}');
    }
  }
}
