import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
const root='/private/tmp/dart3d-w34-ios-live-catcher-composition-20261028/r1/parent';
void main(){
 final cache=<String,Uint8List>{};
 Uint8List get(String p)=>cache.putIfAbsent(p,(){final r=Process.runSync('ffmpeg',['-v','error','-i','$root/$p','-f','rawvideo','-pix_fmt','rgba','pipe:1'],stdoutEncoding:null);if(r.exitCode!=0)throw StateError(r.stderr.toString());final d=r.stdout as Uint8List;if(d.length!=402*874*4)throw StateError('Dimension $p');return d;});
 final pairs=[
 ['transparent/00-load-A.png','transparent/01-replace-A.png','transparent-load-vs-replace-A'],
 ['transparent/00-load-A.png','transparent/02-reload-A.png','transparent-load-vs-reload-A'],
 ['transparent/03-move-B.png','transparent/04-replace-B.png','transparent-move-vs-replace-B'],
 ['transparent/03-move-B.png','transparent/05-reload-B.png','transparent-move-vs-reload-B'],
 ['baseline/00-load-A.png','transparent/00-load-A.png','transparent-vs-initial-correct-alpha-A'],
 ['transparent/00-load-A.png','clean/00-load-A.png','traced-vs-clean-load-A'],
 ['transparent/02-reload-A.png','clean/02-reload-A.png','traced-vs-clean-reload-A'],
 ['transparent/05-reload-B.png','clean/05-reload-B.png','traced-vs-clean-reload-B'],
 ['clean/00-load-A.png','clean/01-replace-A.png','clean-load-vs-replace-A'],
 ['clean/00-load-A.png','clean/02-reload-A.png','clean-load-vs-reload-A'],
 ['clean/03-move-B.png','clean/04-replace-B.png','clean-move-vs-replace-B'],
 ['clean/03-move-B.png','clean/05-reload-B.png','clean-move-vs-reload-B'],
 ['baseline/00-load-A.png','baseline/01-replace-A.png','alpha-load-vs-replace-A'],
 ['baseline/01-replace-A.png','baseline/02-reload-A.png','alpha-replace-vs-reload-A'],
 ['baseline-reload-only/00-load-A.png','baseline-reload-only/01-reload-A.png','alpha-fresh-load-vs-reload-only-A'],
 ['multiply/00-load-A.png','multiply/01-replace-A.png','multiply-load-vs-replace-A'],
 ['multiply/00-load-A.png','multiply/02-reload-A.png','multiply-load-vs-reload-A'],
 ['multiply/03-move-B.png','multiply/04-replace-B.png','multiply-move-vs-replace-B'],
 ['multiply/03-move-B.png','multiply/05-reload-B.png','multiply-move-vs-reload-B'],
 ['baseline/02-reload-A.png','multiply/02-reload-A.png','alpha-vs-multiply-after-reload-A'],
 ['baseline/05-reload-B.png','multiply/05-reload-B.png','alpha-vs-multiply-after-reload-B'],
 ];
 final comps=<Map<String,Object>>[];
 for(final p in pairs){final a=get(p[0]),b=get(p[1]);int count=0,maxDiff=0;for(var y=70;y<650;y++)for(var x=0;x<402;x++){bool changed=false;for(var c=0;c<4;c++){final i=(y*402+x)*4+c,d=(a[i]-b[i]).abs();if(d>0)changed=true;if(d>maxDiff)maxDiff=d;}if(changed)count++;}comps.add({'name':p[2],'a':p[0],'b':p[1],'crop':[0,70,402,580],'changedPixels':count,'maxChannelDifference':maxDiff});}
 final samples=<String,Object>{};
 for(final dir in ['baseline','baseline-reload-only','multiply','transparent','clean'])for(final f in Directory('$root/$dir').listSync().whereType<File>().where((f)=>f.path.endsWith('.png'))){final p='$dir/${f.uri.pathSegments.last}',d=get(p);final out=<String,Object>{};for(final point in [[100,360],[100,425],[160,425],[300,425],[280,290],[100,250]]){final i=(point[1]*402+point[0])*4;out[point.join(',')]=d.sublist(i,i+4);}samples[p]=out;}
 final result={'note':'Encoded PNG pixels, not calibrated RGB or numeric alpha. All captures Off/wire off. Crop excludes status/footer.','comparisons':comps,'samples':samples};File('$root/pixel-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));print(const JsonEncoder.withIndent('  ').convert(comps));
}
