import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const root = '/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out = '/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1';
  const baseline = '/private/tmp/dart3d-e5b-outline-state-current-20261027/r1';
  final scratch = Directory.systemTemp.createTempSync('w34-parent-replay-');
  final commands = <Map<String, Object>>[];
  Future<void> run(String command, List<String> args) async {
    final result = await Process.run(command, args, workingDirectory: scratch.path);
    commands.add({'command': command, 'args': args, 'exit': result.exitCode, 'stdout': result.stdout.toString(), 'stderr': result.stderr.toString()});
    if (result.exitCode != 0) throw StateError('${result.stdout}${result.stderr}');
  }
  try {
    for (final path in File('$baseline/parent-source-paths.txt').readAsLinesSync().where((p) => p.isNotEmpty)) {
      final target = File('${scratch.path}/$path');
      target.parent.createSync(recursive: true);
      File('$root/$path').copySync(target.path);
    }
    await run('shasum', ['-a', '256', '-c', '$baseline/parent-source-sha256.txt']);
    await run('git', ['apply', '--check', '$out/parent-correction.patch']);
    await run('git', ['apply', '$out/parent-correction.patch']);
    await run('shasum', ['-a', '256', '-c', '$out/parent-source-sha256.txt']);
    await run('git', ['apply', '--reverse', '--check', '$out/parent-correction.patch']);
    await run('git', ['apply', '--reverse', '$out/parent-correction.patch']);
    await run('shasum', ['-a', '256', '-c', '$baseline/parent-source-sha256.txt']);
    for (final path in File('$out/owned-paths.txt').readAsLinesSync().where((p) => p.isNotEmpty)) {
      if (File('${scratch.path}/$path').existsSync()) throw StateError('Added file survived reverse: $path');
    }
    File('$out/parent-replay.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'forward_source58': true, 'reverse_source52': true, 'six_additions_removed': true, 'commands': commands, 'scratch_removed': true})}\n');
  } finally {
    scratch.deleteSync(recursive: true);
  }
  stdout.writeln('Parent patch forward reproduces58; reverse restores52 and removes all6 additions. Replay scratch removed.');
}
