import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'inspect-raw.dart' as raw;
const p='/private/tmp/dart3d-u3-outline-view-probe-20261028/r1/parent';
void main(){
 final records=Directory('$p/raw').listSync().whereType<File>().where((f)=>f.path.endsWith('.json')).map((f){final m=jsonDecode(f.readAsStringSync()) as Map<String,dynamic>;m['file']=f.path.replaceAll('.json','.rgba');return m;}).toList();
 double time(Map m)=>double.parse(RegExp(r'time=([\d.]+)').firstMatch(m['label'])!.group(1)!);
 records.sort((a,b)=>time(a).compareTo(time(b)));
 final base=records.firstWhere((m)=>m['label'].startsWith('target ')&&m['label'].contains('mode=0'));
 final baseBytes=File(base['file']).readAsBytesSync();
 final lines=File('$p/native-all.log').readAsLinesSync();
 final maskRows=<Map<String,Object>>[];
 for(final m in records.where((m)=>m['label'].startsWith('mask '))){
  final stamp=time(m);final target=records.singleWhere((r)=>r['label'].startsWith('target ')&&time(r)==stamp);
  final alphaIn=records.singleWhere((r)=>r['label'].startsWith('alpha-input ')&&time(r)==stamp);
  final alphaOut=records.singleWhere((r)=>r['label'].startsWith('alpha-output ')&&time(r)==stamp);
  final bytes=File(m['file']).readAsBytesSync();final width=m['width'] as int,height=m['height'] as int;
  final mask=[for(var i=0;i<bytes.length;i+=8)[for(var c=0;c<4;c++)raw.half(bytes[i+c*2]|bytes[i+c*2+1]<<8)]];
  final contour=<int,int>{};
  for(var y=0;y<height;y++)for(var x=0;x<width;x++){
   final i=y*width+x;if(mask[i][3]>=0.001)continue;var best=0.0,chosen=-1;
   for(var dy=-4;dy<=4;dy++)for(var dx=-4;dx<=4;dx++){
    if(dx*dx+dy*dy>9)continue;final xx=(x+dx).clamp(0,width-1), yy=(y+dy).clamp(0,height-1),j=yy*width+xx;
    if(mask[j][3]>best){best=mask[j][3];chosen=j;}
   }
   if(best>0.001)contour[i]=chosen;
  }
  final targetBytes=File(target['file']).readAsBytesSync(),input=File(alphaIn['file']).readAsBytesSync(),output=File(alphaOut['file']).readAsBytesSync();
  int outsideChanges(Uint8List a,Uint8List b){var count=0;for(var i=0;i<width*height;i++)if(!contour.containsKey(i)){if(List.generate(4,(c)=>a[i*4+c]!=b[i*4+c]).any((v)=>v))count++;}return count;}
  int colorByte(double v){final s=v<=0.0031308?12.92*v:1.055*math.pow(v,1/2.4)-0.055;return (s*255).round().clamp(0,255);}
  int contourMismatches(Uint8List output){var bad=0;for(final e in contour.entries){final c=mask[e.value];final expected=[colorByte(c[2]),colorByte(c[1]),colorByte(c[0]),255];if(List.generate(4,(k)=>output[e.key*4+k]!=expected[k]).any((v)=>v))bad++;}return bad;}
  final maskEvent=lines.singleWhere((l)=>l.contains('U3OV mask-encoded binding=target=')&&l.contains(' time=$stamp '));
  final poses=maskEvent.substring(maskEvent.indexOf(' poses=')+7);
  maskRows.add({'time':stamp,'nativeMaskEvent':maskEvent,'cpuHasSelectedDraws':poses!='[]','maskNonzeroPixels':mask.where((c)=>c[3]>0).length,'observedContourPixels':contour.length,'targetOutsideContourChangedPixels':outsideChanges(baseBytes,targetBytes),'targetContourColorOrAlphaMismatches':contourMismatches(targetBytes),'privateAlphaOutsideContourChangedPixels':outsideChanges(input,output),'privateAlphaContourColorOrAlphaMismatches':contourMismatches(output),'maskFile':m['file'],'targetFile':target['file']});
 }
 final stored=<Map<String,Object>>[];
 for(final m in records.where((m)=>m['label'].startsWith('stored-'))){final previous=records.where((r)=>r['label'].startsWith('target ')&&time(r)<time(m)).last;final a=File(m['file']).readAsBytesSync(),b=File(previous['file']).readAsBytesSync();stored.add({'label':m['label'],'previousTarget':previous['label'],'byteDifferences':List.generate(a.length,(i)=>a[i]!=b[i]).where((v)=>v).length});}
 File('$p/failure-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'targetClearFromCode':[0,0,0,1],'actualOffTargetZeroAlphaPixels':List.generate(baseBytes.length~/4,(i)=>baseBytes[i*4+3]).where((v)=>v==0).length,'maskPasses':maskRows,'storedReads':stored,'oracle':'Pinned radius3 circular kernel, strict-greater coverage, current mask centers and nearest texel-center samples; BGRA8_sRGB expected transfer. This checks actual raw outputs, not source selection correctness.'}));
 print(jsonEncode({'maskPasses':maskRows.map((r)=>{'time':r['time'],'cpuSelected':r['cpuHasSelectedDraws'],'maskPixels':r['maskNonzeroPixels'],'contourPixels':r['observedContourPixels'],'outsideTargetChanged':r['targetOutsideContourChangedPixels'],'outsideAlphaChanged':r['privateAlphaOutsideContourChangedPixels'],'contourTargetMismatches':r['targetContourColorOrAlphaMismatches']}).toList(),'storedByteDifferences':stored.map((r)=>r['byteDifferences']).toList()}));
}
