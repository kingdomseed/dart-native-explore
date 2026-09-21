// W25 stage-effects matrix + `.cube` LUT asset path checks:
// `resolveLutAssets`/`resolveLutAssetsAsync` rewrite each env
// resource's `colorGradingLut` asset-path AssetRef into a `bytes`
// payload chunk the natives claim through their env-payload path;
// the wire `lut` field carries the AssetRef key verbatim
// (`chunk:<token>` after resolution, the path string on a resolver
// miss so the native bundle-asset fallback can try). Same constraint
// as the W7/W13 tests: package:dart3d/dart3d.dart is unreachable
// under `dart test` (the barrel transitively imports
// package:dartnative), so this pulls the pure-Dart libraries
// directly — `lut_assets.dart` has no plugin imports.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/lut_assets.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const envId = LocalId(1, 20);
  const nodeId = LocalId(1, 30);

  /// A tiny valid `.cube` table — 2³ rows, red-fastest.
  Uint8List cubeBytes() => Uint8List.fromList(
    utf8.encode(
      'TITLE "warm"\nLUT_3D_SIZE 2\n'
      '0 0 0\n1 0 0\n0 1 0\n1 1 0\n'
      '0 0 1\n1 0 1\n0 1 1\n1 1 1\n',
    ),
  );

  /// An env resource carrying a LUT ref, staged like the W13 lanes.
  SceneDocument stagedLut(
    String? lutKey, {
    double lutBlend = 1.0,
    EnvironmentEffectsSpec Function(EnvironmentEffectsSpec e)? extra,
  }) {
    var effects = EnvironmentEffectsSpec(
      colorGradingLut: lutKey == null ? null : AssetRef(lutKey),
      colorGradingLutBlend: lutBlend,
    );
    if (extra != null) effects = extra(effects);
    final doc = SceneDocument();
    doc.addResource(
      EnvironmentResource(
        envId,
        environment: const StudioEnvironment(),
        environmentIntensity: 1.0,
        exposure: 1.0,
        toneMapping: 'pbrNeutral',
        skybox: SkyboxSpec(EnvironmentSkySpec()),
        effects: effects,
        overridesEffects: true,
      ),
    );
    doc.stage.environmentRef = envId;
    doc.addNode(
      NodeSpec(id: nodeId, name: 'anchor', transform: TrsTransform()),
      root: true,
    );
    return doc;
  }

  /// The manifest `resources` entry for the env resource.
  Map<String, dynamic> envEntry(SceneDocument doc) {
    final manifest = jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
    return (manifest['resources']
            as Map<String, dynamic>)['env:${envId.toToken()}']
        as Map<String, dynamic>;
  }

  group('lut chunk-ref detection', () {
    test('chunk/id/bare tokens are payload refs, asset paths are not', () {
      final token = envId.toToken();
      expect(isLutChunkRef('chunk:$token'), isTrue);
      expect(isLutChunkRef('id:$token'), isTrue);
      expect(isLutChunkRef(token), isTrue);
      expect(isLutChunkRef('assets/luts/warm.cube'), isFalse);
      expect(isLutChunkRef('luts/warm.cube'), isFalse);
      expect(isLutChunkRef(''), isFalse);
    });
  });

  group('resolveLutAssets', () {
    test('an asset-path ref becomes a bytes payload + chunk: token', () {
      final doc = stagedLut('assets/luts/warm.cube');
      final resolved = resolveLutAssets(
        doc,
        resolve: (key) => key == 'assets/luts/warm.cube' ? cubeBytes() : null,
      );
      expect(resolved, 1);
      final env = doc.resources[envId]! as EnvironmentResource;
      final lutRef = env.effects.colorGradingLut!;
      expect(lutRef.key, startsWith('chunk:'));
      // The minted payload id is the ref's token — the natives strip
      // the `chunk:` prefix and land on the same id.
      final pid = LocalId.parse(lutRef.key);
      final payload = doc.payloads[pid]!;
      expect(payload.encoding, PayloadEncoding.bytes);
      expect(payload.bytes, cubeBytes());
      expect(payload.length, cubeBytes().lengthInBytes);
    });

    test('the manifest carries the chunk token and the bytes spec', () {
      final doc = stagedLut('assets/luts/warm.cube');
      resolveLutAssets(doc, resolve: (_) => cubeBytes());
      final manifest = jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
      final env = envEntry(doc);
      final lut = (env['effects'] as Map)['colorGrading'] as Map;
      expect(lut['lut'], startsWith('chunk:'));
      final pid = LocalId.parse(lut['lut'] as String);
      final payloads = manifest['payloads'] as Map<String, dynamic>;
      expect(payloads.keys, contains('chunk:${pid.toToken()}'));
      final spec = payloads['chunk:${pid.toToken()}'] as Map;
      expect(spec['encoding'], 'bytes');
      expect(spec['length'], cubeBytes().lengthInBytes);
    });

    test('a resolver miss leaves the path for the bundle fallback', () {
      final doc = stagedLut('assets/luts/missing.cube');
      final resolved = resolveLutAssets(doc, resolve: (_) => null);
      expect(resolved, 0);
      final env = doc.resources[envId]! as EnvironmentResource;
      expect(env.effects.colorGradingLut!.key, 'assets/luts/missing.cube');
      expect(doc.payloads, isEmpty);
      // And the wire form is still the raw path string.
      final lut = (envEntry(doc)['effects'] as Map)['colorGrading'] as Map;
      expect(lut['lut'], 'assets/luts/missing.cube');
    });

    test('an already-chunk ref is left alone', () {
      final existing = 'chunk:${const LocalId(7, 3).toToken()}';
      final doc = stagedLut(existing);
      final resolved = resolveLutAssets(doc, resolve: (_) => cubeBytes());
      expect(resolved, 0);
      final env = doc.resources[envId]! as EnvironmentResource;
      expect(env.effects.colorGradingLut!.key, existing);
      expect(doc.payloads, isEmpty);
    });

    test('non-environment resources are untouched', () {
      final doc = SceneDocument();
      doc.addResource(TextureResource(LocalId(1, 50), payload: LocalId(1, 51)));
      final resolved = resolveLutAssets(doc, resolve: (_) => cubeBytes());
      expect(resolved, 0);
      expect(doc.payloads, isEmpty);
    });
  });

  group('resolveLutAssetsAsync', () {
    test('resolves like the sync form', () async {
      SceneDocument build() => stagedLut('assets/luts/warm.cube');
      final a = build();
      final b = build();
      expect(
        await resolveLutAssetsAsync(a, resolve: (key) async => cubeBytes()),
        1,
      );
      expect(
        await resolveLutAssetsAsync(b, resolve: (key) async => cubeBytes()),
        1,
      );
      // Minted ids are session-scoped per SceneDocument, so each
      // doc's ref names a chunk it carries itself — check both
      // resolve inside their own document rather than equal tokens.
      for (final doc in [a, b]) {
        final env = doc.resources[envId]! as EnvironmentResource;
        final ref = env.effects.colorGradingLut!.key;
        expect(ref, startsWith('chunk:'));
        expect(doc.payloads[LocalId.parse(ref)]?.bytes, cubeBytes());
      }
    });
  });

  group('lut diff path', () {
    test('a LUT-bearing env edit ships the chunk op before the resource', () {
      final oldDoc = stagedLut(null);
      final newDoc = stagedLut('assets/luts/warm.cube');
      // applyDiff's resolveLuts hook resolves on the NEW doc before
      // diffCommands runs — exercise that order here.
      resolveLutAssets(newDoc, resolve: (_) => cubeBytes());
      final ops = diffCommands(diffScene(oldDoc, newDoc), oldDoc, newDoc);
      final kinds = [for (final o in ops) o['op']];
      final payloadIdx = kinds.indexOf('upsertPayload');
      final resourceIdx = kinds.indexOf('upsertResource');
      expect(payloadIdx, isNonNegative);
      expect(resourceIdx, greaterThan(payloadIdx));
      final payloadOp = ops[payloadIdx];
      expect(payloadOp['encoding'], 'bytes');
      // The env upsert names the same chunk token.
      final env = (ops[resourceIdx]['resource'] as Map);
      final lut = (env['effects'] as Map)['colorGrading'] as Map;
      expect(lut['lut'], payloadOp['id']);
    });
  });

  // W25 decode cases: every newly-realized or explicitly-handled
  // block's wire form — the natives decode these verbatim.
  group('w25 effect wire forms', () {
    Map<String, dynamic> effectsOf(EnvironmentEffectsSpec e) =>
        envEntry(stagedLut(null, extra: (_) => e))['effects']
            as Map<String, dynamic>;

    test('lut + lutBlend serialize under colorGrading', () {
      final doc = stagedLut('assets/luts/warm.cube', lutBlend: 0.5);
      final cg = (envEntry(doc)['effects'] as Map)['colorGrading'] as Map;
      expect(cg['lut'], 'assets/luts/warm.cube');
      expect(cg['lutBlend'], 0.5);
    });

    test('filmGrain encodes enabled + intensity', () {
      expect(
        effectsOf(
          EnvironmentEffectsSpec(
            filmGrainEnabled: true,
            filmGrainIntensity: 0.4,
          ),
        )['filmGrain'],
        {'enabled': true, 'intensity': 0.4},
      );
    });

    test('autoExposure encodes enabled + compensation', () {
      expect(
        effectsOf(
          EnvironmentEffectsSpec(
            autoExposureEnabled: true,
            autoExposureCompensation: 1.5,
          ),
        )['autoExposure'],
        {'enabled': true, 'compensation': 1.5},
      );
    });

    test('chromaticAberration encodes enabled + intensity', () {
      expect(
        effectsOf(
          EnvironmentEffectsSpec(
            chromaticAberrationEnabled: true,
            chromaticAberrationIntensity: 0.3,
          ),
        )['chromaticAberration'],
        {'enabled': true, 'intensity': 0.3},
      );
    });

    test('screenSpaceReflections encodes enabled + fields', () {
      expect(
        effectsOf(
          EnvironmentEffectsSpec(
            screenSpaceReflectionsEnabled: true,
            screenSpaceReflectionsMaxDistance: 12.0,
          ),
        )['screenSpaceReflections'],
        {'enabled': true, 'maxDistance': 12.0},
      );
    });

    test('globalIllumination encodes enabled + intensity', () {
      expect(
        effectsOf(
          EnvironmentEffectsSpec(
            globalIlluminationEnabled: true,
            globalIlluminationIntensity: 0.6,
          ),
        )['globalIllumination'],
        {'enabled': true, 'intensity': 0.6},
      );
    });

    test('godRays encodes enabled + intensity + color', () {
      // vec3 leaves serialize at float32 precision — use
      // exactly-representable values.
      expect(
        effectsOf(
          EnvironmentEffectsSpec(
            godRaysEnabled: true,
            godRaysIntensity: 0.8,
            godRaysColor: Vector3(1.0, 0.5, 0.25),
          ),
        )['godRays'],
        {
          'enabled': true,
          'intensity': 0.8,
          'color': [1.0, 0.5, 0.25],
        },
      );
    });

    test('lensFlare encodes enabled + ghost fields', () {
      expect(
        effectsOf(
          EnvironmentEffectsSpec(
            lensFlareEnabled: true,
            lensFlareIntensity: 0.7,
            lensFlareGhostCount: 6,
          ),
        )['lensFlare'],
        {'enabled': true, 'intensity': 0.7, 'ghostCount': 6},
      );
    });
  });
}
