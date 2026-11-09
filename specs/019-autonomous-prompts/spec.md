# Feature Specification: The orchestrator sees and answers every worker prompt in autonomous mode

**Feature Branch**: `093-autonomous-prompts`

**Created**: 2026-11-09

**Status**: Draft

**Input**: User description: "Issue #93: in autonomous build mode the orchestrator still cannot handle many worker prompts by itself (seen on 2026-11-08 in the #77/#79/#80 run). Git-guard commit questions stay in the worker pane, `answer` refuses when the pane redraws, and the Codex tab answer loses characters. Grill decisions D2–D8a in `decisions.md`, research in `research.md`."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The orchestrator answers a dialog on a busy worker screen (Priority: P1)

A worker runs a background agent, so lines on its screen change all the time. A permission
dialog opens. The orchestrator judges it and sends the one-time answer. Today the answer is
refused because the whole screen changed between the read and the answer. Now only the dialog
itself (its title line, its text and its option lines) must be the same as the one judged.
Lines outside the dialog may change.

**Why this priority**: On 2026-11-08 the answer was refused three times in a row, and the user had
to press the key. It needs no research and is built first (D2, D3).

**Independent Test**: Show a dialog in a worker pane while other lines change, and answer it with
the hash from `wait`. Then change one character inside the dialog and answer with the old hash.

**Acceptance Scenarios**:

1. **Given** a dialog judged with hash H, **When** lines outside the dialog change and the orchestrator answers with H, **Then** the answer is sent.
2. **Given** a dialog judged with hash H, **When** the command, the title or an option in the dialog changes, **Then** the answer is refused and nothing is sent.
3. **Given** a dialog whose top is cut off at the top of the screen, with one title line and one allowed No option visible, **When** the orchestrator answers its No with the whole-screen hash, **Then** the No is sent, as today; a yes on such a dialog is refused.
4. **Given** a dialog, **When** the chosen option is not a one-time yes or a plain No, **Then** the answer is refused, as today.

---

### User Story 2 - Every worker commit reaches the orchestrator in full (Priority: P1)

A worker commits. Today Claude often writes the message with a heredoc or `$(...)`. The approve
channel refuses to judge such a commit, so the git-guard question stays in the worker pane and goes
to the user. Now the git guard denies a commit written with a heredoc or `$(...)`, in every session,
and its reason tells the agent to use `git commit -m 'subject' -m 'body'`. The agent tries again with
plain `-m`. That commit reaches the orchestrator through the approve channel with the full command,
the branch and the staged files. The orchestrator judges it with the rules it uses today.

**Why this priority**: This was the main cause of the user's key presses on 2026-11-08 (D4, D6).

**Independent Test**: In a test session, run a heredoc commit and a `$(...)` commit and check each is
denied with the `-m` hint. Run a plain `-m` commit and check it is not denied by this rule and a
request with the full command reaches the orchestrator.

**Acceptance Scenarios**:

1. **Given** any Stratum session, **When** an agent runs `git commit` with a heredoc message, **Then** the git guard denies it and the reason names `git commit -m 'subject' -m 'body'`.
2. **Given** any Stratum session, **When** an agent runs `git commit` with `$(...)` or a backtick anywhere in the command, also inside a quoted message, **Then** the git guard denies it with the same reason.
3. **Given** a worker in autonomous mode, **When** it commits with `-m` only, **Then** the orchestrator gets a request with the full command, the branch and the staged files, and nothing about the commit is cut off.
4. **Given** a `-m` message with several paragraphs or line breaks, **When** the commit runs, **Then** it is not denied by this rule.
5. **Given** a worker, **When** it runs `git push`, **Then** the question goes to the user, as today.
6. **Given** a command that is not a `git commit` and uses a heredoc, **When** it runs, **Then** this rule does not deny it.

---

### User Story 3 - Stratum projects stop teaching heredoc commits (Priority: P2)

Claude Code's built-in git instructions teach Claude to write commit messages with a heredoc (and to
add an attribution line the user does not want). `st-init` asks the user once where to turn those
instructions off: in the project (all machines, the recommended choice), for the user (all projects
on this machine), only locally (this repository on this machine), or not at all. `st-update` asks the
same question once for projects that were set up before. Stratum's own text and the `st-git` agent
say to commit with `-m 'subject' -m 'body'`. The git guard of Story 2 stays as the backstop.

**Why this priority**: It makes the denied first try of Story 2 rare. Story 2 already keeps the
orchestrator safe without it (D8, D8a).

**Independent Test**: Run `st-init` in a new project and pick each scope in turn. Check the setting
lands in the matching settings file, and that "not at all" writes nothing. Run `st-update` on an
older project and check it asks once.

**Acceptance Scenarios**:

1. **Given** a new project, **When** `st-init` runs, **Then** it asks where to turn off the built-in git instructions and writes the setting only to the chosen settings file.
2. **Given** the user picks "not at all", **When** `st-init` ends, **Then** no settings file has the setting.
3. **Given** a project set up before this feature, **When** `st-update` runs, **Then** it asks the same question once, and a later `st-update` does not ask again when the setting is already there.
4. **Given** a Stratum session, **When** the `st-git` agent commits, **Then** it uses `-m 'subject' -m 'body'`.

---

### User Story 4 - The Codex tab answer arrives exactly as Codex wrote it (Priority: P2)

A Codex advisor review in the tab ends. Today the answer is read from the screen, which drops
characters such as backticks and backslashes, so the answer can be blocked as malformed or, worse,
parse with the wrong text. Now the answer is read from Codex's own session log, found by the
review's unique marker. If no log holds it, the review runs again headless, whose answer is written to
a file exactly. If that fails too, the point is BLOCKED, as today. The screen is never used for the answer.

**Why this priority**: It hit PR #92 (M4). It needs the research facts (D5).

**Independent Test**: Run a tab review whose answer holds backticks, a `"` and a `\`. Check the
recorded answer equals the text in the session log. Hide the log and check the review runs headless
and says so.

**Acceptance Scenarios**:

1. **Given** a tab review whose answer holds backticks, `"` and `\`, **When** the review ends, **Then** the recorded answer is exactly the text Codex wrote.
2. **Given** two reviews in the same Codex session, **When** the second ends, **Then** its own answer is read, not the first one.
3. **Given** a tab review whose answer is in no session log, **When** the review ends, **Then** the review runs headless and the line says `codex: headless (no session log)`.
4. **Given** the headless run also fails, **When** it ends, **Then** the point is BLOCKED and the user decides, as today.

---

### Edge Cases

- A commit message holds an apostrophe: the agent writes it as `'\''` inside `-m`. It is not denied.
- A commit message names code in backticks: it is denied, and the agent writes the name without backticks.
- A heredoc commit in the user's own session: it is denied once and retried with `-m`, then the user approves it as today.
- A heredoc in a quoted string that only looks like a commit (for example in `echo`): it is not a `git commit` and is not denied.
- The dialog redraws while the orchestrator judges it: if only lines outside the dialog changed, the answer goes through. If the dialog changed, it is refused.
- Codex writes the session log some time after the tab shows idle: the reader waits within the review's time budget before it counts the log as missing.
- The headless rerun has less than 60 s of the time budget left: it does not start and the point is BLOCKED (`timed out`), as today.
- A headless `claude -p` worker: it never commits, so Story 2 does not apply to it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `st-worker.sh answer` MUST compare only the dialog block (title line through the last option line) with the hash the orchestrator judged, not the whole screen.
- **FR-002**: `wait` and `watch` MUST print the hash of that same dialog block on their `screen` line.
- **FR-003**: `answer` MUST refuse when the dialog block differs from the judged hash, when no single title line is visible, or when the option is not a one-time yes or a plain No. When the dialog's top is cut off but one title line and one allowed No option are visible, `wait` and `watch` MUST print the whole-screen hash, and `answer` MUST send only that No after the hash matches, never a yes.
- **FR-004**: The git guard MUST deny a `git commit` whose command holds a heredoc (`<<`) or any text the approve channel refuses as a substitution (a backtick, `$(`, `${` followed by whitespace or `|`, `<(` or `>(`, also inside quotes; a plain `${VAR}` is not refused), in every session, with a reason that tells the agent to use `git commit -m 'subject' -m 'body'` with no backticks or `$(`. The guard and the approve channel MUST use the same test, so every commit the guard lets through can be judged.
- **FR-005**: The git guard MUST NOT deny a `git commit` that uses only `-m` messages, including messages with line breaks, under this rule.
- **FR-006**: A plain `-m` commit by a worker in autonomous mode MUST reach the orchestrator through the approve channel with the full command, the branch and the staged files.
- **FR-007**: `git push` MUST stay with the user.
- **FR-008**: `st-init` MUST ask the user once where to set `includeGitInstructions: false`: project, user, local, or not at all, and write it only there.
- **FR-009**: `st-update` MUST ask the same question once for a project that does not have the setting at any level and has no "not at all" marker. The answer "not at all" MUST leave that marker in the project's `.stratum/` folder. This step MUST carry a `ponytail:` note naming its removal trigger: every Stratum checkout on the PC and the laptop has run the update.
- **FR-016**: When the user turns on autonomous build mode and the built-in git instructions are still on at every level, the turn-on output MUST include a one-line hint that autonomous mode works better with them off, and how to turn them off. It MUST NOT block the turn-on.
- **FR-010**: The Stratum session text and `agents/st-git.md` MUST tell agents to commit with `-m 'subject' -m 'body'`.
- **FR-011**: The advisor MUST read the Codex tab's answer from Codex's session log, picked by the review's nonce, and MUST NOT read the answer from the screen.
- **FR-012**: When no session log holds the answer within the time budget, the advisor MUST run the review headless and print `codex: headless (no session log)`.
- **FR-013**: When the headless run also fails, the advisor MUST block the point, as today.
- **FR-014**: Each story MUST have tests for its negative cases: a changed dialog is refused, a persistent option is refused, a heredoc or `$(` commit is denied, a non-commit heredoc is not denied, and a missing log falls back to headless.
- **FR-015**: `quickstart.md` MUST hold a live check before merge with a real herdr worker and a real Codex tab: a heredoc commit is denied and retried with `-m` and reaches the orchestrator in full; `answer` works on a worker whose screen keeps changing; a Codex answer with backticks and `"` comes back exact.

### Key Entities

- **Dialog block**: the lines of one permission dialog on the worker screen, from its title line to its last option line. Its hash is what the orchestrator judges and answers.
- **Commit request**: what the approve channel gives the orchestrator for a commit: the full command, the branch and the staged files.
- **Codex session log**: Codex's own record of a session, one JSON record per line, with the exact final answer of each turn.
- **Review nonce**: the unique marker each advisor review puts in its prompt, used to find its own answer in the log.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the live check, the user presses no key in a worker tab for a commit or a one-time permission dialog.
- **SC-002**: 100% of tested dialogs that changed after they were judged are refused.
- **SC-003**: 100% of tested heredoc and `$(` commits are denied with the `-m` hint, and 0% of plain `-m` commits are denied by this rule.
- **SC-004**: A Codex answer with backticks, `"` and `\` is recorded with 0 changed characters.
- **SC-005**: A review whose log is missing ends with an exact answer or a BLOCKED line, never with an answer read from the screen.

## Assumptions

- Interactive herdr workers fire the PermissionRequest hook after a PreToolUse `ask` (live probe in `specs/010-workflow-overhaul/research.md`, and the 2.1.319 code path in `research.md` Q1).
- Codex keeps writing its session log under `~/.codex/sessions/` with the final answer in `task_complete.last_agent_message` (`research.md` Q2, codex-cli 0.167.0).
- The orchestrator's rules for judging a commit request do not change.
- Out of scope: one Codex tab per worker (#94), `push` approval, `-p` worker prompts, and the Codex tab's own `st-advisor.sh answer` screen hash.
