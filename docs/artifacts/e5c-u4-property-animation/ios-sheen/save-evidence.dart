import 'dart:io';

Future<void> main() async {
  const out='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-sheen';
  const target='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e5c-u4-property-animation/ios-sheen';
  final diagnostic=['baseline/dart3d/ios/Classes/FsceneRealizer.swift',
    'FsceneRealizer.corrected.swift','SceneViewHost.baseline.swift',
    'SceneViewHost.observation.swift','SceneViewHost.probe.swift','U4SheenProbe.swift'];
  final checked=await Process.run('shasum',['-a','256',...diagnostic],workingDirectory:out);
  if(checked.exitCode!=0) throw StateError('${checked.stderr}');
  File('$out/diagnostic-source-sha256.txt').writeAsStringSync(checked.stdout as String);
  File('/private/tmp/dart3d-e5c-u4-material-alpha-review-20261027/r1/report.md').copySync('$out/review-r1.md');
  File('/private/tmp/dart3d-e5c-u4-sheen-review-20261027/r2/report.md').copySync('$out/review-r2.md');
  final artifacts=Directory(out).listSync().whereType<File>().map((f)=>f.path.split('/').last)
    .where((n)=>n!='artifact-sha256.txt').toList()..sort();
  final hashes=await Process.run('shasum',['-a','256',...artifacts],workingDirectory:out);
  if(hashes.exitCode!=0) throw StateError('${hashes.stderr}');
  File('$out/artifact-sha256.txt').writeAsStringSync(hashes.stdout as String);
  Directory(target).createSync(recursive:true);
  for(final name in artifacts) {
    if(name.endsWith('.tgz') || name.endsWith('.mp4') || name.endsWith('.swift') || name.endsWith('.html') || name.endsWith('.patch')) continue;
    File('$out/$name').copySync('$target/$name');
  }
  for(final name in ['analyze-images.swift','artifact-sha256.txt']) {
    File('$out/$name').copySync('$target/$name');
  }
  stdout.writeln('Saved bounded receipts; full source/probes/archive/video remain in private pickup.');
}
