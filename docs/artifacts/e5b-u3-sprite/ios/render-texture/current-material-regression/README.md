# Current material regression: iOS render-texture sprites

PASS on 2026-10-27. The existing R5 sprite/render-texture correction still
renders correctly after the U4 ordinary-material and sheen changes. No source
change was needed. This is a regression receipt; the original R5 motion and
render-target readback evidence remain in the parent render-texture manifest.

The parent built and ran the current source on the approved iPhone 17 Pro
simulator with `DART3D_MODEL=u3-sprite`, `DART3D_SPRITE_RT=true`, and high
quality. The build and completed application run are recorded in `run.log`.
All 49 current source hashes match the accepted U4 light fixture snapshot:
`/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-lights/source.tgz`, SHA-256
`587e6d1a99b8a563b453d9fb0cb81dfd091ef847dafbdb29db758a6dbced0495`.

The parent inspected all six 1206x2622 screenshots. The original eight sample
regions, linear alpha/additive equations, sRGB encoding and tolerance of three
encoded channel values were reused unchanged. The independent sheet,
untextured and overlapping controls remain visible without the old magenta
failure. The maximum absolute RGB channel errors are:

| State | Maximum error | Result |
| --- | ---: | --- |
| Initial alpha | 2 | PASS |
| Additive | 1 | PASS |
| Additive with tint and vertex color | 1 | PASS |
| Additive, tinted, untextured | 1 | PASS |
| Alpha, tinted, untextured | 1 | PASS |
| Alpha, tinted, render texture restored | 1 | PASS |

Each screenshot has a matching `-pixels.json` and `-comparison.json` receipt.
`measure.dart`, `compare.dart` and `regions.json` are the retained original
measurement inputs. These encoded screenshot values do not establish numeric
coverage alpha, photometric accuracy, latency or performance. No new tests,
Android execution, playback recording or independent review were run for this
unchanged-source regression.

The app and filtered native logger were stopped. A fresh simulator inventory
after asynchronous shutdown contained no booted devices. There is no source
patch, temporary production probe or dependency change to remove. This packet
is retained for review; the six PNGs, scripts, JSON, source hashes and logs are
also copied beside this README in the repository evidence directory.
