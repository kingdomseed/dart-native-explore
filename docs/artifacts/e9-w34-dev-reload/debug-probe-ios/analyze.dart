import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final root = File(Platform.script.toFilePath()).parent.path;
  final names = [
    '00-off-r2.png',
    '01-mapped-r2.png',
    '01-mapped-steady-r2.png',
    '02-geometry-r2.png',
    '03-transfer-r2.png',
    '04-mapped-return-r2.png',
    '05-off-restored-r2.png',
    '06-wire-on-r2.png',
    '07-wire-off-restored-r2.png',
  ];
  final pixels = <String, List<int>>{};
  for (final name in names) {
    final result = await Process.run('ffmpeg', [
      '-v', 'error', '-i', '$root/$name', '-frames:v', '1',
      '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1',
    ], stdoutEncoding: null);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    final bytes = result.stdout as List<int>;
    if (bytes.length != 402 * 874 * 3) throw StateError('$name dimensions');
    pixels[name] = bytes;
  }
  final comparisons = <String, Object>{};
  for (final name in names.skip(1)) {
    final a = pixels[names.first]!;
    final b = pixels[name]!;
    var changed = 0;
    var maxDifference = 0;
    var nonblack = 0;
    for (var y = 100; y < 750; y++) {
      for (var x = 0; x < 402; x++) {
        final offset = (y * 402 + x) * 3;
        var differs = false;
        for (var c = 0; c < 3; c++) {
          final difference = (a[offset + c] - b[offset + c]).abs();
          if (difference > 0) differs = true;
          if (difference > maxDifference) maxDifference = difference;
        }
        if (differs) changed++;
        if (b[offset] != 0 || b[offset + 1] != 0 || b[offset + 2] != 0) nonblack++;
      }
    }
    comparisons[name] = {
      'changedPixelsVsInitialOff': changed,
      'maximumChannelDifference': maxDifference,
      'nonblackPixels': nonblack,
    };
  }
  final samples = <String, Object>{};
  for (final name in names) {
    final p = pixels[name]!;
    final cells = <String, List<int>>{};
    for (final point in [[120, 320], [260, 330], [140, 470], [290, 475]]) {
      final offset = (point[1] * 402 + point[0]) * 3;
      cells['${point[0]},${point[1]}'] = p.sublist(offset, offset + 3);
    }
    samples[name] = cells;
  }
  final mappedA = pixels['01-mapped-r2.png']!;
  final mappedB = pixels['04-mapped-return-r2.png']!;
  var mappedChanged = 0;
  for (var y = 100; y < 750; y++) {
    for (var x = 0; x < 402; x++) {
      final offset = (y * 402 + x) * 3;
      if (List.generate(3, (c) => mappedA[offset + c] != mappedB[offset + c]).any((x) => x)) {
        mappedChanged++;
      }
    }
  }
  final report = {
    'meaning': 'Encoded screenshot observations, not raw linear shader values or calibrated normals.',
    'sceneCropXYWH': [0, 100, 402, 650],
    'comparisons': comparisons,
    'rgbSamples': samples,
    'initialMappedVsReturnSceneChangedPixels': mappedChanged,
  };
  File('$root/pixel-analysis.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
