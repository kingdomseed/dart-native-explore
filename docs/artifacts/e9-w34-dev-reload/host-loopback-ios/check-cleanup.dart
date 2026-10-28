import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const root='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out='/private/tmp/dart3d-e9-host-reload-probe-20261027/r1';
  final paths=File('$out/owned-paths.txt').readAsLinesSync();
  for(final p in paths) { if(File('$root/$p').existsSync()) throw StateError('Probe remains $p'); }
  final fixtures=Directory('$root/dart3d/example/tool/fixtures');
  if(fixtures.existsSync()&&fixtures.listSync().isEmpty) fixtures.deleteSync();
  final cfg=File('$root/dart3d/example/ios/DartNative/Generated.xcconfig').readAsLinesSync();
  final targets=cfg.where((l)=>l.startsWith('DN_TARGET=')).toList();
  if(targets.isNotEmpty&&targets.single!='DN_TARGET=lib/main.dart') throw StateError('Nonstandard target remains');
  final values=cfg.where((l)=>l.startsWith('DART_DEFINES=')).toList();
  if(values.isNotEmpty) {
    final defines=values.single.substring('DART_DEFINES='.length).split(',').where((v)=>v.isNotEmpty).map((v)=>utf8.decode(base64Decode(v)));
    if(defines.any((v)=>v.startsWith('DART3D_RELOAD_URL='))) throw StateError('Reload define remains');
  }
  final locks=await Process.run('shasum',['-a','256','-c','$out/locks-registrants-sha256.txt'],workingDirectory:root);
  if(locks.exitCode!=0) throw StateError('${locks.stderr}\n${locks.stdout}');
  final source=await Process.run('shasum',['-a','256','-c','/private/tmp/dart3d-e5b-outline-state-current-20261027/r1/parent-source-sha256.txt'],workingDirectory:root);
  if(source.exitCode!=0) throw StateError('${source.stderr}\n${source.stdout}');
  File('$out/parent-cleanup.log').writeAsStringSync('All five probe additions absent; accepted52 and six lock/registrant hashes restored. Empty task-created fixture directory removed. Normal main target configuration restored and reload URL absent; other defines undisclosed.\n${source.stdout}\n${locks.stdout}');
  stdout.writeln('All five probe files absent; production52 and locks unchanged; normal target configuration restored.');
}
