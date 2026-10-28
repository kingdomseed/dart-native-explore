import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final directory = Directory(args.single);
  final output = <String, Object>{};
  for (final bake in ['bake001-load', 'bake002-refresh']) {
    final files = directory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.rgba') &&
          file.uri.pathSegments.last.startsWith(bake),
    ).toList();
    final raw = files.singleWhere((file) => file.path.contains('-raw-light-'))
        .readAsBytesSync();
    final aggregate = files.singleWhere(
      (file) => file.uri.pathSegments.last == '$bake-aggregate.rgba',
    ).readAsBytesSync();
    var changed = 0;
    var maxDelta = 0;
    for (var index = 0; index < raw.length; index += 4) {
      final delta = (raw[index] - aggregate[index]).abs();
      if (delta != 0) changed++;
      if (delta > maxDelta) maxDelta = delta;
    }
    final statistics = <String, Object>{};
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      var minimum = 255;
      var maximum = 0;
      var zero = 0;
      var sum = 0;
      for (var index = 0; index < bytes.length; index += 4) {
        final value = bytes[index];
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
        if (value == 0) zero++;
        sum += value;
      }
      statistics[file.uri.pathSegments.last] = {
        'bytes': bytes.length,
        'R_min': minimum,
        'R_max': maximum,
        'R_zero_pixels': zero,
        'R_mean_byte': sum / (bytes.length ~/ 4),
      };
    }
    output[bake] = {
      'raw_vs_aggregate_R_changed_pixels': changed,
      'raw_vs_aggregate_R_max_delta': maxDelta,
      'stages': statistics,
    };
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
}
