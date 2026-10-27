import 'dart:io';

import 'package:image/image.dart' as image;

void main(List<String> args) {
  for (final file in Directory(args.single).listSync().whereType<File>()) {
    if (!file.path.endsWith('.rgba')) continue;
    final stem = file.path.substring(0, file.path.length - 5);
    final metadata = File('$stem.txt').readAsStringSync();
    final size = int.parse(
      RegExp(r'width=(\d+)').firstMatch(metadata)!.group(1)!,
    );
    final bytes = file.readAsBytesSync();
    if (bytes.length != size * size * 4)
      throw StateError('Wrong byte count ${file.path}');
    for (final channel in [0, 3]) {
      final output = image.Image(width: size, height: size);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final value = bytes[(y * size + x) * 4 + channel];
          output.setPixelRgb(x, y, value, value, value);
        }
      }
      final name = '$stem-${channel == 0 ? "R" : "A"}.png';
      File(name).writeAsBytesSync(image.encodePng(output));
      print(name);
    }
  }
}
