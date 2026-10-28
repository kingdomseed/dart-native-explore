import 'dart:io';

Future<String> run(String name, List<String> args, {String? cwd}) async {
  final r = await Process.run(name,args,workingDirectory:cwd);
  if(r.exitCode != 0) throw StateError('$name ${r.stderr}\n${r.stdout}');
  return r.stdout.toString();
}

Future<void> main() async {
  const root='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out='/private/tmp/dart3d-e9-reload-probe-20261027/r1';
  const base='/private/tmp/dart3d-e5b-outline-state-current-20261027/r1';
  final owned=File('$out/owned-paths.txt').readAsLinesSync().toSet();
  final unowned=File('$base/parent-source-sha256.txt').readAsLinesSync().where((l)=>!owned.contains(l.substring(66))).toList();
  File('$out/parent-unowned-sha256.txt').writeAsStringSync('${unowned.join('\n')}\n');
  final kept=await run('shasum',['-a','256','-c','$out/parent-unowned-sha256.txt'],cwd:root);
  final own=await run('shasum',['-a','256','-c','$out/owned-source-sha256.txt'],cwd:root);
  final locks=await run('shasum',['-a','256','-c','$out/locks-registrants-sha256.txt'],cwd:root);
  final paths={...File('$base/parent-source-paths.txt').readAsLinesSync(),...owned}.toList()..sort();
  File('$out/parent-source-paths.txt').writeAsStringSync('${paths.join('\n')}\n');
  File('$out/parent-source-sha256.txt').writeAsStringSync(await run('shasum',['-a','256',...paths],cwd:root));
  await run('tar',['-czf','$out/parent-source.tgz','-T','$out/parent-source-paths.txt'],cwd:root);
  File('$out/parent-source-check.log').writeAsStringSync('Observed source${paths.length}; five owned hashes, ${unowned.length} unowned production snapshot paths and recorded locks unchanged.\n$own\n$kept\n$locks');
  stdout.write(await run('shasum',['-a','256','$out/parent-source.tgz','$out/probe.patch']));
}
