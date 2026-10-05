# dart-native-explore

Dev environment for exploring **DartNative** (dartnative.com) — the commercial
Flutter-API-compatible framework by Presence Network (NOT the abandoned
`package:dart_native` bridge, NOT "Dart native" the platform/FFI toolkit).

Goal: evaluate DartNative for a dice parser app + custom scene-layer plugin
(3D dice rendering). Parser lives on the user's GitHub as an existing fork of
`dart_dice_parser` (pure Dart, zero porting needed). Scene plugin must NOT be
named `mythic_scene` or anything infringing on `flutter_scene` naming.

## Environment

- `dn` CLI: `/Users/jasonholt/zero/bin/dn` (DartNative 3.45.0-0.1.pre, engine
  cached in `~/zero/bin/cache`). Wraps flutter_tools, points at Zero engine.
  Framework `4c1cdb074e0` (2026-09-26 release). Update: `dn upgrade` prints
  the installer command (`curl -fsSL https://cdn.dartnative.com/install.sh | sh`);
  run it, then `dn upgrade` again.
- Xcode 27: `dn build ios --simulator` fails (`lipo -verify_arch` now takes one
  arch; flutter_tools passes two). Use `dn run -d <sim-id>` instead.
- PATH: `~/zero/bin` is appended LAST in `.zshrc`. DO NOT move it to the front
  — `zero/bin` contains its own `flutter`/`dart` binaries that would shadow the
  real Flutter at `~/repos/sdk/flutter/bin`. The `dn doctor` warnings about
  flutter/dart resolving outside the SDK are advisory; ignore them.
- `flutter`/`dart` commands always mean real Flutter (~/repos/sdk/flutter).
  Use `dn` for everything DartNative: `dn pub get`, `dn run`, `dn create`,
  `dn doctor`, `dn devices`, `dn emulators`.
- Xcode 27.0, Android SDK 37, CocoaPods 1.17 (brew) — doctor green except
  advisory warnings + a stale Android license check (deprecated sdkmanager
  path; licenses already accepted via Android Studio).

## Licensing (verified 2026-09-14)

- Official demos (playground, tutorials/*, plugins/*/example) run FREE with
  no account/key — license token expires 2026-09-17, renewable by re-running.
- Own apps run on a trial token; shipping requires subscription at
  dartpub.dev/framework → `dnk_...` key → `dn config --license-key` or
  `--dart-define=DN_LICENSE_KEY=dnk_...`.
- Lapsed subscription: shipped apps keep working; only new builds stop.

## Program state

- Active plan: `docs/program-v2.md` (tracks S/E/P/R/V, verification tiers
  T1–T4, decisions D1–D9). Start at its **Where we are** section. Why it was reset: `docs/program-audit-2026-09-28.md`.
- `docs/full-engine-program.md` is superseded; use it only for W17–W34 scope text.
- Parity: milestone flutter_scene 0.23.0 / scene 0.3.0 (bdero/flutter_scene
  `0dc6ee80`); final goal flutter_scene 0.24 / scene 0.4 (Track V), after
  the existing work is finished.

## Repo layout

- `dartnative/` — clone of github.com/DartNative/dartnative (docs, playground,
  34 plugin examples, `skills/dart-native` + `skills/dart-native-porting`
  LLM porting docs, `tutorials/build_a_plugin`).
- `.devin/skills/` — copies of DartNative's two official LLM skills
  (`dart-native` widget/API guide, `dart-native-porting` Flutter→DartNative
  playbook). They reference docs by repo-relative path — read those under
  `dartnative/docs/` (widgets.md, plugin_development.md, skia.md, etc.).

## LLM tooling (what DartNative officially gives an agent)

- `dart-native` skill — widget catalog + diffs + conventions; the doc says
  pair with porting skill for app migration.
- `dart-native-porting` skill — ordered playbook: pubspec swaps, main.dart
  anatomy, per-file diffs, iOS project surgery.
- `docs/plugin_development.md` — the view-plugin contract with copy-paste
  Swift/Kotlin templates; `docs/plugin_async_callbacks.md` for native→Dart.
- `tutorials/build_a_plugin` + `plugins/dartnative_share` — the canonical
  open-source example plugin (FFI + @_cdecl + JNI + restart-safe callbacks).
- dartpub.dev — plugin registry + docs hub (no llms.txt; docs mirror the repo).

## Devices

- iPhone 17 Pro sim: `C24F3C6D-A3A9-4FB7-978E-36E67EF55354` (iOS 27.0,
  402×874 pt; kept shut down between runs). Check with
  `xcrun simctl list devices available` — the id changes when
  simulators are recreated.
- Simulator on Xcode 27 (found 2026-10-05):
  - Booting one drives the Mac's 1-minute load to 150–330 for about
    five minutes. Boot once per session, wait for the load to settle
    before building or timing, and shut down only when done.
  - Don't use `xcrun simctl bootstatus -b` (it hung for 18 minutes).
    Poll `xcrun simctl list devices booted` instead.
  - There is no Simulator.app. `DeviceHub.app` (inside Xcode.app)
    replaces it; quitting it shuts down every booted simulator, so
    don't open it.
  - `simctl` cannot rotate a device or inject touches. Touches go
    through the session's iOS-simulator tool (pass the device id on
    every call; in landscape its coordinates stay the portrait
    device's: UI point (x, y) is device (y, 874 − x)). Rotation needs
    the operator or a rotation method they have approved.
  - `dn run` on the simulator is a debug build.
- Physical iOS 27 devices: "Jason's iPad", "Holtnet" (wireless)
- Physical Android: Nothing A142 ("Pacman"), serial `00064149A002033`,
  Mali-G610 / GLES 3.2. `dn devices` doesn't list it; pass
  `-d 00064149A002033` to `dn run` and it works.
- Physical Android tablet: Amazon Fire KFTUWI, serial `GN434J02409203LD`,
  Android 11 (API 30), Mali-G52 MC2 / GLES 3.2 / Vulkan 1.1, 1200×1920.
  The low-end floor; shared with other projects, so check with the
  operator before assuming it is free.
- Physical Android tablet: Wacom DTHA116 ("RosePlus"), serial
  `5FL21V6001199`, Android 14 (API 34), MediaTek MT8781 / Mali-G57 MC2 /
  GLES 3.2 / Vulkan 1.1, 8 GB, 1440×2200. A weak GPU with plenty of
  memory: dart3d files it LOW by GPU name. It is a drawing tablet with
  its owner's content on it and is kept rotation-locked in landscape
  (`accelerometer_rotation=0`, `user_rotation=1`): install and run our
  app, nothing else, and don't launch with `adb shell monkey` — monkey
  switches auto-rotate on (use `am start`, as `tool/cold_start.sh` does).
- Device policy (operator, 2026-10-01; Wacom and the simulator added
  2026-10-05): dart3d work runs on the A142, the Fire tablet, the
  Wacom tablet and **one** iOS simulator. One simulator booted on the
  Mac at a time across all projects: if another is booted it is
  someone else's — leave it and ask. Physical iOS devices and the iPad
  are still not cleared, and Android emulators stay off (Mac mini
  load). Before launching and before any
  `adb` input, confirm the foreground is
  `com.jasonholtdigital.dart3d_example` or the launcher.
- Android emulators: Pixel_Tablet_API36, Tablet_WXGA_API30/36, TomeKeeper_Beta6_Smoke

## Android build recipe (dart3d example)

- Java: Gradle 8.14 can't parse the host JDK 25 — `org.gradle.java.home`
  points at Homebrew JDK 21 in `example/android/gradle.properties`
  (already set; required for every Gradle invocation).
- Engine artifacts: dn resolves the custom engine from
  `https://cdn.dartnative.com` — `dn run` injects it; a bare Gradle
  assemble needs `FLUTTER_STORAGE_BASE_URL=https://cdn.dartnative.com`.
- Release is the tested path (`--release`); the SDK cache has no debug
  Android engine artifacts.
- Manual `adb install` hits the license gate — always launch via `dn run`.

## Scene-layer findings (for the plugin work ahead)

- No 3D plugin exists among the 34. flutter_scene/thermion CANNOT port
  (they need Flutter's renderer, which Zero deleted).
- Two viable scene paths: `dartnative_skia` `CanvasSurface` (GPU canvas,
  SkSL shaders, Metal/Vulkan — fake-3D/raymarched dice, no native code) or a
  custom view plugin hosting SceneKit SCNView on iOS / GLSurfaceView+Filament
  on Android (real 3D + physics). Plugin contract: `docs/plugin_development.md`
  (ViewType.claim → NativeElement → PluginMutation bytes → Swift @_cdecl
  provider / Kotlin DNAndroidPluginProvider).
- DartNative is iOS/Android only — no desktop, no web.
