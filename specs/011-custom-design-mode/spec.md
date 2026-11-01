# Feature Specification: Custom Design Mode

**Feature Branch**: `011-custom-design-mode`

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "GitHub issue #57 on HyuseCS/stratum: add a custom design mode to the Design lane. After the UI/UX grill, the agent builds the design in a design tool first, not in code. The user checks it there and changes what they want by hand. When the user says the design is good, the harness reads it from the tool and builds the code from it." Decisions D9 to D21 are in `decisions.md` (the Q, O and D codes start at Q6, O4 and D9, after the codes in #57 and the session handoff). The design tool is FigCraft (https://github.com/storytold/figcraft, D10).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A screen designed by hand in FigCraft, then built (Priority: P1)

The user wants control over a screen's design before any code exists. The task comes from Plan as
`[screen: custom]`, or the user asks for custom design. The orchestrator grills the user on the
UI/UX, as the new-look mode does. The lane starts FigCraft and the agent draws the first design
live in the open window. By default the design keeps the project's existing look: its colors,
fonts and spacing come from the design file, or from the code's tokens when there is no design
file. For a new look or an overhaul, the user first picks a theme, and its tokens go into the
design (D16). The lane stops. The user changes the design in FigCraft: moves, resizes, recolors,
and can ask the agent to change a selected layer. When the user says the design is good, the lane
saves it in the project, writes the design file from it, builds the screen in code from the saved
design, checks it, and shows the gate. On yes, it commits (D9, D11, D12, D21).

**Why this priority**: This is the core of #57: the user shapes the design by hand, and the code
follows the user's design, not a new guess.

**Independent Test**: In a project with a design file, ask for a new screen with custom design.
Answer the grill, see the first design appear in FigCraft, move one block, resize one block and
recolor one block by hand, and say "looks good". Get a built screen at the gate whose screenshots
show all three changes. Say yes and see the screen, the design file and the saved design
committed.

**Acceptance Scenarios**:

1. **Given** a `[screen: custom]` task or a request for custom design, **When** the lane starts,
   **Then** it runs the custom mode, grills the user one question at a time with a recommended
   answer, and builds no code before the user says the design is good.
2. **Given** the grill is done and FigCraft is not open with the lane's control port, **When**
   the lane goes on, **Then** it starts FigCraft itself, limited to the project (FR-007), and the
   agent draws the first design in that window.
3. **Given** a project with a design file and a task that does not ask for a new look, **When**
   the agent draws the first design, **Then** it uses the design file's colors, fonts and spacing
   and there is no theme pick. **Given** a task that asks for a new look or an overhaul, **Then**
   the user picks a theme first and the design uses its tokens.
4. **Given** the lane is stopped for the user's changes, **When** the user replies with anything
   that says the design is good, **Then** the lane saves the design (with the user's unsaved
   changes) to the project and goes on. **When** the user asks the agent for a change, **Then**
   the agent makes it live and the lane stays stopped.
5. **Given** the design is saved, **When** the lane builds the code, **Then** the built screen
   follows the saved design's layout and the design file, without FigCraft open, and the gate
   shows the screenshots, the checks and the design file. There is no other stop between "good"
   and the gate.
6. **Given** the user says yes at the gate, **When** the lane ends, **Then** the screen, the
   design file and the saved design file are committed.

---

### User Story 2 - Redesign a screen that already exists (Priority: P1)

The user wants to improve a screen the project already has, and keep control over the result.
The user asks for custom design on that screen with `/stratum:st-design`, or `/stratum:st` sends
the task to the Design lane. The agent first draws the current screen in FigCraft from its code
and a screenshot, in the existing look. The user changes it, says it is good, and the lane builds
the code again from the saved design, as in User Story 1 (D17).

**Why this priority**: The user said this is the most common use: improve the design of a system
without a change to its color scheme.

**Independent Test**: In a project with a built screen, ask for custom design on it. See the
current screen drawn in FigCraft. Change one part, say it is good, and get the screen rebuilt with
that change and the rest kept.

**Acceptance Scenarios**:

1. **Given** a request for custom design on an existing screen, **When** `/stratum:st` picks the
   lane, **Then** it picks the Design lane, not Fast or Quick.
2. **Given** the lane runs on an existing screen, **When** the agent draws the first design,
   **Then** FigCraft shows the current screen, drawn from its code and a screenshot, in the
   existing look.
3. **Given** the user changes the design and says it is good, **When** the lane builds, **Then**
   the screen's code changes to match the saved design, and parts the user did not change stay as
   they were.

---

### User Story 3 - Changes at the gate, in the tool or in code (Priority: P2)

At the gate the user sees the built screen and wants changes. The user says how each change is
made: in FigCraft or in code. When the user does not say, a layout or look change goes to FigCraft
and a small code-only fix (text, a link, behavior) goes to code (D13).

**Why this priority**: It keeps the saved design and the code the same, and still lets the user
pick a fast code fix.

**Independent Test**: At the gate, ask for a spacing change with no way named, and see the lane
stop again in FigCraft. Ask for a text fix "in code", and see it fixed in code with no FigCraft
stop.

**Acceptance Scenarios**:

1. **Given** the gate, **When** the user asks for a change "in FigCraft", **Then** the lane stops
   for the user's changes in FigCraft again, and on "good" saves, builds, checks and shows the gate
   again.
2. **Given** the gate, **When** the user asks for a change "in code", **Then** the lane makes it in
   code, checks again and shows the gate again, with no FigCraft stop.
3. **Given** the gate, **When** the user asks for a change and does not name a way, **Then** a
   layout or look change goes to FigCraft and a small code-only fix goes to code.

---

### User Story 4 - FigCraft as an optional tool (Priority: P3)

A user who wants the custom mode installs FigCraft. A user who never uses it is not stopped for it
(D19).

**Why this priority**: The custom mode needs FigCraft, but the new-look and autonomous modes must
not.

**Independent Test**: Run `/stratum:st-init` and see FigCraft offered as an optional install with
the exact command for the machine. With FigCraft missing, run a custom-mode task and see it stop
with the install link. Run a new-look task and see it go on.

**Acceptance Scenarios**:

1. **Given** `/stratum:st-init`, **When** it reaches the tool step, **Then** it offers FigCraft as
   an optional install, "for the custom design mode", and on yes gives the exact install command
   for the machine.
2. **Given** FigCraft is missing, **When** a custom-mode run starts, **Then** it stops before any
   work with the install link. **When** a new-look or autonomous run starts, **Then** it does not
   check FigCraft.
3. **Given** `/stratum:st-status`, **When** it lists the tools, **Then** it shows FigCraft as
   optional, "for the custom mode".

---

### Edge Cases

- The user closes FigCraft while the lane is stopped for changes: on "good", the lane says the
  window is closed and the unsaved changes are lost, starts it again on the last saved design,
  and stops again.
- The control port is in use by another program: the lane stops with a message that names the
  port. It does not kill the other program.
- The project has no design folder yet: the lane makes it before it starts FigCraft, since
  FigCraft's write limit needs an existing folder.
- A FigCraft call fails while the agent draws: the lane reports the failed step and stops. It does
  not build code from a half-drawn design.
- An existing screen in a framework project and no dev server answers: the lane stops with the
  dev server message, as the Design lane does now. It never starts a dev server.
- The user asks for a different direction at the gate: the lane goes back to the theme branch of
  the grill, then the agent draws in FigCraft again and the user gets the FigCraft stop again.
- A `[screen: custom]` task during an autonomous Full-lane Build: the screen waits for the user,
  and Build goes on with the other tasks, as it does for other screen tasks now.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `skills/st-design/SKILL.md` MUST have a third mode named "custom", so that Plan
  offers custom design as a `[screen]` mode (D9).
- **FR-002**: The lane MUST run the custom mode when the task line has `[screen: custom]` or the
  task asks for custom design. `/stratum:st` MUST send a task that asks for custom design to the
  Design lane, also for a screen that already exists (D17).
- **FR-003**: Plan MUST write `[screen: custom]` in the task line when the user picks custom
  design. Plan MUST still mark only new screens as `[screen]` (D17).
- **FR-004**: The custom mode MUST grill the user as the new-look mode does. With a design file or
  styled screens and a task that does not ask for a new look, it MUST skip the theme pick and take
  the first design's colors, fonts and spacing from the design file, or from the code's tokens
  when there is no design file. For a new look or an overhaul it MUST run the theme pick and use
  the picked theme's tokens (D16).
- **FR-005**: The lane MUST start FigCraft itself with its control port when the port does not
  answer, and MUST NOT close it after (D15).
- **FR-006**: The agent MUST draw the first design live in the open FigCraft window, through
  FigCraft's MCP server attached to that window. For an existing screen, it MUST first draw the
  current screen from its code and a screenshot (D17, D18).
- **FR-007**: The lane MUST start FigCraft so that agent calls can read files only inside the
  project and write files only inside the project's design folder, and so that FigCraft's sharing
  is off (D20).
- **FR-008**: After the first design, the lane MUST stop and tell the user to change the design in
  FigCraft and to say when it is good. Any reply that says the design is good MUST end the stop.
  While stopped, the agent MUST make changes the user asks for, on the layers the user selected
  when the user names "this" or "the selected" layer (D11, D18).
- **FR-009**: On "good", the agent MUST save the design, with the user's unsaved changes, to
  `design/<screen>.figcraft` in the project. The lane MUST write the design file (`DESIGN.md` +
  `.impeccable/design.json`) from the design's variables and styles and the grill answers, and the
  project's tokens (the engine's `tokens.css` and `base.css`) from the same variables, so a picked
  theme's tokens never ship over the user's changes (D12, D16).
- **FR-010**: The code build MUST read the saved design file (its layout and a picture of it) and
  the design file, with no FigCraft window needed. Every fix round MUST read the same saved design
  (D12).
- **FR-011**: The custom mode MUST have exactly one stop between the grill and the code build: the
  FigCraft stop. The design file MUST be shown at the gate with the screenshots (D21).
- **FR-012**: After the build, the custom mode MUST run the same checks, fix rounds, gate and
  commit as the new-look mode. The commit MUST include `design/<screen>.figcraft`.
- **FR-013**: At the gate, the lane MUST make each change the way the user names: in FigCraft (stop
  again as FR-008, then FR-009 and FR-010) or in code. With no way named, layout and look changes
  MUST go to FigCraft and small code-only fixes MUST go to code (D13).
- **FR-014**: The FigCraft steps (start, draw, save, read back) MUST live in one file beside the
  skill, `skills/st-design/design-tool.md`, as `engine.md` names the engine. FigCraft is the only
  tool built in this feature (D14).
- **FR-015**: The FigCraft MCP server config MUST be in `.claude-plugin/plugin.json`, and the
  `st-design` agent MUST have the FigCraft MCP tools (D18).
- **FR-016**: A custom-mode run MUST check for the FigCraft app and `figcraft-cli` at the start and
  stop before any work with the install link when one is missing. New-look and autonomous runs
  MUST NOT check them (D19).
- **FR-017**: `st-status` MUST show FigCraft as optional, "for the custom mode". `st-init` MUST
  offer FigCraft as an optional install and, on yes, give the exact install command for the
  machine (D19).

### Key Entities

- **Saved design**: `design/<screen>.figcraft`, the screen's design as the user approved it. It is
  the source of the screen's layout and is committed with the screen.
- **Design file**: `DESIGN.md` + `.impeccable/design.json`, the project's look. In the custom mode
  its tokens come from the saved design's variables and styles.
- **Design tool file**: `skills/st-design/design-tool.md`, the FigCraft steps. A later tool is a
  new copy of this file and one setting.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Three changes made by hand in FigCraft (one move, one resize, one recolor) all show
  in the built screen's screenshots at the gate.
- **SC-002**: A custom-mode run has exactly 1 stop between the end of the grill and the gate.
- **SC-003**: The user needs 0 manual steps to open the design tool during a run, after FigCraft is
  installed.
- **SC-004**: A new-look or autonomous run with FigCraft missing does 0 checks for FigCraft and
  stops 0 times for it.
- **SC-005**: During a run, 0 files outside the project's design folder are written through
  FigCraft and 0 designs are sent to a sharing server.
- **SC-006**: The same custom-mode run works on both of the user's machines (PC and laptop).
- **SC-007**: Stub tests show the custom mode, its `[screen: custom]` tag, the tool check and the
  MCP config are in place, and fail when one is removed.

## Assumptions

- FigCraft is in alpha (v0.13.1, 2026-10-31). Its commands cover frames, auto layout, components,
  variables and styles, which the custom mode needs.
- FigCraft's attached MCP server sees the open window's unsaved changes and the user's selection,
  as `docs/mcp.md` says. Nobody has run it here yet: the plan tests it.
- A plugin subagent can call MCP tools from the plugin's own config. The plan tests it before the
  build.
- The `plugin.json` MCP entry starts in every session of every project. The plan tests that it
  does not break or warn in sessions where `figcraft-cli` is not installed. If it does, the config
  moves to a project-level `.mcp.json` that `st-init` writes on the user's yes.
- The MCP config's command must find `figcraft-cli` on both machines. A Flatpak install does not
  put it on the PATH by that name, so the plan picks the command per install type.
- `figcraft-cli info --json` lists only the top-level frames. The plan picks the full layer-tree
  read for the build (an export format, or a `figcraft-cli run` script with read commands).
- FigCraft is installed from its GitHub release packages (AppImage, Flatpak, `.deb`, `.rpm`,
  tarball). The plan picks the install command per machine.
- One saved design file per screen.
- Out of scope: other design tools (D14), Plan marks for existing screens (D17), and FigCraft's
  own code export (the lane's agent builds the code).
