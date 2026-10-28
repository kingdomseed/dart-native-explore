import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
const out='/private/tmp/dart3d-w34-screen-debug-ios-fixes-20261027/r2';
String hash(String p)=>sha256.convert(File(p).readAsBytesSync()).toString();
void json(String p,Object v)=>File(p).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(v)+'\n');
final pixels=<String,List<int>>{};
List<int> rgba(String p)=>pixels.putIfAbsent(p,(){
 final r=Process.runSync('ffmpeg',['-v','error','-i',p,'-frames:v','1','-f','rawvideo','-pix_fmt','rgba','-'],stdoutEncoding:null);
 if(r.exitCode!=0)throw StateError(r.stderr.toString());
 return r.stdout as List<int>;
});
Map<String,Object> stats(String p,List<int> rect){
 final a=rgba(p);int nonblack=0;
 for(int y=rect[1];y<rect[1]+rect[3];y++)for(int x=rect[0];x<rect[0]+rect[2];x++){
  final i=(y*402+x)*4;if(a[i]!=0||a[i+1]!=0||a[i+2]!=0)nonblack++;
 }
 return {'path':p,'sha256':hash(p),'rectangle':rect,'nonblackPixels':nonblack};
}
Map<String,Object> compare(String p,String q,List<int> rect){
 final a=rgba(p),b=rgba(q);int changed=0,max=0;
 for(int y=rect[1];y<rect[1]+rect[3];y++)for(int x=rect[0];x<rect[0]+rect[2];x++){
  final i=(y*402+x)*4;bool differs=false;
  for(int c=0;c<4;c++){final d=(a[i+c]-b[i+c]).abs();if(d>0)differs=true;if(d>max)max=d;}
  if(differs)changed++;
 }
 return {'left':p,'right':q,'rectangle':rect,'changedPixels':changed,'maxChannelDifference':max};
}
void main(){
 const after=out+'/after-viewport';
 json(out+'/pixel-analysis.json',{
 'beforeGap':stats(out+'/before-viewport/06-diagnostic-inset.png',[140,75,175,230]),
 'afterGap':stats(after+'/02-normals-inset.png',[140,75,175,230]),
 'afterOtherOrderGap':stats(after+'/04-normals-inset-from-off.png',[140,75,175,230]),
 'orders':compare(after+'/02-normals-inset.png',after+'/04-normals-inset-from-off.png',[0,70,402,580]),
 'offViewportReturn':compare(after+'/00-off-full.png',after+'/05-off-full-return.png',[0,70,402,580]),
 'offRigReturn':compare(after+'/00-off-full.png',after+'/09-off-rest-return.png',[0,70,402,580]),
 'posedOff':compare(after+'/08-restored-raised-off.png',after+'/09-off-rest-return.png',[0,70,402,580]),
 });
 final videos=<String,Object>{};
 for(final p in ['before-viewport/inset.mp4','before-skin/crash.mp4','after-skin/detached-restored.mp4','after-viewport/viewport-and-rig.mp4']){
  final path=out+'/'+p;
  final log=File(path+'.decode.log').readAsStringSync();
  videos[p]={'sha256':hash(path),'bytes':File(path).lengthSync(),'decodeExitCode':0,'decodeLog':path+'.decode.log','warnings':log.isNotEmpty,'timingClaim':false,
   'info':jsonDecode(File(path+'.info.json').readAsStringSync())};
 }
 json(out+'/video-receipts.json',videos);
 stdout.writeln(File(out+'/pixel-analysis.json').readAsStringSync());
}

