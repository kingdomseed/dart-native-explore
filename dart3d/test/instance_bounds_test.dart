// Stabilization regressions for `d3:instances` bounds (W26):
// payload-backed transform matrices, billboard mode, the instance cap —
// docs/program-audit-2026-09-28.md §3 (world_bounds.dart:218-225).
// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:dart3d/src/geometry/instances.dart';
import 'package:dart3d/src/geometry/proc.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/world_bounds.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('instance bounds', () {
    SceneDocument docWith(ComponentSpec comp, {PayloadSpec? payload}) {
      final doc = SceneDocument();
      if (payload != null) doc.payloads[payload.id] = payload;
      doc.createNode().components.add(comp);
      return doc;
    }

    final mats = [
      for (var i = 0; i < 5; i++) Matrix4.translationValues(i * 10.0, 0, 0),
    ];

    test('payload-backed transforms decode for world bounds', () {
      final doc = SceneDocument();
      final chunk = d3MatricesPayload(doc.allocator.mint(), mats);
      doc.payloads[chunk.id] = chunk;
      doc.createNode().components.add(
        D3InstancesSpec(
          proc: D3CuboidProc(extents: Vector3.all(1)),
          transforms: D3InstanceTransforms.payload(chunk.id),
        ).toComponent(),
      );
      final (min, max) = documentWorldBounds(doc)!;
      expect(min.x, closeTo(-0.5, 1e-6));
      expect(max.x, closeTo(40.5, 1e-6));
    });

    test('D3InstancesSpec.bounds reads a supplied transforms payload', () {
      final id = SceneDocument().allocator.mint();
      final spec = D3InstancesSpec(
        proc: D3CuboidProc(extents: Vector3.all(1)),
        transforms: D3InstanceTransforms.payload(id),
      );
      final b = spec.bounds(
        null,
        transformsPayload: d3MatricesPayload(id, mats),
      )!;
      expect(b.max.x, closeTo(40.5, 1e-6));
      // Without the bytes: untransformed geometry, as before.
      expect(spec.bounds(null)!.max.x, closeTo(0.5, 1e-6));
    });

    test('billboard instances ignore source geometry; pad half-diagonal', () {
      final comp = D3InstancesSpec(
        proc: D3CuboidProc(extents: Vector3.all(100)),
        transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
        billboard: true,
        size: Vector2(1, 1),
      ).toComponent();
      final (min, max) = documentWorldBounds(docWith(comp))!;
      expect(max.x, closeTo(math.sqrt2 / 2, 1e-6));
      expect(min.x, closeTo(-math.sqrt2 / 2, 1e-6));
    });

    test('billboard:false is not billboard mode', () {
      final comp = D3InstancesSpec(
        proc: D3CuboidProc(extents: Vector3.all(2)),
        transforms: D3InstanceTransforms.inline([Matrix4.identity()]),
      ).toComponent();
      comp.properties['billboard'] = const BoolValue(false);
      final (_, max) = documentWorldBounds(docWith(comp))!;
      expect(max.x, closeTo(1, 1e-6));
    });
  });

  group('matrix decode cap (PR #14 4122712653)', () {
    PayloadSpec oversized(int extra) {
      final mats = [
        for (var i = 0; i < kD3MaxBakedInstances; i++) Matrix4.identity(),
        // Past the cap: never drawn, so never decoded or bounded.
        for (var i = 0; i < extra; i++)
          Matrix4.translationValues(1000.0 + i, 0, 0),
      ];
      return d3MatricesPayload(const LocalId(3, 1), mats);
    }

    test('decodes at most the cap, and honours maxCount', () {
      final p = oversized(64);
      expect(d3DecodeMatrices(p.bytes!), hasLength(kD3MaxBakedInstances));
      expect(d3DecodeMatrices(p.bytes!, maxCount: 3), hasLength(3));
      expect(d3DecodeMatrices(p.bytes!, maxCount: -1), isEmpty);
    });

    test('bounds ignore matrices past the cap', () {
      final p = oversized(8);
      final doc = SceneDocument();
      doc.payloads[p.id] = p;
      doc.createNode().components.add(
        D3InstancesSpec(
          proc: D3CuboidProc(extents: Vector3.all(1)),
          transforms: D3InstanceTransforms.payload(p.id),
        ).toComponent(),
      );
      final (_, max) = documentWorldBounds(doc)!;
      expect(max.x, closeTo(0.5, 1e-6));
    });
  });
}
