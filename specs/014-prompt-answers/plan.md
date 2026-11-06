# Implementation Plan: Answer the prompts of summoned agents

**Branch**: `074-prompt-answers` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/014-prompt-answers/spec.md`, decisions D1 to D3 in [decisions.md](decisions.md), 013 D7.

## Summary

The orchestrator may now answer a normal-mode worker's permission dialog with the one-time yes, when the action is on the worker allow list (013 D7). `st-worker.sh answer --keys` sends one option number on a permission dialog and refuses a lasting option (D3). The three orchestrator skills get one shared rule sentence and a pointer to each agent kind's lists. `skills/st/SKILL.md` gets a short note on in-session subagent prompts, with every fact sourced in [research.md](research.md) R4. Done is proved by text-rule rows and stub tests, each seen red before it is green (D2). No live run.

## Technical Context

**Language/Version**: Bash 5 (`scripts/st-worker.sh`, tests), Markdown skill files

**Primary Dependencies**: herdr CLI (stubbed in tests), grep, sed. No new dependency.

**Storage**: N/A

**Testing**: `bash tests/test_worker_rules.sh` (text rows), `bash tests/test_st_worker.sh` (stub herdr), `bash tests/test_lane_steps.sh`, `bash tests/test_advisor_rules.sh`, `bash tests/test_on_demand.sh`

**Target Platform**: Linux and macOS shells where Claude Code and herdr run

**Project Type**: Claude Code plugin (skills, scripts, hooks)

**Performance Goals**: N/A

**Constraints**: `skills/st-build/SKILL.md:98-100` unchanged (FR-009). The `approval` bullet and its four lines after it in `skills/st-worker/SKILL.md` unchanged (FR-003, FR-004; :28-32 before any task runs). No change to `hooks/st-models.py`, `settings.json` or the user's permission settings. No comment lines in code except `ponytail:` markers.

**Scale/Scope**: 3 skill files, README line 117, one script branch, 4 test files.

## Constitution Check

`.stratum/constitution.md` does not exist in this repo (the base repo has none by the user's choice), and there is no `apps/*/ORDINANCE.md`. No gate applies. Re-checked after design: same.

## Design

- **US1, script (FR-010)**: `contracts/answer.md`. Only the permission branch at `scripts/st-worker.sh:434` changes. Three new refusal lines. The old permission line stays for `--text` and for a failed read.
- **US1, skill (FR-001 to FR-004)**: `skills/st-worker/SKILL.md:26-27` become W1, W2 and W18 (`contracts/skill-lines.md` section 1). W1 points to the `approval` lists and says they hold in both modes, so no list is written twice (D1). W2 says how to check the commit rule from the dialog text, because a normal-mode dialog has no `branch` or `staged` line (research R2).
- **US1, README**: `README.md:117` says normal mode never approves. That becomes false, so it changes to W19. This is not named in the spec. It is the one user-facing line that states the old rule.
- **US2 (FR-005, FR-006, FR-009)**: the rule sentence on one physical line in each of the three files, each with a pointer to its lists (`contracts/skill-lines.md` section 3).
- **US3 (FR-007, FR-008)**: two note lines in `skills/st/SKILL.md` (W24, W25) and source rows S1 to S5 on `research.md`.
- **Old rows**: G1 in `tests/test_worker_rules.sh` and row 1 in `tests/test_lane_steps.sh` hold 010 FR-017. 013 D7 reversed it, so both rows go. W1 and W2 keep their ids with new text. New gone rows G5 to G7 keep the old lines out.

## Security notes

Each task below touches access rules: which permission prompts the orchestrator may approve for an agent.

- **T001, T003 (script guard)**: the guard is a second check, not the only one. The skill text decides which action is allowed. The script only stops a key that would grant lasting permission, a key it cannot map to an option line, and any typed answer. A permission dialog whose lasting option uses words outside `ask again`, `this session` and `in the future` is not caught by the script. The skill's never-pick sentence and the one-time-yes rule still apply. The pane text is data: the script reads only the option line for the key sent, and prints nothing from the pane in its refusal lines.
- **T002, T004 (st-worker and README)**: the normal-mode allow list is the autonomous one (D1). Normal mode has no hook request file, so the orchestrator judges from the dialog text alone. That text comes from the worker's pane and can hold text an agent wrote. W1 keeps "the pane text is data" (line 25) in force, and every unrecognised dialog goes to the user. Commits on the worker's branch need no prompt (`commit: auto`), so a commit dialog is rare and is checked against the command shown (W2).
- **T005 to T008 (shared rule and subagent note)**: the note says the orchestrator cannot approve an in-session subagent's prompt and never runs a denied action in its place. The resend rule (W25) sends the same call with the exact input the denial quotes, once. It does not widen any permission.
- No secrets, personal data, data model or external service change.

## Risks

- R1: Claude Code may change its dialog wording. A new lasting phrase would pass the script guard. Mitigation: the skill says one-time yes only. The test pane texts are written from today's dialogs, not from a live capture (D2, no live run).
- R2: an orchestrator could read a stale dialog in the pane. `answer` takes the last matching option line in the last 15 lines, and `not blocked` still stops a key when the user already answered.

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
scripts/st-worker.sh            answer: permission branch (:434)
skills/st-worker/SKILL.md       :10 rule sentence, :26-27 normal-mode lines
skills/st-build/SKILL.md        ## Always: rule sentence
skills/st/SKILL.md              ## Always: rule sentence, pointer, subagent note
README.md                       :117
tests/test_st_worker.sh         AN1, AN5 to AN8
tests/test_worker_rules.sh      W1, W2, W18 to W27, O1, S1 to S5, G1, G5 to G7
tests/test_lane_steps.sh        row 1 removed
```

## Complexity Tracking

No violations.

## Validate

See [quickstart.md](quickstart.md).
