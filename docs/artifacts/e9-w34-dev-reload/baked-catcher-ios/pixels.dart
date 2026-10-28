import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
const root='/private/tmp/dart3d-w34-ios-baked-catcher-20261028/r1/parent';
Uint8List decode(String path) {
 final result=Process.runSync('ffmpeg',['-v','error','-i','$root/$path','-f','rawvideo','-pix_fmt','rgba','pipe:1'],stdoutEncoding:null);
 if(result.exitCode!=0) throw StateError(result.stderr.toString());
 final data=result.stdout as Uint8List;
 if(data.length!=402*874*4) throw StateError('unexpected image $path ${data.length}');
 return data;
}
void main() {
 final images=<String,Uint8List>{};
 Uint8List load(String p)=>images.putIfAbsent(p,()=>decode(p));
 final pairs=[
 ['before/00-off.png','after/00-off.png','authored-before-after',0,70,402,580],
 ['after/00-off.png','after/08-off-restored.png','off-after-wire',0,70,402,580],
 ['after/09-normals-A.png','after/10-normals-B-stale.png','frozen-A-under-moved-caster',100,405,290,45],
 ['after/10-normals-B-stale.png','after/11-normals-B-refresh.png','explicit-refresh-A-to-B',100,405,290,45],
 ['after/16-off-B.png','after/19-off-B-reload.png','off-current-B-after-reload',0,70,402,580],
 ['after/17-normals-B.png','after/18-normals-B-reload.png','selected-normals-after-reload',0,70,402,580],
 ['after/20-depth-B.png','after/21-depth-A-stale.png','frozen-B-under-returned-caster',100,405,290,45],
 ['after/21-depth-A-stale.png','after/22-depth-A-refresh.png','explicit-refresh-B-to-A',100,405,290,45],
 ['after/00-off.png','after/23-off-A-final.png','off-current-A-final',0,70,402,580],
 ['before/01-normals.png','after/01-normals.png','normal-footprint-correction',100,405,290,45],
 ];
 final comparisons=<Map<String,Object>>[];
 for(final p in pairs) {
 final a=load(p[0] as String),b=load(p[1] as String);
 int changed=0,maxDiff=0;
 final x=p[3] as int,y=p[4] as int,w=p[5] as int,h=p[6] as int;
 for(var yy=y;yy<y+h;yy++)for(var xx=x;xx<x+w;xx++){
 bool diff=false;
 for(var c=0;c<4;c++){final i=(yy*402+xx)*4+c; final d=(a[i]-b[i]).abs(); if(d>0)diff=true;if(d>maxDiff)maxDiff=d;}
 if(diff)changed++;
 }
 comparisons.add({'name':p[2],'a':p[0],'b':p[1],'crop':[x,y,w,h],'changedPixels':changed,'maxChannelDifference':maxDiff});
 }
 final samples=<String,Object>{};
 for(final dir in ['before','after']) {
 for(final f in Directory('$root/$dir').listSync().whereType<File>().where((f)=>f.path.endsWith('.png'))) {
 final p='$dir/${f.uri.pathSegments.last}',data=load(p);
 final values=<String,Object>{};
 for(final point in [[300,425],[160,425],[100,425],[280,420],[100,360]]){
 final i=(point[1]*402+point[0])*4; values[point.join(',')]=data.sublist(i,i+4);
 }
 int magenta=0,nonblack=0;
 for(var y=405;y<450;y++)for(var x=100;x<390;x++){
 final i=(y*402+x)*4;
 if(data[i]>240&&data[i+1]<15&&data[i+2]>240)magenta++;
 if(data[i]+data[i+1]+data[i+2]>0)nonblack++;
 }
 samples[p]={'samples':values,'magentaPixelsInFootprintBand':magenta,'nonblackPixelsInFootprintBand':nonblack};
 }
 }
 final result={'dimensions':[402,874],'note':'Encoded PNG comparisons, not calibrated linear-channel or coverage measurements. y405..449 lies below the visible caster in both positions.','comparisons':comparisons,'images':samples};
 File('$root/pixel-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
 print(const JsonEncoder.withIndent('  ').convert(comparisons));
}
