import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  for (final path in args) {
    final bytes = File(path).readAsBytesSync();
    final view = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));
    final version = view.getUint32(4, Endian.little);
    final total = view.getUint32(8, Endian.little);
    print('${path.split('/').last}: magic=$magic v=$version total=$total file=${bytes.length}');
    var offset = 16;
    while (offset + 8 <= total) {
      final len = view.getUint32(offset, Endian.little);
      final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
      print('  $type  $len bytes @ $offset');
      offset += 8 + len + ((-len) & 7);
    }
  }
}
