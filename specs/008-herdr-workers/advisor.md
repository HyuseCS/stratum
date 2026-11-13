## plan | 2026-11-05T15:50:20Z | sha256 b6d93e1d0b6efa2717ec853a2a7b61dd27c253a30d2a7e4caf141f35f78c7e0c | REVISE
summary: Simplify the #71 negative-control design so test mechanics do not dictate production formatting.
- [MEDIUM] specs/008-herdr- workers/tasks.md:238 and :251: Define NC8 and NC9 by the behavior they disable, and keep their mutation mechanics in the test task rather than prescribing production line layout. Evidence: T019 implements controls by deleting exact source text; T021 consequently requires the last-tab expression to appear exactly once and the worktree-removal operation to occupy a uniquely removable line that leaves valid Bash. Retain the green baseline, changed-copy and parse checks, but let the test mutation accommodate the chosen implementation. This removes formatting constraints from the build task while preserving the planned negative controls.

## plan | 2026-11-05T15:56:08Z | sha256 c04eb0a84f8b2679adea2694cee96218e12ff75301566980d5b0816ea2fc9f6a | APPROVED
summary: The revised plan resolves the previous finding: negative-control mutation mechanics stay in the tests without dictating production formatting. No further approach or task-structure changes are warranted within this plan-only review.

## plan | 2026-11-05T16:14:24Z | sha256 b9a1a35ee602e5d8ce0509065fc6ae4f92f3650e88416ed578fef6c9b39e3cde | APPROVED
summary: The revised plan keeps implementation focused, reuses existing helpers and tests, and sequences local and remote live runs after the build. No further approach or task-structure changes are warranted within this plan-only review.

## decisions | 2026-11-05T17:25:14Z | /advisor
summary: advisor: list acceptable; verify the real-herdr incident left nothing (local clean, laptop unreachable); hand T023/T024 steps to user; drift for st-close: S13b raw line, T019 w1P wording, F7 gap

## diff | 2026-11-05T17:34:55Z | /advisor
summary: advisor: no hidden regression in 1b1666b..5c825e0; stdout-only-TAB check left to the T023 live run

## change | 2026-11-12T16:28:32Z | sha256 726100f10ce5df4ca2c1ac4c19a8575d2d43f407652b26aa746a1b39b463ff76 | REVISE
summary: The Enter change is well scoped, but the dialog plan has two correctness gaps. No files were changed or tests run.
- [HIGH] specs/008-herdr-workers/changes/002-enter-and-working-dialogs.md:16: Apply the live-question check before allowing answer through the existing q branch. Evidence: scripts/st-worker.sh:497 sets q using question(), which accepts an 'Enter to select' screen even with an input box below it. The proposed gate short-circuits on nonempty q, so shown() never checks liveness. The WD3b quoted-question fixture would therefore still allow answer --keys or --text to send input to a working worker. Add answer regression cases for that fixture and require liveness when setting q.
- [MEDIUM] specs/008-herdr-workers/changes/002-enter-and-working-dialogs.md:15: Clear permission-dialog metadata before each shown() evaluation so watch cannot reuse another row's hash. Evidence: The proposed question branch of shown() does not clear BM or SH; only block() resets them (scripts/st-worker.sh:181). A quoted permission dialog in an earlier row can leave BM=block and SH populated even though live returns false. A subsequent working row with a live question sets dlg=1 and incorrectly uses that earlier SH as its seen key. Changes to the question can then be suppressed as already seen. Reset BM/SH or return an explicit dialog kind, and add a two-worker regression test covering this sequence and a changed question.

## change | 2026-11-12T17:42:32Z | sha256 21cb63a4fc6f4bf9a584c0c6bd57d0a90591a7a1632e3952c353a141225a0a2b | APPROVED
summary: The revised plan resolves both previous findings with qlive(), per-call metadata resets, and targeted regression tests. The working-only answer gate preserves the permission checks, and the Enter change covers its callers and remote routing. No files changed and no tests run.
