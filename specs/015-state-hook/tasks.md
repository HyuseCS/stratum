---

description: "Task list for State writes from the hook only"
---

# Tasks: State writes from the hook only

**Input**: Design documents from `specs/015-state-hook/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Requested (FR-011, SC-003). Each test task comes before the task that builds it and must fail first.

**Organization**: One user story (US1). The hook part is one chain (two shared files). The skill-line part runs in parallel.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

- **[P]**: no shared file in the phase and no other task's result; the task ends with `Owns:`
- **[lock]**: none in this feature (every hook test uses its own temp folder)
- **[screen: <mode>]**: none in this feature
- Run every `Test:` command from the repo root. Code gets no explanatory comments; a deliberate shortcut gets a `# ponytail:` marker.

## Phase 1: Setup

None. The hook and the tests use the Python stdlib and Bash only.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Wire `hooks/st-phase.py` to the new events.

- [ ] T001 In `tests/test_phase_hook.py`, change `test_hook_registered` (line 266): exactly one PreToolUse entry has matcher `Skill|Agent` and holds `CMD`; one PostToolUse entry has matcher `Bash|Write|Edit|MultiEdit|Agent` and holds `CMD`; a Stop entry holds `CMD`; the UserPromptSubmit check stays. Run it and see it fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_hook_registered`.
- [ ] T002 In `hooks/commands.json`, widen the PreToolUse `Skill` matcher to `Skill|Agent`, add a PostToolUse entry (matcher `Bash|Write|Edit|MultiEdit|Agent`) and a Stop entry, each `{ "type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/st-phase.py\"", "timeout": 10 }`. Keep the separate `Agent` entry for `st-models.py` as is (contracts/hook.md "Wiring"). Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_hook_registered && python3 tests/test_model_hook.py ModelHookTest.test_hook_registered`.

**Checkpoint**: wiring in place. The hook still returns early on the new events.

---

## Phase 3: User Story 1 - Hook writes (Priority: P1) 🎯 MVP

**Goal**: The hook writes `risk`, `feature_directory`, `phase: done` and `skill: ""` from the signals in [data-model.md](data-model.md), with no output.

**Independent Test**: `python3 tests/test_phase_hook.py` passes, and each negative control goes red when its guard is removed (T011).

All tasks in this phase edit `tests/test_phase_hook.py` or `hooks/st-phase.py`: they run in order.

The marker patterns are built once, in their final form (data-model.md "Marker lines": `PRE` + `W`, optional final `.`):

- `PRE` = `^(?:\[[^\]\n]*\][ \t]*)?(?:- )?`
- `W` = ``(?:\*\*|`)?``
- Risk: `PRE W Lane: [A-Za-z]+, risk (high|normal|low|none)\b` (free `(...)` tail after the level)
- Phase done: `PRE W Phase: done\.? W [ \t]*$`
- Label clear: `PRE W Build done\.? W [ \t]*$`

(`PRE W` and `W` are written apart for reading. In code they join with no spaces.)

- [ ] T003 [US1] In `tests/test_phase_hook.py`, add fixture helpers and the risk-from-reply tests (FR-001, FR-003, FR-007, FR-008, FR-012). Helpers: a transcript writer that puts JSONL in the temp folder and returns its path, with line builders shaped as research R4: real prompt (`type` `user`, string content), tool result (`user`, all `tool_result` blocks), meta (`user`, `isMeta: true`, `text` block), reply (`assistant`, `text` block), sidechain reply (`assistant`, `isSidechain: true`), and `api-request-blob` (with a `message.content` `text` block); event senders for PreToolUse Agent, PostToolUse `<tool>` and Stop (with `transcript_path`, optional `last_assistant_message`, optional `agent_id`); and a `make_worktree()` helper that runs `git init`, `git -c user.name=t -c user.email=t@t commit --allow-empty -m x` and `git worktree add` in the temp folder and writes a `.stratum/state.json` in both checkouts. Tests: `test_risk_from_reply` (a current-turn reply `[Orchestrator]\n\nLane: full, risk high (data model: x). Say ...` sets `risk` to `high` on each of PreToolUse Skill `stratum:st-status`, PreToolUse Agent, PostToolUse Agent and Stop, from a fresh state each time; two `Lane:` lines `high` then `low` give `low`; `Lane: Fast, risk Low` gives `low`; stdout is empty for Agent, PostToolUse and Stop; no `.state-` file is left); `test_risk_ignores_out_of_turn` (risk stays as it was for: the line in an earlier turn followed by a real prompt `risk high` and a reply `ok` (spec scenario 3, risk stays `high`); the line only in a tool result, a meta line, a sidechain reply, an `api-request-blob` line; the line inside a sentence; `risk extreme`; input with `agent_id`; no `transcript_path`, a missing file, a file of bad JSON lines; the raw state file is byte-equal after each); `test_risk_at_stop_from_last_message` (transcript without the line, Stop with `last_assistant_message` that has it sets `risk`; the same Stop with a `last_assistant_message` without it changes nothing); `test_risk_goes_to_main_checkout` (Stop with `cwd` in the linked worktree writes `risk` to the main checkout's `.stratum/state.json` and leaves the worktree's file byte-equal); `test_lane_marker_forms` (D1. Each row is its own Stop run from a fresh state with one current-turn reply line. These set `risk` to `high`: label row `[Orchestrator] Lane: full, risk high (data model: x)`, bullet row `- Lane: full, risk high (data model: x)`, label plus bullet `[Orchestrator] - Lane: full, risk high (x)`, `**Lane: full, risk high (x)**`, `` `Lane: full, risk high (x)` ``. These leave the raw state file byte-equal: `I said Lane: full, risk low (x)`, `[Orchestrator] Lane: full, risk extreme`, `-- Lane: full, risk low (x)`). Run them and see each fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_from_reply PhaseHookTest.test_risk_ignores_out_of_turn PhaseHookTest.test_risk_at_stop_from_last_message PhaseHookTest.test_risk_goes_to_main_checkout PhaseHookTest.test_lane_marker_forms`.
- [ ] T004 [US1] In `hooks/st-phase.py`, build the risk-from-reply path per plan.md "Order inside one hook run" and data-model.md: compute the skill name only for UserPromptSubmit and `tool_name == "Skill"` (the Agent input has no `skill`); return when the cwd-walked state file is missing or bad before any transcript read; read the current turn backward in 64 KiB blocks, stop at the first real user prompt or after 16 MiB (mark the cap with `# ponytail:`); skip the read when the input has `agent_id`; read on PreToolUse `Skill`/`Agent`, PostToolUse `Agent` and Stop, and at Stop append `last_assistant_message`; match the final Risk pattern above per line (`re.M`, level without case, stored lower case), last match wins; resolve the main file with `git -C <cwd> rev-parse --path-format=absolute --git-common-dir` (list args, `timeout=3`), fall back to the cwd-walked file on any failure, one write when both are the same file; move the write at lines 61-64 into a small save function and write each file only when it changed; print nothing new. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_from_reply PhaseHookTest.test_risk_ignores_out_of_turn PhaseHookTest.test_risk_at_stop_from_last_message PhaseHookTest.test_risk_goes_to_main_checkout PhaseHookTest.test_lane_marker_forms && python3 tests/test_phase_hook.py`.
- [ ] T005 [US1] In `tests/test_phase_hook.py`, add `test_risk_prompt` (FR-002): with `risk` `high`, the prompt `risk low` sets `low` and ` Risk Normal ` sets `normal`; `risk low please`, `set risk low`, `risk extreme`, `/stratum:st risk low` change nothing (raw file byte-equal); in a `make_worktree()` linked worktree the prompt `risk low` writes the main checkout's file only; the label output of a prompt is unchanged (a `phase: build` state still gets `Start your reply with [Full lane | Build].`). Run it and see it fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_prompt`.
- [ ] T006 [US1] In `hooks/st-phase.py`, on UserPromptSubmit write `risk` when the whole prompt matches `\s*risk (high|normal|low|none)\s*` (without case), to the main file as in T004. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_prompt && python3 tests/test_phase_hook.py`.
- [ ] T007 [US1] In `tests/test_phase_hook.py`, add `test_feature_directory_on_define` (FR-004, spec scenarios 4, 5): with `phase` `define` and `feature_directory` `specs/013-x`, and `specs/013-x/spec.md` plus `specs/015-y/spec.md` on disk, PostToolUse `Write` sets `specs/015-y`; PostToolUse `Bash` and `Agent` do the same from a reset state; with no `feature_directory` the highest folder is set. Unchanged (raw file byte-equal) for: `feature_directory` `specs/015-y` and only `specs/013-x` edited (scenario 5); `phase` `plan` with a new `specs/016-z/spec.md`; a folder `specs/017-w` with no `spec.md`; a folder `specs/abc-x/spec.md`; PreToolUse Skill `stratum:st-status` and Stop while `phase` is `define`. Stdout is empty. Run it and see it fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_feature_directory_on_define`.
- [ ] T008 [US1] In `hooks/st-phase.py`, on PostToolUse while `phase == "define"`: list `<root>/specs/`, keep folders matching `^\d{3}-` that hold `spec.md`, take the highest number, and write `feature_directory` = `specs/<folder>` only when the current `specs/NNN-` number is missing or lower. No tool-input parsing. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_feature_directory_on_define && python3 tests/test_phase_hook.py`.
- [ ] T009 [US1] In `tests/test_phase_hook.py`, add `test_phase_done_marker` (FR-005, scenario 6), `test_build_done_clears_label` (FR-006, scenario 7) and `test_done_marker_forms` (D1). Phase done: a current-turn reply line `Phase: done` sets `phase` to `done` at Stop from `close`, `fast` and `build`; also from `last_assistant_message` alone. Unchanged for `- Phase: done | Lane: full`, `Phase: done and pushed`, the line in a tool result, a meta line or an earlier turn. Label clear: with `lane` `none`, `skill` `st-build`, `skill_session` `s1`, a reply line `Build done.` sets `skill` to `""` at Stop, and the next prompt `what next?` prints nothing; the same for `st-worker`. Unchanged for `Build done. Next: /stratum:st-close` on one line, the line in a tool result or an earlier turn. Marker forms: each row is its own Stop run from a fresh state with one current-turn reply line. These set their value: `[Orchestrator] Phase: done`, `- Phase: done`, `[Orchestrator] - Phase: done`, `` `Phase: done` ``, `**Phase: done**`, `Phase: done.`, `[st-build] Build done.`, `- Build done`, `` `Build done.` ``, `**Build done.**`. These leave the raw state file byte-equal: `- Phase: done | Lane: full`, `[Orchestrator] Phase: done and pushed`, `- Build done. Next: /stratum:st-close`, `Note: Phase: done`, `-- Phase: done`. Stdout of every Stop is empty. Run them and see them fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_phase_done_marker PhaseHookTest.test_build_done_clears_label PhaseHookTest.test_done_marker_forms`.
- [ ] T010 [US1] In `hooks/st-phase.py`, apply the final Phase done pattern above (sets `phase` to `done`, any phase) and the final Label clear pattern (sets `skill` to `""`) to the same current-turn text as the risk marker, before the existing phase and held-label logic. Re-read `old` (line 36) after the markers so the held-label check at line 43 sees the updated phase. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_phase_done_marker PhaseHookTest.test_build_done_clears_label PhaseHookTest.test_done_marker_forms && python3 tests/test_phase_hook.py`.
- [ ] T011 [US1] Negative-control check (SC-003): for each row of quickstart.md "Negative controls", break that guard in `hooks/st-phase.py` with the Edit tool, run the named test, confirm it fails, then undo the edit with the Edit tool (never `git checkout`). Report each row as red or not. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_ignores_out_of_turn PhaseHookTest.test_phase_done_marker PhaseHookTest.test_feature_directory_on_define PhaseHookTest.test_risk_prompt PhaseHookTest.test_risk_goes_to_main_checkout PhaseHookTest.test_lane_marker_forms PhaseHookTest.test_done_marker_forms` (green after the last undo).

**Checkpoint**: the hook writes all four values. The skills still call `st-state.sh` (harmless double write).

---

## Phase 4: User Story 1 - Skill-line tests (Priority: P1)

**Goal**: The phrase tests name the new lines of [contracts/skill-lines.md](contracts/skill-lines.md) and fail.

**Independent Test**: each test below fails on the old lines.

- [ ] T012 [P] [US1] In `tests/test_phase_hook.py` `test_agents_write_done` (lines 219-233), assert ``say `Phase: done` on its own line`` is in `skills/st-close/SKILL.md` and `skills/st-fast/SKILL.md` in place of the old `phrase`; keep the `agents/st-quick.md` assertIn and the `agents/st-close.md` assertNotIn with the old phrase. Owns: `tests/test_phase_hook.py`. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_agents_write_done` (fails until T016, T017).
- [ ] T013 [P] [US1] In `tests/test_state.sh`, delete the `st-state.sh` unit half (lines 4-5 `tmp`/`trap`, 8-9 `run`/`get`, 11-35) and keep the shebang, `set -u`, `root`, `fail`, `check`, the phrase loop and `exit $fail`. Rows S1-S6 hold L3, L4, L1, L2 (from `write {}` to the end), L5, L6 of contracts/skill-lines.md word for word. Add `check S7 '[ ! -e "$root/scripts/st-state.sh" ]'` and `check S8 '! grep -rqF st-state.sh "$root/skills" "$root/procedures" "$root/agents" "$root/hooks" "$root/scripts"'`. Owns: `tests/test_state.sh`. Test: `bash tests/test_state.sh` (S1-S8 fail until Phase 5).
- [ ] T014 [P] [US1] In `tests/test_inspect.sh` line 183, set the `H2 st-close skill phase` phrase to L3 without its leading spaces. Keep the other H2 rows. Owns: `tests/test_inspect.sh`. Test: `bash tests/test_inspect.sh | grep -x 'FAIL H2 st-close skill phase'`.
- [ ] T015 [P] [US1] In `tests/test_risk_rules.sh` line 12, set the R3 phrase to L1. Owns: `tests/test_risk_rules.sh`. Test: `bash tests/test_risk_rules.sh | grep -x 'FAIL R3'`.

---

## Phase 5: User Story 1 - Skill lines (Priority: P1)

**Goal**: No skill line tells the session to write `state.json` (FR-009, FR-010).

**Independent Test**: `bash tests/test_state.sh` passes.

Each task replaces only the named line with its text from contracts/skill-lines.md. Another branch edits other lines of `skills/st/SKILL.md`, `skills/st-build/SKILL.md` and `skills/st-worker/SKILL.md`: touch nothing else.

- [ ] T016 [P] [US1] Replace `skills/st-close/SKILL.md:58` with L3. Owns: `skills/st-close/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S1' && bash tests/test_inspect.sh | grep -x 'ok   H2 st-close skill phase'`.
- [ ] T017 [P] [US1] Replace `skills/st-fast/SKILL.md:41` with L4. Owns: `skills/st-fast/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S2'`.
- [ ] T018 [P] [US1] Replace `skills/st/SKILL.md:37` with L1. Owns: `skills/st/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S3' && bash tests/test_risk_rules.sh | grep -x 'ok   R3'`.
- [ ] T019 [P] [US1] Replace `procedures/specify.md:41` with L2 (keeps the `{}` start sentence and "Later procedures find the feature through this file."). Owns: `procedures/specify.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S4'`.
- [ ] T020 [P] [US1] Replace `skills/st-build/SKILL.md:77` with L5. Owns: `skills/st-build/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S5'`.
- [ ] T021 [P] [US1] Replace `skills/st-worker/SKILL.md:52` with L6. Owns: `skills/st-worker/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S6'`.
- [ ] T022 [P] [US1] Delete `scripts/st-state.sh` (`git rm` through the `st-git` agent at commit time; the build agent removes the file). Owns: `scripts/st-state.sh`. Test: `bash tests/test_state.sh | grep -x 'ok   S7'`.

**Checkpoint**: `bash tests/test_state.sh` passes, S8 included.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T023 In `DESIGN.md` D20 (lines 261-262), change "A UserPromptSubmit hook and a PreToolUse hook on `Skill`," to "A UserPromptSubmit hook, a PreToolUse hook on `Skill` and `Agent`, a PostToolUse hook and a Stop hook," and add one bullet after line 265: "- It writes `risk` to the main checkout's file from a `Lane: <lane>, risk <level>` line in the current turn's reply or a `risk <level>` prompt, `feature_directory` from the highest `specs/NNN-*` folder with a `spec.md` while `phase` is `define`, `phase: done` from a `Phase: done` line and `skill: ""` from a `Build done.` line. Only the main session's reply text after the last user prompt counts." In D21 (line 280), change "until the skill sets `skill` to `""` at its end" to "until the skill says `Build done.` at its end and the hook sets `skill` to `""`". Keep the H2 phrase on line 277 word for word. Test: `bash tests/test_inspect.sh`.
- [ ] T024 Run the quickstart.md automated checks and the SC-001 greps. Test: `python3 tests/test_phase_hook.py && python3 tests/test_model_hook.py && bash tests/test_state.sh && bash tests/test_inspect.sh && bash tests/test_risk_rules.sh`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 2**: none. T002 after T001.
- **Phase 3**: after Phase 2. Strict order T003 → T011 (two shared files).
- **Phase 4**: after Phase 3 (T012 edits `tests/test_phase_hook.py`, and the skill lines must not move before the hook writes the values).
- **Phase 5**: after Phase 4 (test first).
- **Phase 6**: T023 after Phase 3; T024 last.

### User Story Dependencies

- One user story (US1). No two stories to run side by side.

### Within the story

- Every test task fails before its build task. The negative controls of T003, T005, T007 and T009 pass before the build too; T011 proves they can fail.

### Parallel Opportunities

- Phase 4: T012, T013, T014, T015 (four files, one each).
- Phase 5: T016-T022 (seven files, one each).
- T023 (`DESIGN.md`) shares no file with Phases 4 and 5 and can run beside them.

---

## Parallel Example: User Story 1

```bash
# Phase 4, all at once:
Task: "T012 test_agents_write_done phrase in tests/test_phase_hook.py"
Task: "T013 phrase table in tests/test_state.sh"
Task: "T014 H2 row in tests/test_inspect.sh"
Task: "T015 R3 row in tests/test_risk_rules.sh"

# Phase 5, all at once:
Task: "T016 skills/st-close/SKILL.md:58"
Task: "T017 skills/st-fast/SKILL.md:41"
Task: "T018 skills/st/SKILL.md:37"
Task: "T019 procedures/specify.md:41"
Task: "T020 skills/st-build/SKILL.md:77"
Task: "T021 skills/st-worker/SKILL.md:52"
Task: "T022 delete scripts/st-state.sh"
```

---

## Implementation Strategy

### MVP

Phases 2 and 3: the hook writes all four values while the old skill lines still run. Stop and
check `python3 tests/test_phase_hook.py`. Then Phases 4 and 5 remove the chat writes.

### Notes

- The live check (quickstart.md "Live check after merge") runs only after merge (spec Assumptions).
- The PR body names the #74 branch: an `st-state.sh` call it adds must move to the hook.
