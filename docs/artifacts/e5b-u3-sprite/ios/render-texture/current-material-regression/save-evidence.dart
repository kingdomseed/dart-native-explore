import 'dart:io';

Future<void> main() async {
  const root = '/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const source = '/private/tmp/dart3d-e5b-sprite-rt-current-20261027/r1';
  const snapshot = '/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-lights';
  final checked = await Process.run('shasum', ['-a', '256', '-c', '$snapshot/source-sha256.txt'], workingDirectory: root);
  if (checked.exitCode != 0) throw StateError('${checked.stderr}\n${checked.stdout}');
  File('$source/source-check.log').writeAsStringSync(checked.stdout.toString());
  File('$snapshot/source-sha256.txt').copySync('$source/source-sha256.txt');
  const destination = '$root/docs/artifacts/e5b-u3-sprite/ios/render-texture/current-material-regression';
  Directory(destination).createSync(recursive: true);
  final files = Directory(source).listSync().whereType<File>().where((f) => !f.path.endsWith('/evidence-sha256.txt')).toList()..sort((a,b) => a.path.compareTo(b.path));
  for (final file in files) {
    file.copySync('$destination/${file.uri.pathSegments.last}');
  }
  final hashes = await Process.run('shasum', ['-a', '256', ...files.map((f) => f.uri.pathSegments.last)], workingDirectory: source);
  if (hashes.exitCode != 0) throw StateError('${hashes.stderr}');
  File('$source/evidence-sha256.txt').writeAsStringSync(hashes.stdout.toString());
  File('$destination/evidence-sha256.txt').writeAsStringSync(hashes.stdout.toString());
  stdout.writeln('Source49 unchanged; ${files.length} evidence files copied.');
}
