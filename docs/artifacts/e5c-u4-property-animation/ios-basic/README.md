# U4 basic iOS property-animation proof

The basic opaque, untextured, primary-view lane ran on the approved iPhone17Pro
simulator at high quality. Shared material color, directional-light intensity,
camera FOV, pause/seek/stop/weight controls and playback were observed. This
does not complete U4 or the program verification matrix.

## Observed values

Temporary observation code read the actual SCNMaterial KVC uniform,
SCNLight.intensity and SCNCamera.fieldOfView after the existing sampler wrote
them. It did not supply samples or change playback. The exact executed
SceneViewHost.observation.swift, observation-native-sha256.txt and original
SceneViewHost.baseline.swift are retained in the private pickup below. The native
light value uses the existing directional conversion; document-unit values
are logged separately.

| Control | Native material factor | Document intensity | Native light intensity |
|---|---|---:|---:|
| Seek0, weight1 | [1,0,0,1] | 2 | 636.6197723675814 |
| Seek1, weight1 | [.5,0,.5,1] | 4 | 1273.2395447351628 |
| Seek2, weight1 | [0,0,1,1] | 6 | 1909.859317102744 |
| Seek1, weight.25 | [.875,.75,.875,1] | 1.75 | 557.0423008216337 |
| Stop, weight.25 | [1,.75,.75,1] | 1.25 | 397.88735772973837 |

Separate camera mode returned45°,67.5° and90° at Seek0/1/2. Its screenshots
show three visible faces, with first-face widths75,47 and32 pixels respectively.
All faces remain above the controls. The property-only clips reported zero
native TRS targets throughout the recorded observations. Fixed authored camera
transforms are a source/fixture fact; this was not a separate native pose probe.

analyze-native.dart checks eight literal observations at tolerance1e-6 and
requires every logged TRS target count to be zero. native-checks.json retains
expected/observed values and total observation counts. It parses actual logs;
it does not duplicate the production interpolation code.

## Captures and playback

color-t0/t1/t2.png show the same shared pair red, purple and blue while the
independent neutral face brightens. color-quarter-t1.png shows the weighted
rest contribution. camera-t0/t1/t2.png show the separate framing changes.
The parent inspected each image and both video contact sheets. The color video
has14 changed-frame cells over95.0s; camera has24 cells over69.6s. These are
sampled playback observations, not latency/frame-rate/performance measurements.
The camera Play action exceeded the driver's settle budget while the camera
was moving; a fresh snapshot showed Pause, and the subsequent Pause succeeded.

After removing all observation code and restoring both baseline native hashes,
the clean app ran with DART3D_U4_BARE_IDS=true. That route removes the selected
clip then sends a raw bare-ID upsert, so an old correct definition cannot mask
rejection. Seek0/1 rendered the expected red/purple states. raw-clean-t0/t1.png
retain them. Comparing the250×130 scene crop at(80,280) to canonical Seek1
found0 changed pixels and maximum channel difference0. This also checks the
uninstrumented source. The earlier prefix failure was source-traced; no
failing-before native image was captured for it.

analyze-images.swift decodes PNGs with NSBitmapImageRep and converts samples to
sRGB. Shared-face center samples match; camera bounds shrink monotonically.
image-checks.json retains those observations. They are screenshot-space
measurements, not calibrated linear-color or photometric claims.

## Commands and source

All three runs used /Users/jasonholt/zero/bin/dn from dart3d/example:

```text
dn run -d C24F3C6D-A3A9-4FB7-978E-36E67EF55354 --no-pub
  --dart-define=DART3D_SCENE=showcase --dart-define=DART3D_MODEL=u4
  --dart-define=DART3D_QUALITY=high
```

The commands were one line. Camera mode additionally used
DART3D_U4_CAMERA=true; the clean bare-ID mode instead used
DART3D_U4_BARE_IDS=true. color-light-run.log, camera-run.log and raw-clean-run.log
record completed native builds and Application finished. Matching *-native.log
files contain the plugin's unified-log stream. These filtered logs are not a
global crash audit. Native support reporting remains deliberately unadvertised;
the existing required-feature warning is not counted as a native playback pass.

Parent focused fixture tests passed8 cases and example analysis was clean.
Source reviews passed for Dart, both native platforms and the fixture. Android
compilation/13 Gradle-focused tests are recorded in its separate parent-r2
directory, not promoted to Android runtime proof.

Independent Codex audit of this archived43-path BASIC lane passed. It verified
the hashes and independently recomputed native values, image bounds/crop and
video decoding/playback observations. Its report and receipts are retained at
`/private/tmp/dart3d-e5c-u4-ios-basic-review-20261027/r1/`. The saved auxiliary
HTML mislabeled1.75 as native intensity; that label now says document-unit
intensity and gives the actual native value557.04. The authoritative table and
JSON were already correct. No source, sample, image or runtime result changed.
This audit covers the archive above; later material/alpha changes have a
separate review. The auditor did not run fresh builds, tests or devices.

The full source archive, exact probe sources and videos remain at
`/private/tmp/dart3d-e5c-u4-runtime-20261027/ios/`; the repository evidence copy
contains the smaller logs, PNGs, analyses and manifests. Its source.tgz SHA256:
d949afac5ca46506e7b7b03c43b9ece36375c7df887d60885bdf4a000b4b179f.
Its43 clean source paths replay from the reviewed41-path snapshot plus fixture
patch. source-sha256.txt and replay-proof.log identify the exact result. Numeric
runs differ from that clean source only by the retained observation-only Swift
probe; the final bare-ID run used the clean source. No shader/probe remains in
production source, and baseline-native-sha256.txt verifies restoration.

## Remaining gates and cleanup

Textures, alpha, snapshots, variants, foreign rebinds, deferred/replaced texture
behavior, area/point/spot native light units, multi-view/RT projection and general
host lifecycle are not established by this lane. Android live checks, full
T2 smoke, T4 approval and whole-U4 acceptance remain open. The older simulator
2xAA failure is unchanged; these observations cover high quality only.

All three own app runs and native log streams stopped; both recordings exported.
The approved simulator shut down, confirmed by a fresh empty booted-device
listing. A142 safe foreground inspection still showed Google account activity;
it received no input. No physical iOS device or other simulator was used.
No commit, push, issue/PR mutation or external media upload occurred.

Exact probes, source archive, scripts, logs, PNGs, videos, contact sheets and
hashes are retained. Replay scratch was removed. Task-isolated Gradle caches
and generic-build DerivedData remain for subsequent accepted feature checks.
