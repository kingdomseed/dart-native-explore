import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const root = '/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out = '/private/tmp/dart3d-e9-assets-runtime-20261027/r1';
  const source = '/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1/parent-source-sha256.txt';
  final checked = await Process.run('shasum', ['-a', '256', '-c', source], workingDirectory: root);
  if (checked.exitCode != 0) throw StateError('${checked.stdout}${checked.stderr}');
  final locks = await Process.run('shasum', ['-a', '256', '-c', '/private/tmp/dart3d-e9-host-reload-probe-20261027/r1/locks-registrants-sha256.txt'], workingDirectory: root);
  if (locks.exitCode != 0) throw StateError('${locks.stdout}${locks.stderr}');
  final config = File('$root/dart3d/example/ios/DartNative/Generated.xcconfig').readAsLinesSync();
  final target = config.where((line) => line.startsWith('DN_TARGET=')).toList();
  if (target.isNotEmpty && target.single != 'DN_TARGET=lib/main.dart') throw StateError('Dev target remains');
  for (final line in config.where((line) => line.startsWith('DART_DEFINES='))) {
    final values = line.substring('DART_DEFINES='.length).split(',').where((v) => v.isNotEmpty).map((v) => utf8.decode(base64Decode(v)));
    if (values.any((v) => v.startsWith('DART3D_RELOAD_URL='))) throw StateError('Reload URL remains');
  }
  final fixture = Directory('$out/fixture');
  if (fixture.existsSync()) {
    final names = fixture.listSync().map((entry) => entry.uri.pathSegments.where((s) => s.isNotEmpty).last).toList()..sort();
    if (names.join(',') != 'pixels.fsceneb,quad.fscene') throw StateError('Unexpected task fixture content');
    for (final name in names) {
      final live = File('${fixture.path}/$name').readAsBytesSync();
      final saved = File('$out/a-$name').readAsBytesSync();
      if (live.length != saved.length || List.generate(live.length, (i) => live[i] == saved[i]).contains(false)) throw StateError('Fixture differs from saved recovery');
    }
    fixture.deleteSync(recursive: true);
  }
  final leftovers = <Map<String, Object>>[];
  for (final entry in Directory.systemTemp.listSync(followLinks: false).whereType<Directory>()) {
    if (entry.uri.pathSegments.where((p) => p.isNotEmpty).last.startsWith('w34-assets-')) {
      leftovers.add({'path': entry.path, 'modified': entry.statSync().modified.toUtc().toString()});
    }
  }
  File('$out/test-temp-inventory.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(leftovers)}\n');
  File('$out/cleanup.log').writeAsStringSync('Source58 and six locks match. Generated normal target restored and reload URL absent. Task fixture removed after comparing both files with saved recovered inputs. Recorded test temp inventory for explicit ownership review. Other defines undisclosed.\n${checked.stdout}${locks.stdout}');
  stdout.writeln('Source58/locks preserved; normal target/no reload URL; own runtime fixture removed. Temp candidates: ${leftovers.length}.');
}
