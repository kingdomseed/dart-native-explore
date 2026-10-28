import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
const root='/private/tmp/dart3d-u3-outline-first-target-control-20261028/r1/parent';
double half(int v){final s=(v&0x8000)==0?1.0:-1.0;final e=(v>>10)&31;final m=v&1023;if(e==0)return s*m/16777216;if(e==31)return m==0?s*double.infinity:double.nan;return s*(1+m/1024)*(1<<(e>15?e-15:0))/(1<<(e<15?15-e:0));}
void main(){
 final files=Directory('$root/raw').listSync().whereType<File>().where((f)=>f.path.endsWith('.json')).toList()..sort((a,b)=>a.path.compareTo(b.path));
 for(final f in files){final m=jsonDecode(f.readAsStringSync()) as Map;final p=File(f.path.replaceAll('.json','.rgba')).readAsBytesSync(); final counts=<String,int>{};final bpp=m['bytesPerPixel'] as int;for(var i=0;i<p.length;i+=bpp){ final List<num> c=bpp==8?[for(var x=0;x<4;x++)half(p[i+x*2]|(p[i+x*2+1]<<8))]:[...p.sublist(i,i+4)]; final k=c.join(',');counts[k]=(counts[k]??0)+1;}
 final top=counts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
 print(jsonEncode({'label':m['label'],'format':m['pixelFormat'],'pixels':p.length~/bpp,'top':top.take(7).map((e)=>[e.key,e.value]).toList()}));
 if(bpp==4){final image=img.Image(width:m['width'],height:m['height'],numChannels:4);final bgra=m['pixelFormat']==80||m['pixelFormat']==81;for(var y=0;y<image.height;y++)for(var x=0;x<image.width;x++){final i=(y*image.width+x)*4;image.setPixelRgba(x,y,p[i+(bgra?2:0)],p[i+1],p[i+(bgra?0:2)],p[i+3]);}File(f.path.replaceAll('.json','.png')).writeAsBytesSync(img.encodePng(image));}
 }
}
