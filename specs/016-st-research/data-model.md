# Data Model: st-research

No database. Two entities, both plain text.

## Research brief

What `/stratum:st-research` passes to the `st-research` agent. Not stored.

| Field | Rule |
|-------|------|
| Plugin root, project root | Absolute paths |
| Scope | One or two lines |
| Questions | Numbered `Q1`, `Q2`..., at least one. A "which is better" question is kept, and the agent answers it with facts on each side (FR-003) |
| Output path | FR-004 order: the caller's path; else `<feature folder>/research.md` when the caller names a feature folder; else `.stratum/research/<short-name>.md`. Never from `.stratum/state.json`. Must resolve inside the project root (FR-005, research R4) |
| Short name | 2 to 4 lowercase words joined by hyphens, the same rule as `procedures/specify.md` step 1 |
| Plan file | A path, or none. Only with a plan file does the round get a drift section |
| Builds and tests | `no` unless the caller said so (FR-008) |

## Research file

One Markdown file per topic. In a feature it is `<feature folder>/research.md`, the same file
Plan uses (D3).

```text
# Research: <topic>
Written by: st-research

## Round 1
### Scope
### Key facts
#### Q1. <question>
### Drift against <plan file>      (only when a plan file is given)
### Open questions
### Commands

## Round 2                         (a later run, FR-007)
...

## Decisions                       (added by Plan, FR-013)
```

| Rule | Source |
|------|--------|
| Line 2 is `Written by: st-research`. Plan uses it to know the file | research R5 |
| A code fact cites `file:line` or a commit sha. A web fact cites `(<url>, read YYYY-MM-DD)` | FR-003, FR-009 |
| A web fact that does not agree with the installed version starts `Conflict:` and cites both | FR-009 |
| An unanswered question says `Not found.` and where the agent looked, and goes to open questions | Edge cases |
| Each open question starts `[user]` or `[planner]` | FR-006 |
| Commands lists every command the agent ran | FR-006 |
| A new round is `## Round <n>`, n = number of `## Round` headings + 1, added at the end. Earlier rounds never change | FR-007, D8 |
| Plan adds `## Decisions` with Decision/Rationale/Alternatives items, and keeps every round | FR-013, D4 |

State: new file (Round 1) -> more rounds -> rounds plus `## Decisions`. Nothing deletes a round.
