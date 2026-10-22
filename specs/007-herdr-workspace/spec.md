# Feature Specification: Open a herdr Workspace From a Layout Template

**Feature Branch**: `003-session-mods`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "GitHub issue #32 on HyuseCS/stratum: a skill that opens a project folder as a herdr workspace with the user's template layout, on this machine or on a saved remote machine. One request, no keybinding, no fzf popup." The issue body is the source. Decisions D1 to D9 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a full workspace on this machine (Priority: P1)

The user asks for a workspace for a project folder, for example "open a workspace for issue 32 in
`~/Desktop/stratum-003` with the full layout". One request opens a new herdr workspace labelled
after the issue, with the `full` layout: tab `Main` with the agent on the left and `lazygit` on
the right, tab `Dev Servers` with two shells side by side, tab `VM` with two shells side by side.
All six panes start in the project folder. The user gets a report that names the workspace, each
tab, and what runs in each pane, and the new workspace is in front.

**Why this priority**: Today the layout exists only as a keybinding that asks with fzf inside the
TUI. An agent cannot run it, so the issue's session repeated its steps by hand. This story is the
whole value on the common machine.

**Independent Test**: Ask for one workspace on this machine. Count the tabs and panes, check each
pane's folder, see `claude` and `lazygit` in the `Main` panes, and read the report.

**Acceptance Scenarios**:

1. **Given** a project folder on this machine, **When** the user asks for a `full` workspace,
   **Then** a new workspace exists with tabs `Main`, `Dev Servers` and `VM`, two panes each, every
   pane's working folder is the project folder, `claude` runs in the left `Main` pane and
   `lazygit` in the right one.
2. **Given** the workspace is made, **When** the report arrives, **Then** it names the workspace
   id and label, the machine, the folder and its git state, each tab with its id and label, and
   each pane with its id, folder and what runs in it.
3. **Given** the request names an issue or task, **When** the workspace is made, **Then** its label
   is that issue or task (for example `32-herdr-workspace`); **Given** it names none, **Then** the
   label is one first name, like a person (for example `ada`).
4. **Given** the project folder does not exist, **When** the user asks, **Then** nothing is made and
   one line says the folder is missing.
5. **Given** the project folder has uncommitted changes or is behind its remote, **When** the user
   asks, **Then** the workspace is made anyway and the report shows that git state.

---

### User Story 2 - Open the same workspace on a saved remote machine (Priority: P2)

The user adds the machine: "open a parasat-staging workspace on the laptop". The folder is checked
on that machine, the workspace and all tabs and panes are made there, and the report is the same as
on this machine.

**Why this priority**: This is the case in the issue. Without it the user still repeats twelve
calls by hand with `--machine` on each.

**Independent Test**: Ask for one workspace on the saved machine `laptop`. Read back its tabs and
panes on that machine and see that every pane's folder is the remote path.

**Acceptance Scenarios**:

1. **Given** a saved, reachable machine and a folder that exists there, **When** the user asks for
   a `full` workspace on it, **Then** the workspace with the same six panes exists on that machine,
   every pane in that folder, with `claude` and `lazygit` running in `Main`.
2. **Given** the machine is saved but does not answer, **When** the user asks, **Then** nothing is
   made and one line says the machine does not answer, with the error herdr gave.
3. **Given** the folder does not exist on the remote machine, **When** the user asks, **Then**
   nothing is made and one line says so, even if the folder exists on this machine.
4. **Given** the request names a machine that is not saved, **When** the user asks, **Then** nothing
   is made and one line says the machine is unknown.

---

### User Story 3 - Open a basic workspace (Priority: P3)

The user asks for the `basic` layout: one tab `Main` with two shells side by side in the project
folder, nothing started. Local or remote.

**Why this priority**: It is the other branch of the user's keybinding script. It costs little
once story 1 exists.

**Independent Test**: Ask for a `basic` workspace. One tab, two panes, both in the folder, no
program running, and the report says so.

**Acceptance Scenarios**:

1. **Given** a project folder, **When** the user asks for a `basic` workspace, **Then** a new
   workspace has one tab `Main` with two shell panes in the folder and nothing started.

---

### Edge Cases

- The request asks for an agent other than `claude` or `claude2`: nothing is made, one line names
  the two allowed values.
- `claude` or `lazygit` does not show in its pane within a short wait: the workspace stays, and the
  report says `not seen` for that pane.
- The request is made from outside herdr on this machine: one line says the skill must run inside
  a herdr pane for the local case. The remote case does not need it.
- A step after the workspace is made fails (a tab or split is refused): the run stops, the report
  shows what was made so far with its ids, and nothing is closed.
- The user's own keybinding script changes its layout: the skill's layout does not follow. The
  skill says in one line where its layout lives.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: One request MUST open one new herdr workspace from one project folder with one of
  the templates. It MUST never add a layout to an existing workspace (D4).
- **FR-002**: Templates are `full` (tab `Main`: agent left, `lazygit` right; tab `Dev Servers`:
  two shells; tab `VM`: two shells) and `basic` (tab `Main`: two shells). The default is `full`.
- **FR-003**: Every tab and every pane MUST start in the project folder. The folder MUST be given
  on every tab and every split, never left to herdr's default.
- **FR-004**: The target is this machine by default or one saved herdr machine by label or id. For
  a remote target every herdr call MUST name that machine.
- **FR-005**: Every workspace, tab and pane id MUST come from herdr's own response to the call
  that made it. Local ids, the current pane and herdr's environment ids MUST NOT be used for a
  remote target.
- **FR-006**: Before anything is made: a remote machine MUST answer, and the folder MUST exist on
  the target machine. If either fails, nothing is made and one line says why (D3).
- **FR-007**: The git state of the folder on the target (clean or changed, ahead or behind) MUST be
  read and shown in the report. It MUST NOT stop the run (D3).
- **FR-008**: The agent in `Main` is `claude` by default; the request may ask for `claude2`. Any
  other value stops the run with one line (D6).
- **FR-009**: The workspace label MUST be given on every run. It is the issue or task the workspace
  is for, in the form `<number>-<short-name>` when an issue number is known; when the request
  names no issue or task, it is one first name, like a person (D2).
- **FR-010**: The report MUST show: workspace id and label, machine, folder and git state, each tab
  with id and label, each pane with id, folder, and what runs in it (`claude`, `claude2`,
  `lazygit`, `shell`), with `running` or `not seen` for a started program (D7).
- **FR-011**: The run MUST NOT start the herdr TUI, reconnect, add or remove a machine, stop a
  server, or close any workspace, tab or pane, including the ones it made.
- **FR-012**: The new workspace MUST be in front when the run ends (D9).
- **FR-013**: The layout MUST live in the plugin, not in the user's herdr config. The skill text
  MUST say in one line that the user's own `templates.sh` can drift from it (D1).
- **FR-014**: The steps MUST be the same on every run and checkable without herdr: a test with a
  stand-in `herdr` that records each call MUST be able to show that every tab and split names
  the folder, every call names the machine when one is given, and every id used came from a
  response (D2).

### Key Entities

- **Template**: a named layout: tabs in order, panes per tab, and the program each pane starts.
  Two exist: `full` and `basic`.
- **Target machine**: this machine or a saved herdr machine profile (label, id, ssh target).
- **Workspace report**: the proof of what was made: ids, labels, folders, programs, git state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One request on this machine gives a workspace with the six `full` panes, all in the
  project folder, with `claude` and `lazygit` running, and no second request or keypress.
- **SC-002**: The same request with a reachable saved machine gives the same six panes on that
  machine, checked by reading them back there.
- **SC-003**: The report names the workspace id, every tab, and the program in every pane, so the
  user can check it without opening herdr.
- **SC-004**: A missing folder or a machine that does not answer makes nothing and gives one line
  that names the cause.
- **SC-005**: A test with a stand-in `herdr` goes red when one tab or split loses its folder, or
  one call loses its machine, and green when the steps are right.

## Assumptions

- herdr 0.9.4 with its CLI on `PATH`, and `jq` installed, on this machine.
- For a remote target, the remote herdr server is already running and API-compatible, and ssh to
  its saved target works with no password prompt. The skill never starts or repairs either.
- On this machine the request comes from a session inside a herdr pane. herdr's own skill forbids
  controlling the session from outside.
- The user's `~/.config/herdr/templates.sh` stays as it is. Its `full` and `basic` layouts as of
  2026-10-23 are the source for the two templates.
- A started `claude` loads the user's normal plugins and settings; the skill does not change them.
- Opening a workspace changes only herdr state and starts `claude` and `lazygit`. No repo file
  changes.
