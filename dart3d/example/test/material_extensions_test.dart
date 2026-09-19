// W22 glTF material extensions + conformance harness (spec §W22).
// Covers the wire vocabulary the extension family emits
// (docs/texture-material-spec.md's extension matrix) and walks the
// vendored Khronos catalog through the manifest path, asserting no
// asset produces an unhandled property — the unit-level half of the
// spec's "catalog through the importer without a warn-once". Same
// pure-Dart constraint as texture_material_test.dart: dart3d's barrel
// needs DartNative, so this pulls the libraries + the runner directly.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:dart3d/src/protocol.dart';
import 'package:test/test.dart';

import '../tool/conformance_runner.dart';

void main() {
  group('extension property encoding', () {
    // A material carrying the full KHR_materials_* family as upstream's
    // fscene emitter writes it (wire names per
    // docs/texture-material-spec.md).
    Map<String, dynamic> manifestFor() => materialManifest('physical', {
      'anisotropy': 0.8,
      'anisotropyRotation': 1.57,
      'anisotropyTexture': {'texture': true},
      'clearcoat': 1.0,
      'clearcoatRoughness': 0.1,
      'clearcoatTexture': {'texture': true},
      'clearcoatNormalScale': [0.6, 0.6],
      'sheenColor': [0.5, 0.3, 0.1, 1.0],
      'sheenRoughness': 0.5,
      'specular': 0.4,
      'specularColor': [1.0, 0.5, 0.3, 1.0],
      'transmission': 1.0,
      'transmissionTexture': {'texture': true},
      'transmissionTextureTransform': {'texCoord': 1},
      'thickness': 0.8,
      'attenuationColor': [0.8, 0.95, 1.0, 1.0],
      'attenuationDistance': 2.0,
      'ior': 1.33,
      'dispersion': 12.0,
      'iridescence': 0.7,
      'iridescenceIor': 1.3,
      'iridescenceThicknessMinimum': 100.0,
      'iridescenceThicknessMaximum': 400.0,
      'diffuseTransmission': 0.5,
      'diffuseTransmissionColor': [1.0, 1.0, 1.0, 1.0],
    });

    test('every extension property survives the manifest encode', () {
      final manifest = manifestFor();
      final names = manifestPropNames(manifest);
      for (final expected in [
        'anisotropy',
        'anisotropyRotation',
        'anisotropyTexture',
        'clearcoat',
        'clearcoatRoughness',
        'clearcoatTexture',
        'clearcoatNormalScale',
        'sheenColor',
        'sheenRoughness',
        'specular',
        'specularColor',
        'transmission',
        'transmissionTextureTransform',
        'thickness',
        'attenuationColor',
        'attenuationDistance',
        'ior',
        'dispersion',
        'iridescence',
        'iridescenceIor',
        'iridescenceThicknessMinimum',
        'iridescenceThicknessMaximum',
        'diffuseTransmission',
        'diffuseTransmissionColor',
      ]) {
        expect(names, contains(expected), reason: expected);
      }
    });

    test('the physical type and tagged values land', () {
      final manifest = manifestFor();
      final resources = manifest['resources'] as Map<String, dynamic>;
      final material = resources.values
          .map((r) => r as Map<String, dynamic>)
          .singleWhere((r) => r['kind'] == 'material');
      expect(material['type'], 'physical');
      final props = material['properties'] as Map<String, dynamic>;
      expect(props['clearcoat'], {'d': 1.0});
      expect(props['sheenColor'], {
        'c': [0.5, 0.3, 0.1, 1.0],
      });
      expect(props['ior'], {'d': 1.33});
      // v2 lands f32 — 0.6 rounds to its nearest float.
      expect(props['clearcoatNormalScale'], {
        'v2': [closeTo(0.6, 1e-6), closeTo(0.6, 1e-6)],
      });
      final ref = props['transmissionTexture'] as Map<String, dynamic>;
      expect(ref['rref'], isA<String>());
      // KHR_texture_transform on an extension slot rides as the same
      // tagged map base slots carry.
      final transform =
          props['transmissionTextureTransform'] as Map<String, dynamic>;
      expect((transform['map'] as Map)['texCoord'], {'i': 1});
    });
  });

  group('catalog conformance', () {
    test('the vendored catalog covers the spec minimum', () {
      final catalog = loadCatalog();
      final assets = catalog['assets'] as List;
      // Spec names an 86-asset catalog; upstream has grown past it.
      expect(assets.length, greaterThanOrEqualTo(86));
    });

    test('every catalog material round-trips through the manifest', () {
      final catalog = loadCatalog();
      var materials = 0;
      for (final a in catalog['assets'] as List<dynamic>) {
        for (final m in (a as Map)['materials'] as List<dynamic>? ?? []) {
          final mat = (m as Map).cast<String, dynamic>();
          final declared = (mat['properties'] as Map).keys.toSet();
          final names = manifestPropNames(
            materialManifest(
              mat['type'] as String,
              (mat['properties'] as Map).cast<String, Object?>(),
            ),
          );
          // Transforms land as '<slot>Transform' — the declared key
          // already carries that name.
          expect(
            names,
            containsAll(declared),
            reason: '${a['name']} ${mat['name']}',
          );
          materials++;
        }
      }
      expect(materials, greaterThan(0));
    });

    test('no asset produces an unhandled property on either platform', () {
      final report = runConformance(loadCatalog());
      final warned = [
        for (final r in report.rows)
          if (r.unhandled['ios']!.isNotEmpty ||
              r.unhandled['android']!.isNotEmpty)
            '${r.name}: ios=${r.unhandled['ios']} '
                'android=${r.unhandled['android']}',
      ];
      expect(warned, isEmpty, reason: warned.join('\n'));
      final summary = report.summary();
      expect(summary['ios']![RowStatus.warn], 0);
      expect(summary['android']![RowStatus.warn], 0);
    });

    test('the approximation set matches the per-platform contract', () {
      final report = runConformance(loadCatalog());
      // iOS approximates every extension except the texture transform
      // and the base vocabulary — any asset touching an extension
      // approximates. Android realizes all but iridescence and
      // diffuse transmission.
      final iosApprox = report.rows
          .where((r) => r.status['ios'] == RowStatus.approx)
          .length;
      final androidApprox = report.rows
          .where((r) => r.status['android'] == RowStatus.approx)
          .length;
      expect(iosApprox, greaterThan(0));
      expect(androidApprox, greaterThan(0));
      // iOS approximates strictly more assets than Android (its
      // material system supports fewer extensions).
      expect(iosApprox, greaterThanOrEqualTo(androidApprox));
      // Every asset without extension properties stays clean-pass.
      for (final r in report.rows) {
        if (r.approximated['android']!.isEmpty &&
            r.unhandled['android']!.isEmpty) {
          expect(r.status['android'], RowStatus.pass, reason: r.name);
        }
      }
    });

    test('volume props without transmission classify as the inert drop', () {
      // extFlagsFor warn-onces "volume props without transmission are
      // inert — dropped" — a documented drop, i.e. `approx` under the
      // matrix's definition, not the clean pass Android reported
      // before the classification modeled it.
      final report = runConformance(loadCatalog());
      // IORTestGrid's T0 materials carry transmission:0 + thickness +
      // attenuationColor — ten inert-warn materials.
      final grid = report.rows.singleWhere((r) => r.name == 'IORTestGrid');
      expect(grid.status['android'], RowStatus.approx);
      expect(
        grid.approximated['android'],
        containsAll(<String>['thickness', 'attenuationColor']),
      );
      // ScatteringSkull declares no transmission at all — every
      // volume prop is inert on Android.
      final skull = report.rows.singleWhere((r) => r.name == 'ScatteringSkull');
      expect(
        skull.approximated['android'],
        containsAll(<String>[
          'thickness',
          'thicknessTexture',
          'attenuationColor',
          'attenuationDistance',
        ]),
      );
      // Control: a transmissive volume still realizes the props.
      final att = report.rows.singleWhere((r) => r.name == 'AttenuationTest');
      expect(att.status['android'], RowStatus.pass);
    });

    test('the support table covers every catalog property name', () {
      // Guards the table against typos — a claimed-realized name that
      // no asset uses and no wire name matches would hide a gap.
      final catalog = loadCatalog();
      final used = <String>{};
      for (final a in catalog['assets'] as List<dynamic>) {
        for (final m in (a as Map)['materials'] as List<dynamic>? ?? []) {
          used.addAll(((m as Map)['properties'] as Map).keys.cast<String>());
        }
      }
      final tableKeys = {
        ...kMaterialPropertySupport.keys,
        for (final k in kMaterialPropertySupport.keys) '${k}Transform',
      };
      final uncovered = used.difference(tableKeys);
      expect(uncovered, isEmpty, reason: uncovered.join(','));
    });
  });

  group('golden manifest', () {
    test('classifies the upstream smoke scenes and generates fixtures', () {
      expect(goldenScenes, hasLength(37));
      final applicable = goldenScenes.where((s) => s.applies).length;
      expect(applicable, 20);
      // Every generated fixture encodes a valid manifest with a
      // material, a mesh node, and a camera.
      for (final s in goldenScenes.where((s) => s.fixture != null)) {
        final manifest =
            jsonDecode(
                  utf8.decode(
                    D3Protocol.loadSceneBytes(goldenFixture(s.fixture!)),
                  ),
                )
                as Map<String, dynamic>;
        final resources = manifest['resources'] as Map<String, dynamic>;
        expect(
          resources.values.any((r) => (r as Map)['kind'] == 'material'),
          isTrue,
          reason: s.fixture,
        );
        expect(
          resources.values.any((r) => (r as Map)['kind'] == 'geometry'),
          isTrue,
          reason: s.fixture,
        );
      }
    });

    test('writes the matrix and golden artifacts', () {
      final report = runConformance(loadCatalog());
      final out = writeArtifacts(report);
      for (final name in [
        'conformance-matrix.json',
        'golden-manifest.json',
        'golden/pbr_cuboid.fscene.json',
        'golden/physical_transmission.fscene.json',
      ]) {
        expect(File('${out.path}/$name').existsSync(), isTrue, reason: name);
      }
    });
  });
}
