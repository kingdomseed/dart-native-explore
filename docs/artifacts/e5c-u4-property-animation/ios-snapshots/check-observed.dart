import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = args[0];
  final lines = File('$root/observed-states.log').readAsLinesSync();
  final card = r'ObjectIdentifier\((0x[\da-f]+)\):(ordinary|sprite):([\d.,]+):texture=([^: ]+):ObjectIdentifier\((0x[\da-f]+)\)';
  final pattern = RegExp(r'time=([\d.]+) weight=([\d.]+) current=' + card + r' snapshot=' + card);
  final states = lines.map((line) {
    final m = pattern.firstMatch(line)!;
    Map<String, Object> material(int at) => {'id': m[at]!, 'kind': m[at+1]!, 'factor': m[at+2]!.split(',').map(double.parse).toList(), 'textureType': m[at+3]!, 'texture': m[at+4]!};
    return {'time': double.parse(m[1]!), 'weight': double.parse(m[2]!), 'current': material(3), 'snapshot': material(8)};
  }).toList();
  if (states.length != 11) throw StateError('Unexpected state count ${states.length}');
  Map<String, Object> c(int i) => states[i]['current']! as Map<String, Object>;
  Map<String, Object> s(int i) => states[i]['snapshot']! as Map<String, Object>;
  final a0 = c(0)['id'], d0 = s(0)['id'], a1 = c(4)['id'], d1 = s(4)['id'], a2 = c(7)['id'], d2 = s(7)['id'], b = s(9)['id'];
  if ({a0,d0,a1,d1,a2,d2,b}.length != 7) throw StateError('Observed material objects are not distinct');
  final white = c(0)['texture'], t1 = c(3)['texture'], t2 = c(6)['texture'];
  if ({white,t1,t2}.length != 3) throw StateError('Texture identity check failed');
  const red = [1.0,0.0,0.0,1.0], q0 = [1.0,.75,.75,1.0], q1 = [.875,.75,.875,1.0], rest = [1.0,1.0,1.0,1.0];
  const n1 = [.275,.3,.575,1.0], n2 = [.15,.3,.7,1.0], green = [0.0,1.0,0.0,1.0];
  final expected = [
    (0.0,1.0,a0,d0,'ordinary','ordinary',red,rest,white,white),
    (0.0,.25,a0,d0,'ordinary','ordinary',q0,rest,white,white),
    (1.0,.25,a0,d0,'ordinary','ordinary',q1,rest,white,white),
    (1.0,.25,a0,d0,'ordinary','ordinary',q1,rest,t1,white),
    (1.0,.25,a1,d1,'sprite','sprite',n1,n1,white,white),
    (2.0,.25,a1,d1,'sprite','sprite',n2,n1,white,white),
    (2.0,.25,a1,d1,'sprite','sprite',n2,n1,t2,white),
    (2.0,.25,a2,d2,'sprite','sprite',n2,n2,t2,t2),
    (1.0,.25,a2,d2,'sprite','sprite',n1,n2,t2,t2),
    (1.0,.25,a2,b,'sprite','ordinary',n1,green,t2,white),
    (1.0,.25,a2,d2,'sprite','sprite',n1,n2,t2,t2),
  ];
  var maxError = 0.0;
  for (var i=0; i<states.length; i++) {
    final e=expected[i], state=states[i];
    if (state['time'] != e.$1 || state['weight'] != e.$2 || c(i)['id'] != e.$3 || s(i)['id'] != e.$4 || c(i)['kind'] != e.$5 || s(i)['kind'] != e.$6 || c(i)['texture'] != e.$9 || s(i)['texture'] != e.$10) throw StateError('Ownership/clock/texture mismatch at $i');
    for (final (actual, values) in [(c(i),e.$7),(s(i),e.$8)]) {
      final factor=actual['factor']! as List<double>;
      for (var channel=0;channel<4;channel++) {
        final error=(factor[channel]-values[channel]).abs();
        if(error>maxError) maxError=error;
        if(error>1e-6) throw StateError('Factor mismatch $i/$channel');
      }
      final expectedType = actual['texture']==white ? 'UICachedDeviceWhiteColor' : 'MTLSimTexture';
      if(actual['textureType']!=expectedType) throw StateError('Unexpected texture type');
    }
  }
  File('$root/observed-proof.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'pass':true,'states':states.length,'maximumFactorError':maxError,'factorTolerance':1e-6,'materialObjectsObserved':7,'textureObjectsObserved':3,'boundary':'Read-only post-sampler assigned-slot observations. No calibrated pixel color or latency claim. Snapshot texture remains captured until explicit refresh.','observed':states}));
  print('PASS: 11 states, seven observed material objects, three texture objects; max factor error $maxError');
}
