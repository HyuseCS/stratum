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
   For a fact a grill question or the plan needs, take a quick look first (a file or two, or a search). When it does not find the fact, run `/stratum:st-research` (Skill tool) in the background with the fact as its scope, and ask the next question that does not need the fact. When a report comes in, show a short summary of its findings before the next question. These rules replace the research rule of `st-grill`.
   When the grill needs `/stratum:st-research`, make the feature folder first: `specs/<NNN>-<short-name>`, with the next free number and the short-name rule of `<plugin root>/procedures/specify.md` steps 1 and 2, made with `mkdir -p`. Make it once per run and use it again for later research in the same run. Pass `feature <folder>`, not a path. Outside a redo, never use the feature in `.stratum/state.json` for it. In a redo (step 0.2), make no folder: pass `feature <feature_directory>` for the feature in `.stratum/state.json` that step 0.2 redoes.
   At most 3 research runs at a time: put a further scope in a queue and start it, first in, first out, when one ends. Start no scope whose questions are in the brief of research that runs, waits in the queue, or is done.
   From the time the folder exists, the grill writes its decisions to `<folder>/decisions.md`.
   If the grill ran research (in a redo, `<folder>` is the `<feature_directory>` that step 0.2 redoes): when the grill ends, before step 2, wait for all research that runs and show each finding that changes a grill answer or the scope. Do not start the queue: under `## Queued research` at the end of `<folder>/decisions.md`, write one line `- <short-name>: <scope and questions>` for each queued scope and each research that stopped or failed, with a short name of 2 to 4 lowercase words joined by hyphens that no file in `<folder>/research/` and no other queue line uses. Then read `<folder>/decisions.md` and show the user every line in it that this Define run did not write.
2. **Specify.** Follow `<plugin root>/procedures/specify.md`. Input: the description plus a short
   summary of the grilling answers. It creates `specs/NNN-short-name/spec.md` and the
   `checklists/requirements.md` quality checklist.
   If step 1 made a feature folder, put its path in the input.
   The Stratum hook records the new folder as `feature_directory` in `.stratum/state.json`.
3. **Clarify, only if gaps remain.** If the spec still has `[NEEDS CLARIFICATION]` markers or
   failing items in `checklists/requirements.md`, follow `<plugin root>/procedures/clarify.md`.
   Otherwise skip it and say so in one line.
4. **Checklist.** Follow `<plugin root>/procedures/checklist.md`. Input: the feature's highest
   impact areas (for example privacy, access, offline, screens).

## Gate: user agrees the spec

Show the spec in short form: user stories with priority, the FRs, success criteria, and open
assumptions. Name research that stopped or failed, and the queued scopes for Plan. Ask: "Do you agree the spec?" Edit and ask again until they say yes. Do not start
`/stratum:st-plan` before that.

On yes: have `st-git` commit the spec files with exact paths.

## Always

- Never skip the commit guard. If a commit is blocked, tell the user; do not work around it.
- Push only when the user says "push".
