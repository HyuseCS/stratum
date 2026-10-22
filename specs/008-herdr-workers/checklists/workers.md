# Requirements Checklist: Workers, Questions and Cleanup

**Purpose**: Check that the spec says enough about the worker's life, the question path, the team and what is left
**Created**: 2026-10-23
**Feature**: [spec.md](../spec.md)

## Worker life

- [ ] Does the spec define the one prompt a worker gets and what its condition must contain? [FR-003]
- [ ] Does the spec bound the wait and say what happens when the worker never settles? [FR-004, Edge Cases]
- [ ] Does the spec say where the result lives and that the pane text is never the result? [FR-005]
- [ ] Does the spec say how a worker is found again after the orchestrator session ends? [FR-016, Edge Cases]

## Questions

- [ ] Does the spec say how a question is detected, relayed, and answered, and what happens if the user answered in the pane? [FR-006]
- [ ] Does the spec treat a permission prompt the same as a question? [US2 scenario 4, Edge Cases]
- [ ] Does the spec say headless workers never ask and what their reply holds instead? [FR-011, US5 scenario 2]

## Team

- [ ] Is the roster content defined as a closed list of fields? [FR-002, Key Entities]
- [ ] Are the team rules a closed list, with the message path per machine? [FR-008]
- [ ] Does the spec say who merges, in what order, and what happens on a conflict? [FR-009]

## Cleanup and privacy

- [ ] Does the spec say exactly what stays after close and what must not? [FR-010, FR-012, SC-005]
- [ ] Does the spec say which permissions a worker gets and does not get? [FR-013]
- [ ] Does the spec say what crosses to the other machine (brief, result) and over which channel? [FR-007]

## Notes

- Items are reviewer-owned. `[x]` means the requirement is written well enough, not that it is built.
