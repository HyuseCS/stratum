---

description: "Task list for Agent model overrides"
---

# Tasks: Agent model overrides

**Input**: Design documents from `/specs/001-agent-model-overrides/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required. Every FR has a test task that fails before its build task.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum`.

**Rules for every code task**: stdlib only, no new dependency, no comments except `ponytail:`
markers, match the style of the file it copies. Do not edit `agents/*.md`, `spec.md` or
`decisions.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 to US5 from spec.md

## Phase 1: Setup

None. The repo already has `tests/`, `hooks/` and `templates/`.

## Phase 2: Foundational

None. US1 is the foundation for the other stories.

---

## Phase 3: User Story 1 - Override an agent's model and effort (Priority: P1) MVP

**Goal**: A Stratum agent start uses the model and effort from `.stratum/models.json`.

**Independent Test**: `python3 tests/test_model_hook.py` passes; quickstart section 2 shows the
rewrite.

### Tests for User Story 1

- [ ] T001 [US1] Create `tests/test_model_hook.py` in the style of `tests/test_git_guard.py`: unittest, the hook path from env `ST_MODELS_HOOK` or `../hooks/st-models.py`, a temp project folder per test, the hook run as a subprocess with stdin `{"cwd", "tool_name": "Agent", "tool_input": {...}}`, exit code 0 asserted. Tests (FR-001, FR-002, FR-003, FR-006): (a) `{"st-close": {"model": "haiku"}}` and `subagent_type: "stratum:st-close"` gives `updatedInput.model == "haiku"` and adds no `effort`; (b) `{"st-validate": {"effort": "high"}}` gives `effort == "high"` and keeps the call's `model` as it was (or absent); (c) a call with `model: "sonnet"` and a file with `haiku` gives `haiku`; (d) `updatedInput` equals the input `tool_input` with only `model`/`effort` changed, including an extra field `"foo": 1` and `run_in_background`; (e) the rewrite output has `hookEventName: "PreToolUse"` and no `permissionDecision` key; (f) missing file, no entry for the agent, and entry `{}` each give empty stdout; (g) `cwd` in a subfolder `deep/er` still finds `<project>/.stratum/models.json`; (h) run, change the file to `opus`, run again: the second output says `opus`; (i) `subagent_type` `"Explore"` and bare `"st-close"` with a valid file listing `st-close` give empty stdout; (j) `hooks/commands.json` has a `PreToolUse` entry with `matcher` `"Agent"` whose command is `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-models.py"`. Run it and confirm it fails because the hook does not exist.

### Implementation for User Story 1

- [ ] T002 [P] [US1] Create `hooks/st-models.py` (stdlib Python 3, `#!/usr/bin/env python3`, `main()` under `if __name__ == "__main__":`) per `specs/001-agent-model-overrides/contracts/hook.md` steps 1 to 4, 6 and 7: bad stdin or `subagent_type` not starting with `stratum:` gives no output and no file read; find the project by walking up from `cwd` to the first folder with `.stratum/` or `.git` (copy the loop in `guard_file` from `hooks/st-git-guard.py`); missing `.stratum/models.json` gives no output; no entry or `{}` gives no output; else print `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": {**tool_input, **entry}}}` with no `permissionDecision`. Define `MODELS = ["sonnet", "opus", "haiku", "fable"]`, `EFFORTS = ["low", "medium", "high", "xhigh", "max"]` and `AGENTS` = sorted file names without `.md` in `<dir of this file>/../agents/` at module level. Security: see plan.md S1, S3.
- [ ] T003 [P] [US1] In `hooks/commands.json`, add a second object to the `PreToolUse` array after the `Bash` one: `{"matcher": "Agent", "hooks": [{"type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/st-models.py\"", "timeout": 10}]}`. Keep every other entry as it is.

**Checkpoint**: After T002 and T003, run `python3 tests/test_model_hook.py`: all US1 tests pass. A valid file changes Stratum agent starts. Bad files are not checked yet.

---

## Phase 4: User Story 2 - A bad file stops with a clear error (Priority: P1)

**Goal**: Any bad file blocks every Stratum agent start with a message that names the bad item and
the allowed values.

**Independent Test**: `python3 tests/test_model_hook.py` passes, deny cases included.

### Tests for User Story 2

- [ ] T004 [US2] Add to `tests/test_model_hook.py` (FR-004, FR-005, FR-006). Deny cases, each started as `stratum:st-close`, each asserting `permissionDecision == "deny"`, a reason that contains `.stratum/models.json` and `Fix the file`, and the texts from the table in `specs/001-agent-model-overrides/contracts/hook.md`: (a) `not json` gives `cannot be read`; (b) `["st-close"]` gives `must be a JSON object`; (c) `{"st-closee": {}}` names `st-closee` and all 11 agents; (d) `{"st-close": "haiku"}` names `st-close`, `model`, `effort`; (e) `{"st-close": {"modle": "haiku"}}` names `modle`; (f) `{"st-close": {"model": "gpt"}}` names `gpt` and the 4 models; (g) `{"st-close": {"effort": "huge"}}` names `huge` and the 5 efforts; (h) `{"st-close": {"model": 1}}` is denied; (i) a folder at `.stratum/models.json` gives `cannot be read`. Also: (j) `{"st-close": {}, "st-git": {"model": "gpt"}}` blocks a `stratum:st-close` start; (k) a file with two problems names both; (l) `Explore` with `not json` in the file gives empty stdout. Module checks (load the hook with `importlib.util.spec_from_file_location`): `AGENTS` equals exactly `st-build, st-check, st-close, st-debug, st-fast, st-git, st-plan, st-quick, st-review, st-test, st-validate` and equals the file names in `agents/*.md`; `MODELS == ["sonnet", "opus", "haiku", "fable"]`; `EFFORTS == ["low", "medium", "high", "xhigh", "max"]`. Run it and confirm the deny tests fail.

### Implementation for User Story 2

- [ ] T005 [US2] In `hooks/st-models.py`, add contract step 5: read and check the whole file before the entry lookup. Problems, one line each, per `specs/001-agent-model-overrides/contracts/hook.md`: "not valid JSON or not readable" (any exception other than `FileNotFoundError` while reading), "top level not an object", "unknown agent" (not in `AGENTS`), "entry not an object", "unknown key" (not `model` or `effort`), "unknown model" (not in `MODELS`, any non-string included), "unknown effort" (not in `EFFORTS`). Any problem, or any other exception while checking, prints `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "<project>/.stratum/models.json: <problems>\nFix the file, then run the step again."}}`. Non-`stratum:` agents still return before the file is read. Run `python3 tests/test_model_hook.py`: all pass. Security: see plan.md S2.

**Checkpoint**: US1 and US2 together are the MVP. The hook is complete.

---

## Phase 5: User Story 3 - New repos get the default model setup (Priority: P2)

**Goal**: `st-init` writes the template (8 entries, D16) into new repos and git-ignores it. This repo gets its copy.

**Independent Test**: `bash tests/test_model_files.sh` passes; quickstart sections 3 and 5.1.

### Tests for User Story 3

- [ ] T006 [US3] Create `tests/test_model_files.sh` in the style of `tests/test_session_hooks.sh` (`set -u`, `root`, `tmp` with `trap`, `check name 'cmd'`, `exit $fail`). Checks (FR-007, FR-008, FR-012): (a) `templates/models.json` parses with `python3 -c` and equals exactly `{"st-build": {"model": "opus", "effort": "high"}, "st-debug": {"model": "opus", "effort": "high"}, "st-quick": {"model": "opus", "effort": "high"}, "st-plan": {"model": "opus", "effort": "high"}, "st-fast": {"model": "opus", "effort": "high"}, "st-close": {"model": "haiku", "effort": "xhigh"}, "st-git": {"model": "haiku", "effort": "xhigh"}, "st-test": {"model": "haiku", "effort": "xhigh"}}`; (b) copy the template to `$tmp/proj/.stratum/models.json`, pipe `{"cwd": "$tmp/proj", "tool_name": "Agent", "tool_input": {"subagent_type": "stratum:st-git", "prompt": "p", "description": "d"}}` into `python3 "$root/hooks/st-models.py"`: output has `"model": "haiku"` and `"effort": "xhigh"` and no `deny`, and the same input with `stratum:st-quick` gives `"model": "opus"` and `"effort": "high"`; (c) `skills/st-init/SKILL.md` step 2 lists `.stratum/models.json`; (d) `skills/st-init/SKILL.md` contains `Change the model or effort for any agent?`, `templates/models.json` and `agents/*.md`; (e) `skills/st-init/SKILL.md` still says `/stratum:st-status` steps 4 and 5; (f) `grep -qx '.stratum/models.json' "$root/.gitignore"`. Run it and confirm it fails.

### Implementation for User Story 3

- [ ] T007 [P] [US3] Create `templates/models.json` with exactly `{"st-build": {"model": "opus", "effort": "high"}, "st-debug": {"model": "opus", "effort": "high"}, "st-quick": {"model": "opus", "effort": "high"}, "st-plan": {"model": "opus", "effort": "high"}, "st-fast": {"model": "opus", "effort": "high"}, "st-close": {"model": "haiku", "effort": "xhigh"}, "st-git": {"model": "haiku", "effort": "xhigh"}, "st-test": {"model": "haiku", "effort": "xhigh"}}`, one entry per line, two-space indent, in this key order (8 entries, D16; no entry for `st-check`, `st-review`, `st-validate`).
- [ ] T008 [P] [US3] Edit `skills/st-init/SKILL.md`: add `.stratum/models.json` to the step 2 list. Insert a new step 4 after step 3 (Git guard) and renumber old steps 4 to 10 as 5 to 11 (step 9's pointer to `/stratum:st-status` steps 4 and 5 stays as it is): **Models.** If `.stratum/models.json` is missing, ask one question, "Change the model or effort for any agent?", default no. No: copy `<plugin root>/templates/models.json` to `.stratum/models.json`. Yes: ask for the changes, apply them to the template with the rules of `/stratum:st-model` (allowed values, `default` forms), then write it. Then show a table of the 11 agents: the default model from the `model:` line in `<plugin root>/agents/*.md`, and the model and effort from the file where set. Say how to change it later: `/stratum:st-model`, plain words such as "make st-close use opus", or edit the file. If the file exists, skip the question and change nothing. Do not add the file to the step 11 commit list (it is git-ignored).
- [ ] T009 [P] [US3] Add the line `.stratum/models.json` to `.gitignore`. Create `.stratum/models.json` as a copy of `templates/models.json` (FR-012). Do not stage or commit `.stratum/models.json`; confirm with `git check-ignore .stratum/models.json`.

**Checkpoint**: After T007, T008 and T009, run `bash tests/test_model_files.sh`: all pass. New repos and this repo get the template setup.

---

## Phase 6: User Story 4 - Change a model by asking in plain words (Priority: P2)

**Goal**: `/stratum:st-model` changes one entry from plain words.

**Independent Test**: `bash tests/test_model_files.sh` and `python3 tests/test_model_hook.py`
pass; quickstart sections 5.2 to 5.4.

### Tests for User Story 4

- [ ] T010 [US4] Add to `tests/test_model_files.sh` (FR-009): `skills/st-model/SKILL.md` exists; its frontmatter has `name: st-model`; its `description` line contains `make st-close use opus` and `effort`; the body contains `.stratum/models.json`, `model default`, `effort default`, `Never overwrite`, `Keep every other`, and `templates/models.json` (the missing-file case, D17). Run it and confirm the new checks fail.
- [ ] T011 [P] [US4] Add to `tests/test_model_hook.py` (CHK002 drift): load the hook with `importlib.util.spec_from_file_location`; assert every value in `AGENTS`, `MODELS` and `EFFORTS` appears in `skills/st-model/SKILL.md` wrapped in backticks (for example `` `max` ``), so words like `ui-ux-pro-max` or `follow` cannot satisfy it. Run it and confirm it fails.

### Implementation for User Story 4

- [ ] T012 [US4] Create `skills/st-model/SKILL.md` per `specs/001-agent-model-overrides/contracts/st-model.md`, in the style of `skills/st-shape/SKILL.md`: frontmatter `name: st-model` and a `description` that names model, effort, Stratum agent, `.stratum/models.json` and the examples "make st-close use opus", "put st-test on high effort", "put st-close back on its default"; heading `# /stratum:st-model <agent> <value>...`; numbered steps 1 to 6 from the contract, with the full lists of the 11 agents, 4 models and 5 efforts written out, "Never overwrite" for a bad file, "Keep every other entry and key", "file missing: start from templates/models.json" (copy `<plugin root>/templates/models.json`, then apply the change, D17; say the template was copied and list its entries), and the one-line reply. Arguments follow D18 (`<agent> <value>...`). Run both test files: all pass.

**Checkpoint**: Users can change entries without editing JSON.

---

## Phase 7: User Story 5 - See the overrides (Priority: P3)

**Goal**: `st-status` lists the overrides.

**Independent Test**: `bash tests/test_model_files.sh` passes; quickstart section 5.5.

### Tests for User Story 5

- [ ] T013 [US5] Add to `tests/test_model_files.sh` (FR-010): `skills/st-status/SKILL.md` has a step `7.` that contains `.stratum/models.json` and `plugin defaults`; its step `4.` is still `**Tools:**`; its `description` mentions `model overrides`. Run it and confirm the new checks fail.

### Implementation for User Story 5

- [ ] T014 [US5] Edit `skills/st-status/SKILL.md`: add `model overrides` to the `description` list. Add step 7 after step 6: **Model overrides:** from `<project>/.stratum/models.json`, list each agent in the file with its model and effort; for a key the entry does not set, show the default (model from the `model:` line in `<plugin root>/agents/<agent>.md`, effort `default`). Say the values come from `.stratum/models.json` and change with `/stratum:st-model` or by editing the file. No file: say every agent uses the plugin defaults. A bad file: say so and quote the problem; Stratum agents will not start until it is fixed. Do not renumber steps 1 to 6. Run `bash tests/test_model_files.sh`: all pass.

**Checkpoint**: All stories done.

---

## Phase 8: Polish and release

- [ ] T015 Add to `tests/test_model_hook.py` (FR-011, CHK002): `README.md` contains `.stratum/models.json`, `templates/models.json`, `st-model`, `CLAUDE_CODE_EFFORT_LEVEL`, every value in the hook's `AGENTS`, `MODELS` and `EFFORTS` wrapped in backticks (plain `max`, `low`, `opus` already appear inside other README words), `python3 tests/test_model_hook.py` and `bash tests/test_model_files.sh`. Run it and confirm it fails.
- [ ] T016 Edit `README.md` in five places, matching the plain style there: (1) the Skills table: a row `st-model <agent> <value>...` | "Set an agent's model or effort for this project. Plain words work too: \"make st-close use opus\"."; (2) the Project files tree: `models.json         agent model and effort overrides (git-ignored, per machine)`; (3) Built in: a **Model overrides** item after **Git guard**: the file shape (agent name to optional `model` and `effort`), the allowed agents (the 11), models (`sonnet`, `opus`, `haiku`, `fable`) and efforts (`low`, `medium`, `high`, `xhigh`, `max`), that `st-init` writes `templates/models.json` (`st-build`, `st-debug`, `st-quick`, `st-plan`, `st-fast` on opus, effort high; `st-close`, `st-git`, `st-test` on haiku, effort xhigh; no entry for `st-check`, `st-review`, `st-validate`), that a hook applies it on every Stratum agent start and the next start picks up an edit, that a bad file blocks every Stratum agent start with a message, that only Stratum agents are affected, that `CLAUDE_CODE_EFFORT_LEVEL` beats the file's effort, and how to change an entry (`/stratum:st-model`, plain words, or edit the file); (4) under the Agents table: one line that the Model column is the plugin default and `st-init`'s template runs `st-build`, `st-debug`, `st-quick`, `st-plan`, `st-fast` on Opus with effort high and `st-close`, `st-git`, `st-test` on Haiku with effort xhigh; (5) the Tests block: add `python3 tests/test_model_hook.py` and `bash tests/test_model_files.sh`. Run `python3 tests/test_model_hook.py`: all pass.
- [ ] T017 Run `specs/001-agent-model-overrides/quickstart.md` sections 1 to 4. Report each result. Section 4 (end to end with `claude -p --plugin-dir`) must show a Haiku model in the subagent transcript and a blocked start for the bad file. If it cannot run, report the exact blocker.
- [ ] T018 In `.claude-plugin/plugin.json`, change `"version": "0.1.25"` to `"version": "0.1.26"`. Commit it alone as "Bump version to 0.1.26", like `47d7a38`.

---

## Dependencies and Execution Order

- US1 (T001 to T003) first. T002 and T003 run in parallel after T001.
- US2 (T004, T005) after US1: same two files.
- US3 after US2: check (b) in T006 runs the finished hook. T007, T008, T009 run in parallel after T006.
- US4 after US3: T010 edits `tests/test_model_files.sh` after T006. T011 runs in parallel with T010.
- US5 after US4: T013 edits `tests/test_model_files.sh` after T010.
- Polish: T015 after T011 (same file), T016 after T015, T017 after all, T018 last.

`tests/test_model_hook.py` order: T001, T004, T011, T015. `tests/test_model_files.sh` order:
T006, T010, T013. `hooks/st-models.py` order: T002, T005.

## Parallel Examples

```text
After T001:  T002 (hooks/st-models.py)  |  T003 (hooks/commands.json)
After T006:  T007 (templates/models.json)  |  T008 (skills/st-init/SKILL.md)  |  T009 (.gitignore, .stratum/models.json)
US4 tests:   T010 (tests/test_model_files.sh)  |  T011 (tests/test_model_hook.py)
```

US5's T014 (`skills/st-status/SKILL.md`) and US4's T012 (`skills/st-model/SKILL.md`) touch
different files and can run in parallel once T010, T011 and T013 exist.

## Implementation Strategy

1. MVP: US1 + US2 (T001 to T005). The hook works with a hand-written file.
2. US3: the template, `st-init`, and this repo's file.
3. US4: `st-model`.
4. US5: `st-status`.
5. Polish: README, quickstart run, version bump.

## Notes

- Security notes for T002, T003, T005 are in plan.md, Security Notes.
- Commit after each task or story through the commit guard. Never stage `.stratum/models.json`.
