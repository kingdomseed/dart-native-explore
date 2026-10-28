import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
const p='/private/tmp/dart3d-u3-outline-metal-trace-20261028/r1/parent';
const out='docs/artifacts/e5b-u3-outline-probe/ios-metal-capture-preflight';
String hash(File f)=>sha256.convert(f.readAsBytesSync()).toString();
void copy(String from,String to){File(to).parent.createSync(recursive:true);File(from).copySync(to);}
void main(){
 final prior=jsonDecode(File('$p/initial-all-source.json').readAsStringSync()) as Map;
 for(final e in prior.entries)if(!File(e.key).existsSync()||hash(File(e.key))!=e.value)throw StateError('Prior drift ${e.key}');
 final config=File('dart3d/example/ios/DartNative/Generated.xcconfig').readAsLinesSync();
 final target=config.singleWhere((l)=>l.startsWith('DN_TARGET='));
 final defines=config.where((l)=>l.startsWith('DART_DEFINES=')).expand((l)=>l.substring(13).split(',')).where((l)=>l.isNotEmpty).map((l)=>utf8.decode(base64.decode(l))).where((l)=>l.startsWith('DART3D_U3_OUTLINE')).toList();
 if(target!='DN_TARGET=lib/main.dart'||defines.isNotEmpty)throw StateError('Probe config remains');
 if(File('dart3d/example/ios/Pods/Pods.xcodeproj/project.pbxproj').readAsStringSync().contains('SelectionOutlineViewsProbe.swift'))throw StateError('Probe Pod source remains');
 final locks=jsonDecode(File('/private/tmp/dart3d-u3-outline-view-bindings-20261028/r1/review/preservation-receipt.json').readAsStringSync())['sixLocksVerified'] as Map;
 for(final e in locks.entries)if(hash(File(e.key))!=e.value)throw StateError('Lock drift ${e.key}');
 final finalConfig={'normalTarget':target,'probeDefines':defines,'probePodSourceAbsent':true,'sixLocksUnchanged':true,'allPriorFilesUnchanged':prior.length};
 File('$p/final-config-receipt.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(finalConfig));
 final raw=Directory('$p/baseline/raw').listSync().whereType<File>().singleWhere((f)=>f.path.endsWith('.rgba'));
 final bytes=raw.readAsBytesSync();final colors=<String,int>{};
 for(var i=0;i<bytes.length;i+=4){final c=bytes.sublist(i,i+4).join(',');colors[c]=(colors[c]??0)+1;}
 final events=File('$p/baseline/native-events.log').readAsLinesSync();
 final rawResult={'sha256':hash(raw),'bytes':bytes.length,'colorsBGRA':colors,'dueDraws':events.where((l)=>l.contains('U3OV due ')).length,'highlightBatches':events.where((l)=>l.contains('U3OV public-highlights ')).length,'targetInstallEvents':events.where((l)=>l.contains('U3OV target-technique-install ')).length,'note':'Only initial Off was drawn; Set/Clear and GPU command capture were not run.'};
 File('$p/initial-off.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rawResult));
 for(final f in Directory('$p/baseline').listSync(recursive:true).whereType<File>())copy(f.path,'$out/baseline/${f.path.substring('$p/baseline/'.length)}');
 for(final f in Directory('$p/runtime-source').listSync().whereType<File>())copy(f.path,'$out/runtime-source/${f.uri.pathSegments.last}');
 for(final name in ['gpucapture-man.txt','gpudebug-man.txt','measurement-plan.md','check-capture.dart','export-preflight.dart','restore-receipt.json','restore-main.log','restore-pods.log','final-config-receipt.json','initial-off.json'])copy('$p/$name','$out/$name');
 const worker='/private/tmp/dart3d-u3-outline-activation-investigation-20261028/r1/worker';
 final delivery=jsonDecode(File('$worker/delivery-sha256.json').readAsStringSync()) as Map;
 for(final e in delivery.entries){final f=File('$worker/${e.key}');if(hash(f)!=e.value)throw StateError('Review delivery drift ${e.key}');copy(f.path,'$out/independent-review/${e.key}');}
 copy('$worker/delivery-sha256.json','$out/independent-review/delivery-sha256.json');
 File('$out/local-originals.json').writeAsStringSync(jsonEncode({'path':'$p/native-all.log','sha256':hash(File('$p/native-all.log')),'bytes':File('$p/native-all.log').lengthSync()}));
 print(jsonEncode({'restored':finalConfig,'raw':rawResult,'export':out}));
}
