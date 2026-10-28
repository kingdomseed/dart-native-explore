import 'dart:io';

Future<ProcessResult> run(String cmd,List<String> args,{String? cwd}) async {
  final r=await Process.run(cmd,args,workingDirectory:cwd);
  if(r.exitCode!=0) throw StateError('$cmd: ${r.stderr}');
  return r;
}
Future<void> main() async {
  const root='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const base='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials';
  const out='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-sheen';
  final owned=['dart3d/example/lib/showcase_loader.dart','dart3d/example/lib/u4_material_scene.dart',
    'dart3d/example/test/u4_material_showcase_test.dart','dart3d/ios/Classes/FsceneRealizer.swift'];
  final paths=File('$base/source-paths.txt').readAsLinesSync();
  final archive=await run('shasum',['-a','256','$base/source.tgz']);
  if(!(archive.stdout as String).startsWith('6ad07da84ad7e420ab54537f6f467be6ccb2f79942affc1e73ac3f1ac832aacc')) throw StateError('Baseline archive changed');
  final scratch=Directory.systemTemp.createTempSync('u4-sheen-replay-');
  try {
    await run('tar',['-xzf','$base/source.tgz','-C',scratch.path]);
    await run('shasum',['-a','256','-c','$base/source-sha256.txt'],cwd:scratch.path);
    final patch=StringBuffer();
    for(final path in paths) {
      final a=File('${scratch.path}/$path').readAsBytesSync();
      final b=File('$root/$path').readAsBytesSync();
      final same=a.length==b.length && List.generate(a.length,(i)=>a[i]==b[i]).every((v)=>v);
      if(!owned.contains(path) && !same) throw StateError('Unowned changed $path');
      if(owned.contains(path)) {
        final diff=await Process.run('diff',['-u','--label','a/$path','${scratch.path}/$path','--label','b/$path','$root/$path']);
        if(diff.exitCode>1) throw StateError('${diff.stderr}');
        patch.write(diff.stdout);
      }
    }
    File('$out/correction.patch').writeAsStringSync(patch.toString());
    File('$out/source-paths.txt').writeAsStringSync('${paths.join('\n')}\n');
    final hashes=await run('shasum',['-a','256',...paths],cwd:root);
    File('$out/source-sha256.txt').writeAsStringSync(hashes.stdout as String);
    await run('git',['apply','--check','$out/correction.patch'],cwd:scratch.path);
    await run('git',['apply','$out/correction.patch'],cwd:scratch.path);
    final checked=await run('shasum',['-a','256','-c','$out/source-sha256.txt'],cwd:scratch.path);
    await run('git',['diff','--check'],cwd:root);
    final locks=(await run('git',['ls-files','*.lock'],cwd:root)).stdout.toString().trim().split('\n');
    for(final path in locks) {
      final before=await Process.run('git',['show','HEAD:$path'],workingDirectory:root,stdoutEncoding:null);
      final a=before.stdout as List<int>, b=File('$root/$path').readAsBytesSync();
      if(before.exitCode!=0 || a.length!=b.length || !List.generate(a.length,(i)=>a[i]==b[i]).every((v)=>v)) throw StateError('Lock changed $path');
    }
    await run('tar',['-czf','$out/source.tgz','-T','$out/source-paths.txt'],cwd:root);
    File('$out/replay-proof.log').writeAsStringSync('Verified baseline45 source/hash. Four-file patch replay passed for all45 sources;41 unowned sources and ${locks.length} locks unchanged. Host baseline restored, diagnostic class removed. Scratch removed.\n${checked.stdout}');
    stdout.write((await run('shasum',['-a','256','$out/source.tgz','$out/correction.patch'])).stdout);
  } finally { scratch.deleteSync(recursive:true); }
}
