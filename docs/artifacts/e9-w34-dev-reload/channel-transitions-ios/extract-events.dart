import 'dart:convert';
import 'dart:io';

void main() {
  const root = '/private/tmp/dart3d-w34-ios-channel-transitions-20261028/r1/parent';
  final lines = File('$root/native-all.log').readAsLinesSync();
  final groups = <String, List<String>>{};
  final pidPattern = RegExp(r'Runner\[(\d+):');
  for (final line in lines) {
    final pid = pidPattern.firstMatch(line)?.group(1);
    if (pid != null) (groups[pid] ??= []).add(line);
  }
  final active = groups.entries.where((e) => e.value.any((l) => l.contains('debugView channel='))).toList();
  if (active.length != 3) throw StateError('Expected three runtime processes, got ${active.map((e) => e.key)}');
  final result = <String, Object>{};
  for (var i = 0; i < active.length; i++) {
    final stage = ['baseline', 'corrected', 'clean'][i];
    final entry = active[i];
    File('$root/$stage/native-pid.log').writeAsStringSync(entry.value.join('\n') + '\n');
    final events = <Map<String, Object>>[];
    for (final line in entry.value) {
      final option = RegExp(r'debugView channel=(\w+) wireframe=(\w+)').firstMatch(line);
      if (option != null) events.add({'channel': option.group(1)!, 'wire': option.group(2)!, 'rebuilds': <String>[], 'installed': <String>[]});
      if (events.isNotEmpty && line.contains('screenTransition rebuild')) (events.last['rebuilds'] as List<String>).add(line);
      if (events.isNotEmpty && line.contains('screenTransition installed')) (events.last['installed'] as List<String>).add(line);
    }
    var selectedChanges = 0, selectedRebuilds = 0;
    for (var j = 1; j < events.length; j++) {
      final old = events[j - 1]['channel'], next = events[j]['channel'];
      if (old != 'none' && next != 'none' && old != next) {
        selectedChanges++;
        if ((events[j]['rebuilds'] as List).isNotEmpty) selectedRebuilds++;
      }
    }
    final errors = entry.value.where((l) => RegExp(r'liveCatcherTrace|fatal|shader.*error|Cannot modify|cross.scene mutation|SCNTransaction', caseSensitive: false).hasMatch(l)).toList();
    File('$root/$stage/error-query.log').writeAsStringSync(errors.join('\n'));
    final instrumented = stage != 'clean';
    result[stage] = {'pid': entry.key, 'options': events.length, 'selectedChannelChanges': selectedChanges, 'instrumented': instrumented, 'selectedChangesWithRebuild': instrumented ? selectedRebuilds : null, 'allRebuilds': instrumented ? entry.value.where((l) => l.contains('screenTransition rebuild')).length : null, 'installedViews': instrumented ? entry.value.where((l) => l.contains('screenTransition installed')).length : null, 'errorQueryMatches': errors.length, 'events': events};
  }
  File('$root/native-events.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  print(jsonEncode(result.map((k, v) => MapEntry(k, Map<String, Object?>.from(v as Map)..remove('events')))));
}
