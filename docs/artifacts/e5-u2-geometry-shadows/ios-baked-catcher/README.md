# iOS baked catcher verification

The parent ran the integrated iOS baked catcher on the iPhone 17 Pro simulator.
Spot and directional lights pass the cache behavior checks below after the
projection correction. The four consumer-lifecycle findings now have corrections
and parent runtime evidence in [the consumer verification record](consumers/README.md).
Independent re-review found two more consumer gaps. Camera-facing binding
migration and variant-default material copies now have runtime proof in the
[latest consumer record](consumers/variant-default-ownership/README.md).
Independent Codex Sol re-review passed the bounded iOS unit with no reachable
P1 or P2 findings. The review covers source correctness and the supplied parent
artifacts, not an independent runtime run. See the
[review checkpoint](consumers/variant-default-ownership/review.md).
Android baked catchers and the final E5 device matrix remain open.

The fixture has two casters and a translated, yaw-rotated, nonuniformly scaled
receiver. Its `d3:instances` receiver uses the double-sided material-clone path.
All controls send the existing public transform or material-upsert commands.

## Projection correction

The first native run compiled the embedded Metal blur shader and drew a
footprint. Moving the caster left the footprint stale. Refresh updated it, but
on the opposite side from the live reference. The files
`spot-refreshed-before.png` and `spot-live-reference-before.png` retain that
failure at the same camera pose.

A direct SceneKit projection query returned `m22=0.25` at orthographic scale 4,
so the vertical extent is 8. The capture camera's right vector was negative X.
`projection-calibration.log` records both results. The correction halves the
authored capture scale and reverses the texture U mapping to match that camera.
`spot-projection-refreshed.png` now aligns with
`spot-projection-live-reference.png`. The original fixture framing is retained
in these comparison images. Later final images use a frame margin of 1.6 so the
whole footprint remains visible.

## Cache behavior

| Action | Spot evidence | Directional evidence | Observed result |
|---|---|---|---|
| Initial load | `spot-final-initial.png` | `directional-auto-fit-initial.png` | A cached footprint appears. |
| Move caster | `spot-final-caster-stale.png` | `directional-auto-fit-caster-stale.png` | Footprint remains at its old position. |
| Explicit same-properties material upsert | `spot-final-caster-refreshed.png` | `directional-auto-fit-caster-refreshed.png` | Footprint moves to the caster's current position. |
| Move light | `spot-final-light-stale.png` | `directional-auto-fit-light-stale.png` | Lighting changes while the footprint stays stale. |
| Refresh after light movement | `spot-final-light-refreshed.png` | `directional-auto-fit-light-refreshed.png` | Footprint changes direction. |
| Softness 0.14 | `spot-final-soft.png` | `directional-auto-fit-soft.png` | Shadow edges become broader and softer. |
| Live mode, then move | `spot-final-live-moved.png`, `spot-final-live-light.png` | `directional-auto-fit-live-moved.png` | Live shadows follow movement without Refresh. |
| Return to baked | `spot-final-baked-return.png` | `directional-auto-fit-baked-return.png` | Mode upsert creates a fresh cache. |

Native logs report 256x221 captures at softness 0 and 120x104 at softness
0.14. Captures follow load and explicit material upserts, rather than ordinary
transform updates. The directional run also returns softness to 0 before its
live-mode comparison.

The first directional fixture had `shadowMaxDistance=14`, which disables the
adapter's automatic directional shadow fitting. Neither its baked nor live
view showed a shadow. Those unsuccessful controls are the `directional-*`
images without `auto-fit` in their names. Removing that fixture-only override
restored shadows. The renderer adapter is unchanged. Final directional proof
uses the `directional-auto-fit-*` images.

## Checks and limits

`parent-final-tests.log` records nine passing focused catcher, geometry-fixture,
and spot-fixture tests. `parent-final-analyze.log` is clean. Both final native
boots built and executed the new Swift code, geometry modifier, and Metal blur
shader. Each app run ended with `Application finished`. Both recordings were
exported, both native log captures stopped, and simulator shutdown was checked.

`parent-spot-run.log` and `parent-spot-native.log` are the first mapping failure.
`parent-spot-projection-*.log` contain its correction and final spot sequence.
`parent-directional-*.log` contain both the unsuccessful override and the
subsequent automatic-fit sequence, separated by hot restart.

The implementation preserves and blurs captured RGBA. Numeric raw-channel
calibration was not collected, and these checks do not claim upstream raw
visibility semantics. The capture prototype's red-background proof remains
in `../catcher-prototype/ios/`. Material-local AO strength, contact shadows,
shadow color/intensity, fade, live softness, arbitrary shear, and per-instance
footprint caches remain outside this implementation's parity claim.

Local videos are listed in `videos.json`. The successful spot recording is
54.733333 seconds. The successful directional recording is 44.066667 seconds.
The earlier directional recording is an unsuccessful control, not final proof.

## Consumer review and correction

Independent Codex Luna review found four source-traced P2 gaps beyond the
recorded movement sequence. Ordinary-material conversion to a baked catcher
can skip consumer rebinding. Geometry upsert can leave new double-sided clones
outside the registry. Variant and LOD assignment paths omit catcher bindings.
Node removal and component rebuild can leave strong material references in
stale bindings. The parent verified these paths in the decoder and host code.

The geometry-upsert gap requires a resource-backed instance geometry. The
original inline procedural receiver did not exercise that path. The fixture
now uses a geometry resource, and the parent reproduced the missing footprint
before applying the correction. The consumer record includes native material
conversion, geometry upsert, variant, LOD, rebuild, and removal checks.
The second review and runtime record above track the remaining corrections.
