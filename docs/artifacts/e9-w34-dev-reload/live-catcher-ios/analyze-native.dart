import 'dart:convert';
import 'dart:io';

void main() {
  const root = '/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent';
  final lines = File('$root/native-all.log').readAsLinesSync();
  final grouped = <String, List<String>>{};
  for (final line in lines) {
    final pid = RegExp(r'Runner\[(\d+):').firstMatch(line)?.group(1);
    if (pid != null) (grouped[pid] ??= []).add(line);
  }
  final active = grouped.entries.where((e) => e.value.any((l) => l.contains('debugView channel='))).toList();
  if (active.length != 4) throw StateError('Expected four sequenced app PIDs, found ${active.map((e) => e.key)}');
  final summaries = <String, Object>{};
  for (var i = 0; i < active.length; i++) {
    final stage = ['before', 'traced', 'clean', 'pbr-regression'][i];
    final entry = active[i];
    File('$root/$stage/native-pid.log').writeAsStringSync(entry.value.join('\n') + '\n');
    final events = entry.value.where((l) => l.contains('com.jasonholtdigital.dart3d:scene') || RegExp(r'fatal|shader.*error|Cannot modify|cross.scene mutation|SCNTransaction|unrecognized selector|UI API called', caseSensitive: false).hasMatch(l)).toList();
    File('$root/$stage/native-events.log').writeAsStringSync(events.join('\n') + '\n');
    final errors = entry.value.where((l) => RegExp(r'fatal|shader.*error|Cannot modify|cross.scene mutation|SCNTransaction|unrecognized selector|UI API called', caseSensitive: false).hasMatch(l)).toList();
    File('$root/$stage/error-query.log').writeAsStringSync(errors.join('\n'));
    final rows = <Map<String, Object>>[];
    final epochRows = <Map<String, Object>>[];
    final latest = <String, Map<String, Object>>{};
    final sample = RegExp(r'sample frame=(\d+) node=(ObjectIdentifier\([^)]+\)) template=(ObjectIdentifier\([^)]+\)) displayed=(ObjectIdentifier\([^)]+\)) inputI=([-+\d.eE]+) actualI=([-+\d.eE]+) inputShadow=(true|false) actualShadow=(true|false) fieldsMatch=(true|false) attached=(true|false) colorInput=(.*?) colorActual=(.*)$');
    for (final line in entry.value) {
      final creation = RegExp(r'displayCreate node=(ObjectIdentifier\([^)]+\)) template=(ObjectIdentifier\([^)]+\)) displayed=(ObjectIdentifier\([^)]+\))').firstMatch(line);
      if (creation != null) {
        final epoch = <String, Object>{'epoch': epochRows.length + 1, 'node': creation.group(1)!, 'template': creation.group(2)!, 'displayed': creation.group(3)!, 'sampleRows': <Map<String, Object>>[]};
        epochRows.add(epoch);
        latest[creation.group(1)!] = epoch;
      }
      final m = sample.firstMatch(line);
      if (m == null) continue;
      final row = <String, Object>{'raw': line, 'frame': int.parse(m.group(1)!), 'node': m.group(2)!, 'template': m.group(3)!, 'displayed': m.group(4)!, 'inputIntensity': double.parse(m.group(5)!), 'actualIntensity': double.parse(m.group(6)!), 'inputShadow': m.group(7) == 'true', 'actualShadow': m.group(8) == 'true', 'fieldsMatch': m.group(9) == 'true', 'attached': m.group(10) == 'true', 'inputColor': m.group(11)!, 'actualColor': m.group(12)!};
      final epoch = latest[m.group(2)!];
      if (epoch == null || epoch['template'] != row['template'] || epoch['displayed'] != row['displayed']) throw StateError('Sample attachment has no matching creation');
      (epoch['sampleRows'] as List<Map<String, Object>>).add(row);
      rows.add(row);
    }
    final epochSummary = epochRows.map((e) {
      final samples = e['sampleRows'] as List<Map<String, Object>>;
      return {...e, 'sampleRows': samples.length, 'intensities': samples.map((s) => s['inputIntensity']).toSet().toList()..sort((a, b) => (a as double).compareTo(b as double)), 'shadowValues': samples.map((s) => s['inputShadow']).toSet().toList()};
    }).toList();
    final counts = entry.value.map((l) => RegExp(r'captureCount templates=(\d+)').firstMatch(l)?.group(1)).whereType<String>().map(int.parse).toList();
    final summary = <String, Object?>{'pid': entry.key, 'instrumented': stage == 'traced', 'channelChanges': entry.value.where((l) => l.contains('debugView channel=')).length, 'errorQueryMatches': errors.length, 'sampleCount': rows.length, 'allSampleFieldsMatch': rows.isEmpty ? null : rows.every((r) => r['fieldsMatch'] == true && r['attached'] == true && r['inputIntensity'] == r['actualIntensity'] && r['inputShadow'] == r['actualShadow'] && r['inputColor'] == r['actualColor']), 'templateCreates': entry.value.where((l) => l.contains('liveDebugTrace templateCreate')).toList(), 'displayCreates': entry.value.where((l) => l.contains('liveDebugTrace displayCreate')).toList(), 'displayRemovals': entry.value.where((l) => l.contains('liveDebugTrace displayRemove')).toList(), 'captureTemplateCounts': counts, 'adapterProbe': entry.value.where((l) => l.contains('liveDebugTrace adapterProbe')).toList(), 'epochs': epochSummary, 'samples': rows};
    summaries[stage] = summary;
  }
  File('$root/native-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summaries));
  final compact = summaries.map((k, v) {
    final s = v as Map<String, Object?>;
    final instrumented = s['instrumented'] == true;
    return MapEntry(k, {'pid': s['pid'], 'instrumented': instrumented, 'errorQueryMatches': s['errorQueryMatches'], 'sampleCount': s['sampleCount'], 'allSampleFieldsMatch': s['allSampleFieldsMatch'], 'templateCreates': instrumented ? (s['templateCreates'] as List).length : null, 'displayCreates': instrumented ? (s['displayCreates'] as List).length : null, 'displayRemovals': instrumented ? (s['displayRemovals'] as List).length : null, 'captureTemplateCounts': instrumented ? s['captureTemplateCounts'] : null});
  });
  File('$root/native-summary.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(compact));
  print(jsonEncode(compact));
}
