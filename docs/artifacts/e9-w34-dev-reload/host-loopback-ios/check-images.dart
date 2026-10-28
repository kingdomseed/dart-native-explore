import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const out='/private/tmp/dart3d-e9-host-reload-probe-20261027/r1';
  const names=['00-red','01-blue','02-dark-blue','03-malformed-retained','04-recovered-red'];
  final images=[for(final n in names) img.decodePng(File('$out/parent-$n.png').readAsBytesSync())!];
  int changed(img.Image a,img.Image b) {
    var count=0;
    for(var y=100;y<700;y++) { for(var x=0;x<402;x++) {
      final p=a.getPixel(x,y),q=b.getPixel(x,y);
      if(p.r!=q.r||p.g!=q.g||p.b!=q.b) count++;
    }}
    return count;
  }
  final samples=<Map<String,Object>>[];
  for(var i=0;i<images.length;i++) {
    final sum=[0.0,0.0,0.0];
    for(var y=340;y<349;y++) { for(var x=180;x<189;x++) {
      final p=images[i].getPixel(x,y);
      sum[0]+=p.r;sum[1]+=p.g;sum[2]+=p.b;
    }}
    samples.add({'file':'parent-${names[i]}.png','meanRgb9x9':sum.map((v)=>v/81).toList(),'changedScenePixelsAgainstInitial':changed(images.first,images[i])});
  }
  final result={'crop':[0,100,402,700],'sample':[180,340,9,9],'samples':samples,'malformedAgainstLastValidChangedPixels':changed(images[2],images[3]),'recoveryAgainstInitialChangedPixels':changed(images[0],images[4]),'scope':'Encoded screenshot observations only, not photometry, alpha or latency.'};
  File('$out/parent-image-comparison.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
