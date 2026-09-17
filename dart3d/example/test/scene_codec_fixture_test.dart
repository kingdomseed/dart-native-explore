// W2 scene-codec fixture: a physics-bearing document built through
// the upstream `package:scene` document model that scene_model.dart
// re-exports (the same constructors feature_scene.dart ships —
// `ComponentSpec('mesh', …)`, `colliderComponent`, `rigidBodyComponent`,
// `physicsWorldComponent`, `GeometryResource`, `MaterialResource`,
// `EnvironmentResource`, `RenderViewSpec`), serialized by the upstream
// text codec (`writeFscene`/`readFscene`/`decodeDocument`), then fed
// through dart3d's own encode/diff surface (`diffCommands`,
// `D3Protocol.loadSceneBytes`/`commandBytes`/`payloadBytes`,
// `unrealizedFeatureWarnings`). This is the Dart-side half of the
// program's "an upstream-authored `.fscene` rolls identically" lane —
// the native realizers can't run under `dart test`, so the assertions
// pin the wire shapes they decode: prefixed id tokens, tagged property
// values, the rigidBody/collider vocabulary of docs/physics-schema.md,
// and the manifest/chunk payload split. Same constraint as the W3–W14
// tests: package:dart3d/dart3d.dart is unreachable under `dart test`
// (the barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly; `SceneController.loadDocument`/`applyDiff` are thin
// wrappers over the functions exercised here.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/components.dart';
import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/physics.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Deterministic ids — explicit (session, index) pairs so tokens are
  // stable across the encode/decode/diff passes and the expected wire
  // shapes can name them exactly.
  const vertsId = LocalId(7, 0);
  const idxId = LocalId(7, 1);
  const quadGeoId = LocalId(7, 10);
  const boxGeoId = LocalId(7, 11);
  const ballGeoId = LocalId(7, 12);
  const matId = LocalId(7, 20);
  const groundMatId = LocalId(7, 21);
  const ballMatId = LocalId(7, 22);
  const envId = LocalId(7, 30);
  const groundId = LocalId(7, 40);
  const ballId = LocalId(7, 41);
  const meshId = LocalId(7, 42);
  const keyLightId = LocalId(7, 43);
  const fillLightId = LocalId(7, 44);
  const camId = LocalId(7, 45);

  const nodeIds = [
    groundId,
    ballId,
    meshId,
    keyLightId,
    fillLightId,
    camId,
  ];
  const resourceIds = [
    quadGeoId,
    boxGeoId,
    ballGeoId,
    matId,
    groundMatId,
    ballMatId,
    envId,
  ];

  // Chunk bytes for the payload-geometry lane — contents don't matter
  // to the codec, only that they survive the manifest/chunk split.
  final quadVerts = VertexPack.unskinned(
    positions: [
      Vector3(-0.5, 0, -0.5),
      Vector3(0.5, 0, -0.5),
      Vector3(0.5, 0, 0.5),
      Vector3(-0.5, 0, 0.5),
    ],
    normals: [for (var i = 0; i < 4; i++) Vector3(0, 1, 0)],
  );
  final quadIndices = Uint16List.fromList(
    const [0, 2, 1, 0, 3, 2],
  ).buffer.asUint8List();
  final gravity = Vector3(0, -9.8, 0);

  ComponentSpec mesh(LocalId geo, LocalId mat) => ComponentSpec(
    'mesh',
    properties: {
      'geometry': ResourceRefValue(geo),
      'material': ResourceRefValue(mat),
    },
  );

  /// The fixture: a fixed ground slab carrying the world settings, a
  /// ccd dynamic ball (sphere collider + surface material), a
  /// payload-geometry mesh, a directional/point light pair, a camera
  /// bound by the document's one view, and a studio environment on the
  /// stage — the same vocabulary feature_scene.dart emits.
  SceneDocument fixtureDoc() {
    final doc = SceneDocument();
    doc.addPayload(
      PayloadSpec(
        vertsId,
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: quadVerts.lengthInBytes,
        bytes: quadVerts,
      ),
    );
    doc.addPayload(
      PayloadSpec(
        idxId,
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: quadIndices.lengthInBytes,
        bytes: quadIndices,
      ),
    );
    doc.addResource(
      GeometryResource(
        quadGeoId,
        vertices: vertsId,
        indices: idxId,
        bounds: BoundsSpec(
          min: Vector3(-0.5, 0, -0.5),
          max: Vector3(0.5, 0, 0.5),
        ),
      ),
    );
    doc.addResource(
      GeometryResource(
        boxGeoId,
        procedural: CuboidGeometrySpec(extents: Vector3(8, 0.5, 5)),
      ),
    );
    doc.addResource(
      GeometryResource(
        ballGeoId,
        procedural: SphereGeometrySpec(radius: 0.35),
      ),
    );
    doc.addResource(
      MaterialResource(
        matId,
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.85, 0.2, 0.25, 1.0),
          'metallic': DoubleValue(0.05),
          'roughness': DoubleValue(0.55),
        },
      ),
    );
    doc.addResource(
      MaterialResource(
        groundMatId,
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.38, 0.38, 0.44, 1.0),
          'roughness': DoubleValue(0.9),
        },
      ),
    );
    doc.addResource(
      MaterialResource(
        ballMatId,
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.3, 0.55, 0.95, 1.0),
          'roughness': DoubleValue(0.45),
        },
      ),
    );
    doc.addResource(
      EnvironmentResource(
        envId,
        environment: const StudioEnvironment(),
        skybox: SkyboxSpec(EnvironmentSkySpec()),
        effects: EnvironmentEffectsSpec(),
      ),
    );
    doc.stage.environmentRef = envId;

    doc.addNode(
      NodeSpec(
        id: groundId,
        name: 'ground',
        transform: TrsTransform(translation: Vector3(0, -0.75, 1.5)),
        components: [
          mesh(boxGeoId, groundMatId),
          colliderComponent(
            shape: 'box',
            extents: Vector3(8, 0.5, 5),
            friction: 0.7,
            restitution: 0.3,
          ),
          rigidBodyComponent(type: 'fixed'),
          physicsWorldComponent(gravity: gravity),
        ],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: ballId,
        name: 'ball',
        transform: TrsTransform(translation: Vector3(0, 3, 0)),
        components: [
          mesh(ballGeoId, ballMatId),
          colliderComponent(
            shape: 'sphere',
            radius: 0.35,
            friction: 0.6,
            restitution: 0.45,
          ),
          rigidBodyComponent(
            type: 'dynamic',
            mass: 0.5,
            linearDamping: 0.05,
            angularDamping: 0.1,
            ccdEnabled: true,
          ),
        ],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: meshId,
        name: 'payloadMesh',
        transform: TrsTransform(translation: Vector3(-1.5, 0.5, 0)),
        components: [mesh(quadGeoId, matId)],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: keyLightId,
        name: 'key',
        transform: TrsTransform(
          rotation: Quaternion.axisAngle(
            Vector3(0.7, 0, 0.7)..normalize(),
            -0.8,
          ),
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
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: fillLightId,
        name: 'fill',
        transform: TrsTransform(translation: Vector3(-2, 2, -1)),
        components: [
          ComponentSpec(
            'pointLight',
            properties: {
              'color': ColorValue(0.6, 0.7, 1.0, 1),
              'intensity': DoubleValue(900),
              'range': DoubleValue(30),
            },
          ),
        ],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: camId,
        name: 'camera',
        transform: TrsTransform(
          translation: Vector3(0, 3.4, -6.5),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.5),
        ),
        components: [
          ComponentSpec(
            'camera',
            properties: {
              'projection': StringValue('perspective'),
              'fovRadiansY': DoubleValue(1.0),
              'near': DoubleValue(0.05),
              'far': DoubleValue(100),
            },
          ),
        ],
      ),
      root: true,
    );
    doc.views.add(RenderViewSpec(cameraNode: camId));
    return doc;
  }

  /// The manifest `nodes`/`components` lookup helpers — values come
  /// from `jsonDecode(writeFscene(doc))`, the exact bytes the natives
  /// receive in a `loadScene` mutation.
  Map<String, dynamic> manifestOf(SceneDocument doc) =>
      jsonDecode(writeFscene(doc)) as Map<String, dynamic>;

  Map<String, dynamic> manifestNode(
    Map<String, dynamic> manifest,
    LocalId id,
  ) => (manifest['nodes'] as Map<String, dynamic>)['n:${id.toToken()}']
      as Map<String, dynamic>;

  Map<String, dynamic> manifestComponent(
    Map<String, dynamic> manifest,
    LocalId node,
    String type,
  ) => (manifestNode(manifest, node)['components'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((c) => c['type'] == type);

  /// The decoded-side twin: [node]'s component of [type].
  ComponentSpec componentOf(SceneDocument doc, LocalId node, String type) =>
      doc.nodes[node]!.components.firstWhere((c) => c.type == type);

  /// Collects every `(path, string)` leaf in a decoded op so id-looking
  /// strings can be checked against the document's id space.
  List<(String, String)> stringLeaves(Object? v, [String path = '']) => [
    if (v is Map)
      for (final e in v.entries)
        ...stringLeaves(e.value, '$path.${e.key}'),
    if (v is List)
      for (var i = 0; i < v.length; i++)
        ...stringLeaves(v[i], '$path[$i]'),
    if (v is String) (path, v),
  ];

  group('manifest wire shape', () {
    test('the manifest carries the upstream top-level blocks', () {
      final doc = fixtureDoc();
      final manifest = manifestOf(doc);

      expect(manifest['fscene'], currentFsceneVersion);
      expect(manifest['documentId'], doc.documentId.toToken());
      expect(
        manifest.keys,
        containsAll([
          'stage',
          'resources',
          'nodes',
          'roots',
          'payloads',
          'views',
        ]),
      );

      // Id-keyed blocks carry the readability prefixes the native
      // decoders strip through the last colon.
      expect((manifest['nodes'] as Map).keys.toSet(), {
        for (final id in nodeIds) 'n:${id.toToken()}',
      });
      expect((manifest['resources'] as Map).keys.toSet(), {
        'geo:${quadGeoId.toToken()}',
        'geo:${boxGeoId.toToken()}',
        'geo:${ballGeoId.toToken()}',
        'mat:${matId.toToken()}',
        'mat:${groundMatId.toToken()}',
        'mat:${ballMatId.toToken()}',
        'env:${envId.toToken()}',
      });
      expect((manifest['payloads'] as Map).keys.toSet(), {
        'chunk:${vertsId.toToken()}',
        'chunk:${idxId.toToken()}',
      });
      expect(manifest['roots'], [
        for (final id in nodeIds) 'n:${id.toToken()}',
      ]);

      // The payload block is the descriptor only — chunk bytes ride
      // the binary `payload` channel, not the manifest.
      final payloads = manifest['payloads'] as Map<String, dynamic>;
      expect(payloads['chunk:${vertsId.toToken()}'], {
        'encoding': 'vertexBuffer',
        'layout': 'unskinned_uv1_tangent',
        'length': quadVerts.lengthInBytes,
      });
      expect(payloads['chunk:${idxId.toToken()}'], {
        'encoding': 'indexBuffer',
        'format': 'uint16',
        'length': quadIndices.lengthInBytes,
      });

      // Payload-backed geometry refs point at the chunk ids.
      final quadGeo =
          (manifest['resources']
                  as Map<String, dynamic>)['geo:${quadGeoId.toToken()}']
              as Map<String, dynamic>;
      expect(quadGeo['kind'], 'geometry');
      expect(quadGeo['vertices'], 'chunk:${vertsId.toToken()}');
      expect(quadGeo['indices'], 'chunk:${idxId.toToken()}');
    });

    test('the physics vocabulary encodes in upstream shape', () {
      final manifest = manifestOf(fixtureDoc());

      // rigidBody: the W2 field set in tagged-value form — `ccdEnabled`
      // is the lane-8 field this fixture exists to carry.
      expect(manifestComponent(manifest, ballId, 'rigidBody'), {
        'type': 'rigidBody',
        'properties': {
          'type': {'s': 'dynamic'},
          'mass': {'d': 0.5},
          'linearDamping': {'d': 0.05},
          'angularDamping': {'d': 0.1},
          'ccdEnabled': {'b': true},
        },
      });

      // collider: the upstream shape union + nested material map.
      expect(manifestComponent(manifest, ballId, 'collider'), {
        'type': 'collider',
        'properties': {
          'shape': {
            'map': {
              'kind': {'s': 'sphere'},
              'radius': {'d': 0.35},
            },
          },
          'material': {
            'map': {
              'friction': {'d': 0.6},
              'restitution': {'d': 0.45},
            },
          },
        },
      });
      // The box shape halves the emitter's full extents.
      final groundShape =
          manifestComponent(manifest, groundId, 'collider')['properties']
              as Map<String, dynamic>;
      expect(groundShape['shape'], {
        'map': {
          'kind': {'s': 'box'},
          'halfExtents': {
            'v3': [4.0, 0.25, 2.5],
          },
        },
      });
      expect(manifestComponent(manifest, groundId, 'rigidBody'), {
        'type': 'rigidBody',
        'properties': {
          'type': {'s': 'fixed'},
        },
      });
      expect(
        (manifestComponent(manifest, groundId, 'physicsWorld')['properties']
                as Map)['gravity'],
        {
          'v3': [gravity.x, gravity.y, gravity.z],
        },
      );

      // Resource references use the `rref` tag with prefixed tokens.
      expect(manifestComponent(manifest, ballId, 'mesh'), {
        'type': 'mesh',
        'properties': {
          'geometry': {'rref': 'geo:${ballGeoId.toToken()}'},
          'material': {'rref': 'mat:${ballMatId.toToken()}'},
        },
      });
    });

    test('stage, views, lights and camera encode per spec', () {
      final manifest = manifestOf(fixtureDoc());

      expect(manifest['stage'], {'environmentRef': 'env:${envId.toToken()}'});
      expect(manifest['views'], [
        {'camera': 'n:${camId.toToken()}'},
      ]);

      final env =
          (manifest['resources']
                  as Map<String, dynamic>)['env:${envId.toToken()}']
              as Map<String, dynamic>;
      expect(env['kind'], 'environment');
      expect(env['environment'], {'type': 'studio'});
      expect((env['skybox'] as Map)['source'], {
        'type': 'environment',
        'blurriness': 0.0,
      });

      expect(
        (manifestComponent(manifest, keyLightId, 'directionalLight')['properties']
                as Map)['castsShadow'],
        {'b': true},
      );
      expect(
        (manifestComponent(manifest, fillLightId, 'pointLight')['properties']
                as Map)['range'],
        {'d': 30.0},
      );
      expect(
        (manifestComponent(manifest, camId, 'camera')['properties']
                as Map)['projection'],
        {'s': 'perspective'},
      );
    });
  });

  group('upstream codec round-trip', () {
    test('readFscene decodes the same document', () {
      final doc = fixtureDoc();
      final decoded = readFscene(writeFscene(doc));

      expect(decoded.documentId, doc.documentId);
      expect(decoded.nodes.keys.toSet(), doc.nodes.keys.toSet());
      expect(decoded.resources.keys.toSet(), doc.resources.keys.toSet());
      expect(decoded.payloads.keys.toSet(), doc.payloads.keys.toSet());
      expect(decoded.roots, doc.roots);

      for (final id in nodeIds) {
        final node = decoded.nodes[id]!;
        expect(node.name, doc.nodes[id]!.name);
        expect(
          [for (final c in node.components) c.type],
          [for (final c in doc.nodes[id]!.components) c.type],
          reason: 'component list diverged on ${id.toToken()}',
        );
      }

      // The fields the interchange story needs, decoded to typed
      // PropertyValues — ccdEnabled above all (W2 lane 8).
      final rb = componentOf(decoded, ballId, 'rigidBody').properties;
      expect((rb['type'] as StringValue).value, 'dynamic');
      expect((rb['mass'] as DoubleValue).value, 0.5);
      expect((rb['linearDamping'] as DoubleValue).value, 0.05);
      expect((rb['angularDamping'] as DoubleValue).value, 0.1);
      expect((rb['ccdEnabled'] as BoolValue).value, isTrue);

      final collider = componentOf(decoded, ballId, 'collider').properties;
      final shape = (collider['shape'] as MapValue).values;
      expect((shape['kind'] as StringValue).value, 'sphere');
      expect((shape['radius'] as DoubleValue).value, 0.35);
      final material = (collider['material'] as MapValue).values;
      expect((material['friction'] as DoubleValue).value, 0.6);
      expect((material['restitution'] as DoubleValue).value, 0.45);

      final groundShape =
          (componentOf(decoded, groundId, 'collider').properties['shape']
                  as MapValue)
              .values;
      expect((groundShape['kind'] as StringValue).value, 'box');
      expect(
        (groundShape['halfExtents'] as Vec3Value).value,
        Vector3(4, 0.25, 2.5),
      );
      expect(
        (componentOf(decoded, groundId, 'rigidBody').properties['type']
                as StringValue)
            .value,
        'fixed',
      );
      expect(
        (componentOf(decoded, groundId, 'physicsWorld').properties['gravity']
                as Vec3Value)
            .value,
        gravity,
      );

      // Mesh refs resolve back to the same LocalIds.
      final meshProps = componentOf(decoded, ballId, 'mesh').properties;
      expect((meshProps['geometry'] as ResourceRefValue).id, ballGeoId);
      expect((meshProps['material'] as ResourceRefValue).id, ballMatId);

      // Resources keep their decoded types and parameters.
      final ballGeo = decoded.resources[ballGeoId]! as GeometryResource;
      expect(ballGeo.procedural, isA<SphereGeometrySpec>());
      expect(
        (ballGeo.procedural! as SphereGeometrySpec).radius,
        closeTo(0.35, 1e-6),
      );
      final quadGeo = decoded.resources[quadGeoId]! as GeometryResource;
      expect(quadGeo.vertices, vertsId);
      expect(quadGeo.indices, idxId);
      final mat = decoded.resources[matId]! as MaterialResource;
      expect(mat.type, 'physicallyBased');
      expect(mat.properties['baseColor'], isA<ColorValue>());

      // Stage and views survive the trip.
      expect(decoded.stage.environmentRef, envId);
      final env = decoded.resources[envId]! as EnvironmentResource;
      expect(env.environment, isA<StudioEnvironment>());
      expect(env.skybox!.source, isA<EnvironmentSkySpec>());
      expect(decoded.views, hasLength(1));
      expect(decoded.views.single.cameraNode, camId);

      // Payloads decode manifest-only — the wire keeps bytes on the
      // binary channel, so descriptors survive and bytes stay null.
      final verts = decoded.payloads[vertsId]!;
      expect(verts.encoding, PayloadEncoding.vertexBuffer);
      expect(verts.layout, 'unskinned_uv1_tangent');
      expect(verts.length, quadVerts.lengthInBytes);
      expect(verts.bytes, isNull);
    });

    test('re-encoding the decoded document is byte-identical', () {
      final doc = fixtureDoc();
      // Canonical idempotence: the decoded tree re-encodes to the same
      // bytes, so a doc authored by any SDK speaking this wire format
      // serializes identically under dart3d's copy of the codec.
      expect(writeFscene(readFscene(writeFscene(doc))), writeFscene(doc));
    });

    test('decodeDocument accepts the manifest tree; the capability '
        'pass finds nothing unrealized', () {
      final doc = fixtureDoc();
      final decoded = decodeDocument(
        jsonDecode(writeFscene(doc)) as Map<String, dynamic>,
      );
      expect(decoded.nodes, hasLength(nodeIds.length));
      expect(decoded.stage.environmentRef, envId);
      // dart3d's document-level validation (the
      // `featuresRequired`/`featuresUsed` pass SceneController runs on
      // every load) accepts the upstream-authored manifest.
      expect(unrealizedFeatureWarnings(decoded), isEmpty);
    });
  });

  group('diff/encode path on the decoded document', () {
    /// The fresh-install batch `SceneController.applyDiff` would emit
    /// for a first `loadDocument`: every node added, every resource
    /// upserted, stage and views shipped last.
    List<Map<String, Object?>> installOps(SceneDocument doc) =>
        diffCommands(diffScene(SceneDocument(), doc), null, doc);

    test('a fresh-install diff emits the full manifest batch', () {
      final decoded = readFscene(writeFscene(fixtureDoc()));
      final ops = installOps(decoded);

      final counts = <String, int>{};
      for (final op in ops) {
        final name = op['op'] as String;
        counts[name] = (counts[name] ?? 0) + 1;
      }
      // No upsertPayload ops: the decoded doc is manifest-only (chunk
      // bytes never leave the binary channel), and diffCommands skips
      // byteless payloads by contract.
      expect(counts, {
        'addNode': nodeIds.length,
        'upsertResource': resourceIds.length,
        'updateStage': 1,
        'updateViews': 1,
      });

      // Canonical batch order: resources before the nodes that consume
      // them, the stage after (its env resource already landed), views
      // last (the camera node exists by then).
      const order = {
        'removeNode': 0,
        'upsertPayload': 1,
        'upsertResource': 2,
        'addNode': 3,
        'updateNode': 4,
        'updateStage': 5,
        'updateViews': 6,
      };
      var phase = -1;
      for (final op in ops) {
        final rank = order[op['op']]!;
        expect(
          rank,
          greaterThanOrEqualTo(phase),
          reason: '${op['op']} out of canonical order in $ops',
        );
        phase = rank;
      }

      expect({for (final o in ops) o['op']}.toSet(), {
        'upsertResource',
        'addNode',
        'updateStage',
        'updateViews',
      });
      expect(
        {
          for (final o in ops)
            if (o['op'] == 'addNode') o['node'],
        },
        {for (final id in nodeIds) id.toToken()},
      );
      expect(
        {
          for (final o in ops)
            if (o['op'] == 'upsertResource') o['id'],
        },
        {
          'geo:${quadGeoId.toToken()}',
          'geo:${boxGeoId.toToken()}',
          'geo:${ballGeoId.toToken()}',
          'mat:${matId.toToken()}',
          'mat:${groundMatId.toToken()}',
          'mat:${ballMatId.toToken()}',
          'env:${envId.toToken()}',
        },
      );
    });

    test('updateStage and updateViews carry the prefixed ref tokens', () {
      final decoded = readFscene(writeFscene(fixtureDoc()));
      final ops = installOps(decoded);
      final stage = ops.lastWhere((o) => o['op'] == 'updateStage');
      expect(stage['stage'], {'environmentRef': 'env:${envId.toToken()}'});
      final views = ops.lastWhere((o) => o['op'] == 'updateViews');
      expect(views['views'], [
        {'camera': 'n:${camId.toToken()}'},
      ]);
    });

    test('every id the ops reference lives in the document', () {
      final decoded = readFscene(writeFscene(fixtureDoc()));
      final universe = <LocalId>{
        ...decoded.nodes.keys,
        ...decoded.resources.keys,
        ...decoded.payloads.keys,
        ...decoded.skins.keys,
        ...decoded.animations.keys,
      };
      const prefixes = {
        'n',
        'geo',
        'mat',
        'tex',
        'rt',
        'env',
        'skin',
        'anim',
        'chunk',
        'id',
      };
      for (final op in installOps(decoded)) {
        final decodedOp =
            jsonDecode(utf8.decode(D3Protocol.commandBytes(op)))
                as Map<String, dynamic>;
        // Node fields are bare tokens; every prefixed string parses
        // back through the last-colon strip into the id universe.
        for (final key in ['node', 'parent']) {
          final v = decodedOp[key];
          if (v is String) {
            expect(
              LocalId.parse(v),
              isIn(universe),
              reason: '$key=$v in $decodedOp',
            );
          }
        }
        for (final (path, s) in stringLeaves(decodedOp)) {
          final colon = s.indexOf(':');
          if (colon < 0) continue;
          final prefix = s.substring(0, colon);
          expect(
            prefixes,
            contains(prefix),
            reason: '$path = $s in $decodedOp',
          );
          expect(
            LocalId.parse(s),
            isIn(universe),
            reason: '$path = $s in $decodedOp',
          );
        }
      }
    });

    test('ops JSON-encode cleanly and specs match the manifest', () {
      final decoded = readFscene(writeFscene(fixtureDoc()));
      final manifest = manifestOf(decoded);
      for (final op in installOps(decoded)) {
        // Both wire encoders accept the op tree: the canonical writer
        // and the commandBytes utf8-JSON round-trip.
        expect(() => canonicalJson(op), returnsNormally);
        final roundTripped =
            jsonDecode(utf8.decode(D3Protocol.commandBytes(op)))
                as Map<String, dynamic>;
        expect(roundTripped, op);
      }
      // The `spec` addNode carries is byte-for-byte the manifest node
      // entry — encodeNodeCommandSpec ≡ upstream's private _encodeNode.
      for (final id in nodeIds) {
        expect(
          encodeNodeCommandSpec(decoded.nodes[id]!, decoded),
          manifestNode(manifest, id),
          reason: 'spec for ${id.toToken()} diverges from the manifest',
        );
      }
      // manifestIdKey's prefixes match what the manifest emitted.
      final idKey = manifestIdKey(decoded);
      expect(idKey(ballId), 'n:${ballId.toToken()}');
      expect(idKey(quadGeoId), 'geo:${quadGeoId.toToken()}');
      expect(idKey(matId), 'mat:${matId.toToken()}');
      expect(idKey(envId), 'env:${envId.toToken()}');
      expect(idKey(vertsId), 'chunk:${vertsId.toToken()}');
    });
  });

  group('payload chunks travel the binary channel', () {
    test('the with-bytes document emits upsertPayload ops carrying '
        'the chunk spec', () {
      // The pre-serialization document still holds chunk bytes — its
      // install batch ships them, the decoded document's does not.
      final doc = fixtureDoc();
      final ops = diffCommands(diffScene(SceneDocument(), doc), null, doc);
      final payloads = {
        for (final o in ops)
          if (o['op'] == 'upsertPayload') o['id'] as String: o,
      };
      expect(payloads.keys, {
        'chunk:${vertsId.toToken()}',
        'chunk:${idxId.toToken()}',
      });
      final verts = payloads['chunk:${vertsId.toToken()}']!;
      expect(verts['encoding'], 'vertexBuffer');
      expect(verts['layout'], 'unskinned_uv1_tangent');
      expect(verts['length'], quadVerts.lengthInBytes);
      expect(base64Decode(verts['bytes']! as String), quadVerts);
      final idx = payloads['chunk:${idxId.toToken()}']!;
      expect(idx['encoding'], 'indexBuffer');
      expect(idx['format'], 'uint16');
      expect(base64Decode(idx['bytes']! as String), quadIndices);
    });

    test('loadScene/payload frames are what the wire sends', () {
      final doc = fixtureDoc();
      // loadSceneBytes is the exact manifest mutation the controller
      // ships — utf8 canonical .fscene, nothing else.
      expect(
        utf8.decode(D3Protocol.loadSceneBytes(doc)),
        writeFscene(doc),
      );
      // payloadBytes frames [8B id][raw bytes] — the chunk half of the
      // manifest/payload split the decoded doc's manifest describes.
      final framed = D3Protocol.payloadBytes(doc.payloads[vertsId]!);
      final view = ByteData.sublistView(framed);
      expect(view.getUint32(0, Endian.little), vertsId.session);
      expect(view.getUint32(4, Endian.little), vertsId.index);
      expect(framed.sublist(8), quadVerts);
    });
  });
}
