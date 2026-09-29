/// The DartNative logo's stage — lights, backdrop, post effects and
/// the self-glow — as one reusable, data-driven setup (P4).
///
/// Pure Dart (no `dartnative` imports) so it is reachable under
/// `dart test`. The Showcase entry uses [DnLogoStage.showcase]; a
/// launch/hero scene can build its own [DnLogoStage] and animate it.
///
/// **Pulse / glow knobs** (what to animate for a breathing glow):
/// - [DnLogoStage.emissiveGlow] — the logo emits its own base-color
///   texture at this factor (material `emissive`; re-send the material
///   resource to change it live).
/// - [DnLogoStage.bloomIntensity] / [DnLogoStage.bloomThreshold] —
///   the environment's bloom (`effects`; re-send the environment
///   resource with `overridesEffects: true`).
/// - The rim intensities brighten the silhouette outline.
// ignore_for_file: implementation_imports
library;

import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

import 'light_aim.dart';

/// Tunables for the DartNative logo's dramatic stage. Intensities are
/// Android-calibrated wire values (see [keyLightIntensity]).
final class DnLogoStage {
  const DnLogoStage({
    this.emissiveGlow = 0.3,
    this.bloomIntensity = 0.35,
    this.bloomThreshold = 0.5,
    this.bloomScatter = 0.65,
    this.vignetteIntensity = 0.3,
    this.environmentIntensity = 0.3,
    this.keyIntensity = 1900,
    this.rimPinkIntensity = 2400,
    this.rimCyanIntensity = 2200,
    this.fillIntensity = 160,
  });

  /// The values the Showcase entry uses.
  static const showcase = DnLogoStage();

  /// The pulse parameter. The logo emits its own baked gradient (the
  /// base-color texture doubles as the emissive map, white factor ×
  /// this strength), so each part glows its own color — pink end
  /// pink, cyan tail cyan — over the lit, clear-coated surface; bloom
  /// then bleeds it softly outward. 0 = no glow; ~0.15–0.5 reads as a
  /// glow rather than a flat neon sign. Realized as SceneKit
  /// `emission.contents` (factor × texture baked) on iOS and the lit
  /// material's `emissiveMap` × `emissiveColor` on Android
  /// (docs/texture-material-spec.md).
  final double emissiveGlow;

  final double bloomIntensity;
  final double bloomThreshold;
  final double bloomScatter;
  final double vignetteIntensity;

  /// Studio IBL strength — low keeps reflections glossy but the
  /// contrast dramatic.
  final double environmentIntensity;

  /// Hard warm-white key from camera-left (casts the slab shadow).
  final double keyIntensity;

  /// Back rims in the logo's own pink (camera-left) and cyan
  /// (camera-right).
  final double rimPinkIntensity;
  final double rimCyanIntensity;

  /// Faint cool point fill on camera-right (scaled by the frame radius).
  final double fillIntensity;
}

/// Makes every textured material in [doc] emit its own base-color
/// texture at [glow] — a faint self-glow that feeds bloom without a
/// second image payload (the asset itself carries no emissive map).
void applyEmissiveGlow(SceneDocument doc, double glow) {
  for (final r in doc.resources.values) {
    if (r is! MaterialResource) continue;
    final base = r.properties['baseColorTexture'];
    if (base == null) continue;
    if (glow <= 0) {
      r.properties.remove('emissiveTexture');
      r.properties['emissive'] = ColorValue(0, 0, 0, 1);
    } else {
      r.properties['emissiveTexture'] = base;
      r.properties['emissive'] = ColorValue(glow, glow, glow, 1);
    }
  }
}

/// The dark, slightly glossy ground slab material for the stage.
MaterialResource dnLogoSlabMaterial(SceneDocument doc) => MaterialResource(
  doc.newId(),
  type: 'physicallyBased',
  properties: {
    'baseColor': ColorValue(0.035, 0.035, 0.05, 1),
    'roughness': DoubleValue(0.55),
    'metallic': DoubleValue(0.0),
  },
);

/// Adds the light rig around [center], placed relative to the camera
/// so "key from the side, rims from behind" holds for any
/// [cameraDir] (center → camera).
void addDnLogoLights(
  SceneDocument doc, {
  required Vector3 center,
  required double radius,
  required Vector3 cameraDir,
  DnLogoStage stage = DnLogoStage.showcase,
}) {
  // Horizontal toward-camera axis and screen-right in world space
  // (verified on device: the rig's handedness follows the importer's
  // mirrored Z, so screen-right is toCam × up, not up × toCam).
  final toCam = Vector3(cameraDir.x, 0, cameraDir.z)..normalize();
  final right = toCam.cross(Vector3(0, 1, 0))..normalize();
  final up = Vector3(0, 1, 0);

  void directional(
    String name,
    Vector3 from,
    ColorValue color,
    double intensity, {
    bool shadow = false,
  }) {
    doc.createNode(
      name: name,
      // Lights travel along node-local +Z: away from where they sit.
      transform: TrsTransform(rotation: aimAlong(-from)),
      components: [
        ComponentSpec(
          'directionalLight',
          properties: {
            'color': color,
            'intensity': DoubleValue(keyLightIntensity(intensity)),
            'castsShadow': BoolValue(shadow),
            if (shadow) 'shadowRadius': DoubleValue(4.0),
            if (shadow) 'shadowDepthBias': DoubleValue(0.01),
          },
        ),
      ],
      root: true,
    );
  }

  // Key: hard warm-white from camera-left and above, slightly in front
  // — the travelling specular highlight and the slab shadow.
  directional(
    'showcase.key',
    right * -0.75 + up * 0.9 + toCam * 0.35,
    ColorValue(1.0, 0.94, 0.86, 1),
    stage.keyIntensity,
    shadow: true,
  );
  // Rims: from behind, split left/right, in the logo's own pink and
  // cyan — they catch the tube's grazing edges as outlines.
  directional(
    'showcase.rim.pink',
    right * -0.85 + up * 0.45 - toCam * 0.9,
    ColorValue(1.0, 0.32, 0.66, 1),
    stage.rimPinkIntensity,
  );
  directional(
    'showcase.rim.cyan',
    right * 0.85 + up * 0.3 - toCam * 0.9,
    ColorValue(0.2, 0.8, 1.0, 1),
    stage.rimCyanIntensity,
  );
  // Fill: a faint cool point light on the camera-right side.
  doc.createNode(
    name: 'showcase.fill',
    transform: TrsTransform(
      translation:
          center +
          right * radius * 2 +
          up * radius * 1.6 +
          toCam * radius * 1.5,
    ),
    components: [
      ComponentSpec(
        'pointLight',
        properties: {
          'color': ColorValue(0.55, 0.62, 1.0, 1),
          'intensity': DoubleValue(
            keyLightIntensity(stage.fillIntensity * radius),
          ),
          'range': DoubleValue(radius * 24),
        },
      ),
    ],
    root: true,
  );
}

/// The stage environment: a near-black indigo gradient backdrop, the
/// studio IBL dimmed, and a gentle bloom + vignette. Everything here
/// realizes on both natives (docs/extended-surface-program.md: bloom
/// and vignette applied on iOS and Android; gradient sky + studio IBL
/// per docs/environment-ibl-spec.md).
EnvironmentResource dnLogoEnvironment(
  SceneDocument doc, {
  DnLogoStage stage = DnLogoStage.showcase,
}) => EnvironmentResource(
  doc.newId(),
  environment: const StudioEnvironment(),
  environmentIntensity: stage.environmentIntensity,
  exposure: 1.0,
  toneMapping: 'pbrNeutral',
  skybox: SkyboxSpec(
    GradientSkySpec(
      zenithColor: Vector3(0.006, 0.006, 0.016),
      horizonColor: Vector3(0.05, 0.035, 0.09),
      groundColor: Vector3(0.01, 0.01, 0.018),
      sunColor: Vector3.zero(),
    ),
  ),
  effects: EnvironmentEffectsSpec(
    bloomEnabled: true,
    bloomThreshold: stage.bloomThreshold,
    bloomIntensity: stage.bloomIntensity,
    bloomScatter: stage.bloomScatter,
    vignetteEnabled: true,
    vignetteIntensity: stage.vignetteIntensity,
    vignetteRadius: 0.8,
  ),
);
