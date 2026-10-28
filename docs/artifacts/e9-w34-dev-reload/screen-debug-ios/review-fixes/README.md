# iOS PBR review corrections

Both reported failures were reproduced through the public controller/view path
and corrected locally. Independent Codex re-review passes. This covers the
bounded iOS PBR unit, not whole W34 or Track E.

## Detached skin dependencies

With the original native code, removing the two-bone rig while Off and selecting
normals terminated PID 40094:

`dart3d/ScreenDebugPresentation.swift:178: Fatal error: Unexpectedly found nil while unwrapping an Optional value`

The skinner retains its current bone slots after their authored nodes are
removed. Diagnostic capture now includes those actual bone and skeleton poses,
plus necessary ancestry, in its existing packet. These pose-only dependencies
do not enter authored registries or borrow live bones into the presentation.

The final PID 50106 replay removes the rig, selects normals, restores the rig,
raises its joint, returns Off, and resets the pose without a crash. The raised
pose changes 26,179 scene pixels against rest. Returning to rest reproduces the
initial Off scene crop exactly. This is a two-bone fixture result; arbitrary
skinning and morph behavior remain unverified.

## Partial viewports

The first action order did not expose the reported leak. Other early captures
were entirely black. Those observations are retained; their cause was not
established, and their prospective filenames do not establish a leak.

Starting in full-view normals and then requesting an inset viewport did expose
the canonical authored quad above the inset. The decisive before image is
`before-viewport/06-diagnostic-inset.png`, from intermediate PID 46292 with
the bone correction and temporary capture-generation logs. Those logs confirmed
a 362×300 point sibling at (20,333.33), with a real source camera.

A full-bounds opaque black UIView now sits below diagnostic siblings. Their
existing main-thread create/layout/teardown path owns it. Canonical cameras,
simulation, authored targets and material ownership remain unchanged.

In rectangle [140,75,175,230], the before image has 36,630 nonblack pixels; both
final inset orders have zero. The final inset scene crops match exactly.
Returning Off/full reproduces the initial Off scene crop exactly. These checks
use encoded screenshots, not calibrated GPU values or performance measurements.

## Verification and identity

- Full package tests: 393 passed. Full example tests: 332 passed.
- Both analyses clean; arm64 iOS 15 simulator Swift typecheck exits 0.
- Final native simulator build/run completed and quit normally.
- Seven-file correction replays forward and backward against frozen reviewed66.
  All 66 final hashes, 1,926 unowned baseline files and six locks are verified.
- Changed-comment audit: zero changes, zero findings, no edits.
- Four recordings fully decode with exit 0. Timestamp warnings are retained.
  No latency, frame-rate or clean-timestamp claim is made.

The native fixes change three Swift files; the other correction paths are the
optional consumer fixture, its tests and documentation. Temporary capture logs
were removed before the final build. Initial fixture assertion and temporary-log
compilation failures are preserved separately; they are not native bug proofs.

`pixel-analysis.json`, `source-sha256.txt`, `source-replay.json`, test/build
receipts, UI receipts, native scene events and screenshots are retained here.
Full raw logs, recordings, decoder receipts, the correction patch and source
archive remain under:

`/private/tmp/dart3d-w34-screen-debug-ios-fixes-20261027/r2/`

The source archive SHA256 is
`678e0e7edf41ccf5bae32c2f356938c0f96190d244731bacffc83114e45e234e`.
The correction patch SHA256 is
`5da9cc023336a4af2c2129c6ca894181ef4fac0b8da12b5d1daad7ae6f8bad30`.

## Review correction and cleanup

The [fresh Codex report](codex-review/report.md) finds no material reachable
P1/P2 in this bounded unit. Its independent offline checks reproduce all assigned
pixel comparisons and four complete video decodes, and verify exact source
replay and preservation. It performed no independent build, test or native run.

The previous README wrongly described R2's first blend image as missing other
objects. Independent sampling confirms the literal swatches and blue occluder
are present. The current README corrects that observation. Its prior wording
and manifest remain preserved in the private correction packet; historical
audit rows remain untouched.

The app, recorders and native log stream are stopped. The simulator is shut
down, the device panel is empty, and the normal main target is restored. The
A142 received no targeted operation. One cleanup call used an incorrect host
identifier and had no effect; the corrected local-host close and final
inventory establish shutdown.

Android, broader skin/morph and consumer coverage, other material families,
performance, final T2/T4 and whole W34 remain open. Native particles retain the
operator-approved exclusion.

