import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  const expected = [
    'U3HighlightState op=clearScene count=0 colors={}',
    'U3HighlightState op=apply count=2 colors={128861903781889=[1.0,0.25,0.0,1.0];128861903781890=[0.0,0.5,1.0,0.5]}',
    'U3HighlightState op=apply count=2 colors={128861903781890=[0.0,0.5,1.0,0.5];128861903781891=[0.25,1.0,0.0,0.0]}',
    'U3HighlightState op=apply count=2 colors={128861903781890=[0.0,0.5,1.0,0.5];128861903781891=[0.25,1.0,0.0,0.25]}',
    'U3HighlightState op=removeNodes count=1 colors={128861903781891=[0.25,1.0,0.0,0.25]}',
    'U3HighlightState op=apply count=1 colors={128861903781891=[0.5,1.0,0.0,0.25]}',
    'U3HighlightState op=apply count=1 colors={128861903781891=[0.75,1.0,0.0,0.25]}',
    'U3HighlightState op=apply count=2 colors={128861903781890=[1.0,0.0,1.0,0.5];128861903781891=[0.75,1.0,0.0,0.25]}',
    'U3HighlightState op=clearScene count=0 colors={}',
  ];
  final actual = File(args[0]).readAsLinesSync().where((line) => line.contains('U3HighlightState op=')).map((line) => line.substring(line.indexOf('U3HighlightState op='))).toList();
  final checks = [for (var i = 0; i < expected.length; i++) {
    'index': i,
    'expected': expected[i],
    'observed': i < actual.length ? actual[i] : null,
    'matches': i < actual.length && actual[i] == expected[i],
  }];
  final matched = actual.length == expected.length && checks.every((c) => c['matches'] == true);
  File(args[1]).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
    'source': args[0],
    'expectedRecords': expected.length,
    'actualRecords': actual.length,
    'exactOrderedMatch': matched,
    'checks': checks,
    'extraRecords': actual.skip(expected.length).toList(),
    'scope': 'Actual iOS ingress, patch, transform retention, subtree removal, same-ID re-add and explicit replacement only.',
    'notRun': ['streamed reparenting', 'deferred replay', 'host teardown', 'Android', 'rendering', 'performance'],
  })}\n');
  stdout.writeln('${actual.length} native records; exact ordered match $matched');
  if (!matched) exitCode = 1;
}
