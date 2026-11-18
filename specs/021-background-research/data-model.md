# Data model: background research during the Define grill

## Research file

- Path: `<folder>/research/<short-name>.md`. `<folder>` is the feature folder (the new one, or the one being redone). With no feature folder: `.stratum/research/<short-name>.md`. A path the caller gives wins.
- Short name: 2 to 4 lowercase words joined by hyphens. In a feature folder, a short name the skill picks itself is one that no file in `<folder>/research/`, no queue line in `<folder>/decisions.md` and no research that runs uses. In `.stratum/research/`, a name may repeat, and the run adds a round.
- Content: as today (`procedures/research.md`): `# Research: <topic>`, `Written by: st-research`, `## Round <n>` with Scope, Key facts, optional Drift, open questions, Commands.
- Writer: one `st-research` agent. No other file changes.

## Research run (orchestrator context, Define grill only)

- Fields: scope, questions, short name, state.
- States: `queued` -> `running` -> `done` | `stopped` | `failed`.
- Rules: at most 3 `running`. A `queued` run starts, first in, first out, when one ends. A scope whose questions are already in the brief of a `running`, `queued` or `done` run is not added.
- At the end of the grill, when the grill ran research: wait for every `running` run. `queued`, `stopped` and `failed` runs go to `## Queued research`.

## `## Queued research` (in `<folder>/decisions.md`)

- Place: a heading at the end of `<folder>/decisions.md`.
- Line: `- <short-name>: <scope and questions>`, one per scope. The short name is 2 to 4 lowercase words joined by hyphens, used by no file in `<folder>/research/` and no other queue line.
- Reader: `skills/st-plan/SKILL.md` step 0.3 shows the user each line in this form (not a `- D13 (Q12): ...` decision line), then runs each one whose short name is 2 to 4 lowercase words joined by hyphens and whose `<folder>/research/<short-name>.md` does not exist, with `path <folder>/research/<short-name>.md`. It runs before Plan's own research (step 0.2), which then covers only what the files in `<folder>/research/` do not answer.

## `research.md` (Plan's own file)

- With files in `research/`: `## Sources` (one line per research file), then Decision/Rationale/Alternatives items. No fact copied from a research file.
- With an old `research.md` that has `Written by: st-research` and no `research/`: as today, rounds kept, `## Decisions` at the end.
- With both: rounds kept, then `## Sources` (research files and this file's rounds), then `## Decisions`.
- With neither: steps 1 to 3 of `procedures/plan.md`.

## Git check ignore list

- Ignored: `.stratum/state.json`, `<folder>/decisions.md`, `<folder>/research/*.md` (one level, `.md` only). With no feature folder, `<folder>` is `.stratum`.
- Seen: every other path, all of `specs/` and the rest of `.stratum/` (`autonomous/`, `constitution.md`, `templates/`) included, `research/sub/*.md` and non-`.md` files in `research/` included. Git-ignored files are not seen, as today.
