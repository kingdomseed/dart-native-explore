/// The dice screen. The seven dice (six imported `.fsceneb` prefabs
/// expanded host-side through `package:scene`'s `composeScene`, plus
/// the procedural crystal-shard d4 — see `dice_table_scene.dart`) roll
/// in a tray fitted to the screen: a top-down camera, and invisible
/// walls at the edges of the visible area that follow every resize and
/// rotation (`dice_tray_layout.dart`).
///
/// Throwing (`dice_throw.dart`): drag across the table to aim — the
/// dice fly in from off-screen behind the arrow; hold still to pick
/// them up, then fling to toss; a drag that starts on a die sweeps the
/// dice it passes. Roll throws along a random arrow; Reset racks them.
///
/// Settling (`dice_settle.dart`): a die left cocked against a wall or
/// another die gets a small physical nudge and the roll is read once
/// every die lies flat; the d4 then turns to read upright.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/canvas.dart' as ui;
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

import 'back_chevron.dart';
import 'dice_obsidian_tray.dart';
import 'dice_settle.dart';
import 'dice_shard_d4.dart';
import 'dice_table_scene.dart';
import 'dice_throw.dart';
import 'dice_tray_layout.dart';

/// Hidden `--dart-define=DART3D_DICE_THROW=<scale>` multiplier on the
/// throw speed — device testing of hard throws (walls must hold).
final double _throwScale =
    double.tryParse(const String.fromEnvironment('DART3D_DICE_THROW')) ?? 1.0;

/// Upstream's hard settle timeout: a roll is read after this even if
/// the natives never report every body asleep.
const _settleTimeout = Duration(seconds: 8);

/// After a cocked-die nudge, the roll is read after this at the latest.
const _nudgeTimeout = Duration(seconds: 4);

/// Nudges per die per roll before a cocked die is read as it lies.
const _maxNudges = 3;

/// An open entry gate closes once every die is inside; after this the
/// stragglers are tossed in, and after [_gateHardClose] it closes
/// regardless.
const double _gateKick = 2.5, _gateHardClose = 4.5;

/// How long the dice take to rise to the hover plane when picked up.
const double _liftTime = 0.2;

/// Height of the top chrome pills (Back, Reset).
const double _pillHeight = 36;

/// The Roll pill's size (17 pt label, 44×14 padding).
const double _rollWidth = 132, _rollHeight = 48;

/// The idle hint.
const _hint = 'Drag to throw · hold to pick up';

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

class _DiceTableScreenState extends State<DiceTableScreen>
    with SingleTickerProviderStateMixin {
  final _controller = SceneController();
  final _rng = Random();
  final _spec = DiceTableSpec(throwScale: _throwScale);
  final _clock = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_onTick);
  StreamSubscription<ScenePhysicsEvent>? _events;
  Timer? _settleTimer;

  /// Bumped by every roll and reset, so a pose read or settle event that
  /// belongs to an earlier throw (or to the rack drop) is never shown as
  /// this roll's result.
  int _rollId = 0;
  double _rollStart = 0;
  int _turnedRoll = -1;

  /// A real throw can't settle faster than this; a settle event inside the
  /// window was already in flight from native before the roll (the racked
  /// dice going to sleep) and is dropped.
  static const _minSettle = 0.25;

  DiceTableScene? _scene;
  final _values = <LocalId, int>{};

  /// The latest pose of every die, from settle events and per-frame
  /// reads while anything moves.
  final _poses = <LocalId, ScenePose>{};
  bool _poseInFlight = false;

  /// Cocked-die nudges given this roll, per die.
  final _nudges = <LocalId, int>{};

  /// Open entry gates: wall index → how far it's moved out.
  Map<int, double> _gates = const {};
  double _gateOpenedAt = 0;
  bool _gateKicked = false;

  /// The d4 turning to read upright, and until when at most.
  TableDie? _turning;
  double _turnUntil = 0;

  /// The settled roll's total, and its per-die breakdown.
  int? _total;
  String _breakdown = '';

  /// The fitted tray, and the view geometry it was fitted to.
  late TrayLayout _layout;
  Size _view = Size.zero;
  (double, double, double, double, double, double)? _fitKey;
  bool _racked = false;

  String _status = 'loading…';

  // Touch.
  final _arbiter = GestureArbiter();
  final _fling = FlingTracker();
  Offset _finger = Offset.zero;

  /// The aim arrow: tail, tip, and how far it has dissolved (0 = solid).
  Offset? _aimTail, _aimTip;
  double _aimFade = 0;
  double _aimFadeStart = 0;

  /// The dice held up (a long press): where each started, its slot in
  /// the cluster, its idle spin, and the cluster's centre.
  final _held =
      <
        ({
          TableDie die,
          Vector3 from,
          Quaternion rot,
          Vector3 slot,
          Vector3 spinAxis,
          double spinRate,
        })
      >[];
  double _holdStart = 0;
  double _hover = 0;
  Vector3 _holdCentre = Vector3.zero();
  double _lastTick = 0;

  /// Sweep bookkeeping: when each die was last shoved, and whether this
  /// sweep has started a roll.
  final _shovedAt = <LocalId, double>{};
  bool _sweepRolled = false;

  double get _now => _clock.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    unawaited(_build());
  }

  /// Builds the table off the UI isolate — the dice's atlases and meshes
  /// take about a second on a phone — then loads it.
  Future<void> _build() async {
    final logo = loadAssetBytes(kLogoAsset);
    final spec = _spec;
    final sw = Stopwatch()..start();
    var messages = <String>[];
    DiceTableScene? scene;
    try {
      (scene, messages) = await Isolate.run(() {
        final log = <String>[];
        final s = buildDiceTable(
          bytesFor: (key) => key == kLogoAsset ? logo : null,
          log: log.add,
          spec: spec,
        );
        return (s, log);
      });
    } catch (e) {
      dnLog('dart3d: dice table — background build failed ($e); inline');
      scene = buildDiceTable(bytesFor: loadAssetBytes, log: dnLog, spec: spec);
    }
    messages.forEach(dnLog);
    dnLog('dart3d: dice table ready after ${sw.elapsedMilliseconds} ms');
    if (!mounted) return;
    if (scene == null) {
      setState(() => _status = 'Couldn’t build the table — see log');
      return;
    }
    _scene = scene;
    _layout = scene.layout;
    final load = Stopwatch()..start();
    _controller.loadDocument(scene.document);
    dnLog(
      'dart3d: dice table handed to the view in '
      '${load.elapsedMilliseconds} ms',
    );
    _events = _controller.physicsEvents.listen(_onPhysicsEvent);
    setState(() => _status = _hint);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _settleTimer?.cancel();
    _events?.cancel();
    super.dispose();
  }

  bool get _rolling => _settleTimer?.isActive ?? false;

  // MARK: - Frame loop

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  /// Per frame while anything is live: the hold's lift and follow, pose
  /// reads (gates, sweep hits, the d4 turn), the arrow's dissolve.
  void _onTick(Duration _) {
    final t = _now;
    final dt = (t - _lastTick).clamp(0.0, 0.05);
    _lastTick = t;
    if (_arbiter.state == DiceGesture.pending &&
        _arbiter.tick(t) == DiceGesture.hold) {
      _beginHold(t);
    }
    if (_held.isNotEmpty) _updateHold(t, dt);
    final needPoses =
        _rolling ||
        _gates.isNotEmpty ||
        _turning != null ||
        _arbiter.state == DiceGesture.sweep;
    if (needPoses && !_poseInFlight) unawaited(_readPoses());
    if (_aimTail != null && _arbiter.state != DiceGesture.aim) {
      _aimFade = ((t - _aimFadeStart) / 0.28).clamp(0.0, 1.0);
      if (_aimFade >= 1) _aimTail = _aimTip = null;
      setState(() {});
    }
    final busy =
        needPoses ||
        _held.isNotEmpty ||
        _arbiter.state != null ||
        _aimTail != null;
    if (!busy) _ticker.stop();
  }

  Future<void> _readPoses() async {
    _poseInFlight = true;
    final id = _rollId;
    try {
      final List<ScenePose> poses;
      try {
        poses = await _controller.poses();
      } on StateError {
        return; // the view detached mid-roll (Back)
      }
      if (!mounted || id != _rollId) return;
      for (final p in poses) {
        _poses[p.node] = p;
      }
      if (_held.isEmpty) _levelLogos();
      if (_gates.isNotEmpty) _checkGates();
      if (_turning != null) _stepTurn();
    } finally {
      _poseInFlight = false;
    }
  }

  /// Holds every logo level, reading side up, whatever its die is doing
  /// — a gimbal: its local rotation is the die's inverse times its
  /// fixed world facing. [rotations] overrides the cached poses (dice we
  /// just placed ourselves).
  void _levelLogos([Map<LocalId, Quaternion>? rotations]) {
    final scene = _scene;
    if (scene == null) return;
    final writes = <NodeTransform>[];
    for (final die in scene.dice) {
      final logo = die.logo;
      final q = rotations?[die.node] ?? _poses[die.node]?.rotation;
      if (logo == null || q == null) continue;
      writes.add(NodeTransform(logo, rotation: die.logoLocalRotation(q)));
    }
    if (writes.isNotEmpty) _controller.setNodeTransforms(writes);
  }

  // MARK: - Touch

  /// The die under screen point [p] (the top-most by height), if any.
  TableDie? _dieAt(Offset p) {
    final scene = _scene;
    if (scene == null || _view.isEmpty) return null;
    TableDie? best;
    var bestY = -double.infinity;
    for (final die in scene.dice) {
      final pose = _poses[die.node];
      if (pose == null) continue;
      final (sx, sy) = _layout.project(
        pose.position,
        width: _view.width,
        height: _view.height,
      );
      final k = _layout.cameraHeight / (_layout.cameraHeight - pose.position.y);
      final r = die.radius * _layout.pxPerUnit * k * 1.2;
      final dx = sx - p.dx, dy = sy - p.dy;
      if (dx * dx + dy * dy < r * r && pose.position.y > bestY) {
        best = die;
        bestY = pose.position.y;
      }
    }
    return best;
  }

  void _down(Offset p) {
    final t = _now;
    _finger = p;
    _fling
      ..reset()
      ..add(t, _finger.dx, _finger.dy);
    _arbiter.down(t, _finger.dx, _finger.dy, onDie: _dieAt(_finger) != null);
    _sweepRolled = false;
    _wake();
  }

  void _move(Offset p) {
    final t = _now;
    if (_arbiter.state == null) _down(p);
    if (p == _finger) return;
    _finger = p;
    _fling.add(t, _finger.dx, _finger.dy);
    final before = _arbiter.state;
    final state = _arbiter.move(t, _finger.dx, _finger.dy);
    switch (state) {
      case DiceGesture.aim:
        final (x0, y0) = _arbiter.origin;
        setState(() {
          _aimTail = Offset(x0, y0);
          _aimTip = _finger;
          _aimFade = 0;
        });
      case DiceGesture.sweep:
        _sweep(t);
      case DiceGesture.hold:
        if (before == DiceGesture.pending) _beginHold(t);
      case DiceGesture.pending || null:
        break;
    }
  }

  /// The finger lifted. [fling] is the platform's release velocity
  /// (px/s), when it reports one.
  void _up({Offset? fling, bool cancelled = false}) {
    if (fling != null && _len(fling) > 0) _nativeFling = fling;
    _release(_now, cancelled: cancelled);
    _nativeFling = null;
  }

  Offset? _nativeFling;

  /// The release velocity (px/s): the platform's when it has one, else
  /// our own estimate from the recent moves.
  Vector2 _releaseVelocity(double t) {
    final n = _nativeFling;
    return n != null ? Vector2(n.dx, n.dy) : _fling.velocity(t);
  }

  void _release(double t, {required bool cancelled}) {
    switch (_arbiter.up()) {
      case DiceGesture.aim:
        final tail = _aimTail, tip = _aimTip;
        _aimFadeStart = t;
        if (!cancelled && tail != null && tip != null) {
          final d = tip - tail;
          final strength = aimStrength(_len(d));
          if (strength > 0) {
            _throw(Vector2(d.dx, -d.dy), strength, source: 'aim');
          }
        }
      case DiceGesture.hold:
        _toss(t);
      case DiceGesture.sweep || DiceGesture.pending || null:
        break;
    }
    _wake();
  }

  // MARK: - Throws

  /// Starts a roll: a fresh id, the settle timeout, cleared result.
  void _beginRoll({Duration timeout = _settleTimeout}) {
    _rollId++;
    _rollStart = _now;
    _nudges.clear();
    _stopTurn();
    _settleTimer?.cancel();
    _settleTimer = Timer(timeout, _settleFallback);
    _values.clear();
    setState(() {
      _total = null;
      _breakdown = '';
      _status = 'Rolling…';
    });
    _wake();
  }

  /// An aim throw (or Roll): the dice spawn off-screen behind the arrow
  /// and fly in along it through an opened gate.
  void _throw(Vector2 direction, double strength, {required String source}) {
    final scene = _scene;
    if (scene == null) return;
    _dropHeld();
    final plan = planThrow(
      layout: _layout,
      direction: direction,
      strength: (strength * _spec.throwScale).clamp(0.0, 1.0),
      radii: [for (final d in scene.dice) d.radius],
      gravity: _spec.gravity,
      rng: _rng,
      spinScales: [for (final d in scene.dice) _spinScale(d.label)],
      longAxes: [
        for (final d in scene.dice) d.label == 'd4' ? kShardAxis : null,
      ],
    );
    _beginRoll();
    _openGates(plan.gates);
    _controller.setNodeTransforms([
      for (final (i, die) in scene.dice.indexed)
        NodeTransform(
          die.node,
          translation: plan.dice[i].position,
          rotation: plan.dice[i].rotation,
        ),
    ]);
    _levelLogos({
      for (final (i, die) in scene.dice.indexed)
        die.node: plan.dice[i].rotation,
    });
    for (final (i, die) in scene.dice.indexed) {
      final l = plan.dice[i];
      _controller.setBodyVelocity(
        die.node,
        linear: l.linear * (_throwScale > 1 ? _throwScale : 1.0),
        angularAxis: l.angularAxis,
        angularRate: l.angularRate,
      );
    }
    dnLog(
      'dart3d: dice $source throw — strength ${strength.toStringAsFixed(2)} '
      'dir (${direction.x.toStringAsFixed(0)}, '
      '${direction.y.toStringAsFixed(0)}) gates ${plan.gates.keys.toList()}',
    );
  }

  /// Per-die spin retune: round dice roll on by themselves.
  double _spinScale(String label) => switch (label) {
    'd20' || 'd12' => 0.8,
    'd10t' || 'd10u' => 0.9,
    _ => 1.0,
  };

  /// The Roll pill: an aim throw along a random arrow.
  void _rollButton() {
    final a = _rng.nextDouble() * 2 * pi;
    _throw(
      Vector2(cos(a), sin(a)),
      0.55 + _rng.nextDouble() * 0.3,
      source: 'roll',
    );
  }

  // MARK: - Entry gates

  void _openGates(Map<int, double> gates) {
    final scene = _scene;
    if (scene == null) return;
    _closeGates(log: false);
    _gates = gates;
    _gateOpenedAt = _now;
    _gateKicked = false;
    _controller.setNodeTransforms([
      for (final MapEntry(key: i, value: by) in gates.entries)
        NodeTransform(
          scene.wallNodes[i],
          translation: _layout.wallOpened(i, by).position,
        ),
    ]);
  }

  void _closeGates({bool log = true}) {
    final scene = _scene;
    if (scene == null || _gates.isEmpty) return;
    _controller.setNodeTransforms([
      for (final i in _gates.keys)
        NodeTransform(
          scene.wallNodes[i],
          translation: _layout.walls[i].position,
          rotation: _layout.walls[i].rotation,
        ),
    ]);
    if (log) {
      dnLog(
        'dart3d: dice gates closed after '
        '${(_now - _gateOpenedAt).toStringAsFixed(2)} s',
      );
    }
    _gates = const {};
  }

  /// Closes the gates once every die is inside the tray; tosses any
  /// straggler back in after [_gateKick]; closes regardless after
  /// [_gateHardClose], pulling a die still outside back in.
  void _checkGates() {
    final scene = _scene;
    if (scene == null) return;
    final outside = [
      for (final die in scene.dice)
        if (_poses[die.node] case final p?
            when !_layout.holds(p.position, die.radius * 0.6))
          (die, p),
    ];
    final age = _now - _gateOpenedAt;
    if (outside.isEmpty) {
      _closeGates();
      return;
    }
    if (age > _gateHardClose) {
      _controller.setNodeTransforms([
        for (final (die, p) in outside)
          NodeTransform(
            die.node,
            translation: _layout.clampInside(p.position, die.radius * 1.5)
              ..y = max(p.position.y, die.radius + 2),
          ),
      ]);
      dnLog('dart3d: dice gate — pulled ${outside.length} stray dice in');
      _closeGates();
    } else if (age > _gateKick && !_gateKicked) {
      _gateKicked = true;
      for (final (die, p) in outside) {
        final toCentre = _layout.clampInside(Vector3.zero(), 30) - p.position
          ..y = 0;
        final v = toCentre.normalized() * (10 * kUpstreamUnit)
          ..y = 8 * kUpstreamUnit;
        _controller.setBodyVelocity(die.node, linear: v);
      }
      dnLog('dart3d: dice gate — tossed ${outside.length} short dice in');
    }
  }

  // MARK: - Pick up and toss

  void _beginHold(double t) {
    final scene = _scene;
    if (scene == null || _held.isNotEmpty) return;
    // Picking the dice up ends whatever they were doing.
    _rollId++;
    _settleTimer?.cancel();
    _stopTurn();
    _closeGates(log: false);
    final radii = [for (final d in scene.dice) d.radius];
    final slots = holdOffsets(radii);
    _hover = hoverHeight(_layout, radii.reduce(max));
    _holdCentre = _fingerWorld(_hover);
    _holdStart = t;
    for (final (i, die) in scene.dice.indexed) {
      final pose = _poses[die.node];
      final axis = Vector3(
        _rng.nextDouble() - 0.5,
        _rng.nextDouble() - 0.5,
        _rng.nextDouble() - 0.5,
      )..normalize();
      _held.add((
        die: die,
        from: pose?.position.clone() ?? Vector3(0, die.restY, 0),
        rot: pose?.rotation.clone() ?? die.restRotation.clone(),
        slot: slots[i],
        spinAxis: axis,
        spinRate: 1.2 + _rng.nextDouble() * 1.6,
      ));
    }
    setState(() {
      _values.clear();
      _total = null;
      _breakdown = '';
      _status = 'Fling to toss';
    });
    dnLog('dart3d: dice picked up (hover ${_hover.toStringAsFixed(0)})');
  }

  Vector3 _fingerWorld(double y) => _layout.unproject(
    _finger.dx,
    _finger.dy,
    width: _view.width,
    height: _view.height,
    y: y,
  );

  /// The held dice rise to the hover plane and ride under the finger,
  /// each turning slowly in the hand.
  void _updateHold(double t, double dt) {
    final reach = _held.fold(
      0.0,
      (m, h) => max(m, h.slot.length + h.die.radius),
    );
    final target = _layout.clampInside(_fingerWorld(_hover), reach + 2);
    // Follow quickly but not rigidly — the dice have weight.
    final follow = 1 - exp(-dt * 28);
    _holdCentre += (target - _holdCentre) * follow;
    final lift = Curves.easeOutCubic.transform(
      ((t - _holdStart) / _liftTime).clamp(0.0, 1.0),
    );
    final age = t - _holdStart;
    final v = _fling.velocity(t);
    final carry = _layout.screenVelocityToWorld(v.x, v.y, y: _hover);
    final writes = <NodeTransform>[];
    for (final (i, h) in _held.indexed) {
      final bob = sin(age * 3.1 + i * 1.7) * 0.8;
      final at = _holdCentre + h.slot + Vector3(0, bob, 0);
      final p = h.from + (at - h.from) * lift;
      final q = Quaternion.axisAngle(h.spinAxis, h.spinRate * age) * h.rot;
      writes.add(NodeTransform(h.die.node, translation: p, rotation: q));
      final logo = h.die.logo;
      if (logo != null) {
        writes.add(NodeTransform(logo, rotation: h.die.logoLocalRotation(q)));
      }
      _controller.setBodyVelocity(
        h.die.node,
        linear: carry * lift,
        angularAxis: h.spinAxis,
        angularRate: h.spinRate,
      );
    }
    _controller.setNodeTransforms(writes);
  }

  /// Release: every held die leaves with the finger's fling.
  void _toss(double t) {
    if (_held.isEmpty) return;
    final v = _releaseVelocity(t);
    final fling = _layout.screenVelocityToWorld(v.x, v.y, y: _hover);
    for (final h in _held) {
      final jitter = 0.92 + _rng.nextDouble() * 0.16;
      final l = tossLaunch(fling * jitter, h.die.radius, _rng);
      _controller.setBodyVelocity(
        h.die.node,
        linear: l.linear,
        angularAxis: l.axis,
        angularRate: l.rate,
      );
    }
    _held.clear();
    _beginRoll();
    dnLog(
      'dart3d: dice tossed — fling ${v.length.toStringAsFixed(0)} px/s '
      '(${_nativeFling != null ? 'platform' : 'tracked'}, '
      '${_fling.samples} moves, last '
      '${((t - _fling.lastTime) * 1000).toStringAsFixed(0)} ms before '
      'release) → ${(fling.length / kUpstreamUnit).toStringAsFixed(1)} u/s',
    );
  }

  /// A throw or reset while holding lets go without a toss.
  void _dropHeld() => _held.clear();

  // MARK: - Sweep

  /// Shoves every die the finger passes over, with its velocity.
  void _sweep(double t) {
    final scene = _scene;
    if (scene == null) return;
    final v = _fling.velocity(t + 1e-3);
    final finger = _fingerWorld(10);
    final fingerV = _layout.screenVelocityToWorld(v.x, v.y, y: 10);
    var hit = false;
    for (final die in scene.dice) {
      final pose = _poses[die.node];
      if (pose == null ||
          !sweepHits(finger, pose.position, die.radius) ||
          t - (_shovedAt[die.node] ?? -1) < 0.15) {
        continue;
      }
      _shovedAt[die.node] = t;
      final s = sweepShove(fingerV, die.radius, _rng);
      _controller.setBodyVelocity(
        die.node,
        linear: s.linear,
        angularAxis: s.axis,
        angularRate: s.rate,
      );
      hit = true;
    }
    if (!hit) return;
    if (!_sweepRolled) {
      _sweepRolled = true;
      _beginRoll();
      dnLog('dart3d: dice sweep');
    } else if (!_rolling) {
      // The dice settled mid-sweep and were read; this hit is a new roll.
      _beginRoll();
    } else {
      // Keep the roll open while the sweep goes on.
      _rollStart = t;
      _settleTimer?.cancel();
      _settleTimer = Timer(_settleTimeout, _settleFallback);
    }
  }

  // MARK: - Settling

  /// A settle ends a roll only while one is pending (its timeout is
  /// armed) — racking and refitting also wake and settle the dice, but
  /// they don't produce a result.
  void _onPhysicsEvent(ScenePhysicsEvent event) {
    if (event is! SceneSettledEvent) return;
    for (final p in event.poses) {
      _poses[p.node] = p;
    }
    if (_held.isEmpty) _levelLogos();
    if (!_rolling || _now - _rollStart < _minSettle || _held.isNotEmpty) {
      return;
    }
    if (_gates.isNotEmpty) {
      // A die still outside: the gate check tosses it in, and the roll
      // is read at the next settle.
      _checkGates();
      if (_gates.isNotEmpty) return;
    }
    if (_nudgeCocked(event.poses)) return;
    _read(event.poses, source: 'settled');
  }

  /// Nudges every cocked die (up to [_maxNudges] each) and returns
  /// whether any was — the roll is read at the next settle.
  bool _nudgeCocked(List<ScenePose> poses) {
    final scene = _scene;
    if (scene == null) return false;
    final byNode = {for (final p in poses) p.node: p};
    var any = false;
    for (final die in scene.dice) {
      final pose = byNode[die.node];
      if (pose == null || !isCocked(die.faceMap, pose.rotation)) continue;
      final n = _nudges[die.node] ?? 0;
      if (n >= _maxNudges) continue;
      _nudges[die.node] = n + 1;
      final kick = cockedNudge(
        position: pose.position,
        rotation: pose.rotation,
        faceMap: die.faceMap,
        radius: die.radius,
        gravity: _spec.gravity,
        layout: _layout,
        neighbours: [
          for (final other in scene.dice)
            if (other != die && byNode[other.node] != null)
              (byNode[other.node]!.position, other.radius),
        ],
        attempt: n,
        rng: _rng,
      );
      _controller.setBodyVelocity(
        die.node,
        linear: kick.linear,
        angularAxis: kick.axis,
        angularRate: kick.rate,
      );
      dnLog(
        'dart3d: dice cocked ${die.label} (up '
        '${die.faceMap.top(pose.rotation).$2.toStringAsFixed(3)}) → nudge '
        '#${n + 1}',
      );
      any = true;
    }
    if (any) {
      _rollStart = _now;
      _settleTimer?.cancel();
      _settleTimer = Timer(_nudgeTimeout, _settleFallback);
      _wake();
    }
    return any;
  }

  /// Reads every die's up face from [poses] and shows the result.
  void _read(List<ScenePose> poses, {required String source}) {
    final scene = _scene;
    if (scene == null) return;
    _settleTimer?.cancel();
    _closeGates(log: false);
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
          if (dot < flatDotFor(die.faceMap)) 'cocked',
          if (!_layout.contains(p, slack: 1) || p.y < -1) 'OUTSIDE',
        ];
        log.add(
          '${die.label}=${face.value} (up ${dot.toStringAsFixed(3)} '
          'at ${p.x.toStringAsFixed(1)},${p.y.toStringAsFixed(1)},'
          '${p.z.toStringAsFixed(1)}${flags.isEmpty ? '' : ' ${flags.join(' ')}'})',
        );
        if (die.label == 'd4' &&
            source == 'settled' &&
            dot >= flatDotFor(die.faceMap)) {
          _startTurn(die, pose, face.normal);
        }
      }
    }
    if (_values.isEmpty) return;
    final nudged = _nudges.values.fold(0, (a, b) => a + b);
    dnLog(
      'dart3d: dice $source — ${log.join(' ')}'
      '${nudged > 0 ? ' [$nudged nudge${nudged == 1 ? '' : 's'}]' : ''}',
    );
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

  /// No settle event within the timeout: read the poses as they are.
  Future<void> _settleFallback() async {
    final id = _rollId;
    final List<ScenePose> poses;
    try {
      poses = await _controller.poses();
    } on StateError {
      return; // the view detached
    }
    if (!mounted || id != _rollId) return;
    _read(poses, source: 'timeout');
  }

  // MARK: - The d4 turns to read upright

  void _startTurn(TableDie die, ScenePose pose, Vector3 faceNormal) {
    // One turn per roll: the re-read after it must not start another.
    if (_turnedRoll == _rollId) return;
    final yaw = shardUprightYaw(pose.rotation, faceNormal);
    if (yaw.abs() < 2 * kUprightTolerance) return;
    _turnedRoll = _rollId;
    _turning = die;
    _turnUntil = _now + 1.8;
    dnLog(
      'dart3d: dice d4 turns ${(-yaw * 180 / pi).toStringAsFixed(0)}° '
      'to read upright',
    );
    _wake();
  }

  /// One servo step from the latest pose: spin about +Y toward upright.
  void _stepTurn() {
    final die = _turning;
    if (die == null) return;
    final pose = _poses[die.node];
    if (pose == null) return;
    final (face, _) = die.faceMap.top(pose.rotation);
    final rate = uprightTurnRate(shardUprightYaw(pose.rotation, face.normal));
    if (rate == 0 || _now > _turnUntil) {
      _stopTurn();
      // The turn can nudge a neighbour or the d4 itself onto another
      // face: read every die again at the next settle.
      _rollStart = _now;
      _settleTimer?.cancel();
      _settleTimer = Timer(_nudgeTimeout, _settleFallback);
      _wake();
      return;
    }
    _controller.setBodyVelocity(
      die.node,
      angularAxis: Vector3(0, 1, 0),
      angularRate: rate,
    );
  }

  void _stopTurn() {
    final die = _turning;
    if (die == null) return;
    _turning = null;
    _controller.setBodyVelocity(
      die.node,
      angularAxis: Vector3(0, 1, 0),
      angularRate: 0,
    );
  }

  // MARK: - Rack and fit

  /// Racks every die into a grid in the middle of the tray, face up,
  /// at rest, and clears the result.
  void _reset() {
    final scene = _scene;
    if (scene == null) return;
    _rollId++;
    _settleTimer?.cancel();
    _dropHeld();
    _stopTurn();
    _closeGates(log: false);
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
      final at = Vector3(x, die.restY, z);
      writes.add(
        NodeTransform(die.node, translation: at, rotation: die.restRotation),
      );
      _poses[die.node] = ScenePose(die.node, at, die.restRotation);
    }
    _controller.setNodeTransforms(writes);
    _levelLogos();
    setState(() {
      _values.clear();
      _total = null;
      _breakdown = '';
      _status = _hint;
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
    _view = size;
    final ppu = trayPxPerUnit(size.shortestSide);
    final rim = kRimReach * ppu;
    _layout = TrayLayout.fit(
      width: size.width,
      height: size.height,
      pxPerUnit: ppu,
      insetLeft: insets.left + rim,
      insetTop: insets.top + rim,
      insetRight: insets.right + rim,
      insetBottom: insets.bottom + rim,
    );
    final cam = _layout.camera;
    _gates = const {};
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
      for (final (i, rim) in rimPoses(_layout).indexed)
        NodeTransform(
          scene.rimNodes[i],
          translation: rim.translation,
          scale: rim.scale,
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
  /// inside it. A moved die can land against a neighbour and tumble to
  /// another face, so a result on screen is read again at the next
  /// settle.
  Future<void> _pullInside() async {
    final scene = _scene;
    if (scene == null) return;
    final id = _rollId;
    final List<ScenePose> poses;
    try {
      poses = await _controller.poses();
    } on StateError {
      return; // the view detached
    }
    if (!mounted) return;
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
    if (writes.isEmpty) return;
    _controller.setNodeTransforms(writes);
    if (id != _rollId || _total == null) return;
    dnLog('dart3d: dice refit moved ${writes.length} — reading again');
    _rollStart = _now;
    _settleTimer?.cancel();
    _settleTimer = Timer(_nudgeTimeout, _settleFallback);
    _wake();
  }

  // MARK: - Build

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
    final tail = _aimTail, tip = _aimTip;
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
                // Touch on the scene view itself (the chrome above keeps
                // its own taps). DartNative's iOS scale recognizer claims
                // one-finger drags (showcase_scene.dart, #27), so a
                // one-finger scale stream feeds the same moves.
                return GestureDetector(
                  onTapDown: (d) => _down(d.localPosition),
                  // A press held still (the pick-up) ends in a tap-up;
                  // a drag in a pan end, with the release velocity.
                  onTapUp: (_) => _up(),
                  onPanStart: (d) => _move(d.localPosition),
                  onPanUpdate: (d) {
                    if (d.pointerCount == 1) _move(d.localPosition);
                  },
                  onPanEnd: (d) => _up(fling: d.velocity.pixelsPerSecond),
                  onScaleUpdate: (d) {
                    if (d.pointerCount == 1) _move(d.focalPoint);
                  },
                  onScaleEnd: (_) => _up(),
                  child: SceneView(
                    controller: _controller,
                    allowsCameraControl: false,
                    showsStatistics: false,
                    quality: widget.quality,
                  ),
                );
              },
            ),
          ),
          if (tail != null && tip != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: AimArrowPainter(
                    tail: tail,
                    tip: tip,
                    fade: _aimFade,
                  ),
                ),
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
                onPressed: _rollButton,
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

/// The aim arrow: a tapered shaft from where the drag began to the
/// finger, widening and warming (cyan → lime → amber → pink, the logo's
/// gradient) as the pull strengthens toward [kFullPull]; on release it
/// dissolves toward its tip ([fade] 0 → 1).
class AimArrowPainter extends CustomPainter {
  const AimArrowPainter({
    required this.tail,
    required this.tip,
    required this.fade,
  });

  final Offset tail, tip;
  final double fade;

  static const _ramp = [
    Color(0xFF03C3F0),
    Color(0xFFA1EA5A),
    Color(0xFFFFB23D),
    Color(0xFFF0508C),
  ];

  static Color _rampAt(double s) {
    final x = s.clamp(0.0, 1.0) * (_ramp.length - 1);
    final i = min(x.floor(), _ramp.length - 2);
    return Color.lerp(_ramp[i], _ramp[i + 1], x - i)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final d = tip - tail;
    final len = _len(d);
    if (len < 4) return;
    final s = aimStrength(len);
    final armed = len >= kMinPull;
    final alpha = (armed ? 0.92 : 0.35) * (1 - fade);
    if (alpha <= 0.01) return;
    final ux = d.dx / len, uy = d.dy / len;
    final nx = -uy, ny = ux;
    // Dissolve: the tail catches up with the tip.
    final start = tail + d * Curves.easeInCubic.transform(fade);
    final head = min(14 + 14 * s, len * 0.45);
    final w0 = 1.5 + 2 * s, w1 = 3 + 5 * s;
    final neck = tip - Offset(ux, uy) * head;
    final colour = _rampAt(s);
    final shaft = Path()
      ..moveTo(start.dx + nx * w0, start.dy + ny * w0)
      ..lineTo(neck.dx + nx * w1, neck.dy + ny * w1)
      ..lineTo(neck.dx - nx * w1, neck.dy - ny * w1)
      ..lineTo(start.dx - nx * w0, start.dy - ny * w0)
      ..close();
    canvas.drawPath(
      shaft,
      Paint()
        ..shader = ui.Gradient.linear(start, neck, [
          colour.withOpacity(alpha * 0.15),
          colour.withOpacity(alpha),
        ]),
    );
    final hw = head * 0.62;
    final arrowHead = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(neck.dx + nx * hw, neck.dy + ny * hw)
      ..lineTo(neck.dx - nx * hw, neck.dy - ny * hw)
      ..close();
    canvas.drawPath(arrowHead, Paint()..color = colour.withOpacity(alpha));
    // Where the pull started.
    canvas.drawCircle(
      tail,
      6 + 4 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colour.withOpacity(alpha * 0.6 * (1 - fade)),
    );
  }

  @override
  bool shouldRepaint(AimArrowPainter old) =>
      old.tail != tail || old.tip != tip || old.fade != fade;
}

/// An offset's length — computed here rather than via `Offset.distance`
/// (it read a 228 px pull as a full 420 px one on the A142).
double _len(Offset o) => sqrt(o.dx * o.dx + o.dy * o.dy);
