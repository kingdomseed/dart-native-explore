import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main(List<String> args) {
  final dir = args.single;
  final commands = <Map<String, Object>>[];
  ProcessResult run(String program, List<String> arguments, String log) {
    final started = DateTime.now().toUtc().toIso8601String();
    final r = Process.runSync(program, arguments);
    File('$dir/$log').writeAsStringSync(r.stderr.toString());
    commands.add({'program': program, 'args': arguments, 'start': started, 'end': DateTime.now().toUtc().toIso8601String(), 'exitCode': r.exitCode, 'stderrLog': log});
    if (r.exitCode != 0) throw StateError('$program failed: ${r.stderr}');
    return r;
  }
  final video = '$dir/journey.mp4';
  final probe = run('ffprobe', ['-v', 'error', '-threads', '2', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,duration,nb_read_frames:frame=best_effort_timestamp_time', '-of', 'json', video], 'probe-errors.log');
  File('$dir/probe.json').writeAsStringSync(probe.stdout.toString());
  final metadata = jsonDecode(probe.stdout.toString()) as Map<String, dynamic>;
  final frames = metadata['frames'] as List<dynamic>;
  File('$dir/frame-times.txt').writeAsStringSync(frames.map((f) => f['best_effort_timestamp_time']).join('\n') + '\n');
  run('ffmpeg', ['-v', 'error', '-y', '-threads', '2', '-i', video, '-vf', 'scale=402:874:flags=neighbor,crop=42:35:180:360', '-pix_fmt', 'rgb24', '-fps_mode', 'passthrough', '-f', 'rawvideo', '$dir/roi.rgb'], 'roi-decode.log');
  final analyzed = run('/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart', ['/private/tmp/dart3d-w34-ios-channel-transitions-20261028/r1/parent/analyze-roi.dart', dir], 'roi-script-errors.log');
  final hash = sha256.convert(File(video).readAsBytesSync()).toString();
  File('$dir/video-receipt.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'video': video, 'sha256': hash, 'streams': metadata['streams'], 'commands': commands, 'roiSummary': jsonDecode(analyzed.stdout.toString())}));
  print(analyzed.stdout);
}
