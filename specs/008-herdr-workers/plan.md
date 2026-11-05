# Implementation Plan: Orchestrator Starts Worker Sessions

**Branch**: `003-session-mods` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/008-herdr-workers/spec.md`, decisions D11 to D26 in
[decisions.md](decisions.md), GitHub issues #11 and #17, spike #9
(`specs/003-session-mods/research.md`), #32 (`specs/007-herdr-workspace`).

**Amended 2026-11-05 for issue #71** (D31 to D35, spec FR-001, FR-010, FR-015, FR-018): a pane
worker is one tab labelled `worker-<id>` in the orchestrator's workspace (on a saved machine, in the
workspace that has the main checkout open), with the agent pane and lazygit side by side. The
worktree comes from `git worktree add`. Research R17 holds the facts; tasks T019 to T023 the work.

## Summary

One script, `scripts/st-worker.sh`, with eight subcommands: `start` (`git worktree add` makes the
worktree from the main checkout, `herdr tab create` opens one tab labelled `worker-<id>` in the
orchestrator's workspace (#71), the script writes `brief.md`, starts `claude` in auto mode in the
tab's pane with lazygit beside it and sends the one `/goal` prompt), `goal`, `wait`, `answer`,
`result`, `close` (closes that tab), `list` and
`headless`. Every herdr call goes through `herdr --machine <m>` for a saved machine; the brief and
result cross by ssh to the `target` in herdr's profile. herdr is the only store: every subcommand
finds its worker again from the task id (`worker-<id>`, the tab label), so a new orchestrator
session takes over (FR-016). One thin skill, `skills/st-worker/SKILL.md`, turns the request into script calls,
answers small worker questions itself and brings big ones to the user (D26), runs `st-review` per branch, merges in task order and closes. One stub test,
`tests/test_st_worker.sh`, proves every call, the brief, the prompt, the wait, the result read and
the close on both machines, with negative controls (SC-007).

## Technical Context

**Language/Version**: Bash 5.3.20 (script, test), Markdown (skill, docs)

**Primary Dependencies**: herdr 0.9.4 CLI, Claude Code 2.1.302 (`/goal`, `--permission-mode auto`,
`dontAsk`, `--permission-prompts`), jq 1.8.2, OpenSSH 10.6p1 (saved machine only), git 2.56.0,
coreutils `timeout`. No new package. README's `herdr` 0.9.4, `jq` row widens to name `st-worker`; ssh is needed only for a saved machine, as in #32.

**Storage**: N/A. herdr holds worker state; git holds the work. Two files per worker in its
worktree: `brief.md` (orchestrator) and `result.md` (worker).

**Testing**: `bash tests/test_st_worker.sh` (new), `bash tests/test_on_demand.sh` (skill phrases),
`bash tests/test_inspect.sh` (README rows), `bash scripts/st-verify.sh` (no added comments)

**Target Platform**: Linux and macOS shells with herdr 0.9.4, run from a herdr pane.

**Project Type**: Claude Code plugin (skill, script, docs)

**Performance Goals**: each script call returns within 600 s (the Bash tool's foreground cap):
`wait` 540 s, `headless` 540 s (research R6, R12).

**Constraints**: bash and jq only, minimal code, no abstractions, no comments except `ponytail:`
markers. Never: bare `herdr`, `pane close`, herdr `worktree remove`, `--group`, `machine reconnect`,
`machine add|remove|enable|disable`, `server`, `--trust-repository`, a push. `git worktree remove`
and `git branch -D` run only in `start`, only on the folder and branch that run just made, when
`tab create` failed (D33, S3). The skill's rule "never remove a worktree folder"
(`skills/st-worker/SKILL.md:54`) is the orchestrator's rule for finished workers and still holds.

**Scale/Scope**: 1 script, 1 skill, 1 test file. Edits: `tests/test_on_demand.sh`, `README.md`,
`DESIGN.md`, `skills/st-status/SKILL.md`, `hooks/st-models.py`, `skills/st-model/SKILL.md`,
`tests/test_model_hook.py`, `tests/test_model_files.sh` (D27, D28). #71 edits:
`scripts/st-worker.sh`, `tests/test_st_worker.sh`, `tests/test_worker_rules.sh` (W14),
`skills/st-worker/SKILL.md` (line 18).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` (base repo). The gates come from the rules the
orchestrator passed, the settled decisions and `docs/lessons.md`.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that fails before its build task | Pass in the design: contracts/script.md section 6 maps every FR to a stub case, contracts/skill.md section 2 to a phrase row. tasks.md puts each test task before its build task |
| G2. Minimal: one script, one skill, one test, no new dependency, no comments | Pass. herdr is the store, no state file (research R10) |
| G3. lessons L1: a text check asserts a phrase the code builds | Pass: every line in contracts/script.md section 2 and every output word in section 5 is built by the script. The pane text and result file hold random markers the input does not hold |
| G4. lessons L2, L25: each guard has a negative control that goes red, with a green baseline right before it | Pass: NC1 to NC7 (contracts/script.md section 6), each after a baseline run on the same state |
| G5. lessons L5: the plan matches the tool's real schema | Pass: JSON paths from `herdr api schema --json` and live read-only calls (research R1); `claude -p` JSON keys from spike test 3. Not live-verified items are listed in research and measured in quickstart sections 2, 3, 5. Corrected by the live runs: `agent read` prints plain text, not the schema's JSON (research R1) |
| G6. lessons L6: tasks that share one test file are not parallel | Pass in the design: every script task shares `tests/test_st_worker.sh` and runs in order; only the skill task (`tests/test_on_demand.sh`) can be `[P]` |
| G7. lessons L7: README lists are checked both ways | Pass: the skill row and the test line go into README in the same task as the file they name (`tests/test_inspect.sh` checks both ways) |
| G8. lessons L8: test runs leave no file in the repo | Pass: stubs, repos and briefs in `mktemp -d`, removed by `trap`; the headless brief is outside the repo (H5) |
| G9. lessons L10: the guard that stops a write is named and controlled | Pass: the `HEAD` compare before and after is the main guard against a headless commit (H2, H3b; research R12). The tool list (`--tools`, `--allowedTools`, `dontAsk`) narrows the worker but does not stop a commit; NC6 removes it. Close is guarded by the label match (C4) |
| G10. lessons L11: each background action has its failure states | Pass: start that cannot start (S4), a worker that already exists (S6), start blocked (S3, S7), prompt stalled (S5), wait with no end (W2), wait with no output (W4), result missing (G2), close of a worker still at work (C2), close that leaves something (C3), close of a worker whose agent is gone (C5), a tab that cannot open (S13, S13b, R16; S9 is gone since #71), a pane busy for good (S11b), ssh down on start, result and wait (R1c, R2b, R3b) |
| G11. lessons L12: a lane runs through the Skill tool | Pass: the brief says "Start it with the Skill tool"; the skill runs `st-review` with the Skill tool |
| G12. lessons L24: a gated task that does not run says why | Pass in the design: the remote live run (quickstart section 6) gets `Not run, <herdr error>.` while the laptop is down |
| G13. lessons L26: stub ids have a random part; expectations come from the stub log | Pass: contracts/script.md section 6 |
| G14. lessons L27: a report line only after its call succeeded | Pass: contracts/script.md section 5, S4 asserts `-` ids on a stop |
| G15. lessons L28: "started" comes from herdr, not from echoed text | Pass: started means `agent start` exited 0, which herdr gives only after it detected `claude` ready (`herdr --skill`) |
| G16. Settled decisions kept | Pass: D12 two paths, D13 file result (the prompt is sent with `--wait`; the long wait is `agent wait`, D14, because one call must end under 600 s), D14 one question path, D15 one worktree per worker (made by `git worktree add` since #71, D33), D16 roster and rules, D17 one skill with st-build unchanged, D18 close keeps folder and branch, D19 headless allow list, D21 one `/goal` prompt pointing at `brief.md`, D26 the orchestrator answers small questions itself and brings big ones to the user |
| G17. Decisions D24 and D25 kept | Pass: S1 and R1 assert the worktree's `git-guard.json` and NC7 removes its write (D24); team rule 2 and the skill's machine rule keep commits on one machine (D25) |
| G18. lessons L9: lines other branches edit are diffed against main | Pass: the README skill table, tool row and `## Tests` list and the DESIGN.md skill count are also edited on other branches; T016 merges a moved `main` first and keeps main's lines plus ours |
| G19. lessons L13: a guard added by review updates every plan file | Pass: when a review adds a guard to `scripts/st-worker.sh`, the same commit updates contracts/script.md, research.md, data-model.md, quickstart.md and plan.md S1 to S6 |
| G20. D28 kept: the model hook accepts the `st-worker` key | Pass: `hooks/st-models.py` accepts `st-worker` beside the names from `agents/*.md`, so an `st-worker` entry in `.stratum/models.json` does not deny agent starts; `tests/test_model_hook.py` covers it (T017, T018) |

| G21. #71 decisions D31 to D35 kept | Pass in the design: contracts/script.md section 4 (tab per worker, `git worktree add`, undo on a failed tab, find by tab label, `tab close` and the `st-workers` rule of D35), section 6 cases S13, S13b, C13 to C18, R15, R15b, R16, NC8, NC9; tasks T019 to T023 |
| G22. lessons L5 for #71: the plan matches herdr's real schema | Pass: research R17, read-only calls and `herdr api schema --json` on 2026-11-05. Not known: whether herdr closes a workspace with its last tab (#4379); `close` works either way (C15). Measured live in T023 |

Post-design re-check: G1 to G22 pass. Complexity
Tracking stays empty.

## Open decisions

None. #71 is settled by D31 to D35. D35 (user, 2026-11-05) settles the plan finding F1: a new
workspace always has a first tab, so the D34 last-tab rule never closed a workspace `start` made.
Now `start` on a saved machine uses the main checkout's workspace, else an open `st-workers`
workspace, else makes one labelled `st-workers`; `close` closes only an `st-workers` workspace with
no `worker-*` tab left. The older two are settled in decisions.md:

- D24: `start` writes `{"commit":"auto"}` to `.stratum/git-guard.json` in the worker's worktree
  only (git-ignored, `.gitignore:8`). Plain commits pass with no human step; amend, push,
  `reset --hard` and branch delete still ask (`hooks/st-git-guard.py:155-160`). A commit aimed at
  another checkout (`-C`, `--git-dir`, `--work-tree`, a `GIT_DIR=`/`GIT_WORK_TREE=` prefix, a
  `cd` or `pushd` segment) asks, and so do merge, pull, cherry-pick, revert and am there. `close`
  removes the guard file (D30). Only another git toplevel counts as elsewhere for `-C`, `cd`, `pushd`; the file also holds `"branch": "worker-<id>"` and a commit or in-folder merge off that branch asks (decisions.md D24 lists the rest). Open gap: `env GIT_DIR=X git ...` and `export GIT_DIR`. The orchestrator's
  review and merge stay the gate.
- D25: tasks that build on each other run on one machine, where every teammate's branch is in the
  shared repo. Teammates on different machines only exchange messages; no commit crosses
  machines. No `bring` subcommand, nothing pushed.

## Security Notes

- **S1. User text into argv and into the brief (start, goal, answer, headless).** The task text
  comes from a file and goes only into `brief.md`, never into argv or a shell line. The test
  command must be one line with no `(` or `)` (it sits inside `Bash(...)` for headless and inside
  the `/goal` text); the lane is one line; the id matches `^[A-Za-z0-9][A-Za-z0-9-]{0,24}$`, so no
  id starts with `-`; the model, from `--model` or models.json, matches `^[A-Za-z0-9][A-Za-z0-9._-]*$`,
  so no value after `--model` starts with `-` (M4, M4d); an `answer` value that starts with `-` is
  refused (A4). Every value is one quoted argument; no `eval`, no `bash -c` on user text.
  One exception (#71): `start` runs `git -C <repo> worktree add -b <N> <path> <sha>`, and on a
  failed tab `git worktree remove` and `git branch -D`, through `rx`, whose local branch is
  `bash -c` (the same string goes over ssh on a saved machine). Its values are the repo path, the
  worker name (from the regex-checked id), the path built from them and a sha from `git rev-parse`,
  each `printf %q` quoted; no task text, test command, lane or answer reaches that string.
  The `/goal` text is capped at 4,000 characters.
- **S2. External service: ssh to the saved machine (start, wait, result).** The target comes only
  from the `target` field of `herdr machine list --json` for a matched label or id.
  `ssh -o BatchMode=yes -- <target> ...`: no password prompt, no option injection. Remote paths
  are `printf %q` of the path (since #71 the `--repo` based path, `~` kept unquoted as in #32).
  Since #71 `start` also sends `git -C <repo> worktree add -b <N> <path> <sha>` and, on a failed tab,
  the undo of S7. What crosses: the brief (task text, test
  command, roster, rules) to the laptop, the result file and the branch back. No credential is
  read, stored or printed. `git fetch <target>:<path> N:N` writes only `refs/heads/N` here and
  refuses a non-fast-forward.
- **S3. herdr session control (start, close; #71, D34, D35, FR-018).** Only the calls in
  contracts/script.md section 4, plus `machine list --json`. The script reads one `HERDR_*_ID` value,
  `HERDR_WORKSPACE_ID`, only in a local `start`, for the row 7 check and to open the worker tab there; it never reads
  `HERDR_TAB_ID` or `HERDR_PANE_ID` and never passes `--current`. On a saved machine it never uses
  this machine's ids (herdr ids are valid on one server only). `tab close` runs only on the one tab
  labelled with the script's own `worker-` name, at most once. `workspace close` runs only on a
  saved machine, only on that tab's workspace, at most once, never with `--group`, and only when
  that workspace is labelled `st-workers` and no tab labelled `worker-*` is left in it after the
  `tab close`. `workspace create` runs only on a saved machine with no open main checkout and no
  open `st-workers` workspace, and always labels it `st-workers`. So the orchestrator's own tab and
  workspace, and any workspace not labelled `st-workers`, are never closed (tests C1, C17, C18, R9,
  NC8). The `st-workers` label is reserved for the script: an `st-workers` workspace the user made
  by hand counts as the script's and is closed once no worker tab is left in it (D35, D36).
  `close` refuses a `working` or
  `blocked` worker. Never `pane close`, herdr `worktree remove`, `machine reconnect`, `server stop`,
  `--trust-repository`. Local runs need `HERDR_ENV=1`. A failed remote call may still have acted:
  the script stops, closes nothing, and the skill runs `list` instead of a retry (S5 of #32).
- **S7. Undo of a failed tab (start; data on disk; D33).** When `tab create` fails, `start` runs
  `git -C <repo> worktree remove <path>` (no `--force`) and `git -C <repo> branch -D <N>`, here or
  over ssh. Both target only the folder and branch that `git worktree add -b <N>` made in the same
  run, before any agent ran or any file was written there, so no commit or user file can be lost:
  `-b` fails when the branch already exists, and `worktree remove` without `--force` refuses a
  folder with changes. If the undo fails, the stop line names what was left (test S13b). Over ssh
  every value is `printf %q` quoted (S2).
- **S4. Worker permissions (start; access rule).** A pane worker is the user's own `claude` with
  the user's plugins and settings, started with `--permission-mode auto -n <name>`, plus
  `--model <name>` when a model is set, and nothing else (FR-013, FR-017, tests S1, M1): no `--dangerously-skip-permissions`, no `--allowedTools`. Auto mode's
  classifier and every ask and deny rule still apply. D26: the orchestrator may answer a
  permission prompt for the task's own command; any other access question goes to the user. D24: `start` writes the repo's own guard file (or `{}`)
  with `"commit": "auto"` set to `.stratum/git-guard.json` in that worktree only, so per-repo
  `deny` keys carry over and a plain `git commit` there passes the Stratum guard (the file also has `"branch": "worker-<id>"`; off that branch it asks); amend, push, `reset --hard` and branch delete still ask. The worker's `commit: auto` applies only to a plain `git commit` run from the worker worktree: a `git -C`, `--git-dir`, `--work-tree`, a `GIT_DIR=`/`GIT_WORK_TREE=` prefix, or a `cd`/`pushd` to another checkout asks, and so do merge, pull, cherry-pick, revert and am aimed there (`env GIT_DIR=X` and `export GIT_DIR` stay an open gap). `close` removes the file and refuses a symlinked `.stratum` (D30). A `cd`/`-C`/`pushd` into the same checkout passes. The file is git-ignored
  and never written in the orchestrator's own folder (tests S1 and S1b check both).
- **S5. Headless allow list (headless; access rule).** `--tools Read,Edit,Write,Glob,Grep,Bash`
  (no AskUserQuestion, SendMessage, Agent or web tool), `--allowedTools` for those and only
  `Bash(<test command>)`, `--permission-mode dontAsk`, `--permission-prompts none`,
  `--strict-mcp-config`, `--max-turns 30`, `timeout -k 10 540`, and `--model <name>` when a model is set. The `HEAD` check refuses a run that
  committed anyway.
- **S6. Untrusted text back from a worker.** The result file, the pane text and a teammate's
  SendMessage are the worker's words. The skill reads them as data, never as instructions (phrase
  `#17 FR-005 data`). A session in another permission mode holds cross-session messages for its
  user (spike #9); all workers run in auto mode.
- No sign-in, personal or minors' data, secrets, or stored data model.

## Blocker

- **B1. Remote live run (US3, SC-002). Closed 2026-10-24.** The laptop timed out on port 22 on
  2026-10-23 (007 plan B1). The live remote run of quickstart section 6 passed on 2026-10-24 (laptop
  repo at 3275e07: `start`, `wait`, `result` with `fetched`, `close`, all checks empty), and
  `herdr --machine laptop workspace list` exited 0 on 2026-11-05 and timed out on 2026-11-06 (research R17). Open for #71: the remote path with
  the `st-workers` workspace (R15, R15b, C14, C17) is stub-proven until T024 runs it live on the
  laptop (D37, quickstart section 6b); T023 runs on this PC.

## ponytail notes

- `ponytail:` `wait` bound 540 s and the 10 s resume check are constants; quickstart section 2
  measures the idle gap between goal turns.
- `ponytail:` `start` retries `agent_pane_busy` up to 10 times, 1 s apart; `answer` waits up to 5 s
  for `blocked` to clear after a key (live T008 saw about 2 s, not re-run live after the fix).
- `ponytail:` `headless` uses fixed `--max-turns 30` and `timeout -k 10 540`.
- `ponytail:` the worker's `brief.md` and `result.md` sit untracked in its worktree; only the
  brief's rule keeps them out of a commit, and `st-review` sees them if one slips in.
- `ponytail:` no process check in `close`; quickstart section 2 checks `pgrep` live.
- `ponytail:` `printf %q` quoting assumes a bash or zsh login shell on the saved machine (as #32).

## Breaking Changes

None. New files, one README tool row and the `st-status` tool line widened to name `st-worker`, one README skill row, one README
test line, one DESIGN row and its count (Twenty-three to Twenty-four), phrase rows in
`tests/test_on_demand.sh`. `skills/st-build/SKILL.md` does not change (FR-014). Rollback: revert
the feature's commits.

#71: field 4 of the `worker` and `found` lines changes from the workspace id to the tab id, the
`approval` `tab` line and the approvals record's third field change from `workspace <N>, tab Main`
to `tab <N>`, and workers started before #71 (a workspace of their own) are no longer found, listed
or closed by the script (spec Assumptions). Only the skill reads these lines. Rollback: revert the
#71 commits.

## Project Structure

### Documentation (this feature)

```text
specs/008-herdr-workers/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
├── contracts/
│   ├── script.md        # usage, checks, brief text, calls, output, test cases
│   └── skill.md         # skill text, phrase table
└── tasks.md
```

### Source Code (repository root)

```text
scripts/st-worker.sh            # new (US1 to US5)
skills/st-worker/SKILL.md       # new (US1, US2, US4, US5)
tests/test_st_worker.sh         # new (US1 to US5)
tests/test_on_demand.sh         # skill phrase rows, st-status tool row
skills/st-status/SKILL.md       # step 4 tool line names st-worker
README.md                       # skill row, tool row, test line
DESIGN.md                       # skill row, count 23 -> 24
docs/lessons.md                 # written at Close (st-close), not in Build
hooks/st-models.py              # accept the st-worker key (D28)
skills/st-model/SKILL.md        # list st-worker (D28)
tests/test_model_hook.py        # case: an st-worker entry does not deny an agent start (D28)
tests/test_model_files.sh       # check: st-model names st-worker (D28)
tests/test_worker_rules.sh      # #71: W14 pins the new skill line 18
```

**Structure Decision**: same layout as #32 (`scripts/st-herdr-workspace.sh`,
`skills/st-herdr-workspace/`, `tests/test_herdr_workspace.sh`). The machine checks are copied
from the #32 script with their words; that script does not change.

## Complexity Tracking

Empty. No violations.

## Validate

Date: 2026-11-06. Verdict: CONDITIONAL

Scope: the #71 amendment (spec commit 1316085, plan commit f3aa07a: D31 to D35, FR-001, FR-010,
FR-015, FR-018, SC-005, US1, US3, research R17, tasks T019 to T023). Replaces the 2026-10-23 section.

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | Here: herdr 0.9.4, Claude Code 2.1.316 (plan says 2.1.302 or later), jq 1.8.2, bash 5.3.20, git 2.56.0, OpenSSH 10.6p1. Every herdr call of contracts/script.md section 4 is in the 0.9.4 group usage: `tab create --workspace --cwd --label --no-focus`, `tab list [--workspace]`, `tab close`, `pane list --workspace`, `pane split <id> --direction right --cwd --no-focus`, `pane run`, `workspace create --cwd --label --no-focus`, `workspace close [--group]`, `worktree list --cwd`. `pane list` gives `tab_id` and `cwd` here and on the laptop. The laptop answers now: herdr 0.9.4, Claude Code 2.1.316, git 2.56.0, jq 1.8.2 (closes the old F17). No new dependency |
| 2. Test coverage per requirement | CONCERN | F1, F2. FR-001, FR-010, FR-015, FR-016, FR-018, SC-005, US1, US3: 8/8 have a task; 7/8 have a stub case that can fail (NC8, NC9 for the two new guards); SC-005 is live in T023, with C3 for a leftover agent in the stub. Runners exist and are green now with no file left: `bash tests/test_st_worker.sh`, `bash tests/test_worker_rules.sh`, `bash tests/test_on_demand.sh`, `bash tests/test_inspect.sh`. Only W14 in `tests/test_worker_rules.sh:23` pins skill line 18, and T020 owns it |
| 3. Breaking changes | PASS | Field 4 of `worker` and `found`, the `tab` line and the record's third field: the only readers are `tests/test_st_worker.sh:1027` (`recok`) and `:1111` (WA1), both in T019. The skill does not parse field 4; `hooks/st-approve.py` does not read the record's third field. No `worker-*` workspace is open on this PC or on the laptop (2026-11-06), so no pre-#71 worker is stranded (closes the spec Assumption "the laptop was not checked"). No stored data, no migration. Rollback: revert the #71 commits |
| 4. Security and privacy | CONCERN | F3, F4. No secrets, sign-in, personal or minors' data. S2, S3, S7 have checks: `never()`, P7b, C13 to C18, R9, R16, S13, S13b, NC8, NC9 |

F1. tasks.md:259, plan.md:186-188, research.md R17 "Not known" The laptop answers today, but no #71 task runs the remote path live. Only a saved machine uses `workspace create --label st-workers`, `workspace close` (D35, destructive) and `tab create --cwd ~/...`/`pane split --cwd ~/...`, and R17 lists `~` expansion there and herdr #4379 as not known -> add T024: a live remote run (quickstart section 6b, mirror of 2b with `--machine laptop --repo '~/Desktop/stratum'`, no main checkout open so the `st-workers` path runs), recording `workspace list` and `tab list` on the laptop before `start`, after `start` and after `close`. Close plan B1 in the same task.
F2. tests/test_st_worker.sh:532, :560, :579; tasks.md:238 C3, C8 and C11 assert `hascall "workspace\tclose\t%s" "$(wsid)"`. T019 names C3 and C8 only for the `close left tab` wording and does not name C11. These stay green on the old script and go red after T021, and T021 owns only `scripts/st-worker.sh` -> in T019, add: C3, C8, C11 assert one `tab close` on the worker's tab and zero `workspace close`.
F3. decisions.md:27, research.md R17 (Finding), contracts/script.md `close` paragraph vs plan.md:148-149 D35, R17 and the contract say a workspace the user opened is never closed. Plan S3 says an `st-workers` workspace the user opened is closed once no `worker-*` tab is left, and R15b reuses it. Closing it ends every other tab and process in it -> user decision. O1: keep the reserved label and reword D35, R17, the contract and FR-018 to say a user-made `st-workers` workspace counts as the script's. O2: close only a workspace this `start` made (needs a record; herdr is the only store, research R10). Recommended: O1.
F4. scripts/st-worker.sh:336, tasks.md:251 item 3, plan.md:126 T021 moves `rx` (local branch `bash -c "$1"`) into `start` for `git worktree add`, `worktree remove` and `branch -D`. Plan S1 says no `bash -c` on user text. Values are `printf %q` quoted and the id is regex-checked, so it is safe, but the rule and the build disagree -> in T021, call git directly here and keep `rx` for ssh only, or name the exception in S1.
