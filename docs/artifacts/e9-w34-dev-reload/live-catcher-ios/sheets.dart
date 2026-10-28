import 'dart:io';
import 'package:image/image.dart' as img;
void main() {
 const p='/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent';
 for(final stage in ['blend-after','final-clean','final-pbr']) {
  final files=Directory('$p/$stage').listSync().whereType<File>().where((f)=>RegExp(r'/\d\d-[^/]+\.png$').hasMatch(f.path)).toList()..sort((a,b)=>a.path.compareTo(b.path));
  final sheet=img.Image(width:804,height:((files.length+3)~/4)*308);
  img.fill(sheet,color:img.ColorRgb8(255,255,255));
  for(var i=0;i<files.length;i++) {
   final decoded=img.decodePng(files[i].readAsBytesSync())!;
   final thumb=img.copyResize(decoded,width:201,height:285);
   img.compositeImage(sheet,thumb,dstX:(i%4)*201,dstY:(i~/4)*308+23);
   img.drawString(sheet,files[i].uri.pathSegments.last,font:img.arial14,x:(i%4)*201+2,y:(i~/4)*308+4,color:img.ColorRgb8(0,0,0));
  }
  File('$p/$stage/contact-sheet.png').writeAsBytesSync(img.encodePng(sheet));
 }
}
