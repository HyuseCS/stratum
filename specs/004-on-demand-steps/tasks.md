---

description: "Task list for Run Stratum Steps On Demand"
---

# Tasks: Run Stratum Steps On Demand

**Input**: Design documents from `/specs/004-on-demand-steps/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/commands.md,
contracts/background.md, quickstart.md

**Tests**: Required. Every FR has a check that fails before its build task. Expected red states
between tasks are in quickstart.md section 1. Do not edit a test to make it green.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum` (branch `013-agent-skills`), not the plugin root that runs the
session.

**Rules for every task**: no comments except `ponytail:` markers, minimal diff, no new
dependency, match the style of the file it copies. Keep every contract phrase whole on one line
(contracts/commands.md rule P1). Do not edit `hooks/st-models.py`, `hooks/st-phase.py`,
`templates/models.json`, `agents/st-review.md`, `agents/st-test.md`, `agents/st-debug.md`,
`agents/st-git.md`, `spec.md` or the checklists. Run every test with
`PYTHONDONTWRITEBYTECODE=1`.

**Models (decision D1, answer A)**: `st-impeccable` and `st-ponytail-audit` use `model: opus`, `st-ponytail-debt` uses `model: sonnet`. No `templates/models.json` entry.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 to US3 from spec.md

## Phase 1: Setup

None. `tests/`, `agents/`, `skills/` and `hooks/` exist. Tools are installed (research header).

## Phase 2: Foundational

None. Each story adds its own checks to `tests/test_on_demand.sh`.

---

## Phase 3: User Story 1 - Run any Stratum agent as a command (Priority: P1) MVP

**Goal**: `/stratum:st-review`, `/stratum:st-test`, `/stratum:st-debug` and `/stratum:st-git`
start their agent, fill missing inputs, and run the lane's check. A test names any agent with no
command.

**Independent Test**: `bash tests/test_on_demand.sh` shows every US1 check `ok`; quickstart
section 3 rows L1 to L7.

### Tests for User Story 1

- [X] T001 [US1] Create `tests/test_on_demand.sh` and list it in `README.md`. Test file: copy the frame of `tests/test_inspect.sh` (`#!/usr/bin/env bash`, `set -u`, `fail=0`, the same `check()`, `report()` and `phrases()` functions, `ok   `/`FAIL ` output, `exit $fail`), with `root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"` so quickstart section 2 can run it on a copy, and `tmp=$(mktemp -d)` with `trap 'rm -rf "$tmp"' EXIT`. In `phrases()` the target is a path relative to `$root`, or `hook` (T005 sets that file). Keep phrases out of `eval`: compute counts and lists outside `check`, as `tests/test_inspect.sh:83-84` does. Checks (contracts/commands.md section 5): (a) FR-001, one check per skill in `st-review st-test st-debug st-git`, named `FR-001 <skill>`: `skills/<skill>/SKILL.md` exists, `grep -qx "name: <skill>"`, a line starts `# /stratum:<skill>`, and exactly 1 line holds `` (`stratum:<skill>`) `` (count with `grep -cF` outside `check`); (b) FR-002, FR-003, FR-004 phrase rows of the table, one check per row named `<FR> <skill>`, from a quoted heredoc (`<<'EOF'`) of `name<TAB>target<TAB>phrase` lines; (c) FR-005: `miss=$(for a in "$root"/agents/*.md; do n=$(basename "$a" .md); [ -f "$root/skills/$n/SKILL.md" ] || printf ' %s' "$n"; done)`, then `check "every agent has a command:$miss" '[ -z "$miss" ]'`, so the FAIL line names each agent. `README.md`: add `bash tests/test_on_demand.sh` to the Tests block after `bash tests/test_inspect.sh` (`tests/test_inspect.sh` "README tests" needs it). Run `bash tests/test_on_demand.sh`: every FR-001 to FR-004 check prints FAIL and the FR-005 line reads `FAIL every agent has a command: st-debug st-git st-review st-test`. Run `bash tests/test_inspect.sh`: all `ok`.

### Implementation for User Story 1

- [X] T002 [US1] Create the 4 skills and their doc rows in one task (`tests/test_on_demand.sh` and `tests/test_inspect.sh` "README skills" read all of them, lessons L6). Security: plan.md S1 (`st-git` commits).
  - Create `skills/st-review/SKILL.md`, `skills/st-test/SKILL.md`, `skills/st-debug/SKILL.md`, `skills/st-git/SKILL.md` with the text of `specs/004-on-demand-steps/contracts/commands.md` sections 1 to 4 (FR-001 to FR-004). Each has exactly one `` (`stratum:<name>`) `` line.
  - `README.md` Skills table: after the `st-define`, `st-plan`, ... row add `` | `st-review`, `st-test`, `st-debug`, `st-git` | Run one Build-loop agent on demand. A missing feature comes from `.stratum/state.json`, a missing range is `main..HEAD`. | ``.
  - `DESIGN.md` D9: `Seventeen entry skills` to `Twenty-one entry skills`, and after the `st-pr [base]` row add `` | `st-review`, `st-test`, `st-debug`, `st-git` | Run one Build-loop agent on demand, then the check the orchestrator runs after it in a lane. | ``.
  - Run `bash tests/test_on_demand.sh` and `bash tests/test_inspect.sh`: every check `ok`.

**Checkpoint**: US1 works alone. `bash tests/test_on_demand.sh` is all `ok`.

---

## Phase 4: User Story 2 - Run a read-only skill in the background (Priority: P2)

**Goal**: `st-impeccable`, `st-ponytail-audit` and `st-ponytail-debt` each have a read-only agent
of the same name, and the session rule starts them in the background and refuses other skills.

**Independent Test**: `bash tests/test_on_demand.sh` all `ok`; quickstart section 3 rows L8 to
L10.

### Tests for User Story 2

- [X] T003 [US2] Add the agent checks and move the pinned agent lists to 13 (FR-006, FR-007).
  - `tests/test_on_demand.sh`: per agent in `st-impeccable st-ponytail-audit st-ponytail-debt`, with `tools` = `Read, Grep, Glob, Bash, Skill` for `st-impeccable` and `Read, Grep, Glob, Skill` for the other two: (a) `FR-006 <agent> frontmatter`: `agents/<agent>.md` has `grep -qx` lines `name: <agent>`, `tools: <tools>`, `model: <model>` (`opus` for `st-impeccable` and `st-ponytail-audit`, `sonnet` for `st-ponytail-debt`); (b) `FR-006 <agent> skill`: `skills/<agent>/SKILL.md` exists; (c) `FR-007 <agent> no edit tools`: its `tools:` line (read with `sed -n 's/^tools: //p'` outside `check`) has no `Edit` and no `Write` word; (d) for the two ponytail agents, `FR-007 <agent> no Bash`: no `Bash` word in that line; (e) the FR-006 and FR-007 phrase rows of `specs/004-on-demand-steps/contracts/background.md` section 4, added to the heredoc, one check per row.
  - `tests/test_inspect.sh:88-89`: `check "10 agents" '[ "$count" = 10 ]'` to `check "13 agents" '[ "$count" = 13 ]'`; line 97 phrase `Show a table of the 10 agents` to `Show a table of the 13 agents`.
  - `tests/test_model_hook.py:202-203` `test_module_constants`: expect `["st-build", "st-close", "st-debug", "st-fast", "st-git", "st-impeccable", "st-inspect", "st-plan", "st-ponytail-audit", "st-ponytail-debt", "st-quick", "st-review", "st-test"]`.
  - Run all three: the new FR-006 and FR-007 checks, "13 agents", the st-init phrase check and `test_module_constants` fail. Every other check passes.

### Implementation for User Story 2

- [X] T004 [US2] Create the 3 agents and every doc that lists agents, in one task (the agent list checks in `tests/test_inspect.sh`, `tests/test_model_files.sh` and `tests/test_model_hook.py` read all of them, lessons L6). Security: plan.md S2 (Bash and the engine download), S4 (model file names).
  - Create `agents/st-impeccable.md`, `agents/st-ponytail-audit.md`, `agents/st-ponytail-debt.md` with the text of `specs/004-on-demand-steps/contracts/background.md` sections 1 to 3: `model: opus` for `st-impeccable` and `st-ponytail-audit`, `model: sonnet` for `st-ponytail-debt` (FR-006, FR-007). Each keeps `` Start your report with `[<agent>]` on its own line. `` (`tests/test_session_hooks.sh:43`).
  - `skills/st-model/SKILL.md:10-11`: list the 13 agents in sorted order (as in T003).
  - `skills/st-init/SKILL.md:26`: `Show a table of the 10 agents` to `Show a table of the 13 agents`.
  - `README.md` agent table (after line 123, the `st-git` row): `` | `st-impeccable` | Opus | Background impeccable audit, read-only | ``, `` | `st-ponytail-audit` | Opus | Background ponytail audit, read-only | ``, `` | `st-ponytail-debt` | Sonnet | Background ponytail debt ledger, read-only | ``. Model overrides bullet (`README.md:166-168`): the 13 agents in sorted order. After `` `st-inspect` and `st-review` have no entry and keep the plugin default. `` (line 172, leave that sentence as it is) add `` `st-impeccable`, `st-ponytail-audit` and `st-ponytail-debt` have no entry either. ``
  - `DESIGN.md` D7 table, after the `st-git` row: `` | `st-impeccable` | impeccable audit | Opus | No | Background impeccable audit. Read-only. | ``, `` | `st-ponytail-audit` | ponytail audit | Opus | No | Background over-engineering audit. Read-only. | ``, `` | `st-ponytail-debt` | ponytail debt | Sonnet | No | Background `ponytail:` ledger. Read-only. | ``.
  - Run `bash tests/test_on_demand.sh`, `bash tests/test_inspect.sh`, `bash tests/test_model_files.sh`, `bash tests/test_session_hooks.sh`, `python3 -m unittest tests/test_model_hook.py`: all pass.
- [ ] T005 [US2] Add the FR-008 checks to `tests/test_on_demand.sh`. Before the phrase heredoc: make `$tmp/proj/.stratum` and `$tmp/plain`, a `$tmp/home/.claude/sr-opus-5.md` copy of `$root/sr-opus-5.md`, then `HOME="$tmp/home" CLAUDE_PLUGIN_ROOT="$root" CLAUDE_PROJECT_DIR="$tmp/proj" bash "$root/hooks/st-session-start.sh" > "$tmp/hook.out"` and the same with `CLAUDE_PROJECT_DIR="$tmp/plain"` into `$tmp/nohook.out`. In `phrases()` map target `hook` to `$tmp/hook.out`. Add the five phrases of `specs/004-on-demand-steps/contracts/background.md` section 5 as one check `FR-008 rule` with target `hook`. Add `check "FR-008 no rule outside Stratum" '! grep -qF "start the agent of the same name" "$tmp/nohook.out"'`. Run it: `FR-008 rule` fails, the no-rule check passes.
- [ ] T006 [US2] Add the background rule (FR-008). Security: plan.md S2 (the before and after `git status --porcelain` is the guard).
  - `hooks/st-session-start.sh:16`: append the text of `specs/004-on-demand-steps/contracts/background.md` section 5 inside the same `echo` string, before its closing `"`. No backticks (the string is in double quotes).
  - `README.md` Built in: after the **Session handoff** bullet add `- **Background audits.** Say "run st-ponytail-audit in the background" (or st-ponytail-debt, or an st-impeccable audit). The agent of the same name runs it read-only while you keep talking, and its report comes back. Any other skill runs only in the main session.`
  - `DESIGN.md`: after D23 add `- **D24. Background agents.** st-impeccable (audit only), st-ponytail-audit and st-ponytail-debt each have a read-only agent of the same name (no Edit or Write tool). The session-start rule starts it when the user asks for the skill in the background, compares git status --porcelain before and after, and says any other skill runs only in the main session.`
  - Run `bash tests/test_on_demand.sh` and `bash tests/test_session_hooks.sh`: all `ok`.

**Checkpoint**: US1 and US2 work. `bash tests/test_on_demand.sh` is all `ok`.

---

## Phase 5: User Story 3 - Write the handoff without stopping the discussion (Priority: P3)

**Goal**: mid-session the handoff runs as a background fork; when the user says they are done it
runs in the main session.

**Independent Test**: `bash tests/test_on_demand.sh` all `ok`; quickstart section 3 rows L11 and
L12.

### Tests for User Story 3

- [ ] T007 [US3] Add the FR-009 check to `tests/test_on_demand.sh`: one check `FR-009 handoff` from the phrases of `specs/004-on-demand-steps/contracts/background.md` section 6 on `skills/st-handoff/SKILL.md`, plus `d=$(grep -m1 "^description:" "$root/skills/st-handoff/SKILL.md")` outside `check` and `check "FR-009 handoff description" 'grep -qF "background fork" <<<"$d"'`. Run it: both fail.

### Implementation for User Story 3

- [ ] T008 [US3] Make the handoff fork or main session (FR-009). Security: plan.md S3 (the fork has the whole conversation).
  - `skills/st-handoff/SKILL.md`: the description and the `## Where it runs` section from `specs/004-on-demand-steps/contracts/background.md` section 6, then a `## Write it` heading before the existing "Write `<project>/.stratum/handoff.md`." line. Keep the rest unchanged.
  - `README.md` **Session handoff** bullet: after its first sentence add `Mid-session it runs in a background fork that has the whole conversation, so you keep talking. When you say you are done, it runs in the main session.`
  - `DESIGN.md` D18: add the bullet `- Mid-session st-handoff starts an Agent with subagent_type "fork" (it inherits the conversation and runs in the background). When the user says they are done, it runs in the main session so it finishes before exit. If the fork cannot start, it runs in the main session.`
  - Run `bash tests/test_on_demand.sh` and `bash tests/test_inspect.sh`: all `ok`.

**Checkpoint**: all stories work.

---

## Phase 6: Polish and checks Inspect would run

- [ ] T009 Negative controls (lessons L2, L7). Run quickstart.md section 2 exactly: the phrase loop (baseline 0, then 1 per line, each naming its own check), structure controls C1 to C6, and the README control. A control with 0 `FAIL` lines is a check that cannot fail: fix the check in `tests/test_on_demand.sh` and run again. Touch no repo file other than `tests/test_on_demand.sh`. Report each output line.
- [ ] T010 Full run. Run quickstart.md section 1 in full, including `claude plugin validate .claude-plugin/plugin.json` and the final `git status --porcelain` (no file a test wrote, lessons L8). Then give the user quickstart.md section 3 (live checks L1 to L12) as exact steps. It needs a live Claude Code session, so the user runs it. Record the results in the report: which rows passed, which failed with the output.

---

## Dependencies & Execution Order

### Phase Dependencies

- No setup or foundational phase.
- US1 (T001, T002), then US2 (T003 to T006), then US3 (T007, T008), then Polish (T009, T010).

### User Story Dependencies

- The stories do not use each other's features. They share `tests/test_on_demand.sh`, `README.md`
  and `DESIGN.md`, so they run one after another.
- Within each story the test task comes first and must be red before its build task.

### Parallel Opportunities

- None. Every task edits `tests/test_on_demand.sh` or a doc another task edits, and each build
  task must make the whole test file green (lessons L6). No task is `[P]`.

## Parallel Example

None (see above). The build is short: 10 tasks, all Markdown or small Bash.

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001, T002.
2. Stop and run quickstart section 3 rows L1 to L7.
3. Commit per task with `st-git`.

### Incremental Delivery

1. US1: the four commands (issue #13).
2. US2: background audits (I1).
3. US3: handoff fork (I2).
4. T009, T010 before the feature is called done.

## Notes

- One commit per task, exact paths, through `st-git`.
- No version bump in this feature (research R13).
- The live checks (quickstart section 3) are the only proof of SC-002 and SC-003. The automated
  checks prove the text and file structure, not the client's behavior.
