import 'dart:convert';
import 'dart:io';

void main() {
  const dir = '/private/tmp/dart3d-e5c-u4-runtime-20261027/ios';
  List<Map<String, Object>> read(String name) {
    return File('$dir/$name').readAsLinesSync()
        .where((line) => line.contains('u4 observed ')).map((line) {
      List<double> numbers(String expression) =>
          RegExp(expression).firstMatch(line)!.groups([1, 2]).map((v) => double.parse(v!)).toList();
      final clip = numbers(r'clips=\[\d+:t=([^,]+),w=([^\]]+)\]');
      final light = numbers(r'lights=\[\d+:document=([^,]+),native=([^\]]+)\]');
      final color = RegExp(r'colors=\[\d+:native=([^;]+);').firstMatch(line)![1]!
          .split(',').map(double.parse).toList();
      final camera = numbers(r'cameras=\[\d+:document=([^,]+),nativeDegrees=([^\]]+)\]');
      final targets = int.parse(RegExp(r'trsTargets=(\d+)').firstMatch(line)![1]!);
      if (targets != 0) throw StateError('Property-only clip bound transforms: $line');
      return <String, Object>{'time': clip[0], 'weight': clip[1], 'color': color,
        'intensity': light[0], 'nativeIntensity': light[1],
        'fovRadians': camera[0], 'nativeDegrees': camera[1], 'trsTargets': targets};
    }).toList();
  }

  final color = read('color-light-native.log');
  final camera = read('camera-native.log');
  final checks = <Map<String, Object>>[];
  void check(String name, List<Map<String, Object>> rows, double time,
      double weight, Map<String, Object> expected) {
    final row = rows.firstWhere((r) => r['time'] == time && r['weight'] == weight);
    for (final entry in expected.entries) {
      final actual = row[entry.key]!;
      final a = actual is List<double> ? actual : [(actual as num).toDouble()];
      final e = entry.value is List<double> ? entry.value as List<double>
          : [(entry.value as num).toDouble()];
      if (a.length != e.length || List.generate(a.length, (i) => (a[i] - e[i]).abs())
          .any((error) => error > 0.000001)) {
        throw StateError('$name ${entry.key}: expected $e, observed $a');
      }
    }
    checks.add({'name': name, 'expected': expected, 'observed': row});
  }

  check('color/light start', color, 0, 1, {'color': [1.0, 0.0, 0.0, 1.0],
    'intensity': 2, 'nativeIntensity': 636.6197723675814});
  check('color/light midpoint', color, 1, 1, {'color': [.5, 0.0, .5, 1.0],
    'intensity': 4, 'nativeIntensity': 1273.2395447351628});
  check('color/light end', color, 2, 1, {'color': [0.0, 0.0, 1.0, 1.0],
    'intensity': 6, 'nativeIntensity': 1909.859317102744});
  check('quarter-weight midpoint', color, 1, .25, {'color': [.875, .75, .875, 1.0],
    'intensity': 1.75, 'nativeIntensity': 557.0423008216337});
  check('stop preserves quarter weight', color, 0, .25, {'color': [1.0, .75, .75, 1.0],
    'intensity': 1.25, 'nativeIntensity': 397.88735772973837});
  for (final (time, degrees) in [(0.0, 45.0), (1.0, 67.5), (2.0, 90.0)]) {
    check('camera $degrees degrees', camera, time, 1, {'nativeDegrees': degrees});
  }
  final result = {'checks': checks, 'colorObservationRows': color.length,
    'cameraObservationRows': camera.length, 'allObservedTrsTargetCounts': 0,
    'numericTolerance': 0.000001,
    'scope': 'Actual SceneKit uniform/light/camera readback in the opaque untextured primary-view fixture; not performance or general material parity'};
  File('$dir/native-checks.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
  stdout.writeln('${checks.length} native observation checks passed');
}
