# Feature Specification: Harness Diagram

**Feature Branch**: `078-harness-diagram`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "#78 Add a diagram of the Stratum workflows and harness. Purpose: see the harness so we can make the workflows work better and the skills in the workflows more cohesive and autonomous. The diagram must be editable by the developer, easy to consume, and easy for an LLM to read." Decisions D1 to D7 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See how each lane works (Priority: P1)

The developer opens the harness page on GitHub or in the repo. It has one view per lane (Full,
Fast, Quick, Design). Each lane view shows, in order, which skill or agent passes what to which
next one, and where each gate stops for the user. Other views show the agents, the harness
(hooks and their events, the statusline, the advisors and the risk level) and the data flow
(which step reads and writes which file).

**Why this priority**: Today the flow is only in text across `README.md`, 40 skills and 15
agents (issue #78). A picture of each lane is the core value.

**Independent Test**: Open the page on GitHub. Each of the 7 views draws. Follow the Full-lane
view and name its phases and its three gates in order.

**Acceptance Scenarios**:

1. **Given** the page on GitHub, **When** the developer opens it, **Then** every view draws with
   no error.
2. **Given** the Full-lane view, **When** the developer reads it, **Then** it shows Define, Plan,
   Inspect, Build and Close in order, the three gates, and the data passed at each step.
3. **Given** a skill that more than one lane uses, **When** the developer reads each lane view,
   **Then** each view shows the links that skill has in that lane only.
4. **Given** the main `README.md`, **When** the developer reads it, **Then** it links to the page.

---

### User Story 2 - An LLM reads the whole harness (Priority: P1)

The LLM reads the model source as plain text, or queries it through the LikeC4 MCP server. Every
skill, agent, hook, script and data file is in it, with a short plain summary. Every link names
the data it carries. From the model alone, the LLM can answer questions like "which steps write
`.stratum/state.json`" or "which skills start no agent and are in no lane".

**Why this priority**: The purpose of the feature is to improve the workflows and make the
skills more cohesive. The LLM does that analysis, so it must read the full harness with ease.

**Independent Test**: Ask the LLM, from the model only, which steps write `.stratum/state.json`.
Compare the answer with a search of the repo.

**Acceptance Scenarios**:

1. **Given** the model, **When** it is read, **Then** each skill, agent, hook, script and data
   file is one element with a summary of 1 or 2 short sentences.
2. **Given** any link in the model, **When** it is read, **Then** it has a kind (starts, reads,
   writes, runs or passes) and a label that names the data.
3. **Given** a vendored skill (the 11 skills whose folder `THIRD_PARTY_NOTICES.md` names: the six
   `st-ponytail*` skills, `st-grill`, `st-ui-ux`, `st-impeccable`, `st-graphify`, `st-hallmark`),
   **When** it is read, **Then** it carries a `vendored` tag.

---

### User Story 3 - The developer edits the diagram (Priority: P2)

The developer changes the model text, or drags boxes in the VS Code LikeC4 preview. The dragged
layout is saved in the source. One command makes the GitHub page again. The main `README.md`
says how to edit, check and rebuild the page, and gives the one-time command that adds the
LikeC4 MCP server on a machine.

**Why this priority**: The diagram must stay editable by hand. It is P2 because the views have
value before the developer edits them.

**Independent Test**: Drag one box in the VS Code preview, save, close and open it again. The box
stays where it was put. Run the rebuild command. The page changes only where the model changed.

**Acceptance Scenarios**:

1. **Given** the VS Code LikeC4 preview, **When** the developer drags a box and saves, **Then**
   the new position is kept in the source.
2. **Given** a change to the model text, **When** the developer runs the rebuild command, **Then**
   the page shows the change.
3. **Given** a new machine, **When** the developer runs the documented MCP command once, **Then**
   the LLM can query the model in every worktree of the repo.

---

### User Story 4 - The model does not drift (Priority: P2)

A test fails when the repo and the model disagree: a skill, agent, hook script or script is
missing from the model, the model names a file that does not exist, the model is not valid, or
the page is not rebuilt after a model change.

**Why this priority**: A full model goes stale fast. Without the test it gives wrong answers
with no alert.

**Independent Test**: Add an empty skill folder and run the test. It fails and names the skill.
Remove the folder. The test passes.

**Acceptance Scenarios**:

1. **Given** a new `skills/<name>/` with no element, **When** the test runs, **Then** it fails and
   names `<name>`.
2. **Given** an element whose file was removed, **When** the test runs, **Then** it fails and names
   the file.
3. **Given** a model change with no rebuild of the page, **When** the test runs, **Then** it fails.
4. **Given** a machine with no `npx`, or with Node below 22.22.3, **When** the test runs, **Then**
   the validity and rebuild checks print SKIP and the coverage check still runs.

### Edge Cases

- A data file that git ignores (`.stratum/handoff.md`, `.stratum/models.json`) is still an
  element, because the harness reads and writes it.
- A hook script runs on more than one event (`st-approve.py`, `st-phase.py`, `st-handoff-facts.sh`):
  one element, one link per event.
- When #51 changes the lanes, the coverage check catches added and removed items. Changed links
  inside a lane are not caught by the test. The lane views are then updated by hand.
- Gaps seen while building the model are not drawn in it. They go in a short side note
  (`gaps.md`) in this feature folder, not linked from any page (D5).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The model source MUST be plain text in `docs/harness/`, under version control.
- **FR-002**: The model MUST have one element per `skills/*` folder, per `agents/*.md`, per file
  under `hooks/` (with `hooks/ponytail/`), per `scripts/*.sh`, per file under `statusline/`, per
  `procedures/*.md`, and per data file the harness reads or writes (`.stratum/*` and the files in
  `specs/<feature>/`: spec, plan, research, data model, contracts, quickstart, tasks, checklists,
  changes, decisions, advisor.md, gaps.md). Another file that a link needs (for example the
  project's `DESIGN.md`, `graphify-out/GRAPH_REPORT.md`, `templates/*`) also gets one element (D10).
  The coverage check does not require these, and the test checks that each one that is a plugin
  file exists.
- **FR-003**: Each element MUST have a plain summary of 1 or 2 short sentences.
- **FR-004**: Each link MUST have a kind (starts, reads, writes, runs or passes) and a label that
  names the data it carries.
- **FR-005**: There MUST be one ordered view per lane (Full, Fast, Quick, Design) that shows who
  passes what to whom, and each gate. Each step label starts with its step number `(n)` (D8). A
  gate is a step whose label has `gate:` after the step number and names what the user must say,
  for example `(4) gate: you agree the spec`. A skill that is in no lane shows only in the topic
  views.
- **FR-006**: There MUST be an agents view, a harness view (hooks by event, statusline, advisors
  and risk level) and a data-flow view. The user, Codex, `/advisor` and GitHub are elements too,
  because steps pass data to them.
- **FR-007**: The steps inside a skill MUST NOT be elements. They stay in the summary (D7).
- **FR-008**: Vendored skills MUST carry a `vendored` tag.
- **FR-009**: `docs/harness/README.md` MUST be made by the tool from the model, with one diagram
  per view that GitHub draws. It is not edited by hand.
- **FR-010**: The main `README.md` MUST link to the page and say how to edit, check and rebuild
  it, and how to add the MCP server once per machine.
- **FR-011**: The tool version MUST be pinned, so both machines make the same page.
- **FR-012**: The repo MUST NOT get any file that Claude Code loads as a plugin component for this
  feature (no root `.mcp.json`) (D6).
- **FR-013**: `tests/test_harness_model.sh` MUST check coverage (FR-002 items both ways), model
  validity and that the page is rebuilt. The last two print SKIP when `npx` is missing or Node is
  below 22.22.3 (D9).
- **FR-014**: The model MUST describe the harness as it is now. No skill, agent, hook or script
  changes in this feature.

### Key Entities

- **Element**: one skill, agent, hook script, script, statusline script or data file. Has a kind,
  a name, a repo path, a summary and tags.
- **Link**: from one element to another. Has a kind, a data label and the lanes it belongs to.
- **View**: a lane view (ordered steps) or a topic view (agents, harness, data flow).
- **Page**: the generated `docs/harness/README.md`, one diagram per view.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the skills, agents, hook scripts and scripts in the repo are in the model,
  and the model names 0 missing files.
- **SC-002**: A reader names every phase and gate of the Full lane, in order, from its view alone
  in under 2 minutes.
- **SC-003**: 0 links have no data label.
- **SC-004**: From the model alone, the LLM lists the steps that write `.stratum/state.json`, and
  the list matches a search of the repo.
- **SC-005**: A skill added with no model change makes the test fail on its first run.
- **SC-006**: All 7 views draw on GitHub with no error.

## Assumptions

- The format is LikeC4, pinned at 1.60.0 and run with `npx` (D1). LikeC4 1.60.0 needs Node
  22.22.3 or later (D9). Node 24 is on the PC. The laptop must have Node 22.22.3 or later to
  validate and rebuild the page. With an older Node the test prints SKIP for those checks.
- GitHub draws the Mermaid blocks of the page with automatic layout. The dragged layout shows only
  in the LikeC4 preview (D2).
- Dragging needs the LikeC4 VS Code extension. Drag-and-save was not tested in the spike, so it is
  a check by hand (User Story 3).
- The whole repo ships as the plugin (marketplace `source` is `./`). `docs/harness/` ships too,
  which is harmless because Claude Code loads nothing from `docs/`.
- The project has no constitution.
- #51 will change the lanes later. This feature draws the lanes as they are now.
