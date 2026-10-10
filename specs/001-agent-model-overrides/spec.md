# Feature Specification: Agent model overrides

**Feature Branch**: `001-agent-model-overrides`

**Created**: 2026-10-10

**Status**: Draft

**Input**: User description: "GitHub issue #8 on HyuseCS/stratum: project setting for subagent models and effort (.stratum/models.json). Issue body is the source spec." Decisions D10 to D18 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Override an agent's model and effort in one project (Priority: P1)

A Stratum user wants one agent to run on a different model or effort level in one project only,
without editing the plugin. They write the agent name and the values into the project's model
file. The next time Stratum starts that agent, it runs with those values. Other projects keep the
plugin defaults.

**Why this priority**: This is the core of issue #8. Without it, the only way to change a model is
to edit the plugin, which changes every project.

**Independent Test**: In a project whose file says `st-close` uses haiku, start `st-close` and see
that it runs on haiku. In a second project with no file, `st-close` runs on sonnet.

**Acceptance Scenarios**:

1. **Given** a project file `{ "st-close": { "model": "haiku" } }`, **When** Stratum starts
   `st-close`, **Then** it runs on haiku.
2. **Given** a project file `{ "st-validate": { "effort": "high" } }`, **When** Stratum starts
   `st-validate`, **Then** it runs with effort high and its default model.
3. **Given** a project with no file, or a file without an entry for the agent, **When** Stratum
   starts the agent, **Then** it runs with its default model and effort, as it does now.
4. **Given** a running session, **When** the user edits the file, **Then** the next agent start
   uses the new values without a reload.

---

### User Story 2 - A bad file stops with a clear error (Priority: P1)

A user makes a typo in the model file (a wrong agent name, model or effort). Stratum does not start
the agent with a silent fallback. It stops and names the bad key and the allowed values.

**Why this priority**: A silent fallback hides mistakes and costs money on the wrong model. The
issue requires a clear error.

**Independent Test**: Put each kind of bad value in the file, start any Stratum agent, and see the
start blocked with a message that names the bad key and the allowed values.

**Acceptance Scenarios**:

1. **Given** a file with `"st-closee"`, **When** any Stratum agent starts, **Then** the start is
   blocked and the message names `st-closee` and the 11 allowed agent names.
2. **Given** a file with `"model": "gpt"`, **When** any Stratum agent starts, **Then** the start
   is blocked and the message lists the allowed models.
3. **Given** a file with `"effort": "huge"`, **When** any Stratum agent starts, **Then** the start
   is blocked and the message lists the allowed effort levels.
4. **Given** a file that is not valid JSON, **When** any Stratum agent starts, **Then** the start
   is blocked and the message says the file cannot be read.

---

### User Story 3 - New repos get the default model setup (Priority: P2)

When a user sets up Stratum in a new repo, `st-init` asks one question: "Change the model or effort
for any agent?" The default answer is no. On no, it writes the plugin's model template into the
repo: `st-close`, `st-git` and `st-test` on haiku with effort xhigh, and `st-build`, `st-debug`, `st-quick`, `st-plan`, `st-fast` on opus with effort high. It shows the table of defaults and says how to
change them later. The file stays on this machine and git does not track it.

**Why this priority**: The user wants every new repo to start with the Haiku setup. The override
itself (Story 1) works without it.

**Independent Test**: Run `st-init` in a fresh repo, answer no, and see the file written with the
8 template entries and listed in `.gitignore`.

**Acceptance Scenarios**:

1. **Given** a repo without a model file, **When** the user runs `st-init` and answers no,
   **Then** the file holds `st-close`, `st-git` and `st-test` on haiku with effort xhigh, and `st-build`, `st-debug`, `st-quick`, `st-plan`, `st-fast` on opus with effort high.
2. **Given** a repo without a model file, **When** the user answers yes and names changes,
   **Then** the file holds the template entries plus or minus those changes.
3. **Given** a repo that already has a model file, **When** the user runs `st-init`, **Then** the
   file is not changed and the question is not asked.
4. **Given** `st-init` has run, **When** the user runs `git status`, **Then** the model file is
   not listed.

---

### User Story 4 - Change a model by asking in plain words (Priority: P2)

A user says to Claude Code, for example, "make st-close use opus" or "put st-test on high effort".
Claude Code changes the project's model file to match and confirms the new values. "Use the
default" removes the entry.

**Why this priority**: The user asked for this at the spec gate. Editing JSON by hand works, so it
is not P1.

**Independent Test**: Ask "make st-close use opus" and see the file change to
`"st-close": { "model": "opus" }`, with the other entries kept.

**Acceptance Scenarios**:

1. **Given** a model file, **When** the user asks to set an agent's model or effort, **Then** that
   entry changes, every other entry stays, and the reply shows the agent's new values.
2. **Given** a model file, **When** the user asks to put an agent back on its default, **Then** that
   agent's entry (or that key) is removed.
3. **Given** a request with an unknown agent, model or effort, **When** the user asks, **Then**
   nothing changes and the reply lists the allowed values.

---

### User Story 5 - See the overrides (Priority: P3)

`st-status` shows which agents the project overrides, with their model and effort, and says where
the values come from.

**Why this priority**: Required by the issue. It helps the user check the setup but is not needed
for it to work.

**Independent Test**: With the template entries in the file, run `st-status` and see them
listed.

**Acceptance Scenarios**:

1. **Given** a model file with entries, **When** the user runs `st-status`, **Then** each
   overridden agent shows its model and effort.
2. **Given** no model file, **When** the user runs `st-status`, **Then** it says every agent uses
   the plugin defaults.

---

### Edge Cases

- An entry with an empty object `{}`: valid. The agent uses its defaults.
- An entry that only sets effort: the agent keeps its default model.
- The start call already names a model or effort: the file's value replaces it.
- An agent that is not a Stratum agent (for example `Explore`): the file never applies to it, and
  a bad model file does not block it.
- A bad entry for one agent blocks the start of every Stratum agent, so the mistake shows at once.
- A clone of the repo has no model file: agents use the plugin defaults until `st-init` runs.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each project MUST be able to hold a model file at `.stratum/models.json` that maps a
  Stratum agent name to an optional `model` and an optional `effort`.
- **FR-002**: Each time a Stratum agent starts, the system MUST read the model file at that moment
  and start the agent with the file's model and effort, where set.
- **FR-003**: A missing file, a missing agent entry or a missing key MUST keep that agent's default
  model and effort.
- **FR-004**: The system MUST block the start of any Stratum agent when the model file is not
  valid JSON, is not an object, or holds an unknown agent name, an unknown key, an unknown model,
  or an unknown effort. The message MUST name the bad items, up to 10, and the allowed values. Any
  further bad items are counted as "... and K more.".
- **FR-005**: Allowed agent names MUST be the 11 Stratum agents: st-build, st-check, st-close,
  st-debug, st-fast, st-git, st-plan, st-quick, st-review, st-test, st-validate. Allowed models:
  sonnet, opus, haiku, fable. Allowed efforts: low, medium, high, xhigh, max.
- **FR-006**: The override MUST apply only to Stratum agents. Other agents MUST start unchanged,
  whatever the model file holds.
- **FR-007**: The plugin MUST ship a model template with `st-close`, `st-git` and `st-test` on
  haiku with effort xhigh (D15), and `st-build`, `st-debug`, `st-quick`,
  `st-plan`, `st-fast` on opus with effort high (D16). The plugin's own agent defaults MUST stay as they are.
- **FR-008**: `st-init` MUST ask one question about model changes when the repo has no model file,
  write the template on no (with the user's changes on yes), show the default table and how to
  change it, and add the file to `.gitignore`.
- **FR-009**: A Stratum command MUST let the user set or reset one agent's model and effort in the
  model file from plain words, keep all other entries, reject unknown values without changing the
  file, and reply with the new values.
- **FR-010**: `st-status` MUST list each overridden agent with its model and effort, or say that
  all agents use the defaults.
- **FR-011**: The README MUST document the model file, the allowed values, the template and how to
  change an entry.
- **FR-012**: This repo MUST get a model file with the template's 8 entries (D15, D16).

### Key Entities

- **Model file** (`.stratum/models.json`): per project, per machine, not tracked by git. Keys are
  agent names. Each value may set `model` and `effort`.
- **Model template**: shipped in the plugin. The starting content of a new repo's model file.
- **Agent default**: the model the plugin's agent definition names. No Stratum agent sets an
  effort, so the default effort is the one Claude Code uses for that model.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a project with `st-close` on haiku, 100% of `st-close` starts run on haiku, and a
  second project without the file runs `st-close` on sonnet.
- **SC-002**: Each of the 4 bad-file cases in User Story 2 blocks the start with a message that
  names the bad item. None falls back silently.
- **SC-003**: A change to the model file takes effect on the very next agent start, with no reload.
- **SC-004**: A fresh `st-init` with the default answer gives a model file with exactly 8 entries,
  and `git status` does not list it.
- **SC-005**: One plain-words request changes exactly one entry and leaves every other entry as it
  was.

## Assumptions

- Claude Code lets a hook that runs before an agent starts change the start's model and effort, or
  block the start with a message. Confirmed on Claude Code 2.1.294 (research.md R1, V1 to V3).
- The `haiku` model name starts the current Haiku model (Haiku 5.5).
- The user accepts that `st-test` on Haiku may write weaker tests (D12).
- Existing projects that already ran `st-init` get no model file until the user runs `st-init`
  again or uses the change command. Until then they use the defaults.
