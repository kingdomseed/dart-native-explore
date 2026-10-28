import 'dart:io';

Future<void> main() async {
  const root='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials';
  final diagnostic=['SceneViewHost.baseline.swift','SceneViewHost.observation-r1.swift',
    'SceneViewHost.observation.swift','SceneViewHost.alpha-probe.swift',
    'FsceneRealizer.before-alpha.swift','FsceneRealizer.alpha-candidate.swift',
    'U4AlphaProbe.r1.swift','U4AlphaProbe.swift'];
  final hashes=await Process.run('shasum',['-a','256',...diagnostic],workingDirectory:out);
  if(hashes.exitCode!=0) throw StateError('${hashes.stderr}');
  File('$out/diagnostic-source-sha256.txt').writeAsStringSync(hashes.stdout as String);
  final artifacts=Directory(out).listSync().whereType<File>().map((f)=>f.path.split('/').last)
    .where((name)=>name!='artifact-sha256.txt').toList()..sort();
  final all=await Process.run('shasum',['-a','256',...artifacts],workingDirectory:out);
  if(all.exitCode!=0) throw StateError('${all.stderr}');
  File('$out/artifact-sha256.txt').writeAsStringSync(all.stdout as String);
  final target=Directory('$root/docs/artifacts/e5c-u4-property-animation/ios-materials')..createSync(recursive:true);
  for(final name in artifacts) {
    if(name.endsWith('.tgz') || name.endsWith('.mp4') || name.endsWith('.swift') || name.endsWith('.patch') || name.endsWith('.html')) continue;
    File('$out/$name').copySync('${target.path}/$name');
  }
  for(final name in ['analyze-images.swift','artifact-sha256.txt']) {
    File('$out/$name').copySync('${target.path}/$name');
  }
  stdout.writeln('Saved bounded evidence receipts; full archives, probes, videos and comparison page remain in private pickup.');
}
