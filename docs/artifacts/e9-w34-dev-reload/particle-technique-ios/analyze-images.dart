import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = args.single;
  final files = Directory(root).listSync().whereType<File>()
      .where((x) => x.path.endsWith('.png')).toList()..sort((a,b) => a.path.compareTo(b.path));
  final images = <String,List<int>>{};
  for (final file in files) {
    final result = await Process.run('ffmpeg', ['-v','error','-i',file.path,
      '-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'], stdoutEncoding: null);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    final rgb = result.stdout as List<int>;
    if (rgb.length != 402*874*3) throw StateError('Unexpected dimensions: ${file.path}');
    images[file.path.split('/').last] = rgb;
  }
  final baseline = images['01-frozen-off.png']!;
  final output = <String,Object>{};
  for (final entry in images.entries) {
    var sceneChanges=0, meshChanges=0, magentaPixels=0;
    for (var y=100; y<720; y++) {
      for (var x=0; x<402; x++) {
        final p=(y*402+x)*3;
        final changed = entry.value[p]!=baseline[p] || entry.value[p+1]!=baseline[p+1] || entry.value[p+2]!=baseline[p+2];
        if (changed) sceneChanges++;
        if (changed && x>=30 && x<170 && y>=295 && y<445) meshChanges++;
        if (entry.value[p]>220 && entry.value[p+1]<50 && entry.value[p+2]>220) magentaPixels++;
      }
    }
    final samples = <String,List<int>>{};
    for (final xy in [[80,360],[270,255],[300,360]]) {
      final p=(xy[1]*402+xy[0])*3;
      samples['${xy[0]},${xy[1]}']=entry.value.sublist(p,p+3);
    }
    output[entry.key]={'sceneChangedPixelsVsFrozen':sceneChanges,
      'meshROIChangedPixels':meshChanges,'sceneMagentaPixelCount':magentaPixels,
      'rgbSamples':samples};
  }
  final constant = images['02-constant.png']!;
  var greenInteriors=0, greenRemaining=0, magentaAtGreen=0, maximumGreenDifference=0;
  for (var y=181; y<559; y++) {
    for (var x=221; x<379; x++) {
      final p=(y*402+x)*3;
      if (!(baseline[p+1]>150 && baseline[p+1]>baseline[p]+25 && baseline[p+1]>baseline[p+2]+15)) continue;
      var interior=true;
      for (var dy=-1;dy<=1;dy++) {
        for (var dx=-1;dx<=1;dx++) {
          final q=((y+dy)*402+x+dx)*3;
          for (var c=0;c<3;c++) {
            if (baseline[p+c]!=baseline[q+c]) interior=false;
          }
        }
      }
      if (!interior) continue;
      greenInteriors++;
      if (constant[p+1]>150 && constant[p+1]>constant[p]+25 && constant[p+1]>constant[p+2]+15) greenRemaining++;
      if (constant[p]>220 && constant[p+1]<50 && constant[p+2]>220) magentaAtGreen++;
      for (var c=0;c<3;c++) {
        final d=(constant[p+c]-baseline[p+c]).abs();
        if (d>maximumGreenDifference) maximumGreenDifference=d;
      }
    }
  }
  final report={'meaning':'Encoded screenshots. Crop excludes status/header/footer. No raw shader calibration.',
    'sceneCropXYWH':[0,100,402,620], 'meshROI':[30,295,140,150], 'images':output,
    'greenParticleInteriorComparison':{'regionXYWH':[220,180,160,380],
      'baselineGreenInteriorPixels':greenInteriors,'remainingGreenInConstant':greenRemaining,
      'magentaInConstantAtThosePixels':magentaAtGreen,'maximumChannelDifference':maximumGreenDifference}};
  File('$root/pixel-analysis.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
