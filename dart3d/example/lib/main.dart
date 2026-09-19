import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart';

import 'dartnative_plugin_registrant.dart';
import 'dice_table.dart';
import 'feature_scene.dart';
import 'imported_scene.dart';
import 'showcase_scene.dart';

void main() {
  DartNativePluginRegistrant.registerAll();
  _applyBackendDefine();
  runApp(const Dart3dExampleApp());
}

/// `--dart-define=DART3D_BACKEND=auto|opengl|vulkan` picks the Filament
/// backend on Android. `opengl` (or `gl`) forces the GL fallback,
/// `vulkan` forces Vulkan, anything else leaves the library's auto
/// default. Forwarded to the JNI shim before any SceneView exists; the
/// engine reads it once at construction, so a live run ignores a later
/// flip.
void _applyBackendDefine() {
  if (!Platform.isAndroid) return;
  final pref = switch (const String.fromEnvironment('DART3D_BACKEND')) {
    'opengl' || 'gl' => 1,
    'vulkan' => 2,
    _ => 0,
  };
  DynamicLibrary.open('libdart3d_jni.so')
      .lookupFunction<Void Function(Int32), void Function(int)>(
        'Dart3dSetBackend',
      )(pref);
}

/// The example app's shell — three screens switched by a segmented
/// control:
///
/// - **Dice** — the user-facing table: seven upstream-imported dice on
///   a felt tray, tap to select, Roll throws the selection (or all).
/// - **Showcase** — the broader `flutter_scene` corpus (dash, fcar,
///   the Flutter logo, skinning/animation/texture coverage) plus the
///   single-die physics lane.
/// - **Harness** — the deterministic verification scene whose timed
///   phases exercise the feature matrix (W0–W14, wloose).
///
/// Boot overrides: `--dart-define=DART3D_SCENE=dice|showcase|harness`
/// picks the screen; `--dart-define=DART3D_MODEL=<label>` boots the
/// showcase with that item selected (the old single-model lane);
/// `--dart-define=DART3D_QUALITY=low|medium|high` pins the view tier.
/// `--dart-define=DART3D_BACKEND=auto|opengl|vulkan` picks the Filament
/// backend (Android only); `--dart-define=DART3D_STATS=1` turns the
/// showcase view's stats HUD on (and its ~4 Hz `stats:` logcat line).
class Dart3dExampleApp extends StatefulWidget {
  const Dart3dExampleApp({super.key});

  static const _bootScene = String.fromEnvironment(
    'DART3D_SCENE',
    defaultValue: 'dice',
  );
  static const _bootModel = String.fromEnvironment('DART3D_MODEL');
  static const _bootQuality = String.fromEnvironment('DART3D_QUALITY');

  /// The boot tier — null leaves each view at its own defaults.
  static SceneQuality? get bootQuality => switch (_bootQuality) {
    'low' => SceneQuality.low,
    'medium' => SceneQuality.medium,
    'high' => SceneQuality.high,
    _ => null,
  };

  @override
  State<Dart3dExampleApp> createState() => _Dart3dExampleAppState();
}

class _Dart3dExampleAppState extends State<Dart3dExampleApp> {
  late int _screen = _bootIndex();

  int _bootIndex() {
    if (Dart3dExampleApp._bootModel.isNotEmpty) return 1;
    return switch (Dart3dExampleApp._bootScene) {
      'harness' => 2,
      'showcase' || 'gallery' => 1,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final nav = Center(
      child: SegmentedControl(
        segments: const ['Dice', 'Showcase', 'Harness'],
        selectedIndex: _screen,
        onValueChanged: (i) => setState(() => _screen = i),
      ),
    );
    return switch (_screen) {
      1 => ShowcaseScreen(
        nav: nav,
        initialLabel: Dart3dExampleApp._bootModel.isEmpty
            ? null
            : Dart3dExampleApp._bootModel,
        quality: Dart3dExampleApp.bootQuality,
      ),
      2 => FeatureMatrixScreen(
        nav: nav,
        quality: Dart3dExampleApp.bootQuality,
      ),
      _ => DiceTableScreen(
        nav: nav,
        quality: Dart3dExampleApp.bootQuality,
      ),
    };
  }
}

/// The W0 verification scene — a physically simulated die and ball on
/// a lit slab, surrounded by one node per harness feature (nested rig,
/// hidden torus, textured box, payload tetra). "Roll" throws the die;
/// the native side reports the settle, and the app reads the up-face
/// plus the ball's rest position from the poses. Toggles exercise the
/// view-config and camera manifest fields.
class FeatureMatrixScreen extends StatefulWidget {
  const FeatureMatrixScreen({super.key, this.nav, this.quality});

  /// The app shell's screen switcher, overlaid at the top edge.
  final Widget? nav;

  /// The `DART3D_QUALITY` boot tier — null runs the widget defaults.
  final SceneQuality? quality;

  @override
  State<FeatureMatrixScreen> createState() => _FeatureMatrixScreenState();
}

class _FeatureMatrixScreenState extends State<FeatureMatrixScreen> {
  final _controller = SceneController();
  final _rng = Random();
  StreamSubscription<ScenePhysicsEvent>? _events;
  StreamSubscription<SceneCollisionEvent>? _contacts;
  StreamSubscription<SceneJointBroke>? _joints;
  Timer? _reroll;
  Timer? _watchdog;
  Timer? _queryBattery;
  Timer? _jointTimer;
  int Function()? _jointRig;
  void Function(void Function(int playing) report)? _w11Phase;
  void Function()? _w12Phase;
  void Function()? _w13Phase;
  void Function()? _w14Phase;
  void Function()? _wLoosePhase;
  Timer? _w11Timer;
  Timer? _w12Timer;
  Timer? _w13Timer;
  Timer? _w14Timer;
  Timer? _wLooseTimer;
  int _animsPlaying = 0;
  LocalId? _die;
  LocalId? _ball;
  LocalId? _hidden;
  bool _ortho = false;
  bool _stats = true;
  bool _cameraControl = true;
  // The W7 environment lane — starts on studio, the baseline look.
  int _env = 1;
  static const _envNames = ['none', 'studio', 'constant', 'equirect', 'empty'];
  // The upstream-interchange lane: -1 is the harness scene, 0+ indexes
  // importedDice (the .fsceneb dice set). [_dieCenter]/[_dieRadius]
  // scale the throw in imported mode — the models are ~19 units.
  int _model = -1;
  Vector3 _dieCenter = Vector3.zero();
  double _dieRadius = 1.0;
  String _status = 'dropping…';
  int? _result;
  Vector3? _ballPos;
  int _contactCount = 0;
  int _jointCount = 0;
  int _jointsBroke = 0;
  String _queryStatus = '';

  /// d6 face values on the cuboid's local axes — opposite faces sum to 7.
  static const _faces = {'+y': 1, '-y': 6, '+x': 2, '-x': 5, '+z': 3, '-z': 4};

  @override
  void initState() {
    super.initState();
    // Safe to call before the view attaches — the controller queues it
    // and flushes on mount. The DART3D_MODEL boot lives on the showcase
    // screen now; the harness always starts on its own scene.
    _loadScene();
    _events = _controller.physicsEvents.listen(_onPhysicsEvent);
    _contacts = _controller.contactEvents.listen(_onContactEvent);
    _joints = _controller.jointEvents.listen(_onJointEvent);
  }

  /// Rebuilds the document and loads it — a full replace, so ids are
  /// re-minted and bodies reset to their spawn poses.
  void _loadScene() {
    final scene = FeatureScene.build(
      ortho: _ortho,
      env: _env,
      controller: _controller,
    );
    _die = scene.die;
    _ball = scene.ball;
    _hidden = scene.hidden;
    _jointRig = scene.jointRig;
    _jointCount = 0;
    _w11Phase = scene.w11Phase;
    _w12Phase = scene.w12Phase;
    _w13Phase = scene.w13Phase;
    _w14Phase = scene.w14Phase;
    _wLoosePhase = scene.wLoosePhase;
    _animsPlaying = 0;
    // The W11 lane lands at +14 s — after the joint rig — so its
    // skinned flag and morph blob don't contend with the +8 s diff
    // or the +10 s query battery.
    _w11Timer?.cancel();
    _w11Timer = Timer(const Duration(seconds: 14), _runW11);
    // W12's component-parity lane lands at +22 s — after W11's
    // +18 s seek/weight-write and its reference-trace window.
    _w12Timer?.cancel();
    _w12Timer = Timer(const Duration(seconds: 22), _runW12);
    // W13's environment-effects lane lands at +34 s — after W12's
    // last inner timer (+22 s + 11 s pose evidence).
    _w13Timer?.cancel();
    _w13Timer = Timer(const Duration(seconds: 34), _runW13);
    // W14's render-texture/views lane lands at +50 s — after W13's
    // last inner timer (+34 s + 14 s overridesEffects flip).
    _w14Timer?.cancel();
    _w14Timer = Timer(const Duration(seconds: 50), _runW14);
    // The loose-ends evidence lane lands at +78 s — after W14's last
    // inner timer (+50 s + 12 s showcase), leaving its probe drops,
    // pose reads, and three timed rolls clear of the render-texture
    // churn.
    _wLooseTimer?.cancel();
    _wLooseTimer = Timer(const Duration(seconds: 78), _runWLoose);
    _jointsBroke = 0;
    _controller.loadDocument(scene.document);
    // W8: the query battery fires at +10 s — after the +8 s diff — and
    // aims at this generation's die, so re-arm on every reload (a
    // reload re-mints the ids it queries).
    _queryBattery?.cancel();
    _queryBattery = Timer(const Duration(seconds: 10), _runQueryBattery);
    // W9: the joint rig lands at +12 s — its bodies and joints all
    // ride command ops, so a reload needs a fresh rig on fresh ids.
    _jointTimer?.cancel();
    _jointTimer = Timer(const Duration(seconds: 12), _runJointRig);
  }

  void _onContactEvent(SceneCollisionEvent event) {
    setState(() => _contactCount++);
    // Wire-kind names for log correlation with the native emitters.
    final kind = switch (event) {
      SceneCollisionBegan() => 'began',
      SceneCollisionEnded() => 'ended',
      SceneTriggerEntered() => 'triggerEntered',
      SceneTriggerExited() => 'triggerExited',
    };
    dnLog(
      'dart3d: contact $kind a=${event.nodeA.index} b=${event.nodeB.index}'
      '${event is SceneCollisionBegan ? ' pts=${event.contacts.length}' : ''}',
    );
  }

  /// The W8 query battery — one shot of poseOf/raycast/overlapSphere/
  /// shapeCastSphere against known landmarks; the summary lands in the
  /// status line and the log.
  Future<void> _runQueryBattery() async {
    final die = _die;
    if (die == null) return;
    final summary = await FeatureScene.queryBattery(_controller, die);
    dnLog('dart3d: queries: $summary');
    if (mounted) setState(() => _queryStatus = summary);
  }

  /// The W9 joint rig at +12 s — after the W8 query battery. The rig's
  /// bodies go out as `addNode` ops and the joints as `addJoint` ops;
  /// the returned count feeds the status line.
  void _runJointRig() {
    final added = _jointRig?.call() ?? 0;
    dnLog('dart3d: joint rig landed — $added joints');
    if (mounted) setState(() => _jointCount = added);
  }

  /// The W11 skins/animation phase at +14 s — after the joint rig.
  /// The phase upserts its meshes/skin/animations and drives playback;
  /// its report feeds the `anims: N playing` status.
  void _runW11() {
    dnLog('dart3d: w11 phase — flag skin, morph blob, wave+pulse');
    _w11Phase?.call((playing) {
      if (mounted) setState(() => _animsPlaying = playing);
    });
  }

  /// The W12 component-parity phase at +22 s — joint components
  /// (world-anchored + node↔node), a materialsVariants selection
  /// cycle, and a rectAreaLight with `enabled:false`. The phase logs
  /// its own pose evidence two seconds in.
  void _runW12() {
    dnLog(
      'dart3d: w12 phase — joint components + variants + '
      'rectAreaLight',
    );
    _w12Phase?.call();
  }

  /// The W13 environment-effects phase at +34 s — after W12's inner
  /// timers end. The phase re-ships the env resource's `effects` spec
  /// on a two-second cadence, ending on the `overridesEffects:false`
  /// absent-key lane; it logs each toggle itself.
  void _runW13() {
    dnLog('dart3d: w13 phase — environment effects toggles');
    _w13Phase?.call();
  }

  /// The W14 render-texture/views phase at +50 s — after W13's inner
  /// timers end. The phase mints an everyFrame render target a second
  /// camera produces and a foreground cube consumes, adds a `manual`
  /// target driven by the `render` op, grows/shrinks the view list,
  /// and toggles the stage's AA/renderScale; it logs each step itself.
  void _runW14() {
    dnLog('dart3d: w14 phase — render textures + views');
    _w14Phase?.call();
  }

  /// The loose-ends evidence phase at +78 s — after W14's showcase
  /// timer ends. The phase spawns its own probe bodies (a `ccdEnabled`
  /// sphere dropped through a thin plate, a drifting drop into the
  /// concaveMesh bowl, a dead drop onto boundsQuad's bounds collider),
  /// reads their rest poses through `poseOf`, then removes the
  /// perpetual movers (`w5NoRest`, the lift motor, the chain links)
  /// and times three roll→rest cycles on the die. The demo's own
  /// churn stops here — the auto-reroll and the rescue watchdog would
  /// throw and teleport the die inside the measurement window. The
  /// phase logs each PASS/FAIL itself.
  void _runWLoose() {
    dnLog('dart3d: wloose phase — ccd + bowl + margin + settle latency');
    _reroll?.cancel();
    _watchdog?.cancel();
    _wLoosePhase?.call();
  }

  void _onJointEvent(SceneJointBroke event) {
    dnLog(
      'dart3d: joint broke #${event.id} '
      'a=${event.nodeA.index} b=${event.nodeB?.index ?? 'world'}',
    );
    setState(() => _jointsBroke++);
  }

  void _onPhysicsEvent(ScenePhysicsEvent event) {
    switch (event) {
      case SceneAwakeEvent():
        setState(() {
          _status = 'rolling…';
          _result = null;
        });
        // If nothing settles within 10s a body left the world —
        // teleport both back above the slab and drop them again.
        _watchdog?.cancel();
        _watchdog = Timer(const Duration(seconds: 10), _rescueBodies);
      case SceneSettledEvent(poses: final poses):
        for (final pose in poses) {
          if (pose.node == _die) {
            setState(() {
              // The axis face map only applies to the harness d6 —
              // imported dice keep the settle signal without a face.
              _result = _model < 0 ? _upFace(pose.rotation) : null;
              _status = 'settled';
            });
          } else if (pose.node == _ball) {
            _ballPos = pose.position;
          }
        }
        // Self-running demo: throw again shortly after every settle.
        _watchdog?.cancel();
        _reroll?.cancel();
        _reroll = Timer(const Duration(seconds: 3), _roll);
    }
  }

  /// Teleports both dynamic bodies back above the slab and zeroes their
  /// velocity — transform writes on a dynamic body reposition it (the
  /// sim owns the motion afterwards, which is what a respawn wants).
  void _rescueBodies() {
    final die = _die;
    final ball = _ball;
    if (die == null) return;
    _controller.setBodyVelocity(
      die,
      linear: Vector3.zero(),
      angularAxis: Vector3(0, 1, 0),
      angularRate: 0,
    );
    if (ball != null) {
      _controller.setBodyVelocity(
        ball,
        linear: Vector3.zero(),
        angularAxis: Vector3(0, 1, 0),
        angularRate: 0,
      );
    }
    _controller.setNodeTransforms([
      NodeTransform(
        die,
        translation: _model < 0
            ? Vector3(0, 1.5, 0)
            : _dieCenter + Vector3(0, _dieRadius * 1.6, 0),
        rotation: Quaternion.identity(),
      ),
      if (ball != null)
        NodeTransform(
          ball,
          translation: Vector3(1.7, 1.2, 3.0),
          rotation: Quaternion.identity(),
        ),
    ]);
  }

  /// Which local face of the die points up: rotate each local axis into
  /// world space and take the one most aligned with +Y.
  static final _axes = {
    '+x': Vector3(1, 0, 0),
    '-x': Vector3(-1, 0, 0),
    '+y': Vector3(0, 1, 0),
    '-y': Vector3(0, -1, 0),
    '+z': Vector3(0, 0, 1),
    '-z': Vector3(0, 0, -1),
  };

  int _upFace(Quaternion q) {
    var best = '+y';
    var bestDot = -2.0;
    for (final e in _axes.entries) {
      final d = q.rotated(e.value).y;
      if (d > bestDot) {
        bestDot = d;
        best = e.key;
      }
    }
    return _faces[best]!;
  }

  void _roll() {
    final die = _die;
    if (die == null) return;
    final imported = _model >= 0;
    // Dice-cup throw: lift the die above the slab center with a random
    // spin, then a modest impulse. A throw that launches the die meters
    // high with lateral drift just leaves the arena — the sim then
    // correctly reports a body that never settles. In imported mode the
    // throw scales with the model's bounds radius (~9–10 units for the
    // dice set).
    final r = _dieRadius;
    final tumble = Quaternion.axisAngle(
      Vector3(
        _rng.nextDouble() * 2 - 1,
        _rng.nextDouble() * 2 - 1,
        _rng.nextDouble() * 2 - 1,
      )..normalize(),
      _rng.nextDouble() * pi * 2,
    );
    _controller.setBodyVelocity(
      die,
      linear: Vector3.zero(),
      angularAxis: Vector3(0, 1, 0),
      angularRate: 0,
    );
    _controller.setNodeTransforms([
      NodeTransform(
        die,
        translation: imported
            ? _dieCenter +
                Vector3(
                  (_rng.nextDouble() - 0.5) * r * 0.6,
                  r * 1.5,
                  (_rng.nextDouble() - 0.5) * r * 0.6,
                )
            : Vector3(
                (_rng.nextDouble() - 0.5) * 0.8,
                1.4,
                0.8 + (_rng.nextDouble() - 0.5) * 0.6,
              ),
        rotation: tumble,
      ),
      // A rotation write on the hidden node — the "stays invisible
      // after a transform write" lane runs on every throw.
      if (_hidden != null)
        NodeTransform(
          _hidden!,
          rotation: Quaternion.axisAngle(
            Vector3(0, 1, 0),
            _rng.nextDouble() * pi * 2,
          ),
        ),
    ]);
    // mass 0.5 → Δv = J/0.5: J.y ~1.2–1.8 pops the die ~0.5–0.8 m,
    // lateral J ≤0.25 keeps it inside the slab footprint. Imported
    // dice carry mass 1.0 at ~10-unit radius, so the impulse scales.
    _controller.applyImpulse(
      die,
      imported
          ? Vector3(
              (_rng.nextDouble() - 0.5) * r * 0.3,
              r * (0.9 + _rng.nextDouble() * 0.4),
              (_rng.nextDouble() - 0.5) * r * 0.3,
            )
          : Vector3(
              (_rng.nextDouble() - 0.5) * 0.5,
              1.2 + _rng.nextDouble() * 0.6,
              (_rng.nextDouble() - 0.5) * 0.5,
            ),
    );
    // Unit box, mass 0.5 → I ≈ 0.167 kg·m², so J ≈ 0.8–2.0 gives
    // ω ≈ 5–12 rad/s: a tumble. Anything much hotter stores enough
    // spin energy that first contact converts it into a lateral kick
    // and the die shoots off the slab edge. The imported die's inertia
    // scales with r², so its torque impulse does too.
    _controller.applyTorqueImpulse(
      die,
      Vector3(
        _rng.nextDouble() * 2 - 1,
        _rng.nextDouble() * 2 - 1,
        _rng.nextDouble() * 2 - 1,
      )..normalize(),
      imported ? r * r * (0.8 + _rng.nextDouble() * 0.8)
               : 0.8 + _rng.nextDouble() * 1.2,
    );
  }

  void _setOrtho(bool value) {
    setState(() {
      _ortho = value;
      _model = -1;
      _result = null;
      _ballPos = null;
      _status = 'dropping…';
    });
    // Projection lives in the manifest — the only way to write it with
    // today's protocol is a document reload.
    _loadScene();
  }

  /// Advances the upstream-interchange lane: harness → d4 → … → d20 →
  /// harness. Imported documents replace the whole scene through
  /// `loadDocument`; the phase timers and query battery reference
  /// harness nodes, so they cancel for the imported scenes.
  void _cycleModel() {
    setState(() {
      _model = (_model + 2) % (importedDice.length + 1) - 1;
      _result = null;
      _ballPos = null;
      _status = 'dropping…';
    });
    if (_model < 0) {
      _loadScene();
      return;
    }
    _loadImported(importedDice[_model]);
  }

  /// Swaps the scene to an upstream-importer `.fsceneb` artifact.
  /// [loadImportedScene] augments the foreign document with a
  /// camera/lights/environment/ground and puts a dynamic convexHull
  /// body on the mesh root, so the Roll button and settle event work
  /// unchanged.
  void _loadImported(ImportedModel model) {
    _w11Timer?.cancel();
    _w12Timer?.cancel();
    _w13Timer?.cancel();
    _w14Timer?.cancel();
    _wLooseTimer?.cancel();
    _queryBattery?.cancel();
    _jointTimer?.cancel();
    _reroll?.cancel();
    _watchdog?.cancel();
    final loaded = loadImportedScene(model);
    if (loaded == null) {
      setState(() => _status = 'import failed — see log');
      return;
    }
    _die = loaded.meshNode;
    _ball = null;
    _hidden = null;
    _jointRig = null;
    _w11Phase = null;
    _w12Phase = null;
    _w13Phase = null;
    _w14Phase = null;
    _wLoosePhase = null;
    _animsPlaying = 0;
    _jointCount = 0;
    _jointsBroke = 0;
    _dieCenter = loaded.center;
    _dieRadius = loaded.radius;
    _controller.loadDocument(loaded.document);
  }

  /// Advances the W7 environment lane and rebuilds the document —
  /// `stage.environmentRef` lives in the manifest, so the env swap is
  /// the same reload path as the Ortho toggle.
  void _cycleEnv() {
    setState(() {
      _env = (_env + 1) % _envNames.length;
      _model = -1;
      _result = null;
      _ballPos = null;
      _status = 'dropping…';
    });
    _loadScene();
  }

  @override
  void dispose() {
    _events?.cancel();
    _contacts?.cancel();
    _joints?.cancel();
    _reroll?.cancel();
    _watchdog?.cancel();
    _queryBattery?.cancel();
    _jointTimer?.cancel();
    _w11Timer?.cancel();
    _w12Timer?.cancel();
    _w13Timer?.cancel();
    _w14Timer?.cancel();
    _wLooseTimer?.cancel();
    super.dispose();
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// A cycle control in the toggles' layout: the label sits where a
  /// Switch would be, with the current value as a tap-to-advance button.
  Widget _cycler(String label, String value, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Button(title: value, onPressed: onPressed),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ball = _ballPos;
    return Scaffold(
      brightness: Brightness.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: SceneView(
              controller: _controller,
              allowsCameraControl: _cameraControl,
              showsStatistics: _stats,
              quality: widget.quality,
            ),
          ),
          if (widget.nav != null)
            Positioned(
              left: 0,
              right: 0,
              top: 56,
              child: widget.nav!,
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 100,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _result == null
                        ? _status
                        : '$_status — rolled $_result'
                              '${ball == null ? '' : ' · ball('
                                        '${ball.x.toStringAsFixed(2)}, '
                                        '${ball.z.toStringAsFixed(2)})'}',
                  ),
                  Text(
                    'contacts: $_contactCount · joints: $_jointCount'
                    '${_jointsBroke == 0 ? '' : ' ($_jointsBroke broke)'}'
                    ' · anims: $_animsPlaying playing'
                    '${_queryStatus.isEmpty ? '' : ' · $_queryStatus'}',
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _toggle('Ortho', _ortho, _setOrtho),
                    _toggle('Stats', _stats, (v) => setState(() => _stats = v)),
                    _toggle(
                      'Camera',
                      _cameraControl,
                      (v) => setState(() => _cameraControl = v),
                    ),
                    _cycler('Env', _envNames[_env], _cycleEnv),
                    _cycler(
                      'Model',
                      _model < 0 ? 'harness' : importedDice[_model].label,
                      _cycleModel,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Button(title: 'Roll', onPressed: _roll),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
