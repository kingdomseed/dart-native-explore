import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
void main(){
 const p='/private/tmp/dart3d-u3-outline-view-probe-20261028/r1/parent';
 const w='/private/tmp/dart3d-u3-outline-view-probe-20261028/r1/worker';
 String hash(File f)=>sha256.convert(f.readAsBytesSync()).toString();
 final runtime=jsonDecode(File('$p/split/packet/source-sha256.json').readAsStringSync()) as Map<String,dynamic>;
 for(final e in runtime.entries)if(hash(File(e.key))!=e.value)throw StateError('Runtime source drift ${e.key}');
 final baseline=jsonDecode(File('$w/baseline66-source-sha256.json').readAsStringSync()) as Map<String,dynamic>;
 final changed=baseline.keys.where((k)=>runtime[k]!=baseline[k]).toList()..sort();
 final added=runtime.keys.where((k)=>!baseline.containsKey(k)).toList()..sort();
 if(changed.length!=4||added.length!=4)throw StateError('Unexpected probe fence');
 final tmp=Directory.systemTemp.createTempSync('u3-restore-baseline-');
 try{
  final r=Process.runSync('tar',['-xzf','$w/baseline66-source.tgz','-C',tmp.path,...changed]);
  if(r.exitCode!=0)throw StateError(r.stderr.toString());
  for(final f in changed)File('${tmp.path}/$f').copySync(f);
  for(final f in added)File(f).deleteSync();
 }finally{tmp.deleteSync(recursive:true);}
 for(final e in baseline.entries)if(hash(File(e.key))!=e.value)throw StateError('Restore failed ${e.key}');
 final initial=jsonDecode(File('$p/initial-all-source.json').readAsStringSync()) as Map<String,dynamic>;
 for(final e in initial.entries)if(!File(e.key).existsSync()||hash(File(e.key))!=e.value)throw StateError('Prior file not preserved ${e.key}');
 File('$p/restore-receipt.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'accepted66Restored':true,'allPreexistingFilesRestored':initial.length,'restoredNativePaths':changed,'removedOwnProbePaths':added,'runtimePacketRetained':'split/packet/source.tgz','scratchRemoved':true}));
 print('Restored accepted66 and all ${initial.length} pre-existing files; removed only4 own probe additions after preserving the runtime packet.');
}
