# Feature Specification: Run Stratum Steps On Demand

**Feature Branch**: `013-agent-skills`

**Created**: 2026-10-14

**Status**: Draft

**Input**: User description: "Run Stratum steps on demand: issue #13 (every agent can run as a `/stratum:` command), background agents for read-only skills (I1), and the handoff as a background fork (I2)." Decisions D1 to D4 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run any Stratum agent as a command (Priority: P1)

The user types `/stratum:st-review`, `/stratum:st-test`, `/stratum:st-debug` or `/stratum:st-git` and
the matching agent runs, without running a whole lane. Inputs the user leaves out are filled in
from the project's Stratum state. After the agent reports, the command runs the same check the
orchestrator runs after that agent inside a lane.

**Why this priority**: Handoffs and reviews name these steps, and today the user cannot run them
by name (issue #13).

**Independent Test**: Type each of the four commands in a project with a current feature. Each one
starts its agent, and its check runs.

**Acceptance Scenarios**:

1. **Given** a project whose state names a feature, **When** the user types `/stratum:st-review`
   with no range, **Then** the review agent runs on the feature's diff against `main`, and each
   finding is checked against the source before it is shown.
2. **Given** `/stratum:st-test T004`, **When** the test agent reports, **Then** the test is run
   again and shown to fail for the right reason.
3. **Given** `/stratum:st-debug T004`, **When** the debug agent reports, **Then** the test is run
   again and the touched files are checked for added comment lines.
4. **Given** `/stratum:st-git` with no file list, **When** it starts, **Then** the user sees the
   changed files and picks which to commit, and only those are committed.
5. **Given** `/stratum:st-git` with a file list, **When** the commit is made, **Then** the last
   commit's file list is shown and matches the list given.
6. **Given** an agent with no command of the same name, **When** the project's tests run,
   **Then** a test fails and names that agent.

---

### User Story 2 - Run a read-only skill in the background (Priority: P2)

The user asks for an audit or a list while the discussion goes on, for example "run an
impeccable audit of the settings page in the background". A background agent named after the
skill does it. The panel row shows the skill's name for the whole run, and its report comes back
to the main session. The agent changes no file. Fixes it finds go through a lane.

**Why this priority**: The main session stays free for discussion while the slow, read-heavy work
runs elsewhere.

**Independent Test**: Ask for each skill in the background. The row shows the skill name, the
discussion continues, and a report arrives with no file changed.

**Acceptance Scenarios**:

1. **Given** the user says to run `st-impeccable`, `st-ponytail-audit` or `st-ponytail-debt` in
   the background, **When** the orchestrator starts it, **Then** the agent row names that skill
   and the main session keeps answering.
2. **Given** a background audit finishes, **When** its report arrives, **Then** the working tree
   has no change made by the agent.
3. **Given** the user asks for a skill that starts agents or asks questions (a lane, Define,
   grilling), **When** they say "in the background", **Then** the orchestrator says in one line
   that it must run in the main session.

---

### User Story 3 - Write the handoff without stopping the discussion (Priority: P3)

Mid-session, the user asks for the handoff and keeps talking. The handoff is written by a
background fork that has the whole conversation. When the user says they are done, the handoff
runs in the main session so it finishes before they leave.

**Why this priority**: Writing the handoff is a pause in the discussion today. It is useful but
less often needed than stories 1 and 2.

**Independent Test**: Ask for a handoff mid-session, send another message before it ends, then
read `.stratum/handoff.md`.

**Acceptance Scenarios**:

1. **Given** a session in progress, **When** the user asks for the handoff and keeps talking,
   **Then** the main session answers while a fork writes `.stratum/handoff.md`, and the file
   names the decisions made in the conversation.
2. **Given** the user says they are done or is ending the session, **When** the handoff runs,
   **Then** it runs in the main session and finishes before the reply ends.

### Edge Cases

- No current feature in the state: a command that needs one says so in one line and stops.
- `/stratum:st-git` and nothing changed: it says so and commits nothing.
- A background agent's skill finds nothing: it reports that in one line.
- Two background agents at once: each row shows its own skill name.
- A handoff is asked for while a `Handoff` fork runs: no second fork starts. If the user said they
  are done, the main session waits for the first fork before the reply ends.
- A `Handoff` fork writes no file: the main session writes `.stratum/handoff.md`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each of `st-review`, `st-test`, `st-debug` and `st-git` MUST run as a `/stratum:`
  command that starts its agent and passes the user's arguments through.
- **FR-002**: The commands MUST fill a missing feature from the project state and a missing diff
  range with the branch's changes against `main`.
- **FR-003**: `/stratum:st-git` with no file list MUST show the changed files and commit only the
  ones the user picks. It MUST stop, showing the agent's text, unless the agent's report starts
  with `Committed`.
- **FR-004**: Each command MUST run the check the orchestrator runs after that agent in a lane.
  `/stratum:st-debug` MUST stop, showing the agent's text, when the agent reports `Stopped` or
  changes no file.
- **FR-005**: A test MUST fail when an agent has no command of the same name.
- **FR-006**: `st-impeccable`, `st-ponytail-audit` and `st-ponytail-debt` MUST each have a
  background agent with the same name that runs only the skill's read-only modes and reports.
- **FR-007**: The background agents MUST NOT change files.
- **FR-008**: The orchestrator MUST start the matching background agent when the user asks to run
  one of those skills in the background, and MUST refuse in one line for skills that start agents
  or ask the user questions (`st-handoff` is covered by FR-009). Before the start it MUST note
  `git rev-parse HEAD` and `git status --porcelain --untracked-files=all`; when the report arrives
  it MUST run both again and check any difference.
- **FR-009**: Mid-session, the handoff MUST run as a background fork. When the user says they are
  done or is ending the session, it MUST run in the main session. A second fork MUST NOT start
  while one runs. When a fork writes no file or cannot start, the main session MUST write the
  handoff.

### Key Entities

- **Agent / command pair**: an agent and a command with the same name. Every agent has one.
- **Background agent**: an agent named after a read-only skill. It runs that skill and reports.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All agents can be run by name: the count of agents with no same-name command is 0.
- **SC-002**: A background audit's panel row shows the skill name from start to finish.
- **SC-003**: During a background audit or handoff, the main session answers the next message
  without waiting for it.
- **SC-004**: Background agents leave the working tree as they found it in every test run.

## Assumptions

- #14 later merges `st-ponytail-review` into `st-review`. This feature keeps the
  `/stratum:st-review` name for it.
- Claude Code's live summary replaces the row's description after about 30 seconds, so the
  agent's name is what stays visible (tested 2026-10-14).
- A fork inherits the full conversation and the parent's model.
- Model per background agent is a default the user can change with `/stratum:st-model`.
- Out of scope: #19, I3 (parallel spec writer), I5 (shortcut list at Close), #14. I5 was done
  later as change 001 in the Fast lane (`changes/001-close-shortcuts.md`, commit e59a22e).
