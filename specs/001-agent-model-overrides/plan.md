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
  input, so the hook copies every field of `tool_input` and takes only `model` and `effort` from
  the entry, never other keys (so a file entry cannot replace `prompt` or `subagent_type`). Tests
  check all three.
- **S2. Hook deny path (T005).** Deny only for a bad file and only for `stratum:` agents.
  Non-Stratum agents are never read for, never blocked (FR-006). Any exception while reading or
  checking the file becomes a deny, so a crash never falls back silently. A missing `python3`
  still fails open (Claude Code shows a non-blocking hook error). The git guard has the same limit.
- **S3. Untrusted repo content (T002, T005).** The file is git-ignored, but a hostile repo can still
  commit it. Impact is limited: the hook parses it as JSON only, nothing runs, and it accepts only
  the allowlisted models and efforts. The worst case is a cost change (opus, max effort) or blocked
  starts. `st-status` shows the overrides so the user can see them. The deny reason quotes each
  bad key or value with `json.dumps` and cuts it to 80 characters, so file content cannot flood
  or inject text into the model's context.
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
DESIGN.md                 # st-model in the D9 skills table, new D19 model hook entry
.gitignore                # add .stratum/models.json
.stratum/models.json      # this repo's copy of the template (git-ignored, FR-012)
.claude-plugin/plugin.json # version 0.1.26
```

**Structure Decision**: Plugin layout as it is. One new hook next to `hooks/st-git-guard.py`, one
new skill folder, one new template, two new test files in `tests/`.

## Complexity Tracking

No violations.

## Validate

Date: 2026-10-10. Verdict: CONDITIONAL

st-check F1 to F5 are not repeated here.

| Check | Verdict | Findings |
|-------|---------|----------|
| Setup and dependencies | PASS | python3 3.14.7, bash 5.3.20, node v24.14.1, Claude Code 2.1.294, git 2.56.0. `python3 tests/test_git_guard.py` (24 OK), `bash tests/test_session_hooks.sh`, `bash tests/test_statusline.sh`, `node tests/test_token_weather.mjs` all exit 0. `claude plugin validate .claude-plugin/plugin.json` passes. No new package. |
| Test coverage per requirement | CONCERN | Each FR has a test task. The hook tests can fail on wrong code. Gaps: F3, F4, F5, F6. |
| Breaking changes | CONCERN | The st-init renumber is safe: the only step pointer in skills, agents and README is `skills/st-init/SKILL.md:50` (st-status steps 4 and 5, which do not change). Repos with no `.stratum/models.json` get no hook output. A missing `python3` fails the same way as the git guard, which already runs on every Bash call. No stored data migrates. Rollback: revert the commits or delete the file. Gaps: F2, F7, F8. |
| Security and privacy | CONCERN | No secrets, no personal data, no network. The rewrite has no `permissionDecision` (S1). Gaps: F1, F9. |

F1. tasks.md:49 (Security) T002 builds `updatedInput` as `{**tool_input, **entry}`. A committed `.stratum/models.json` with `{"st-close": {"prompt": "...", "subagent_type": "..."}}` can then rewrite the whole agent call. Only the T005 check stops this. -> In T002, copy only the allowed keys: `{**tool_input, **{k: entry[k] for k in ("model", "effort") if k in entry}}`. In T004 (tasks.md:65), add a case with a `prompt` key that asserts deny and no `updatedInput`.

F2. contracts/st-model.md:34 (Breaking) Repos set up before 0.1.26 have no `.stratum/models.json` line in `.gitignore`. When `st-model` copies the template there (D17), the file is untracked and can be committed. This breaks D13. -> Step 3 and T012 (tasks.md:109) also add the `.gitignore` line if it is missing. T010 greps the skill for `.gitignore`.

F3. tasks.md:137 (Coverage, user decides) FR-008, FR-009 and FR-010 (st-init, st-model, st-status) have only grep checks (T006, T010, T013). US3 scenarios 2 and 3 (the "yes" path, and an existing file that is kept) have no check of any kind. Quickstart section 5 is the only behavior check, and T017 runs sections 1 to 4 only. -> Choose one: T017 also runs section 5, or T017 gives section 5 to the user as exact manual steps. Add a step for US3 scenarios 2 and 3 to section 5.

F4. tasks.md:45 (Coverage) T001(h) cannot fail. Each hook call is a new process, so the hook always reads the file again. -> Do not count (h) as proof of FR-002 or SC-003. The design guarantees it, and quickstart section 4 is the live check.

F5. tasks.md:45 (Coverage) The Agent tool's `subagent_type` is optional in 2.1.294 (the binary has `subagent_type:o().optional().describe("The type of specialized agent to use for this task")`). A hook that calls `None.startswith` crashes on every general-purpose agent start and shows a hook error. No test covers this. -> Add a T001 case with no `subagent_type`: exit 0, empty stdout.

F6. tasks.md:83 (Coverage) T006(c) "step 2 lists `.stratum/models.json`" passes on a whole-file grep, because the new step 4 contains that path. -> Grep only the step 2 block, for example `sed -n '/Git ignore/,/^3\./p' "$f" | grep -q 'models.json'`.

F7. research.md:91 (Breaking, user decides) R8 says a worktree finds the same file. A linked git worktree has `.stratum/` (because `state.json` is tracked) but no git-ignored `models.json`. The walk stops at the worktree root, so overrides do not apply there, and nothing tells the user. No agent uses `isolation: worktree`, so only sessions started inside a worktree are affected. `git-guard.json` behaves the same way. -> Accept this and fix the R8 text, or document the limit in the README.

F8. DESIGN.md:76 (Breaking, user decides) Commit cc6ccf4 (git guard per repo) updated DESIGN.md together with README. This plan changes README only. The D9 skills table ("Fourteen entry skills") and the hooks part near D17 (DESIGN.md:188) will be out of date. -> Add `st-model` and the Agent hook to DESIGN.md in T016, or confirm that FR-011 means README only.

F9. tasks.md:69 (Security) The deny reason quotes keys and values from a file in the repo into the model's context. A hostile repo can use this to inject a prompt. The risk is small, because the model already reads repo text such as CLAUDE.md. -> In T005, quote each bad item with `json.dumps` and limit it to about 80 characters.
