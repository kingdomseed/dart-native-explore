// The harness scene-generation timer owner (PR #8/#9 review threads:
// nested phase timers were not cancellable, so a scene switch let old
// callbacks write stale ids into the replacement scene).

import 'dart:async';

import 'package:dart3d_example/phase_timers.dart';
import 'package:test/test.dart';

Future<void> pump(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('cancelAll stops pending one-shots, nested ones included', () async {
    final timers = PhaseTimers();
    final fired = <String>[];
    timers.after(const Duration(milliseconds: 10), () {
      fired.add('outer');
      // A phase's nested follow-up, scheduled from inside the kick.
      timers.after(const Duration(milliseconds: 40), () => fired.add('inner'));
    });
    await pump(25);
    expect(fired, ['outer']);
    expect(timers.active, 1);
    timers.cancelAll();
    await pump(60);
    expect(fired, ['outer']);
    expect(timers.active, 0);
  });

  test('after cancelAll, new timers are inert', () async {
    final timers = PhaseTimers()..cancelAll();
    var ran = false;
    final t = timers.after(Duration.zero, () => ran = true);
    final p = timers.periodic(
      const Duration(milliseconds: 1),
      (_) => ran = true,
    );
    await pump(10);
    expect(ran, isFalse);
    expect(t.isActive, isFalse);
    expect(p.isActive, isFalse);
  });

  test(
    'periodic timers stop on cancelAll and release on self-cancel',
    () async {
      final timers = PhaseTimers();
      var ticks = 0;
      timers.periodic(const Duration(milliseconds: 5), (t) {
        if (++ticks == 2) t.cancel();
      });
      await pump(40);
      expect(ticks, 2);
      expect(timers.active, 0);

      var ticks2 = 0;
      timers.periodic(const Duration(milliseconds: 5), (_) => ticks2++);
      await pump(12);
      timers.cancelAll();
      final at = ticks2;
      await pump(30);
      expect(ticks2, at);
    },
  );

  test('owned subscriptions cancel with the generation', () async {
    final timers = PhaseTimers();
    final events = StreamController<int>.broadcast();
    final seen = <int>[];
    timers.own(events.stream.listen(seen.add));
    events.add(1);
    await pump(1);
    timers.cancelAll();
    events.add(2);
    await pump(1);
    expect(seen, [1]);
    // Handed over late: cancelled immediately.
    timers.own(events.stream.listen(seen.add));
    events.add(3);
    await pump(1);
    expect(seen, [1]);
    await events.close();
  });

  test('fired timers leave the live set', () async {
    final timers = PhaseTimers();
    timers.after(const Duration(milliseconds: 1), () {});
    expect(timers.active, 1);
    await pump(10);
    expect(timers.active, 0);
  });
}
