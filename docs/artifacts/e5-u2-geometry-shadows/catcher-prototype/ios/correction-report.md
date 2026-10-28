# iOS shadow-footprint probe correction

The throwaway probe now configures a capture-owned SceneKit scene. The full generic arm64 simulator build passes. GPU/runtime NOT_RUN. This does not establish a clean shadow footprint or prove that either reported exception has disappeared.

## Cause supported by evidence

The supplied transparent-crash-system.log line 645 reports `Modifying properties of a view's layer off the main thread is not allowed`. Lines 653 through 661 contain SCNView _updateOpacity, KVO notification, ShadowCatcherProbe.beginCapture, and SceneViewHost.renderer(_:willRenderScene:atTime:).

Source inspection connects that stack to `scene.background.contents = UIColor.clear` in beginCapture. The scene is also installed on the active SCNView and its siblings. The probe additionally changes shared materials, caster categories, and camera clipping. Restoring values after capture cannot prevent a synchronous KVO side effect or protect an overlapping sibling draw. The shared background write is the evidenced first fault in this path.

The log separately records an NSInvalidArgumentException for `-[SCNCamera _fastCStringContents:]` near line 684. Its exact cause remains UNKNOWN. The evidence does not justify calling SceneKit broken or claiming that the KVO fault fully explains this exception.

I inspected ios-control-dir-alpha.png. It is baseline evidence of a sampled caster over a gray receiver field, not proof of clean transparency.

## Correction

Exactly three files differ from the imported snapshot.

- ShadowCatcherProbe.swift owns the capture scene, camera, copied attachments, source-to-copy node pairs, target key, and variant. It configures capture properties once. Each capture reads source presentation transforms and writes copied node transforms. Display mask and backdrop nodes are removed from the capture hierarchy to avoid sampling the target being written.
- RenderTargets.swift selects that scene and camera only for the probe target. The existing scheduler, Metal textures, command buffer, and normal renderer path remain in use. Logging now says transparent RGBA clear and leaves footprint transparency unverified.
- SceneViewHost.swift installs the probe after stage camera settings. It removes beginCapture/endCapture. Teardown drops the probe without restoration because the probe never changes source properties.

Each cloned node receives copied geometry, materials, camera, and light attachments. Apple documents that clone() alone shares these attachments. Copying them keeps capture-specific changes out of the active screen scene. Immutable geometry buffers and read-only environment texture contents remain shared.

The data shape is one capture scene with source-to-copy node pairs instead of saved property values and an active/restored phase.

No Dart file changed. All eight selectors, directional control first, next-button flow, source/mask comparison, both positive pi/2 camera rotations, blend display plane, and white backdrop remain byte-identical to the import. The variants remain control, camera clipping, caster color-write exclusion with depth writes disabled, and caster category-cull exclusion, for both light kinds.

The receiver remains shadowOnly with alpha blending. This isolates the submitted experiment without adding an alpha conversion shader or claiming that transparent clear removes the receiver field. Installed SCNMaterial.h lines 81 through 85 recommend multiply blending for composing shadowOnly over a background. They do not promise a reusable transparent-alpha footprint.

The clone captures attachment state at installation and follows transforms afterward. This is limited to this fixture and selector reloads. It is not synchronization for arbitrary live material or light-property changes and is not production baked-catcher architecture.

## Checks

- Archive SHA256 matches cc6cd24566d3958a20709ee6d12d40411cc5033e877465ee948ae06042c28781.
- All 20 listed paths matched archive contents byte for byte before edits. The archive also contains AppleDouble metadata entries. imported-sha256.txt records the listed hashes.
- /Users/jasonholt/zero/bin/dn analyze in dart3d/example passed with `No issues found! (ran in 2.7s)` and exit 0.
- The first generic build failed before Swift compilation because this fresh checkout lacked CocoaPods support files. The failing line was `Unable to load contents of file list: '/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-input-files.xcfilelist'`.
- pod install succeeded. logs/pod-install.log records the result. It produced no additional tracked changes relative to the imported snapshot. The inherited Podfile.lock and dn_plugins.lock remain preserved.
- The retry passed with `** BUILD SUCCEEDED **` at line 6710 of logs/xcodebuild-ios-sim-arm64.log. Lines 4714 and 4716 show arm64 compilation of ShadowCatcherProbe.swift. The build compiled the full plugin and Runner.
- git diff --check passed.
- verify-patch.sh applied correction.patch to the saved imported baseline and verified all four owned file hashes, including the unchanged Dart file. logs/patch-replay.log records all four as OK.
- Comparing every imported path after the build found exactly the three owned Swift files changed. Imported geometry, Android, fixture, test, and lockfile contents remain unchanged.

The successful build command ran in dart3d/example/ios without booting a simulator.

```sh
FLUTTER_ROOT=/Users/jasonholt/zero xcodebuild \
  -workspace Runner.xcworkspace -scheme Runner \
  -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator \
  -derivedDataPath /private/tmp/dart3d-e5-geometry-20261026/catcher-ios-correction-sol-r1/DerivedData \
  ARCHS=arm64 IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO build
```

## Remaining decision

GPU/runtime NOT_RUN. Source appearance during actual concurrent draws, absence of both exceptions, texture orientation, receiver alpha, and all eight shadow/exclusion results remain unverified.

Run the corrected directional control first, then compare all eight variants through the preserved switcher. A valid control must show caster color and its shadow in the sampled target while the source stays normal. Transparent clear alone does not prove the absence of a receiver field. If the control still has an opaque field, record it before interpreting an exclusion variant as a clean footprint.

## References and principles

[Apple SCNNode.clone documentation](https://developer.apple.com/documentation/scenekit/scnnode/clone%28%29) explains shared attachments and independent geometry copies. Installed Xcode iPhoneSimulator.sdk SceneKit.framework/Headers/SCNNode.h lines 88 through 95 documents the same contract.

I read the repo README, example README, current program guide, supplied crash log, installed SceneKit skill, prototype playbook, and requested poteto-mode instructions. The checkout lacks dartnative/docs/plugin_development.md despite the project guide naming it.

Attack the Premise changed the correction from another clear/blend adjustment to removal of active-scene mutation. Fix Root Causes removed the KVO-producing shared background write instead of dispatching it or suppressing the exception. Separate Before Serializing Shared State led to copied attachments instead of locks or asynchronous swaps. Model the Domain replaced restoration state with an owned scene and node pairs.

## Artifacts and preserved work

correction.patch is relative to the imported crashing snapshot, not git HEAD. Its SHA256 is 6405789ccd66e1e9b347f7603121b9832e00c1bc2d850ff52463f0967ababcea.

The artifact directory retains this report, patch, imported owned baseline tar, import and corrected-file hash manifests, replay script, and build/pod/replay logs. The worktree retains corrected source, all imported work, and gitignored SDK/pod support files. No devices, simulator boots, adb, commits, pushes, or external mutations were used.

Generated DerivedData was removed after the successful build. No replay extraction directories remain.
