# Parent reload integration checkpoint

The six-file worker patch was hash-verified, checked and applied to the existing
source52 writer. Parent replayed the 28 supplied integration tests successfully.
Accepted52 and six locks remained unchanged. No native files were edited.

Parent added one real invalid-UTF8 file-save test. The first custom-zone test
wrapper timed out and is retained as parent-utf8-before.log, a test failure and
not a reproduced production defect. Installed file_impl.dart:699–715 wraps
decode failures in FileSystemException, which the host already catches. The
direct real-file test passes without a host change. Valid file replacement
recovers while invalid bytes retain controller identity and send no mutation.

The read-only no-comments audit recommended three deletions and one ownership
correction. All accepted. Removed the cleanup justification, the open-response
test narration, and the example's Later banner. No comments restored, no audit
rerun, no suppressions, no encoding or unresolved constraint. The audit retained
five public contract comments and five external SDK/platform constraints.

Preparation now stores its handled nullable candidate future. Expected input
rejections are reported once by reception; stop joins that completion and no
longer catches the same FormatException again. Unexpected errors still propagate.
The chosen active-preparation drain remains. The small ownership sketch is in
parent-error-ownership-sketch.md. This is an ownership refactor, not a claimed
reproduced user-visible failure. Public API and transport are unchanged.

All29 integration tests pass after this correction in
parent-focused-owned-errors.log. Both final package analyses are clean. Parent
git diff check passes. Worker's 86 package and53 example regressions are preserved
as worker results before this parent delta, not exact-current-tree execution.

Frozen source58 and complete six-file patch hashes are in parent-artifact-sha256.txt.
All52 accepted paths and six lock/registrant hashes were verified at packaging.
Native source/frame evidence and independent source review remain pending here.
A142 has no targeted query, launch or input. Only the approved iPhone17Pro
simulator is opened for the next bounded asset proof.
