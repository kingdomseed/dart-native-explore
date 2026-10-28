library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';

const kBootU4Camera = bool.fromEnvironment('DART3D_U4_CAMERA');
final kBootU4Light = kBootU4Camera
    ? U4LightKind.directional
    : U4LightKind.values.byName(
        const String.fromEnvironment(
          'DART3D_U4_LIGHT',
          defaultValue: 'directional',
        ),
      );

enum U4LightKind {
  directional('directionalLight'),
  point('pointLight'),
  spot('spotLight'),
  area('rectAreaLight');

  const U4LightKind(this.componentType);
  final String componentType;

  ComponentSpec component({
    double intensity = 1,
    double width = 2,
    double height = 1,
  }) => ComponentSpec(
    componentType,
    properties: {
      'color': const ColorValue(1, 1, 1, 1),
      'intensity': DoubleValue(intensity),
      'castsShadow': const BoolValue(false),
      if (this != directional) 'range': const DoubleValue(12),
      if (this == spot) ...{
        'innerConeAngle': const DoubleValue(0.25),
        'outerConeAngle': DoubleValue(math.pi / 4),
      },
      if (this == area) ...{
        'width': DoubleValue(width),
        'height': DoubleValue(height),
      },
    },
  );
}

const kBootU4BareIds = bool.fromEnvironment('DART3D_U4_BARE_IDS');

NodeSpec u4Node(SceneDocument doc, String name) =>
    doc.nodes.values.singleWhere((node) => node.name == 'u4.$name');

SceneDocument buildU4PropertyDocument({
  bool camera = false,
  U4LightKind lightKind = U4LightKind.directional,
}) {
  if (camera) lightKind = U4LightKind.directional;
  final doc = SceneDocument(allocator: IdAllocator(session: 0x7534));
  final shared = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'u4.shared',
      type: 'unlit',
      properties: {'baseColor': const ColorValue(1, 1, 1, 1)},
    ),
  );
  final neutral = doc.addResource(
    MaterialResource(
      doc.newId(),
      name: 'u4.neutral',
      type: 'physicallyBased',
      properties: {
        'baseColor': const ColorValue(0.45, 0.45, 0.45, 1),
        'roughness': const DoubleValue(1),
        'metallic': const DoubleValue(0),
      },
    ),
  );
  final geometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(0.7, 0.7, 0.1)),
    ),
  );
  for (final (name, x, material) in [
    ('shared.left', -0.95, shared.id),
    ('shared.right', 0.0, shared.id),
    ('lit', 0.95, neutral.id),
  ]) {
    doc.createNode(
      name: 'u4.$name',
      transform: TrsTransform(translation: Vector3(x, 1.25, 0)),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(geometry.id),
            'material': ResourceRefValue(material),
          },
        ),
      ],
      root: true,
    );
  }
  final light = doc.createNode(
    name: 'u4.light',
    transform: lightKind == U4LightKind.directional
        ? null
        : TrsTransform(
            translation: lightKind == U4LightKind.area
                ? Vector3(0.95, 3.5, -3)
                : Vector3(0.95, 1.25, -3),
            rotation: lightKind == U4LightKind.area
                ? aimAlong(Vector3(0, -2.25, 3))
                : Quaternion.identity(),
          ),
    components: [lightKind.component()],
    root: true,
  );
  final cameraNode = doc.createNode(
    name: 'u4.camera',
    transform: TrsTransform(translation: Vector3(0, 0, -10)),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': const StringValue('perspective'),
          'fovRadiansY': DoubleValue(math.pi / 3),
          'near': const DoubleValue(0.1),
          'far': const DoubleValue(30),
        },
      ),
    ],
    root: true,
  );
  doc.stage.environmentRef = doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          name: 'u4.empty',
          environment: const EmptyEnvironment(),
          environmentIntensity: 0,
          exposure: 1,
          toneMapping: 'linear',
          effects: EnvironmentEffectsSpec(),
        ),
      )
      .id;
  final payloads = <LocalId>[];
  for (final values in <List<double>>[
    [0, 2],
    [1, 0, 0, 1, 0, 0, 1, 1],
    [2, 6],
    [math.pi / 4, math.pi / 2],
  ]) {
    final id = doc.newId();
    final bytes = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      bytes.setFloat32(i * 4, values[i], Endian.little);
    }
    doc.payloads[id] = PayloadSpec(
      id,
      encoding: PayloadEncoding.floats,
      bytes: bytes.buffer.asUint8List(),
    );
    payloads.add(id);
  }
  final clip = doc.newId();
  doc.animations[clip] = Dart3dAnimationSpec(
    clip,
    name: camera ? 'u4.camera' : 'u4.color-light',
    propertyChannels: camera
        ? [
            D3CameraFovChannel(
              node: cameraNode.id,
              timeline: payloads[0],
              keyframes: payloads[3],
            ),
          ]
        : [
            D3MaterialBaseColorChannel(
              material: shared.id,
              timeline: payloads[0],
              keyframes: payloads[1],
            ),
            D3LightIntensityChannel(
              node: light.id,
              timeline: payloads[0],
              keyframes: payloads[2],
            ),
          ],
  );
  return doc;
}

class U4PropertyControls {
  U4PropertyControls(
    this.controller,
    SceneDocument document, {
    bool bareIds = false,
    this.log,
    this.onChanged,
  }) : clip = document.animations.keys.single {
    final definition = document.animations[clip]!;
    if (bareIds) {
      final wire = encodeAnimationSpec(definition, document);
      for (final channel in (wire['d3:properties']! as List).cast<Map>()) {
        for (final field in ['material', 'node', 'timeline', 'keyframes']) {
          if (channel.containsKey(field)) {
            channel[field] = LocalId.parse(channel[field] as String).toToken();
          }
        }
      }
      controller.applyCommands([
        {'op': 'removeAnimation', 'id': clip.toToken()},
        {'op': 'upsertAnimation', 'id': clip.toToken(), 'animation': wire},
      ]);
    }
    controller.playAnimation(clip, time: 0, weight: 1, loop: true);
    controller.pauseAnimation(clip);
    log?.call(
      'dart3d: u4 requested mode=${definition.name} clip=${clip.toToken()} time=0 weight=1 rawIds=$bareIds',
    );
  }

  final SceneController controller;
  final LocalId clip;
  final void Function(String)? log;
  final void Function()? onChanged;
  bool playing = false;
  double weight = 1;

  void seek(double time) {
    controller.pauseAnimation(clip);
    controller.seekAnimation(clip, time);
    playing = false;
    log?.call('dart3d: u4 requested clip=${clip.toToken()} pause time=$time');
    onChanged?.call();
  }

  void togglePlayback() {
    playing = !playing;
    if (playing) {
      controller.playAnimation(clip);
    } else {
      controller.pauseAnimation(clip);
    }
    log?.call('dart3d: u4 requested clip=${clip.toToken()} playing=$playing');
    onChanged?.call();
  }

  void stop() {
    controller.stopAnimation(clip);
    playing = false;
    log?.call(
      'dart3d: u4 requested clip=${clip.toToken()} stop time=0 weight=$weight',
    );
    onChanged?.call();
  }

  void setWeight(double value) {
    weight = value;
    controller.playAnimation(clip, weight: weight);
    if (!playing) controller.pauseAnimation(clip);
    log?.call(
      'dart3d: u4 requested clip=${clip.toToken()} weight=$weight playing=$playing',
    );
    onChanged?.call();
  }
}

class U4LightControls {
  U4LightControls(this.controller, this.kind, {this.log});

  final SceneController controller;
  final U4LightKind kind;
  final void Function(String)? log;

  void replace() => _update(
    kind.component(intensity: 3, width: 3, height: 2),
    'Replace light rest=3',
  );

  void remove() => _update(null, 'Remove light');

  void reAdd() => _update(kind.component(), 'Re-add light rest=1');

  void _update(ComponentSpec? component, String action) {
    final doc = controller.serializeScene()!;
    final node = u4Node(doc, 'light');
    node.components.clear();
    if (component != null) node.components.add(component);
    controller.applyCommands([
      {
        'op': 'updateNode',
        'node': node.id.toToken(),
        'flags': ['components'],
        'spec': encodeNodeCommandSpec(node, doc),
      },
    ]);
    log?.call('dart3d: u4 requested light=${kind.name} $action');
  }
}
