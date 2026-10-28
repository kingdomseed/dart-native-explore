import 'dart:io';

void main() {
  const root='/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb';
  const out='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-sheen';
  for(final path in ['dart3d/example/lib/u4_material_scene.dart',
    'dart3d/example/lib/showcase_loader.dart','dart3d/example/test/u4_material_showcase_test.dart',
    'dart3d/ios/Classes/FsceneRealizer.swift']) {
    final target=File('$out/baseline/$path');
    target.parent.createSync(recursive:true);
    File('$root/$path').copySync(target.path);
  }
}
