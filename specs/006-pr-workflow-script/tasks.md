---

description: "Task list for Ultracode Workflow Script for st-pr"
---

# Tasks: Ultracode Workflow Script for st-pr

**Input**: Design documents from `/specs/006-pr-workflow-script/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/pr-workflow.md, quickstart.md

**Tests**: Required (FR-012, FR-013). Every FR has a check that fails before its build task.
Expected red states between tasks are in quickstart.md section 1. Do not edit a test to make it
green.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum-22` (branch `22-workflow-scripts`).

**Rules for every task**: no comments except `ponytail:` markers (`scripts/st-verify.sh` fails
on an added line that starts with `//`, `# `, `/*` or `*`), minimal diff, no new dependency, no
config. Keep every phrase of contracts section 5 whole on one line (rule P1). Do not edit
`spec.md`, `decisions.md`, the checklists, or any line of `skills/st-pr/SKILL.md` that exists
now. Run every test with `PYTHONDONTWRITEBYTECODE=1`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1, US2 or US3 from spec.md

## Phase 1: Setup

None. node v24.14.1, bash 5.3.20 and git 2.56.0 are installed (research header). `workflows/` is
created by T002.

## Phase 2: Foundational

None.

---

## Phase 3: User Story 1 - Big branch, Ultracode on (Priority: P1) MVP

**Goal**: st-pr takes the workflow path on a big branch with Ultracode on, and the fixed script
does steps 2 to 4.

**Independent Test**: `node tests/test_pr_workflow.mjs` and `bash tests/test_pr_skill.sh` all
`ok`; quickstart section 3 rows M3, M4 and M5.

### Tests for User Story 1

- [x] T001 [US1] Create `tests/test_pr_workflow.mjs` and `tests/test_pr_skill.sh`, and add both to the README `## Tests` block, in one task (`tests/test_inspect.sh` "README tests" reads the folder and the README together, lessons L6). The checks assert phrases and values the code builds (lessons L1). The node test writes no file (lessons L8). FR-001 to FR-013, SC-004.
  - `tests/test_pr_workflow.mjs`: the harness and the 16 cases of contracts section 6, names verbatim. Frame of `tests/test_token_weather.mjs`: `import assert from "node:assert/strict"`, `check(name, fn)` that prints `ok   <name>` or `FAIL <name>: <message>`, `process.exit(fails)` at the end. Cases are async, so `check` awaits `fn`. Cases run one at a time (`await check(...)` at top level, never `Promise.all`), because each sets its own fakes on `globalThis`. Script path: `process.env.ST_PR_SCRIPT ?? fileURLToPath(new URL("../workflows/pr.js", import.meta.url))`. A missing or unreadable script prints `FAIL load: <message>` and exits 1. Each case sets fresh fakes and fresh `globalThis.args`: `{projectRoot: "/p", pluginRoot: "/g", scratchpad: "/s", base: "main", branch: "b", featureDir: "", commits}`. The `blocking stop` case message names "blocking stop".
  - `tests/test_pr_skill.sh`: `#!/usr/bin/env bash`, `set -u`, `root="$(cd "$(dirname "$0")/.." && pwd)"`, `skill="${ST_PR_SKILL:-$root/skills/st-pr/SKILL.md}"`, `fail=0`. Read the 14 rows of contracts section 5 from a `<<'EOF'` heredoc as `name<TAB>phrase` (phrase = the cell text inside its outer backticks, no space at either end), `grep -qF -- "$phrase" "$skill"`, print `ok   <name>` or `FAIL <name>: <phrase>`, then `exit $fail`. Mode 644 like the other `tests/*.sh` files (they run as `bash tests/<file>`).
  - `README.md` `## Tests` block: after the line `bash tests/test_on_demand.sh` add `bash tests/test_pr_skill.sh`; after `node tests/test_token_weather.mjs` add `node tests/test_pr_workflow.mjs`.
  - Run `node tests/test_pr_workflow.mjs` (red: `FAIL load`), `bash tests/test_pr_skill.sh` (red: all 14 rows), `bash tests/test_inspect.sh` (green). This is the T001 row of quickstart section 1.

### Implementation for User Story 1

- [x] T002 [P] [US1] Create `workflows/pr.js` per contracts section 2 (FR-001, FR-005 to FR-011). Checked against the Workflow runtime of Claude Code 2.1.302 (lessons L5, research R1, R2, R11). Security: plan.md S1 (publish scan, never the value), S2 (read-only prompt rule, the draft and fixers write only `<scratchpad>/pr-body.md`), S3 (repo text is data), S4 (args and result contract).
  - First statement: the meta literal of contracts 2.1, verbatim. The body never reads `meta`.
  - The three pinned lines of contracts 2.2: `const CHUNK = 25`, `const LENSES = ['paths', 'frs', 'commands']`, and the blocking return on one line, the only line with `blocked: true`.
  - Labels, schemas, phases and control flow of contracts 2.2 and 2.3. Facts and chunks in one `parallel`. Refuters in one `parallel`. Fixers in a plain `for` loop with `await`, one per lens with problems. `opts.phase` on every `agent()` call. No `model` or `effort` option.
  - Prompts per contracts 2.4. The read-only sentence is verbatim and on one line (contracts 2.2 pinned lines). The `facts:tests` prompt says `PYTHONDONTWRITEBYTECODE=1` (lessons L8).
  - Return values per contracts section 3. Warning strings use the prefixes of contracts section 3 exactly.
  - Run `node tests/test_pr_workflow.mjs`: all 16 cases `ok`.

- [x] T003 [P] [US1] Edit `skills/st-pr/SKILL.md`: add step 1 item 5 (contracts 4.1) after item 4, and the `## Workflow path` section (contracts 4.2, including the step 2 sentence for a refused `scriptPath`: read the file and pass its text through the `script` input, same `args`, decision D6) between `## 1. Scope` and `## 2. Facts`, text verbatim (FR-002, FR-003, FR-004, FR-006, FR-010, FR-013). Two inserts only: no existing line changes. The before and after compare is detection, not a stop, and does not see git-ignored paths, writes outside the repo, a push or a gh call (lessons L10). The three failure states of the background run (in progress, no result, cannot start) are in the text (lessons L11). Security: plan.md S2, S4.
  - Run `bash tests/test_pr_skill.sh`: all 14 rows `ok`. `bash tests/test_inspect.sh`: all `ok`. `git diff --numstat main -- skills/st-pr/SKILL.md | awk '{d+=$2} END {print d+0}'` prints `0`.

- [x] T004 [US1] Manual: quickstart section 3 rows M3 (big branch, workflow path, body passes the step 4 check with zero edits), M4 (blocking find stops before the gate, value not shown) and M5 (working directory outside the plugin dir: the `Workflow({name: "stratum:pr"})` call starts the run, D8). The user runs these with Ultracode on and answers Abort at the gate. Reads `skills/st-pr/SKILL.md` and `workflows/pr.js`, edits nothing (SC-001, SC-003, SC-005).

**Checkpoint**: US1 works. Both new tests are all `ok`.

---

## Phase 4: User Story 2 - Small branch, or Ultracode off (Priority: P1)

**Goal**: under the size rule, or with Ultracode off, st-pr says so in one line and runs steps 2
to 4 as today. Built by T003 (step 1 item 5). No file of its own.

**Independent Test**: quickstart section 3 rows M1 and M2.

- [ ] T005 [US2] Manual: quickstart section 3 rows M1 (Ultracode on, under the rule: current path) and M2 (Ultracode off, over the rule: current path), Abort at the gate. Reads `skills/st-pr/SKILL.md`, edits nothing. US2 scenario 3 (exactly 30 and 40) is the text `more than 30 commits or more than 40 changed files`, checked by `tests/test_pr_skill.sh` rows FR-002 (FR-002, FR-003, FR-004, SC-002).

**Checkpoint**: the one-line path message shows on both paths.

---

## Phase 5: User Story 3 - The script is tested (Priority: P2)

**Goal**: a change to the chunk size, the blocking stop, the refuter count, the sequential fixes,
a threshold or the script path turns a test red. Built by T001.

**Independent Test**: quickstart section 2, C1 to C13.

- [x] T006 [US3] Run the negative controls C1 to C13 of quickstart section 2 against scratch copies of `workflows/pr.js` and `skills/st-pr/SKILL.md` through `ST_PR_SCRIPT` and `ST_PR_SKILL`, and C13 in a scratch git repo (lessons L2). Each gives exactly the FAIL lines of its row. Edit no repo file. If a control gives other FAIL lines, report it; do not edit the test to match (FR-012, FR-013, SC-004).

**Checkpoint**: every guarded fact has a control that went red.

---

## Phase 6: Polish

- [x] T007 Run every command of quickstart section 1 and each line of the README `## Tests` block in `README.md`: all pass. Run `bash scripts/st-verify.sh 'node tests/test_pr_workflow.mjs && bash tests/test_pr_skill.sh' workflows/pr.js tests/test_pr_workflow.mjs tests/test_pr_skill.sh`: `ok`. `git status --porcelain` lists only `workflows/pr.js`, `tests/test_pr_workflow.mjs`, `tests/test_pr_skill.sh`, `skills/st-pr/SKILL.md`, `README.md`, `.stratum/state.json` (`hooks/st-phase.py` writes it) and the feature dir files (lessons L8).

---

## Dependencies & Execution Order

- T001 first. T002 and T003 after T001, in parallel (different files, different tests).
- T004 after T002 and T003. T005 after T003. T006 after T002 and T003. T007 last.
- US2 and US3 have no build task of their own: T003 builds US2, T001 builds US3.

## Parallel Example

```text
After T001: T002 (workflows/pr.js) and T003 (skills/st-pr/SKILL.md) at once.
```

## Implementation Strategy

MVP is US1: T001 to T003 give a working workflow path and the current path. T004 to T006 prove
it. Coverage: FR-001 to FR-004, FR-006, FR-010 to FR-013 have test rows in T001 that check behavior.
FR-005, FR-007, FR-008 and FR-009 are prompt-only: what the agents do is not testable with fakes.
Their checks are the `prompt rules` case (the prompt holds the rule) and the manual row M3.
SC-001, SC-002, SC-003 and SC-005 also have manual rows (T004, T005).

---

## Phase 7: Convergence

- [x] T008 [US3] Extend the `prompt rules` case in `tests/test_pr_workflow.mjs` with the five review-added strings of `workflows/pr.js`, and change nothing else (test-only, decision D7, FR-012). The strings already exist in the script, so the case stays green. The test's scratchpad is `/s` and the case runs with `featureDir` `""`, so check each string against the prompts in `calls`, naming the label and the missing text in the fail message:
  - `Do not stage, commit, push or run gh.` in the `draft` prompt and in every `fix:` prompt.
  - `Read files only under the project root, plus /s/pr-body.md` in every prompt.
  - ``under `.github/` or under `docs/` `` in the `draft` prompt.
  - `There is no feature dir: report each FR claim in the body as wrong` in the `refute:frs` prompt.
  - `facts:tests result:` in the `refute:commands` prompt.
  - Run `node tests/test_pr_workflow.mjs`: all 16 cases `ok`. Control, on a scratch copy (lessons L2): for each of the five strings, `s=$(mktemp -d); sed "s/<string>//" workflows/pr.js > "$s/pr.js"; ST_PR_SCRIPT="$s/pr.js" node tests/test_pr_workflow.mjs | grep '^FAIL'` prints a `FAIL prompt rules` line that names the removed string. Edit no repo file other than the test (partial, FR-005, FR-007, FR-008, FR-009).
