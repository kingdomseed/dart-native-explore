/// The dice-table screen — the user-facing demo. All seven dice load
/// as *prefab instances* of the upstream-importer `.fsceneb` artifacts
/// and expand host-side through `package:scene`'s `composeScene` (see
/// `dice_table_scene.dart`), so the natives receive one flat document.
///
/// Tap a die to select it; the ROLL button throws the selected dice,
/// or all of them when nothing is selected. Settle events read each
/// die's up-face through the bundled face map. Pinch zooms the camera
/// boom. No timers — nothing moves unless the user throws it.
library;

import 'dart:async';
import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart';

import 'dice_table_scene.dart';

/// The dice-table screen: a static top-down camera over the tray,
/// tap-to-select (screen tap → world ray → `raycast` → variant swap),
/// pinch zoom on the camera boom, and user-driven rolls. No timers —
/// nothing moves unless the user throws it.
class DiceTableScreen extends StatefulWidget {
  const DiceTableScreen({super.key, this.nav, this.quality});

  /// The app shell's screen switcher, overlaid at the top edge.
  final Widget? nav;

  /// The `DART3D_QUALITY` boot tier — null runs the widget defaults.
  final SceneQuality? quality;

  @override
  State<DiceTableScreen> createState() => _DiceTableScreenState();
}

class _DiceTableScreenState extends State<DiceTableScreen> {
  final _controller = SceneController();
  final _rng = Random();
  StreamSubscription<ScenePhysicsEvent>? _events;

  DiceTableScene? _scene;
  final _selected = <LocalId>{};
  final _values = <LocalId, int>{};
  final _resting = <LocalId>{};

  /// Live tuning state — [_spec] feeds `buildDiceTable`; structural
  /// fields rebuild the scene via `loadDocument`, `throwScale` applies
  /// to the next roll without one.
  DiceTableSpec _spec = const DiceTableSpec();
  bool _tuning = false;

  /// A structural slider moved but the document hasn't rebuilt yet —
  /// set by `onChanged`, applied by `onChangeEnd` or Done (some
  /// runtimes don't deliver drag-end, so Done is the sure path).
  bool _specDirty = false;

  /// The settled roll's total — shown big at bottom-center like the
  /// reference demo; null before the first settle.
  int? _total;

  /// Camera boom: [_fitDist] is recomputed per aspect (the tray's
  /// long axis must fit the frame); pinch zoom rides on top of it
  /// until the next aspect change resets it. [_elevation] is the
  /// camera pitch — live-tunable from the tune panel.
  double _dist = 310;
  double _fitDist = 310;
  double _distAtScaleStart = 310;
  bool _userZoomed = false;
  late double _elevation;
  late Quaternion _cameraRotation;
  late Vector3 _cameraDir;
  late Vector3 _cameraTarget;
  Offset _lastFocal = Offset.zero;
  int _gesturePointers = 0;

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
      _status = 'failed to build table — see log';
      return;
    }
    _scene = scene;
    _elevation = scene.cameraElevation;
    _cameraDir = scene.cameraDir;
    _cameraTarget = scene.cameraTarget.clone();
    _cameraRotation = Quaternion.axisAngle(Vector3(1, 0, 0), _elevation);
    _controller.loadDocument(scene.document);
    _events = _controller.physicsEvents.listen(_onPhysicsEvent);
    _status = 'tap dice to select · ROLL throws';
  }

  /// Rebuilds the document for a structural spec change — new node
  /// ids land, so selection and settle state reset alongside.
  void _rebuild() {
    final scene = buildDiceTable(
      bytesFor: loadAssetBytes,
      log: dnLog,
      spec: _spec,
    );
    if (scene == null) return;
    _controller.loadDocument(scene.document);
    setState(() {
      _scene = scene;
      _selected.clear();
      _values.clear();
      _resting.clear();
      _total = null;
      _userZoomed = false;
      _specDirty = false;
      _cameraTarget = scene.cameraTarget.clone();
      _status = 'rebuilt — tap dice to select';
    });
  }

  /// Applies a spec update — live for `throwScale`, a document rebuild
  /// when a structural field moved. Drag-end rebuilds when the runtime
  /// delivers it; Done catches whatever it missed.
  void _applySpec(DiceTableSpec next, {required bool rebuild}) {
    final needsRebuild = !_spec.structurallySame(next);
    setState(() {
      _spec = next;
      if (needsRebuild) _specDirty = true;
    });
    if (rebuild && needsRebuild) _rebuild();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _onPhysicsEvent(ScenePhysicsEvent event) {
    switch (event) {
      case SceneAwakeEvent():
        setState(() {
          _status = 'rolling…';
          _values.clear();
          _resting.clear();
        });
      case SceneSettledEvent(poses: final poses):
        var changed = false;
        for (final pose in poses) {
          for (final die in _scene?.dice ?? const <TableDie>[]) {
            if (pose.node != die.node || die.faceMap.faces.isEmpty) {
              continue;
            }
            _resting.add(die.node);
            _values[die.node] = die.faceMap.read(pose.rotation);
            changed = true;
          }
        }
        if (changed) {
          final (detail, total) = _rollSummary();
          dnLog('dart3d: $detail');
          setState(() {
            _total = total;
            _status = '';
          });
        }
    }
  }

  /// The settle readout: per-die detail for the log plus the big
  /// total. The d10t/d10u pair also reports as percentile
  /// (00+0 = 100).
  (String, int) _rollSummary() {
    if (_values.isEmpty) return ('settled', 0);
    final parts = <String>[];
    var total = 0;
    int? tens, units;
    for (final die in _scene!.dice) {
      final v = _values[die.node];
      if (v == null || _resting.contains(die.node) == false) continue;
      parts.add('${die.label}:$v');
      if (die.label == 'd10t') {
        tens = v;
      } else if (die.label == 'd10u') {
        units = v;
      } else {
        total += v;
      }
    }
    if (tens != null || units != null) {
      final pct = (tens ?? 0) + (units ?? 0);
      parts.add('d%:${pct == 0 ? 100 : pct}');
      total += pct == 0 ? 100 : pct;
    }
    return ('rolled ${parts.join(' ')}  ·  total $total', total);
  }

  /// Unprojects a tap into a world-space ray against the authored
  /// camera (fixed pitch, boom distance [_dist]).
  (Vector3, Vector3) _tapRay(Offset local, Size size) {
    final ndcX = (local.dx / size.width) * 2 - 1;
    final ndcY = 1 - (local.dy / size.height) * 2;
    final tanY = tan(_scene!.cameraFovY / 2);
    final aspect = size.width / size.height;
    final dir = _cameraRotation.rotated(
      Vector3(ndcX * tanY * aspect, ndcY * tanY, 1)..normalize(),
    );
    return (_cameraTarget + _cameraDir * _dist, dir);
  }

  /// Tap-to-select fires on `onTapUp` — a release without a drag —
  /// so a one-finger pan that starts on a die doesn't also select it.
  Future<void> _onTapUp(TapUpDetails details, Size size) async {
    final scene = _scene;
    if (scene == null) return;
    final (origin, dir) = _tapRay(details.localPosition, size);
    final hits = await _controller.raycast(
      origin: origin,
      direction: dir,
      maxDistance: 800,
      all: true,
    );
    // Nearest die hit toggles; taps on the tray/rails do nothing.
    for (final hit in hits) {
      TableDie? die;
      for (final d in scene.dice) {
        if (d.node == hit.node) die = d;
      }
      if (die == null) break; // tray or rail in front — stop looking
      setState(() {
        if (_selected.remove(die!.node)) {
          _controller.selectMaterialVariant(die.node, null);
        } else {
          _selected.add(die.node);
          _controller.selectMaterialVariant(die.node, kSelectedVariant);
        }
        _status = _selected.isEmpty
            ? ''
            : '${_selected.length} selected — ROLL throws them';
      });
      return;
    }
  }

  /// Throws [targets] from where they sit — the MythicGME2e launch
  /// model: a shared *sweep direction* per roll, with each die getting
  /// a mostly-horizontal velocity (~4×√(g·d) along the sweep plus a
  /// modest loft and lateral scatter) and an end-over-end tumble about
  /// the axis perpendicular to its travel. Dice travel across the
  /// tray, kick off the near-elastic rails, clatter into each other,
  /// and roll out on the felt — a flung handful, not popcorn.
  ///
  /// Velocities are written directly (like the reference's
  /// `setBodyLinearVelocity`/`setBodyAngularVelocity`), not applied as
  /// impulses — magnitude is exact instead of inertia-dependent.
  void _roll(Iterable<TableDie> targets) {
    final scene = _scene;
    if (scene == null) return;
    final s = _spec.throwScale;
    final spin = _spec.spinScale;
    // √(g·d) — the scale speed for dice this size under this gravity.
    final u = sqrt(_spec.gravity * scene.dieRadius * 2);
    // One sweep direction per roll — a handful travels together.
    final theta = _rng.nextDouble() * pi * 2;
    final baseSpeed = u * (4.2 + _rng.nextDouble() * 1.2) * s;
    for (final die in targets) {
      final ang = theta + (_rng.nextDouble() - 0.5) * 0.7;
      final dir = Vector3(cos(ang), 0, sin(ang));
      final perp = Vector3(-sin(ang), 0, cos(ang));
      final v =
          dir * (baseSpeed * (0.8 + _rng.nextDouble() * 0.4)) +
          perp * ((_rng.nextDouble() - 0.5) * u * 0.6 * s) +
          Vector3(0, u * (1.3 + _rng.nextDouble() * 0.6) * s, 0);
      // End-over-end tumble about the axis ⊥ to travel (~13 rad/s
      // like the reference), plus wobble and yaw.
      final tumble = (10.5 + _rng.nextDouble() * 5.0) * spin;
      final w =
          perp * (tumble * (_rng.nextBool() ? 1.0 : -1.0)) +
          Vector3(
            (_rng.nextDouble() - 0.5) * 2.4 * spin,
            (_rng.nextDouble() - 0.5) * 11.0 * spin,
            (_rng.nextDouble() - 0.5) * 2.4 * spin,
          );
      _controller.setBodyVelocity(
        die.node,
        linear: v,
        angularAxis: w.normalized(),
        angularRate: w.length,
      );
    }
    setState(() {
      _status = 'rolling…';
      _values.clear();
      _resting.clear();
      _total = null;
    });
  }

  /// Re-racks every die to its spawn slot — cleared selection and
  /// values, zeroed velocities.
  void _reset() {
    final scene = _scene;
    if (scene == null) return;
    final writes = <NodeTransform>[];
    for (final die in scene.dice) {
      final s = dieSpawnSlots[die.label]!;
      final slot = Vector3(s.$1, die.restY, s.$2);
      _controller.setBodyVelocity(
        die.node,
        linear: Vector3.zero(),
        angularAxis: Vector3(0, 1, 0),
        angularRate: 0,
      );
      writes.add(
        NodeTransform(die.node, translation: slot, rotation: Quaternion.identity()),
      );
    }
    _controller.setNodeTransforms(writes);
    setState(() {
      for (final die in scene.dice) {
        _controller.selectMaterialVariant(die.node, null);
      }
      _selected.clear();
      _values.clear();
      _resting.clear();
      _total = null;
      _status = '';
    });
  }

  /// One slider row: label + live value + the control. [structural]
  /// sliders rebuild the document on drag-end; the others (throwScale)
  /// apply to the next roll with no rebuild.
  Widget _tuneRow(
    String label,
    String value,
    double v,
    double min,
    double max,
    DiceTableSpec Function(double) update, {
    bool structural = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: Text('$label  $value'),
        ),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            onChanged: (x) => _applySpec(update(x), rebuild: false),
            onChangeEnd: structural
                ? (x) => _applySpec(update(x), rebuild: true)
                : null,
          ),
        ),
      ],
    );
  }

  /// The physics panel — throw and spin are live multipliers on the
  /// next roll; everything else rebuilds the document on drag-end.
  /// Knobs mirror the reference overlay's `dicePhysicsKnobs`.
  Widget _tunePanel() {
    final s = _spec;
    return Container(
      color: const Color(0xCC101014),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      constraints: const BoxConstraints(maxHeight: 340),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _tuneRow(
              'throw', '×${s.throwScale.toStringAsFixed(2)}',
              s.throwScale, 0.3, 2.5,
              (x) => s.copyWith(throwScale: x),
            ),
            _tuneRow(
              'spin', '×${s.spinScale.toStringAsFixed(2)}',
              s.spinScale, 0.3, 2.5,
              (x) => s.copyWith(spinScale: x),
            ),
            // Live camera pitch — a transform write, not a rebuild.
            Row(
              children: [
                SizedBox(
                  width: 116,
                  child: Text(
                    'camera  ${(_elevation * 180 / pi).toStringAsFixed(0)}°',
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _elevation.clamp(0.5, pi / 2),
                    min: 0.5,
                    max: pi / 2,
                    onChanged: (x) => setState(() => _setElevation(x)),
                  ),
                ),
              ],
            ),
            _tuneRow(
              'gravity', s.gravity.toStringAsFixed(0),
              s.gravity, 300, 9800,
              (x) => s.copyWith(gravity: x),
              structural: true,
            ),
            _tuneRow(
              'die bounce', s.dieRestitution.toStringAsFixed(2),
              s.dieRestitution, 0.15, 0.95,
              (x) => s.copyWith(
                dieRestitution: x,
                feltRestitution: x * 0.4,
              ),
              structural: true,
            ),
            _tuneRow(
              'wall bounce', s.wallRestitution.toStringAsFixed(2),
              s.wallRestitution, 0.4, 1.05,
              (x) => s.copyWith(wallRestitution: x),
              structural: true,
            ),
            _tuneRow(
              'die grip', s.dieFriction.toStringAsFixed(2),
              s.dieFriction, 0.0, 0.6,
              (x) => s.copyWith(dieFriction: x),
              structural: true,
            ),
            _tuneRow(
              'table grip', s.feltFriction.toStringAsFixed(2),
              s.feltFriction, 0.1, 1.5,
              (x) => s.copyWith(feltFriction: x),
              structural: true,
            ),
            _tuneRow(
              'slide fade', s.linearDamping.toStringAsFixed(2),
              s.linearDamping, 0.0, 0.6,
              (x) => s.copyWith(linearDamping: x),
              structural: true,
            ),
            _tuneRow(
              'spin fade', s.angularDamping.toStringAsFixed(2),
              s.angularDamping, 0.0, 0.6,
              (x) => s.copyWith(angularDamping: x),
              structural: true,
            ),
            _tuneRow(
              'tray W', '±${s.trayHalfX.toStringAsFixed(0)}',
              s.trayHalfX, 44, 120,
              (x) => s.copyWith(trayHalfX: x),
              structural: true,
            ),
            _tuneRow(
              'tray D', '±${s.trayHalfZ.toStringAsFixed(0)}',
              s.trayHalfZ, 80, 190,
              (x) => s.copyWith(trayHalfZ: x),
              structural: true,
            ),
            _tuneRow(
              'walls', s.railHeight.toStringAsFixed(0),
              s.railHeight, 60, 600,
              (x) => s.copyWith(railHeight: x),
              structural: true,
            ),
          ],
        ),
      ),
    );
  }

  void _writeCamera() {
    final scene = _scene;
    if (scene == null) return;
    _controller.setNodeTransforms([
      NodeTransform(
        scene.cameraNode,
        translation: _cameraTarget + _cameraDir * _dist,
        rotation: _cameraRotation,
      ),
    ]);
  }

  /// Live camera pitch — a transform write, no rebuild. The boom
  /// direction is (0, sin e, −cos e) and the node pitches about +X.
  void _setElevation(double e) {
    _elevation = e;
    _cameraDir = Vector3(0, sin(e), -cos(e));
    _cameraRotation = Quaternion.axisAngle(Vector3(1, 0, 0), e);
    _writeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                // Fit the tray to the surface aspect — the frame
                // extent (tray + rails + wall tops) on both axes,
                // whichever binds. Pinch zoom marks `_userZoomed`
                // until the aspect changes again.
                final tanY = tan(_scene!.cameraFovY / 2);
                final aspect = size.width / size.height;
                final frame = _scene!.frameExtent;
                final fit = max(
                  frame.x / (tanY * aspect),
                  frame.y / tanY,
                );
                if ((fit - _fitDist).abs() > 1) {
                  _fitDist = fit;
                  if (!_userZoomed) {
                    _dist = fit;
                    _writeCamera();
                  }
                }
                return GestureDetector(
                  onTapUp: (d) => _onTapUp(d, size),
                  onScaleStart: (d) {
                    _distAtScaleStart = _dist;
                    _lastFocal = d.focalPoint;
                    _gesturePointers = d.pointerCount;
                  },
                  onScaleUpdate: (d) {
                    var changed = false;
                    // One finger: pan the camera target across the
                    // table plane (screen-up on the ground is +Z under
                    // the camera's pure +X pitch). Guarded on the
                    // previous count too so a second finger landing
                    // doesn't jump the centroid.
                    if (d.pointerCount == 1 && _gesturePointers == 1) {
                      final worldPerPx =
                          2 * _dist * tan(_scene!.cameraFovY / 2) /
                              size.height;
                      final dd = d.focalPoint - _lastFocal;
                      if (dd.dx * dd.dx + dd.dy * dd.dy > 0.3) {
                        _cameraTarget.x = (_cameraTarget.x -
                                dd.dx * worldPerPx)
                            .clamp(-240.0, 240.0);
                        _cameraTarget.z = (_cameraTarget.z +
                                dd.dy * worldPerPx)
                            .clamp(-170.0, 170.0);
                        changed = true;
                      }
                    }
                    // Two+ fingers: pinch zooms the boom.
                    if (d.pointerCount >= 2) {
                      final next = (_distAtScaleStart / d.scale)
                          .clamp(_fitDist * 0.45, _fitDist * 2.4);
                      _userZoomed = true;
                      if ((next - _dist).abs() > 0.5) {
                        _dist = next;
                        changed = true;
                      }
                    }
                    _lastFocal = d.focalPoint;
                    _gesturePointers = d.pointerCount;
                    if (changed) _writeCamera();
                  },
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
          if (widget.nav != null)
            Positioned(
              left: 0,
              right: 0,
              top: 56,
              child: widget.nav!,
            ),
          // The reference demo's chrome: a labeled ROLL pill as the
          // primary action at bottom-center, the settle total above
          // it, re-rack and tune as floating circles in the corners.
          // Status stays only for hints/errors — small and dim.
          if (_status.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 104,
              child: Center(
                child: Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0x99FFFFFF),
                  ),
                ),
              ),
            ),
          // ↻ re-racks every die to its spawn slot.
          Positioned(
            top: 108,
            right: 20,
            child: _roundButton(CupertinoIcons.arrow_clockwise, _reset),
          ),
          Positioned(
            bottom: 44,
            left: 20,
            child: _roundButton(
              CupertinoIcons.gear,
              () {
                setState(() => _tuning = !_tuning);
                // The sure rebuild path — onChangeEnd isn't delivered
                // by every runtime, so closing the panel applies any
                // pending structural change.
                if (!_tuning && _specDirty) _rebuild();
              },
            ),
          ),
          if (_total != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 112,
              child: Center(
                child: Text(
                  '$_total',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    color: Color(0xEEFFFFFF),
                  ),
                ),
              ),
            ),
          // The primary action — labeled so it can't be missed. When
          // dice are selected it throws just those, and says so.
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: Button(
                onPressed: () => _roll(
                  _selected.isEmpty
                      ? _scene?.dice ?? const []
                      : _scene!.dice
                          .where((d) => _selected.contains(d.node)),
                ),
                shape: const StadiumBorder(),
                color: const Color(0xE6FFFFFF),
                foregroundColor: const Color(0xFF101014),
                padding: const EdgeInsets.symmetric(
                  horizontal: 44,
                  vertical: 14,
                ),
                child: Text(
                  _selected.isEmpty ? 'ROLL' : 'ROLL ${_selected.length}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (_tuning)
            Positioned(
              left: 0,
              right: 0,
              bottom: 104,
              child: _tunePanel(),
            ),
        ],
      ),
    );
  }

  /// A floating circular icon button — the reference demo's chrome
  /// shape (glyph on a translucent dark disc).
  Widget _roundButton(IconData icon, VoidCallback onPressed) {
    return Button(
      onPressed: onPressed,
      shape: const CircleBorder(),
      color: const Color(0x66101014),
      foregroundColor: const Color(0xEEFFFFFF),
      padding: const EdgeInsets.all(14),
      child: Icon(icon, size: 22),
    );
  }
}
