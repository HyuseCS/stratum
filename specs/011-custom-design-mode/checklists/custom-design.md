# Requirements Checklist: Custom Design Mode

**Purpose**: Check that the spec says enough about the mode's entry, the FigCraft round trip, the stops, the limits and the tools
**Created**: 2026-11-01
**Feature**: [spec.md](../spec.md)

## Entry and mode pick

- [ ] CHK001 Is the rule that picks the custom mode a closed list of signals, and does it say which wins over the new-look and autonomous rules? [FR-002, FR-004]
- [ ] CHK002 Does the spec say how `/stratum:st` tells a custom-design task on an existing screen from a Fast or Quick screen fix? [FR-002, US2]
- [ ] CHK003 Is the `[screen: custom]` tag defined with the same wording Plan writes and the lane reads? [FR-001, FR-003]

## First design

- [ ] CHK004 Is "a task that asks for a new look or an overhaul" defined well enough to decide the theme pick? [FR-004, US1 scenario 3]
- [ ] CHK005 Does the spec say what the first design holds for a new screen: which frames, at which sizes, and which parts of the grill answers it shows? [FR-006, US1]
- [ ] CHK006 For an existing screen, does the spec say what "drawn from its code and a screenshot" must match, and what may differ? [FR-006, US2 scenario 2]

## The FigCraft stop

- [ ] CHK007 Is "a reply that says the design is good" defined well enough to tell it from a question or a change request? [FR-008]
- [ ] CHK008 Does the spec say what the agent may and may not change during the stop without the user asking? [FR-008]
- [ ] CHK009 Are the edge cases for a closed window, a busy port and a failed draw call each given one defined result? [Edge Cases]

## Read-back and build

- [ ] CHK010 Does the spec say which parts of the saved design the build must follow exactly (layout, sizes, colors, text) and which it may adapt to code? [FR-010, SC-001]
- [ ] CHK011 Does the spec say how the design file is written when the saved design's variables differ from the existing design file? [FR-009, D16]
- [ ] CHK012 Is the page name in `design/app.figcraft` defined, so two screens never share or overwrite one page? [FR-009, Key Entities]

## Gate changes

- [ ] CHK013 Is "small code-only fix" a closed list, so the default for an unnamed change is decidable? [FR-013, US3]
- [ ] CHK014 After a change made in code, does the spec say how the saved design and the code stay the same, or that they may differ? [FR-013, D13]

## Limits and privacy

- [ ] CHK015 Are the read and write folders named exactly, and does the spec say what happens to a call outside them? [FR-007, SC-005]
- [ ] CHK016 Does the spec say that no design leaves the machine, and is that measurable? [FR-007, SC-005]

## Tools and setup

- [ ] CHK017 Does the spec say which FigCraft version or newer the mode needs, and what the check does with an older one? [FR-016, Assumptions]
- [ ] CHK018 Does the spec say what the MCP config does in a project or machine with no FigCraft installed? [FR-015, FR-016]
- [ ] CHK019 Is the `st-init` offer's result on "no" defined? [FR-017, US4]
- [ ] CHK020 Does each Assumption that the plan must test name what happens if the test fails? [Assumptions]
