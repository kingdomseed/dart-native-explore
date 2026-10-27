# Variant-default and camera-facing verification

The parent reproduced both findings from independent Sol review on the iPhone
17 Pro simulator on 2026-10-26. Camera-facing binding migration now passes the
capture-lifecycle check. Variant-default conversion remains broken for the
component's double-sided material copy.

This record preserves the failed attempt. The subsequent
[ownership correction](../variant-default-ownership/README.md) passes the
conversion and hidden-refresh runtime checks.

## Camera-facing geometry replacement

The same `DART3D_CATCHER_PATH=camera-facing` fixture runs before and after the
native binding migration. The native adapter rebuilds its billboard geometry
each frame before the catcher registry checks for dirty captures.

`before-facing-native.log` records no capture on load or explicit Refresh.
`before-facing-initial.png` and `before-facing-refresh.png` show the baseline.

`after-facing-native.log` records a 256x122 capture on load. Caster movement
leaves the count at one. Refresh produces the second capture.
`after-facing-initial-ready.png`, `after-facing-caster-stale.png`, and
`after-facing-refreshed.png` record that sequence. The earlier
`after-facing-initial.png` preceded confirmed app startup and is not final proof.

This verifies binding migration and explicit-refresh scheduling. It does not
establish general billboard footprint parity. The angled camera-facing receiver
does not lie in local XZ, which the baked material contract assumes.

## Variant-default conversion remains open

The `variant-default` fixture starts with an ordinary default material, a
distinct ordinary mapped variant, and a double-sided instance receiver.
The Toggle material type control sends a same-ID baked-catcher upsert.

`before-variant-default-convert.png` and `before-variant-native.log` reproduce
the ordinary receiver remaining visible with no capture. The first correction
updates variant defaults only when their object identity matches the old shared
resource. `after-variant-default-convert.png` and `after-variant-native.log`
show that this correction is insufficient.

The temporary diagnostic in `variant-default-diagnosis-native.log` records
`declaredMatch=true identityMatch=false defaultDoubleSided=true resourceDoubleSided=false`.
The default points at the declared resource ID but holds a component-specific
copy. Source inspection identifies the double-sided instance copy and the
variant rebase rule that adopts it as the default.

The remaining correction must update catcher-owned default copies while
preserving foreign material rebinds and ordinary snapshot-copy behavior.
Refreshing a baked default while another variant is selected also remains to
be verified after that correction.

## Checks and cleanup

`parent-focused-tests.log` records 14 passing focused tests.
`parent-analyze.log` reports no issues. These tests validate the fixture and
public Dart commands, not native slot rebinding. Assertions that could pass
without variant selection were removed from the new test.

The generic arm64 simulator build passed before these native runs. Each native
run built and executed the selected fixture. All app runs and log streams
stopped. The diagnostic source was removed and the native file restored before
the next snapshot. A simulator-state query confirmed shutdown. The A142 was not
used. No commit or PR was created.
