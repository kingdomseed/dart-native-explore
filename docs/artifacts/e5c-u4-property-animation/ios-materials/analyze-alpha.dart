import 'dart:convert';
import 'dart:io';

void main() {
  const out='/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials';
  final data=jsonDecode(File('$out/alpha-readback-r2.json').readAsStringSync()) as Map;
  final cases={for(final r in data['results'] as List) (r as Map)['case']: r};
  final straight=(data['expectedFromOpaqueControlRGBA'] as List).cast<num>();
  final doubleAlpha=(data['doubleFromOpaqueControlRGBA'] as List).cast<num>();
  final explicit=(data['expectedStraightAlphaRGBA'] as List).cast<num>();
  final baseline=(data['observedEmptyBaselineRGBA'] as List).cast<num>();
  final opaquePatch=(cases['generated_opaque_control'] as Map)['centerPatchRGBA'] as List;
  final destinationPatch=(cases['empty_scene_load'] as Map)['centerPatchRGBA'] as List;
  final alpha=(data['nativeFactor'] as List)[3] as num;
  final checks=<String, dynamic>{};
  for(final entry in {
    'current_realized_fragment':straight,
    'without_late_multiply':straight,
    'original_late_multiply':doubleAlpha,
    'explicit_premult_reference':explicit,
  }.entries) {
    final r=cases[entry.key] as Map;
    if(r['gpuError']!=null || r['commandStatus']!=4) throw StateError('GPU failure');
    var maximumError=0.0;
    final patch=r['centerPatchRGBA'] as List;
    for(var index=0; index<patch.length; index++) {
      final pixel=patch[index] as List;
      for(var channel=0;channel<4;channel++) {
        num expected=entry.value[channel];
        if(entry.key!='explicit_premult_reference' && channel<3) {
          final source=(opaquePatch[index] as List)[channel] as num;
          final destination=(destinationPatch[index] as List)[channel] as num;
          expected=source*alpha*(entry.key=='original_late_multiply'?alpha:1)+destination*(1-alpha);
        }
        final error=((pixel[channel] as num)-expected).abs().toDouble();
        if(error>maximumError) maximumError=error;
      }
    }
    if(maximumError>0.001) throw StateError('${entry.key}: $maximumError');
    checks[entry.key]={'observed':(r['centerPatchRGBA'] as List)[4],
      'expected':entry.value,'maximumAbsoluteError':maximumError};
  }
  for(final r in cases.values) {
    if(r['gpuError']!=null || r['commandStatus']!=4) throw StateError('GPU failure');
    for(final p in r['outerPatchRGBA'] as List) {
      for(var i=0;i<4;i++) {
        if((((p as List)[i] as num)-baseline[i]).abs()>0.001) throw StateError('Outside plane altered');
      }
    }
  }
  final result={'checks':checks,'allSevenGpuCommandsCompleted':true,
    'outsidePlaneUnchanged':true,'absoluteTolerance':0.001,
    'measuredOpaqueRGBA':data['observedOpaqueControlRGBA'],
    'measuredDestinationRGBA':baseline,
    'boundary':'Raw rgba16Float synthetic white-source ordinary unlit control. Compares corresponding pixels to measured opaque and destination controls; generated opaque shading varies across the patch and differs from a direct final-output override. Not PBR, textured-source or whole-U4 numeric parity.'};
  File('$out/alpha-checks.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
