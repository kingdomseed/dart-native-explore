import 'dart:async';

/// Owns every wall-clock timer one harness scene generation schedules —
/// the outer `+N s` phase kicks and each phase's nested follow-ups — so
/// a scene switch, reload, or dispose can cancel all of them at once.
///
/// Before this, the nested timers inside each phase were fire-and-forget:
/// switching scenes mid-phase left callbacks that wrote stale ids into
/// the replacement document or called `MediaQuery.of` on a disposed
/// context. After [cancelAll], [after]/[periodic] hand back an inert,
/// already-cancelled timer, so a late-running callback that schedules
/// more work can't resurrect the old generation.
final class PhaseTimers {
  final Set<Timer> _live = {};
  final List<StreamSubscription<Object?>> _subs = [];
  bool _cancelled = false;

  /// Timers scheduled and not yet fired or cancelled.
  int get active => _live.length;

  /// Whether [cancelAll] has run — the generation is dead.
  bool get isCancelled => _cancelled;

  /// A one-shot timer owned by this set.
  Timer after(Duration delay, void Function() callback) {
    if (_cancelled) return _inert();
    late final Timer timer;
    timer = Timer(delay, () {
      _live.remove(timer);
      if (_cancelled) return;
      callback();
    });
    _live.add(timer);
    return timer;
  }

  /// A periodic timer owned by this set. Cancelling the returned timer
  /// from inside [callback] (the usual loop exit) releases it here too.
  Timer periodic(Duration period, void Function(Timer timer) callback) {
    if (_cancelled) return _inert();
    final timer = Timer.periodic(period, (t) {
      if (_cancelled) {
        t.cancel();
        return;
      }
      callback(t);
      if (!t.isActive) _live.remove(t);
    });
    _live.add(timer);
    return timer;
  }

  /// Ties [sub] to this generation: [cancelAll] cancels it (a phase's
  /// own cleanup timer may never run once the generation dies). A sub
  /// handed over after [cancelAll] is cancelled immediately.
  StreamSubscription<T> own<T>(StreamSubscription<T> sub) {
    if (_cancelled) {
      sub.cancel();
    } else {
      _subs.add(sub);
    }
    return sub;
  }

  /// The first event of [stream] matching [test] within [timeout], or
  /// null on timeout. The listener is owned by this generation: it is
  /// cancelled on a match, on timeout, and by [cancelAll] (the returned
  /// future then never completes). Unlike `firstWhere(...).timeout(...)`,
  /// whose inner subscription outlives the timeout, nothing is left
  /// listening afterwards.
  Future<T?> firstWithin<T>(
    Stream<T> stream,
    bool Function(T event) test,
    Duration timeout,
  ) {
    final done = Completer<T?>();
    if (_cancelled) return done.future;
    late final StreamSubscription<T> sub;
    late final Timer timer;
    void finish(T? value) {
      if (done.isCompleted) return;
      timer.cancel();
      _live.remove(timer);
      sub.cancel();
      _subs.remove(sub);
      done.complete(value);
    }

    sub = own(
      stream.listen((event) {
        if (test(event)) finish(event);
      }),
    );
    timer = after(timeout, () => finish(null));
    return done.future;
  }

  /// Cancels every live timer and owned subscription, and refuses new
  /// ones.
  void cancelAll() {
    _cancelled = true;
    for (final t in _live) {
      t.cancel();
    }
    _live.clear();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  static Timer _inert() => Timer(Duration.zero, () {})..cancel();
}

/// Whether a settle event re-arms the harness demo's automatic
/// re-throw. On by default; the measurement lanes suspend it for the
/// rest of the scene generation so a lane's own one-shot roll (W25's
/// dice-regression close-out) can't restart the loop under a later
/// lane (W18). A scene reload resumes it.
final class AutoRerollGate {
  bool _suspended = false;

  /// Whether the next settle should schedule another throw.
  bool get rearmAfterSettle => !_suspended;

  /// Stops settles from re-arming the loop.
  void suspend() => _suspended = true;

  /// Restores the self-running loop (new scene generation).
  void resume() => _suspended = false;
}
