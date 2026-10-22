---

description: "Task list for Triage a GitHub Issue"
---

# Tasks: Triage a GitHub Issue

**Input**: Design documents from `/specs/005-st-triage/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/triage.md, quickstart.md

**Tests**: Required. Every FR has a check that fails before its build task. Expected red states
between tasks are in quickstart.md section 1. Do not edit a test to make it green.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum-15` (branch `15-st-triage`).

**Rules for every task**: no comments except `ponytail:` markers, minimal diff, no new
dependency, match the style of the file it copies. Keep every contract phrase whole on one line
(contracts/triage.md rule P1). Do not edit `hooks/st-session-start.sh`, `hooks/st-models.py`,
`templates/models.json`, any other agent file, `spec.md` or the checklists. Line numbers are from before any edit: find each line by its text. Run every test with
`PYTHONDONTWRITEBYTECODE=1`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 or US2 from spec.md

## Phase 1: Setup

None. `tests/`, `agents/`, `skills/` exist. gh 2.102.0 and Claude Code 2.1.302 are installed
(research header).

## Phase 2: Foundational

None. Each story adds its own checks to `tests/test_on_demand.sh`.

---

## Phase 3: User Story 1 - Triage one issue (Priority: P1) MVP

**Goal**: `/stratum:st-triage <n>` starts a read-only `st-triage` agent, checks its cites and the
git and GitHub state, and shows a four-part report. The agent is listed everywhere the other
agents are.

**Independent Test**: `bash tests/test_on_demand.sh` shows every US1 check `ok`; quickstart
section 3 rows L1, L2, L3, L5, L6.

### Tests for User Story 1

- [X] T001 [US1] Add the US1 checks to `tests/test_on_demand.sh` and move the pinned agent lists to 14 in `tests/test_inspect.sh` and `tests/test_model_hook.py` (FR-001 to FR-004, FR-006 to FR-008, SC-004).
  - `tests/test_on_demand.sh:25`: `for s in st-review st-test st-debug st-git; do` to `for s in st-review st-test st-debug st-git st-triage; do` (skill exists, `name: st-triage`, a line starts `# /stratum:st-triage`, exactly one line holds `` (`stratum:st-triage`) ``).
  - `tests/test_on_demand.sh:56`: add `st-triage` to the end of the `for a in` list. After line 60 (`[ "$a" = st-impeccable ] && t=...`) add `  [ "$a" = st-triage ] && t="Read, Grep, Glob, Bash"`. The no-Bash line (line 65 before the insert): `[ "$a" = st-impeccable ] || check "FR-007 $a no Bash" ...` to `grep -qw Bash <<<"$t" || check "FR-007 $a no Bash" ...` (rest of the line unchanged), so the no-Bash check runs only for agents whose expected tools lack Bash. `m` stays `opus` for `st-triage`.
  - `tests/test_on_demand.sh`: before `exit $fail` add one `phrases <<'EOF'` heredoc with the rows of `specs/005-st-triage/contracts/triage.md` section 3, in table order, each `name<TAB>target<TAB>phrase`, except the two `#15 FR-005 skill` rows (T003 adds them). The phrase is the cell text inside its outer backticks, with no space at either end.
  - `tests/test_inspect.sh:89`: `check "13 agents" '[ "$count" = 13 ]'` to `check "14 agents" '[ "$count" = 14 ]'`. Line 97: the phrase `Show a table of the 13 agents` to `Show a table of the 14 agents` (keep its name `rename skills/st-init/SKILL.md:26`).
  - `tests/test_model_hook.py:202-204` `test_module_constants`: add `"st-triage"` after `"st-test"`.
  - Run all three. Red: the T001 row of quickstart section 1, nothing else.

### Implementation for User Story 1

- [X] T002 [US1] Create the skill, the agent and every doc that lists agents, in one task (the agent-list checks in `tests/test_inspect.sh`, `tests/test_model_files.sh`, `tests/test_model_hook.py` and `tests/test_on_demand.sh` read all of them at once, lessons L6). Security: plan.md S1 (Bash and the before and after checks), S2 (gh, an external service), S3 (untrusted issue text), S4 (model file names).
  - Create `skills/st-triage/SKILL.md` with the text of contracts/triage.md section 1, without the two `[US2: ...]` parts: step 4 reads `` 4. Start one `st-triage` subagent (`stratum:st-triage`) per issue. Pass each the plugin root, the project root and its issue number. `` and step 7 reads `` 7. Show one report per issue, headed by `#<n>`. Then the dropped and corrected cites, with why. `` (FR-001, FR-004, FR-006, FR-007).
  - Create `agents/st-triage.md` with the text of contracts/triage.md section 2: `tools: Read, Grep, Glob, Bash`, `model: opus`, and `` Start your report with `[st-triage]` on its own line. `` (`tests/test_session_hooks.sh:42`) (FR-001 to FR-004, FR-008).
  - `skills/st-model/SKILL.md:11`: `` `st-review`, `st-test`. `` to `` `st-review`, `st-test`, `st-triage`. ``
  - `skills/st-init/SKILL.md:26`: `Show a table of the 13 agents` to `Show a table of the 14 agents`.
  - `README.md` Skills table, after the `` | `st-review`, `st-test`, `st-debug`, `st-git` | `` row (line 92): `` | `st-triage <issue#>...` | Check GitHub issues against the code and git history, read-only: verdict, what is built, blocker, next step. | ``
  - `README.md` Agents table, after the `st-ponytail-debt` row (line 127): `` | `st-triage` | Opus | Checks a GitHub issue against the code and git history, read-only | ``
  - `README.md:172` (Model overrides): `` `st-review`, `st-test`. Models: `` to `` `st-review`, `st-test`, `st-triage`. Models: ``. `README.md:177`: `` `st-impeccable`, `st-ponytail-audit` and `st-ponytail-debt` have no entry either. `` to `` `st-impeccable`, `st-ponytail-audit`, `st-ponytail-debt` and `st-triage` have no entry either. ``
  - `DESIGN.md` D7 table, after the `st-ponytail-debt` row (line 70): `` | `st-triage` | issue #15 | Opus | No | Checks a GitHub issue against the code and git history. Read-only. | ``
  - `DESIGN.md:78`: `Twenty-one entry skills` to `Twenty-two entry skills`. D9 table, after the `` | `st-review`, `st-test`, `st-debug`, `st-git` | `` row (line 93): `` | `st-triage <issue#>...` | Check GitHub issues against the code and git history: verdict, what is built, blocker, next step. Read-only. | ``
  - Run `bash tests/test_on_demand.sh`, `bash tests/test_inspect.sh`, `bash tests/test_model_files.sh`, `bash tests/test_session_hooks.sh`, `python3 -B -m unittest tests/test_model_hook.py`: all pass.

**Checkpoint**: US1 works alone. `bash tests/test_on_demand.sh` is all `ok`.

---

## Phase 4: User Story 2 - Triage several issues at once (Priority: P2)

**Goal**: several issue numbers start their agents side by side and the reports come back in the
order given.

**Independent Test**: `bash tests/test_on_demand.sh` all `ok`; quickstart section 3 row L4.

### Tests for User Story 2

- [X] T003 [US2] In `tests/test_on_demand.sh`, add the two `#15 FR-005 skill` rows of contracts/triage.md section 3 at the end of the `#15` heredoc from T001 (FR-005). Run it: only `#15 FR-005 skill` fails.

### Implementation for User Story 2

- [X] T004 [US2] `skills/st-triage/SKILL.md` (FR-005): step 4, after `per issue` add `, all in the same message so they run side by side`. Step 7, after `Show one report per issue` add `, in the order given`. The two steps now match contracts/triage.md section 1 with the markers removed. Run `bash tests/test_on_demand.sh`: all `ok`.

**Checkpoint**: both stories work. `bash tests/test_on_demand.sh` is all `ok`.

---

## Phase 5: Polish and checks Inspect would run

- [ ] T005 Negative controls (lessons L2, L10). Run quickstart.md section 2 exactly: the phrase loop (baseline 0, then 1 per line, each naming its own check), structure controls C1 to C4, and the two README controls. A control with 0 `FAIL` lines is a check that cannot fail: fix the check in `tests/test_on_demand.sh` and run again. Touch no repo file other than `tests/test_on_demand.sh`. Report each output line.
- [ ] T006 Full run. Run quickstart.md section 1 in full, including `claude plugin validate .claude-plugin/plugin.json` and the final `git status --porcelain` (no file a test wrote, lessons L8). Then give the user quickstart.md section 3 (live checks L1 to L6) as exact steps. It needs a live Claude Code session and a signed-in `gh`, so the user runs it. Record the results in the report: which rows passed, which failed with the output.

---

## Dependencies & Execution Order

### Phase Dependencies

- No setup or foundational phase.
- US1 (T001, T002), then US2 (T003, T004), then Polish (T005, T006).

### User Story Dependencies

- US2 edits the skill US1 creates, so it starts after T002.
- Within each story the test task comes first and must be red before its build task.

### Parallel Opportunities

- None. T001 and T003 edit `tests/test_on_demand.sh`. T002 and T004 edit
  `skills/st-triage/SKILL.md`, and each build task must make the whole test file green (lessons
  L6). No task is `[P]`.

## Parallel Example

None (see above). The build is short: 6 tasks, all Markdown or one-line test edits.

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001, T002.
2. Stop and run quickstart section 3 rows L1, L2, L3, L5, L6.
3. Commit per task with `st-git`.

### Incremental Delivery

1. US1: one issue (#15).
2. US2: several issues side by side.
3. T005, T006 before the feature is called done.

## Notes

- One commit per task, exact paths, through `st-git`.
- No version bump in this feature (research R9).
- The live checks (quickstart section 3) are the only proof of SC-001 to SC-003 at run time. The
  automated checks prove the text and file structure, not the agent's behavior.
