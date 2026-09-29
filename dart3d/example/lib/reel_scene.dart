/// The social-reel capture mode (`--dart-define=DART3D_SCENE=reel`):
/// the 3D DartNative logo on the [DnLogoStage.reel] look, full-screen,
/// with no app chrome at all — no nav, labels, buttons or stats — and
/// the system bars hidden, so `adb shell screenrecord` captures only
/// the SceneView.
///
/// Motion is the logo's authored `Spin` clip (one full turn plus a
/// gentle bob and nod), slowed natively through the clip's timeScale
/// to one revolution per [reelRevolutionSeconds]. The rig and camera
/// stay fixed, so relative to the logo this is a smooth 360° orbit
/// whose pink/cyan rims stay behind the subject the whole way round —
/// and the native clock drives it, so there's no Dart-timer judder.
library;

import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart';

import 'dn_logo_stage.dart';
import 'showcase_loader.dart';

/// Seconds per full revolution in the reel (the clip authors 6 s).
const double reelRevolutionSeconds = 13.5;

/// The logo's authored `Spin` clip length, seconds.
const double _spinClipSeconds = 6.0;

/// How much wider than the glyph the frame is — the operator asked for
/// the logo zoomed out more than the showcase default.
const double _reelFrameMargin = 1.7;

const _reelItem = ShowcaseItem(
  'dartnative_logo',
  'assets/showcase/dn_logo.fsceneb',
  'reel',
  // Face-on from the glyph's reading side (−Z), a touch above.
  cameraDir: (0.0, 0.16, -1.0),
  stage: DnLogoStage.reel,
  frameMargin: _reelFrameMargin,
);

/// Full-screen capture view for the social reel — nothing but the
/// SceneView.
class ReelScreen extends StatefulWidget {
  const ReelScreen({super.key, this.quality});

  /// The `DART3D_QUALITY` boot tier — null runs the widget defaults.
  final SceneQuality? quality;

  @override
  State<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends State<ReelScreen> {
  final _controller = SceneController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final size = MediaQuery.of(context).size;
    if (size.width <= 0 || size.height <= 0) return;
    _loaded = true;
    _load(size.width / size.height);
  }

  void _load(double aspect) {
    final scene = loadShowcaseScene(
      _reelItem,
      bytesFor: loadAssetBytes,
      log: dnLog,
    );
    if (scene == null) return;
    // Fit the framed radius into the horizontal half-angle (portrait
    // narrows fovY·aspect), then author the pose into the document
    // before it ships.
    const fovY = 0.8;
    final dist = max(
      scene.frameRadius * 2.8,
      scene.frameRadius / (tan(fovY / 2) * aspect),
    );
    final dir = scene.cameraDir;
    final fwd = -dir;
    scene.document.nodes[scene.cameraNode]?.transform = TrsTransform(
      translation: scene.cameraTarget + dir * dist,
      rotation:
          Quaternion.axisAngle(Vector3(0, 1, 0), atan2(fwd.x, fwd.z)) *
          Quaternion.axisAngle(Vector3(1, 0, 0), -asin(fwd.y.clamp(-1.0, 1.0))),
    );
    _controller.loadDocument(scene.document);
    final spin = _controller.animations.values
        .where((a) => a.name == 'Spin')
        .firstOrNull;
    if (spin != null) {
      _controller.playAnimation(
        spin.id,
        loop: true,
        timeScale: _spinClipSeconds / reelRevolutionSeconds,
      );
    }
    dnLog(
      'dart3d: reel — frameRadius ${scene.frameRadius.toStringAsFixed(3)} '
      'dist ${dist.toStringAsFixed(3)} spin ${spin != null}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.dark,
      backgroundColor: const Color(0xFF090E12),
      body: SceneView(controller: _controller, quality: widget.quality),
    );
  }
}
