import 'package:dart3d/dart3d.dart';
import 'package:dartnative/dartnative.dart';

import 'dartnative_plugin_registrant.dart';
import 'u3_outline_views_scene.dart';

const _single = bool.fromEnvironment('DART3D_U3_OUTLINE_SINGLE');
const _msaa = bool.fromEnvironment('DART3D_U3_OUTLINE_TARGET_MSAA');
const _publishInUpdate = bool.fromEnvironment(
  'DART3D_U3_OUTLINE_PUBLISH_IN_UPDATE',
);
const _bindBeforeInstall = bool.fromEnvironment(
  'DART3D_U3_OUTLINE_BIND_BEFORE_INSTALL',
);
const _modeName = String.fromEnvironment(
  'DART3D_U3_OUTLINE_MODE',
  defaultValue: 'off',
);
const _bootMode = _modeName == 'outline'
    ? U3OutlineMode.outline
    : _modeName == 'control'
    ? U3OutlineMode.control
    : U3OutlineMode.off;

void main() {
  DartNativePluginRegistrant.registerAll();
  runApp(const _OutlineScreen());
}

class _OutlineScreen extends StatefulWidget {
  const _OutlineScreen();
  @override
  State<_OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends State<_OutlineScreen> {
  final _controller = SceneController();
  final _document = buildU3OutlineViewsDocument(
    single: _single,
    targetMsaa: _msaa,
    publishInUpdate: _publishInUpdate,
    bindBeforeInstall: _bindBeforeInstall,
    mode: _bootMode,
  );
  U3OutlineMode _mode = _bootMode;
  bool _cameraB = false;
  bool _playing = false;

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

  @override
  Widget build(BuildContext context) => Scaffold(
    brightness: Brightness.dark,
    backgroundColor: const Color(0xFF14171C),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SceneView(controller: _controller, quality: SceneQuality.high),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    for (final mode in U3OutlineMode.values)
                      Expanded(
                        child: Button(
                          title: mode.name,
                          variant: _mode == mode
                              ? ButtonVariant.filled
                              : ButtonVariant.plain,
                          onPressed: () {
                            setState(() => _mode = mode);
                            setU3OutlineMode(
                              _controller,
                              mode,
                              cameraB: _cameraB,
                              publishInUpdate: _publishInUpdate,
                              bindBeforeInstall: _bindBeforeInstall,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Button(
                        title: 'Set colors',
                        onPressed: () => setU3OutlineColors(_controller),
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: 'Clear',
                        onPressed: () => clearU3OutlineColors(_controller),
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: 'Render target',
                        onPressed: () => _controller.renderTexture(
                          _document.resources.values
                              .whereType<RenderTextureResource>()
                              .single
                              .id,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Button(
                        title: _cameraB ? 'Camera B' : 'Camera A',
                        onPressed: () {
                          setState(() => _cameraB = !_cameraB);
                          setU3OutlineMode(
                            _controller,
                            _mode,
                            cameraB: _cameraB,
                            publishInUpdate: _publishInUpdate,
                            bindBeforeInstall: _bindBeforeInstall,
                          );
                          setU3OutlineCameraPose(
                            _controller,
                            alternate: _cameraB,
                            single: _single,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: _playing ? 'Pause' : 'Play',
                        onPressed: () {
                          setState(() => _playing = !_playing);
                          final clip = _document.animations.keys.single;
                          if (_playing) {
                            _controller.playAnimation(
                              clip,
                              weight: 1,
                              loop: true,
                            );
                          } else {
                            _controller.pauseAnimation(clip);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: Button(
                        title: 'Rebind views',
                        onPressed: () =>
                            _controller.updateViews(_document.views),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_single ? "Host" : "Two siblings"}; target 96×72 ${_msaa ? "MSAA4x" : "none"}.\n'
                'Orange mesh + blue batch. Authored child stays unselected.\n'
                'Manual target changes only after Render target. Raw rows: U3OV logs.',
                style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
