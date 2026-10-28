import 'dart:io';

Future<String> run(String name,List<String> args,{String? cwd}) async {
  final r=await Process.run(name,args,workingDirectory:cwd);
  if(r.exitCode!=0) throw StateError('$name ${r.stderr}\n${r.stdout}');
  return r.stdout.toString();
}

Future<void> main() async {
  const root='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out='/private/tmp/dart3d-e9-host-reload-probe-20261027/r1';
  const base='/private/tmp/dart3d-e5b-outline-state-current-20261027/r1';
  final owned=File('$out/owned-paths.txt').readAsLinesSync();
  final kept=await run('shasum',['-a','256','-c','$base/parent-source-sha256.txt'],cwd:root);
  final locks=await run('shasum',['-a','256','-c','$out/locks-registrants-sha256.txt'],cwd:root);
  final patch=StringBuffer();
  for(final path in owned) {
    final r=await Process.run('diff',['-u','--label','/dev/null','/dev/null','--label','b/$path','$root/$path']);
    if(r.exitCode>1) throw StateError('${r.stderr}');
    patch.write(r.stdout);
  }
  File('$out/parent-probe.patch').writeAsStringSync(patch.toString());
  final paths={...File('$base/parent-source-paths.txt').readAsLinesSync(),...owned}.toList()..sort();
  File('$out/parent-source-paths.txt').writeAsStringSync('${paths.join('\n')}\n');
  File('$out/parent-source-sha256.txt').writeAsStringSync(await run('shasum',['-a','256',...paths],cwd:root));
  File('$out/parent-owned-sha256.txt').writeAsStringSync(await run('shasum',['-a','256',...owned],cwd:root));
  await run('tar',['-czf','$out/parent-source.tgz','-T','$out/parent-source-paths.txt'],cwd:root);
  final scratch=Directory.systemTemp.createTempSync('e9-host-reload-replay-');
  try {
    await run('tar',['-xzf','$base/parent-source.tgz','-C',scratch.path]);
    await run('git',['apply','$out/parent-probe.patch'],cwd:scratch.path);
    await run('shasum',['-a','256','-c','$out/parent-source-sha256.txt'],cwd:scratch.path);
    await run('git',['apply','--reverse','$out/parent-probe.patch'],cwd:scratch.path);
    await run('shasum',['-a','256','-c','$base/parent-source-sha256.txt'],cwd:scratch.path);
    for(final p in owned) { if(File('${scratch.path}/$p').existsSync()) throw StateError('Probe remains $p'); }
  } finally { scratch.deleteSync(recursive:true); }
  File('$out/parent-preservation.log').writeAsStringSync('All52 reviewed files and six locks/registrant preserved; five new probe files only. Parent adds receiver operation-name diagnostics and explicit Column cross-axis stretch in the temporary entrypoint. Host/receiver application decisions unchanged. Full source${paths.length} forward/reverse replay verified; scratch removed.\n$kept\n$locks');
  stdout.write(await run('shasum',['-a','256','$out/parent-source.tgz','$out/parent-probe.patch']));
}
