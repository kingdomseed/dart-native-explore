// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:math' as math;

import 'package:dart3d/src/diff_apply.dart' show writeFsceneWithExtensions;
import 'package:dart3d/src/geometry/proc.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/world_bounds.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u2_geometry_scene.dart';
import 'package:test/test.dart';

const bool _bootCastsShadow = bool.fromEnvironment(
  'DART3D_U2_CAST_SHADOWS',
  defaultValue: true,
);

void main() {
  group('U2 spot-shadow showcase', () {
    test('catalogue route builds one spot and uses the boot flag', () {
      final item = showcaseItems.singleWhere(
        (entry) => entry.label == 'u2-shadow',
      );
      expect(item.assetKey, kBuiltinU2ShadowKey);
      expect(AppRoute.boot(model: item.label).screen, AppScreen.showcase);

      final logs = <String>[];
      final scene = loadShowcaseScene(item, log: logs.add);
      expect(scene, isNotNull);
      final repeatedScene = loadShowcaseScene(item)!;

      final doc = scene!.document;
      expect(repeatedScene.cameraNode, scene.cameraNode);
      expect(
        _wireWithoutCastFlag(repeatedScene.document),
        _wireWithoutCastFlag(doc),
      );
      final spotNodes = doc.nodes.values
          .where(
            (node) => node.components.any(
              (component) => component.type == 'spotLight',
            ),
          )
          .toList();
      expect(spotNodes.map((node) => node.name), ['u2.shadow.spot']);
      expect(
        (spotNodes.single.components.single.properties['castsShadow']!
                as BoolValue)
            .value,
        _bootCastsShadow,
      );
      expect(logs, contains('dart3d: u2-shadow castsShadow=$_bootCastsShadow'));
      expect(scene.summary, 'Spot shadow · elevated cuboid · neutral receiver');
      expect(scene.cameraTarget.y, lessThan(0));
      expect(scene.cameraDir.length, closeTo(1, 1e-6));
      expect(
        doc.nodes.values.any((node) => node.name == 'showcase.slab'),
        isFalse,
      );
      expect(
        doc.nodes.values.any((node) => node.name == 'showcase.key'),
        isFalse,
      );
    });

    test('off and on documents differ only in the spot cast flag', () {
      final off = buildU2ShadowDocument(castsShadow: false);
      final on = buildU2ShadowDocument(castsShadow: true);

      expect(off.documentId, on.documentId);
      expect(off.nodes.keys, on.nodes.keys);
      expect(off.resources.keys, on.resources.keys);
      expect(_wireWithoutCastFlag(off), _wireWithoutCastFlag(on));
    });

    test('receiver, caster, and spot aim share the same fixture geometry', () {
      final doc = buildU2ShadowDocument(castsShadow: true);
      final receiver = doc.nodes.values.singleWhere(
        (node) => node.name == 'u2.shadow.receiver',
      );
      final receiverMesh = receiver.components.single;
      expect(receiverMesh.type, kD3ProcMeshType);
      expect((receiverMesh.properties['shape']! as StringValue).value, 'plane');
      final receiverMaterialId =
          (receiverMesh.properties['material']! as ResourceRefValue).id;
      final receiverMaterial =
          doc.resources[receiverMaterialId]! as MaterialResource;
      final receiverColor =
          receiverMaterial.properties['baseColor']! as ColorValue;
      expect(
        [receiverColor.r, receiverColor.g, receiverColor.b],
        [0.48, 0.48, 0.48],
      );

      final caster = doc.nodes.values.singleWhere(
        (node) => node.name == 'u2.shadow.caster',
      );
      final casterMesh = caster.components.single;
      expect(casterMesh.type, kD3ProcMeshType);
      expect((casterMesh.properties['shape']! as StringValue).value, 'cuboid');
      final casterExtents =
          (casterMesh.properties['extents']! as Vec3Value).value;
      final casterTranslation = (caster.transform as TrsTransform).translation;
      expect(casterTranslation.y - casterExtents.y / 2, closeTo(0, 1e-6));
      expect(casterTranslation.y + casterExtents.y / 2, greaterThan(0));

      final bounds = documentContentBounds(doc)!;
      expect(bounds.$1.x, closeTo(-2.1, 1e-6));
      expect(bounds.$2.x, closeTo(2.1, 1e-6));
      expect(bounds.$1.y, closeTo(0, 1e-6));
      expect(bounds.$2.y, closeTo(1.4, 1e-6));

      final spot = doc.nodes.values.singleWhere(
        (node) => node.name == 'u2.shadow.spot',
      );
      final spotComponent = spot.components.single;
      final properties = spotComponent.properties;
      final wireDirection = (properties['direction']! as Vec3Value).value;
      expect([wireDirection.x, wireDirection.y, wireDirection.z], [0, 0, 1]);
      expect((properties['intensity']! as DoubleValue).value, 100);
      expect((properties['range']! as DoubleValue).value, 12);
      final inner = (properties['innerConeAngle']! as DoubleValue).value;
      final outer = (properties['outerConeAngle']! as DoubleValue).value;
      expect(inner, lessThan(outer));
      expect(outer, lessThan(math.pi / 2));

      final spotTransform = spot.transform as TrsTransform;
      final aimedAtReceiver =
          spotTransform.rotation.asRotationMatrix() * wireDirection;
      final directionToReceiver = -spotTransform.translation.normalized();
      expect(aimedAtReceiver.distanceTo(directionToReceiver), lessThan(1e-6));
      expect(spotTransform.translation.y, greaterThan(bounds.$2.y));
    });
  });
}

Map<String, Object?> _wireWithoutCastFlag(SceneDocument doc) {
  final wire =
      jsonDecode(writeFsceneWithExtensions(doc)) as Map<String, Object?>;
  final nodes = wire['nodes']! as Map<String, Object?>;
  final spot = nodes.values.cast<Map<String, Object?>>().singleWhere(
    (node) => node['name'] == 'u2.shadow.spot',
  );
  final spotComponent = (spot['components']! as List)
      .cast<Map<String, Object?>>()
      .singleWhere((component) => component['type'] == 'spotLight');
  (spotComponent['properties']! as Map<String, Object?>).remove('castsShadow');
  return wire;
}
