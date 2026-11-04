# Feature Specification: st-update

**Feature Branch**: `012-st-update`

**Created**: 2026-11-04

**Status**: Draft

**Input**: Issue #73: "Add /st-update: audit the harness files in a project, then update, remove or add them." Grilling decisions D1 to D9 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See what is out of date (Priority: P1)

A user runs `/stratum:st-update` (optionally with a project folder) and sees one table. It shows each Stratum harness item in the project, its main checkout and its linked worktrees that is not current, marked outdated, discontinued or new. Nothing changes before the user says OK.

**Why this priority**: The audit is the base of every other story. It also shows the user how far each folder has drifted.

**Independent Test**: Run st-update on a fixture project that has one item in each state, answer no at the gate, and check that the table marks each item right and that no file changed.

**Acceptance Scenarios**:

1. **Given** a project whose install record is 0.1.22 and whose `statusLine` points at `cache/stratum/stratum/0.1.22/`, **When** the user runs st-update, **Then** the table marks the install and `statusLine` outdated.
2. **Given** a project with `.stratum/commit-mode` and an `st-check` key in `.stratum/models.json`, **When** the user runs st-update, **Then** the table marks both discontinued.
3. **Given** a project whose `.gitignore` lacks `.stratum/models.json`, **When** the user runs st-update, **Then** the table marks that line new.
4. **Given** a project where every item is current, **When** the user runs st-update, **Then** it says all items are current and stops with no gate.
5. **Given** the user answers no at the gate, **Then** no file, setting or install record changed.

---

### User Story 2 - Bring the project up to date (Priority: P1)

After the user's OK, st-update updates the plugin install in each folder that has a record, points `statusLine` at the new install, adds new items, removes discontinued traces, commits the committed files once per branch, and reports what changed and that running sessions need a restart.

**Why this priority**: This is the fix the issue asks for. Without it the audit is only a list of chores.

**Independent Test**: Run st-update on the fixture project with a main checkout and one linked worktree, answer yes, then run it again and check that the second audit shows every item current.

**Acceptance Scenarios**:

1. **Given** the user says OK, **When** st-update runs, **Then** each folder with an install record gets `claude plugin update` with the record's own scope, and its `statusLine` points at the new install path.
2. **Given** a linked worktree whose `.gitignore` lacks a Stratum line, **When** st-update runs, **Then** it adds the line and commits only that file on that worktree's branch.
3. **Given** an install record whose folder no longer exists, **When** st-update runs, **Then** it lists the record and does not touch it.
4. **Given** `claude plugin update` fails in one folder, **When** st-update runs, **Then** it shows the error and the exact command for the user, and goes on with the other folders.
5. **Given** a settings edit is blocked by a hook or the classifier, **When** st-update runs, **Then** it names the edit it could not make and gives the exact command for the user.
6. **Given** the project lacks `.stratum/advisor.json`, **When** st-update runs, **Then** it asks st-init's advisor question, and the "skip" answer leaves the file missing.

---

### User Story 3 - Keep the user's own changes (Priority: P2)

st-update changes only Stratum's own lines and keys. It never changes the user's data files. A value it would change that Stratum did not write gets a diff and a question. A committed file with uncommitted changes in a worktree is skipped and reported.

**Why this priority**: The update touches many folders and some untracked settings that git cannot restore. One wrong overwrite loses user work.

**Independent Test**: Give the fixture a custom `statusLine` command, an edited `.stratum/constitution.md`, and an uncommitted change to `CLAUDE.md` in the worktree. Run st-update and check that the first gets a diff and a question, the second is not touched, and the third is skipped with a reason.

**Acceptance Scenarios**:

1. **Given** `statusLine` runs a command that is not a Stratum statusline, **When** st-update runs, **Then** it shows the diff and asks before it changes it.
2. **Given** `CLAUDE.md` in a worktree has uncommitted changes, **When** st-update runs, **Then** it skips that file in that worktree and the report gives the reason.
3. **Given** the user says "skip <worktree>" at the gate, **Then** that worktree is left out completely.

---

### User Story 4 - Keep st-init and the item list the same (Priority: P3)

A maintainer who changes what st-init writes gets a red test until the st-update item list matches.

**Why this priority**: Without it the project drifts again, which is the bug in this issue. It helps maintainers, not users, so it comes last.

**Independent Test**: Add a `.gitignore` line to st-init only and run the test. It goes red. Remove the line and it goes green.

**Acceptance Scenarios**:

1. **Given** st-init names a `.gitignore` line, a pointer line, a `.stratum/` file or a settings key that the item list does not have, **When** the test runs, **Then** it fails and names the item.

---

### Edge Cases

- A folder has no install record: st-update still checks its files and settings, and the table says it has no install.
- The target is not a Stratum project (no `.stratum/`): st-update tells the user to run `/stratum:st-init` and stops.
- `statusLine` already points at the source folder, as on the user's PC: it is outdated and gets the new install path (D4).
- A subfolder of a worktree has its own install record (`v2-veent-parasat/apps/parasat`): it is updated like any other folder.
- `.stratum/models.json` has dead agent keys and live ones: only the dead keys are removed.
- A worktree is on a detached HEAD: its committed files are skipped and reported. There is no branch to commit on.
- A project hook denies a commit: st-update quotes the hook's deny reason and gives the exact `git -C <checkout> add -- <paths> && git -C <checkout> commit -m "<message>" -- <paths>` command, without working around it (D11).
- The marketplace is a local directory that is the top level of a git checkout not on `main`: the plugin update would install that branch, so st-update warns at the gate and names the branch.
- The plugin update fails in a folder: that folder's `statusLine` is left as it was, so it never points at an install that does not exist.
- st-update stops halfway: a second run audits again and does only what is still left.
- `.claude/settings.local.json` is missing: `statusLine` is new and the file is created with only that key. The file is not valid JSON: st-update does not touch it and reports it.
- A `user` scope install record is not per folder: st-update lists it and does not update it.
- `claude` is not on the PATH: st-update reports it, gives the command, and still does the file items.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: st-update MUST take an optional folder argument. The default is the current project. It MUST stop with a pointer to `/stratum:st-init` when the folder has no `.stratum/`.
- **FR-002**: st-update MUST cover the folder's main checkout, each linked worktree that exists, and each subfolder of these that has a Stratum install record.
- **FR-003**: st-update MUST check one list of harness items. Each item has a rule: a `.gitignore` line, a pointer line in `AGENTS.md` or `CLAUDE.md`, the `statusLine` entry, the `enabledPlugins` entries set to false, the FigCraft allow entries, the install version, and the `.stratum/` files that st-init writes.
- **FR-004**: st-update MUST mark each item current, outdated, discontinued or new. It also marks `ask` (a `statusLine` a Stratum did not write), `invalid` (a file it cannot read or must not touch), `gone` (a record whose folder is missing), `listed` (a `user` or `managed` record, or a folder with no install), `warn` (the marketplace branch) and `skip` (a committed file with uncommitted changes, or a detached HEAD). data-model.md lists the states.
- **FR-005**: The install is current when its record's version equals the marketplace version, and outdated otherwise.
- **FR-006**: `statusLine` is current when it runs `st-statusline.sh` from the current install path. Any other Stratum statusline path is outdated (an old cache version, a path that does not exist, the source folder). A missing entry is new. A command that is not a Stratum statusline MUST get a diff and a question.
- **FR-007**: A Stratum name in the project that the current version does not have MUST be marked discontinued: the agent keys in `.stratum/models.json`, and the `stratum` skills and tools in `permissions.allow`.
- **FR-008**: A file on the discontinued file list that the project still has MUST be marked discontinued. The list starts with `.stratum/commit-mode`.
- **FR-009**: st-update MUST show one table: only the items that are not current, grouped by folder, plus one line per folder that counts its current items. Then one gate for the user's OK. The user can say "skip <worktree>" at the gate.
- **FR-010**: Before the OK, st-update MUST change no file, setting, install record or commit.
- **FR-011**: After the OK, st-update MUST run `claude plugin update --json -s <scope> stratum@stratum` in each folder with a record, with the record's scope. A record whose folder is gone MUST be listed and not touched. A failed run MUST show its error and the exact command, and the other folders MUST still run.
- **FR-012**: After the plugin update, st-update MUST point `statusLine` in `.claude/settings.local.json` at the new install path from the updated record, and keep every other key.
- **FR-013**: st-update MUST change only Stratum's own lines and keys. It MUST NOT rewrite a whole file's content (a JSON file is written whole with every other key and value kept, and its spacing can change, research R12), and MUST NOT change user data files (`constitution.md`, `state.json` once it exists, `lessons.md`, `handoff.md`, or the values in `git-guard.json`, `models.json`, `powerline.json`, `advisor.json`).
- **FR-014**: New items that need no question MUST be added after the gate. For a missing `.stratum/` file that st-init asks about, st-update MUST ask that st-init step's question, one at a time, with a "skip" answer that leaves the file missing.
- **FR-015**: Discontinued traces MUST be removed only after the gate. In `.stratum/models.json`, only the dead keys are removed.
- **FR-016**: st-update MUST update the committed harness files (`.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, and `.stratum/state.json` and `.stratum/advisor.json` when git does not ignore them) in the main checkout and in each linked worktree, with one commit per branch through the commit guard, staging exact paths only.
- **FR-017**: A committed file with uncommitted changes in a folder MUST be skipped in that folder and reported with the reason.
- **FR-018**: An edit blocked by a hook or the classifier MUST be reported with the exact command for the user to run.
- **FR-019**: The report MUST list what changed per folder, what was skipped and why, and say that running sessions need a restart to load the new version.
- **FR-020**: A test MUST fail when st-init names a `.gitignore` line, pointer line, `.stratum/` file or settings key that the item list does not have, and a negative control MUST prove it.
- **FR-021**: The README MUST give the first-time command for a project whose install has no st-update yet: `claude plugin update stratum@stratum -s local`.

### Key Entities

- **Harness item**: one thing Stratum puts in a project. It has a kind (line, key, file, install), where it lives (file and folder), and a rule that gives its state.
- **Install record**: one entry in the config folder's `plugins/installed_plugins.json` for one folder, with scope, version and install path.
- **Discontinued file list**: the files that a removed Stratum feature used to write into projects.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After one st-update run with OK, a second audit of the same project shows 0 outdated, 0 discontinued and 0 new items, except for skipped items and items the user answered "skip".
- **SC-002**: In v2-veent with every linked worktree (7 today), the user gives one OK for all folders, plus only the questions from FR-006 and FR-014.
- **SC-003**: In the fixture tests, 0 user data files and 0 non-Stratum lines change.
- **SC-004**: After a restart, an autonomous session in a formerly 0.1.22 folder shows the `autonomous` tag.

## Assumptions

- st-update works on the machine it runs on. For the laptop, the user runs it there. It finds the config folder from `CLAUDE_CONFIG_DIR`, else `~/.claude`.
- The marketplace version is the `version` in the marketplace's `plugin.json`. That is what `claude plugin update` installs.
- The `bunx @owloops/claude-powerline` `statusLine` in a committed `.claude/settings.json` is the user's, and st-update does not touch it.
- Tool checks (graphify, FigCraft install) stay in `/stratum:st-status` and `/stratum:st-init`. st-update does not install tools.
- The release that ships st-update is version 0.7.0, because it adds a new command.
