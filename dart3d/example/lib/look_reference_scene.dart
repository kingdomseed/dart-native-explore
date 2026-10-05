/// The look-reference board (`--dart-define=DART3D_SCENE=lookref`): a
/// flat chart of patches whose rendered colour is measured on each
/// platform and compared (`tool/look_compare.py`).
///
/// The board lies in the XY plane facing the camera, which looks along
/// +Z from far away through a narrow lens, so a patch's board
/// coordinates map linearly to pixels. Two unlit magenta squares mark
/// the board's top-left and bottom-right corners; the tool finds them
/// and derives that map, whatever the screen size.
///
/// The camera is not orthographic: under an orthographic projection
/// Filament 1.71 clips a point or spot light to a cross of froxels
/// once the light is off the view axis.
///
/// Pure Dart (no `dartnative` imports) so the document and the patch
/// table are reachable under `dart test`.
// ignore_for_file: implementation_imports
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';

/// One state of the board. Each lights the chart with one source, or
/// resolves it with one tone mapper, so a difference between platforms
/// can be traced to a single stage of the pipeline.
enum LookVariant {
  /// No lights and no IBL: unlit, emissive and sky patches only.
  unlitLinear('unlit-linear', toneMapping: 'linear'),
  unlitNeutral('unlit-neutral'),
  unlitAces('unlit-aces', toneMapping: 'aces'),
  unlitExposure2('unlit-exposure2', toneMapping: 'linear', exposure: 2),
  directional('directional', toneMapping: 'linear', directionalLight: true),
  point('point', toneMapping: 'linear', pointLight: true),
  spot('spot', toneMapping: 'linear', spotLight: true),
  iblConstant('ibl-constant', toneMapping: 'linear', ibl: LookIbl.constant),

  /// The studio environment at half intensity. The sky behind the board
  /// is its own source and must not dim with it.
  iblStudio(
    'ibl-studio',
    toneMapping: 'linear',
    ibl: LookIbl.studio,
    environmentIntensity: 0.5,
  ),
  all(
    'all',
    directionalLight: true,
    pointLight: true,
    spotLight: true,
    ibl: LookIbl.constant,
  ),

  /// The directional light over a document with no environment at all:
  /// what a scene gets before its author sets anything. It keeps the
  /// effects of the variant before it (an absent `effects` block
  /// leaves them alone), so it follows one without bloom.
  defaultStage('default-stage', directionalLight: true, stage: false),
  allBloom(
    'all-bloom',
    directionalLight: true,
    pointLight: true,
    spotLight: true,
    ibl: LookIbl.constant,
    bloom: true,
  );

  const LookVariant(
    this.label, {
    this.toneMapping = 'pbrNeutral',
    this.exposure = 1,
    this.directionalLight = false,
    this.pointLight = false,
    this.spotLight = false,
    this.ibl = LookIbl.none,
    this.bloom = false,
    this.stage = true,
    this.environmentIntensity = 1,
  });

  final String label;
  final String toneMapping;
  final double exposure;
  final bool directionalLight;
  final bool pointLight;
  final bool spotLight;
  final LookIbl ibl;
  final bool bloom;

  /// Whether the document carries an environment resource.
  final bool stage;
  final double environmentIntensity;
}

enum LookIbl { none, constant, studio }

/// What a patch shows, which decides the tolerance it is held to.
enum LookPatchKind {
  unlit,
  emissive,
  texture,
  sky,
  lit,
  sphere,
  light,
  shadow,
}

/// A measured region of the board, in board units (+X right, +Y up).
final class LookPatch {
  const LookPatch(this.name, this.kind, this.x, this.y, this.halfSize);

  final String name;
  final LookPatchKind kind;
  final double x;
  final double y;
  final double halfSize;

  Map<String, Object> toJson() => {
    'name': name,
    'kind': kind.name,
    'x': x,
    'y': y,
    'half': halfSize,
  };
}

/// The board's lights. Each puts an irradiance of 2 on the card it
/// faces head-on: the directional light everywhere, the point light
/// from 1 unit away and the spot light from 1.5.
const double kLookDirectionalIntensity = 2;
const double kLookPointIntensity = 2;
const double kLookSpotIntensity = 4.5;

/// The directional light's travel direction: 30° off the board's
/// normal, from the upper left.
final Vector3 kLookLightTravel = Vector3(0.35, -0.35, 0.87)..normalize();

/// Radiance of the constant environment, and of the sky behind the board.
const double kLookIblRadiance = 0.5;
final Vector3 kLookSkyColor = Vector3(0.1, 0.2, 0.4);

/// Half-angles of the spot light's cone, radians.
const double kLookSpotInner = 15 * pi / 180;
const double kLookSpotOuter = 30 * pi / 180;

const double _cell = 1.0;
const double _patch = 0.8;
const double _measure = 0.2;
const double _left = -2.5;
const double _depth = 0.02;

const _greys = [0.02, 0.05, 0.18, 0.5, 1.0];
const _hues = <String, (double, double, double)>{
  'red': (1, 0, 0),
  'green': (0, 1, 0),
  'blue': (0, 0, 1),
  'cyan': (0, 1, 1),
  'magenta': (1, 0, 1),
  'yellow': (1, 1, 0),
};
const _indigo = (0.02, 0.03, 0.08);
const _emissive = <String, (double, double, double)>{
  'grey0.18': (0.18, 0.18, 0.18),
  'white1': (1, 1, 1),
  'white4': (4, 4, 4),
  'orange1': (1, 0.2, 0.05),
  'orange4': (4, 0.8, 0.2),
  'blue2': (0.2, 0.8, 2),
};
const _litGreys = [0.04, 0.18, 0.5, 1.0];

/// sRGB-encoded texel colours of the textured row.
const _lime = (181, 199, 94);
const _pink = (250, 96, 166);
const _midGrey = (128, 128, 128);

/// Row centres, top to bottom.
const double _yTexture = 6.5;
const double _yUnlitGrey = 5.5;
const double _yUnlitHue = 4.5;
const double _yEmissive = 3.5;
const double _yLitGrey = 2.5;
const double _yLitHue = 1.5;
const double _ySphere = 0.3;
const double _yLights = -1.3;
const double _yShadow = -3.9;

/// Board extent the camera has to cover, and the fiducial squares that
/// mark it.
const double kLookBoardLeft = -3.5;
const double kLookBoardRight = 3.5;
const double kLookBoardTop = 7.5;
const double kLookBoardBottom = -5.5;
const double kLookFiducial = 0.4;

const double _shadowOccluderX = -1.5;
const double _shadowOccluderZ = -1.5;

double _col(int i) => _left + i * _cell;

/// Every measured region, in a fixed order the tool's tables follow.
List<LookPatch> lookReferencePatches() {
  final shift = _shadowShift();
  return [
    for (final (i, name) in const [
      'unlit.lime',
      'unlit.pink',
      'lit.lime',
      'emissive.lime',
      'emissive.pink',
      'unlit.factor',
    ].indexed)
      LookPatch(
        'texture.$name',
        LookPatchKind.texture,
        _col(i),
        _yTexture,
        _measure,
      ),
    for (var i = 0; i < _greys.length; i++)
      LookPatch(
        'unlit.grey${_greys[i]}',
        LookPatchKind.unlit,
        _col(i),
        _yUnlitGrey,
        _measure,
      ),
    LookPatch('unlit.indigo', LookPatchKind.unlit, _col(5), _yUnlitGrey, _measure),
    for (final (i, name) in _hues.keys.indexed)
      LookPatch('unlit.$name', LookPatchKind.unlit, _col(i), _yUnlitHue, _measure),
    for (final (i, name) in _emissive.keys.indexed)
      LookPatch(
        'emissive.$name',
        LookPatchKind.emissive,
        _col(i),
        _yEmissive,
        _measure,
      ),
    for (var i = 0; i < _litGreys.length; i++)
      LookPatch(
        'lit.grey${_litGreys[i]}',
        LookPatchKind.lit,
        _col(i),
        _yLitGrey,
        _measure,
      ),
    LookPatch('lit.white.rough0.5', LookPatchKind.lit, _col(4), _yLitGrey, _measure),
    LookPatch('lit.indigo', LookPatchKind.lit, _col(5), _yLitGrey, _measure),
    for (final (i, name) in _hues.keys.indexed)
      LookPatch('lit.$name', LookPatchKind.lit, _col(i), _yLitHue, _measure),
    LookPatch('sphere.dielectric', LookPatchKind.sphere, -2, _ySphere, 0.25),
    LookPatch('sphere.metal', LookPatchKind.sphere, 0, _ySphere, 0.25),
    LookPatch('sphere.glossy', LookPatchKind.sphere, 2, _ySphere, 0.25),
    LookPatch('point.centre', LookPatchKind.light, -2, _yLights, 0.12),
    LookPatch('point.edge', LookPatchKind.light, -2.7, _yLights, 0.1),
    LookPatch('spot.centre', LookPatchKind.light, 0, _yLights, 0.12),
    LookPatch('spot.penumbra', LookPatchKind.light, 0.6, _yLights, 0.08),
    LookPatch('spot.outside', LookPatchKind.light, 0, _yLights - 1.0, 0.08),
    LookPatch('ibl.card', LookPatchKind.lit, 2, _yLights, 0.3),
    LookPatch('shadow.lit', LookPatchKind.shadow, 1.5, _yShadow, 0.3),
    LookPatch(
      'shadow.umbra',
      LookPatchKind.shadow,
      _shadowOccluderX + shift.x + 0.2,
      _yShadow + 0.5 + shift.y - 0.2,
      0.1,
    ),
    LookPatch('sky', LookPatchKind.sky, 3.25, 0.3, 0.12),
  ];
}

/// Where the occluder's shadow lands relative to the occluder.
Vector2 _shadowShift() {
  final t = -_shadowOccluderZ / kLookLightTravel.z;
  return Vector2(kLookLightTravel.x * t, kLookLightTravel.y * t);
}

/// The camera's vertical field of view: narrow, so the spheres and the
/// shadow's occluder, which stand off the board, shift by about 3% of
/// their distance from the view axis; not narrower, because Filament
/// stops lighting with point and spot lights 100 units from the camera
/// unless told otherwise, and dims them well before that.
const double kLookFovY = 20 * pi / 180;

/// Half the height of the board plane the camera has to see to fit
/// the whole board, fiducials included, into a view of [aspect]
/// (width / height).
double lookReferenceHalfHeight(double aspect) {
  const margin = 0.3;
  final halfW = (kLookBoardRight - kLookBoardLeft) / 2 + margin;
  final halfH = (kLookBoardTop - kLookBoardBottom) / 2 + margin;
  return max(halfH, halfW / aspect);
}

/// The board for [variant], framed for a view of [aspect].
SceneDocument buildLookReference(LookVariant variant, {required double aspect}) {
  final doc = SceneDocument();

  final card = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(_patch, _patch, _depth)),
    ),
  );
  GeometryResource slab(double w, double h) => doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: CuboidGeometrySpec(extents: Vector3(w, h, _depth)),
    ),
  );

  MaterialResource unlit((double, double, double) c) => doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'unlit',
      properties: {'baseColor': ColorValue(c.$1, c.$2, c.$3, 1)},
    ),
  );
  MaterialResource lit(
    (double, double, double) c, {
    double roughness = 1,
    double metallic = 0,
    (double, double, double)? emissive,
  }) {
    // The wire's emissive colour is a 0…1 factor; anything brighter
    // rides `emissiveStrength`.
    final peak = emissive == null
        ? 1.0
        : max(1.0, max(emissive.$1, max(emissive.$2, emissive.$3)));
    return doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(c.$1, c.$2, c.$3, 1),
          'roughness': DoubleValue(roughness),
          'metallic': DoubleValue(metallic),
          if (emissive != null)
            'emissive': ColorValue(
              emissive.$1 / peak,
              emissive.$2 / peak,
              emissive.$3 / peak,
              1,
            ),
          if (emissive != null) 'emissiveStrength': DoubleValue(peak),
        },
      ),
    );
  }

  void mesh(
    String name,
    GeometryResource geometry,
    MaterialResource material,
    Vector3 at,
  ) {
    doc.createNode(
      name: name,
      transform: TrsTransform(translation: at),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(geometry.id),
            'material': ResourceRefValue(material.id),
          },
        ),
      ],
      root: true,
    );
  }

  // One solid colour as a 4 × 4 sRGB texture.
  TextureResource texture((int, int, int) c) {
    final bytes = Uint8List(4 * 4 * 4);
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = c.$1;
      bytes[i + 1] = c.$2;
      bytes[i + 2] = c.$3;
      bytes[i + 3] = 255;
    }
    final payload = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: 4,
        height: 4,
        length: bytes.length,
        bytes: bytes,
      ),
    );
    return doc.addResource(TextureResource(doc.newId(), payload: payload.id));
  }

  MaterialResource textured(
    String type,
    TextureResource tex, {
    double factor = 1,
    bool emissive = false,
  }) => doc.addResource(
    MaterialResource(
      doc.newId(),
      type: type,
      properties: {
        if (!emissive) ...{
          'baseColor': ColorValue(factor, factor, factor, 1),
          'baseColorTexture': ResourceRefValue(tex.id),
        },
        if (emissive) ...{
          'baseColor': ColorValue(0, 0, 0, 1),
          'emissive': ColorValue(1, 1, 1, 1),
          'emissiveTexture': ResourceRefValue(tex.id),
          'emissiveStrength': DoubleValue(1.3),
        },
        if (type != 'unlit') 'roughness': DoubleValue(1),
      },
    ),
  );

  final lime = texture(_lime);
  final pink = texture(_pink);
  for (final (i, material) in [
    textured('unlit', lime),
    textured('unlit', pink),
    textured('physicallyBased', lime),
    textured('physicallyBased', lime, emissive: true),
    textured('physicallyBased', pink, emissive: true),
    textured('unlit', texture(_midGrey), factor: 0.5),
  ].indexed) {
    mesh('texture.$i', card, material, Vector3(_col(i), _yTexture, 0));
  }

  final half = kLookFiducial / 2;
  final fiducial = slab(kLookFiducial, kLookFiducial);
  final magenta = unlit((1, 0, 1));
  mesh(
    'fiducial.topLeft',
    fiducial,
    magenta,
    Vector3(kLookBoardLeft + half, kLookBoardTop - half, 0),
  );
  mesh(
    'fiducial.bottomRight',
    fiducial,
    magenta,
    Vector3(kLookBoardRight - half, kLookBoardBottom + half, 0),
  );

  for (var i = 0; i < _greys.length; i++) {
    final g = _greys[i];
    mesh('unlit.grey$g', card, unlit((g, g, g)), Vector3(_col(i), _yUnlitGrey, 0));
  }
  mesh('unlit.indigo', card, unlit(_indigo), Vector3(_col(5), _yUnlitGrey, 0));
  for (final (i, e) in _hues.entries.indexed) {
    mesh('unlit.${e.key}', card, unlit(e.value), Vector3(_col(i), _yUnlitHue, 0));
  }
  for (final (i, e) in _emissive.entries.indexed) {
    mesh(
      'emissive.${e.key}',
      card,
      lit((0, 0, 0), emissive: e.value),
      Vector3(_col(i), _yEmissive, 0),
    );
  }
  for (var i = 0; i < _litGreys.length; i++) {
    final g = _litGreys[i];
    mesh('lit.grey$g', card, lit((g, g, g)), Vector3(_col(i), _yLitGrey, 0));
  }
  mesh(
    'lit.white.rough0.5',
    card,
    lit((1, 1, 1), roughness: 0.5),
    Vector3(_col(4), _yLitGrey, 0),
  );
  mesh('lit.indigo', card, lit(_indigo), Vector3(_col(5), _yLitGrey, 0));
  for (final (i, e) in _hues.entries.indexed) {
    mesh('lit.${e.key}', card, lit(e.value), Vector3(_col(i), _yLitHue, 0));
  }

  final sphere = doc.addResource(
    GeometryResource(doc.newId(), procedural: SphereGeometrySpec(radius: 0.55)),
  );
  mesh(
    'sphere.dielectric',
    sphere,
    lit((0.5, 0.5, 0.5), roughness: 0.5),
    Vector3(-2, _ySphere, -0.6),
  );
  mesh(
    'sphere.metal',
    sphere,
    lit((1.0, 0.77, 0.34), roughness: 0.3, metallic: 1),
    Vector3(0, _ySphere, -0.6),
  );
  mesh(
    'sphere.glossy',
    sphere,
    lit((0.6, 0.05, 0.05), roughness: 0.2),
    Vector3(2, _ySphere, -0.6),
  );

  final white = lit((1, 1, 1));
  final lightCard = slab(1.8, 1.8);
  mesh('point.card', lightCard, white, Vector3(-2, _yLights, 0));
  mesh('spot.card', slab(1.8, 2.3), white, Vector3(0, _yLights - 0.25, 0));
  mesh('ibl.card', lightCard, white, Vector3(2, _yLights, 0));

  mesh('shadow.floor', slab(6, 2.2), lit((0.5, 0.5, 0.5)), Vector3(0, _yShadow, 0));
  mesh(
    'shadow.occluder',
    slab(1, 1),
    lit((0.5, 0.5, 0.5)),
    Vector3(_shadowOccluderX, _yShadow + 0.5, _shadowOccluderZ),
  );

  if (variant.directionalLight) {
    doc.createNode(
      name: 'look.directional',
      transform: TrsTransform(rotation: aimAlong(kLookLightTravel)),
      components: [
        ComponentSpec(
          'directionalLight',
          properties: {
            'color': ColorValue(1, 1, 1, 1),
            'intensity': DoubleValue(kLookDirectionalIntensity),
            'castsShadow': BoolValue(true),
            'shadowDepthBias': DoubleValue(0.01),
          },
        ),
      ],
      root: true,
    );
  }
  if (variant.pointLight) {
    doc.createNode(
      name: 'look.point',
      transform: TrsTransform(translation: Vector3(-2, _yLights, -1)),
      components: [
        ComponentSpec(
          'pointLight',
          properties: {
            'color': ColorValue(1, 1, 1, 1),
            'intensity': DoubleValue(kLookPointIntensity),
            'range': DoubleValue(3),
          },
        ),
      ],
      root: true,
    );
  }
  if (variant.spotLight) {
    doc.createNode(
      name: 'look.spot',
      transform: TrsTransform(translation: Vector3(0, _yLights, -1.5)),
      components: [
        ComponentSpec(
          'spotLight',
          properties: {
            'color': ColorValue(1, 1, 1, 1),
            'intensity': DoubleValue(kLookSpotIntensity),
            'direction': Vec3Value(Vector3(0, 0, 1)),
            'range': DoubleValue(6),
            'innerConeAngle': DoubleValue(kLookSpotInner),
            'outerConeAngle': DoubleValue(kLookSpotOuter),
          },
        ),
      ],
      root: true,
    );
  }

  final distance = lookReferenceHalfHeight(aspect) / tan(kLookFovY / 2);
  doc.createNode(
    name: 'look.camera',
    transform: TrsTransform(
      translation: Vector3(
        (kLookBoardLeft + kLookBoardRight) / 2,
        (kLookBoardTop + kLookBoardBottom) / 2,
        -distance,
      ),
    ),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': StringValue('perspective'),
          'fovRadiansY': DoubleValue(kLookFovY),
          'near': DoubleValue(distance - 10),
          'far': DoubleValue(distance + 10),
        },
      ),
    ],
    root: true,
  );

  if (!variant.stage) return doc;
  doc.stage.environmentRef = doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          environment: switch (variant.ibl) {
            LookIbl.none => const EmptyEnvironment(),
            LookIbl.constant => ConstantEnvironment(Vector3.all(kLookIblRadiance)),
            LookIbl.studio => const StudioEnvironment(),
          },
          environmentIntensity: variant.environmentIntensity,
          exposure: variant.exposure,
          toneMapping: variant.toneMapping,
          skybox: SkyboxSpec(
            GradientSkySpec(
              zenithColor: kLookSkyColor,
              horizonColor: kLookSkyColor,
              groundColor: kLookSkyColor,
              sunColor: Vector3.zero(),
            ),
          ),
          effects: EnvironmentEffectsSpec(
            bloomEnabled: variant.bloom,
            bloomThreshold: 1,
            bloomIntensity: 0.5,
          ),
        ),
      )
      .id;
  return doc;
}
