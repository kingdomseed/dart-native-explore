import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/dev_reload.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:test/test.dart';

import '../../tool/reload_host.dart';
import '../tool/w34_asset_fixture.dart';

class RecordingElement extends SceneViewElement {
  RecordingElement(SceneController controller)
    : super(SceneViewLeaf(controller: controller));

  final sent = <({int tag, Uint8List data})>[];
  bool failCommand = false;

  @override
  void sendMutation(int tag, Uint8List bytes) {
    if (failCommand && tag == D3Protocol.command) {
      throw StateError('application failure');
    }
    sent.add((tag: tag, data: Uint8List.fromList(bytes)));
  }

  List<Map<String, dynamic>> get commands => [
    for (final mutation in sent.where((m) => m.tag == D3Protocol.command))
      ..._flatten(
        jsonDecode(utf8.decode(mutation.data)) as Map<String, dynamic>,
      ),
  ];

  List<Map<String, dynamic>> _flatten(Map<String, dynamic> op) =>
      op['op'] == 'batch'
      ? (op['ops'] as List).cast<Map<String, dynamic>>()
      : [op];
}

class Messages {
  final values = <String>[];
  final events = StreamController<String>.broadcast(sync: true);
  void add(String value) {
    values.add(value);
    events.add(value);
  }

  Future<String> next(String prefix) => events.stream
      .firstWhere((message) => message.startsWith(prefix))
      .timeout(const Duration(seconds: 8));
  Future<void> until(bool Function() accepted) async {
    if (accepted()) return;
    await events.stream
        .firstWhere((_) => accepted())
        .timeout(const Duration(seconds: 8));
  }
}

void main() {
  late Directory directory;
  late File source;
  late File sidecar;
  late String initial;
  late SceneController controller;
  SceneController? controllerToDispose;
  late RecordingElement element;
  late Messages status;
  late Messages hostLog;
  SceneReloadHost? host;
  DevSceneReload? reload;

  setUp(() async {
    directory = Directory(
      (await Directory.systemTemp.createTemp(
        'w34-assets-',
      )).resolveSymbolicLinksSync(),
    );
    source = File('${directory.path}/quad.fscene');
    sidecar = File('${directory.path}/pixels.fsceneb');
    initial = writeFsceneWithExtensions(buildW34AssetDocument());
    source.writeAsStringSync(initial);
    writeW34Pattern(directory);
    controller = SceneController();
    controllerToDispose = controller;
    element = RecordingElement(controller);
    controller.attachElement(element);
    status = Messages();
    hostLog = Messages();
  });

  tearDown(() async {
    await reload?.stop();
    await host?.close();
    controllerToDispose?.detachElement(element);
    controllerToDispose?.dispose();
    await status.events.close();
    await hostLog.events.close();
    await directory.delete(recursive: true);
    host = null;
    reload = null;
  });

  Future<void> settleEvents() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  Future<void> start() async {
    host = await SceneReloadHost.start(
      sourcePath: source.path,
      port: 0,
      log: hostLog.add,
    );
    reload = DevSceneReload(
      controller: controller,
      endpoint: host!.endpoint,
      onStatus: status.add,
    );
    final loaded = status.next('loadDocument');
    await reload!.start();
    await loaded;
    await settleEvents();
  }

  Future<void> pattern(bool alternate, {bool rename = false}) async {
    final applied = status.until(
      () =>
          controller.document?.payload(w34ImageId)?.bytes?.toString() ==
          w34Pixels(alternate: alternate).toString(),
    );
    if (rename) {
      final replacement = File('${directory.path}/replacement.tmp');
      replacement.writeAsBytesSync(
        emitW34Container(
          buildW34AssetDocument(),
          blobs: {w34ImageId: w34Pixels(alternate: alternate)},
        ),
        flush: true,
      );
      replacement.renameSync(sidecar.path);
    } else {
      writeW34Pattern(directory, alternate: alternate);
    }
    await applied;
    await settleEvents();
  }

  Map<String, dynamic> manifest() =>
      jsonDecode(writeFsceneWithExtensions(controller.document!))
          as Map<String, dynamic>;

  test(
    'sidecar-only save loads once, upserts same-ID bytes before consumers, leaves camera and authored text fixed',
    () async {
      await start();
      expect(
        element.sent.where((m) => m.tag == D3Protocol.loadScene),
        hasLength(1),
      );
      expect(controller.document!.payload(w34ImageId)!.bytes, w34Pixels());
      final authoredBytes = source.readAsBytesSync();
      final authoredHash = await Process.run('shasum', [
        '-a',
        '256',
        source.path,
      ]);
      expect(authoredHash.exitCode, 0);
      final camera = controller.document!.nodes.values.singleWhere(
        (n) => n.name == 'w34.camera',
      );
      final cameraJson = manifest()['nodes']['n:${camera.id.toToken()}'];
      element.sent.clear();
      await pattern(true);
      expect(source.readAsBytesSync(), authoredBytes);
      final changedHash = await Process.run('shasum', [
        '-a',
        '256',
        source.path,
      ]);
      expect(changedHash.exitCode, 0);
      expect(changedHash.stdout, authoredHash.stdout);
      expect(source.readAsStringSync(), initial);
      expect(
        controller.document!.payload(w34ImageId)!.bytes,
        w34Pixels(alternate: true),
      );
      final commands = element.commands;
      expect(commands.map((op) => op['op']), [
        'upsertPayload',
        'upsertResource',
        'upsertResource',
        'updateNode',
      ]);
      expect(commands.first, {
        'op': 'upsertPayload',
        'id': 'chunk:${w34ImageId.toToken()}',
        'bytes': base64Encode(w34Pixels(alternate: true)),
        'encoding': 'image',
        'format': 'rgba8',
        'width': 2,
        'height': 2,
        'length': 16,
      });
      expect(manifest()['nodes']['n:${camera.id.toToken()}'], cameraJson);
      expect(
        element.sent.where(
          (m) => m.tag == D3Protocol.loadScene || m.tag == D3Protocol.payload,
        ),
        isEmpty,
      );
      expect(status.values.where((v) => v == 'loadDocument'), hasLength(1));
      element.sent.clear();
      final reread = status.next('applyDiff');
      writeW34Pattern(directory, alternate: true);
      await reread;
      await settleEvents();
      expect(element.sent, isEmpty);
      expect(
        hostLog.values.where((v) => v.startsWith('payload ')).length,
        greaterThanOrEqualTo(3),
      );
    },
  );

  test(
    'invalid UTF-8 retains the scene and a later file save recovers',
    () async {
      await start();
      final accepted = controller.document;
      element.sent.clear();
      final rejected = hostLog.next('file error');
      source.writeAsBytesSync([0xff], flush: true);
      expect(await rejected, contains('Failed to decode'));
      expect(controller.document, same(accepted));
      expect(element.sent, isEmpty);
      final applied = status.next('applyDiff');
      source.writeAsStringSync(initial, flush: true);
      await applied;
      expect(controller.document!.payload(w34ImageId)!.bytes, w34Pixels());
      expect(element.sent, isEmpty);
    },
  );

  test(
    'malformed text retains accepted identity; real atomic scene rename recovers',
    () async {
      await start();
      final accepted = controller.document;
      element.sent.clear();
      final raw = jsonDecode(initial) as Map<String, dynamic>;
      final resources = raw['resources'] as Map;
      final material =
          resources.values.singleWhere((r) => r['kind'] == 'material') as Map;
      material['properties']['baseColor'] = {
        'c': [1],
      };
      for (final text in ['{', '[]', jsonEncode(raw)]) {
        final error = status.next('input error');
        source.writeAsStringSync(text, flush: true);
        await error;
        await settleEvents();
        expect(controller.document, same(accepted));
        expect(element.sent, isEmpty);
      }
      final recovered = status.next('applyDiff');
      File(
        '${directory.path}/atomic.tmp',
      ).writeAsStringSync(initial, flush: true);
      File('${directory.path}/atomic.tmp').renameSync(source.path);
      await recovered;
      await settleEvents();
      expect(controller.document, isNot(same(accepted)));
      expect(element.sent, isEmpty);
    },
  );

  final invalidSidecars = <String, Uint8List Function()>{
    'malformed container': () => Uint8List.fromList([0, 1, 2]),
    'missing chunk': () => emitW34Container(buildW34AssetDocument()),
    'missing payload ID': () {
      final doc = buildW34AssetDocument()..payloads.clear();
      return emitW34Container(doc);
    },
    for (final field in [
      'encoding',
      'layout',
      'format',
      'width',
      'height',
      'length',
    ])
      'mismatched $field': () {
        final doc = buildW34AssetDocument();
        doc.payloads[w34ImageId] = PayloadSpec(
          w34ImageId,
          encoding: field == 'encoding'
              ? PayloadEncoding.bytes
              : PayloadEncoding.image,
          layout: field == 'layout' ? 'other' : null,
          format: field == 'format' ? 'ktx2' : 'rgba8',
          width: field == 'width' ? 3 : 2,
          height: field == 'height' ? 3 : 2,
          length: field == 'length' ? 17 : 16,
        );
        return emitW34Container(doc, blobs: {w34ImageId: w34Pixels()});
      },
    'wrong declared byte length': () => emitW34Container(
      buildW34AssetDocument(),
      blobs: {w34ImageId: Uint8List(15)},
    ),
  };
  for (final entry in invalidSidecars.entries) {
    test(
      '${entry.key} retains accepted identity and real rename sidecar recovers',
      () async {
        await start();
        final accepted = controller.document;
        element.sent.clear();
        final error = status.next('input error');
        sidecar.writeAsBytesSync(entry.value(), flush: true);
        await error;
        await settleEvents();
        expect(controller.document, same(accepted));
        expect(element.sent, isEmpty);
        await pattern(true, rename: true);
        expect(controller.document, isNot(same(accepted)));
        expect(element.commands.first['op'], 'upsertPayload');
        expect(source.readAsStringSync(), initial);
      },
    );
  }

  test(
    'matching but invalid raw dimensions and undeclared raw byte length reject before load',
    () async {
      for (final dimensions in [(0, 2, 0), (2, -1, 0), (2, 2, 15)]) {
        final doc = buildW34AssetDocument();
        doc.payloads[w34ImageId] = PayloadSpec(
          w34ImageId,
          encoding: PayloadEncoding.image,
          format: 'rgba8',
          width: dimensions.$1,
          height: dimensions.$2,
        );
        source.writeAsStringSync(writeFsceneWithExtensions(doc));
        sidecar.writeAsBytesSync(
          emitW34Container(doc, blobs: {w34ImageId: Uint8List(dimensions.$3)}),
        );
        host = await SceneReloadHost.start(
          sourcePath: source.path,
          port: 0,
          log: hostLog.add,
        );
        reload = DevSceneReload(
          controller: controller,
          endpoint: host!.endpoint,
          onStatus: status.add,
        );
        final error = status.next('input error');
        await reload!.start();
        await error;
        expect(controller.document, isNull);
        expect(element.sent, isEmpty);
        await reload!.stop();
        await host!.close();
      }
    },
  );

  test(
    'missing HTTP sidecar retains accepted document and later file creation recovers',
    () async {
      await start();
      final accepted = controller.document;
      element.sent.clear();
      final error = status.next('input error');
      sidecar.deleteSync();
      expect(await error, contains('404'));
      await settleEvents();
      expect(controller.document, same(accepted));
      expect(element.sent, isEmpty);
      await pattern(true);
      expect(element.commands.first['op'], 'upsertPayload');
    },
  );

  test(
    'recursive nested asset events reread unchanged text; surplus chunks and graph are ignored',
    () async {
      final nested = Directory('${directory.path}/nested')..createSync();
      final doc = buildW34AssetDocument()
        ..payloadSource = 'nested/pixels.fsceneb';
      initial = writeFsceneWithExtensions(doc);
      source.writeAsStringSync(initial);
      writeW34Pattern(nested);
      await start();
      element.sent.clear();
      final side = buildW34AssetDocument()
        ..nodes.clear()
        ..roots.clear();
      const surplus = LocalId(123, 99);
      side.addPayload(
        PayloadSpec(
          surplus,
          encoding: PayloadEncoding.bytes,
          bytes: Uint8List(1),
        ),
      );
      final applied = status.until(
        () =>
            controller.document!.payload(w34ImageId)!.bytes.toString() ==
            w34Pixels(alternate: true).toString(),
      );
      File('${nested.path}/pixels.fsceneb').writeAsBytesSync(
        emitW34Container(
          side,
          blobs: {
            w34ImageId: w34Pixels(alternate: true),
            surplus: Uint8List(1),
          },
        ),
        flush: true,
      );
      await applied;
      expect(controller.document!.nodes, hasLength(2));
      expect(controller.document!.payloads.keys, [w34ImageId]);
      expect(source.readAsStringSync(), initial);
    },
  );

  test(
    'text-only path accepts color/exposure edits without sidecar and keeps camera fixed',
    () async {
      final doc = buildW34AssetDocument()..payloadSource = null;
      doc.payloads.clear();
      final texture = doc.resources.values.whereType<TextureResource>().single;
      doc.resources.remove(texture.id);
      final material = doc.resources.values
          .whereType<MaterialResource>()
          .single;
      material.properties.remove('baseColorTexture');
      initial = writeFsceneWithExtensions(doc);
      source.writeAsStringSync(initial);
      sidecar.deleteSync();
      await start();
      final cameraId = controller.document!.nodes.values
          .singleWhere((n) => n.name == 'w34.camera')
          .id;
      final camera = manifest()['nodes']['n:${cameraId.toToken()}'];
      element.sent.clear();
      final next = readFsceneLogged(initial);
      next.resources.values
          .whereType<MaterialResource>()
          .single
          .properties['baseColor'] = const ColorValue(
        0,
        0,
        1,
        1,
      );
      final applied = status.next('applyDiff');
      source.writeAsStringSync(writeFsceneWithExtensions(next), flush: true);
      await applied;
      expect(element.commands.map((op) => op['op']), [
        'upsertResource',
        'updateNode',
      ]);
      expect(manifest()['nodes']['n:${cameraId.toToken()}'], camera);
      await settleEvents();
      element.sent.clear();
      final exposed =
          jsonDecode(writeFsceneWithExtensions(next)) as Map<String, dynamic>;
      final environment =
          (exposed['resources'] as Map).values.singleWhere(
                (r) => r['kind'] == 'environment',
              )
              as Map;
      environment['exposure'] = 0.25;
      final exposureApplied = status.next('applyDiff');
      source.writeAsStringSync(jsonEncode(exposed), flush: true);
      await exposureApplied;
      expect(element.commands.map((op) => op['op']), [
        'upsertResource',
        'updateStage',
      ]);
      expect(
        controller.document!.resources.values
            .whereType<EnvironmentResource>()
            .single
            .exposure,
        0.25,
      );
      expect(manifest()['nodes']['n:${cameraId.toToken()}'], camera);
      expect(hostLog.values.where((v) => v.startsWith('payload ')), isEmpty);
    },
  );

  test(
    'missing authored file reports error and later save recovers; unrelated saves reread harmlessly',
    () async {
      await start();
      element.sent.clear();
      final error = hostLog.next('file error');
      source.renameSync('${directory.path}/moved.fscene');
      await error;
      final recovered = status.next('applyDiff');
      source.writeAsStringSync(initial, flush: true);
      await recovered;
      await settleEvents();
      final reread = status.next('applyDiff');
      File(
        '${directory.path}/unrelated.txt',
      ).writeAsStringSync('saved', flush: true);
      await reread;
      await settleEvents();
      expect(element.sent, isEmpty);
    },
  );

  test(
    'HTTP boundary rejects escapes and serves fresh bytes while socket is claimed',
    () async {
      await start();
      final client = HttpClient();
      final outside = await Directory.systemTemp.createTemp('w34-outside-');
      try {
        File('${outside.path}/outside.fsceneb').writeAsBytesSync([9]);
        Link(
          '${directory.path}/escape.fsceneb',
        ).createSync('${outside.path}/outside.fsceneb');
        Directory('${directory.path}/directory.fsceneb').createSync();
        File('${directory.path}/literal%20.fsceneb').writeAsBytesSync([7]);
        Future<(int, List<int>)> get(String path) async {
          final req = await client.getUrl(
            host!.endpoint.replace(
              scheme: 'http',
              path: '/payload',
              queryParameters: {'path': path},
            ),
          );
          final response = await req.close();
          final bytes = await response.fold<List<int>>(
            [],
            (a, b) => a..addAll(b),
          );
          return (response.statusCode, bytes);
        }

        for (final path in [
          '/etc/passwd.fsceneb',
          '../escape.fsceneb',
          'https://example.com/a.fsceneb',
          'escape.fsceneb',
          'pixels.txt',
        ]) {
          expect((await get(path)).$1, 400, reason: path);
        }
        expect((await get('missing.fsceneb')).$1, 404);
        expect((await get('directory.fsceneb')).$1, 500);
        final literal = await get('literal%20.fsceneb');
        expect(literal.$1, 200);
        expect(literal.$2, [7]);
        final first = await get('pixels.fsceneb');
        expect(first.$1, 200);
        writeW34Pattern(directory, alternate: true);
        expect((await get('pixels.fsceneb')).$2, isNot(first.$2));
        await expectLater(
          WebSocket.connect(host!.endpoint.toString()),
          throwsA(isA<WebSocketException>()),
        );
        await status.until(
          () =>
              controller.document!.payload(w34ImageId)!.bytes.toString() ==
              w34Pixels(alternate: true).toString(),
        );
      } finally {
        client.close(force: true);
        await outside.delete(recursive: true);
      }
    },
  );

  test(
    'stop is synchronous, idempotent and prevents saves reaching the same disposed controller',
    () async {
      await start();
      final stopped = reload!.stop();
      expect(reload!.stop(), same(stopped));
      await stopped;
      controller.detachElement(element);
      controller.dispose();
      controllerToDispose = null;
      element.sent.clear();
      final count = status.values.length;
      writeW34Pattern(directory, alternate: true);
      await host!.done.timeout(const Duration(seconds: 5));
      await settleEvents();
      expect(controller.document, isNull);
      expect(element.sent, isEmpty);
      expect(status.values, hasLength(count));
      expect(() => reload!.start(), throwsStateError);
    },
  );

  test(
    'host close reports restart; peer disconnect releases listener',
    () async {
      await start();
      final closed = status.next('socket closed');
      final port = host!.endpoint.port;
      await host!.close();
      expect(await closed, contains('restart required'));
      final rebound = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      await rebound.close(force: true);
    },
  );

  test(
    'constructor opens no connection; refused start reports I/O and emits no mutation',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final endpoint = Uri.parse('ws://127.0.0.1:${server.port}/scene');
      await server.close(force: true);
      reload = DevSceneReload(
        controller: controller,
        endpoint: endpoint,
        onStatus: status.add,
      );
      expect(status.values, isEmpty);
      await reload!.start();
      expect(status.values.last, startsWith('connection error'));
      expect(controller.document, isNull);
      expect(element.sent, isEmpty);
    },
  );

  test(
    'stop during real pending handshake joins connection before same controller disposal',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final request = Completer<HttpRequest>();
      final requests = server.listen(request.complete);
      try {
        reload = DevSceneReload(
          controller: controller,
          endpoint: Uri.parse('ws://127.0.0.1:${server.port}/scene'),
          onStatus: status.add,
        );
        final connecting = reload!.start();
        final pending = await request.future.timeout(
          const Duration(seconds: 5),
        );
        await reload!.stop().timeout(const Duration(seconds: 5));
        controller.detachElement(element);
        controller.dispose();
        controllerToDispose = null;
        final count = status.values.length;
        await connecting;
        await pending.response.close();
        expect(controller.document, isNull);
        expect(element.sent, isEmpty);
        expect(status.values, hasLength(count));
      } finally {
        await server.close(force: true);
        await requests.cancel();
      }
    },
  );

  test(
    'stop drains active real HTTP body read before same disposed controller can receive a late response',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final reading = Completer<HttpRequest>();
      WebSocket? peer;
      StreamSubscription<dynamic>? peerMessages;
      final requests = server.listen((request) async {
        if (request.uri.path == '/scene') {
          peer = await WebSocketTransformer.upgrade(request);
          peerMessages = peer!.listen((_) {});
          peer!.add(initial);
        } else {
          request.response.add([70, 83, 67, 66]);
          await request.response.flush();
          reading.complete(request);
        }
      });
      try {
        reload = DevSceneReload(
          controller: controller,
          endpoint: Uri.parse('ws://127.0.0.1:${server.port}/scene'),
          onStatus: status.add,
        );
        await reload!.start();
        final pending = await reading.future.timeout(
          const Duration(seconds: 5),
        );
        final stop = reload!.stop();
        final count = status.values.length;
        await stop.timeout(const Duration(seconds: 5));
        controller.detachElement(element);
        controller.dispose();
        controllerToDispose = null;
        await pending.response.close();
        await settleEvents();
        expect(controller.document, isNull);
        expect(element.sent, isEmpty);
        expect(status.values, hasLength(count));
      } finally {
        await reload?.stop();
        await peer?.close();
        await peerMessages?.cancel();
        await server.close(force: true);
        await requests.cancel();
      }
    },
  );

  test(
    'serial preparation reads the controller document after the last await',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final firstRead = Completer<void>();
      final release = Completer<void>();
      var reads = 0;
      WebSocket? peer;
      StreamSubscription<dynamic>? peerMessages;
      final requests = server.listen((request) async {
        if (request.uri.path == '/scene') {
          peer = await WebSocketTransformer.upgrade(request);
          peerMessages = peer!.listen((_) {});
          peer!
            ..add(initial)
            ..add(initial);
        } else {
          reads++;
          if (reads == 1) {
            firstRead.complete();
            await release.future;
          }
          request.response.add(
            emitW34Container(
              buildW34AssetDocument(),
              blobs: {w34ImageId: w34Pixels()},
            ),
          );
          await request.response.close();
        }
      });
      try {
        reload = DevSceneReload(
          controller: controller,
          endpoint: Uri.parse('ws://127.0.0.1:${server.port}/scene'),
          onStatus: status.add,
        );
        await reload!.start();
        await firstRead.future.timeout(const Duration(seconds: 5));
        await settleEvents();
        expect(reads, 1);
        controller.loadDocument(readFsceneLogged(initial));
        final applied = status.next('applyDiff');
        release.complete();
        await applied;
        await status.until(
          () =>
              reads == 2 &&
              status.values.where((v) => v.startsWith('applyDiff')).length == 2,
        );
        expect(
          element.sent.where((m) => m.tag == D3Protocol.loadScene),
          hasLength(1),
        );
        expect(status.values.where((v) => v == 'loadDocument'), isEmpty);
        expect(controller.document!.payload(w34ImageId)!.bytes, w34Pixels());
        expect(
          element.commands.where((op) => op['op'] == 'upsertPayload'),
          hasLength(1),
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await reload?.stop();
        await peer?.close();
        await peerMessages?.cancel();
        await server.close(force: true);
        await requests.cancel();
      }
    },
  );

  test(
    'binary frame rejection recovers on later text; HTTP redirects are not followed',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final upgraded = Completer<WebSocket>();
      var redirectedReads = 0;
      final requests = server.listen((request) async {
        if (request.uri.path == '/scene') {
          upgraded.complete(await WebSocketTransformer.upgrade(request));
        } else if (request.uri.path == '/payload') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            '/elsewhere',
          );
          await request.response.close();
        } else {
          redirectedReads++;
          await request.response.close();
        }
      });
      WebSocket? peer;
      StreamSubscription<dynamic>? peerMessages;
      try {
        reload = DevSceneReload(
          controller: controller,
          endpoint: Uri.parse('ws://127.0.0.1:${server.port}/scene'),
          onStatus: status.add,
        );
        await reload!.start();
        peer = await upgraded.future;
        peerMessages = peer.listen((_) {});
        final binary = status.next('input error');
        peer.add([1, 2, 3]);
        expect(await binary, contains('text'));
        final redirect = status.next('input error');
        peer.add(initial);
        expect(await redirect, contains('302'));
        expect(redirectedReads, 0);
        expect(controller.document, isNull);
        final loaded = status.next('loadDocument');
        final textOnly = buildW34AssetDocument()..payloadSource = null;
        peer.add(writeFsceneWithExtensions(textOnly));
        await loaded;
        expect(
          element.sent.where((m) => m.tag == D3Protocol.loadScene),
          hasLength(1),
        );
      } finally {
        await reload?.stop();
        await peer?.close();
        await peerMessages?.cancel();
        await server.close(force: true);
        await requests.cancel();
      }
    },
  );

  test(
    'fixture CLI changes only the sidecar and reproducibly restores the baseline',
    () async {
      const dart = '/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart';
      Future<void> action(String action) async {
        final result = await Process.run(dart, [
          'tool/w34_asset_fixture.dart',
          directory.path,
          action,
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }

      await action('init');
      final baseline = sidecar.readAsBytesSync();
      final authoredHash = await Process.run('shasum', [
        '-a',
        '256',
        source.path,
      ]);
      await action('b');
      expect(sidecar.readAsBytesSync(), isNot(baseline));
      expect(source.readAsStringSync(), initial);
      await action('malformed');
      expect(sidecar.readAsBytesSync(), [0, 1, 2]);
      await action('a');
      expect(sidecar.readAsBytesSync(), baseline);
      final restoredHash = await Process.run('shasum', [
        '-a',
        '256',
        source.path,
      ]);
      expect(authoredHash.exitCode, 0);
      expect(restoredHash.exitCode, 0);
      expect(restoredHash.stdout, authoredHash.stdout);
    },
  );

  test(
    'async controller application errors propagate to caller zone',
    () async {
      final failure = Completer<Object>();
      final ready = Completer<void>();
      runZonedGuarded(
        () async {
          await start();
          element.failCommand = true;
          writeW34Pattern(directory, alternate: true);
          await failure.future.timeout(const Duration(seconds: 8));
          element.failCommand = false;
          await reload!.stop();
          await host!.close();
          ready.complete();
        },
        (error, stack) {
          if (!failure.isCompleted) failure.complete(error);
        },
      );
      await ready.future.timeout(const Duration(seconds: 8));
      expect(
        await failure.future.timeout(const Duration(seconds: 8)),
        isA<StateError>(),
      );
      expect(status.values.where((v) => v.startsWith('input error')), isEmpty);
      element.failCommand = false;
    },
  );

  test('CLI SIGTERM exits cleanly and releases its listener', () async {
    // dn test uses flutter_tester. A CLI subprocess needs its sibling host SDK.
    const dart = '/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart';
    final process = await Process.start(dart, [
      '../tool/reload_host.dart',
      source.path,
      '0',
    ]);
    final errors = process.stderr.transform(utf8.decoder).join();
    final lines = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    try {
      expect(
        await lines.moveNext().timeout(const Duration(seconds: 8)),
        isTrue,
      );
      expect(lines.current, startsWith('listening ws://127.0.0.1:'));
      final endpoint = Uri.parse(lines.current.split(' ')[1]);
      expect(process.kill(ProcessSignal.sigterm), isTrue);
      expect(await process.exitCode.timeout(const Duration(seconds: 5)), 0);
      expect(await errors, isEmpty);
      final rebound = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        endpoint.port,
      );
      await rebound.close(force: true);
    } finally {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode;
      await lines.cancel();
    }
  });
}
