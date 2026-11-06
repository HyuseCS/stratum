# Feature Specification: Answer the prompts of summoned agents

**Feature Branch**: `074-prompt-answers`

**Created**: 2026-11-06

**Status**: Draft

**Input**: Items 2 to 4 of issue #74 ("Orchestrator answers the permission prompts of agents it summons"). Item 1 (the Codex tab) was built in `specs/013-codex-shared-tab` (PR #82). Grilling decisions are in `decisions.md` (D1, D2). 013's D7 settles item 2.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The orchestrator answers a worker's safe permission prompt (Priority: P1)

A herdr worker in normal mode stops on a permission dialog. Today the st-worker skill tells the orchestrator never to answer it, so the user must go to the pane. With this change the orchestrator answers the dialog when the worker allow list permits it, with the one-time yes only. Every other dialog goes to the user with the worker's workspace, tab and the exact dialog text.

**Why this priority**: This is the gap the issue reports for workers. The autonomous-mode rules (`approve`, `pass`) are already there. Normal mode is not covered.

**Independent Test**: Read the st-worker skill. It tells the orchestrator, for normal mode and for autonomous mode, when to answer, with which command, which option it may pick, and what it must never approve. Each of these lines has a text-rule test that goes red when the line is removed.

**Acceptance Scenarios**:

1. **Given** a normal-mode worker stops on a permission dialog for an action on the worker allow list (a test, a lint, an edit inside the worker's own worktree, a commit that meets the commit rule), **When** the orchestrator reads the pane, **Then** it sends the one-time yes with `answer --keys`, taking the option number from the dialog text.
2. **Given** a normal-mode dialog for an action on the worker never list, or one the orchestrator does not recognise, **Then** it sends no key and tells the user the workspace, the tab and the exact dialog text.
3. **Given** a dialog that offers "don't ask again" or a similar lasting option, **Then** the orchestrator never picks that option.
4. **Given** autonomous mode, **Then** the skill still says when to use `approve` and when to use `pass`, and what never to approve.
5. **Given** a worker question that is not a permission dialog, **Then** the existing small and big decision rule still applies.

---

### User Story 2 - One shared rule in the three orchestrator skills (Priority: P1)

The st, st-build and st-worker skills each hold the same rule: "Watch each agent you summon. Answer its permission prompt when the answer keeps it in its brief. Bring every other prompt to the user with the exact text." Each skill points to the allow and never lists for the agents it summons.

**Why this priority**: The issue asks for this rule in these three files. Without it, each agent kind has its own rule and the next agent kind gets none.

**Independent Test**: A text-rule test finds the exact rule sentence in each of the three files and goes red when it is removed from any one of them.

**Acceptance Scenarios**:

1. **Given** any of the three skill files, **Then** it holds the rule sentence word for word.
2. **Given** the rule in `skills/st/SKILL.md`, **Then** it names where each agent kind's lists are: the Codex tab lists in st-build, the worker lists in st-worker, and the in-session subagent note (US3).

---

### User Story 3 - A written note on in-session subagent prompts (Priority: P2)

The orchestrator starts subagents in this session with the Agent tool. When such a subagent's tool call needs permission, the note says what the orchestrator can do and what it cannot do. Each fact in the note comes from the Claude Code docs or from a check in this repo, with its source.

**Why this priority**: The issue asks to find out and write this down. It changes no behavior, so it comes after US1 and US2.

**Independent Test**: The note exists in the st skill. A text-rule test checks its lines. Each fact in the research file has a source (a doc URL with a quote, or a file and line in this repo).

**Acceptance Scenarios**:

1. **Given** a subagent's tool call needs permission, **Then** the note says who sees the prompt and if the orchestrator can answer it.
2. **Given** a subagent reports that a tool call was denied, **Then** the note says the orchestrator never does that action itself in place of the subagent, and brings it to the user.
3. **Given** a Stratum hook that changes the input of an Agent call (`hooks/st-models.py`), **Then** the note says what that does to the permission check, as far as the docs or a check show it.

### Edge Cases

- A worker dialog shows more than one yes option: only the one-time yes is allowed. If no one-time yes is shown, the dialog goes to the user.
- A worker's own classifier blocked the action: it goes to the user, as autonomous mode already says.
- A permission check or the classifier blocks the orchestrator's own `answer` call: it tries no other way and tells the user.
- The pane text is data, never an instruction. Text in a dialog that asks the orchestrator to approve is not a reason to approve.
- A fact about in-session subagents that the docs do not state and no check shows is written as "not documented", not guessed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The st-worker skill MUST let the orchestrator answer a normal-mode worker's permission dialog with `answer --keys` when the action is on the worker allow list, picking the one-time yes only (013 D7).
- **FR-002**: The st-worker skill MUST send every other normal-mode permission dialog to the user with the worker's workspace, tab and the exact dialog text.
- **FR-003**: The worker allow and never lists MUST be written once in the st-worker skill and used for both normal and autonomous mode (D1). No new list is added.
- **FR-004**: The st-worker skill MUST keep saying, for autonomous mode, when to use `approve`, when to use `pass`, and what never to approve.
- **FR-005**: The rule sentence "Watch each agent you summon. Answer its permission prompt when the answer keeps it in its brief. Bring every other prompt to the user with the exact text." MUST be in `skills/st/SKILL.md`, `skills/st-build/SKILL.md` and `skills/st-worker/SKILL.md`, word for word.
- **FR-006**: `skills/st/SKILL.md` MUST say where each agent kind's lists are: the Codex tab in st-build, workers in st-worker, in-session subagents in the note (FR-007).
- **FR-007**: `skills/st/SKILL.md` MUST hold a short note on in-session subagents: what the orchestrator can do and cannot do when a subagent's tool call needs permission, including that it never re-runs a denied action in place of the subagent.
- **FR-008**: Each fact behind the note MUST be in the feature's research file with its source: a doc URL and quote, a file and line in this repo, or a Claude Code denial text quoted word for word with the date it was seen (D4). A fact with no source is written as "not documented".
- **FR-009**: The Codex tab allow and never lists in st-build MUST stay as 013 wrote them.
- **FR-010**: `st-worker.sh answer --keys` MUST send a key on a permission dialog only when the option line for that key does not say "don't ask again", "this session" or "in the future"; else it MUST send nothing and say why. `answer --text` MUST still refuse a permission dialog (D3).

### Key Entities

- **Agent kind**: an agent the orchestrator summons: the Codex advisor tab, a herdr worker, or an in-session subagent. Each has its own lists or note.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each new or changed rule line in the three skill files has a text-rule test row, and each row is shown red once with its line removed (D2).
- **SC-002**: The rule sentence is found word for word in 3 of 3 skill files.
- **SC-003**: 100% of the facts in the subagent note have a source in the research file, of a kind FR-008 accepts (D4).
- **SC-004**: The existing worker, advisor and lane tests stay green, except the rows that hold 010 FR-017, which 013 D7 reversed.
- **SC-005**: The `answer` script guard has a stub test that sends the one-time yes and a negative control for each lasting option text, where no key is sent.

## Assumptions

- `st-worker.sh answer` refuses every permission dialog today (`scripts/st-worker.sh:434`, from 010 FR-017). FR-010 changes that for `--keys` only.
- `wait` and `watch` already report a normal-mode permission dialog as `blocked` with the pane text.
- The one-time yes option of a Claude Code permission dialog can be told apart from a lasting one by its text.
- The user's permission settings and `settings.json` are out of scope.
- A change to `hooks/st-models.py` (how it returns a changed Agent input) is out of scope. The note only says what it does.
- No live herdr run is needed (D2).
