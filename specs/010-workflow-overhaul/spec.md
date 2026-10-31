# Feature Specification: Workflow Overhaul

**Feature Branch**: `010-workflow-overhaul`

**Created**: 2026-10-31

**Status**: Draft

**Input**: User description: "GitHub issues #51, #48 and #55 on HyuseCS/stratum as one feature. #51: bring the newer skills into the lanes and look again at the lane steps. #48: fewer advisor calls, and no full test suite unless a human asks. #55: worker sessions stop on permission prompts the orchestrator cannot answer, and the test wait loop matches itself." Decisions D1 to D29 are in `decisions.md`. #51 stays open after this feature for a later skill-by-skill workflow review (D22).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fewer advisor runs and no surprise full suite (Priority: P1)

The user runs a Full-lane feature. The Codex plan review runs once at the end of Plan. Its
MEDIUM and LOW findings are handled without a second run. At Inspect, a plan that changed only by
fixes gets a waive line, not a new Codex run. The end-of-Build `/advisor` pass is skipped when
every story was reviewed and nothing changed after. Tests run only for the changed files and the
files that import them; the full suite runs only when the user asks. At the end of Build the user
sees the count of advisor calls.

**Why this priority**: #48 shows a real feature with 9 advisor calls and two 12-minute full runs
that the user had to stop. This costs time on every Full-lane feature.

**Independent Test**: Run a Full-lane feature whose Codex review returns only MEDIUM and LOW
findings and whose Inspect changes only fix findings. See 1 Codex run, 1 waive line, no
end-of-Build `/advisor` pass, no full-suite run, and a call count at the end.

**Acceptance Scenarios**:

1. **Given** a Codex REVISE with only MEDIUM and LOW findings, **When** the orchestrator handles
   them, **Then** the point does not run again in that gate pass.
2. **Given** a Codex REVISE with a CRITICAL or HIGH finding that changes the plan, **When** the fix
   is made, **Then** the point runs one more time, and never more than 2 times per gate pass.
3. **Given** a plan changed at Inspect only by fixes of findings, **When** the orchestrator reaches
   "OK to build?", **Then** it writes a `WAIVED` line with the new fingerprint and a reason to
   `advisor.md`, calls no Codex, the check passes, and the user sees the line and its reason.
4. **Given** a plan whose approach changed at Inspect, **When** the check runs, **Then** Codex runs
   again.
5. **Given** every story had an `st-review` and no code changed after the last one, **When** all
   tasks are done, **Then** the end-of-Build `/advisor` pass does not run; otherwise it runs once,
   on the changes after the last review only.
6. **Given** a changed file that 5 other files import, **When** an agent verifies the change,
   **Then** it runs the tests of those importers and not the full suite.
7. **Given** a change to shared config, test setup, a schema or migration, middleware, or a file
   imported by more than 20 files, **When** an agent must pick tests, **Then** the orchestrator
   asks the user, says why in short words, and offers a named list of tests or the full suite.

---

### User Story 2 - Workers do not stop on Stratum's own prompts (Priority: P1)

A worker session runs a heredoc that writes a test file and runs a grep. The git guard cannot
split the command, but it has no `git` in it, so it runs with no prompt. A heredoc with
`git status` runs; a heredoc with `git commit` still asks. Two workers whose tests cannot run at
the same time take turns through one Stratum lock, with a time limit, and never loop forever.

**Why this priority**: #55 shows workers stopped for 8 and 23 minutes on these two problems, and
the user had to go to each tab or run `kill`.

**Independent Test**: Feed the git guard the four commands of FR-008 and see each decision. Start
two test runs through the lock at the same time and see the second wait, then run; start one with
a held lock and a short limit and see it stop and report.

**Acceptance Scenarios**:

1. **Given** a command the guard cannot split with no `git` word, **When** the guard runs,
   **Then** it gives no decision and the command runs.
2. **Given** a command the guard cannot split with a line `git status` or `git log --oneline`,
   **When** the guard runs, **Then** it reads that line alone, judges it with today's rules, and
   the command runs.
3. **Given** a command the guard cannot split with a line `git commit -m x`, **When** the guard
   runs, **Then** it asks, as today for a commit.
4. **Given** a command the guard cannot split with `git` it cannot read as a full command (for
   example inside Python code), **When** the guard runs, **Then** it asks.
5. **Given** a test run holds the lock, **When** a second run starts, **Then** it waits, and runs
   when the first ends.
6. **Given** the lock is held past the time limit, **When** a waiting run reaches it, **Then** it
   stops waiting, runs nothing, and reports to the orchestrator, which tells the user.

---

### User Story 3 - The right advisors for the risk (Priority: P2)

The orchestrator picks a risk level with the lane (High, Normal, Low, None) and shows it in the
lane line. The advisor matrix then names the advisors at each point. In herdr, Codex runs as an
agent in its own tab of the same workspace, read-only, and the user can watch it. In High cases
the two advisors review alone, then talk until they agree, at most 3 rounds, and the last round
must give a compromise. A point with no compromise goes to the user.

**Why this priority**: More views where the risk is high, fewer calls where it is low, and the
user can see what Codex reviewed.

**Independent Test**: Run the plan point at each risk level with stand-ins for Codex and
`/advisor`, and see which advisors are called, the rounds, the compromise step and the record.

**Acceptance Scenarios**:

1. **Given** a task, **When** the orchestrator picks the lane, **Then** the lane line names the
   risk level, and the user can change it.
2. **Given** advisor mode `auto`, **When** an advisor point runs, **Then** the advisors called are
   the ones the matrix names for that point and risk level; modes `codex`, `both` and `off`
   override the matrix.
3. **Given** the orchestrator runs in herdr, **When** a Codex point runs, **Then** Codex runs as a
   herdr agent in its own tab of the same workspace, read-only, with no permission prompts, and
   at most one Codex agent exists per workspace.
4. **Given** Codex's answer in the tab, **When** the orchestrator reads it, **Then** the answer
   between the two marker lines is checked against the verdict format, and a bad answer counts
   as BLOCKED.
5. **Given** a High point, **When** both advisors answered alone, **Then** they talk at most 3
   rounds; in the last round each proposes a compromise for every open point; a point with no
   compromise both accept goes to the user with both views in short, simple words.
6. **Given** a finished talk, **When** the orchestrator records it, **Then** `advisor.md` has the
   rounds, the agreed points, the compromises, the points sent to the user and the number of
   calls.
7. **Given** the orchestrator does not run in herdr, **When** a Codex point runs, **Then** Codex
   runs in the background as today.
8. **Given** small decisions the orchestrator made during a story, **When** the story review runs,
   **Then** the list goes to the advisors the matrix names; a decision an advisor sends to the user
   is undone if the user says no.

---

### User Story 4 - Autonomous build with workers (Priority: P2)

The user says "build with workers, autonomous". Build sends a phase's `[P]` tasks to `st-worker`.
Each worker opens in its own herdr workspace with the user's full template. In this mode a
Stratum permission hook in each worker sends its prompts to the orchestrator. The orchestrator
approves small, safe prompts one time only, and sends risky ones to the user with the tab name in
short, simple words. The mode lasts for this run only.

**Why this priority**: Parallel workers that do not wait on the user for routine prompts, with a
safety check on each approval.

**Independent Test**: With stand-ins for herdr and the worker, run a worker build in autonomous
mode. Feed the hook a test command, an edit in the worktree, a push and an edit outside the
worktree. See the first two approved one time, the last two sent to the user, and every approval
recorded.

**Acceptance Scenarios**:

1. **Given** normal mode, **When** a worker shows a permission prompt, **Then** the orchestrator
   approves nothing and tells the user the tab name and what the prompt asks.
2. **Given** the user says "build with workers", **When** Build reaches a phase with `[P]` tasks,
   **Then** it sends them to `st-worker`; without those words it uses subagents as today.
3. **Given** a worker starts, **When** its workspace opens, **Then** it has the user's full
   template layout with the worker agent in the Main tab.
4. **Given** autonomous build mode, **When** a worker's prompt is small and safe (a test, a lint,
   an edit in its own worktree), **Then** the orchestrator approves it one time only and records
   it.
5. **Given** autonomous build mode, **When** a worker's prompt is risky or on the never-approve
   list, **Then** the orchestrator approves nothing and tells the user the tab name and the prompt
   in short, simple words, and the other workers keep running.
6. **Given** the classifier blocks an approval, **When** it happens, **Then** the orchestrator tries
   no other way and the prompt goes to the user.
7. **Given** autonomous build mode is on, **When** the run ends or the user says "stop
   autonomous", **Then** it is off, and a new session never starts in it.
8. **Given** the user asks to open workspaces for agents to work by themselves, **When** the
   orchestrator does it, **Then** it uses `st-worker`, in autonomous build mode, and a worker on a
   whole issue opens its own PR.

---

### User Story 5 - Lanes use the Design lane and run more tasks at once (Priority: P2)

The planner marks each new-screen task, and the user picks its Design lane mode at Plan. Build
sends it to `/stratum:st-design` and goes on with other tasks. If the Design lane cannot start,
only that task pauses. The planner also splits the work so that as many tasks as possible run at
the same time, each owning its files.

**Why this priority**: New screens get the Design lane's checks, and builds take less time.

**Independent Test**: Plan a feature with one new page and two independent helpers. See the page
task marked with its mode, both helpers marked `[P]` with their own files, and the page sent to
the Design lane in Build.

**Acceptance Scenarios**:

1. **Given** a task that makes a page or view the app does not have yet, **When** the planner
   writes tasks, **Then** it marks the task as a new screen, and at Plan the user picks autonomous,
   new look, or (after #57) custom design.
2. **Given** a new-screen task, **When** Build reaches it, **Then** it sends it to
   `/stratum:st-design` in that mode, goes on with the other tasks, and shows the screen's report
   with the story review.
3. **Given** a change to an existing screen, **When** Build reaches it, **Then** `st-build` with
   `st-ui-ux` builds it, reading the project's `DESIGN.md` if one exists.
4. **Given** the Design lane's tool check fails or no dev server runs, **When** Build reaches the
   screen, **Then** only that task pauses, the user is told what is missing in short, simple words,
   and on "go" the screen runs again; Build never changes to `st-ui-ux` without telling the user.
5. **Given** tasks that share no files and need no other task's result, **When** the planner writes
   tasks, **Then** they are marked `[P]`, each names the files it owns, and no two tasks that run
   at the same time own the same file; user stories that share no files run at the same time.
6. **Given** tests that cannot run at the same time, **When** the planner writes tasks, **Then** it
   marks them, and Build runs them through the lock of User Story 2.

---

### User Story 6 - Skill clean-up (Priority: P3)

When a task names GitHub issues, `/stratum:st` triages them first. The Plan phase no longer offers
to make GitHub issues from tasks. `st-frontend-design` is removed.

**Why this priority**: Wrong issue claims are found before the grill (F4 and F5 in this feature
were found by hand), and the plugin carries no unused skill.

**Independent Test**: Start `/stratum:st` with "#51" and see one triage report before the lane
line. Run the Plan phase and see no issue question. Search the plugin and see no
`st-frontend-design`.

**Acceptance Scenarios**:

1. **Given** a task that names issue numbers, **When** `/stratum:st` starts, **Then** it runs
   `st-triage` on them side by side, shows a short verdict per issue, then picks the lane.
2. **Given** the Plan phase ends, **When** the orchestrator reaches its end, **Then** it does not
   ask to make GitHub issues; issues are made only when the user asks in their own words.
3. **Given** the plugin, **When** it is searched, **Then** `st-frontend-design` has no folder,
   license file, `vendor.lock` entry, or row in `THIRD_PARTY_NOTICES.md`, `README.md` or
   `DESIGN.md`.

### Edge Cases

- A command the guard cannot split has `git` only inside a quoted string, such as an `echo`
  text: the guard asks, because it cannot read it as a full command (safe side).
- Codex's tab was closed by the user mid-feature: the orchestrator starts a new Codex agent in the
  workspace and gives it the review as a new conversation.
- Two orchestrator sessions in one workspace: the second finds the existing Codex agent and uses
  it, one review at a time; it does not start a second one.
- The permission hook gets no answer from the orchestrator (session ended): the prompt stays for
  the user, as in normal mode.
- The lock holder crashed and left the lock: the lock is freed when its owner process no longer
  runs, so the next run does not wait for the time limit.
- A High talk where one advisor has `no advisor` (Codex not found, mode off): the point runs with
  the one advisor left and the record says so.
- Autonomous mode is on and the user's session ends: the next session starts in normal mode.

## Requirements *(mandatory)*

### Functional Requirements

**Advisor runs (#48)**

- **FR-001**: Each advisor point MUST run one time per gate pass. A REVISE with only MEDIUM and
  LOW findings MUST count as passed. The point MUST run again only when a CRITICAL or HIGH finding
  changed the plan or the plan's approach changed, at most 2 runs per gate pass (D11). The
  approach changed when a user story or task was added or removed, a file outside the plan's
  file list is now touched, or a design choice in `plan.md` was replaced; a fix inside a task's
  own text and files is not an approach change.
- **FR-002**: `st-advisor.sh` MUST have a `waive plan <feature dir> "<reason>"` command that calls
  no advisor and appends a `WAIVED` record with the current input fingerprint and the reason;
  `check plan` MUST pass after it until the input changes again. The orchestrator MUST use it at
  Inspect only when the plan changed by fixes of findings with no new approach, and MUST show the
  line and reason at "OK to build?" (D13).
- **FR-003**: The end-of-Build `/advisor` pass MUST be skipped when every story had an `st-review`
  and no code changed after the last one; otherwise it MUST run one time on the changes after the
  last review (D14).
- **FR-004**: At the end of Build the orchestrator MUST show the count of Codex runs, waive lines
  and `/advisor` calls for the feature (D14).

**Tests (#48)**

- **FR-005**: No skill, agent, procedure or planned task MUST run the project's full test suite
  unless the user asks in their own words. Planned tasks MUST name the exact test command (D18).
- **FR-006**: The default test scope MUST be the tests of the changed files and of the files that
  import them, found by search (D18).
- **FR-007**: When the change touches shared config, test setup, a schema or migration,
  middleware, or a file imported by more than 20 files, the orchestrator MUST ask the user, say
  why in short words, and offer a named list of tests or the full suite (D18).

**Git guard and test lock (#55)**

- **FR-008**: When the git guard cannot split a command: with no `git` word it MUST give no
  decision; for each line with a `git` word it MUST read that line alone and judge the full git
  command and its parameters with today's rules; a `git` it cannot read as a full command MUST
  ask (D19).
- **FR-009**: Stratum MUST give one lock script for test runs that cannot run at the same time:
  one run per project at a time, the others wait, a time limit (default 10 minutes) after which a
  waiting run stops, runs nothing and reports; a lock whose owner process is gone MUST be freed.
  It MUST use only POSIX shell tools (no `pgrep`, no `flock`) so it runs on Linux, macOS and
  Windows (Git Bash); it is tested on Linux (D20).
- **FR-010**: `st-test`, `st-build`, `st-debug` and the worker brief MUST say to use the lock for
  marked tests and never to write a wait loop of their own (D20).

**Advisor matrix and talk (#48, #55)**

- **FR-011**: The orchestrator MUST pick a risk level with the lane (High: privacy and access, data
  model, contracts, secrets, money, cannot be undone; Normal: other Full work; Low: Fast; None:
  Quick and Design), show it in the lane line, and let the user change it (D15).
- **FR-012**: Advisor mode `auto` MUST call the advisors the matrix in D15 names per point and risk
  level, and MUST be the default when `.stratum/advisor.json` has no mode; `codex`, `both` and
  `off` MUST override the matrix (D15).
- **FR-013**: In herdr, Codex MUST run as a herdr agent in its own tab of the orchestrator's
  workspace, read-only and never asking; at most one Codex agent MUST exist per workspace; it MUST
  start a new conversation per feature; its answer MUST be read between two marker lines and
  checked against the verdict format, and a bad answer MUST count as BLOCKED. The tab MUST run only
  with the Stratum Codex home the user opted in to, and only after the live probe T050 passed;
  otherwise, and outside herdr, Codex MUST run in the background as today (D12, D25).
- **FR-014**: At a High point the two advisors MUST first answer alone, then talk at most 3 rounds;
  in the last round each MUST propose a compromise for every open point; a point with no
  compromise both accept MUST go to the user with both views in short, simple words (D16, D17).
- **FR-015**: Each talk MUST be recorded in `advisor.md`: rounds, agreed points, compromises,
  points sent to the user, number of calls (D17).
- **FR-016**: Small decisions the orchestrator makes MUST be listed and, at each story review (at
  the end of a Fast change), sent to the advisors the matrix names; a decision an advisor sends to
  the user MUST be undone if the user says no (D15).

**Workers and autonomous build mode (#55, #51)**

- **FR-017**: In normal mode the orchestrator MUST NOT approve a worker's permission prompt; it
  MUST tell the user the tab name and what the prompt asks. `st-worker.sh answer --keys` MUST be
  used only for a worker's questions, never for a permission prompt (D1).
- **FR-018**: Autonomous build mode MUST turn on only when the user says so in their own words for
  a run, MUST be shown as one line and in the status line, MUST end with that run or on "stop
  autonomous", and a new session MUST NOT start in it (D21).
- **FR-019**: In autonomous build mode each worker MUST start with a Stratum permission hook that
  sends its prompts to the orchestrator. The orchestrator MUST approve small, safe prompts (a
  test, a lint, an edit in the worker's own worktree, or a commit in the worker's own worktree,
  on its own branch, that stages only files its task owns and has no `--amend` and no
  `--no-verify`) one time only, and MUST send all others to
  the user with the tab name in short, simple words. It MUST never approve: push, force-push,
  deleting a branch or worktree, `reset --hard`, anything outside the worker's worktree, secrets
  or `.env`, new dependencies, network calls to new hosts. When the classifier blocks an approval,
  it MUST try no other way. Every approval MUST be recorded and listed at the end of the run. The
  hook MUST act only while the main checkout's `.stratum/autonomous` holds the orchestrator's
  session id and the worker's session file matches it, and in a worker session every Bash
  command, Edit or Write that touches `.stratum/approve/` or `.stratum/autonomous`, or runs
  `st-worker.sh approve`, `pass` or `autonomous-off`, MUST be denied (D27). On a saved machine,
  `start --autonomous` MUST write that machine's flag and the run's end or "stop autonomous" MUST
  remove it (D28). There is no fallback to standing permissions: if the plugin hook does not
  fire, `start --autonomous` loads the same hook with `--settings` once the user OKs it; if that
  fails too, autonomous mode stays off and every prompt goes to the user (D1, D23, D29).
- **FR-020**: Build MUST send a phase's `[P]` tasks to `st-worker` when the user says so ("build
  with workers", "on the laptop"); otherwise it MUST use subagents as today (D2).
- **FR-021**: `st-worker` MUST open each worker workspace with the user's full template layout, the
  worker agent in the Main tab (D10).
- **FR-022**: When the user asks the orchestrator to open workspaces for agents to work in by
  themselves, it MUST do so through `st-worker` in autonomous build mode. `st-herdr-workspace`
  stays a manual tool (D9).

**Lanes (#51)**

- **FR-023**: The planner MUST mark each new-screen task (a page or view the app does not have
  yet), and the user MUST pick its Design lane mode at Plan: autonomous, new look, or custom design
  once #57 is built (D4).
- **FR-024**: Build MUST send a new-screen task to `/stratum:st-design` in its mode, go on with the
  other tasks, and show the screen's report with the story review. Changes to existing screens
  MUST stay with `st-build` + `st-ui-ux`, and `agents/st-build.md` MUST read the project's
  `DESIGN.md` in place of "the project's design brief" (D4, D6).
- **FR-025**: When the Design lane cannot start in Build, only that task MUST pause; the user MUST be
  told what is missing in short, simple words; on "go" it MUST run again; Build MUST NOT change to
  `st-ui-ux` without telling the user (D5).
- **FR-026**: The planner MUST mark as `[P]` every task that shares no file and needs no other
  task's result, MUST name the files each `[P]` task owns, MUST NOT let two tasks that run at the
  same time own the same file, MUST run user stories that share no files at the same time, and
  MUST mark tests that cannot run at the same time (D3).
- **FR-027**: In the Plan phase the planner MUST list every lane step the new rules make out of date
  or wrong and fix it in this feature; anything bigger MUST go to the user (D22).

**Skills (#51)**

- **FR-028**: When a task names GitHub issue numbers, `/stratum:st` MUST run `st-triage` on them
  side by side, show a short verdict per issue, then pick the lane (D7).
- **FR-029**: The Plan phase MUST NOT ask to make GitHub issues from tasks. Stratum MUST make an
  issue only when the user asks in their own words. `/stratum:st-issues` stays a manual tool (D8).
- **FR-030**: `st-frontend-design` MUST be removed: its folder, license file, `vendor.lock` entry,
  and its rows in `THIRD_PARTY_NOTICES.md`, `README.md` and `DESIGN.md` (D6).
- **FR-031**: Each FR MUST have a test in `tests/` that fails before the change and passes after.

### Key Entities

- **Advisor record** (`<feature>/advisor.md`): one entry per advisor run, waive or talk: point,
  time, input fingerprint, verdict, findings; a talk adds rounds, agreed points, compromises,
  points sent to the user and calls.
- **Advisor setting** (`.stratum/advisor.json`): mode `auto`, `codex`, `both` or `off`, and the
  Codex model.
- **Approval record**: one entry per prompt the orchestrator approved in autonomous build mode:
  worker, tab, prompt text, time. Listed at the end of the run.
- **Test lock**: one per project; owner process and start time.
- **Risk level**: High, Normal, Low or None, picked with the lane.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Full-lane feature with only MEDIUM and LOW advisor findings and fix-only Inspect
  changes has 1 Codex plan run, not 3 or more.
- **SC-002**: No Stratum step starts the full test suite without the user's words: 0 full-suite
  runs in a feature where the user did not ask.
- **SC-003**: In a worker run, 0 stops on "The git guard could not parse the command" for commands
  with no `git`.
- **SC-004**: Two runs that wait for the test lock never wait longer than the time limit, and the
  user never has to run `kill` on a wait.
- **SC-005**: In autonomous build mode, workers stop only for prompts the orchestrator sent to the
  user, and the user gets one short message per such prompt with its tab name.
- **SC-006**: Every FR has a test that fails before the change and passes after (FR-031).

## Assumptions

- The user is the only user of the harness; no one else's workflow breaks.
- This feature changes `st-build`, but its own build runs under today's rules. The new rules apply
  from the next feature.
- The Claude Code permission hook in worker sessions can send a prompt to the orchestrator and
  wait for its answer; the Plan phase checks this, and FR-019 has the fallback.
- herdr 0.9.4 supports `--kind codex`; Codex runs with `-s read-only -a never`.
- The approval record lives in the run's scratch space and is not committed, because a prompt can
  hold a secret value.
- The parasat constitution's wait loop is out of scope; the user gets the line to change there.
- #57 (custom design mode) is not built in this feature; FR-023 offers it only after it exists.
- #51 stays open after this feature for a skill-by-skill workflow review, with #56.
