// ignore_for_file: implementation_imports
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:test/test.dart';

void main() {
  group('W17 showcase scene loader', () {
    test('w17 showcase item builds physical sky + skyEnvironment + sunLight and round-trips', () {
      final item = showcaseItems.firstWhere((it) => it.label == 'w17');
      final scene = loadShowcaseScene(item);
      expect(scene, isNotNull);

      final doc = scene!.document;
      final envId = doc.stage.environmentRef;
      expect(envId, isNotNull);
      final envRes = doc.resources[envId!] as EnvironmentResource;
      expect(envRes.skybox?.source, isA<PhysicalSkySpec>());
      expect(envRes.skyEnvironment, isNotNull);
      expect(envRes.skyEnvironment!.source, isA<PhysicalSkySpec>());
      expect(envRes.skyEnvironment!.sunLight, isNotNull);
      expect(envRes.skyEnvironment!.sunLight!.castsShadow, isTrue);

      final json = writeFscene(doc);
      final decoded = readFscene(json);
      final decodedEnv =
          decoded.resources[decoded.stage.environmentRef!] as EnvironmentResource;
      expect(decodedEnv.skybox?.source, isA<PhysicalSkySpec>());
      expect(decodedEnv.skyEnvironment?.source, isA<PhysicalSkySpec>());
      expect(decodedEnv.skyEnvironment?.sunLight?.castsShadow, isTrue);
    });

    test('w17 modes (lowsun, override, step1..3, sweep) build expected specs', () {
      final lowsun = buildW17SkyDocument(mode: 'lowsun');
      final lowEnv =
          lowsun.resources[lowsun.stage.environmentRef!] as EnvironmentResource;
      final lowSky = lowEnv.skybox!.source as PhysicalSkySpec;
      expect(lowSky.sunDirection.y, closeTo(0.04, 1e-3));
      expect(lowSky.turbidity, closeTo(14.0, 1e-3));

      final overrideDoc = buildW17SkyDocument(mode: 'override');
      final overrideEnv =
          overrideDoc.resources[overrideDoc.stage.environmentRef!]
              as EnvironmentResource;
      expect(overrideEnv.skyEnvironment, isNull);
      expect(overrideEnv.environment, isA<ConstantEnvironment>());
      expect(overrideEnv.skybox?.source, isA<PhysicalSkySpec>());

      final step1Doc = buildW17SkyDocument(mode: 'step1');
      final step1Env =
          step1Doc.resources[step1Doc.stage.environmentRef!]
              as EnvironmentResource;
      expect(step1Env.skyEnvironment!.equirectWidth, 64);

      final step2Doc = buildW17SkyDocument(mode: 'step2');
      final step2Env =
          step2Doc.resources[step2Doc.stage.environmentRef!]
              as EnvironmentResource;
      expect(step2Env.skyEnvironment!.equirectWidth, 128);

      final step3Doc = buildW17SkyDocument(mode: 'step3');
      final step3Env =
          step3Doc.resources[step3Doc.stage.environmentRef!]
              as EnvironmentResource;
      expect(step3Env.skyEnvironment!.equirectWidth, 256);
    });
  });
}
