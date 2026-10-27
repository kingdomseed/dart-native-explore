# Final E5 verification

Verification is in progress on the integrated E5 source based on E4 merge
`4a75520`. These runs supplement the scoped feature evidence in the parent
manifest; they do not replace its before/after records.

Both package analyses report no issues. The package suite passes 332 tests
and the example suite passes 250 tests. The corresponding `package-*` and
`example-*` logs contain these final runs.

The A142 Vulkan harness completes W25's dice regression and W18's final
particle lane. A real hero-to-dice journey rolls and settles with readout 63.
The `a142-vulkan-*.png` images and matching run/native logs record those
surfaces, with Vulkan pref2 and no fatal markers. Both app runs were stopped.

The A142 OpenGL harness also completes W25 and W18. Its real dice roll
settles at 98. The iPhone 17 Pro simulator completes both harness lanes
and a hero-to-dice roll. Its log first reports 79, then 85 after another
settled event; `ios-dice.png` shows 85. The logs retain both readouts.
No fatal/crash marker was found in these native logs. Both iOS app runs
ended normally and the simulator was shut down.

The OpenGL dice image contains bright white regions on two faces and the
rim. The older E4 dice screenshot has different poses, so it does not
establish whether this is a regression. Dice materials and scene files
are unchanged. This smoke check establishes roll/settle and crash behavior,
not material-image parity; the image remains available for operator review.

Fire and Wacom final smoke checks remain NOT_RUN. Only the A142 is connected
to the mini at this checkpoint. The MacBook Pro did not answer SSH, and
Tailscale reports it offline. Tablet connection was requested.

Final operator screenshot approval remains open. No E5 PR or merge exists
at this checkpoint.

## Final Android feature checks

The `a142-<backend>-spot-on.png` captures show a spotlight shadow on the lit
receiver with the final native shadow options. Native logs confirm OpenGL
pref1 and Vulkan pref2, medium quality, and a 1024-pixel shadow map.

Vulkan PID 9962 combines the camera-facing receiver with the tied-directional
fixture. Load shows a footprint, moving the caster retains it, and an explicit
same-ID material upsert updates it. The three `a142-vulkan-facing-tied-*.png`
images show those states. The native log records exactly two 256-pixel
captures and no fatal marker. This verifies the two reviewed corrections on
Vulkan; it does not claim numeric image parity.

Vulkan PID 10760 uses a stronger noncasting directional above a weaker
casting directional. Both `a142-vulkan-primary-unshadowed-baked.png` and
`a142-vulkan-primary-unshadowed-live.png` show no footprint. The bake keeps
the native winner instead of promoting the weaker caster. The run logs
the live-mode switch and has no fatal marker. The A142 app was then stopped,
its PID was absent, the launcher was foreground, and its panel was closed
without shutting down the phone.

The geometry factories and fixture geometry have not changed since their
three-lane, two-light proof. The earlier iOS spotlight and catcher checks are
also reused: subsequent source changes are Android-only, fixture selector
additions, or documentation. The seven ordinary/GPU Android consumer paths
remain unchanged by the final facing-map correction, as its scoped review
records. All 57 reviewed source/asset hashes still match
`reviewed-source-check.log`.

## Independent evidence audit

Fresh Codex review checked these logs and images, recalculated all 57 source
hashes, and reports PASS for the bounded evidence set. It did not run builds,
tests, or devices. The audit confirmed the missing tablet and operator gates
and the OpenGL image caveat. It requested durable JVM totals; the original
19 result XMLs and their hash/count summary are now retained in
`android-jvm-results/` (162 cases, 147 passed, 15 skipped, zero failures/errors).
