/// W22 conformance harness (spec: docs/full-engine-program.md §W22).
///
/// Walks the vendored Khronos glTF-Sample-Assets catalog
/// (`assets/conformance/catalog.json` — distilled upstream at authoring
/// time, mirroring `fscene_emitter.dart`'s material mapping), encodes
/// every material through the real `writeFscene`/manifest path, and
/// classifies each wire property against the per-platform support
/// table the realizers implement:
///
///   pass   — every property realized, no log expected
///   approx — realized or a documented approximation (log-once at
///            decode); the material still renders
///   warn   — ≥1 property outside the wire vocabulary the realizers
///            handle → an unhandled warn-once at decode
///
/// The matrix is the unit-level half of the spec's "86-asset catalog
/// through the importer asserting each realizes without a warn-once" —
/// the live render check is the verify swarm's lanes. `main()` emits
/// the matrix artifact under `build/conformance/`; the test asserts
/// the report's expectations.
///
/// The golden phase classifies upstream's 37 `smoke_render` scenes
/// against the dart3d wire vocabulary and emits fixture manifests for
/// the applicable subset — the live golden comparison is swarm lane 9.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

// ── Support table ─────────────────────────────────────────────────────

/// How a platform treats a wire property at material decode.
enum Support {
  /// Mapped onto a native material input — no log.
  realized,

  /// Documented approximation (a log-once at decode naming the
  /// approximation or the dropped property) — the material still
  /// realizes and renders; the spec table records the mapping.
  approximated,
}

/// One row of the per-platform extension matrix.
class PropRow {
  const PropRow(this.ios, this.android, this.note);
  final Support ios;
  final Support android;
  final String note;
}

/// The material-property support table — the contract
/// `docs/texture-material-spec.md`'s extension matrix renders and both
/// realizers implement. A property absent here is *unhandled*: the
/// realizers' coverage guard warn-onces it.
///
/// Transform rows are implicit — `<slot>Transform` takes the base
/// slot's status.
const Map<String, PropRow> kMaterialPropertySupport = {
  // Base vocabulary (pre-W22).
  'baseColor': PropRow(Support.realized, Support.realized, ''),
  'baseColorTexture': PropRow(Support.realized, Support.realized, ''),
  'metallic': PropRow(Support.realized, Support.realized, ''),
  'roughness': PropRow(Support.realized, Support.realized, ''),
  'metallicRoughnessTexture': PropRow(Support.realized, Support.realized, ''),
  'normalTexture': PropRow(Support.realized, Support.realized, ''),
  'normalScale': PropRow(Support.realized, Support.realized, ''),
  'occlusionTexture': PropRow(Support.realized, Support.realized, ''),
  'occlusionStrength': PropRow(Support.realized, Support.realized, ''),
  'emissive': PropRow(Support.realized, Support.realized, ''),
  'emissiveStrength': PropRow(
    Support.realized,
    Support.realized,
    'KHR_materials_emissive_strength',
  ),
  'emissiveTexture': PropRow(Support.realized, Support.realized, ''),
  'doubleSided': PropRow(Support.realized, Support.realized, ''),
  'alphaMode': PropRow(Support.realized, Support.realized, ''),
  'alphaCutoff': PropRow(Support.realized, Support.realized, ''),

  // KHR_materials_clearcoat.
  'clearcoat': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: environment-reflection intensity on `reflective`',
  ),
  'clearcoatRoughness': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped — no coat roughness lever',
  ),
  'clearcoatTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: R×factor baked into `reflective` intensity map',
  ),
  'clearcoatRoughnessTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),
  'clearcoatNormalTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),
  'clearcoatNormalScale': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),

  // KHR_materials_sheen.
  'sheenColor': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: tinted `reflective` rim via fresnelExponent',
  ),
  'sheenRoughness': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: folded into fresnelExponent',
  ),
  'sheenColorTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped — sheen rides the reflective approximation',
  ),
  'sheenRoughnessTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),

  // KHR_materials_specular.
  'specular': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: no dielectric-f0 lever under .physicallyBased',
  ),
  'specularColor': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: no f0 tint lever',
  ),
  'specularTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),
  'specularColorTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),

  // KHR_materials_anisotropy.
  'anisotropy': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: no anisotropic lobe',
  ),
  'anisotropyRotation': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),
  'anisotropyTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),

  // KHR_materials_iridescence — Filament 1.71.6 has no iridescence
  // input and SceneKit has none; both sides log once.
  'iridescence': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'iridescenceIor': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'iridescenceThicknessMinimum': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'iridescenceThicknessMaximum': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'iridescenceTexture': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'iridescenceThicknessTexture': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),

  // KHR_materials_transmission.
  'transmission': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: thin-blend approximation via `transparent`',
  ),
  'transmissionTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: baked into `transparent` alpha',
  ),

  // KHR_materials_volume.
  'thickness': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped — no refraction volume',
  ),
  'thicknessTexture': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),
  'attenuationColor': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),
  'attenuationDistance': PropRow(
    Support.approximated,
    Support.realized,
    'iOS: dropped',
  ),

  // KHR_materials_dispersion — Android realizes only on the SOLID
  // refraction variant (thickness>0); THIN warns + drops per Filament's
  // field guard.
  'dispersion': PropRow(
    Support.approximated,
    Support.realized,
    'Android: SOLID refraction only; iOS: logged only',
  ),

  // KHR_materials_ior.
  'ior': PropRow(
    Support.approximated,
    Support.realized,
    'Android: `material.ior`; iOS: no IOR lever',
  ),

  // KHR_materials_diffuse_transmission — neither material system has a
  // diffuse-transmission input; both sides log once.
  'diffuseTransmission': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'diffuseTransmissionColor': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'diffuseTransmissionTexture': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
  'diffuseTransmissionColorTexture': PropRow(
    Support.approximated,
    Support.approximated,
    'logged only',
  ),
};

/// `<slot>Transform` (KHR_texture_transform) takes the base slot's
/// status — both platforms decode the transform map for every bound
/// slot; a transform on an approximation-only slot approximates with it.
String _baseSlot(String prop) =>
    prop.endsWith('Transform') && prop.length > 'Transform'.length
    ? prop.substring(0, prop.length - 'Transform'.length)
    : prop;

/// The KHR_materials_volume slots `extFlagsFor` guards when no
/// transmission arms the material — its warn is "volume props
/// without transmission are inert — dropped". `thickness` trips it
/// only when nonzero; the other three trip on presence alone.
const _volumeProps = {
  'thickness',
  'thicknessTexture',
  'attenuationColor',
  'attenuationDistance',
};

/// Per-property classification. [value] is the catalog's declared
/// property value; [hasTransmission] says the owning material carries
/// transmission>0 or a transmission texture; [solidVolume] says it
/// additionally carries thickness>0.
///
/// `ior` and `dispersion` are the two properties upstream emits on
/// EVERY material — at their no-op defaults (1.5 / 0) they classify
/// `pass` rather than approximating nothing. Android's `dispersion`
/// field exists only under SOLID refraction, so a nonzero dispersion
/// outside a transmissive solid volume is a documented drop
/// (warn-once), not a realization. The volume props share the
/// transmission gate: on Android they realize only alongside it —
/// without it `extFlagsFor` warn-onces the inert drop, which is
/// `approx` under the matrix's own definition. iOS logs the volume
/// lobe dropped either way, so its rows already read approximated.
Support? _classify(
  String platform,
  String prop,
  Object? value, {
  required bool hasTransmission,
  required bool solidVolume,
}) {
  final row =
      kMaterialPropertySupport[prop] ??
      kMaterialPropertySupport[_baseSlot(prop)];
  if (row == null) return null;
  if (prop == 'ior' && (value as num?)?.toDouble() == 1.5) {
    return Support.realized;
  }
  if (prop == 'dispersion') {
    if ((value as num?)?.toDouble() == 0) return Support.realized;
    return platform == 'android'
        ? (solidVolume ? Support.realized : Support.approximated)
        : Support.approximated;
  }
  if (platform == 'android' &&
      !hasTransmission &&
      _volumeProps.contains(prop) &&
      (prop != 'thickness' || ((value as num?)?.toDouble() ?? 0) > 0)) {
    return Support.approximated;
  }
  return switch (platform) {
    'ios' => row.ios,
    'android' => row.android,
    _ => throw ArgumentError(platform),
  };
}

/// Worst-case ordering: warn > approx > pass.
enum RowStatus { pass, approx, warn }

RowStatus _statusOf(Support? s) => switch (s) {
  Support.realized => RowStatus.pass,
  Support.approximated => RowStatus.approx,
  null => RowStatus.warn,
};

// ── Catalog → wire manifest ───────────────────────────────────────────

/// The catalog's property value forms: numbers, bools, strings, 2- and
/// 4-lists, `{'texture': true}` for a texture ref, `{'texCoord': N}`
/// for a slot transform carrying just the channel selector.
PropertyValue _propValue(Object? v, LocalId tex) {
  if (v is Map) {
    if (v['texture'] == true) return ResourceRefValue(tex);
    if (v.containsKey('texCoord')) {
      return MapValue({
        'offset': Vec2Value(Vector2.zero()),
        'scale': Vec2Value(Vector2(1, 1)),
        'rotation': DoubleValue(0),
        'texCoord': IntValue(v['texCoord'] as int? ?? 0),
      });
    }
    throw ArgumentError('catalog property map $v');
  }
  if (v is bool) return BoolValue(v);
  if (v is String) return StringValue(v);
  if (v is num) return DoubleValue(v.toDouble());
  if (v is List) {
    if (v.length == 4) {
      return ColorValue(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      );
    }
    if (v.length == 2) {
      return Vec2Value(
        Vector2((v[0] as num).toDouble(), (v[1] as num).toDouble()),
      );
    }
    if (v.length == 3) {
      return Vec3Value(
        Vector3(
          (v[0] as num).toDouble(),
          (v[1] as num).toDouble(),
          (v[2] as num).toDouble(),
        ),
      );
    }
  }
  throw ArgumentError('catalog property value $v');
}

/// Builds the wire document one catalog material produces: a texture
/// resource per referenced slot (bytes pending, the deferred-texture
/// lane) plus the material itself. Returns the decoded manifest JSON —
/// the same bytes the native `realize` consumes.
Map<String, dynamic> materialManifest(
  String type,
  Map<String, Object?> catalogProps,
) {
  final doc = SceneDocument();
  final pending = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 2,
      height: 2,
      length: 2 * 2 * 4,
    ),
  );
  final tex = doc.addResource(
    TextureResource(doc.newId(), payload: pending.id),
  );
  doc.addResource(
    MaterialResource(
      doc.newId(),
      type: type,
      properties: {
        for (final e in catalogProps.entries)
          e.key: _propValue(e.value, tex.id),
      },
    ),
  );
  return jsonDecode(utf8.decode(D3Protocol.loadSceneBytes(doc)))
      as Map<String, dynamic>;
}

/// The material entry's property names as they land on the wire.
Set<String> manifestPropNames(Map<String, dynamic> manifest) {
  final resources = manifest['resources'] as Map<String, dynamic>;
  final material = resources.values
      .map((r) => r as Map<String, dynamic>)
      .singleWhere((r) => r['kind'] == 'material');
  return (material['properties'] as Map<String, dynamic>).keys.toSet();
}

// ── The walk ──────────────────────────────────────────────────────────

/// Per-asset matrix rows, one per platform.
class AssetRow {
  AssetRow(this.name, this.extensionsUsed);

  final String name;
  final List<String> extensionsUsed;
  final Map<String, RowStatus> status = {
    'ios': RowStatus.pass,
    'android': RowStatus.pass,
  };
  final Map<String, List<String>> approximated = {'ios': [], 'android': []};
  final Map<String, List<String>> unhandled = {'ios': [], 'android': []};

  void classify(
    String platform,
    String prop,
    Object? value, {
    required bool hasTransmission,
    required bool solidVolume,
  }) {
    final s = _statusOf(
      _classify(
        platform,
        prop,
        value,
        hasTransmission: hasTransmission,
        solidVolume: solidVolume,
      ),
    );
    final cur = status[platform]!;
    if (s.index > cur.index) status[platform] = s;
    if (s == RowStatus.approx && !approximated[platform]!.contains(prop)) {
      approximated[platform]!.add(prop);
    }
    if (s == RowStatus.warn && !unhandled[platform]!.contains(prop)) {
      unhandled[platform]!.add(prop);
    }
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'extensionsUsed': extensionsUsed,
    'ios': _platformJson('ios'),
    'android': _platformJson('android'),
  };

  Map<String, Object?> _platformJson(String p) => {
    'status': status[p]!.name,
    if (approximated[p]!.isNotEmpty) 'approximated': approximated[p],
    if (unhandled[p]!.isNotEmpty) 'unhandled': unhandled[p],
  };
}

class ConformanceReport {
  final rows = <AssetRow>[];
  final errors = <String>[];

  Map<String, Map<RowStatus, int>> summary() => {
    for (final p in ['ios', 'android'])
      p: {
        for (final s in RowStatus.values)
          s: rows.where((r) => r.status[p] == s).length,
      },
  };

  Map<String, Object?> toJson() => {
    'source': 'KhronosGroup/glTF-Sample-Assets (vendored subset)',
    'assetCount': rows.length,
    'summary': {
      for (final p in summary().entries)
        p.key: {for (final s in p.value.entries) s.key.name: s.value},
    },
    if (errors.isNotEmpty) 'errors': errors,
    'assets': [for (final r in rows) r.toJson()],
  };
}

/// Walks the catalog: encodes each material through the manifest path
/// and classifies every wire property on both platforms.
ConformanceReport runConformance(Map<String, dynamic> catalog) {
  final report = ConformanceReport();
  for (final a in catalog['assets'] as List<dynamic>) {
    final asset = a as Map<String, dynamic>;
    final name = asset['name'] as String;
    if (asset['error'] != null) {
      report.errors.add('$name: ${asset['error']}');
      continue;
    }
    final row = AssetRow(
      name,
      (asset['extensionsUsed'] as List? ?? []).cast<String>(),
    );
    for (final m in asset['materials'] as List<dynamic>? ?? []) {
      final mat = m as Map<String, dynamic>;
      final declared = (mat['properties'] as Map).cast<String, Object?>();
      // Mirrors extFlagsFor: a transmission factor or texture arms
      // the transmission feature; the solid-volume bit additionally
      // needs nonzero thickness (it gates the dispersion rule).
      final hasTransmission =
          (declared['transmission'] as num? ?? 0) > 0 ||
          declared.containsKey('transmissionTexture');
      final solidVolume =
          hasTransmission && (declared['thickness'] as num? ?? 0) > 0;
      final manifest = materialManifest(mat['type'] as String, declared);
      for (final prop in manifestPropNames(manifest)) {
        row.classify(
          'ios',
          prop,
          declared[prop],
          hasTransmission: hasTransmission,
          solidVolume: solidVolume,
        );
        row.classify(
          'android',
          prop,
          declared[prop],
          hasTransmission: hasTransmission,
          solidVolume: solidVolume,
        );
      }
    }
    report.rows.add(row);
  }
  return report;
}

// ── Golden scenes ─────────────────────────────────────────────────────

/// One upstream `smoke_render` scene classified against the dart3d
/// wire vocabulary. [fixture] names a generated manifest the runner
/// emits; null means the lane authors the scene by hand.
class GoldenScene {
  const GoldenScene(
    this.name, {
    required this.applies,
    this.reason,
    this.fixture,
  });
  final String name;
  final bool applies;
  final String? reason;
  final String? fixture;
}

/// The 37 upstream `smoke_render` scenes (master @00b5870) vs the
/// dart3d wire surface. 20 apply; 17 get generated fixtures.
const goldenScenes = <GoldenScene>[
  GoldenScene('pbr_cuboid', applies: true, fixture: 'pbr_cuboid'),
  GoldenScene(
    'depth_post',
    applies: false,
    reason: 'post-process depth visualization pass — no wire equivalent',
  ),
  GoldenScene(
    'ambient_occlusion_edge',
    applies: false,
    reason: 'upstream-specific AO edge debug pass',
  ),
  GoldenScene(
    'ambient_occlusion_gtao',
    applies: false,
    reason:
        'GTAO is an upstream pipeline technique; dart3d realizes '
        'the stage `ambientOcclusion` block as platform SSAO — not '
        'parameter-equivalent',
  ),
  GoldenScene(
    'ssgi',
    applies: false,
    reason:
        'upstream screen-space GI pass; the `globalIllumination` '
        'block is platform-mapped, not parameter-equivalent',
  ),
  GoldenScene('area_light', applies: true, fixture: 'area_light'),
  GoldenScene(
    'soft_shadows',
    applies: false,
    reason: 'no softness/PCSS controls on the wire (DPCF is fixed)',
  ),
  GoldenScene('punctual_shadows', applies: true, fixture: 'punctual_shadows'),
  GoldenScene(
    'smaa',
    applies: false,
    reason: 'no SMAA control on the wire (temporalAntiAliasing differs)',
  ),
  GoldenScene(
    'reflection_probe',
    applies: false,
    reason: 'no reflection-probe component',
  ),
  GoldenScene(
    'planar_mirror',
    applies: false,
    reason: 'needs upstream .fmat custom material',
  ),
  GoldenScene('lens_flare', applies: true, fixture: 'lens_flare'),
  GoldenScene('pbr_metallic', applies: true, fixture: 'pbr_metallic'),
  GoldenScene(
    'dielectric_specular',
    applies: true,
    fixture: 'dielectric_specular',
  ),
  GoldenScene('physical_layered', applies: true, fixture: 'physical_layered'),
  GoldenScene(
    'physical_transmission',
    applies: true,
    fixture: 'physical_transmission',
  ),
  GoldenScene('mirrored_node', applies: true, fixture: 'mirrored_node'),
  GoldenScene(
    'instanced_lighting',
    applies: false,
    reason: 'no prefab/instance component on the wire',
  ),
  GoldenScene(
    'directional_shadow',
    applies: true,
    fixture: 'directional_shadow',
  ),
  GoldenScene(
    'orthographic_camera',
    applies: true,
    fixture: 'orthographic_camera',
  ),
  GoldenScene(
    'debug_view',
    applies: false,
    reason: 'upstream debug render mode',
  ),
  GoldenScene(
    'shadow_catcher',
    applies: false,
    reason: 'no shadow-catcher material flag on the wire',
  ),
  GoldenScene(
    'compressed_texture',
    applies: true,
    fixture: 'compressed_texture',
  ),
  GoldenScene('texture_mips', applies: true, fixture: 'texture_mips'),
  GoldenScene('basisu_textures', applies: true, fixture: 'basisu_textures'),
  GoldenScene(
    'fmat_custom_material',
    applies: false,
    reason: '.fmat is upstream-only',
  ),
  GoldenScene('decal', applies: false, reason: 'no decal component'),
  GoldenScene('fog', applies: true, fixture: 'fog'),
  GoldenScene('auto_exposure', applies: true, fixture: 'auto_exposure'),
  GoldenScene(
    'gaussian_splats',
    applies: false,
    reason: 'no gaussian-splat primitive',
  ),
  GoldenScene(
    'skinned_animation',
    applies: true,
    reason:
        'realizable — fixture needs a real skin payload; the lane '
        'authors it from the showcase skin assets',
  ),
  GoldenScene(
    'morph_skinned',
    applies: true,
    reason:
        'realizable — fixture needs morph+skin payloads; the lane '
        'authors it',
  ),
  GoldenScene(
    'raw_shader_pair',
    applies: false,
    reason: 'custom shader pair — no wire equivalent',
  ),
  GoldenScene('prebaked_ibl', applies: true, fixture: 'prebaked_ibl'),
  GoldenScene(
    'baked_lightmap',
    applies: true,
    reason:
        'realizable via texCoord 1 — fixture needs a uv1-bearing '
        'mesh; the lane authors it',
  ),
  GoldenScene(
    'cascade_shaping',
    applies: false,
    reason: 'upstream CSM shaping debug — no wire equivalent',
  ),
  GoldenScene(
    'instance_attributes',
    applies: false,
    reason: 'no per-instance custom attributes on the wire',
  ),
];

// ── Golden fixture manifests ──────────────────────────────────────────

LocalId _meshNode(
  SceneDocument doc,
  String shape,
  Map<String, Object?> shapeProps,
  Map<String, PropertyValue> matProps, {
  String matType = 'physicallyBased',
  Vector3? translation,
  Vector3? scale,
}) {
  final geo = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: shape == 'cuboid'
          ? CuboidGeometrySpec(
              extents: shapeProps['extents'] as Vector3? ?? Vector3.all(1.0),
            )
          : shape == 'sphere'
          ? SphereGeometrySpec(radius: (shapeProps['radius'] as double?) ?? 0.5)
          : PlaneGeometrySpec(
              width: (shapeProps['width'] as double?) ?? 1,
              depth: (shapeProps['depth'] as double?) ?? 1,
            ),
    ),
  );
  final mat = doc.addResource(
    MaterialResource(doc.newId(), type: matType, properties: matProps),
  );
  final node = doc.createNode(
    name: 'subject',
    transform: TrsTransform(
      translation: translation ?? Vector3(0, 0.9, 0),
      scale: scale ?? Vector3.all(1),
    ),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(geo.id),
          'material': ResourceRefValue(mat.id),
        },
      ),
    ],
    root: true,
  );
  return node.id;
}

void _groundAndCamera(
  SceneDocument doc, {
  bool ortho = false,
  Vector3? camPos,
}) {
  final groundGeo = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(8, 0.4, 6)),
    ),
  );
  final groundMat = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(0.2, 0.2, 0.24, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.9),
      },
    ),
  );
  doc.createNode(
    name: 'ground',
    transform: TrsTransform(translation: Vector3(0, -0.4, 1.2)),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(groundGeo.id),
          'material': ResourceRefValue(groundMat.id),
        },
      ),
    ],
    root: true,
  );
  doc.createNode(
    name: 'camera',
    transform: TrsTransform(
      translation: camPos ?? Vector3(0, 2.0, -4.0),
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.3),
    ),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': StringValue(ortho ? 'orthographic' : 'perspective'),
          if (ortho) 'orthographicScale': DoubleValue(3.0),
          'fovRadiansY': DoubleValue(0.9),
          'near': DoubleValue(0.05),
          'far': DoubleValue(100),
        },
      ),
    ],
    root: true,
  );
  doc.createNode(
    name: 'key',
    transform: TrsTransform(
      rotation: Quaternion.axisAngle(Vector3(0.7, 0, 0.7)..normalize(), -0.8),
    ),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': ColorValue(1, 1, 1, 1),
          'intensity': DoubleValue(1400),
          'castsShadow': BoolValue(true),
        },
      ),
    ],
    root: true,
  );
}

/// The fixture generator for each named golden fixture: a minimal
/// `.fscene` document whose subject exercises the scene's
/// distinguishing feature.
SceneDocument goldenFixture(String name) {
  final doc = SceneDocument();
  switch (name) {
    case 'pbr_cuboid':
      _meshNode(doc, 'cuboid', {}, {
        'baseColor': ColorValue(0.8, 0.25, 0.2, 1),
        'metallic': DoubleValue(0.1),
        'roughness': DoubleValue(0.4),
      });
    case 'pbr_metallic':
      _meshNode(doc, 'sphere', {}, {
        'baseColor': ColorValue(0.7, 0.7, 0.75, 1),
        'metallic': DoubleValue(1.0),
        'roughness': DoubleValue(0.15),
      });
    case 'dielectric_specular':
      _meshNode(doc, 'sphere', {}, {
        'baseColor': ColorValue(0.4, 0.6, 0.9, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.3),
        'specular': DoubleValue(0.2),
        'specularColor': ColorValue(1, 0.5, 0.3, 1),
      }, matType: 'physical');
    case 'physical_layered':
      _meshNode(doc, 'sphere', {}, {
        'baseColor': ColorValue(0.15, 0.3, 0.6, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.6),
        'clearcoat': DoubleValue(1.0),
        'clearcoatRoughness': DoubleValue(0.1),
        'sheenColor': ColorValue(0.5, 0.3, 0.1, 1),
        'sheenRoughness': DoubleValue(0.5),
      }, matType: 'physical');
    case 'physical_transmission':
      _meshNode(doc, 'sphere', {}, {
        'baseColor': ColorValue(0.9, 0.95, 1, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.1),
        'transmission': DoubleValue(1.0),
        'ior': DoubleValue(1.5),
        'thickness': DoubleValue(0.8),
        'attenuationColor': ColorValue(0.8, 0.95, 1, 1),
        'attenuationDistance': DoubleValue(2.0),
      }, matType: 'physical');
    case 'mirrored_node':
      _meshNode(doc, 'cuboid', {}, {
        'baseColor': ColorValue(0.85, 0.7, 0.2, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.5),
        'doubleSided': BoolValue(true),
      }, scale: Vector3(-1, 1, 1));
    case 'directional_shadow':
    case 'punctual_shadows':
      _meshNode(doc, 'cuboid', {}, {
        'baseColor': ColorValue(0.7, 0.3, 0.25, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.8),
      });
      if (name == 'punctual_shadows') {
        doc.createNode(
          name: 'spot',
          transform: TrsTransform(
            translation: Vector3(2.5, 3.5, 0),
            rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 1.2),
          ),
          components: [
            ComponentSpec(
              'spotLight',
              properties: {
                'color': ColorValue(1, 0.9, 0.8, 1),
                'intensity': DoubleValue(300),
                'range': DoubleValue(15),
                'innerConeAngle': DoubleValue(0.3),
                'outerConeAngle': DoubleValue(0.6),
                'castsShadow': BoolValue(true),
              },
            ),
          ],
          root: true,
        );
      }
    case 'area_light':
      _meshNode(doc, 'cuboid', {}, {
        'baseColor': ColorValue(0.7, 0.7, 0.72, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.7),
      });
      // rectAreaLight is a wire component (W12): iOS decodes
      // SCNLight.area with drawsArea (the emitter renders itself);
      // Android approximates a 4-point cluster and leaves the visible
      // emitter to the document — hence the emissive panel below.
      // −90° about X turns the light's −Z emission axis down onto the
      // subject, the orientation feature_scene's w12 panel verifies.
      doc.createNode(
        name: 'areaLight',
        transform: TrsTransform(
          translation: Vector3(0, 2.2, 0.6),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -1.5708),
        ),
        components: [
          ComponentSpec(
            'rectAreaLight',
            properties: {
              'width': DoubleValue(2.0),
              'height': DoubleValue(1.0),
              'intensity': DoubleValue(240.0),
              'color': ColorValue(1.0, 0.9, 0.75, 1.0),
            },
          ),
        ],
        root: true,
      );
      // The emitter panel — PlaneGeometrySpec is an XZ quad, already
      // horizontal in the light's frame; doubleSided so it shows from
      // below.
      final emitterGeo = doc.addResource(
        GeometryResource(
          doc.newId(),
          procedural: PlaneGeometrySpec(width: 2.0, depth: 1.0),
        ),
      );
      final emitterMat = doc.addResource(
        MaterialResource(
          doc.newId(),
          type: 'physicallyBased',
          properties: {
            'baseColor': ColorValue(0, 0, 0, 1),
            'emissive': ColorValue(1.0, 0.9, 0.75, 1),
            'emissiveStrength': DoubleValue(4),
            'doubleSided': BoolValue(true),
            'metallic': DoubleValue(0),
            'roughness': DoubleValue(1),
          },
        ),
      );
      doc.createNode(
        name: 'areaEmitter',
        transform: TrsTransform(translation: Vector3(0, 2.2, 0.6)),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(emitterGeo.id),
              'material': ResourceRefValue(emitterMat.id),
            },
          ),
        ],
        root: true,
      );
    case 'orthographic_camera':
      _meshNode(doc, 'cuboid', {}, {
        'baseColor': ColorValue(0.3, 0.7, 0.4, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.6),
      });
    case 'compressed_texture':
    case 'texture_mips':
    case 'basisu_textures':
      final ref = name == 'texture_mips'
          ? 'assets/uastc_srgb_mips_zstd_64.ktx2'
          : name == 'basisu_textures'
          ? 'assets/etc1s_srgb_mips_64.ktx2'
          : 'assets/uncompressed_rgba8_64.ktx2';
      final tex = doc.addResource(
        TextureResource(doc.newId(), asset: AssetRef(ref)),
      );
      _meshNode(
        doc,
        'plane',
        {'width': 2.4, 'depth': 2.4},
        {
          'baseColor': ColorValue(1, 1, 1, 1),
          'baseColorTexture': ResourceRefValue(tex.id),
          'metallic': DoubleValue(0),
          'roughness': DoubleValue(0.9),
        },
      );
    case 'lens_flare':
      _meshNode(doc, 'sphere', {}, {
        'baseColor': ColorValue(0.2, 0.2, 0.25, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.4),
      });
      doc.stage.environmentRef = doc
          .addResource(
            EnvironmentResource(
              doc.newId(),
              effects: EnvironmentEffectsSpec(lensFlareEnabled: true),
            ),
          )
          .id;
    case 'fog':
      _meshNode(doc, 'cuboid', {}, {
        'baseColor': ColorValue(0.6, 0.55, 0.5, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.9),
      });
      doc.stage.environmentRef = doc
          .addResource(
            EnvironmentResource(
              doc.newId(),
              effects: EnvironmentEffectsSpec(
                fogEnabled: true,
                fogDensity: 0.06,
                fogEnd: 12,
              ),
            ),
          )
          .id;
    case 'auto_exposure':
      _meshNode(doc, 'sphere', {}, {
        'baseColor': ColorValue(0.9, 0.85, 0.4, 1),
        'emissive': ColorValue(2.5, 2.2, 1.2, 1),
        'metallic': DoubleValue(0),
        'roughness': DoubleValue(0.5),
      });
      doc.stage.environmentRef = doc
          .addResource(
            EnvironmentResource(
              doc.newId(),
              effects: EnvironmentEffectsSpec(autoExposureEnabled: true),
            ),
          )
          .id;
    case 'prebaked_ibl':
      final env = doc.addResource(
        EnvironmentResource(
          doc.newId(),
          environment: AssetEnvironment(AssetRef('assets/rgb_4x2.hdr')),
          skybox: SkyboxSpec(EnvironmentSkySpec()),
        ),
      );
      doc.stage.environmentRef = env.id;
      _meshNode(doc, 'sphere', {}, {
        'baseColor': ColorValue(0.8, 0.8, 0.85, 1),
        'metallic': DoubleValue(1.0),
        'roughness': DoubleValue(0.2),
      });
    default:
      throw ArgumentError('no generator for golden fixture $name');
  }
  _groundAndCamera(doc, ortho: name == 'orthographic_camera');
  return doc;
}

// ── Runner ────────────────────────────────────────────────────────────

/// Locates the dart3d example package root from the current working
/// directory (test and `dart run` both resolve here).
Directory exampleRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        File('${dir.path}/tool/conformance_runner.dart').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  return Directory.current;
}

Map<String, dynamic> loadCatalog() =>
    jsonDecode(
          File(
            '${exampleRoot().path}/assets/conformance/catalog.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Emits the conformance matrix + golden manifest artifacts under
/// `build/conformance/`. Returns the output directory.
Directory writeArtifacts(ConformanceReport report) {
  final out = Directory('${exampleRoot().path}/build/conformance')
    ..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  File(
    '${out.path}/conformance-matrix.json',
  ).writeAsStringSync(encoder.convert(report.toJson()));

  final golden = [
    for (final s in goldenScenes)
      {
        'name': s.name,
        'applies': s.applies,
        if (s.reason != null) 'reason': s.reason,
        if (s.fixture != null) 'fixture': 'golden/${s.fixture}.fscene.json',
      },
  ];
  File('${out.path}/golden-manifest.json').writeAsStringSync(
    encoder.convert({
      'source':
          'bdero/flutter_scene examples/smoke_render '
          '(37 scenes, master @00b5870)',
      'applicable': goldenScenes.where((s) => s.applies).length,
      'total': goldenScenes.length,
      'scenes': golden,
    }),
  );
  final fixtures = Directory('${out.path}/golden')..createSync();
  for (final s in goldenScenes.where((s) => s.fixture != null)) {
    final manifest = jsonDecode(
      utf8.decode(D3Protocol.loadSceneBytes(goldenFixture(s.fixture!))),
    );
    File(
      '${fixtures.path}/${s.fixture}.fscene.json',
    ).writeAsStringSync(encoder.convert(manifest));
  }
  return out;
}

void main() {
  final report = runConformance(loadCatalog());
  final out = writeArtifacts(report);
  final summary = report.summary();
  for (final p in ['ios', 'android']) {
    final s = summary[p]!;
    stdout.writeln(
      '$p: ${s[RowStatus.pass]} pass, ${s[RowStatus.approx]} approx, '
      '${s[RowStatus.warn]} warn across ${report.rows.length} assets',
    );
  }
  final warns = report.rows.where(
    (r) => r.unhandled.values.any((l) => l.isNotEmpty),
  );
  for (final r in warns) {
    stdout.writeln('  WARN ${r.name}: ${r.unhandled}');
  }
  stdout.writeln('artifacts → ${out.path}');
}
