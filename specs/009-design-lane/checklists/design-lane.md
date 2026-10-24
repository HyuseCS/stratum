# Requirements Checklist: Design Lane

**Purpose**: Check that the spec says enough about the design file, the two modes, the checks, the scope line and the tools
**Created**: 2026-10-24
**Feature**: [spec.md](../spec.md)

## Design file

- [ ] Does the spec say who shapes the design file, by which method, and that nothing is built before the user confirms it? [FR-003, FR-004]
- [ ] Is the list of first grill branches closed, per mode? [FR-003]
- [ ] Does the spec say what the lane does with a look in the code but no file? [FR-005, US3]
- [ ] Does the spec say what happens when the user wants to change an existing design file? [Edge Cases, Assumptions]

## Modes and gates

- [ ] Is the number of gates in each mode stated, and where each one sits? [FR-006, FR-007, US1, US2]
- [ ] Is "vague request" defined by items that can be checked, and is the number of question messages bounded? [FR-007, SC-003]
- [ ] Does the spec say what the user can answer at the new-look gate and what each answer does? [US1 scenario 3]

## Checks

- [ ] Does each check own exactly one concern, and are the skipped duplicates named? [FR-008]
- [ ] Are fix rounds bounded, and is the result after the last round defined? [FR-008, Edge Cases]
- [ ] Is the report content a closed list? [FR-009]
- [ ] Does the spec say how UI behavior is tested, and what happens with no UI test runner? [FR-013]

## Scope line

- [ ] Is the line between the lane and Fast or Full a closed list on both sides? [FR-011, FR-012]
- [ ] Does the spec say what stands in for real data? [FR-012]
- [ ] Does the spec say which cases this feature does not route to the lane? [Edge Cases, D10]

## Tools, vendoring and privacy

- [ ] Are the required tools a closed list, and is the behavior when one is missing defined? [FR-015, SC-005]
- [ ] Does the spec say what data may leave the machine (image generation, photos) and when? [FR-016, Assumptions]
- [ ] Does the spec say how hallmark is pinned, synced and kept apart from local edits? [FR-017, FR-018]
- [ ] Does the spec keep the new-look engine swappable in one place? [FR-010]
