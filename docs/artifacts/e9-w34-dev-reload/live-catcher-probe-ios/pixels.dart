import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
const root='/private/tmp/dart3d-w34-ios-live-catcher-probe-20261028/r1/parent';
void main(){
 final cache=<String,Uint8List>{};
 Uint8List get(String p)=>cache.putIfAbsent(p,(){final r=Process.runSync('ffmpeg',['-v','error','-i','$root/$p','-f','rawvideo','-pix_fmt','rgba','pipe:1'],stdoutEncoding:null);if(r.exitCode!=0)throw StateError(r.stderr.toString());final d=r.stdout as Uint8List;if(d.length!=402*874*4)throw StateError('Dimensions $p');return d;});
 final pairs=[
 ['before/00-off-A.png','model-copy/18-off-A-final.png','authored-matched-A-final',0,70,402,580],
 ['before/04-off-B.png','model-copy/00-off-A.png','initial-model-vs-baseline-B-control',0,70,402,580],
 ['model-copy/01-normals-A.png','model-copy/06-normals-A.png','normals-A-repeat',0,70,402,580],
 ['before/00-off-A.png','model-copy/00-off-A.png','authored-before-after',0,70,402,580],
 ['model-copy/00-off-A.png','model-copy/12-off-restored-A.png','authored-after-wire',0,70,402,580],
 ['model-copy/06-normals-A.png','model-copy/07-normals-B.png','live-normals-motion-without-replace',100,405,290,45],
 ['model-copy/08-depth-B.png','model-copy/09-depth-A.png','live-depth-return-without-replace',100,405,290,45],
 ['model-copy/14-normals-B.png','model-copy/15-normals-B-replace.png','same-ID-live-replacement',0,70,402,580],
 ['model-copy/15-normals-B-replace.png','model-copy/16-normals-B-reload.png','current-B-reload',0,70,402,580],
 ['before/04-off-B.png','model-copy/17-off-B.png','authored-current-B',0,70,402,580],
 ['model-copy/00-off-A.png','model-copy/18-off-A-final.png','A-initial-vs-after-replace-reload',0,70,402,580],
 ];
 final comps=<Map<String,Object>>[];
 for(final p in pairs){final a=get(p[0]as String),b=get(p[1]as String);int n=0,maxDiff=0;final x=p[3]as int,y=p[4]as int,w=p[5]as int,h=p[6]as int;for(int yy=y;yy<y+h;yy++)for(int xx=x;xx<x+w;xx++){bool diff=false;for(int c=0;c<4;c++){final i=(yy*402+xx)*4+c;final d=(a[i]-b[i]).abs();if(d>0)diff=true;if(d>maxDiff)maxDiff=d;}if(diff)n++;}comps.add({'name':p[2],'a':p[0],'b':p[1],'crop':[x,y,w,h],'changedPixels':n,'maxChannelDifference':maxDiff});}
 final samples=<String,Object>{};
 for(final dir in ['before','model-copy'])for(final f in Directory('$root/$dir').listSync().whereType<File>().where((f)=>f.path.endsWith('.png'))){final p='$dir/${f.uri.pathSegments.last}',d=get(p);final out=<String,Object>{};for(final point in [[300,425],[160,425],[100,425],[100,360],[250,425]]){final i=(point[1]*402+point[0])*4;out[point.join(',')]=d.sublist(i,i+4);}samples[p]=out;}
 final result={'note':'Encoded screenshot comparisons, not calibrated linear/alpha values or latency. Footprint band is below caster in both positions.','comparisons':comps,'samples':samples};
 File('$root/pixel-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
 print(const JsonEncoder.withIndent('  ').convert(comps));
}
