// The app shell's routing (`app_route.dart`): the hero leads to Dice
// and Showcase and back leads home; the harness and the reel are
// reachable only through the DART3D_SCENE boot define.

import 'package:dart3d_example/app_route.dart';
import 'package:test/test.dart';

void main() {
  group('boot', () {
    test('no define boots the hero', () {
      expect(AppRoute.boot().screen, AppScreen.hero);
      expect(AppRoute.boot(scene: 'hero').screen, AppScreen.hero);
      expect(AppRoute.boot(scene: 'bogus').screen, AppScreen.hero);
    });

    test('DART3D_SCENE picks the screen', () {
      expect(AppRoute.boot(scene: 'dice').screen, AppScreen.dice);
      expect(AppRoute.boot(scene: 'showcase').screen, AppScreen.showcase);
      expect(AppRoute.boot(scene: 'gallery').screen, AppScreen.showcase);
      expect(AppRoute.boot(scene: 'harness').screen, AppScreen.harness);
      expect(AppRoute.boot(scene: 'reel').screen, AppScreen.reel);
    });

    test('DART3D_MODEL boots the showcase whatever the scene', () {
      expect(
        AppRoute.boot(scene: 'harness', model: 'dash').screen,
        AppScreen.showcase,
      );
    });
  });

  group('navigation', () {
    test('hero → dice → back returns to the hero', () {
      final route = AppRoute.boot();
      expect(route.canGoBack, isFalse);
      expect(route.open(AppScreen.dice), isTrue);
      expect(route.screen, AppScreen.dice);
      expect(route.canGoBack, isTrue);
      expect(route.back(), isTrue);
      expect(route.screen, AppScreen.hero);
    });

    test('hero → showcase → back returns to the hero', () {
      final route = AppRoute.boot();
      expect(route.open(AppScreen.showcase), isTrue);
      expect(route.screen, AppScreen.showcase);
      expect(route.back(), isTrue);
      expect(route.screen, AppScreen.hero);
    });

    test('back from a booted dice screen still lands on the hero', () {
      final route = AppRoute.boot(scene: 'dice');
      expect(route.back(), isTrue);
      expect(route.screen, AppScreen.hero);
    });

    test('the hero cannot open the harness or the reel', () {
      final route = AppRoute.boot();
      expect(route.open(AppScreen.harness), isFalse);
      expect(route.open(AppScreen.reel), isFalse);
      expect(route.screen, AppScreen.hero);
    });

    test('dice and showcase do not open each other', () {
      final route = AppRoute.boot(scene: 'dice');
      expect(route.open(AppScreen.showcase), isFalse);
      expect(route.screen, AppScreen.dice);
    });

    test('the define-only screens and the hero have no back', () {
      for (final scene in ['harness', 'reel', 'hero']) {
        final route = AppRoute.boot(scene: scene);
        final before = route.screen;
        expect(route.canGoBack, isFalse, reason: scene);
        expect(route.back(), isFalse, reason: scene);
        expect(route.screen, before, reason: scene);
      }
    });
  });
}
