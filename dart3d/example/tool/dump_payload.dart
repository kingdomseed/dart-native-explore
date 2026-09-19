import 'dart:io';

import 'package:scene/scene.dart';

void main(List<String> args) {
  final doc = readFsceneb(File(args[0]).readAsBytesSync());
  for (final r in doc.resources.values) {
    if (r is! GeometryResource) continue;
    final vp = doc.payloads[r.vertices];
    final ip = r.indices != null ? doc.payloads[r.indices] : null;
    print(
      'geo ${r.id} bounds=${r.bounds == null ? "none" : "${r.bounds!.min.storage} → ${r.bounds!.max.storage}"}',
    );
    print(
      '  vertex payload ${r.vertices}: layout=${vp?.layout} enc=${vp?.encoding} len=${vp?.length} bytesLen=${vp?.bytes?.length}',
    );
    if (ip != null) {
      print(
        '  index payload ${r.indices}: fmt=${ip.format} len=${ip.length} bytesLen=${ip.bytes?.length}',
      );
      final ib = ip.bytes!;
      final u16 = ib.buffer.asUint16List(
        ib.offsetInBytes,
        ib.lengthInBytes ~/ 2,
      );
      var mx = 0;
      for (final v in u16) {
        if (v > mx) mx = v;
      }
      print(
        '  indices: count=${u16.length} maxIndex=$mx → vertexCount≥${mx + 1}',
      );
    }
    final vb = vp?.bytes;
    if (vb != null) {
      // candidate vertex counts for plausible strides
      for (final stride in [32, 36, 44, 48, 52, 56, 64, 72, 80, 104]) {
        if (vb.lengthInBytes % stride == 0) {
          print(
            '  stride $stride divides → ${vb.lengthInBytes ~/ stride} verts',
          );
        }
      }
      final f = vb.buffer.asFloat32List(
        vb.offsetInBytes,
        vb.lengthInBytes ~/ 4,
      );
      print(
        '  first 12 floats: ${f.take(12).map((e) => e.toStringAsFixed(3)).join(", ")}',
      );
      // if layout is 6-stream soa, positions occupy first vertexCount*3 floats
    }
  }
}
