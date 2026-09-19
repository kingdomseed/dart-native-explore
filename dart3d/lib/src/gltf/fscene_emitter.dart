// Ported from flutter_scene 0.23.0
// `lib/src/importer/src/fscene_emitter/fscene_emitter.dart`
// (MIT, copyright Brandon DeRosier).
//
// Adaptations for dart3d:
// - `package:scene/scene.dart` -> dart3d's `scene_model.dart` component
//   barrel (the upstream barrel transitively pulls the vendored-archive
//   binary reader, which cannot compile under the DartNative kernel).
// - Textures are NOT decoded here: upstream decodes every image through
//   `package:image` to RGBA8 (or re-encodes to KTX2), but dart3d cannot add
//   the `image` dependency and does not need to — both native realizers
//   sniff encoded PNG/JPEG payload bytes themselves (the "encoded
//   container" path in FsceneRealizer/TextureFactory) and both decode KTX2
//   natively. So an embedded glTF image is carried verbatim as an `image`
//   payload with `format` set to its container name (`png`, `jpeg`,
//   `ktx2`, `webp`, ...), which lands on exactly that native path.
// - The `compressTextures`/`alignForCompression` cooking options are
//   dropped: they exist to shrink `.fsceneb` files at build time, which
//   the runtime importer never does.
// - KHR_draco_mesh_compression throws (no Draco codec is ported).

/// Parsed glTF -> an in-memory `.fscene` [SceneDocument].
///
/// Builds a [SceneDocument] from a parsed glTF document. Geometry uses the
/// shared primitive packer with native coordinate baking enabled.
///
/// Pure Dart (no `dart:ui` / Flutter GPU). Ids are derived deterministically
/// from the binary chunk, so re-importing the same asset yields an identical
/// document.
///
/// Geometry bounds: unskinned primitives carry their rest AABB; skinned
/// primitives carry the offline-baked pose-union AABB (the union of every
/// animated pose's extent), the only sound cull bound once joints move. A
/// skinned primitive whose pose union could not be computed carries no
/// bounds, and the realizer leaves it unbounded (always visible).
library;

import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import '../scene_model.dart';
import 'accessor.dart';
import 'bounds_baker.dart';
import 'coordinate_policy.dart';
import 'gltf_light_units.dart';
import 'interleaved_layout.dart';
import 'primitive_packer.dart';
import 'texture_roles.dart';
import 'types.dart';

/// Builds an `.fscene` [SceneDocument] from a parsed glTF document.
///
/// Spatial data is converted to native scene coordinates during emission.
SceneDocument buildSceneDocument(GltfDocument doc, Uint8List bufferData) {
  // The document id stays content-derived, so distinct imports get distinct
  // ids, but local ids are minted from a fixed session: a node's id then
  // depends only on its position in the glTF, not on the buffer bytes. So
  // re-importing an edited model keeps the same ids for nodes whose position is
  // unchanged.
  final document = SceneDocument(
    documentId: DocumentId.generate(Random(_seedFrom(bufferData))),
    allocator: IdAllocator(session: _kImporterIdSession),
  );
  document.generator = 'dart3d glTF importer (flutter_scene 0.23.0 port)';

  // Pre-mint a stable id per glTF node so child/joint/animation-target
  // references resolve regardless of the build order below.
  final nodeIds = [for (var i = 0; i < doc.nodes.length; i++) document.newId()];

  // Textures, then materials (which reference textures), then mesh geometry
  // (which references materials).
  final textureContents = gltfTextureContents(doc);
  final textureIds = [
    for (var i = 0; i < doc.textures.length; i++)
      _buildTexture(
        document,
        doc.textures[i],
        doc,
        bufferData,
        content: textureContents[i],
      ),
  ];
  final materialIds = [
    for (final material in doc.materials)
      _buildMaterial(document, material, textureIds),
  ];

  LocalId? defaultMaterialId;
  LocalId materialFor(int? index) {
    if (index != null && index >= 0 && index < materialIds.length) {
      return materialIds[index];
    }
    return defaultMaterialId ??= document
        .addResource(
          MaterialResource(document.newId(), type: 'physicallyBased'),
        )
        .id;
  }

  // Pose-union analysis for skinned culling, plus which nodes use each mesh
  // (geometry resources are shared per mesh, so a mesh used by a skinned
  // node carries pose-union bounds rather than rest bounds).
  final poseUnions = bakeSkinnedPoseUnionAabbs(doc, bufferData);
  final skinnedUsers = <int, List<int>>{};
  final unskinnedUse = <int>{};
  for (var i = 0; i < doc.nodes.length; i++) {
    final node = doc.nodes[i];
    final mesh = node.mesh;
    if (mesh == null) continue;
    if (node.skin != null) {
      skinnedUsers.putIfAbsent(mesh, () => []).add(i);
    } else {
      unskinnedUse.add(mesh);
    }
  }

  // Geometry resources per mesh primitive, shared across the nodes that
  // reference the same mesh.
  final meshPairs = <(int, bool), List<(LocalId, LocalId)>>{};
  for (var meshIndex = 0; meshIndex < doc.meshes.length; meshIndex++) {
    validateMorphTargetConsistency(doc.meshes[meshIndex]);
    List<(LocalId, LocalId)> buildPairs(bool skinned) {
      final pairs = <(LocalId, LocalId)>[];
      var primIndex = 0;
      final mesh = doc.meshes[meshIndex];
      for (final primitive in mesh.primitives) {
        if (primitive.mode != 4) continue; // triangles only
        final bounds = _primitiveBounds(
          primitive,
          doc,
          primIndex,
          skinnedUsers: skinned ? skinnedUsers[meshIndex] : null,
          alsoUsedUnskinned: false,
          poseUnions: poseUnions,
        );
        final geometryId = _buildGeometry(
          document,
          primitive,
          doc,
          bufferData,
          bounds: bounds,
          includeSkinning: skinned,
          morphTargetNames: mesh.targetNames,
          defaultMorphWeights: mesh.weights,
        );
        pairs.add((geometryId, materialFor(primitive.material)));
        primIndex++;
      }
      return pairs;
    }

    final hasSkinnedUsers = skinnedUsers[meshIndex]?.isNotEmpty ?? false;
    if (unskinnedUse.contains(meshIndex) || !hasSkinnedUsers) {
      meshPairs[(meshIndex, false)] = buildPairs(false);
    }
    if (hasSkinnedUsers) {
      meshPairs[(meshIndex, true)] = buildPairs(true);
    }
  }

  // Skins (joints reference nodes by id; inverse-bind matrices ride in a
  // payload chunk).
  final skinIds = [
    for (final skin in doc.skins)
      _buildSkin(
        document,
        skin,
        doc,
        bufferData,
        nodeIds,
        GltfCoordinatePolicy.bakeNative,
      ),
  ];

  // Nodes.
  for (var i = 0; i < doc.nodes.length; i++) {
    final node = doc.nodes[i];
    final components = <ComponentSpec>[];
    if (node.mesh != null && node.mesh! < doc.meshes.length) {
      final pairs = meshPairs[(node.mesh!, node.skin != null)] ?? const [];
      if (pairs.isNotEmpty) {
        // node.weights overrides the mesh's default morph weights for this
        // instance; it rides the mesh component rather than the shared
        // geometry resource.
        components.add(_meshComponent(pairs, morphWeights: node.weights));
      }
    }
    final lightIndex = node.light;
    if (lightIndex != null &&
        lightIndex >= 0 &&
        lightIndex < doc.lights.length) {
      final component = _lightComponent(doc.lights[lightIndex]);
      if (component != null) components.add(component);
    }
    document.addNode(
      NodeSpec(
        id: nodeIds[i],
        name: resolveGltfNodeName(node.name, i),
        transform: _transform(node),
        children: [
          for (final c in node.children)
            if (c >= 0 && c < nodeIds.length) nodeIds[c],
        ],
        components: components,
        skin: (node.skin != null && node.skin! < skinIds.length)
            ? skinIds[node.skin!]
            : null,
      ),
    );
  }

  // Roots from the default scene.
  final sceneIndex = doc.scene ?? (doc.scenes.isNotEmpty ? 0 : -1);
  if (sceneIndex >= 0 && sceneIndex < doc.scenes.length) {
    for (final root in doc.scenes[sceneIndex].nodes) {
      if (root >= 0 && root < nodeIds.length) document.roots.add(nodeIds[root]);
    }
  }

  // KHR_materials_variants: attach a materialsVariants component to each
  // document root whose subtree has variant-mapped primitives. Bindings
  // reference nodes and their mesh primitive index (triangle primitives
  // only, matching the emitted mesh); the mapped materials are already in
  // the resource pool ([materialIds] covers every source material).
  if (doc.materialsVariants.isNotEmpty &&
      sceneIndex >= 0 &&
      sceneIndex < doc.scenes.length) {
    _emitMaterialsVariants(
      document,
      doc,
      sceneRoots: doc.scenes[sceneIndex].nodes,
      nodeIds: nodeIds,
      materialIds: materialIds,
    );
  }

  // Animations (one keyframe timeline/value payload per channel).
  for (final animation in doc.animations) {
    _buildAnimation(
      document,
      animation,
      doc,
      bufferData,
      nodeIds,
      GltfCoordinatePolicy.bakeNative,
    );
  }

  return document;
}

LocalId _buildSkin(
  SceneDocument document,
  GltfSkin skin,
  GltfDocument doc,
  Uint8List bufferData,
  List<LocalId> nodeIds,
  GltfCoordinatePolicy coordinatePolicy,
) {
  final Float32List matrices;
  if (skin.inverseBindMatrices != null) {
    final accessor = doc.accessors[skin.inverseBindMatrices!];
    matrices = coordinatePolicy.convertMatrices(
      readAccessorAsFloat32(accessor, doc.bufferViews, bufferData),
    );
  } else {
    // Spec default: identity per joint, column-major.
    matrices = Float32List(skin.joints.length * 16);
    for (var i = 0; i < skin.joints.length; i++) {
      matrices[i * 16 + 0] = 1.0;
      matrices[i * 16 + 5] = 1.0;
      matrices[i * 16 + 10] = 1.0;
      matrices[i * 16 + 15] = 1.0;
    }
  }
  final payload = _floatPayload(document, matrices, PayloadEncoding.matrices);
  return document
      .addSkin(
        SkinSpec(
          document.newId(),
          joints: [
            for (final j in skin.joints)
              if (j >= 0 && j < nodeIds.length) nodeIds[j],
          ],
          inverseBindMatrices: payload,
          skeleton: (skin.skeleton != null && skin.skeleton! < nodeIds.length)
              ? nodeIds[skin.skeleton!]
              : null,
        ),
      )
      .id;
}

void _buildAnimation(
  SceneDocument document,
  GltfAnimation animation,
  GltfDocument doc,
  Uint8List bufferData,
  List<LocalId> nodeIds,
  GltfCoordinatePolicy coordinatePolicy,
) {
  final channels = <AnimationChannelSpec>[];
  for (final channel in animation.channels) {
    final target = channel.targetNode;
    if (target == null || target < 0 || target >= nodeIds.length) continue;
    if (channel.sampler < 0 || channel.sampler >= animation.samplers.length) {
      continue;
    }
    final property = switch (channel.targetPath) {
      'translation' => AnimationProperty.translation,
      'rotation' => AnimationProperty.rotation,
      'scale' => AnimationProperty.scale,
      'weights' => AnimationProperty.weights,
      _ => null, // unknown target paths
    };
    if (property == null) continue;

    final sampler = animation.samplers[channel.sampler];
    final inputAccessor = doc.accessors[sampler.input];
    final outputAccessor = doc.accessors[sampler.output];
    final times = readAccessorAsFloat32(
      inputAccessor,
      doc.bufferViews,
      bufferData,
    );
    final values = readAccessorAsFloat32(
      outputAccessor,
      doc.bufferViews,
      bufferData,
    );
    final isCubic = sampler.interpolation == 'CUBICSPLINE';
    // A weights sampler is a flattened (frame x target) scalar stream; its
    // per-keyframe component count is the output/input length ratio.
    final componentCount = switch (property) {
      AnimationProperty.rotation => 4,
      AnimationProperty.weights =>
        times.isEmpty ? 0 : values.length ~/ (times.length * (isCubic ? 3 : 1)),
      _ => 3,
    };
    if (property == AnimationProperty.weights && componentCount == 0) continue;
    final keyframes = coordinatePolicy.convertAnimationValues(
      selectGltfKeyframeValues(
        values,
        componentCount: componentCount,
        cubicSpline: isCubic,
      ),
      targetPath: channel.targetPath,
    );

    channels.add(
      AnimationChannelSpec(
        target: nodeIds[target],
        targetName: resolveGltfNodeName(doc.nodes[target].name, target),
        property: property,
        timeline: _floatPayload(
          document,
          Float32List.fromList(times),
          PayloadEncoding.floats,
        ),
        keyframes: _floatPayload(document, keyframes, PayloadEncoding.floats),
      ),
    );
  }
  if (channels.isEmpty) return;
  document.addAnimation(
    AnimationSpec(
      document.newId(),
      name: animation.name ?? '',
      channels: channels,
    ),
  );
}

LocalId _floatPayload(
  SceneDocument document,
  Float32List floats,
  PayloadEncoding encoding,
) {
  final bytes = floats.buffer.asUint8List(
    floats.offsetInBytes,
    floats.lengthInBytes,
  );
  return document
      .addPayload(
        PayloadSpec(
          document.newId(),
          encoding: encoding,
          length: bytes.length,
          bytes: bytes,
        ),
      )
      .id;
}

ComponentSpec _meshComponent(
  List<(LocalId, LocalId)> pairs, {
  List<double>? morphWeights,
}) {
  final weights = morphWeights == null
      ? null
      : ListValue([for (final w in morphWeights) DoubleValue(w)]);
  if (pairs.length == 1) {
    return ComponentSpec(
      'mesh',
      properties: {
        'geometry': ResourceRefValue(pairs.first.$1),
        'material': ResourceRefValue(pairs.first.$2),
        if (weights != null) 'morphWeights': weights,
      },
    );
  }
  return ComponentSpec(
    'mesh',
    properties: {
      'primitives': ListValue([
        for (final (geometryId, materialId) in pairs)
          MapValue({
            'geometry': ResourceRefValue(geometryId),
            'material': ResourceRefValue(materialId),
          }),
      ]),
      if (weights != null) 'morphWeights': weights,
    },
  );
}

ComponentSpec? _lightComponent(GltfPunctualLight light) {
  // The extension carries no shadow metadata, so imported lights keep shadow
  // rendering disabled unless the authored scene overrides the component.
  final properties = <String, PropertyValue>{
    'color': Vec3Value(light.color.clone()),
    'intensity': DoubleValue(gltfLightIntensity(light)),
  };
  switch (light.type) {
    case 'directional':
      properties['castsShadow'] = const BoolValue(false);
      return ComponentSpec('directionalLight', properties: properties);
    case 'point':
      properties['range'] = DoubleValue(light.range ?? 0);
      return ComponentSpec('pointLight', properties: properties);
    case 'spot':
      properties
        ..['direction'] = Vec3Value(Vector3(0, 0, 1))
        ..['range'] = DoubleValue(light.range ?? 0)
        ..['innerConeAngle'] = DoubleValue(light.innerConeAngle)
        ..['outerConeAngle'] = DoubleValue(light.outerConeAngle)
        ..['castsShadow'] = const BoolValue(false);
      return ComponentSpec('spotLight', properties: properties);
  }
  return null;
}

TransformSpec _transform(GltfNode node) {
  const policy = GltfCoordinatePolicy.bakeNative;
  if (node.matrix != null) {
    return MatrixTransform(policy.convertTransform(node.matrix!));
  }
  return TrsTransform(
    translation: policy.convertPosition(node.translation ?? Vector3.zero()),
    rotation: policy.convertRotation(node.rotation ?? Quaternion.identity()),
    scale: (node.scale ?? Vector3(1, 1, 1)).clone(),
  );
}

LocalId _buildGeometry(
  SceneDocument document,
  GltfMeshPrimitive primitive,
  GltfDocument doc,
  Uint8List bufferData, {
  required BoundsSpec? bounds,
  required bool includeSkinning,
  List<String> morphTargetNames = const [],
  List<double> defaultMorphWeights = const [],
}) {
  final packed = packGltfPrimitive(
    primitive: primitive,
    accessors: doc.accessors,
    bufferViews: doc.bufferViews,
    bufferData: bufferData,
    coordinatePolicy: GltfCoordinatePolicy.bakeNative,
    includeSkinning: includeSkinning,
  );
  final morph = packed.morphTargets;
  // Unskinned geometry is stored de-interleaved (structure of arrays) so the
  // realizer uploads each attribute straight to its own GPU buffer with no
  // load-time reshuffle. Skinned geometry stays interleaved, as does morphed
  // geometry (whose realizer stashes the interleaved base for CPU blending).
  final Uint8List vertexBytes;
  final String vertexLayout;
  if (packed.isSkinned) {
    vertexBytes = packed.vertexBytes;
    vertexLayout = InterleavedLayoutAdapter.skinnedLayout;
  } else if (morph != null) {
    vertexBytes = packed.vertexBytes;
    vertexLayout = InterleavedLayoutAdapter.unskinnedInterleavedLayout;
  } else {
    vertexBytes = InterleavedLayoutAdapter.concatUnskinnedStreams(
      InterleavedLayoutAdapter.splitUnskinnedAttributes(
        ByteData.sublistView(packed.vertexBytes),
        packed.vertexCount,
      ),
    );
    vertexLayout = InterleavedLayoutAdapter.unskinnedSoaLayout;
  }
  final vertices = document.addPayload(
    PayloadSpec(
      document.newId(),
      encoding: PayloadEncoding.vertexBuffer,
      layout: vertexLayout,
      length: vertexBytes.length,
      bytes: vertexBytes,
    ),
  );
  final indices = document.addPayload(
    PayloadSpec(
      document.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: packed.indices32Bit ? 'uint32' : 'uint16',
      length: packed.indexBytes.length,
      bytes: packed.indexBytes,
    ),
  );
  MorphTargetsSpec? morphSpec;
  if (morph != null) {
    // Dense GPU-ready delta slabs, concatenated positions/normals/tangents.
    final sections = BytesBuilder(copy: false);
    void addSection(Float32List floats) {
      sections.add(
        floats.buffer.asUint8List(floats.offsetInBytes, floats.lengthInBytes),
      );
    }

    addSection(morph.positionDeltas);
    if (morph.normalDeltas != null) addSection(morph.normalDeltas!);
    if (morph.tangentDeltas != null) addSection(morph.tangentDeltas!);
    final deltaBytes = sections.toBytes();
    final deltas = document.addPayload(
      PayloadSpec(
        document.newId(),
        encoding: PayloadEncoding.floats,
        length: deltaBytes.length,
        bytes: deltaBytes,
      ),
    );
    morphSpec = MorphTargetsSpec(
      deltas: deltas.id,
      targetCount: morph.targetCount,
      hasNormalDeltas: morph.normalDeltas != null,
      hasTangentDeltas: morph.tangentDeltas != null,
      targetNames: morphTargetNames,
      defaultWeights: defaultMorphWeights,
    );
  }
  return document
      .addResource(
        GeometryResource(
          document.newId(),
          vertices: vertices.id,
          indices: indices.id,
          bounds: bounds,
          morphTargets: morphSpec,
        ),
      )
      .id;
}

/// Chooses the cull bounds for one shared mesh primitive.
///
/// A primitive used by skinned nodes carries the union of those nodes' baked
/// pose-union AABBs ([poseUnions], aligned with the mesh's triangle-mode
/// primitive order); when any pose union is missing, the primitive carries no
/// bounds and renders unculled. When the mesh is also referenced by an
/// unskinned node, the rest AABB is unioned in so the shared bound covers
/// both usages. Primitives without skinning attributes (or without skinned
/// users) carry the rest AABB.
BoundsSpec? _primitiveBounds(
  GltfMeshPrimitive primitive,
  GltfDocument doc,
  int primIndex, {
  required List<int>? skinnedUsers,
  required bool alsoUsedUnskinned,
  required Map<int, List<AabbBounds?>> poseUnions,
}) {
  final skinnedPrimitive =
      primitive.attributes.containsKey('JOINTS_0') &&
      primitive.attributes.containsKey('WEIGHTS_0');
  if (!skinnedPrimitive || skinnedUsers == null || skinnedUsers.isEmpty) {
    return _restBounds(primitive, doc);
  }

  final box = AabbBounds.empty();
  for (final nodeIndex in skinnedUsers) {
    final unions = poseUnions[nodeIndex];
    final union = unions != null && primIndex < unions.length
        ? unions[primIndex]
        : null;
    // No computable pose union (no joints, empty influence): leave the
    // primitive unbounded so it is never culled mid-animation.
    if (union == null || union.isEmpty) return null;
    box.expandToBounds(union);
  }
  if (alsoUsedUnskinned) {
    final rest = _restBounds(primitive, doc);
    if (rest == null) return null;
    box.includeMinMax(
      rest.min.x,
      rest.min.y,
      rest.min.z,
      rest.max.x,
      rest.max.y,
      rest.max.z,
    );
  }
  if (box.isEmpty) return null;
  return BoundsSpec(
    min: Vector3(box.minX, box.minY, -box.maxZ),
    max: Vector3(box.maxX, box.maxY, -box.minZ),
  );
}

BoundsSpec? _restBounds(GltfMeshPrimitive primitive, GltfDocument doc) {
  final index = primitive.attributes['POSITION'];
  if (index == null) return null;
  final accessor = doc.accessors[index];
  final min = accessor.min;
  final max = accessor.max;
  if (min != null && min.length >= 3 && max != null && max.length >= 3) {
    return BoundsSpec(
      min: Vector3(min[0], min[1], -max[2]),
      max: Vector3(max[0], max[1], -min[2]),
    );
  }
  // No spec-provided bounds; the realizer scans positions on upload.
  return null;
}

LocalId _buildMaterial(
  SceneDocument document,
  GltfMaterial material,
  List<LocalId?> textureIds,
) {
  final pbr = material.pbrMetallicRoughness;
  final base = pbr?.baseColorFactor;
  final properties = <String, PropertyValue>{
    'baseColor': ColorValue(
      _at(base, 0, 1.0),
      _at(base, 1, 1.0),
      _at(base, 2, 1.0),
      _at(base, 3, 1.0),
    ),
    'doubleSided': BoolValue(material.doubleSided),
    'alphaMode': StringValue(material.alphaMode.toLowerCase()),
    'alphaCutoff': DoubleValue(material.alphaCutoff),
  };
  _addTexture(
    properties,
    'baseColorTexture',
    pbr?.baseColorTexture,
    textureIds,
  );

  if (material.unlit) {
    return document
        .addResource(
          MaterialResource(
            document.newId(),
            type: 'unlit',
            name: material.name ?? '',
            properties: properties,
          ),
        )
        .id;
  }

  properties['metallic'] = DoubleValue(pbr?.metallicFactor ?? 0.0);
  properties['roughness'] = DoubleValue(pbr?.roughnessFactor ?? 0.5);
  properties['emissive'] = ColorValue(
    _at(material.emissiveFactor, 0, 0.0),
    _at(material.emissiveFactor, 1, 0.0),
    _at(material.emissiveFactor, 2, 0.0),
    1.0,
  );
  properties['emissiveStrength'] = DoubleValue(material.emissiveStrength);
  properties['occlusionStrength'] = DoubleValue(
    material.occlusionTexture?.strength ?? 1.0,
  );
  if (material.normalTexture?.scale != null) {
    properties['normalScale'] = DoubleValue(material.normalTexture!.scale!);
  }
  _addTexture(
    properties,
    'metallicRoughnessTexture',
    pbr?.metallicRoughnessTexture,
    textureIds,
  );
  _addTexture(properties, 'normalTexture', material.normalTexture, textureIds);
  _addTexture(
    properties,
    'occlusionTexture',
    material.occlusionTexture,
    textureIds,
  );
  _addTexture(
    properties,
    'emissiveTexture',
    material.emissiveTexture,
    textureIds,
  );

  final anisotropy = material.anisotropy;
  if (anisotropy != null) {
    properties['anisotropy'] = DoubleValue(anisotropy.strength);
    properties['anisotropyRotation'] = DoubleValue(anisotropy.rotation);
    _addTexture(
      properties,
      'anisotropyTexture',
      anisotropy.texture,
      textureIds,
    );
  }
  final clearcoat = material.clearcoat;
  if (clearcoat != null) {
    properties['clearcoat'] = DoubleValue(clearcoat.factor);
    properties['clearcoatRoughness'] = DoubleValue(clearcoat.roughnessFactor);
    _addTexture(properties, 'clearcoatTexture', clearcoat.texture, textureIds);
    _addTexture(
      properties,
      'clearcoatRoughnessTexture',
      clearcoat.roughnessTexture,
      textureIds,
    );
    _addTexture(
      properties,
      'clearcoatNormalTexture',
      clearcoat.normalTexture,
      textureIds,
    );
    if (clearcoat.normalTexture?.scale != null) {
      properties['clearcoatNormalScale'] = Vec2Value(
        Vector2.all(clearcoat.normalTexture!.scale!),
      );
    }
  }
  final diffuseTransmission = material.diffuseTransmission;
  if (diffuseTransmission != null) {
    properties['diffuseTransmission'] = DoubleValue(diffuseTransmission.factor);
    properties['diffuseTransmissionColor'] = _color3(
      diffuseTransmission.colorFactor,
      1.0,
    );
    _addTexture(
      properties,
      'diffuseTransmissionTexture',
      diffuseTransmission.texture,
      textureIds,
    );
    _addTexture(
      properties,
      'diffuseTransmissionColorTexture',
      diffuseTransmission.colorTexture,
      textureIds,
    );
  }
  properties['dispersion'] = DoubleValue(material.dispersion);
  properties['ior'] = DoubleValue(material.ior);
  final iridescence = material.iridescence;
  if (iridescence != null) {
    properties['iridescence'] = DoubleValue(iridescence.factor);
    properties['iridescenceIor'] = DoubleValue(iridescence.ior);
    properties['iridescenceThicknessMinimum'] = DoubleValue(
      iridescence.thicknessMinimum,
    );
    properties['iridescenceThicknessMaximum'] = DoubleValue(
      iridescence.thicknessMaximum,
    );
    _addTexture(
      properties,
      'iridescenceTexture',
      iridescence.texture,
      textureIds,
    );
    _addTexture(
      properties,
      'iridescenceThicknessTexture',
      iridescence.thicknessTexture,
      textureIds,
    );
  }
  final sheen = material.sheen;
  if (sheen != null) {
    properties['sheenColor'] = _color3(sheen.colorFactor, 1.0);
    properties['sheenRoughness'] = DoubleValue(sheen.roughnessFactor);
    _addTexture(
      properties,
      'sheenColorTexture',
      sheen.colorTexture,
      textureIds,
    );
    _addTexture(
      properties,
      'sheenRoughnessTexture',
      sheen.roughnessTexture,
      textureIds,
    );
  }
  final specular = material.specular;
  if (specular != null) {
    properties['specular'] = DoubleValue(specular.factor);
    properties['specularColor'] = _color3(specular.colorFactor, 1.0);
    _addTexture(properties, 'specularTexture', specular.texture, textureIds);
    _addTexture(
      properties,
      'specularColorTexture',
      specular.colorTexture,
      textureIds,
    );
  }
  final transmission = material.transmission;
  if (transmission != null) {
    properties['transmission'] = DoubleValue(transmission.factor);
    _addTexture(
      properties,
      'transmissionTexture',
      transmission.texture,
      textureIds,
    );
  }
  final volume = material.volume;
  if (volume != null) {
    properties['thickness'] = DoubleValue(volume.thicknessFactor);
    // The glTF default is +infinity (no attenuation), which JSON cannot
    // carry; absent means infinity on realize.
    if (volume.attenuationDistance.isFinite) {
      properties['attenuationDistance'] = DoubleValue(
        volume.attenuationDistance,
      );
    }
    properties['attenuationColor'] = _color3(volume.attenuationColor, 1.0);
    _addTexture(
      properties,
      'thicknessTexture',
      volume.thicknessTexture,
      textureIds,
    );
  }

  return document
      .addResource(
        MaterialResource(
          document.newId(),
          type: material.requiresPhysicalMaterial
              ? 'physical'
              : 'physicallyBased',
          name: material.name ?? '',
          properties: properties,
        ),
      )
      .id;
}

void _addTexture(
  Map<String, PropertyValue> properties,
  String key,
  GltfTextureInfo? info,
  List<LocalId?> textureIds,
) {
  if (info == null) return;
  if (info.index < 0 || info.index >= textureIds.length) return;
  final id = textureIds[info.index];
  if (id != null) properties[key] = ResourceRefValue(id);
  final transform = info.transform;
  final texCoord = transform?.texCoord ?? info.texCoord;
  if (transform != null || texCoord != 0) {
    properties['${key}Transform'] = MapValue({
      'offset': Vec2Value(
        Vector2(_at(transform?.offset, 0, 0.0), _at(transform?.offset, 1, 0.0)),
      ),
      'scale': Vec2Value(
        Vector2(_at(transform?.scale, 0, 1.0), _at(transform?.scale, 1, 1.0)),
      ),
      'rotation': DoubleValue(transform?.rotation ?? 0.0),
      'texCoord': IntValue(texCoord),
    });
  }
}

ColorValue _color3(List<double> values, double alpha) => ColorValue(
  _at(values, 0, 1.0),
  _at(values, 1, 1.0),
  _at(values, 2, 1.0),
  alpha,
);

/// Carries one glTF texture into the document's resource pool, or returns
/// null when the texture references no decodable image.
///
/// Unlike upstream (which decodes to RGBA8 or cooks to KTX2 through
/// `package:image`), dart3d stores the *encoded* bytes verbatim. The payload
/// `format` records the container (`png`, `jpeg`, `ktx2`, `webp`, ...); both
/// native realizers route any format other than `rgba8`/`ktx2` through their
/// own container sniffing (`UIImage(data:)` / `uploadEncoded`), and `ktx2`
/// through their KTX2 decoders — so no image codec is needed in Dart.
LocalId? _buildTexture(
  SceneDocument document,
  GltfTexture texture,
  GltfDocument doc,
  Uint8List bufferData, {
  TextureContent content = TextureContent.color,
}) {
  // A KHR_texture_basisu KTX2 image wins over the fallback source, matching
  // the runtime importer.
  final sourceIndex = texture.basisuSource ?? texture.source;
  if (sourceIndex == null ||
      sourceIndex < 0 ||
      sourceIndex >= doc.images.length) {
    return null;
  }
  final image = doc.images[sourceIndex];
  if (image.bufferView != null) {
    final viewIndex = image.bufferView!;
    if (viewIndex < 0 || viewIndex >= doc.bufferViews.length) return null;
    final view = doc.bufferViews[viewIndex];
    if (view.meshopt != null) {
      // decodeMeshoptBufferViews replaces compressed views before the
      // emitter runs, so reaching this means the caller skipped that step.
      throw const FormatException(
        'glTF image buffer view is EXT_meshopt_compression-compressed; '
        'decode meshopt views before emitting the document',
      );
    }
    final end = view.byteOffset + view.byteLength;
    if (view.byteOffset < 0 || end > bufferData.length) {
      throw FormatException(
        'glTF image buffer view spans bytes ${view.byteOffset}..$end of a '
        '${bufferData.length} byte buffer',
      );
    }
    final encoded = Uint8List.sublistView(bufferData, view.byteOffset, end);
    final payload = document.addPayload(
      PayloadSpec(
        document.newId(),
        encoding: PayloadEncoding.image,
        format: _imageContainerFormat(encoded, image.mimeType),
        length: encoded.length,
        bytes: encoded,
      ),
    );
    return document
        .addResource(
          TextureResource(
            document.newId(),
            payload: payload.id,
            content: content.name,
          ),
        )
        .id;
  }
  if (image.uri != null) {
    // An external image, carried as an asset reference; the async realize
    // path loads it from the asset bundle by this key, so the uri must be a
    // valid bundle asset path.
    return document
        .addResource(
          TextureResource(
            document.newId(),
            asset: AssetRef(image.uri!),
            content: content.name,
          ),
        )
        .id;
  }
  return null;
}

/// Names the image container [mimeType] (or the magic bytes, when the mime
/// type is missing) for the payload `format` field. Any value other than
/// `rgba8`/`ktx2` lands on the natives' encoded-container path, which sniffs
/// the container itself; `ktx2` names their KTX2 decoder path.
String _imageContainerFormat(Uint8List encoded, String? mimeType) {
  switch (mimeType) {
    case 'image/ktx2':
      return 'ktx2';
    case 'image/png':
      return 'png';
    case 'image/jpeg':
      return 'jpeg';
    case 'image/webp':
      return 'webp';
  }
  // Sniff the magic bytes: KTX2 («KTX 20»), PNG, then JPEG.
  if (encoded.length >= 12 &&
      encoded[0] == 0xAB &&
      encoded[1] == 0x4B &&
      encoded[2] == 0x54 &&
      encoded[3] == 0x58 &&
      encoded[4] == 0x20 &&
      encoded[5] == 0x32 &&
      encoded[6] == 0x30) {
    return 'ktx2';
  }
  if (encoded.length >= 4 &&
      encoded[0] == 0x89 &&
      encoded[1] == 0x50 &&
      encoded[2] == 0x4E &&
      encoded[3] == 0x47) {
    return 'png';
  }
  if (encoded.length >= 3 &&
      encoded[0] == 0xFF &&
      encoded[1] == 0xD8 &&
      encoded[2] == 0xFF) {
    return 'jpeg';
  }
  return 'encoded';
}

double _at(List<double>? values, int index, double fallback) =>
    (values != null && values.length > index) ? values[index] : fallback;

// A 32-bit FNV-1a hash of [data], used to seed deterministic, content-derived
// document and session ids so re-importing the same asset is reproducible.
// The fixed local-id session every import uses, so node ids are positional
// (stable across content edits) rather than content-derived. Distinct imports
// are still distinguished by their content-derived document id.
const int _kImporterIdSession = 0x5ce4e5;

int _seedFrom(Uint8List data) {
  var hash = 0x811c9dc5;
  for (final byte in data) {
    hash = (hash ^ byte) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash == 0 ? 1 : hash;
}

/// Emits `KHR_materials_variants` as `materialsVariants` components, one per
/// scene root whose subtree contains variant-mapped primitives, with each
/// component's bindings scoped to that subtree.
void _emitMaterialsVariants(
  SceneDocument document,
  GltfDocument doc, {
  required List<int> sceneRoots,
  required List<LocalId> nodeIds,
  required List<LocalId> materialIds,
}) {
  // Per glTF node, the binding specs for its variant-mapped primitives. The
  // primitive index counts emitted (triangle) primitives so it matches the
  // realized mesh's primitive order.
  final bindingsByNode = <int, List<PropertyValue>>{};
  for (var i = 0; i < doc.nodes.length; i++) {
    final meshIndex = doc.nodes[i].mesh;
    if (meshIndex == null || meshIndex < 0 || meshIndex >= doc.meshes.length) {
      continue;
    }
    var primIndex = 0;
    for (final primitive in doc.meshes[meshIndex].primitives) {
      if (primitive.mode != 4) continue;
      if (primitive.variantMappings.isNotEmpty) {
        final materials = <String, PropertyValue>{
          for (final entry in primitive.variantMappings.entries)
            if (entry.value >= 0 && entry.value < materialIds.length)
              '${entry.key}': ResourceRefValue(materialIds[entry.value]),
        };
        if (materials.isNotEmpty) {
          final defaultIndex = primitive.material;
          bindingsByNode
              .putIfAbsent(i, () => [])
              .add(
                MapValue({
                  'node': NodeRefValue(nodeIds[i]),
                  'primitive': IntValue(primIndex),
                  // The authored default, kept explicit so an editor save
                  // made while a variant is selected does not bake the
                  // selection in as the default.
                  if (defaultIndex != null &&
                      defaultIndex >= 0 &&
                      defaultIndex < materialIds.length)
                    'default': ResourceRefValue(materialIds[defaultIndex]),
                  'materials': MapValue(materials),
                }),
              );
        }
      }
      primIndex++;
    }
  }
  if (bindingsByNode.isEmpty) return;

  document.featuresUsed.add('materialsVariants');
  final variantNames = ListValue([
    for (final name in doc.materialsVariants) StringValue(name),
  ]);
  for (final root in sceneRoots) {
    if (root < 0 || root >= nodeIds.length) continue;
    // Collect the root's subtree (including itself) in the glTF index space.
    final subtree = <int>[root];
    final bindings = <PropertyValue>[];
    for (var i = 0; i < subtree.length; i++) {
      bindings.addAll(bindingsByNode[subtree[i]] ?? const []);
      for (final child in doc.nodes[subtree[i]].children) {
        if (child >= 0 && child < doc.nodes.length) subtree.add(child);
      }
    }
    if (bindings.isEmpty) continue;
    document.nodes[nodeIds[root]]!.components.add(
      ComponentSpec(
        'materialsVariants',
        properties: {'variants': variantNames, 'bindings': ListValue(bindings)},
      ),
    );
  }
}
