import 'dart:convert';
import 'dart:io';

void main() {
  const out = '/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials';
  final lines = File('$out/observed-native.log').readAsLinesSync();
  final head = RegExp(r'Runner\[(\d+):[^\]]+\].*u4 materials observed clips=\[\d+:t=([^,]+),w=([^\]]+)\] trsTargets=(\d+)$');
  final draw = RegExp(r'u4 materials draw (u4\.materials\.[^/]+)/0:material=ObjectIdentifier\(([^)]+)\),factor=([^,]+),([^,]+),([^,]+),([^,]+),texture=(.*),transparency=([^,]+)$');
  final records = <Map<String, dynamic>>[];
  Map<String, dynamic>? current;
  for (final line in lines) {
    final h = head.firstMatch(line);
    if (h != null) {
      current = {'pid': int.parse(h[1]!), 'time': double.parse(h[2]!),
        'weight': double.parse(h[3]!), 'trsTargets': int.parse(h[4]!),
        'draws': <String, dynamic>{}};
      records.add(current);
    } else {
      final d = draw.firstMatch(line);
      if (d != null && current != null) {
        (current['draws'] as Map<String, dynamic>)[d[1]!] = {
          'object': d[2]!, 'factor': [for (var i=3; i<=6; i++) double.parse(d[i]!)],
          'texture': d[7]!, 'transparency': double.parse(d[8]!),
        };
      }
    }
  }
  final complete = records.where((r) => (r['draws'] as Map).length == 8).toList();
  if (complete.isEmpty) throw StateError('No complete native observation');
  final checks = <Map<String, dynamic>>[];
  void require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }
  void factor(Map<String, dynamic> record, String name, List<double> expected) {
    final actual = ((record['draws'] as Map)['u4.materials.$name'] as Map)['factor'] as List;
    require(List.generate(4, (i) => (actual[i] as double) - expected[i]).every((v) => v.abs() < 1e-6), '$name factor $actual != $expected');
  }
  for (final c in <(double, double, List<double>, List<double>)>[
    (0,1,[1,.25,.25,1],[1,.25,.25,.25]),
    (1,1,[.625,.25,.625,1],[.625,.25,.625,.5]),
    (2,1,[.25,.25,1,1],[.25,.25,1,.75]),
    (1,.25,[.15625,.0625,.15625,1],[.90625,.25,.34375,.3125]),
    (0,.25,[.25,.0625,.0625,1],[1,.25,.25,.25]),
  ]) {
    final record = complete.lastWhere((r) => r['time']==c.$1 && r['weight']==c.$2);
    factor(record,'shared.canonical',c.$3); factor(record,'shared.live',c.$3);
    factor(record,'pbr',c.$3); factor(record,'alpha',c.$4);
    checks.add({'time':c.$1,'weight':c.$2,'opaqueExpected':c.$3,'alphaExpected':c.$4,'observed':record});
  }
  for (final r in complete) {
    require(r['trsTargets']==0,'Property-only animation acquired a TRS target');
    factor(r,'reference',[1,1,1,1]); factor(r,'snapshot',[0,0,0,1]);
    final draws = r['draws'] as Map;
    final canonical = draws['u4.materials.shared.canonical'] as Map;
    final shared = draws['u4.materials.shared.live'] as Map;
    final snapshot = draws['u4.materials.snapshot'] as Map;
    require(canonical['object']==shared['object'],'Shared pair has different material objects');
    require(canonical['object']!=snapshot['object'],'Snapshot aliases live material');
    for (final name in ['shared.canonical','shared.live','pbr','reference','alpha','snapshot']) {
      final d = draws['u4.materials.$name'] as Map;
      require((d['texture'] as String).startsWith('metal2x2:'),'Missing 2x2 texture');
      require(d['texture']==canonical['texture'],'Texture identity changed among consumers');
    }
  }
  final result = {'literalStateChecks':checks, 'completeObservations':complete.length,
    'allSnapshotFactorsBlack':true,'allReferenceFactorsWhite':true,
    'sharedMaterialIdentity':true,'independentSnapshotIdentity':true,
    'sameMetalTextureAcrossSixFaces':true,'allTrsTargetsZero':true,
    'boundary':'Reads actual native material uniforms/objects after sampling; does not calibrate GPU alpha or color. Initial R1 diagnostic truncated and excluded.'};
  File('$out/native-checks.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln('5 literal sampled states, ${complete.length} complete native observations; identity, texture and snapshot checks passed');
}
