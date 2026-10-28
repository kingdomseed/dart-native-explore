import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

const root = '/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent';
img.Image read(String path) => img.decodePng(File('$root/$path').readAsBytesSync())!;
Map<String, Object> compare(String left, String right, {bool expectedStable = true, List<int> crop = const [0, 70, 402, 570]}) {
  final a = read(left), b = read(right);
  if (a.width != 402 || a.height != 874 || b.width != 402 || b.height != 874) throw StateError('Unexpected image dimensions');
  var changed = 0, maximum = 0;
  for (var y = crop[1]; y < crop[1] + crop[3]; y++) {
    for (var x = crop[0]; x < crop[0] + crop[2]; x++) {
      var difference = 0;
      final p = a.getPixel(x, y), q = b.getPixel(x, y);
      for (var c = 0; c < 3; c++) {
        final d = (p[c] - q[c]).abs().toInt();
        if (d > difference) difference = d;
      }
      if (difference > 0) changed++;
      if (difference > maximum) maximum = difference;
    }
  }
  return {'left': left, 'right': right, 'crop': crop, 'expectedStable': expectedStable, 'changedPixels': changed, 'maxRGBDifference': maximum};
}

void main() {
  final comparisons = <Map<String, Object>>[];
  final samples = <String, Object>{};
  for (final stage in ['before', 'traced', 'clean', 'no-light-control']) {
    final files = Directory('$root/$stage').listSync().whereType<File>().where((f) => RegExp(r'/\d\d-[^/]+\.png$').hasMatch(f.path)).toList()..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final image = read('$stage/$name');
      final selected = <String, List<int>>{};
      for (final (x, y) in [(100, 350), (300, 370), (335, 365), (200, 250)]) {
        final p = image.getPixel(x, y);
        selected['$x,$y'] = [p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt()];
      }
      samples['$stage/$name'] = selected;
      if (stage == 'before') comparisons.add(compare('before/$name', 'clean/$name', expectedStable: name.startsWith('00-') || name.startsWith('06-') || name.startsWith('07-')));
      if (stage == 'traced') comparisons.add(compare('traced/$name', 'clean/$name', expectedStable: !name.startsWith('23-') && !name.startsWith('24-')));
    }
  }
  for (final name in ['03-off-absent-return.png', '04-off-absent-replace.png', '05-off-absent-reload.png']) comparisons.add(compare('no-light-control/01-off-absent.png', 'no-light-control/$name'));
  for (final name in ['06-off-restored.png', '08-off-restored-return.png']) comparisons.add(compare('no-light-control/00-off-present.png', 'no-light-control/$name'));
  comparisons.add(compare('clean/29-light-absent.png', 'no-light-control/02-normals-absent.png'));
  comparisons.add(compare('clean/00-off-A.png', 'no-light-control/00-off-present.png'));
  for (final stage in ['traced', 'clean']) {
    for (final name in ['07-off-A-return.png', '15-off.png', '34-off-new-A.png', '35-off-reload-new-A.png', '43-off-final.png']) comparisons.add(compare('$stage/00-off-A.png', '$stage/$name'));
    comparisons.add(compare('$stage/03-baseColor-A.png', '$stage/04-baseColor-B.png', expectedStable: false));
    comparisons.add(compare('$stage/16-normals-A.png', '$stage/17-light-B.png', expectedStable: false));
    comparisons.add(compare('$stage/16-normals-A.png', '$stage/18-light-A-return.png'));
  }
  final regression = Directory('$root/pbr-regression');
  if (regression.existsSync()) {
    const prior = '/private/tmp/dart3d-w34-ios-channel-transitions-20261028/r1/parent/clean';
    for (final file in regression.listSync().whereType<File>().where((f) => RegExp(r'/\d\d-[^/]+\.png$').hasMatch(f.path))) {
      final name = file.uri.pathSegments.last;
      File('$prior/$name').copySync('$root/pbr-regression/old-$name');
      comparisons.add(compare('pbr-regression/old-$name', 'pbr-regression/$name', crop: const [0, 70, 402, 580]));
    }
  }
  File('$root/pixel-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'comparisons': comparisons, 'samples': samples}));
  final stable = comparisons.where((c) => c['expectedStable'] == true).toList();
  final changed = stable.where((c) => c['changedPixels'] != 0).toList();
  print(jsonEncode({'comparisons': comparisons.length, 'sampledImages': samples.length, 'stableComparisons': stable.length, 'nonzeroStableComparisons': changed}));
}
