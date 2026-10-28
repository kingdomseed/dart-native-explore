import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final root = File(Platform.script.toFilePath()).parent.path;
  final expected = (jsonDecode(File('$root/evidence/output-sha256.json').readAsStringSync()) as Map).cast<String, String>();
  final failures = <String>[];
  for (final entry in expected.entries) {
    final result = await Process.run('shasum', ['-a', '256', entry.key], workingDirectory: root);
    if (result.exitCode != 0 || result.stdout.toString().split(' ').first != entry.value) {
      failures.add(entry.key);
    }
  }
  final report = {'filesChecked': expected.length, 'mismatches': failures};
  File('$root/parent-receipt-check.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln(jsonEncode(report));
  if (failures.isNotEmpty) exitCode = 1;
}
