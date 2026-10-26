# Feature Specification: Design Lane

**Feature Branch**: `009-design-lane`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "GitHub issue #49 on HyuseCS/stratum: a Design lane, a creative, non-generic design step for screen work. Today `st-build` loads `st-ui-ux` before a screen task, and the output is generic: a keyword search gives the same category default each time, and nothing checks the result. The lane makes the project's design file with the user, builds screens from it with hallmark as the new-look engine, and checks them before the user sees them." Decisions D1 to D19 are in `decisions.md` (the Q and O codes start at Q5 and O3, after the codes in #49). Wiring Fast and Full to call the lane is in #51 (D10). Browser tools for page checks and e2e tests are in #52.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A new look, made with the user (Priority: P1)

The user asks for a new look, or for a new page or screen in a project with no look yet. The
orchestrator grills the user, one question at a time with a recommended answer, until the design
tree is empty. The first branches are the North Star, the overview voice, color character,
elevation, components, UX (density, how a user moves through the screens), and the audience, use,
tone, material and theme (D12, D13, D20, D23). The answers become the project's design file, and the user confirms it.
Then the lane builds one reference screen from the file, runs the checks and fixes (FR-008), and
shows the user the screenshots and its picks (theme, type, palette, structure). The user says
yes, gives changes, or asks for a different direction. On yes, the design file and the screen are
committed.

**Why this priority**: This is the core of #49: a look that is the user's own and not a category
default. The design file it makes is what every later screen follows.

**Independent Test**: In a project with no design file, ask for a new look. Answer the grill,
confirm the file, and get one built screen with screenshots and a picks list, after its checks
passed. Say yes and see the file and the screen committed.

**Acceptance Scenarios**:

1. **Given** a project with no design file, **When** the user asks for a new look, **Then** the
   orchestrator grills the user one question at a time, each with a recommended answer, and does
   not build before the user confirms the design file.
2. **Given** a confirmed design file, **When** the lane builds the reference screen, **Then** the
   screen follows the file, passes the checks of FR-008 or lists what is still open after 2 fix
   rounds, and the user sees screenshots and the picks.
3. **Given** the gate after the build, **When** the user asks for changes, **Then** the lane
   makes them, runs the checks again, and shows the gate again. **When** the user asks for a
   different direction, **Then** the lane goes back to the theme branch and the design file
   confirm, then builds, checks and shows the gate again (D24).
4. **Given** the user says yes at the gate, **When** the lane ends, **Then** the design file and
   the reference screen are committed, and nothing behind the screen (FR-012) was built.

---

### User Story 2 - A new page in the existing look, with no gate in the middle (Priority: P1)

The user asks for a new page and wants the project's existing look. The project has a design
file. If the request does not say the page's job, its visitor or its main action, and the design
file does not say them either, the orchestrator asks once, with all the missing items in one
message (D7). Then the lane builds the page from the design file with no more questions. It runs
the checks, fixes what they find for up to 2 rounds, and runs its component tests. It gives the
user the page with screenshots and a list of what was found, fixed, still open, and assumed. The
user checks it, and the lane commits.

**Why this priority**: The user's main way of working: "build it and I will check it after". It
must still give a page that is unique, not generic, and with good UX (D4).

**Independent Test**: In a project with a design file, ask for a new page with a clear request.
Get the page with no question asked, with screenshots, the checks passed, the component tests
run, and a report. Ask again with a vague request and get exactly one message with the missing
items before the build.

**Acceptance Scenarios**:

1. **Given** a project with a design file and a clear request, **When** the user asks for a new
   page, **Then** the lane asks nothing, builds the page from the design file, and reports.
2. **Given** a vague request, **When** the user asks for a new page, **Then** the orchestrator
   asks once before the build, all missing items in one message, and builds with no more
   questions after the answer.
3. **Given** the page is built, **When** the lane reports, **Then** the report has screenshots,
   each check's result, what was fixed, what is still open, every answer the lane assumed, and
   the component tests it ran.
4. **Given** the page has UI behavior (FR-011), **When** the project has a UI test runner,
   **Then** the lane wrote component tests for that behavior and they pass; **When** it has none,
   **Then** the report says the behavior is not tested and no new test tool was added.
5. **Given** the user checked the page, **When** the user OKs it, **Then** the lane commits it.

---

### User Story 3 - A new page in a project with a look but no design file (Priority: P2)

The user asks for a new page in the existing look, but the project has no design file. The lane
reads the current look from the code as a draft, then grills the user as in User Story 1, and the
user confirms the file (D11, D12, D25). Then it builds the page as in User Story 2. This happens once per
project: the next request finds the file.

**Why this priority**: Many existing projects have a look in their code but no file. The design
file is the system's UI and UX philosophy, so the lane must not write it alone from the code.

**Independent Test**: In a project with styled screens and no design file, ask for a new page.
Get a grill that starts from the look found in the code, confirm the file, then get the page as in
User Story 2. Ask for a second page and get no grill.

**Acceptance Scenarios**:

1. **Given** a project with styled screens and no design file, **When** the user asks for a new
   page in the existing look, **Then** the lane drafts from the code, grills the user, and does
   not build before the user confirms the file.
2. **Given** the file was made in this way, **When** the user asks for another page, **Then** no
   grill runs.

---

### User Story 4 - Getting into the lane, and its tools (Priority: P2)

`/stratum:st` sends a new look, or a new page or screen, to the Design lane, and says so in one
line. Changes to screens that exist stay in Fast or Quick. The user can call
`/stratum:st-design` directly and can override the pick (D9). The lane checks its tools at the
start. `st-status` and `st-init` report the same tools. Hallmark is pinned and synced from
upstream like impeccable (D5).

**Why this priority**: Without the routing the user must remember to call the lane. Without the
tool check the layout check would be skipped in silence.

**Independent Test**: Give `/stratum:st` a task for a new page and see it pick the Design lane;
give it a fix to an existing screen and see Fast or Quick. Remove `puppeteer-core` and see the lane
stop at the start with the install command, and `st-status` name it.

**Acceptance Scenarios**:

1. **Given** a task for a new look, page or screen, **When** `/stratum:st` picks a lane,
   **Then** it picks Design and says so in one line, and the user can override it.
2. **Given** a change to a screen that exists, **When** `/stratum:st` picks a lane, **Then** it
   picks Fast or Quick, as today.
3. **Given** node, `puppeteer-core` or a Chrome or Chromium browser is missing, **When** the lane
   starts, **Then** it stops before any work and prints the exact install command.
4. **Given** the same tool is missing, **When** the user runs `st-status` or `st-init`, **Then**
   the tool check names it.
5. **Given** the monthly sync, **When** `st-sync` runs, **Then** it lists hallmark's upstream
   changes since the pinned commit, as it does for impeccable.

### Edge Cases

- The user asks for changes at the gate many times: each round runs the checks again; the lane
  does not count these rounds against the 2 fix rounds of FR-008.
- A check still fails after 2 fix rounds: the lane stops fixing and lists the item as open in the
  report; it does not loop.
- The request needs work behind the screen (data, API, sign-in): the lane builds the screen with
  placeholder data of the same shape and names the work behind it for Fast or Full (FR-012).
- The user has set `TOGETHER_API_KEY`: hallmark may generate images, and the report says so. With
  no key, the lane never asks for one (FR-016).
- A framework project (a dev server renders the page) with no dev server answering on its port:
  the lane stops before any work, like a missing tool, and tells the user to start it with the
  exact command. The lane never starts a dev server; the user does.
- A new screen inside a bigger Full or Fast feature: this feature does not route it to the lane;
  the user calls `/stratum:st-design` (D10, #51).
- An existing design file that the user wants to change: out of scope here; it is a new-look
  request (User Story 1).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Design lane MUST be its own lane, callable as `/stratum:st-design`, with two
  modes: new look (User Story 1) and autonomous (User Stories 2 and 3).
- **FR-002**: `/stratum:st` MUST send a new look, or a new page or screen, to the Design lane,
  and accept the user's override. Every lane, Quick included, MUST say the lane in one line before
  its first skill or agent starts. A new page or screen is one the project does not have yet. A
  change to a screen that exists, including a new component on it, MUST keep its current lane
  (Fast, or Quick for a small fix).
- **FR-003**: The lane MUST make a missing design file with the user through the `st-grill`
  method: one question at a time, each with a recommended answer, until the frontier is empty.
  The first branches MUST be North Star, overview voice, color character, elevation, components
  and UX; in the new-look mode also audience, use, tone, material and theme (the user picks one of 3 themes
  hallmark deals, D20).
- **FR-004**: The design file MUST be written by `st-impeccable document` from the grill's
  answers. The lane MUST give it those answers, so it does not ask its own questions again. The
  user MUST read and confirm the file before any screen is built.
- **FR-005**: With styled screens (a tracked file sets a color or a font) and no design file, the lane MUST start the grill from the look
  it reads in the code.
- **FR-006**: The new-look mode MUST stop for the user exactly twice per direction: once to
  confirm the design file (FR-004), and once at the gate after the reference screen is built and
  checked (FR-008). At the gate the user sees screenshots and the picks and can answer yes,
  changes, or a different direction. Changes MUST lead to a new build, new checks and the same
  gate again. A different direction MUST go back to the theme branch and the design file confirm,
  then to a new build, new checks and the gate (D24). Only yes ends the mode.
- **FR-007**: The autonomous mode MUST ask nothing when the request and the design file give all
  three of: the page's job (what the page is for), its visitor (who uses it), and its main action
  (the one thing the visitor must do there). When one is missing, it MUST ask once, before the
  build, with all missing items in one message, and MUST ask nothing more until it reports. The
  only other stop is the design-file grill of User Story 3, when the project has no design file.
- **FR-008**: Before the lane shows a screen to the user, the screen MUST go through these checks,
  each owning one concern: hallmark's lint (generic patterns in the code), hallmark's render check
  (layout at each width), `st-impeccable audit` (accessibility and speed), `st-impeccable
  critique` (UX). Critique runs in full, with its own detector, split by rule: for each rule that
  hallmark's lint also checks (the same or partly the same), hallmark's lint owns it and the
  detector MUST ignore it; the detector owns only the rules hallmark's lint lacks (D21). Hallmark's
  own reviewer and the responsive part of the audit MUST NOT run. A check passes when it reports no finding at its two highest severity levels; lower
  findings go in the report. One fix round is: fix the findings that block a pass, then run all
  four checks again. The lane MUST run at most 2 fix rounds and then report what still blocks a
  pass as open.
- **FR-009**: The lane's report MUST list screenshots, each check's result, what was fixed, what
  is open, every assumed answer, and the component tests run.
- **FR-010**: The lane MUST name hallmark in one place only, so a swap to another engine changes
  one place (D8).
- **FR-011**: The lane MUST build the screen as a frontend engineer: layout, components, styles,
  copy, pictures, motion, UI state, client-side form checks, loading, empty and error states,
  accessibility and keyboard use.
- **FR-012**: The lane MUST NOT build what is behind the screen: API calls, data fetch and save,
  data model, sign-in, server code. It MUST use placeholder data of the same shape and name that
  work for Fast or Full.
- **FR-013**: The lane MUST write component tests for the UI behavior it builds, with the
  project's own test runner, and run them before it reports. With no UI test runner it MUST say
  so in the report and MUST NOT add one.
- **FR-014**: The lane MUST commit through `st-git` with exact paths, only after the user's yes
  at the gate (new look) or the user's OK after the check (autonomous). In the autonomous mode,
  if the user asks for changes after the check, the lane MUST make them, run the checks and tests
  again, and report again before it commits.
- **FR-015**: The lane MUST check node, `puppeteer-core` and a Chrome or Chromium browser at the
  start, and stop before any work with the exact install command when one is missing. `st-status`
  (and so `st-init`) MUST check the same tools and print the script's lines word for word.
- **FR-016**: The lane MUST NOT ask for `TOGETHER_API_KEY` or turn image generation on. It MUST
  say in the report when hallmark used a key the user set.
- **FR-017**: Hallmark MUST be vendored like impeccable: a pinned entry in `vendor.lock`, its
  license kept, and upstream changes listed by `st-sync`.
- **FR-018**: `st-impeccable` MUST stay as it is (D1). The lane MUST NOT edit vendored impeccable
  or hallmark files. The vendored hallmark copy changes only its frontmatter: the `st-hallmark`
  name and `disable-model-invocation: true` (D22).

### Key Entities

- **Design file**: the project's UI and UX philosophy and direction (`DESIGN.md`), made with the
  user. Every screen the lane builds follows it.
- **Reference screen**: the one screen the new-look mode builds to show the direction.
- **Picks**: the theme, type, palette and page structure hallmark chose for a screen.
- **Lane report**: screenshots, check results, fixed, open and assumed items, and tests run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a side-by-side demo, the same small brief is built the old way (`st-build` with
  `st-ui-ux`) and with the Design lane, and the user picks the lane's version from the
  screenshots.
- **SC-002**: An autonomous run in a project with a design file and a clear request gives a page
  with 0 questions asked, all four checks run, and a full report (FR-009).
- **SC-003**: A vague request gives exactly 1 message of questions before the build, and 0 after.
- **SC-004**: Stub tests show the lane skill, the routing row, the `vendor.lock` entry and the
  tool check are in place, and fail when one is removed.
- **SC-005**: With a tool missing, the lane does 0 work and prints 1 install command.

## Assumptions

- The project's UI runs in a browser. Native mobile screens are out of scope for hallmark's
  render check.
- The four checks map to real tool output: the plan confirms the concern split of FR-008 and
  which severity levels count as the two highest for each tool.
- Hallmark reads `design.md` and impeccable writes `DESIGN.md`. The plan picks one file name that
  both see.
- The plan decides whether the lane's build runs in a new agent or in `st-build` with hallmark
  loaded, and whether a `PRODUCT.md` is written or the grill covers it.
- Hallmark's photos come from Wikimedia links, so a build needs network access for pictures.
- Fast and Full do not call the lane in this feature (D10, #51). Browser tools for e2e tests are
  out of scope (#52).
- Changing an existing design file is a new-look request, not a separate mode.
