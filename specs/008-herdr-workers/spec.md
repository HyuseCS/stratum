# Feature Specification: Orchestrator Starts Worker Sessions

**Feature Branch**: `003-session-mods`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "GitHub issues #11 and #17 on HyuseCS/stratum as one feature: the Stratum orchestrator starts worker sessions (headless `claude -p` for quick local tasks, and a `claude` in its own herdr pane and git worktree for visible or remote tasks, PC or laptop), gives each a brief and a `/goal`, relays the worker's questions to the user, collects the result, reviews and merges, and closes the pane. Workers on one project act as a team." The issue bodies are the source. Decisions D11 to D21 are in `decisions.md` (codes continue from the #32 grill). Spike #9 (`specs/003-session-mods/research.md`) proved the pieces: a session starts with no human step, gets a message by name, and stops with nothing left. #32 (`specs/007-herdr-workspace`) gives the script that opens a herdr workspace.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One worker in a herdr pane on this machine (Priority: P1)

The user asks the orchestrator: "run T004 in a worker". The orchestrator makes a git worktree and
a herdr workspace for it, labelled after the task, starts a `claude` in the pane, writes the brief
into the worktree, and sends one prompt: a `/goal` with a short, checkable condition that points
at the brief. The worker builds on its own. The user can watch the pane the whole time. When the
worker settles, the orchestrator reads the result file, reviews the branch, merges it on green,
closes the pane and workspace, and names the worktree folder as ready to remove.

**Why this priority**: This is the Done-when of #17 and the base of every other story. Without
it nothing else has value.

**Independent Test**: Ask for one small task in a worker. See the worker in its pane, get the
result back with no human step, see the branch merged, and find no pane, workspace, worker
process or session left afterwards, only the worktree and the branch.

**Acceptance Scenarios**:

1. **Given** a task with a test command, **When** the user asks for it in a worker, **Then** a
   worktree and a workspace labelled after the task exist, a `claude` runs in the pane, and the
   brief is in the worktree.
2. **Given** the worker is running, **When** the user looks at the pane, **Then** they see the
   worker's work as it happens, and can type into it.
3. **Given** the worker settles, **When** the orchestrator reads the result file, **Then** the
   result names what was built, the test result, and the commit, and the orchestrator reviews the
   branch and merges it on green with no human step.
4. **Given** the merge is done, **When** the orchestrator closes the worker, **Then** the pane and
   workspace are gone, the worktree folder and the branch stay, the report names the folder as
   ready to remove, and no worker process or session is left.
5. **Given** the worker fails or is stopped, **When** the orchestrator reports, **Then** the pane
   stays open so the user can read it, and nothing is merged.

---

### User Story 2 - The worker asks, the orchestrator answers or asks the user (Priority: P2)

The worker hits a decision it cannot make. It asks in its own pane. herdr marks it `blocked`.
The orchestrator sees that, reads the question from the pane, and decides it with the
`/stratum:st` rule: a small decision it answers itself, a big one it asks the user first. It sends
the answer into the pane and lists every answer it gave on its own at the end of the run (D26).
The worker goes on. The user can also answer in the pane directly at any time.

**Why this priority**: The user's rule: a worker asks the orchestrator; the orchestrator decides
small questions and asks the user on big ones (D26). Without it an autonomous worker either
guesses or stalls.

**Independent Test**: Give a worker a task whose brief forces one small and one big question. The
orchestrator answers the small one itself and lists it at the end, the big one reaches the user
through the orchestrator, both answers reach the worker, and the worker finishes.

**Acceptance Scenarios**:

1. **Given** a running worker, **When** it asks a small question (inside the brief, the plan and
   the task's files), **Then** the orchestrator answers it within its wait, the worker leaves
   `blocked`, and the answer is listed at the end of the run.
2. **Given** a running worker, **When** it asks a big question (spec, scope, approach, privacy,
   access, data model, contracts, dependencies, cannot be undone, audience, cost), **Then** the
   orchestrator puts it to the user with the worker's name, sends the user's answer into the
   pane, and the worker leaves `blocked`.
3. **Given** the user types the answer in the pane directly, **When** the orchestrator next
   checks, **Then** it sees the worker working again and does not send a second answer.
4. **Given** a permission prompt in the worker (for example a tool permission prompt), **When** it
   shows, **Then** it is handled the same way as a question.

---

### User Story 3 - A worker on the laptop (Priority: P3)

The user asks: "run T004 in a worker on the laptop". The worktree, workspace, brief, pane and
result live on the laptop. Every herdr call names the machine. The brief goes over ssh, the
result comes back over ssh. The rest is the same as story 1, including the question path.

**Why this priority**: D11: workers are cross-machine, PC to laptop and back.

**Independent Test**: With the laptop reachable, run one task in a worker there. The result comes
back here, the branch is merged here after a fetch, and nothing is left on the laptop but the
worktree and the branch.

**Acceptance Scenarios**:

1. **Given** a saved, reachable machine, **When** the user asks for a worker there, **Then** the
   worktree, workspace and pane are on that machine, and the brief is in that worktree.
2. **Given** the worker settles, **When** the orchestrator reads the result, **Then** it reads the
   file on that machine and merges the branch here after fetching it.
3. **Given** the machine does not answer, **When** the user asks, **Then** nothing is made and one
   line says so.

---

### User Story 4 - A team of workers on one project (Priority: P4)

The user asks: "build user story 2 with a team of three". The orchestrator starts one worker per
task, each with the roster in its brief: every teammate's name, machine, branch and task. The
team rules in the brief: commit each finished unit, fetch before you build on a teammate's work,
ask a teammate by name (SendMessage on the same machine, `herdr agent prompt` across machines),
and never merge. The orchestrator reviews each branch and is the only one who merges.

**Why this priority**: The user's rule: workers on one project act as a development team with
one standard. D16.

**Independent Test**: Start two workers on this machine with two tasks where the second builds on
the first. The second worker fetches the first's commit and reaches the first by name. Both
branches are reviewed and merged by the orchestrator.

**Acceptance Scenarios**:

1. **Given** two or more tasks, **When** the user asks for a team, **Then** each worker's brief
   holds the full roster and the team rules.
2. **Given** a worker needs a teammate's work, **When** it fetches, **Then** it sees the teammate's
   commits on that branch.
3. **Given** a worker messages a teammate by name, **When** the teammate is on the same machine,
   **Then** the message is delivered by SendMessage; **When** it is on the other machine, **Then**
   it is delivered by `herdr agent prompt` with that machine.
4. **Given** every worker settled, **When** the orchestrator closes the team, **Then** each branch
   was reviewed and merged on green, in task order, and a merge conflict is brought to the user.

---

### User Story 5 - A headless worker for a quick local task (Priority: P5)

For a small local task with no question expected, the orchestrator runs `claude -p` with the
same `/goal` form, an allow list of tools, a turn limit and a timeout. The result comes back as
JSON. The headless worker never asks and never commits; the orchestrator commits on green.

**Why this priority**: D12 keeps the headless path from #11 for cases where a pane costs more
than it gives. It is last because the pane path covers every case the headless one does.

**Independent Test**: Run one small task headless. The JSON result holds the reply and the cost,
the change is in the working tree, nothing is committed by the worker, and no process is left.

**Acceptance Scenarios**:

1. **Given** a small local task, **When** the orchestrator runs it headless, **Then** the JSON
   result holds the worker's reply, the turn count and the cost, and the run ends within the
   timeout.
2. **Given** the headless worker would need a decision, **When** its turns end, **Then** the reply
   says what is missing and the orchestrator brings it to the user; nothing was committed.

---

### Edge Cases

- The worker does not settle within the wait bound: the orchestrator reports "still working" with
  the pane id, leaves everything open, and asks the user whether to wait more or stop it.
- The result file is missing after the worker settled: the orchestrator reads the pane as a
  fallback, reports "no result file", and does not merge.
- The `/goal` evaluator judges the goal impossible: the pane stays open, the orchestrator reports
  the reason from the worker's transcript, nothing is merged.
- Two workers edit the same file and the merge conflicts: the conflict goes to the user; the
  orchestrator does not resolve it.
- herdr, the machine, or `claude` is missing on the target: nothing is made, one line says why.
- The worker runs `git commit`: it passes (D24). Amend, push, reset --hard and branch delete
  still ask: that is a question (story 2).
- The orchestrator session ends while workers run: the workers keep running in their panes; the
  next orchestrator session finds them by their labels and names and takes over.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A pane worker MUST get its own git worktree and herdr workspace, made together by
  herdr, labelled after the task, on this machine or on one saved machine (D15, D11).
- **FR-002**: The brief MUST be a file in the worker's worktree and MUST hold: the task text and
  its test command, the Stratum lane the worker runs, the result file path, the roster (name,
  machine, branch, task per teammate), the team rules, and the Codex advisor line once #18 is
  merged (D16, D21).
- **FR-003**: The worker MUST get exactly one prompt: `/goal <condition>; read <brief> first and
  follow it`. The condition MUST be short and checkable: the task's test command exits 0, the
  change is committed on the worker's branch, and the result file is written (D21).
- **FR-004**: The orchestrator MUST wait for the worker through herdr's agent states (`working`,
  `idle`, `done`, `blocked`), with a wait bound, and MUST NOT poll by re-prompting (D13, D14).
- **FR-005**: The result MUST be read from the result file: directly on this machine, over ssh
  on the other. The pane text is for a look or a fallback, never the result (D13).
- **FR-006**: A `blocked` worker MUST be handled as a question: read the question from the pane
  and decide it with the `/stratum:st` rule. A small decision the orchestrator answers itself; a
  big decision it MUST put to the user with the worker's name first, then send the user's answer
  into the pane. Every answer the orchestrator gave on its own MUST be listed at the end of the
  run. If the user answered in the pane already, the orchestrator MUST NOT send a second answer
  (D14, D26).
- **FR-007**: For a remote worker every herdr call MUST name the machine, and the worktree, brief
  and result MUST live on that machine. The branch is fetched here before review (D11).
- **FR-008**: The team rules in every brief MUST say: commit each finished unit, merge a
  teammate's branch before building on its work (D25: same machine only), ask a teammate by name (SendMessage on the same machine,
  `herdr agent prompt` with the machine across machines), and never merge (D16).
- **FR-009**: The orchestrator MUST review each worker branch with the Stratum review and MUST be
  the only one who merges. It merges on green, in task order; a conflict goes to the user (D16).
- **FR-010**: After the merge the orchestrator MUST close the worker's pane and workspace, keep
  the worktree folder and the branch, and name the folder as ready to remove. A failed or stopped
  worker's pane MUST stay open (D18).
- **FR-011**: A headless worker MUST run with an allow list of tools, no question tool, a turn
  limit, a timeout and the same `/goal` form, MUST never commit, and its result MUST be read from
  the JSON output (D12, D19).
- **FR-012**: After a worker is closed nothing of it MUST remain except the worktree folder, the
  branch, and the session transcript (D18).
- **FR-013**: A pane worker is the user's normal `claude` with their plugins. The orchestrator MUST
  NOT grant it permissions beyond what `/goal` needs to run unattended (D19).
- **FR-014**: The feature is one new skill the orchestrator uses on request ("run T004 in a
  worker on the laptop", "build US2 with a team of three"). The existing build loop MUST stay as
  it is (D17).
- **FR-015**: The steps MUST be the same on every run and checkable without herdr, ssh or a real
  `claude`: a test with stand-ins that record every call MUST show the worktree and workspace
  calls, the brief content, the one prompt, the wait, the result read, the review and merge order,
  and the close, for both machines.
- **FR-016**: The orchestrator MUST be able to find running workers again after its own session
  ended, by their labels and agent names, and take over their wait and close.

### Key Entities

- **Worker**: one `claude` session for one task: name, machine, worktree, branch, workspace and
  pane ids, state, result file.
- **Brief**: the file the worker reads first: task, test command, lane, result path, roster,
  team rules, advisor line.
- **Roster**: the team list in every brief: name, machine, branch, task per worker.
- **Result file**: what the worker writes at the end: what was built, the test result, the
  commit, open points.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One task runs in a pane worker on this machine and its result comes back with no
  human step. The user can see the worker in its pane while it runs.
- **SC-002**: The same task runs in a pane worker on the laptop with the same result, checked by
  reading it back there.
- **SC-003**: A worker's big question reaches the user with the worker's name, a small one is
  answered by the orchestrator and listed at the end of the run, and every answer reaches the
  worker through the orchestrator.
- **SC-004**: Two workers on one machine share work through git and reach each other by name. Each
  branch is reviewed and merged by the orchestrator.
- **SC-005**: After a worker is closed, no pane, workspace, worker process or session of it is
  left, only its worktree folder, branch and transcript.
- **SC-006**: One quick task runs headless with its result read from JSON, nothing committed by the
  worker, and no process left.
- **SC-007**: A test with stand-ins goes red when a call loses its machine, when the brief loses
  the roster or the rules, or when the result is taken from the pane instead of the file.

## Assumptions

- herdr 0.9.4 on both machines, with `herdr worktree create`, `agent start --kind claude`,
  `agent prompt --wait`, `agent wait --until`, `agent read` and `--machine` as `herdr --skill`
  describes. The remote server already runs; the skill never starts or repairs it.
- Claude Code 2.1.302 or later on both machines, with `/goal` (https://code.claude.com/docs/en/goal.md)
  and cross-session messaging. `/goal` needs auto mode to run unattended, so the worker starts in
  auto mode. Agent Teams are not used.
- The `claude` in a pane loads the user's plugins, so Stratum, ponytail and the Codex advisor (when
  merged) are present in every worker.
- The #32 script and skill are on this branch. The worker feature reuses its pre-checks and its
  stub-test shape, not its layouts.
- One worktree per worker next to the repo, as `scripts/st-worktree.sh` and herdr do it. The
  orchestrator merges locally; nothing is pushed unless the user says push.
- A worker's transcript stays on disk after close, as the spike found.
- Token cost grows with every worker. The user decides the team size per request.
