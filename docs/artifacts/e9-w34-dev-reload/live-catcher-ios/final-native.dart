import 'dart:convert';
import 'dart:io';
void main() {
 const p='/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent';
 final lines=File('$p/blend-before/native-all.log').readAsLinesSync();
 final selected=lines.where((l)=>l.contains('debugView channel=')).toList();
 final pids=selected.map((l)=>RegExp(r'Runner\[(\d+):').firstMatch(l)!.group(1)!).toSet().toList();
 if(pids.length!=4)throw StateError('Unexpected PID sequence $pids');
 const stages=['blend-before','blend-after','final-clean','final-pbr'];
 final output=<String,Object>{};
 for(var i=0;i<4;i++) {
  final rows=lines.where((l)=>l.contains('Runner[${pids[i]}:')).toList();
  final events=rows.where((l)=>l.contains('com.jasonholtdigital.dart3d:scene')).toList();
  final errors=rows.where((l)=>RegExp(r'fatal|shader.*error|Cannot modify|cross.scene mutation|SCNTransaction|unrecognized selector|UI API called',caseSensitive:false).hasMatch(l)).toList();
  File('$p/${stages[i]}/native-events.log').writeAsStringSync(events.join('\n')+'\n');
  File('$p/${stages[i]}/error-query.log').writeAsStringSync(errors.join('\n'));
  output[stages[i]]={'pid':pids[i],'nativeRowCount':rows.length,'eventRows':events.length,'errorMatches':errors.length,'sampledCopyCount':null,'templateCreateCount':null,'displayCreateCount':null};
 }
 File('$p/final-native-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'stages':output,'loggerExit':137,'loggerEnd':'Simulator shutdown ended the logger; earlier app runs quit normally.'}));
 print(jsonEncode(output));
}
