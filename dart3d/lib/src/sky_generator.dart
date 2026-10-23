/// Analytic Rayleigh + Mie physical sky and stylized gradient sky equirect
/// generators (`W17` / `E3`).
///
/// Mirrors upstream `flutter_scene`'s `shaders/flutter_scene_sky_physical.frag`,
/// `shaders/flutter_scene_sky_gradient.frag`, `lib/src/sky_sources.dart`, and
/// `lib/src/sun_light.dart`. Both native realizers (`EnvironmentFactory.kt` on
/// Android and `FsceneRealizer.swift` on iOS) implement the same math natively
/// so equirect generation stays off the Dart isolate and well inside the A142
/// frame budget.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

const double _kRayleighZenithSize = 8400.0;
const double _kMieZenithSize = 1250.0;

double _smoothstep(double edge0, double edge1, double x) {
  if ((edge1 - edge0).abs() < 1e-12) return x >= edge1 ? 1.0 : 0.0;
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _henyeyGreensteinPhase(double cosTheta, double g) {
  final g2 = g * g;
  final denom = math.max(1.0 + g2 - 2.0 * g * cosTheta, 1e-12);
  return (1.0 / (4.0 * math.pi)) * ((1.0 - g2) / (denom * math.sqrt(denom)));
}

/// Evaluates upstream's analytic Preetham Rayleigh/Mie single-scattering
/// daylight model (`flutter_scene_sky_physical.frag`) along world-space view
/// direction [direction] for [spec], returning linear HDR RGB radiance.
Vector3 evaluatePhysicalSkyDirection(
  Vector3 direction,
  PhysicalSkySpec spec, {
  double? effectiveSunAngularRadius,
  double directSunScale = 1.0,
}) {
  final dirLen = direction.length;
  final dir = dirLen > 1e-12 ? direction / dirLen : Vector3(0.0, 1.0, 0.0);

  final sunLen = spec.sunDirection.length;
  final sunDir = sunLen > 1e-12
      ? spec.sunDirection / sunLen
      : Vector3(0.0, 1.0, 0.0);

  final sunZenithCos = sunDir.y.clamp(-1.0, 1.0);
  final sunEnergy =
      math.max(
        0.0,
        1.0 - math.exp(-((math.pi * 0.5) - math.acos(sunZenithCos))),
      ) *
      60.0 *
      spec.energy;
  final sunFade = 1.0 - (1.0 - math.exp(sunDir.y)).clamp(0.0, 1.0);

  final rayleighScale =
      math.max(spec.rayleighCoefficient - (1.0 - sunFade), 0.0) * 0.0001;
  final rayleighBetaR = spec.rayleighColor.x * rayleighScale;
  final rayleighBetaG = spec.rayleighColor.y * rayleighScale;
  final rayleighBetaB = spec.rayleighColor.z * rayleighScale;

  final mieScale = spec.turbidity * spec.mieCoefficient * 0.000434;
  final mieBetaR = spec.mieColor.x * mieScale;
  final mieBetaG = spec.mieColor.y * mieScale;
  final mieBetaB = spec.mieColor.z * mieScale;

  final zenith = math.acos(math.max(0.0, dir.y));
  final opticalMass =
      1.0 /
      (math.cos(zenith) + 0.00094 * math.pow(1.6386 - zenith, -1.253));
  final extR = math.exp(
    -(rayleighBetaR * _kRayleighZenithSize + mieBetaR * _kMieZenithSize) *
        opticalMass,
  );
  final extG = math.exp(
    -(rayleighBetaG * _kRayleighZenithSize + mieBetaG * _kMieZenithSize) *
        opticalMass,
  );
  final extB = math.exp(
    -(rayleighBetaB * _kRayleighZenithSize + mieBetaB * _kMieZenithSize) *
        opticalMass,
  );

  final cosTheta = dir.dot(sunDir);
  final halfCos = cosTheta * 0.5 + 0.5;
  final rayleighPhase =
      (3.0 / (16.0 * math.pi)) * (1.0 + halfCos * halfCos);
  final miePhase = _henyeyGreensteinPhase(cosTheta, spec.mieEccentricity);

  final denomR = math.max(rayleighBetaR + mieBetaR, 1e-12);
  final denomG = math.max(rayleighBetaG + mieBetaG, 1e-12);
  final denomB = math.max(rayleighBetaB + mieBetaB, 1e-12);
  final scatterR = (rayleighBetaR * rayleighPhase + mieBetaR * miePhase) / denomR;
  final scatterG = (rayleighBetaG * rayleighPhase + mieBetaG * miePhase) / denomG;
  final scatterB = (rayleighBetaB * rayleighPhase + mieBetaB * miePhase) / denomB;

  final sR = math.max(sunEnergy * scatterR * (1.0 - extR), 0.0);
  final sG = math.max(sunEnergy * scatterG * (1.0 - extG), 0.0);
  final sB = math.max(sunEnergy * scatterB * (1.0 - extB), 0.0);
  var inscatterR = sR * math.sqrt(sR);
  var inscatterG = sG * math.sqrt(sG);
  var inscatterB = sB * math.sqrt(sB);

  final sunsetMix = math.pow(1.0 - sunZenithCos, 5.0).toDouble().clamp(0.0, 1.0);
  if (sunsetMix > 0.0) {
    final seR = math.sqrt(math.max(sunEnergy * scatterR * extR, 0.0));
    final seG = math.sqrt(math.max(sunEnergy * scatterG * extG, 0.0));
    final seB = math.sqrt(math.max(sunEnergy * scatterB * extB, 0.0));
    inscatterR *= _lerp(1.0, seR, sunsetMix);
    inscatterG *= _lerp(1.0, seG, sunsetMix);
    inscatterB *= _lerp(1.0, seB, sunsetMix);
  }

  final groundBlend = _smoothstep(-0.1, 0.1, dir.y);
  inscatterR *= _lerp(spec.groundColor.x, 1.0, groundBlend);
  inscatterG *= _lerp(spec.groundColor.y, 1.0, groundBlend);
  inscatterB *= _lerp(spec.groundColor.z, 1.0, groundBlend);

  final radius = math.max(0.0, effectiveSunAngularRadius ?? spec.sunAngularRadius);
  final diskOuter = math.cos(radius);
  final diskInner = math.cos(radius * 0.5);
  final sunDisk = _smoothstep(diskOuter, diskInner, cosTheta) * directSunScale;
  final directR = sunEnergy * extR * sunDisk;
  final directG = sunEnergy * extG * sunDisk;
  final directB = sunEnergy * extB * sunDisk;

  return Vector3(
    math.max(0.0, inscatterR + directR),
    math.max(0.0, inscatterG + directG),
    math.max(0.0, inscatterB + directB),
  );
}

/// Generates a row-0-up (`+Y` pole at row 0) RGBA float32 equirectangular
/// image of [spec] matching upstream's `flutter_scene_sky_physical.frag`.
///
/// When [conserveSunEnergy] is true, sub-pixel sun disks on coarse equirects
/// are anti-aliased to a minimum filter radius of `1.75 * pi / height` with
/// matching `(r0 / rEff)^2` peak scaling so total integrated sun flux is
/// invariant across resolutions (`64x32` .. `1024x512`).
Float32List generatePhysicalSkyEquirect(
  PhysicalSkySpec spec, {
  int width = 256,
  int height = 128,
  double scale = 1.0,
  bool conserveSunEnergy = false,
}) {
  final out = Float32List(width * height * 4);
  final sunLen = spec.sunDirection.length;
  final sunX = sunLen > 1e-12 ? spec.sunDirection.x / sunLen : 0.0;
  final sunY = sunLen > 1e-12 ? spec.sunDirection.y / sunLen : 1.0;
  final sunZ = sunLen > 1e-12 ? spec.sunDirection.z / sunLen : 0.0;

  final sunZenithCos = sunY.clamp(-1.0, 1.0);
  final sunEnergy =
      math.max(
        0.0,
        1.0 - math.exp(-((math.pi * 0.5) - math.acos(sunZenithCos))),
      ) *
      60.0 *
      spec.energy;
  final sunFade = 1.0 - (1.0 - math.exp(sunY)).clamp(0.0, 1.0);

  final rayleighScale =
      math.max(spec.rayleighCoefficient - (1.0 - sunFade), 0.0) * 0.0001;
  final rayleighBetaR = spec.rayleighColor.x * rayleighScale;
  final rayleighBetaG = spec.rayleighColor.y * rayleighScale;
  final rayleighBetaB = spec.rayleighColor.z * rayleighScale;

  final mieScale = spec.turbidity * spec.mieCoefficient * 0.000434;
  final mieBetaR = spec.mieColor.x * mieScale;
  final mieBetaG = spec.mieColor.y * mieScale;
  final mieBetaB = spec.mieColor.z * mieScale;

  final denomR = math.max(rayleighBetaR + mieBetaR, 1e-12);
  final denomG = math.max(rayleighBetaG + mieBetaG, 1e-12);
  final denomB = math.max(rayleighBetaB + mieBetaB, 1e-12);

  final extCoeffR =
      rayleighBetaR * _kRayleighZenithSize + mieBetaR * _kMieZenithSize;
  final extCoeffG =
      rayleighBetaG * _kRayleighZenithSize + mieBetaG * _kMieZenithSize;
  final extCoeffB =
      rayleighBetaB * _kRayleighZenithSize + mieBetaB * _kMieZenithSize;

  final sunsetMix = math.pow(1.0 - sunZenithCos, 5.0).toDouble().clamp(0.0, 1.0);
  final g = spec.mieEccentricity;
  final g2 = g * g;
  final oneMinusG2 = 1.0 - g2;
  const invFourPi = 1.0 / (4.0 * math.pi);
  const rayleighConst = 3.0 / (16.0 * math.pi);

  final r0 = math.max(0.0, spec.sunAngularRadius);
  final minGridRadius = 1.75 * math.pi / math.max(1, height);
  final rEff = (conserveSunEnergy && r0 > 0.0 && r0 < minGridRadius)
      ? minGridRadius
      : r0;
  final directSunScale = (conserveSunEnergy && rEff > r0 && rEff > 0.0)
      ? (r0 / rEff) * (r0 / rEff)
      : 1.0;
  final diskOuter = math.cos(rEff);
  final diskInner = math.cos(rEff * 0.5);

  final twoPi = 2.0 * math.pi;
  final cosLon = Float64List(width);
  final sinLon = Float64List(width);
  for (var px = 0; px < width; px++) {
    final u = (px + 0.5) / width;
    final lon = (u - 0.5) * twoPi;
    cosLon[px] = math.cos(lon);
    sinLon[px] = math.sin(lon);
  }

  for (var py = 0; py < height; py++) {
    final v = (py + 0.5) / height;
    final latitude = (0.5 - v) * math.pi;
    final cosLat = math.cos(latitude);
    final dirY = math.sin(latitude);

    final zenith = math.acos(math.max(0.0, dirY));
    final opticalMass =
        1.0 /
        (math.cos(zenith) + 0.00094 * math.pow(1.6386 - zenith, -1.253));
    final extR = math.exp(-extCoeffR * opticalMass);
    final extG = math.exp(-extCoeffG * opticalMass);
    final extB = math.exp(-extCoeffB * opticalMass);
    final oneMinusExtR = 1.0 - extR;
    final oneMinusExtG = 1.0 - extG;
    final oneMinusExtB = 1.0 - extB;

    final groundBlend = _smoothstep(-0.1, 0.1, dirY);
    final groundFactorR = _lerp(spec.groundColor.x, 1.0, groundBlend);
    final groundFactorG = _lerp(spec.groundColor.y, 1.0, groundBlend);
    final groundFactorB = _lerp(spec.groundColor.z, 1.0, groundBlend);

    final rowDirectR = sunEnergy * extR * directSunScale;
    final rowDirectG = sunEnergy * extG * directSunScale;
    final rowDirectB = sunEnergy * extB * directSunScale;

    for (var px = 0; px < width; px++) {
      final dirX = cosLat * cosLon[px];
      final dirZ = cosLat * sinLon[px];
      final cosTheta = dirX * sunX + dirY * sunY + dirZ * sunZ;

      final halfCos = cosTheta * 0.5 + 0.5;
      final rayleighPhase = rayleighConst * (1.0 + halfCos * halfCos);
      final denom = math.max(1.0 + g2 - 2.0 * g * cosTheta, 1e-12);
      final miePhase = invFourPi * (oneMinusG2 / (denom * math.sqrt(denom)));

      final scatterR =
          (rayleighBetaR * rayleighPhase + mieBetaR * miePhase) / denomR;
      final scatterG =
          (rayleighBetaG * rayleighPhase + mieBetaG * miePhase) / denomG;
      final scatterB =
          (rayleighBetaB * rayleighPhase + mieBetaB * miePhase) / denomB;

      final sR = math.max(sunEnergy * scatterR * oneMinusExtR, 0.0);
      final sG = math.max(sunEnergy * scatterG * oneMinusExtG, 0.0);
      final sB = math.max(sunEnergy * scatterB * oneMinusExtB, 0.0);
      var r = sR * math.sqrt(sR);
      var gC = sG * math.sqrt(sG);
      var b = sB * math.sqrt(sB);

      if (sunsetMix > 0.0) {
        final seR = math.sqrt(math.max(sunEnergy * scatterR * extR, 0.0));
        final seG = math.sqrt(math.max(sunEnergy * scatterG * extG, 0.0));
        final seB = math.sqrt(math.max(sunEnergy * scatterB * extB, 0.0));
        r *= _lerp(1.0, seR, sunsetMix);
        gC *= _lerp(1.0, seG, sunsetMix);
        b *= _lerp(1.0, seB, sunsetMix);
      }

      r *= groundFactorR;
      gC *= groundFactorG;
      b *= groundFactorB;

      if (cosTheta > diskOuter) {
        final sunDisk = _smoothstep(diskOuter, diskInner, cosTheta);
        r += rowDirectR * sunDisk;
        gC += rowDirectG * sunDisk;
        b += rowDirectB * sunDisk;
      }

      final o = (py * width + px) * 4;
      out[o] = math.max(0.0, r) * scale;
      out[o + 1] = math.max(0.0, gC) * scale;
      out[o + 2] = math.max(0.0, b) * scale;
      out[o + 3] = 1.0;
    }
  }
  return out;
}

/// Derives the directional sun light's travel direction (opposite
/// `sunDirection`), linear RGB color, and scalar intensity from [source] and
/// [sunLight] matching upstream `SunLight.resolve()` (`sun_light.dart`).
///
/// Returns `null` when [source] does not carry a sun (`EnvironmentSkySpec` or
/// `FmatSkySpec`).
({Vector3 direction, Vector3 color, double intensity})? deriveSunLightFromSky(
  SkySourceSpec source,
  SunLightSpec sunLight,
) {
  switch (source) {
    case PhysicalSkySpec s:
      final len = s.sunDirection.length;
      final dir = len > 1e-12
          ? (-s.sunDirection / len)
          : Vector3(0.0, -1.0, 0.0);
      return (
        direction: dir,
        color: Vector3(1.0, 0.98, 0.95),
        intensity: 3.0 * s.energy * sunLight.intensityScale,
      );
    case GradientSkySpec s:
      final len = s.sunDirection.length;
      final dir = len > 1e-12
          ? (-s.sunDirection / len)
          : Vector3(0.0, -1.0, 0.0);
      final peak = math.max(
        s.sunColor.x,
        math.max(s.sunColor.y, s.sunColor.z),
      );
      final color = peak > 0.0 ? (s.sunColor / peak) : Vector3(1.0, 1.0, 1.0);
      return (
        direction: dir,
        color: color,
        intensity: peak * sunLight.intensityScale,
      );
    default:
      return null;
  }
}
