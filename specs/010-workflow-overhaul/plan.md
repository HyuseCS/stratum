# Implementation Plan: Workflow Overhaul

**Branch**: `010-workflow-overhaul` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-workflow-overhaul/spec.md`, decisions D1 to D22 in
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
   worker's prompt to the orchestrator, which approves small safe ones one time, a worker's
   own-files commit on its own branch included (D23), (`st-worker.sh approve`) and passes the rest to the user (`pass`). The status line shows it.
5. Lanes (US5): the planner marks `[P]` with owned files, `[lock]` and `[screen: <mode>]`; Build
   sends new screens to the Design lane.
6. Skill clean-up (US6): `/stratum:st` triages named issues first, the Plan gate no longer offers
   issues, and `st-frontend-design` is removed.

Research R-A shows the `PermissionRequest` hook can wait 75 s and answer `allow` in a worker
running `--permission-mode auto`, so FR-019 needs no fallback.

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

**Scale/Scope**: about 10 scripts and hooks, about 20 Markdown files, 13 new or changed test files.

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
| lessons L11 | a background action lists its failure states | Design lane in Build: cannot start (D12), ends with no report (D14), screen still open while others run (D11) |
| lessons L12 | a phase starts through the Skill tool | `/stratum:st-design` and `/stratum:st-triage` are started with the Skill tool (D11, T1) |
| lessons L14 | a prompt string change updates the contract and test together | the Codex prompt lines are in contracts/scripts.md sections 1.3 and 2; T018 and T019 assert them |
| lessons L16, L17 | a hash step has one failing test per producer | `diff` point: a failing `git diff` and a failing `sha256sum`; `decisions`: an unreadable list (T002, T018) |
| lessons L18 | a commit line for a generated file says "if it changed" | the Inspect and Build lines that commit `advisor.md` keep "if it changed" |
| lessons L19 | work moved to the main session names its folder | `approve` and `pass` run in the main session and name the worker by id; the record file is in the orchestrator's scratchpad |
| lessons L25 | a negative control runs on a green baseline | T047 and T013 run the new code green first, then the old copy |
| lessons L26 | stub ids have a random part | herdr stand-ins in T019 and T027 |
| lessons L29 | worktree work uses the main checkout | the test lock lives in `git rev-parse --git-common-dir`, shared by all worktrees |
| lessons L30 | `agent start` retries `agent_pane_busy` | `st-codex-agent.sh` step 3 |
| lessons L31 | a herdr stub answers in the real CLI format | `agent read` stub prints plain text with the Codex wrap seen live (research R-C) |
| lessons L32 | each new herdr or claude call gets a live run | T024 (Codex tab review), T034 (worker layout and approval) |
| lessons L33 | a review fix that adds `--` to a real CLI call is run once live | no new `--` except the documented agent-argument separator of `herdr agent start`, already used by `st-worker.sh:200` |
| lessons L34 | wait for `blocked` to clear after an answer | `approve` runs `agent wait --until working --timeout 5000` before it returns |
| lessons L37 | a brief rule change updates contract 008 section 3 and test S1 | T016 (B1), T031 (B2) |
| lessons L38 | a routing line states where in the sequence it comes | R1 keeps "Before the first lane skill or agent starts"; T1 says "first" and "then pick the lane" |
| lessons L39 | a skill shows a script's output word for word | A11 (`count`), W7 (approvals file) |
| lessons L40 | a repeated check names its full scope | D12 runs the screen again "from `/stratum:st-design` step 1" |
| lessons L41 | a mode-specific line names the mode | D1, D11 name the screen mode; W3 says "autonomous build mode only" |
| lessons L42 | an agent names the folder for files it keeps | approval record in the orchestrator's scratchpad (W3); lock folder in the git common dir |

## Security notes

These tasks touch access rules, an external service, or text that can hold secrets.

- **S1. Advisor default (FR-012, external service, D24).** "auto is the default when
  `.stratum/advisor.json` has no mode" means: a file with no `mode` key means `auto`. No file
  keeps today's `no advisor: mode not set` line, so nothing goes to OpenAI until the user writes
  the file. `st-init` recommends `auto`. Tasks T018, T022, T023.
- **S2. Codex in a herdr tab reads the user's Codex config (FR-013, external service).** The TUI
  has no `--ignore-user-config` (research R-C), so `~/.codex/config.toml` (model, hooks, MCP)
  applies, and the session is saved under `~/.codex/sessions/`. The sandbox stays `read-only`
  and approvals `never`. README says so (R17). The prompt rules that forbid secrets stay. Tasks
  T019, T021, T022.
- **S3. Permission approvals (FR-019, access rules).** The hook acts only in a folder with
  `.stratum/approve/`, which only `st-worker.sh start --autonomous` makes, and only when the
  orchestrator session's id is in `.stratum/autonomous`. The never list is in the hook, so a
  wrong judgement by the orchestrator cannot approve a push, a path outside the worktree, a
  `.stratum` path, a secret file, a dependency or a network tool. A commit reaches the
  orchestrator only when D23 holds: own worktree, own branch (from `.stratum/git-guard.json`),
  only staged files listed in `.stratum/approve/owns` (the task's `Owns:`), no `--amend`, no
  `--no-verify`; the orchestrator checks the same rules again (W16). The hook never answers `deny`
  and never sets a rule or mode: each approval is one time. Tasks T026, T027, T030, T031.
- **S4. Residual risk in S3.** A worker in auto mode can write its own `.ok` file. The brief
  forbids writing in `.stratum/approve/` (B2), the hook refuses to send any request that names
  `.stratum`, and the worker's own classifier judges the write. A worker that bypasses all three
  is a compromised session, which this feature does not defend against. Stated in README.
- **S5. Prompt text can hold secrets (FR-019).** The request file stays in the worktree's
  untracked `.stratum/approve/`, the approval record in the orchestrator's scratchpad. Neither is
  committed. B2 forbids committing `.stratum/approve/`.
- **S6. Git guard fallback (FR-008, access rules).** The fallback judges git lines with the folder
  unknown, so a `git commit` there asks even in commit `auto` mode. It only removes asks for
  commands with no git word. Today's gap stays: git called from inside another program in a
  command that splits fine is not read (research R-F).

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
├── commands.json          # + PermissionRequest entry (US4)
├── st-approve.py          # new (US4)
└── st-git-guard.py        # fallback for unsplittable commands (US2)
scripts/
├── st-advisor.sh          # waive, note, count, diff (US1); auto, matrix, decisions, round, talk, herdr path (US3)
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
| 4 | skills/st-build/SKILL.md:36-41 | `[P]` only through subagents; "merge it into `main` yourself" | FR-020; FR-026 story parallelism; the merge target is the feature branch (skills/st/SKILL.md:66, skills/st-worker/SKILL.md:29) | W10 (T033), D15, D16 (T039) |
| 5 | skills/st-build/SKILL.md:58-61 | `/advisor` on the feature's full diff, always | FR-003, FR-004 | A8 to A11 (T006) |
| 6 | skills/st-build/SKILL.md:65 | "It runs at two points" | FR-012 matrix | R5, R6 (T022) |
| 7 | skills/st-build/SKILL.md:72 | "Then run the same point once more on the changed input." | FR-001 | A1 to A3 (T006) |
| 8 | skills/st-build/SKILL.md:74 | modes `codex`, `both`, `off` | FR-012 adds `auto` | R4 (T022) |
| 9 | skills/st-build/SKILL.md:75 | stale plan always runs Codex again | FR-002 waive | A7 (T006) |
| 10 | skills/st-build/SKILL.md:20-23 | no `[lock]`, no `[screen]` route | FR-010, FR-024 | L1, L3 (T015), D11 to D14 (T039) |
| 11 | skills/st-inspect/SKILL.md:33 | stale plan always runs Codex again | FR-002 | A5, A6 (T006) |
| 12 | skills/st-plan/SKILL.md:3, 36 | "then offer GitHub issues", "Make GitHub issues from the tasks?" | FR-029 | T3 (T043) |
| 13 | skills/st-plan/SKILL.md:25-27 | Verify step has no owned files, test command or screen mode check | FR-005, FR-023, FR-026 | D9, D10 (T038) |
| 14 | skills/st-full/SKILL.md:11 | "(asks: make GitHub issues?)" | FR-029 | T4 (T043) |
| 15 | skills/st/SKILL.md:30 | lane line with no risk | FR-011 | R1 to R3 (T022) |
| 16 | skills/st/SKILL.md:54-56 | small decisions listed only at the end | FR-016 | R12 (T022) |
| 17 | skills/st/SKILL.md:69 | "or at the `st-plan` question" | FR-029 | T2 (T043) |
| 18 | skills/st/SKILL.md:14-31 | no issue triage before the lane | FR-028 | T1 (T043) |
| 19 | skills/st-fast/SKILL.md:16-20 | no small-decision review | FR-016 | R14 (T022) |
| 20 | skills/st-init/SKILL.md:62-63 | `codex` recommended, no `auto` | FR-012 | R15 (T022) |
| 21 | skills/st-sync/SKILL.md:26 | "Run the tests in `tests/` and report the result." (the full suite) | FR-005 | S6 (T007) |
| 22 | agents/st-build.md:43-45 | "the other tests that cover the files you touched", "design brief" | FR-006, FR-007, FR-010, FR-024 | S1, S2 (T007), L1, L2 (T015), D17 (T039) |
| 23 | agents/st-debug.md:41 | "the other tests that cover the touched files" | FR-006, FR-007, FR-010 | S1, S2 (T007), L1, L2 (T015) |
| 24 | agents/st-test.md:33-39 | no lock rule | FR-010 | L1, L2 (T015) |
| 25 | agents/st-plan.md:41 | "Mark tasks that touch no common file `[P]`." | FR-026, FR-023, FR-005 | S4 (T007), D1, D2 (T038) |
| 26 | procedures/tasks.md:81 | "[P] marker: Include ONLY if task is parallelizable" | FR-026 | S5 (T007), D3 to D5 (T038) |
| 27 | templates/tasks.md:18, 246 | `[P]` = different files | FR-026 | D6 to D8 (T038) |
| 28 | README.md:154, 170-180 | advisor modes and runs | FR-012, FR-013 | R16 to R18 (T022) |
| 29 | scripts/st-worker.sh:155-166 | brief has no lock rule and no approval folder rule | FR-010, FR-019 | B1 (T016), B2 (T031) |

Out of scope by D22: Define, Close and Quick (`agents/st-quick.md:46-47` already says "Do not run
the full suite").

## Open points for later (not in this feature)

- The parasat constitution's `pgrep -f vitest` wait loop (spec Assumptions). Line to give the user:
  replace the wait loop with `bash <stratum plugin root>/scripts/st-lock.sh -- <test command>`.

## Complexity Tracking

No constitution, so no violation to justify.
