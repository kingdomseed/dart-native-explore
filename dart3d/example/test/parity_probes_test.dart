// W6 parity-lane encoding checks: the field names feature_scene.dart's
// probes put on the wire — `doubleSided` (material property),
// `allowsResting` (rigidBody dart3d-extension property, injected by
// hand since the emitter doesn't expose it), `shadowRadius`/
// `shadowDepthBias` (light), and the `concaveMesh` collider kind
// (tagged-union map per docs/physics-schema.md). The harness file is
// unreachable under `dart test` — it imports package:dart3d/dart3d.dart,
// which transitively needs DartNative's patched SDK — so these tests pin
// the vocabulary at the emitter/manifest level: a mistyped field name
// would decode to nothing on the native side and the lane would
// silently no-op. `readFscene(writeFscene(doc))` round-trips are what
// `_phaseTwo` relies on for its stable-id copy.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/physics.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const matId = LocalId(1, 0);
  const geoId = LocalId(1, 1);
  const bowlId = LocalId(1, 10);
  const lightId = LocalId(1, 11);
  const bodyId = LocalId(1, 12);

  /// A miniature of the W6 additions: the bowl's mesh + concaveMesh
  /// collider + fixed body, the key light's shadow fields, and the
  /// +8 s no-rest body's rigidBody — same construction the harness uses.
  SceneDocument probeDoc() {
    final doc = SceneDocument();
    doc.addResource(
      MaterialResource(
        matId,
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.95, 0.6, 0.1, 1.0),
          'doubleSided': BoolValue(true),
        },
      ),
    );
    doc.addResource(
      GeometryResource(
        geoId,
        procedural: CuboidGeometrySpec(extents: Vector3.all(0.4)),
      ),
    );
    doc.addNode(
      NodeSpec(
        id: bowlId,
        name: 'concaveBowl',
        transform: TrsTransform(),
        components: [
          ComponentSpec(
            'mesh',
            properties: {
              'geometry': ResourceRefValue(geoId),
              'material': ResourceRefValue(matId),
            },
          ),
          colliderComponent(
            shape: 'concaveMesh',
            friction: 0.6,
            restitution: 0.2,
          ),
          rigidBodyComponent(type: 'fixed'),
        ],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: lightId,
        name: 'key',
        transform: TrsTransform(),
        components: [
          ComponentSpec(
            'directionalLight',
            properties: {
              'castsShadow': BoolValue(true),
              'shadowRadius': DoubleValue(3.0),
              'shadowDepthBias': DoubleValue(0.005),
            },
          ),
        ],
      ),
      root: true,
    );
    // allowsResting rides as an injected property — the +8 s diff's
    // w5NoRest body builds its rigidBody exactly this way.
    final body = rigidBodyComponent(type: 'dynamic', mass: 0.3)
      ..properties['allowsResting'] = BoolValue(false);
    doc.addNode(
      NodeSpec(
        id: bodyId,
        name: 'w5NoRest',
        transform: TrsTransform(),
        components: [
          colliderComponent(shape: 'box', extents: Vector3.all(0.4)),
          body,
        ],
      ),
      root: true,
    );
    return doc;
  }

  Map<String, dynamic> manifest(SceneDocument doc) =>
      jsonDecode(writeFscene(doc)) as Map<String, dynamic>;

  List componentsOf(Map<String, dynamic> manifest, LocalId id) =>
      (manifest['nodes']
              as Map<String, dynamic>)['n:${id.toToken()}']['components']
          as List;

  Map<String, dynamic> component(List components, String type) => components
      .whereType<Map<String, dynamic>>()
      .firstWhere((c) => c['type'] == type);

  group('manifest encoding', () {
    test('concaveMesh collider emits the tagged-union shape map', () {
      final collider = component(
        componentsOf(manifest(probeDoc()), bowlId),
        'collider',
      );
      expect(collider['properties'], {
        'shape': {
          'map': {
            'kind': {'s': 'concaveMesh'},
          },
        },
        'material': {
          'map': {
            'friction': {'d': 0.6},
            'restitution': {'d': 0.2},
          },
        },
      });
      // mustBeStatic shapes force a fixed body natively — the probe
      // still authors 'fixed' honestly.
      final body = component(
        componentsOf(manifest(probeDoc()), bowlId),
        'rigidBody',
      );
      expect((body['properties'] as Map)['type'], {'s': 'fixed'});
    });

    test('material doubleSided encodes as a BoolValue', () {
      final resources =
          manifest(probeDoc())['resources'] as Map<String, dynamic>;
      final mat = resources['mat:${matId.toToken()}'] as Map<String, dynamic>;
      expect(mat['kind'], 'material');
      expect((mat['properties'] as Map)['doubleSided'], {'b': true});
    });

    test('shadow fields ride the directionalLight properties', () {
      final light = component(
        componentsOf(manifest(probeDoc()), lightId),
        'directionalLight',
      );
      expect(light['properties'], {
        'castsShadow': {'b': true},
        'shadowRadius': {'d': 3.0},
        'shadowDepthBias': {'d': 0.005},
      });
    });

    test('allowsResting encodes on the rigidBody as BoolValue(false)', () {
      final body = component(
        componentsOf(manifest(probeDoc()), bodyId),
        'rigidBody',
      );
      final props = body['properties'] as Map;
      expect(props['type'], {'s': 'dynamic'});
      expect(props['allowsResting'], {'b': false});
    });
  });

  group('round-trip and command spec', () {
    test('the W6 fields survive the _phaseTwo manifest round-trip', () {
      final copy = readFscene(writeFscene(probeDoc()));

      final bowlBody = copy.nodes[bowlId]!.components.firstWhere(
        (c) => c.type == 'rigidBody',
      );
      expect((bowlBody.properties['type']! as StringValue).value, 'fixed');
      final bowlCollider = copy.nodes[bowlId]!.components.firstWhere(
        (c) => c.type == 'collider',
      );
      expect(
        ((bowlCollider.properties['shape']! as MapValue).values['kind']!
                as StringValue)
            .value,
        'concaveMesh',
      );

      final mat = copy.resources[matId]! as MaterialResource;
      expect((mat.properties['doubleSided']! as BoolValue).value, isTrue);

      final light = copy.nodes[lightId]!.components.firstWhere(
        (c) => c.type == 'directionalLight',
      );
      expect((light.properties['shadowRadius']! as DoubleValue).value, 3.0);
      expect(
        (light.properties['shadowDepthBias']! as DoubleValue).value,
        0.005,
      );

      final noRest = copy.nodes[bodyId]!.components.firstWhere(
        (c) => c.type == 'rigidBody',
      );
      expect((noRest.properties['allowsResting']! as BoolValue).value, isFalse);
    });

    test('encodeNodeCommandSpec carries allowsResting for addNode', () {
      // The +8 s diff ships w5NoRest as an addNode whose spec is
      // encodeNodeCommandSpec output — the extension property must be
      // in that encoding, not just the manifest's.
      final doc = probeDoc();
      final spec = encodeNodeCommandSpec(doc.nodes[bodyId]!, doc);
      final body = component(spec['components'] as List, 'rigidBody');
      expect((body['properties'] as Map)['allowsResting'], {'b': false});
    });
  });
}
