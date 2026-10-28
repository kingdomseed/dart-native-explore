import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  const root='/private/tmp/dart3d-e9-host-reload-probe-20261027/r1';
  final phase=args.single;
  final source=File('$root/parent-authored.fscene');
  final original=File('$root/parent-authored-initial.fscene').readAsStringSync();
  final String text;
  if(phase=='baseline') {
    text=original;
  } else if(phase=='malformed') {
    text='{';
  } else {
    final doc=jsonDecode(source.readAsStringSync()) as Map<String,dynamic>;
    final resources=doc['resources'] as Map<String,dynamic>;
    if(phase=='material') {
      resources['mat:01VK6D0000000']['properties']['baseColor']['c']=[0.03,0.08,0.7,1.0];
    } else if(phase=='environment') {
      resources['env:01VK6D000000A']['exposure']=0.2;
    } else { throw ArgumentError('Unknown phase $phase'); }
    text=const JsonEncoder.withIndent('  ').convert(doc);
  }
  source.writeAsStringSync(text,flush:true);
  File('$root/parent-authored-$phase.fscene').writeAsStringSync(text);
  stdout.writeln('host save=$phase time=${DateTime.now().toUtc().toIso8601String()} strategy=in-place chars=${text.length}');
}
