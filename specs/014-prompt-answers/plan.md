# Implementation Plan: Answer the prompts of summoned agents

**Branch**: `074-prompt-answers` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/014-prompt-answers/spec.md`, decisions D1 to D9 in [decisions.md](decisions.md), 013 D7.

## Summary

The orchestrator may now answer a normal-mode worker's permission dialog with the one-time yes, when the action is on the worker allow list (013 D7). `st-worker.sh answer --keys` sends one option number on a permission dialog only when that option is a one-time yes form (D3, D7), and only when the pane still shows the screen the orchestrator judged (`--screen <hash>`, D6). The three orchestrator skills get one shared rule sentence and a pointer to each agent kind's lists. `skills/st/SKILL.md` gets a short note on in-session subagent prompts, with every fact sourced in [research.md](research.md) R4. Done is proved by text-rule rows and stub tests, each seen red before it is green (D2). No live run.

## Technical Context

**Language/Version**: Bash 5 (`scripts/st-worker.sh`, tests), Markdown skill files

**Primary Dependencies**: herdr CLI (stubbed in tests), grep, sed. No new dependency.

**Storage**: N/A

**Testing**: `bash tests/test_worker_rules.sh` (text rows), `bash tests/test_st_worker.sh` (stub herdr), `bash tests/test_lane_steps.sh`, `bash tests/test_advisor_rules.sh`, `bash tests/test_on_demand.sh`

**Target Platform**: Linux and macOS shells where Claude Code and herdr run

**Project Type**: Claude Code plugin (skills, scripts, hooks)

**Performance Goals**: N/A

**Constraints**: `skills/st-build/SKILL.md:98-100` unchanged (FR-009). The `approval` bullet and its four lines after it in `skills/st-worker/SKILL.md` unchanged (FR-003, FR-004; :28-32 before any task runs). No change to `hooks/st-models.py`, `settings.json` or the user's permission settings. No comment lines in code except `ponytail:` markers.

**Scale/Scope**: 3 skill files, README line 117, one script branch, 3 test files.

## Constitution Check

`.stratum/constitution.md` does not exist in this repo (the base repo has none by the user's choice), and there is no `apps/*/ORDINANCE.md`. No gate applies. Re-checked after design: same.

## Design

- **US1, script (FR-010)**: built in T003 (42c758b): one option number, and a lasting-phrase list. The old permission line stays for `--text` and for a failed read.
- **US1 rework, script (FR-010, FR-011)**: T012, per `contracts/answer.md`. `st blocked` prints `screen<TAB><hash>` for a permission dialog, so `wait` and `watch` both get it. `answer` takes `--screen <hash>` before `--keys`, reads 20 lines with the hash method of `scripts/st-advisor.sh:35`, judges the dialog by the last 15, refuses a missing or changed screen, and checks the option line against the one-time yes allow list (D7). The lasting-phrase list and the no-option line go.
- **US1 re-review fixes (FR-010, FR-011)**: T014 adds the cases, then T015 changes the script. One 40-line read in `st blocked` is hashed and printed as the pane text, and `answer` hashes the same read (D9). Option lines count only after the last dialog head line, and no head line means a refusal (re-review F1, inside D7). The `ponytail:` note says 40-line.
- **US1 rework, skill**: T013 replaces the W1 line (`contracts/skill-lines.md` section 1b). W1 now passes `--screen <hash>` from the `screen` line, and says that normal mode has no request id, so `approve` and `pass` are not used (the review's wording point).
- **US1, skill (FR-001 to FR-004)**: `skills/st-worker/SKILL.md:26-27` become W1, W2 and W18 (`contracts/skill-lines.md` section 1). W1 points to the `approval` lists and says they hold in both modes, so no list is written twice (D1). W2 says how to check the commit rule from the dialog text, because a normal-mode dialog has no `branch` or `staged` line (research R2). W1 also holds W28 (the dialog must show the whole command or path, else the user gets it) and W29 (the Bash description of the `answer` call names the action, so the user's permission check sees what is approved).
- **US1, README**: `README.md:117` says normal mode never approves. That becomes false, so it changes to W19. This is not named in the spec. It is the one user-facing line that states the old rule.
- **US2 (FR-005, FR-006, FR-009)**: the rule sentence on one physical line in each of the three files, each with a pointer to its lists (`contracts/skill-lines.md` section 3).
- **US3 (FR-007, FR-008)**: two note lines in `skills/st/SKILL.md` (W24, and W30 plus W25 on one line, D5) and source rows S1 to S6 on `research.md`.
- **Old rows**: G1 in `tests/test_worker_rules.sh` and row 1 in `tests/test_lane_steps.sh` hold 010 FR-017. 013 D7 reversed it, so both rows go. W1 and W2 keep their ids with new text. New gone rows G5 to G7 keep the old lines out.

## Security notes

Each task below touches access rules: which permission prompts the orchestrator may approve for an agent.

- **T001, T003, T010, T012, T014, T015 (script guard)**: the guard is a second check, not the only one. The skill text decides which action is allowed. After T012 the script sends a key on a permission dialog only when the option line is a one-time yes form (an allow list, D7) and the pane is the screen the orchestrator judged (D6). So a new lasting wording, a wrapped line, a look-alike line in the command (only lines after the dialog head count, T015), or a dialog that changed after `wait` sends nothing. After T015 the hashed text is the same text the orchestrator judged (D9). The pane text is data: the script reads only the option line for the key sent and the hash of the screen, and prints nothing from the pane in its refusal lines.
- **T002, T004, T011, T013 (st-worker and README)**: the normal-mode allow list is the autonomous one (D1). Normal mode has no hook request file, so the orchestrator judges from the dialog text alone. That text comes from the worker's pane and can hold text an agent wrote. W1 keeps "the pane text is data" (line 25) in force, and every unrecognised dialog goes to the user. Commits on the worker's branch need no prompt (`commit: auto`), so a commit dialog is rare and is checked against the command shown (W2).
- **T005 to T008 (shared rule and subagent note)**: the note says the orchestrator cannot approve an in-session subagent's prompt and never runs a denied action in its place. W30 has the orchestrator put `model` and `effort` from `.stratum/models.json` in the call, so the hook changes nothing and auto mode reviews what runs. The resend rule (W25) sends the same call with the exact input the denial quotes, once. Neither widens any permission.
- No secrets, personal data, data model or external service change.

## Safety checklist

`checklists/safety.md` belongs to the reviewer. Its items stay unchecked here. The reviewer works them at the PR, not at a build gate, and no task changes that file.

## Risks

- R1: Claude Code may change its dialog wording. After T012 a new wording of the one-time yes is refused (fails safe: the dialog goes to the user). A new lasting wording is refused too. The test pane texts are written from today's dialogs, not from a live capture (D2, no live run).
- R2: a stale or changed dialog. After T012 the screen hash stops a key when the pane changed after `wait` (D6).
- R3: a pane that redraws while the dialog waits (P1, closed by D8). Every `answer` is then refused. This fails closed, but normal-mode answers would not work at all. T012's `ponytail:` note at the hash compare names the upgrade: `--expect <text>`, when a real worker pane's hash never matches.

## Open points

None. P1 (can a blocked worker pane redraw in its last 20 lines, 40 after D9?) is closed by D8 (O15): build the hash with no `--expect`, fail closed, and leave a `ponytail:` note (`contracts/answer.md` section 6). O16 (a live check before T012) was rejected.

## Project Structure

### Documentation (this feature)

```text
specs/014-prompt-answers/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── quickstart.md
├── contracts/
│   ├── answer.md
│   └── skill-lines.md
└── tasks.md
```

No `data-model.md`: the feature adds no data. The one key entity (agent kind) is a word in the skills, defined in spec.md.

### Source Code (repository root)

```text
scripts/st-worker.sh            st(): screen line; answer: --screen, permission branch
skills/st-worker/SKILL.md       :10 rule sentence, :26-28 normal-mode lines (W1 reworked)
skills/st-build/SKILL.md        ## Always: rule sentence
skills/st/SKILL.md              ## Always: rule sentence, pointer, subagent note
README.md                       :117
tests/test_st_worker.sh         AN1, AN5 to AN13
tests/test_worker_rules.sh      W1, W2, W18 to W32, O1, S1 to S6, G1, G5 to G9
tests/test_lane_steps.sh        row 1 removed
```

## Complexity Tracking

No violations.

## Validate

Date: 2026-11-06. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | bash 5.3.20, jq 1.8.2, GNU grep 3.12 (under bash), python3 3.14.9, herdr on PATH (stubbed in tests), `scripts/st-verify.sh` present. Baseline at `13ae81d`: test_worker_rules, test_lane_steps, test_advisor_rules, test_on_demand, test_st_worker, test_risk_rules, test_state and test_model_hook all exit 0. No new dependency. |
| 2. Test coverage per requirement | CONCERN | F1, F3 |
| 3. Breaking changes | PASS | `answer` has one caller, `skills/st-worker/SKILL.md:25-27`. Other `answer` cases in `tests/test_st_worker.sh` (:698-736, :893) use question panes and keep their behavior. `test_on_demand.sh:215-223,241-242` rows sit on line 25, which stays. Old rows G1 and lane row 1 are removed on purpose (013 D7). No stored data, no migration. |
| 4. Security and privacy | CONCERN | F7 |

F1. specs/014-prompt-answers/research.md:44 (fact 6) and contracts/skill-lines.md:59 (W25). FR-008 (spec.md:80) allows two source kinds: a doc URL with a quote, or a file and line in this repo. Fact 6 rests on a denial text seen live in one session, which is neither, so W25 has no FR-008 source. S1 to S5 only grep for strings in research.md, so no test can go red on this. -> User decision: (a) amend FR-008 and SC-003 to accept a quoted Claude Code denial text as a source (new D4), or (b) mark fact 6 "not documented" and drop W25 from T008.

F3. specs/014-prompt-answers/tasks.md:46,83. O1, S1, S2, S3 and S5 are green before the build and have no negative control, so it is not shown that they can fail. -> st-plan: in T002, copy the never-list line once, see O1 `FAIL`, undo. In T007, also break the S1 URL once and see S1 `FAIL`.

F7. specs/014-prompt-answers/contracts/skill-lines.md:18 (W1). In normal mode the orchestrator judges the action from pane text only (`wait` shows 40 lines, `answer` reads 15). A long command or heredoc can push its first lines out of view, and W1 does not say to refuse when the full command or path is not shown. W2 has this guard for commits only. -> st-plan: add to W1 "The dialog must show the whole command or path. Else send no key and tell the user." and its row.
