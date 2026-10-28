# Observe existing first and second Set target command buffers

Source remains the existing 70-file installation-control packet. No shader,
renderer, queue, target schedule, scene update, or control implementation changes.
The app launch adds only SIMCTL_CHILD_MTL_CAPTURE_ENABLED=1 so Apple's installed
gpucapture can discover it. Both binding variants keep private-update publication.

Use the standard existing Off, Outline-empty, Set-held/request, Clear-held/request,
Set-held/request, Clear-held/request sequence. The native raw files remain the
functional oracle. Initial Off must retain its exact RGBA and there must remain
five admitted target draws and four unchanged held reads per run.

First inspect gpucapture's process and boundary discovery. A source breakpoint
before the target's existing command-buffer allocation may be used through the
installed LLDB to select that already admitted buffer. It must not call render,
update, or create another command buffer. Record the target queue and existing
buffer identity. Capture at most three selected target buffers per variant.
Stop this measurement if capture cannot select the real target or changes the
failure. Do not accept a sibling-only trace or introduce instrumentation.

Inspect the actual target's outline pipeline, mode buffer, sampled mask and
attachments, then subsequent writers and readback. Compare the first failing
Set with the existing second passing Set. Initial Off command capture is optional
if the target queue cannot be selected before its first creation. Its raw output
remains required. Synthetic alpha remains a distinct path and result.

Use gpudebug noninteractively, on the local Mac's compatible GPU. Never profile
or change the GPU state. Terminate only sessions created by this measurement.
Source, normal-main configuration, Pods and six locks must be restored. Close
the owned app and simulator. The A142 and existing Xcode window remain untouched.

The cua foreground request is unnecessary after discovering Apple's installed
gpucapture/gpudebug. No foreground or certificate-trust operation is authorized
by this plan. Official Apple capture guidance and installed man pages describe
the CLI route; no custom capture driver or app capture framework is introduced.
