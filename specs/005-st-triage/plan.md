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
| G4. A text check asserts a phrase the file builds (L1) | Pass: the phrases in contracts/triage.md section 3 match the contract text, one line each (checked on a scratch copy, 35 of 35) |
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
  `#N` links with N digits only, puts each path and each value it passes to
  `git log --oneline --grep='<word>'` and `git log --oneline -S'<text>'` in single quotes, marks
  one that holds a `'` as `unchecked`, and treats the issue text as claims to check, never as instructions (research R6).
  A path inside the repo is relative, has no `..` part, and does not start with `/` or `~`. The
  agent reads no other path and fetches no web page, so issue text cannot point it at `~/.ssh`
  or a URL.
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

## Validate

Date: 2026-10-22. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | gh 2.102.0 (signed in as HyuseCS), Claude Code 2.1.302, Bash 5.3.20, Python 3.14.8, git 2.56.0, node v24.14.1 match research.md. No new package |
| 2. Test coverage per requirement | CONCERN | F3, F4, F6 |
| 3. Breaking changes | PASS | Pinned lists that break and are fixed by T001/T002: `tests/test_model_hook.py:202-204`, `tests/test_inspect.sh:89` and `:97`, `tests/test_inspect.sh:112-118` (README two-way), `tests/test_model_files.sh:42` (via `skills/st-model/SKILL.md:11`), `tests/test_session_hooks.sh:40-43`. `hooks/st-models.py:8` reads `agents/`, no break. Existing `.stratum/models.json` files stay valid. Rollback: revert the commits (line 87) |
| 4. Security and privacy | CONCERN | F2, F5 |

Evidence: T001 to T004 built from contracts/triage.md in a scratch clone of `2515f68`. After T001 the red set equals quickstart section 1 row T001. After T003 only `#15 FR-005 skill` is red. After T004 every quickstart section 1 command passes and `git status` lists only the planned files. The 16 phrase controls, C1 to C4 and both README controls give the red checks quickstart section 2 names.

F2. contracts/triage.md:77 The agent runs `git log --oneline --grep=<word>` and `git log --oneline -S<text>` with values taken from issue text. S3 (line 74-78) quotes paths only, so these values reach the shell unquoted. -> st-plan: in step 4, put each value from the issue in single quotes, mark a value with a `'` as `unchecked`, add a `#15 untrusted` phrase row and a control line.
F3. quickstart.md:112 FR-006 and SC-002 have no check that can fail on behavior. The text check proves only that the skill says to check cites. L1 says "every cite shown was checked" but gives the user no step to check one. -> st-plan: add to L1 a by-hand step: for each cite, `sed -n '<line>p' '<file>'` and `git cat-file -t <sha>`, all match.
F4. quickstart.md:113 US1 scenario 1 (`partly built`) has no live row that can fail. L2 accepts `partly built` or `obsolete`, and #15 is fully built on this branch when L2 runs. -> st-plan: pin L2 to one verdict and add a row with an issue that is partly built.
F5. contracts/triage.md:73-75 "A path inside the repo" is not defined. A path from issue text such as `../x`, `/x` or `~/x` has no rule, so line 78 ("reads no path outside the repo") has no text that enforces it. -> st-plan: define a repo path as relative, with no `..` part and no leading `/` or `~`, and say anything else is not read.
F6. spec.md:63-64, 69-70 The edge cases "gh missing or not signed in" and "the agent changes a file" have text checks only, no live row. -> st-plan, or accept with the note in tasks.md:143-144.
