import 'dart:io';
import 'dart:typed_data';
import 'package:dart3d/src/world_bounds.dart';
import 'package:dart3d_example/showcase_loader.dart';

Uint8List? bytesFor(String key) {
  final f = File(key);
  return f.existsSync() ? f.readAsBytesSync() : null;
}

void main() {
  for (final item in showcaseItems) {
    final s = loadShowcaseScene(item, bytesFor: bytesFor);
    if (s == null) { print('${item.label}: FAILED'); continue; }
    final wb = documentWorldBounds(s.document);
    final cb = documentContentBounds(s.document);
    String fmt(b) => b == null ? 'null' : 'r=${((b.$2 - b.$1).length / 2).toStringAsFixed(2)} c=${((b.$1 + b.$2) * 0.5).storage.map((v) => v.toStringAsFixed(1)).join(",")}';
    print('${item.label}: frameR=${s.frameRadius.toStringAsFixed(2)} | world ${fmt(wb)} | content ${fmt(cb)}');
  }
}
