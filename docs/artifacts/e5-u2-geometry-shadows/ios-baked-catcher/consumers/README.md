# iOS catcher consumer verification

The parent ran the corrected iOS catcher on the iPhone 17 Pro simulator on
2026-10-26. Material conversion, rebuilt geometry, variants, active LOD geometry,
and repeated consumer replacement now retain or refresh the cache through the
existing public commands. Independent Codex re-review found variant-default
and camera-facing consumer gaps. The [second runtime record](round2/README.md)
retains their reproduction. The latest [variant-default ownership record](variant-default-ownership/README.md)
verifies the corrected conversion, hidden refresh, and existing consumer paths.
Independent Codex Sol re-review passed the bounded iOS unit. Its
[checkpoint](variant-default-ownership/review.md) preserves the evidence limits.

## Native before and after

| Public path | Before correction | Corrected evidence |
|---|---|---|
| Ordinary material to baked catcher | `type-baked.png` still shows the ordinary receiver. `parent-type-native.log` queues refresh without a capture. | `type-fixed-baked.png`, `type-fixed-ordinary-return.png`, and `type-fixed-baked-return.png` show both conversions. `parent-type-fixed-native.log` records captures. |
| Resource-backed geometry upsert | `before-geometry-lost-cache.png` loses the footprint. `before-geometry-refresh-fails.png` remains empty after Refresh. | `geometry-rebuilt-cache-stale.png` retains the cache after caster movement and geometry replacement. `geometry-rebuilt-refreshed.png` updates it after Refresh. |
| Variant-only catcher | `before-variant-no-footprint.png` has no footprint after selection and Refresh. `before-variant-native.log` has no capture. | `variant-catcher.png` has the first capture. `variant-reselected-stale.png` reuses it after reselection. `variant-refreshed.png` updates it. |
| Component rebuild | The prior source review traced missing binding cleanup. | Three rebuild actions retain the original cache in `components-rebuilt-stale.png`. Refresh updates `components-refreshed.png`. |
| Remove and add | The retention measurement below reproduces accumulating strong references. | Three remove/add actions retain the cache in `remove-rebuilt-stale.png`. Refresh updates `remove-refreshed.png`. |

The before comparisons use the pre-correction native files with the current
resource-backed fixture. The geometry sequences differ in caster movement, so
these images do not establish a pixel-matched comparison. The native logs show
the missing capture and its recovery through the same resource command.

The first material-conversion replay caught a remaining correction bug.
`registerCurrentShadowCatcherConsumers` searched the surgical context's empty
node map. It now resolves the owner through the host's live `nodesById` map.
The `type-fixed-*` artifacts contain the successful replay.

## Active LOD geometry

The fixture uses a 0.35 screen-size threshold. The original 1.0 threshold
required an unusable view inside a caster. Actual pinch input crosses the new
threshold in `parent-lod-native.log`, process 85321.

At size 0.1271, level 1 captures 256x221 pixels. With softness 0.14, the same
geometry captures 120x104. At size 0.3572, level 0 captures 35x31 after explicit
Refresh. Returning to size 0.3464 selects level 1 and Refresh restores 120x104.
The level changes alone do not capture. These dimensions verify that the cache
uses the geometry currently assigned to the node.

`lod-return-stale.png` retains the small geometry's old mapping after the level
changes. `lod-return-refreshed.png` shows the refreshed large footprint. The
temporary selection log was removed after this run. Earlier rejected pinch and
overzoom images remain as unsuccessful controls, not visual pass evidence.

## Strong material references

The temporary diagnostic counted `entry.bindings` and distinct material object
identities held by those bindings in `updateBindings`. Both builds ran the same
three Remove + add actions.

| Build | Registry materials after successive actions | Evidence |
|---|---|---|
| Before correction | 2, 3, 4 | `before-retention-native.log` |
| Corrected | 0 after removal, 1 after re-add, repeated three times | `after-retention-native.log` |

This measures strong references in the catcher registry. It does not measure
whole-heap allocations or retained bytes. The temporary counter was removed.
The three native files matched their saved corrected hashes after restoration.

## Final checks

`parent-final-tests.log` records 12 passing catcher, geometry-fixture, and
spot-fixture tests. `parent-final-analyze.log` reports no issues. One earlier
test was removed because it checked unchanged final document fields and would
pass even if its rebuild and remove/add helpers did nothing. The native runs
above exercise those commands.

`parent-final-run.log` records a clean native build and normal app exit.
`parent-final-native.log` records load and Refresh captures with the temporary
diagnostics removed. `final-clean-initial.png` and `final-clean-refreshed.png`
show that run. App runs, log streams, and recording stopped. A simulator-state
query confirmed that no simulator remained booted.

The geometry sequence's local video receipt is in `video.json`. The MP4 is
4.93 seconds and is not published. The final correction-only patch is
`/private/tmp/dart3d-e5-geometry-20261026/ios-catcher-consumer-fix-r1/consumer-final.patch`.
Its SHA-256 is
`b2571a6d187f19278f61a031b874b44d1a6602f1d1162ff3f8afb6cbc2292cdf`.

The original baked-catcher parity limits remain in the parent record. Android
baking, the full E5 smoke matrix, and final operator review remain open. The
A142 was not used during this verification.
