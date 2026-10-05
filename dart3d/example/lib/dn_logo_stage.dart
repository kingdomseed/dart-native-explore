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

/// Tunables for the DartNative logo's dramatic stage. Light
/// intensities and the environment are in upstream's units: a
/// directional light of intensity `I` puts `I / π` on a white surface
/// facing it, before exposure.
final class DnLogoStage {
  const DnLogoStage({
    this.emissiveGlow = 0.3,
    this.bloomIntensity = 0.35,
    this.bloomThreshold = 0.5,
    this.bloomScatter = 0.65,
    this.vignetteIntensity = 0.3,
    this.environmentIntensity = 0.234,
    this.keyIntensity = 0.495,
    this.rimPinkIntensity = 0.625,
    this.rimCyanIntensity = 0.573,
    this.flatBackdrop = false,
    this.groundSlab = true,
    this.backdrop,
  });

  /// The values the Showcase entry uses.
  static const showcase = DnLogoStage();

  /// The social-reel capture look (`DART3D_SCENE=reel`): a hotter rig
  /// and self-glow than the showcase, no vignette, and a flat site
  /// `--bg` (#090E12) backdrop — the dark gradient and the vignette
  /// banded in 8-bit capture.
  static const reel = DnLogoStage(
    emissiveGlow: 0.55,
    bloomIntensity: 0.5,
    bloomThreshold: 0.45,
    bloomScatter: 0.7,
    vignetteIntensity: 0,
    environmentIntensity: 0.58,
    keyIntensity: 0.914,
    rimPinkIntensity: 1.266,
    rimCyanIntensity: 1.195,
    flatBackdrop: true,
    groundSlab: false,
  );

  /// The launch hero: the reel's rig, brighter and with a dimmer
  /// self-glow, tuned for a full orbit.
  static const hero = DnLogoStage(
    emissiveGlow: 0.35,
    bloomIntensity: 0.5,
    bloomThreshold: 0.45,
    bloomScatter: 0.7,
    vignetteIntensity: 0,
    environmentIntensity: 0.688,
    keyIntensity: 1.083,
    rimPinkIntensity: 1.5,
    rimCyanIntensity: 1.417,
    flatBackdrop: true,
    groundSlab: false,
    backdrop: (0.0179, 0.0206, 0.0227),
  );

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

  /// A flat #090E12 backdrop instead of the indigo gradient sky — no
  /// gradient left to band in 8-bit video. The vignette follows
  /// [vignetteIntensity] (0 turns it off).
  final bool flatBackdrop;

  /// Whether the loader lays the dark ground slab (and its shadow)
  /// under the logo. The reel floats the logo in the void instead —
  /// the hotter rig lit the slab into a grey horizon band.
  final bool groundSlab;

  /// The flat backdrop's linear sky color (with [flatBackdrop]); null
  /// uses the reel's (`_dnBgSky`).
  final (double, double, double)? backdrop;
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

/// Adds the light rig, placed relative to the camera so "key from the
/// side, rims from behind" holds for any [cameraDir] (center →
/// camera).
void addDnLogoLights(
  SceneDocument doc, {
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
            'intensity': DoubleValue(intensity),
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
    stage.flatBackdrop
        ? GradientSkySpec(
            zenithColor: _backdrop(stage),
            horizonColor: _backdrop(stage),
            groundColor: _backdrop(stage),
            sunColor: Vector3.zero(),
          )
        : GradientSkySpec(
            zenithColor: Vector3(0.0014, 0.0014, 0.0038),
            horizonColor: Vector3(0.0117, 0.0082, 0.0211),
            groundColor: Vector3(0.0023, 0.0023, 0.0042),
            sunColor: Vector3.zero(),
          ),
  ),
  effects: EnvironmentEffectsSpec(
    bloomEnabled: true,
    bloomThreshold: stage.bloomThreshold,
    bloomIntensity: stage.bloomIntensity,
    bloomScatter: stage.bloomScatter,
    vignetteEnabled: stage.vignetteIntensity > 0,
    vignetteIntensity: stage.vignetteIntensity,
    vignetteRadius: 0.8,
  ),
);

/// The reel's flat sky, in linear light before the tone map: after it
/// the sky is a deep blue-black just under site `--bg` #090E12, and
/// the reel's ffmpeg grade lifts the floor the rest of the way.
Vector3 _backdrop(DnLogoStage stage) {
  final b = stage.backdrop;
  return b == null ? _dnBgSky.clone() : Vector3(b.$1, b.$2, b.$3);
}

final Vector3 _dnBgSky = Vector3(0.0095, 0.0117, 0.0139);
