## plan | 2026-11-01T13:18:08Z | sha256 425a5d5c3d1837acbb0b0daa3241804c6d014a8702d42140df865c695074ec85 | REVISE
summary: Simplify delivery by consolidating small edits to the core workflow and removing an unsupported-platform spike.
- [MEDIUM] specs/011-custom-design-mode/tasks.md:55: Merge US2 and US3's small instruction edits into the core workflow implementation, while retaining their separate live scenarios. Evidence: T012 and T014 deliberately omit bracketed sentences that T017 and T020 later add to the same files. T016 and T019 likewise revisit the same test file. Include these rows in the initial test task and their sentences in the initial implementation tasks to reduce repeated edits and task handoffs. This also delivers existing-screen redesign—the spec's most common use—with the first usable workflow.
- [LOW] specs/011-custom-design-mode/tasks.md:42: Cut T006's Flatpak spike from this feature unless Flatpak support is actually desired. Evidence: Plan G6 explicitly excludes Flatpak support. T006 nevertheless investigates it and requests a user decision if it works, while recommending that it remain unsupported. Keeping the stated scope avoids a separate machine-dependent experiment and decision without changing the planned delivery.

## plan | 2026-11-01T14:01:54Z | sha256 2713ba1dcc39cccb8f1111f4d81a808491f36e377788d5da1d5d4187ad24b762 | REVISE
summary: One execution-order improvement; review limited to planning approach, without correctness, coverage or risk checks.
- [LOW] specs/011-custom-design-mode/tasks.md:119: Separate spike execution from recording results so the shared research file does not serialize independent work. Evidence: The dependency section says T001 and T002 need nothing, yet serializes all five spikes because they write research.md. Run independent probes in separate scratch directories and consolidate their results and contract updates afterward. Keep T004 after installation and T005 after T004. This shortens the setup phase without adding implementation scope.

## plan | 2026-11-01T14:02:55Z | sha256 e96adf17a579773bee038f40cdf036281434ba19ff08b07c01567b4a16e7a1f4 | WAIVED
reason: Round 2 LOW fix only: T001 and T002 probes run side by side; no task, story or design choice changed

## decisions | 2026-11-01T15:13:14Z | /advisor
summary: US1 decisions: keep 1,3-9; item 2 (setup stops do not count against D21's one stop) goes to the user as yes/no; H2 fix must run the whole README test block; L1 steps must add accepting the trust dialog; make the L1 scratch project now

## diff | 2026-11-01T16:07:59Z | /advisor
summary: End-of-Build pass c80a21e..HEAD: nothing blocks; US1 fixes, US4 st-init fix and T021 docs each had red-before tests; merge origin/main into 011 before Close and run every README test line
