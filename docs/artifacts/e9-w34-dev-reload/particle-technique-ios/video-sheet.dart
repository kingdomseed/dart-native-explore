import 'dart:io';

Future<void> main(List<String> args) async {
  final root = args.single;
  final scratch = Directory.systemTemp.createTempSync('w34-video-sheet-');
  final times = [0, 5, 12, 30, 60, 75, 82, 88];
  try {
    for (var i = 0; i < times.length; i++) {
      final result = await Process.run('ffmpeg', [
        '-v', 'error', '-ss', '${times[i]}', '-i', '$root/interception.mp4',
        '-frames:v', '1', '-vf', 'scale=201:437',
        '${scratch.path}/frame${i.toString().padLeft(2, '0')}.png',
      ]);
      if (result.exitCode != 0) throw StateError('${result.stderr}');
    }
    final result = await Process.run('ffmpeg', [
      '-v', 'error', '-framerate', '1', '-i', '${scratch.path}/frame%02d.png',
      '-vf', 'tile=4x2', '-frames:v', '1', '$root/video-contact-sheet.png',
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    File('$root/video-sheet-times.txt').writeAsStringSync('Seconds, left-to-right then top-to-bottom: ${times.join(', ')}\n');
    stdout.writeln('8-frame contact sheet saved. Scratch removed.');
  } finally {
    scratch.deleteSync(recursive: true);
  }
}
