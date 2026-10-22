# Implementation Plan: Open a herdr Workspace From a Layout Template

**Branch**: `003-session-mods` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/007-herdr-workspace/spec.md`, decisions D1 to D11 in
[decisions.md](decisions.md), GitHub issue #32, the user's `~/.config/herdr/templates.sh`.

## Summary

`scripts/st-herdr-workspace.sh <folder> --label <name> [--machine <m>] [--template full|basic] [--agent claude|claude2]`
checks the input, the machine and the folder, then makes one new herdr workspace with the `full`
or `basic` layout, gives `--cwd` on every create and split, starts the agent and `lazygit` in
`Main`, puts the workspace in front and prints a TAB-separated report read back from herdr (D2).
For a remote machine every herdr call has `--machine <m>` and the folder and git checks run over
`ssh` to the `target` from herdr's saved profile (D5). `skills/st-herdr-workspace/SKILL.md` parses
the request, picks the label, runs the script and shows the report. `tests/test_herdr_workspace.sh`
proves the call sequence with stub `herdr`, `ssh` and `sleep` on `PATH`, plus negative controls.

## Technical Context

**Language/Version**: Bash 5.3.20 (script, test), Markdown (skill, docs)

**Primary Dependencies**: herdr 0.9.4 CLI, jq 1.8.2, OpenSSH 10.6p1 (remote only), git 2.56.0. No new package. jq is new to this repo's runtime, so README's tool table gets a row.

**Storage**: N/A. Changes only herdr state.

**Testing**: `bash tests/test_herdr_workspace.sh` (new), `bash tests/test_on_demand.sh` (phrase rows), `bash tests/test_inspect.sh` (README checks), `bash scripts/st-verify.sh` (no added comments)

**Target Platform**: Linux and macOS shells with herdr 0.9.4. Local runs inside a herdr pane (D8).

**Project Type**: Claude Code plugin (skill, script, docs)

**Performance Goals**: none beyond D7's short wait: 10 s total for the running check (research R5).

**Constraints**: Minimal code, no abstractions, bash and jq only, no comments except `ponytail:` markers. Never: bare `herdr`, `close`, `reconnect`, `machine add|remove|enable|disable`, `server` (FR-011).

**Scale/Scope**: 1 script, 1 skill, 1 test file. Edits: `tests/test_on_demand.sh`, `README.md`, `DESIGN.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` (base repo). The gates come from the rules the
orchestrator passed and `docs/lessons.md`.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that fails before its build task | Pass: T001 before T002 (FR-001 to FR-003, FR-005 to FR-012 local), T003 before T004 (FR-009, FR-011, FR-013 skill text), T005 before T006 (FR-004 to FR-006 remote), T008 before T009 (FR-002 basic). FR-014 is the test file itself, proven by its negative controls |
| G2. Minimal diff, no new dependency, no comments | Pass: one script, one skill, one test. `st-verify.sh` in T010 |
| G3. lessons L1: a text check asserts a phrase the code builds | Pass: messages and phrases in contracts/script.md section 2 and contracts/skill.md section 2 are built by the script or skill, not the input. D20 replaces D7's `wait-output --match claude`, which would pass on the shell's echo of the typed command (research R5) |
| G4. lessons L2: each guard has a negative control that goes red | Pass: NC1 (drop `--cwd` on one split), NC2 (drop `--machine`), NC3 (env pane id as a target), NC4 (escape `~`) run inside the test. Each first checks its broken copy differs from the script |
| G5. lessons L5: the plan matches the tool's real schema | Pass: argv and JSON fields from live herdr 0.9.4 usage and `pane list` output (research R1). `machine status` is not used because its success value is unknown (R2) |
| G6. lessons L6: tasks that share one test file are not parallel | Pass: T001, T002, T005, T006, T008, T009 share `tests/test_herdr_workspace.sh` and run in order. T003 (`tests/test_on_demand.sh` only) is the one `[P]` task |
| G7. lessons L7: README lists are checked both ways | Pass: `tests/test_inspect.sh` already diffs skills against README rows both ways and needs every `tests/test_*` in README. T001 and T004 add those rows |
| G8. lessons L8: test runs leave no file in the repo | Pass: stubs, logs and git repos live in `mktemp -d`, removed by `trap`. T010 checks `git status --porcelain` |
| G9. lessons L17: a conditional task skipped says why | Pass: T007 (remote live run) gets `Not run, <herdr error>.` if the laptop still does not answer |
| G10. Settled decisions D1 to D11 kept (D11 is for the next feature; it needs nothing here beyond the `workspace` line naming the machine) | Pass: D20 replaces D7's method (`pane wait-output`) with `pane process-info` polling; D7's outcome (short wait, `running` or `not seen`, never fatal) is kept |

Post-design re-check: all gates pass. Complexity Tracking stays empty.

## Open decisions

None. D20 (decisions.md) settled the running check: poll `herdr pane process-info --pane <id>`
until a foreground process `name` is `claude` (for `claude` and `claude2`) or `lazygit`, up to
10 s (research R5).

## Security Notes

- **S1. User text into argv (T002, T006).** The folder and label come from the user's request
  through the skill. The label must match `^[A-Za-z0-9][A-Za-z0-9._-]*$`, so it cannot start
  with `-`. The folder never reaches herdr as typed: herdr gets the absolute path `D` that the
  target probe printed, which starts with `/`. Every value is one quoted argument; no `eval`.
- **S2. External service: ssh to the saved machine (T006).** The ssh target comes only from the
  `target` field of `herdr machine list --json` for a matched label or id, never from the
  request. `ssh -o BatchMode=yes -- <target> <probe>`: no password prompt, no option injection.
  The folder goes into the remote shell line through `printf %q` with only a leading `~` left
  unescaped (research R3). The probe reads (`cd`, `pwd`, `git status`) and writes nothing;
  `--no-optional-locks` stops the index refresh. No credential is read, stored or printed.
- **S3. herdr session control (T002, T006).** The script runs only the calls in
  contracts/script.md section 4 plus `machine list --json` and `workspace list`. The test fails on
  bare `herdr`, any `close`, `reconnect`, `machine add|remove|enable|disable`, `server`,
  `--current`, `--session`, `--remote`. Local runs need `HERDR_ENV=1`, as `herdr --skill` demands.
- **S4. Remote ids (T006).** The script never reads `HERDR_PANE_ID`, `HERDR_TAB_ID` or
  `HERDR_WORKSPACE_ID`. The test sets them to known values and fails if they appear in any call
  (FR-005).
- **S5. A failed remote call can still have acted** (`herdr --skill`). The script stops, closes
  nothing and prints what it knows. The skill says not to run it again after a failure.
- No access rules, sign-in, data model, contracts of other features, secrets, or personal data.
  `claude` starts with the user's own settings (spec Assumption).

## Blocker

- **B1. Remote live run (US2, SC-002) cannot run now.** `herdr machine status laptop --json` gives
  `"status":"error"` with `ssh: connect to host 100.73.64.64 port 22: Connection timed out`, and
  `herdr --machine laptop workspace list` exits 1 with the same cause. The remote path is proven
  by the stub test (T005). The live check is T007, run only when the laptop answers. Also not
  verified until then: `pane process-info` over `--machine`, the `claude2` alias on the laptop,
  and the laptop's login shell reading `printf %q` output.

## ponytail notes

- `ponytail:` the 10 s running-check bound is a constant, not an option. Raise it if quickstart
  section 2 measures a slower `claude` start.
- `ponytail:` `printf %q` quoting assumes a bash or zsh login shell on the target. A fish shell
  needs a different quote.
- `ponytail:` ahead and behind are against the last fetch; no `git fetch` (research R4).

## Breaking Changes

None. New files only, plus one row each in README and DESIGN tables and one test line.
Rollback: revert the feature's commits.

## Project Structure

### Documentation (this feature)

```text
specs/007-herdr-workspace/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
├── contracts/
│   ├── script.md        # usage, pre-checks, calls, report
│   └── skill.md         # skill text, phrase table
└── tasks.md
```

### Source Code (repository root)

```text
scripts/st-herdr-workspace.sh        # new (US1, US2, US3)
skills/st-herdr-workspace/SKILL.md   # new (US1)
tests/test_herdr_workspace.sh        # new (US1, US2, US3)
tests/test_on_demand.sh              # phrase rows (US1)
README.md                            # skill row, tool row, test line
DESIGN.md                            # skill row, count 22 -> 23
```

**Structure Decision**: same layout as `st-worktree.sh` and `st-verify.sh` (scripts) and
`st-triage` (skill). No new folder besides the skill's.

## Complexity Tracking

Empty. No violations.
