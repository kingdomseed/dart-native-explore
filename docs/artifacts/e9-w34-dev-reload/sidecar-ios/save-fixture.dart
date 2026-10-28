import 'dart:io';

Future<void> main(List<String> args) async {
  final phase = args.single;
  if (!['init', 'b', 'malformed', 'a'].contains(phase)) throw ArgumentError(phase);
  const out = '/private/tmp/dart3d-e9-assets-runtime-20261027/r1';
  const example = '/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/dart3d/example';
  const dart = '/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart';
  Directory('$out/fixture').createSync(recursive: true);
  final before = DateTime.now().toUtc();
  final result = await Process.run(dart, ['tool/w34_asset_fixture.dart', '$out/fixture', phase], workingDirectory: example);
  File('$out/save-$phase.log').writeAsStringSync('save requested $before\n${result.stdout}${result.stderr}exit=${result.exitCode}\n');
  if (result.exitCode != 0) throw StateError('${result.stderr}');
  for (final name in ['quad.fscene', 'pixels.fsceneb']) {
    File('$out/fixture/$name').copySync('$out/$phase-$name');
  }
  final hashes = await Process.run('shasum', ['-a', '256', '$phase-quad.fscene', '$phase-pixels.fsceneb'], workingDirectory: out);
  if (hashes.exitCode != 0) throw StateError('${hashes.stderr}');
  File('$out/save-$phase.log').writeAsStringSync(hashes.stdout.toString(), mode: FileMode.append);
  stdout.write(hashes.stdout);
}
