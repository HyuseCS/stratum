# Implementation Plan: st-update

**Branch**: `012-st-update` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/012-st-update/spec.md`, decisions D1 to D11 in
[decisions.md](decisions.md), checklist [checklists/safety.md](checklists/safety.md), issue #73.

**Status**: No open decisions. D10 and D11 (decisions.md) settle the item rules (research R1 to
R3) and the denied-commit text (research R13). The marketplace branch warning comes from the spec
edge case (research R16, case U20).

## Summary

A new skill, `/stratum:st-update [<folder>]`, and one script, `scripts/st-update.sh`. The script's
`audit` reads the project's main checkout, its linked worktrees and record subfolders, the install
records and the marketplace, and prints one row per harness item with its state. It writes
nothing. The skill shows the rows that are not current in one table and asks once. After the OK, the
script's `plugin` runs `claude plugin update --json -s <scope> stratum@stratum` in each folder with
its own record and checks that only that record moved. Then `fix` repoints `statusLine` at the
updated record's path and fixes each other row, one line or key at a time, and refuses dirty
committed files and detached HEADs. The skill asks st-init's questions for missing `.stratum/`
files, commits the changed files once per branch through the commit guard, and reports. A drift
test fails when st-init names something the item list lacks. Version 0.7.0.

An item is current when its effect is in place from any source (D10): an ignored path, the
constitution named in `AGENTS.md`, `CLAUDE.md` or `CLAUDE.local.md`, a plugin `false` in either
settings file. When the marketplace folder is a git checkout not on `main`, the gate warns and
names the branch (research R16).

## Technical Context

**Language/Version**: Bash 5 (script, tests), Python 3 (`python3 -I` blocks for JSON), Markdown
(skill, README, DESIGN.md).

**Primary Dependencies**: Claude Code 2.1.316 CLI: `claude plugin update [--json] [-s <scope>] <plugin>`
(research R4). `git` worktrees. No new package. No `jq` (research R15).

**Storage**: Reads `<config>/plugins/installed_plugins.json`, `<config>/plugins/known_marketplaces.json`,
`<config>/settings.json`, the marketplace's `plugin.json`. Writes only Stratum lines and keys in
`.gitignore`, `CLAUDE.md`, `.claude/settings.json`, `.claude/settings.local.json`,
`.stratum/models.json`, `.stratum/state.json`, and deletes `.stratum/commit-mode` (data-model.md).

**Testing**: `bash tests/test_st_update.sh` (new, fixture with a `claude` stub, cases U1 to U21),
`bash tests/test_update_rules.sh` (new, skill phrases), `bash tests/test_update_items.sh` (new,
FR-020 with a built-in negative control), existing `bash tests/test_inspect.sh`,
`bash tests/test_no_frontend_design.sh`, `bash tests/test_local_files.sh`,
`claude plugin validate .claude-plugin/plugin.json`. Live run by hand (quickstart section 3).

**Target Platform**: Claude Code on Linux, the PC and the laptop.

**Project Type**: Claude Code plugin (skill, script, tests, docs).

**Performance Goals**: N/A. One `claude plugin update` per folder, about 2 s each.

**Constraints**: No comments except `ponytail:` markers. Minimal diff. st-init unchanged (D9).
The script runs no git command that changes the repo (research R13). Nothing changes before the
gate (FR-010).

**Scale/Scope**: New: `skills/st-update/SKILL.md`, `scripts/st-update.sh`,
`tests/test_st_update.sh`, `tests/test_update_rules.sh`, `tests/test_update_items.sh`. Edits:
`README.md` (skills row, first-time command with `-s local` and `-s project`, tests block lines
`bash tests/test_st_update.sh`, `bash tests/test_update_rules.sh`,
`bash tests/test_update_items.sh`), `DESIGN.md` (D9 row and count, D13a
row and rule), `.claude-plugin/plugin.json` (0.7.0).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md`, on purpose (base repo). The gates come from the Plan
agent rules.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that can fail, before its build task | Pass. tasks.md "FR coverage" maps each FR to its test task and build task |
| G2. Every task names its files and its exact test command, none runs the full suite | Pass (tasks.md) |
| G3. `[P]` only for tasks that share no file in their phase, each with `Owns:` | Pass. T001 and T002, T005 and T006, T009 and T010, T013, T015 and T016 |
| G4. `[screen]` tasks | None. No app screen |
| G5. Security notes | Pass. S1 to S7 below |
| G6. No speculative work | Pass. No tool installs (spec Assumption 4), no marketplace refresh, no per-worktree questions, no hash records (D1 rejected O2), no other config folder |
| G7. Ground in the installed code and versions | Pass. CLI 2.1.316 probed (research R4). One unknown: how the CLI picks a record in a folder with no exact match. The script never runs it there and checks the result (F1) |
| G8. Each new check has a negative control | Pass. Quickstart section 2, N1 to N6, and the built-in control in `tests/test_update_items.sh` |
| G9. Tests leave no files | Pass. All fixtures under one temp folder, removed on exit |
| G10. Open decisions settled | Pass. D10, D11 |
| G11. No live install change in tests or build | Pass. Tests use a fake `CLAUDE_CONFIG_DIR` and a `claude` stub. Only the user's live run (quickstart section 3) calls the real CLI |

## Security Notes

- **S1. Access rules (`permissions.allow`).** `fix allow` removes only the exact Stratum forms of
  research R9 whose target the marketplace tree lacks, and only from the file the row names.
  `fix figcraft` adds only Tools-line names, only where the user already allowed FigCraft
  (research R10), never the server-wide `mcp__plugin_stratum_figcraft`. Nothing else in an allow
  list is read for removal.
- **S2. Settings files.** `.claude/settings.json` and `.claude/settings.local.json` change one key
  per call, every other key kept. Invalid JSON is never touched. `audit` prints only the keys it
  checks, never `env` or other values, since settings files can hold secrets. A blocked edit is
  reported with the exact command, never forced another way (FR-018).
- **S3. External CLI.** `claude plugin update` runs only after the gate, only in a folder whose
  path has its own `local` or `project` record. A run in a folder with no record updated another
  folder's record (research R4), so the script checks after each run that only the target record
  moved. `user` and `managed` records are never updated.
- **S4. Install records.** Read only. The script never edits `installed_plugins.json` or the cache.
- **S5. Commits on many branches.** The skill runs `git add` and `git commit` itself, so the git
  guard and project hooks see each call. Exact paths, no `-A`, no `--amend`, no `--no-verify`, no
  push. Dirty files and detached HEADs are skipped. A denied commit is reported, never worked around.
- **S6. Untrusted paths.** Folder paths come from `git worktree list` and the records. The script
  quotes them, uses `cd -- "$dir"` and `git -C "$dir"`, and runs no `eval`. JSON is parsed by
  `python3 -I`, never by `source`.
- **S7. No sign-in, secrets, personal or minors' data, data model or contracts of an app.**

## Breaking Changes

- None for stored data. Version 0.7.0 adds a command.
- `statusLine` in each updated folder moves from the source folder or an old cache to
  `cache/stratum/stratum/0.7.0/` (D4). A later version needs another st-update run.
- Rollback: revert the feature's commits. Changes in user projects stay: they are the same lines
  st-init writes.

## Decisions

- D10 (decisions.md): an item is current when its effect is in place from any source. A missing
  item goes in st-init's place. Research R1 to R3, case U7.
- D11 (decisions.md): a denied commit gets the hook's reason and the exact `git -C` command. The
  skill names no personal script. Research R13, rule row R9.
- Spec edge case (branch): a `directory` marketplace on a branch other than `main` gets a warning
  at the gate that names the branch. Research R16, case U20, rule row R4.
- No open decisions.

## Project Structure

### Documentation (this feature)

```text
specs/012-st-update/
├── spec.md
├── decisions.md
├── plan.md
├── research.md          # R1 to R16
├── data-model.md        # checkout, record, marketplace, item, row, states
├── quickstart.md        # tests, negative controls, live run
├── contracts/
│   └── st-update.md     # script subcommands, skill steps, test cases, drift test
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
skills/
└── st-update/SKILL.md      # new: audit, table, gate, plugin, ask, fix, commit, report
scripts/
└── st-update.sh            # new: items, audit, plugin, fix
tests/
├── test_st_update.sh       # new: U1 to U21
├── test_update_rules.sh    # new: skill phrases
└── test_update_items.sh    # new: FR-020 drift test with built-in negative control
README.md                   # skills row, first-time command, tests block
DESIGN.md                   # D9 row and count, D13a commit-mode row and rule
.claude-plugin/plugin.json  # 0.7.0
```

**Structure Decision**: Stratum's own layout. The script follows `scripts/st-worker.sh`
(subcommands) and `statusline/st-statusline.sh` (python3 for JSON). The tests follow
`tests/test_st_worker.sh` (stub on `PATH`) and `tests/test_plan_rules.sh` (phrase rows).

## Complexity Tracking

Empty.
