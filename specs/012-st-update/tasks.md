---

description: "Task list for st-update"
---

# Tasks: st-update

**Input**: Design documents from `/specs/012-st-update/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/st-update.md, quickstart.md

**Tests**: Required. Each FR gets a check that can fail, written before the task that builds it
(FR coverage at the end). Case ids U1 to U21 and rule rows R1 to R13 are in
`contracts/st-update.md` section 3.

**Rules for every task**: no comments in code except `ponytail:` markers. No new dependency, no
`jq`. Tests use a temp folder, a fake `CLAUDE_CONFIG_DIR` and a `claude` stub on `PATH` only. No
task runs the real `claude plugin update` or changes a real install record, settings file or
other project. Undo a negative control with the Edit tool, never `git checkout`.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

- **[P]**: Can run in parallel: no shared file in the phase and no other task's result; the task ends with `Owns:`
- **[lock]**: Test that cannot run at the same time as another; it runs through the test lock
- **[screen: <mode>]**: New screen; Build sends it to the Design lane in that mode
- **[Story]**: Which user story this task belongs to (US1 to US4)

No task is `[lock]`: every fixture lives under its own temp folder. No task is `[screen]`.

---

## Phase 1: Setup

None. The repo has the layout already.

## Phase 2: Foundational

None. The script is built in US1 and grown in US2 to US4.

---

## Phase 3: User Story 1 - See what is out of date (Priority: P1) MVP

**Goal**: `/stratum:st-update [<folder>]` shows one table of the items that are not current in
the main checkout, each linked worktree and each record subfolder, and changes nothing before the
OK.

**Independent Test**: `bash tests/test_st_update.sh` cases U1 to U8 and U20 pass on the fixture:
each item in each state, and the tree, `git status` and the fake records file are the same after
`audit`.

### Tests for User Story 1

- [X] T001 [P] [US1] Create `tests/test_st_update.sh` in the style of `tests/test_st_worker.sh` (`set -u`, `check` helper, `tmp=$(mktemp -d)`, `trap 'rm -rf "$tmp"' EXIT`, then `tmp=$(cd "$tmp" && pwd -P)` so every fake record `projectPath` equals what `git worktree list --porcelain` prints). Fixture: a git repo `$tmp/proj` with one commit, `.stratum/`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, `.claude/settings.local.json`; one linked worktree `$tmp/proj-wt` on its own branch; a second linked worktree `$tmp/proj-norec` with no install record and no `.claude/settings.local.json`; a record subfolder `$tmp/proj/apps/a`; a fake config folder `$tmp/cfg` (`CLAUDE_CONFIG_DIR`) with `settings.json` (`enabledPlugins` `ponytail@ponytail: true`), `plugins/installed_plugins.json` (records: main `local` 0.1.22 with `installPath` `$tmp/cfg/plugins/cache/stratum/stratum/0.1.22`, worktree `local` 0.7.0, subfolder `local` 0.1.22, a gone folder under `$tmp/proj`, a gone sibling `$tmp/proj-worker-w1a`, a gone folder of another project `$tmp/other-x`, a `user` record) and `plugins/known_marketplaces.json` (`stratum`, `directory` source, `installLocation` `$tmp/mkt`); a fake marketplace `$tmp/mkt` with `.claude-plugin/plugin.json` version `0.7.0` and `mcpServers.figcraft`, `agents/st-build.md`, `skills/st-init/SKILL.md`, `skills/st-design/design-tool.md` with a Tools line of two names; cache folders with `statusline/st-statusline.sh` for 0.1.22 and 0.7.0. Cases U1 to U8 and U20 exactly as the contract table says. U2 checks the `listed` `no install` row of `$tmp/proj-norec`, `gone` rows for the gone folder under `$tmp/proj` and for `$tmp/proj-worker-w1a`, and no row for `$tmp/other-x`. U5 uses the dead names `st-gone` and `Skill(stratum:st-gone)` and the name `Skill(stratum:x$(touch pwned))` (expected `invalid`, and no file `pwned` anywhere under `$tmp` after `audit`); no tracked file outside `specs/` may contain `st-check` or `st-validate` (`tests/test_inspect.sh:86`). U7 for D10: a path ignored only by `.git/info/exclude` is `current`, one ignored nowhere is `new`; the constitution named only in `CLAUDE.local.md` is `current`; `ponytail@ponytail` `false` only in `.claude/settings.local.json` is `current`, in neither file is `new`. U8 compares the hashes of `find "$tmp" -path '*/.git' -prune -o -type f -print` (no `.git` folders, whose index `git status` can rewrite), `git status --porcelain` of every checkout and the records file before and after `audit`. U20: `git init -b feat-x "$tmp/mkt"` gives a `marketplace-branch` `warn` row naming `feat-x`; on `main` and as a plain folder, no row. Exit 1 when any check fails. Red now: `scripts/st-update.sh` is missing. Owns: `tests/test_st_update.sh`. Test: bash tests/test_st_update.sh.
- [X] T002 [P] [US1] Create `tests/test_update_rules.sh` in the style of `tests/test_plan_rules.sh` (`root="${ST_ROOT:-...}"`, `check`, `ROWS` heredoc of `id|file|phrase`) with rows R1 to R4 from the contract table on `skills/st-update/SKILL.md`, and a check that `skills/st-update/SKILL.md` exists with `name: st-update` in its front matter. Red now: the skill is missing. Owns: `tests/test_update_rules.sh`. Test: bash tests/test_update_rules.sh.

### Implementation for User Story 1

- [ ] T003 [US1] Create `scripts/st-update.sh` (bash, `set -euo pipefail`, usage line and exit 2 like `scripts/st-worker.sh`, JSON work in `python3 -I` blocks like `statusline/st-statusline.sh`) with `items` (contract 1a: a static list in the script, reads no other file) and `audit [<folder>]` (contract 1b; research R1 to R3 per D10, R5 to R12, R16). States only from this set: "`current`, `outdated`, `discontinued`, `new`, `ask`, `invalid`, `gone`, `listed`, `warn`". `audit` never writes, never calls `claude`, and prints no settings value it does not check. The discontinued file list starts with `.stratum/commit-mode`. A discontinued name gets its row only when it matches `^[A-Za-z0-9_.:@/*()-]+$`, any other name an `invalid` row. A `gone` row only for a missing folder under a checkout or a sibling of the main checkout named `<main checkout name>-*`. In `DESIGN.md` D13a, add the row, with the same two-space indent as the other rows of that table (`tests/test_local_files.sh:5` reads only `^  | `), `` | `.stratum/commit-mode` | own | Discontinued. `st-update` removes it from each checkout. | `` and the sentence: a change that removes a feature which wrote a project file adds that file to the discontinued list in `scripts/st-update.sh`. Test: bash tests/test_st_update.sh && bash tests/test_local_files.sh.
- [ ] T004 [US1] Create `skills/st-update/SKILL.md` (front matter `name: st-update` and a one-line description) with contract section 2 steps 1 to 3: audit call and stop line, the table (header with marketplace version, folder and config folder; rows not `current` per folder; one count line per folder; `worker` marks), the branch warning text, and the one gate with `skip <worktree>` and no change before the OK. Add the row `` | `st-update [folder]` | Audit the project's Stratum files in every checkout, then update the install, statusline and harness lines after one OK. | `` to the Skills table in `README.md` after the `st-init` row, and the same row to the D9 table in `DESIGN.md`, with "Twenty-five entry skills" changed to "Twenty-six entry skills". Test: bash tests/test_update_rules.sh && bash tests/test_inspect.sh && bash tests/test_no_frontend_design.sh && bash tests/test_local_files.sh.

**Checkpoint**: the audit and gate work. Answering no changes nothing.

---

## Phase 4: User Story 2 - Bring the project up to date (Priority: P1)

**Goal**: after the OK, each folder with its own record gets `claude plugin update` with its
scope, `statusLine` follows the updated record, new items are added, discontinued traces go, each
branch gets one commit, and the report says to restart.

**Independent Test**: on the fixture with the `claude` stub, run `plugin` and every `fix`, then
`audit` again: only `current`, `gone` and `listed` rows (U17).

### Tests for User Story 2

- [ ] T005 [P] [US2] Add to `tests/test_st_update.sh` a `claude` stub in `$tmp/bin` that writes its arguments and working folder to a log, and on `plugin update --json -s <scope> stratum@stratum` sets the matching fake record's `version` to `0.7.0`, `installPath` to the 0.7.0 cache folder and a new `lastUpdated`, then prints the `--json` line from research R4. Modes by env: `STUB_FAIL` (prints `{"outcome":"failed",...}`, exit 1) and `STUB_OTHER` (updates a different record). Add cases U9, U10, U11, U13, U14, U17, U18 and U19 exactly as the contract table says. U9 also checks the stub is never called for the gone record under `$tmp/proj`, the gone sibling `$tmp/proj-worker-w1a`, the `user` record or `$tmp/proj-norec` (no record). U11 also runs `fix statusline` in `$tmp/proj-norec` (target: the main checkout's updated record) and checks that `.claude/settings.local.json` is created with only the `statusLine` key. Red on the new cases. Owns: `tests/test_st_update.sh`. Test: bash tests/test_st_update.sh.
- [ ] T006 [P] [US2] Add rows R5, R7, R8, R9, R10 and R11 to `tests/test_update_rules.sh`. R8 checks that the commit command in the skill ends with `-- <paths>`. R9 also checks that `skills/st-update/SKILL.md` does not contain `veent-commit-ask` (D11). Red on the new rows. Owns: `tests/test_update_rules.sh`. Test: bash tests/test_update_rules.sh.

### Implementation for User Story 2

- [ ] T007 [US2] Add `plugin <folder>` (contract 1c: exact-path record with scope `local` or `project` only; `claude` missing prints the command; after the run, the folder's record must have `newVersion` and no other `stratum@stratum` record may change `lastUpdated`, else exit 1 with the message and `Run: cd <folder> && claude plugin update stratum@stratum -s <scope>`) and `fix <folder> <kind> <name>` for every kind in contract 1d (`ignore`, `pointer`, `statusline`, `plugins-off`, `figcraft`, `file`, `models-key`, `allow`, `gone-file`) to `scripts/st-update.sh`. `fix statusline` refuses with exit 3 when the target record's version is not the marketplace version. A `fix` on a current item prints `same <file>`, exit 0. JSON writes keep every other key, `indent=2`. The script runs no `git add`, `git commit` or `git push`. Test: bash tests/test_st_update.sh.
- [ ] T008 [US2] Add contract section 2 steps 4, 6, 7 and 8 to `skills/st-update/SKILL.md`: `plugin` per folder and go on after a failure; `fix statusline` only after `plugin` exits 0; the other fixes; st-init steps 3, 4, 7 and 11 questions one at a time with `skip`; `/stratum:st-constitution` for a missing constitution; the exact `fix` command for a blocked Bash call; single quotes around every argument passed to the script and to git; per checkout one `git -C <checkout> add -- <paths> && git -C <checkout> commit -m "chore(stratum): update harness files to <version>" -m "<one line per item>" -- <paths>` (the commit ends with `-- <paths>`, so files the user staged stay out of it) with the fixed path list (`.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, and `.stratum/state.json`, `.stratum/advisor.json` when not ignored; never `.claude/settings.local.json` or `.stratum/models.json`), no `-A`, `--amend`, `--no-verify` or push; a denied commit quotes the hook's reason and gives that command (D11); the report per folder and the last line `Restart running Claude Code sessions in these folders to load Stratum <version>.` Test: bash tests/test_update_rules.sh.

**Checkpoint**: a full run on the fixture leaves only current rows.

---

## Phase 5: User Story 3 - Keep the user's own changes (Priority: P2)

**Goal**: st-update changes only Stratum's lines and keys, asks before it changes a non-Stratum
`statusLine`, and skips dirty committed files and detached HEADs.

**Independent Test**: `bash tests/test_st_update.sh` cases U12, U15, U16 and U21 pass: a custom
`statusLine` is refused without `--force`, the edited constitution is byte-equal, a dirty
`CLAUDE.md` in the worktree is skipped with its reason.

### Tests for User Story 3

- [ ] T009 [P] [US3] Add cases U12, U15, U16 and U21 to `tests/test_st_update.sh` exactly as the contract table says. U12 gives the fixture an edited `.stratum/constitution.md`, `state.json`, `lessons.md`, `handoff.md`, `git-guard.json`, `powerline.json`, `advisor.json`, a user line in `.gitignore` and `CLAUDE.md`, and user keys (including an `env` key) in both settings files, runs every `fix`, and checks those files byte-equal and those lines and keys kept; it also checks `audit` output does not contain the `env` value. U15 makes `CLAUDE.md` dirty in the worktree and runs `fix pointer` there (exit 3, the reason, `CLAUDE.md` byte-equal), then checks out a detached HEAD in a second worktree and runs `fix pointer` there (exit 3). Red on the new cases. Owns: `tests/test_st_update.sh`. Test: bash tests/test_st_update.sh.
- [ ] T010 [P] [US3] Add rows R6 and R12 to `tests/test_update_rules.sh`. Red on the new rows. Owns: `tests/test_update_rules.sh`. Test: bash tests/test_update_rules.sh.

### Implementation for User Story 3

- [ ] T011 [US3] In `scripts/st-update.sh` `fix`: before a change to `.gitignore`, `AGENTS.md`, `CLAUDE.md` or `.claude/settings.json`, refuse with exit 3 and `skip: <file> has uncommitted changes` when `git -C <folder> status --porcelain -- <file>` is not empty, and `skip: detached HEAD, no branch to commit on` on a detached HEAD; `fix statusline` refuses a non-Stratum command (`skip: not a Stratum statusline`) unless `--force`; `fix pointer` writes `@AGENTS.md` only when `AGENTS.md` exists and never creates `AGENTS.md`; invalid JSON is refused with `skip: <file> is not valid JSON`. Test: bash tests/test_st_update.sh.
- [ ] T012 [US3] Add contract section 2 step 5 (each `ask` row: show the old and the new `statusLine` command, ask, `fix ... --force` only on yes) and the Never list to `skills/st-update/SKILL.md`. Test: bash tests/test_update_rules.sh.

**Checkpoint**: user content survives a full run.

---

## Phase 6: User Story 4 - Keep st-init and the item list the same (Priority: P3)

**Goal**: a maintainer who adds a name to st-init gets a red test until the item list has it.

**Independent Test**: `bash tests/test_update_items.sh` is green, and its built-in negative
control proves it goes red on an added `.gitignore` line.

### Tests for User Story 4

- [ ] T013 [P] [US4] Create `tests/test_update_items.sh` per contract section 4: `root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"`; collect from `$root/skills/st-init/SKILL.md` the backticked names of step 2, the `@` lines of step 6, every backticked `.stratum/<name>.json` or `.stratum/<name>.md` without `<`, and the settings keys from steps 7, 8 and 10 by the rule of contract section 4 step 1 (the first `"<key>":` without `<` in a backticked span right after `Merge in` or `merge`, and each backticked name right after `into`; today `statusLine`, `enabledPlugins`, `permissions.allow`; no fixed list of keys); compare with `bash "$root/scripts/st-update.sh" items`; print `FAIL st-init names <name>, st-update items lack it` for each miss. Negative control, only when `ST_ROOT` is not set: copy `skills/st-init/SKILL.md` and `scripts/st-update.sh` into a temp root, add `` `.stratum/zz-drift.json` `` to step 2 of the copy, run `ST_ROOT=<temp> bash tests/test_update_items.sh`, and check exit 1 and `.stratum/zz-drift.json` in its output. Owns: `tests/test_update_items.sh`. Test: bash tests/test_update_items.sh.

### Implementation for User Story 4

- [ ] T014 [US4] Add to the `items` list in `scripts/st-update.sh` each name T013 reports missing. Then run quickstart negative control N2 by hand (N1 is covered by T013's built-in control): make the break with the Edit tool, see `bash tests/test_update_items.sh` exit 1 and name the item, undo with the Edit tool, see it green. Record the result in the task's report. Test: bash tests/test_update_items.sh.

**Checkpoint**: drift between st-init and st-update turns a test red.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T015 [P] Add row R13 to `tests/test_update_rules.sh`: `README.md` has `claude plugin update stratum@stratum -s local`, `claude plugin update stratum@stratum -s project`, `bash tests/test_st_update.sh`, `bash tests/test_update_rules.sh` and `bash tests/test_update_items.sh`. Red now. Owns: `tests/test_update_rules.sh`. Test: bash tests/test_update_rules.sh.
- [ ] T016 [P] Set `"version": "0.7.0"` in `.claude-plugin/plugin.json`. Owns: `.claude-plugin/plugin.json`. Test: claude plugin validate .claude-plugin/plugin.json && grep -q '"version": "0.7.0"' .claude-plugin/plugin.json.
- [ ] T017 In `README.md` Install, after the `/stratum:st-init` block, add the first-time update for a project whose install has no st-update yet (FR-021): run in the project folder `claude plugin update stratum@stratum -s local` for a personal install or `claude plugin update stratum@stratum -s project` for the `--scope project` install above (use the scope you installed with), restart the session, then `/stratum:st-update`. Add the three lines `bash tests/test_st_update.sh`, `bash tests/test_update_rules.sh`, `bash tests/test_update_items.sh` to the Tests block. Depends on T015. Test: bash tests/test_update_rules.sh && bash tests/test_inspect.sh.
- [ ] T018 Run quickstart negative controls N3 to N8 on `scripts/st-update.sh`, `README.md` and the audit: break with the Edit tool, see the named case fail, undo with the Edit tool, see it green. No file stays changed. Record each result in the task's report. Test: bash tests/test_st_update.sh && bash tests/test_inspect.sh.

The live run (quickstart section 3) is the user's, after the merge to `main`. No agent runs it.

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 3 (US1) first. Phases 4 and 5 (US2, US3) follow in order: they grow the same
  `scripts/st-update.sh`, `tests/test_st_update.sh`, `tests/test_update_rules.sh` and
  `skills/st-update/SKILL.md`.
- Phase 6 (US4): T013 needs only T003 (the `items` subcommand) and owns only
  `tests/test_update_items.sh`, so it runs at the same time as US2 and US3. T014 edits
  `scripts/st-update.sh`, so it runs after T011.
- Phase 7: T015 and T016 can run any time after T004. T017 after T015. T018 last.

### User Story Dependencies

- US1: none.
- US2: after US1 (shares all four files).
- US3: after US2 (shares all four files).
- US4: T013 shares no file with US2 or US3 and runs beside them. T014 after US3.

### Within Each User Story

- The test tasks come first and must fail on the new cases before the build task starts.
- Script before skill text in each story.

### Parallel Opportunities

- Phase 3: T001 and T002.
- Phase 4: T005 and T006.
- Phase 5: T009 and T010.
- T013 beside Phases 4 and 5.
- Phase 7: T015 and T016.

## Parallel Example: User Story 1

```text
T001 tests/test_st_update.sh   (fixture and U1 to U8, U20)
T002 tests/test_update_rules.sh (R1 to R4)
then T003 scripts/st-update.sh, then T004 skills/st-update/SKILL.md with README.md and DESIGN.md
```

## Implementation Strategy

- MVP: US1. The audit alone shows the user how far each folder has drifted and changes nothing.
- Then US2 (the update), US3 (safety for user content), US4 (drift test), Polish (0.7.0, README).
- Each story ends with its own tests green. No task runs the full suite.

## FR coverage

| FR | Test task (case or row) | Build task |
|----|-------------------------|------------|
| FR-001 | T001 (U1), T002 (R1) | T003, T004 |
| FR-002 | T001 (U2) | T003 |
| FR-003 | T001 (U7) | T003 |
| FR-004 | T001 (U3 to U7) | T003 |
| FR-005 | T001 (U3) | T003 |
| FR-006 | T001 (U4), T009 (U16), T010 (R6) | T003, T011, T012 |
| FR-007 | T001 (U5) | T003 |
| FR-008 | T001 (U6) | T003 |
| FR-009 | T002 (R2, R3); behavior: quickstart section 3 | T004 |
| FR-010 | T001 (U8), T002 (R3) | T003, T004 |
| FR-011 | T005 (U9, U10, U18), T006 (R5) | T007, T008 |
| FR-012 | T005 (U11), T006 (R5) | T007, T008 |
| FR-013 | T009 (U12, U21), T010 (R12) | T011, T012 |
| FR-014 | T005 (U13), T006 (R7); the questions: quickstart section 3 | T007, T008 |
| FR-015 | T005 (U14) | T007 |
| FR-016 | T005 (U19), T006 (R8); one commit per branch: quickstart section 3 | T007, T008 |
| FR-017 | T009 (U15) | T011 |
| FR-018 | T006 (R10); behavior: quickstart section 3 | T008 |
| FR-019 | T006 (R11); behavior: quickstart section 3 | T008 |
| FR-020 | T013 (built-in negative control), T014 (N2) | T014 |
| FR-021 | T015 (R13) | T017 |
| Edge case: marketplace branch | T001 (U20), T002 (R4) | T003, T004 |
| D11 denied commit | T006 (R9) | T008 |
| SC-001 | T005 (U17) | T007 |
| SC-002 | quickstart section 3 steps 3 and 5 (one OK for all folders, only FR-006 and FR-014 questions) | T004, T008 |
| SC-003 | T009 (U12) | T011 |
| SC-004 | quickstart section 3 step 7 (`autonomous` tag after restart) | T007, T008 |

Skill steps (FR-009, FR-016, FR-018, FR-019 and the FR-014 questions) are checked by phrase rows
in `tests/test_update_rules.sh` plus the user's live run in quickstart section 3. That is the
repo's pattern for skill steps (found at Inspect, F5). There is no skill-level behavior test.
