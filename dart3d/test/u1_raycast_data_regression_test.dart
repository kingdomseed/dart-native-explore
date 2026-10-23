import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('payload BVH cache observes current bytes', () {
    test('replacing vertex bytes moves the picked triangle', () {
      final scene = _makePayloadScene(
        vertices: _twoTriangleVertices(),
        indices: _indices([0, 1, 2]),
      );
      final ray = _centerRay();

      expect(raycastDocument(scene.doc, ray)?.distance, closeTo(2.0, 1e-5));

      scene.vertices.bytes = _unskinnedVertices([
        for (final p in _twoTrianglePositions()) Vector3(p.x + 20, p.y, p.z),
      ]);

      expect(raycastDocument(scene.doc, ray), isNull);
    });

    test('replacing index bytes selects the current triangle', () {
      final scene = _makePayloadScene(
        vertices: _twoTriangleVertices(),
        indices: _indices([0, 1, 2]),
      );
      final ray = _centerRay();

      expect(raycastDocument(scene.doc, ray)?.distance, closeTo(2.0, 1e-5));

      scene.indices.bytes = _indices([3, 4, 5]);

      expect(raycastDocument(scene.doc, ray), isNull);
    });

    test('in-place index byte mutation updates ScenePointer picking', () {
      final scene = _makePayloadScene(
        vertices: _twoTriangleVertices(),
        indices: _indices([0, 1, 2]),
      );
      final pointer = ScenePointer(document: scene.doc);
      final ray = _centerRay();

      expect(pointer.pointAlong(ray)?.distance, closeTo(2.0, 1e-5));
      expect(pointer.hit?.node, scene.node);

      final bytes = scene.indices.bytes!;
      final data = ByteData.sublistView(bytes);
      data.setUint16(0, 3, Endian.little);
      data.setUint16(2, 4, Endian.little);
      data.setUint16(4, 5, Endian.little);

      expect(pointer.pointAlong(ray), isNull);
      expect(pointer.hit, isNull);
    });

    test('in-place vertex byte mutation updates ScenePointer picking', () {
      final scene = _makePayloadScene(
        vertices: _twoTriangleVertices(),
        indices: _indices([0, 1, 2]),
      );
      final pointer = ScenePointer(document: scene.doc);
      final ray = _centerRay();

      expect(pointer.pointAlong(ray)?.distance, closeTo(2.0, 1e-5));
      expect(pointer.hit?.node, scene.node);

      final bytes = scene.vertices.bytes!;
      final data = ByteData.sublistView(bytes);
      for (var vertex = 0; vertex < 3; vertex++) {
        final offset = vertex * VertexPack.unskinnedUv1TangentStride;
        data.setFloat32(
          offset,
          data.getFloat32(offset, Endian.little) + 20,
          Endian.little,
        );
      }

      expect(pointer.pointAlong(ray), isNull);
      expect(pointer.hit, isNull);
    });
  });

  test('skinned hit normal uses the inverse-transpose of joint scale', () {
    final positions = <Vector3>[
      Vector3(0, 0, -1),
      Vector3(0, 0, 1),
      Vector3(1, -1, -1),
    ];
    final normal = Vector3(1 / math.sqrt(2), 1 / math.sqrt(2), 0);
    final scene = _makePayloadScene(
      vertices: VertexPack.skinned(
        positions: positions,
        normals: List<Vector3>.filled(3, normal),
        joints: List<Vector4>.filled(3, Vector4.zero()),
        weights: List<Vector4>.filled(3, Vector4(1, 0, 0, 0)),
      ),
      indices: _indices([0, 1, 2]),
      layout: 'skinned_uv1_tangent',
    );
    final joint = scene.doc.newId();
    scene.doc.addNode(
      NodeSpec(
        id: joint,
        transform: TrsTransform(
          translation: Vector3.zero(),
          rotation: Quaternion.identity(),
          scale: Vector3(2, 1, 1),
        ),
      ),
    );
    scene.doc.roots.add(joint);
    final skin = scene.doc.newId();
    scene.doc.addSkin(
      SkinSpec(
        skin,
        joints: [joint],
        inverseBindMatrices: _identityInverseBindMatrices(scene.doc),
      ),
    );
    scene.doc.nodes[scene.node]!.skin = skin;

    final center = Vector3(2 / 3, -1 / 3, -1 / 3);
    final towardSurface = Vector3(-1, -2, 0)..normalize();
    final ray = Ray.originDirection(center - towardSurface * 2, towardSurface);
    final hit = raycastDocument(scene.doc, ray);

    expect(hit, isNotNull);
    final hitNormal = hit!.worldNormal;
    expect(hitNormal, isNotNull);
    expect(hitNormal!.x, closeTo(0.4472135955, 1e-5));
    expect(hitNormal.y, closeTo(0.8944271910, 1e-5));
    expect(hitNormal.z, closeTo(0.0, 1e-5));
  });

  test('p3t4 hit normal comes from its packed tangent-frame quaternion', () {
    final bytes = Uint8List(3 * 28);
    final data = ByteData.sublistView(bytes);
    final positions = <Vector3>[
      Vector3(-1, -1, 1),
      Vector3(1, -1, 1),
      Vector3(0, 1, 1),
    ];
    final rotation = Quaternion(0.2, 0.3, 0.4, math.sqrt(0.71));
    for (var vertex = 0; vertex < positions.length; vertex++) {
      final offset = vertex * 28;
      final position = positions[vertex];
      data.setFloat32(offset, position.x, Endian.little);
      data.setFloat32(offset + 4, position.y, Endian.little);
      data.setFloat32(offset + 8, position.z, Endian.little);
      data.setFloat32(offset + 12, rotation.x, Endian.little);
      data.setFloat32(offset + 16, rotation.y, Endian.little);
      data.setFloat32(offset + 20, rotation.z, Endian.little);
      data.setFloat32(offset + 24, rotation.w, Endian.little);
    }
    final scene = _makePayloadScene(
      vertices: bytes,
      indices: _indices([0, 1, 2]),
      layout: 'p3t4',
    );

    final hit = raycastDocument(scene.doc, _centerRay());

    expect(hit, isNotNull);
    expect(hit!.distance, closeTo(1.0, 1e-5));
    final hitNormal = hit.worldNormal;
    expect(hitNormal, isNotNull);
    expect(hitNormal!.x, closeTo(0.6655689864, 1e-5));
    expect(hitNormal.y, closeTo(-0.0970459910, 1e-5));
    expect(hitNormal.z, closeTo(-0.74, 1e-5));
  });

  for (final (label, jointIndex) in <(String, double)>[
    ('NaN', double.nan),
    ('infinity', double.infinity),
  ]) {
    test('malformed $label joint index rejects skinned picking', () {
      final scene = _makePayloadScene(
        vertices: VertexPack.skinned(
          positions: [Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(0, 1, 0)],
          joints: List<Vector4>.filled(3, Vector4(jointIndex, 0, 0, 0)),
          weights: List<Vector4>.filled(3, Vector4(1, 0, 0, 0)),
        ),
        indices: _indices([0, 1, 2]),
        layout: 'skinned_uv1_tangent',
      );
      final joint = scene.doc.newId();
      scene.doc.addNode(NodeSpec(id: joint));
      scene.doc.roots.add(joint);
      final skin = scene.doc.newId();
      scene.doc.addSkin(
        SkinSpec(
          skin,
          joints: [joint],
          inverseBindMatrices: _identityInverseBindMatrices(scene.doc),
        ),
      );
      scene.doc.nodes[scene.node]!.skin = skin;

      expect(raycastDocument(scene.doc, _centerRay()), isNull);
    });
  }
}

typedef _PayloadScene = ({
  SceneDocument doc,
  PayloadSpec vertices,
  PayloadSpec indices,
  LocalId node,
});

_PayloadScene _makePayloadScene({
  required Uint8List vertices,
  required Uint8List indices,
  String layout = 'unskinned_uv1_tangent',
}) {
  final doc = SceneDocument();
  final vertexPayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.vertexBuffer,
      layout: layout,
      length: vertices.lengthInBytes,
      bytes: vertices,
    ),
  );
  final indexPayload = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.indexBuffer,
      format: 'uint16',
      length: indices.lengthInBytes,
      bytes: indices,
    ),
  );
  final geometry = doc.newId();
  doc.addResource(
    GeometryResource(
      geometry,
      vertices: vertexPayload.id,
      indices: indexPayload.id,
    ),
  );
  final node = doc.newId();
  doc.addNode(
    NodeSpec(
      id: node,
      components: [
        ComponentSpec(
          'mesh',
          properties: {'geometry': ResourceRefValue(geometry)},
        ),
      ],
    ),
  );
  doc.roots.add(node);
  return (doc: doc, vertices: vertexPayload, indices: indexPayload, node: node);
}

Uint8List _twoTriangleVertices() => _unskinnedVertices(_twoTrianglePositions());

List<Vector3> _twoTrianglePositions() => [
  Vector3(-1, -1, 0),
  Vector3(1, -1, 0),
  Vector3(0, 1, 0),
  Vector3(9, -1, 0),
  Vector3(11, -1, 0),
  Vector3(10, 1, 0),
];

Uint8List _unskinnedVertices(List<Vector3> positions) => VertexPack.unskinned(
  positions: positions,
  normals: List<Vector3>.filled(positions.length, Vector3(0, 0, 1)),
);

Uint8List _indices(List<int> indices) {
  final bytes = Uint8List(indices.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < indices.length; index++) {
    data.setUint16(index * 2, indices[index], Endian.little);
  }
  return bytes;
}

LocalId _identityInverseBindMatrices(SceneDocument doc) {
  final bytes = Uint8List(64);
  final data = ByteData.sublistView(bytes);
  for (var diagonal = 0; diagonal < 4; diagonal++) {
    data.setFloat32(diagonal * 20, 1.0, Endian.little);
  }
  return doc
      .addPayload(
        PayloadSpec(
          doc.newId(),
          encoding: PayloadEncoding.matrices,
          length: bytes.lengthInBytes,
          bytes: bytes,
        ),
      )
      .id;
}

Ray _centerRay() => Ray.originDirection(Vector3(0, 0, -2), Vector3(0, 0, 1));
