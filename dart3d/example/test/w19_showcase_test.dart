// ignore_for_file: implementation_imports
import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:test/test.dart';

void main() {
  group('W19 showcase scene loader', () {
    test('w19 showcase item builds characterController + collider + obstacles and round-trips', () {
      final item = showcaseItems.firstWhere((it) => it.label == 'w19');
      final scene = loadShowcaseScene(item);
      expect(scene, isNotNull);

      final doc = scene!.document;
      final mainChar = doc.nodes.values.firstWhere(
        (n) => n.name == 'w19.character.main',
      );
      expect(
        mainChar.components.any((c) => c.type == 'characterController'),
        isTrue,
      );
      expect(
        mainChar.components.any((c) => c.type == 'collider'),
        isTrue,
      );

      final slopeChar = doc.nodes.values.firstWhere(
        (n) => n.name == 'w19.character.slope',
      );
      expect(
        slopeChar.components.any((c) => c.type == 'characterController'),
        isTrue,
      );

      final json = writeFsceneWithExtensions(doc);
      final decoded = readFsceneWithExtensions(json);
      final decodedMain = decoded.nodes.values.firstWhere(
        (n) => n.name == 'w19.character.main',
      );
      final cc = decodedMain.components.firstWhere(
        (c) => c.type == 'characterController',
      );
      expect((cc.properties['autostep'] as BoolValue).value, isTrue);
      expect((cc.properties['mass'] as DoubleValue).value, closeTo(25.0, 1e-6));
    });
  });
}
