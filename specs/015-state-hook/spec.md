# Feature Specification: State writes from the hook only

**Feature Branch**: `086-state-hook`

**Created**: 2026-11-06

**Status**: Draft

**Input**: User description: "Issue #86: make every state.json write from the hook (risk, feature_directory, phase done, label clear), so no write or print of state.json shows in the main chat."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Stratum run with no state writes in the chat (Priority: P1)

The user runs a task from `/stratum:st` through Define, Plan, Inspect, Build and Close. The chat
shows the work and the gates. It shows no command or diff that writes `.stratum/state.json`,
and no print of that file. The Stratum hook writes the four values the session writes today:
the risk, the new feature folder, `phase done`, and the reply-label clear. The file holds the
same values at each step as it does today.

**Why this priority**: This is the whole issue. The writes are noise in the chat, and the model
adds `&& cat .stratum/state.json` to check them, which prints the whole file.

**Independent Test**: Feed the hook the events of each step (a prompt, a tool call, the end of a
reply) with a sample transcript, and compare `state.json` after each step to the values the
skill lines write today. Grep the skills for any `state.json` write instruction.

**Acceptance Scenarios**:

1. **Given** a reply in the current turn that has the line `Lane: full, risk high (...)`, **When** the hook runs on a later Skill or Agent call in that turn, after an Agent call, or at the end of the reply, **Then** `risk` is `high` in the main checkout's `state.json`.
2. **Given** `risk` is `high`, **When** the user sends the prompt `risk low`, **Then** `risk` is `low`.
3. **Given** a `Lane:` line in an earlier turn and a `risk high` prompt in this turn, **When** the hook runs at the end of this reply, **Then** `risk` stays `high` (the old line does not apply again).
4. **Given** Define started with a description while `specs/` held `013-x`, and `feature_directory` is `specs/013-x`, **When** a tool call creates `specs/015-y/spec.md`, **Then** `feature_directory` is `specs/015-y`.
5. **Given** `phase` is `define` and `feature_directory` is `specs/015-y` (the new folder already found), **When** a tool call edits `specs/013-x/spec.md`, **Then** `feature_directory` stays `specs/015-y`.
6. **Given** `phase` is `close` (or `fast`), **When** the reply has the line `Phase: done`, **Then** `phase` is `done` at the end of the reply.
7. **Given** a held reply label (`skill` is `st-build` or `st-worker`), **When** the reply has the line `Build done.`, **Then** `skill` is empty at the end of the reply and the next prompt gets no `[st-build]` label.
8. For each scenario above, **Given** the same state with no marker line (or the marker only in a tool result or in an earlier turn), **Then** the value does not change.

---

### Edge Cases

- The transcript does not have the newest reply text yet when a tool-call hook fires (measured: up to about 1 second, see `research.md` R1). The hook then also reads at a later tool call and at the end of the reply, and at the end it also reads the last reply text the hook input gives.
- A marker line inside a tool result, a quoted user prompt, or a subagent's own reply: it does not count. Only the main session's reply text in the current turn counts, and only at the start of a line.
- The state file is missing or is not valid JSON: the hook writes no key to it and does not block the session. The risk still goes to the main checkout's file when the walk found a `.stratum/` folder or a `.git` file (a linked worktree with no `state.json`).
- The `Lane:` line names a level that is not `high`, `normal`, `low` or `none`: no write.
- A run in a linked worktree: the risk goes to the main checkout's `state.json`, as it does today, because `st-advisor.sh` reads it there.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The hook MUST write `risk` from a line that starts with `Lane: <lane>, risk <level>` in the main session's reply text of the current turn, where `<level>` is `high`, `normal`, `low` or `none`. If the turn has more than one such line, the last one wins.
- **FR-002**: The hook MUST write `risk` from a user prompt that is only `risk <level>`.
- **FR-003**: The risk write MUST land before the first in-turn reader: in the Fast lane, before `st-advisor.sh change` in `st-fast` step 2.
- **FR-004**: When Define starts with a description, the hook MUST store `define_before`: the sorted list of all folder names in `specs/` then (empty if none). When Define starts with no description (a redo), the hook MUST remove `define_before`. While `phase` is `define` and `define_before` is a list, after a `Bash`, `Write`, `Edit`, `MultiEdit` or `Agent` tool call, the hook MUST look for new folders in `specs/`: not in the list, with a name that fully matches `[A-Za-z0-9._-]+`, holding a `spec.md`. If there is one or more, it MUST set `feature_directory` to `specs/<name>` for the name that sorts last, and remove `define_before`. Folder names need no number. With no `define_before`, the hook does not switch.
- **FR-005**: The hook MUST set `phase` to `done` when the current turn's reply has a line `Phase: done`, in any phase. Only st-close and st-fast tell the session to say it.
- **FR-006**: The hook MUST set `skill` to empty when the current turn's reply has a line `Build done.`.
- **FR-007**: A marker MUST count only in the current turn: the reply text after the last real user prompt. Tool results, injected skill text and earlier turns MUST NOT count.
- **FR-008**: Every hook write MUST stay atomic (temp file in the same folder, then rename), as the hook does now.
- **FR-009**: The skill lines MUST no longer tell the session to write `state.json`: `skills/st/SKILL.md:37`, `procedures/specify.md:41` (the `st-state.sh` part), `skills/st-close/SKILL.md:58`, `skills/st-fast/SKILL.md:41`, `skills/st-build/SKILL.md:77`, `skills/st-worker/SKILL.md:52`. In st-close and st-fast, the line tells the session to say `Phase: done`. In st-build and st-worker, it tells the session to say `Build done.`. `skills/st-define/SKILL.md:26` MUST no longer say that specify writes `state.json`: the hook records `feature_directory`.
- **FR-010**: `scripts/st-state.sh` MUST be deleted, with the half of `tests/test_state.sh` that tests it. The skill-text checks in `tests/test_state.sh` (S1–S4), `tests/test_inspect.sh` (H2) and `tests/test_risk_rules.sh` (R3) MUST follow the new lines.
- **FR-011**: Each of the four writes MUST have a hook test and a negative control (the same input without the signal, or the signal out of the current turn, leaves the value as it was).
- **FR-012**: The hook MUST never block the session or print a state value into the chat. On any error it changes nothing.

### Key Entities

- **State file** (`.stratum/state.json`): the keys `risk`, `feature_directory`, `phase`, `lane`, `skill`, `skill_session`. Only `risk`, `feature_directory`, `phase` (`done`) and `skill` (cleared) get new writers. A new key, `define_before` (a list of folder names), is written and read only by the hook: it holds the `specs/` folder names on disk when a new Define starts, and exists only until the hook finds the new folder or a redo removes it.
- **Marker line**: a line at the start of the main session's reply text: `Lane: <lane>, risk <level> (...)`, `Phase: done`, `Build done.`. The line may have an optional `[label] ` and `- ` bullet in front, and `**` or backticks around it (forms in data-model.md "Marker lines").

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A grep of `skills/` and `procedures/` finds no instruction that writes or prints `state.json`, except the accepted `{}` start line (see Assumptions) and the file creation in `skills/st-init/SKILL.md:11`.
- **SC-002**: At each step of a Full run (lane pick, Define, Plan, Inspect, Build end, Close end), `state.json` has the same values as the skill lines give today.
- **SC-003**: Four hook tests pass, and each negative control fails when the guard it checks is removed.
- **SC-004**: All existing tests still pass.

## Assumptions

- Accepted limit: `procedures/specify.md:41` keeps the line that writes `{}` when `.stratum/state.json` is missing. `st-init` makes the file and it is tracked in git, so this is rare. Handling it in the hook needs a special case only for that.
- The label clear goes to the same `state.json` the hook's held-label write uses (the one found from the working folder). Today the skill line writes the main checkout's file. In the main checkout, both are the same file.
- The transcript timing was measured on headless `claude -p` runs (Claude Code 2.1.316). The interactive mode is assumed to use the same transcript writer.
- The live check of the hook cannot run in the session that builds it: that session loads the plugin from the main checkout. Proof is the tests, and a live Full run after merge.
- The #74 branch (`074-prompt-answers`) edits the same skills. A `st-state.sh` call it adds later must move to the hook. The PR body says so.
- Not in scope: the `phase`, `lane` and `skill` writes the hook already makes, and whether `state.json` stays tracked.
