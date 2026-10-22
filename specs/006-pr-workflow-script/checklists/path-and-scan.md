# Requirements Checklist: Path Choice and Publish Scan

**Purpose**: Check that the spec says enough about when the workflow runs, what it may cost, and the secrets scan
**Created**: 2026-10-23
**Feature**: [spec.md](../spec.md)

## Path choice

- [ ] Are both thresholds given as exact numbers with the comparison ("more than") and the range they count? [Clarity, FR-002]
- [ ] Is "Ultracode is on" defined by a signal the skill can observe, not a feeling? [Clarity, FR-002, Assumptions]
- [ ] Does the spec say what the current path is when either condition fails, and that it does not change? [Completeness, FR-003, SC-002]
- [ ] Is the one-line path message defined with the facts it must carry? [Clarity, FR-004]
- [ ] Is the boundary case (exactly 30, exactly 40) settled? [Edge Case, US2 scenario 3]

## Cost and scale

- [ ] Is the agent budget stated as a number with its parts, so a reviewer can count? [Measurability, FR-011]
- [ ] Does the spec say who authorizes the scale above the session guideline? [Assumption, D2]
- [ ] Are model and effort overrides settled (none)? [Clarity, FR-011]

## Publish scan

- [ ] Does the spec define what the scan covers ("everything the push publishes") in terms a reader can list? [Clarity, FR-005]
- [ ] Is "blocking find" bounded (secrets and personal data) and its effect named at both levels, script and session? [Completeness, FR-006, SC-003]
- [ ] Does the spec say what reaches the user on a blocking find, and that nothing is pushed? [Completeness, US1 scenario 4]

## Failure and result

- [ ] Is the result contract listed field by field? [Completeness, FR-010]
- [ ] Does the spec say what happens when a facts agent dies, and when the draft agent dies? [Edge Cases, Gap]
- [ ] Is a false refuter problem handled and visible? [Edge Cases, FR-009]
- [ ] Does the spec say which parts of st-pr must not change (gate, push, create)? [Consistency, FR-010]

## Tests

- [ ] Does the spec name the control-flow facts a test must guard, so a change to each goes red? [Measurability, FR-012, SC-004]
- [ ] Does the spec name the skill text facts a grep must find? [Measurability, FR-013]
- [ ] Are the two manual demos marked as manual, with their expected result? [Coverage, US1, US2, SC-001, SC-002]

## Notes

- Items are reviewer-owned. `[x]` means the requirement is written well enough, not that it is built.
