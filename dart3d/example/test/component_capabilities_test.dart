// W12 checks: the `selectVariant` op wire shape and the
// `featuresRequired`/`featuresUsed` capability pass — pinned by
// docs/extended-surface-program.md §W12. Same constraint as the
// W3–W11 tests: package:dart3d/dart3d.dart is unreachable under
// `dart test` (the barrel transitively imports package:dartnative,
// which needs DartNative's patched SDK), so this pulls the pure-Dart
// libraries directly. `SceneController.selectMaterialVariant` is a
// thin wrapper over encodeSelectVariantCommand, and its feature pass
// logs each unrealizedFeatureWarnings line — those are what these
// assertions exercise.
// ignore_for_file: implementation_imports

import 'package:dart3d/src/components.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';

void main() {
  const nodeId = LocalId(7, 42);

  group('encodeSelectVariantCommand', () {
    test('carries the op, node token and variant name', () {
      expect(encodeSelectVariantCommand(nodeId, 'alert'), {
        'op': 'selectVariant',
        'node': nodeId.toToken(),
        'selected': 'alert',
      });
    });

    test('null selection re-applies defaults', () {
      expect(encodeSelectVariantCommand(nodeId, null), {
        'op': 'selectVariant',
        'node': nodeId.toToken(),
        'selected': null,
      });
    });
  });

  group('unrealizedFeatureWarnings', () {
    test('silent when every required feature is realized', () {
      final doc = SceneDocument()
        ..featuresRequired.addAll({'skinning', 'materialsVariants'});
      expect(unrealizedFeatureWarnings(doc), isEmpty);
    });

    test('required features warn as degradation with the plan wave', () {
      final doc = SceneDocument()..featuresRequired.add('streaming');
      expect(unrealizedFeatureWarnings(doc), [
        allOf(
          contains("requires feature 'streaming'"),
          contains('planned W15'),
          contains('may be degraded'),
        ),
      ]);
    });

    test('used-only features warn as advisories', () {
      final doc = SceneDocument()..featuresUsed.add('prefabInstances');
      expect(unrealizedFeatureWarnings(doc), [
        allOf(
          contains("uses feature 'prefabInstances'"),
          contains('planned W15'),
          isNot(contains('may be degraded')),
        ),
      ]);
    });

    test('an unplanned feature warns without a wave name', () {
      final doc = SceneDocument()..featuresRequired.add('gaussianSplats');
      expect(unrealizedFeatureWarnings(doc), [
        allOf(
          contains("requires feature 'gaussianSplats'"),
          isNot(contains('planned')),
        ),
      ]);
    });

    test('a feature in both sets warns once, as required', () {
      final doc = SceneDocument()
        ..featuresRequired.add('prefabInstances')
        ..featuresUsed.add('prefabInstances');
      expect(unrealizedFeatureWarnings(doc), hasLength(1));
    });
  });
}
