## plan | 2026-11-04T05:42:18Z | sha256 308f58070559f5e31fd1f75a0ef4bb8b8d5617521380139cd303883ee0764e1d | REVISE
summary: Simplify implementation sequencing and remove duplicate manual work.
- [LOW] specs/012-st-update/tasks.md:82: Merge US2 and US3 implementation tasks so the fix dispatcher and skill flow are each built in one pass. Evidence: T007/T008 introduce fixes and orchestration; T011/T012 revisit those same functions and skill steps to add refusal rules and questions. Keep the story labels, but write both groups of tests first, then combine T007 with T011 and T008 with T012.
- [LOW] specs/012-st-update/tasks.md:125: Cut the manual N1 negative control from T014. Evidence: T013 already automates adding .stratum/zz-drift.json to a temporary st-init copy and checking the failure. Quickstart N1 explicitly repeats that same mutation manually. Retain the automated control and the distinct N2 exercise.

## plan | 2026-11-04T06:06:39Z | sha256 846e939a3663f27ec479c1693696f845672ade15353197ce82de9f94f98dfbf4 | WAIVED
reason: Inspect fixes F1-F11, F13 only: test names, indent, commit -- paths, name filter, drift keys from st-init, gone siblings, wording; no task added or removed, no approach change

## decisions | 2026-11-04T06:38:30Z | /advisor
summary: US1 decisions: accept 1-7 and 9; 8 should be invalid not discontinued (D1); fix ignore in T007 must reuse --no-index; add test_update_items README line with T013

## decisions | 2026-11-04T07:34:05Z | /advisor
summary: US2/US3 decisions: accept 1,2,4-8,10,12; 3 skip rows need their reason shown, not 'nothing to update'; 9 note T016 as done on main after merge; 11 split the README commands into two blocks; bump to 0.7.0 is needed before plugin update has any effect

## diff | 2026-11-04T09:05:53Z | /advisor
summary: /advisor unavailable in this session, diff d4b00a8..ef7b47c not reviewed by an advisor
