---
name: st-define
description: Full-lane Define phase. Grill the user, write the feature spec, clarify gaps, run the checklist, and stop at the gate "user agrees the spec".
---

# /stratum:st-define <feature description>

You are the orchestrator and you run this phase yourself: grilling needs the user.
Plugin root (`<plugin root>`) is two levels up from this skill's base directory. Use absolute paths.
In every procedure file, `<PLUGIN_ROOT>` means this plugin root.

## 0. Start

1. If `<project>/.stratum/` does not exist, stop and tell the user to run `/stratum:st-init`.
2. Read `<project>/.stratum/state.json` if it exists. Define starts a feature, so it is never out
   of order. If no description is given and state.json names a feature, redo Define on that
   feature: skip step 2 of "Steps" and revise its existing `spec.md`.
3. If `lane` is not set, it is `full`.

## Steps

1. **Grill.** Run the `st-grill` skill on the description. One question at a time, each with
   your recommended answer. Stop when scope, users, data, privacy, and done-criteria are clear.
2. **Specify.** Follow `<plugin root>/procedures/specify.md`. Input: the description plus a short
   summary of the grilling answers. It creates `specs/NNN-short-name/spec.md`, the
   `checklists/requirements.md` quality checklist, and writes `.stratum/state.json` with
   `phase: define`.
3. **Clarify, only if gaps remain.** If the spec still has `[NEEDS CLARIFICATION]` markers or
   failing items in `checklists/requirements.md`, follow `<plugin root>/procedures/clarify.md`.
   Otherwise skip it and say so in one line.
4. **Checklist.** Follow `<plugin root>/procedures/checklist.md`. Input: the feature's highest
   impact areas (for example privacy, access, offline, screens).

## Gate: user agrees the spec

Show the spec in short form: user stories with priority, the FRs, success criteria, and open
assumptions. Ask: "Do you agree the spec?" Edit and ask again until they say yes. Do not start
`/stratum:st-plan` before that.

On yes: set `phase` to `define` in state.json (keep the other keys), then have `st-git` commit
the spec files with exact paths.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
