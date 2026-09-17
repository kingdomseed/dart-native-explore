// Inspect a .fsceneb container: decode it, dump the node/component/
// resource inventory so we can see what the engine needs to render it.
import 'dart:io';
import 'package:scene/scene.dart';

void main(List<String> args) {
  final file = File(args.single);
  final bytes = file.readAsBytesSync();
  final doc = readFsceneb(bytes);
  print('== ${file.uri.pathSegments.last} (${bytes.length} bytes) ==');

  final compCounts = <String, int>{};
  for (final n in doc.nodes.values) {
    for (final comp in n.components) {
      compCounts[comp.type] = (compCounts[comp.type] ?? 0) + 1;
    }
  }
  print('nodes: ${doc.nodes.length}  roots: ${doc.nodes.values.where((n) => doc.roots.contains(n.id)).length}');
  print('components:');
  compCounts.forEach((k, v) => print('  $k ×$v'));

  final resTypes = <String, int>{};
  for (final r in doc.resources.values) {
    resTypes[r.runtimeType.toString()] = (resTypes[r.runtimeType.toString()] ?? 0) + 1;
  }
  print('resources:');
  resTypes.forEach((k, v) => print('  $k ×$v'));
  print('payloads: ${doc.payloads.length}');
  var totalBytes = 0;
  // ignore: avoid_print
  for (final p in doc.payloads.values) {
    totalBytes += (p.length as int);
  }
  print('payload bytes total: $totalBytes');
}
