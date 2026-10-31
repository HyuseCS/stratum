# Implementation Plan: Workflow Overhaul

**Branch**: `010-workflow-overhaul` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-workflow-overhaul/spec.md`, decisions D1 to D29 in
`decisions.md`.

## Summary

Six changes to the Stratum plugin, each with tests in `tests/` (FR-031):

1. Fewer advisor runs (US1): a `REVISE` with only MEDIUM and LOW findings passes, Inspect can
   waive a fix-only plan change (`st-advisor.sh waive`), the end-of-Build pass runs only on
   changes after the last review (`st-advisor.sh diff`), and Build ends with a call count
   (`st-advisor.sh count`, `note`). One test rule for every agent: the tests of the changed files
   and their importers, never the full suite unless the user asks.
2. No stops on Stratum's own prompts (US2): the git guard reads a command it cannot split line by
   line, and a new `scripts/st-lock.sh` makes tests that cannot run at the same time take turns.
3. Advisors for the risk (US3): a risk level with the lane, an advisor matrix in `st-advisor.sh`
   (mode `auto`), Codex as a herdr agent in a `Codex` tab (`scripts/st-codex-agent.sh`), and a
   talk of at most 3 rounds at High points (`round`, `talk`).
4. Autonomous build with workers (US4): Build can send `[P]` tasks to `st-worker`; workers get the
   full layout; in autonomous mode a `PermissionRequest` hook (`hooks/st-approve.py`) sends a
   worker's prompt to the orchestrator, which approves small, safe ones one time with
   `st-worker.sh approve` and passes the rest to the user with `pass`. A commit of the task's own
   files on the worker's own branch counts as small and safe (D23). The status line shows the mode.
5. Lanes (US5): the planner marks `[P]` with owned files, `[lock]` and `[screen: <mode>]`; Build
   sends new screens to the Design lane.
6. Skill clean-up (US6): `/stratum:st` triages named issues first, the Plan gate no longer offers
   issues, and `st-frontend-design` is removed.

Research R-A shows the `PermissionRequest` hook can wait 75 s and answer `allow` in a worker
running `--permission-mode auto`. FR-019 has no fallback to permissions the user grants (D29):
if the plugin hook does not fire, `start --autonomous` loads the same hook with `--settings`
after the user OKs it; if that fails too, autonomous mode stays off and every prompt goes to the
user.

## Technical Context

**Language/Version**: Bash 5 (scripts, shell tests), Python 3 stdlib (hooks, the advisor
validator, Python tests), Markdown (skills, agents, procedures, templates).

**Primary Dependencies**: `herdr` 0.9.4, `codex-cli` 0.166.0, Claude Code 2.1.312, `jq`, `git`.
All already required by Stratum (README requirements table). No new dependency.

**Storage**: files only (data-model.md).

**Testing**: `bash tests/<name>.sh` with stand-ins on PATH for `herdr`, `codex`, `timeout`, `ssh`
(the style of `tests/test_advisor.sh` and `tests/test_st_worker.sh`), and
`PYTHONDONTWRITEBYTECODE=1 python3 tests/<name>.py` for hooks (L8). Live runs in herdr for each
new herdr or claude call (L32).

**Target Platform**: Linux and macOS for every script. Git Bash on Windows for `st-lock.sh`
(FR-009), not verified on a Windows machine (research R-D).

**Project Type**: Claude Code plugin (skills, agents, hooks, scripts).

**Performance Goals**: a lock wait ends by its limit (default 600 s, SC-004). A herdr Codex review
ends under the Bash tool's 600 s cap: `st-codex-agent.sh` keeps agent start and review under
480 s, inside a 540 s `timeout` that starts before the 50 s lock wait (contracts/scripts.md 1.5).

**Constraints**: built code adds no explanatory comments, only `ponytail:` markers. Every task
names its exact test command. No step runs the whole of `tests/`.

**Scale/Scope**: 8 scripts and hooks, about 20 Markdown files, 15 new and 5 changed test files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.stratum/constitution.md` does not exist in this repo (it is the Stratum plugin itself), so the
gates are the lessons in `docs/lessons.md` that apply. All pass at plan time. Re-checked after
Phase 1: pass.

| Gate | Rule | How this plan meets it |
|------|------|------------------------|
| lessons L1 | a text check asserts a phrase the code builds | every phrase test reads `contracts/phrases.md`; each row is new text |
| lessons L2, L20 | each guard has a test red on the old code | T047 runs every new test against the tree at `6fe9d60`; T013 runs the guard tests against `git show 6fe9d60:hooks/st-git-guard.py` |
| lessons L3 | hooks read stdin and files as bytes | `hooks/st-approve.py` (contracts/scripts.md section 5), T024 |
| lessons L5 | check plan inputs against the real schema | the `PermissionRequest` input has no `tool_use_id` (research R-A); the hook makes its own id |
| lessons L6 | two `[P]` tasks never share one test file | one test file per build task in each phase (tasks.md); `tests/test_on_demand.sh` has one owner per phase |
| lessons L7 | a check between two lists reads both sides | T042 keeps the README skill check two ways after the removal; two README tasks (T008, T046) add the new tests, timed so `tests/test_inspect.sh` is green each time it runs |
| lessons L8 | test runs do not write into the repo | Python tests run with `PYTHONDONTWRITEBYTECODE=1` |
| lessons L11 | a background action lists its failure states | Design lane in Build: cannot start (DL12), ends with no report (DL14), screen still open while others run (DL11) |
| lessons L12 | a phase starts through the Skill tool | `/stratum:st-design` and `/stratum:st-triage` are started with the Skill tool (DL11, TP1) |
| lessons L14 | a prompt string change updates the contract and test together | the Codex prompt lines are in contracts/scripts.md sections 1.3 and 2; T018 and T019 assert them |
| lessons L16, L17 | a hash step has one failing test per producer | `diff` point: a failing `git diff` and a failing `sha256sum`; `decisions`: an unreadable list (T002, T018) |
| lessons L18 | a commit line for a generated file says "if it changed" | the Inspect and Build lines that commit `advisor.md` keep "if it changed" |
| lessons L19 | work moved to the main session names its folder | `approve` and `pass` run in the main session and name the worker by id; the record file is in the orchestrator's scratchpad |
| lessons L25 | a negative control runs on a green baseline | T047 and T013 run the new code green first, then the old copy |
| lessons L26 | stub ids have a random part | herdr stand-ins in T019 and T027 |
| lessons L29 | worktree work uses the main checkout | the test lock lives in `git rev-parse --git-common-dir`, shared by all worktrees |
| lessons L30 | `agent start` retries `agent_pane_busy` | `st-codex-agent.sh` step 3 |
| lessons L31 | a herdr stub answers in the real CLI format | `agent read` stub prints plain text with the Codex wrap seen live (research R-C) |
| lessons L32 | each new herdr or claude call gets a live run | T050 (Codex home probe), T024 (Codex tab review), T034 (worker layout and approval) |
| lessons L33 | a review fix that adds `--` to a real CLI call is run once live | no new `--` except the documented agent-argument separator of `herdr agent start`, already used by `st-worker.sh:200` |
| lessons L34 | wait for `blocked` to clear after an answer | `approve` runs `agent wait --until working --timeout 5000` before it returns |
| lessons L37 | a brief rule change updates contract 008 section 3 and test S1 | T016 (B1), T031 (B2) |
| lessons L38 | a routing line states where in the sequence it comes | R1 keeps "Before the first lane skill or agent starts"; TP1 says "first" and "then pick the lane" |
| lessons L39 | a skill shows a script's output word for word | A11 (`count`), W7 (approvals file) |
| lessons L40 | a repeated check names its full scope | DL12 runs the screen again "from `/stratum:st-design` step 1" |
| lessons L41 | a mode-specific line names the mode | DL1, DL11 name the screen mode; W3 says "autonomous build mode only" |
| lessons L42 | an agent names the folder for files it keeps | approval record in the orchestrator's scratchpad (W3); lock folder in the git common dir |

## Security notes

These tasks touch access rules, an external service, or text that can hold secrets.

- **S1. Advisor default (FR-012, external service, D24).** "auto is the default when
  `.stratum/advisor.json` has no mode" means: a file with no `mode` key means `auto`. No file
  keeps today's `no advisor: mode not set` line, so nothing goes to OpenAI until the user writes
  the file. `st-init` recommends `auto`. Tasks T018, T022, T023.
- **S2. Codex in a herdr tab does not read the user's Codex config (FR-013, external service,
  D25).** The TUI has no `--ignore-user-config` (research R-C), so the tab runs with a
  Stratum-owned `CODEX_HOME` (`~/.local/state/stratum/codex-home`) that holds only a link to the
  user's Codex login. `~/.codex/config.toml`, `~/.codex/hooks.json` and a trusted project's
  `.codex/config.toml` do not load; the model comes from `.stratum/advisor.json`. The folder is
  made only by `st-advisor.sh codex-home`, when the user opts in to a Codex advisor. T050 proves
  it live before the adapter is built; if it fails, Codex runs in the background as today and the
  tab is not used. The sandbox stays `read-only` and approvals `never`. README says so (R17).
  Tasks T050, T018, T019, T021, T022, T023.
- **S3. Permission approvals (FR-019, access rules, D27).** The hook acts only in a folder with
  `.stratum/approve/`, which only `st-worker.sh start --autonomous` makes, and only while the
  main checkout's `.stratum/autonomous` (read through the git common dir) holds the same session
  id as the worktree's `.stratum/approve/session`. Normal mode, a stale folder and the time after
  "stop autonomous" give no output. On a saved machine (D28) `start --autonomous --machine` writes
  the session id into that machine's main checkout `.stratum/autonomous` over `rsh`, and
  `st-worker.sh autonomous-off` removes it on every machine in the roster at the end of the run
  or on "stop autonomous". The hook runs on that machine, so both locks work there the same way.
  A stale file from a crashed session matches no live session id. The never list is in the hook, so a
  wrong judgement by the orchestrator cannot approve a push, a path outside the worktree, a
  `.stratum` path, a secret file, a dependency or a network tool. A commit reaches the
  orchestrator only when D23 holds: own worktree, own branch (from `.stratum/git-guard.json`),
  only staged files listed in `.stratum/approve/owns` (the task's `Owns:`), no `--amend`, no
  `--no-verify`; the orchestrator checks the same rules again (W16). `approve` takes the full input text and
  refuses if it differs from the request, so the orchestrator's permission check sees what it
  approves; README says never to put `st-worker.sh` on an allow list (W15). The hook never answers `deny`
  and never sets a rule or mode: each approval is one time. Tasks T026, T027, T030, T031.
- **S4. Residual risk in S3 (D27).** In a worker session, a `PreToolUse` branch of the same hook
  denies any Bash command, Edit or Write that touches `.stratum/approve/` or
  `.stratum/autonomous` (after normalizing `.stratum/./approve` and `//`), and any Bash command
  that runs `st-worker.sh approve`, `pass` or `autonomous-off`. `approve`, `pass`,
  `autonomous-off` and `start --autonomous` read the flag from the main checkout through the git
  common dir, refuse inside a worker worktree, and `approve` and `pass` also need the worker's
  session file to match the flag. The brief forbids the writes too (B2), and the hook refuses to
  send any request that names `.stratum`. The checks are text matches: a worker that builds a
  path at run time, on purpose, to get past them is not stopped. README states that risk (W15).
- **S4b. Commits that never prompt (D23).** A worker commit on its own branch runs with no
  prompt, because `start` writes `commit: auto` for the worker branch
  (`scripts/st-worker.sh:176`). D23 covers only commits that do prompt (for example the guard's
  ask on a commit in an unsplittable command). Commits with no prompt are checked at the story
  review, as today. W15 says so.
- **S5. Prompt text can hold secrets (FR-019).** The request file stays in the worktree's
  untracked `.stratum/approve/`, the approval record in the orchestrator's scratchpad. Neither is
  committed. B2 forbids committing `.stratum/approve/`.
- **S6. Git guard fallback (FR-008, access rules).** The fallback finds git words after removing
  `\`, `'` and `"`, so `\git` and `g''it` still count. It judges git lines with the folder
  unknown, so a `git commit` there asks even in commit `auto` mode. It only removes asks for
  commands with no git word. Today's gap stays: git called from inside another program in a
  command that splits fine is not read (research R-F), and neither are forms that only the shell
  expands, such as `{git,push}`, `$'git'` or `GIT=git; $GIT push`. Today's guard misses the same
  forms.

## Project Structure

### Documentation (this feature)

```text
specs/010-workflow-overhaul/
├── spec.md, decisions.md
├── plan.md              # this file
├── research.md          # R-A to R-H
├── data-model.md        # files and record formats
├── contracts/
│   ├── scripts.md       # script, hook and status line interfaces
│   └── phrases.md       # exact skill and agent text and its tests
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
hooks/
├── commands.json          # + PermissionRequest and PreToolUse entries for st-approve.py (US4)
├── st-approve.py          # new (US4)
└── st-git-guard.py        # fallback for unsplittable commands (US2)
scripts/
├── st-advisor.sh          # waive, note, count, diff (US1); auto, matrix, decisions, round, talk, codex-home, herdr path (US3)
├── st-codex-agent.sh      # new (US3)
├── st-lock.sh             # new (US2)
└── st-worker.sh           # brief (US2, US4); --autonomous, layout, approve, pass, wait, answer, close (US4)
statusline/st-statusline.sh  # autonomous segment (US4)
skills/  st, st-build, st-inspect, st-plan, st-full, st-fast, st-init, st-sync, st-worker,
         st-herdr-workspace (text); st-frontend-design (removed)
agents/  st-build, st-debug, st-test, st-plan (text)
procedures/tasks.md, templates/tasks.md (text)
README.md, DESIGN.md, THIRD_PARTY_NOTICES.md, vendor.lock, licenses/ (US6, docs)
specs/008-herdr-workers/contracts/script.md (brief section 3, L37)
tests/
├── test_advisor_waive.sh, test_advisor_rules.sh, test_test_scope.sh      # US1, new
├── test_lock.sh, test_lock_rules.sh                                      # US2, new
├── test_advisor_matrix.sh, test_codex_agent.sh, test_risk_rules.sh       # US3, new
├── test_approve_hook.py, test_worker_rules.sh                            # US4, new
├── test_plan_rules.sh, test_screen_rules.sh                              # US5, new
├── test_triage_rules.sh, test_no_frontend_design.sh                      # US6, new
├── test_lane_steps.sh                                                    # FR-027, new
└── changed: test_git_guard.py, test_st_worker.sh, test_statusline.sh, test_advisor.sh, test_on_demand.sh
```

**Structure Decision**: no new folder. New scripts sit beside the ones they serve. Each new test
file pairs with one build task, so tasks in a phase can run at the same time (L6).

## Design choices

- **C1. One lock script, two uses.** `st-lock.sh` serves `[lock]` tests (FR-009) and one Codex
  review at a time per workspace (spec edge case), by `--name`. No second lock.
- **C2. The matrix lives in `st-advisor.sh`.** The orchestrator reads the `advisors:` line instead
  of carrying the table in its head, and the table is testable (FR-012). Modes `codex`, `both`,
  `off` keep today's output, so a project that set one sees no change.
- **C3. `st-codex-agent.sh` is a drop-in for `codex exec`.** It writes the same answer file, so
  the validator, records and BLOCKED rules stay as they are.
- **C4. New conversation per feature = new agent.** `/new` needs a second key for a dialog
  (research R-C). Closing the old `st-codex-*` tab also covers a tab the user closed.
- **C5. File channel for approvals.** The same channel works on a saved machine through the
  existing `rsh`, and every orchestrator answer is one visible Bash call (research R-B).
- **C6. Session id, not a reset hook, ends autonomous mode for a new session** (research R-E).
- **C7. Layout copied, not shared.** `st-worker.sh` copies the 10 layout calls of
  `st-herdr-workspace.sh:75-94` into its own `h`/`get` helpers. The two scripts share no helper
  file today (`scripts/common.sh` holds only path helpers), and a shared file for one block is an
  abstraction for one use.
- **C9. One hook file for both D27 locks.** `hooks/st-approve.py` handles `PreToolUse` (the
  write lock) and `PermissionRequest` (the channel) by `hook_event_name`, so the git guard is not
  touched for a non-git rule and Edit and Write are covered by the same code.
- **C10. The Codex home is a user-level folder** (research R-J), made only on the user's opt-in.
- **C8. FR-003's review points live in the conversation.** Build notes `git rev-parse HEAD` after
  each story's review fixes. `diff <base>` prints `no change since <base>: skip` when nothing
  changed. No new record type.

## FR-027: lane steps the new rules make out of date or wrong

Each row is fixed in this feature. `tests/test_lane_steps.sh` (T001) asserts, per row, that the
old text is gone or that the missing step is now there. Nothing bigger was found, so nothing
goes to the user.

| # | File:line (today) | Old step | Why it is wrong now | Fix (task) |
|---|-------------------|----------|---------------------|------------|
| 1 | skills/st-worker/SKILL.md:21 | "For a permission dialog, pick the one-time yes" | FR-017: never in normal mode | W1, W2 (T033) |
| 2 | skills/st-worker/SKILL.md:21 | "a tool permission for the task's own command" as a small decision | FR-017 | W1 (T033) |
| 3 | skills/st-worker/SKILL.md:39 | "The build loop (/stratum:st-build) does not use workers." | FR-020, D2 | W11 (T033) |
| 4 | skills/st-build/SKILL.md:36-41 | `[P]` only through subagents; "merge it into `main` yourself" | FR-020; FR-026 story parallelism; the merge target is the feature branch (skills/st/SKILL.md:66, skills/st-worker/SKILL.md:29) | W10 (T033), DL15, DL16 (T039) |
| 5 | skills/st-build/SKILL.md:58-61 | `/advisor` on the feature's full diff, always | FR-003, FR-004 | A8 to A11 (T006) |
| 6 | skills/st-build/SKILL.md:65 | "It runs at two points" | FR-012 matrix | R5, R6 (T022) |
| 7 | skills/st-build/SKILL.md:72 | "Then run the same point once more on the changed input." | FR-001 | A1 to A3 (T006) |
| 8 | skills/st-build/SKILL.md:74 | modes `codex`, `both`, `off` | FR-012 adds `auto` | R4 (T022) |
| 9 | skills/st-build/SKILL.md:75 | stale plan always runs Codex again | FR-002 waive | A7 (T006) |
| 10 | skills/st-build/SKILL.md:20-23 | no `[lock]`, no `[screen]` route | FR-010, FR-024 | L1, L3 (T015), DL11 to DL14 (T039) |
| 11 | skills/st-inspect/SKILL.md:33 | stale plan always runs Codex again | FR-002 | A5, A6 (T006) |
| 12 | skills/st-plan/SKILL.md:3, 36 | "then offer GitHub issues", "Make GitHub issues from the tasks?" | FR-029 | TP3 (T043) |
| 13 | skills/st-plan/SKILL.md:25-27 | Verify step has no owned files, test command or screen mode check | FR-005, FR-023, FR-026 | DL9, DL10 (T038) |
| 14 | skills/st-full/SKILL.md:11 | "(asks: make GitHub issues?)" | FR-029 | TP4 (T043) |
| 15 | skills/st/SKILL.md:30 | lane line with no risk | FR-011 | R1 to R3 (T022) |
| 16 | skills/st/SKILL.md:54-56 | small decisions listed only at the end | FR-016 | R12 (T022) |
| 17 | skills/st/SKILL.md:69 | "or at the `st-plan` question" | FR-029 | TP2 (T043) |
| 18 | skills/st/SKILL.md:14-31 | no issue triage before the lane | FR-028 | TP1 (T043) |
| 19 | skills/st-fast/SKILL.md:16-20 | no small-decision review | FR-016 | R14 (T022) |
| 20 | skills/st-init/SKILL.md:62-63 | `codex` recommended, no `auto` | FR-012 | R15 (T022) |
| 21 | skills/st-sync/SKILL.md:26 | "Run the tests in `tests/` and report the result." (the full suite) | FR-005 | S6 (T007) |
| 22 | agents/st-build.md:43-45 | "the other tests that cover the files you touched", "design brief" | FR-006, FR-007, FR-010, FR-024 | S1, S2 (T007), L1, L2 (T015), DL17 (T039) |
| 23 | agents/st-debug.md:41 | "the other tests that cover the touched files" | FR-006, FR-007, FR-010 | S1, S2 (T007), L1, L2 (T015) |
| 24 | agents/st-test.md:33-39 | no lock rule | FR-010 | L1, L2 (T015) |
| 25 | agents/st-plan.md:41 | "Mark tasks that touch no common file `[P]`." | FR-026, FR-023, FR-005 | S4 (T007), DL1, DL2 (T038) |
| 26 | procedures/tasks.md:81 | "[P] marker: Include ONLY if task is parallelizable" | FR-026 | S5 (T007), DL3 to DL5 (T038) |
| 27 | templates/tasks.md:18, 246 | `[P]` = different files | FR-026 | DL6 to DL8 (T038) |
| 28 | README.md:154, 170-180 | advisor modes and runs | FR-012, FR-013 | R16 to R18 (T022) |
| 29 | scripts/st-worker.sh:155-166 | brief has no lock rule and no approval folder rule | FR-010, FR-019 | B1 (T016), B2 (T031) |

Out of scope by D22: Define, Close and Quick (`agents/st-quick.md:46-47` already says "Do not run
the full suite").

## Open points for later (not in this feature)

- The parasat constitution's `pgrep -f vitest` wait loop (spec Assumptions). Line to give the user:
  replace the wait loop with `bash <stratum plugin root>/scripts/st-lock.sh -- <test command>`.

## Complexity Tracking

No constitution, so no violation to justify.

## Validate

Date: 2026-10-31 (pass 2). Verdict: BLOCKED

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | CONCERN | F9 (claude 2.1.312, codex-cli 0.166.0, herdr 0.9.4, bash 5.3, python 3.14, jq 1.8, git 2.56, timeout, sha256sum, ssh present; `herdr tab create --env`, `agent prompt --until`, `agent read --source recent-unwrapped`, `tab rename/close`, `pane split --direction`, `pane run` exist) |
| 2. Test coverage per requirement | CONCERN | F6, F13 |
| 3. Breaking changes | FAIL | F1, F14 |
| 4. Security and privacy | FAIL | F2, F3, F4, F5, F7, F8, F10, F11, F12 |

F1. HIGH. tests/test_on_demand.sh:309 asserts `! grep -qF "st-advisor.sh diff" skills/st-build/SKILL.md`. A9 (contracts/phrases.md:22) writes `bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <last review sha>` there. T006 writes A9 in wave 2, and its Test runs `test_on_demand.sh`, so it goes red. The Tests of T007, T015, T022, T033, T038, T043 and T048 also go red. No task changes check 309: T003 deletes row 268, T020 changes rows 274, 277 and 283, and T029 changes rows 222, 234 and 258. -> T003 (wave 1, owns `tests/test_on_demand.sh`) changes check 309 so the only `st-advisor.sh diff` line allowed is A9, and it keeps the `check diff` half.

F2. HIGH. contracts/scripts.md:179 (`approve`: "the autonomous check as `start`"), :174, scripts/st-worker.sh:174 (`top=$(git rev-parse --show-toplevel)`), :133-143 (`find_worker` finds any worker through herdr). From inside its own worktree, worker A can do 3 steps. (1) Write `<wtA>/.stratum/autonomous`. (2) Set `CLAUDE_CODE_SESSION_ID` to the same value. (3) Run `st-worker.sh wait worker-B`, then `st-worker.sh approve worker-B --request <rid> --input <text>`. No step has `.stratum/approve` in its text, so D27 lock 2 does not stop it. B's hook then sees a real `.ok` and allows. The orchestrator's classifier never sees this approval. The lock 2 regex also misses `.stratum/./approve/`. This route does not build a path at run time, so S4 and W15 understate the risk. The hook reads the main checkout's file (data-model.md:63), but `approve` reads `<top>`. -> `approve`, `pass` and `start` read the main checkout's `.stratum/autonomous` through the git common dir, as the hook does. They refuse when `<top>` has `.stratum/approve/` or is a linked worktree. They require the worker's `.stratum/approve/session` to equal the caller's id, which also stops a new session from approving an orphan of a crashed session. When the root has `.stratum/approve/`, lock 2 also denies Bash text that names `st-worker.sh approve` or `pass`, or `.stratum/autonomous`. Normalize `/./` before the match. Add T026 and T027 cases. Change S4 and W15 to match. Goes to st-plan.

F3. HIGH. contracts/scripts.md:213-218. The edit never list has no `.claude/` and no `.mcp.json`. W3 (phrases.md:109) approves "an edit inside the worker's own worktree". A worker can edit `<wt>/.claude/settings.local.json` (allow rules, hooks, `defaultMode`) or `.mcp.json`. One approved edit of that kind gives the worker standing permissions, and FR-019's "one time only" no longer holds. -> Add `.claude/` and `.mcp.json` to the edit never list, the Bash never list and W5. Add T026 (f) cases. Not verified live: whether a running session reloads its settings.

F4. HIGH. contracts/scripts.md:228-246. The D23 checks read the branch (`symbolic-ref`) and the staged list (`diff --cached`) before the command runs, and they look only at `git add` and `git commit` words. Example: `git checkout other && git add src/a.py && git commit -m x`. The guard asks on it (`left`, hooks/st-git-guard.py:241), and the `.req` shows `branch worker-t1`, but the commit lands on `other`. These commands also change what gets committed and pass the rule: `git rm src/b.py && git commit -m x`, `git mv`, `git restore --staged`, `git apply --cached`, `git stash pop`. Also, a commit on the worker's own branch never asks (`commit: auto`, scripts/st-worker.sh:176). So W15's "approves only ... a commit of the task's own files" overstates the guard. -> A command with a commit holds no git subcommand other than `add` and `commit`. Add each form above to T026 (h2) with "no `.req`". Change W15 to say that an own-branch commit runs with no prompt and is checked at review.

F5. HIGH. contracts/phrases.md:109 (W3) and quickstart.md:122 put the worker's request text inside `--input "<the input line's text>"`. In the orchestrator's shell, `$(...)` and backticks in that text run, and each `"` of the JSON breaks the quoting. The worker controls that text, and W3 itself calls it data. -> `approve` reads the input from stdin through a quoted heredoc (`<<'ST_INPUT'`). The input is one line of JSON, so it cannot hold the end line, the classifier still sees the full text, and the shell expands nothing. Add a T027 (d) case whose input holds `$(touch pwned)`: no `pwned` file is made.

F6. HIGH. contracts/scripts.md:250-253 splits words on white space, and :242-245 counts every non-option word after `commit` as a pathspec. In `git commit -m "demo heredoc"` (quickstart.md:118), `-m` takes only `demo`, so `heredoc` counts as an unowned path and the hook sends no `.req`. Step 3 of quickstart section 4L (line 121) then fails. Most real commit messages have spaces, so D23 never fires. T026 (h2) uses only `-m x`, so no test catches this. -> Split the git line with shlex (refuse only when that one line does not split), and add a T026 case `git commit -m "two words"` that gives a `.req`.

F7. MEDIUM. contracts/phrases.md:109 (W3) sends "a request for an action the worker's own classifier blocked (the pane says so)" to the user. In the `approval` state, `wait` prints no pane text (contracts/scripts.md:178, scripts/st-worker.sh:124-127). So the orchestrator cannot see the classifier block that pass-1 F9 is about. -> The `approval` state also prints the pane text. T027 (c) asserts it.

F8. MEDIUM. contracts/scripts.md:131 tells the user to "Answer it there" on `agent_not_ready`, with no rule for what to answer. With the new Codex home, a trust dialog can show. If the user picks "trust", Codex writes the trust into the Stratum home's `config.toml`. From then on, the project's `.codex/config.toml` loads in the tab, and D25 no longer holds. -> If T050 sees a trust dialog, the `agent_not_ready` line, R7 and R17 say to pick "do not trust".

F9. MEDIUM. `~/.claude/plugins/installed_plugins.json` maps `/home/hyuse/Desktop/stratum` to the cached plugin 0.2.1. A worker started in this repo loads that copy's `hooks/commands.json`, which has no `PermissionRequest` entry. So T034's "the hook never fires" test is true for the wrong reason, and its contingency would start. -> Quickstart section 0, T024 and T034 name the step that loads this branch's plugin before the live runs.

F10. LOW. research.md:160-162, tasks.md:229-230. T050 checks `test -L auth.json` after one short prompt only, and a short prompt does not refresh the token. If a refresh replaces the link with a file, the user's own `~/.codex/auth.json` keeps an old token. -> T024 repeats the `test -L` and `codex login status` checks. `st-codex-agent.sh` prints a line when `auth.json` is no longer a link, and does not quietly fall back.

F11. LOW. decisions.md:37 (D28) says that a stop removes a stale file. contracts/scripts.md:176 removes only the caller's own id. A crashed session leaves a pair of files that still match each other. The hook then writes a `.req` and holds each prompt for 300 s, and no one answers it. There is no approval path, because `approve` needs the live id. -> Change the D28 text to match the contract.

F12. LOW. contracts/scripts.md:268-270. The fallback finds no git word in `{git,push}`, `$'git' push` or `GIT=git; $GIT push`, so it gives no decision. Today's guard does the same for commands that split, so this opens no new route. But S6 (plan.md:145-149) does not name these forms, which pass-1 F4 asked for. -> Name them in S6.

F13. LOW. tasks.md:599. T048 runs `tests/test_codex_agent.sh` in all cases, but the file does not exist when T050 fails. -> Run it only if T050 passed.

F14. LOW. tasks.md:530-533. T039 changes skills/st-build/SKILL.md:36-41, where on_demand rows 263 and 297 assert text. Its Test has no `test_on_demand.sh`, so the first task to see a break there is T022. -> T039 runs `test_on_demand.sh`, with only rows `#18 FR-010 modes`, `#18 FR-010 no file` and `#18 FR-015 init` as expected reds.
