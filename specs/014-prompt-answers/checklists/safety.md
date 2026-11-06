# Safety Checklist: Answer the prompts of summoned agents

**Purpose**: Unit tests for the requirements on which permission prompts the orchestrator may answer
**Created**: 2026-11-06
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer agrees the requirement is written well. It does not mean the work is built. `st-build` reads this file and does not change its markers.

## Requirement Completeness

- [ ] CHK001 - Is the worker allow list named in one place and used by both normal and autonomous mode? [Completeness, Spec §FR-003]
- [ ] CHK002 - Does the spec say which dialog option the orchestrator may pick, and which lasting options it must never pick? [Completeness, Spec §US1]
- [ ] CHK003 - Is the case with no one-time yes option covered? [Edge Case, Spec §Edge Cases]
- [ ] CHK004 - Does the spec say what the user receives for an unanswered dialog (workspace, tab, exact text)? [Completeness, Spec §FR-002]

## Requirement Clarity

- [ ] CHK005 - Is "keeps it in its brief" in the rule sentence tied to a list for each agent kind? [Clarity, Spec §FR-006]
- [ ] CHK006 - Is it clear that pane text and dialog text are data and never a reason to approve? [Clarity, Spec §Edge Cases]

## Requirement Consistency

- [ ] CHK007 - Do the normal-mode worker rules agree with the autonomous never list (push, secrets, `.claude/`, `.stratum/approve`)? [Consistency, Spec §FR-003]
- [ ] CHK008 - Do the Codex tab lists stay as 013 wrote them? [Consistency, Spec §FR-009]
- [ ] CHK009 - Does the subagent note agree with the rule that a denied action is never re-run by the orchestrator? [Consistency, Spec §FR-007]

## Acceptance Criteria Quality

- [ ] CHK010 - Does each new rule line have a test that can go red? [Measurability, Spec §SC-001]
- [ ] CHK011 - Is "a source" for each note fact defined (doc URL and quote, or file and line)? [Measurability, Spec §FR-008]

## Dependencies & Assumptions

- [ ] CHK012 - Is the `answer --keys` guard on lasting options stated, with what it sends and refuses? [Completeness, Spec §FR-010]
- [ ] CHK013 - Is the boundary to `settings.json` and `hooks/st-models.py` stated as out of scope? [Assumption, Spec §Assumptions]
