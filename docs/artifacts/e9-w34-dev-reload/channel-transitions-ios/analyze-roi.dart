import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final stage = args.single;
  final bytes = File('$stage/roi.rgb').readAsBytesSync();
  final times = File('$stage/frame-times.txt').readAsLinesSync().map((l) => double.tryParse(l.split(',').first)).whereType<double>().toList();
  const width = 42, height = 35, stride = width * height * 3;
  if (bytes.length != times.length * stride) throw StateError('Raw frame/time counts disagree ${bytes.length ~/ stride} / ${times.length}');
  final rows = <Map<String, Object>>[];
  for (var i = 0; i < times.length; i++) {
    var sum = 0, maximum = 0;
    for (var j = i * stride; j < (i + 1) * stride; j++) {
      final value = bytes[j];
      sum += value;
      if (value > maximum) maximum = value;
    }
    rows.add({'frame': i, 'time': times[i], 'mean': sum / stride, 'max': maximum, 'dark': maximum < 20});
  }
  final groups = <List<Map<String, Object>>>[];
  for (final row in rows.where((r) => r['dark'] == true)) {
    if (groups.isEmpty || (groups.last.last['frame'] as int) + 1 != row['frame']) groups.add([]);
    groups.last.add(row);
  }
  final summary = {'crop': [180, 360, width, height], 'scaledVideo': [402, 874], 'threshold': 'maximum RGB byte < 20', 'frames': rows.length, 'darkFrames': rows.where((r) => r['dark'] == true).length, 'intervals': groups.map((g) => {'firstFrame': g.first['frame'], 'lastFrame': g.last['frame'], 'start': g.first['time'], 'lastTimestamp': g.last['time'], 'frames': g.length}).toList()};
  File('$stage/roi-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'summary': summary, 'rows': rows}));
  print(jsonEncode(summary));
}
