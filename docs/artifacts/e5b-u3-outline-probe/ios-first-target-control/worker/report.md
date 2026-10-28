# First target contour still fails; one installation control is ready

Scoped verdict. The supplied matched evidence confirms that private-update publication fixes this fixture's mask freshness. It also independently confirms that the complete first requested target render still fails. The controlled first target misses all 267 expected contour pixels despite a current 205-pixel mask. No production correction or shared cause with private alpha is established.

One reversible control is prepared and compiled. It configures the target technique's initial mask and mode before the existing copying installation setter. Native execution of this control is NOT_RUN. This is a single Codex source/evidence investigation, with no children or provider-diversity claim.

## Exact inputs and preservation

HEAD is `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. The checkout was clean before import. Only the supplied actual runtime70 archive was imported. Its SHA256 is `f24f666fca2af5f574fb7b745fa63a04158d3fce1bbfdbfbec7854b9488ee672`. All 70 adjacent manifest identities matched before and after import. Archive processing rejected absolute paths, parent traversal, duplicate/unlisted members and non-regular files, and filtered AppleDouble names. There were no AppleDouble members in this packet. See [import-receipt.json](import-receipt.json).

The final source differs from imported70 in exactly the five authorized disposable paths. All 65 imported peers remain exact, including ToneMapping.swift, SceneViewHost.swift, SelectionOutline.swift, source simulation and scheduler/admission. All 1,873 pre-existing paths outside the import retain their bytes and file modes. The six actual locks/registrant are unchanged. They are dart3d/pubspec.lock, dart3d/example/pubspec.lock, dart3d/example/dn_plugins.lock, dart3d/example/ios/Podfile.lock, dart3d/example/lib/dartnative_plugin_registrant.dart and probe/pubspec.lock. See [preservation-receipt.json](preservation-receipt.json).

I read the applicable AGENTS.md, poteto-mode including its native Codex section, verification guide, local DartNative guide, repo README/program guide and supplied worker diagnosis/patch/receipts. The documented dartnative/ vendor clone is absent in this checkout. No clone or dependency upgrade was created. The current open-PR lookup found draft PR 65, the existing engine stack. The Linear connector rejected a read-only search with `This app tool requires a non-empty string link_id argument`. No issue thread was available through that call and no alternate API was used.

## Independent evidence recomputation

[recompute.py](recompute.py) reads the parent artifacts without writing them. [independent-evidence.json](independent-evidence.json) records the results. All 235 publication evidence-manifest entries and all three local originals match their hashes and lengths, including the full native log and both videos. Both analysis.json files and both first-use.json files agree with the independent pixel oracle.

All 42 raw textures have complete consistent 96 by 72 metadata and expected byte lengths. Targets, alpha inputs, alpha outputs and held reads are BGRA8 sRGB, Metal81. Masks are RGBA16Float, Metal115. The oracle decodes actual little-endian half floats, scans the radius-three circular neighborhood in y-then-x order with strict-greater coverage selection, clamps at texture edges and encodes linear contour RGB to sRGB bytes. It compares all four bytes, including outside-contour alpha.

The baseline mask supports are 0, 205, 0, 205 across Set, Clear, Set, Clear. All four baseline targets composite their actual stale masks exactly. The private-update run has current supports 205, 0, 205, 0. Its first target, at 541431.7500000001, is byte-identical to actual Off. Its mask implies 267 contour pixels and all 267 are missing. Its next three target outputs have zero contour mismatches. Every controlled target preserves every outside-contour RGBA byte.

Each populated mask has 94 orange pixels with linear RGBA 1,.25,.0625,1 and 111 blue pixels with .0625,.5,1,.5. Every remaining mask pixel is zero. Initial Off has 6,695 transparent pixels and 217 opaque geometry pixels. The recorded pass descriptor's alpha-one clear does not justify claiming this actual output is opaque.

Both first synthetic-alpha outputs are exactly 6,912 black opaque pixels. The baseline first outside-contour mismatch count is 6,912. The control count is 6,645 outside plus 267 contour mismatches. This is the same fully failed output measured against a different mask, not an alpha improvement. The remaining three synthetic outputs in each run match their actual masks and preserve outside RGBA. Their cause remains separate from the first target failure.

Both runs have exactly five admitted target draws, initial load plus four explicit requests, and four public highlight batches. All four dirty=false held reads per run are byte-identical to their preceding output. Full logs contain no extra target due, mask/normal encode or highlight events beyond the exported evidence. Four controlled private-renderer callbacks publish 3,0,3,0 draws at the same encode timestamps. In each event sequence, target-mask-encode begins, the private callback publishes, mask-encoded reports return, and target-normal-encode follows. Source establishes that both render encodes use the existing same command buffer; log strings alone do not prove Metal execution or binding internals.

[log-reconstruction.json](log-reconstruction.json) records 34 complete four-byte textures reconstructed exactly from the full native-log base64 rows. All 576 half-float console rows are truncated. I used their complete hash-verified raw files, not invented console bytes. The eight masks each have 72 such truncated rows.

[full-log-receipt.json](full-log-receipt.json) distinguishes receipt snapshots from final originals. Baseline supplied receipt counts 22,177 PID rows; final full log contains 23,556. Control counts are 29,522 and 29,721. The extra 1,379 and 199 scene events occur after the exported snapshot endpoints and contain no additional target or selection operations. The explicit error-marker query recorded in my receipt has zero matches across both complete PID logs. This is not functional success.

All eleven frozen RGB screen crops recompute exactly. I inspected control/03-set-render.png. The left sibling has orange mesh and blue batch contours; the other camera has the orange mesh, and the separated authored child remains unoutlined. This is static screenshot evidence, not target readback, screen-alpha or motion proof.

[independent-video-receipts.json](independent-video-receipts.json) records fresh full ffmpeg decode and ffprobe frame counting. Both exit zero, with 3,831 baseline frames and 3,882 control frames, total 7,713. The new baseline-decode.log and control-decode.log retain four and two duplicate-DTS warnings. No interaction-latency or performance inference is made.

The original negative sibling packet is also checked independently in [original-negative-recomputation.json](original-negative-recomputation.json). All 237 evidence-manifest entries and 29 raw textures verify. Its six mask supports are 0,205,0,0,205,205; every ordinary target composites its actual mask exactly, and its first alpha output fails. This historical run does not override the newer first-target failure exposed by current masks.

The parent restoration receipts and final-config receipt were read and hash-verified. They state accepted66 plus 4,702 prior files were restored, six locks and normal-main Pods restored, and the owned simulator shut down. These are parent cleanup receipts. I did not query a device to turn them into a fresh live-state claim.

## Reachable path and owner

The public contract is that setNodeHighlights followed by one explicit renderTexture request includes the current contour in that first requested output.

1. dart3d/lib/src/scene_controller.dart:403 copies the real public highlight values into the existing command. SceneViewHost.swift:1649 applies valid live-node changes to the sole SelectionOutline colors map, SelectionOutline.swift:13. It issues stored readback, without dirtying the target.
2. SceneViewHost.swift:5803 captures current selected attachments after constraints, then invokes renderDueTargets. RenderTargets.swift:263 admits the existing manual dirty request and clears it once.
3. RenderTargets.swift:301 owns the ordinary target SCNRenderer, camera setup and render-only draw. It shares the source scene intentionally; the host owns source animation, physics and constraints.
4. SelectionOutlineViewsProbe.swift:250 owns the detached mask scene/renderer. Its existing private-update selector remains exactly `control.position.z == -1`. The private renderer performs the existing single update-and-render call and supplies the current mask to the target.
5. Imported RenderTargets.swift:402 installs the composite-only technique when renderer.technique is nil, then binds the installed copy at original line 405. OutlineViewsBinding.bind, final lines 343-352, binds u3MaskSymbol and u3ModeSymbol. ToneMapping.swift:405-431 returns the ordinary base when mode is below 1.5, otherwise samples the mask; lines 548-558 construct the unchanged composite-only pass.

The decisive failure lies after a correctly published mask and before the complete target output. It does not justify moving selection ownership or updating the shared source scene.

## Installed SDK and primary documentation

Exact installed headers, copied without alteration, are in [sdk/](sdk/). [sdk-sha256.json](sdk-sha256.json) records original absolute paths and hashes under /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks/SceneKit.framework/Headers.

- SCNRenderer.h:53-77 distinguishes combined update-and-render, update-only and render-only. The mask already uses combined rendering. The ordinary target deliberately uses render-only. Neither a second render nor a source-scene update follows from these contracts.
- SCNTechnique.h:313-316 declares the renderer's technique property with copy semantics. Apple's [technique property](https://developer.apple.com/documentation/scenekit/scntechniquesupport/technique?language=objc) exposes that same setter contract. Copy semantics do not promise a distinct object identity or document an internal first-use delay.
- SCNTechnique.h:270-293 documents symbol values and keyed subscripting. Apple's [setObject documentation](https://developer.apple.com/documentation/scenekit/scntechnique/setobject(_:forkeyedsubscript:)) supports values set once or infrequently. The source currently installs before providing those initial values. Fully configuring the candidate before the copying setter is a valid installation experiment. The docs do not say that the existing installed-copy binding is invalid.
- SCNSceneRenderer.h:181-196 only lists scenes, nodes, geometry and materials as preparation inputs. Apple's [synchronous preparation documentation](https://developer.apple.com/documentation/scenekit/scnscenerenderer/prepare(_:shouldabortblock:)) describes preloading associated content. It does not document SCNTechnique as a supported input or promise that preparing an already-rendered shared scene publishes a newly installed technique. No unsupported prepare(technique) or speculative prepare(scene) was added.
- SCNSceneRenderer.h:329-336 documents direct presentation-tree changes in the renderer's update callback. This explains the basis of the prior mask experiment. It does not establish that an ordinary render-only target's technique installation uses that same mechanism.
- SCNTransaction.h:14-29 describes per-thread nested transactions and delayed implicit flush while explicit transactions remain open. The evidence does not identify the surrounding transaction state. A thread-wide flush would not isolate the target technique and was not added.

Apple's Markdown links returned Unsupported content-type through the web tool. Indexed Apple documentation above supplied the text; the exact installed headers independently supplied the contracts. No platform tool is declared broken.

## Competing hypotheses

Installation-time initial symbol capture is plausible. The first target technique is installed before receiving its mask/mode, and the shader's default mode can return the base unchanged. Current mask bytes plus an Off-identical target fit either stale parameters or an omitted postprocess pass. They do not prove either.

Deferred first-use technique/program/attachment readiness is also plausible. The first target enables its technique lazily. Its unchanged base image does not tell whether the quad was omitted, sampled stale/empty resources, or received a bypass mode. Successful later outputs argue against a universally invalid kernel, technique definition or Metal API combination.

A current readback mask does not itself prove which resource/version a fragment sampled earlier in the command buffer. Same-buffer encode order and later correct output constrain that hypothesis but do not expose SceneKit's internal sampler binding or synchronization. The pre-install control also supplies the initial mask property before installation; it cannot separately attribute mode versus mask if it succeeds.

The synthetic renderer's first-use empty scene, copied camera and newly installed technique differ from the already-rendered ordinary target. Both first-use failures may be related, or may be independent. This experiment intentionally cannot settle that relationship.

## One prepared control and its limits

The data shape remains one derived OutlineViewsFrame. It gains a fixture-only bindBeforeInstall Boolean. No authoritative state, public library API or wire protocol changes.

DART3D_U3_OUTLINE_BIND_BEFORE_INSTALL defaults false. True makes the invisible fixture marker's x scale equal two. D3Wire.swift:118-119 preserves scale; FsceneRealizer.swift:4172 and SceneViewHost.swift:1576 carry the existing load/transform paths. The marker has no geometry or children. Its existing z-position publication selector is untouched. Real mode/camera mutations retain the boot selector; the baseline still emits translation-only mutations.

Only the existing target technique creation block changes behavior. On true, it calls the existing binding method on the candidate before assigning renderer.technique. Both variants then perform the original binding of renderer.technique before the original single ordinary render. The default retains the original order. There is no early installation at initial Off, warm-up draw, update, prepare, flush, retry, wait, dirty mark, new queue/clock, scene recreation or alternative compositor.

The existing bind method records an `installed-copy` identity message even when called on this control's not-yet-installed candidate. Do not interpret that message label alone as proof of installation. The additional target-technique-install event brackets the setter and logs target, view, selector, mode and timestamp. If SceneKit returns a distinct installed copy, the subsequent original bind observes that identity as well. This is CPU observation only.

The complete targetProof synthetic-alpha method and shared bind arithmetic are byte-identical to imported70. ToneMapping.swift is also byte-identical. No candidate binding executes for syntheticRenderer; its existing construction and draw remain unchanged.

The scope excludes a production fix. A successful result would support initial configured technique installation for this finite fixture. It would not prove a particular SceneKit internal cause, fix the separate alpha output, or establish production safety.

## Parent runtime decision

Run matched launches from this same final70 packet. Keep DART3D_U3_OUTLINE_PUBLISH_IN_UPDATE=true in both. Set DART3D_U3_OUTLINE_BIND_BEFORE_INSTALL=false for baseline and true for control. Boot Off, two siblings, paused, no AA, manual 96 by 72 target. Enable Outline with empty selection, then Set-held, one explicit render, Clear-held, one explicit render, and repeat Set/Clear with one request each. Do not add diagnostic draws before judging those first requested outputs.

An informative baseline reproduces current masks 205,0,205,0 and the missing first 267-pixel target contour. The control must log the true installation branch at its first requested non-Off target encode. Both variants must retain five due draws, four highlight batches, current callback membership/time/order, four identical held reads and unchanged screen crops.

Pass requires the controlled first Set target to contain the full current contour with correct RGBA, followed by all three current transitions passing the same oracle and preserving every outside byte. A changed historical raster count requires judging against actual current geometry/mask, not accepting a count in isolation. Recompute synthetic alpha separately and retain its result even if the target succeeds.

A branch that runs with the expected current mask but still misses the first contour refutes this control as sufficient. If the baseline no longer reproduces, the selector fails to arrive, admission changes, masks become stale or the controlled output changes outside the expected contour, the experiment is inconclusive or invalid. Do not call it a fix or add another control automatically. Neither result licenses a source-scene update.

## Host verification and delivery

Analysis reports no issues. The real-controller fixture/W34 suite passes 25 tests, including all four combinations of the existing publication selector and new installation selector. It checks the loaded scene differs only in the marker, observes real binary transform fields through public controller calls, and verifies no implicit render mutation. The highlight suite passes 13 tests. All 14 plugin Swift files typecheck together. The generic arm64 Debug simulator app build reports BUILD SUCCEEDED and explicitly compiles SelectionOutlineViewsProbe.swift. These are host source/compilation checks, not GPU proof. Exact commands are in [verification.md](verification.md).

Existing build warnings include the engine's newer simulator deployment version, missing Metal toolchain Swift search path, a Flutter umbrella header omission, and skipped AppIntents metadata without its framework dependency. They did not fail compilation. No pin or lock changed. Own log copies redact build-define/license environment lines; [log-sanitization.json](log-sanitization.json) records counts. Supplied secrets/config values were not deleted or changed.

The initial snapshot assertion used Flutter registrant paths that this DartNative repo does not have. It failed before import or setup writes. Inspection identified the actual six files and the corrected snapshot/import passed. The source lookup also confirmed the absent vendor clone and a missing schedule.log name; recomputation reads the actual native-events files. [investigation-notes.log](investigation-notes.log) retains these diagnostics. There were no failed host analysis, test, typecheck or generic-build runs.

[control-only.patch](control-only.patch) is correction-only relative to exact imported70, not HEAD. Its SHA256 is `cb7aa7e908d6a34560bcef20e7bf55a00fb8e531e1c54f14cd0025e62afa224d`. [owned/](owned/) contains all five complete files. [final70-control/source.tgz](final70-control/source.tgz) and source-sha256.json contain the coherent final70, archive SHA256 `433daa2a14f574564bc1f91af3a3cdc23fe215e843a1b2e1ee3bcb33d2b7c5e2`.

[package.py](package.py) and [replay-receipt.json](replay-receipt.json) verify all 70 identities before, after forward patch application, after reverse application and inside the final archive. Replay used a plain temporary archive directory, no checkout/worktree, and removed that directory. No temporary clone was made.

Own generated build/test/Pods outputs were removed. Only the two ignored Generated.xcconfig and dn_export_environment.sh files remain, normalized to lib/main.dart with no outline probe defines. [normal-main-receipt.json](normal-main-receipt.json) records that check. Every final source still matches the packaged manifest after cleanup. Parent artifacts remained read-only.

NOT_RUN for the new control includes native app execution, GPU/Metal shader execution, devices or simulator discovery/use, Android/A142, production integration, performance, moving alignment/deformation, MSAA runtime, single host, replacement/retirement stress, W34 runtime coexistence, reduced-scale width, T2/T4 and whole-U3 acceptance. The parent owns integration, comment audit and native verification. No commits, pushes, PR/issue changes, external writes or dependency upgrades were performed.

The pstack Fix Root Causes principle kept this at the first target's technique boundary and excluded compensating draws. Model the Domain kept the selector in the existing derived frame and marker. Build the Lever produced rerunnable raw recomputation and patch replay instead of relying on supplied conclusions. These principles do not turn the unperformed native lane into a pass.
