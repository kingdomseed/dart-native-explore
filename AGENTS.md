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

- iPhone 17 Pro sim: `9151BBE4-8453-4F3F-8FD6-17535A25A18E` (booted,
  playground running)
- Physical iOS 27 devices: "Jason's iPad", "Holtnet" (wireless)
- Physical Android: Nothing A142 ("Pacman"), serial `00064149A002033`,
  Mali-G610 / GLES 3.2. `dn devices` doesn't list it; pass
  `-d 00064149A002033` to `dn run` and it works.
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
