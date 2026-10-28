library;

import 'dart:async';
import 'dart:math' as math;

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';
import 'u3_atlas_probe.dart';

const kBootU3SpriteBlend = String.fromEnvironment(
  'DART3D_SPRITE_BLEND',
  defaultValue: 'alpha',
);
const kBootU3SpriteTint = bool.fromEnvironment('DART3D_SPRITE_TINT');
const kBootU3SpriteUntextured = bool.fromEnvironment(
  'DART3D_SPRITE_UNTEXTURED',
);
const kBootU3SpriteRenderTexture = bool.fromEnvironment('DART3D_SPRITE_RT');

NodeSpec u3SpriteNode(SceneDocument doc, String name) =>
    doc.nodes.values.singleWhere((node) => node.name == 'u3.sprite.$name');

MaterialResource u3SelectedSpriteMaterial(SceneDocument doc) => doc
    .resources
    .values
    .whereType<MaterialResource>()
    .singleWhere((material) => material.name == 'u3.sprite.selected');

SceneDocument buildU3SpriteDocument({
  D3SpriteBlendMode blend = D3SpriteBlendMode.alpha,
  bool tinted = false,
  bool untextured = false,
  bool renderTexture = false,
}) {
  final doc = buildU3AtlasProbeDocument();
  for (final node in doc.nodes.values) {
    node.name = node.name.replaceFirst('u3.atlas.', 'u3.sprite.');
  }
  final pixels = doc.payloads.values.single.bytes!;
  for (var y = 0; y < u3ProbeAtlas.height; y++) {
    for (var x = 0; x < u3ProbeAtlas.width; x++) {
      final localY = (y % 20 - 2).clamp(0, 15);
      final p = (y * u3ProbeAtlas.width + x) * 4;
      final mark =
          (pixels[p] == 255 && pixels[p + 1] == 255 && pixels[p + 2] == 255) ||
          (pixels[p] == 0 && pixels[p + 1] == 0 && pixels[p + 2] == 0);
      pixels[p + 3] = mark ? 255 : (localY < 5 ? 0 : (localY < 10 ? 128 : 255));
    }
  }
  final sheet = doc.resources.values.whereType<MaterialResource>().singleWhere(
    (m) => m.name == 'u3.atlas.sheet',
  );
  sheet.properties['alphaMode'] = const StringValue('blend');
  final oldSelected = doc.resources.values
      .whereType<MaterialResource>()
      .singleWhere((m) => m.name == 'u3.atlas.selected');
  final imageTexture = doc.resources.values
      .whereType<TextureResource>()
      .single
      .id;
  LocalId source = imageTexture;
  if (renderTexture) {
    final rt = doc.addResource(
      RenderTextureResource(doc.newId(), width: 256, height: 256),
    );
    source = rt.id;
    final sourceNode = doc.createNode(
      name: 'u3.sprite.rtSheet',
      transform: TrsTransform(
        translation: Vector3(20, 0, 0),
        rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2),
      ),
      components: [
        d3ProcMeshComponent(
          D3PlaneProc(width: 2, depth: 2),
          material: sheet.id,
        ),
      ],
      root: true,
    );
    sourceNode.layers = 2;
    final camera = doc.createNode(
      name: 'u3.sprite.rtCamera',
      transform: TrsTransform(translation: Vector3(20, 0, -3)),
      components: [
        ComponentSpec(
          'camera',
          properties: {
            'projection': const StringValue('orthographic'),
            'orthoScale': const DoubleValue(1),
            'near': const DoubleValue(0.1),
            'far': const DoubleValue(10),
          },
        ),
      ],
      root: true,
    );
    doc.views.addAll([
      RenderViewSpec(cameraNode: camera.id, target: rt.id, layerMask: 2),
      RenderViewSpec(cameraNode: u3SpriteNode(doc, 'camera').id, layerMask: 1),
    ]);
  }
  doc.resources[oldSelected.id] = D3SpriteMaterial(
    colorTexture: untextured ? null : source,
    tint: tinted ? Vector4(0.4, 0.7, 0.9, 0.5) : null,
    blendMode: blend,
    textureRect: u3ProbeAtlas.tileBounds(0),
  ).toResource(oldSelected.id).copyWith(name: 'u3.sprite.selected');
  u3SpriteNode(doc, 'sheet')
    ..transform = TrsTransform(translation: Vector3(-1.2, 2.4, 0))
    ..components[0] = d3ProcMeshComponent(
      D3BillboardProc(size: Vector2.all(0.9)),
      material: sheet.id,
    );
  u3SpriteNode(doc, 'selected')
    ..transform = TrsTransform(translation: Vector3(0, 2.4, 0))
    ..components[0] = d3ProcMeshComponent(
      D3BillboardProc(
        size: Vector2.all(0.9),
        color: tinted ? const [0.8, 0.6, 0.4, 0.5] : const [1, 1, 1, 1],
      ),
      material: oldSelected.id,
    );
  final reference = doc.addResource(
    D3SpriteMaterial(
      colorTexture: source,
      textureRect: renderTexture ? null : u3ProbeAtlas.tileBounds(0),
    ).toResource(doc.newId()),
  );
  doc.createNode(
    name: 'u3.sprite.reference',
    transform: TrsTransform(translation: Vector3(1.2, 2.4, 0)),
    components: [
      d3ProcMeshComponent(
        D3BillboardProc(size: Vector2.all(0.9)),
        material: reference.id,
      ),
    ],
    root: true,
  );
  for (final (name, x, z, color) in [
    ('untextured', -1.2, 0.0, Vector4(0.2, 0.6, 0.9, 0.5)),
    ('overlapBack', 0.35, 0.3, Vector4(0.6, 0.1, 0.2, 0.5)),
    ('overlapFront', 0.75, 0.0, Vector4(0.1, 0.5, 0.3, 0.5)),
  ]) {
    final material = doc.addResource(
      D3SpriteMaterial(tint: color, blendMode: blend).toResource(doc.newId()),
    );
    doc.createNode(
      name: 'u3.sprite.$name',
      transform: TrsTransform(translation: Vector3(x, 1.15, z)),
      components: [
        d3ProcMeshComponent(
          D3BillboardProc(size: Vector2.all(0.9)),
          material: material.id,
        ),
      ],
      root: true,
    );
  }
  final lit = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.45, 0.45, 0.45, 1),
        'roughness': const DoubleValue(1),
        'metallic': const DoubleValue(0),
      },
    ),
  );
  final background = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'unlit',
      properties: {'baseColor': const ColorValue(0.08, 0.12, 0.16, 1)},
    ),
  );
  for (final (name, position, size, material) in [
    ('backdrop', Vector3(0, 1.85, 1.5), Vector3(3.6, 2.3, 0.05), background.id),
    ('receiver', Vector3(0, 0, 1.4), Vector3(3.6, 1.2, 0.05), lit.id),
    ('caster', Vector3(-0.8, 0, 0), Vector3(0.4, 0.4, 0.4), lit.id),
    ('occluder', Vector3(0.25, 2.4, -0.3), Vector3(0.2, 0.55, 0.1), lit.id),
  ]) {
    doc.createNode(
      name: 'u3.sprite.$name',
      transform: TrsTransform(translation: position),
      components: [
        d3ProcMeshComponent(D3CuboidProc(extents: size), material: material),
      ],
      root: true,
    );
  }
  doc.createNode(
    name: 'u3.sprite.shadowSprite',
    transform: TrsTransform(translation: Vector3(0.7, 0, 0)),
    components: [
      d3ProcMeshComponent(
        D3BillboardProc(size: Vector2.all(0.6)),
        material: oldSelected.id,
      ),
    ],
    root: true,
  );
  final lightPosition = Vector3(-2, 4, -3);
  doc.createNode(
    name: 'u3.sprite.spot',
    transform: TrsTransform(
      translation: lightPosition,
      rotation: aimAlong(Vector3(0, 0.6, 1.4) - lightPosition),
    ),
    components: [
      ComponentSpec(
        'spotLight',
        properties: {
          'color': const ColorValue(1, 1, 1, 1),
          'intensity': const DoubleValue(100),
          'range': const DoubleValue(15),
          'direction': Vec3Value(Vector3(0, 0, 1)),
          'innerConeAngle': const DoubleValue(0.3),
          'outerConeAngle': const DoubleValue(0.9),
          'castsShadow': const BoolValue(true),
        },
      ),
    ],
    root: true,
  );
  u3SpriteNode(doc, 'camera').transform = TrsTransform(
    translation: Vector3(0, 0, -12),
  );
  return doc;
}

class U3SpriteControls {
  U3SpriteControls(this.controller, this.document, {this.onChanged}) {
    final material = u3SelectedSpriteMaterial(document);
    blend = D3SpriteBlendMode.values.byName(
      (material.properties['blendMode'] as StringValue).value,
    );
    tinted = (material.properties['baseColor'] as ColorValue).a != 1;
    final ref = material.properties['baseColorTexture'] as ResourceRefValue?;
    textured = ref != null;
    texture =
        ref?.id ??
        document.resources.values
            .whereType<RenderTextureResource>()
            .firstOrNull
            ?.id ??
        document.resources.values.whereType<TextureResource>().single.id;
  }
  final SceneController controller;
  final SceneDocument document;
  final void Function()? onChanged;
  late final LocalId texture;
  late D3SpriteBlendMode blend;
  late bool tinted;
  late bool textured;
  int frame = 0;
  bool ordinary = false;
  bool crossed = false;
  Timer? _timer;
  bool get playing => _timer != null;

  void upsert() {
    final old = u3SelectedSpriteMaterial(document);
    final sprite = D3SpriteMaterial(
      colorTexture: textured ? texture : null,
      tint: tinted ? Vector4(0.4, 0.7, 0.9, 0.5) : null,
      blendMode: blend,
      textureRect: u3ProbeAtlas.tileBounds(frame),
    ).toResource(old.id).copyWith(name: old.name);
    final material = ordinary
        ? MaterialResource(
            old.id,
            name: old.name,
            type: 'physicallyBased',
            properties: {
              ...sprite.properties..remove('blendMode'),
              'roughness': const DoubleValue(1),
              'metallic': const DoubleValue(0),
            },
          )
        : sprite;
    document.resources[old.id] = material;
    controller.applyCommands([
      {
        'op': 'upsertResource',
        'id': old.id.toToken(),
        'resource': encodeResource(material, (id) => id.toToken()),
      },
    ]);
    onChanged?.call();
  }

  void nextFrame() {
    frame = (frame + 1) % u3ProbeAtlas.tileCount;
    upsert();
  }

  void togglePlayback() {
    if (playing) {
      _timer!.cancel();
      _timer = null;
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => nextFrame());
    }
    onChanged?.call();
  }

  void toggleTint() {
    tinted = !tinted;
    final node = u3SpriteNode(document, 'selected');
    node.components[0] = d3ProcMeshComponent(
      D3BillboardProc(
        size: Vector2.all(0.9),
        color: tinted ? const [0.8, 0.6, 0.4, 0.5] : const [1, 1, 1, 1],
      ),
      material: u3SelectedSpriteMaterial(document).id,
    );
    controller.applyCommands([
      {
        'op': 'updateNode',
        'node': node.id.toToken(),
        'flags': ['components'],
        'spec': encodeNodeCommandSpec(node, document),
      },
    ]);
    upsert();
  }

  void crossDepths() {
    crossed = !crossed;
    final node = u3SpriteNode(document, 'overlapBack');
    final position = Vector3(0.35, 1.15, crossed ? -0.3 : 0.3);
    node.transform = TrsTransform(translation: position);
    controller.setNodeTransforms([
      NodeTransform(node.id, translation: position),
    ]);
    onChanged?.call();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
