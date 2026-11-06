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

- [x] T001 In `tests/test_phase_hook.py`, change `test_hook_registered` (line 266): exactly one PreToolUse entry has matcher `Skill|Agent` and holds `CMD`; one PostToolUse entry has matcher `Bash|Write|Edit|MultiEdit|Agent` and holds `CMD`; a Stop entry holds `CMD`; the UserPromptSubmit check stays. Run it and see it fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_hook_registered`.
- [x] T002 In `hooks/commands.json`, widen the PreToolUse `Skill` matcher to `Skill|Agent`, add a PostToolUse entry (matcher `Bash|Write|Edit|MultiEdit|Agent`) and a Stop entry, each `{ "type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/st-phase.py\"", "timeout": 10 }`. Keep the separate `Agent` entry for `st-models.py` as is (contracts/hook.md "Wiring"). Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_hook_registered && python3 tests/test_model_hook.py ModelHookTest.test_hook_registered`.

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

- [x] T003 [US1] In `tests/test_phase_hook.py`, add fixture helpers and the risk-from-reply tests (FR-001, FR-003, FR-007, FR-008, FR-012). Helpers: a transcript writer that puts JSONL in the temp folder and returns its path, with line builders shaped as research R4: real prompt (`type` `user`, string content), tool result (`user`, all `tool_result` blocks), meta (`user`, `isMeta: true`, `text` block), reply (`assistant`, `text` block), sidechain reply (`assistant`, `isSidechain: true`), and `api-request-blob` (with a `message.content` `text` block); event senders for PreToolUse Agent, PostToolUse `<tool>` and Stop (with `transcript_path`, optional `last_assistant_message`, optional `agent_id`); and a `make_worktree()` helper that runs `git init`, `git -c user.name=t -c user.email=t@t commit --allow-empty -m x` and `git worktree add` in the temp folder and writes a `.stratum/state.json` in both checkouts. Tests: `test_risk_from_reply` (a current-turn reply `[Orchestrator]\n\nLane: full, risk high (data model: x). Say ...` sets `risk` to `high` on each of PreToolUse Skill `stratum:st-status`, PreToolUse Agent, PostToolUse Agent and Stop, from a fresh state each time; two `Lane:` lines `high` then `low` give `low`; `Lane: Fast, risk Low` gives `low`; stdout is empty for Agent, PostToolUse and Stop; no `.state-` file is left); `test_risk_ignores_out_of_turn` (risk stays as it was for: the line in an earlier turn followed by a real prompt `risk high` and a reply `ok` (spec scenario 3, risk stays `high`); the line only in a tool result, a meta line, a sidechain reply, an `api-request-blob` line; the line inside a sentence; `risk extreme`; input with `agent_id`; no `transcript_path`, a missing file, a file of bad JSON lines; the raw state file is byte-equal after each); `test_risk_at_stop_from_last_message` (transcript without the line, Stop with `last_assistant_message` that has it sets `risk`; the same Stop with a `last_assistant_message` without it changes nothing); `test_risk_goes_to_main_checkout` (Stop with `cwd` in the linked worktree writes `risk` to the main checkout's `.stratum/state.json` and leaves the worktree's file byte-equal; with the main checkout's `state.json` deleted, the same Stop creates no main file and leaves the worktree's file byte-equal; with the main file holding `{bad`, the same Stop leaves both files byte-equal); `test_lane_marker_forms` (D1. Each row is its own Stop run from a fresh state with one current-turn reply line. These set `risk` to `high`: label row `[Orchestrator] Lane: full, risk high (data model: x)`, bullet row `- Lane: full, risk high (data model: x)`, label plus bullet `[Orchestrator] - Lane: full, risk high (x)`, `**Lane: full, risk high (x)**`, `` `Lane: full, risk high (x)` ``. These leave the raw state file byte-equal: `I said Lane: full, risk low (x)`, `[Orchestrator] Lane: full, risk extreme`, `-- Lane: full, risk low (x)`). Run them and see each fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_from_reply PhaseHookTest.test_risk_ignores_out_of_turn PhaseHookTest.test_risk_at_stop_from_last_message PhaseHookTest.test_risk_goes_to_main_checkout PhaseHookTest.test_lane_marker_forms`.
- [x] T004 [US1] In `hooks/st-phase.py`, build the risk-from-reply path per plan.md "Order inside one hook run" and data-model.md: compute the skill name only for UserPromptSubmit and `tool_name == "Skill"` (the Agent input has no `skill`); return when the cwd-walked state file is missing or bad before any transcript read; read the current turn backward in 64 KiB blocks, stop at the first real user prompt or after 16 MiB (mark the cap with `# ponytail:`); skip the read when the input has `agent_id`; read on PreToolUse `Skill`/`Agent`, PostToolUse `Agent` and Stop, and at Stop append `last_assistant_message`; match the final Risk pattern above per line (`re.M`, level without case, stored lower case), last match wins; resolve the main file with `git -C <cwd> rev-parse --path-format=absolute --git-common-dir` (list args, `timeout=3`), fall back to the cwd-walked file only when `git` fails; when `git` works and the main file is missing or bad, write nothing and create nothing; one write when both are the same file; move the write at lines 61-64 into a small save function and write each file only when it changed; print nothing new. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_from_reply PhaseHookTest.test_risk_ignores_out_of_turn PhaseHookTest.test_risk_at_stop_from_last_message PhaseHookTest.test_risk_goes_to_main_checkout PhaseHookTest.test_lane_marker_forms && python3 tests/test_phase_hook.py`.
- [x] T005 [US1] In `tests/test_phase_hook.py`, add `test_risk_prompt` (FR-002): with `risk` `high`, the prompt `risk low` sets `low` and ` Risk Normal ` sets `normal`; `risk low please`, `set risk low`, `risk extreme`, `/stratum:st risk low` change nothing (raw file byte-equal); in a `make_worktree()` linked worktree the prompt `risk low` writes the main checkout's file only; the label output of a prompt is unchanged (a `phase: build` state still gets `Start your reply with [Full lane | Build].`). Run it and see it fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_prompt`.
- [x] T006 [US1] In `hooks/st-phase.py`, on UserPromptSubmit write `risk` when the whole prompt matches `\s*risk (high|normal|low|none)\s*` (without case), to the main file as in T004. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_prompt && python3 tests/test_phase_hook.py`.
- [x] T007 [US1] In `tests/test_phase_hook.py`, give the `skill()` helper an optional `args` (default `"x"`), and add two tests (FR-004, spec scenarios 4, 5; data-model.md "`feature_directory` transition"). `test_define_floor`: with `specs/013-x/` and `specs/015-y/` on disk (each with `spec.md`), the prompt `/stratum:st-define new thing` and the Skill `stratum:st-define` with args `new thing` each set `define_floor` to 15; with no `specs/` folder the floor is 0; the prompt `/stratum:st-define` and the Skill with args `""` each remove `define_floor`; a non-define skill (`stratum:st-plan`) leaves it as it was. `test_feature_directory_on_define`, each row from a fresh state with `phase` `define`: redo of 013 (no `define_floor`, `feature_directory` `specs/013-x`, `013-x` and `015-y` on disk) keeps `specs/013-x` after PostToolUse `Write`; new Define (`define_floor` 15, `feature_directory` `specs/013-x`) then `specs/016-z/spec.md` written: PostToolUse `Write` sets `specs/016-z`, and PostToolUse `Bash` and `Agent` do the same; new Define with `feature_directory` `specs/016-z` and only `specs/013-x/spec.md` edited keeps `specs/016-z` (scenario 5); no `feature_directory` and `define_floor` 15 with `016-z` sets `specs/016-z`; a tie `016-a` and `016-z` (both with `spec.md`) sets `specs/016-z`. Unchanged (raw file byte-equal) for: `define_floor` 16 with `016-z` the highest; `phase` `plan` with `define_floor` 15 and `016-z`; a folder `specs/017-w` with no `spec.md`; folders `specs/abc-x/spec.md` and `specs/999-x$(y)/spec.md` (ignored, `999` never wins); PreToolUse Skill `stratum:st-status` and Stop while `phase` is `define`. Stdout is empty. Also update `test_phase_sets_lane_only_when_unset` line 217: after `self.skill("stratum:st-define")` (args `x`, no `specs/`) the state also holds `"define_floor": 0`. Run them and see the new tests fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_define_floor PhaseHookTest.test_feature_directory_on_define PhaseHookTest.test_phase_sets_lane_only_when_unset`.
- [x] T008 [US1] In `hooks/st-phase.py`: (a) in the existing `st-define` branch that sets `phase` to `define` (line 46-56), set `define_floor` to the highest `NNN` of `<root>/specs/` folders whose name starts with `^\d{3}-` (0 if none or no `specs/`) when the description is non-blank (prompt text after the matched command, or `tool_input.args`), else remove `define_floor`; (b) on PostToolUse while `phase == "define"` and `define_floor` is an integer: list `<root>/specs/`, keep folders matching `^\d{3}-[a-z0-9-]+$` that hold `spec.md`, take the highest number (tie: the name that sorts last), and write `feature_directory` = `specs/<folder>` only when that number is above `define_floor` and the current `specs/NNN-` number is missing or lower. No tool-input parsing on PostToolUse. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_define_floor PhaseHookTest.test_feature_directory_on_define PhaseHookTest.test_phase_sets_lane_only_when_unset && python3 tests/test_phase_hook.py`.
- [x] T009 [US1] In `tests/test_phase_hook.py`, add `test_phase_done_marker` (FR-005, scenario 6), `test_build_done_clears_label` (FR-006, scenario 7) and `test_done_marker_forms` (D1). Phase done: a current-turn reply line `Phase: done` sets `phase` to `done` at Stop from `close`, `fast` and `build`; also from `last_assistant_message` alone. Unchanged for `- Phase: done | Lane: full`, `Phase: done and pushed`, the line in a tool result, a meta line or an earlier turn. Label clear: with `lane` `none`, `skill` `st-build`, `skill_session` `s1`, a reply line `Build done.` sets `skill` to `""` at Stop, and the next prompt `what next?` prints nothing; the same for `st-worker`. Unchanged for `Build done. Next: /stratum:st-close` on one line, the line in a tool result or an earlier turn. Marker forms: each row is its own Stop run from a fresh state with one current-turn reply line. These set their value: `[Orchestrator] Phase: done`, `- Phase: done`, `[Orchestrator] - Phase: done`, `` `Phase: done` ``, `**Phase: done**`, `Phase: done.`, `[st-build] Build done.`, `- Build done`, `` `Build done.` ``, `**Build done.**`. These leave the raw state file byte-equal: `- Phase: done | Lane: full`, `[Orchestrator] Phase: done and pushed`, `- Build done. Next: /stratum:st-close`, `Note: Phase: done`, `-- Phase: done`. Stdout of every Stop is empty. Run them and see them fail. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_phase_done_marker PhaseHookTest.test_build_done_clears_label PhaseHookTest.test_done_marker_forms`.
- [x] T010 [US1] In `hooks/st-phase.py`, apply the final Phase done pattern above (sets `phase` to `done`, any phase) and the final Label clear pattern (sets `skill` to `""`) to the same current-turn text as the risk marker, before the existing phase and held-label logic. Re-read `old` (line 36) after the markers so the held-label check at line 43 sees the updated phase. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_phase_done_marker PhaseHookTest.test_build_done_clears_label PhaseHookTest.test_done_marker_forms && python3 tests/test_phase_hook.py`.
- [x] T011 [US1] Negative-control check (SC-003): for each row of quickstart.md "Negative controls", break that guard in `hooks/st-phase.py` with the Edit tool, run the named test, confirm it fails, then undo the edit with the Edit tool (never `git checkout`). Report each row as red or not. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_risk_ignores_out_of_turn PhaseHookTest.test_risk_at_stop_from_last_message PhaseHookTest.test_phase_done_marker PhaseHookTest.test_feature_directory_on_define PhaseHookTest.test_risk_prompt PhaseHookTest.test_risk_goes_to_main_checkout PhaseHookTest.test_lane_marker_forms PhaseHookTest.test_done_marker_forms` (green after the last undo).

**Checkpoint**: the hook writes all four values. The skills still call `st-state.sh` (harmless double write).

---

## Phase 4: User Story 1 - Skill-line tests (Priority: P1)

**Goal**: The phrase tests name the new lines of [contracts/skill-lines.md](contracts/skill-lines.md) and fail.

**Independent Test**: each test below fails on the old lines.

- [x] T012 [P] [US1] In `tests/test_phase_hook.py` `test_agents_write_done` (lines 219-233), assert ``say `Phase: done` on its own line`` is in `skills/st-close/SKILL.md` and `skills/st-fast/SKILL.md` in place of the old `phrase`; keep the `agents/st-quick.md` assertIn and the `agents/st-close.md` assertNotIn with the old phrase. Owns: `tests/test_phase_hook.py`. Test: `python3 tests/test_phase_hook.py PhaseHookTest.test_agents_write_done` (fails until T016, T017).
- [x] T013 [P] [US1] In `tests/test_state.sh`, delete the `st-state.sh` unit half (lines 4-5 `tmp`/`trap`, 8-9 `run`/`get`, 11-35) and keep the shebang, `set -u`, `root`, `fail`, `check`, the phrase loop and `exit $fail`. Rows S1-S6 hold L3, L4, L1, L2 (from `write {}` to the end), L5, L6 of contracts/skill-lines.md word for word. Add `check S7 '[ ! -e "$root/scripts/st-state.sh" ]'`, `check S8 '! grep -rqF st-state.sh "$root/skills" "$root/procedures" "$root/agents" "$root/hooks" "$root/scripts"'`, a table row `S9|skills/st-define/SKILL.md|` + the S9 phrase of contracts/skill-lines.md, and ``check S10 '! grep -qF -- "and writes \`.stratum/state.json\` with" "$root/skills/st-define/SKILL.md"'``. Owns: `tests/test_state.sh`. Test: `bash tests/test_state.sh` (S1-S10 fail until Phase 5).
- [x] T014 [P] [US1] In `tests/test_inspect.sh` line 183, set the `H2 st-close skill phase` phrase to L3 without its leading spaces. Keep the other H2 rows. Owns: `tests/test_inspect.sh`. Test: `bash tests/test_inspect.sh | grep -x 'FAIL H2 st-close skill phase'`.
- [x] T015 [P] [US1] In `tests/test_risk_rules.sh` line 12, set the R3 phrase to L1. Owns: `tests/test_risk_rules.sh`. Test: `bash tests/test_risk_rules.sh | grep -x 'FAIL R3'`.

---

## Phase 5: User Story 1 - Skill lines (Priority: P1)

**Goal**: No skill line tells the session to write `state.json` (FR-009, FR-010).

**Independent Test**: `bash tests/test_state.sh` passes.

Each task replaces only the named line with its text from contracts/skill-lines.md. Find each old line by its text (the "old text to find" column of contracts/skill-lines.md), not by line number: another branch edits other lines of `skills/st/SKILL.md`, `skills/st-build/SKILL.md` and `skills/st-worker/SKILL.md`, so the numbers can shift. Touch nothing else.

- [x] T016 [P] [US1] In `skills/st-close/SKILL.md`, replace the line that starts ``   After the commit lands, set `phase` `` (line 58 today) with L3. Owns: `skills/st-close/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S1' && bash tests/test_inspect.sh | grep -x 'ok   H2 st-close skill phase'`.
- [x] T017 [P] [US1] In `skills/st-fast/SKILL.md`, replace the line that starts `10. After the last commit lands` (line 41 today) with L4. Owns: `skills/st-fast/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S2'`.
- [x] T018 [P] [US1] In `skills/st/SKILL.md`, replace the line that starts ``Write the risk (`high`, `` (line 37 today) with L1. Owns: `skills/st/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S3' && bash tests/test_risk_rules.sh | grep -x 'ok   R3'`.
- [x] T019 [P] [US1] In `procedures/specify.md`, replace the line that starts ``   - If `.stratum/state.json` does not exist`` (line 41 today) with L2 (keeps the `{}` start sentence and "Later procedures find the feature through this file."). Owns: `procedures/specify.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S4'`.
- [x] T020 [P] [US1] In `skills/st-build/SKILL.md`, replace the line that starts `Then clear the reply label:` (line 77 today) with L5. Owns: `skills/st-build/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S5'`.
- [x] T021 [P] [US1] In `skills/st-worker/SKILL.md`, replace the line that starts `When the run ends (after the last close` (line 52 today) with L6. Owns: `skills/st-worker/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S6'`.
- [x] T022 [P] [US1] Delete `scripts/st-state.sh` (`git rm` through the `st-git` agent at commit time; the build agent removes the file). Owns: `scripts/st-state.sh`. Test: `bash tests/test_state.sh | grep -x 'ok   S7'`.
- [x] T023 [P] [US1] In `skills/st-define/SKILL.md` step 2, replace the three lines from ``   summary of the grilling answers. It creates `specs/NNN-short-name/spec.md`, the`` to ``   `phase: define`.`` (lines 25-27 today) with the three L7 lines. Keep line 24 as it is. Owns: `skills/st-define/SKILL.md`. Test: `bash tests/test_state.sh | grep -x 'ok   S9' && bash tests/test_state.sh | grep -x 'ok   S10'`.

**Checkpoint**: `bash tests/test_state.sh` passes, S8 included.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T024 In `DESIGN.md` D20 (lines 261-262), change "A UserPromptSubmit hook and a PreToolUse hook on `Skill`," to "A UserPromptSubmit hook, a PreToolUse hook on `Skill` and `Agent`, a PostToolUse hook and a Stop hook," and add one bullet after line 265: "- It writes `risk` to the main checkout's file from a `Lane: <lane>, risk <level>` line in the current turn's reply or a `risk <level>` prompt, `feature_directory` from the highest `specs/NNN-<name>` folder with a `spec.md` while `phase` is `define`, when its number is above the highest folder number on disk when a new Define started (`define_floor`), `phase: done` from a `Phase: done` line and `skill: ""` from a `Build done.` line. Only the main session's reply text after the last user prompt counts." In D21 (line 280), change "until the skill sets `skill` to `""` at its end" to "until the skill says `Build done.` at its end and the hook sets `skill` to `""`". Keep the H2 phrase on line 277 word for word. Run after Phase 5 (the H2 `st-close skill phase` row is red until T016). Test: `bash tests/test_inspect.sh`.
- [x] T025 Run the quickstart.md automated checks and the SC-001 greps. Test: `python3 tests/test_phase_hook.py && python3 tests/test_model_hook.py && bash tests/test_state.sh && bash tests/test_inspect.sh && bash tests/test_risk_rules.sh`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 2**: none. T002 after T001.
- **Phase 3**: after Phase 2. Strict order T003 → T011 (two shared files).
- **Phase 4**: after Phase 3 (T012 edits `tests/test_phase_hook.py`, and the skill lines must not move before the hook writes the values).
- **Phase 5**: after Phase 4 (test first).
- **Phase 6**: after Phase 5. T024 needs T016 (its test runs the whole `tests/test_inspect.sh`, and the H2 `st-close skill phase` row is red until T016). T025 last.

### User Story Dependencies

- One user story (US1). No two stories to run side by side.

### Within the story

- Every test task fails before its build task. The negative controls of T003, T005, T007 and T009 pass before the build too; T011 proves they can fail.

### Parallel Opportunities

- Phase 4: T012, T013, T014, T015 (four files, one each).
- Phase 5: T016-T023 (eight files, one each).
- T024 (`DESIGN.md`) runs after Phase 5, not beside it.

---

## Parallel Example: User Story 1

```bash
# Phase 4, all at once:
Task: "T012 test_agents_write_done phrase in tests/test_phase_hook.py"
Task: "T013 phrase table in tests/test_state.sh"
Task: "T014 H2 row in tests/test_inspect.sh"
Task: "T015 R3 row in tests/test_risk_rules.sh"

# Phase 5, all at once:
Task: "T016 skills/st-close/SKILL.md (L3)"
Task: "T017 skills/st-fast/SKILL.md (L4)"
Task: "T018 skills/st/SKILL.md (L1)"
Task: "T019 procedures/specify.md (L2)"
Task: "T020 skills/st-build/SKILL.md (L5)"
Task: "T021 skills/st-worker/SKILL.md (L6)"
Task: "T022 delete scripts/st-state.sh"
Task: "T023 skills/st-define/SKILL.md step 2"
```

---

## Implementation Strategy

### MVP

Phases 2 and 3: the hook writes all four values while the old skill lines still run. Stop and
check `python3 tests/test_phase_hook.py`. Then Phases 4 and 5 remove the chat writes.

### Notes

- The live check (quickstart.md "Live check after merge") runs only after merge (spec Assumptions).
- The PR body names the #74 branch: an `st-state.sh` call it adds must move to the hook.
