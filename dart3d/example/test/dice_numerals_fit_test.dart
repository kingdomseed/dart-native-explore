import 'dart:math';

import 'package:dart3d_example/dice_numerals.dart';
import 'package:dart3d_example/dice_polyhedra.dart';
import 'package:test/test.dart';

void main() {
  test('every numeral fits inside its face inlay', () {
    const look = DiceFaceLook();
    for (final kind in ['d4', 'd6', 'd8', 'd10u', 'd10t', 'd12', 'd20']) {
      final geo = buildDieGeo(kind);
      final byDigits = <int, double>{};
      for (final face in geo.faces) {
        final label = face.label(geo.kind);
        if (label == null) continue;
        final fit = numeralFit(geo, face, look);
        expect(fit, inInclusiveRange(0.6, 1.0), reason: '$kind $label');
        final digits = label.replaceAll('.', '').length;
        byDigits.update(digits, (v) => min(v, fit), ifAbsent: () => fit);
      }
      // The shared size for a digit count fits every face that uses it:
      // fitting is monotonic, so the smallest per-face fit fits them all.
      for (final face in geo.faces) {
        final label = face.label(geo.kind);
        if (label == null) continue;
        final shared = byDigits[label.replaceAll('.', '').length]!;
        expect(
          shared,
          lessThanOrEqualTo(numeralFit(geo, face, look)),
          reason: '$kind $label',
        );
      }
    }
    // The d6's single digits already fit at full size.
    final d6 = buildDieGeo('d6');
    for (final face in d6.faces) {
      if (face.label(d6.kind) == null) continue;
      expect(numeralFit(d6, face, look), 1.0);
    }
  });
}
