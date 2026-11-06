# Feature Specification: Shared Codex advisor tab

**Feature Branch**: `013-codex-shared-tab`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Issue #75 ("Summoned Codex tab cannot be used by the user") and item 1 of issue #74 ("Orchestrator answers the permission prompts of agents it summons", Codex tab only). Grilling decisions D1 to D12 are in `decisions.md`. Items 2 to 4 of #74 (D7, Q8) are a later change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use the Codex tab yourself (Priority: P1)

The orchestrator opens one Codex tab in the user's workspace for advisor reviews. The user can talk to Codex in that same tab with their own Codex setup (config, history, skills, trust, approvals). An advisor point never types into the tab while the user is in a turn, and never closes the tab.

**Why this priority**: This is the problem #75 reports. Today the user must open a second Codex tab.

**Independent Test**: In herdr, run an advisor point, then type a request in the tab and get an answer, then run a second point with a changed model, and check the tab and the user's conversation are still there.

**Acceptance Scenarios**:

1. **Given** no Codex tab in the workspace, **When** an advisor point runs, **Then** one tab with the agent `st-codex-<workspace label>` opens with the user's own Codex setup, and the review runs in it.
2. **Given** the tab exists and is idle, **When** the user types a request in it, **Then** Codex answers with the user's normal config and approvals.
3. **Given** the user's turn is running in the tab, **When** an advisor point comes, **Then** nothing is typed into the tab, the review runs in the background instead, and the point says `codex: headless (Codex tab in use)`.
4. **Given** the model or effort in `advisor.json` changed since the tab opened, **When** a point runs, **Then** the tab stays open with the old values and the point prints a line telling the user to close the tab to apply the new ones.
5. **Given** the user closed the tab, **When** the next point runs, **Then** a new tab opens.
6. **Given** a point for a second feature in the same workspace and folder, **When** it runs, **Then** it uses the same tab and closes nothing.

---

### User Story 2 - A review never changes files (Priority: P1)

The advisor prompt and the st-build skill say Codex only advises and changes no file, unless the user drives the tab for something else. Each review is checked: the project's changed and untracked files before and after the turn must match. Any difference fails the point.

**Why this priority**: With the user's normal approvals, the read-only sandbox no longer stops a write. The check is the guard, and git is the undo.

**Independent Test**: Run a point where the fake Codex changes a tracked file, and one where it adds an untracked file, and check both points end BLOCKED with the file named and nothing reverted. Run a point that changes nothing and check it passes.

**Acceptance Scenarios**:

1. **Given** a review that changes no file, **When** the turn ends, **Then** the point passes as today.
2. **Given** a review during which a tracked file changed or an untracked file was added, changed or removed, **When** the turn ends, **Then** the point ends BLOCKED, lists each changed file, and reverts nothing.
3. **Given** any advisor prompt, **Then** it says Codex reviews only and changes no file.

---

### User Story 3 - The orchestrator answers Codex's prompts (Priority: P2)

When the tab opens, the orchestrator starts watching it. If Codex stops on a permission prompt during a review, the review keeps waiting in the tab. The orchestrator reads the screen and answers prompts that only let Codex read or run read-only commands. Every other prompt goes to the user with the exact screen text, and the tab stays open.

**Why this priority**: On 2026-11-04 a review stalled on a safe prompt, fell back to the background, and the user could not watch it. It is P2 because US1 and US2 work without it: a stalled review fails visibly instead of silently.

**Independent Test**: With a fake Codex that stops on a read prompt, check the point waits, the watch reports it, the answer command sends the key, and the review finishes in the tab. With a fake write prompt, check nothing is approved and the screen text reaches the user.

**Acceptance Scenarios**:

1. **Given** a point opens or reuses the tab, **Then** the orchestrator is watching the tab before the review prompt is sent.
2. **Given** Codex asks to read a file or run a read-only command (tests, lint, `git log`, `git diff`), **When** the orchestrator sees it, **Then** it approves it and the review goes on in the tab.
3. **Given** Codex asks to write or delete a file, change git state, install anything, or touch `.env` or secrets, **Then** the orchestrator approves nothing and shows the user the exact screen text; the tab stays open.
4. **Given** a prompt the orchestrator does not recognise, **Then** it goes to the user with the exact screen text.
5. **Given** a review runs in the tab, **When** the tab ends (the user closes it or Codex exits), **Then** the point ends BLOCKED with that reason and does not run the review in the background. A review in the tab has no time limit (D11).

### Edge Cases

- Text the user typed in the tab but did not send cannot be seen by the script. A point may type after it. This limit is marked as a deliberate shortcut.
- The tab is blocked on a prompt from the user's own turn when a point comes: the point treats the tab as in use and runs the review in the background.
- The project folder is not trusted in the user's Codex: the trust screen at start is a prompt like any other, so it goes to the user (trusting a folder changes the user's Codex config).
- Not inside herdr: the review runs in the background as today.
- A linked worktree in its own workspace gets its own tab. A linked worktree in the same workspace as its main checkout gets the same tab name, so while that tab is open its points run in the background with the clash line (D10).
- The old Stratum Codex home folder stays on disk. The user is told they may delete it.
- The user changes a file in the checkout during a review: the check cannot tell who changed it, so the point fails and the user decides.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The advisor tab MUST start Codex with the user's own Codex home and the user's normal sandbox and approval settings.
- **FR-002**: The Stratum Codex home, the `codex-home` setup command, its BLOCKED check and its `untrusted` project entry MUST be removed, with st-init, st-build, the README and the tests changed to match.
- **FR-003**: There MUST be at most one advisor tab per herdr workspace, named `st-codex-<workspace label>` and shared by every feature. The label is lowercased, every character outside `a-z0-9_-` becomes `-`, and it is cut so the name has at most 32 characters; a label with no letter or digit uses the lowercased workspace id. When that name is live in another workspace or folder, the point MUST run the review in the background and say so (D10).
- **FR-004**: The advisor scripts MUST never close the advisor tab.
- **FR-005**: When the model or effort differs from the values the tab started with, the point MUST keep the tab and print one line telling the user to close the tab to apply the new values.
- **FR-006**: Before it sends a review prompt, the script MUST check the tab's state; when the tab is working or blocked, it MUST NOT type into it and MUST run the review in the background, reporting `codex: headless (Codex tab in use)`.
- **FR-007**: Every advisor prompt MUST say that Codex reviews only and changes no file. The advisor section of the st-build skill MUST say the same, and that the user may use the tab for their own work.
- **FR-008**: Each review in the tab MUST record the project's changed and untracked files, with a hash of each, before and after the turn. Any difference MUST end the point BLOCKED with the changed files listed and nothing reverted.
- **FR-009**: When Codex stops on a prompt during a review, the script MUST keep waiting for the review's answer instead of failing or falling back to the background.
- **FR-010**: There MUST be a command the orchestrator uses to send an answer key to the advisor tab.
- **FR-011**: The st-build skill MUST tell the orchestrator to start watching the advisor tab as soon as it exists, to approve only reads and read-only commands, never a write, delete, git change, install, `.env` or secret, and to bring every other prompt to the user with the exact screen text.
- **FR-012**: A review in the tab MUST have no time limit. When the tab ends during a review (the user closes it or Codex exits), the point MUST end BLOCKED with that reason. Once a review has started in the tab, the point MUST NOT run it in the background (D11).

### Key Entities

- **Advisor tab**: the one `st-codex-<workspace label>` Codex agent in a workspace and folder. Attributes: the model and effort it started with.
- **Review snapshot**: the list of changed and untracked files and staged entries, with modes and hashes, taken before and after one review turn.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The user can hold a conversation in the advisor tab between two advisor points, and the tab and that conversation are still there after both points.
- **SC-002**: 100% of reviews that change a file end BLOCKED with the file named; 0 files are reverted by the advisor.
- **SC-003**: In the live run, one real prompt during a review, made by asking the review for something that needs approval (for example a command that needs the network), reaches the orchestrator through the watch and is handled by the rule: approved when on the allow list, else brought to the user with the exact text. The approve key path is covered by the stub tests (D12).
- **SC-004**: 0 advisor prompts are typed into the tab while the user's turn is running.
- **SC-005**: Each new guard in FR-004, FR-006, FR-008, FR-009, FR-010 and FR-002 has a test that goes red when the guard is broken.

## Assumptions

- The user's Codex trusts the projects they use (true today for this repo and v2-veent).
- With the user's normal settings, Codex reads files without asking, so a prompt during a review asks for more than reading.
- herdr reports an agent as idle, working or blocked, and cannot report unsent input.
- The orchestrator can watch the tab with a background monitor while the point runs.
- The exact Codex prompt text is unknown until the live run; the live run's prompt text is saved into the tests.
- Advisor mode `codex` at the end-of-Build diff point (handoff Q1) is out of scope.
