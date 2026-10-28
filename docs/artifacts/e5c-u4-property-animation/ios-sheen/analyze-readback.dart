import 'dart:convert';
import 'dart:io';

void main() {
  const root='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-sheen';
  final summaries=<String,dynamic>{};
  for(final name in ['before','after']) {
    final report=jsonDecode(File('$root/$name-readback.json').readAsStringSync()) as Map;
    final cases={for(final r in report['results'] as List) (r as Map)['case']:r};
    if(cases.length!=11) throw StateError('Expected 11 GPU cases');
    for(final r in cases.values) {
      if(r['commandStatus']!=4 || r['gpuError']!=null) throw StateError('GPU error');
      for(final pixel in r['outerPatchRGBA'] as List) {
        for(var c=0;c<4;c++) {
          final expected=c==3?1.0:.5;
          if(((pixel as List)[c] as num)-expected!=0) throw StateError('Outside plane changed');
        }
      }
    }
    var maxError=0.0, zeroDelta=0.0;
    final centerDeltas=<String,List<double>>{};
    for(final alpha in ['0.0','0.5','1.0']) {
      final current=cases['alpha${alpha}_current']!['centerPatchRGBA'] as List;
      final none=cases['alpha${alpha}_withoutSheen']!['centerPatchRGBA'] as List;
      centerDeltas[alpha]=[for(var c=0;c<3;c++)
        ((current[4] as List)[c] as num).toDouble()-((none[4] as List)[c] as num).toDouble()];
      if(alpha=='0.0') for(var i=0;i<9;i++) for(var c=0;c<3;c++) {
        final d=(((current[i] as List)[c] as num)-((none[i] as List)[c] as num)).abs().toDouble();
        if(d>zeroDelta) zeroDelta=d;
      }
    }
    final half=cases['alpha0.5_current']!['centerPatchRGBA'] as List;
    final halfNone=cases['alpha0.5_withoutSheen']!['centerPatchRGBA'] as List;
    final full=cases['alpha1.0_current']!['centerPatchRGBA'] as List;
    final fullNone=cases['alpha1.0_withoutSheen']!['centerPatchRGBA'] as List;
    for(var i=0;i<9;i++) for(var c=0;c<3;c++) {
      final actual=((half[i] as List)[c] as num)-((halfNone[i] as List)[c] as num);
      final expected=(((full[i] as List)[c] as num)-((fullNone[i] as List)[c] as num))*.5;
      final error=(actual-expected).abs().toDouble();
      if(error>maxError) maxError=error;
    }
    if(zeroDelta!=0) throw StateError('Unexpected zero-alpha rim');
    if(name=='before' && maxError<.2) throw StateError('Did not reproduce partial-alpha defect');
    if(name=='after' && maxError>.001) throw StateError('Corrected sheen exceeds tolerance $maxError');
    summaries[name]={'centerSheenContributionByAlpha':centerDeltas,
      'maxHalfAlphaScalingError':maxError,'zeroAlphaContribution':zeroDelta,
      'all11GpuCommandsCompleted':true,'outsidePlaneUnchanged':true};
  }
  final result={'results':summaries,'afterTolerance':.001,
    'boundary':'Raw float16 copied PBR material, synthetic white diffuse/black RGB, rotated plane, no lights. Subtracts same-alpha without-sheen control from each matching pixel. Zero-alpha rim did not reproduce; confirmed defect is full contribution at partial alpha.'};
  File('$root/readback-checks.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
