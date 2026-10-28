import 'dart:async';
import 'dart:io';

/// Loopback transport for one explicit authored file and one app session.
final class SceneReloadHost {
  SceneReloadHost._(this.source, this._parent, this._server, this._log);

  final File source;
  final Directory _parent;
  final HttpServer _server;
  final void Function(String) _log;
  final _done = Completer<void>();
  StreamSubscription<FileSystemEvent>? _watch;
  StreamSubscription<HttpRequest>? _requests;
  StreamSubscription<dynamic>? _messages;
  WebSocket? _socket;
  bool _claimed = false;
  bool _closed = false;
  Future<void>? _closing;

  Uri get endpoint =>
      Uri(scheme: 'ws', host: '127.0.0.1', port: _server.port, path: '/scene');
  Future<void> get done => _done.future;

  static Future<SceneReloadHost> start({
    required String sourcePath,
    required int port,
    required void Function(String message) log,
  }) async {
    final file = File(sourcePath).absolute;
    final parent = Directory(file.parent.resolveSymbolicLinksSync());
    final source = File('${parent.path}/${file.uri.pathSegments.last}');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final host = SceneReloadHost._(source, parent, server, log);
    try {
      host._watch = parent
          .watch(recursive: true)
          .listen(
            (_) => host._sendAuthoredText(),
            onError: host._fail,
            onDone: () => host._fail('watch closed'),
          );
      host._requests = server.listen(
        host._accept,
        onError: host._fail,
        onDone: () => host._fail('server closed'),
      );
      return host;
    } catch (_) {
      await host.close();
      rethrow;
    }
  }

  Future<void> _accept(HttpRequest request) async {
    try {
      if (_closed) return;
      if (request.method == 'GET' && request.uri.path == '/payload') {
        await _serveSidecar(request);
        return;
      }
      if (request.method != 'GET' || request.uri.path != '/scene') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      if (_claimed) {
        request.response.statusCode = HttpStatus.conflict;
        await request.response.close();
        return;
      }
      _claimed = true;
      final socket = await WebSocketTransformer.upgrade(request);
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _messages = socket.listen(
        (_) {},
        onError: _fail,
        onDone: () => _fail('peer closed'),
      );
      _log('connected');
      _sendAuthoredText();
    } on IOException catch (error) {
      _fail(error);
    }
  }

  Future<void> _serveSidecar(HttpRequest request) async {
    try {
      final key = request.uri.queryParameters['path'];
      if (key == null || key.isEmpty) {
        throw const FormatException('Missing payload path');
      }
      final relative = Uri.parse(key);
      if (relative.hasScheme ||
          relative.hasAuthority ||
          relative.path.startsWith('/') ||
          relative.hasQuery ||
          relative.hasFragment ||
          key.contains('\\') ||
          !key.endsWith('.fsceneb')) {
        throw const FormatException('Expected relative .fsceneb path');
      }
      // queryParameters decodes once. File paths preserve any remaining literal percent signs.
      final file = File('${_parent.path}/$key');
      final normalized = file.absolute.uri.normalizePath().toFilePath();
      if (!normalized.startsWith('${_parent.path}/')) {
        throw const FormatException('Payload escapes authored parent');
      }
      final resolved = file.resolveSymbolicLinksSync();
      if (!resolved.startsWith('${_parent.path}/')) {
        throw const FormatException('Payload symlink escapes authored parent');
      }
      final bytes = File(resolved).readAsBytesSync();
      request.response.headers.contentType = ContentType.binary;
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      _log('payload path=$key bytes=${bytes.length}');
    } on FormatException catch (error) {
      request.response.statusCode = HttpStatus.badRequest;
      _log('path error $error');
    } on FileSystemException catch (error) {
      request.response.statusCode = error.osError?.errorCode == 2
          ? HttpStatus.notFound
          : HttpStatus.internalServerError;
      _log('file error $error');
    }
    await request.response.close();
  }

  void _sendAuthoredText() {
    if (_closed) return;
    late final String text;
    try {
      text = source.readAsStringSync();
    } on FileSystemException catch (error) {
      _log('file error $error');
      return;
    }
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(text);
      _log('send chars=${text.length}');
    } on IOException catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    if (_closed) return;
    _log('error $error; restart required');
    unawaited(close());
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    try {
      await Future.wait<dynamic>([
        if (_watch != null) _watch!.cancel(),
        if (_socket != null) _socket!.close(),
        if (_messages != null) _messages!.cancel(),
        _server.close(force: true),
        if (_requests != null) _requests!.cancel(),
      ]);
    } on IOException catch (error) {
      _log('close error $error');
    } finally {
      _done.complete();
    }
  }
}

Future<void> main(List<String> args) async {
  final port = args.length == 2 ? int.tryParse(args[1]) : null;
  if (port == null || port < 0 || port > 65535) {
    stderr.writeln('Usage: dart tool/reload_host.dart SOURCE PORT');
    exitCode = 64;
    return;
  }
  SceneReloadHost? host;
  StreamSubscription<ProcessSignal>? interrupt;
  StreamSubscription<ProcessSignal>? terminate;
  try {
    host = await SceneReloadHost.start(
      sourcePath: args[0],
      port: port,
      log: stdout.writeln,
    );
    final running = host;
    interrupt = ProcessSignal.sigint.watch().listen((_) => running.close());
    terminate = ProcessSignal.sigterm.watch().listen((_) => running.close());
    stdout.writeln('listening ${host.endpoint} source=${host.source.path}');
    await host.done;
  } on IOException catch (error) {
    stderr.writeln('host error $error');
    exitCode = 1;
  } finally {
    await host?.close();
    await interrupt?.cancel();
    await terminate?.cancel();
  }
}
