# Sampled-normal and filled-wireframe experiment

The iOS experiment displays the quad's sampled normal-map regions, distinguishes geometric normals, overlays triangle edges over filled material, and restores the ordinary image. [Independent Codex source/evidence review passed](review/report.md), with no material in-scope P1/P2 defect or evidence overclaim. The probe was removed after the run; production debug views remain open.

| View | Saved capture |
| --- | --- |
| Ordinary material | [Off](00-off-r2.png) |
| Sampled view-space normal | [Mapped](01-mapped-r2.png) |
| Geometric-normal control | [Geometry](02-geometry-r2.png) |
| Literal RGB control | [Transfer](03-transfer-r2.png) |
| Mapped return | [Mapped again](04-mapped-return-r2.png) |
| Ordinary restoration | [Off restored](05-off-restored-r2.png) |
| Filled triangle-edge overlay | [Wire on](06-wire-on-r2.png) |
| Final ordinary restoration | [Wire off](07-wire-off-restored-r2.png) |

Both ordinary restorations and the mapped return have zero changed scene pixels in crop [0,100,402,650]. Wireframe changes 1,364 pixels and shows the internal diagonal. [Pixel receipts](pixel-analysis.json) and [analysis script](analyze.dart) use decoded screenshot RGB, not calibrated linear normal values. The mapped screenshot's interior regions differ; the geometric control is uniform.

[Native logs](native-r2.log) record the selected fields, matching requested/actual wire states and debugOptions 0 → 32 → 0. Camera HDR packing, exposure and SCNTechnique remain active, with all fourteen logged effects disabled. The literal shader control (0.125,0.5,0.875) displays approximately [100,187,237]; no raw shader-color claim is made.

The [run transcript](run-r2.log) records a successful documented dn run on the approved iPhone 17 Pro simulator and Application finished. [The movie contact sheet](video-contact-sheet.png) samples the full control sequence; [sample times](video-sheet-times.txt) and [movie hash](video-sha256.txt) identify the private recording. The 213.713333-second recording decoded all 12,989 frames with FFmpeg exit 0, with retained null-muxer duplicate-DTS warnings. It is not a clean timing or latency measurement.

An early preview was misread as black. Saved initial and steady mapped PNGs are byte-identical and colored, and their scene pixels match mapped return. There is no saved GPU-failure evidence from that interpretation.

Observed source61 archive SHA-256 2c70e6f6dd5c19f42bda18f6fe69a1835ace47a7a7d33807486bf8b175abcfb9 and five-file probe patch SHA-256 520fe187e53ec2f21059be9e3029860b2f15fa1dccad2d9ff3baef262ed8e3db are retained under /private/tmp/dart3d-e9-debug-probe-20261027/ios-r1/. The full runtime manifest is [README.md](/private/tmp/dart3d-e9-debug-probe-20261027/ios-r1/parent-runtime/README.md).

The recording, app and logger were stopped. Reversing only the probe restores all accepted58 source hashes and six locks/registrants; the three added probe files are absent. Normal main configuration is restored without a reload selector. All accepted reload-library files remain integrated. [Cleanup receipt](cleanup-check.txt), [source restoration](restored58.txt), [locks](restored-locks.txt) and [final device inventory](device-after.json) record this. The simulator is shut down and no device is open; the A142 had no targeted operation. Raw evidence, frozen source and ignored existing build outputs are retained. Contact-sheet scratch was removed.

Other material families, deformation, clones, multiview/capture isolation, metallic/roughness/base-color/depth views, Android, performance, T1/T2/T4 and whole E9/Track E remain open.

The reviewer independently verified source replay/preservation, all image comparisons and all 12,989 video frames offline. Its native runtime, builds and tests were NOT_RUN. Copied review receipts retain their original hashes. This final review checkpoint changes the manifest narrative; native inputs and observed source are unchanged.
