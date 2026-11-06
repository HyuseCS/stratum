# Feature Specification: Harness Diagram

**Feature Branch**: `078-harness-diagram`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "#78 Add a diagram of the Stratum workflows and harness. Purpose: see the harness so we can make the workflows work better and the skills in the workflows more cohesive and autonomous. The diagram must be editable by the developer, easy to consume, and easy for an LLM to read." Decisions D1 to D18 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See how each lane works (Priority: P1)

The developer opens the harness page on GitHub or in the repo. Each lane (Full, Fast, Quick,
Design) has its views. The Full lane has an overview and one view per phase, and the Design lane
has an overview and one view per mode (D13). Each lane view shows, in order, which skill or agent
passes what to which next one, and where each gate stops for the user. Other views show the agents, the harness
(hooks and their events, the statusline, the advisors and the risk level) and the data flow
(which step reads and writes which file).

**Why this priority**: Today the flow is only in text across `README.md`, 40 skills and 15
agents (issue #78). A picture of each lane is the core value.

**Independent Test**: Open the page on GitHub. Each of the 15 views draws. Follow the Full-lane
overview and name its phases and its four gates in order.

**Acceptance Scenarios**:

1. **Given** the page on GitHub, **When** the developer opens it, **Then** every view draws with
   no error.
2. **Given** the Full-lane overview, **When** the developer reads it, **Then** it shows Define,
   Plan, Inspect, Build and Close in order and the four gates (you agree the spec, you answer each
   open decision, OK to build, push). Each phase view shows the data passed at each step of that
   phase.
3. **Given** a skill that more than one lane uses, **When** the developer reads each lane view,
   **Then** each view shows the links that skill has in that lane only.
4. **Given** the main `README.md`, **When** the developer reads it, **Then** it links to the page.
5. **Given** the Full-lane or Design-lane overview in the VS Code LikeC4 preview, **When** the
   developer clicks a phase or mode, **Then** its view opens. On GitHub the same views show one
   after the other, with no clicks.

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

---

### User Story 5 - Compare with a system atlas (Priority: P3)

The developer opens a system atlas of the same harness: an interactive isometric page that shows
the harness a few structures at a time, chapter by chapter, with a generated text twin
(`SYSTEM.md`). The developer compares it with the LikeC4 views to see which form helps more to
improve the workflows (D14). The atlas is a trial: one data file, no drift test (D15).

**Why this priority**: The LikeC4 views (US1 to US4) are the deliverable. The atlas is a second
form to compare, so it comes last.

**Independent Test**: Open the published atlas. Step through the 10 chapters. Pick each flow in
the last chapter. Open the questions tab and find the 13 gaps of `gaps.md`.

**Acceptance Scenarios**:

1. **Given** the published atlas, **When** the developer opens its URL, **Then** `atlas.html`
   opens at one stable private URL. The same file also opens from a static server.
2. **Given** the atlas, **When** the developer steps through it, **Then** it has 10 chapters.
   Each of chapters 1 to 9 adds at most 3 structures and runs one small flow that touches only
   structures shown so far. The last chapter shows all structures with a flow picker.
3. **Given** any structure, **When** the developer selects it, **Then** it has a one-line summary,
   a "what it does", a "how it is built" that names the LikeC4 element ids it stands for, a short
   label and a role shape.
4. **Given** the questions tab, **When** the developer reads it, **Then** the 13 gaps of `gaps.md`
   are open questions `Q-<code><n>`, each on the structure it touches, and none is drawn on the map
   (D16).
5. **Given** `docs/harness/atlas/data.mjs` and the system-atlas skill installed on the machine,
   **When** the developer runs the build line of FR-015, **Then** it runs with no error and writes
   `atlas.html` and `SYSTEM.md` into `docs/harness/atlas/`. `SYSTEM.md` has the decisions table, the question index and the "how this file is
   maintained" footer.

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
- **FR-005**: There MUST be ordered lane views that show who passes what to whom, and each gate
  (D13): the Full lane has an overview (the orchestrator, the 5 phases and the 4 gates) and one
  view per phase (Define, Plan, Inspect, Build, Close). The Design lane has an overview (the start
  steps and the 3 modes) and one view per mode (new look, autonomous, custom). The Fast and Quick
  lanes have one view each. In each overview, each phase or mode opens its view with `navigateTo`
  (a click in the LikeC4 preview; GitHub shows no clicks). Each step label starts with its step
  number `(n)`, and each view numbers its steps from `(1)` (D8). A gate is a step whose label has
  `gate:` after the step number and names what the user must say, for example
  `(4) gate: you agree the spec`. A skill that is in no lane shows only in the topic views.
- **FR-006**: There MUST be an agents view, a harness view (hooks by event, statusline, advisors
  and risk level) and a data-flow view. The user, Codex, `/advisor` and GitHub are elements too,
  because steps pass data to them.
- **FR-007**: The steps inside a skill MUST NOT be elements. They stay in the summary (D7).
- **FR-008**: Vendored skills MUST carry a `vendored` tag.
- **FR-009**: `docs/harness/README.md` MUST be made by the tool from the model, with one diagram
  per view that GitHub draws. It is not edited by hand.
- **FR-010**: The main `README.md` MUST link to the page and say how to edit, check and rebuild
  it, and how to add the MCP server once per machine.
- **FR-011**: The top LikeC4 package MUST be pinned to one version, so both machines make the same
  page. Its own dependencies are not pinned (D11). The rebuild check catches a page that changes.
- **FR-012**: The repo MUST NOT get any file that Claude Code loads as a plugin component for this
  feature (no root `.mcp.json`) (D6).
- **FR-013**: `tests/test_harness_model.sh` MUST check coverage (FR-002 items both ways), model
  validity and that the page is rebuilt. The last two print SKIP when `npx` is missing or Node is
  below 22.22.3 (D9).
- **FR-014**: The model MUST describe the harness as it is now. No skill, agent, hook or script
  changes in this feature.
- **FR-015**: The atlas MUST live in `docs/harness/atlas/` (D15) as exactly 3 files: `data.mjs`
  (the only edited source) and the generated `atlas.html` and `SYSTEM.md`. The skill's
  `build.mjs` and `template.html` are NOT committed: they have no license and the repo is public
  and ships as the plugin (D17). The build runs them from the installed skill in a temp folder,
  and MUST run with no error:
  `t=$(mktemp -d) && cp ~/.claude/skills/system-atlas/assets/build.mjs ~/.claude/skills/system-atlas/assets/template.html docs/harness/atlas/data.mjs "$t" && node "$t/build.mjs" && cp "$t/atlas.html" "$t/SYSTEM.md" docs/harness/atlas/ && rm -rf "$t"`.
  `META.outDir` is `'.'`, so the build writes into the temp folder. Nobody edits a generated file.
- **FR-016**: The atlas MUST have 10 chapters: 1 You and /st, 2 The four lanes, 3 The spec on
  disk, 4 The agents that do the work, 5 Gates: asking you first, 6 Second opinion: Codex and
  /advisor, 7 Guard rails: hooks, 8 Memory across sessions, 9 Shipping, 10 The whole system.
  Chapters 1 to 9 each add at most 3 structures and run one small flow among the structures shown
  so far. Chapter 10 adds none and has a flow picker. The chapters, structures, flows, decisions
  and questions are all in `data.mjs`.
- **FR-017**: Each atlas structure MUST have `one`, `what`, `how`, `short` (14 characters at most)
  and a role `kind`. Structures are at group level (about 20). Each `how` names the LikeC4 element
  ids the structure stands for, so the developer can compare the two forms.
- **FR-018**: The 13 gaps of `gaps.md` MUST be open questions `Q-<code><n>` on the structure each
  touches, in the questions tab and the index counts only, not drawn on the map. The LikeC4 model
  stays facts only (D5, D16).
- **FR-019**: `SYSTEM.md` MUST be generated with the decisions table (the decisions of
  `decisions.md`), the question index and the "how this file is maintained" footer.
- **FR-020**: The orchestrator MUST publish `atlas.html` as a private claude.ai artifact at one
  stable URL and republish it there after each data change. The URL stays out of the repo
  (`META.artifactUrl` is empty): it lives in the session handoff and project memory (D18). The
  page MUST also open from a static server (`python3 -m http.server`).
- **FR-021**: The atlas MUST NOT break the existing tests. The `nomcp` check allows exactly the 3
  atlas files. The atlas gets no drift test while it is a trial (D15).

### Key Entities

- **Element**: one skill, agent, hook script, script, statusline script, procedure, data file,
  actor, event or group. Has a kind, a name, a summary and tags, and a repo path (plugin files), a
  data path (run-time data files) or neither (actors, events, groups).
- **Link**: from one element to another. Has a kind and a data label. Lane membership is only in
  the lane views (D12).
- **View**: a lane view (ordered steps) or a topic view (agents, harness, data flow).
- **Page**: the generated `docs/harness/README.md`, one diagram per view.
- **Atlas**: `docs/harness/atlas/data.mjs` and what it builds. It has structures (group-level
  boxes), flows, chapters, decisions and questions.

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
- **SC-006**: All 15 views draw on GitHub with no error.
- **SC-007**: The developer compares the atlas and the LikeC4 views on the same question (for
  example "where does the Full lane ask me first?") and says which form helps more.

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
- The atlas has no ADRs and no `CONTEXT.md`: `decisions.md` is the decision record, and a
  glossary is not needed for a trial (YAGNI).
- The atlas page loads the IBM Plex Mono font from Google Fonts when it opens.
- Rebuilding the atlas needs the system-atlas skill installed at `~/.claude/skills/system-atlas`
  on that machine (the user's PC and laptop). Reading the atlas does not: the 3 committed files
  and the published URL are enough.
