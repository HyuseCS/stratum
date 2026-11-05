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
