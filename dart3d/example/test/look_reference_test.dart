// The look-reference board (`look_reference_scene.dart`): every variant
// builds, every measured patch lies on the board, and the patch table
// the comparison tool reads is the one the Dart layout produces.
//
// Regenerate the table after a layout change with
//   LOOKREF_WRITE=1 dn test test/look_reference_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:dart3d_example/look_reference_scene.dart';
import 'package:test/test.dart';

const _tablePath = '../tool/look_reference_patches.json';

String _table() => const JsonEncoder.withIndent('  ').convert({
  'board': {
    'left': kLookBoardLeft,
    'right': kLookBoardRight,
    'top': kLookBoardTop,
    'bottom': kLookBoardBottom,
  },
  'variants': [for (final v in LookVariant.values) v.label],
  'patches': [for (final p in lookReferencePatches()) p.toJson()],
});

void main() {
  test('every variant builds a document with its lights and its stage', () {
    for (final variant in LookVariant.values) {
      final doc = buildLookReference(variant, aspect: 0.46);
      expect(
        doc.stage.environmentRef,
        variant.stage ? isNotNull : isNull,
        reason: variant.label,
      );
      final lights = doc.nodes.values
          .expand((n) => n.components)
          .where((c) => c.type.endsWith('Light'))
          .length;
      expect(
        lights,
        [
          variant.directionalLight,
          variant.pointLight,
          variant.spotLight,
        ].where((b) => b).length,
        reason: variant.label,
      );
    }
  });

  test('patch names are unique and every patch lies on the board', () {
    final patches = lookReferencePatches();
    expect(patches.map((p) => p.name).toSet().length, patches.length);
    for (final p in patches) {
      expect(p.x - p.halfSize, greaterThan(kLookBoardLeft), reason: p.name);
      expect(p.x + p.halfSize, lessThan(kLookBoardRight), reason: p.name);
      expect(p.y + p.halfSize, lessThan(kLookBoardTop), reason: p.name);
      expect(p.y - p.halfSize, greaterThan(kLookBoardBottom), reason: p.name);
    }
  });

  test('the board fits the view at phone and tablet aspects', () {
    for (final aspect in [0.45, 0.46, 0.625, 1.53]) {
      final halfH = lookReferenceOrthoScale(aspect);
      expect(halfH * 2, greaterThan(kLookBoardTop - kLookBoardBottom));
      expect(
        halfH * 2 * aspect,
        greaterThan(kLookBoardRight - kLookBoardLeft),
      );
    }
  });

  test('tool/look_reference_patches.json matches the Dart layout', () {
    final file = File(_tablePath);
    if (Platform.environment['LOOKREF_WRITE'] == '1') {
      file.writeAsStringSync('${_table()}\n');
    }
    expect(file.readAsStringSync().trim(), _table());
  });
}
