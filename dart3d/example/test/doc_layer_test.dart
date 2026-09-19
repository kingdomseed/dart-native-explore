// W29 document layer: `serializeScene` round-trip, the command-op fold
// that keeps the tracked document a live mirror, `migrateFscene`
// upgrades on load, the strict half of feature negotiation, and the
// runtime glTF/GLB importer. Same constraint as the codec fixture:
// package:dart3d/dart3d.dart needs DartNative's patched SDK, so the
// tests pull the pure-Dart libraries directly — `SceneController`'s
// `applyCommands`/`setNodeTransforms`/`sendPayload`/`serializeScene`
// are thin wrappers over the functions exercised here.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart3d/src/components.dart';
import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/doc_layer.dart';
import 'package:dart3d/src/glb_import.dart';
import 'package:dart3d/src/gltf/parser.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const vertsId = LocalId(9, 0);
  const idxId = LocalId(9, 1);
  const ibmId = LocalId(9, 2);
  const timeId = LocalId(9, 3);
  const keysId = LocalId(9, 4);
  const geoId = LocalId(9, 10);
  const matId = LocalId(9, 20);
  const envId = LocalId(9, 30);
  const nodeA = LocalId(9, 40);
  const nodeB = LocalId(9, 41);
  const nodeC = LocalId(9, 42);
  const nodeD = LocalId(9, 43);
  const camId = LocalId(9, 44);
  const skinId = LocalId(9, 50);
  const skin2Id = LocalId(9, 51);
  const animId = LocalId(9, 52);
  const anim2Id = LocalId(9, 53);

  ComponentSpec meshComp() => ComponentSpec(
    'mesh',
    properties: {
      'geometry': ResourceRefValue(geoId),
      'material': ResourceRefValue(matId),
    },
  );

  /// The "old" document: A and C at the roots, B under A, a payload
  /// quad, a skin and a clip, one view. Every op class has something to
  /// change against it.
  SceneDocument baseDoc() {
    final doc = SceneDocument(
      documentId: DocumentId(Uint8List.fromList(List.filled(16, 7))),
    );
    doc.addPayload(
      PayloadSpec(
        vertsId,
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: 48,
        bytes: Uint8List(48),
      ),
    );
    doc.addPayload(
      PayloadSpec(
        idxId,
        encoding: PayloadEncoding.indexBuffer,
        format: 'uint16',
        length: 6,
        bytes: Uint8List(6),
      ),
    );
    doc.addPayload(
      PayloadSpec(
        ibmId,
        encoding: PayloadEncoding.matrices,
        length: 128,
        bytes: Uint8List(128),
      ),
    );
    doc.addResource(
      GeometryResource(
        geoId,
        vertices: vertsId,
        indices: idxId,
        bounds: BoundsSpec(min: Vector3.zero(), max: Vector3.all(1)),
      ),
    );
    doc.addResource(MaterialResource(matId, type: 'unlit'));
    doc.addResource(EnvironmentResource(envId));
    doc.addNode(
      NodeSpec(
        id: nodeA,
        name: 'a',
        transform: TrsTransform(translation: Vector3(1, 0, 0)),
        children: [nodeB],
        components: [meshComp()],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: nodeB,
        name: 'b',
        transform: TrsTransform(translation: Vector3(0, 1, 0)),
      ),
    );
    doc.addNode(
      NodeSpec(
        id: nodeC,
        name: 'c',
        transform: TrsTransform(translation: Vector3(0, 0, 1)),
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(
        id: camId,
        name: 'cam',
        transform: TrsTransform(translation: Vector3(0, 0, -4)),
      ),
      root: true,
    );
    doc.addSkin(SkinSpec(skinId, joints: [nodeA], inverseBindMatrices: ibmId));
    doc.addAnimation(
      AnimationSpec(
        animId,
        name: 'slide',
        channels: [
          AnimationChannelSpec(
            target: nodeC,
            property: AnimationProperty.translation,
            timeline: timeId,
            keyframes: keysId,
          ),
        ],
      ),
    );
    doc.views.add(RenderViewSpec(cameraNode: camId));
    return doc;
  }

  group('serializeScene', () {
    test('snapshot serializes byte-identically to the live document', () {
      final doc = baseDoc();
      expect(writeFscene(serializeScene(doc)), writeFscene(doc));
    });

    test('snapshot keeps chunk bytes so it can re-realize', () {
      final snapshot = serializeScene(baseDoc());
      expect(snapshot.payloads[vertsId]!.bytes, hasLength(48));
      expect(snapshot.payloads[ibmId]!.bytes, hasLength(128));
    });

    test('snapshot is detached from later live edits', () {
      final doc = baseDoc();
      final snapshot = serializeScene(doc);
      doc.nodes[nodeA]!.name = 'renamed';
      doc.payloads[vertsId]!.bytes = Uint8List(4);
      expect(snapshot.nodes[nodeA]!.name, 'a');
      expect(snapshot.payloads[vertsId]!.bytes, hasLength(48));
    });
  });

  group('command-op fold', () {
    /// The acceptance shape: ops the controller emits for a diff fold
    /// back into the tracked document, and the mirror must equal the
    /// diff's target byte-for-byte.
    test('a diff batch folded into the old doc reproduces the new doc', () {
      final oldDoc = baseDoc();
      final newDoc = baseDoc();

      // Extend the new doc along every op class: a reparent, a remove,
      // an add, an update, a resource upsert, a payload upsert, skin
      // and animation swaps, a stage change, a views change.
      newDoc.nodes.remove(nodeB);
      newDoc.nodes[nodeA]!.children
        ..clear()
        ..addAll([nodeD, nodeC]);
      newDoc.roots
        ..clear()
        ..addAll([nodeA, camId]);
      newDoc.nodes[nodeA]!.transform = TrsTransform(
        translation: Vector3(5, 0, 0),
      );
      newDoc.addNode(
        NodeSpec(
          id: nodeD,
          name: 'd',
          transform: TrsTransform(scale: Vector3.all(2)),
        ),
      );
      newDoc.resources[matId] = MaterialResource(
        matId,
        type: 'physicallyBased',
        properties: {'roughness': DoubleValue(0.2)},
      );
      newDoc.payloads[vertsId] = PayloadSpec(
        vertsId,
        encoding: PayloadEncoding.vertexBuffer,
        layout: 'unskinned_uv1_tangent',
        length: 96,
        bytes: Uint8List(96),
      );
      newDoc.skins.remove(skinId);
      newDoc.addSkin(
        SkinSpec(skin2Id, joints: [nodeA, nodeC], inverseBindMatrices: ibmId),
      );
      newDoc.animations.remove(animId);
      newDoc.addAnimation(
        AnimationSpec(
          anim2Id,
          name: 'spin',
          channels: [
            AnimationChannelSpec(
              target: nodeD,
              property: AnimationProperty.rotation,
              timeline: timeId,
              keyframes: keysId,
            ),
          ],
        ),
      );
      newDoc.stage.environmentRef = envId;
      newDoc.views
        ..clear()
        ..add(RenderViewSpec(cameraNode: camId, order: 2));

      final ops = diffCommands(diffScene(oldDoc, newDoc), oldDoc, newDoc);
      final mirror = baseDoc();
      for (final op in ops) {
        foldCommandIntoDocument(mirror, op);
      }
      expect(writeFscene(mirror), writeFscene(newDoc));
    });

    test('updateNode applies only flagged fields', () {
      final doc = baseDoc();
      foldCommandIntoDocument(doc, {
        'op': 'updateNode',
        'node': nodeA.toToken(),
        'flags': ['name'],
        'spec': encodeNodeCommandSpec(
          NodeSpec(
            id: nodeA,
            name: 'renamed',
            transform: TrsTransform(translation: Vector3(9, 9, 9)),
          ),
          doc,
        ),
      });
      final node = doc.nodes[nodeA]!;
      expect(node.name, 'renamed');
      // transform wasn't flagged — the live value survives.
      expect((node.transform as TrsTransform).translation, Vector3(1, 0, 0));
    });

    test('addNode attaches via the parent edge; spec children stay inert', () {
      final doc = baseDoc();
      foldCommandIntoDocument(doc, {
        'op': 'addNode',
        'node': nodeD.toToken(),
        'parent': nodeA.toToken(),
        'spec': encodeNodeCommandSpec(
          NodeSpec(
            id: nodeD,
            name: 'd',
            children: [nodeC], // inert on the wire — C never re-emits
          ),
          doc,
        ),
      });
      expect(doc.nodes[nodeA]!.children, [nodeB, nodeD]);
      expect(doc.nodes.containsKey(nodeD), isTrue);
      // C stayed a root: its own op's parent edge is the only authority.
      expect(doc.nodes[nodeD]!.children, isEmpty);
      expect(doc.roots, contains(nodeC));
    });

    test('removeNode drops the subtree and the root membership', () {
      final doc = baseDoc();
      foldCommandIntoDocument(doc, {
        'op': 'removeNode',
        'node': nodeA.toToken(),
      });
      expect(doc.nodes.containsKey(nodeA), isFalse);
      expect(doc.nodes.containsKey(nodeB), isFalse);
      expect(doc.roots, isNot(contains(nodeA)));
      expect(doc.nodes.keys, {nodeC, camId});
    });

    test('reparented moves the node between roots and children', () {
      final doc = baseDoc();
      foldCommandIntoDocument(doc, {
        'op': 'updateNode',
        'node': nodeC.toToken(),
        'flags': ['reparented'],
        'spec': encodeNodeCommandSpec(doc.nodes[nodeC]!, doc),
        'parent': nodeA.toToken(),
      });
      expect(doc.roots, isNot(contains(nodeC)));
      expect(doc.nodes[nodeA]!.children, [nodeB, nodeC]);
    });

    test('upsertPayload registers the spec and decodes both byte forms', () {
      final doc = baseDoc();
      foldCommandIntoDocument(doc, {
        'op': 'upsertPayload',
        'id': 'chunk:${timeId.toToken()}',
        'bytes': base64Encode([1, 2, 3, 4]),
        'encoding': 'floats',
        'length': 4,
      });
      expect(doc.payloads[timeId]!.encoding, PayloadEncoding.floats);
      expect(doc.payloads[timeId]!.bytes, [1, 2, 3, 4]);
      foldCommandIntoDocument(doc, {
        'op': 'upsertPayload',
        'id': 'chunk:${keysId.toToken()}',
        'bytes': [5, 6],
        'encoding': 'floats',
      });
      expect(doc.payloads[keysId]!.bytes, [5, 6]);
    });

    test('non-document ops leave the mirror alone', () {
      final doc = baseDoc();
      for (final op in <Map<String, Object?>>[
        {'op': 'anim', 'anim': animId.toToken(), 'play': true},
        {
          'op': 'setMorphWeights',
          'node': nodeA.toToken(),
          'weights': [0.5],
        },
        {
          'op': 'applyImpulse',
          'node': nodeA.toToken(),
          'impulse': [0, 1, 0],
        },
        {
          'op': 'query',
          'q': 7,
          'type': 'pose',
          'nodes': ['all'],
        },
        {'op': 'addJoint', 'id': 3, 'type': 'fixed'},
      ]) {
        expect(commandAffectsDocument(op), isFalse);
        foldCommandIntoDocument(doc, op);
      }
      expect(writeFscene(doc), writeFscene(baseDoc()));
    });
  });

  group('transform fold', () {
    test('absent fields keep the node\'s previous values', () {
      final doc = baseDoc();
      foldTransformIntoDocument(doc, nodeC, translation: Vector3(4, 5, 6));
      final trs = doc.nodes[nodeC]!.transform as TrsTransform;
      expect(trs.translation, Vector3(4, 5, 6));
      expect(trs.rotation, Quaternion.identity());
      expect(trs.scale, Vector3(1, 1, 1));
    });

    test('a MatrixTransform base decomposes before merging', () {
      final doc = baseDoc();
      doc.nodes[nodeC]!.transform = MatrixTransform(
        Matrix4.compose(
          Vector3(1, 2, 3),
          Quaternion.identity(),
          Vector3(2, 2, 2),
        ),
      );
      foldTransformIntoDocument(doc, nodeC, scale: Vector3(3, 3, 3));
      final trs = doc.nodes[nodeC]!.transform as TrsTransform;
      expect(trs.translation, Vector3(1, 2, 3));
      expect(trs.scale, Vector3(3, 3, 3));
    });
  });

  group('migrateFscene', () {
    test('the real v2 showcase document upgrades to v5 on load', () {
      final source = File('assets/showcase/cube.fscene').readAsStringSync();
      expect((jsonDecode(source) as Map)['fscene'], 2);
      final doc = readFscene(source);
      expect(doc.formatVersion, currentFsceneVersion);
      expect(doc.nodes, isNotEmpty);
    });

    test('v4 geometry gains legacyWinding on the way to v5', () {
      final json = <String, dynamic>{
        'fscene': 4,
        'documentId': DocumentId(Uint8List(16)).toToken(),
        'stage': <String, dynamic>{},
        'resources': <String, dynamic>{
          'geo:0000000000000': <String, dynamic>{
            'kind': 'geometry',
            'vertices': 'chunk:0000000000001',
            'indices': 'chunk:0000000000002',
          },
          'geo:0000000000003': <String, dynamic>{
            'kind': 'geometry',
            'vertices': 'chunk:0000000000001',
          },
        },
      };
      final migrated = migrateFscene(json);
      expect(migrated['fscene'], 5);
      final resources = migrated['resources'] as Map;
      expect((resources['geo:0000000000000'] as Map)['legacyWinding'], isTrue);
      // Only indexed geometry is flagged — an index-less mesh reads as-is.
      expect(
        (resources['geo:0000000000003'] as Map).containsKey('legacyWinding'),
        isFalse,
      );
    });

    test('v1 left-handed documents migrate; right-handed refuse', () {
      Map<String, dynamic> v1(String handedness) => {
        'fscene': 1,
        'documentId': DocumentId(Uint8List(16)).toToken(),
        'stage': {
          'handedness': handedness,
          'upAxis': 'y',
          'unitsPerMeter': 1.0,
        },
      };
      final migrated = migrateFscene(v1('left'));
      expect(migrated['fscene'], 5);
      expect(migrated['stage'], isNot(contains('handedness')));
      expect(
        () => migrateFscene(v1('right')),
        throwsA(isA<FsceneVersionException>()),
      );
    });

    test('newer-than-supported and missing versions refuse', () {
      Map<String, dynamic> doc(Object? version) => {
        'fscene': version,
        'documentId': DocumentId(Uint8List(16)).toToken(),
        'stage': <String, dynamic>{},
      };
      expect(
        () => migrateFscene(doc(currentFsceneVersion + 1)),
        throwsA(isA<FsceneVersionException>()),
      );
      expect(
        () => migrateFscene(doc(null)..remove('fscene')),
        throwsA(isA<FsceneVersionException>()),
      );
    });

    test('readFscene accepts JSONC comments and trailing commas', () {
      final doc = readFscene('''
      {
        // a doc-level comment
        "fscene": 5,
        "documentId": "${DocumentId(Uint8List(16)).toToken()}",
        "stage": {}, /* trailing block comment */
      }
      ''');
      expect(doc.formatVersion, 5);
    });
  });

  group('feature negotiation', () {
    test('decode refuses a required feature outside supportedFeatures', () {
      expect(
        () => readFscene('''
        {
          "fscene": 5,
          "documentId": "${DocumentId(Uint8List(16)).toToken()}",
          "stage": {},
          "featuresRequired": ["gaussianSplats"]
        }
        '''),
        throwsA(isA<FsceneUnsupportedFeatureException>()),
      );
    });

    test('missingRequiredFeatures names only the unrealized required set', () {
      final doc = SceneDocument()
        ..featuresRequired.addAll({'skinning', 'streaming', 'renderTextures'})
        ..featuresUsed.add('prefabInstances');
      expect(missingRequiredFeatures(doc), {'streaming'});
    });
  });

  group('runtime glTF/GLB import', () {
    /// A single-triangle glTF document; [bufferUri] switches it between
    /// single-file .glb and multi-file .gltf shapes.
    Map<String, Object?> gltfJson({String? bufferUri}) => {
      'asset': {'version': '2.0'},
      'scene': 0,
      'scenes': [
        {
          'nodes': [0],
        },
      ],
      'nodes': [
        {'mesh': 0, 'name': 'tri'},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {'POSITION': 0},
              'indices': 1,
              'material': 0,
            },
          ],
        },
      ],
      'materials': [
        {
          'pbrMetallicRoughness': {
            'baseColorFactor': [0.9, 0.1, 0.1, 1.0],
          },
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
        {'buffer': 0, 'byteOffset': 36, 'byteLength': 6},
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 3,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 0.0],
        },
        {'bufferView': 1, 'componentType': 5123, 'count': 3, 'type': 'SCALAR'},
      ],
      'buffers': [
        {'byteLength': 42, 'uri': ?bufferUri},
      ],
    };

    /// Three f32 vec3 positions then three u16 indices.
    Uint8List triBin() {
      final out = ByteData(42);
      const positions = [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0];
      for (var i = 0; i < positions.length; i++) {
        out.setFloat32(i * 4, positions[i], Endian.little);
      }
      const indices = [0, 1, 2];
      for (var i = 0; i < indices.length; i++) {
        out.setUint16(36 + i * 2, indices[i], Endian.little);
      }
      return out.buffer.asUint8List();
    }

    Uint8List glbOf(Map<String, Object?> json, Uint8List bin) {
      final jsonBytes = utf8.encode(jsonEncode(json));
      final jsonPad = (4 - jsonBytes.length % 4) % 4;
      final binPad = (4 - bin.length % 4) % 4;
      final total =
          12 + 8 + jsonBytes.length + jsonPad + 8 + bin.length + binPad;
      final out = ByteData(total);
      out.setUint32(0, 0x46546C67, Endian.little); // 'glTF'
      out.setUint32(4, 2, Endian.little);
      out.setUint32(8, total, Endian.little);
      var off = 12;
      out.setUint32(off, jsonBytes.length + jsonPad, Endian.little);
      out.setUint32(off + 4, 0x4E4F534A, Endian.little); // 'JSON'
      off += 8;
      for (var i = 0; i < jsonBytes.length; i++) {
        out.setUint8(off + i, jsonBytes[i]);
      }
      off += jsonBytes.length;
      // The GLB spec pads the JSON chunk with spaces.
      for (var i = 0; i < jsonPad; i++) {
        out.setUint8(off + i, 0x20);
      }
      off += jsonPad;
      out.setUint32(off, bin.length + binPad, Endian.little);
      out.setUint32(off + 4, 0x004E4942, Endian.little); // 'BIN\0'
      off += 8;
      for (var i = 0; i < bin.length; i++) {
        out.setUint8(off + i, bin[i]);
      }
      return out.buffer.asUint8List();
    }

    test('a single-file .glb imports to a realizable document', () {
      final doc = importGlbToSceneDocument(glbOf(gltfJson(), triBin()));

      final node = doc.rootNodes.single;
      expect(node.name, 'tri');
      final mesh = node.components.firstWhere((c) => c.type == 'mesh');
      final geometry =
          doc.resources[(mesh.properties['geometry'] as ResourceRefValue).id]!
              as GeometryResource;
      expect(doc.resources.values.whereType<MaterialResource>(), hasLength(1));
      // Vertex and index chunks landed as byte-carrying payloads — the
      // document re-realizes without an offline cook.
      expect(doc.payload(geometry.vertices!)!.bytes, isNotEmpty);
      expect(doc.payload(geometry.indices!)!.bytes, isNotEmpty);
      expect(geometry.bounds, isNotNull);

      // The imported document round-trips through the codec like any
      // authored one.
      final reparsed = readFscene(writeFscene(doc));
      expect(writeFscene(reparsed), writeFscene(doc));
    });

    test('a multi-file .gltf resolves external resources', () {
      final bin = triBin();
      final gltf = utf8.encode(jsonEncode(gltfJson(bufferUri: 'tri.bin')));
      final doc = importGltfToSceneDocument(
        Uint8List.fromList(gltf),
        resolveUri: (uri) => uri == 'tri.bin' ? bin : null,
      );
      expect(doc.rootNodes.single.name, 'tri');
      expect(doc.payloads.values.every((p) => p.bytes != null), isTrue);
    });

    test('the bundled cube.glb imports: textured mesh + punctual light', () {
      final bytes = File('assets/showcase/cube.glb').readAsBytesSync();
      final doc = importGlbToSceneDocument(bytes);
      expect(doc.rootNodes, hasLength(2));
      final meshNode = doc.rootNodes.firstWhere(
        (n) => n.components.any((c) => c.type == 'mesh'),
      );
      final mesh = meshNode.components.firstWhere((c) => c.type == 'mesh');
      final geometry =
          doc.resources[(mesh.properties['geometry'] as ResourceRefValue).id]!
              as GeometryResource;
      expect(doc.payload(geometry.vertices!)!.bytes, isNotEmpty);
      expect(doc.payload(geometry.indices!)!.bytes, isNotEmpty);
      // The embedded PNG stays an encoded image payload for the native
      // container-sniffing texture path.
      final textures = doc.resources.values.whereType<TextureResource>();
      expect(textures, hasLength(1));
      final imagePayload = doc.payload(textures.single.payload!)!;
      expect(
        imagePayload.bytes!.sublist(0, 4),
        [0x89, 0x50, 0x4E, 0x47], // PNG magic
      );
      // KHR_lights_punctual's directional light lands as a component.
      expect(
        doc.rootNodes.any(
          (n) => n.components.any((c) => c.type == 'directionalLight'),
        ),
        isTrue,
      );
      // And the imported document survives the document-layer round trip.
      final reparsed = readFscene(writeFscene(doc));
      expect(writeFscene(reparsed), writeFscene(doc));
    });

    test('a data-uri buffer decodes without the resolver', () {
      final uri =
          'data:application/octet-stream;base64,${base64Encode(triBin())}';
      final gltf = utf8.encode(jsonEncode(gltfJson(bufferUri: uri)));
      final doc = importGltfToSceneDocument(
        Uint8List.fromList(gltf),
        resolveUri: (uri) => throw StateError('resolver must not be called'),
      );
      expect(doc.rootNodes.single.name, 'tri');
    });

    test('an unresolvable resource refuses with FormatException', () {
      final gltf = utf8.encode(jsonEncode(gltfJson(bufferUri: 'gone.bin')));
      expect(
        () => importGltfToSceneDocument(
          Uint8List.fromList(gltf),
          resolveUri: (uri) => null,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('extensionsRequired the importer lacks refuse loudly', () {
      final json = gltfJson()
        ..['extensionsRequired'] = ['KHR_draco_mesh_compression'];
      expect(
        () => importGlbToSceneDocument(glbOf(json, triBin())),
        throwsA(isA<UnsupportedRequiredExtensionException>()),
      );
    });

    test('malformed containers refuse with FormatException', () {
      expect(
        () => importGlbToSceneDocument(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });

    test('import warnings reach the callback instead of printing', () {
      final json = gltfJson()..['extensionsUsed'] = ['VENDOR_fake_extension'];
      final warnings = <GltfImportWarning>[];
      importGlbToSceneDocument(glbOf(json, triBin()), onWarning: warnings.add);
      expect(warnings, isNotEmpty);
    });

    // The two upstream-fidelity pins a mid-flight edit regressed: the
    // sheen extension's field is `sheenRoughnessTexture`, and
    // `specularFactor` defaults to 1.0 per KHR_materials_specular.
    test('sheen/specular parse per the glTF extension spec', () {
      final doc = parseGltfJson({
        'asset': {'version': '2.0'},
        'textures': [
          {'source': 0},
        ],
        'materials': [
          {
            'extensions': {
              'KHR_materials_sheen': {
                'sheenRoughnessTexture': {'index': 0},
              },
              'KHR_materials_specular': {},
            },
          },
        ],
      });
      final material = doc.materials.single;
      expect(material.sheen!.roughnessTexture, isNotNull);
      expect(material.sheen!.roughnessTexture!.index, 0);
      expect(material.specular!.factor, 1.0);
    });
  });
}
