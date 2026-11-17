# Feature Specification: background research during the Define grill

**Feature Branch**: `stratum-111`

**Created**: 2026-11-17

**Status**: Draft

**Input**: User description: "Issue #111: during the grill in Define, run `st-research` in the background, several agents at once, so Plan starts with the facts. Grill decisions D6–D10 in `decisions.md`."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Research runs while the grill goes on (Priority: P1)

During the grill in Define, the orchestrator sees a fact that a grill question or the plan
will need. It first takes a quick look (a file or two). When the quick look does not find the
fact, it starts `st-research` in the background at once, shows the brief in one line, and asks
the next grill question. It does not wait for an OK and does not wait for the agent. When the
agent's report comes in, the orchestrator shows a short summary before its next question.

**Why this priority**: This is the gap in #111. Today research during the grill blocks the
grill (an OK prompt, then a wait), and facts that only the plan needs are found after the spec
gate, so Plan takes longer than it must.

**Independent Test**: Run Define on a task whose grill has one fact the quick look cannot
find. Check that the research starts with no OK prompt, that the next grill question comes
before the research ends, and that the summary shows before the question after the report.

**Acceptance Scenarios**:

1. **Given** a grill in Define and a fact a quick look cannot find, **When** the orchestrator sees it, **Then** it starts `st-research` in the background with no OK prompt and shows the brief in one line.
2. **Given** research that runs, **When** the orchestrator has a grill question that does not depend on that fact, **Then** it asks that question at once.
3. **Given** a fact that only the plan needs (no grill question needs it), **When** the quick look cannot find it, **Then** the orchestrator still starts research for it.
4. **Given** a fact a quick look finds, **When** the orchestrator sees it, **Then** it starts no research.
5. **Given** a research report that comes in, **When** the orchestrator writes its next message, **Then** it shows a short summary of the findings before the next question.

---

### User Story 2 - Several research agents at once, each with its own file (Priority: P1)

When the grill has more than one independent fact to find, the orchestrator starts one
`st-research` agent for each scope, up to 3 at a time. Each agent writes its own file,
`<folder>/research/<short-name>.md`, with a short name no other file in `<folder>/research/` uses.
The orchestrator never starts the same scope twice. A fourth scope waits in a queue and starts
when one of the 3 agents ends.

**Why this priority**: One agent at a time is too slow when the user answers fast. One shared
file breaks when two agents write at once.

**Independent Test**: Run Define on a task whose grill has two independent facts the quick
look cannot find. Check that two agents run at the same time, that two files exist in
`<folder>/research/`, and that each file holds only its own scope.

**Acceptance Scenarios**:

1. **Given** two independent scopes, **When** the orchestrator starts research, **Then** two agents run at the same time and each writes its own file.
2. **Given** 3 agents that run, **When** a fourth scope comes up, **Then** it waits in the queue and starts when one agent ends.
3. **Given** a scope that runs or is done, **When** the same scope comes up again, **Then** the orchestrator starts no second agent for it.
4. **Given** a short name that a file in `<folder>/research/` already uses, **When** a new scope starts, **Then** the orchestrator picks another short name.

---

### User Story 3 - The safety check stays real with agents in parallel (Priority: P1)

Each research run takes a git snapshot before and after. While several agents run and the
grill writes `decisions.md`, the check ignores `.stratum/state.json`, `<folder>/decisions.md` and
`<folder>/research/*.md`. Any other change, all of `specs/`, the rest of `.stratum/` and the
code included, is a finding that the orchestrator shows to the user.

**Why this priority**: Without this, each agent sees the other agents' files and the
grill's `decisions.md` as changes, so every run shows false findings and the check gets
ignored.

**Independent Test**: Take the snapshot, write a file in `<folder>/research/`, change
`<folder>/decisions.md` and `.stratum/state.json`, and take the snapshot again: no finding.
Then change a file in the code, `spec.md` of any feature, or write a file in `.stratum/autonomous/`: a finding.

**Acceptance Scenarios**:

1. **Given** another agent writes its research file, **When** the check runs, **Then** it shows no finding for that file.
2. **Given** the grill writes `<folder>/decisions.md` and a hook changes `.stratum/state.json`, **When** the check runs, **Then** it shows no finding for those files.
3. **Given** a code file or any file in `specs/` outside those two paths changes, **When** the check runs, **Then** it shows a finding.
4. **Given** a file in `.stratum/` other than `state.json` changes (for example `.stratum/autonomous/<session>` or `.stratum/constitution.md`), **When** the check runs, **Then** it shows a finding.

---

### User Story 4 - Define waits at the end of the grill, and Plan uses the files (Priority: P2)

At the end of the grill, before Specify writes any file, Define waits for every research agent
that runs. It shows each finding that changes a grill answer or the scope, so the spec is written with it. The gate
names research that stopped or failed, and the queued scopes it hands to Plan. Scopes still in the
queue do not start: Define writes them under `## Queued research` in `decisions.md` for Plan. Plan runs those scopes through
`/stratum:st-research` into `<folder>/research/` before the `st-plan` agent starts. The
`st-plan` agent reads every file in `<folder>/research/` and does not research those questions
again. It writes `research.md` as its own file: a `Sources` list that points to each research
file, then its decisions. The facts stay only in the research files.

**Why this priority**: The research is only worth it when Plan uses it and does not repeat it.

**Independent Test**: Put two research files in `<folder>/research/` and one queued scope in
the hand-off, and run Plan. Check that the queued scope gets its own research file before the
`st-plan` agent starts, that `research.md` lists all three files under `Sources`, and that it
copies no fact from them.

**Acceptance Scenarios**:

1. **Given** research that still runs at the end of the grill, **When** the grill ends, **Then** Define waits for it before Specify writes any file, and shows each finding that changes a grill answer or the scope.
2. **Given** research that stopped or failed, **When** the gate shows, **Then** it names that research.
3. **Given** scopes in the queue at the end of the grill, **When** the grill ends, **Then** they do not start, Define writes them for Plan, and the gate names them.
4. **Given** queued scopes from Define, **When** Plan starts, **Then** it runs them through `/stratum:st-research` into `<folder>/research/` before the `st-plan` agent starts.
5. **Given** files in `<folder>/research/`, **When** the `st-plan` agent runs, **Then** `research.md` has a `Sources` list that names each file, and the agent researches no question those files answer.
6. **Given** an older feature whose `research.md` has the line `Written by: st-research`, **When** Plan runs on it, **Then** it works as it does today.
7. **Given** a line in `<folder>/decisions.md` that this Define run did not write (for example one a research agent added), **When** the grill ends, **Then** Define shows that line to the user before Specify writes any file.

---

### Edge Cases

- The grill ends with no research: Define reaches the gate with no wait, and Plan works as it does today, with no `research/` folder.
- An agent reports `Stopped:` or fails: the gate names it, and its questions go to Plan like a queued scope.
- The user runs `/stratum:st-grill` alone (not in Define): today's rule stays: research only when a question needs a fact a quick look cannot find, with the OK step.
- A redo of Define (`st-define` step 0.2): the research files go to `<feature_directory>/research/` of the feature being redone, not to a new folder.
- `.stratum/state.json` still names an older feature during the grill: no research file goes to the older feature's folder.
- The user runs `/stratum:st-research` by hand with a feature folder: the file goes to `<feature folder>/research/<short-name>.md`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: During the grill in Define, the orchestrator MUST first take a quick look for a fact a grill question or the plan needs, and MUST start `st-research` only when the quick look does not find it.
- **FR-002**: Research that the grill in Define starts MUST run in the background. The orchestrator MUST ask the next grill question that does not depend on it, with no wait.
- **FR-003**: Research that the grill in Define starts MUST need no OK. The orchestrator MUST show its brief in one line.
- **FR-004**: At most 3 research agents from the grill MUST run at a time. A further scope MUST wait in a queue and start when one agent ends, first in, first out.
- **FR-005**: The orchestrator MUST NOT start the same scope twice in one Define run. A scope is the same when research that runs, waits in the queue, or is done already has its questions in its brief.
- **FR-006**: Every research file for a feature MUST go to `<folder>/research/<short-name>.md`, with a short name the skill picks itself that no other file in that folder, no queue line in `<folder>/decisions.md` and no research that runs uses. This holds for the grill, for Plan's own research, and for a hand run of `/stratum:st-research` that names a feature folder.
- **FR-007**: The before and after git check of a research run MUST ignore `.stratum/state.json`, `<folder>/decisions.md` and `<folder>/research/*.md`, where `<folder>` is the feature folder this run writes to (the new one, or the one being redone), or `.stratum` when the run has no feature folder. It MUST show every other change as a finding, all of `specs/` and the rest of `.stratum/` included.
- **FR-008**: When a research report comes in during the grill, the orchestrator MUST show a short summary of its findings before its next question.
- **FR-009**: When the grill ran research, at the end of the grill, before Specify writes any file, Define MUST wait for every research agent that runs and show each finding that changes a grill answer or the scope. The gate MUST name any research that stopped or failed, and the queued scopes handed to Plan. Before Specify writes, Define MUST show the user every line of `<folder>/decisions.md` that this Define run did not write.
- **FR-010**: Scopes still in the queue at the end of the grill MUST NOT start. Define MUST write them, and the questions of research that stopped or failed, under a `## Queued research` heading at the end of `<folder>/decisions.md`, so they reach Plan in a later session too. Each queue line's short name MUST be 2 to 4 lowercase words joined by hyphens.
- **FR-011**: Plan MUST run the scopes under `## Queued research` in `<folder>/decisions.md` through `/stratum:st-research` into `<folder>/research/` before the `st-plan` agent starts. Plan MUST show each queue line to the user before it runs it, and MUST skip a line whose short name is not 2 to 4 lowercase words joined by hyphens. Plan MUST run the queue before its own research, and its own research MUST cover only what the files in `<folder>/research/` do not answer.
- **FR-012**: The `st-plan` agent MUST read every file in `<folder>/research/`, MUST NOT research again a question those files answer, and MUST write `research.md` with a `Sources` list that names each research file, then its decisions. It MUST NOT copy their facts into `research.md`.
- **FR-013**: For a feature with no `<folder>/research/` folder whose `research.md` has the line `Written by: st-research`, Plan MUST work as it does today. When both exist, the `<folder>/research/` rule (FR-012) applies, and `Sources` also names the old `research.md` rounds, which Plan keeps as they are.
- **FR-014**: These rules MUST apply only to the grill inside Define. `/stratum:st-grill` run alone MUST keep today's rule, with the OK step.
- **FR-015**: `tests/test_research.sh` MUST check the parallel paths, the cap and queue, the git check ignore list, and the hand-off to Plan. Each new check MUST have a negative control: a broken copy that makes it fail.
- **FR-016**: The existing checks for the rules this feature replaces (in `tests/test_research.sh`, the research path, the Define research path and the Plan research rule) MUST change in the same change to check the new rules. All other existing tests MUST pass with no change, the harness model drift test included.

### Key Entities

- **Research file**: one Markdown file per scope, `<folder>/research/<short-name>.md`, written by one `st-research` agent. Its rounds and sections are as today.
- **Research queue**: the scopes the orchestrator found while 3 agents ran. It lives in the orchestrator's context during the grill. At the end of the grill, what is left goes under `## Queued research` in `<folder>/decisions.md` for Plan.
- **`research.md`**: Plan's own file. A `Sources` list of the research files, then Plan's decisions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a grill with two independent facts the quick look cannot find, two research agents run at the same time and two research files exist after, each with only its own scope.
- **SC-002**: While research runs, the grill asks its next question with no wait and no OK prompt.
- **SC-003**: At most 3 research agents from one grill run at the same time.
- **SC-004**: In a grill where agents run in parallel and `decisions.md` changes, the git check shows zero false findings. A change to a code file, a spec file or a `.stratum/` file outside the ignore list shows as a finding every time.
- **SC-005**: Plan researches zero questions that the research files already answer, and `research.md` names every research file.
- **SC-006**: Every new check in `tests/test_research.sh` fails on its negative control, and all other existing tests pass with no change.

## Assumptions

- The Agent tool runs subagents in the background and tells the orchestrator when each ends, so the grill can go on while research runs.
- Research is read-only and writes only its own file, so skipping the OK for grill research is safe (#111 proposal 3).
- If the session ends during the grill, before the gate, the queue is lost. The next Define or Plan finds those facts again.
- The live checks (two agents at once, the next question with no wait) are run by hand in a real session. Shell tests check the text of the rules.
- This feature replaces the research path rules of `specs/016-st-research/spec.md` FR-004, FR-013 and FR-015: a feature's research goes to `<folder>/research/<short-name>.md`, not `<folder>/research.md`.
- "Quick look" means the orchestrator reads a file or two or runs a search itself, as in #80.
