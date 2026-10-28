import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final picture = img.decodePng(File(args[0]).readAsBytesSync())!;
  final boxes = (jsonDecode(File(args[1]).readAsStringSync()) as Map)
      .cast<String, List<dynamic>>();
  final result = <String, Object>{
    'image': args[0],
    'width': picture.width,
    'height': picture.height,
    'interpretation': 'Encoded PNG channels; no GPU readback or calibration.',
    'regions': <String, Object>{},
  };
  for (final entry in boxes.entries) {
    final [x, y, width, height] = entry.value.cast<int>();
    final sums = List<double>.filled(4, 0);
    final squares = List<double>.filled(4, 0);
    for (var py = y; py < y + height; py++) {
      for (var px = x; px < x + width; px++) {
        final pixel = picture.getPixel(px, py);
        final values = [pixel.r, pixel.g, pixel.b, pixel.a];
        for (var channel = 0; channel < 4; channel++) {
          final value = values[channel].toDouble();
          sums[channel] += value;
          squares[channel] += value * value;
        }
      }
    }
    final count = width * height;
    final mean = sums.map((value) => value / count).toList();
    final deviation = [
      for (var channel = 0; channel < 4; channel++)
        math.sqrt(math.max(0, squares[channel] / count -
            mean[channel] * mean[channel])),
    ];
    (result['regions'] as Map<String, Object>)[entry.key] = {
      'box': entry.value,
      'meanRgba': mean,
      'standardDeviation': deviation,
    };
  }
  File(args[2]).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result)}\n',
  );
  stdout.writeln('Measured ${boxes.length} PNG regions.');
}
