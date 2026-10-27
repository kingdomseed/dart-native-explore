# OpenGL directional shadow capture

The parent rebuilt the existing R3 probe for OpenGL and ran the native-default
directional cases on A142. No production source or probe source changed for
this build. `apk-sha256.txt` identifies the saved release APK.

`native.log` confirms `OPENGL (pref=1)`, native option defaults, separate
camera and shadow culling, and both capture-ready markers. The runtime
capture, display, and private-caster materials compile successfully.

`directional-dpcf.png` shows a green shadow region with a broad noisy edge.
`directional-pcf.png` shows a clean hard green footprint. Red marks lit
receiver pixels, while green marks shadowed receiver pixels. The caster's
visible geometry and its camera-depth rectangle are absent from these masks.
This matches the earlier Vulkan route experiment.

The raw shadow data is available on OpenGL. The separate production
`u2-catcher` ground footprint remains missing, so that failure is not evidence
that OpenGL cannot capture a shadow. The production receiver uses
`d3:instances`; its material capability mismatch is tracked by issue #59.
That mismatch is a source-supported next correction, not an established
cause of the missing footprint.

These are live RGB capture experiments. They do not establish a scalar mask,
transparent baked display, frozen cache, blur, refresh, or spot-light capture
on OpenGL. Those remain runtime checks for the production implementation.
The app and native log stream stopped. The app PID was absent and the
launcher was foreground. No device settings changed.
