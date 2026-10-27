library;

import 'package:dart3d/dart3d.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';
import 'u2_geometry_scene.dart';

const u2CatcherPathDirect = 'direct';
const u2CatcherPathInstanceColor = 'instance-color';
const u2CatcherPathTypeUpsert = 'type-upsert';
const u2CatcherPathGeometryUpsert = 'geometry-upsert';
const u2CatcherPathVariant = 'variant';
const u2CatcherPathVariantDefault = 'variant-default';
const u2CatcherPathCameraFacing = 'camera-facing';
const u2CatcherDefaultProbeVariant = 'other';
const u2CatcherLightUnshadowedPrimary = 'directional-primary-unshadowed';
const u2CatcherLightTied = 'directional-tied';
const u2CatcherPathLod = 'lod';
const u2CatcherPathComponentRebuild = 'component-rebuild';
const u2CatcherPathRemoveRebuild = 'remove-rebuild';

SceneDocument buildU2CatcherDocument({
  String light = 'spot',
  String path = u2CatcherPathDirect,
}) {
  final doc = buildU2ShadowDocument(castsShadow: true);
  final receiver = doc.nodes.values.singleWhere(
    (node) => node.name == 'u2.shadow.receiver',
  );
  final materialId =
      (receiver.components.single.properties['material']! as ResourceRefValue)
          .id;
  final sourceMaterial = doc.resources[materialId]! as MaterialResource;
  final receiverGeometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: PlaneGeometrySpec(
        width: 4.2,
        depth: 4.2,
        segmentsX: 2,
        segmentsZ: 2,
      ),
    ),
  );
  receiver.name = 'u2.catcher.receiver';
  receiver.transform = TrsTransform(
    translation: Vector3(0.10, 0.025, -0.08),
    rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.12),
    scale: Vector3(1.0, 1.0, 0.86),
  );
  if (path == u2CatcherPathLod) {
    doc.resources[materialId] = _bakedCatcher(sourceMaterial);
    final smallGeometry = doc.addResource(
      GeometryResource(
        doc.newId(),
        procedural: PlaneGeometrySpec(
          width: 1.2,
          depth: 1.2,
          segmentsX: 1,
          segmentsZ: 1,
        ),
      ),
    );
    receiver.components
      ..clear()
      ..add(
        lodComponent(
          levels: [
            LodLevel(
              geometry: smallGeometry.id,
              material: materialId,
              screenSize: 0.35,
            ),
            LodLevel(
              geometry: receiverGeometry.id,
              material: materialId,
              screenSize: 0.0,
            ),
          ],
          hysteresis: 0,
        ),
      );
  } else if (path == u2CatcherPathVariant) {
    final variantMaterial = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'shadowCatcher',
        properties: _bakedCatcher(sourceMaterial).properties,
      ),
    );
    receiver.components
      ..clear()
      ..add(
        D3InstancesSpec(
          geometry: receiverGeometry.id,
          material: materialId,
          transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
          doubleSided: true,
        ).toComponent(),
      )
      ..add(
        ComponentSpec(
          'materialsVariants',
          properties: {
            'variants': ListValue([const StringValue('catcher')]),
            'bindings': ListValue([
              MapValue({
                'node': ResourceRefValue(receiver.id),
                'primitive': const IntValue(0),
                'default': ResourceRefValue(materialId),
                'materials': MapValue({
                  '0': ResourceRefValue(variantMaterial.id),
                }),
              }),
            ]),
          },
        ),
      );
  } else if (path == u2CatcherPathVariantDefault) {
    final otherMaterial = doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          ...sourceMaterial.properties,
          'baseColor': const ColorValue(0.16, 0.55, 0.88, 1),
        },
      ),
    );
    receiver.components
      ..clear()
      ..add(
        D3InstancesSpec(
          geometry: receiverGeometry.id,
          material: materialId,
          transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
          doubleSided: true,
        ).toComponent(),
      )
      ..add(
        ComponentSpec(
          'materialsVariants',
          properties: {
            'variants': ListValue([
              const StringValue(u2CatcherDefaultProbeVariant),
            ]),
            'bindings': ListValue([
              MapValue({
                'node': ResourceRefValue(receiver.id),
                'primitive': const IntValue(0),
                'default': ResourceRefValue(materialId),
                'materials': MapValue({
                  '0': ResourceRefValue(otherMaterial.id),
                }),
              }),
            ]),
          },
        ),
      );
  } else {
    if (path != u2CatcherPathTypeUpsert) {
      doc.resources[materialId] = _bakedCatcher(sourceMaterial);
    }
    receiver.components
      ..clear()
      ..add(
        D3InstancesSpec(
          geometry: receiverGeometry.id,
          material: materialId,
          transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
          attributes: path == u2CatcherPathInstanceColor
              ? {
                  'color': D3InstanceAttribute.inline([Vector4(1, 1, 1, 0.65)]),
                }
              : const {},
          billboard: path == u2CatcherPathCameraFacing,
          size: path == u2CatcherPathCameraFacing ? Vector2(3.6, 2.4) : null,
          doubleSided: true,
        ).toComponent(),
      );
  }

  final caster = doc.nodes.values.singleWhere(
    (node) => node.name == 'u2.shadow.caster',
  );
  caster.name = 'u2.catcher.caster';
  final casterMaterialId =
      (caster.components.single.properties['material']! as ResourceRefValue).id;
  doc.createNode(
    name: 'u2.catcher.caster.second',
    transform: TrsTransform(translation: Vector3(1.20, 0.46, -0.72)),
    components: [
      d3ProcMeshComponent(
        D3CuboidProc(extents: Vector3(0.64, 0.92, 0.70)),
        material: casterMaterialId,
      ),
    ],
    root: true,
  );

  final lightNode = doc.nodes.values.singleWhere(
    (node) => node.name == 'u2.shadow.spot',
  );
  lightNode.name = 'u2.catcher.light';
  if (light == 'directional' ||
      light == u2CatcherLightUnshadowedPrimary ||
      light == u2CatcherLightTied) {
    lightNode.transform = TrsTransform(
      rotation: aimAlong(Vector3(-0.45, -1, 0.34)),
    );
    lightNode.components
      ..clear()
      ..add(
        ComponentSpec(
          'directionalLight',
          properties: {
            'color': const ColorValue(1, 1, 1, 1),
            'intensity': const DoubleValue(2.8),
            'castsShadow': const BoolValue(true),
            'shadowMapResolution': const IntValue(1024),
          },
        ),
      );
    if (light == u2CatcherLightUnshadowedPrimary) {
      lightNode.components.single.properties['intensity'] = const DoubleValue(
        1,
      );
      doc.createNode(
        name: 'u2.catcher.light.primary',
        transform: TrsTransform(rotation: aimAlong(Vector3(0.55, -1, -0.18))),
        components: [
          ComponentSpec(
            'directionalLight',
            properties: {
              ...lightNode.components.single.properties,
              'intensity': const DoubleValue(3),
              'castsShadow': const BoolValue(false),
            },
          ),
        ],
        root: true,
      );
    }
    if (light == u2CatcherLightTied) {
      lightNode.components.single.properties['intensity'] = const DoubleValue(3);
      lightNode.components.single.properties['castsShadow'] = const BoolValue(false);
      for (var index = 1; index <= 2; index++) {
        doc.createNode(
          name: 'u2.catcher.light.tie.$index',
          transform: lightNode.transform,
          components: [
            ComponentSpec(
              'directionalLight',
              properties: {
                ...lightNode.components.single.properties,
                'castsShadow': BoolValue(index == 2),
              },
            ),
          ],
          root: true,
        );
      }
    }
  }
  return doc;
}

MaterialResource _bakedCatcher(MaterialResource material) => material.copyWith(
  type: 'shadowCatcher',
  properties: {
    ...material.properties,
    'mode': const StringValue('baked'),
    'softness': const DoubleValue(0),
  },
);

MaterialResource u2CatcherMaterial(SceneDocument doc) {
  final receiver = doc.nodes.values.singleWhere(
    (node) => node.name == 'u2.catcher.receiver',
  );
  for (final component in receiver.components) {
    if (component.type != 'd3:instances') continue;
    final defaultId =
        (component.properties['material']! as ResourceRefValue).id;
    final defaultMaterial = doc.resources[defaultId]! as MaterialResource;
    if (defaultMaterial.type == 'shadowCatcher') return defaultMaterial;
  }
  for (final resource in doc.resources.values) {
    if (resource is MaterialResource && resource.type == 'shadowCatcher') {
      return resource;
    }
  }
  final ref = receiver.components
      .map((component) => component.properties['material'])
      .whereType<ResourceRefValue>()
      .first;
  return doc.resources[ref.id]! as MaterialResource;
}

LocalId u2CatcherReceiverId(SceneDocument doc) => doc.nodes.values
    .singleWhere((node) => node.name == 'u2.catcher.receiver')
    .id;

LocalId u2CatcherGeometryId(SceneDocument doc) {
  final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
  final component = receiver.components.singleWhere(
    (candidate) => candidate.type == 'd3:instances',
  );
  return (component.properties['geometry']! as ResourceRefValue).id;
}

MaterialResource copyU2CatcherMaterial(
  MaterialResource material, {
  String? type,
  String? mode,
  double? softness,
}) {
  return material.copyWith(
    type: type ?? material.type,
    properties: {
      ...material.properties,
      if (mode != null) 'mode': StringValue(mode),
      if (softness != null) 'softness': DoubleValue(softness),
    },
  );
}

GeometryResource copyU2CatcherGeometry(
  GeometryResource geometry, {
  required double width,
}) {
  final plane = geometry.procedural! as PlaneGeometrySpec;
  return GeometryResource(
    geometry.id,
    procedural: PlaneGeometrySpec(
      width: width,
      depth: plane.depth,
      segmentsX: plane.segmentsX,
      segmentsZ: plane.segmentsZ,
    ),
  );
}

/// Sends an explicit resource upsert. Calling with the current material
/// unchanged is the public refresh command for a baked catcher.
void upsertU2CatcherMaterial(
  SceneController controller,
  SceneDocument doc,
  MaterialResource material,
) {
  doc.resources[material.id] = material;
  controller.applyCommands([
    {
      'op': 'upsertResource',
      'id': material.id.toToken(),
      'resource': encodeResource(material, (id) => id.toToken()),
    },
  ]);
}

void upsertU2CatcherGeometry(
  SceneController controller,
  SceneDocument doc,
  GeometryResource geometry,
) {
  doc.resources[geometry.id] = geometry;
  controller.applyCommands([
    {
      'op': 'upsertResource',
      'id': geometry.id.toToken(),
      'resource': encodeResource(geometry, (id) => id.toToken()),
    },
  ]);
}

void selectU2CatcherVariant(
  SceneController controller,
  SceneDocument doc,
  String? variant,
) {
  controller.selectMaterialVariant(u2CatcherReceiverId(doc), variant);
}

void rebuildU2CatcherComponents(SceneController controller, SceneDocument doc) {
  final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
  final originalSpec = encodeNodeCommandSpec(receiver, doc);
  final components = (originalSpec['components']! as List)
      .cast<Map<String, Object?>>();
  final withoutDoubleSided = <Map<String, Object?>>[
    for (final component in components)
      if (component['type'] == 'd3:instances')
        {
          ...component,
          'properties': Map<String, Object?>.from(
            component['properties']! as Map,
          )..remove('doubleSided'),
        }
      else
        component,
  ];
  controller.applyCommands([
    {
      'op': 'updateNode',
      'node': receiver.id.toToken(),
      'flags': ['components'],
      'spec': {...originalSpec, 'components': withoutDoubleSided},
    },
  ]);
  controller.applyCommands([
    {
      'op': 'updateNode',
      'node': receiver.id.toToken(),
      'flags': ['components'],
      'spec': originalSpec,
    },
  ]);
}

void removeAndRestoreU2CatcherReceiver(
  SceneController controller,
  SceneDocument doc,
) {
  final receiver = doc.nodes[u2CatcherReceiverId(doc)]!;
  controller.applyCommands([
    {'op': 'removeNode', 'node': receiver.id.toToken()},
    {
      'op': 'addNode',
      'node': receiver.id.toToken(),
      'parent': null,
      'spec': encodeNodeCommandSpec(receiver, doc),
    },
  ]);
}
