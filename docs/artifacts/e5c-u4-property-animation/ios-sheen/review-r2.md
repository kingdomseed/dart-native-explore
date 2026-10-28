# PASS — bounded U4 ordinary PBR sheen correction

No material scoped P1/P2 remains. The four-file correction closes R1's reachable partial-alpha sheen defect at its existing native owner. This is independent Codex source/provenance review and offline recomputation of retained parent evidence, not whole-U4 or Track E acceptance. No provider diversity is claimed.

## Contract and source review

Read the adopted contract, ios-sheen README, original R1 report, complete correction.patch, all four changed source files and relevant material construction/import/composition code. The public path remains a physicallyBased material with BLEND, nonzero sheenColor/sheenRoughness and animated straight base-color alpha through D3MaterialBaseColorChannel. The glTF emitter also supplies these material properties.

FsceneRealizer.swift:2591 passes the existing decoded, case-insensitive BLEND decision as a Bool to decodeMaterialExtensions. At :2699–2700, only the manual tint*rim contribution gains multiplication by _output.color.a. Uniform and textured sheen converge on that addition. The false branch emits the exact previous OPAQUE/MASK expression, preserving mask-snippet order. The existing pre-lighting factor, transparent declaration and generated material RGB remain intact. No whole-output multiplication, animation/sampler/clock/registry/API/fallback changes appear. A production iOS search for RGB += or *= output modifications found this sole addition. No ownership transfer or additional machinery is needed.

The installed iPhoneSimulator SDK SCNShadable.h:142–145 documents transparent RGB as premultiplied, with RGB + (1-alpha)*destination blending; :538–540 identifies the fragment modifier as the final color entry point. The repo's texture-material-spec.md documents the existing post-lighting sheen approximation. These support weighting the manually added BLEND term. They do not establish which generated shader step suppresses zero-alpha fragments.

The permanent DART3D_U4_SHEEN selector reuses the existing fixture, typed clip and controls. Its conditional PBR cell uses BLEND, white roughness1 sheen, a Y60-degree pose, gray backing and literal black alpha0→1 payload. The default false path adds no sheen configuration, node or payload and keeps the prior channel mapping/rest values. The loader delta only selects the summary. The new test inspects literal endpoint bytes, pose/backing and materialBaseColor protocol fields emitted by SceneController.loadDocument; it does not duplicate sampling logic. No new scoped defect was found in this fixture/test composition.

## Exact provenance and preservation

- Initial checkout was clean at requested HEAD 2f38e4e33f0b1cb678bc408a42d069c796cefc12. Saved initial status, hashes of all present tracked files, five lock hashes and pre-import source backup before importing.
- Verified new archive SHA256 8d07c601bfb91546c03f5b3bfff38c05e6821384e8e01ecfb3ec6de0b89515e6, prior archive 6ad07da84ad7e420ab54537f6f467be6ccb2f79942affc1e73ac3f1ac832aacc, and correction.patch 73b40fd6f69b69284ce36de1af1130e78447e49cb0337724f9ff3e1889c88a69.
- Independently verified all45 adjacent source-sha256 entries for both archives; AppleDouble metadata is excluded. Replayed the patch on an isolated prior-archive copy: all45 resulting hashes equal the new archive. Exactly the named four paths differ; all41 other sources are byte-identical.
- All five tracked locks and every pre-import tracked file outside the imported source set remain unchanged. HEAD remains unchanged. The parent's45 source paths and five lock paths match their pre-review hashes; no parent writes were performed.
- All57 artifact-manifest entries and all six retained diagnostic-manifest entries verify, including the video, screenshots, raw JSON, logs, scripts and archives. Rechecked after inspection.
- Retained baseline FsceneRealizer hash 6dda8a14 joins the prior archive; corrected hash 08b1f5011e2dd13848dcad3833fba486e593f2f46711ba8632f3b4be1527ab22 joins the clean imported source. The baseline/final SceneViewHost is 8887e13b946bb3ba8d4073992fef2e2d432fbbf91bc7ef001c71c404e191da73. Diffed observation-only and capture-hook hosts against that baseline. Historical probe manifests describe executed root paths; retained local diagnostic files establish their identities. Observation/capture hooks and U4SheenProbe are absent from final production sources.

## Independently checked retained runtime evidence

The observer reads the actual drawn PBR material KVC factor and clip state after sampling. Independently parsed seven records and confirmed old/new fragment flags with native factors [0,0,0,0], [0,0,0,.5], [0,0,0,1] at times0/1/2, weight1. Both raw-readback UUIDs join corresponding observed-native.log capture records.

Read U4SheenProbe and both analysis scripts. The probe copies the realized PBR material/shaders into capture-owned scenes/materials/cameras, replaces diffuse with synthetic white, supplies black RGB and copy alpha0/.5/1, renders an angled plane without lights over gray into rgba16Float, then reads a completed command's shared buffer. It compares current, explicitly weighted and same-alpha no-sheen shaders. Live scene attachments are not modified.

Independent arithmetic over every corresponding3x3 sample confirms:

| Measurement | Before | Corrected |
|---|---:|---:|
| Center sheen contribution at alpha.5 | .50634765625 | .2529296875 |
| Center sheen contribution at alpha1 | .50634765625 | .50634765625 |
| Maximum half-scaling error | .259765625 | .000244140625 |
| Zero-alpha contribution | 0 | 0 |

The unchanged tolerance is .001. All22 GPU commands report completed/no error; all198 outside pixels retain gray. Corrected/current equals the explicitly weighted control at all three alphas. This establishes the partial-alpha correction in the copied uniform-sheen control. R1's predicted visible zero-alpha rim did not reproduce; no explanation of the generated suppression step is asserted. Numeric textured-sheen parity and full-renderer color calibration are not established.

Independently decoded all before/after/clean t0/t1/t2 PNGs and default-clean-t1. Clean corrected scene crops exactly equal instrumented corrected crops. Across the scene crop, only half-alpha PBR changes; zero/full endpoints, shared pair, reference, alpha/snapshot and default fixture versus ios-materials/final-t1 remain byte-identical. Raw PNG RGB gives3007 changed PBR pixels/max55. The parent's AppKit analysis converts to sRGB: independently assigning Generic RGB then converting to sRGB reproduces its exact3006/max48. These distinct measurements do not imply calibrated linear color.

Visually inspected all nine before/after/clean screenshots, default capture and18-cell contact sheet. ffprobe independently reports178.528333s video; decoded and inspected frames at147s and153s show changing playback cells with frozen reference/snapshot. This is retained motion evidence, not performance verification.

Read final parent receipts:283 example and380 package tests pass; both analyses report no issues. Clean sheen/default native logs finish “Application finished.” The retained shutdown listing contains no booted device. These are parent-run receipts, not fresh independent execution or current device/process-state verification. Filtered native logs and the unadvertised-feature warning are not a global crash/capability pass.

## Limits and retained files

Independent tests, builds, native rendering, devices, simulator, adb and UI: NOT_RUN, as instructed. No implementation edits beyond authorized source import; no children, external/PR65 mutations, commits or pushes. Android runtime, other U4 owners/variants/multiview/light types, T2/T4, full U4 and Track E remain open outside this review. Missing coverage alone is not a finding.

Report, provenance/preservation receipts, independent recomputation JSON, video metadata, pre-import state/source backup and reproducible offline setup scripts/log are retained in this r2 directory. Imported sources remain in the isolated app-managed checkout. Temporary replay extraction, color-conversion images and decoded video frames were removed after inspection. Parent evidence was not overwritten.
