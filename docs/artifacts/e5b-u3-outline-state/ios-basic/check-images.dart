import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  final files = Directory(args[0]).listSync().whereType<File>().where((f) => RegExp(r'parent-0[0-7]-.*\.png$').hasMatch(f.path)).toList()..sort((a,b) => a.path.compareTo(b.path));
  final initial = img.decodePng(files.first.readAsBytesSync())!;
  final records = <Map<String, Object>>[];
  for (final file in files) {
    final picture = img.decodePng(file.readAsBytesSync())!;
    var colored = 0;
    var changed = 0;
    for (var y = 100; y < 650; y++) {
      for (var x = 0; x < picture.width; x++) {
        final p = picture.getPixel(x,y);
        final q = initial.getPixel(x,y);
        if (p.b > 120 && p.g > 100 && p.b > p.r + 10) colored++;
        if (p.r != q.r || p.g != q.g || p.b != q.b) changed++;
      }
    }
    records.add({'file': file.uri.pathSegments.last, 'width':picture.width, 'height':picture.height, 'blueObjectPixels':colored, 'changedSceneRgbPixelsAgainstReady':changed});
  }
  final result = {'crop':[0,100,402,650], 'records':records, 'scope':'Uncalibrated encoded screenshot inventory and unchanged RGB only. No outline rendering claim.'};
  File('${args[0]}/parent-image-comparison.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
