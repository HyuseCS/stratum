# Implementation Plan: Merge Check and Validate into Inspect

**Branch**: `002-merge-check-validate` | **Date**: 2026-10-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-merge-check-validate/spec.md`, GitHub issue
HyuseCS/stratum #10, grilling decisions G1 to G4 in the spec.

## Summary

One agent, `st-inspect`, replaces `st-check` and `st-validate`. It runs the cross-artifact
analysis (`procedures/analyze.md`) and the four validate checks in one pass, on opus with Read,
Grep, Glob, Bash and Edit. It writes only the `## Validate` section of `plan.md`. One skill,
`/stratum:st-inspect`, replaces `/stratum:st-check`: it starts the one agent, sets `phase` to
`inspect`, and its advisor step asks for improvements as well as risks. The build creates the new
agent and skill first, a test confirms each kept capability (C1-C10, V1-V6, S1-S6) by an exact
phrase, and only then the old agents and skill are deleted. Every reference is renamed, the agent
list drops to 10, and the version goes to 0.1.27. `hooks/st-models.py` needs no change: it reads
the agent list from `agents/*.md` (`hooks/st-models.py:8-9`).

## Technical Context

**Language/Version**: Markdown (agents, skills, docs), Bash 5.3.20 (new test), Python 3.14.7 (existing hook tests), JSON (`plugin.json`)

**Primary Dependencies**: Claude Code 2.1.294 plugin layout (`agents/*.md`, `skills/*/SKILL.md`). git 2.56.0 (`git grep -w`). No new packages.

**Storage**: N/A. `.stratum/state.json` `phase` takes the value `inspect` instead of `check`.

**Testing**: `bash tests/test_inspect.sh` (new, `check()` style of `tests/test_model_files.sh`); `python3 -m unittest tests/test_model_hook.py`; `bash tests/test_model_files.sh`

**Target Platform**: Claude Code on Linux, macOS, Windows

**Project Type**: Claude Code plugin (agents, skills, hooks, docs)

**Performance Goals**: The Inspect phase starts 1 agent instead of 2 (SC-001).

**Constraints**: No comments in code except `ponytail:` markers. Minimal diff. No new dependency. `procedures/analyze.md` and `hooks/st-models.py` unchanged.

**Scale/Scope**: 2 new files, 3 deleted files, 10 edited files (7 skills, README, DESIGN, `plugin.json`), 1 new test, 2 edited tests, 10 agents.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md`. The gates come from the repo rules the orchestrator
passed, the user's ordering decision and the patterns of feature 001.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a test that can fail, before its build task | Pass: T001, T005, T008, T009 come before their build tasks. Each check has a stated negative control (contracts/st-inspect.md, quickstart section 2) |
| G2. Build first, delete after (user decision, spec G2) | Pass: T002-T003 create, T007 runs the capability checks and their controls, T010 deletes |
| G3. Minimal diff, no new dependency, no comments | Pass: Markdown edits, one Bash test, no package |
| G4. One source of truth for the agent list | Pass: the hook reads `agents/*.md`. `test_module_constants` pins the 10 names |
| G5. A text check asserts a phrase the file must contain (lessons L1) | Pass: the phrase table in contracts/st-inspect.md. No phrase is shared by two items |
| G6. Release: version bump last | Pass: T021 |

Post-design re-check: all gates pass. No violations, so Complexity Tracking stays empty.

## Security Notes

These tasks touch an access rule (the write limit of an agent), the tool set of an agent, and a
contract (the model file's allowed agent names).

- **S1. Wider tools (T002, CHK013).** The analysis part ran read-only before (Read, Grep, Glob).
  Now it runs inside an agent with Bash and Edit. Nothing sandboxes the agent. The only guards are
  its instructions (`Never` section: edit nothing except the `## Validate` section of `plan.md`,
  install nothing, run no migration, change no config, no `git add` or `git commit`) and the
  orchestrator's `git status --porcelain` and `git diff` check after it returns (T003, S1 of the
  spec). That check runs after the fact. A change outside `plan.md` is a finding, and the
  orchestrator reverts it with the user. This is the same guard the old `st-validate` had.
- **S2. Model file names (T009, T010).** After the delete, a `.stratum/models.json` that names an
  old agent blocks every Stratum agent start with "unknown agent" and the 10 names (FR-010, no
  special case). This is a breaking change for hand-edited files. Recovery: rename the entry to
  `st-inspect` or drop it. The version bump commit message says so (T021). The template names
  neither old agent (`templates/models.json`).
- **S3. Cost.** `st-inspect` runs on opus. The old analysis ran on sonnet. One opus start replaces
  one sonnet start plus one opus start.
- No secrets, no personal or minors' data, no external service, no sign-in.

## Breaking Changes

- `/stratum:st-check` is gone. Users call `/stratum:st-inspect`.
- `stratum:st-check` and `stratum:st-validate` subagent types are gone.
- A model file entry for either old agent blocks every Stratum agent start (S2).
- `phase: check` in a project's `state.json`: `/stratum:st-build` warns once (order check
  expects `inspect` or `build`) and runs. `/stratum:st-inspect` also warns once and runs.
- Rollback: revert the feature's commits. No stored data migrates.

## Project Structure

### Documentation (this feature)

```text
specs/002-merge-check-validate/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── st-inspect.md     # agent and skill contract, phrase table, rename table
└── tasks.md
```

### Source Code (repository root)

```text
agents/
├── st-inspect.md         # new: merged agent
├── st-check.md           # delete
└── st-validate.md        # delete
skills/
├── st-inspect/SKILL.md   # new: phase skill
├── st-check/             # delete
├── st/SKILL.md           # Full lane list
├── st-full/SKILL.md      # description and step 3
├── st-plan/SKILL.md      # next phase
├── st-build/SKILL.md     # order check
├── st-status/SKILL.md    # next gate, hook probe
├── st-model/SKILL.md     # agent list, hook probe
└── st-init/SKILL.md      # "10 agents"
tests/
├── test_inspect.sh       # new
├── test_model_hook.py    # 10 names, st-inspect in place of the old name
└── test_model_files.sh   # hook probe
README.md                 # phase row, skills row, agent table, model note, test list
DESIGN.md                 # D7 agent table, D9 skills row, Full lane row
.claude-plugin/plugin.json # version 0.1.27
```

**Structure Decision**: Plugin layout as it is. One new agent file, one new skill folder, one new
test next to `tests/test_model_files.sh`.

## Complexity Tracking

No violations.
