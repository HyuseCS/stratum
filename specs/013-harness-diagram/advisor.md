## plan | 2026-11-05T15:55:21Z | sha256 1ff2efed8004c0ce02eaf18582b81932a245555e74e0706d49f2c8eed0c0827a | REVISE
summary: Simplify the task split by combining the three small topic-view tasks.
- [LOW] specs/013-harness-diagram/ tasks.md:101: Merge T017–T019 into one topic- views task, retaining the three output files and running the shared views check once. Evidence: Each task only applies the include rules already specified in model-format.md and runs the same check. The execution plan schedules all three separately within a 16-task wave. One owner can implement these related views with fewer handoffs and repeated setup, while preserving the separate model and lane-view tasks.

## plan | 2026-11-05T16:14:35Z | sha256 9b1745e00bc6618a52755d1c97cd47c09750749f519818be634026eea4609b8c | WAIVED
reason: Plan changed at Inspect only by fixes of Inspect findings F1-F14 (test greps, negative controls, README commit order, wording) and user decisions D11 (pin note) and D12 (drop lane tags); no story, task or file-list change.

## decisions | 2026-11-05T16:46:13Z | /advisor
summary: US1+US2 small decisions: 14 of 15 ok; restore the st-close APP-constitution write (fix missing check), make views fail on a missing lane file, quickstart names the 3 phase gates; render the page in a browser before the PR

## diff | 2026-11-05T16:58:46Z | /advisor
summary: End-of-Build diff 3c5a3f7..c6e9743 docs only, approve; resolve gap G2 vs model, pre-check snap allowed by nomcp/rebuild and the snap folder, fix tasks.md dependency line at Close

## plan | 2026-11-05T23:28:47Z | sha256 3dec05229e4ea303dc8d64df6054d46812910ee00db150eadc7dddf5d2af9293 | APPROVED
summary: The earlier topic-view consolidation is incorporated. The remaining lane splits have clear ownership and a shared integration step; no further task cuts or merges are warranted within this plan review.
