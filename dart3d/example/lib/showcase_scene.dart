/// The showcase screen — the broader `flutter_scene` corpus on dart3d:
/// a scene cycler over the bundled upstream artifacts (see
/// `showcase_loader.dart` / `assets/showcase/ATTRIBUTION.md`), an
/// animation cycler when the scene carries clips, and a pinch-zoom
/// camera boom. The dice stay reachable here too — they keep their
/// physics-slab loader so a single die still rolls.
library;

import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart';

import 'showcase_loader.dart';

/// The showcase screen: a scene cycler over [showcaseItems], an
/// animation cycler when the scene has clips, and an orbit camera —
/// one-finger drag spins around the target, pinch zooms the boom.
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({
    super.key,
    this.nav,
    this.initialLabel,
    this.quality,
  });

  /// The app shell's screen switcher, overlaid at the top edge.
  final Widget? nav;

  /// Boots a specific item — the `DART3D_MODEL` lane.
  final String? initialLabel;

  /// The `DART3D_QUALITY` boot tier — null runs the widget defaults.
  final SceneQuality? quality;

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  final _controller = SceneController();

  /// The gallery roster — the upstream corpus. Dice live on their own
  /// tab; a single die reads huge next to the authored scenes.
  late final List<ShowcaseItem> _items = showcaseItems;
  late int _index = _initialIndex();
  ShowcaseScene? _scene;
  List<SceneAnimation> _anims = const [];
  int _animIndex = 0;

  /// The camera rig — [_dist] is the boom length along [_cameraDir]
  /// from [_cameraTarget].
  LocalId? _cameraNode;
  Vector3 _cameraTarget = Vector3.zero();
  Vector3 _cameraDir = Vector3(0, 0.3, -1);

  /// Orbit state — spherical angles decomposed from [_cameraDir] at
  /// load, driven by one-finger drags. [_pitch] is the camera's
  /// elevation above the target (0 = level, π/2 = straight down).
  double _yaw = 0;
  double _pitch = 0.3;
  double _dist = 0;
  double _distMin = 0;
  double _distMax = 0;

  /// The loaded item's fit radius — feeds the aspect-ratio widening
  /// in the layout pass.
  double _frameRadius = 0;
  double _distAtScaleStart = 0;
  bool _aspectFramed = false;
  String _status = 'loading…';

  int _initialIndex() {
    final label = widget.initialLabel;
    if (label == null) return 0;
    final i = _items.indexWhere((it) => it.label == label);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _load(_items[_index]);
  }

  void _load(ShowcaseItem item) {
    setState(() {
      _status = 'loading ${item.label}…';
      _anims = const [];
      _animIndex = 0;
      _aspectFramed = false;
      _cameraNode = null;
      _frameRadius = 0;
    });

    final scene = loadShowcaseScene(item, bytesFor: loadAssetBytes, log: dnLog);
    if (scene == null) {
      setState(() => _status = '${item.label}: load failed — see log');
      return;
    }
    _scene = scene;
    _controller.loadDocument(scene.document);
    _cameraNode = scene.cameraNode;
    _cameraTarget = scene.cameraTarget;
    _cameraDir = scene.cameraDir;
    _yaw = atan2(_cameraDir.x, _cameraDir.z);
    _pitch = asin(_cameraDir.y.clamp(-1.0, 1.0));
    // The authored boom distance; first layout may widen it for the
    // aspect ratio, and pinch zooms within [_distMin, _distMax].
    _dist = scene.frameRadius * 2.8;
    _distMin = scene.frameRadius * 0.8;
    _distMax = scene.frameRadius * 30;
    _frameRadius = scene.frameRadius;
    setState(() => _status = '${item.label} — ${item.note}');
    _installAnims();
  }

  /// Reads the loaded document's clip pool and autoplays the first
  /// (preferring 'Idle'). The list comes from the tracked document —
  /// available synchronously after `loadDocument` — and the `anim` op
  /// queues behind the manifest + payloads on the native side, so no
  /// settle delay is needed.
  void _installAnims() {
    final anims = _controller.animations.values.toList();
    if (anims.isEmpty) return;
    // Prefer 'Idle' when authored.
    final idle = anims.indexWhere(
      (a) => a.name.toLowerCase() == 'idle',
    );
    setState(() {
      _anims = anims;
      _animIndex = idle < 0 ? 0 : idle;
    });
    _controller.playAnimation(anims[_animIndex].id, loop: true);
  }

  void _stepScene(int dir) {
    _index = (_index + dir) % _items.length;
    if (_index < 0) _index += _items.length;
    _load(_items[_index]);
  }

  void _cycleAnim() {
    if (_anims.isEmpty) return;
    _controller.stopAnimation(_anims[_animIndex].id);
    _animIndex = (_animIndex + 1) % _anims.length;
    _controller.playAnimation(_anims[_animIndex].id, loop: true);
    setState(() {});
  }

  /// Rebuilds [_cameraDir] from the orbit angles and writes the boom
  /// pose — translation and look-at rotation together, since orbiting
  /// re-aims the camera. Rotation math mirrors the loader's authored
  /// pose (`+Z`-forward convention: `fwd = -dir`).
  void _writeCamera() {
    final node = _cameraNode;
    if (node == null || _dist <= 0) return;
    _cameraDir = Vector3(
      cos(_pitch) * sin(_yaw),
      sin(_pitch),
      cos(_pitch) * cos(_yaw),
    );
    final fwd = -_cameraDir;
    _controller.setNodeTransforms([
      NodeTransform(
        node,
        translation: _cameraTarget + _cameraDir * _dist,
        rotation: Quaternion.axisAngle(
              Vector3(0, 1, 0),
              atan2(fwd.x, fwd.z),
            ) *
            Quaternion.axisAngle(
              Vector3(1, 0, 0),
              -asin(fwd.y.clamp(-1.0, 1.0)),
            ),
      ),
    ]);
  }

  /// One-finger drag orbits the camera around the target — drag right
  /// swings the camera right, drag down lifts it toward top-down.
  /// Two-finger drags belong to the pinch zoom.
  void _orbit(DragUpdateDetails d) {
    if (d.pointerCount != 1 || _cameraNode == null) return;
    _yaw -= d.delta.dx * 0.008;
    _pitch = (_pitch + d.delta.dy * 0.008).clamp(0.05, 1.45);
    _writeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    return Scaffold(
      brightness: Brightness.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (!_aspectFramed && _frameRadius > 0) {
                  _aspectFramed = true;
                  // Widen the boom until the bounds diameter fits the
                  // horizontal half-angle (fovY·aspect narrows on
                  // portrait screens).
                  final aspect =
                      constraints.maxWidth / constraints.maxHeight;
                  final needed =
                      _frameRadius * 1.2 / (tan(0.8 / 2) * aspect);
                  if (needed > _dist) {
                    _dist = min(needed, _distMax);
                    _writeCamera();
                  }
                }
                return GestureDetector(
                  onPanUpdate: _orbit,
                  onScaleStart: (_) => _distAtScaleStart = _dist,
                  onScaleUpdate: (d) {
                    final next = (_distAtScaleStart / d.scale)
                        .clamp(_distMin, _distMax);
                    if ((next - _dist).abs() > _dist * 0.005) {
                      _dist = next;
                      _writeCamera();
                    }
                  },
                  child: SceneView(
                    controller: _controller,
                    quality: widget.quality,
                  ),
                );
              },
            ),
          ),
          if (widget.nav != null)
            Positioned(
              left: 0,
              right: 0,
              top: 56,
              child: widget.nav!,
            ),
          // One dock: prev/next circles flanking a translucent card
          // that carries the item name, its stats, and the clip chip.
          // Nothing outside the card reflows when clips appear or the
          // copy changes length.
          Positioned(
            left: 16,
            right: 16,
            bottom: 40,
            child: Row(
              children: [
                _dockButton(
                  CupertinoIcons.chevron_left,
                  () => _stepScene(-1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC101014),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _status.startsWith('loading') ||
                                  _status.contains('failed')
                              ? _status
                              : item.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xEEFFFFFF),
                          ),
                        ),
                        if (!_status.startsWith('loading') &&
                            !_status.contains('failed')) ...[
                          const SizedBox(height: 2),
                          Text(
                            _scene == null ? item.note : _scene!.summary,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0x99FFFFFF),
                            ),
                          ),
                        ],
                        if (_anims.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _cycleAnim,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x2EFFFFFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.play_fill,
                                    size: 11,
                                    color: Color(0xEEFFFFFF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_anims[_animIndex].name}'
                                    ' · ${_animIndex + 1}/${_anims.length}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xEEFFFFFF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _dockButton(
                  CupertinoIcons.chevron_right,
                  () => _stepScene(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The dock's prev/next circles — same translucent language as the
  /// dice table's floating controls.
  Widget _dockButton(IconData icon, VoidCallback onPressed) {
    return Button(
      onPressed: onPressed,
      shape: const CircleBorder(),
      color: const Color(0x66101014),
      foregroundColor: const Color(0xEEFFFFFF),
      padding: const EdgeInsets.all(14),
      child: Icon(icon, size: 20),
    );
  }
}
