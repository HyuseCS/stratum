---

description: "Task list for answering the prompts of summoned agents"
---

# Tasks: Answer the prompts of summoned agents

**Input**: Design documents from `/specs/014-prompt-answers/`

**Prerequisites**: plan.md, spec.md, decisions.md (D1 to D3), research.md, contracts/answer.md, contracts/skill-lines.md, quickstart.md

**Tests**: Required (D2, SC-001, SC-005). Each FR gets a row or case that can fail, written before the task that builds it. Row ids W, O, S and G are in `contracts/skill-lines.md`. Case ids AN1 to AN13 are in `contracts/answer.md`. FR coverage is at the end.

**Rules for every task**: no comment lines in code except `ponytail:` markers. No new dependency. Tests use the stub `herdr` in `tests/test_st_worker.sh` only: no task starts a real herdr tab or agent. Each phrase goes into the skill file and the test row word for word from `contracts/skill-lines.md`. A test task shows its new rows or cases `FAIL` before the build task runs: that run is the red with the line absent (D2). A negative control is a break made with the Edit tool, one test run, the named case seen `FAIL`, then the break undone with the Edit tool, never `git checkout`. Do not change the Codex allow and never lists (`skills/st-build/SKILL.md:98-100`) or the `approval` bullet of `skills/st-worker/SKILL.md` and its four lines after it (:28-32 before T004 and T006). Line numbers in tasks are the numbers before any task runs.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

- **[P]**: Can run in parallel: no shared file in the phase and no other task's result; the task ends with `Owns:`
- **[lock]**: Test that cannot run at the same time as another; it runs through the test lock
- **[screen: <mode>]**: New screen; Build sends it to the Design lane in that mode
- **[Story]**: Which user story this task belongs to (US1 to US3)

No task is `[lock]`: `tests/test_st_worker.sh` makes its own temp folder and the rule tests only read files. No task is `[screen]`: the feature has no page or view.

---

## Phase 1: Setup

None.

## Phase 2: Foundational

None.

---

## Phase 3: User Story 1 - The orchestrator answers a worker's safe permission prompt (Priority: P1) MVP

**Goal**: in normal mode the orchestrator sends the one-time yes on a worker dialog for an action on the worker allow list. `answer --keys` refuses a lasting option. Every other dialog goes to the user with the workspace, the tab and the exact text.

**Independent Test**: `bash tests/test_st_worker.sh` (AN1 to AN13) and `bash tests/test_worker_rules.sh` (W1, W2, W18, W19, W28, W29, W31, W32, O1, G5 to G9) pass.

### Tests for User Story 1

- [X] T001 [P] [US1] In `tests/test_st_worker.sh`, change the AN1 loop (:1362-1366) to call `answer T004 --text hi` and keep its expected line, and add AN5, AN5b, AN6 (one case per option text: the straight-apostrophe "don't ask again", the curly "don’t ask again", "for this session", "during this session (shift+tab)", "in the future"), AN7 (`--keys 1 enter`, `--keys enter`, `--keys down`) and AN8 (`--keys 4`) after AN4 (:1377), with the panes, `states` and expected lines in the `contracts/answer.md` table. Keep AN2, AN3 and AN4 as they are. Use the file's `mk`, `states`, `run`, `cnt` and `hascall` helpers. Red now: AN5, AN5b, AN6, AN7 and AN8 print `FAIL`. Owns: `tests/test_st_worker.sh`. Test: bash tests/test_st_worker.sh.
- [X] T002 [P] [US1] In `tests/test_worker_rules.sh`, first table: replace the text of W1 and W2 (:10-11) with the W1 and W2 phrases, and add W18, W28, W29 (file `skills/st-worker/SKILL.md`) and W19 (file `README.md`). After the first table, add the O1 check line, then show it can fail: copy the `Never approve a push` line of `skills/st-worker/SKILL.md` once with the Edit tool, run the test, see O1 `FAIL`, and delete the copy with the Edit tool. Second table: delete G1 (:32) and add G5, G6 and G7. In `tests/test_lane_steps.sh`, delete `row 1` (:24). Both deletions cite 013 D7 in the commit message, not in the file. Every phrase comes from `contracts/skill-lines.md` sections 1, 2 and 5. Red now: W1, W2, W18, W19, W28, W29, G5, G6 and G7 print `FAIL`, and O1 prints `ok`. Owns: `tests/test_worker_rules.sh`, `tests/test_lane_steps.sh`. Test: bash tests/test_worker_rules.sh; bash tests/test_lane_steps.sh.

### Implementation for User Story 1

- [X] T003 [US1] In `scripts/st-worker.sh`, change the permission check of `answer` (:434) as `contracts/answer.md` steps 1 to 4 say. The refusal lines are word for word: `A permission prompt takes one option number. Nothing sent.`, `The permission prompt has no option <key>. Nothing sent.`, `Option <key> lasts beyond this call. Nothing sent. Tell the user the workspace, the tab and the prompt.` Keep the permission line for `--text` and for a failed read. The lasting match is `ask again|this session|in the future`, case-insensitive, on the option line only. The key must match `^[1-9]$`. Then run the three negative controls of `contracts/answer.md` and see AN6, AN7 and AN1 go `FAIL` one at a time. Test: bash tests/test_st_worker.sh.
- [X] T004 [US1] In `skills/st-worker/SKILL.md`, replace lines 26 and 27 with the W1, W2 and W18 lines, 5-space indent, in that order. Do not touch line 25 or lines 28 to 32. In `README.md`, replace line 117 with the W19 line. Then, one at a time with the Edit tool: delete the W1 line, run the test, see W1 `FAIL`, put it back; delete only the sentence `The dialog must show the whole command or path. Else send no key and tell the user.`, run the test, see W28 `FAIL`, put it back. Test: bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_on_demand.sh.

### US1 rework: screen check and one-time yes allow list (D6, D7, review wording)

T001 to T004 are built (b2e19c4, 42c758b). T010 to T013 change them. They run before T005.

- [ ] T010 [P] [US1] In `tests/test_st_worker.sh`, change and add the stub cases of `contracts/answer.md` section 4. AN5, AN5b, AN6, AN7 and AN8 now get `--screen <the hash>` before `--keys`, and AN6 and AN8 expect `Option <key> is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt.`. AN6 also gets the option text `  2. Yes, and always allow access to other/ from this project`. Add AN6b, AN6c, AN6d, AN9, AN10, AN11, AN12 and AN13 with the panes, calls and expected lines in that table. "The hash" is the hash on the `screen` line of a `wait T004` run on the same pane: run `wait` with `states blocked`, read the line, then set `states blocked working` (for a send) or `states blocked` (for a refusal) and run `answer`. AN11 writes the `git push` pane to `$tmp/pane.txt` after `wait` and before `answer`. Keep AN1 to AN4 as they are. Use the file's `mk`, `states`, `run`, `cnt` and `hascall` helpers, and add no comment lines. Red now: AN5, AN5b, AN6 to AN6d, AN7, AN8 and AN9 to AN13 print `FAIL`, and AN1 to AN4 print `ok`. Owns: `tests/test_st_worker.sh`. Test: bash tests/test_st_worker.sh.
- [X] T011 [P] [US1] In `tests/test_worker_rules.sh`, first table: set W1 to the whole line of `contracts/skill-lines.md` section 1b, and add W31 and W32 (file `skills/st-worker/SKILL.md`). Second table: add G8 and G9. Phrases word for word from section 1b. Red now: W1, W31, W32, G8 and G9 print `FAIL`, and W28, W29, W2, W18 and O1 print `ok`. Owns: `tests/test_worker_rules.sh`. Test: bash tests/test_worker_rules.sh.
- [ ] T012 [US1] In `scripts/st-worker.sh`, build `contracts/answer.md` sections 1 to 3:
  - In `st()`, for `blocked`, print `screen<TAB><hash>` after the `state` line and before `pane text:` when the pane shows a permission dialog.
  - Parse `answer --screen <hash>`: before `--keys`, it must match `^[0-9a-f]{12}$`, else `usage`.
  - In `answer`, read 20 lines with the `scripts/st-advisor.sh:35` hash method, and judge the dialog by the last 15 lines.
  - On a permission dialog, refuse in the order of section 3 step 3, with the exact lines there.
  - Remove T003's no-option line and its lasting-phrase `grep`. Keep the permission line for `--text` and for a failed read.
  - Use one helper for the read and hash, shared by `st()` and `answer`, so both read the same way.
  - On the line of the hash compare, add this note word for word (D8, `contracts/answer.md` section 6): `# ponytail: the whole 20-line screen must match, add --expect <text> if a real worker pane redraws so its hash never matches`. Add no other comment lines.
  - Then run the 5 negative controls of section 5, one at a time with the Edit tool, and see AN11, AN12, AN6, AN9 and AN10, and AN6d go `FAIL`, each undone with the Edit tool.
  Test: bash tests/test_st_worker.sh.
- [X] T013 [US1] In `skills/st-worker/SKILL.md`, replace the W1 line (the line that starts `A permission dialog in normal mode`) with the line of `contracts/skill-lines.md` section 1b, keeping its 5-space indent. Change no other line. Then, one at a time with the Edit tool: delete only the W31 text, run the test, see W31 `FAIL`, put it back; delete only `--screen <hash> ` in the command, run the test, see W32 `FAIL`, put it back. Test: bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_on_demand.sh.

**Checkpoint**: US1 works alone. A normal-mode dialog for an allowed action gets the one-time yes. The script refuses anything that is not a one-time yes form, and any dialog that changed after `wait`.

---

## Phase 4: User Story 2 - One shared rule in the three orchestrator skills (Priority: P1)

**Goal**: the rule sentence, word for word, in `skills/st/SKILL.md`, `skills/st-build/SKILL.md` and `skills/st-worker/SKILL.md`, each with a pointer to its lists.

**Independent Test**: `bash tests/test_worker_rules.sh` (W20 to W23, W26, W27) and `bash tests/test_advisor_rules.sh` pass.

### Tests for User Story 2

- [ ] T005 [US2] In `tests/test_worker_rules.sh`, first table, add W20, W21, W22, W23, W26 and W27 with the files and phrases in `contracts/skill-lines.md` section 3. Red now: all six print `FAIL`, and `tests/test_advisor_rules.sh` is green (A18 to A28 hold the Codex lists). Test: bash tests/test_worker_rules.sh; bash tests/test_advisor_rules.sh.

### Implementation for User Story 2

- [ ] T006 [US2] Add the rule sentence R and its pointer as `contracts/skill-lines.md` section 3 says: in `skills/st/SKILL.md`, a new `## Always` bullet with R after the bullet that ends "and why." (:68), and the W23 line under it, 2-space indent; in `skills/st-build/SKILL.md`, a new last bullet in `## Always` with R, and the W26 line under it, 2-space indent; in `skills/st-worker/SKILL.md`, a blank line and then one line with R and the W27 text after line 10. R is one physical line in each file. Do not change `skills/st-build/SKILL.md:98-100`. Then delete R from `skills/st-build/SKILL.md` once with the Edit tool, run the test, see W21 `FAIL`, and put it back with the Edit tool. Test: bash tests/test_worker_rules.sh && bash tests/test_advisor_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_lane_steps.sh.

**Checkpoint**: SC-002: `grep -cF` of R gives 1 in each of the three files.

---

## Phase 5: User Story 3 - A written note on in-session subagent prompts (Priority: P2)

**Goal**: two short note lines in `skills/st/SKILL.md` that say what the orchestrator can and cannot do when an in-session subagent's tool call needs permission. Every fact is sourced in `research.md` R4.

**Independent Test**: `bash tests/test_worker_rules.sh` (W24, W25, S1 to S5) passes.

### Tests for User Story 3

- [ ] T007 [US3] In `tests/test_worker_rules.sh`, first table, add W24, W30 and W25 (`contracts/skill-lines.md` section 4) and the source rows S1 to S6 word for word. Red now: W24, W30 and W25 print `FAIL`. S1 to S6 print `ok`, because `research.md` was written at Plan. Show that the S rows can fail, one at a time with the Edit tool in `specs/014-prompt-answers/research.md`: change `https://code.claude.com/docs/en/sub-agents.md` to `https://code.claude.com/docs/en/sub-agent.md` at every place it appears, run the test, see S1 `FAIL`, undo; delete fact 7, run the test, see S4 `FAIL`, put it back. Test: bash tests/test_worker_rules.sh.

### Implementation for User Story 3

- [ ] T008 [US3] In `skills/st/SKILL.md`, add the W24 line and the W30-plus-W25 line (`contracts/skill-lines.md` section 4) right after the W23 line, 2-space indent, one line each. Each claim must map to `research.md` R4: W24 to facts 1, 2 and 8, W30 to facts 5 and 9, and W25 to facts 5 and 6. No line points to `research.md`. Add no other claim. Then, one at a time with the Edit tool: delete the W25 sentences, run the test, see W25 `FAIL`, put them back; delete only the W30 sentence, run the test, see W30 `FAIL`, put it back. Test: bash tests/test_worker_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_state.sh.

**Checkpoint**: all three stories work. The `quickstart.md` steps pass.

---

## Phase 6: Polish

- [ ] T009 Run the end check of `quickstart.md`. Fix nothing outside this feature's files. No `st-verify.sh` run here: it reads only uncommitted changes (`git diff` against the index) and takes no base, so after the commits it would check nothing. The comment grep runs per task in the build loop, before each commit. Test: bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh && bash tests/test_st_worker.sh && bash tests/test_risk_rules.sh && bash tests/test_state.sh && python3 tests/test_model_hook.py.

## Dependencies

- US1 -> US2 -> US3. US1 and US2 share `skills/st-worker/SKILL.md` and `tests/test_worker_rules.sh`. US2 and US3 share `skills/st/SKILL.md` and `tests/test_worker_rules.sh`. No two stories run at the same time.
- Order: T001 to T004 (built), then T010 to T013, then T005. IDs T005 to T009 are kept, so T010 to T013 run before them.
- Inside the US1 rework: T010 and T011 run at the same time. T012 needs T010. T013 needs T011. T012 and T013 share no file.
- Inside US1: T001 and T002 run at the same time. T003 needs T001. T004 needs T002. T003 and T004 share no file, so they may run one after the other in either order.
- T009 is last.

## Parallel examples

- US1: T001 and T002 together. Then T003 and T004. Then T010 and T011 together. Then T012 and T013.
- US2: T005, then T006.
- US3: T007, then T008.

## Implementation strategy

MVP is US1: the gap the issue reports. US2 and US3 are text only and add no behavior. Ship all three in one PR.

## FR coverage

| FR | Test task (rows or cases) | Build task |
|----|---------------------------|------------|
| FR-001 | T002 (W1, W2, W28, W29, G5, G6), T001 (AN5, AN5b), T011 (W1, W31, W32, G8, G9), T010 (AN5, AN5b, AN10) | T004, T003, T013, T012 |
| FR-002 | T002 (W1, W18) | T004 |
| FR-003 | T002 (O1, W1), existing W3, W5, W16 | T004 |
| FR-004 | T002 (its run shows W3, W4, W5, W6, W16 green) | T004 |
| FR-005 | T005 (W20, W21, W22) | T006 |
| FR-006 | T005 (W23, W26, W27) | T006 |
| FR-007 | T007 (W24, W25, W30) | T008 |
| FR-008 | T007 (S1 to S6, S1 and S4 negative controls) | Plan (`research.md` R4) |
| FR-009 | T005 (A18 to A28 in `tests/test_advisor_rules.sh`) | T006 (no change to :98-100) |
| FR-010 | T001 (AN1, AN6, AN7, AN8), T010 (AN6 to AN6d, AN7, AN8, AN10; negative controls 3 and 5) | T003, T012 |
| FR-011 | T010 (AN9, AN11, AN12, AN13; negative controls 1, 2 and 4) | T012 |
| README line 117 | T002 (W19, G7) | T004 |
