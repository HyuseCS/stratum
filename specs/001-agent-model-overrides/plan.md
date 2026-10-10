# Implementation Plan: Agent model overrides

**Branch**: `001-agent-model-overrides` | **Date**: 2026-10-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-agent-model-overrides/spec.md`, decisions D10 to D18 in [decisions.md](decisions.md)

## Summary

A project can set the model and effort of each Stratum agent in `.stratum/models.json`. A new
PreToolUse hook on the `Agent` tool (`hooks/st-models.py`) reads the file on every start of a
`stratum:st-*` agent. It rewrites the call's `model` and `effort` through `updatedInput`, or it
denies the start with a message when the file is bad. The plugin ships `templates/models.json`
(D16: `st-build`, `st-debug`, `st-quick`, `st-plan`, `st-fast` on opus, effort high; `st-close`, `st-git`, `st-test` on haiku, effort xhigh). `st-init` writes it into new repos. A new
skill `st-model` edits the file from plain words. `st-status` lists the overrides. The README
documents the file. Research confirmed the hook mechanism on Claude Code 2.1.294 (see
[research.md](research.md) R1).

## Technical Context

**Language/Version**: Python 3 stdlib (hook), Markdown (skills, README), JSON (template, hook registration)

**Primary Dependencies**: Claude Code 2.1.294 hooks API (PreToolUse, `updatedInput`, `permissionDecision: "deny"`). No new packages.

**Storage**: `.stratum/models.json`, per project, per machine, git-ignored

**Testing**: `python3 tests/test_model_hook.py` (unittest, hook run as a subprocess with stdin JSON, same style as `tests/test_git_guard.py`); `bash tests/test_model_files.sh` (grep checks, same style as `tests/test_session_hooks.sh`)

**Target Platform**: Claude Code on Linux, macOS, Windows (wherever `python3` runs; the git guard already needs it)

**Project Type**: Claude Code plugin (hooks, skills, agents, templates)

**Performance Goals**: The hook reads one small JSON file per agent start. No goal beyond the 10 s hook timeout the git guard uses.

**Constraints**: Minimal code, no comments except `ponytail:` markers, no new dependencies, agent frontmatter unchanged (D12)

**Scale/Scope**: 11 agents, 4 models, 5 efforts, 1 hook, 1 new skill, 2 changed skills, 1 template, README

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md`. The gates below come from the repo rules the
orchestrator passed and from the existing code patterns.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a failing test task before its build task | Pass (tasks.md) |
| G2. Minimal code, stdlib only, no new dependency | Pass: one stdlib Python hook, no package |
| G3. No comments in code except `ponytail:` | Pass (task text repeats it) |
| G4. Agent frontmatter unchanged (D12) | Pass: no task touches `agents/*.md` |
| G5. Copy existing patterns (git guard hook, st-shape/st-theme skill) | Pass |
| G6. One source of truth for allowed values (CHK002) | Pass: the hook holds models and efforts, agent names come from `agents/*.md`, a test checks the skill and README against the hook |
| G7. Release: version bump last | Pass: final task bumps `.claude-plugin/plugin.json` to 0.1.26 |

Post-design re-check: all gates still pass. No violations, so Complexity Tracking stays empty.

## Security Notes

These tasks touch an access rule (a PreToolUse hook that can deny and rewrite tool calls), the
data model (a new config file), and contracts (hook I/O, file schema, command).

- **S1. Hook rewrite path (T002, T003).** The hook never sets `permissionDecision` when it
  rewrites. The user's permission rules and mode stay in force. `updatedInput` replaces the whole
  input, so the hook copies every field and changes only `model` and `effort`. A test checks both.
- **S2. Hook deny path (T005).** Deny only for a bad file and only for `stratum:` agents.
  Non-Stratum agents are never read for, never blocked (FR-006). Any exception while reading or
  checking the file becomes a deny, so a crash never falls back silently. A missing `python3`
  still fails open (Claude Code shows a non-blocking hook error). The git guard has the same limit.
- **S3. Untrusted repo content (T002, T005).** The file is git-ignored, but a hostile repo can still
  commit it. Impact is limited: the hook parses it as JSON only, nothing runs, and it accepts only
  the allowlisted models and efforts. The worst case is a cost change (opus, max effort) or blocked
  starts. `st-status` shows the overrides so the user can see them.
- **S4. Cost.** An override can move an agent to a more expensive model or effort. This is the
  feature. `st-model` replies with the new values so every change is visible.
- No secrets, no personal or minors' data, no external service call.

## Project Structure

### Documentation (this feature)

```text
specs/001-agent-model-overrides/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── hook.md           # PreToolUse Agent hook input, rewrite and deny output
│   ├── models-file.md    # .stratum/models.json schema and template
│   └── st-model.md       # /stratum:st-model arguments and replies
└── tasks.md
```

### Source Code (repository root)

```text
hooks/
├── commands.json         # add PreToolUse matcher "Agent" entry
└── st-models.py          # new hook
templates/
└── models.json           # new template (D12, D15, D16)
skills/
├── st-model/SKILL.md     # new skill (D14)
├── st-init/SKILL.md      # gitignore line, new Models step
└── st-status/SKILL.md    # new step 7: overrides
tests/
├── test_model_hook.py    # new: hook, registration, drift checks
└── test_model_files.sh   # new: template, skills, .gitignore grep checks
README.md                 # skills table, project files, Built in, Agents note, Tests
.gitignore                # add .stratum/models.json
.stratum/models.json      # this repo's copy of the template (git-ignored, FR-012)
.claude-plugin/plugin.json # version 0.1.26
```

**Structure Decision**: Plugin layout as it is. One new hook next to `hooks/st-git-guard.py`, one
new skill folder, one new template, two new test files in `tests/`.

## Complexity Tracking

No violations.
