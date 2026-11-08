# Feature Specification: st-advisor, an on-demand Codex review with no spec folder

**Feature Branch**: `worker-f79` (feature folder `017-st-advisor`)

**Created**: 2026-11-08

**Status**: Draft

**Input**: User description: "Issue #79: an on-demand Codex diff review that needs no `spec.md`, fits a whole-build diff, and has a skill the user can call by name. Grill decisions D11–D18 in `decisions.md`; D19 and D20 come from the plan."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review finished work on demand, with no spec folder (Priority: P1)

The user has finished work on a branch, for example a whole build made outside a Stratum lane,
with no `specs/<feature>/spec.md`. The user types `/stratum:st-advisor`, or
`/stratum:st-advisor <base>`. The skill starts a Codex review of the commits from the base to
HEAD in the current folder. With no base, the base is the point where the branch left `main`.
The review runs in the Codex tab first, so the user can watch it, and it has no time limit
there. When the tab cannot be used, the review runs headless as a fallback, with a longer
limit than the lane points. Codex does a full review: bugs, regressions, security and broken
rules of the project's constitution. The result goes to a record file outside the tracked
files. The skill checks each finding against the source and shows the real ones.

**Why this priority**: This is the gap in #79. Today the advisor review needs a feature folder
with `spec.md`, writes into that folder, has a 540 s limit for the whole point, and can start
only from inside a lane.

**Independent Test**: In a repo with no `specs/` folder, make two commits on a branch and run
the skill with no argument. Check that a review runs, that the record appears at
`<main checkout>/.stratum/advisor/<branch>.md`, and that `git status` shows no other change.

**Acceptance Scenarios**:

1. **Given** a branch with commits and no feature folder, **When** the user runs the skill with no argument, **Then** the review covers the commits from the point where the branch left `main` to HEAD.
2. **Given** a base ref, **When** the user runs the skill with it, **Then** the review covers the commits from that base to HEAD.
3. **Given** the session runs in herdr and the Codex tab is free, **When** the review runs, **Then** it runs in the Codex tab with no time limit, and the output says that the tab ran it.
4. **Given** the session is not in herdr, or the Codex tab is busy, or the tab name is in use in another folder, **When** the review runs, **Then** it runs headless with a limit of 1800 s, and the output says headless and why.
5. **Given** advisor mode `auto`, `codex` or `both`, at any risk level, **When** the user runs the skill, **Then** Codex runs.
6. **Given** advisor mode `off`, **When** the user runs the skill, **Then** no review runs and the output says the mode is off.
7. **Given** any review, **When** it ends, **Then** its verdict, summary and findings are added to `<main checkout>/.stratum/advisor/<branch>.md`, and earlier entries in that file stay.
8. **Given** the review is done, **When** the skill shows the result, **Then** it shows only findings it checked against the source, and lists the dropped ones with why.

---

### User Story 2 - Review a worker's pull request by number (Priority: P1)

The orchestrator session runs in the main checkout. A worker has finished its work in its own
worktree and opened a pull request. The user types `/stratum:st-advisor #<n>`. The skill finds
the local worktree that has the PR's branch checked out, and checks that its HEAD is the PR's
head commit, so the work is finished and pushed. Then it reviews from that worktree. At the
same time it runs a CodeRabbit review of the same range. The CodeRabbit findings go in their own
section of the same record. The skill checks each finding from both reviewers against the
source before it shows them.

**Why this priority**: The case in #79 was a review of a worker's PR from the orchestrator
session. The user had to make a Codex tab by hand. CodeRabbit is the second reviewer the user
uses on PRs.

**Independent Test**: Make a worktree with a branch, push it, open a PR, and run the skill with
the PR number from another checkout. Check that the review ran in the worker's worktree, and
that the record has a Codex entry and a CodeRabbit section.

**Acceptance Scenarios**:

1. **Given** a PR whose branch is checked out in a local worktree at the PR's head commit, **When** the user runs the skill with the PR number, **Then** the review runs in that worktree and covers the PR's commits.
2. **Given** a PR whose branch is not checked out in any local worktree, **When** the user runs the skill with its number, **Then** no review runs and the skill says that no local worktree has the branch.
3. **Given** a worktree whose HEAD is not the PR's head commit, **When** the user runs the skill with the PR number, **Then** no review runs and the skill says that the worktree and the PR do not match.
4. **Given** the PR form, **When** the review runs, **Then** a CodeRabbit review of the same range runs at the same time, and its findings go in their own section of the same record file.
5. **Given** the PR form and CodeRabbit is not installed or not signed in, **When** the review runs, **Then** the Codex review still runs and the skill says that CodeRabbit did not run, and why.
6. **Given** the plain form (no argument, or a base ref), **When** the review runs, **Then** CodeRabbit does not run.
7. **Given** Codex falls back to headless, **When** the PR form runs, **Then** CodeRabbit still runs.

---

### User Story 3 - Check the work against a plan in any format (Priority: P3)

The user names a plan or spec file with the review, for example a RIPER plan file in another
folder layout. Codex then also checks whether the diff does what that file says. With no file,
there is no plan check.

**Why this priority**: The work in #79 had a plan, but not in a Stratum spec folder. The full
review of Story 1 already covers the main need.

**Independent Test**: Run the skill with a base ref and a plan file that names one change the
diff does not make. Check that the record has a finding about the missing change.

**Acceptance Scenarios**:

1. **Given** a readable plan file, **When** the review runs, **Then** Codex checks whether the diff does what the file says, and a gap is a finding.
2. **Given** a plan file that does not exist or cannot be read, **When** the user runs the skill, **Then** no review runs and the skill says that the file cannot be read.
3. **Given** no plan file, **When** the review runs, **Then** there is no plan check.

---

### Edge Cases

- No commits between the base and HEAD: no review runs, and the output says there is no change.
- No `main` branch and no base given: the skill stops and asks for the base.
- The base is not a commit: the skill stops with the usage line.
- A file changes in the review folder during a review in the Codex tab: the review is BLOCKED, the same as today, and the record says so. A headless review has no change check, the same as the other points. The review is made for finished work, so this is an error case.
- Codex cannot run in the PR form (mode off, mode not set, Codex not installed): the skill stops before either reviewer starts, with the same line as the script, and CodeRabbit does not run (D19).
- Uncommitted files in the review folder: they are not part of the review. The skill says that they are not reviewed.
- Advisor mode is not set: the skill stops and asks the advisor question of `/stratum:st-init`, the same as the lane points.
- Codex is not installed: no review runs, and the output says so.
- The branch name has `/` in it: each `/` becomes `-` in the record file name.
- Detached HEAD: the record file name is the short commit id.
- The Codex tab shows a prompt during the review: the skill handles it with the same allow list as the lane points, and brings any other prompt to the user with the exact screen text.
- The PR's worktree is on another machine: the skill finds no local worktree and stops (Story 2, Scenario 2).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The advisor script MUST have a new point, `review <base>`, that needs no feature folder and no `spec.md`.
- **FR-002**: The `review` point MUST review the commits from `<base>` to HEAD in the folder where it runs. A base that is not a commit MUST stop with the usage line. No change between base and HEAD MUST give a "no change" line and run no review.
- **FR-003**: The `review` point MUST run Codex in advisor mode `auto`, `codex` or `both`, at any risk level. Mode `off`, mode not set, and Codex not installed MUST give the same lines as the other points.
- **FR-004**: The `review` point MUST use the Codex tab first. It MUST fall back to a headless run only when the session is not in herdr, the tab is busy, or the tab name is in use in another folder. The output MUST say which one ran.
- **FR-005**: The headless fallback of `review` MUST have a limit of 1800 s. The other points MUST keep their 540 s limit.
- **FR-006**: In a review that runs in the Codex tab, a change to a file or to HEAD in the review folder during the review MUST make the review BLOCKED, the same as the other points. A headless review has no change check, the same as the other points.
- **FR-007**: The `review` point MUST add each result (verdict, summary, findings, or BLOCKED with the reason) to `<main checkout>/.stratum/advisor/<branch>.md`, also from a linked worktree. Each `/` in the branch name MUST become `-`. On a detached HEAD the file name MUST be the short commit id. Earlier entries MUST stay.
- **FR-008**: This repo's `.gitignore` MUST ignore `.stratum/advisor/`.
- **FR-009**: The `review` prompt MUST ask Codex for a full review: bugs, regressions, security and broken rules of the project's constitution. It MUST keep the review-only and secrets rules of the other points.
- **FR-010**: When the caller names a plan or spec file, the prompt MUST also ask whether the diff does what that file says. A file that does not exist or cannot be read MUST stop the point with the usage line.
- **FR-011**: Stratum MUST have a `/stratum:st-advisor` skill. It MUST take no argument (base: the point where the branch left `main`), a base ref, or a PR number, and an optional plan file.
- **FR-012**: For a PR number, the skill MUST find the local worktree that has the PR's branch checked out, check that its HEAD is the PR's head commit, and run the review there with the PR's base. When no worktree has the branch, or HEAD is not the PR's head commit, or the PR cannot be read, it MUST stop and say why.
- **FR-013**: For a PR number only, the skill MUST also run a CodeRabbit review of the same range at the same time as Codex, and add its findings to the same record file in their own section. When CodeRabbit cannot run, the skill MUST say why and the Codex review MUST still run.
- **FR-014**: The skill MUST watch the Codex tab during the review and handle its prompts with the same rules as the Advisor section of the Build skill.
- **FR-015**: The skill MUST check each finding from Codex and CodeRabbit against the source before it shows it, and show the dropped ones with why, the record path, and which runner (tab or headless) ran Codex.
- **FR-016**: The other advisor points, the lanes, and the `advisor.md` in feature folders MUST NOT change. The one allowed change to their output is the shared usage line, which gains `review`.
- **FR-017**: The harness model and its drift test MUST list the new skill, so that all existing tests pass.

### Key Entities

- **Review record**: one Markdown file per branch, at `<main checkout>/.stratum/advisor/<branch>.md`. Each review adds one entry with the time, the hash of the reviewed diff, the verdict, the summary and the findings. A PR review also adds a CodeRabbit section.
- **Review request**: what the skill gives the script: the base, the folder to run in, and an optional plan file.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can start a review of a finished whole-build diff of about 5,800 lines with one command, with no `spec.md`, and the review in the Codex tab ends with a verdict and not with "timed out".
- **SC-002**: After any review, `git status` in the review folder is the same as before it, except the record file in a project that does not ignore `.stratum/advisor/`.
- **SC-003**: A user can review a worker's PR from the orchestrator session with one command, and the record has both a Codex entry and a CodeRabbit section.
- **SC-004**: Every finding the skill shows was checked against the source. 100% of the dropped findings are listed with a reason.
- **SC-005**: The lane points give the same output as before for the same inputs.
- **SC-006**: All existing tests still pass, including the harness model drift test.

## Assumptions

- The review is for finished work only (D12). The skill does not pin a copy of the code. A worker must not change its worktree during the review.
- The user chose to send PR diffs to the CodeRabbit service (D18). The plain form never sends code to CodeRabbit.
- CodeRabbit runs only where its command-line tool is installed and signed in. The skill does not install it or sign it in.
- The 1800 s limit is a choice, not a measured number. A diff that needs more time can run in the Codex tab, which has no limit.
- The PR form finds only worktrees on this machine. A worker on another machine is out of scope.
- In other projects, `.stratum/advisor/` is not added to `.gitignore`. A record file there shows as untracked.
- A live Codex tab run and a live CodeRabbit run cannot be part of the automated tests. Proof for them is a manual run, listed in the quickstart.
