import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
const out='/private/tmp/dart3d-w34-ios-material-families-20261027/r1/parent';
final pixels=<String,List<int>>{};
List<int> rgba(String p)=>pixels.putIfAbsent(p,(){
 final r=Process.runSync('ffmpeg',['-v','error','-i',p,'-frames:v','1','-f','rawvideo','-pix_fmt','rgba','-'],stdoutEncoding:null);
 if(r.exitCode!=0)throw StateError(r.stderr.toString());return r.stdout as List<int>;
});
Map<String,Object> compare(String p,String q,List<int> rect){
 final a=rgba(out+'/'+p),b=rgba(out+'/'+q);int changed=0,max=0,masks=0;
 for(int y=rect[1];y<rect[1]+rect[3];y++)for(int x=rect[0];x<rect[0]+rect[2];x++){
  final i=(y*402+x)*4;bool differs=false;
  for(int c=0;c<4;c++){final d=(a[i+c]-b[i+c]).abs();if(d>0)differs=true;if(d>max)max=d;}
  if(differs)changed++;
  final am=a[i]!=0||a[i+1]!=0||a[i+2]!=0;
  final bm=b[i]!=0||b[i+1]!=0||b[i+2]!=0;if(am!=bm)masks++;
 }
 return {'left':p,'right':q,'rectangle':rect,'changedPixels':changed,'maxChannelDifference':max,'nonblackMaskDifferences':masks};
}
Map<String,Object> sample(String p,int x,int y){final a=rgba(out+'/'+p);final i=(y*402+x)*4;return{'path':p,'point':[x,y],'rgba':a.sublist(i,i+4)};}
void main(){
 const scene=[0,70,402,580],main=[50,105,310,290],monitor=[160,440,90,55];
 final result={
 'beforeFinalOff':compare('before/00-off.png','final/00-off.png',scene),
 'offReturn':compare('final/00-off.png','final/09-off-return.png',scene),
 'normalInputControl':compare('normal-input-r2/01-normals.png','final/01b-normals-settled.png',scene),
 'normalFailureCorrection':compare('after/01b-normals-settled.png','final/01b-normals-settled.png',main),
 'targetCaptureA':compare('final/05-baseColor.png','final/06-baseColor-after-normal-capture.png',monitor),
 'targetCaptureB':compare('final/23-baseColor-target-off-capture.png','final/24-baseColor-target-normal-capture.png',monitor),
 'wire':compare('final/05-baseColor.png','final/07-baseColor-wire.png',main),
 'wireOccluder':compare('final/05-baseColor.png','final/07-baseColor-wire.png',[230,160,28,60]),
 'factorEdit':compare('final/10-baseColor-a.png','final/11-baseColor-factors-b.png',main),
 'nativeColorEdit':compare('final/11-baseColor-factors-b.png','final/12-baseColor-colors-b.png',main),
 'coverageModes':compare('final/15-baseColor-mask.png','final/16-baseColor-blend.png',[60,120,125,140]),
 'reloadMain':compare('final/17-off-edited.png','final/18-off-edited-reload.png',main),
 'reloadTarget':compare('final/17-off-edited.png','final/18-off-edited-reload.png',monitor),
 'untexturedOffDiagnostic':compare('final/21-baseColor-texture-off-settled.png','final/22-off-texture-off.png',main),
 'absentInputUnlit':compare('final/02-metallic.png','final/03-roughness.png',[110,145,60,75]),
 'samples':[
 sample('final/02-metallic.png',130,170),
 sample('final/03-roughness.png',130,170),
 sample('final/01b-normals-settled.png',130,170),
 sample('final/21-baseColor-texture-off-settled.png',130,170),
 sample('final/22-off-texture-off.png',130,170)
 ],
 };
 File(out+'/pixel-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result)+'\n');
 final hashes={for(final e in Directory(out+'/final').listSync().whereType<File>().where((f)=>f.path.endsWith('.png')))e.uri.pathSegments.last:sha256.convert(e.readAsBytesSync()).toString()};
 File(out+'/final/screenshot-sha256.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(hashes)+'\n');
 stdout.writeln(File(out+'/pixel-analysis.json').readAsStringSync());
}

