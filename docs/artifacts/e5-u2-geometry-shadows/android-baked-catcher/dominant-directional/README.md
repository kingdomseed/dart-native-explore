# Dominant directional-light correction

This records the first correction. The later [tied-light replay](../directional-ties/README.md)
replaces Kotlin winner selection with one native directional-group capture.

A142 OpenGL medium reproduces and resolves the reviewed two-light defect.
The cache now selects the strongest directional light across all scene
directionals before checking whether that light casts shadows. Spot selection
and composition are unchanged.

## Two-light regression

The fixture selector is `DART3D_CATCHER_LIGHT=directional-primary-unshadowed`.
Its primary white directional has intensity 3 and does not cast shadows.
The secondary white directional has intensity 1 and does cast shadows.

- [Before baked](corrected-before-baked.png) has an unwanted secondary-light
  footprint to the left of the large cuboid.
- [Before live control](corrected-before-live.png) has no ground footprint.
- [After baked](after-baked.png) also has no ground footprint.

The valid before run is PID 28476. The after run is PID 28738.
Their run logs record the exact selector and native logs identify OpenGL.
The initial attempt silently selected spot because the showcase loader
normalized the new selector. That loader path and its define-specific test
were corrected before the valid before capture. [The invalid-attempt note](INVALID-SELECTOR.txt)
identifies the earlier private files, which are excluded from this evidence set.

## Single-light positive control

PID 28987 uses `DART3D_CATCHER_LIGHT=directional` with the corrected source.
The initial camera leaves much of the shadow behind the cuboid and footer.
After a camera orbit and caster movement, [the baked view before recapture](positive-caster-moved.png)
still leaves much of the initial patch obscured. [Live mode](positive-live-moved.png) exposes a clear
footprint to the left of the moved cuboid. [Returning to baked mode](positive-baked-moved-refreshed.png)
recaptures and shows the corresponding footprint in that area.
The native log records two 256-pixel captures, on load and return to baked.
This is visual evidence for the exercised directional case, not numeric
pixel parity or the full directional freeze-and-refresh matrix.

## Source and automated checks

[The native patch](native-selection.patch) adds only dominant-light selection.
The fixture, loader, and test add the exact public two-light route.
The define-specific catcher suite passes 10 tests. Current example analysis
reports no issues. The full Android Release JVM task passes with the existing
15 opt-in native-physics skips. The tests do not replace GPU proof.
The changed-comment audit found no new comments or suppressions.

The parent inspected all linked before, after, and positive-control images.
No fatal marker occurs in the valid native logs. The app was stopped normally,
its PID was absent, and the Nothing launcher was foreground afterward.
Independent recheck, remaining consumer journeys, final E5 device checks,
and operator approval remain open. Vulkan has not repeated this new two-light
regression yet.
