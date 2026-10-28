import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() {
  const root = '/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent';
  final videos = ['blend-before/journey.mp4', 'blend-after/journey.mp4', 'final-clean/journey.mp4'];
  final receipts = <Map<String, Object>>[];
  for (final relative in videos) {
    final path = '$root/$relative';
    final stem = path.substring(0, path.length - 4);
    final commands = <Map<String, Object>>[];
    ProcessResult run(String program, List<String> args, String log) {
      final start = DateTime.now().toUtc().toIso8601String();
      final result = Process.runSync(program, args);
      File(log).writeAsStringSync(result.stderr.toString());
      commands.add({'program': program, 'args': args, 'startUTC': start, 'endUTC': DateTime.now().toUtc().toIso8601String(), 'exitCode': result.exitCode, 'stderrLog': log});
      if (result.exitCode != 0) throw StateError('$program failed for $relative');
      return result;
    }
    final probe = run('ffprobe', ['-v', 'error', '-threads', '2', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,duration,nb_read_frames', '-of', 'json', path], '$stem-probe.log');
    File('$stem-probe.json').writeAsStringSync(probe.stdout.toString());
    run('ffmpeg', ['-v', 'warning', '-threads', '2', '-i', path, '-map', '0:v:0', '-an', '-fps_mode', 'passthrough', '-f', 'null', '-'], '$stem-decode.log');
    final receipt = <String, Object>{'path': path, 'sha256': sha256.convert(File(path).readAsBytesSync()).toString(), 'probe': jsonDecode(probe.stdout.toString()), 'commands': commands, 'decodeWarningLines': File('$stem-decode.log').readAsLinesSync().length};
    receipts.add(receipt);
    File('$root/final-video-receipts.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(receipts));
    print('$relative fully probed/decoded; ${(receipt['probe'] as Map)['streams']}');
  }
}
