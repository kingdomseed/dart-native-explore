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

  test('auto-reroll gate: suspended lanes never re-arm; reload resumes', () {
    final gate = AutoRerollGate();
    expect(gate.rearmAfterSettle, isTrue);
    gate.suspend(); // wLoose (+78 s)
    // Every later settle — wLoose's own rolls, W25's one-shot roll —
    // leaves the loop off.
    for (var i = 0; i < 4; i++) {
      expect(gate.rearmAfterSettle, isFalse);
    }
    gate.resume(); // _loadScene / _loadImported
    expect(gate.rearmAfterSettle, isTrue);
  });

  group('firstWithin (PR #14 4123065174)', () {
    test('firstWhere+timeout leaks its listener (the reported bug)', () async {
      final events = StreamController<int>.broadcast();
      await events.stream
          .firstWhere((e) => e == 1)
          .timeout(const Duration(milliseconds: 5))
          .then((_) {}, onError: (_) {});
      expect(events.hasListener, isTrue);
      await events.close();
    });

    test('timeout yields null and leaves nothing listening', () async {
      final timers = PhaseTimers();
      final events = StreamController<int>.broadcast();
      final got = await timers.firstWithin(
        events.stream,
        (e) => e == 1,
        const Duration(milliseconds: 5),
      );
      expect(got, isNull);
      expect(events.hasListener, isFalse);
      expect(timers.active, 0);
      await events.close();
    });

    test('a match completes and cancels the listener', () async {
      final timers = PhaseTimers();
      final events = StreamController<int>.broadcast();
      final f = timers.firstWithin(
        events.stream,
        (e) => e == 2,
        const Duration(seconds: 5),
      );
      events
        ..add(1)
        ..add(2);
      expect(await f, 2);
      expect(events.hasListener, isFalse);
      expect(timers.active, 0);
      await events.close();
    });

    test('cancelAll drops the listener mid-wait', () async {
      final timers = PhaseTimers();
      final events = StreamController<int>.broadcast();
      timers.firstWithin(
        events.stream,
        (e) => true,
        const Duration(seconds: 5),
      );
      expect(events.hasListener, isTrue);
      timers.cancelAll();
      expect(events.hasListener, isFalse);
      await events.close();
    });
  });
  group('bodies the settle lanes retire', () {
    test('the box kicked off the slab by its breaking joint', () {
      expect(harnessBodyNeverRests('j9.breakBox'), isTrue);
    });

    test('the unsleeping body, the motor plate and the whole chain', () {
      for (final name in [
        'w5NoRest',
        'j9.liftPlate',
        'j9.chainAnchor',
        'j9.chain1',
        'j9.chain4',
      ]) {
        expect(harnessBodyNeverRests(name), isTrue, reason: name);
      }
    });

    test('bodies that do come to rest stay', () {
      for (final name in [
        'die',
        'ball',
        'j9.breakAnchor',
        'j9.pendBob',
        'j9.doorPanel',
        'j9.weldA',
        'j9.genBox',
        'wlooseCcd',
      ]) {
        expect(harnessBodyNeverRests(name), isFalse, reason: name);
      }
    });
  });
}
