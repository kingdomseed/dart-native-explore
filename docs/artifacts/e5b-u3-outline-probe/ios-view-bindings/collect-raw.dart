import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
void main() {
 const root='/private/tmp/dart3d-u3-outline-view-probe-20261028/r1/parent';
 final lines=File('$root/native-all.log').readAsLinesSync();
 final paths=<String>{};
 for(final l in lines) {
  final m=RegExp(r'U3OV RAW file=(.+\.rgba) schema=(.+\.json)$').firstMatch(l);
  if(m!=null){paths.add(m.group(1)!);paths.add(m.group(2)!);}
 }
 final out=Directory('$root/raw')..createSync();
 final result=<Map<String,Object>>[];
 for(final p in paths.toList()..sort()) {
  if(!p.contains('/tmp/u3-outline-'))throw StateError('Unexpected native output path');
  final f=File(p);
  if(!f.existsSync())throw StateError('Reported native file missing $p');
  final target='${out.path}/${f.uri.pathSegments.last}';
  f.copySync(target);
  result.add({'nativePath':p,'copiedPath':target,'bytes':f.lengthSync(),'sha256':sha256.convert(f.readAsBytesSync()).toString()});
 }
 File('$root/raw-files.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
 print('Copied ${result.length} logged native outputs via exact host paths; no simulator container query.');
}
