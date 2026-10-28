import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
void main(){
 const p='/private/tmp/dart3d-u3-outline-view-probe-20261028/r1/parent';
 final config=File('dart3d/example/ios/DartNative/Generated.xcconfig').readAsLinesSync();
 final target=config.singleWhere((l)=>l.startsWith('DN_TARGET='));
 final defines=config.where((l)=>l.startsWith('DART_DEFINES=')).expand((l)=>l.substring(13).split(',')).where((l)=>l.isNotEmpty).map((l)=>utf8.decode(base64.decode(l))).where((l)=>l.startsWith('DART3D_U3_OUTLINE')).toList();
 if(target!='DN_TARGET=lib/main.dart'||defines.isNotEmpty)throw StateError('Probe build config remains');
 final code=File('dart3d/example/ios/Pods/Pods.xcodeproj/project.pbxproj').readAsStringSync();
 if(code.contains('SelectionOutlineViewsProbe.swift'))throw StateError('Probe Pod source remains');
 final locks=jsonDecode(File('/private/tmp/dart3d-u3-outline-view-bindings-20261028/r1/review/preservation-receipt.json').readAsStringSync())['sixLocksVerified'] as Map;
 for(final e in locks.entries)if(sha256.convert(File(e.key).readAsBytesSync()).toString()!=e.value)throw StateError('Lock drift ${e.key}');
 File('$p/final-config-receipt.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'normalTarget':target,'probeDefines':defines,'probePodSourceAbsent':true,'sixLocksUnchanged':true}));
 print('Normal main restored; probe absent from Pod sources; six lock/generated files unchanged.');
}
