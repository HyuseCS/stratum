# Implementation Plan: Triage a GitHub Issue

**Branch**: `15-st-triage` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-st-triage/spec.md`, decisions D1 and D2 in
[decisions.md](decisions.md), GitHub issue #15.

## Summary

A thin skill, `/stratum:st-triage <issue#>...`, checks each number with `gh issue view`, notes
the git state and each issue's `updatedAt`, and starts one read-only `st-triage` agent per issue
in the same message (research R5). Each agent reads its issue, the comments and the repo paths
and `#N` issues it links to, checks every claim against the code and `git log`, and reports the
verdict, what is built, the blocker and the next step. The skill then compares the git state and
`updatedAt` again, checks each cited `file:line` and commit against the source, and shows one
report per issue in the order given. The agent has `tools: Read, Grep, Glob, Bash` and
`model: opus`. `tests/test_on_demand.sh` gains `st-triage` in two existing loops and one phrase
table. The docs and tests that list every agent go from 13 to 14 agents.

## Technical Context

**Language/Version**: Markdown (skill, agent, docs), Bash 5.3.20 (test edits), Python 3.14.8 (one test edit)

**Primary Dependencies**: Claude Code 2.1.302 plugin layout (`agents/*.md`, `skills/*/SKILL.md`), gh 2.102.0 (`gh issue view --json`, research R3), git. No new package.

**Storage**: N/A. Reads GitHub and the repo. Writes nothing.

**Testing**: `bash tests/test_on_demand.sh` (extended), `bash tests/test_inspect.sh`, `bash tests/test_model_files.sh`, `bash tests/test_session_hooks.sh`, `python3 -B -m unittest tests/test_model_hook.py`, `claude plugin validate .claude-plugin/plugin.json`

**Target Platform**: Claude Code on Linux, macOS, Windows, with `gh` signed in

**Project Type**: Claude Code plugin (agents, skills, hooks, docs)

**Performance Goals**: FR-005: the agents of several issues run at the same time.

**Constraints**: No comments except `ponytail:` markers. Minimal diff. No new script, hook or dependency. `hooks/st-session-start.sh`, `hooks/st-models.py` and `templates/models.json` unchanged (research R9). The agent has no Edit or Write tool.

**Scale/Scope**: 1 new skill, 1 new agent. Edits: `tests/test_on_demand.sh`, `tests/test_inspect.sh`, `tests/test_model_hook.py`, `skills/st-model/SKILL.md`, `skills/st-init/SKILL.md`, `README.md`, `DESIGN.md`. 14 agents.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` (base repo). The gates come from the rules the
orchestrator passed and `docs/lessons.md`, as in feature 004.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that fails before its build task | Pass: T001 before T002 (FR-001 to FR-004, FR-006 to FR-008), T003 before T004 (FR-005). Red states in quickstart section 1 |
| G2. Minimal diff, no new script, hook or dependency, no comments | Pass: two Markdown files, one-line doc and test edits |
| G3. One source of truth for the agent list | Pass: `hooks/st-models.py:8` reads `agents/`. The pinned lists follow (research R8) |
| G4. A text check asserts a phrase the file builds (L1) | Pass: the phrases in contracts/triage.md section 3 match the contract text, one line each (checked on a scratch copy, 31 of 31) |
| G5. Tasks that share one test or one repo-wide check are one task (L6) | Pass: T002 builds every file the agent-list checks read. No task is `[P]` |
| G6. A check between two lists reads both sides (L7) | Pass: README checks are two-way already. "every agent has a command" is one-way by 004's spec |
| G7. Test runs leave no files (L8) | Pass: `PYTHONDONTWRITEBYTECODE=1` in every run, `git status --porcelain` in T006 |
| G8. Each new check has a negative control (L2, L10) | Pass: quickstart section 2. The tool list guard has its own control (C1) |
| G9. Background or fork failure states named (L11) | Pass: the agents are not a background fork and write no file. A run that cannot start (no `gh`, bad number) stops in step 2 |

Post-design re-check: all gates pass. No violations, so Complexity Tracking stays empty.

## Security Notes

- **S1. The agent has Bash and reads GitHub (T002).** Bash is needed for `gh issue view` and
  `git log` (research R2). So the tool list stops Edit and Write but not a write through Bash, and
  not `gh issue comment`, `gh issue edit` or `gh issue close`. The guards: the `## Never` lines
  (only `gh issue view`, no state change), the skill's `git rev-parse HEAD` and
  `git status --porcelain --untracked-files=all` before and after, and each issue's `updatedAt`
  before and after (research R7). The git pair does not see git-ignored paths (`.env`,
  `.stratum/models.json`) or edits to files that were already changed (lessons L10). `updatedAt`
  also moves when another person comments, so a difference is a finding to check, not proof.
- **S2. External service: GitHub through gh (T002).** The skill and the agent use the user's
  `gh` sign-in and read only. No token is read, stored or printed by Stratum. A failed sign-in
  shows gh's own error line (FR-007).
- **S3. Untrusted input (T002).** Anyone who can comment on the repo writes the text the agent
  reads. The skill accepts digits only as issue numbers before any shell call. The agent uses
  `#N` links with N digits only, puts each path in single quotes, marks a path with a `'` as
  `unchecked`, and treats the issue text as claims to check, never as instructions (research R6).
  The agent reads no path outside the repo and fetches no web page, so issue text cannot point it at `~/.ssh` or a URL.
- **S4. Model file names (T002).** `.stratum/models.json` accepts `st-triage` once the agent file
  exists. Existing files stay valid. No other contract changes.
- No access rules, no personal or minors' data beyond what the issue already shows on GitHub.

## Breaking Changes

- None for stored data or existing files.
- The agent count in docs and tests goes from 13 to 14.
- Rollback: revert the feature's commits.

## Project Structure

### Documentation (this feature)

```text
specs/005-st-triage/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
├── contracts/
│   └── triage.md         # skill and agent text, phrase table
└── tasks.md
```

### Source Code (repository root)

```text
skills/
├── st-triage/SKILL.md    # new (US1, US2)
├── st-model/SKILL.md     # agent list (US1)
└── st-init/SKILL.md      # "14 agents" (US1)
agents/
└── st-triage.md          # new (US1)
tests/
├── test_on_demand.sh     # two loops, #15 phrase table
├── test_inspect.sh       # "14 agents", st-init phrase
└── test_model_hook.py    # 14 names
README.md                 # skills row, agent row, model overrides list and sentence
DESIGN.md                 # D7 row, D9 row and count
```

**Structure Decision**: Plugin layout as it is. The skill copies the frame of
`skills/st-review/SKILL.md`. The agent copies the frame of `agents/st-review.md` and
`agents/st-ponytail-audit.md`.

## Complexity Tracking

No violations.
