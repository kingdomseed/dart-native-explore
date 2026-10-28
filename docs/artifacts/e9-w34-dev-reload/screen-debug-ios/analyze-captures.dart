import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

Future<void> main() async {
  const root = '/private/tmp/dart3d-w34-screen-debug-ios-20261027/r1';
  final images = <String, List<int>>{};
  for (final run in ['parent-runtime-r2', 'parent-runtime-r3']) {
    for (final file in Directory('$root/$run').listSync().whereType<File>()) {
      if (!file.path.endsWith('.png')) continue;
      final process = await Process.run('ffmpeg', [
        '-v', 'error', '-i', file.path, '-frames:v', '1',
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1',
      ], stdoutEncoding: null);
      if (process.exitCode != 0) throw StateError('${process.stderr}');
      final bytes = process.stdout as List<int>;
      if (bytes.length != 402 * 874 * 3) throw StateError(file.path);
      images['$run/${file.path.split('/').last}'] = bytes;
    }
  }
  List<int> sample(String file, int x, int y) {
    final p = (y * 402 + x) * 3;
    return images[file]!.sublist(p, p + 3);
  }
  Map<String, int> compare(String a, String b, List<int> rect) {
    var changed = 0, maximum = 0;
    for (var y = rect[1]; y < rect[1] + rect[3]; y++) {
      for (var x = rect[0]; x < rect[0] + rect[2]; x++) {
        final p = (y * 402 + x) * 3;
        var different = false;
        for (var c = 0; c < 3; c++) {
          final d = (images[a]![p+c] - images[b]![p+c]).abs();
          different |= d != 0;
          maximum = math.max(maximum, d);
        }
        if (different) changed++;
      }
    }
    return {'changedPixels': changed, 'maximumEncodedChannelDifference': maximum};
  }
  const r2 = 'parent-runtime-r2', r3 = 'parent-runtime-r3';
  const monitor = [160, 450, 80, 115], scene = [0, 70, 402, 610];
  final target = <String, Object>{};
  for (final name in ['03-base-after-normal-capture', '05-base-after-metal-capture',
      '07-base-after-rough-capture', '09-base-after-depth-capture',
      '11-base-after-wire-capture']) {
    target[name] = compare('$r2/01-base-authored-capture.png', '$r2/$name.png', monitor);
  }
  final literals = <String, Object>{};
  for (final name in ['05-metallic', '06-roughness', '07-base']) {
    literals[name] = [for (final x in [115, 200, 285]) sample('$r3/$name.png', x, 377)];
  }
  final expected = [for (final x in [0.125, 0.5, 0.875])
    (255 * (x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1/2.4) - 0.055)).round()];
  final result = {
    'basis': 'Encoded 402x874 agent-device screenshots, not raw GPU values or calibrated colorimetry.',
    'monitorRectXYWH': monitor, 'sceneRectXYWH': scene,
    'r2AuthoredTargetComparisons': target,
    'r3AuthoredTargetComparison': compare('$r3/02-base-authored-capture.png', '$r3/04-base-after-normal-capture.png', monitor),
    'r3OffRestoration': compare('$r3/00-off.png', '$r3/10-off-final.png', scene),
    'r2EditedOffRestoration': compare('$r2/15-off-factors-b.png', '$r2/18-off-final.png', scene),
    'r2EditVsOriginal': compare('$r2/00-off.png', '$r2/15-off-factors-b.png', scene),
    'r3WireDifference': compare('$r3/07-base.png', '$r3/08-base-wire.png', scene),
    'r3WireOccluderInterior': compare('$r3/07-base.png', '$r3/08-base-wire.png', [230, 170, 30, 60]),
    'literalValues': [0.125, 0.5, 0.875], 'idealSrgbRoundedCodes': expected,
    'literalEncodedRgb': literals,
    'r3Depth': {'nearXY': [240,200], 'nearRgb': sample('$r3/01-depth-near.png',240,200),
      'farXY': [160,200], 'farRgb': sample('$r3/01-depth-near.png',160,200)},
    'r2OriginalDepth': {'nearRgb': sample('$r2/08-depth.png',240,200),
      'farRgb': sample('$r2/08-depth.png',160,200)},
  };
  File('$root/pixel-analysis.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
