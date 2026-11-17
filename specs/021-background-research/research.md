# Research: background research during the Define grill

No `research/` folder and no `st-research` file for this feature. Facts below come from the code and probes on this machine (git 2.56.1, Claude Code 2.1.325), 2026-11-17.

## R1. How the git check ignores paths

- Decision: add the git exclude pathspec `-- . ':(exclude,glob).stratu[m]/state.json' ':(exclude,glob)<folder>/decisions.m[d]' ':(exclude,glob)<folder>/research/*.md'` to the `git status`, `git ls-files -s` and `git ls-files -z --modified --others` commands of `skills/st-research/SKILL.md` step 5. With no feature folder, `<folder>` is `.stratum`.
- Rationale: one command form for every run, testable by exact grep and by running it in a real repo. Probe: writes to `<folder>/research/a-b.md` (also staged), `<folder>/decisions.md` and `.stratum/state.json` give the same snapshot; a change to a code file, a new `.stratum/autonomous/x`, a new `.stratum/research/n.md` in a feature run, another feature's `spec.md`, this feature's `spec.md`, a staged spec, `research/notes.txt` and `research/sub/z.md` each change it. `git status` and the two `ls-files` commands accept only exclude-style specs after `.`; the hooks `st-git-guard.py` and `st-approve.py` pass all three commands with no deny.
- Alternatives considered: plain `:!<folder>/research/*.md` (also hides `research/sub/z.md`, because `*` crosses `/` without glob magic); filtering the output by eye (the index hash is one line for all files and cannot be filtered); a new snapshot script (rejected: the rule fits in text).

## R2. Run from the project root, relative folder

- Decision: step 5 starts "From the project root" and `<folder>` is a path from the project root.
- Rationale: probe: from `src/`, `-- .` misses a change in `specs/`. An absolute `<folder>` in `:!` does not exclude `decisions.md`.
- Alternatives considered: `:/` (top) magic in each spec (longer, same effect as running from the root).

## R3. Background runs

- Decision: Define starts `/stratum:st-research` and the skill starts the agent in the background; steps 7 and 8 run when the report comes in.
- Rationale: Claude Code 2.1.325 Agent tool text: "Agents run in the background by default ... you will be notified when it completes", with `run_in_background` to choose. The spec assumption holds for the installed version.
- Alternatives considered: none; a foreground run is today's blocking behaviour.

## R4. Decisions file during a new Define

- Decision: Define step 1 says the grill writes its decisions to `<folder>/decisions.md` from the time the folder exists.
- Rationale: `skills/st-grill/SKILL.md:29` picks the file from `.stratum/state.json`; `hooks/st-phase.py:137-141` sets `feature_directory` to the new folder only once its `spec.md` exists. Without the rule, grill decisions go to the older feature's `decisions.md`, which the ignore list does not cover: a false finding each run (SC-004). D6 names `<folder>/decisions.md` as the file this Define run writes.
- Alternatives considered: edit `st-grill` (vendored, and FR-014 keeps it as is for a lone grill); ignore the older feature's folder (D6 rejects ignoring a whole folder).

## R5. Queue line format and re-runs

- Decision: one line per scope under `## Queued research`: `- <short-name>: <scope and questions>`. Plan runs a line only when `<feature dir>/research/<short-name>.md` does not exist, passing that exact `path`.
- Rationale: Plan's own grill appends `- D13 (Q12): ...` lines at the end of the same file, below the heading; the short-name form tells them apart. The file test stops a second Plan run from running the scope again.
- Alternatives considered: delete lines after the run (Plan would edit Define's record); no format (Plan cannot tell scopes from decisions).

## R6. Tests that read the touched files

- Decision: each task's `Test:` names the tests that grep its file. `skills/st-define/SKILL.md`: `tests/test_research.sh`, `tests/test_state.sh`. `skills/st-research/SKILL.md`: `tests/test_research.sh`. `skills/st-plan/SKILL.md`: `tests/test_research.sh`, `tests/test_advisor_rules.sh`, `tests/test_inspect.sh`, `tests/test_lane_steps.sh`, `tests/test_on_demand.sh`, `tests/test_plan_rules.sh`, `tests/test_triage_rules.sh`. `procedures/plan.md`: `tests/test_research.sh`. Tests that glob all skills or procedures: `tests/test_state.sh` (S8), `tests/test_local_files.sh`, `tests/test_test_scope.sh`, `tests/test_on_demand.sh`, `tests/test_triage_rules.sh`, `tests/test_lane_steps.sh`, `tests/test_inspect.sh`, `tests/test_no_frontend_design.sh`. Every skill or procedure edit also runs `bash tests/test_harness_model.sh coverage-data missing`. Each story has one build task with all of these in its `Test:`, because `tests/test_research.sh` exits 1 on any red row.
- Rationale: grep of `tests/` for each path and for globs over `skills/` and `procedures/`. Dry run: the contract text applied to a scratch copy turns `tests/test_research.sh` fully green (112 ok rows after D11) and keeps `test_state`, `test_local_files`, `test_test_scope`, `test_advisor_rules`, `test_lane_steps`, `test_on_demand`, `test_plan_rules`, `test_triage_rules` and `test_harness_model.sh coverage-data missing` green; all 31 negative controls of quickstart.md section 2 show their `FAIL` lines (N13 to N19 and N31 re-run after D11). `test_inspect` and `test_no_frontend_design` need a git checkout and fail the same way on an unchanged copy, so they were run only in the repo (green at baseline). `tests/test_harness_model.sh` reads all harness files for `.stratum/<name>`; the new text adds no new name.
- Alternatives considered: run the full suite (not allowed per task).
