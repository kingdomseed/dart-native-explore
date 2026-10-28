import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root=args[0];
  final grouped=<String,List<Map<String,String>>>{};
  final raw=<String>[];
  for(final line in File('$root/native-observed.log').readAsLinesSync()) {
    final at=line.indexOf('u4 lights observed ');
    if(at<0) continue;
    raw.add(line);
    final pid=RegExp(r'Runner\[(\d+):').firstMatch(line)![1]!;
    final values={for(final m in RegExp(r'(\w+)=([^ ]+)').allMatches(line.substring(at))) m[1]!:m[2]!};
    grouped.putIfAbsent(pid,()=>[]).add(values);
  }
  if(grouped.length!=3) throw StateError('Expected three native process lanes');
  const times=[0.0,1.0,2.0,2.0,1.0,1.0,2.0,2.0,2.0,1.0];
  const weights=[1.0,1.0,1.0,.25,.25,.25,.25,.25,.25,.25];
  const rests=[1.0,1.0,1.0,1.0,1.0,3.0,3.0,-1.0,1.0,1.0];
  const effects=[2.0,4.0,6.0,2.25,1.75,3.25,3.75,-1.0,2.25,1.75];
  final result=<String,Object>{};
  var maxError=0.0;
  for(final entry in grouped.entries) {
    final states=entry.value;
    if(states.length!=10) throw StateError('Wrong observation count for ${entry.key}: ${states.length}');
    final type=states.first['type']!;
    final lane={'omni':'point','spot':'spot','area':'area'}[type]!;
    final scale=type=='area'?1000.0:1.0;
    for(var i=0;i<states.length;i++) {
      final s=states[i];
      if(double.parse(s['time']!)!=times[i]||double.parse(s['weight']!)!=weights[i]||s['playing']!='false'||s['clips']!='1') throw StateError('Clock mismatch $lane/$i');
      final removed=i==7;
      if(s['count']!=(removed?'0':'1')||s['same']!=(removed?'false':'true')||s['type']!=(removed?'nil':type)) throw StateError('Assigned owner mismatch $lane/$i');
      if(removed&&(s['light']!='nil'||s['owner']!='nil'||s['extents']!='nil')) throw StateError('Removed owner remains $lane');
      for(final (key,expected) in [('rest',rests[i]),('effective',effects[i]),('native',removed?-1.0:effects[i]*scale)]) {
        final error=(double.parse(s[key]!)-expected).abs();
        if(error>maxError)maxError=error;
        if(error>1e-6)throw StateError('Value mismatch $lane/$i/$key');
      }
      if(!removed&&type=='area') {
        final expected=(i==5||i==6)?[3.0,2.0,0.0]:[2.0,1.0,0.0];
        final actual=s['extents']!.split(',').map(double.parse).toList();
        if(jsonEncode(actual)!=jsonEncode(expected))throw StateError('Area extents mismatch $i');
      }
    }
    for(final span in [[0,4],[5,6],[8,9]]) {
      for(var i=span[0];i<=span[1];i++) {
        for(final key in ['owner','light']) {
          if(states[i][key]!=states[span[0]][key])throw StateError('Unrequested identity change $lane/$i/$key');
        }
      }
    }
    result[lane]={'pid':entry.key,'pass':true,'states':states,'boundary':'Object identifiers are scoped to live lifetimes; a historical address can recur after the nil removal interval.'};
  }
  File('$root/observed-states.log').writeAsStringSync('${raw.join('\n')}\n');
  File('$root/observed-proof.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'pass':true,'lanes':result,'observations':raw.length,'maximumNumericError':maxError,'tolerance':1e-6,'boundary':'Actual assigned SCNLight and owner fields after sampling. No calibrated photometry, frame timing or Android claim.'}));
  print('PASS: three lanes, ${raw.length} states, actual owners/values/dimensions/clock; max error $maxError');
}
