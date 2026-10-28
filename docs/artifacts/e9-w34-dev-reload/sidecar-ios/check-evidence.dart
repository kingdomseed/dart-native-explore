import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> main() async {
  const out = '/private/tmp/dart3d-e9-assets-runtime-20261027/r1';
  final names = ['00-a.png', '01-b.png', '02-malformed-retained.png', '03-a-recovered.png'];
  final images = <Uint8List>[];
  for (final name in names) {
    final png = File('$out/$name').readAsBytesSync();
    final header = ByteData.sublistView(png);
    if (header.getUint32(16) != 402 || header.getUint32(20) != 874) throw StateError('Unexpected PNG size $name');
    final decoded = await Process.run('ffmpeg', ['-v', 'error', '-i', '$out/$name', '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'], stdoutEncoding: null);
    if (decoded.exitCode != 0) throw StateError('${decoded.stderr}');
    final pixels = Uint8List.fromList(decoded.stdout as List<int>);
    if (pixels.length != 402 * 874 * 3) throw StateError('Unexpected RGB length');
    images.add(pixels);
  }
  int changed(Uint8List a, Uint8List b) {
    var count = 0;
    for (var y = 100; y < 740; y++) {
      for (var x = 0; x < 402; x++) {
        final offset = (y * 402 + x) * 3;
        if (a[offset] != b[offset] || a[offset + 1] != b[offset + 1] || a[offset + 2] != b[offset + 2]) count++;
      }
    }
    return count;
  }
  List<double> sample(Uint8List data, int left, int top) {
    final sums = [0, 0, 0];
    for (var y = top; y < top + 9; y++) {
      for (var x = left; x < left + 9; x++) {
        final offset = (y * 402 + x) * 3;
        for (var c = 0; c < 3; c++) sums[c] += data[offset + c];
      }
    }
    return sums.map((value) => value / 81).toList();
  }
  final report = {
    'size': [402, 874],
    'scene_crop': [0, 100, 402, 740],
    'samples': {for (var i = 0; i < names.length; i++) names[i]: {'left': sample(images[i], 40, 200), 'right': sample(images[i], 350, 200)}},
    'changed_pixels': {
      'b_vs_a': changed(images[1], images[0]),
      'malformed_vs_b': changed(images[2], images[1]),
      'recovered_vs_a': changed(images[3], images[0]),
    },
    'meaning': 'Encoded screenshot RGB only. No raw texture calibration, photometry, latency or performance measurement.',
  };
  File('$out/image-comparison.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  final probe = await Process.run('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', '$out/asset-reload.mp4']);
  if (probe.exitCode != 0) throw StateError('${probe.stderr}');
  File('$out/video-probe.json').writeAsStringSync(probe.stdout.toString());
  final metadata = jsonDecode(probe.stdout.toString()) as Map<String, dynamic>;
  final video = (metadata['streams'] as List).firstWhere((s) => s['codec_type'] == 'video') as Map;
  final timeBase = video['time_base'].toString();
  final decoded = await Process.run('ffmpeg', ['-hide_banner', '-nostats', '-v', 'info', '-xerror', '-err_detect', 'explode', '-i', '$out/asset-reload.mp4', '-map', '0:v:0', '-fps_mode', 'passthrough', '-enc_time_base', timeBase.replaceAll('/', ':'), '-f', 'null', '/dev/null']);
  File('$out/video-strict-decode.log').writeAsStringSync('${decoded.stdout}${decoded.stderr}exit=${decoded.exitCode}\n');
  if (decoded.exitCode != 0) throw StateError('Strict video decode failed');
  stdout.writeln('Video duration=${metadata['format']['duration']} time_base=$timeBase strict_decode_exit=0');
  final hash = await Process.run('shasum', ['-a', '256', 'asset-reload.mp4'], workingDirectory: out);
  File('$out/video-sha256.txt').writeAsStringSync(hash.stdout.toString());
  stdout.write(hash.stdout);
}
