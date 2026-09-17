import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  final bytes = File(args.single).readAsBytesSync();
  final view = ByteData.sublistView(bytes);
  final len = view.getUint32(16, Endian.little);
  final manifest = utf8.decode(bytes.sublist(24, 24 + len));
  final json = jsonDecode(manifest) as Map;
  print(const JsonEncoder.withIndent('  ').convert({
    'fscene': json['fscene'],
    'stage': json['stage'],
    'nodes': json['nodes'],
    'roots': json['roots'],
  }));
}
