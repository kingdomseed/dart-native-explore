import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'src/doc_layer.dart';
import 'src/fsceneb_reader.dart';
import 'src/scene_controller.dart';
import 'src/scene_model.dart';

/// One opt-in reload session. Construction opens no connection.
final class DevSceneReload {
  DevSceneReload({
    required SceneController controller,
    required Uri endpoint,
    required void Function(String message) onStatus,
  }) : _controller = controller,
       _endpoint = endpoint,
       _onStatus = onStatus {
    if ((endpoint.scheme != 'ws' && endpoint.scheme != 'wss') ||
        endpoint.host.isEmpty ||
        endpoint.path != '/scene' ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpoint.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'Expected ws(s)://host:port/scene',
      );
    }
  }

  final SceneController _controller;
  final Uri _endpoint;
  final void Function(String) _onStatus;
  HttpClient? _client;
  WebSocket? _socket;
  StreamSubscription<void>? _messages;
  Future<void>? _connecting;
  Future<SceneDocument?>? _preparing;
  Future<void>? _stopping;
  bool _stopped = false;

  /// Connects once. Completion acknowledges setup, not a rendered frame.
  Future<void> start() {
    if (_stopped || _connecting != null) {
      throw StateError('Reload sessions are single-use');
    }
    _client = HttpClient();
    return _connecting = _connect();
  }

  void _status(String message) {
    if (!_stopped) _onStatus(message);
  }

  Future<void> _connect() async {
    _status('connecting $_endpoint');
    late final WebSocket socket;
    try {
      socket = await WebSocket.connect(
        _endpoint.toString(),
        customClient: _client,
      );
    } on IOException catch (error) {
      if (!_stopped) {
        _status('connection error $error; restart required');
        _stopped = true;
        _client!.close(force: true);
      }
      return;
    }
    if (_stopped) {
      await socket.close();
      return;
    }
    _socket = socket;
    _status('connected $_endpoint');
    _messages = socket
        .handleError((Object error, StackTrace stack) {
          if (error is! IOException) Error.throwWithStackTrace(error, stack);
          _status('socket error $error; restart required');
          unawaited(stop());
        })
        .asyncMap(_receive)
        .listen(
          (_) {},
          onDone: () {
            if (_stopped) return;
            _status('socket closed; restart required');
            unawaited(stop());
          },
        );
    // No onError here. Application failures from asyncMap belong to the caller's zone.
  }

  Future<void> _receive(dynamic message) async {
    if (_stopped) return;
    if (message is! String) {
      _status('input error expected WebSocket text');
      return;
    }
    late final SceneDocument? next;
    final preparation = () async {
      try {
        return await _prepare(message);
      } on IOException catch (error) {
        _status('input error $error');
        return null;
      } on FormatException catch (error) {
        _status('input error $error');
        return null;
      }
    }();
    _preparing = preparation;
    try {
      next = await preparation;
    } finally {
      _preparing = null;
    }
    if (_stopped || next == null) return;
    final current = _controller.document;
    if (current == null) {
      _controller.loadDocument(next);
      _status('loadDocument');
    } else {
      final operations = _controller.applyDiff(diffScene(current, next), next);
      _status('applyDiff ops=${operations.map((op) => op['op']).toList()}');
    }
  }

  Future<SceneDocument> _prepare(String text) async {
    final next = _parse(() => readFsceneLogged(text, log: _status));
    final source = next.payloadSource;
    if (source == null) return next;
    final relative = Uri.parse(source);
    if (source.isEmpty ||
        relative.hasScheme ||
        relative.hasAuthority ||
        relative.path.startsWith('/') ||
        source.contains('\\') ||
        relative.hasQuery ||
        relative.hasFragment ||
        !source.endsWith('.fsceneb')) {
      throw const FormatException(
        'payloadSource must be a relative .fsceneb path',
      );
    }
    final url = _endpoint.replace(
      scheme: _endpoint.scheme == 'wss' ? 'https' : 'http',
      path: '/payload',
      queryParameters: {'path': source},
    );
    final request = await _client!.getUrl(url);
    request.followRedirects = false;
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('Payload HTTP ${response.statusCode}', uri: url);
    }
    final body = BytesBuilder(copy: false);
    await for (final chunk in response) {
      body.add(chunk);
    }
    final sidecar = _parse(() => readFsceneb(body.takeBytes()));
    for (final required in next.payloads.values) {
      final supplied = sidecar.payloads[required.id];
      final bytes = supplied?.bytes;
      if (supplied == null ||
          bytes == null ||
          required.encoding != supplied.encoding ||
          required.layout != supplied.layout ||
          required.format != supplied.format ||
          required.width != supplied.width ||
          required.height != supplied.height ||
          required.length != supplied.length) {
        throw FormatException(
          'Missing bytes or mismatched descriptor for ${required.id}',
        );
      }
      if (required.length != null && required.length != bytes.length) {
        throw FormatException('Payload length mismatch for ${required.id}');
      }
      if (required.encoding == PayloadEncoding.image &&
          required.format == 'rgba8') {
        final width = required.width;
        final height = required.height;
        if (width == null ||
            height == null ||
            width <= 0 ||
            height <= 0 ||
            bytes.length != width * height * 4) {
          throw FormatException(
            'Invalid RGBA8 dimensions or bytes for ${required.id}',
          );
        }
      }
      required.bytes = bytes;
    }
    return next;
  }

  /// Revokes callbacks and application synchronously, then joins owned I/O.
  Future<void> stop() {
    _stopped = true;
    _client?.close(force: true);
    return _stopping ??= _stop();
  }

  Future<void> _stop() async {
    final preparation = _preparing;
    await Future.wait<void>([
      if (_messages != null) _settleCancellation(_messages!.cancel()),
      if (_socket != null) _settleCancellation(_socket!.close()),
      if (_connecting != null) _settleCancellation(_connecting!),
      // asyncMap cancellation does not join its converter future.
      if (preparation != null) _settleCancellation(preparation),
    ]);
  }
}

SceneDocument _parse(SceneDocument Function() decode) {
  try {
    return decode();
  } on FormatException {
    rethrow;
  } on FscenebFormatException catch (error) {
    throw FormatException(error.toString());
  } on FsceneFormatException catch (error) {
    throw FormatException(error.toString());
  } on FsceneVersionException catch (error) {
    throw FormatException(error.toString());
  } on FsceneUnsupportedFeatureException catch (error) {
    throw FormatException(error.toString());
  } on TypeError catch (error) {
    throw FormatException(error.toString());
  } on ArgumentError catch (error) {
    throw FormatException(error.toString());
  }
}

Future<void> _settleCancellation(Future<dynamic> work) async {
  try {
    await work;
  } on IOException {
    // Closing the owned client interrupts handshake and response reads.
  }
}
