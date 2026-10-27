# Camera-facing catcher correction

The parent A142 OpenGL replay now shows a baked footprint for the existing
single-billboard receiver. The production build preserves the patch after
caster movement and updates it after an explicit same-ID material upsert.
Independent Codex source and evidence review reports PASS. The final E5
device matrix remains open.

## Before and after

The earlier [failure](../README.md#camera-facing-failure) records a missing
registration and zero Z extent. Full manifest decoding wrote fresh facing
specs into the installed host registry, then installation cleared them during
old-scene teardown. The cache also read the mesh's original flat bounds.

The correction stages facing specs on the fresh `Context`, aliases installed
state for surgical commands, and adopts the staged map after old teardown.
The facing receiver reads the current local renderable box. GPU mesh instances
retain the existing base-geometry bounds and first-instance transform path.

The temporary probe in PID 6427 reports this actual updated state.

```text
baked facing registered=true min=-1.8900788,-1.0352696,-0.9936733 max=1.8900788,1.0352696,0.9936733
```

[The probe image](probe-load.png) shows a footprint where the before view
had none. [The log](probe-native.log) and [temporary patch](probe.patch)
record the values. The parent then removed the probe and rebuilt the
production source. No diagnostic log or helper remains in production.

## Production replay

PID 6860 uses `DART3D_CATCHER_PATH=camera-facing`, OpenGL, medium quality.
The parent inspected these frames and the recording contact sheet.

- [Load](clean-load.png) shows a footprint with the default camera.
- A 1.2 pinch makes the fixture larger. It does not trigger another capture.
- [Caster moved](clean-caster-stale.png) retains the old footprint to its left.
- [Explicit refresh](clean-refreshed.png) updates that footprint beneath the
  moved caster.

[The run log](clean-run.log) records the public actions. [The native log](clean-native.log)
records exactly two 256-pixel captures, on load and explicit refresh, and no
fatal marker. The 11.5-second local recording decodes. Its
[24-cell contact sheet](facing-contact-sheet.png) shows movement followed by
refresh. [The receipt](video-receipt.json) records its local path and hash.
The [video is published](https://github.com/kingdomseed/dart-native-explore/releases/download/media-e5-u2/facing-journey.mp4)
as review media; its uploaded digest matches the local receipt.

The parent stopped the app after recording export, confirmed no app PID and
the Nothing launcher in front, then stopped its logcat process.

## Checks and limits

The parent Release JVM task records 162 cases, 147 passed, 15 existing
opt-in native-physics skips, no failures, and no errors. The parent clean
Release APK build passes. The fresh comment audit recommended three comment
removals, six net lines. The parent applied them. No comments were restored
or suppressions changed.

Only `FsceneRealizer.kt` and `Dart3dView.kt` differ from the reviewed r3
snapshot. The other 55 source/assets entries and both imported lockfiles
are unchanged. [The source manifest](source-assets-sha256.txt) records the
current tree and [the correction patch](correction.patch) records that delta.

The seven earlier consumer fixtures do not register facing geometry. Their
map remains empty and their ordinary/GPU bounds path is unchanged. Those
observed cases are reused for this correction. Vulkan rendering, full E5
smoke, and operator approval remain open.
These images do not establish numeric shadow parity or a native allocation
measurement.

The fresh Codex reviewer verified all 57 source hashes, both snapshot hashes,
the two intended asset deletions, and the exact two-file delta. Source review
covered full install, deferred realization, surgical rebuilds, removal, and
disposal. The reviewer inspected the five images, logs, and video receipt;
independent builds, tests, and device execution were NOT_RUN.

[The review](t3-thread://v1/thread:delegated-task:command%3Amcp%3Ad12b24be-d1fd-4c7a-88e7-3520d53747f6%3Adelegate-task%3Ae5-android-facing-consumer-review-sol-r1-20261027)
reports no material reachable P1/P2 findings.
