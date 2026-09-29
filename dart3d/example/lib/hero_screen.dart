/// The launch hero (P4): the 3D DartNative logo on a dark stage,
/// orbiting slowly and breathing its own gradient glow, under a short
/// headline, three value props, and the way into the Dice and Showcase
/// screens. Spec: docs/design/hero-scene-brief.md (operator
/// overrides: full 360° orbit, glow from the logo itself, zoomed out).
///
/// Motion is Dart-driven: one ticker writes the orbit pivot's rotation
/// every frame (one `setNodeTransforms`), and re-sends the glow
/// material at ≤ [_glowHz] (10 Hz) with a new emissive factor. Costs are logged
/// with `--dart-define=DART3D_HERO_PERF=1` (`dart3d: hero perf …`).
library;

import 'dart:io';
import 'dart:math';

import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import 'app_route.dart';
import 'dn_logo_stage.dart';
import 'hero_motion.dart';
import 'hero_scene.dart';

// Site tokens (dartnative.com CSS, converted — brief §1.1).
const _bg = Color(0xFF090E12);
const _text = Color(0xFFEFF2F5);
const _text2 = Color(0xFFB2B8BF);
const _muted = Color(0xFF757B81);
const _accent = Color(0xFFA1EA5A);
const _accentInk = Color(0xFF121F05);

/// The site's brand gradient (`--brand-grad`), for the hairline.
const _brandGradient = LinearGradient(
  colors: [
    Color(0xFFFA60A6),
    Color(0xFFEF388B),
    Color(0xFFE99173),
    Color(0xFFD7BA52),
    Color(0xFFB5C75E),
  ],
  stops: [0, 0.26, 0.48, 0.72, 1],
);

/// The site's entrance curve (`cubic-bezier(0.16, 1, 0.3, 1)`, see
/// [heroEase]) over the [begin]–[end] slice of the parent clock —
/// DartNative has no `Interval`/`Cubic`, so this is both.
class _ExpoOutInterval extends Curve {
  const _ExpoOutInterval(this.begin, this.end);
  final double begin;
  final double end;

  @override
  double transform(double t) =>
      heroEase(((t - begin) / (end - begin)).clamp(0.0, 1.0));
}

/// The glow re-send rate cap (`DART3D_HERO_PULSE_HZ`; 0 = no breath).
/// 10 Hz: each re-send rebuilds the material instance natively, and on
/// the A142 (Vulkan, 90 Hz panel) 20 Hz cost ~4 fps on average where
/// 10 Hz is indistinguishable from no pulse — while a 4.8 s breath
/// moves ≤ 0.02 emissive per 100 ms step, below what the eye can see
/// (numbers in the P4 hero PR).
final double _glowHz = double.tryParse(
      const String.fromEnvironment('DART3D_HERO_PULSE_HZ'),
    ) ??
    10;

/// Pins the emissive factor (no breath) — for still evidence.
final double? _pinnedGlow = double.tryParse(
  const String.fromEnvironment('DART3D_HERO_GLOW'),
);

/// Parks the orbit at this yaw in degrees (no drift; the bob and a
/// drag still run) — for same-angle evidence, e.g. breath min vs max.
final double? _pinnedYawDeg = double.tryParse(
  const String.fromEnvironment('DART3D_HERO_YAW'),
);

const _perf = bool.fromEnvironment('DART3D_HERO_PERF') ||
    String.fromEnvironment('DART3D_HERO_PERF') == '1';

/// The launch screen. [onOpen] enters [AppScreen.dice] ("Roll the
/// dice") or [AppScreen.showcase].
class HeroScreen extends StatefulWidget {
  const HeroScreen({super.key, required this.onOpen, this.quality});

  final void Function(AppScreen screen) onOpen;

  /// The `DART3D_QUALITY` boot tier — null runs the widget defaults.
  final SceneQuality? quality;

  @override
  State<HeroScreen> createState() => _HeroScreenState();
}

class _HeroScreenState extends State<HeroScreen>
    with TickerProviderStateMixin {
  final _controller = SceneController();
  final _orbit = _pinnedYawDeg == null
      ? HeroOrbit()
      : HeroOrbit(
          revolutionSeconds: double.infinity,
          initialYaw: _pinnedYawDeg! * pi / 180,
        );
  late final DnLogoStage _stage =
      Platform.isIOS ? DnLogoStage.heroIos : DnLogoStage.heroAndroid;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Ticker _ticker = createTicker(_onTick);

  HeroScene? _scene;
  bool _loaded = false;

  /// The 3D logo failed to load — the copy and the way into the other
  /// screens still show, over a short note in the stage.
  bool _failed = false;

  /// The aspect the camera is currently framed for.
  double _framedAspect = 0;
  Duration _lastTick = Duration.zero;
  double _lastGlowAt = -1;
  double _lastGlow = -1;
  bool _entranceScaleDone = false;

  /// One-finger drag bookkeeping — DartNative's iOS scale recognizer
  /// claims one-finger drags too (see showcase_scene.dart, #27), so
  /// both streams feed the orbit and the first to deliver owns it.
  _DragSource? _dragOwner;
  final _focal = HeroFocalTracker();

  final _perfStats = _HeroPerf();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    if (size.width <= 0 || size.height <= 0) return;
    final aspect = size.width / size.height;
    if (!_loaded) {
      _loaded = true;
      // The copy and the way into the other screens rise in whether or
      // not the 3D stage loads.
      _entrance.forward();
      _load(aspect);
    } else if ((aspect - _framedAspect).abs() > 0.01) {
      _reframe(aspect);
    }
  }

  void _load(double aspect) {
    final scene = buildHeroScene(
      bytesFor: loadAssetBytes,
      stage: _stage,
      aspect: aspect,
      initialYaw: _orbit.yaw,
      initialPitch: _orbit.pitch,
      log: dnLog,
    );
    if (scene == null) {
      dnLog('dart3d: hero — logo asset failed to load; showing fallback');
      setState(() => _failed = true);
      return;
    }
    _scene = scene;
    _framedAspect = aspect;
    // The logo blooms in from no glow and 0.965 scale (brief §3.6).
    heroGlowOps(scene.document, scene.glowMaterials, 0);
    scene.document.nodes[scene.pivot]?.transform = TrsTransform(
      translation: scene.center.clone(),
      rotation: heroPivotRotation(_orbit.yaw, _orbit.pitch),
      scale: Vector3.all(1 / heroEntranceScale(0)),
    );
    _controller.loadDocument(scene.document);
    _lastGlow = 0;
    _ticker.start();
  }

  /// Re-aims the camera for a new viewport aspect (rotation, split
  /// screen, window resize) — one camera transform, no reload.
  void _reframe(double aspect) {
    final scene = _scene;
    if (scene == null) return;
    _framedAspect = aspect;
    final pose = heroCameraPose(heroFramingFor(scene.frameRadius, aspect));
    _controller.setNodeTransforms([
      NodeTransform(scene.camera, translation: pose.$1, rotation: pose.$2),
    ]);
    final mq = MediaQuery.of(context);
    dnLog('dart3d: hero — reframed for aspect ${aspect.toStringAsFixed(3)} '
        '(size ${mq.size} padding ${mq.padding} viewPadding ${mq.viewPadding})');
  }

  void _onTick(Duration elapsed) {
    final scene = _scene;
    if (scene == null) return;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final t = elapsed.inMicroseconds / 1e6;
    // A stalled frame (backgrounding, a GC) shouldn't jump the orbit.
    _orbit.tick(dt.clamp(0.0, 0.1));

    // Entrance bloom: the logo grows 0.965 → 1.0 over the first second.
    // The camera and rig are the pivot's children, so the pivot scales
    // by the inverse — the boom lengthens by 1/s and the logo reads s×
    // as large (the lights' directions are unchanged by a uniform scale).
    Vector3? scale;
    if (!_entranceScaleDone) {
      scale = Vector3.all(1 / heroEntranceScale(t));
      if (t >= 1.0) _entranceScaleDone = true;
    }
    final sw = Stopwatch()..start();
    _controller.setNodeTransforms([
      NodeTransform(
        scene.pivot,
        rotation: heroPivotRotation(_orbit.yaw % (2 * pi), _orbit.pitch),
        scale: scale,
      ),
    ]);
    final transformUs = sw.elapsedMicroseconds;

    int? glowUs;
    // With the breath off (`DART3D_HERO_PULSE_HZ=0`) or pinned
    // (`DART3D_HERO_GLOW`), the entrance ramp still runs at 10 Hz and
    // then holds a static glow — no re-sends once it settles.
    final glow = heroGlowAt(
      t,
      low: _stage.emissiveGlow,
      pinned: _pinnedGlow,
      breathing: _glowHz > 0,
    );
    final hz = _glowHz > 0 ? _glowHz : 10.0;
    if ((glow - _lastGlow).abs() > 0.004 &&
        t - _lastGlowAt >= 1 / hz - 0.002) {
      sw.reset();
      _controller.applyCommands(
        heroGlowOps(_controller.document ?? scene.document,
            scene.glowMaterials, glow),
      );
      glowUs = sw.elapsedMicroseconds;
      _lastGlowAt = t;
      _lastGlow = glow;
    }
    if (_perf) {
      _perfStats.add(dt, transformUs, glowUs);
      if (_perfStats.seconds >= 5) {
        dnLog('dart3d: hero perf ${Platform.operatingSystem} '
            'pulse ${_glowHz}Hz — ${_perfStats.report()}');
        _perfStats.reset();
      }
    }
  }

  void _dragBy(_DragSource source, Offset delta) {
    _dragOwner ??= source;
    if (_dragOwner != source) return;
    _orbit.drag(delta.dx, delta.dy);
  }

  void _endDrag() {
    _dragOwner = null;
    _focal.end();
    _orbit.release();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// A staggered rise-in (26 px + fade, 850 ms) starting at [startMs]
  /// on the entrance clock.
  Widget _rise(int startMs, Widget child) {
    const total = 1600.0;
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: _ExpoOutInterval(
        startMs / total,
        min(1, (startMs + 850) / total),
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      // Controls only take input once they're visibly in — an Opacity
      // at 0 still hit-tests.
      builder: (context, child) => IgnorePointer(
        ignoring: anim.value < 0.6,
        child: Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - anim.value)),
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mono = Platform.isIOS ? 'Menlo' : 'monospace';
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final landscape = size.width >= size.height;
    // Horizontal safe area for the wordmark: landscape insets (notch /
    // cutout) sit on the sides — on the A142 the cutout arrives in
    // `padding.top` (see copyRight), so take the larger of the two.
    final double wordmarkLeft =
        24 + (landscape ? max(padding.left, padding.top) : padding.left);
    // Landscape: the copy takes the right half.
    final double copyLeft = landscape ? size.width / 2 : 24 + padding.left;
    // DartNative quirk (A142, landscape): `size` spans the full display
    // while the window loses the 48 dp display-cutout band on the side,
    // and the cutout inset is reported in `padding.top` (t:48, r:0). So
    // in landscape the side margin takes the larger of the two.
    final copyRight =
        24.0 +
        (landscape ? max(padding.right, padding.top) + 16 : padding.right);
    return Scaffold(
      brightness: Brightness.dark,
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (_) => _dragOwner = null,
              onPanUpdate: (d) {
                if (d.pointerCount == 1) _dragBy(_DragSource.pan, d.delta);
              },
              onPanEnd: (_) => _endDrag(),
              onScaleStart: (d) => _focal.start(
                d.focalPoint.dx,
                d.focalPoint.dy,
                d.pointerCount,
              ),
              onScaleUpdate: (d) {
                final delta = _focal.update(
                  d.focalPoint.dx,
                  d.focalPoint.dy,
                  d.pointerCount,
                );
                if (delta != null) {
                  _dragBy(_DragSource.scale, Offset(delta.$1, delta.$2));
                }
              },
              onScaleEnd: (_) => _endDrag(),
              child: SceneView(
                controller: _controller,
                quality: widget.quality,
                backgroundColor: 0xFF090E12,
                showsStatistics: switch (
                    const String.fromEnvironment('DART3D_STATS')) {
                  '1' || 'true' => true,
                  _ => false,
                },
              ),
            ),
          ),
          // Scrim: keeps the glow off the copy (brief §3.7).
          Positioned(
            left: landscape ? size.width * 0.45 : 0,
            right: 0,
            bottom: 0,
            top: landscape ? 0 : size.height * 0.5,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: landscape
                        ? Alignment.centerLeft
                        : Alignment.topCenter,
                    end: landscape
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                    colors: const [Color(0x00090E12), Color(0xE6090E12)],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: wordmarkLeft,
            top: padding.top + 14,
            // The brief's identity guardrail: our wordmark leads; the
            // DartNative name appears only as "for DartNative".
            // Static, not a rise-in: on Android a faded-in Text
            // straight over the SurfaceView (no ancestor but the
            // Stack) came back invisible when the hero re-entered —
            // present in the view tree, never drawn.
            child: const Text(
              'dart3d',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _text,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (_failed)
            Positioned(
              left: landscape ? 24 : 0,
              right: landscape ? size.width / 2 : 0,
              top: padding.top + 56,
              height: landscape ? size.height * 0.6 : size.height * 0.3,
              child: const Center(
                child: Text(
                  '3D stage unavailable — the screens below still work.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            ),
          // The copy: bottom-anchored in portrait, the right half in
          // landscape. Bounded above (clear of the wordmark and, in
          // portrait, the logo) and scrollable, so short viewports and
          // large text scales can't push it off-screen.
          Positioned(
            left: copyLeft,
            right: copyRight,
            top: landscape
                ? padding.top + 16
                : max(padding.top + 56, size.height * 0.36),
            bottom: padding.bottom + 16,
            // Bottom-aligned, shrink-wrapped; scrolls only when the
            // copy outgrows the region. (A `reverse: true` scroll view
            // latched its offset before the text finished laying out on
            // Android's fresh launch and clipped the eyebrow.)
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SingleChildScrollView(
                child: SizedBox(
                  // Full region width, so the centred CTA row centres on
                  // the region, not on the widest text line.
                  width: landscape
                      // Capped: text measured wider than it drew on the
                      // A142 in landscape (see the inset quirk above).
                      ? min(size.width - copyLeft - copyRight, 320)
                      : size.width - copyLeft - copyRight,
                  child: _copy(mono, compact: landscape),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The copy block; [compact] (landscape) tightens the headline so the
  /// CTA stays on screen on a short viewport.
  Widget _copy(String mono, {bool compact = false}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rise(
            400,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'COMMUNITY PLUGIN · FOR DARTNATIVE',
                  style: TextStyle(
                    fontFamily: mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.3,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _rise(
            520,
            Text(
              "Real 3D, on the platform's own GPU.",
              style: TextStyle(
                fontSize: compact ? 26 : 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                height: 1.05,
                color: _text,
              ),
            ),
          ),
          // Landscape (compact) drops the value props so the CTA stays
          // above the fold on a ~400 dp-tall viewport (the block still
          // scrolls if a large text scale outgrows it).
          if (!compact) const SizedBox(height: 16),
          if (!compact)
          _rise(
            640,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _prop('Native renderers.',
                    ' SceneKit on iOS, Filament on Android.'),
                const SizedBox(height: 6),
                _prop('One Dart scene graph.',
                    ' flutter_scene documents, loaded as-is.'),
                const SizedBox(height: 6),
                _prop('PBR, physics, particles.',
                    ' No Flutter renderer required.'),
              ],
            ),
          ),
          SizedBox(height: compact ? 18 : 24),
          _rise(
            740,
            Column(
              children: [
                Button(
                  onPressed: () => widget.onOpen(AppScreen.dice),
                  shape: const StadiumBorder(),
                  color: _accent,
                  foregroundColor: _accentInk,
                  height: 52,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  child: const Text('Roll the dice'),
                ),
                const SizedBox(height: 6),
                Button(
                  onPressed: () => widget.onOpen(AppScreen.showcase),
                  color: const Color(0x00000000),
                  foregroundColor: _text2,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Text('Showcase'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'dart3d is a community plugin, not affiliated with or '
                  'endorsed by Presence Network Inc. DartNative and its logo '
                  'belong to their owners.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _prop(String lead, String rest) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15, color: _text2, height: 1.35),
          children: [
            TextSpan(
              text: lead,
              style: const TextStyle(fontWeight: FontWeight.w600, color: _text),
            ),
            TextSpan(text: rest),
          ],
        ),
      );
}

enum _DragSource { pan, scale }

/// Rolling frame / write-cost stats for the `DART3D_HERO_PERF` log.
final class _HeroPerf {
  final _dts = <double>[];
  final _transformUs = <int>[];
  final _glowUs = <int>[];
  double seconds = 0;

  void add(double dt, int transformUs, int? glowUs) {
    if (dt > 0) {
      _dts.add(dt * 1000);
      seconds += dt;
    }
    _transformUs.add(transformUs);
    if (glowUs != null) _glowUs.add(glowUs);
  }

  String report() {
    String pct(List<num> v, double p) {
      if (v.isEmpty) return '-';
      final s = [...v]..sort();
      return s[min(s.length - 1, (p * s.length).floor())].toStringAsFixed(1);
    }

    final slow = _dts.where((d) => d > 25).length;
    final fps = seconds > 0 ? _dts.length / seconds : 0;
    return 'ticks ${_dts.length} (${fps.toStringAsFixed(1)}/s) '
        'dt p50 ${pct(_dts, .5)} p95 ${pct(_dts, .95)} '
        'max ${pct(_dts, 1)} ms, >25ms $slow · '
        'xform p50 ${pct(_transformUs, .5)} max ${pct(_transformUs, 1)} us · '
        'glow n ${_glowUs.length} p50 ${pct(_glowUs, .5)} '
        'p95 ${pct(_glowUs, .95)} max ${pct(_glowUs, 1)} us';
  }

  void reset() {
    _dts.clear();
    _transformUs.clear();
    _glowUs.clear();
    seconds = 0;
  }
}
