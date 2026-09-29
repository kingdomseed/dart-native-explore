/// The example app's routing, kept free of widgets so it can be unit
/// tested: which screen boots, where the hero leads, and where back goes.
library;

/// The app's screens.
enum AppScreen {
  /// The launch hero — the 3D DartNative logo and the way into the app.
  hero,

  /// The dice table ("Roll the dice" on the hero).
  dice,

  /// The `flutter_scene` corpus viewer ("Showcase" on the hero).
  showcase,

  /// The deterministic verification scene. Not user-facing: reachable
  /// only by booting with `--dart-define=DART3D_SCENE=harness`.
  harness,

  /// The chrome-free logo capture view. Not user-facing: reachable only
  /// by booting with `--dart-define=DART3D_SCENE=reel`.
  reel,
}

/// The current screen and the moves between screens a user can make.
final class AppRoute {
  /// Boots from the `DART3D_SCENE` / `DART3D_MODEL` defines: a model
  /// boots the showcase with that item; an unknown or empty scene
  /// boots the hero.
  AppRoute.boot({String scene = '', String model = ''})
    : _screen = model.isNotEmpty
          ? AppScreen.showcase
          : switch (scene) {
              'dice' => AppScreen.dice,
              'showcase' || 'gallery' => AppScreen.showcase,
              'harness' => AppScreen.harness,
              'reel' => AppScreen.reel,
              _ => AppScreen.hero,
            };

  AppScreen _screen;

  /// The screen on display.
  AppScreen get screen => _screen;

  /// Whether back has somewhere to go — the hero, from the two screens
  /// it opens. The hero and the define-only screens have no back.
  bool get canGoBack =>
      _screen == AppScreen.dice || _screen == AppScreen.showcase;

  /// Opens [next] from the hero. Only [AppScreen.dice] and
  /// [AppScreen.showcase] are reachable this way; anything else, or a
  /// call off the hero, is refused and returns false.
  bool open(AppScreen next) {
    if (_screen != AppScreen.hero) return false;
    if (next != AppScreen.dice && next != AppScreen.showcase) return false;
    _screen = next;
    return true;
  }

  /// Returns to the hero when [canGoBack]; otherwise returns false.
  bool back() {
    if (!canGoBack) return false;
    _screen = AppScreen.hero;
    return true;
  }
}
