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

import 'back_chevron.dart';
import 'showcase_loader.dart';

/// Boot override for the U1 camera-controller pose (`orbit1..3`,
/// `fly1..3`, `follow1..3`).
const String _kBootU1Pose = String.fromEnvironment(
  'DART3D_U1_POSE',
  defaultValue: 'orbit1',
);

const List<String> _kU1PoseSequence = <String>[
  'orbit1',
  'orbit2',
  'orbit3',
  'fly1',
  'fly2',
  'fly3',
  'follow1',
  'follow2',
  'follow3',
];

/// The showcase screen: a scene cycler over [showcaseItems], an
/// animation cycler when the scene has clips, and an orbit/fly/follow
/// camera rig with tap-to-pick (`ScenePointer`).
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({
    super.key,
    required this.onBack,
    this.initialLabel,
    this.quality,
  });

  /// Returns to the hero — the top-left back chevron.
  final VoidCallback onBack;

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

  /// The camera rig — driven by [OrbitCameraController] by default,
  /// and switchable across [OrbitCameraController],
  /// [FlyCameraController], and [FollowCameraController] in the `u1`
  /// verification scene.
  LocalId? _cameraNode;
  OrbitCameraController? _orbitController;
  CameraController? _activeCameraController;
  ScenePointer? _scenePointer;

  /// U1 state: current pose index in [_kU1PoseSequence] and last picked
  /// target summary.
  int _u1PoseIndex = max(0, _kU1PoseSequence.indexOf(_kBootU1Pose));
  String _u1PickedLabel = 'Tap a target to pick';
  LocalId? _u1FollowSubjectId;
  LocalId? _u1PickMarkerId;

  /// The loaded item's fit radius — feeds the aspect-ratio widening
  /// in the layout pass.
  double _frameRadius = 0;
  double _distAtScaleStart = 0;
  bool _aspectFramed = false;

  /// One-finger orbit bookkeeping. DartNative's iOS scale recognizer
  /// claims one-finger drags too (it reports `pointerCount == 1`
  /// updates and `onPanUpdate` never fires alongside it), so the orbit
  /// reads focal-point deltas from the scale stream as well as pan
  /// deltas. Whichever recognizer delivers the first one-finger delta
  /// of a gesture owns it, so a platform that fires both can't
  /// double-rotate (#27).
  _OrbitSource? _orbitOwner;
  Offset? _lastFocal;
  int _scalePointers = 0;
  bool _tapPending = false;

  /// The screen's width / height, once known — lets [_load] author the
  /// aspect-fitted boom into the document itself (see [_fitBoom]).
  double? _viewAspect;
  double _lastViewW = 800;
  double _lastViewH = 600;
  bool _loadedOnce = false;
  String _status = 'loading…';

  int _initialIndex() {
    final label = widget.initialLabel;
    if (label == null) return 0;
    final i = _items.indexWhere((it) => it.label == label);
    return i < 0 ? 0 : i;
  }

  // The first load waits for didChangeDependencies so the screen's
  // aspect ratio is known before the document ships.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    if (size.width > 0 && size.height > 0) {
      _viewAspect = size.width / size.height;
      _lastViewW = size.width;
      _lastViewH = size.height;
    }
    if (!_loadedOnce) {
      _loadedOnce = true;
      _load(_items[_index]);
    }
  }

  void _load(ShowcaseItem item) {
    setState(() {
      _status = 'loading ${item.label}…';
      _anims = const [];
      _animIndex = 0;
      _aspectFramed = false;
      _cameraNode = null;
      _frameRadius = 0;
      _u1FollowSubjectId = null;
      _u1PickMarkerId = null;
    });

    final scene = loadShowcaseScene(item, bytesFor: loadAssetBytes, log: dnLog);
    if (scene == null) {
      setState(() => _status = '${item.label}: load failed — see log');
      return;
    }
    _scene = scene;
    _cameraNode = scene.cameraNode;
    _frameRadius = scene.frameRadius;

    final dir = scene.cameraDir;
    final azimuth = atan2(dir.x, -dir.z);
    final elevation = asin(dir.y.clamp(-1.0, 1.0));
    final initialDist = scene.frameRadius * 2.8;
    final minDist = scene.frameRadius * 0.8;
    final maxDist = scene.frameRadius * 30.0;

    final orbit = OrbitCameraController(
      target: scene.cameraTarget.clone(),
      distance: initialDist,
      azimuth: azimuth,
      elevation: elevation,
      minDistance: minDist,
      maxDistance: maxDist,
      minElevation: 0.05,
      maxElevation: 1.45,
      damping: 0.0,
      fovRadiansY: 0.8,
      near: max(scene.frameRadius * 0.02, 0.01),
      far: scene.frameRadius * 60.0,
    );
    _orbitController = orbit;
    _activeCameraController = orbit;

    final aspect = _viewAspect;
    if (aspect != null) {
      _fitBoom(aspect);
      _aspectFramed = true;
    }

    if (item.assetKey == kBuiltinU1Key) {
      _initU1Controllers(scene);
      _applyU1Pose(_kU1PoseSequence[_u1PoseIndex], writeLive: false);
    }

    // Author the fitted pose into the document before it ships: a
    // setNodeTransforms sent right behind loadScene can land before
    // the native side has realized the camera node and be lost.
    final activeCam = _activeCameraController;
    if (activeCam != null) {
      final nt = activeCam.toNodeTransform(scene.cameraNode);
      scene.document.nodes[scene.cameraNode]?.transform = TrsTransform(
        translation: nt.translation ?? Vector3.zero(),
        rotation: nt.rotation ?? Quaternion.identity(),
      );
    }

    _scenePointer = ScenePointer(
      document: scene.document,
      camera: _activeCameraController?.camera ??
          SceneCamera.fromDocument(scene.document) ??
          SceneCamera.perspective(),
      where: (node) =>
          node.id != _u1PickMarkerId && node.name != 'showcase.slab',
      onTap: _onSceneTapPicked,
    );

    if (item.assetKey == kBuiltinDocRoundtripKey) {
      _runDocRoundtrip(scene.document);
    } else {
      _controller.loadDocument(scene.document);
    }
    setState(() => _status = '${item.label} — ${item.note}');
    _installAnims();

    if (item.assetKey == kBuiltinU1Key) {
      _verifyU1FiveTargetPicks(scene.document);
    }
  }

  void _initU1Controllers(ShowcaseScene scene) {
    final doc = scene.document;
    for (final n in doc.nodes.values) {
      if (n.name == 'u1.target.d3proc') _u1FollowSubjectId = n.id;
      if (n.name == 'u1.pick.marker') _u1PickMarkerId = n.id;
    }
    final baseEye = _orbitController!.camera.position;
    final baseTarget = _orbitController!.camera.target;
    final fwd = (baseTarget - baseEye)..normalize();
    final yaw = atan2(fwd.x, fwd.z);
    final pitch = asin(fwd.y.clamp(-1.0, 1.0));

    FlyCameraController(
      position: baseEye.clone(),
      yaw: yaw,
      pitch: pitch,
      moveSpeed: 4.5,
      boostMultiplier: 2.0,
      fovRadiansY: 0.8,
      near: max(scene.frameRadius * 0.02, 0.01),
      far: scene.frameRadius * 60.0,
    );

    final subjectId = _u1FollowSubjectId;
    if (subjectId != null) {
      FollowCameraController(
        document: doc,
        targetNode: subjectId,
        offset: Vector3(0.0, 1.8, -5.6),
        lookAtOffset: Vector3(0.0, 0.1, 0.0),
        rotateOffsetWithTarget: true,
        positionSmoothing: 0.0,
        targetSmoothing: 0.0,
        fovRadiansY: 0.8,
        near: max(scene.frameRadius * 0.02, 0.01),
        far: scene.frameRadius * 60.0,
      );
    }
  }

  /// Applies one of the 9 U1 verification poses (`orbit1..3`, `fly1..3`,
  /// `follow1..3`) by driving the corresponding [CameraController]'s
  /// gesture/input methods.
  void _applyU1Pose(String poseName, {required bool writeLive}) {
    final scene = _scene;
    if (scene == null) return;
    final doc = scene.document;
    final baseDist = _orbitController?.distance ?? (scene.frameRadius * 2.8);

    // Reset follow subject to its default home position unless in follow2/3.
    final subjectId = _u1FollowSubjectId;
    if (subjectId != null && doc.nodes[subjectId] != null) {
      var subPos = Vector3(0.0, 0.85, 0.0);
      var subRot = Quaternion.identity();
      if (poseName == 'follow2') {
        subPos = Vector3(-1.35, 1.25, -0.75);
        subRot = Quaternion.axisAngle(Vector3(0, 1, 0), 0.48);
      } else if (poseName == 'follow3') {
        subPos = Vector3(1.35, 1.10, 0.85);
        subRot = Quaternion.axisAngle(Vector3(0, 1, 0), -0.52);
      }
      doc.nodes[subjectId]!.transform = TrsTransform(
        translation: subPos,
        rotation: subRot,
      );
      if (writeLive) {
        _controller.setNodeTransforms([
          NodeTransform(subjectId, translation: subPos, rotation: subRot),
        ]);
      }
    }

    String mode = 'orbit';
    if (poseName.startsWith('orbit')) {
      mode = 'orbit';
      final orbit = OrbitCameraController(
        target: scene.cameraTarget.clone(),
        distance: baseDist,
        azimuth: 0.0,
        elevation: 0.28,
        minDistance: scene.frameRadius * 0.6,
        maxDistance: scene.frameRadius * 30.0,
        minElevation: 0.05,
        maxElevation: 1.45,
        damping: 0.0,
        fovRadiansY: 0.8,
        near: max(scene.frameRadius * 0.02, 0.01),
        far: scene.frameRadius * 60.0,
      );
      if (poseName == 'orbit2') {
        orbit.orbitBy(0.58, 0.20);
        orbit.zoomByFactor(0.84);
      } else if (poseName == 'orbit3') {
        orbit.orbitBy(-0.52, 0.34);
        orbit.panBy(0.65, 0.15);
        orbit.zoomByFactor(0.90);
      }
      _orbitController = orbit;
      _activeCameraController = orbit;
    } else if (poseName.startsWith('fly')) {
      mode = 'fly';
      final fly = FlyCameraController(
        position: Vector3(0.0, 2.1, -baseDist * 0.92),
        yaw: 0.0,
        pitch: -0.18,
        moveSpeed: 4.0,
        boostMultiplier: 1.8,
        fovRadiansY: 0.8,
        near: max(scene.frameRadius * 0.02, 0.01),
        far: scene.frameRadius * 60.0,
      );
      if (poseName == 'fly1') {
        fly.setMoveInput(Vector2(-0.55, 0.25), elevate: 0.1);
        fly.update(0.5);
        fly.lookBy(0.24, -0.04);
      } else if (poseName == 'fly2') {
        fly.setMoveInput(Vector2(0.15, 0.85), elevate: -0.10);
        fly.update(0.65);
        fly.lookBy(-0.08, 0.03);
      } else if (poseName == 'fly3') {
        fly.setMoveInput(Vector2(0.65, 0.55), elevate: 0.25, boost: true);
        fly.update(0.5);
        fly.lookBy(-0.34, -0.10);
      }
      fly.setMoveInput(Vector2.zero());
      _activeCameraController = fly;
    } else if (poseName.startsWith('follow') && subjectId != null) {
      mode = 'follow';
      final follow = FollowCameraController(
        document: doc,
        targetNode: subjectId,
        offset: Vector3(0.0, 1.9, -baseDist * 0.72),
        lookAtOffset: Vector3(0.0, 0.05, 0.0),
        rotateOffsetWithTarget: true,
        positionSmoothing: 0.0,
        targetSmoothing: 0.0,
        fovRadiansY: 0.8,
        near: max(scene.frameRadius * 0.02, 0.01),
        far: scene.frameRadius * 60.0,
      );
      if (poseName == 'follow2') {
        follow.orbitBy(0.28, 0.10);
      } else if (poseName == 'follow3') {
        follow.orbitBy(-0.32, 0.18);
      }
      follow.update(1 / 60);
      _activeCameraController = follow;
    }

    final cam = _activeCameraController?.camera;
    if (cam != null) {
      _scenePointer?.camera = cam;
      dnLog(
        'dart3d: u1 controller=$mode pose=$poseName '
        'camPos=(${cam.position.x.toStringAsFixed(2)},'
        '${cam.position.y.toStringAsFixed(2)},'
        '${cam.position.z.toStringAsFixed(2)}) '
        'camTarget=(${cam.target.x.toStringAsFixed(2)},'
        '${cam.target.y.toStringAsFixed(2)},'
        '${cam.target.z.toStringAsFixed(2)}) PASS',
      );
    }
    if (writeLive) {
      _writeCamera();
      setState(() {});
    }
  }

  void _cycleU1Pose() {
    _u1PoseIndex = (_u1PoseIndex + 1) % _kU1PoseSequence.length;
    _applyU1Pose(_kU1PoseSequence[_u1PoseIndex], writeLive: true);
  }

  /// Runs a deterministic 5-target tap-to-pick check through
  /// [ScenePointer] across the 5 U1 targets (procedural, payload,
  /// `d3:procMesh`, skinned, and `d3:instances`) and logs each result.
  void _verifyU1FiveTargetPicks(SceneDocument doc) {
    final cam = _activeCameraController?.camera ?? SceneCamera.fromDocument(doc);
    if (cam == null) return;
    final viewW = _lastViewW > 0 ? _lastViewW : 800.0;
    final viewH = _lastViewH > 0 ? _lastViewH : 600.0;

    final targets = <(int, String, Vector3)>[
      (1, 'u1.target.procedural', Vector3(-3.2, 0.85, 0.0)),
      (2, 'u1.target.payload', Vector3(-1.6, 0.85, 0.0)),
      (3, 'u1.target.d3proc', Vector3(0.0, 0.85, 0.0)),
      (4, 'u1.target.skinned', Vector3(1.6, 1.35, 0.0)), // Deformed by joint0
      (5, 'u1.target.instanced', Vector3(3.2, 1.50, 0.0)), // Instance #2
    ];

    final verifierPointer = ScenePointer(
      document: doc,
      camera: cam,
      where: (node) =>
          node.id != _u1PickMarkerId && node.name != 'showcase.slab',
    );

    var passCount = 0;
    for (final (idx, expectedName, worldPt) in targets) {
      final screen = cam.worldToScreen(worldPt, viewW, viewH);
      if (screen == null) {
        dnLog('dart3d: u1 pick target=$idx expected=$expectedName FAIL (offscreen)');
        continue;
      }
      verifierPointer.press(
        screenX: screen.$1,
        screenY: screen.$2,
        viewWidth: viewW,
        viewHeight: viewH,
      );
      final hit = verifierPointer.release(
        screenX: screen.$1,
        screenY: screen.$2,
        viewWidth: viewW,
        viewHeight: viewH,
      );
      final hitName = hit == null ? 'none' : (doc.nodes[hit.node]?.name ?? '');
      final ok = hit != null && hitName == expectedName;
      if (ok) passCount++;
      dnLog(
        'dart3d: u1 pick target=$idx node=$hitName '
        'id=${hit?.node.toToken() ?? "none"} '
        'instance=${hit?.instanceIndex} '
        ' ${ok ? "PASS" : "FAIL"}',
      );
    }
    dnLog(
      'dart3d: u1 pick summary $passCount/${targets.length} targets '
      '${passCount == targets.length ? "PASS" : "FAIL"}',
    );
  }

  void _onSceneTapPicked(LocalId nodeId, SceneRaycastHit hit) {
    final doc = _scene?.document;
    if (doc == null) return;
    final name = doc.nodes[nodeId]?.name ?? nodeId.toToken();
    final instSuffix = hit.instanceIndex != null ? '#${hit.instanceIndex}' : '';
    dnLog(
      'dart3d: u1 tap-pick node=$name id=${nodeId.toToken()} '
      'instance=${hit.instanceIndex} '
      'point=(${hit.point.x.toStringAsFixed(2)},'
      '${hit.point.y.toStringAsFixed(2)},'
      '${hit.point.z.toStringAsFixed(2)}) PASS',
    );
    final markerId = _u1PickMarkerId;
    if (markerId != null && doc.nodes[markerId] != null) {
      doc.nodes[markerId]!.transform = TrsTransform(
        translation: hit.point,
        scale: Vector3.all(1.0),
      );
      _controller.setNodeTransforms([
        NodeTransform(
          markerId,
          translation: hit.point,
          scale: Vector3.all(1.0),
        ),
      ]);
    }
    setState(() {
      _u1PickedLabel = 'Picked: $name$instSuffix';
    });
  }

  void _startTap(Offset position, Size viewSize) {
    if (_tapPending) return;
    final pointer = _scenePointer;
    final camera = _activeCameraController?.camera;
    if (pointer == null || camera == null) return;
    _tapPending = true;
    pointer.camera = camera;
    pointer.press(
      screenX: position.dx,
      screenY: position.dy,
      viewWidth: viewSize.width,
      viewHeight: viewSize.height,
    );
  }

  void _cancelTap() {
    if (!_tapPending) return;
    _tapPending = false;
    _scenePointer?.cancel();
  }

  void _finishTap(Offset position, Size viewSize) {
    if (!_tapPending) return;
    _tapPending = false;
    final pointer = _scenePointer;
    final camera = _activeCameraController?.camera;
    if (pointer == null || camera == null) return;
    pointer.camera = camera;
    pointer.release(
      screenX: position.dx,
      screenY: position.dy,
      viewWidth: viewSize.width,
      viewHeight: viewSize.height,
    );
  }

  /// The W29 round-trip lane (the `roundtrip` showcase item):
  /// [document] loads, comes back through [SceneController.serializeScene]'s
  /// mirror snapshot, and re-realizes from its canonical `.fscene` form
  /// under strict feature negotiation.
  void _runDocRoundtrip(SceneDocument document) {
    _controller.loadDocument(document);
    final snapshot = _controller.serializeScene();
    if (snapshot == null) {
      dnLog('dart3d: showcase — roundtrip: serializeScene returned null');
      return;
    }
    _controller.loadFscene(
      writeFsceneWithExtensions(snapshot),
      strictFeatures: true,
    );
    var resent = 0;
    for (final payload in snapshot.payloads.values) {
      if (payload.bytes == null) continue;
      _controller.sendPayload(payload);
      resent++;
    }
    dnLog(
      'dart3d: showcase — roundtrip: ${snapshot.nodes.length} nodes · '
      '$resent/${snapshot.payloads.length} chunks re-sent after the '
      'JSON leg',
    );
  }

  /// Reads the loaded document's clip pool and autoplays the first
  /// (preferring 'Idle').
  void _installAnims() {
    final anims = _controller.animations.values.toList();
    if (anims.isEmpty) return;
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
    final previous = _anims[_animIndex].id;
    _animIndex = (_animIndex + 1) % _anims.length;
    _controller.switchAnimation(
      from: previous,
      to: _anims[_animIndex].id,
      loop: true,
    );
    setState(() {});
  }

  /// Syncs the active [CameraController] pose to the native view and
  /// the tracked document.
  void _writeCamera() {
    final node = _cameraNode;
    final active = _activeCameraController;
    if (node == null || active == null) return;
    final nt = active.toNodeTransform(node);
    _scene?.document.nodes[node]?.transform = TrsTransform(
      translation: nt.translation ?? Vector3.zero(),
      rotation: nt.rotation ?? Quaternion.identity(),
    );
    _scenePointer?.camera = active.camera;
    _controller.setNodeTransforms([nt]);
  }

  /// Widens the boom until the bounds diameter fits the horizontal
  /// half-angle (fovY·aspect narrows on portrait screens).
  void _fitBoom(double aspect) {
    final orbit = _orbitController;
    if (orbit == null) return;
    final needed = _frameRadius * 1.2 / (tan(0.8 / 2) * aspect);
    if (needed > orbit.distance) {
      orbit.distance = needed;
    }
  }

  /// One-finger drag drives the active [CameraController].
  void _orbit(DragUpdateDetails d) {
    if (d.pointerCount != 1) {
      if (d.pointerCount >= 2) _cancelTap();
      return;
    }
    _orbitBy(_OrbitSource.pan, d.delta);
  }

  /// Applies one drag [delta] from [source] unless the other
  /// recognizer already owns this gesture.
  void _orbitBy(_OrbitSource source, Offset delta) {
    if (_cameraNode == null) return;
    _orbitOwner ??= source;
    if (_orbitOwner != source) return;
    _cancelTap();
    final active = _activeCameraController;
    if (active is OrbitCameraController) {
      active.orbitBy(-delta.dx * 0.008, delta.dy * 0.008);
    } else if (active is FlyCameraController) {
      active.lookBy(delta.dx * 0.006, -delta.dy * 0.006);
    } else if (active is FollowCameraController) {
      active.orbitBy(-delta.dx * 0.008, delta.dy * 0.008);
      active.update(1 / 60);
    }
    _writeCamera();
  }

  void _onScaleStart(ScaleStartDetails d, Size viewSize) {
    _distAtScaleStart = _orbitController?.distance ?? (_frameRadius * 2.8);
    _lastFocal = d.focalPoint;
    _scalePointers = d.pointerCount;
    if (d.pointerCount >= 2) {
      _cancelTap();
    } else {
      _startTap(d.focalPoint, viewSize);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final last = _lastFocal;
    final pointers = _scalePointers;
    _lastFocal = d.focalPoint;
    _scalePointers = d.pointerCount;
    if (d.pointerCount >= 2) _cancelTap();
    if (d.pointerCount == 1) {
      if (pointers == 1 && last != null) {
        _orbitBy(_OrbitSource.scale, d.focalPoint - last);
      }
      return;
    }
    final active = _activeCameraController;
    if (active is OrbitCameraController) {
      if (pointers < 2) _distAtScaleStart = active.distance;
      final next = (_distAtScaleStart / d.scale).clamp(
        active.minDistance,
        active.maxDistance,
      );
      if ((next - active.distance).abs() > active.distance * 0.005) {
        active.distance = next;
        _writeCamera();
      }
    } else if (active is FlyCameraController && last != null) {
      final focalDelta = d.focalPoint - last;
      active.setMoveInput(
        Vector2(focalDelta.dx * 0.05, (d.scale - 1.0) * 4.0),
        elevate: -focalDelta.dy * 0.05,
      );
      active.update(1 / 60);
      active.setMoveInput(Vector2.zero());
      _writeCamera();
    }
  }

  void _endGesture() {
    _orbitOwner = null;
    _lastFocal = null;
    _scalePointers = 0;
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    final isU1 = item.assetKey == kBuiltinU1Key;
    return Scaffold(
      brightness: Brightness.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 0 &&
                    constraints.maxHeight > 0 &&
                    constraints.maxHeight.isFinite) {
                  _lastViewW = constraints.maxWidth;
                  _lastViewH = constraints.maxHeight;
                }
                if (!_aspectFramed &&
                    _frameRadius > 0 &&
                    constraints.maxWidth > 0 &&
                    constraints.maxHeight > 0 &&
                    constraints.maxHeight.isFinite) {
                  _aspectFramed = true;
                  final before = _orbitController?.distance ?? 0;
                  _fitBoom(constraints.maxWidth / constraints.maxHeight);
                  if ((_orbitController?.distance ?? 0) > before) {
                    if (isU1) {
                      _applyU1Pose(
                        _kU1PoseSequence[_u1PoseIndex],
                        writeLive: true,
                      );
                    } else {
                      _writeCamera();
                    }
                  }
                }
                final viewSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  onTapDown: (d) => _startTap(d.localPosition, viewSize),
                  onTapUp: (d) => _finishTap(d.localPosition, viewSize),
                  onTapCancel: _cancelTap,
                  onPanStart: (_) {
                    _orbitOwner = null;
                    _cancelTap();
                  },
                  onPanUpdate: _orbit,
                  onPanEnd: (_) => _endGesture(),
                  onScaleStart: (d) => _onScaleStart(d, viewSize),
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: (_) {
                    final last = _lastFocal;
                    if (last != null) _finishTap(last, viewSize);
                    _endGesture();
                  },
                  child: SceneView(
                    controller: _controller,
                    quality: widget.quality,
                    showsStatistics: switch (
                        const String.fromEnvironment('DART3D_STATS')) {
                      '1' || 'true' => true,
                      _ => false,
                    },
                  ),
                );
              },
            ),
          ),
          backChevron(context, widget.onBack),
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
                        if (isU1) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _cycleU1Pose,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x2EFFFFFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Cam: ${_kU1PoseSequence[_u1PoseIndex]} · $_u1PickedLabel',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xEEFFFFFF),
                                ),
                              ),
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

/// The recognizer driving a one-finger orbit — see
/// [_ShowcaseScreenState._orbitOwner].
enum _OrbitSource { pan, scale }
