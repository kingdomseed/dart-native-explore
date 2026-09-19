// Emits `assets/showcase/cube.glb`: a textured 24-vertex cube plus a
// KHR_lights_punctual directional light, with `dn-logo.png` embedded as
// the texture image — a real single-file `.glb` for the W29 runtime
// import lane. Re-run with:
//
//   dart run tool/make_cube_glb.dart
//
// The cube is per-face unwrapped (4 verts/face) so normals stay flat;
// the PNG bytes ride inside the BIN chunk as an image bufferView, which
// exercises the importer's embedded-image path end to end.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() {
  final png = File('assets/dn-logo.png').readAsBytesSync();

  // 6 faces × 4 verts: positions (f32×3), normals (f32×3), uvs (f32×2).
  const axes = [
    [0.0, 0.0, 1.0], // +Z normal
    [0.0, 0.0, -1.0],
    [1.0, 0.0, 0.0],
    [-1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [0.0, -1.0, 0.0],
  ];
  // For each face normal n, in-face tangent axes u, v.
  const uvAxes = [
    [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
    ],
    [
      [-1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
    ],
    [
      [0.0, 0.0, -1.0],
      [0.0, 1.0, 0.0],
    ],
    [
      [0.0, 0.0, 1.0],
      [0.0, 1.0, 0.0],
    ],
    [
      [1.0, 0.0, 0.0],
      [0.0, 0.0, -1.0],
    ],
    [
      [1.0, 0.0, 0.0],
      [0.0, 0.0, 1.0],
    ],
  ];
  const corners = [
    [-0.5, -0.5],
    [0.5, -0.5],
    [0.5, 0.5],
    [-0.5, 0.5],
  ];

  final positions = <double>[];
  final normals = <double>[];
  final uvs = <double>[];
  final indices = <int>[];
  for (var f = 0; f < 6; f++) {
    final n = axes[f];
    final u = uvAxes[f][0];
    final v = uvAxes[f][1];
    for (var c = 0; c < 4; c++) {
      positions.addAll([
        n[0] * 0.5 + u[0] * corners[c][0] + v[0] * corners[c][1],
        n[1] * 0.5 + u[1] * corners[c][0] + v[1] * corners[c][1],
        n[2] * 0.5 + u[2] * corners[c][0] + v[2] * corners[c][1],
      ]);
      normals.addAll(n);
      uvs.addAll([corners[c][0] + 0.5, corners[c][1] + 0.5]);
    }
    indices.addAll([f * 4, f * 4 + 1, f * 4 + 2, f * 4, f * 4 + 2, f * 4 + 3]);
  }

  final bin = BytesBuilder();
  int align() {
    final pad = (4 - bin.length % 4) % 4;
    for (var i = 0; i < pad; i++) {
      bin.addByte(0);
    }
    return bin.length;
  }

  final viewOffsets = <int>[];
  void pushF32(List<double> values) {
    viewOffsets.add(align());
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      data.setFloat32(i * 4, values[i], Endian.little);
    }
    bin.add(data.buffer.asUint8List());
  }

  pushF32(positions); // view 0
  pushF32(normals); // view 1
  pushF32(uvs); // view 2
  viewOffsets.add(align()); // view 3: indices
  final indexData = ByteData(indices.length * 2);
  for (var i = 0; i < indices.length; i++) {
    indexData.setUint16(i * 2, indices[i], Endian.little);
  }
  bin.add(indexData.buffer.asUint8List());
  viewOffsets.add(align()); // view 4: image
  bin.add(png);
  final binBytes = bin.toBytes();

  final json = <String, Object?>{
    'asset': {
      'version': '2.0',
      'generator': 'dart3d make_cube_glb.dart (W29 lane asset)',
    },
    'scene': 0,
    'scenes': [
      {
        'nodes': [0, 1],
      },
    ],
    'nodes': [
      {
        'mesh': 0,
        'name': 'cube',
        'rotation': [0.259, 0.259, 0.0, 0.929],
      },
      {
        'name': 'key',
        'rotation': [-0.4, 0.2, 0.0, 0.893],
        'extensions': {
          'KHR_lights_punctual': {'light': 0},
        },
      },
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2},
            'indices': 3,
            'material': 0,
          },
        ],
      },
    ],
    'materials': [
      {
        'pbrMetallicRoughness': {
          'baseColorTexture': {'index': 0},
          'roughnessFactor': 0.6,
        },
      },
    ],
    'textures': [
      {'source': 0},
    ],
    'images': [
      {'mimeType': 'image/png', 'bufferView': 4},
    ],
    'extensionsUsed': ['KHR_lights_punctual'],
    'extensions': {
      'KHR_lights_punctual': {
        'lights': [
          {
            'type': 'directional',
            'color': [1.0, 0.98, 0.92],
            'intensity': 3.0,
          },
        ],
      },
    },
    'bufferViews': [
      {
        'buffer': 0,
        'byteOffset': viewOffsets[0],
        'byteLength': positions.length * 4,
      },
      {
        'buffer': 0,
        'byteOffset': viewOffsets[1],
        'byteLength': normals.length * 4,
      },
      {'buffer': 0, 'byteOffset': viewOffsets[2], 'byteLength': uvs.length * 4},
      {
        'buffer': 0,
        'byteOffset': viewOffsets[3],
        'byteLength': indices.length * 2,
      },
      {'buffer': 0, 'byteOffset': viewOffsets[4], 'byteLength': png.length},
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 24,
        'type': 'VEC3',
        'min': [-0.5, -0.5, -0.5],
        'max': [0.5, 0.5, 0.5],
      },
      {'bufferView': 1, 'componentType': 5126, 'count': 24, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5126, 'count': 24, 'type': 'VEC2'},
      {'bufferView': 3, 'componentType': 5123, 'count': 36, 'type': 'SCALAR'},
    ],
    'buffers': [
      {'byteLength': binBytes.length},
    ],
  };

  final jsonBytes = utf8.encode(jsonEncode(json));
  final jsonPad = (4 - jsonBytes.length % 4) % 4;
  final binPad = (4 - binBytes.length % 4) % 4;
  final total =
      12 + 8 + jsonBytes.length + jsonPad + 8 + binBytes.length + binPad;
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
  for (var i = 0; i < jsonPad; i++) {
    out.setUint8(off + i, 0x20);
  }
  off += jsonPad;
  out.setUint32(off, binBytes.length + binPad, Endian.little);
  out.setUint32(off + 4, 0x004E4942, Endian.little); // 'BIN\0'
  off += 8;
  for (var i = 0; i < binBytes.length; i++) {
    out.setUint8(off + i, binBytes[i]);
  }

  File('assets/showcase/cube.glb').writeAsBytesSync(out.buffer.asUint8List());
  stdout.writeln(
    'wrote assets/showcase/cube.glb ($total B, png ${png.length} B)',
  );
}
