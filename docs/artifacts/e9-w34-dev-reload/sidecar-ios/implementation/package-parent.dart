import 'dart:io';

Future<void> main() async {
  const root = '/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out = '/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1';
  const baseline = '/private/tmp/dart3d-e5b-outline-state-current-20261027/r1';
  for (final manifest in [
    '$baseline/parent-source-sha256.txt',
    '/private/tmp/dart3d-e9-host-reload-probe-20261027/r1/locks-registrants-sha256.txt',
  ]) {
    final check = await Process.run('shasum', ['-a', '256', '-c', manifest], workingDirectory: root);
    if (check.exitCode != 0) throw StateError('${check.stdout}${check.stderr}');
  }
  final owned = File('$out/owned-paths.txt').readAsLinesSync().where((p) => p.isNotEmpty).toList();
  final source = {...File('$baseline/parent-source-paths.txt').readAsLinesSync().where((p) => p.isNotEmpty), ...owned}.toList()..sort();
  File('$out/parent-source-paths.txt').writeAsStringSync('${source.join('\n')}\n');
  for (final entry in {'parent-source-sha256.txt': source, 'parent-owned-sha256.txt': owned}.entries) {
    final hashes = await Process.run('shasum', ['-a', '256', ...entry.value], workingDirectory: root);
    if (hashes.exitCode != 0) throw StateError('${hashes.stderr}');
    File('$out/${entry.key}').writeAsStringSync(hashes.stdout.toString());
  }
  final patch = StringBuffer();
  for (final path in owned) {
    final diff = await Process.run('git', ['diff', '--no-index', '--', '/dev/null', path], workingDirectory: root);
    if (diff.exitCode != 1) throw StateError('Unexpected diff result for $path: ${diff.stderr}');
    patch.write(diff.stdout);
  }
  File('$out/parent-correction.patch').writeAsStringSync(patch.toString());
  final archive = await Process.run('tar', ['-czf', '$out/parent-source.tgz', '-T', '$out/parent-source-paths.txt'], workingDirectory: root, environment: {'COPYFILE_DISABLE': '1'});
  if (archive.exitCode != 0) throw StateError('${archive.stderr}');
  final hashes = await Process.run('shasum', ['-a', '256', 'parent-source.tgz', 'parent-correction.patch'], workingDirectory: out);
  File('$out/parent-artifact-sha256.txt').writeAsStringSync(hashes.stdout.toString());
  stdout.write(hashes.stdout);
  stdout.writeln('${source.length} source paths frozen; accepted52 and six locks unchanged.');
}
