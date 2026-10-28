import 'dart:convert';
import 'dart:io';
import 'analyze-pixels.dart' as prior;
void main() {
  final rows=<Map<String,Object>>[];
  for(final n in ['00-off-A','01-normals-A','02-depth-A','03-baseColor-A','04-baseColor-B','05-off-B']) {
    rows.add(prior.compare('blend-before/$n.png','blend-after/$n.png',expectedStable:n.startsWith('00')||n.startsWith('05')));
  }
  for(final n in ['06-off-A-return','10-off-wire-return','14-off-final']) rows.add(prior.compare('blend-after/00-off-A.png','blend-after/$n.png'));
  for(final n in ['07-normals-A-return','11-normals-reenter','12-material-replace','13-reload']) rows.add(prior.compare('blend-after/01-normals-A.png','blend-after/$n.png'));
  for(final n in ['00-off-A','01-normals-A','02-depth-A','03-baseColor-A','04-baseColor-B','05-normals-B','06-off-B','07-off-A-return','08-normals-A-return']) rows.add(prior.compare('clean/$n.png','final-clean/$n.png'));
  for(final (a,b) in [('21-dim','09-dim'),('22-bright','10-bright'),('25-rest-100','11-rest'),('19-low','12-low'),('20-high-return','13-high'),('26-new-B','14-new-B'),('29-light-absent','15-absent'),('30-light-restored','16-restored'),('31-material-replace','17-replace'),('32-reload-selected','18-reload'),('33-off-new-B','19-off-new-B')]) rows.add(prior.compare('clean/$a.png','final-clean/$b.png'));
  final pbrNames=Directory('${prior.root}/pbr-regression').listSync().whereType<File>().where((f)=>RegExp(r'/\d\d-[^/]+\.png$').hasMatch(f.path)).map((f)=>f.uri.pathSegments.last).toList()..sort();
  final finalNames=Directory('${prior.root}/final-pbr').listSync().whereType<File>().where((f)=>RegExp(r'/\d\d-[^/]+\.png$').hasMatch(f.path)).map((f)=>f.uri.pathSegments.last).toList()..sort();
  if(pbrNames.length!=5||finalNames.length!=5) throw StateError('PBR image count');
  for(final name in finalNames) {
    final matched=pbrNames.singleWhere((p)=>p.substring(3)==name.substring(3));
    rows.add(prior.compare('pbr-regression/$matched','final-pbr/$name',crop:const [0,70,402,580]));
  }
  final stable=rows.where((e)=>e['expectedStable']==true).toList();
  final failures=stable.where((e)=>e['changedPixels']!=0).toList();
  final json={'comparisons':rows,'stableComparisons':stable.length,'stableFailures':failures};
  File('${prior.root}/final-pixel-analysis.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  print(jsonEncode({'comparisons':rows.length,'stableComparisons':stable.length,'stableFailures':failures}));
}
