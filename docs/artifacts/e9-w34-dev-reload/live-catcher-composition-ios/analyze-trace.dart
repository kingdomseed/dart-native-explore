import 'dart:io';
import 'dart:convert';
const root='/private/tmp/dart3d-w34-ios-live-catcher-composition-20261028/r1/parent';
void main(){
 final rows=<Map<String,Object>>[];
 for(final line in File('$root/native-all.log').readAsLinesSync().where((s)=>s.contains('liveCatcherTrace'))){
 final pid=RegExp(r'Runner\[(\d+):').firstMatch(line)?.group(1);if(pid==null)continue;
 final phase=RegExp(r'phase=([^ ]+)').firstMatch(line)?.group(1)??'';
 final stateAt=line.indexOf('lightingModel=');
 rows.add({'pid':int.parse(pid),'phase':phase,'channel':RegExp(r'channel=([^ ]+)').firstMatch(line)?.group(1)??'','wireframe':RegExp(r'wireframe=([^ ]+)').firstMatch(line)?.group(1)??'','consumer':stateAt<0?'none':'current','compositionState':stateAt<0?'none':line.substring(stateAt),'materialId':RegExp(r'materialId=ObjectIdentifier\(([^)]+)\)').firstMatch(line)?.group(1)??'none','raw':line});
 }
 File('$root/trace-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
 final byPid=<String,Object>{};for(final pid in rows.map((r)=>r['pid']).toSet()){
 final events=rows.where((r)=>r['pid']==pid).toList();
 byPid[pid.toString()]={'events':events.length,'currentConsumers':events.where((r)=>r['consumer']=='current').length,'channels':events.map((r)=>r['channel']).toSet().toList(),'wireframes':events.map((r)=>r['wireframe']).toSet().toList(),'compositionProfiles':events.where((r)=>r['consumer']=='current').map((r)=>r['compositionState']).toSet().toList()};}
 File('$root/trace-summary.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(byPid));print(const JsonEncoder.withIndent('  ').convert(byPid));
}
