# Preparation completion ownership

The no-comments audit found that stop joins the raw preparation future while
receive separately catches its expected input errors. Cleanup therefore catches
the same FormatException to avoid reporting an already-handled input rejection.
The public trigger is stop while a sidecar preparation is settling. Ownership
belongs to the session's input boundary, not generic cleanup.

Keep the agreed active-preparation drain. Change only its stored outcome.

```dart
Future<SceneDocument?>? _preparing;
// One handled preparation future returns a candidate or a reported rejection.
// Unexpected programming failures still complete with their original error.
// _receive awaits it, clears ownership, then applies only a non-null candidate.
// stop joins that same handled future. Cleanup catches cancellation I/O only.
```

Alternative. Keep the raw future and a second handled-completion token. Rejected
because it duplicates lifecycle state and retains the current ownership problem.
Another alternative is a new result hierarchy. Rejected because a nullable local
candidate already distinguishes rejection without public types or extra layers.

No public API, controller semantics, transport or file schema changes. This is
the small accepted audit fix, implemented by parent. The existing real malformed
input and pending-read stop tests verify behavior after this ownership refactor.
The prototype's public behavior did not have a reproduced failure here.
