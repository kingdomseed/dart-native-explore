# iOS baked-catcher debug views

The corrected native run displays the actual cached shadow footprint in all five
screen diagnostic channels. Normals and depth inspect the receiver; base color,
metallic and roughness show magenta for absent inputs. Transparent surrounding
pixels expose the real PBR backdrop. This is one transformed, planar spot-light
fixture on the iPhone 17 Pro simulator, not whole W34 or Track E acceptance.

Both baseline and corrected initial captures log a cross-scene mutation warning
and a missing `d3CatcherRegion` attachment. Their causes remain unresolved. The
same messages precede the baseline's first capture and the corrected first
capture; later refresh/reload captures in this run do not repeat them. No fix for
those existing capture-owner warnings is claimed. No fatal termination or shader
compilation error was found in the retained PID logs. Numeric channel/alpha
calibration and the pending-cache first-frame path remain unverified.

## Matched baseline and correction

The baseline uses the accepted 66-file source packet, with only the new Dart
fixture imported. PID 12785 identifies that run; PID 15785 identifies the native
material correction. Both use `lib/w34_debug_main.dart` and
`DART3D_W34_BAKED_CATCHER=true`. The source cache owner, capture pass, host,
private presentation graph, lights, render targets, Android, and all six lock or
registrant files are unchanged. The material signature/copy includes the current
`d3CatcherRegion`; the diagnostic retains its cache and geometry mapping.

| Channel | Before | After |
| --- | --- | --- |
| Off | [authored A](before/00-off.png) | [authored A](after/00-off.png) |
| Normals | [black cached shadow](before/01-normals.png) | [receiver normal under cache coverage](after/01-normals.png) |
| Metallic | [black cached shadow](before/02-metallic.png) | [absent-input magenta](after/04-metallic.png) |
| Roughness | [black cached shadow](before/03-roughness.png) | [absent-input magenta](after/05-roughness.png) |
| Base color | [black cached shadow](before/04-basecolor.png) | [absent-input magenta](after/03-basecolor.png) |
| Depth | [black cached shadow](before/05-depth.png) | [receiver depth under cache coverage](after/02-depth.png) |

All PNGs are original 402×874 CLI captures. The panel screenshot was also
inspected at its native 1206×2622 resolution. The caster, covered receiver,
backdrop and footer fit; the unused area below the backdrop is authored black.
The scene crop `[0,70,402,580]` excludes status and controls. Before/after Off,
Off after wire, Off B after reload, normals B after reload, and final Off A each
have zero changed pixels in that crop.

## Movement, refresh and lifetime

[09](after/09-normals-A.png) is normals at A. In
[10](after/10-normals-B-stale.png), the caster has moved to B while the cached
footprint remains at A. [11](after/11-normals-B-refresh.png) follows the explicit
same-ID material upsert: the footprint moves to B while normals stays selected.
The native log records the upsert then one new capture. Channel and wire changes
and caster transforms do not produce captures. There are exactly four corrected
captures: initial load, explicit A→B refresh, full reload at B, explicit B→A
refresh.

The footprint band `[100,405,290,45]` lies below both caster positions. Its normals
pixels have zero differences after caster movement and 5,016 differences after
refresh. The reverse depth sequence [20](after/20-depth-B.png),
[21](after/21-depth-A-stale.png), [22](after/22-depth-A-refresh.png) likewise has
zero differences before refresh and 4,157 afterward. These are encoded PNG
observations, not calibrated coverage or linear-channel measurements.

[06](after/06-roughness-wire.png) retains filled surfaces with actual geometry
edges. [07](after/07-off-wire.png) returns authored shading while wire remains;
[08](after/08-off-restored.png) removes wire and matches initial authored pixels.
[16](after/16-off-B.png) and [19](after/19-off-B-reload.png) match exactly. Reload
keeps B and the selected channel ([17](after/17-normals-B.png),
[18](after/18-normals-B-reload.png)); [23](after/23-off-A-final.png) matches initial
A after returning and refreshing.

[Pixel analysis](pixel-analysis.json) and [its Dart recomputation](pixels.dart)
retain the crops, per-image samples and differences. The script currently uses
the retained parent artifact root; changing that root is sufficient to recompute
against this directory. The original captures were decoded with FFmpeg before
making missing/black-pixel claims.

## Execution receipts

- [Focused public-path fixture checks](focused-tests.log): 29 passed.
- [Full package suite](package-tests.log): 393 passed.
- [Full example suite](example-tests.log): 337 passed.
- Both analyses are clean: [package](package-analyze.log), [example](example-analyze.log).
- [Swift typecheck](swift-typecheck.log) exited 0 for all plugin sources at
  `arm64-apple-ios15.0-simulator` with the installed simulator SDK.
- Both `dn run` builds and app sessions completed: [baseline](before/run.log),
  [corrected](after/run.log). [Baseline native excerpt](before/native-relevant.log)
  and [corrected excerpt](after/native-relevant.log) retain warnings and capture events.
- [Video receipt](video-receipt.json) identifies the original 65.48-second,
  6,631-frame recording retained locally. Complete null and raw-video decodes
  exited 0 and both emitted duplicate-timestamp muxer warnings. Both logs are
  retained; neither is described as warning-free decoding.

The app and owned log stream were stopped, the simulator shut down, and the
Device panel was verified empty with no simulator booted. Config-only generation
restored `lib/main.dart` and removed all W34 defines. The A142 was not targeted.
Ignored build/SDK/Pods outputs and the source/evidence packets remain; task-owned
replay scratch is removed after validation. No commit, push or PR change occurred.

Independent [Codex review](review/report.md) passed with no scoped reachable
P1/P2 finding. It independently verified packets, replay, preservation, all
30 PNGs, pixel comparisons and complete video decoding. It ran no tests, builds
or native sessions. The empty parent typecheck log alone cannot establish its
exit code; the worker's explicit typecheck receipt records exit 0.
Android, live shadow-only catchers,
baked-specific authored-target isolation, general receiver/consumer coverage,
performance, final T2/T4 and whole Track E remain open. Native particles retain
the operator-approved unsupported status.
