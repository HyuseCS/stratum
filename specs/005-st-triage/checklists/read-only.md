# Requirements Checklist: Read-only and GitHub Access

**Purpose**: Check that the spec says enough about the read-only rule and the GitHub side
**Created**: 2026-10-22
**Feature**: [spec.md](../spec.md)

## Read-only

- [ ] Does the spec name every side effect the command must not have (repo files, issue body, comments, labels, state)? [FR-004]
- [ ] Does the spec say how a side effect is noticed and reported when it happens anyway? [Edge Cases, SC-003]
- [ ] Does the spec say which tools the research agent may not have, in a way a test can check? [FR-008, SC-004]

## GitHub access

- [ ] Does the spec say what is read from the issue (title, body, comments, state) and what is not (web pages)? [FR-001, Assumptions]
- [ ] Does the spec say what happens when the GitHub tool is missing, not signed in, or the issue number is wrong? [FR-007, Edge Cases]
- [ ] Does the spec bound which links are followed (same repo only)? [Assumptions]

## Report

- [ ] Is each of the four report parts defined with a closed set of values where one exists (verdict, next step)? [FR-003]
- [ ] Does the spec say what a claim with no evidence looks like in the report ("unchecked")? [FR-002, SC-002]
- [ ] Does the spec say in which order several reports arrive? [FR-005]

## Notes

- Items are reviewer-owned. `[x]` means the requirement is written well enough, not that it is built.
