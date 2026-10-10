---

description: "Task list for Merge Check and Validate into Inspect"
---

# Tasks: Merge Check and Validate into Inspect

**Input**: Design documents from `/specs/002-merge-check-validate/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/st-inspect.md, quickstart.md

**Tests**: Required. Every FR has a check that fails before its build task. Expected red states
between tasks are listed in quickstart.md section 1. Do not edit a test to make it green.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum`.

**Rules for every task**: no comments except `ponytail:` markers, minimal diff, no new
dependency, match the style of the file it copies. Do not edit `procedures/analyze.md`,
`hooks/st-models.py`, `spec.md` or the checklists. Never write `st-check` or `st-validate` in a
tracked file outside `specs/` (write the search pattern as `st-(check|validate)`, research R1).

**Order (user decision)**: build `agents/st-inspect.md` and `skills/st-inspect/SKILL.md` first,
confirm every kept capability (T006), then delete the old files and rename (T009).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 to US3 from spec.md

## Phase 1: Setup

None. `tests/`, `agents/` and `skills/` exist. Tools are installed (research R10).

## Phase 2: Foundational

None. US1 is the base for the other stories.

---

## Phase 3: User Story 1 - One agent runs the whole Inspect phase (Priority: P1) MVP

**Goal**: `st-inspect` runs the analysis and the validate checks in one pass, and
`/stratum:st-inspect` starts it once.

**Independent Test**: `bash tests/test_inspect.sh` shows every US1 check `ok`; quickstart
section 5 reports both planted gaps with one agent start.

### Tests for User Story 1

- [X] T001 [US1] Create `tests/test_inspect.sh` in the style of `tests/test_model_files.sh` (`#!/usr/bin/env bash`, `set -u`, `root="$(cd "$(dirname "$0")/.." && pwd)"`, `fail=0`, the same `check()` function and `ok   `/`FAIL ` output, `exit $fail`). Paths: `agent="${ST_INSPECT_AGENT:-$root/agents/st-inspect.md}"`, `skill="${ST_INSPECT_SKILL:-$root/skills/st-inspect/SKILL.md}"`. Keep every phrase out of `eval`: `check()` runs its command through `eval`, and the phrases hold backticks and an apostrophe (`minors' data`). Phrase checks come from a quoted heredoc (`<<'EOF'`) of lines `name<TAB>target<TAB>phrase`, where target is `agent`, `skill` or a repo-relative path. Consecutive lines with the same name form one check; the loop runs `grep -qF -- "$phrase"` on each and prints `ok   name` or `FAIL name` (and sets `fail=1`) once per check. Values with quotes or backticks are computed outside `check`, for example `n=$(grep -cF '(`stratum:' "$skill")` and then `check "one agent" '[ "$n" = 1 ]'`. Checks (FR-001, FR-002, FR-003, FR-004, FR-005, FR-012): (a) agent frontmatter: `grep -qx` for each of `name: st-inspect`, `tools: Read, Grep, Glob, Bash, Edit`, `model: opus` (one check); (b) heredoc lines for every row of the agent phrase table in `specs/002-merge-check-validate/contracts/st-inspect.md` section 1 (C1 to C10, V1 to V6, FR-003, FR-004), one check per row; (c) skill frontmatter `grep -qx "name: st-inspect"`; (d) heredoc lines for every row of the skill phrase table in section 2 except S5 (FR-005, S1, S2, S3, S4, S6); (e) one agent: exactly 1 line of the skill holds `` (`stratum: ``. Run `bash tests/test_inspect.sh`: every check prints FAIL because the files do not exist.

### Implementation for User Story 1

- [X] T002 [US1] Create both new files in one task. `tests/test_inspect.sh` checks both, so neither is green alone:
  - Create `agents/st-inspect.md` per `specs/002-merge-check-validate/contracts/st-inspect.md` section 1: frontmatter, description, sections in the listed order, every phrase of the agent table written exactly and whole on one line (rules P1, P2), the `## Validate` format unchanged from `agents/st-validate.md`. Copy the sr-opus-5 line, Inputs and Navigation from `agents/st-validate.md` (drop "st-check findings, if the orchestrator passes them."). One finding list F1, F2... with severity critical, high, medium or low (research R5). Net verdict from the 4 validate checks only (research R7). Security: plan.md S1 (the `## Never` lines are the agent's only write limit).
  - Create `skills/st-inspect/SKILL.md` per `specs/002-merge-check-validate/contracts/st-inspect.md` section 2, from the frame of `skills/st-check/SKILL.md`: frontmatter `name: st-inspect` and the contract description, heading `# /stratum:st-inspect`, Start steps 1 to 3 with the order check `` `phase` should be `plan` or `inspect` `` and `` Set `phase` to `inspect` ``, then Steps: (1) note `git status --porcelain`, start the `st-inspect` subagent (`stratum:st-inspect`) with absolute paths (plugin root, project root, feature dir), tell it to follow `<plugin root>/procedures/analyze.md` (`<PLUGIN_ROOT>` is the plugin root) and then its validate checks; after it returns, run `git status --porcelain` again: `` only `plan.md` may change ``, and `git diff` of it `` touches only its `## Validate` section ``; any other change is a finding; (2) Findings, as the old step 3 without "Merge both reports"; (3) `` If any CRITICAL finding was fixed, run `st-inspect` once more `` (it replaces its older `## Validate` section); (4) Advisor: copy the old step 5 unchanged (T005 widens it). Gate as the old one, with "the verdict" in place of "validate's verdict". Keep the `## Always` lines. Exactly one line holds `` (`stratum: ``. Every skill-table phrase whole on one line.
- [X] T003 [US1] Run `bash tests/test_inspect.sh`: every check prints `ok`. Run `python3 -m unittest tests/test_model_hook.py` and `bash tests/test_model_files.sh`: only the red tests listed in quickstart.md section 1 for "T002 to T006" fail. Fix the new files, not the tests. Change `tests/test_inspect.sh` only for a harness bug you show (for example a phrase that fails because of shell quoting while `grep -F` finds it by hand), and say so in the report.

**Checkpoint**: The new agent and skill exist next to the old ones. Do not delete anything yet.

---

## Phase 4: User Story 2 - The advisor step also asks for improvements (Priority: P2)

**Goal**: The advisor step asks for risks and improvements and handles the answers as findings.

**Independent Test**: The S5 check in `bash tests/test_inspect.sh` is `ok`; quickstart section 6.

### Tests for User Story 2

- [X] T004 [US2] Add to `tests/test_inspect.sh` one check for the S5 row of the skill phrase table in `specs/002-merge-check-validate/contracts/st-inspect.md` section 2 (FR-006): `a simpler or better approach`, `tasks to cut or merge`, `missed auth invariants`, `big ones go to the user before the gate`, each with `grep -qF --` on `$skill`. Run it: the S5 check prints FAIL (T002 copied the risk-only step).

### Implementation for User Story 2

- [X] T005 [US2] In `skills/st-inspect/SKILL.md`, rewrite the Advisor step: "If an advisor is set (`/advisor`), consult it on the plan before the gate." Risks: missed auth invariants, schema or contract breaks, hidden breaking changes. Improvements: a simpler or better approach, tasks to cut or merge. "Treat its answers as findings: check each against the source, fix the small ones, and big ones go to the user before the gate." Keep each S5 phrase whole on one line. Run `bash tests/test_inspect.sh`: every check `ok`.

---

## Phase 5: User Story 3 - No trace of the old names (Priority: P2)

**Goal**: Every reference says `inspect` / `st-inspect`, 10 agents everywhere, old files gone,
and `README.md` matches the repo (FR-013).

**Independent Test**: `git grep -nwE 'st-(check|validate)' -- . ':!specs'` prints nothing; all
three test commands pass; quickstart sections 3 and 4.

### Capability gate (before any delete)

- [X] T006 [US3] Gate for FR-012 on `tests/test_inspect.sh`: run it, every check `ok`. Run quickstart.md section 2 (the phrase loop and the frontmatter and one-agent controls). Every loop line must start with baseline plus 1. A line at the baseline is a check that cannot fail: fix the phrase placement in `agents/st-inspect.md` or `skills/st-inspect/SKILL.md` (rules P1, P2) and run again. Do not start T009 until this passes. Report the loop output.

### Tests for User Story 3

- [X] T007 [US3] Add to `tests/test_inspect.sh` (FR-007, FR-008, FR-009): (a) `old names gone`: compute outside `check`: `(cd "$root" && git grep -qwE 'st-(check|validate)' -- . ':!specs'); old_rc=$?`, then `check "old names gone" '[ "$old_rc" = 1 ]'`. Exit code 1 means no match; 0 is a match; 128 (no git repo) must also fail, so never test for empty output. Write the pattern exactly so, never as `st-check|st-validate` (research R1); (b) `10 agents`: `[ "$(ls "$root/agents" | grep -c '\.md$')" = 10 ]`; (c) one `grep -qF --` check per row of the rename table in `specs/002-merge-check-validate/contracts/st-inspect.md` section 3, except the two rows that name other guards, on the file the row names; the phrase is the first code span in the row's second column (the `README.md:75`, `README.md:114-115`, `DESIGN.md:59-60` and `DESIGN.md:119` rows use the whole row text with plain `|`); the `skills/st-full/SKILL.md:3` row greps only the `description:` line (`grep -m1 "^description:"`); the rows go in the heredoc of T001. Run it: (a), (b) and (c) print FAIL.
- [X] T008 [P] [US3] Edit `tests/test_model_hook.py` (FR-009, FR-010): in `test_module_constants`, expect `["st-build", "st-close", "st-debug", "st-fast", "st-git", "st-inspect", "st-plan", "st-quick", "st-review", "st-test"]`; in `test_effort_only_keeps_model`, replace the old agent name with `st-inspect` in the file text and in both `subagent_type` values. Add no test that names an old agent (research R4). Run `python3 -m unittest tests/test_model_hook.py`: `test_module_constants` fails (12 agents), `test_effort_only_keeps_model` passes.

### Implementation for User Story 3

- [X] T009 [US3] Delete the old files and do every rename in one task. T007's old-name search is repo-wide, so no single file passes it alone. Steps:
  - Delete `agents/st-check.md`, `agents/st-validate.md` and `skills/st-check/SKILL.md` (and the empty `skills/st-check/` folder) (FR-007). Security: plan.md S2 (a model file that names an old agent now blocks every start).
  - Edit `skills/st/SKILL.md:32`: `/stratum:st-check` to `/stratum:st-inspect` (FR-008).
  - Edit `skills/st-full/SKILL.md`: description `(Define, Plan, Check, Build, Close)` to `(Define, Plan, Inspect, Build, Close)`; line 12 to `` 3. `/stratum:st-inspect` (gate: user OKs the build) `` (FR-008).
  - Edit `skills/st-plan/SKILL.md:35` to `` Next phase: `/stratum:st-inspect`. `` (FR-008).
  - Edit `skills/st-build/SKILL.md:16`: `` `phase` should be `check` or `build` `` to `` `phase` should be `inspect` or `build` `` (FR-008, research R9).
  - Edit `skills/st-status/SKILL.md`: line 13 `Check → "you OK the` to `Inspect → "you OK the` (keep the rest of the sentence); line 37 `stratum:st-check` to `stratum:st-inspect` in the hook probe (FR-008).
  - Edit `skills/st-model/SKILL.md`: lines 10-11 list the 10 agents in sorted order (`` `st-build`, `st-close`, `st-debug`, `st-fast`, `st-git`, `st-inspect`, `st-plan`, `st-quick`, `st-review`, `st-test` ``); line 35 `stratum:st-check` to `stratum:st-inspect` (FR-009).
  - Edit `skills/st-init/SKILL.md:26`: `Show a table of the 11 agents` to `Show a table of the 10 agents` (FR-009).
  - Edit `tests/test_model_files.sh:31`: `stratum:st-check` to `stratum:st-inspect` in the hook probe.
  - Edit `README.md` per the `README.md` rows of `specs/002-merge-check-validate/contracts/st-inspect.md` section 3: line 75 phase row; line 90 skills row; lines 114-115 one agent row for `st-inspect` (Opus); lines 166-168 the 10 agents in sorted order; lines 171-172 `` `st-inspect` and `st-review` have no entry and keep the plugin default ``, reflowed so this whole sentence sits on one line (today it wraps mid-sentence at line 171; rule P1, so the check passes on content, not on line wrap); add `bash tests/test_inspect.sh` after line 259 (FR-008, FR-009). Do not name the old agents anywhere (research R2).
  - Edit `DESIGN.md` per the `DESIGN.md` rows of `specs/002-merge-check-validate/contracts/st-inspect.md` section 3: lines 59-60 one D7 row for `st-inspect`; line 82 the D9 skills row; line 119 the Full lane row (FR-008, FR-009).
  - Then run `bash tests/test_inspect.sh`, `python3 -m unittest tests/test_model_hook.py` and `bash tests/test_model_files.sh`: every check of T007 and T008, and every other test, passes. One commit for the whole task.

**Checkpoint**: Every check of all three test files passes.

### README matches the repo (FR-013)

- [ ] T010 [US3] Add to `tests/test_inspect.sh` the README checks of `specs/002-merge-check-validate/contracts/st-inspect.md` section 5 (FR-013). Add `readme="${ST_INSPECT_README:-$root/README.md}"`. Compute each list of misses outside `check` and assert it is empty: (a) `README skills`; (b) `README agents` (model from the `model:` line, first letter upper case, row text `` | `<a>` | <Model> | ``); (c) `README paths` (backticked `agents/`, `hooks/`, `licenses/`, `procedures/`, `scripts/`, `skills/`, `statusline/`, `templates/`, `tests/` paths, `vendor.lock`, and `](<NAME>.md)` links); (d) `README tests` (both directions: named files exist, every `tests/test_*` is named); (e) `README themes` (keys of `statusline/themes.json`); (f) `README git guard` (`userConfig` keys of `.claude-plugin/plugin.json`). Read JSON with `python3 -c`. Add the three README phrase rows of section 5 to the heredoc with target `readme`. Run it: (a) to (f) are `ok` and the three phrase checks print FAIL. Then run the six controls of quickstart.md section 9: each turns only its own check red.
- [ ] T011 [US3] Fix the README drift in `README.md` only (FR-013). Keep each phrase whole on one line (rule P1). Do not name the old agents (FR-007):
  - Line 91, `st-status` row: the repo's skill (`skills/st-status/SKILL.md:3`) also shows duplicate installs, days since the last upstream sync and model overrides. New row: `` | `st-status` | Feature, phase, lane, tasks done, git guard options, next gate, missing tools, duplicate installs, days since the last upstream sync, model overrides. | ``
  - Lines 31-34, `st-init` paragraph: `skills/st-init/SKILL.md` steps 3, 4 and 6 also ask for the git guard modes, ask for model overrides and write the pointers. New text: "`st-init` creates the project's `.stratum/` files and `specs/`, asks for the git guard modes and any model overrides, grills you for the project's rules (the constitution), writes the `AGENTS.md` and `CLAUDE.md` pointers, sets the statusline and asks for its theme, shape and Token Weather line, turns off a global ponytail or Token Weather plugin for this project, offers to upgrade graphify, installs its post-commit hook, and checks your tools."
  - Line 40, Requirements row: `python3` also runs `hooks/st-models.py` and the Python inside `statusline/st-statusline.sh` and `hooks/st-handoff-facts.sh`. New row: `` | `git`, `python3` | git guard, model overrides hook, statusline, handoff facts, scripts | ``
  - Run `bash tests/test_inspect.sh`: every check `ok`.

---

## Phase 6: Polish and Release

- [ ] T012 Edit `.claude-plugin/plugin.json`: `"version": "0.1.26"` to `"version": "0.1.27"` (FR-011, research R3). Commit it alone. The commit message is `specs/002-merge-check-validate/contracts/st-inspect.md` section 4 word for word, with no `Co-Authored-By` or other trailer. FR-011 has no automated check (research R3); quickstart section 7 checks it by hand.
- [ ] T013 Run `specs/002-merge-check-validate/quickstart.md` sections 1, 3, 4, 7, 8 and 9 and report each result. Run the README controls of section 9 and the old-name controls of section 2 (the clone with a planted name, and the copy with no git repo: both must print the FAIL line of the old-name search). Run `claude plugin validate .claude-plugin/plugin.json` from the repo root: it must pass. Run section 5 (SC-004) in a scratch clone only, never on a tracked `specs/` dir, and section 6 if an advisor is set. Report the actual output, not a summary.

---

## Dependencies and Execution Order

- US1 (T001 to T003) first, in order.
- US2 (T004, T005) after T003: same skill file and test file.
- US3: T006 after T005. T007 and T008 after T006, in parallel (test files only, both red until
  T009). T009 after T007 and T008, and only after T006 passed.
- README: T010 after T009, T011 after T010.
- Polish: T012 after T011. T013 last.

`tests/test_inspect.sh` order: T001, T004, T007, T010. `skills/st-inspect/SKILL.md` order: T002, T005.

## Parallel Examples

```text
After T006:  T007 (tests/test_inspect.sh)  |  T008 (tests/test_model_hook.py)
```

No other task runs in parallel: T002 and T009 each change files that one test checks together.

## Implementation Strategy

1. MVP: US1 (T001 to T003). The new agent and skill work next to the old ones.
2. US2: the advisor asks for improvements.
3. Capability gate T006, then US3: tests, then delete and renames in one task.
4. README drift: T010 test, T011 fix.
5. Polish: version bump and its release note, then the quickstart run.

## Notes

- Between T002 and T009 there are 12 agents and `test_module_constants` is red. This is expected.
- The build loop commits each task through `st-git`. T009 deletes and renames in one commit, so
  no commit has skills that point at a removed skill.
- FR to task map: FR-001 T001/T002; FR-002 T001/T002; FR-003 T001/T002, quickstart 5; FR-004
  T001/T002; FR-005 T001/T002; FR-006 T004/T005; FR-007 T007/T009; FR-008 T007/T009; FR-009
  T007/T008/T009; FR-010 T008 plus the existing `test_deny_unknown_agent`, quickstart 4; FR-011
  T012, quickstart 7 (by hand); FR-012 T001/T004/T006; FR-013 T010/T011, quickstart 9.
