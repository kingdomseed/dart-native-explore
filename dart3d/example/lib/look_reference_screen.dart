/// The look-reference capture view (`--dart-define=DART3D_SCENE=lookref`):
/// nothing but the board of `look_reference_scene.dart`, stepping through
/// its variants on a timer and logging each one, so a script can capture
/// a screenshot per variant without touching the device.
library;

import 'dart:async';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';

import 'look_reference_scene.dart';

/// How long each variant stays up. Long enough for a reload, an IBL
/// prefilter and a slow device's screenshot.
const Duration lookVariantDwell = Duration(seconds: 8);

class LookReferenceScreen extends StatefulWidget {
  const LookReferenceScreen({super.key, this.quality});

  /// The `DART3D_QUALITY` boot tier — null runs the widget defaults.
  final SceneQuality? quality;

  @override
  State<LookReferenceScreen> createState() => _LookReferenceScreenState();
}

class _LookReferenceScreenState extends State<LookReferenceScreen> {
  final _controller = SceneController();
  Timer? _timer;
  double _aspect = 0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    if (size.width <= 0 || size.height <= 0) return;
    final aspect = size.width / size.height;
    if ((aspect - _aspect).abs() < 0.01) return;
    _aspect = aspect;
    _index = 0;
    _show();
    _timer?.cancel();
    _timer = Timer.periodic(lookVariantDwell, (_) {
      _index = (_index + 1) % LookVariant.values.length;
      _show();
    });
  }

  void _show() {
    final variant = LookVariant.values[_index];
    _controller.loadDocument(buildLookReference(variant, aspect: _aspect));
    dnLog('dart3d: lookref variant ${variant.label}');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.dark,
      backgroundColor: const Color(0xFF000000),
      body: SceneView(controller: _controller, quality: widget.quality),
    );
  }
}
