# Feature Specification: Autonomous build mode in more than one session at the same time

**Feature Branch**: `077-autonomous-sessions`

**Created**: 2026-11-08

**Status**: Draft

**Input**: User description: "Issue #77: autonomous build mode can be on for only one session per repository, because all linked worktrees share one flag file with one session id. Let each worktree session turn the mode on and off by itself, at the same time as the others. Grill decisions D19–D20 in `decisions.md`."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Two orchestrator sessions are in autonomous mode at the same time (Priority: P1)

The user has two orchestrator sessions of the same repository, each in its own linked worktree
(for example two herdr workspaces for two features). The user says "autonomous mode" in the
first session, and later in the second session. Both sessions are now in autonomous build mode.
The statusline of each session shows `autonomous`. The permission prompts of the workers of
each session go to their own orchestrator. Turning the mode on in the second session does not
change the first session.

**Why this priority**: This is the defect in #77. Today the second session writes over the
first session's id, so the first session loses the mark and its workers' prompts stop going to it.

**Independent Test**: Make a repository with two linked worktrees. Turn the mode on for session
S1 in one and for session S2 in the other. Check that the statusline shows `autonomous` for both,
and that a worker prompt of each session goes to its own orchestrator.

**Acceptance Scenarios**:

1. **Given** session S1 is in autonomous mode, **When** session S2 of the same repository turns the mode on, **Then** S1 stays in autonomous mode and S2 is also in autonomous mode.
2. **Given** S1 and S2 are both in autonomous mode, **When** the statusline of each session draws, **Then** each one shows `autonomous`.
3. **Given** S1 and S2 are both in autonomous mode, each with a worker, **When** a worker of S1 needs a permission, **Then** the prompt goes to S1 and not to S2, and the same for a worker of S2.
4. **Given** S1 is in autonomous mode, **When** a third session S3 that did not turn the mode on draws its statusline, **Then** it does not show `autonomous`, and the prompts of its workers are not sent on.
5. **Given** S1 and S2 are in autonomous mode, **When** both turn it on or off at the same moment, **Then** neither one changes the mode of the other.

---

### User Story 2 - Each session turns only its own mode off (Priority: P1)

A session turns its own mode off when its task is finished (the Build or worker run ends), when
the user says "stop autonomous", or when the user says they will continue some other time. Turning
it off removes only this session's entry. The other sessions stay in autonomous mode. This also
works for a worker on a saved machine, where the mode entry is on that machine.

**Why this priority**: Without this, the fix of Story 1 fails at the end of a run: one session
that turns off would also turn off the other.

**Independent Test**: With S1 and S2 both on, run the turn-off step in S1. Check that S1 is off
and S2 is still on, here and on a saved machine.

**Acceptance Scenarios**:

1. **Given** S1 and S2 are both in autonomous mode, **When** S1 turns its mode off, **Then** S1 is off and S2 is still on.
2. **Given** S1 has workers on a saved machine and S2 is also on there, **When** S1 turns its mode off, **Then** only the entry of S1 on that machine is removed, and the output says so for each machine.
3. **Given** the user says they will continue some other time, **When** the session writes its handoff, **Then** it turns its own autonomous mode off first and says so.
4. **Given** the Build or worker run of a session ends, **When** the run ends, **Then** that session turns its own mode off, as today.
5. **Given** a session that is not in autonomous mode, **When** it runs the turn-off step, **Then** nothing is removed and the output says there was nothing to turn off.

---

### User Story 3 - Workers still cannot turn the mode on (Priority: P1)

A worker session must never put itself or its orchestrator in autonomous mode. The lock-2 guard
still stops a worker from writing any mode entry, wherever the entries are now kept.

**Why this priority**: The mode lets prompts be approved without the user. A worker that could
write an entry could approve its own actions. This is an access rule.

**Independent Test**: In a worker worktree, try to write a mode entry with Bash and with the
edit tools. Check that each try is refused.

**Acceptance Scenarios**:

1. **Given** a worker session, **When** it tries to make, change or remove any mode entry by a shell command, **Then** the try is refused.
2. **Given** a worker session, **When** it tries to make, change or remove any mode entry with an edit tool, **Then** the try is refused.
3. **Given** a worker session, **When** it tries to turn the mode off with the turn-off command, **Then** the try is refused, as today.

---

### Edge Cases

- A session id with characters other than letters, digits and `-` (for example `/` or `..`): no entry is made and the session is not in autonomous mode. A session id can never point outside the mode folder.
- An old single-file flag from an earlier version is in the place of the new folder: turning the mode on replaces it. Until then, no session is in autonomous mode.
- The mode folder or an entry is a symlink: no entry is made or removed through it, here and on a saved machine, the same as today.
- No session id is set: the session cannot turn the mode on, as today.
- A session crashes while in autonomous mode: its entry stays. It affects only that session id. A new session gets a new id and does not start in autonomous mode. No cleanup removes it (D20).
- A session that is resumed with the same id after a crash is still in autonomous mode, as today.
- An empty entry folder: no session is in autonomous mode.
- The repository is a plain checkout with no linked worktrees: everything works as above with one session or more.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The autonomous mode MUST be kept as one entry per session, in one mode folder in the main checkout's `.stratum/`, also from a linked worktree. The entry name MUST be the session id.
- **FR-002**: Turning the mode on MUST make only this session's entry. It MUST NOT change or remove the entry of any other session.
- **FR-003**: Turning the mode off MUST remove only this session's entry, here and on each saved machine in the roster. The output MUST say for each machine whether the entry was removed, was not there, or could not be removed, and why.
- **FR-004**: A session MUST count as in autonomous mode only when its own entry exists. Every reader MUST use this rule: the statusline, the permission-prompt routing of the approve hook, the worker script's check before `start --autonomous`, `approve` and `pass`, and its write of the entry on a saved machine.
- **FR-005**: A session id MUST contain only letters, digits and `-` before it is used as an entry name. Any other id MUST be refused, and the session MUST NOT count as in autonomous mode.
- **FR-006**: An entry or mode folder that is a symlink MUST NOT be made, read as on, or removed through, here and on a saved machine.
- **FR-007**: The lock-2 guard MUST refuse every write, change or removal of the mode folder or any entry in it by a worker, by shell command and by edit tool.
- **FR-008**: An old single-file flag MUST be replaced when a session turns the mode on. It MUST NOT count as on for any session.
- **FR-009**: The orchestrator skill MUST turn the mode on and off with the new layout, and MUST turn this session's mode off when the task is finished, when the user says "stop autonomous", and when the user says they will continue some other time, before the handoff is written.
- **FR-010**: The handoff skill MUST turn this session's autonomous mode off first when the user says they are done or will continue later, if the mode is on for this session.
- **FR-011**: The worker skill text MUST describe the new layout where it names the flag.
- **FR-012**: The statusline, approve-hook and worker-script tests MUST each have a case with two sessions in two linked worktrees of the same repository, both on, and each session MUST be seen as on. The worker-script test MUST also show that turning one session off leaves the other on.
- **FR-013**: All existing tests MUST still pass, changed only where they name the old single-file layout.

### Key Entities

- **Mode entry**: one empty file per session, named with the session id, in the mode folder `<main checkout>/.stratum/autonomous/`. It exists while that session is in autonomous build mode.
- **Session id**: the Claude Code session id of the orchestrator (`CLAUDE_CODE_SESSION_ID`, and `session_id` in hook input). A worker's `.stratum/approve/session` holds the id of its orchestrator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two orchestrator sessions of one repository can be in autonomous mode at the same time, and 100% of the worker prompts of each session go to that session.
- **SC-002**: When one session turns its mode off, 0 other sessions change mode.
- **SC-003**: Every try by a worker to write, change or remove a mode entry is refused, in each test case.
- **SC-004**: A session id with a `/` or `..` never makes an entry outside the mode folder.
- **SC-005**: All tests pass, including the new two-session cases in the three test files.

## Assumptions

- The mode folder lives in the main checkout's `.stratum/`, as the flag does today, so all linked worktrees see the same folder.
- Lock 2 is still a text match, not an operating-system wall, as its existing shortcut note says. This feature keeps that level of protection and does not raise it.
- There is no cleanup of entries left by crashed sessions (D20). They affect only their own id.
- `.stratum/autonomous` stays untracked and is not in `.gitignore`, as today. This feature does not change that.
- The live two-workspace case (two herdr workspaces with real workers) can only be proved by hand. The automated tests use two linked worktrees and fake session ids.
