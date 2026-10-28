# Xcode command capture — first outlined target

The first requested 96×72 target still omits its outline. Xcode capture is available, but this trace captured the 1206×2058 main-view command buffer, so it does not establish why the target's first technique pass fails. No rendering correction or production acceptance is claimed.

The operator approved brief foreground Xcode control and cleared its window. The parent opened its own writer workspace, selected the approved iPhone 17 Pro simulator, left GPU capture set to Automatically, attached to its own Runner PID 79445, and captured one SceneKit command buffer. No physical device was used. No certificate dialog was accepted or trust setting changed.

## Observations

- The exact 70-file probe source is retained in `runtime-source/`. Its archive SHA-256 is `3536bdb1291ff164f287b2259139283efe33fd644c9afe963b9ce424624b03a9`. Source identities match the prior control; publication-in-update is enabled and bind-before-install is disabled.
- There were two scheduled target draws: initial Off and one explicit Set request. The held read between them is byte-identical to Off. No Clear, repeated request, or warm-up draw was added.
- The first Set mask has 205 current selected pixels. All 267 expected contour pixels are absent, and the output remains identical to Off. The separate private-alpha first-use failure also remains. See `baseline/analysis.json` and retained raw bytes.
- Breakpoint 1 stopped the target owner before `queue.makeCommandBuffer()` at RenderTargets.swift:391. The debugger displayed queue `0x103d9e580`. After capture was armed and execution resumed, Xcode captured a different draw. Selecting the named SceneKit queue did not reliably isolate the target buffer.
- `baseline/first-set.gputrace` contains one command buffer, three render encoders, one compute encoder, and two draws. Attachments are 1206×2058. The final draw uses `d3_resolve_vertex` / `d3_resolve_fragment`; its textures include the main-view image and 1×1 fallback. The static search found no `u3_views_outline`. This is evidence about this captured buffer, not evidence that the target compositor never executes.
- The filtered native log has 201,122 PID rows and zero matches for the documented error query. No video, performance measurement, or calibrated color result was produced.

## Cleanup and limits

The parent removed only its own breakpoint, stopped its Runner and log stream, terminated gpudebug session 11, shut down the simulator, closed only its own Xcode workspace, and ended its Cua session. The pre-existing off-screen Xcode windows were left alone.

Accepted66 was restored and the four probe-only additions removed. Xcode had automatically upgraded the shared scheme before the source snapshot; that exact rewrite is retained in `xcode-ui/Runner.xcscheme.xcode-upgraded` and was reversed to its verified pre-Xcode hash. All 5,206 prior files match, with this earlier scheme identity restored. Pods and normal-main configuration were regenerated, and all six lock/registrant checks pass. See restoration and preservation receipts.

The full 45 MB native log remains local at the hashed path recorded in `final-preservation.json`; filtered events, raw textures, trace, screenshots, source archive and summaries are retained here. Host checks from the identical prior source were reused; no fresh tests or builds beyond the actual simulator launch build were added. Whole U3, W34, E9 and Track E remain open. The next command measurement must identify the actual target buffer before drawing conclusions about its shader, uniforms, or later writers.
