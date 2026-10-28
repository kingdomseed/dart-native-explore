# U4 ordinary PBR sheen alpha correction

The reviewed P2 is corrected at the shared native sheen term. Half-alpha sheen
previously contributed its full opaque value; it now contributes half. Generated
material RGB retains the earlier proven unlit correction. This closes one
bounded finding, not U4 or Track E acceptance. Independent Codex R2 re-review
passed at the45-source snapshot below with no scoped P1/P2 remaining.

## Finding and correction

Public/imported physicallyBased materials can combine BLEND, sheenColor and a
materialBaseColor alpha channel. FsceneRealizer decodes sheen before assembling
the final ordinary fragment modifier. Its manual `tint * rim` addition was not
attenuated after the whole-output multiplication was removed. Both uniform and
textured sheen share this one addition; searching production shader additions
found no second ordinary RGB term requiring the same correction.

The owner now passes the already-decoded BLEND decision into the extension
decoder and multiplies only the added sheen contribution by output alpha.
OPAQUE/MASK retain their existing expression. No whole-output multiplication,
sampler, animation API, registry, clock, fallback or renderer change is added.

The review predicted a visible rim at zero alpha. That specific prediction did
not reproduce: native observations confirmed zero alpha and the image showed
only the backing. Raw readback also found zero contribution at zero. We did not
identify the generated shader step suppressing it. The material P2 remains
real at partial alpha and is established below, rather than inferred at zero.

## Public-path fixture and native observation

Run the existing u4-materials mode with DART3D_U4_SHEEN=true. Its PBR card rotates
60 degrees around Y, adds a gray backing and white roughness1 sheen, and uses
black RGB with alpha0→1 in the existing typed property clip. Other cells and
controls remain. Seek0/1/2 requests alpha0/.5/1. The default fixture is unchanged.
A new test checks literal payload endpoints and actual emitted PBR track fields.

An observation-only post-sampler probe read the actual PBR material KVC factor
and existing clip time. observed-native.log records [0,0,0,0], [0,0,0,.5] and
[0,0,0,1] before and after, with the old/new fragment term flags. These are actual
native values, not requested-only logs. Retained baseline, observation and
capture-probe hosts distinguish executed instrumentation from final source.

## Decisive raw GPU comparison

U4SheenProbe copies the actual realized PBR material and shader into independent
capture scenes/materials/cameras. Synthetic isolation uses white diffuse input,
black RGB, copy alpha0/.5/1, an angled plane, no lights and a gray destination.
It compares the current shader, an explicitly weighted candidate, and the same
shader with its manual sheen addition removed. rgba16Float targets are read
back after command completion; live scene attachments are never changed.

Subtracting each same-alpha no-sheen control isolates the added contribution:

| Alpha | Before center contribution | Corrected center contribution |
|---|---:|---:|
| 0 | 0 | 0 |
| .5 | .50634765625 | .2529296875 |
| 1 | .50634765625 | .50634765625 |

analyze-readback.dart checks corresponding3x3 pixels. Maximum half-alpha scaling
error falls from .259765625 to .000244140625, within the unchanged .001 tolerance.
All22 before/after commands completed without GPU error; all outside samples
retain the destination. before-readback.json, after-readback.json and
readback-checks.json retain the numbers. This is a copied uniform-sheen PBR
control, not calibrated full-renderer color or textured-sheen numeric parity.
Texture and uniform sheen use the same corrected source term by inspection.

## Clean app proof and checks

Both temporary probes and the U4SheenProbe source were removed. Clean native
builds replayed the sheen selector and the default u4-materials selector.
clean-t0/t1/t2.png match their corresponding observed corrected scene crops
exactly. Before/after comparisons find3006 changed pixels only in the PBR
half-alpha region (maximum encoded-channel difference48). Zero/full-alpha PBR
endpoints, shared pair, reference, alpha cell and snapshot are unchanged.
The default fixture's Seek1 scene crop matches its prior verified capture with
zero changed pixels, preserving the earlier unlit-alpha result.

analyze-images.swift/image-checks.json retain exact PNG comparisons, not linear
color claims. The parent inspected screenshots and the clean video contact
sheet. clean-sheen-controls.mp4 spans178.5s;18 cells sample48 decoded frames,
showing seeks and playback with the frozen reference/snapshot. No frame-rate,
latency or performance conclusion is made.

Final parent suites pass283 example and380 package tests. Both package analyses
are clean. Native Swift compiled/executed in the real simulator runs. Existing
native feature reporting remains deliberately unadvertised and is not a pass.
Codex R1's source/ownership/image/raw-unlit evidence checks remain valid at their
archived45-source snapshot; this correction and its additional fixture require
a new independent review. That R2 review now passed: it independently verified
hashes/replay/preservation and recomputed native, raw GPU and image comparisons.
The report and receipts are retained at
`/private/tmp/dart3d-e5c-u4-sheen-review-20261027/r2/`. It ran no fresh tests,
builds or devices and makes no whole-U4 acceptance claim. Raw PNG channel counts
and AppKit-converted sRGB counts differ as expected; its explicit color-space
recomputation reproduced the parent3006/max48 comparison.

## Commands and exact source

From dart3d/example: `dn run -d C24F3C6D-A3A9-4FB7-978E-36E67EF55354 --no-pub --dart-define=DART3D_SCENE=showcase --dart-define=DART3D_MODEL=u4-materials --dart-define=DART3D_QUALITY=high --dart-define=DART3D_U4_SHEEN=true`.
The default replay omits only the last define. Probed and clean run logs retain
native build/run receipts. Filtered logs are not a global crash audit.

Current45-source source.tgz SHA256:
`8d07c601bfb91546c03f5b3bfff38c05e6821384e8e01ecfb3ec6de0b89515e6`.
Four-file correction.patch SHA256:
`73b40fd6f69b69284ce36de1af1130e78447e49cb0337724f9ff3e1889c88a69`.
It replays on the prior45-source archive6ad07da8. All41 unowned source files and
five tracked locks remain unchanged. source-sha256.txt/replay-proof.log verify
the clean result. SceneViewHost restores8887e13b; corrected FsceneRealizer is
08b1f501. Probe sources/manifests identify the two executed native variants.
No observation hooks or diagnostic class remain in production source.

## Cleanup and remaining gates

All own recordings, app runs and log streams are stopped. shutdown.txt confirms
no booted simulator. One earlier command/log session was lost at the intentional
turn interruption; a fresh process check found no live dn/logger and the device
was reopened through the same tool. No alternate GUI/input driver was used.
One stale AX ref was refused; a fresh full snapshot authorized the successful
action. Later app runs ended Application finished. A fresh A142 foreground check
still shows Google account activity; it received no input.

Exact source/probes, raw JSON, scripts, images, logs, video/contact sheet and
hashes remain in this private pickup. Tool refusals and the interruption are
also recorded in the parent thread. Smaller durable
receipts live under writer docs/artifacts/e5c-u4-property-animation/ios-sheen/.
Replay scratch, duplicate probe copy and temporary production hooks/class were
removed. Build caches/outputs remain for subsequent checks. No commit/push,
PR65 change or external media upload occurred. Android runtime, remaining U4
owner/variant/multiview/light-type checks, T2/T4 and whole-U4 acceptance stay open.
