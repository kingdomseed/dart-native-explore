/// The dice screen. The seven dice (six imported `.fsceneb` prefabs
/// expanded host-side through `package:scene`'s `composeScene`, plus
/// the procedural crystal-shard d4 — see `dice_table_scene.dart`) roll
/// in a tray fitted to the screen: a top-down camera, and invisible
/// walls at the edges of the visible area that follow every resize and
/// rotation (`dice_tray_layout.dart`).
///
/// Roll throws every die; Reset racks them back into a grid. Settle
/// events read each die's up face through its face map.
library;

import 'dart:async';
import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart';

import 'back_chevron.dart';
import 'dice_table_scene.dart';
import 'dice_tray_layout.dart';

/// Hidden `--dart-define=DART3D_DICE_THROW=<scale>` multiplier on the
/// throw speed — device testing of hard throws (walls must hold).
final double _throwScale =
    double.tryParse(const String.fromEnvironment('DART3D_DICE_THROW')) ?? 1.0;

/// Upstream's hard settle timeout: a roll is read after this even if
/// the natives never report every body asleep.
const _settleTimeout = Duration(seconds: 8);

/// Height of the top chrome pills (Back, Reset).
const double _pillHeight = 36;

/// The Roll pill's size (17 pt label, 44×14 padding).
const double _rollWidth = 132, _rollHeight = 48;

/// The dice screen.
class DiceTableScreen extends StatefulWidget {
  const DiceTableScreen({super.key, required this.onBack, this.quality});

  /// Returns to the hero — the top-left Back pill.
  final VoidCallback onBack;

  /// The `DART3D_QUALITY` boot tier — null runs the widget defaults.
  final SceneQuality? quality;

  @override
  State<DiceTableScreen> createState() => _DiceTableScreenState();
}

class _DiceTableScreenState extends State<DiceTableScreen> {
  final _controller = SceneController();
  final _rng = Random();
  final _spec = DiceTableSpec(throwScale: _throwScale);
  StreamSubscription<ScenePhysicsEvent>? _events;
  Timer? _settleTimer;

  /// Bumped by every roll and reset, so a pose read or settle event that
  /// belongs to an earlier throw (or to the rack drop) is never shown as
  /// this roll's result.
  int _rollId = 0;
  final _sinceRoll = Stopwatch();

  /// A real throw can't settle faster than this; a settle event inside the
  /// window was already in flight from native before the roll (the racked
  /// dice going to sleep) and is dropped.
  static const _minSettle = Duration(milliseconds: 250);

  DiceTableScene? _scene;
  final _values = <LocalId, int>{};

  /// The settled roll's total, and its per-die breakdown.
  int? _total;
  String _breakdown = '';

  /// The fitted tray, and the view geometry it was fitted to.
  late TrayLayout _layout;
  (double, double, double, double, double, double)? _fitKey;
  bool _racked = false;

  String _status = 'loading…';

  @override
  void initState() {
    super.initState();
    final scene = buildDiceTable(
      bytesFor: loadAssetBytes,
      log: dnLog,
      spec: _spec,
    );
    if (scene == null) {
      _status = 'Couldn’t build the table — see log';
      return;
    }
    _scene = scene;
    _layout = scene.layout;
    _controller.loadDocument(scene.document);
    _events = _controller.physicsEvents.listen(_onPhysicsEvent);
    _status = 'Roll throws the dice';
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _events?.cancel();
    super.dispose();
  }

  /// A settle ends a roll only while one is pending (its timeout is
  /// armed) — racking and refitting also wake and settle the dice, but
  /// they don't produce a result.
  void _onPhysicsEvent(ScenePhysicsEvent event) {
    if (event is SceneSettledEvent &&
        (_settleTimer?.isActive ?? false) &&
        _sinceRoll.elapsed >= _minSettle) {
      _read(event.poses, source: 'settled');
    }
  }

  /// Reads every die's up face from [poses] and shows the result.
  void _read(List<ScenePose> poses, {required String source}) {
    final scene = _scene;
    if (scene == null) return;
    _settleTimer?.cancel();
    _values.clear();
    final log = <String>[];
    for (final die in scene.dice) {
      if (die.faceMap.faces.isEmpty) continue;
      for (final pose in poses) {
        if (pose.node != die.node) continue;
        final (face, dot) = die.faceMap.top(pose.rotation);
        _values[die.node] = face.value;
        final p = pose.position;
        final flags = [
          if (dot < 0.9) 'cocked',
          if (!_layout.contains(p, slack: 1) || p.y < -1) 'OUTSIDE',
        ];
        log.add(
          '${die.label}=${face.value} (up ${dot.toStringAsFixed(3)} '
          'at ${p.x.toStringAsFixed(1)},${p.y.toStringAsFixed(1)},'
          '${p.z.toStringAsFixed(1)}${flags.isEmpty ? '' : ' ${flags.join(' ')}'})',
        );
      }
    }
    if (_values.isEmpty) return;
    dnLog('dart3d: dice $source — ${log.join(' ')}');
    final (breakdown, total) = _summary();
    dnLog('dart3d: dice readout $breakdown = $total');
    setState(() {
      _total = total;
      _breakdown = breakdown;
      _status = '';
    });
  }

  /// The per-die breakdown and total. The d10t/d10u pair reads as
  /// percentile (00 + 0 = 100).
  (String, int) _summary() {
    final parts = <String>[];
    var total = 0;
    int? tens, units;
    for (final die in _scene!.dice) {
      final v = _values[die.node];
      if (v == null) continue;
      switch (die.label) {
        case 'd10t':
          tens = v;
        case 'd10u':
          units = v;
        default:
          parts.add('${die.label} $v');
          total += v;
      }
    }
    if (tens != null || units != null) {
      final t = tens ?? 0, u = units ?? 0;
      final pct = t + u == 0 ? 100 : t + u;
      parts.add('d% ${t == 0 ? '00' : t}+$u');
      total += pct;
    }
    return (parts.join(' · '), total);
  }

  /// Throws [targets] from where they sit, with upstream's throw model
  /// (demo-program §3.2) in our units: one direction per roll, speed
  /// 14–20 u/s ±10% per die, a small sideways scatter, a hop, and spin
  /// that is mostly end-over-end along the throw (speed·0.7–1.4 rad/s)
  /// plus a random 6–22 rad/s tumble. Velocities are written directly,
  /// so magnitudes don't depend on each die's inertia.
  void _roll(Iterable<TableDie> targets) {
    final scene = _scene;
    if (scene == null) return;
    const u = kUpstreamUnit;
    final spin = _spec.spinScale;
    final theta = _rng.nextDouble() * pi * 2;
    final speed = (14 + _rng.nextDouble() * 6) * _spec.throwScale;
    for (final die in targets) {
      final ang = theta + (_rng.nextDouble() - 0.5) * 0.5;
      final dir = Vector3(cos(ang), 0, sin(ang));
      final side = Vector3(-sin(ang), 0, cos(ang));
      final s = speed * (0.9 + _rng.nextDouble() * 0.2);
      final lift =
          (7 + _rng.nextDouble() * 3) * (0.82 + _rng.nextDouble() * 0.36);
      final v =
          (dir * s +
              side * ((_rng.nextDouble() - 0.5) * 2.2) +
              Vector3(0, lift, 0)) *
          u;
      final tumble = Vector3(
        _rng.nextDouble() - 0.5,
        _rng.nextDouble() - 0.5,
        _rng.nextDouble() - 0.5,
      )..normalize();
      final w =
          side * (s * (0.7 + _rng.nextDouble() * 0.7)) +
          tumble * (6 + _rng.nextDouble() * 16);
      w.scale(spin);
      _controller.setBodyVelocity(
        die.node,
        linear: v,
        angularAxis: w.normalized(),
        angularRate: w.length,
      );
    }
    _rollId++;
    _sinceRoll
      ..reset()
      ..start();
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleTimeout, _settleFallback);
    setState(() {
      _values.clear();
      _total = null;
      _breakdown = '';
      _status = 'Rolling…';
    });
  }

  /// No settle event within upstream's 8 s: read the poses as they are.
  Future<void> _settleFallback() async {
    final id = _rollId;
    final poses = await _controller.poses();
    if (!mounted || id != _rollId) return;
    _read(poses, source: 'timeout');
  }

  /// Racks every die into a grid in the middle of the tray, face up,
  /// at rest, and clears the result.
  void _reset() {
    final scene = _scene;
    if (scene == null) return;
    _rollId++;
    _settleTimer?.cancel();
    final slots = _layout.rack(scene.dice.length, rackSpacingFor(scene.dice));
    final writes = <NodeTransform>[];
    for (final (i, die) in scene.dice.indexed) {
      final (x, z) = slots[i];
      _controller.setBodyVelocity(
        die.node,
        linear: Vector3.zero(),
        angularAxis: Vector3(0, 1, 0),
        angularRate: 0,
      );
      writes.add(
        NodeTransform(
          die.node,
          translation: Vector3(x, die.restY, z),
          rotation: die.restRotation,
        ),
      );
    }
    _controller.setNodeTransforms(writes);
    setState(() {
      _values.clear();
      _total = null;
      _breakdown = '';
      _status = 'Roll throws the dice';
    });
  }

  /// Refits the tray when the view's size or chrome insets change:
  /// moves the camera, walls and ceiling, and pulls any die the new
  /// walls would cut off back inside.
  void _fit(Size size, EdgeInsets insets) {
    final scene = _scene;
    if (scene == null || size.isEmpty) return;
    final key = (
      size.width,
      size.height,
      insets.left,
      insets.top,
      insets.right,
      insets.bottom,
    );
    if (key == _fitKey) return;
    _fitKey = key;
    _layout = TrayLayout.fit(
      width: size.width,
      height: size.height,
      pxPerUnit: trayPxPerUnit(size.shortestSide),
      insetLeft: insets.left,
      insetTop: insets.top,
      insetRight: insets.right,
      insetBottom: insets.bottom,
    );
    final cam = _layout.camera;
    _controller.setNodeTransforms([
      NodeTransform(
        scene.cameraNode,
        translation: cam.position,
        rotation: cam.rotation,
      ),
      for (final (i, wall) in _layout.walls.indexed)
        NodeTransform(
          scene.wallNodes[i],
          translation: wall.position,
          rotation: wall.rotation,
        ),
      NodeTransform(
        scene.ceilingNode,
        translation: _layout.ceiling.position,
        rotation: _layout.ceiling.rotation,
      ),
    ]);
    dnLog(
      'dart3d: dice tray fit ${size.width.toStringAsFixed(0)}x'
      '${size.height.toStringAsFixed(0)} insets $insets → '
      '${_layout.pxPerUnit.toStringAsFixed(2)} px/u, camera '
      '${_layout.cameraHeight.toStringAsFixed(0)}, play '
      'x ${_layout.play.xMin.toStringAsFixed(1)}..'
      '${_layout.play.xMax.toStringAsFixed(1)} z '
      '${_layout.play.zMin.toStringAsFixed(1)}..'
      '${_layout.play.zMax.toStringAsFixed(1)}',
    );
    if (!_racked) {
      // The document was built for a guessed screen; rack for this one.
      _racked = true;
      scheduleMicrotask(_reset);
    } else {
      unawaited(_pullInside());
    }
  }

  /// Moves any die outside the current play area to the nearest point
  /// inside it, keeping its orientation (and so its readout).
  Future<void> _pullInside() async {
    final scene = _scene;
    if (scene == null) return;
    final poses = await _controller.poses();
    final writes = <NodeTransform>[];
    for (final die in scene.dice) {
      for (final pose in poses) {
        if (pose.node != die.node) continue;
        final p = pose.position;
        if (_layout.contains(p, slack: -die.radius)) continue;
        writes.add(
          NodeTransform(
            die.node,
            translation: _layout.clampToPlay(p, die.radius),
          ),
        );
      }
    }
    if (writes.isNotEmpty) _controller.setNodeTransforms(writes);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final screen = MediaQuery.of(context).size;
    final landscape = screen.width >= screen.height;
    // DartNative quirk (A142, landscape): the side cutout inset arrives
    // in `padding.top` — the Back pill takes the larger, and so do the
    // tray's side walls (both sides, so the tray stays centred).
    final side = landscape
        ? max(max(padding.left, padding.right), padding.top)
        : max(padding.left, padding.right);
    // The chrome the walls keep dice out from under: the Back/Reset row
    // at the top; in portrait the readout line and Roll pill along the
    // bottom, in landscape the Roll pill at the right edge (mid-height)
    // and just the readout line at the bottom — a phone on its side has
    // little height to spare. 10 px of air keeps dice off the rounded
    // display corners.
    final trayInsets = landscape
        ? EdgeInsets.fromLTRB(
            side + 10,
            padding.top + 8 + _pillHeight + 12,
            side + 16 + _rollWidth + 12,
            padding.bottom + 8 + 18 + 8,
          )
        : EdgeInsets.fromLTRB(
            side + 10,
            padding.top + 8 + _pillHeight + 12,
            side + 10,
            padding.bottom + 20 + _rollHeight + 8 + 20 + 14,
          );
    final line = _status.isNotEmpty ? _status : _breakdown;
    return Scaffold(
      brightness: Brightness.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                // Mid-rotation the view can report the new width with the
                // old height; fit only once it matches the screen's shape.
                if ((size.width >= size.height) == landscape) {
                  _fit(size, trayInsets);
                }
                return SceneView(
                  controller: _controller,
                  allowsCameraControl: false,
                  showsStatistics: false,
                  quality: widget.quality,
                );
              },
            ),
          ),
          backChevron(context, widget.onBack),
          if (_total != null)
            Positioned(
              left: 0,
              right: 0,
              top: padding.top + 6,
              child: Center(
                child: Text(
                  '$_total',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xF2FFFFFF),
                  ),
                ),
              ),
            ),
          Positioned(
            top: padding.top + 8,
            right: 16 + side,
            child: Button(
              onPressed: _reset,
              title: 'Reset',
              shape: const StadiumBorder(),
              color: const Color(0x66101014),
              foregroundColor: const Color(0xEEFFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            ),
          ),
          if (line.isNotEmpty)
            Positioned(
              left: 16 + side,
              right: 16 + side,
              bottom: landscape
                  ? padding.bottom + 8
                  : padding.bottom + 20 + _rollHeight + 8,
              child: Center(
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ),
            ),
          Positioned(
            left: landscape ? null : 0,
            right: landscape ? 16 + side : 0,
            top: landscape ? 0 : null,
            bottom: landscape ? 0 : padding.bottom + 20,
            child: Center(
              child: Button(
                onPressed: () => _roll(_scene?.dice ?? const []),
                shape: const StadiumBorder(),
                color: const Color(0xE6FFFFFF),
                foregroundColor: const Color(0xFF101014),
                padding: const EdgeInsets.symmetric(
                  horizontal: 44,
                  vertical: 14,
                ),
                child: Text(
                  'Roll',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
