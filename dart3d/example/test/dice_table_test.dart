// The dice-table + showcase document builders against the real bundled
// assets: `buildDiceTable` composes seven `.fsceneb` prefabs host-side
// through upstream `composeScene` (id remap, addedComponents delta,
// resolver-injected materialsVariants), and `loadShowcaseScene` decodes
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
import 'package:dart3d_example/showcase_loader.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

Uint8List? bytesFromDisk(String key) {
  final file = File(key);
  return file.existsSync() ? file.readAsBytesSync() : null;
}

void main() {
  group('loadDiceFaceMaps', () {
    test('parses all seven dice with rollable faces', () {
      final maps = loadDiceFaceMaps(bytesFor: bytesFromDisk);
      expect(maps.keys, containsAll(['d4', 'd6', 'd8', 'd10t', 'd10u', 'd12', 'd20']));
      expect(maps['d6']!.faces, hasLength(6));
      expect(maps['d20']!.faces, hasLength(20));
      expect(maps['d10u']!.faces, hasLength(10));
      for (final map in maps.values) {
        expect(map.resultSide, 'up');
        for (final f in map.faces) {
          expect(f.normal.length, closeTo(1.0, 0.01));
        }
      }
    });

    test('read() reports the up face', () {
      final maps = loadDiceFaceMaps(bytesFor: bytesFromDisk);
      final d6 = maps['d6']!;
      // Identity rotation — whatever value the generator put on +Y.
      final top = d6.faces
          .reduce((a, b) => a.normal.y > b.normal.y ? a : b)
          .value;
      expect(d6.read(Quaternion.identity()), top);
      // Flip 180° about X — the bottom face comes up; standard dice
      // sum opposites to 7.
      final flipped = Quaternion.axisAngle(Vector3(1, 0, 0), pi);
      expect(d6.read(flipped), 7 - top);
    });
  });

  group('buildDiceTable', () {
    test('composes seven dice with physics + selection variants', () {
      final scene = buildDiceTable(bytesFor: bytesFromDisk)!;
      final doc = scene.document;

      expect(scene.dice, hasLength(7));
      // Prefab expansion is complete — no instance nodes remain.
      for (final node in doc.nodes.values) {
        expect(node.instance, isNull, reason: '${node.name} unexpanded');
      }
      // Each die node carries the addedComponents physics delta plus
      // the resolver-injected materialsVariants.
      for (final die in scene.dice) {
        final node = doc.nodes[die.node];
        expect(node, isNotNull, reason: '${die.label} missing');
        final types = node!.components.map((c) => c.type).toSet();
        expect(types, containsAll(['mesh', 'collider', 'rigidBody', 'materialsVariants']),
            reason: '${die.label} components: $types');
        // The variants binding targets the composed node itself.
        final variants = node.components
            .firstWhere((c) => c.type == 'materialsVariants');
        final bindings =
            (variants.properties['bindings'] as ListValue).values;
        expect(bindings, hasLength(2)); // shell + numeral inlay
        for (final b in bindings) {
          final m = (b as MapValue).values;
          expect((m['node'] as NodeRefValue).id, die.node);
        }
      }
      // Tray: wood slab + 4 invisible walls + world + camera + 2 lights.
      expect(doc.payloads, hasLength(29)); // 7 dice × 4 + wood texture
      expect(
        doc.nodes.values.where((n) => n.name.startsWith('tray.')),
        hasLength(6),
      );
      expect(doc.stage.environmentRef, isNotNull);
      expect(doc.nodes[scene.cameraNode], isNotNull);
      // Dice ids survive composition as the instance ids — the tap
      // raycast resolves them directly.
      expect(
        scene.dice.map((d) => d.node).toSet(),
        hasLength(7),
      );
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
      expect(
        doc.resources.values.whereType<TextureResource>(),
        hasLength(2),
      );
      // Image payloads decoded with the document.
      final images = doc.payloads.values
          .where((p) => p.encoding == PayloadEncoding.image);
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

    test('logo: texture + animation', () {
      final doc = load('logo').document;
      expect(doc.animations, hasLength(1));
      expect(
        doc.resources.values.whereType<TextureResource>(),
        hasLength(1),
      );
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
        bytesFor: (key) => key == item.assetKey
            ? utf8.encode(writeFscene(doc))
            : null,
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
      final transform =
          (uv1['baseColorTextureTransform'] as MapValue).values;
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
      final envRes = doc.resources[doc.stage.environmentRef]!
          as EnvironmentResource;
      expect(envRes.environment, isA<PayloadEnvironment>());
      final envPayload =
          doc.payload((envRes.environment as PayloadEnvironment).payload)!;
      expect(envPayload.format, 'hdr');
      expect(envPayload.bytes, isNotEmpty);
    });
  });
}
