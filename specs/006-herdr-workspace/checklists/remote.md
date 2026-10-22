# Requirements Checklist: Remote Machine and Layout

**Purpose**: Check that the spec says enough about the remote target, the pre-checks and the layout
**Created**: 2026-10-23
**Feature**: [spec.md](../spec.md)

## Remote target

- [ ] Does the spec say how a machine is named in a request (label or id) and what happens for an unknown one? [FR-004, US2 scenario 4]
- [ ] Does the spec say which checks run on the remote machine and which on this one (folder, git state)? [FR-006, FR-007]
- [ ] Does the spec forbid local ids, the current pane and environment ids for a remote target in a way a test can check? [FR-005, FR-014]
- [ ] Does the spec say what the run must never do to herdr (TUI, reconnect, machine add or remove, server stop, close)? [FR-011]

## Pre-checks and failure

- [ ] Does the spec say for each pre-check failure that nothing is made and one line names the cause? [FR-006, SC-004]
- [ ] Does the spec say what happens when a step fails after the workspace exists (keep, report, close nothing)? [Edge Cases]
- [ ] Does the spec bound the wait for `claude` and `lazygit` and say what the report shows when they are not seen? [FR-010, Edge Cases]

## Layout

- [ ] Is each template defined as a closed list of tabs, panes and programs? [FR-002]
- [ ] Does the spec say the folder is given on every tab and split, not only on the workspace? [FR-003]
- [ ] Does the spec say where the layout lives and that the user's keybinding script can drift? [FR-013]
- [ ] Is the label rule complete for both cases (issue or task known, none known)? [FR-009]

## Notes

- Items are reviewer-owned. `[x]` means the requirement is written well enough, not that it is built.
