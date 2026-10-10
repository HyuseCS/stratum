# Feature Specification: Merge Check and Validate into Inspect

**Feature Branch**: `002-merge-check-validate`

**Created**: 2026-10-10

**Status**: Draft

**Input**: User description: "GitHub issue #10 on HyuseCS/stratum: merge st-check and st-validate into one agent, and add an improvement pass to the advisor step." Issue body is the source spec. Grilling decisions:
- G1. A model file that names a removed agent is blocked like any unknown name. No special case.
- G2. Build the merged agent first, then remove both old agents. No trace of `st-check` or `st-validate` stays.
- G3. The new name is `st-inspect` for the agent, the skill (`/stratum:st-inspect`) and the phase (`inspect`).
- G4. The advisor step stays on Claude Code's `/advisor` (runs only when one is set). No Stratum advisor agent.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One agent runs the whole Inspect phase (Priority: P1)

A Stratum user runs `/stratum:st-inspect` after the plan. Today the Check phase starts two agents
in a row, and both read the same files. After this change one agent, `st-inspect`, starts. Its one
report covers both jobs: spec, plan and tasks agree (cross-artifact analysis), and the plan can be
built in the real project (setup, test coverage, breaking changes, security and privacy). It writes
the `## Validate` section of `plan.md` with the verdict.

**Why this priority**: This is the core of issue #10. The second agent start costs time and tokens,
and the orchestrator must pass findings from one agent to the other.

**Independent Test**: Run `/stratum:st-inspect` on a feature with a plan. Exactly one agent starts.
Its report has analysis findings, a coverage line and a validate verdict. `plan.md` has a fresh
`## Validate` section, and no other file changed.

**Acceptance Scenarios**:

1. **Given** a feature with spec, plan and tasks, **When** the user runs `/stratum:st-inspect`,
   **Then** one agent starts, and its report has cross-artifact findings, a coverage line and a
   verdict (PASS, CONDITIONAL or BLOCKED).
2. **Given** the Inspect agent ran, **When** the orchestrator compares `git status` before and
   after, **Then** only that feature's `plan.md` changed, and only its `## Validate` section.
3. **Given** a plan with an FR that has no task and a tool the project does not have, **When** the
   Inspect phase runs, **Then** the report names both (the same kinds of issues the two old agents
   found).

---

### User Story 2 - The advisor step also asks for improvements (Priority: P2)

Before the build gate, the orchestrator consults the advisor (if set). Today it asks only about
risks. After this change it also asks: is there a simpler or better approach, and which tasks can
be cut or merged? Each answer is a finding: checked against the source, small ones fixed, big ones
brought to the user before the build gate.

**Why this priority**: It improves plan quality, but the Inspect phase works without it.

**Independent Test**: Read `/stratum:st-inspect`. The advisor step names the risk questions and the
improvement questions, and says how the answers are handled.

**Acceptance Scenarios**:

1. **Given** an advisor is set, **When** the Inspect phase reaches the advisor step, **Then** it
   asks for risks and for improvements (simpler approach, tasks to cut or merge).
2. **Given** the advisor proposes a big change (scope or approach), **When** the orchestrator
   handles it, **Then** it goes to the user before the build gate.

---

### User Story 3 - No trace of the old names (Priority: P2)

The Full lane, the phase order checks, status, the model file check, the model command, setup and
the docs all name the phase and its agent. After the change they all say `inspect` /
`st-inspect`, list the same 10 agents, and none names `st-check` or `st-validate`.

**Why this priority**: A stale name sends users to a skill or agent that does not exist.

**Independent Test**: Search every tracked file outside `specs/` for `st-check` and `st-validate`:
no match. Put either name in a project model file and start any Stratum agent: the start is
blocked with "unknown agent" and the 10 allowed names.

**Acceptance Scenarios**:

1. **Given** the updated plugin, **When** a user searches its tracked files outside `specs/` for
   the whole words `st-check` or `st-validate`, **Then** there is no match.
2. **Given** a model file with an `st-check` or `st-validate` entry, **When** any Stratum agent
   starts, **Then** the start is blocked, and the message names the bad entry and lists the 10
   allowed agents, `st-inspect` among them.
3. **Given** the Full lane, **When** it runs, **Then** its phases are Define, Plan, Inspect, Build,
   Close, and state.json holds `phase: inspect` during the third one.
4. **Given** the release notes for the new version, **When** a user reads them, **Then** they say
   that `/stratum:st-check`, `st-check` and `st-validate` are replaced by `st-inspect`, and that a
   model file naming an old agent must rename or drop that entry.

### Edge Cases

- The Inspect agent finds a CRITICAL issue that the orchestrator then fixes: the agent runs once
  more, and it replaces its older `## Validate` section instead of adding a second one.
- The Inspect agent edits a file other than `plan.md`, or `plan.md` outside `## Validate`: the
  orchestrator sees it in `git status` or the diff and treats it as a finding.
- A project whose state.json still says `phase: check` (mid-feature during the update): the next
  phase skill warns once that the order is unexpected and runs, as it does for any out-of-order
  phase.
- A session that loaded the old plugin still lists the old skill and agents until it reloads: out
  of scope.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Stratum MUST have one Inspect agent, `st-inspect`, that runs the cross-artifact analysis and the validate checks (setup and dependencies, test coverage per requirement, breaking changes, security and privacy) in one pass.
- **FR-002**: The Inspect agent MUST run on opus with Read, Grep, Glob, Bash and Edit.
- **FR-003**: The Inspect agent MUST change no file except the `## Validate` section of the feature's `plan.md`, replacing an older one if present. It never installs, migrates, changes config or commits.
- **FR-004**: The Inspect agent's report MUST hold the analysis findings, the coverage line and the validate verdict with per-check results.
- **FR-005**: `/stratum:st-inspect` MUST replace `/stratum:st-check`, start one agent, set `phase` to `inspect`, and confirm by `git status` and `git diff` of `plan.md` that only `plan.md` changed, and only its `## Validate` section.
- **FR-006**: The advisor step of `/stratum:st-inspect` MUST ask for improvements (a simpler or better approach, tasks to cut or merge) as well as risks, and treat the answers as findings.
- **FR-007**: The `st-check` agent, the `st-validate` agent and the `/stratum:st-check` skill MUST be removed after `st-inspect` exists, and no tracked file outside `specs/` may name them.
- **FR-008**: The phase name MUST be `inspect` everywhere it is named: the Full lane, the phase order checks of the next phase, status and its next-gate text, README and DESIGN.
- **FR-009**: Every list of Stratum agents (model file check messages, `/stratum:st-model`, `/stratum:st-init`, README, DESIGN, tests) MUST show the same 10 names.
- **FR-010**: A model file that names `st-check` or `st-validate` MUST be blocked like any unknown agent name. No special case.
- **FR-011**: The plugin version MUST be bumped, and the release notes MUST name the renames and the model file action.
- **FR-012**: The Inspect agent and `/stratum:st-inspect` MUST keep every capability listed under "Kept capabilities". A check MUST confirm each one is named in the new files.
- **FR-013**: `README.md` MUST match the repo: it names every skill and every agent with its default model, every repo path and test file it names exists, every test file is listed, the theme and git guard option lists match the repo, and its skill and setup descriptions match the skills. A check MUST fail when the README drifts. (Added by the user during the Inspect phase.)

### Kept capabilities

From the old check agent and `procedures/analyze.md` (do spec, plan and tasks agree):

- C1. Duplicate requirements.
- C2. Vague words with no measure, and leftover placeholders (TODO, `???`).
- C3. Missing detail: a requirement with no outcome, a story with no acceptance criteria, a task naming a file the spec and plan never define.
- C4. Constitution MUST rules: any break is CRITICAL.
- C5. Coverage gaps: a requirement with no task, a task with no requirement, a success criterion that needs work but has no task.
- C6. Inconsistency: one concept with two names, an entity in one file but not the other, tasks out of order, conflicting requirements.
- C7. A test task placed after its build task, and `[P]` tasks that touch the same file. (A requirement with no test task is merged into V2.)
- C8. Severity per finding: critical, high, medium, low.
- C9. Coverage line: requirements covered by tasks / total, by tests / total.
- C10. Fixes are offered, never applied. Each finding says whether it needs a user decision.

From the old validate agent (can the plan be built in this project):

- V1. Setup and tools: everything the plan uses is installed or has a setup task, proved with read-only commands. Nothing is installed.
- V2. Tests that can fail: every requirement has a named test on real behavior; the test command and its runner exist.
- V3. Breaking changes: public API, contracts, data model, stored data, shared code. Each broken caller named. Migrations need a rollback note.
- V4. Security and privacy: access, sign-in, secrets, personal or minors' data, outside input each have a check. No secrets in code or git.
- V5. Verdicts: PASS, CONCERN or FAIL per check. Net: any FAIL is BLOCKED, only CONCERNs is CONDITIONAL, else PASS.
- V6. The `## Validate` section of `plan.md`, replacing an older one.

From the old phase skill:

- S1. `git status` before and after the agent: only `plan.md` may change.
- S2. Each finding checked against the source; false ones dropped, small ones fixed, big ones to the user one at a time.
- S3. Fixes to spec, plan or tasks go to `st-plan`; `st-git` commits them.
- S4. After a CRITICAL fix, the agent runs once more.
- S5. Advisor step: risks and improvements (FR-006).
- S6. Gate: "OK to build?", showing coverage, findings by severity, fixes made, findings dropped and the verdict.

### Key Entities

- **Inspect agent**: the one agent of the Inspect phase. Inputs: plugin root, project root, feature dir. Output: a report and the `## Validate` section of `plan.md`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The Inspect phase starts 1 agent instead of 2.
- **SC-002**: A whole-word search for `st-check` and `st-validate` in tracked files outside `specs/` finds 0 matches. (A plain search hits the icon name `list-checks`; see research R1.)
- **SC-003**: All existing model file tests pass with 10 agents.
- **SC-004**: On a sample feature with a planted cross-artifact gap and a planted buildability gap, the Inspect phase reports both.

## Assumptions

- `procedures/analyze.md` stays as it is. The validate checks move into the agent body, as they were in the old validate agent.
- The `## Validate` section name in `plan.md` stays. It names the job, not the old agent.
- The template `templates/models.json` names neither old agent, so only hand-edited model files hit FR-010.
- Release notes are the body of the version bump commit. Stratum has no CHANGELOG file, and the README may not name the old agents (FR-007).
- Old names in git history, `specs/001-*` and the ignored `.stratum/handoff.md` stay. They are history.
- "Check" as a plain word (a test check, a tool check) stays. Only the phase, skill and agent names change.
