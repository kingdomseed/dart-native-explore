import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'raw-utils.dart' as raw;
const root='/private/tmp/dart3d-u3-outline-first-target-control-20261028/r1/parent';
void main(List<String> args){
 final stage=args.single, p='$root/${args.single}';
 final records=Directory('$p/raw').listSync().whereType<File>().where((f)=>f.path.endsWith('.json')).map((f){final m=jsonDecode(f.readAsStringSync()) as Map<String,dynamic>;m['file']=f.path.replaceAll('.json','.rgba');return m;}).toList();
 double time(Map m)=>double.parse(RegExp(r'time=([\d.]+)').firstMatch(m['label'])!.group(1)!);
 records.sort((a,b)=>time(a).compareTo(time(b)));
 final base=records.firstWhere((m)=>m['label'].startsWith('target ')&&m['label'].contains('mode=0'));
 final baseBytes=File(base['file']).readAsBytesSync();
 final logs=File('$p/native-events.log').readAsLinesSync();
 final maskRows=<Map<String,Object>>[];
 for(final m in records.where((m)=>m['label'].startsWith('mask '))){
  final stamp=time(m);
  Map<String,dynamic> match(String prefix)=>records.singleWhere((r)=>r['label'].startsWith(prefix)&&time(r)==stamp);
  final target=match('target '),alphaIn=match('alpha-input '),alphaOut=match('alpha-output ');
  final bytes=File(m['file']).readAsBytesSync(),width=m['width'] as int,height=m['height'] as int;
  final mask=[for(var i=0;i<bytes.length;i+=8)[for(var c=0;c<4;c++)raw.half(bytes[i+c*2]|(bytes[i+c*2+1]<<8))]];
  final contour=<int,int>{};
  for(var y=0;y<height;y++)for(var x=0;x<width;x++){
   final i=y*width+x;if(mask[i][3]>=0.001)continue;var best=0.0,chosen=-1;
   for(var dy=-4;dy<=4;dy++)for(var dx=-4;dx<=4;dx++){
    if(dx*dx+dy*dy>9)continue;final xx=(x+dx).clamp(0,width-1),yy=(y+dy).clamp(0,height-1),j=yy*width+xx;
    if(mask[j][3]>best){best=mask[j][3];chosen=j;}
   }
   if(best>0.001)contour[i]=chosen;
  }
  int outsideChanges(Uint8List a,Uint8List b){var n=0;for(var i=0;i<width*height;i++)if(!contour.containsKey(i)&&List.generate(4,(c)=>a[i*4+c]!=b[i*4+c]).any((v)=>v))n++;return n;}
  int colorByte(double v){final s=v<=0.0031308?12.92*v:1.055*math.pow(v,1/2.4)-0.055;return (s*255).round().clamp(0,255);}
  int contourBad(Uint8List output){var n=0;for(final e in contour.entries){final c=mask[e.value],expected=[colorByte(c[2]),colorByte(c[1]),colorByte(c[0]),255];if(List.generate(4,(i)=>output[e.key*4+i]!=expected[i]).any((v)=>v))n++;}return n;}
  final targetBytes=File(target['file']).readAsBytesSync(),input=File(alphaIn['file']).readAsBytesSync(),output=File(alphaOut['file']).readAsBytesSync();
  final event=logs.singleWhere((l)=>l.contains('U3OV mask-encoded binding=target=')&&l.contains(' time=$stamp '));
  final expected=event.substring(event.indexOf(' poses=')+7)!='[]';
  final support=mask.where((c)=>c[3]>0).length;
  final callbacks=logs.where((l)=>l.contains('U3OV private-update-publication binding=target=')&&l.contains(' time=$stamp ')).toList();
  maskRows.add({'time':stamp,'cpuSelected':expected,'support':support,'contour':contour.length,'currentMembershipMatches':expected?support>0:support==0,'targetOutsideChanged':outsideChanges(baseBytes,targetBytes),'targetContourMismatches':contourBad(targetBytes),'alphaOutsideChanged':outsideChanges(input,output),'alphaContourMismatches':contourBad(output),'privateUpdateEvents':callbacks,'maskEvent':event});
 }
 final stored=<Map<String,Object>>[];
 for(final m in records.where((m)=>m['label'].startsWith('stored-'))){final previous=records.where((r)=>r['label'].startsWith('target ')&&time(r)<time(m)).last;final a=File(m['file']).readAsBytesSync(),b=File(previous['file']).readAsBytesSync();stored.add({'label':m['label'],'previous':previous['label'],'byteDifferences':List.generate(a.length,(i)=>a[i]!=b[i]).where((v)=>v).length});}
 final due=logs.where((l)=>l.contains('U3OV due ')).toList(),changes=logs.where((l)=>l.contains('U3OV public-highlights')).toList();
 final result={'stage':stage,'maskPasses':maskRows,'storedReads':stored,'dueCount':due.length,'setClearCount':changes.length,'dueEvents':due,'highlightEvents':changes};
 File('$p/analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
 print(jsonEncode({'stage':stage,'maskPasses':maskRows.map((r)=>{'time':r['time'],'cpuSelected':r['cpuSelected'],'support':r['support'],'contour':r['contour'],'currentMatches':r['currentMembershipMatches'],'targetOutsideChanged':r['targetOutsideChanged'],'targetContourMismatches':r['targetContourMismatches'],'alphaOutsideChanged':r['alphaOutsideChanged'],'alphaContourMismatches':r['alphaContourMismatches'],'callbacks':(r['privateUpdateEvents'] as List).length}).toList(),'storedByteDifferences':stored.map((r)=>r['byteDifferences']).toList(),'dueCount':due.length,'setClearCount':changes.length}));
}
