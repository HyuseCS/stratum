# Feature Specification: Ultracode Workflow Script for st-pr

**Feature Branch**: `22-workflow-scripts`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "Fix GitHub issue #22: Ultracode: ship workflow scripts for big tasks, starting with st-pr." Decisions D1 to D5 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Big branch, Ultracode on (Priority: P1)

The user has Ultracode on and runs `/stratum:st-pr` on a big branch (more than 30 commits or more
than 40 changed files). st-pr says in one line that it takes the workflow path and why. A fixed
script that ships with the plugin does steps 2 to 4 of st-pr: it gathers the facts with several
agents at once (test runs, FR to task to file map, changed files by area, commit subjects against
their diffs, a scan of everything the push publishes for secrets and personal data, the test
plan), writes the title and body, has three refuters check the body with one lens each (paths and
their A/M/D letters, FR claims, commands and test numbers), and applies the true fixes. The gate
(step 5) and push and create (step 6) run in the main session as today.

**Why this priority**: This is the issue's problem. Today the agent writes a new workflow script
by hand each time, so the result changes from run to run and the script is never tested.

**Independent Test**: Run st-pr with Ultracode on against a branch over the size rule. The one-line
path message names the workflow path and the counts. The body that reaches the gate passes the
step 4 check with no manual edit.

**Acceptance Scenarios**:

1. **Given** Ultracode on and a branch with 45 commits, **When** the user runs st-pr, **Then**
   the one-line message says the workflow path runs because 45 commits is over 30, and the
   fixed script runs, not a hand-written one.
2. **Given** Ultracode on and a branch with 12 commits and 60 changed files, **When** the user
   runs st-pr, **Then** the workflow path runs because 60 files is over 40.
3. **Given** the workflow path ran, **When** the gate shows the body, **Then** every named path
   exists at HEAD with the letter the body implies, every FR claim matches the facts, every
   command exists in the project, and the warnings list the flagged commit subjects and any
   unverified claim.
4. **Given** the facts scan finds a secret or personal data in what the push would publish,
   **When** the script reaches that point, **Then** it stops before the draft, and st-pr shows
   the find and stops before the gate. Nothing is pushed.
5. **Given** the workflow path ran, **When** it ends, **Then** the user sees the same gate as on
   the current path: body, title, base, existing PR handling, warnings, and the one question.

---

### User Story 2 - Small branch, or Ultracode off (Priority: P1)

The user runs `/stratum:st-pr` on a branch under the size rule, or with Ultracode off. st-pr says
in one line that it takes the current one-agent path and why, and runs as today.

**Why this priority**: A workflow uses many more tokens. Small tasks must keep the cheap path, and
the current path must not change for them.

**Independent Test**: Run st-pr with Ultracode on against a branch with 3 commits and 5 files.
The one-line message names the current path, and no workflow runs.

**Acceptance Scenarios**:

1. **Given** Ultracode on and a branch with 3 commits and 5 files, **When** the user runs st-pr,
   **Then** the one-line message says the current path runs because 3 commits is not over 30 and
   5 files is not over 40, and no workflow starts.
2. **Given** Ultracode off and a branch with 100 commits, **When** the user runs st-pr, **Then**
   the current path runs and the message says Ultracode is off.
3. **Given** a branch with exactly 30 commits and exactly 40 files, **When** the user runs st-pr,
   **Then** the current path runs (the rule is "more than").

---

### User Story 3 - The script is tested (Priority: P2)

A maintainer changes the script. The project's tests run the script with fake agents and prove its
control flow: commit subjects are split in chunks of 25, a blocking find stops the run before the
draft, the three refuters each run, and fixes are applied one after another. A second test fails
when the st-pr skill text stops naming the two thresholds or the script path.

**Why this priority**: The issue's second problem is "the script is not tested". Without this
story a script edit can break st-pr with no test going red.

**Independent Test**: Run the project's tests. Change the chunk size or remove the blocking stop
from the script, run again, and watch the test go red.

**Acceptance Scenarios**:

1. **Given** the script as shipped, **When** the tests run, **Then** the script test passes with
   no real agent started.
2. **Given** a script where the blocking stop is removed, **When** the tests run, **Then** the
   script test fails and names the blocking stop.
3. **Given** a skill text without the words for "30 commits", "40 files" or the script path,
   **When** the tests run, **Then** the grep test fails and names the missing part.

### Edge Cases

- The size counts cannot be computed (no base, empty range): st-pr already stops in step 1
  before the path choice.
- The script ends with no result, or a fact agent dies: the script treats a missing fact agent as
  "unverified" and lists it under warnings; a missing draft is a failure that st-pr reports, and
  st-pr falls back to the current path for steps 2 to 4.
- A refuter reports a problem that is not real: the fixer checks it against the source first and
  drops it; the drop is named in the warnings.
- The repo has no feature spec: the FR map agent reports "N/A" and the body's Requirements
  section says so, as the template asks.
- The user is in a worktree: all facts come from the project root given to the script, never
  from another checkout.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plugin MUST ship a fixed workflow script at `<plugin root>/workflows/pr.js`
  that does steps 2 to 4 of st-pr: facts, draft, verify, fix.
- **FR-002**: st-pr MUST run the script only when both hold: Ultracode is on (a system-reminder
  in the session says so) and the branch is over the size rule: more than 30 commits in
  `origin/<base>..HEAD` or more than 40 changed files in `origin/<base>...HEAD` (three dots,
  from the merge base, as step 2 counts files). Both numbers and the script path MUST be
  written in the skill text.
- **FR-003**: When either condition fails, st-pr MUST run the current one-agent path for steps 2
  to 4, unchanged.
- **FR-004**: st-pr MUST say in one line which path it takes and why, with the two counts and the
  Ultracode state.
- **FR-005**: The script's facts phase MUST run read-only and side by side: every test suite,
  the FR to tasks to diff-files map, changed files grouped by area, commit subjects checked
  against their diffs in chunks of 25 commits, a scan of everything the push publishes for
  secrets and personal data, and the test plan from `quickstart.md`.
- **FR-006**: On a blocking secrets or personal-data find, the script MUST stop before the draft
  and return the find; st-pr MUST show it and stop before the gate.
- **FR-007**: The draft phase MUST write the title and body to the session scratchpad's
  `pr-body.md` using the same template rule as the current step 3.
- **FR-008**: The verify phase MUST run three refuters, one lens each: paths and their A/M/D
  letters; FR claims; commands and test numbers. Each reports problems with the line they are on.
- **FR-009**: The fix phase MUST check each reported problem against the source and apply only
  the true ones, one fixer after another, never two at once on the body file. Dropped problems
  are named in the warnings.
- **FR-010**: The script MUST return the title, the body file path, the warnings (flagged commit
  subjects, unverified claims, dropped problems), and whether it was blocked. The gate (step 5)
  and push and create (step 6) MUST stay in the main session and MUST NOT change.
- **FR-011**: The script MUST use 5 facts agents plus one per 25-commit chunk, 1 draft, 3
  refuters, and up to 3 fixers: 15 agents at 60 commits. No model or effort overrides.
- **FR-012**: A project test MUST run the script with fake agents and fail when the chunk size,
  the blocking stop, the three refuters, or the sequential fixes change.
- **FR-013**: A project test MUST fail when the st-pr skill text no longer names "30" commits,
  "40" files, or `workflows/pr.js`.

### Key Entities

- **Size rule**: the two thresholds (30 commits, 40 files) and the two counts for the branch.
- **Facts**: the six read-only results: test results, FR map, file groups, flagged commit
  subjects, publish scan, test plan.
- **Draft**: the title and the body file.
- **Problem**: one refuter finding: lens, line, what is wrong, what is right.
- **Result**: title, body path, warnings, blocked.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a branch over the size rule with Ultracode on, the body shown at the gate
  passes the step 4 check with zero manual edits.
- **SC-002**: On a branch under the size rule, or with Ultracode off, no workflow starts and the
  steps 2 to 6 run as before. Shown once on a small PR.
- **SC-003**: A blocking find in the publish scan never reaches the gate or the push.
- **SC-004**: The project's tests go red when the script's chunk size, blocking stop, refuter
  count or sequential fixes change, and when the skill text drops a threshold or the path.
- **SC-005**: The same branch gives the same phase structure on every run: the script file does
  not change between runs.

## Assumptions

- A skill whose text tells the agent to call the workflow tool counts as the user's opt-in, as
  the tool's own rule says. The skill text also sets the scale: FR-011 (15 agents at 60 commits) overrides the
  session's "under 10" guideline (D2).
- The script has no file access of its own. Every fact and every edit is done by its agents. The
  session passes the scratchpad path, project root, plugin root, base, branch and feature
  directory to the script as arguments.
- The two thresholds are fixed in the skill text, not a setting (issue #22).
- Only st-pr gets a script now. st-review and st-inspect are "Later" in the issue; st-build is
  low value there. Out of scope.
- The feature number is 006; 005 is st-triage.

## Deferred Gaps (Close, 2026-10-23, decision D7)

- G1. Task T004 (manual demos M3, M4, M5; SC-001, SC-003, SC-005): passed on 2026-10-24 (quickstart section 3).
- G2. Task T005 (manual demos M1, M2; SC-002): passed on 2026-10-24 (quickstart section 3).
- G4. Open runtime checks: whether `scriptPath` is readable from the installed plugin cache (M5), whether `hooks/st-git-guard.py` fires inside workflow agents, and whether workflow agents can write to the session scratchpad (if not, the draft returns no `bodyPath` and the fallback runs). On 2026-10-24: the `scriptPath` check is moot (D8, the name call ran from outside the plugin in M5); workflow agents write to the session scratchpad (M3 and M5 returned a `bodyPath` there); the git guard inside workflow agents is still unchecked.
