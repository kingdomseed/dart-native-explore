import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const root = '/private/tmp/dart3d-w34-ios-channel-transitions-20261028/r1/parent';
  final comparisons = <Map<String, Object>>[];
  final files = Directory('$root/baseline').listSync().whereType<File>().where((f) => RegExp(r'/\d\d-[^/]+\.png$').hasMatch(f.path)).map((f) => f.uri.pathSegments.last).toList()..sort();
  for (final stage in ['corrected', 'clean']) {
    for (final name in files) {
      final a = img.decodePng(File('$root/baseline/$name').readAsBytesSync())!;
      final b = img.decodePng(File('$root/$stage/$name').readAsBytesSync())!;
      if (a.width != 402 || a.height != 874 || b.width != 402 || b.height != 874) throw StateError('Unexpected PNG size $stage/$name');
      var changed = 0, maximum = 0;
      for (var y = 70; y < 650; y++) {
        for (var x = 0; x < 402; x++) {
          final p = a.getPixel(x, y), q = b.getPixel(x, y);
          var delta = 0;
          for (var c = 0; c < 3; c++) {
            final d = (p[c] - q[c]).abs().toInt();
            if (d > delta) delta = d;
          }
          if (delta > 0) changed++;
          if (delta > maximum) maximum = delta;
        }
      }
      comparisons.add({'baseline': name, 'compared': '$stage/$name', 'changedPixels': changed, 'maxRGBDifference': maximum});
    }
  }
  File('$root/still-comparisons.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'crop': [0, 70, 402, 580], 'comparisons': comparisons}));
  print(jsonEncode(comparisons));
}
