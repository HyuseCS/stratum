# Feature Specification: Triage a GitHub Issue

**Feature Branch**: `15-st-triage`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "Fix GitHub issue #15: add `st-triage`, a read-only step that checks whether an existing GitHub issue is still valid against the current code and git history." Decisions D1 and D2 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Triage one issue (Priority: P1)

The user types `/stratum:st-triage 15`. The issue, its comments, and the repo notes and issues it
links to are read. Every claim in the issue is checked against the current code and git history.
The user gets one short report: the verdict (still valid, partly built, or obsolete), what is
already built with `file:line` and commits, the real blocker and what the user must provide, and
the next step (run `/stratum:st` in the Full lane, split the issue, or close it). Nothing in the
repo or on GitHub changes.

**Why this priority**: Old backlog issues point to old notes, and today no Stratum step checks
them against the code (issue #15). Without this story the feature has no value.

**Independent Test**: Run the command on one open issue. A report with the four parts arrives,
`git status` is unchanged, and the issue on GitHub is unchanged.

**Acceptance Scenarios**:

1. **Given** an issue whose claims are partly built, **When** the user runs the command,
   **Then** the report says "partly built", names each built part with `file:line` or a commit,
   and names what is still missing.
2. **Given** an issue that the code already covers in full, **When** the user runs the command,
   **Then** the report says "obsolete" and the next step is to close it.
3. **Given** an issue that links to a note that no longer exists, **When** the user runs the
   command, **Then** the report says the note is gone and what git history says about it.
4. **Given** any issue, **When** the report arrives, **Then** every cited `file:line` and commit
   was checked against the source before it was shown, and claims that could not be checked are
   marked as unchecked.
5. **Given** any issue, **When** the command ends, **Then** no file in the repo changed and the
   issue has no new comment, label, or state.

---

### User Story 2 - Triage several issues at once (Priority: P2)

The user types `/stratum:st-triage 100 102`. The issues are checked side by side and the user
gets one report per issue, in the order given.

**Why this priority**: Backlog triage comes in batches. Issue #15 was done by hand with two
research runs at once.

**Independent Test**: Run the command with two issue numbers. Two reports arrive, each with the
four parts, and the checks of one do not wait for the other.

**Acceptance Scenarios**:

1. **Given** two issue numbers, **When** the user runs the command, **Then** two reports arrive,
   each headed by its issue number, in the order given.

### Edge Cases

- The issue number does not exist, or the GitHub tool is missing or not signed in: the command
  says so in one line and stops.
- The issue is already closed: the report's first line says so, and the triage still runs.
- The issue makes no claim about the code (an idea only): the verdict is "still valid", the
  built part says "nothing built", and the next step is the Full lane.
- A linked note is outside the repo (a web page): it is not read, and the report says so.
- The agent that does the research changes a file: the command reports the change as a finding
  and shows it to the user.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `/stratum:st-triage <issue#>...` MUST read the issue's title, body and comments,
  and every repo file and GitHub issue or pull request the issue links to.
- **FR-002**: It MUST check each claim in the issue against the current code and git history,
  and cite a `file:line` or a commit for each claim it confirms or rejects.
- **FR-003**: The report MUST have four parts: the verdict, one of `still valid`, `partly built`
  or `obsolete`; what is already built, with `file:line` and commits; the real blocker and what
  the user must provide; and the next step, one of run `/stratum:st` in the Full lane, split the
  issue, or close it.
- **FR-004**: The command MUST NOT change any file in the repo and MUST NOT edit, comment on,
  label, or close the issue.
- **FR-005**: With several issue numbers it MUST check the issues side by side and give one report
  per issue, in the order given.
- **FR-006**: Before a report is shown, each cited `file:line` and commit MUST be checked against
  the source; a false cite is dropped or corrected and the drop is named.
- **FR-007**: When the issue cannot be read, the command MUST say why in one line and stop.
- **FR-008**: The research step MUST run as a read-only agent named `st-triage`, with no tool
  that writes files, so that the project's agent tests cover it like the other read-only agents.

### Key Entities

- **Issue**: a GitHub issue by number: title, body, comments, state, and the notes and issues it
  links to.
- **Claim**: one statement in the issue about the code ("X is not done", "the plan is in file
  Y"). Each claim gets a cite or an "unchecked" mark.
- **Report**: the verdict, the built list, the blocker, and the next step for one issue.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One command gives a report with all four parts for each issue number given.
- **SC-002**: Every confirmed or rejected claim in a report carries a `file:line` or commit cite;
  the rest are marked unchecked. Zero cites that do not match the source after the check.
- **SC-003**: After every run, the working tree and the issue on GitHub are as they were.
- **SC-004**: The project's tests fail when the `st-triage` agent has no command of the same name
  or has a tool that writes files.

## Assumptions

- The research runs in a read-only `st-triage` agent of the same name as the skill, one per
  issue, like the background agents of feature 004 (decision D3 there). The orchestrator checks
  the cites before it shows the report, as it does for `st-review`.
- The agent runs on Opus by default; the user can change it with `/stratum:st-model st-triage`.
- Links the agent follows: paths inside the repo and `#N` references to issues and pull
  requests of the same repo. Web pages are not fetched.
- The skill is not added to the "in the background" rule: it already starts an agent, so the
  user can keep talking while it runs.
- The feature number is 005, since 003 is the unmerged session-mods spike and 004 is taken.
- Out of scope: editing or closing issues, turning the verdict into a plan (that is `/stratum:st`),
  and triage of pull requests.
