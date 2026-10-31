# Requirements Checklist: Workflow Overhaul

**Purpose**: Check that the spec says enough about approvals, advisor runs, tests and parallel work
**Created**: 2026-10-31
**Feature**: [spec.md](../spec.md)

## Approvals (safety)

- [ ] Is "small and safe" a closed list, and is everything outside it sent to the user? [FR-019, US4]
- [ ] Is the never-approve list closed, and does it win over "small and safe"? [FR-019]
- [ ] Does the spec say what happens when the hook gets no answer or the classifier blocks? [FR-019, Edge Cases]
- [ ] Does the spec say where the approval record lives and that it is not committed? [Key Entities, Assumptions]
- [ ] Are the words that turn autonomous mode on and off stated, and is its end defined? [FR-018]

## Advisor runs

- [ ] Is "the plan's approach changed" defined well enough to tell a fix from a new approach? [Ambiguity, FR-001, FR-002]
- [ ] Is the matrix closed for every point and risk level, including Low and None? [FR-012, D15]
- [ ] Is the talk bounded, and is the result for an open point defined? [FR-014]
- [ ] Does the spec say what a High point does when one advisor is not available? [Edge Cases]
- [ ] Is the Codex agent's life defined: start, one per workspace, new conversation per feature, closed tab? [FR-013, Edge Cases]

## Tests and lock

- [ ] Is the "ask the user" trigger for test scope a closed list with a number? [FR-007]
- [ ] Is the lock's time limit stated, and what a timed-out run reports? [FR-009]
- [ ] Does the spec say how a lock left by a crashed run is freed? [FR-009, Edge Cases]

## Git guard

- [ ] Does each of the four unreadable-command cases have a stated decision? [FR-008, US2]
- [ ] Is the safe side stated for `git` inside text that is not a command? [Edge Cases]

## Parallel work and lanes

- [ ] Is file ownership per `[P]` task stated, with no overlap for tasks that run together? [FR-026]
- [ ] Is "new screen" defined so the planner can mark it, with examples of what is not one? [FR-023, US5]
- [ ] Does the spec say what Build does while a new screen waits for the user? [FR-024, FR-025]

## Scope

- [ ] Are the parts of #51, #48 and #55 left out of this feature named? [Assumptions]
- [ ] Does every FR have a named test? [FR-031]
