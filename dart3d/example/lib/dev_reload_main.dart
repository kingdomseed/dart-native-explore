import 'dart:async';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/dev_reload.dart';
import 'package:dartnative/dartnative.dart';

import 'dartnative_plugin_registrant.dart';

void main() {
  const url = String.fromEnvironment('DART3D_RELOAD_URL');
  if (url.isEmpty) {
    throw ArgumentError('DART3D_RELOAD_URL is required for this dev target');
  }
  DartNativePluginRegistrant.registerAll();
  runApp(const _ReloadScreen(url: url));
}

class _ReloadScreen extends StatefulWidget {
  const _ReloadScreen({required this.url});
  final String url;

  @override
  State<_ReloadScreen> createState() => _ReloadScreenState();
}

class _ReloadScreenState extends State<_ReloadScreen> {
  final _controller = SceneController();
  late final DevSceneReload _reload;
  String _status = 'waiting for authored text';

  @override
  void initState() {
    super.initState();
    _reload = DevSceneReload(
      controller: _controller,
      endpoint: Uri.parse(widget.url),
      onStatus: (message) {
        dnLog('w34 $message');
        if (mounted) setState(() => _status = message);
      },
    );
    unawaited(_reload.start());
  }

  @override
  void dispose() {
    unawaited(_reload.stop().then((_) => _controller.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    brightness: Brightness.dark,
    backgroundColor: const Color(0xFF111111),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SceneView(controller: _controller, quality: SceneQuality.high),
        ),
        SizedBox(
          height: 100,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _status,
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12),
            ),
          ),
        ),
      ],
    ),
  );
}
