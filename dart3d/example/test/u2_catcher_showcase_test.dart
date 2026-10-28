
import 'package:dart3d/dart3d.dart';
import 'package:dart3d_example/app_route.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:dart3d_example/u2_catcher_scene.dart';
import 'package:test/test.dart';

void main() {
  group('U2 baked shadow-catcher showcase', () {
    test('catalogue route builds the baked catcher fixture', () {
      final item = showcaseItems.singleWhere(
        (entry) => entry.label == 'u2-catcher',
      );
      expect(item.assetKey, kBuiltinU2CatcherKey);
      expect(AppRoute.boot(model: item.label).screen, AppScreen.showcase);

      final logs = <String>[];
      final scene = loadShowcaseScene(item, log: logs.add);
      expect(scene, isNotNull);
      final doc = scene!.document;
      final receiver = doc.nodes.values.singleWhere(
        (node) => node.name == 'u2.catcher.receiver',
      );
      final component = receiver.components.single;
      expect(component.type, 'd3:instances');
      final geometryId =
          (component.properties['geometry']! as ResourceRefValue).id;
      expect(
        (doc.resources[geometryId]! as GeometryResource).procedural,
        isA<PlaneGeometrySpec>(),
      );
      expect((component.properties['doubleSided']! as BoolValue).value, isTrue);
      expect(
        component.properties.containsKey('attributes'),
        kBootU2CatcherPath == u2CatcherPathInstanceColor,
      );
      final catcher = u2CatcherMaterial(doc);
      expect(catcher.type, 'shadowCatcher');
      expect((catcher.properties['mode']! as StringValue).value, 'baked');
      expect((catcher.properties['softness']! as DoubleValue).value, 0);
      final transform = receiver.transform as TrsTransform;
      expect(transform.translation.x, closeTo(0.10, 1e-6));
      expect(transform.translation.z, closeTo(-0.08, 1e-6));
      expect(transform.scale.z, closeTo(0.86, 1e-6));
      expect(
        doc.nodes.values.where(
          (node) => node.name.startsWith('u2.catcher.caster'),
        ),
        hasLength(2),
      );
      expect(
        doc.nodes.values
            .singleWhere((node) => node.name == 'u2.catcher.light')
            .components
            .single
            .type,
        _bootLight == 'directional' ||
                _bootLight == u2CatcherLightUnshadowedPrimary ||
                _bootLight == u2CatcherLightTied
            ? 'directionalLight'
            : 'spotLight',
      );
      expect(
        logs,
        contains(
          kBootU2CatcherPath == u2CatcherPathDirect
              ? 'dart3d: u2-catcher light=$_bootLight mode=baked softness=0'
              : 'dart3d: u2-catcher path=$kBootU2CatcherPath light=$_bootLight',
        ),
      );
      expect(
        doc.nodes.values.any((node) => node.name == 'showcase.slab'),
        isFalse,
      );
      expect(scene.summary, contains('Baked shadow footprint'));
    });

    test('builder supports a directional light boot fixture', () {
      final doc = buildU2CatcherDocument(light: 'directional');
      final light = doc.nodes.values.singleWhere(
        (node) => node.name == 'u2.catcher.light',
      );
      expect(light.components.single.type, 'directionalLight');
      expect(
        (light.components.single.properties['castsShadow']! as BoolValue).value,
        isTrue,
      );
    });

    test('dominant unshadowed directional competes with a casting light', () {
      final doc = buildU2CatcherDocument(
        light: u2CatcherLightUnshadowedPrimary,
      );
      final lights = doc.nodes.values
          .expand((node) => node.components)
          .where((component) => component.type == 'directionalLight')
          .toList();
      expect(lights, hasLength(2));
      final primary = lights.singleWhere(
        (component) =>
            (component.properties['intensity']! as DoubleValue).value == 3,
      );
      final secondary = lights.singleWhere(
        (component) =>
            (component.properties['intensity']! as DoubleValue).value == 1,
      );
      expect((primary.properties['castsShadow']! as BoolValue).value, isFalse);
      expect((secondary.properties['castsShadow']! as BoolValue).value, isTrue);
      expect(u2CatcherMaterial(doc).type, 'shadowCatcher');
    });

    test('tied directionals keep only the third light shadow-casting', () {
      final doc = buildU2CatcherDocument(light: u2CatcherLightTied);
      final lights = doc.nodes.values
          .expand((node) => node.components)
          .where((component) => component.type == 'directionalLight')
          .toList();
      expect(lights, hasLength(3));
      expect(
        lights.map((component) =>
            (component.properties['intensity']! as DoubleValue).value),
        [3, 3, 3],
      );
      expect(
        lights.map((component) =>
            (component.properties['castsShadow']! as BoolValue).value),
        [false, false, true],
      );
    });

    test('instance-color path carries one white catcher tint with alpha', () {
      final doc = buildU2CatcherDocument(path: u2CatcherPathInstanceColor);
      final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
      final instances = receiver.components.single;
      final attributes =
          (instances.properties['attributes']! as MapValue).values;
      final colors = (attributes['color']! as ListValue).values;

      expect(instances.type, 'd3:instances');
      expect(colors, hasLength(1));
      final color = (colors.single as Vec4Value).value;
      expect([color.x, color.y, color.z], [1, 1, 1]);
      expect(color.w, closeTo(0.65, 1e-6));
      expect(u2CatcherMaterial(doc).type, 'shadowCatcher');
      expect(
        (u2CatcherMaterial(doc).properties['mode']! as StringValue).value,
        'baked',
      );
    });

    test('public resource command accepts edits and identical refreshes', () {
      final item = showcaseItems.singleWhere(
        (entry) => entry.assetKey == kBuiltinU2CatcherKey,
      );
      final doc = loadShowcaseScene(item)!.document;
      final controller = SceneController()..loadDocument(doc);
      final baked = u2CatcherMaterial(doc);
      upsertU2CatcherMaterial(controller, doc, baked);
      final mirroredBaked =
          controller.document!.resources[baked.id]! as MaterialResource;
      expect(mirroredBaked.id, baked.id);
      expect(
        (mirroredBaked.properties['mode']! as StringValue).value,
        'baked',
      );
      expect(
        (mirroredBaked.properties['softness']! as DoubleValue).value,
        0,
      );

      final live = copyU2CatcherMaterial(mirroredBaked, mode: 'live');
      upsertU2CatcherMaterial(controller, doc, live);
      final mirroredLive =
          controller.document!.resources[live.id]! as MaterialResource;
      expect(mirroredLive.type, 'shadowCatcher');
      expect((mirroredLive.properties['mode']! as StringValue).value, 'live');

      upsertU2CatcherMaterial(controller, doc, mirroredLive);
      final mirroredRefresh =
          controller.document!.resources[live.id]! as MaterialResource;
      expect(mirroredRefresh.id, live.id);
      expect(
        (mirroredRefresh.properties['mode']! as StringValue).value,
        'live',
      );
      expect((mirroredRefresh.properties['softness']! as DoubleValue).value, 0);

      final softened = copyU2CatcherMaterial(
        mirroredRefresh,
        mode: 'baked',
        softness: 0.14,
      );
      upsertU2CatcherMaterial(controller, doc, softened);
      final mirroredSoftened =
          controller.document!.resources[softened.id]! as MaterialResource;
      expect(
        (mirroredSoftened.properties['mode']! as StringValue).value,
        'baked',
      );
      expect(
        (mirroredSoftened.properties['softness']! as DoubleValue).value,
        0.14,
      );
    });

    test('ordinary receiver resource can become a baked catcher by upsert', () {
      final doc = buildU2CatcherDocument(path: u2CatcherPathTypeUpsert);
      final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
      final instances = receiver.components.single;
      final geometryId =
          (instances.properties['geometry']! as ResourceRefValue).id;
      final materialId =
          (instances.properties['material']! as ResourceRefValue).id;
      final ordinary = doc.resources[materialId]! as MaterialResource;
      expect(ordinary.type, 'physicallyBased');
      expect(doc.resources[geometryId], isA<GeometryResource>());

      final controller = SceneController()..loadDocument(doc);
      upsertU2CatcherMaterial(
        controller,
        doc,
        copyU2CatcherMaterial(ordinary, type: 'shadowCatcher', mode: 'baked'),
      );

      final mirrored =
          controller.document!.resources[materialId]! as MaterialResource;
      expect(mirrored.type, 'shadowCatcher');
      expect((mirrored.properties['mode']! as StringValue).value, 'baked');
      expect(
        (controller
                    .document!
                    .nodes[receiver.id]!
                    .components
                    .single
                    .properties['geometry']!
                as ResourceRefValue)
            .id,
        geometryId,
      );
    });

    test('variant-default keeps the default material as the catcher target', () {
      final doc = buildU2CatcherDocument(path: u2CatcherPathVariantDefault);
      final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
      final instances = receiver.components.singleWhere(
        (component) => component.type == 'd3:instances',
      );
      final geometryId =
          (instances.properties['geometry']! as ResourceRefValue).id;
      final defaultId =
          (instances.properties['material']! as ResourceRefValue).id;
      final geometry = doc.resources[geometryId]! as GeometryResource;
      final plane = geometry.procedural! as PlaneGeometrySpec;
      final variants = receiver.components.singleWhere(
        (component) => component.type == 'materialsVariants',
      );
      final binding =
          ((variants.properties['bindings']! as ListValue).values.single
              as MapValue);
      final mappedId =
          (((binding.values['materials']! as MapValue).values['0']!
                  as ResourceRefValue)
              .id);
      final defaultColor =
          ((doc.resources[defaultId]! as MaterialResource).properties['baseColor']!
              as ColorValue);
      final mappedColor =
          ((doc.resources[mappedId]! as MaterialResource).properties['baseColor']!
              as ColorValue);

      expect(
        (instances.properties['doubleSided']! as BoolValue).value,
        isTrue,
      );
      expect(plane.width, greaterThan(0));
      expect(plane.depth, greaterThan(0));
      expect(
        (doc.resources[defaultId]! as MaterialResource).type,
        'physicallyBased',
      );
      expect(
        (doc.resources[mappedId]! as MaterialResource).type,
        'physicallyBased',
      );
      expect(mappedColor.r, isNot(defaultColor.r));
      expect(mappedId, isNot(defaultId));
      expect((binding.values['default']! as ResourceRefValue).id, defaultId);
      expect(
        (variants.properties['variants']! as ListValue).values
            .cast<StringValue>()
            .map((variant) => variant.value),
        [u2CatcherDefaultProbeVariant],
      );
      expect(u2CatcherMaterial(doc).id, defaultId);

      final controller = SceneController()
        ..loadDocument(
          buildU2CatcherDocument(path: u2CatcherPathVariantDefault),
        );
      final receiverId = receiver.id;
      final baked = copyU2CatcherMaterial(
        u2CatcherMaterial(doc),
        type: 'shadowCatcher',
        mode: 'baked',
      );
      upsertU2CatcherMaterial(controller, doc, baked);
      expect(
        (controller.document!.resources[defaultId]! as MaterialResource).type,
        'shadowCatcher',
      );
      expect(u2CatcherMaterial(controller.document!).id, defaultId);
      final mirroredReceiver = controller.document!.nodes[receiverId]!;
      final mirroredInstances = mirroredReceiver.components.singleWhere(
        (component) => component.type == 'd3:instances',
      );
      expect(
        (mirroredInstances.properties['material']! as ResourceRefValue).id,
        defaultId,
      );
      final mirroredVariants = mirroredReceiver.components.singleWhere(
        (component) => component.type == 'materialsVariants',
      );
      final mirroredBinding =
          ((mirroredVariants.properties['bindings']! as ListValue).values.single
              as MapValue);
      final mirroredMappedId =
          (((mirroredBinding.values['materials']! as MapValue).values['0']!
                  as ResourceRefValue)
              .id);
      expect(
        mirroredMappedId,
        mappedId,
      );

      upsertU2CatcherMaterial(
        controller,
        doc,
        copyU2CatcherMaterial(
          u2CatcherMaterial(controller.document!),
          type: 'physicallyBased',
        ),
      );
      expect(
        (controller.document!.resources[defaultId]! as MaterialResource).type,
        'physicallyBased',
      );
      expect(
        (controller.document!.resources[mappedId]! as MaterialResource).type,
        'physicallyBased',
      );
      expect(u2CatcherMaterial(controller.document!).id, defaultId);
    });

    test('camera-facing fixture keeps one baked billboard over nonzero bounds', () {
      final doc = buildU2CatcherDocument(path: u2CatcherPathCameraFacing);
      final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
      final receiverTransform = receiver.transform as TrsTransform;
      final instances = receiver.components.single;
      final geometryId =
          (instances.properties['geometry']! as ResourceRefValue).id;
      final materialId =
          (instances.properties['material']! as ResourceRefValue).id;
      final geometry = doc.resources[geometryId]! as GeometryResource;
      final plane = geometry.procedural! as PlaneGeometrySpec;
      final size = (instances.properties['size']! as Vec2Value).value;
      final transforms =
          (instances.properties['transforms']! as ListValue).values;
      final instanceTransform = transforms.single as Matrix4Value;
      final bounds = meshNodeWorldBounds(doc)[receiver.id]!;
      final item = showcaseItems.singleWhere(
        (entry) => entry.assetKey == kBuiltinU2CatcherKey,
      );
      final (cameraX, cameraY, cameraZ) = item.cameraDir!;

      expect(instances.type, 'd3:instances');
      expect((instances.properties['billboard']! as BoolValue).value, isTrue);
      expect(
        (instances.properties['doubleSided']! as BoolValue).value,
        isTrue,
      );
      expect(transforms, hasLength(1));
      expect(instanceTransform.value.getTranslation().x, 0);
      expect(instanceTransform.value.getTranslation().y, 0);
      expect(instanceTransform.value.getTranslation().z, 0);
      expect(size.x, greaterThan(0));
      expect(size.y, greaterThan(0));
      expect(plane.width, greaterThan(0));
      expect(plane.depth, greaterThan(0));
      expect(receiverTransform.rotation.x, 0);
      expect(receiverTransform.rotation.z, 0);
      expect(
        (doc.resources[materialId]! as MaterialResource).type,
        'shadowCatcher',
      );
      expect(
        ((doc.resources[materialId]! as MaterialResource).properties['mode']!
                as StringValue)
            .value,
        'baked',
      );
      expect(bounds.$2.x - bounds.$1.x, greaterThan(0));
      expect(bounds.$2.z - bounds.$1.z, greaterThan(0));
      expect(cameraX.abs(), greaterThan(0));
      expect(cameraY.abs(), greaterThan(0));
      expect(cameraZ.abs(), greaterThan(0));

    });

    test('resource-backed instance geometry upsert stays explicit-refresh', () {
      final doc = buildU2CatcherDocument(path: u2CatcherPathGeometryUpsert);
      final geometryId = u2CatcherGeometryId(doc);
      final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
      final instances = receiver.components.single;
      expect(instances.type, 'd3:instances');
      expect(
        (instances.properties['geometry']! as ResourceRefValue).id,
        geometryId,
      );
      expect((instances.properties['doubleSided']! as BoolValue).value, isTrue);

      final controller = SceneController()..loadDocument(doc);
      final original = doc.resources[geometryId]! as GeometryResource;
      upsertU2CatcherGeometry(
        controller,
        doc,
        copyU2CatcherGeometry(original, width: 4.45),
      );
      final mirroredGeometry =
          controller.document!.resources[geometryId]! as GeometryResource;
      expect((mirroredGeometry.procedural! as PlaneGeometrySpec).width, 4.45);

      final catcher = u2CatcherMaterial(doc);
      upsertU2CatcherMaterial(controller, doc, catcher);
      final refreshed =
          controller.document!.resources[catcher.id]! as MaterialResource;
      expect(refreshed.type, 'shadowCatcher');
      expect((refreshed.properties['mode']! as StringValue).value, 'baked');
    });

    test('variant and LOD fixtures expose their catcher material slots', () {
      final variantDoc = buildU2CatcherDocument(path: u2CatcherPathVariant);
      final variantReceiver =
          variantDoc.nodes[u2CatcherReceiverId(variantDoc)]!;
      final instances = variantReceiver.components.singleWhere(
        (component) => component.type == 'd3:instances',
      );
      final baseMaterialId =
          (instances.properties['material']! as ResourceRefValue).id;
      expect(
        (variantDoc.resources[baseMaterialId]! as MaterialResource).type,
        'physicallyBased',
      );
      final variants = variantReceiver.components.singleWhere(
        (component) => component.type == 'materialsVariants',
      );
      final binding =
          ((variants.properties['bindings']! as ListValue).values.single
              as MapValue);
      final variantMaterialId =
          (((binding.values['materials']! as MapValue).values['0']!
                  as ResourceRefValue)
              .id);
      expect(variantMaterialId, u2CatcherMaterial(variantDoc).id);
      expect(encodeSelectVariantCommand(variantReceiver.id, 'catcher'), {
        'op': 'selectVariant',
        'node': variantReceiver.id.toToken(),
        'selected': 'catcher',
      });
      final variantController = SceneController()..loadDocument(variantDoc);
      selectU2CatcherVariant(variantController, variantDoc, 'catcher');
      selectU2CatcherVariant(variantController, variantDoc, null);

      final lodDoc = buildU2CatcherDocument(path: u2CatcherPathLod);
      final lodReceiver = lodDoc.nodes[u2CatcherReceiverId(lodDoc)]!;
      final lod = lodReceiver.components.single;
      expect(lod.type, 'lod');
      final levels = (lod.properties['levels']! as ListValue).values
          .cast<MapValue>();
      expect(levels, hasLength(2));
      expect(
        levels
            .map((level) => (level.values['material']! as ResourceRefValue).id)
            .toList(),
        [u2CatcherMaterial(lodDoc).id, u2CatcherMaterial(lodDoc).id],
      );
      expect(
        levels
            .map((level) => (level.values['geometry']! as ResourceRefValue).id)
            .toSet(),
        hasLength(2),
      );
      expect(
        (levels.first.values['screenSize']! as DoubleValue).value,
        greaterThan((levels.last.values['screenSize']! as DoubleValue).value),
      );
      expect((levels.last.values['screenSize']! as DoubleValue).value, 0);
    });

  });
}

const String _bootLight = String.fromEnvironment(
  'DART3D_CATCHER_LIGHT',
  defaultValue: 'spot',
);
