import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

const root = '/private/tmp/dart3d-w34-ios-channel-transitions-20261028/r1/parent';
const native = 'dart3d/ios/Classes/SceneViewHost.swift';
String hash(File f) => sha256.convert(f.readAsBytesSync()).toString();
Map<String, dynamic> read(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;
void run(String cmd, List<String> args, {String? cwd}) {
  final r = Process.runSync(cmd, args, workingDirectory: cwd, environment: {'COPYFILE_DISABLE': '1'});
  if (r.exitCode != 0) throw StateError('$cmd failed: ${r.stdout}${r.stderr}');
}

void main() {
  final baseline = read('$root/baseline/production-packet/source-sha256.json');
  final prior = read('/private/tmp/dart3d-w34-ios-live-catcher-composition-20261028/r1/parent/production/source-sha256.json');
  final current = read('$root/production/source-sha256.json');
  final clean = read('$root/clean/runtime-packet/source-sha256.json');
  for (final p in baseline.keys) {
    if (baseline[p] != prior[p]) throw StateError('Previous accepted baseline drift $p');
    if (current[p] != clean[p] || hash(File(p)) != current[p]) throw StateError('Runtime/current mismatch $p');
  }
  final changed = baseline.keys.where((p) => baseline[p] != current[p]).toList();
  if (changed.length != 1 || changed.single != native) throw StateError('Unexpected production delta $changed');
  final initial = read('$root/initial-all-source.json');
  for (final e in initial.entries.where((e) => e.key != native)) {
    if (!File(e.key).existsSync() || hash(File(e.key)) != e.value) throw StateError('Preservation failed ${e.key}');
  }
  final locks = read('/private/tmp/dart3d-w34-ios-live-catcher-composition-20261028/r1/parent/production/receipt.json')['locks'] as Map<String, dynamic>;
  for (final e in locks.entries) {
    if (hash(File(e.key)) != e.value) throw StateError('Lock changed ${e.key}');
  }
  final scratch = Directory.systemTemp.createTempSync('w34-channel-replay-');
  try {
    final a = File('${scratch.path}/a/$native');
    a.parent.createSync(recursive: true);
    File('$root/SceneViewHost.baseline.swift').copySync(a.path);
    final b = File('${scratch.path}/b/$native');
    b.parent.createSync(recursive: true);
    File(native).copySync(b.path);
    final delta = Process.runSync('/usr/bin/git', ['diff', '--no-index', '--src-prefix=a/', '--dst-prefix=b/', 'a/$native', 'b/$native'], workingDirectory: scratch.path);
    if (delta.exitCode != 1) throw StateError('No correction diff');
    File('$root/production/correction.patch').writeAsStringSync(delta.stdout.toString().replaceAll('a/a/', 'a/').replaceAll('b/b/', 'b/'));
    final replay = Directory('${scratch.path}/replay')..createSync();
    run('tar', ['-xzf', '$root/baseline/production-packet/source.tgz', '-C', replay.path]);
    run('/usr/bin/git', ['apply', '--check', '$root/production/correction.patch'], cwd: replay.path);
    run('/usr/bin/git', ['apply', '$root/production/correction.patch'], cwd: replay.path);
    for (final e in current.entries) {
      if (hash(File('${replay.path}/${e.key}')) != e.value) throw StateError('Forward replay ${e.key}');
    }
    run('/usr/bin/git', ['apply', '--reverse', '--check', '$root/production/correction.patch'], cwd: replay.path);
    run('/usr/bin/git', ['apply', '--reverse', '$root/production/correction.patch'], cwd: replay.path);
    for (final e in baseline.entries) {
      if (hash(File('${replay.path}/${e.key}')) != e.value) throw StateError('Reverse replay ${e.key}');
    }
  } finally {
    scratch.deleteSync(recursive: true);
  }
  final config = File('dart3d/example/ios/DartNative/Generated.xcconfig').readAsLinesSync();
  final target = config.singleWhere((l) => l.startsWith('DN_TARGET='));
  final defines = config.where((l) => l.startsWith('DART_DEFINES=')).expand((l) => l.substring(13).split(',')).where((s) => s.isNotEmpty).map((s) => utf8.decode(base64.decode(s))).where((s) => s.startsWith('DART3D_W34')).toList();
  if (target != 'DN_TARGET=lib/main.dart' || defines.isNotEmpty) throw StateError('Normal target not restored');
  final head = Process.runSync('/usr/bin/git', ['rev-parse', 'HEAD']).stdout.toString().trim();
  if (head != '2f38e4e33f0b1cb678bc408a42d069c796cefc12') throw StateError('HEAD changed');
  for (final p in [native, 'dart3d/ios/Classes/RenderTargets.swift']) {
    if (File(p).readAsStringSync().contains('screenTransition ')) throw StateError('Trace remains $p');
  }
  run('/usr/bin/git', ['diff', '--check']);
  File('$root/production/receipt.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'head': head, 'baselineArchiveSha256': hash(File('$root/baseline/production-packet/source.tgz')), 'sourceArchiveSha256': hash(File('$root/production/source.tgz')), 'patchSha256': hash(File('$root/production/correction.patch')), 'changedPaths': changed, 'unownedOverlayPreserved': baseline.length - 1, 'preexistingOtherFilesPreserved': initial.length - 1, 'locks': locks, 'cleanRuntimeAll66MatchesProduction': true, 'forwardReverseAll66Replay': true, 'traceRemoved': true, 'scratchRemoved': true, 'normalTarget': target, 'remainingW34Defines': defines}));
  print('One native expression changed; ${baseline.length - 1} overlay and ${initial.length - 1} prior files preserved. Clean runtime matches all66. Replay and six locks pass.');
}
