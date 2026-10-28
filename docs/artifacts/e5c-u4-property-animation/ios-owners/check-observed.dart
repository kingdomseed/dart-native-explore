import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final lines = File('${args[0]}/observed-states.log').readAsLinesSync();
  final pattern = RegExp(r'time=([\d.]+) weight=([\d.]+) canonical=ObjectIdentifier\((0x[\da-f]+)\):([\d.,]+) default=ObjectIdentifier\((0x[\da-f]+)\):([\d.,]+) rebind=ObjectIdentifier\((0x[\da-f]+)\):([\d.,]+)');
  final states = lines.map((line) {
    final m = pattern.firstMatch(line)!;
    return <String, Object>{
      'time': double.parse(m[1]!), 'weight': double.parse(m[2]!),
      'ids': [m[3]!, m[5]!, m[7]!],
      'factors': [m[4]!, m[6]!, m[8]!].map((v) => v.split(',').map(double.parse).toList()).toList(),
    };
  }).toList();
  final oldA = (states[0]['ids']! as List)[0];
  final b = (states[3]['ids']! as List)[1];
  final newA = (states[8]['ids']! as List)[0];
  final f = (states[11]['ids']! as List)[2];
  if ({oldA, b, newA, f}.length != 4) throw StateError('Expected four distinct material objects');
  const red = [1.0, 0.0, 0.0, 1.0];
  const q0 = [1.0, .75, .75, 1.0];
  const q1 = [.875, .75, .875, 1.0];
  const q2 = [.75, .75, 1.0, 1.0];
  const green = [0.0, 1.0, 0.0, 1.0];
  const orange = [1.0, .5, 0.0, 1.0];
  const n1 = [.275, .3, .575, 1.0];
  const n2 = [.15, .3, .7, 1.0];
  const purple = [.5, 0.0, .5, 1.0];
  const blue = [0.0, 0.0, 1.0, 1.0];
  final expected = [
    (0.0, 1.0, [oldA, oldA, oldA], [red, red, red]),
    (0.0, .25, [oldA, oldA, oldA], [q0, q0, q0]),
    (1.0, .25, [oldA, oldA, oldA], [q1, q1, q1]),
    (1.0, .25, [oldA, b, b], [q1, green, green]),
    (2.0, .25, [oldA, b, b], [q2, green, green]),
    (2.0, .25, [oldA, oldA, oldA], [q2, q2, q2]),
    (1.0, .25, [oldA, oldA, oldA], [q1, q1, q1]),
    (1.0, .25, [oldA, b, b], [q1, green, green]),
    (1.0, .25, [newA, b, b], [n1, green, green]),
    (2.0, .25, [newA, b, b], [n2, green, green]),
    (2.0, .25, [newA, oldA, oldA], [n2, q1, q1]),
    (2.0, .25, [newA, oldA, f], [n2, q1, orange]),
    (2.0, 1.0, [newA, oldA, f], [blue, q1, orange]),
    (1.0, 1.0, [newA, oldA, f], [purple, q1, orange]),
    (1.0, 1.0, [newA, b, b], [purple, green, green]),
    (1.0, 1.0, [newA, oldA, f], [purple, q1, orange]),
  ];
  if (states.length != expected.length) throw StateError('Wrong state count: ${states.length}');
  var maxError = 0.0;
  for (var i = 0; i < states.length; i++) {
    final s = states[i];
    final e = expected[i];
    if (s['time'] != e.$1 || s['weight'] != e.$2 || jsonEncode(s['ids']) != jsonEncode(e.$3)) {
      throw StateError('Owner/time/weight mismatch at state $i: $s');
    }
    final factors = s['factors']! as List<List<double>>;
    for (var card = 0; card < 3; card++) {
      for (var c = 0; c < 4; c++) {
        final error = (factors[card][c] - e.$4[card][c]).abs();
        if (error > maxError) maxError = error;
        if (error > 0.000001) throw StateError('Factor mismatch at $i/$card/$c');
      }
    }
  }
  final result = {'states': states.length, 'materialObjects': {'oldA': oldA, 'B': b, 'newA': newA, 'F': f}, 'factorTolerance': 0.000001, 'maximumFactorError': maxError, 'pass': true, 'observed': states};
  File('${args[0]}/observed-proof.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  print('PASS: ${states.length} states, four material objects, maximum factor error $maxError');
}
