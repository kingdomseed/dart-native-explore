import 'dart:io';

Future<void> main() async {
  const out = '/private/tmp/dart3d-e9-assets-runtime-20261027/r1';
  const implementation = '/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1';
  const dest = '/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e9-w34-dev-reload/sidecar-ios';
  Directory('$dest/implementation').createSync(recursive: true);
  final files = Directory(out).listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return !name.endsWith('.mp4') && !name.endsWith('.fscene') && !name.endsWith('.fsceneb') && name != 'evidence-sha256.txt';
  }).toList()..sort((a,b) => a.path.compareTo(b.path));
  for (final file in files) file.copySync('$dest/${file.uri.pathSegments.last}');
  final implementationFiles = [
    'parent-integration.md', 'parent-error-ownership-sketch.md',
    'parent-source-sha256.txt', 'parent-source-paths.txt', 'parent-owned-sha256.txt',
    'parent-artifact-sha256.txt', 'parent-correction.patch', 'parent-replay.json',
    'parent-focused-before.log', 'parent-focused-final.log',
    'parent-focused-owned-errors.log', 'parent-utf8-before.log', 'parent-utf8-direct.log',
    'parent-package-analysis-final.log', 'parent-example-analysis-final.log',
    'package-parent.dart', 'replay-parent.dart',
  ];
  for (final name in implementationFiles) File('$implementation/$name').copySync('$dest/implementation/$name');
  File('$implementation/handoff.md').copySync('$dest/implementation/worker-handoff.md');
  File('$implementation/verification-results.json').copySync('$dest/implementation/worker-verification-results.json');
  final names = Directory(out).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((name) => name != 'evidence-sha256.txt').toList()..sort();
  final hashes = await Process.run('shasum', ['-a', '256', ...names], workingDirectory: out);
  if (hashes.exitCode != 0) throw StateError('${hashes.stderr}');
  File('$out/evidence-sha256.txt').writeAsStringSync(hashes.stdout.toString());
  File('$dest/evidence-sha256.txt').writeAsStringSync(hashes.stdout.toString());
  stdout.writeln('${files.length} small runtime files and ${implementationFiles.length + 2} implementation receipts copied. Full source archives, inputs and raw video remain in private pickup.');
}
