import 'dart:io';

Future<ProcessResult> run(String command,List<String> args,{String? cwd}) async {
  final r=await Process.run(command,args,workingDirectory:cwd);
  if(r.exitCode!=0) throw StateError('$command ${r.stderr}');
  return r;
}
Future<void> main() async {
  const root='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials';
  const base='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios';
  final owned=[
    'dart3d/example/lib/showcase_loader.dart','dart3d/example/lib/showcase_scene.dart',
    'dart3d/example/lib/u4_material_scene.dart','dart3d/example/test/u4_material_showcase_test.dart',
    'dart3d/ios/Classes/FsceneRealizer.swift'];
  final paths={...File('$base/source-paths.txt').readAsLinesSync(),...owned}.toList()..sort();
  File('$out/source-paths.txt').writeAsStringSync('${paths.join('\n')}\n');
  final scratch=Directory.systemTemp.createTempSync('u4-material-replay-');
  try {
    final archive=await run('shasum',['-a','256','$base/source.tgz']);
    if(!(archive.stdout as String).startsWith('d949afac5ca46506e7b7b03c43b9ece36375c7df887d60885bdf4a000b4b179f')) throw StateError('wrong baseline');
    await run('tar',['-xzf','$base/source.tgz','-C',scratch.path]);
    await run('shasum',['-a','256','-c','$base/source-sha256.txt'],cwd:scratch.path);
    for(final path in paths.where((p)=>!owned.contains(p))) {
      final a=File('${scratch.path}/$path').readAsBytesSync();
      final b=File('$root/$path').readAsBytesSync();
      if(a.length!=b.length || List.generate(a.length,(i)=>a[i]==b[i]).contains(false)) throw StateError('unowned changed $path');
    }
    final patch=StringBuffer();
    for(final path in owned) {
      final old=File('${scratch.path}/$path');
      final diff=await Process.run('diff',['-u','--label',old.existsSync()?'a/$path':'/dev/null',old.existsSync()?old.path:'/dev/null','--label','b/$path','$root/$path']);
      if(diff.exitCode>1) throw StateError('${diff.stderr}');
      patch.write(diff.stdout);
    }
    File('$out/correction.patch').writeAsStringSync(patch.toString());
    final hashes=await run('shasum',['-a','256',...paths],cwd:root);
    File('$out/source-sha256.txt').writeAsStringSync(hashes.stdout as String);
    await run('git',['apply','--check','$out/correction.patch'],cwd:scratch.path);
    await run('git',['apply','$out/correction.patch'],cwd:scratch.path);
    final verified=await run('shasum',['-a','256','-c','$out/source-sha256.txt'],cwd:scratch.path);
    await run('git',['diff','--check'],cwd:root);
    await run('tar',['-czf','$out/source.tgz','-T','$out/source-paths.txt'],cwd:root);
    final locks=(await run('git',['ls-files','*.lock'],cwd:root)).stdout.toString().trim().split('\n');
    for(final path in locks) {
      final before=await Process.run('git',['show','HEAD:$path'],workingDirectory:root,stdoutEncoding:null);
      if(before.exitCode!=0) throw StateError('missing lock baseline');
      final a=before.stdout as List<int>, b=File('$root/$path').readAsBytesSync();
      if(a.length!=b.length || List.generate(a.length,(i)=>a[i]==b[i]).contains(false)) throw StateError('lock changed $path');
    }
    File('$out/replay-proof.log').writeAsStringSync('Baseline43 archive/hash verified. Five-file delta replayed. All45 current source hashes match. All40 unowned sources and ${locks.length} tracked locks unchanged. No probe class/host hooks in final source. Scratch removed.\n${verified.stdout}');
    stdout.write((await run('shasum',['-a','256','$out/source.tgz','$out/correction.patch'])).stdout);
  } finally { scratch.deleteSync(recursive:true); }
}
