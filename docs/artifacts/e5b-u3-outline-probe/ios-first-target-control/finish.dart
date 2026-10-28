import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
const p='/private/tmp/dart3d-u3-outline-first-target-control-20261028/r1/parent';
const out='docs/artifacts/e5b-u3-outline-probe/ios-first-target-control';
String hash(File f)=>sha256.convert(f.readAsBytesSync()).toString();
void copy(String source,String target){File(target).parent.createSync(recursive:true);File(source).copySync(target);}
void main(){
 final config=File('dart3d/example/ios/DartNative/Generated.xcconfig').readAsLinesSync();
 final target=config.singleWhere((l)=>l.startsWith('DN_TARGET='));
 final defines=config.where((l)=>l.startsWith('DART_DEFINES=')).expand((l)=>l.substring(13).split(',')).where((l)=>l.isNotEmpty).map((l)=>utf8.decode(base64.decode(l))).where((l)=>l.startsWith('DART3D_U3_OUTLINE')).toList();
 if(target!='DN_TARGET=lib/main.dart'||defines.isNotEmpty)throw StateError('Probe config remains');
 if(File('dart3d/example/ios/Pods/Pods.xcodeproj/project.pbxproj').readAsStringSync().contains('SelectionOutlineViewsProbe.swift'))throw StateError('Probe Pod source remains');
 final locks=jsonDecode(File('/private/tmp/dart3d-u3-outline-view-bindings-20261028/r1/review/preservation-receipt.json').readAsStringSync())['sixLocksVerified'] as Map;
 for(final e in locks.entries)if(hash(File(e.key))!=e.value)throw StateError('Lock drift ${e.key}');
 final prior=jsonDecode(File('$p/initial-all-source.json').readAsStringSync()) as Map;
 for(final e in prior.entries)if(!File(e.key).existsSync()||hash(File(e.key))!=e.value)throw StateError('Prior drift ${e.key}');
 File('$p/final-config-receipt.json').writeAsStringSync(jsonEncode({'normalTarget':target,'probeDefines':defines,'probePodSourceAbsent':true,'sixLocksUnchanged':true,'priorFilesUnchanged':prior.length,'simulatorShutdownConfirmedByDeviceList':true,'loggerSessionExited':true}));
 final comparisons=<Map<String,Object>>[];
 for(final name in ['00-off','01-outline-empty','02-set-held','03-set-render','04-clear-held','05-clear-render','06-set-held','07-set-render','08-clear-held','09-clear-render','10-off-return']){
  final a=img.decodePng(File('$p/baseline/$name.png').readAsBytesSync())!,b=img.decodePng(File('$p/control/$name.png').readAsBytesSync())!;
  if(a.width!=402||b.width!=402||a.height!=874||b.height!=874)throw StateError('Unexpected image size');
  var changed=0,maxDifference=0;
  for(var y=70;y<670;y++)for(var x=0;x<402;x++){final aa=a.getPixel(x,y),bb=b.getPixel(x,y);var d=0;for(var c=0;c<3;c++){final v=(aa[c]-bb[c]).abs().toInt();if(v>d)d=v;}if(d>0)changed++;if(d>maxDifference)maxDifference=d;}
  comparisons.add({'pair':name,'crop':[0,70,402,600],'changedRGBPixels':changed,'maxRGBDifference':maxDifference});
 }
 File('$p/pixel-comparisons.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(comparisons));
 for(final stage in ['baseline','control']){for(final f in Directory('$p/$stage').listSync(recursive:true).whereType<File>()){if(f.path.endsWith('journey.mp4'))continue;copy(f.path,'$out/$stage/${f.path.substring('$p/$stage/'.length)}');}}
 for(final f in Directory('$p/runtime-source').listSync().whereType<File>())copy(f.path,'$out/runtime-source/${f.uri.pathSegments.last}');
 for(final name in ['analyze.dart','first-use.dart','raw-utils.dart','pixel-comparisons.json','fixture-tests.log','restore-receipt.json','final-config-receipt.json','restore-main.log','restore-pods.log','finish.dart'])copy('$p/$name','$out/$name');
 const worker='/private/tmp/dart3d-u3-outline-first-target-diagnosis-20261028/r1/worker';
 for(final name in ['report.md','control-only.patch','verification.md','preservation-receipt.json','replay-receipt.json','delivery-sha256.json'])copy('$worker/$name','$out/worker/$name');
 final originals=[for(final name in ['native-all.log','baseline/journey.mp4','control/journey.mp4']){'path':'$p/$name','sha256':hash(File('$p/$name')),'bytes':File('$p/$name').lengthSync()}];
 File('$out/local-originals.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(originals));
 print(jsonEncode({'export':out,'comparisons':comparisons,'configRestored':true,'sixLocksUnchanged':true,'priorFilesUnchanged':prior.length}));
}
