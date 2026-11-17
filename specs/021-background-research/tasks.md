---
description: "Tasks for 021 background research during the Define grill"
---

# Tasks: background research during the Define grill

**Input**: `specs/021-background-research/` (spec.md, decisions.md, plan.md, research.md, data-model.md, contracts/rule-text.md, quickstart.md)

**Tests**: required (FR-015, FR-016). Each test task comes before the build task of its story and must fail first, with exactly the red rows in quickstart.md section 1.

**Build rules (plan.md)**: copy the text of contracts/rule-text.md byte for byte. Each new or changed skill sentence is one line, no wrap. Keep every other line of each file. Do not edit `skills/st-grill/SKILL.md`, `agents/`, `procedures/research.md` or any test file but `tests/test_research.sh`. Add no comment to the test file.

**Baseline**: every test named below passes on commit `7b18033`.

**Build test command** (`<SK>` below): `bash tests/test_research.sh && bash tests/test_state.sh && bash tests/test_local_files.sh && bash tests/test_test_scope.sh && bash tests/test_on_demand.sh && bash tests/test_triage_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_inspect.sh && bash tests/test_no_frontend_design.sh && bash tests/test_harness_model.sh coverage-data missing`. These are the tests that read `skills/st-define/SKILL.md`, `skills/st-research/SKILL.md` or `procedures/plan.md`, by path or by a glob over all skills and procedures.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

---

## Phase 1: Setup

None.

## Phase 2: Foundational

None.

---

## Phase 3: User Story 1 - Research runs while the grill goes on (Priority: P1) MVP

**Goal**: In the Define grill, a fact the quick look cannot find starts `st-research` in the background with no OK; the grill goes on; a report gets a short summary before the next question. A lone `/stratum:st-grill` keeps the OK.

**Independent Test**: T001 rows green after T002; quickstart.md M1, M2, M9.

- [X] T001 [US1] Tests for FR-001, FR-002, FR-003, FR-008, FR-014 (FR-015) in tests/test_research.sh, red until T002. Add these rows to the `phrases` heredoc (tab between name, target and phrase), after the row `SC-003 ignored`:
  `#111 FR-001 quick look` / `skills/st-define/SKILL.md` / ``For a fact a grill question or the plan needs, take a quick look first (a file or two, or a search).``;
  `#111 FR-002 background` / `skills/st-define/SKILL.md` / ``run `/stratum:st-research` (Skill tool) in the background with the fact as its scope, and ask the next question that does not need the fact.``;
  `#111 FR-002 background` / `skills/st-research/SKILL.md` / ``From the grill in `/stratum:st-define`, start it in the background and go back to the grill; do steps 7 and 8 when its report comes in.``;
  `#111 FR-003 no OK` / `skills/st-research/SKILL.md` / ``From the grill in `/stratum:st-define`: show the brief in one line and start the research at once, with no OK; skip the rest of this step.``;
  `#111 FR-008 summary` / `skills/st-define/SKILL.md` / ``When a report comes in, show a short summary of its findings before the next question.``;
  `#111 FR-014 define only` / `skills/st-define/SKILL.md` / ``These rules replace the research rule of `st-grill`.``
  Keep the `FR-014 grill` rows as they are. Test: bash tests/test_research.sh.
- [X] T002 [US1] Build FR-001, FR-002, FR-003, FR-008, FR-014. In skills/st-define/SKILL.md insert contracts/rule-text.md C2 line A as a new line right before the line that starts `   When the grill needs `/stratum:st-research``. In skills/st-research/SKILL.md, step 4 gets the C1 "Step 4" first sentence before `Show the scope`, and step 6 gets the C1 "Step 6" sentence at its end. Test: `<SK>`.

**Checkpoint**: T001 rows green.

---

## Phase 4: User Story 2 - Several research agents at once, each with its own file (Priority: P1)

**Goal**: Each research run of a feature writes `<folder>/research/<short-name>.md` with a unique short name; at most 3 run, the rest wait first in, first out; no scope runs twice.

**Independent Test**: T003 rows green after T004; quickstart.md M3, M4, M10.

- [ ] T003 [US2] Tests for FR-004, FR-005, FR-006 (FR-015, FR-016) in tests/test_research.sh, red until T004. Replace the phrase of row `FR-004 order` with ``Output path, in this order: the path the caller gives; else `<feature folder>/research/<short-name>.md` when the caller names a feature folder; else `.stratum/research/<short-name>.md``. Replace the `FR-015 define` row whose phrase is ``Pass `<folder>/research.md` as the research path.`` with the phrase ``Pass `feature <folder>`, not a path.``. Replace the phrase of row `FR-015 redo` with ``In a redo (step 0.2), make no folder: pass `feature <feature_directory>` for the feature in `.stratum/state.json` that step 0.2 redoes.``. Add rows after the T001 rows:
  `#111 FR-006 short name` / `skills/st-research/SKILL.md` / ``A short name is 2 to 4 lowercase words joined by hyphens that no file in that folder and no research that runs uses.``;
  `#111 FR-004 cap` / `skills/st-define/SKILL.md` / ``At most 3 research runs at a time: put a further scope in a queue and start it, first in, first out, when one ends.``;
  `#111 FR-005 same scope` / `skills/st-define/SKILL.md` / ``Start no scope whose questions are in the brief of research that runs, waits in the queue, or is done.``.
  After the `SC-003 index cmd` check, add `check "#111 FR-006 old path gone" '! grep -qF -- "/research.md" "$root/skills/st-define/SKILL.md" && ! grep -qF -- "<feature folder>/research.md" "$s"'`. Test: bash tests/test_research.sh.
- [ ] T004 [US2] Build FR-004, FR-005, FR-006. In skills/st-research/SKILL.md replace the first paragraph of step 3 with contracts/rule-text.md C1 "Step 3" new text. In skills/st-define/SKILL.md replace the line that starts `   When the grill needs `/stratum:st-research`` with C2 line B, and add C2 line C right after it. Test: `<SK>`.

**Checkpoint**: T001 and T003 rows green.

---

## Phase 5: User Story 3 - The safety check stays real with agents in parallel (Priority: P1)

**Goal**: The git check of a run ignores `.stratum/state.json`, `<folder>/decisions.md` and `<folder>/research/*.md`, and shows every other change, the rest of `.stratum/` included (D11); the Define grill writes its decisions to `<folder>/decisions.md`.

**Independent Test**: T005 rows and block B6 green after T006; quickstart.md M5.

- [ ] T005 [US3] Tests for FR-007 (FR-015, FR-016) in tests/test_research.sh, red until T006. Set the `idx` and `hash` heredocs to the contracts/rule-text.md C6 `idx` and `hash` lines, and add a heredoc `st` (same `IFS= read -r st <<'EOF'` form, right after `hash`) with the C6 `st` line. Add `check "#111 FR-007 status cmd" 'grep -qF -- "$st" "$s"'` after the `SC-003 index cmd` check; keep the `SC-003 index cmd` and `SC-003 hash cmd` checks, which now compare the new copies. Add rows after the T003 rows:
  `#111 FR-007 root` / `skills/st-research/SKILL.md` / ``5. From the project root, note `git rev-parse HEAD```;
  `#111 FR-007 folder` / `skills/st-research/SKILL.md` / the last sentence of contracts/rule-text.md C1 "Step 5" (it starts with `` `<folder>` is the feature folder``);
  `#111 FR-007 decisions` / `skills/st-define/SKILL.md` / ``From the time the folder exists, the grill writes its decisions to `<folder>/decisions.md`.``.
  B3: run `"${hash//<folder>/.stratum}"` in place of `"$hash"`. B5: run `"${idx//<folder>/.stratum}"` in place of `"$idx"` (both lines). Add block B6 before `exit $fail`: a repo `$tmp/g` made with `git init -q`, files `src/a.sh`, `.stratum/state.json`, `specs/021-x/decisions.md`, `specs/021-x/spec.md`, `specs/020-y/spec.md`, all committed (`-c user.name=t -c user.email=t@t`). `snap()` runs `st`, `idx` and `hash` from the repo root, each through `bash -c "${c//<folder>/$1}"`, and prints all output. With `f=specs/021-x`: take `snap "$f"`; write `$f/research/a-b.md` (staged) and `$f/research/c-d.md` (untracked), append to `$f/decisions.md`, change `.stratum/state.json`; then row `#111 FR-007 B6 ignored` (snapshot unchanged). Then, one at a time and undone after each (checkout a tracked file, delete a new one), change each of `src/a.sh`, `specs/020-y/spec.md`, `specs/021-x/spec.md`, `specs/021-x/research/sub/z.md` (new), `specs/021-x/research/notes.txt` (new), `src/new.sh` (new), `.stratum/autonomous/x` (new), `.stratum/research/n.md` (new): row `#111 FR-007 B6 finding <path>` (snapshot differs). Then `#111 FR-007 B6 back to base` (equal again), and `#111 FR-007 B6 staged` (stage a change to `src/a.sh`, then write its committed content back to the work tree: the snapshot differs; `git reset -q -- src/a.sh` after). No folder: take `snap .stratum`, change `.stratum/state.json` and write `.stratum/research/m.md`: `#111 FR-007 B6 no folder ignored` (equal); append to `src/a.sh`: `#111 FR-007 B6 no folder finding` (differs). Test: bash tests/test_research.sh.
- [ ] T006 [US3] Build FR-007. In skills/st-research/SKILL.md replace step 5 with contracts/rule-text.md C1 "Step 5"; keep step 7 as it is. In skills/st-define/SKILL.md add C2 line D right after line C (plan.md design note 4). Test: `<SK>`.

**Checkpoint**: T001, T003 and T005 rows green.

---

## Phase 6: User Story 4 - Define waits at the end of the grill, and Plan uses the files (Priority: P2)

**Goal**: Define waits for running research before Specify, writes the queue under `## Queued research`, and names it at the gate. Plan runs the queue first; the `st-plan` agent reads `research/` and writes `research.md` as `## Sources` plus decisions.

**Independent Test**: T007 rows green after T008; quickstart.md M6, M7, M8.

- [ ] T007 [US4] Tests for FR-009 to FR-013 (FR-015, FR-016) in tests/test_research.sh, red until T008. Replace the phrase of the `FR-013 plan proc` row ``With no such file, follow steps 1 to 3.`` with ``With neither, follow steps 1 to 3.``. Add rows after the T005 rows:
  `#111 FR-009 wait` / `skills/st-define/SKILL.md` / ``When the grill ends, before step 2, wait for all research that runs and show each finding that changes a grill answer or an FR.``;
  `#111 FR-010 queue` / `skills/st-define/SKILL.md` / ``Do not start the queue: under `## Queued research` at the end of `<folder>/decisions.md`, write one line `- <short-name>: <scope and questions>` for each queued scope and each research that stopped or failed, with a short name that no file in `<folder>/research/` and no other queue line uses.``;
  `#111 FR-009 gate` / `skills/st-define/SKILL.md` / ``Name research that stopped or failed, and the queued scopes for Plan.``;
  `#111 FR-009 foreign lines` / `skills/st-define/SKILL.md` / ``Then read `<folder>/decisions.md` and show the user every line in it that this Define run did not write.``;
  `#111 FR-011 plan queue` / `skills/st-plan/SKILL.md` / the whole contracts/rule-text.md C4 line;
  `#111 FR-012 sources` / `procedures/plan.md` / ``If `FEATURE_DIR/research/` has files, read each one and use its facts. Do not research again what they answer. Research only the unknowns they do not cover.``;
  `#111 FR-012 sources` / `procedures/plan.md` / ``Write `research.md` as your own file: a `## Sources` list that names each research file, then your Decision/Rationale/Alternatives items. Never copy their facts into it.``;
  `#111 FR-013 both` / `procedures/plan.md` / ``With `research/` too, put the `## Sources` list, which also names this file's rounds, before `## Decisions`.``. Test: bash tests/test_research.sh.
- [ ] T008 [US4] Build FR-009 to FR-013. In skills/st-define/SKILL.md add C2 line E right after line D, and apply C3 in the gate. In skills/st-plan/SKILL.md add C4 as step 3 of "0. Start", after step 2. In procedures/plan.md replace the `**Research from st-research.**` paragraph of Phase 0 with the two C5 paragraphs. Test: `<SK>` && bash tests/test_advisor_rules.sh && bash tests/test_plan_rules.sh.

**Checkpoint**: tests/test_research.sh fully green.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T009 Harness model and README (D13), in the shape of commit `1e9bad3`. Apply contracts/rule-text.md C7 to docs/harness/model/data.c4, docs/harness/model/agents.c4, docs/harness/model/procedures.c4, docs/harness/atlas/data.mjs and README.md. Then rebuild, from the repo root: the atlas build command that `tests/test_harness_model.sh` `readme` checks in README.md (`t=$(mktemp -d) && cp ~/.claude/skills/system-atlas/assets/build.mjs ~/.claude/skills/system-atlas/assets/template.html docs/harness/atlas/data.mjs "$t" && node "$t/build.mjs" && cp "$t/atlas.html" "$t/SYSTEM.md" docs/harness/atlas/ && rm -rf "$t"`, which writes docs/harness/atlas/atlas.html and docs/harness/atlas/SYSTEM.md), then `npx -y likec4@1.60.0 export markdown docs/harness` (writes docs/harness/README.md). Red before the export: `FAIL rebuild: page is not rebuilt`. No backticks in `.c4`; each summary 1 to 200 characters, at most 2 sentences. Run on a machine with node 22.22.3 or later and `npx`: without them `validate` and `rebuild` print SKIP, not FAIL. Test: bash tests/test_harness_model.sh && bash tests/test_research.sh && bash tests/test_advisor_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_inspect.sh && bash tests/test_no_frontend_design.sh && bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh && bash tests/test_triage_rules.sh && bash tests/test_update_rules.sh && bash tests/test_worker_rules.sh && python3 tests/test_model_hook.py && python3 tests/test_phase_hook.py.
- [ ] T010 FR-016: the tests that read a touched file pass with no change to them, and only tests/test_research.sh changed under `tests/` (quickstart.md section 3). Run it on a machine with node 22.22.3 or later and `npx`: without them `tests/test_harness_model.sh` prints SKIP, not FAIL, for its model checks, and T010 does not count. Test: bash tests/test_state.sh && bash tests/test_local_files.sh && bash tests/test_test_scope.sh && bash tests/test_on_demand.sh && bash tests/test_triage_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_inspect.sh && bash tests/test_no_frontend_design.sh && bash tests/test_advisor_rules.sh && bash tests/test_plan_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_update_rules.sh && bash tests/test_worker_rules.sh && python3 tests/test_model_hook.py && python3 tests/test_phase_hook.py && bash tests/test_harness_model.sh && [ "$(git diff --name-only 7b18033 -- tests/)" = tests/test_research.sh ].
- [ ] T011 Operator check, quickstart.md section 4, runs M1 to M11 by hand in a real session (SC-001 to SC-005). It gates the first release: the merge of the #111 PR into main. Test: quickstart.md section 4, by hand.
- [ ] T012 Negative controls N1 to N35 (FR-015, SC-006), quickstart.md section 2: each row on its own fresh copy, break made with the Edit tool, never in the repo. Record each row's `FAIL` lines in the task report; a row with a missing `FAIL` line goes back to the test task of its story. It needs only T008 and may run before T011. Test: ST_ROOT="$c" bash "$c/tests/test_research.sh" on each copy.

---

## Dependencies & Execution Order

- Phases 1 and 2 are empty.
- No two user stories run at the same time: US1 to US4 all edit `tests/test_research.sh` and `skills/st-define/SKILL.md`, and US1 to US3 all edit `skills/st-research/SKILL.md`. Order: US1, US2, US3, US4, then Polish.
- No task is `[P]`. Each story has one build task, because `tests/test_research.sh` exits 1 on any red row: two build tasks of one story that split the files could not each pass their own test.
- In each story, the test task runs first and must show its red rows (quickstart.md section 1), then the build task makes them green.
- C2 lines are placed relative to each other (A before B, then C, D, E), so T002, T004, T006 and T008 must land in that order, which the phase order gives.
- T009 runs after T008. T010 runs after T009, because its full `tests/test_harness_model.sh` and the README readers need the model and README edits. T011 runs after T010. T012 needs only T008; IDs T010 and T011 stay as the plan.md Validate section names them, so the negative controls are numbered last.
- No `[lock]` task: every test works in its own `mktemp -d` folder.

## Parallel Example

None: every story shares `tests/test_research.sh` and `skills/st-define/SKILL.md`.

## Implementation Strategy

1. MVP: Phase 3 (US1). Grill research runs in the background with no OK. On its own it still writes to `<folder>/research.md`, so only one run at a time is safe until US2.
2. US2 and US3 make several runs safe: own files, cap and queue, and a git check with no false findings. Ship them with US1.
3. US4 hands the work to Plan.
4. Polish makes the harness model true, proves every new check can fail and that no other test changed. Then the operator runs the live checks before the merge.
