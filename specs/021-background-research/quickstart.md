# Quickstart: background research during the Define grill

Run every command from the repo root. Exact rule text: [contracts/rule-text.md](contracts/rule-text.md). Data shapes: [data-model.md](data-model.md).

## 1. Red states between tasks

`bash tests/test_research.sh` after each test task. Every other row stays green.

| After | Red (expected) | Green by design |
|-------|----------------|-----------------|
| T001 | `#111 FR-001 quick look`, `#111 FR-002 background`, `#111 FR-003 no OK`, `#111 FR-008 summary`, `#111 FR-014 define only` | `FR-014 grill` (st-grill does not change) |
| T003 | `FR-004 order`, `FR-015 define`, `FR-015 redo`, `#111 FR-006 short name`, `#111 FR-006 old path gone`, `#111 FR-004 cap`, `#111 FR-005 same scope` | none |
| T005 | `SC-003 index cmd`, `SC-003 hash cmd`, `#111 FR-007 status cmd`, `#111 FR-007 root`, `#111 FR-007 folder`, `#111 FR-007 decisions` | B3, B5 and every `#111 FR-007 B6` row: they run the test's own command copies; the `cmd` rows tie the copies to the skill |
| T007 | `FR-013 plan proc`, `#111 FR-009 wait`, `#111 FR-010 queue`, `#111 FR-009 gate`, `#111 FR-009 foreign lines`, `#111 FR-011 plan queue`, `#111 FR-012 sources`, `#111 FR-013 both` | none |
| T009 (after the `.c4` edits, before the export) | `tests/test_harness_model.sh`: `FAIL rebuild: page is not rebuilt` | every other harness check |

After each build task (T002, T004, T006, T008) its story's rows go green. After T008 the whole file is green. After T009's rebuild, `bash tests/test_harness_model.sh` is fully green.

## 2. Negative controls

Do each row on its own fresh scratch copy, never in the repo:
`c="$(mktemp -d)"/r && cp -r . "$c"`, make the break with the Edit tool, then run
`ST_ROOT="$c" bash "$c/tests/test_research.sh"`. The output must hold every listed `FAIL` line.

| # | Break in the copy | Must show |
|---|-------------------|-----------|
| N1 | `skills/st-define/SKILL.md`: delete `take a quick look first (a file or two, or a search). ` | `FAIL #111 FR-001 quick look` |
| N2 | `skills/st-define/SKILL.md`: delete ` in the background` | `FAIL #111 FR-002 background` |
| N3 | `skills/st-research/SKILL.md`: change `with no OK` to `after the OK` | `FAIL #111 FR-003 no OK` |
| N4 | `skills/st-define/SKILL.md`: delete `When a report comes in, show a short summary of its findings before the next question. ` | `FAIL #111 FR-008 summary` |
| N5 | `skills/st-define/SKILL.md`: delete `These rules replace the research rule of `st-grill`.` | `FAIL #111 FR-014 define only` |
| N6 | `skills/st-grill/SKILL.md`: delete `Show its findings to the user, then go on with the grill.` | `FAIL FR-014 grill` |
| N7 | `skills/st-research/SKILL.md`: change `<feature folder>/research/<short-name>.md` to `<feature folder>/research.md` | `FAIL FR-004 order`, `FAIL #111 FR-006 old path gone` |
| N8 | `skills/st-research/SKILL.md`: delete ` and no research that runs` | `FAIL #111 FR-006 short name` |
| N9 | `skills/st-define/SKILL.md`: change `At most 3` to `At most 4` | `FAIL #111 FR-004 cap` |
| N10 | `skills/st-define/SKILL.md`: delete ` waits in the queue,` | `FAIL #111 FR-005 same scope` |
| N11 | `skills/st-define/SKILL.md`: change `Pass `feature <folder>`, not a path.` to `Pass `<folder>/research.md` as the research path.` | `FAIL FR-015 define`, `FAIL #111 FR-006 old path gone` |
| N12 | `skills/st-define/SKILL.md`: change `pass `feature <feature_directory>`` to `pass `<feature_directory>/research.md`` | `FAIL FR-015 redo`, `FAIL #111 FR-006 old path gone` |
| N13 | `skills/st-research/SKILL.md`: in the `git status` command only, delete ` ':(exclude,glob)<folder>/research/*.md'` | `FAIL #111 FR-007 status cmd` |
| N14 | `skills/st-research/SKILL.md`: in the `git ls-files -s` command only, delete ` ':(exclude,glob).stratu[m]/state.json'` | `FAIL SC-003 index cmd` |
| N15 | `skills/st-research/SKILL.md`: in the `git ls-files -z` command only, delete ` ':(exclude,glob)<folder>/decisions.m[d]'` | `FAIL SC-003 hash cmd` |
| N16 | `tests/test_research.sh`: in the `st`, `idx` and `hash` heredocs, delete ` ':(exclude,glob)<folder>/decisions.m[d]'` (false finding) | `FAIL #111 FR-007 B6 ignored` |
| N17 | `tests/test_research.sh`: in the `st`, `idx` and `hash` heredocs, change `':(exclude,glob)<folder>/decisions.m[d]'` to `':!specs'` (missed finding) | `FAIL #111 FR-007 B6 finding specs/020-y/spec.md`, `FAIL #111 FR-007 B6 finding specs/021-x/spec.md` |
| N18 | `tests/test_research.sh`: in the three heredocs, change `':(exclude,glob)<folder>/research/*.md'` to `':!<folder>/research/*.md'` | `FAIL #111 FR-007 B6 finding specs/021-x/research/sub/z.md` |
| N19 | `tests/test_research.sh`: in the three heredocs, delete ` ':(exclude,glob).stratu[m]/state.json'` | `FAIL #111 FR-007 B6 ignored`, `FAIL #111 FR-007 B6 no folder ignored` |
| N20 | `skills/st-research/SKILL.md`: delete `From the project root, ` in step 5 | `FAIL #111 FR-007 root` |
| N21 | `skills/st-research/SKILL.md`: delete `, as a path from the project root,` | `FAIL #111 FR-007 folder` |
| N22 | `skills/st-define/SKILL.md`: delete the line `From the time the folder exists, the grill writes its decisions to `<folder>/decisions.md`.` | `FAIL #111 FR-007 decisions` |
| N23 | `skills/st-define/SKILL.md`: delete `before step 2, ` | `FAIL #111 FR-009 wait` |
| N24 | `skills/st-define/SKILL.md`: change `Do not start the queue` to `Start the queue` | `FAIL #111 FR-010 queue` |
| N25 | `skills/st-define/SKILL.md`: delete `Name research that stopped or failed, and the queued scopes for Plan. ` | `FAIL #111 FR-009 gate` |
| N26 | `skills/st-plan/SKILL.md`: delete ` whose `<feature dir>/research/<short-name>.md` does not exist` | `FAIL #111 FR-011 plan queue` |
| N27 | `procedures/plan.md`: delete `Never copy their facts into it.` | `FAIL #111 FR-012 sources` |
| N28 | `procedures/plan.md`: delete `With `research/` too, put the `## Sources` list, which also names this file's rounds, before `## Decisions`. ` | `FAIL #111 FR-013 both` |
| N29 | `procedures/plan.md`: change `With neither` to `With no such file` | `FAIL FR-013 plan proc` |
| N30 | `skills/st-research/SKILL.md`: delete `From the grill in `/stratum:st-define`, start it in the background and go back to the grill; do steps 7 and 8 when its report comes in.` | `FAIL #111 FR-002 background` |
| N32 | `skills/st-define/SKILL.md`: delete ` and no other queue line` | `FAIL #111 FR-010 queue` |
| N33 | `skills/st-plan/SKILL.md`: delete ` A line in another form, such as `- D13 (Q12): ...`, is not a scope.` | `FAIL #111 FR-011 plan queue` |
| N34 | `skills/st-define/SKILL.md`: change `changes a grill answer or an FR` to `changes the spec` | `FAIL #111 FR-009 wait` |
| N35 | `skills/st-define/SKILL.md`: delete ` Then read `<folder>/decisions.md` and show the user every line in it that this Define run did not write.` | `FAIL #111 FR-009 foreign lines` |
| N31 | `tests/test_research.sh`: in the three heredocs, change `':(exclude,glob).stratu[m]/state.json'` to `':!.stratum'` (D6 before D11, missed finding) | `FAIL #111 FR-007 B6 finding .stratum/autonomous/x`, `FAIL #111 FR-007 B6 finding .stratum/research/n.md` |

## 3. Other tests (FR-016)

These read a touched file and must pass with no change to the test:

```bash
bash tests/test_state.sh
bash tests/test_local_files.sh
bash tests/test_test_scope.sh
bash tests/test_no_frontend_design.sh
bash tests/test_advisor_rules.sh
bash tests/test_inspect.sh
bash tests/test_lane_steps.sh
bash tests/test_on_demand.sh
bash tests/test_plan_rules.sh
bash tests/test_triage_rules.sh
bash tests/test_risk_rules.sh
bash tests/test_update_rules.sh
bash tests/test_worker_rules.sh
python3 tests/test_model_hook.py
python3 tests/test_phase_hook.py
bash tests/test_harness_model.sh
[ "$(git diff --name-only 7b18033 -- tests/)" = tests/test_research.sh ]
```

Each command must exit 0. The last one fails when any test file other than `tests/test_research.sh` changed since commit `7b18033`. Run on a machine with node 22.22.3 or later and `npx`: without them `tests/test_harness_model.sh` prints SKIP, not FAIL, for its model checks.

## 4. Manual runs (operator gate)

Operator check. It gates the first release: the merge of the #111 PR into main.

Run in a scratch project with `.stratum/`, git and one older feature `specs/001-old/spec.md`, with `.stratum/state.json` set to `{"feature_directory": "specs/001-old"}`. Autonomous mode off.

| # | Story | Steps | Expected |
|---|-------|-------|----------|
| M1 | US1 | `/stratum:st-define <a task whose grill needs one code fact a quick look cannot find>` | The brief shows in one line, no OK prompt. The next grill question comes before the report. After the report, a short summary shows before the next question (SC-002). `specs/001-old/` gets no file |
| M2 | US1 | Same, with a fact a one-file read answers | No research starts |
| M3 | US2 | A task whose grill has two independent facts the quick look cannot find | Two agents run at the same time; `specs/<NNN>-<name>/research/` holds two files, each with only its own scope (SC-001) |
| M4 | US2 | A task with four such facts | At most 3 run at a time; the fourth starts when one ends (SC-003). The same fact asked twice starts no second run |
| M5 | US3 | During M3 | No git check finding for `decisions.md`, `research/*.md` or `.stratum/state.json`. Edit a code file by hand during a run: a finding. Make a file in `.stratum/autonomous/` by hand during a run: a finding (SC-004, D11) |
| M6 | US4 | End the grill while one run is still going and one scope is queued | Define waits for the run before `spec.md` exists. `decisions.md` ends with `## Queued research` and one `- <short-name>: ...` line. The gate names the queued scope |
| M7 | US4 | Agree the spec, then `/stratum:st-plan` | The queued scope gets `research/<short-name>.md` before the `st-plan` agent starts. `research.md` starts with `## Sources` naming every research file and copies no fact from them (SC-005) |
| M8 | US4 | Run `/stratum:st-plan` on a feature that has only an old `research.md` with `Written by: st-research` | Rounds kept, `## Decisions` at the end, as today |
| M9 | FR-014 | `/stratum:st-grill <a plan whose question needs a code fact>` alone | The research waits for the OK, as today |
| M10 | Edge | `/stratum:st-define` with no description (redo of `specs/001-old`), grill needs a code fact | The file goes to `specs/001-old/research/<short-name>.md`; no new folder |
| M11 | US4 | During a grill with research, add the line `- D99 (Q99): planted.` to `<folder>/decisions.md` by hand | When the grill ends, before `spec.md` exists, Define shows that line to the user (D12) |
