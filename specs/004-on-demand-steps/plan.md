# Implementation Plan: Run Stratum Steps On Demand

**Branch**: `013-agent-skills` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-on-demand-steps/spec.md`, decisions D1 to D4 in
[decisions.md](decisions.md), GitHub issue #13, items I1 and I2.

## Summary

Four thin skills, `st-review`, `st-test`, `st-debug` and `st-git`, start the agent of the same name
on demand. Each fills a missing feature from `.stratum/state.json` and a missing range with
`main..HEAD`, then runs the check the orchestrator runs after that agent in a lane (research R10).
The agent files do not change. Three read-only agents, `st-impeccable`, `st-ponytail-audit` and
`st-ponytail-debt`, run their skill in the background with no Edit or Write tool. Impeccable runs
`audit` only (research R7). A background paragraph in the session-start `Stratum rule` routes "in
the background" requests and refuses the rest (research R9). `st-handoff` runs as a background fork
mid-session, and in the main session when the user says they are done or is ending the session. One
fork runs at a time, and the main session writes the handoff when the fork writes no file or cannot
start. A new test,
`tests/test_on_demand.sh`, checks each FR by phrase and by file structure, including an
agent-without-command check that names the agent. Docs and the tests that pin the agent list go
from 10 to 13 agents. No hook code changes: `hooks/st-models.py` reads `agents/*.md`.

## Technical Context

**Language/Version**: Markdown (skills, agents, docs), Bash 5.3 (hook line, new test), Python 3.14 (one existing test edit)

**Primary Dependencies**: Claude Code 2.1.296 plugin layout (`agents/*.md`, `skills/*/SKILL.md`), Agent tool `subagent_type: "fork"` (research R4), impeccable engine 0.1.11 launcher (`skills/st-impeccable/scripts/VERSION`). No new package.

**Storage**: N/A. Reads `feature_directory` from `.stratum/state.json`. Writes nothing new.

**Testing**: `bash tests/test_on_demand.sh` (new, `check()` style of `tests/test_inspect.sh`); existing `tests/test_inspect.sh`, `tests/test_model_files.sh`, `tests/test_session_hooks.sh`, `python3 -m unittest tests/test_model_hook.py`; `claude plugin validate .claude-plugin/plugin.json`

**Target Platform**: Claude Code on Linux, macOS, Windows

**Project Type**: Claude Code plugin (agents, skills, hooks, docs)

**Performance Goals**: SC-003: the main session answers the next message while a background audit or the handoff fork runs.

**Constraints**: No comments in code except `ponytail:` markers. Minimal diff. No new dependency. `hooks/st-models.py`, `hooks/st-phase.py` and the 4 existing agent files unchanged. Background agents have no Edit or Write tool.

**Scale/Scope**: 4 new skills, 3 new agents, 1 new test. Edits: `hooks/st-session-start.sh`, `skills/st-handoff/SKILL.md`, `skills/st-model/SKILL.md`, `skills/st-init/SKILL.md`, `skills/st-build/SKILL.md`, `skills/st-fast/SKILL.md`, `skills/st-quick/SKILL.md` (agent wording only), `README.md`, `DESIGN.md`, `tests/test_inspect.sh`, `tests/test_model_hook.py`. 13 agents.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md`. The gates come from the repo rules the orchestrator
passed and `docs/lessons.md`.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that fails before its build task | Pass: T001 before T002 (FR-001 to FR-005), T003 before T004 (FR-006, FR-007), T005 before T006 (FR-008), T007 before T008 (FR-009). Red states in quickstart section 1 |
| G2. Minimal diff, no new dependency, no comments | Pass: Markdown, one hook string, one Bash test, two test edits |
| G3. One source of truth for the agent list | Pass: the hook reads `agents/*.md`. Docs follow the pinned tests (research R12) |
| G4. A text check asserts a phrase the file builds (lessons L1) | Pass: phrase tables in the contracts. The FR-008 check reads the hook's output, not its source |
| G5. Tasks that share one test or one repo-wide check are one task (L6) | Pass: T002, T004 each build every file their checks read. No `[P]` build task shares `tests/test_on_demand.sh` |
| G6. A check between two lists reads both sides (L7) | Pass with a note: README checks are two-way already. FR-005 is one-way by the spec (a skill may have no agent) |
| G7. Test runs leave no files (L8) | Pass: `PYTHONDONTWRITEBYTECODE=1` in every run, `git status --porcelain` in T010 |
| G8. Each new check has a negative control (L2) | Pass: T009, quickstart section 2 |
| G9. Inspect skipped by the user: setup and coverage checks live in the plan | Pass: T009 (controls), T010 (all tests, plugin validate, live steps) |

Post-design re-check: all gates pass. No violations, so Complexity Tracking stays empty.

## Security Notes

- **S1. `/stratum:st-git` commits on demand (T002).** The git guard still applies (`commit` mode
  `ask` by default). The file list comes from the user or from the user's pick of
  `git status --porcelain --untracked-files=all`. The agent stages each path by name and never
  stages `.env` files, secrets, keys, `graphify-out/` or `.stratum/handoff.md`
  (`agents/st-git.md:41-42`). The check shows `git log -1 --name-only` so a wrong file is seen at
  once. Push only on the user's "push".
- **S2. `st-impeccable` has Bash and an external download (T004).** It needs Bash for
  `impeccable context` and `impeccable detect` (research R8). On first use the launcher downloads
  the engine from `github.com/pbakaus/impeccable/releases` into `~/.impeccable/bin/<version>/`
  with a sha256 check. That is outside the working tree. Nothing sandboxes Bash. The guards: the
  `## Never` lines, no Edit or Write tool, and the orchestrator's `git rev-parse HEAD` and
  `git status --porcelain --untracked-files=all` before and after (T006; review commit 94e827c
  added HEAD and the untracked flag). That check does not see git-ignored paths (`.env`,
  `.stratum/models.json`). The ponytail agents have no Edit, Write or Bash, so their tool list
  stops writes and network use. `st-impeccable` keeps Bash, so for it the before and after check
  and its `## Never` lines are the guards.
- **S3. The handoff fork has the whole conversation and every tool (T008).** A fork inherits the
  conversation. The fork type's definition gives it `tools: ["*"]` and `permissionMode: "bubble"`
  (permission asks go to the user; research R4). The skill sets neither. It writes `.stratum/handoff.md`, which is git-ignored, as the main session does today. Any
  secret pasted in the conversation could reach that file, the same as today.
- **S4. Model file names (T004).** `.stratum/models.json` accepts the 3 new agent names. Existing
  files stay valid. No other contract changes.
- No sign-in, no personal or minors' data, no access rules.

## Breaking Changes

- None for stored data or existing files. A `.stratum/models.json` written before still passes.
- The agent count in docs and tests goes from 10 to 13 (research R12).
- Risk: a lane step that says "`st-git` (`stratum:st-git`) commits" could now reach the
  `st-git` skill. Commit 7323230 changed the lane steps to say "the `st-git` agent", and Close
  changed the last one, `skills/st-build/SKILL.md:22`. With a file list the `st-git` skill passes
  the list through and starts the same agent, so the result is the same plus the log check.
- Rollback: revert the feature's commits.

## Project Structure

### Documentation (this feature)

```text
specs/004-on-demand-steps/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
├── contracts/
│   ├── commands.md       # the 4 skills: text and phrase table
│   └── background.md     # the 3 agents, the session rule, the handoff section
└── tasks.md
```

### Source Code (repository root)

```text
skills/
├── st-review/SKILL.md    # new (US1)
├── st-test/SKILL.md      # new (US1)
├── st-debug/SKILL.md     # new (US1)
├── st-git/SKILL.md       # new (US1)
├── st-handoff/SKILL.md   # fork or main session (US3)
├── st-model/SKILL.md     # 13 agents (US2)
├── st-init/SKILL.md      # "13 agents" (US2)
├── st-build/SKILL.md     # "agent" wording in lane steps (7323230)
├── st-fast/SKILL.md      # same
└── st-quick/SKILL.md     # same
agents/
├── st-impeccable.md      # new (US2)
├── st-ponytail-audit.md  # new (US2)
└── st-ponytail-debt.md   # new (US2)
hooks/st-session-start.sh # background rule (US2)
tests/
├── test_on_demand.sh     # new
├── test_inspect.sh       # 13 agents, st-init phrase
└── test_model_hook.py    # 13 names
README.md                 # skills row, agent rows, model note, background and handoff bullets, test list
DESIGN.md                 # D7 rows, D9 row, D18 handoff
```

**Structure Decision**: Plugin layout as it is. New skills copy the frame of
`skills/st-quick/SKILL.md`. New agents copy the frame of `agents/st-review.md`.

## Complexity Tracking

No violations.
