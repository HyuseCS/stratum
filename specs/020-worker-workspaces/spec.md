# Feature Specification: Workers in their own herdr workspaces, each with its own Codex tab

**Feature Branch**: `worker-f94`

**Created**: 2026-11-09

**Status**: Draft

**Input**: User description: "Issue #94: `st-worker.sh start` opens each worker as a tab in the orchestrator's herdr workspace. With several workers this is confusing, and all workers get the same Codex tab name, so only one gets the Codex tab and the others fall back to headless. Run each worker in its own herdr workspace with its own Codex tab. Grill decisions D10 to D12 and the defaults in `decisions.md`."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Each worker gets its own workspace (Priority: P1)

The orchestrator starts one or more workers. Each worker opens in a new herdr workspace of its
own, with its worktree as the folder. The workspace is a separate sidebar entry, named
`<orchestrator> / <id>: <task words>`, for example `stratum / f77: Autonomous sessions`, so the
user sees at a glance which worker it is and which orchestrator started it. Inside it, one tab
labelled `worker-<id>` holds the worker agent and lazygit side by side, as today. The new
workspace does not take the focus. The orchestrator's own workspace gets no new tab.

**Why this priority**: This is the core of #94. All other parts follow from it.

**Independent Test**: Start two workers from a workspace labelled `stratum`. Check that two new
workspaces exist, each with the right name and folder, each with one `worker-<id>` tab, and that
the orchestrator's workspace has no new tab.

**Acceptance Scenarios**:

1. **Given** the orchestrator runs in a workspace labelled `stratum`, **When** it starts worker `f77` for a task whose first heading is `Autonomous sessions`, **Then** a new workspace named `stratum / f77: Autonomous sessions` opens with the worker's worktree as its folder, and it does not take the focus.
2. **Given** that new workspace, **When** the user looks inside it, **Then** it has one tab labelled `worker-f77` with the worker agent and lazygit side by side.
3. **Given** two workers started from the same orchestrator, **When** the user looks at the sidebar, **Then** both workspace names start with the orchestrator's name, so they sort together.
4. **Given** a task whose first heading is longer than 30 characters, **When** the worker starts, **Then** the task words in the workspace name are cut to 30 characters.
5. **Given** a worker in its own workspace, **When** the orchestrator runs `wait`, `watch`, `answer`, `followup`, `goal`, `resend` or `result` with its id, **Then** each finds the worker by its `worker-<id>` tab as today.

---

### User Story 2 - Each worker gets its own Codex tab (Priority: P1)

A worker runs a lane that calls the Codex advisor. The advisor opens its Codex tab (label `Codex`) in the
worker's own workspace, with the Codex agent name `st-codex-worker-<id>`. Two or more workers each get their own
Codex tab at the same time, and none falls back to headless because the name is in use.
The orchestrator's Codex agent name does not change.

**Why this priority**: This is the defect that #94 reports: today only one worker gets the
Codex tab, the others run headless.

**Independent Test**: In a worker workspace for worker `f77`, compute the Codex agent name and
check it is `st-codex-worker-f77`. In the orchestrator's workspace, check the name is the same
as before.

**Acceptance Scenarios**:

1. **Given** worker `f77` in its own workspace, **When** it runs the advisor, **Then** the Codex agent name is `st-codex-worker-f77` and its `Codex` tab opens in that workspace.
2. **Given** workers `f77` and `f79` from the same orchestrator, **When** both run the advisor, **Then** each gets its own Codex tab, and neither reports the name as in use elsewhere.
3. **Given** the orchestrator's workspace labelled `stratum`, **When** the orchestrator runs the advisor, **Then** the Codex agent name is `st-codex-stratum`, as today.
4. **Given** a workspace whose name has a long orchestrator part, **When** a worker in it runs the advisor, **Then** the worker part is not cut off: the name is still `st-codex-worker-<id>`.

---

### User Story 3 - Close removes the worker's whole workspace (Priority: P1)

After the merge, the orchestrator closes the worker. `close` removes the worker's whole
workspace, with the worker tab and the Codex tab in it. The worktree folder and the branch stay,
as today. All the refusals of `close` stay: a working or blocked worker, an open PR, PRs that
cannot be read, a symlinked `.stratum`.

**Why this priority**: Without it, every closed worker would leave an empty workspace or a
lone Codex tab in the sidebar.

**Independent Test**: Start a worker, add a Codex tab to its workspace, then close the worker.
Check that the workspace is gone, that no other workspace was closed, and that the worktree
folder is still there.

**Acceptance Scenarios**:

1. **Given** a finished worker with a Codex tab in its workspace, **When** the orchestrator runs `close`, **Then** the worker's workspace is closed with both tabs, and `close` prints the folder as ready to remove.
2. **Given** a worker that is working or blocked, or has an open PR, **When** the orchestrator runs `close`, **Then** it is refused as today and nothing is closed.
3. **Given** a worker whose tab is in a workspace that holds other tabs that are not the worker's (an old worker started before this feature, in the orchestrator's workspace), **When** the orchestrator runs `close`, **Then** only the worker's tab is closed and the workspace stays.

---

### User Story 4 - The same on a saved machine (Priority: P2)

The orchestrator starts a worker on a saved machine. `start` makes the same per-worker
workspace on that machine, with the same name, folder and tab. The `st-workers` workspace and the
use of the main checkout's open workspace go away. `close` with `--machine` closes that
workspace on that machine.

**Why this priority**: Workers must work on the PC and the laptop alike, but the local case is
the one the user hit first.

**Independent Test**: With the herdr stub for a saved machine, start a worker with `--machine`
and check that a workspace with the right name and folder is made on that machine, and that no
`st-workers` workspace is made or used.

**Acceptance Scenarios**:

1. **Given** a saved machine, **When** the orchestrator starts a worker there, **Then** a new workspace named `<orchestrator> / <id>: <task words>` is made on that machine with the worker's worktree as its folder.
2. **Given** a saved machine that has an `st-workers` workspace or a workspace with the main checkout open, **When** the orchestrator starts a worker there, **Then** neither is used.
3. **Given** a worker on a saved machine, **When** the orchestrator runs `close --machine`, **Then** that worker's workspace on that machine is closed.

---

### User Story 5 - List names each worker's workspace (Priority: P3)

In a new session, the orchestrator runs `list` to find workers. Each found worker line also
names the worker's workspace, so the orchestrator can tell the user where to look.

**Why this priority**: Helpful for finding workers, not needed for the fix.

**Independent Test**: Start a worker and run `list`. Check that its line ends with the workspace name.

**Acceptance Scenarios**:

1. **Given** a worker in its own workspace, **When** the orchestrator runs `list`, **Then** the worker's line names its workspace.

---

### User Story 6 - Worker folder and branch named after the project and the issue (Priority: P1, round 3)

The orchestrator starts a worker for an issue. The worker's worktree folder and its branch get
the same name, built from the project and the issue: `stratum-94` for a worker on the whole of
issue 94, `stratum-93_t005` for a worker on task T005 of issue 93, `parasat-prod-142` when the
project rule adds an env part. The user sees from the folder and the branch which project and
issue the work is for, the same way as for branches the user makes by hand. A worker with no
issue gets the task words instead. The tab label `worker-<id>` stays the key every command uses
to find the worker, and workers started before this change keep working.

**Why this priority**: The user added it to #94 after the PR opened (D21 to D23). It changes
what every new worker leaves on disk and on the remote.

**Independent Test**: Start a worker with an issue, one with an issue and a task id, one with a
project and env override, and one with no issue. Check each folder and branch name, that a
taken name is refused before anything is made, and that `wait`, `result`, `list` and `close`
find each worker and use its real branch.

**Acceptance Scenarios**:

1. **Given** the repo folder `stratum`, **When** the orchestrator starts worker `f94` for the whole of issue 94, **Then** the worktree folder is `<parent>/stratum-94` and the branch is `stratum-94`.
2. **Given** the repo folder `stratum`, **When** the orchestrator starts worker `t005` for task T005 of issue 93, **Then** the folder and branch are `stratum-93_t005`.
3. **Given** a project rule that says project `parasat` and env `prod`, **When** the skill starts a worker for issue 142, **Then** it passes the project and env, and the folder and branch are `parasat-prod-142`.
4. **Given** no issue, **When** the orchestrator starts a worker whose task heading is `Autonomous sessions`, **Then** the folder and branch are `stratum-autonomous_sessions`.
5. **Given** a branch or folder with that name already exists, **When** the orchestrator starts the worker, **Then** `start` refuses before it makes a worktree, a branch or a workspace.
6. **Given** a project, env, issue or task id that is not a safe token, **When** the orchestrator starts the worker, **Then** `start` refuses before any git or herdr call.
7. **Given** a worker with the new name, **When** the orchestrator runs `wait`, `answer`, `followup`, `goal`, `resend`, `result`, `list` or `close` with its id, **Then** each finds it by the `worker-<id>` tab, and `result`, `close` and `list` use its real branch and folder.
8. **Given** a worker started before this change (folder `<repo>-worker-<id>`, branch `worker-<id>`), **When** the orchestrator runs any command with its id, **Then** it works as before.

---

### User Story 7 - Worker guards still know a worker (Priority: P1, round 3)

A worker on a branch such as `stratum-94` is still known as a worker by every check that knows
one today. The lock-2 guard still stops it from writing the autonomous-mode or approve files, the
orchestrator-only commands still refuse to run in it, the research skill still starts at once in
it, and its Codex agent is still `st-codex-worker-<id>`.

**Why this priority**: These checks found a worker by its `worker-*` branch. Without this story,
D21 would turn off an access guard (D24).

**Independent Test**: Start a worker with the new branch name in normal mode. In its folder, try
to write the autonomous-mode file and the worker marker by shell and by edit tool, run an
orchestrator-only command, and compute the Codex agent name. Check that each is refused or
named as before.

**Acceptance Scenarios**:

1. **Given** a worker worktree with the new branch name in normal mode, **When** the worker tries to make, change or remove a file under `.stratum/autonomous`, `.stratum/approve` or the worker marker, by shell or by edit tool, **Then** the try is refused.
2. **Given** that worktree, **When** someone runs `st-worker.sh approve`, `pass`, `autonomous-on` or `autonomous-off` there, **Then** it is refused as from a worker worktree.
3. **Given** that worktree, **When** the research skill checks for a worker, **Then** it sees a worker and starts at once.
4. **Given** that worktree, **When** the advisor names its Codex agent, **Then** the name is `st-codex-worker-<id>` (cut to 32 characters), and `close` matches that same name.
5. **Given** a worktree on a `worker-*` branch with no marker (made before this change), **When** any of these checks runs, **Then** it still sees a worker.
6. **Given** the orchestrator's own checkout (no marker, branch not `worker-*`), **When** any of these checks runs, **Then** it does not see a worker.

---

### Edge Cases

- The orchestrator's workspace has no label, or `start` runs with `--machine` outside a herdr pane: the orchestrator part of the name is the repo folder name.
- The task file has no heading: the workspace name is `<orchestrator> / <id>` with no task words.
- The first heading has Markdown marks (`#`, `**`, backticks) or a line break: only the plain words are used, on one line.
- Making the workspace fails: `start` removes the worktree and branch it just made, as it does today when the tab cannot be made, and stops with the herdr message.
- A workspace with the same name already exists (a worker with the same id was closed by hand but its workspace stayed): the duplicate id check of `start` (a `worker-<id>` tab already exists) stays the guard. A leftover workspace with no `worker-<id>` tab does not block `start`.
- Workers started before this feature (tabs in the orchestrator's workspace) can still be found, waited on and closed. `close` then closes only the tab (US3 scenario 3).
- `close` must never close the orchestrator's own workspace.
- Round 3: the repo folder name has upper-case letters or characters that are not safe (for example `My Repo`): the default project part is lower-cased, and `start` refuses a name with an unsafe character, telling the orchestrator to pass `--project`.
- Round 3: a task id with upper-case letters (`T005`) is lower-cased in the name (`stratum-93_t005`), as the tab label `worker-t005` is today.
- Round 3: no issue and no task heading: the feature part is the worker id (for example `stratum-f94`).
- Round 3: two workers for the same issue and no task id get the same name: the second `start` refuses (the name is taken).
- Round 3: the worker marker is a symlink, or a worker deleted it and switched to a `worker-*` branch: the checks read the marker only when it is a plain file, and a `worker-*` branch still counts.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `start` MUST make a new herdr workspace for each worker, with the worker's worktree as its folder, and with `--no-focus`. It MUST NOT add a tab to the orchestrator's workspace.
- **FR-002**: The workspace MUST be named `<orchestrator> / <id>: <task words>`. The orchestrator part is the label of the workspace that runs `start` (`HERDR_WORKSPACE_ID`), else the repo folder name. The task words are the plain text of the first Markdown heading of the task file, on one line, cut to 30 characters. With no heading, the name is `<orchestrator> / <id>`.
- **FR-003**: Inside the workspace, the worker MUST have one tab labelled `worker-<id>` with the worker agent and lazygit side by side, as today.
- **FR-004**: `wait`, `watch`, `answer`, `followup`, `goal`, `resend` and `result` MUST keep finding the worker by its `worker-<id>` tab, with no change to their behaviour.
- **FR-005**: The advisor MUST name a worker's Codex agent `st-codex-worker-<id>` and open its `Codex` tab in the worker's own workspace. The orchestrator's Codex agent name MUST stay as it is today. Exception (D14, D16): herdr agent names are at most 32 characters, so the name is cut to 32 characters; two ids over 16 characters that share their first 16 get the same name, and the second worker's Codex runs headless.
- **FR-006**: `close` MUST close the worker's whole workspace when it holds no tab other than the worker's own tab and its Codex tab. Otherwise it MUST close only the worker's tab. It MUST never close the workspace that runs `close`. All existing refusals and checks of `close` stay.
- **FR-007**: On a saved machine, `start` MUST make the same per-worker workspace on that machine. It MUST NOT use or make an `st-workers` workspace, and MUST NOT use the main checkout's open workspace.
- **FR-008**: If making the workspace or the worker tab fails, `start` MUST remove what it made (workspace, worktree, branch) and stop with the herdr message, as it does today for a failed tab.
- **FR-009**: `list` MUST name each found worker's workspace on its line.
- **FR-010**: `skills/st-worker/SKILL.md` MUST describe the per-worker workspace and its name, and MUST NOT name the `st-workers` workspace.
- **FR-011**: `tests/test_st_worker.sh` MUST cover: the workspace name with and without a heading, a long heading, the fallback name, no new tab in the orchestrator's workspace, close of the whole workspace, close of a tab in a shared workspace, the saved-machine path with no `st-workers`, and the `list` workspace name. The advisor tests MUST cover the worker Codex tab name and the unchanged orchestrator name.
- **FR-012**: All existing tests MUST still pass, changed only where they name the old tab-in-the-orchestrator's-workspace or `st-workers` layout.

Round 3 (D21 to D25):

- **FR-013**: `start` MUST give the worker's worktree folder and its branch the same name, `<project>-<feature>`, or `<project>-<env>-<feature>` when an env is given. The folder sits next to the repo, as today.
- **FR-014**: `<project>` MUST default to the repo folder name, lower-cased. The orchestrator MUST be able to give another project and an env part to `start`. The script MUST NOT read any project rule text itself.
- **FR-015**: `<feature>` MUST be the issue number for a worker on a whole issue, and `<issue>_<task id>` for a worker on one task of an issue. With no issue it MUST be the task words of FR-002, lower-cased, with every run of other characters turned into one `_`, cut to 30 characters. With no issue and no heading it MUST be the worker id.
- **FR-016**: Each name part (project, env, issue, task id) MUST be lower-cased and checked as a safe token (letters, digits, `.`, `_` and `-`, starting with a letter or digit, no `..`) before it reaches git, a path or ssh. A part that fails MUST stop `start` before any git or herdr call.
- **FR-017**: `start` MUST refuse a name whose branch or folder already exists, before it makes a worktree, a branch or a workspace, here and on a saved machine.
- **FR-018**: The tab label `worker-<id>` MUST stay the key every command uses to find a worker. `find_worker` and `list` MUST read the worker's branch and folder from the worktree of its pane, not from `worker-<id>`. `result` (its fetch on a saved machine), `close` (its open-PR check) and `list` MUST use that real branch. The commit guard file, the brief's Branch line and the `/goal` prompt MUST name the real branch.
- **FR-019**: Workers started before round 3 (folder `<repo>-worker-<id>`, branch `worker-<id>`) MUST keep working with every command.
- **FR-020**: `start` MUST write a worker marker `.stratum/worker` holding the worker id in the worktree, here and on a saved machine, with the same symlink and exists checks as the brief and guard files. `close` MUST remove it with the guard file.
- **FR-021**: A session MUST count as a worker when a plain-file worker marker exists in its folder or a folder above, or its branch starts with `worker-`, or (as today) `.stratum/approve` exists. Every worker check MUST use this rule: lock 2 in the approve hook, the "run this from the orchestrator's checkout" check of `st-worker.sh`, and the research skill's worker check.
- **FR-022**: Lock 2 MUST refuse a worker's write, change or removal of the worker marker, by shell and by edit tool, as it does for `.stratum/approve` and `.stratum/autonomous`.
- **FR-023**: The advisor MUST name a worker's Codex agent `st-codex-worker-<id>` (cut to 32 characters) from the marker's id, and from a `worker-*` branch when there is no marker. `close` MUST match the same name.
- **FR-024**: The st-worker skill MUST read the project's worktree naming rule from `.stratum/constitution.md` or the app's ORDINANCE file when there is one, pass the project and env parts to `start`, pass the issue (and the task id for a one-task worker) from the request, and write the real branch in the roster's branch field and in the review and merge steps. `README.md` MUST describe the new folder and branch name.
- **FR-025**: The tests MUST cover each FR-013 to FR-023 case: every name form, the fallbacks, a refused unsafe part, a taken name, old workers, the real branch in `result`, `close` and `list`, the marker on both machines, each worker check with marker, with a `worker-*` branch, and with neither, and lock 2 on the marker.

### Key Entities

- **Worker workspace**: one herdr workspace per worker, named `<orchestrator> / <id>: <task words>`, with the worker's worktree as its folder. It holds the `worker-<id>` tab and, once the advisor runs, the `Codex` tab with the Codex agent `st-codex-worker-<id>`.
- **Worker id**: the task id the orchestrator passes to `start`. Every command finds the worker by the tab label `worker-<id>`.
- **Worker name** (round 3): `<project>[-<env>]-<feature>`, the name of the worker's worktree folder and of its branch.
- **Worker marker** (round 3): the file `.stratum/worker` in a worker's worktree, holding the worker id. It tells every worker check that the session is a worker.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With three workers started from one orchestrator, all three get their own Codex tab, and 0 fall back to headless because the agent name is in use (worker ids of 16 characters or fewer, see the FR-005 exception).
- **SC-002**: Starting N workers adds N sidebar entries and 0 tabs to the orchestrator's workspace.
- **SC-003**: After `close` of every worker, 0 worker workspaces and 0 worker Codex tabs are left, and the orchestrator's workspace is still open.
- **SC-004**: The user can tell from the sidebar alone which worker and which orchestrator each worker workspace belongs to.
- **SC-005**: All tests pass, including the new cases.
- **SC-006** (round 3): The user can tell from a worker's folder and branch name alone which project and which issue it works on, for 100% of workers started with an issue.
- **SC-007** (round 3): In a worker worktree with the new branch name, 100% of the tries to write the autonomous-mode, approve or marker files are refused, as they are today on a `worker-*` branch.

## Assumptions

- herdr 0.9.4 gives a pane in a workspace made by `herdr workspace create` that workspace's own `HERDR_WORKSPACE_ID` (live probe 2026-11-09). The advisor inside a worker reads its own workspace from it.
- The user accepts that worker workspaces are not grouped under the orchestrator in the sidebar (D10).
- Issue #93 changes `answer`, the `wait`/`watch` screen hashing and the Codex answer reader in the same scripts. This feature does not touch them. Round 3 builds on top of #93 after it merges into main (D25), because both change `hooks/st-approve.py`.
- Round 3: lock 2 stays a text match, as its shortcut note says. The marker raises no guard level: a worker that can delete the marker could already switch its branch.
- The live multi-worker run with real Codex tabs can only be proved by hand. The automated tests use the herdr stub.
