import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';

import 'dartnative_plugin_registrant.dart';
import 'u2_catcher_scene.dart';
import 'w34_debug_scene.dart';

const _liveCatcherChecks = bool.fromEnvironment('DART3D_W34_LIVE_CATCHER');
const _bakedCatcherChecks =
    !_liveCatcherChecks && bool.fromEnvironment('DART3D_W34_BAKED_CATCHER');
const _catcherChecks = _liveCatcherChecks || _bakedCatcherChecks;
const _materialChecks =
    !_catcherChecks && bool.fromEnvironment('DART3D_W34_MATERIALS');
const _consumerChecks =
    !_catcherChecks && bool.fromEnvironment('DART3D_W34_CONSUMERS');

void main() {
  DartNativePluginRegistrant.registerAll();
  runApp(const _DebugScreen());
}

class _DebugScreen extends StatefulWidget {
  const _DebugScreen();

  @override
  State<_DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<_DebugScreen> {
  final _controller = SceneController();
  final _document = buildW34DebugDocument(
    skinned: _consumerChecks,
    materials: _materialChecks,
    bakedCatcher: _bakedCatcherChecks,
    liveCatcher: _liveCatcherChecks,
    blendCaster: const bool.fromEnvironment('DART3D_W34_LIVE_BLEND_CASTER'),
  );
  late final _rig = _document.nodes.values.singleWhere(
    (n) => n.name == 'w34.rig',
  );
  late final _joint = _document.nodes.values.singleWhere(
    (n) => n.name == 'w34.joint',
  );
  SceneDebugChannel _channel = SceneDebugChannel.none;
  bool _wireframe = false;
  bool _edited = false;
  String _coverage = 'opaque';
  bool _rigPresent = true;
  bool _posed = false;
  bool _inset = false;
  bool _textured = true;
  bool _colored = true;
  bool _casterMoved = false;
  bool _lowQuality = false;
  late final _lightControls = W34LiveLightControls(_controller, _document);

  @override
  void initState() {
    super.initState();
    _controller.loadDocument(_document);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _edit() {
    if (_materialChecks) {
      editW34MaterialFamilies(
        _controller,
        _document,
        edited: _edited,
        textured: _textured,
        colored: _colored,
        coverage: _coverage,
      );
      return;
    }
    editW34DebugMaterial(
      _controller,
      _document,
      edited: _edited,
      coverage: _coverage,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    brightness: Brightness.dark,
    backgroundColor: const Color(0xFF111111),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SceneView(
            controller: _controller,
            quality: _lowQuality ? SceneQuality.low : SceneQuality.high,
            debugView: SceneDebugView(channel: _channel, wireframe: _wireframe),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    for (final channel in SceneDebugChannel.values.take(3))
                      Expanded(
                        child: Button(
                          title: channel == SceneDebugChannel.none
                              ? 'Off'
                              : channel.name,
                          variant: _channel == channel
                              ? ButtonVariant.filled
                              : ButtonVariant.plain,
                          onPressed: () => setState(() => _channel = channel),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    for (final channel in SceneDebugChannel.values.skip(3))
                      Expanded(
                        child: Button(
                          title: channel.name,
                          variant: _channel == channel
                              ? ButtonVariant.filled
                              : ButtonVariant.plain,
                          onPressed: () => setState(() => _channel = channel),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Button(
                      title: _wireframe ? 'Wire on' : 'Wire off',
                      fontSize: 12,
                      onPressed: () => setState(() => _wireframe = !_wireframe),
                    ),
                  ),
                  if (_catcherChecks) ...[
                    Expanded(
                      child: Button(
                        title: _casterMoved ? 'Caster B' : 'Caster A',
                        fontSize: 12,
                        onPressed: () {
                          setState(() => _casterMoved = !_casterMoved);
                          moveW34CatcherCaster(
                            _controller,
                            _document,
                            moved: _casterMoved,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _liveCatcherChecks ? 'Replace' : 'Refresh',
                        fontSize: 12,
                        onPressed: () => upsertU2CatcherMaterial(
                          _controller,
                          _document,
                          u2CatcherMaterial(_document),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Button(
                        title: _edited ? 'Factors B' : 'Factors A',
                        fontSize: 12,
                        onPressed: () {
                          setState(() => _edited = !_edited);
                          _edit();
                        },
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _coverage,
                        fontSize: 12,
                        onPressed: () {
                          const modes = ['opaque', 'mask', 'blend'];
                          setState(
                            () => _coverage =
                                modes[(modes.indexOf(_coverage) + 1) % 3],
                          );
                          _edit();
                        },
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: 'Capture',
                        fontSize: 12,
                        onPressed: () => _controller.renderTexture(
                          _document.resources.values
                              .whereType<RenderTextureResource>()
                              .single
                              .id,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Button(
                      title: 'Reload',
                      fontSize: 12,
                      onPressed: () {
                        if (_liveCatcherChecks) {
                          setState(_lightControls.reload);
                        } else {
                          _controller.loadDocument(_document);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_liveCatcherChecks) ...[
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        title: _lightControls.moved ? 'Light B' : 'Light A',
                        fontSize: 12,
                        onPressed: () => setState(_lightControls.togglePose),
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _lowQuality ? 'Low' : 'High',
                        fontSize: 12,
                        onPressed: () =>
                            setState(() => _lowQuality = !_lowQuality),
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _lightControls.present
                            ? 'Light on'
                            : 'Light off',
                        fontSize: 12,
                        onPressed: () =>
                            setState(_lightControls.togglePresence),
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _lightControls.alternate ? 'New B' : 'New A',
                        fontSize: 12,
                        onPressed: () => setState(_lightControls.replace),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (final (label, time) in [('Dim', 0.0), ('Bright', 2.0)])
                      Expanded(
                        child: Button(
                          title: label,
                          fontSize: 12,
                          onPressed: _lightControls.present
                              ? () => setState(() => _lightControls.seek(time))
                              : null,
                        ),
                      ),
                    Expanded(
                      child: Button(
                        title: _lightControls.playing ? 'Pause' : 'Play',
                        fontSize: 12,
                        onPressed: _lightControls.present
                            ? () => setState(_lightControls.togglePlayback)
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: 'Rest',
                        fontSize: 12,
                        onPressed: () =>
                            setState(_lightControls.releaseIntensityOverride),
                      ),
                    ),
                  ],
                ),
              ],
              if (_materialChecks)
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        title: _textured ? 'Texture on' : 'Texture off',
                        fontSize: 12,
                        onPressed: () {
                          setState(() => _textured = !_textured);
                          _edit();
                        },
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _colored ? 'Colors A' : 'Colors B',
                        fontSize: 12,
                        onPressed: () {
                          setState(() => _colored = !_colored);
                          _edit();
                        },
                      ),
                    ),
                  ],
                ),
              if (_consumerChecks)
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        title: _rigPresent ? 'Rig present' : 'Rig removed',
                        fontSize: 12,
                        onPressed: () {
                          final rig = _rig, joint = _joint;
                          setState(() => _rigPresent = !_rigPresent);
                          setW34RigPresent(
                            _controller,
                            _document,
                            rig,
                            joint,
                            present: _rigPresent,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _posed ? 'Pose raised' : 'Pose rest',
                        fontSize: 12,
                        onPressed: _rigPresent
                            ? () {
                                setState(() => _posed = !_posed);
                                poseW34Joint(
                                  _controller,
                                  _joint,
                                  posed: _posed,
                                );
                              }
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _inset ? 'Viewport inset' : 'Viewport full',
                        fontSize: 12,
                        onPressed: () {
                          setState(() => _inset = !_inset);
                          setW34Viewport(_controller, _document, inset: _inset);
                        },
                      ),
                    ),
                  ],
                ),
              Text(
                _liveCatcherChecks
                    ? 'Live footprint. ${_lightControls.cue}. Replace is material only.\n'
                          'Base color / metallic / roughness absent: magenta.'
                    : _bakedCatcherChecks
                    ? 'Baked footprint. Caster moves; cache stays frozen.\n'
                          'Refresh bakes current caster. Reload keeps its position.\n'
                          'Base color / metallic / roughness absent: magenta.'
                    : _materialChecks
                    ? 'Unlit left; sprite alpha / additive right.\n'
                          'Metallic / roughness absent inputs are magenta.\n'
                          'Capture is authored. Image textures only; RT alpha unproven.'
                    : 'PBR only. Native particles excluded in channel views.\n'
                          'Depth d/(1+d). Literals 0.125 / 0.5 / 0.875.\n'
                          'Capture saves authored target. Inspect lower panel in baseColor.',
                style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
