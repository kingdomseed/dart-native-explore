// The dice-table + showcase document builders against the real bundled
// assets: `buildDiceTable` composes six `.fsceneb` prefabs host-side
// through upstream `composeScene` (id remap, addedComponents delta)
// plus the procedural shard d4, and `loadShowcaseScene` decodes
// the wider upstream corpus (skins, animations, textures, prefab
// references). Same constraint as the codec fixture: pure-Dart
// libraries only — `package:dart3d/dart3d.dart` needs DartNative's
// patched SDK — so the tests pull `dice_table_scene.dart` /
// `showcase_loader.dart` directly.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d_example/dice_table_scene.dart';
import 'package:dart3d_example/dn_logo_stage.dart';
import 'package:dart3d_example/showcase_loader.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

Uint8List? bytesFromDisk(String key) {
  final file = File(key);
  return file.existsSync() ? file.readAsBytesSync() : null;
}

void main() {
  group('buildDiceTable', () {
    test('builds on a background isolate', () async {
      final (scene, log) = await buildDiceTableInBackground(
        logo: bytesFromDisk(kLogoAsset),
      );
      expect(scene!.dice.map((d) => d.label), kDiceOrder);
      expect(scene.dice.every((d) => d.logo != null), isTrue);
      expect(log.single, contains('7 DartNative dice (logo inside)'));
    });

    test('composes seven dice with physics', () {
      final scene = buildDiceTable(bytesFor: bytesFromDisk)!;
      final doc = scene.document;

      expect(scene.dice.map((d) => d.label), kDiceOrder);
      // Prefab expansion is complete — no instance nodes remain.
      for (final node in doc.nodes.values) {
        expect(node.instance, isNull, reason: '${node.name} unexpanded');
      }
      // Each die node carries its mesh and the physics components.
      for (final die in scene.dice) {
        final node = doc.nodes[die.node];
        expect(node, isNotNull, reason: '${die.label} missing');
        final types = node!.components.map((c) => c.type).toSet();
        expect(
          types,
          containsAll(['mesh', 'collider', 'rigidBody']),
          reason: '${die.label} components: $types',
        );
        expect(die.faceMap.faces, isNotEmpty, reason: die.label);
        final body = node.components.firstWhere((c) => c.type == 'rigidBody');
        expect((body.properties['ccdEnabled'] as BoolValue).value, isTrue);
      }
      // 7 dice × (vertices, indices, atlas) + the rim's gradient and 8
      // pieces × 2 + the logo's payloads, once.
      final logo = readFsceneb(bytesFromDisk(kLogoAsset)!);
      expect(doc.payloads, hasLength(7 * 3 + 1 + 8 * 2 + logo.payloads.length));
      // Tray: felt slab + 8 rim pieces + 4 walls + ceiling + world.
      expect(
        doc.nodes.values.where((n) => n.name.startsWith('tray.')),
        hasLength(15),
      );
      expect(scene.rimNodes, hasLength(8));
      // A logo inside every die, all sharing one mesh.
      final meshes = <String>{};
      for (final die in scene.dice) {
        expect(die.logo, isNotNull, reason: die.label);
        expect(doc.nodes[die.node]!.children, contains(die.logo));
        final mesh = doc.nodes[die.logo]!.components.firstWhere(
          (c) => c.type == 'mesh',
        );
        meshes.add('${(mesh.properties['geometry'] as ResourceRefValue).id}');
        // Held level, reading side up, at rest.
        final t = doc.nodes[die.node]!.transform as TrsTransform;
        // (The instanced logo's transform composes to a matrix.)
        final world =
            t.toMatrix4() * doc.nodes[die.logo]!.transform.toMatrix4();
        final front = world.rotated3(Vector3(0, 0, -1))..normalize();
        expect(front.y, closeTo(1, 1e-4), reason: die.label);
        // Centred in the die (the prefab root's lift must not leak in).
        expect(
          doc.nodes[die.logo]!.transform.toMatrix4().getTranslation().length,
          closeTo(0, 1e-6),
          reason: die.label,
        );
      }
      expect(meshes, hasLength(1));
      expect(scene.wallNodes, hasLength(4));
      expect(doc.stage.environmentRef, isNotNull);
      expect(doc.nodes[scene.cameraNode], isNotNull);
      expect(scene.dice.map((d) => d.node).toSet(), hasLength(7));
      // Dice start racked inside the play area, resting on the table.
      for (final die in scene.dice) {
        final t = doc.nodes[die.node]!.transform as TrsTransform;
        expect(
          scene.layout.contains(t.translation, slack: -die.radius * 0.5),
          isTrue,
          reason: '${die.label} at ${t.translation}',
        );
        expect(t.translation.y, closeTo(die.restY, 1e-6));
        // Racked squarely face up, so a reset never tips a die over.
        expect(
          die.faceMap.top(t.rotation).$2,
          closeTo(1.0, 1e-5),
          reason: die.label,
        );
        expect(die.restY, inInclusiveRange(4.0, 12.0), reason: die.label);
        // Racked highest number up.
        expect(
          die.faceMap.read(t.rotation),
          die.faceMap.faces.map((f) => f.value).reduce(max),
        );
      }
    });
  });

  group('loadShowcaseScene', () {
    ShowcaseScene load(String label) {
      final item = showcaseItems.firstWhere((i) => i.label == label);
      final scene = loadShowcaseScene(item, bytesFor: bytesFromDisk);
      expect(scene, isNotNull, reason: '$label failed to load');
      return scene!;
    }

    test('dash: skinned, textured, 9 animations', () {
      final doc = load('dash').document;
      expect(doc.skins, hasLength(1));
      expect(doc.animations, hasLength(9));
      expect(doc.resources.values.whereType<TextureResource>(), hasLength(2));
      // Image payloads decoded with the document.
      final images = doc.payloads.values.where(
        (p) => p.encoding == PayloadEncoding.image,
      );
      expect(images, hasLength(2));
      for (final p in images) {
        expect(p.bytes, isNotNull);
        expect(p.format, 'rgba8');
      }
    });

    test('fcar: multi-mesh multi-material', () {
      final doc = load('fcar').document;
      // 17 imported mesh nodes + the loader's shadow slab.
      expect(
        doc.nodes.values.where(
          (n) =>
              n.name != 'showcase.slab' &&
              n.components.any((c) => c.type == 'mesh'),
        ),
        hasLength(17),
      );
      expect(
        doc.resources.values.whereType<MaterialResource>().length,
        greaterThanOrEqualTo(11),
      );
    });

    test('prefab_demo: two tree instances expand', () {
      final doc = load('prefabs').document;
      for (final node in doc.nodes.values) {
        expect(node.instance, isNull);
      }
      // Ground + two expanded trees (Trunk+Foliage each) + the
      // loader's shadow slab.
      expect(
        doc.nodes.values.where(
          (n) =>
              n.name != 'showcase.slab' &&
              n.components.any((c) => c.type == 'mesh'),
        ),
        hasLength(5),
      );
      // Each instance kept its grafted children.
      final trees = doc.nodes.values.where((n) => n.name.startsWith('Tree'));
      for (final t in trees) {
        expect(t.children, hasLength(2), reason: '${t.name} children');
      }
    });

    test('dartnative_logo: one mesh, one 1024² texture, the Spin clip', () {
      // Leads the roster — the Showcase opens on it.
      expect(showcaseItems.first.label, 'dartnative_logo');
      final scene = load('dartnative_logo');
      final doc = scene.document;
      final meshNodes = doc.nodes.values.where(
        (n) =>
            n.name != 'showcase.slab' &&
            n.components.any((c) => c.type == 'mesh'),
      );
      expect(meshNodes, hasLength(1));
      expect(meshNodes.single.name, 'DartNativeLogo');
      expect(doc.animations, hasLength(1));
      expect(doc.animations.values.single.name, 'Spin');
      expect(doc.resources.values.whereType<TextureResource>(), hasLength(1));
      final image = doc.payloads.values.singleWhere(
        (p) => p.encoding == PayloadEncoding.image,
      );
      expect(image.format, 'rgba8');
      expect(image.bytes!.length, 1024 * 1024 * 4);
      // Triangle budget (< 20k) from the uint16/uint32 index payloads.
      var indices = 0;
      for (final p in doc.payloads.values) {
        if (p.encoding != PayloadEncoding.indexBuffer) continue;
        indices += p.bytes!.length ~/ (p.format == 'uint32' ? 4 : 2);
      }
      expect(indices ~/ 3, inInclusiveRange(1, 20000));
      // Glossy clear-coated material; the stage reuses the base-color
      // texture as a faint emissive (no second image payload).
      final mat = doc.resources.values.whereType<MaterialResource>().firstWhere(
        (m) => m.name == 'DartNativeLogo',
      );
      expect(mat.properties['clearcoat'], isA<DoubleValue>());
      expect(
        mat.properties['emissiveTexture'],
        mat.properties['baseColorTexture'],
      );
      // Authored face-on framing from the reading (−Z) side, with
      // breathing room over the bounds radius.
      expect(scene.cameraDir.z, lessThan(-0.9));
      expect(scene.frameRadius, greaterThan(1.3));
      // Dramatic stage: bloom on, dark gradient sky, pink + cyan rims.
      final env =
          doc.resources[doc.stage.environmentRef]! as EnvironmentResource;
      expect(env.effects.bloomEnabled, isTrue);
      expect(env.skybox?.source, isA<GradientSkySpec>());
      expect(
        doc.nodes.values.where((n) => n.name.startsWith('showcase.rim.')),
        hasLength(2),
      );
      expect(
        doc.nodes.values.where((n) => n.name == 'showcase.slab'),
        hasLength(1),
      );
      expect(env.effects.vignetteEnabled, isTrue);
    });

    test('dartnative_logo reel stage: no slab, no vignette, flat sky', () {
      final item = showcaseItems.first;
      final scene = loadShowcaseScene(
        ShowcaseItem(
          item.label,
          item.assetKey,
          'reel',
          cameraDir: item.cameraDir,
          stage: DnLogoStage.reel,
        ),
        bytesFor: bytesFromDisk,
      )!;
      final doc = scene.document;
      expect(doc.nodes.values.where((n) => n.name == 'showcase.slab'), isEmpty);
      final env =
          doc.resources[doc.stage.environmentRef]! as EnvironmentResource;
      expect(env.effects.vignetteEnabled, isFalse);
      expect(env.effects.bloomEnabled, isTrue);
      expect(env.exposure, DnLogoStage.reel.exposure);
      final sky = env.skybox!.source as GradientSkySpec;
      expect(sky.zenithColor, sky.horizonColor);
      expect(sky.groundColor, sky.horizonColor);
    });

    test('two_triangles: minimal skin + 2 animations', () {
      final doc = load('triangles').document;
      expect(doc.skins, hasLength(1));
      expect(doc.animations, hasLength(2));
    });

    test('prefabs: framing excludes the authored ground slab', () {
      final scene = load('prefabs');
      // Two trees at ±2 units — the frame tracks the content, not the
      // 16-unit authored Ground plane.
      expect(scene.frameRadius, lessThan(6));
      expect(scene.frameRadius, greaterThan(1));
    });

    test('cube: procedural bounds feed the frame', () {
      final scene = load('cube');
      // A 1-unit cuboid — bounds derive from the spec, no fallback.
      expect(scene.frameRadius, closeTo(sqrt(3) / 2, 0.01));
    });

    test('playground: framing follows the primitives', () {
      final scene = load('playground');
      // Box + ball + tower within ±2 — not the 12-unit Floor.
      expect(scene.frameRadius, lessThan(6));
    });

    // W21: the `.fscene` text path normalizes the upstream `n` light
    // field at load (the `.fsceneb` path does it inside readFsceneb).
    test('.fscene light field n normalizes to intensity at load', () {
      final doc = SceneDocument();
      doc.addNode(
        NodeSpec(
          id: const LocalId(9, 7),
          name: 'sun',
          components: [
            ComponentSpec(
              'directionalLight',
              properties: {
                // White 1.0-lux glTF directional → n = 1/683.
                'n': DoubleValue(1.0 / 683.0),
                'color': Vec3Value(Vector3(1, 1, 1)),
              },
            ),
          ],
        ),
        root: true,
      );
      const item = ShowcaseItem('nlight', 'test/nlight.fscene', 'n field');
      final scene = loadShowcaseScene(
        item,
        bytesFor: (key) =>
            key == item.assetKey ? utf8.encode(writeFscene(doc)) : null,
      );
      expect(scene, isNotNull);
      final light = scene!.document.nodes.values.firstWhere(
        (n) => n.name == 'sun',
      );
      final props = light.components.single.properties;
      expect(
        (props['intensity'] as DoubleValue).value,
        closeTo(kGltfToSceneKitLightScale, 1),
      );
    });

    // W21 conformance lane: the builtin materials scene carries the
    // blend/mask/UV-set surfaces the native realizers realize.
    test('materials: builtin scene carries the W21 lanes', () {
      final scene = load('materials');
      final doc = scene.document;

      MaterialResource materialOf(String name) {
        final node = doc.nodes.values.firstWhere(
          (n) => n.name == name,
          orElse: () => throw StateError('node $name missing'),
        );
        final mesh = node.components.singleWhere((c) => c.type == 'mesh');
        final matId = (mesh.properties['material'] as ResourceRefValue).id;
        return doc.resources[matId]! as MaterialResource;
      }

      // Blend lane: alphaMode blend + fractional-alpha baseColor.
      final blend = materialOf('materials.blend').properties;
      expect((blend['alphaMode'] as StringValue).value, 'blend');
      expect((blend['baseColor'] as ColorValue).a, lessThan(1.0));
      // An opaque control and a backdrop sit beside it.
      expect(
        materialOf('materials.opaque').properties.containsKey('alphaMode'),
        isFalse,
      );
      expect(
        materialOf('materials.backdrop').properties['baseColorTexture'],
        isA<ResourceRefValue>(),
      );

      // Mask lane: alphaMode mask + cutoff over a real alpha texture —
      // the lattice payload is attached rgba8.
      final mask = materialOf('materials.mask').properties;
      expect((mask['alphaMode'] as StringValue).value, 'mask');
      expect((mask['alphaCutoff'] as DoubleValue).value, 0.5);
      final maskTex =
          doc.resources[(mask['baseColorTexture'] as ResourceRefValue).id]!
              as TextureResource;
      final maskPixels = doc.payload(maskTex.payload!)!;
      expect(maskPixels.format, 'rgba8');
      // The lattice really has holes — some texels at a=0, some a=255.
      final alphas = <int>{};
      final bytes = maskPixels.bytes!;
      for (var i = 3; i < bytes.length; i += 4) {
        alphas.add(bytes[i]);
      }
      expect(alphas, containsAll([0, 255]));

      // UV-set lane: the uv1 twin's texture transform selects set 1,
      // and its vertex payload really carries a nonzero uv1 channel.
      final uv1 = materialOf('materials.uv1').properties;
      final transform = (uv1['baseColorTextureTransform'] as MapValue).values;
      expect((transform['texCoord'] as IntValue).value, 1);
      final uv1Node = doc.nodes.values.firstWhere(
        (n) => n.name == 'materials.uv1',
      );
      final geoId =
          (uv1Node.components
                      .singleWhere((c) => c.type == 'mesh')
                      .properties['geometry']
                  as ResourceRefValue)
              .id;
      final geo = doc.resources[geoId]! as GeometryResource;
      final verts = doc.payload(geo.vertices!)!;
      expect(verts.layout, 'unskinned_uv1_tangent');
      // uv1 sits at floats 8-9 of the 72 B interleave — nonzero here.
      final uv1u = ByteData.sublistView(
        verts.bytes!,
      ).getFloat32(8 * 4, Endian.little);
      expect(uv1u, closeTo(0.19, 1e-6));

      // KTX2 lane: the quad's texture payload is a real bundled .ktx2
      // (the test VM takes the non-iOS asset pick — ETC1S).
      final ktx2 = materialOf('materials.ktx2').properties;
      final ktx2Tex =
          doc.resources[(ktx2['baseColorTexture'] as ResourceRefValue).id]!
              as TextureResource;
      final ktx2Payload = doc.payload(ktx2Tex.payload!)!;
      expect(ktx2Payload.format, 'ktx2');
      expect(ktx2Payload.bytes!.length, greaterThan(80));
      // KTX2 magic «KTX 20».
      expect(ktx2Payload.bytes!.sublist(1, 7), 'KTX 20'.codeUnits);

      // HDR env lane: the payload environment resolves to a real
      // equirect file (hdr on this host — non-iOS pick).
      final envRes =
          doc.resources[doc.stage.environmentRef]! as EnvironmentResource;
      expect(envRes.environment, isA<PayloadEnvironment>());
      final envPayload = doc.payload(
        (envRes.environment as PayloadEnvironment).payload,
      )!;
      expect(envPayload.format, 'hdr');
      expect(envPayload.bytes, isNotEmpty);
    });
  });
}
