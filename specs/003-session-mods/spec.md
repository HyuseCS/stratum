# Feature Specification: Mods That Talk To and Start Other Sessions

**Feature Branch**: `003-session-mods`

**Created**: 2026-10-11

**Status**: Draft

**Input**: User description: "GitHub issue #9 on HyuseCS/stratum: explore if a Claude Code mod can send messages to other Claude Code sessions and read the replies, and start new sessions and watch them. If yes, find out what Stratum can do with it." The issue body is the source. Its questions Q1 to Q5 keep their codes here. Grilling decisions are in `decisions.md`:
- D6. Spike only: a report, test mods, and a yes or no. Stratum use becomes a new issue.
- D7. Test mods go in `specs/003-session-mods/spikes/<mod name>/`. The report is `research.md`. Work is on branch `003-session-mods`, not `st-tree`.
- D8. Local sessions only. The report records the cloud limit from its source.
- D9. "Mod sends" is a full pass. "Model sends, mod shows the reply" is a partial pass.
- D10. For the message test the user opens the second session by hand.
- D11. A third test: the model starts a session with no human step.
- D12. "Yes" only if a session starts with no human step, its result comes back, and it stops with no process left.
- D13. At most 3 approaches per test, then "blocked" with the exact limit.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The model starts a session on its own (Priority: P1)

The Stratum orchestrator is the model. If it can start a second local session with no human step,
get that session's result back, and stop it, Stratum can run work in other sessions. Test 3 checks
this.

**Why this priority**: The yes or no for Stratum (D12) rests on this path first. The orchestrator
is the model, so this is the path Stratum would use.

**Independent Test**: In one session, ask the model to start a second local session with a short
task. Check that the task result comes back to the first session, and that no started process is
alive after the test.

**Acceptance Scenarios**:

1. **Given** one running session, **When** the model starts a second session with a short task,
   **Then** the result of that task comes back to the first session with no human step.
2. **Given** the test ended, **When** the user lists running processes, **Then** no process that
   the test started is alive.
3. **Given** all 3 approaches fail, **When** the test ends, **Then** `research.md` marks it
   "blocked" and quotes the exact error or names the missing feature.

---

### User Story 2 - A mod sends a message to a second session and shows the reply (Priority: P2)

The user opens a second session by hand. From the first session, a message goes to the second
session, and the reply shows in a pane in the first session. Test 1 checks this.

**Why this priority**: Stratum needs the result back from a session. A message is one way. It
answers issue questions Q1 and Q3.

**Independent Test**: Open two local sessions by the exact steps in `quickstart.md`. Load the test
mod in the first. Send one message. The reply text shows in the pane.

**Acceptance Scenarios**:

1. **Given** a second session opened by hand, **When** the mod sends a message, **Then** the reply
   shows in the pane, and the test is a full pass.
2. **Given** the mod cannot send by itself, **When** the model sends the message and the mod shows
   the reply in the pane, **Then** the test is a partial pass, and `research.md` names the limit.
3. **Given** neither way works in 3 approaches, **When** the test ends, **Then** it is "blocked",
   with the exact limit.

---

### User Story 3 - A mod starts a session and shows its status (Priority: P3)

A mod starts a local session with no human step and shows its status (running, done, failed) in a
pane. Test 2 checks this.

**Why this priority**: It is a second way to start a session. It matters if the model path (story 1)
fails, or if a pane that shows all sessions is useful.

**Independent Test**: Load the test mod. Run its command. A session starts, and the pane shows its
status until it ends. Afterwards no started process is alive.

**Acceptance Scenarios**:

1. **Given** the test mod is loaded, **When** the user runs its command, **Then** a session starts
   with no other human step, and the pane shows its status.
2. **Given** the started session ends or is stopped, **When** the pane updates, **Then** it shows
   the final status, and no started process is alive.

---

### User Story 4 - The report and the verdict (Priority: P1)

The owner reads `research.md` and gets an answer to each issue question (Q1 to Q5) with evidence,
the result of each test, a compare of "mod starts" and "model starts", and a yes or no for Stratum.

**Why this priority**: The report is what the issue asks for. Without it the tests do not lead to a
decision.

**Independent Test**: Read `research.md`. Each of Q1 to Q5 has an answer and evidence. Each test has
a result. The verdict follows the D12 rule.

**Acceptance Scenarios**:

1. **Given** the tests ended, **When** the owner reads `research.md`, **Then** each of Q1 to Q5 has
   an answer with at least one evidence item (a doc source, a command output, or a test mod file).
2. **Given** the D12 rule, **When** the owner checks the verdict, **Then** "yes" holds only if all
   three parts hold, and a "no" names the part that failed.
3. **Given** the verdict is "yes", **When** the report ends, **Then** it lists the proposed
   follow-up issue for Stratum use. The issue is opened only after the owner says so.

### Edge Cases

- A mod change needs the "Enable hot reloading for this session?" answer. Hot reloading is off in a
  headless session. The steps say when a restart is needed.
- A started session stops on a permission prompt that no human sees. The test sets a turn limit
  and a time limit, and stops the session when a limit is hit.
- The second session for test 1 is not running when the message is sent. The test reports that
  the message was not delivered, and does not count it as a fail of the API.
- A test approach makes a git worktree. The test removes it at the end.
- A started session keeps running after the first session ends. The process check after each test
  finds it, and the test stops it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each test mod MUST be its own plugin in `specs/003-session-mods/spikes/<mod name>/`,
  loadable with `claude --plugin-dir`. The shipped Stratum plugin MUST NOT change.
- **FR-002**: Test 1 MUST send one message from the first session to a second session that the user
  opened by hand, and show the reply in a pane in the first session.
- **FR-003**: Test 1 MUST record its result as full pass (mod sends), partial pass (model sends, mod
  shows the reply), or blocked.
- **FR-004**: Test 2 MUST have a mod start a local session with no human step after the user runs
  the mod's command, and show the session's status (running, done, failed) in a pane.
- **FR-005**: Test 3 MUST have the model start a local session with no human step, and get the
  session's result back by a message or a file. "Result back" means the exact reply text of the
  short task reaches the first session.
- **FR-006**: Every session that a test starts MUST be stopped by the end of that test, and every
  git worktree it made MUST be removed. After each test, a process list MUST show no process that
  the test started. If a test stops partway, this check MUST run before the next test.
- **FR-007**: Each test MUST try at most 3 different approaches. If all 3 fail, the test MUST be
  marked "blocked" with the exact error text or the name of the missing feature.
- **FR-008**: `research.md` MUST answer issue questions Q1 to Q5, each with at least one evidence
  item.
- **FR-009**: `research.md` MUST record the cloud limit (a cloud session cannot reply yet) with its
  source, without starting a cloud session.
- **FR-010**: `research.md` MUST compare test 2 (mod starts) with test 3 (model starts).
- **FR-011**: `research.md` MUST give a yes or no for Stratum by the D12 rule, and name the failed
  part when the answer is no. The parts: "starts" holds if test 2 or test 3 passes. "Result back"
  holds if a session started in test 2 or test 3 returns its reply text to the first session. A
  pass in test 1 alone does not count, because nothing started that session. "Stops" holds if
  FR-006 holds for that same test.
- **FR-012**: Sessions that a test starts MUST use Haiku, one short prompt, and a limit of 3 turns,
  or no tools where the start method refuses a turn limit. The 5-minute stop always applies. The
  report records which limit was used.
- **FR-013**: The report and the test mods MUST hold only test text (the test prompts, replies and
  command output), and no other session content. Nothing leaves this machine except the normal
  model calls of the sessions.
- **FR-014**: `quickstart.md` MUST give exact steps for every manual step (opening the second
  session, loading a mod, the hot reload answer, the process check).
- **FR-015**: `research.md` MUST name the Claude Code version the tests ran on.
- **FR-016**: Test 3 MUST record whether a started session shows in ListAgents and can receive a
  SendMessage, and what this gives over the built-in Agent tool. Approach C2 (a background
  session that stays alive) MUST always run for this, even when an earlier approach passed.

### Key Entities

- **Test result**: one per test. Which test, the approaches tried, the outcome (full pass, partial
  pass, pass, blocked), the evidence, and the limit if blocked.
- **Started session**: one per session a test starts. How it was started, its status, how it was
  stopped, and the process check that proves it stopped.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 3 of 3 tests end with a recorded outcome (full pass, partial pass, pass or blocked). None ends as
  "unknown".
- **SC-002**: 5 of 5 issue questions (Q1 to Q5) have an answer with at least one evidence item.
- **SC-003**: After each test, 0 processes that the test started are alive.
- **SC-004**: A reader can check the verdict against the D12 rule in under 5 minutes.
- **SC-005**: When the work ends, the changed files are only in `specs/003-session-mods/` and
  `.stratum/state.json`. The shipped Stratum plugin is unchanged.

## Assumptions

- AS1 (cost): Started sessions use Haiku, one short prompt, and a turn limit (FR-012).
- AS2 (cleanup): Each test stops the sessions it started, and the process check proves it.
- AS3 (privacy): All work stays on this machine. The report shows only test text.
- The mod API is only partly documented. Large parts are found by test, not by reading.
- The tests run on this machine with the installed Claude Code version (FR-015), because the mod
  API can change.
- The `st-tree` branch is not used or changed.
- Opening the follow-up GitHub issue reaches an audience, so it waits for the owner's OK.
