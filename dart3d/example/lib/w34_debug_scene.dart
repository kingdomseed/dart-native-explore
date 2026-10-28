import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';
import 'u2_catcher_scene.dart';

SceneDocument buildW34DebugDocument({
  bool skinned = false,
  bool materials = false,
  bool bakedCatcher = false,
  bool liveCatcher = false,
  bool blendCaster = false,
}) {
  if (bakedCatcher || liveCatcher) {
    final doc = buildU2CatcherDocument(light: 'spot');
    final second = doc.nodes.values.singleWhere(
      (node) => node.name == 'u2.catcher.caster.second',
    );
    doc.roots.remove(second.id);
    doc.nodes.remove(second.id);
    final cameraPosition = Vector3(0, 4.5, -6);
    final camera = doc.createNode(
      name: 'w34.camera',
      root: true,
      transform: TrsTransform(
        translation: cameraPosition,
        rotation: aimAlong(Vector3(0, 0.3, 0) - cameraPosition),
      ),
      components: [
        ComponentSpec(
          'camera',
          properties: {
            'projection': const StringValue('orthographic'),
            'orthoScale': const DoubleValue(4.6),
            'near': const DoubleValue(0.1),
            'far': const DoubleValue(30),
          },
        ),
      ],
    );
    doc.views.add(RenderViewSpec(cameraNode: camera.id));
    final backdrop = doc.addResource(
      MaterialResource(
        doc.newId(),
        name: 'w34.backdrop',
        type: 'physicallyBased',
        properties: {
          'baseColor': const ColorValue(0.18, 0.3, 0.45, 1),
          'metallic': const DoubleValue(0.2),
          'roughness': const DoubleValue(0.7),
        },
      ),
    );
    doc.createNode(
      name: 'w34.backdrop',
      root: true,
      transform: TrsTransform(translation: Vector3(0, -1, 3.5)),
      components: [
        d3ProcMeshComponent(
          D3CuboidProc(extents: Vector3(8, 6, 0.1)),
          material: backdrop.id,
        ),
      ],
    );
    if (liveCatcher) {
      if (blendCaster) {
        final caster = doc.nodes.values.singleWhere(
          (node) => node.name == 'u2.catcher.caster',
        );
        final id =
            (caster.components.single.properties['material']!
                    as ResourceRefValue)
                .id;
        final material = doc.resources[id]! as MaterialResource;
        doc.resources[id] = material.copyWith(
          properties: {
            ...material.properties,
            'alphaMode': const StringValue('blend'),
            'baseColor': const ColorValue(0.82, 0.34, 0.12, 0.55),
          },
        );
      }
      final catcher = u2CatcherMaterial(doc);
      doc.resources[catcher.id] = copyU2CatcherMaterial(catcher, mode: 'live');
      final light = doc.nodes.values.singleWhere(
        (node) => node.name == 'u2.catcher.light',
      );
      final curves = <LocalId>[];
      for (final values in <List<double>>[
        [0, 2],
        [20, 160],
      ]) {
        final bytes = ByteData(values.length * 4);
        for (var i = 0; i < values.length; i++) {
          bytes.setFloat32(i * 4, values[i], Endian.little);
        }
        final payload = doc.addPayload(
          PayloadSpec(
            doc.newId(),
            encoding: PayloadEncoding.floats,
            bytes: bytes.buffer.asUint8List(),
          ),
        );
        curves.add(payload.id);
      }
      final clip = doc.newId();
      doc.animations[clip] = Dart3dAnimationSpec(
        clip,
        name: 'w34.live.intensity',
        propertyChannels: [
          D3LightIntensityChannel(
            node: light.id,
            timeline: curves[0],
            keyframes: curves[1],
          ),
        ],
      );
    }
    return doc;
  }
  final doc = SceneDocument(allocator: IdAllocator(session: 0x7734696f));
  final positions = [
    Vector3(-1, -1, 0),
    Vector3(1, -1, 0),
    Vector3(1, 1, 0),
    Vector3(-1, 1, 0),
  ];
  final normals = List.generate(4, (_) => Vector3(0, 0, -1));
  final uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)];
  final colors = List.generate(4, (_) => Vector4(0.8, 1, 0.6, 1));
  final tangents = List.generate(4, (_) => Vector4(1, 0, 0, -1));
  final vertices = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.vertexBuffer,
      layout: skinned ? 'skinned_uv1_tangent' : 'unskinned_uv1_tangent',
      bytes: skinned
          ? VertexPack.skinned(
              positions: positions,
              normals: normals,
              uvs: uvs,
              colors: colors,
              tangents: tangents,
              joints: List.generate(4, (_) => Vector4(1, 0, 0, 0)),
              weights: List.generate(4, (_) => Vector4(1, 0, 0, 0)),
            )
          : VertexPack.unskinned(
              positions: positions,
              normals: normals,
              uvs: uvs,
              colors: colors,
              tangents: tangents,
            ),
    ),
  );
  final indexBytes = ByteData(12);
  for (final (i, index) in [0, 2, 1, 0, 3, 2].indexed) {
    indexBytes.setUint16(i * 2, index, Endian.little);
  }
  final indices = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: 'uint16',
      bytes: indexBytes.buffer.asUint8List(),
    ),
  );
  final quad = doc.addResource(
    GeometryResource(doc.newId(), vertices: vertices.id, indices: indices.id),
  );
  final normalBytes = Uint8List.fromList([
    for (var y = 0; y < 64; y++)
      for (var x = 0; x < 64; x++)
        ...(y < 24
            ? (x < 40 ? [128, 128, 255, 255] : [218, 128, 218, 255])
            : (x < 20 ? [128, 37, 218, 255] : [54, 201, 201, 255])),
  ]);
  final normalPayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 64,
      height: 64,
      length: normalBytes.length,
      bytes: normalBytes,
    ),
  );
  final normal = doc.addResource(
    TextureResource(doc.newId(), payload: normalPayload.id, content: 'normal'),
  );
  final mrPayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 2,
      height: 2,
      length: 16,
      bytes: Uint8List.fromList([
        255,
        64,
        32,
        255,
        255,
        128,
        192,
        255,
        255,
        192,
        128,
        255,
        255,
        255,
        255,
        255,
      ]),
    ),
  );
  final mr = doc.addResource(
    TextureResource(doc.newId(), payload: mrPayload.id, content: 'data'),
  );
  final baseBytes = Uint8List.fromList([
    for (var y = 0; y < 64; y++)
      for (var x = 0; x < 64; x++) ...[
        x < 32 ? 255 : 160,
        y < 32 ? 200 : 255,
        220,
        x < 16 ? 0 : (x < 32 ? 128 : 255),
      ],
  ]);
  final basePayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 64,
      height: 64,
      length: baseBytes.length,
      bytes: baseBytes,
    ),
  );
  final base = doc.addResource(
    TextureResource(doc.newId(), payload: basePayload.id),
  );
  final material = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'w34.mapped',
      type: materials ? 'unlit' : 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.65, 0.42, 0.2, 1),
        'baseColorTexture': ResourceRefValue(base.id),
        if (materials) 'normalTexture': ResourceRefValue(normal.id),
        if (materials)
          'baseColorTextureTransform': MapValue({
            'offset': Vec2Value(Vector2(0.04, 0.08)),
            'scale': Vec2Value(Vector2(0.88, 0.84)),
            'rotation': const DoubleValue(0.13),
          }),
        if (!materials) ...{
          'metallic': const DoubleValue(0.7),
          'roughness': const DoubleValue(0.6),
          'metallicRoughnessTexture': ResourceRefValue(mr.id),
          'normalTexture': ResourceRefValue(normal.id),
          'normalScale': const DoubleValue(1),
          'normalTextureTransform': MapValue({
            'offset': Vec2Value(Vector2(0.1, 0.08)),
            'scale': Vec2Value(Vector2(0.8, 0.84)),
            'rotation': const DoubleValue(0.13),
            'texCoord': const IntValue(0),
          }),
        },
        'alphaMode': const StringValue('opaque'),
        'alphaCutoff': const DoubleValue(0.5),
      },
    ),
  );
  final quadNode = doc.createNode(
    name: 'w34.quad',
    root: true,
    transform: TrsTransform(
      translation: materials ? Vector3(-0.65, 1.1, 0) : Vector3(0, 1.1, 0),
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.18),
      scale: Vector3.all(materials ? 0.48 : 0.88),
    ),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(quad.id),
          'material': ResourceRefValue(material.id),
        },
      ),
    ],
  );
  if (skinned) {
    final rig = doc.createNode(
      name: 'w34.rig',
      root: true,
      transform: quadNode.transform,
    );
    final joint = doc.createNode(name: 'w34.joint');
    rig.children.add(joint.id);
    final matrices = Float32List.fromList([
      ...Matrix4.identity().storage,
      ...Matrix4.identity().storage,
    ]);
    final ibm = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.matrices,
        length: matrices.lengthInBytes,
        bytes: matrices.buffer.asUint8List(),
      ),
    );
    final skin = doc.addSkin(
      SkinSpec(
        doc.newId(),
        joints: [rig.id, joint.id],
        skeleton: rig.id,
        inverseBindMatrices: ibm.id,
      ),
    );
    quadNode.skin = skin.id;
    quadNode.transform = TrsTransform();
  }
  final occluderMaterial = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'w34.occluder',
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.1, 0.3, 0.7, 1),
        'roughness': const DoubleValue(0.5),
        'metallic': const DoubleValue(0),
      },
    ),
  );
  doc.createNode(
    name: 'w34.occluder',
    root: true,
    transform: TrsTransform(translation: Vector3(0.35, 1.05, -3)),
    components: [
      d3ProcMeshComponent(
        D3CuboidProc(extents: Vector3(0.35, 0.75, 0.12)),
        material: occluderMaterial.id,
      ),
    ],
  );
  for (final (index, value)
      in (materials ? <double>[] : [0.125, 0.5, 0.875]).indexed) {
    final literal = doc.addResource(
      MaterialResource(
        doc.newId(),
        name: 'w34.literal.$value',
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(value, value, value, 1),
          'metallic': DoubleValue(value),
          'roughness': DoubleValue(value),
        },
      ),
    );
    doc.createNode(
      name: 'w34.literal.$value',
      root: true,
      transform: TrsTransform(
        translation: Vector3((index - 1) * 0.62, -0.25, 0),
      ),
      components: [
        d3ProcMeshComponent(
          D3CuboidProc(extents: Vector3(0.48, 0.3, 0.04)),
          material: literal.id,
        ),
      ],
    );
  }
  if (materials) {
    for (final (index, blend) in D3SpriteBlendMode.values.indexed) {
      final sprite = doc.addResource(
        D3SpriteMaterial(
          colorTexture: base.id,
          tint: Vector4(0.65, 0.42, 0.2, 0.7),
          blendMode: blend,
          textureRect: Vector4(0.04, 0.08, 0.92, 0.92),
        ).toResource(doc.newId()).copyWith(name: 'w34.sprite.${blend.name}'),
      );
      doc.createNode(
        name: 'w34.sprite.${blend.name}',
        root: true,
        transform: TrsTransform(
          translation: Vector3(0.65, 1.15 - index * 1.1, -0.1),
        ),
        components: [
          d3ProcMeshComponent(
            D3BillboardProc(
              size: Vector2.all(0.9),
              facing: 'screen',
              rotation: 0.13,
              color: const [0.8, 0.6, 0.4, 0.5],
            ),
            material: sprite.id,
          ),
        ],
      );
    }
  }
  final camera = doc.createNode(
    name: 'w34.camera',
    root: true,
    transform: TrsTransform(translation: Vector3(0, 0, -5)),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': const StringValue('orthographic'),
          'orthoScale': const DoubleValue(2.6),
          'near': const DoubleValue(0.1),
          'far': const DoubleValue(20),
        },
      ),
    ],
  );
  doc.createNode(
    name: 'w34.light',
    root: true,
    transform: TrsTransform(
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), -0.4),
    ),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': const ColorValue(1, 1, 1, 1),
          'intensity': const DoubleValue(2),
          'castsShadow': const BoolValue(false),
        },
      ),
    ],
  );
  final target = doc.addResource(
    RenderTextureResource(
      doc.newId(),
      width: 512,
      height: 512,
      update: 'manual',
    ),
  );
  final monitorMaterial = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'w34.authoredTarget',
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(1, 1, 1, 1),
        'baseColorTexture': ResourceRefValue(target.id),
        'metallic': const DoubleValue(0),
        'roughness': const DoubleValue(1),
      },
    ),
  );
  final monitor = doc.createNode(
    name: 'w34.authoredTarget',
    root: true,
    transform: TrsTransform(
      translation: Vector3(0, materials ? -1.4 : -1.5, 0),
    ),
    components: [
      d3ProcMeshComponent(
        D3CuboidProc(
          extents: materials
              ? Vector3(1.5, 1.3, 0.04)
              : Vector3(1.7, 1.7, 0.04),
        ),
        material: monitorMaterial.id,
      ),
    ],
  );
  monitor.layers = 2;
  doc.views.addAll([
    RenderViewSpec(cameraNode: camera.id, target: target.id, layerMask: 1),
    RenderViewSpec(cameraNode: camera.id, layerMask: 3),
  ]);
  doc.stage.environmentRef = doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          environment: const EmptyEnvironment(),
          environmentIntensity: 0,
          exposure: 1,
          toneMapping: 'linear',
          effects: EnvironmentEffectsSpec(),
        ),
      )
      .id;
  return doc;
}

void moveW34CatcherCaster(
  SceneController controller,
  SceneDocument document, {
  required bool moved,
}) {
  final caster = document.nodes.values.singleWhere(
    (node) => node.name == 'u2.catcher.caster',
  );
  final translation = Vector3(moved ? 0.9 : 0, 0.7, 0);
  caster.transform = TrsTransform(translation: translation);
  controller.setNodeTransforms([
    NodeTransform(caster.id, translation: translation),
  ]);
}

void editW34DebugMaterial(
  SceneController controller,
  SceneDocument document, {
  required bool edited,
  String coverage = 'opaque',
}) {
  final material = document.resources.values
      .whereType<MaterialResource>()
      .singleWhere((material) => material.name == 'w34.mapped');
  material.properties.addAll({
    'baseColor': edited
        ? const ColorValue(0.18, 0.7, 0.4, 1)
        : const ColorValue(0.65, 0.42, 0.2, 1),
    'metallic': DoubleValue(edited ? 0.25 : 0.7),
    'roughness': DoubleValue(edited ? 0.9 : 0.6),
    'normalScale': DoubleValue(edited ? 0.35 : 1),
    'alphaMode': StringValue(coverage),
  });
  controller.applyCommands([
    {
      'op': 'upsertResource',
      'id': material.id.toToken(),
      'resource': encodeResource(material, (id) => id.toToken()),
    },
  ]);
}

void setW34RigPresent(
  SceneController controller,
  SceneDocument document,
  NodeSpec rig,
  NodeSpec joint, {
  required bool present,
}) {
  if (!present) {
    controller.removeNode(rig.id);
    return;
  }
  controller.applyCommands([
    {
      'op': 'addNode',
      'node': rig.id.toToken(),
      'parent': null,
      'spec': encodeNodeCommandSpec(rig, document),
    },
    {
      'op': 'addNode',
      'node': joint.id.toToken(),
      'parent': rig.id.toToken(),
      'spec': encodeNodeCommandSpec(joint, document),
    },
  ]);
}

void poseW34Joint(
  SceneController controller,
  NodeSpec joint, {
  required bool posed,
}) {
  controller.setNodeTransforms([
    NodeTransform(joint.id, translation: Vector3(0, posed ? 0.35 : 0, 0)),
  ]);
}

void setW34Viewport(
  SceneController controller,
  SceneDocument document, {
  required bool inset,
}) {
  final target = document.views.singleWhere((view) => view.target != null);
  final screen = document.views.singleWhere((view) => view.target == null);
  controller.updateViews([
    target,
    Dart3dRenderViewSpec(
      cameraNode: screen.cameraNode,
      layerMask: screen.layerMask,
      viewport: inset ? [60, 60, 1086, 900] : null,
    ),
  ]);
}

void editW34MaterialFamilies(
  SceneController controller,
  SceneDocument document, {
  required bool edited,
  required bool textured,
  required bool colored,
  required String coverage,
}) {
  final unlit = document.resources.values
      .whereType<MaterialResource>()
      .singleWhere((material) => material.name == 'w34.mapped');
  final texture = document.resources.values
      .whereType<TextureResource>()
      .singleWhere((texture) => texture.content == 'color');
  final ops = <Map<String, dynamic>>[];
  for (final material in [
    unlit,
    ...document.resources.values.whereType<MaterialResource>().where(
      (material) => material.type == 'd3:sprite',
    ),
  ]) {
    final sprite = material.type == 'd3:sprite';
    material.properties['baseColor'] = edited
        ? ColorValue(0.18, 0.7, 0.4, sprite ? 0.4 : 0.65)
        : ColorValue(0.65, 0.42, 0.2, sprite ? 0.7 : 1);
    if (textured) {
      material.properties['baseColorTexture'] = ResourceRefValue(texture.id);
    } else {
      material.properties.remove('baseColorTexture');
    }
    if (!sprite) material.properties['alphaMode'] = StringValue(coverage);
    ops.add({
      'op': 'upsertResource',
      'id': material.id.toToken(),
      'resource': encodeResource(material, (id) => id.toToken()),
    });
    if (sprite) {
      final node = document.nodes.values.singleWhere(
        (node) => node.name == material.name,
      );
      node.components[0] = d3ProcMeshComponent(
        D3BillboardProc(
          size: Vector2.all(0.9),
          facing: 'screen',
          rotation: 0.13,
          color: colored
              ? const [0.8, 0.6, 0.4, 0.5]
              : const [0.35, 0.9, 0.7, 0.8],
        ),
        material: material.id,
      );
      ops.add({
        'op': 'updateNode',
        'node': node.id.toToken(),
        'flags': ['components'],
        'spec': encodeNodeCommandSpec(node, document),
      });
    }
  }
  controller.applyCommands(ops);
}

class W34LiveLightControls {
  W34LiveLightControls(this.controller, this.document)
    : light = document.nodes.values.singleWhere(
        (node) => node.name == 'u2.catcher.light',
      ),
      clip = document.animations.keys.single {
    component = light.components.single;
    restPose = light.transform as TrsTransform;
  }

  final SceneController controller;
  final SceneDocument document;
  final NodeSpec light;
  final LocalId clip;
  late final ComponentSpec component;
  late final TrsTransform restPose;
  bool moved = false;
  bool present = true;
  bool alternate = false;
  bool playing = false;
  String cue = 'Rest';

  void togglePose() {
    moved = !moved;
    final translation = moved ? Vector3(2, 5, 1) : restPose.translation;
    final rotation = moved ? aimAlong(-translation) : restPose.rotation;
    light.transform = TrsTransform(
      translation: translation,
      rotation: rotation,
    );
    controller.setNodeTransforms([
      NodeTransform(light.id, translation: translation, rotation: rotation),
    ]);
  }

  void togglePresence() {
    releaseIntensityOverride();
    present = !present;
    _applyComponent();
  }

  void replace() {
    releaseIntensityOverride();
    alternate = !alternate;
    present = true;
    _applyComponent();
  }

  void _applyComponent() {
    light.components
      ..clear()
      ..addAll([
        if (present)
          ComponentSpec(
            component.type,
            properties: {
              ...component.properties,
              if (alternate) ...{
                'color': const ColorValue(0.7, 0.85, 1, 1),
                'intensity': const DoubleValue(80),
              },
            },
          ),
      ]);
    controller.applyCommands([
      {
        'op': 'updateNode',
        'node': light.id.toToken(),
        'flags': ['components'],
        'spec': encodeNodeCommandSpec(light, document),
      },
    ]);
  }

  void seek(double time) {
    controller.playAnimation(clip, time: time, weight: 1, loop: true);
    controller.pauseAnimation(clip);
    playing = false;
    cue = time == 0 ? 'Dim' : 'Bright';
  }

  void togglePlayback() {
    playing = !playing;
    if (playing) {
      controller.playAnimation(clip, weight: 1, loop: true);
      cue = 'Running';
    } else {
      controller.pauseAnimation(clip);
      cue = 'Paused';
    }
  }

  void releaseIntensityOverride() {
    controller.playAnimation(clip, time: 0, weight: 0);
    controller.pauseAnimation(clip);
    playing = false;
    cue = 'Rest';
  }

  void reload() {
    controller.loadDocument(document);
    playing = false;
    cue = 'Rest';
  }
}
