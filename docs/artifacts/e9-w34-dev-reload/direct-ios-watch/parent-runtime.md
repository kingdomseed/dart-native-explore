# Direct iOS authored-file watch experiment

FAILED at the watch capability boundary on 2026-10-27. The real application
built and launched on the approved iPhone17Pro simulator, but `Directory.watch`
threw before the first authored-file read. This is not a successful reload or
file-access result. No production correction was made.

`parent-run.log` records:

```text
FileSystemException: File system watching is not supported on this platform, path = ''
```

The parent inspected the device screen and retained
`parent-watch-unsupported.png`. The footer shows that same error and the scene
is empty. The host-generated authored file exists at the explicit supplied
path. The probe subscribes to the directory before `_read`, so failure proves
neither that the app can read the host file nor that it cannot. No later
material/environment/malformed-input save was attempted in the app.

The parent reran both focused host file/controller tests successfully. Those
tests exercise macOS file events and controller mutations, not iOS watch
support. The native build completed in20.3s; that is a build receipt, not a
reload-latency result. The worker's49 combined regressions, analysis and generic
build remain supplied source/build evidence.

## Platform evidence and plan mismatch

The installed SDK's `file_system_entity.dart:430` documents platform-dependent
watch implementations and describes macOS FSEvents, Windows and Linux. Its
native watcher is external. The current upstream Dart implementation explicitly
returns false for `FileSystemWatcher::IsSupported` on iOS, corroborating the
observed failure. This source is current upstream, not a claim that the exact
DartNative engine commit was inspected:

- [Dart filesystem watcher source, iOS branch](https://github.com/dart-lang/sdk/blob/main/runtime/bin/file_system_watcher_macos.cc#L324-L340).
- [Dart watch API](https://api.dart.dev/dart-io/FileSystemEntity/watch.html).
- [Historical upstream iOS report](https://github.com/flutter/flutter/issues/99456), closed as a Dart core-library concern.

The E9 row specifies iOS first with Dart I/O watching and `dn run` reload; the
tested interpretation, watching inside the iOS app, is unavailable. Android's
same row already assigns filesystem watching to a host tool. A host-owned
watcher is the next design candidate for both platforms. No transport,
polling loop, native binding, SDK upgrade or new scene command was added here.
The exact host-to-app route still needs source grounding and proof.

## Source and cleanup

Observed source55 archive SHA-256:
`1bcb8709ab37adba22e8e79b0c64177a6612b2ae543295378ead450c2ded7383`.
Five-file diagnostic patch SHA-256:
`28da878f73044f76884b3578a48f8a3fb5e923667c28b8b194f55fb1cadde4ab`.
`parent-source-sha256.txt` records the observed source. All five probe hashes,
50 unowned production snapshot paths and recorded locks matched before run.

The parent stopped its app and filtered logger and shut down the simulator.
Fresh `simctl list devices booted` showed no booted devices. The exact patch
was reversed; all52 accepted production hashes and recorded lock hashes match
again, and `git diff --check` passes. Three probe-only Dart files are absent.
The unused malformed-save script was deleted. Evidence, the initial authored
file, source archives and ignored build/package-resolution outputs are kept.
No recording was started. No commit, PR or external-system mutation occurred.

Simulator host-file access, actual file-event delivery, visible incremental
reload, error retention/recovery, Android transport, debug views and latency
remain NOT_RUN. E9 and Track E remain open.
