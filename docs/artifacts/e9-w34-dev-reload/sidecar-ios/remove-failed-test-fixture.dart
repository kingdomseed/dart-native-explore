import 'dart:io';

void main() {
  const out = '/private/tmp/dart3d-e9-assets-runtime-20261027/r1';
  const path = '/var/folders/fv/nlzjt_8x3hq9kq9x4vhjxgsm0000gn/T/w34-assets-VZbZUl';
  final directory = Directory(path);
  if (!directory.existsSync()) return;
  final age = File('/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1/parent-utf8-before.log').statSync().modified.difference(directory.statSync().modified);
  if (age.inSeconds < 0 || age.inSeconds > 40) throw StateError('Not in the failed test interval');
  final entries = directory.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();
  if (entries.join(',') != 'pixels.fsceneb,quad.fscene') throw StateError('Unexpected fixture files');
  for (final name in entries) {
    final actual = File('$path/$name').readAsBytesSync();
    final expected = File('$out/init-$name').readAsBytesSync();
    if (actual.length != expected.length || List.generate(actual.length, (i) => actual[i] == expected[i]).contains(false)) throw StateError('Fixture content differs');
  }
  File('$out/failed-test-cleanup.log').writeAsStringSync('Removed exactly $path, containing only quad.fscene and pixels.fsceneb. Both bytes match the deterministic saved initial fixture. Directory timestamp is ${age.inSeconds}s before the parent custom-zone test timeout log. No other temp directory removed.\n');
  directory.deleteSync(recursive: true);
}
