import 'dart:math' as math;

import 'package:dart3d/dart3d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('W17 physical sky generator & skyEnvironment', () {
    test('sun disc peak sits at sunDirection and tracks sun movement', () {
      final sunA = Vector3(0.3, 0.5, 0.8)..normalize();
      final specA = PhysicalSkySpec(sunDirection: sunA);

      final atSunA = evaluatePhysicalSkyDirection(sunA, specA);
      final awayFromSunA = evaluatePhysicalSkyDirection(
        Vector3(-0.3, 0.5, -0.8)..normalize(),
        specA,
      );
      expect(atSunA.length, greaterThan(awayFromSunA.length * 10.0));

      final sunB = Vector3(-0.6, 0.4, 0.7)..normalize();
      final specB = PhysicalSkySpec(sunDirection: sunB);
      final atSunB = evaluatePhysicalSkyDirection(sunB, specB);
      final atOldSunInB = evaluatePhysicalSkyDirection(sunA, specB);
      expect(atSunB.length, greaterThan(atOldSunInB.length * 10.0));
    });

    test('equirect generator places sun peak at the expected UV texel', () {
      const w = 128, h = 64;
      final sunDir = Vector3(0.0, 0.5, 0.8660254)..normalize();
      final spec = PhysicalSkySpec(
        sunDirection: sunDir,
        sunAngularRadius: 0.05,
      );
      final eq = generatePhysicalSkyEquirect(spec, width: w, height: h);

      var maxLum = -1.0;
      var maxPx = -1;
      var maxPy = -1;
      for (var py = 0; py < h; py++) {
        for (var px = 0; px < w; px++) {
          final o = (py * w + px) * 4;
          final lum = 0.2126 * eq[o] + 0.7152 * eq[o + 1] + 0.0722 * eq[o + 2];
          if (lum > maxLum) {
            maxLum = lum;
            maxPx = px;
            maxPy = py;
          }
        }
      }

      final expectedLat = math.asin(sunDir.y.clamp(-1.0, 1.0));
      final expectedV = 0.5 - expectedLat / math.pi;
      final expectedLon = math.atan2(sunDir.z, sunDir.x);
      final expectedU = 0.5 + expectedLon / (2.0 * math.pi);

      expect((maxPy + 0.5) / h, closeTo(expectedV, 2.0 / h));
      expect((maxPx + 0.5) / w, closeTo(expectedU, 2.0 / w));
    });

    test('zenith is Rayleigh blue, horizon is brighter, and nadir fades to groundColor', () {
      final spec = PhysicalSkySpec(
        sunDirection: Vector3(0.0, 0.85, 0.52)..normalize(),
        groundColor: Vector3(0.12, 0.12, 0.13),
      );
      final zenith = evaluatePhysicalSkyDirection(Vector3(0, 1, 0), spec);
      final horizon = evaluatePhysicalSkyDirection(
        Vector3(-1.0, 0.16, 0.0)..normalize(),
        spec,
      );
      final nadir = evaluatePhysicalSkyDirection(Vector3(0, -1, 0), spec);

      // Zenith has strong Rayleigh blue dominance (B > R).
      expect(zenith.z, greaterThan(zenith.x * 1.4));
      // Horizon optical mass increases in-scattering luminance away from the sun.
      expect(horizon.length, greaterThan(zenith.length));
      // Nadir is attenuated by groundColor (~0.12).
      expect(nadir.length, lessThan(horizon.length * 0.25));
    });

    test('low-sun sky warms the horizon compared to midday sky', () {
      final middaySpec = PhysicalSkySpec(
        sunDirection: Vector3(0.0, 0.85, 0.52)..normalize(),
      );
      final lowSunSpec = PhysicalSkySpec(
        sunDirection: Vector3(0.0, 0.04, 0.999)..normalize(),
        turbidity: 14.0,
      );
      final sampleDir = Vector3(0.25, 0.08, 0.96)..normalize();
      final middayHorizon = evaluatePhysicalSkyDirection(sampleDir, middaySpec);
      final lowSunHorizon = evaluatePhysicalSkyDirection(sampleDir, lowSunSpec);

      final middayRedBlueRatio = middayHorizon.x / math.max(middayHorizon.z, 1e-6);
      final lowSunRedBlueRatio = lowSunHorizon.x / math.max(lowSunHorizon.z, 1e-6);
      expect(lowSunRedBlueRatio, greaterThan(middayRedBlueRatio * 1.35));
    });

    test('progressive prefilter steps (64x32, 128x64, 256x128) converge with conserved flux', () {
      final spec = PhysicalSkySpec(
        sunDirection: Vector3(0.22, 0.36, 0.90)..normalize(),
        sunAngularRadius: 0.028,
      );
      final step1 = generatePhysicalSkyEquirect(
        spec,
        width: 64,
        height: 32,
        conserveSunEnergy: true,
      );
      final step2 = generatePhysicalSkyEquirect(
        spec,
        width: 128,
        height: 64,
        conserveSunEnergy: true,
      );
      final step3 = generatePhysicalSkyEquirect(
        spec,
        width: 256,
        height: 128,
        conserveSunEnergy: true,
      );

      Vector3 integrateIrradiance(
        List<double> eq,
        int w,
        int h,
      ) {
        var r = 0.0, g = 0.0, b = 0.0;
        final dCell = (2.0 * math.pi * math.pi) / (w * h);
        for (var py = 0; py < h; py++) {
          final v = (py + 0.5) / h;
          final lat = (0.5 - v) * math.pi;
          final weight = math.cos(lat) * dCell;
          for (var px = 0; px < w; px++) {
            final o = (py * w + px) * 4;
            r += eq[o] * weight;
            g += eq[o + 1] * weight;
            b += eq[o + 2] * weight;
          }
        }
        return Vector3(r, g, b);
      }

      final irr1 = integrateIrradiance(step1, 64, 32);
      final irr2 = integrateIrradiance(step2, 128, 64);
      final irr3 = integrateIrradiance(step3, 256, 128);

      final err1 = (irr1 - irr3).length / irr3.length;
      final err2 = (irr2 - irr3).length / irr3.length;
      expect(err1, lessThan(0.03));
      expect(err2, lessThan(err1));
      expect(err2, lessThan(0.01));
    });

    test('deriveSunLightFromSky matches upstream SunLight direction, color, and intensity', () {
      final phys = PhysicalSkySpec(
        sunDirection: Vector3(0.0, 3.0, 4.0),
        energy: 1.5,
      );
      final sunSpec = SunLightSpec(intensityScale: 2.0);
      final derivedPhys = deriveSunLightFromSky(phys, sunSpec)!;
      expect(derivedPhys.direction.x, closeTo(0.0, 1e-6));
      expect(derivedPhys.direction.y, closeTo(-0.6, 1e-6));
      expect(derivedPhys.direction.z, closeTo(-0.8, 1e-6));
      expect(derivedPhys.color.x, closeTo(1.0, 1e-6));
      expect(derivedPhys.color.y, closeTo(0.98, 1e-6));
      expect(derivedPhys.color.z, closeTo(0.95, 1e-6));
      expect(derivedPhys.intensity, closeTo(3.0 * 1.5 * 2.0, 1e-6));

      final grad = GradientSkySpec(
        sunDirection: Vector3(1.0, 0.0, 0.0),
        sunColor: Vector3(4.0, 2.0, 1.0),
      );
      final derivedGrad = deriveSunLightFromSky(grad, sunSpec)!;
      expect(derivedGrad.direction.x, closeTo(-1.0, 1e-6));
      expect(derivedGrad.color.x, closeTo(1.0, 1e-6));
      expect(derivedGrad.color.y, closeTo(0.5, 1e-6));
      expect(derivedGrad.color.z, closeTo(0.25, 1e-6));
      expect(derivedGrad.intensity, closeTo(4.0 * 2.0, 1e-6));
    });
  });
}
