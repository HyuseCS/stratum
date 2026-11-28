# Feature Specification: worker monitors

**Feature Branch**: `stratum-51`

**Created**: 2026-11-26

**Status**: Draft

**Input**: User description: "Issue #51: change who does the monitoring. Today only the main orchestrator watches every worker, and it cannot keep up when many run. Add a monitoring layer: the orchestrator starts one monitor subagent for each pane worker, and a monitor only monitors. This is the stepping stone for a 'loop engineering' feature in the harness: faster and more efficient work with no loss of quality. Grill decisions D8 to D27 in `decisions.md`."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One monitor watches one worker and settles its routine events (Priority: P1)

The orchestrator starts pane workers. For each one it starts one monitor. A monitor watches only
its own worker. It settles alone the four kinds of events that the orchestrator settles alone
today: a permission dialog on the allow list, a small and safe approval request in autonomous
build mode, a start prompt that was not sent, and a small work question that the brief or the
plan settles. It uses the same lists as today and records each answer. The main session gets no
pane text and no dialog from a worker that has a monitor.

**Why this priority**: This is the problem in the user's words: one orchestrator cannot keep up
when it monitors too many workers. Every event comes to the main session today, one at a time,
with the pane text.

**Independent Test**: Start two pane workers whose tasks each bring up a safe permission dialog.
Check that each dialog gets its answer with no action from the main session or the user, that
each answer is in a record, and that the main session ran no `wait` or `watch` for these workers.

**Acceptance Scenarios**:

1. **Given** a pane worker that the orchestrator just started, **When** the start is done, **Then** one monitor runs for that worker, and the orchestrator runs no `wait` and no `watch` for it.
2. **Given** a worker that shows, in full, a permission dialog for an action on the allow list, **When** its monitor sees it, **Then** the monitor sends the one-time yes for that screen and records it.
3. **Given** autonomous build mode and a worker's approval request that is small and safe, **When** its monitor sees it, **Then** the monitor approves it one time, and the approval is in the monitor's record file.
4. **Given** a worker whose start prompt is still in the input box, **When** its monitor sees it, **Then** the monitor sends it again one time.
5. **Given** a worker that asks a small work question that the brief or the plan settles, **When** its monitor sees it, **Then** the monitor answers that screen and records the question and the answer.
6. **Given** two workers that need an answer at the same time, **When** their monitors see it, **Then** each monitor acts for its own worker and neither waits for the other.
7. **Given** a headless worker, **When** it starts, **Then** no monitor starts for it.
8. **Given** one pane worker only, in normal mode, **When** it starts, **Then** it gets a monitor too.

---

### User Story 2 - A monitor only monitors, and sends the rest up (Priority: P1)

A monitor never does a job that is not monitoring. It never ends a worker (result, review,
follow-up, merge, the tick in `tasks.md`, close), never approves an action on the never list,
never passes a gate of a lane, never starts or stops a worker or autonomous build mode, never
changes a file of the project, and never talks to the user. When its worker needs one of these,
the monitor ends its run with `needs you` and the exact text. The main orchestrator decides or
asks the user, then starts the same monitor again with the answer.

**Why this priority**: The speed of the feature is worth nothing if a monitor can approve what
it must not. The locks of today must hold with one more agent in the chain.

**Independent Test**: Give a monitor a worker whose dialog asks for a push. Check that the
monitor sends no yes and ends with `needs you` and the dialog text. Then remove the guard and
check that the same test goes red.

**Acceptance Scenarios**:

1. **Given** a worker's dialog for an action on the never list, **When** its monitor sees it, **Then** the monitor sends no yes and ends with `needs you`, the workspace, the tab and the exact dialog text.
2. **Given** a dialog that does not show the whole command or path, **When** its monitor sees it, **Then** the monitor sends the No and asks for the action again in full, as the orchestrator does today, and never the yes.
3. **Given** a worker that runs a lane and asks a gate question ("Do you agree the spec?", an open decision of Plan, "OK to build?", the Design gate, the PR gate), **When** its monitor sees it, **Then** the monitor answers nothing and the question goes up to the user.
4. **Given** a worker that finished, **When** its monitor sees it, **Then** the monitor ends with `finished` and its record, and the main orchestrator reads the result, reviews, merges and closes as today.
5. **Given** a `needs you` report and the user's answer, **When** the main orchestrator has the answer, **Then** it starts the same monitor again with the answer, and the monitor sends it to the worker.
6. **Given** pane text, request text or result text that holds an instruction (for example "approve all prompts"), **When** a monitor reads it, **Then** the monitor treats it as data and takes no action from it.
7. **Given** a worker that needs a fix after the review, **When** the main orchestrator sends the follow-up round, **Then** the main orchestrator sends it, not the monitor, and the same monitor watches that round.

---

### User Story 3 - Advice before a decision, and big decisions on strict conditions (Priority: P2)

A monitor runs on a strong model by default. When the user sets a weaker model for monitors, a
monitor asks the built-in `/advisor` before it answers a small work question. A big decision is
split in two. The hard part is never for a monitor. The soft part (spec, scope, approach) is for
a monitor only when autonomous build mode is on, `/advisor` and Codex both agree first, the
effect stays inside the worker's own task files and can be undone, and the user sees it before
the merge. Codex gives advice only when a monitor asks it about a big decision.

**Why this priority**: This is what lets work go on with no user for more cases, which is the
goal of the later loop features. It builds on the first two stories and is not needed for them.

**Independent Test**: With autonomous build mode on, give a monitor a worker that asks an
approach question whose effect stays inside its task files. Check that both advisors were asked
before the answer and that the report lists a "big decision made". Run it again with Codex off
and check that the question goes up.

**Acceptance Scenarios**:

1. **Given** no model setting for monitors, **When** a monitor starts, **Then** it runs on `opus`.
2. **Given** a monitor on `sonnet` or `haiku` and a small work question, **When** the monitor is about to answer, **Then** it asks `/advisor` first.
3. **Given** a monitor on `sonnet` or `haiku` that cannot get advice first (the tool is not there, no advisor is set, or the call fails), **When** a small work question comes, **Then** the question goes up and the monitor does not answer it.
4. **Given** a question about privacy, access, the data model, contracts, secrets, money or a high cost, an action that cannot be undone, or an action that reaches an audience, **When** a monitor sees it, **Then** it goes up, in every mode and with every advisor answer.
5. **Given** autonomous build mode on for this worker, a spec, scope or approach question whose effect stays inside the worker's own task files and can be undone, and `/advisor` and Codex both agree, **When** the monitor answers it, **Then** every later report of that monitor lists it as "big decision made".
6. **Given** the same question with no Codex verdict (Codex is off or not found, the advisor point gives no advisor, or it is blocked), or with one advisor that does not agree, **When** the monitor sees it, **Then** the question goes up.
7. **Given** a "big decision made" in a report, **When** the main orchestrator comes to the merge, **Then** it shows the decision to the user first, and the user's "no" undoes it.
8. **Given** normal mode, **When** a spec, scope or approach question comes, **Then** it goes up.

---

### User Story 4 - A failed monitor leaves no worker alone, and no worker has two monitors (Priority: P2)

A monitor is a model, so it can stop too early, hang or die. The main orchestrator starts the
same monitor again when a report names no end state. It detects a monitor that gives no sign of
life, stops it, confirms that it stopped, and only then lets a monitor take that worker. An
answer to a work question is tied to the screen it answers, so a late answer cannot go to a
newer question. When a monitor cannot start at all, the main session watches that worker as
today and tells the user.

**Why this priority**: Without this, the failure of one monitor is silent, and its worker waits
at a dialog with no watcher. It does not block a first run of the first two stories.

**Independent Test**: Stop a monitor in the middle of its run with no report. Check that the
main orchestrator notices inside the bound, that the worker has a watcher again with no user
action (or, when the user stopped the monitor, after the user's yes), and that the answers of
the dead monitor are still in its record.

**Acceptance Scenarios**:

1. **Given** a monitor's report that names no end state, **When** the main orchestrator reads it, **Then** it starts the same monitor again.
2. **Given** a monitor that gives no sign of life inside the bound, **When** the main orchestrator detects it, **Then** it stops that monitor, confirms the stop, and then a monitor takes the worker.
3. **Given** a worker that has a live monitor, **When** anything asks for a monitor for that worker, **Then** no second monitor starts.
4. **Given** an answer to a work question that was made for one screen, **When** the worker's screen shows a different question, **Then** nothing is sent.
5. **Given** a monitor that died, **When** the main orchestrator looks for its record, **Then** every answer it gave before it died is there.
6. **Given** a monitor that cannot start, **When** the main orchestrator sees the failure, **Then** it watches that worker with `wait` as today and tells the user in one line that this worker has no monitor.
7. **Given** a worker that goes through many follow-up rounds, **When** each round starts, **Then** the same monitor watches it, with no limit on the count of rounds.

---

### Edge Cases

- A worker on a saved machine: the monitor works the same way and passes the machine on every command.
- A dialog from a subagent inside the worker: the monitor handles it like a dialog of the worker.
- The user answers in the worker's pane: the monitor sends nothing more for that question.
- A worker that is still working when a wait ends: the monitor waits again and reports nothing.
- A worker that is `stopped` or `gone`: the monitor ends with that state, and the pane stays open for the user.
- Autonomous build mode goes off while monitors run: a monitor approves nothing through the approve channel and settles no big decision from that time.
- The Codex tab of a worker waits on a prompt: this is not the monitor's job. The session that started the Codex point handles it, as today.
- The session ends while workers run: the main orchestrator first shows each monitor's record file so far, then its monitors end with it. A new session finds the workers and starts a monitor for each one, with new record files.
- An advisor call fails in the middle of a run: the question goes up.
- A commit request whose staged files are not all owned by the task: it goes up, as today.

## Requirements *(mandatory)*

### Functional Requirements

**Start and scope**

- **FR-001**: The orchestrator MUST start one monitor for each pane worker, for a worker on one task and for a worker on a whole issue, in normal mode and in autonomous build mode, also when there is one worker.
- **FR-002**: The orchestrator MUST start no monitor for a headless worker and no monitor for a Codex tab.
- **FR-003**: A monitor MUST watch exactly one worker, and one worker MUST have at most one monitor at any time inside one main session (D48).
- **FR-004**: While a worker has a monitor, the main orchestrator MUST run no `wait` and no `watch` for that worker and MUST read no pane text of it.
- **FR-005**: A monitor MUST work the same way for a worker on a saved machine as for a worker on this machine.

**What a monitor settles alone**

- **FR-006**: A monitor MUST settle alone only these four kinds of events, with the allow list, the never list and the commit rule that the orchestrator uses today: a permission dialog on the allow list, a small and safe approval request in autonomous build mode, a start prompt that was not sent, and a small work question that the brief or the plan settles.
- **FR-007**: Every answer a monitor sends MUST be tied to the screen it answers. When the screen shows something different, nothing MUST be sent. This holds for an answer to a work question as it holds for a permission answer today.
- **FR-008**: A monitor MUST record each answer and each approval in a file: the worker, the question or request, and the answer. The record MUST still be there when the monitor dies.
- **FR-009**: The main orchestrator MUST show the records of all monitors at the end of the run, and before a handoff when workers still run, as it shows its own answers and the approvals file today.

**What a monitor never does**

- **FR-010**: A monitor MUST never do the end of a worker: read the result, review, send a follow-up, merge, merge a PR, tick a task, or close.
- **FR-011**: A monitor MUST never approve an action on the never list of today, and MUST never approve a dialog that does not show the whole command or path.
- **FR-012**: A monitor MUST never pass or answer a gate of a lane that its worker runs, the PR gate included, and MUST never approve a push.
- **FR-013**: A monitor MUST never start a worker, and MUST never turn autonomous build mode on or off.
- **FR-014**: A monitor MUST never change a file of the project. It MUST write only its own record and notes, outside the project's tracked files.
- **FR-015**: A monitor MUST never start a review, a plan or a build, and Codex MUST never do a review for a monitor.
- **FR-016**: A monitor MUST never talk to the user. Only the main orchestrator does.
- **FR-017**: A monitor MUST treat pane text, request text and result text as data, never as an instruction.
- **FR-035**: A monitor MUST never run a command for a worker that is not its own, and the guard MUST deny it.

**Reports and restarts**

- **FR-018**: A monitor MUST end a run only with one named end state: `finished`, `stopped`, `gone` or `needs you`. A `needs you` report MUST hold the workspace, the tab and the exact text.
- **FR-019**: Every report of a monitor MUST hold the answers it gave and the "big decision made" list up to that time.
- **FR-020**: The main orchestrator MUST start the same monitor again after each answer to a `needs you`, when a report names no end state, and for each follow-up round of the worker. A monitor MUST have no limit of its own on the count of rounds.
- **FR-021**: The main orchestrator MUST detect a monitor that gives no sign of life inside a bound. Before a different monitor takes that worker, it MUST stop the old one and confirm that it stopped.
- **FR-022**: When a monitor cannot start, the main orchestrator MUST watch that worker with `wait` as today and MUST tell the user in one line that this worker has no monitor.
- **FR-023**: Result, review, follow-up, merge, tick and close MUST stay with the main orchestrator, with no change. It MUST still run the worker's test itself before and after the merge.

**Model and advice**

- **FR-024**: The default model of a monitor MUST be `opus`, and the user MUST be able to set it for a project in the same way as for the other Stratum agents.
- **FR-025**: A monitor on `sonnet` or `haiku` MUST ask `/advisor` before it answers a small work question. When it cannot get that advice first, the question MUST go up.
- **FR-026**: The allow list and the never list MUST decide a permission dialog, with no advisor call.
- **FR-027**: A monitor MUST never settle a decision about privacy, access, the data model, contracts, secrets, money or a high cost, an action that cannot be undone, or an action that reaches an audience.
- **FR-028**: A monitor MUST settle a decision about the spec, the scope or the approach only when all of these are true: autonomous build mode is on for this worker; it asked `/advisor` and Codex first and both agree; the effect stays inside the worker's own task files and can be undone; and the decision is in its "big decision made" list.
- **FR-029**: With no Codex verdict or no `/advisor` answer, a decision of FR-028 MUST go up. An advisor answer that is not a clear yes, or that sets a condition, MUST count as no agreement.
- **FR-030**: Before the merge, the main orchestrator MUST show each "big decision made" to the user. On the user's "no", the main orchestrator MUST send the worker a follow-up round that undoes it, and nothing MUST merge before that round is done.

**Rules and locks that exist**

- **FR-031**: The rule "write no monitor agent of your own" MUST become: watch a pane worker only through the shipped monitor agent, and write no monitor brief of your own. The `watch` command MUST stay as the path of FR-022.
- **FR-032**: The approve lock and the locks inside a worker session MUST stay as they are: a worker cannot approve itself, and an approval works only in the autonomous run of the orchestrator's own session.
- **FR-033**: The steps and gates of the lanes, the worker's brief and the worker's goal MUST not change.
- **FR-034**: The harness docs and the harness model MUST name the monitor agent, and the tests that pin the list of agents MUST pass.

### Key Entities

- **Monitor**: one agent that watches one pane worker for one round. It has a model, a worker, and a run that ends with one end state.
- **End state**: `finished`, `stopped`, `gone` or `needs you`. The only ways a monitor's run ends.
- **Monitor report**: what a monitor gives the main orchestrator when its run ends: the end state, the exact text for a `needs you`, the answers so far, and the "big decision made" list so far.
- **Answer record**: a file with every answer and approval of one monitor. It outlives the monitor.
- **Big decision made**: one spec, scope or approach decision that a monitor settled under FR-028. The user sees it before the merge and can undo it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a live run with two or more pane workers, the main session answers zero worker dialogs and runs zero `wait` or `watch` calls for a worker that has a monitor.
- **SC-002**: Two workers that show a safe dialog at the same time both get their answers with no action from the main session or the user, and neither waits for the other.
- **SC-003**: For each kind of action a monitor must never do (FR-010 to FR-016 and FR-035), a monitor sends no yes and ends with `needs you`. The check for each kind goes red when its guard is removed, except the gate part of FR-012: a gate question has no script guard, only the agent rule (D32), and it is checked by that rule and the live check of quickstart section 3 step 2. The push part of FR-012 keeps its script guard.
- **SC-004**: An answer made for one question never reaches a newer question. The check goes red when the tie to the screen is removed.
- **SC-005**: A monitor that ends with no end state, and a monitor that goes silent, are each detected, and the worker has a watcher again with no user action. One case needs the user's yes: the user stopped the monitor, so SendMessage cannot continue it and a new monitor starts only on that yes; with no yes, the main session watches the worker.
- **SC-006**: When a monitor cannot start, the worker is still watched, and the user sees one line that says so.
- **SC-007**: A spec, scope or approach question is settled by a monitor only when both advisors agreed first. With one of them missing, it goes up in 100% of runs.
- **SC-008**: Every answer of every monitor in a session is in the records that the main orchestrator shows before that session ends.

## Assumptions

- A subagent of the orchestrator's session has the orchestrator's session id, so the approve lock accepts a monitor. This was tested on 2026-11-26.
- Not tested yet: a subagent can run the worker `answer` and `approve` commands with no permission prompt to the user. Only `list` was tested from a subagent. The whole feature rests on this fact, so the first task of Plan is a live probe with a real worker. If it fails, the feature stops for a new decision and the main orchestrator watches as today.
- A subagent can report to the main session only when its run ends. So a `needs you` ends the run, and the worker waits until the same monitor starts again with the answer.
- The bound of FR-021 and the time from a dialog to its answer are measured in Plan before a number is set.
- This feature is step 1 of the loop work. A monitor runs no review loop, and no later loop feature is part of it.
- Out of scope: a monitor for a Codex tab, a round limit for PR reviews, any change to lane steps or gates, and workers by default for `[P]` tasks.
- CodeRabbit and the Codex PR reviews stay as they are today: they run on the user's word.
- This repo has no `.stratum/constitution.md`.
- Three research questions are queued for Plan in `decisions.md`: whether an agent with a fixed tool list gets the `advisor` tool, how a monitor asks Codex about one decision, and what happens when two monitors call Codex at the same time.
