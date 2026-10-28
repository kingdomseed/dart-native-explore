# Variant-default ownership verification

The parent ran the integrated ownership correction on the iPhone 17 Pro
simulator on 2026-10-26. The previously failing default-material conversion now
captures a baked footprint. Refresh while another variant is selected also
works when the default returns. Independent Codex Sol re-review passed the
bounded iOS unit. See the [review checkpoint](review.md).

## Before and after

The [preceding record](../round2/README.md) retains the failed shared-identity
correction and its native diagnostic. That diagnostic distinguishes the shared
resource from the component's double-sided copy.

The correction stores resource ownership and copy status in the existing
variant binding. Catcher-related upserts replace the owned default, including
when that default is hidden. A copied default retains `isDoubleSided`.
Ordinary material upserts retain their existing snapshot behavior by source
inspection. Foreign writes still use the existing variant rebase rule.

| Action | Screenshot | Native observation |
|---|---|---|
| Convert the ordinary double-sided default to baked | `default-converted.png` | First 256x221 capture. The ordinary receiver disappears. |
| Select other, move the caster, and Refresh the hidden default | `other-hidden-refresh.png` | Refresh queues, with the capture count still one. The ordinary blue variant stays selected. |
| Return to default | `default-after-hidden-refresh.png` | Second capture uses the moved caster. |
| Convert the visible default back to ordinary | `default-ordinary-return.png` | The ordinary receiver returns. |
| Select other, convert the hidden default to baked, and return | `default-baked-return.png` | Third capture produces the baked default again. |

`variant-default-native.log` and `variant-default-run.log` record the sequence.
The local recording is 45.67 seconds. `video.json` records its path and hash.
The recording is exported but not published.

## Shared default control

A temporary fixture variation sets `doubleSided: false` only in the
`variant-default` case. That uses the shared resource instead of creating a
component copy. `shared-fixture-only.patch` records the exact variation.

`shared-converted.png` and `shared-after-hidden-refresh.png` show successful
conversion and hidden refresh. `shared-default-native.log` records two captures.
The fixture was restored to its original hash before subsequent runs.
`fixture-source-hash.json` records that hash. This variation is a test control,
not a production fixture change.

## Existing paths

The existing mapped-catcher selector still works. `mapped-initial.png` shows
its first capture. After caster movement and Refresh, selection away and back
retains the refreshed cache in `mapped-refreshed-reselected.png`.
`mapped-variant-native.log` records two captures and no extra bake on reselection.

The camera-facing regression records one capture after load and caster movement,
then a second after Refresh in `camera-facing-native.log`.
`camera-facing-refreshed.png` records that run. This checks binding migration
and capture scheduling, not general nonplanar billboard footprint parity.

## Checks and limits

All four runs built the integrated native source and ended normally.
All log streams and the recording stopped. A simulator-state query confirmed
shutdown. The A142 was not used. The final source hashes are in
`source-hashes.json`. The comment audit led to six comment-line deletions.
No temporary native diagnostic remains.

The earlier 14 focused Dart tests and clean analysis cover the unchanged
fixtures and public Dart commands. They do not execute these native changes.
The worker's generic arm64 simulator build passed, and the parent native runs
compiled and executed the correction after comment cleanup.

Foreign-rebind runtime behavior, ordinary snapshot-update runtime behavior,
and fresh allocation or retention measurements were NOT_RUN in this sequence.
They remain source-review checks. The earlier registry-retention comparison is
historical evidence for the previous cleanup correction.

Android baking, the final E5 device matrix, and operator review remain open.
