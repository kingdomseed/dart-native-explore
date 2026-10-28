import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  final phase = args[0];
  final samples = jsonDecode(File(args[1]).readAsStringSync()) as Map;
  const background = [0.08, 0.12, 0.16];
  final additive = phase.contains('additive');
  final tinted = phase.contains('tinted');
  final untextured = phase.contains('untextured');
  List<double> over(List<double> color, double alpha,
      {List<double> destination = background, bool add = false}) => [
    for (var c = 0; c < 3; c++)
      color[c] * alpha + destination[c] * (add ? 1 : 1 - alpha),
  ];
  int encoded(double v) {
    final x = v.clamp(0.0, 1.0);
    return ((x <= 0.0031308 ? x * 12.92 :
        1.055 * math.pow(x, 1 / 2.4) - 0.055) * 255).round();
  }
  final color = untextured
      ? (tinted ? [0.32, 0.42, 0.36] : [1.0, 1.0, 1.0])
      : (tinted ? [0.32, 0.0, 0.0] : [1.0, 0.0, 0.0]);
  final factorAlpha = tinted ? 0.25 : 1.0;
  final back = over([0.6, 0.1, 0.2], 0.5);
  final front = over([0.1, 0.5, 0.3], 0.5);
  final expected = {
    'backdrop': background,
    'selectedZeroAlpha': over(color,
        (untextured ? 1 : 0) * factorAlpha, add: additive),
    'selectedHalfAlpha': over(color,
        (untextured ? 1 : 128 / 255) * factorAlpha, add: additive),
    'selectedOpaque': over(color, factorAlpha, add: additive),
    'untexturedHalfAlpha': over([0.2, 0.6, 0.9], 0.5),
    'overlapBackOnly': back,
    'overlapFrontOnly': front,
    'overlapBoth': phase.contains('crossed')
        ? over([0.6, 0.1, 0.2], 0.5, destination: front)
        : over([0.1, 0.5, 0.3], 0.5, destination: back),
  };
  final comparisons = <String, Object>{};
  var maximum = 0.0;
  for (final entry in expected.entries) {
    final observed = ((samples['regions'] as Map)[entry.key]['meanRgba']
        as List).take(3).cast<num>().toList();
    final target = entry.value.map(encoded).toList();
    final errors = [for (var c = 0; c < 3; c++)
        (observed[c] - target[c]).abs()];
    maximum = math.max(maximum, errors.reduce(math.max).toDouble());
    comparisons[entry.key] = {
      'observedRgb': observed, 'expectedRgb': target, 'absoluteError': errors,
    };
  }
  final result = {
    'phase': phase,
    'equation': additive ? 'C * a + B' : 'C * a + B * (1 - a)',
    'encoding': 'sRGB transfer applied to linear model values',
    'tolerance': 3,
    'maximumEncodedChannelError': maximum,
    'withinTolerance': maximum <= 3,
    'coverageAlpha': 'NOT_MEASURED: opaque screenshots cannot establish coverage',
    'regions': comparisons,
  };
  File(args[2]).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result)}\n',
  );
  stdout.writeln('$phase maximum error $maximum; within tolerance ${maximum <= 3}');
}
