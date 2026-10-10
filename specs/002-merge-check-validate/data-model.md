# Data Model: Merge Check and Validate into Inspect

No stored data changes shape. The entities are plugin files and one state value.

## Inspect agent (`agents/st-inspect.md`)

- Fields: frontmatter `name: st-inspect`, `description`, `tools: Read, Grep, Glob, Bash, Edit`,
  `model: opus` (FR-002). Body per [contracts/st-inspect.md](contracts/st-inspect.md) section 1.
- Inputs: plugin root, project root, feature dir (absolute paths).
- Outputs: the report (FR-004) and the `## Validate` section of `<feature>/plan.md` (V6).
- Rule: changes no file except that section, and replaces an older one (FR-003).
- Replaces: `agents/st-check.md` and `agents/st-validate.md` (deleted after it exists, FR-007).

## Inspect skill (`skills/st-inspect/SKILL.md`)

- Fields: frontmatter `name: st-inspect`, `description`. Body per
  [contracts/st-inspect.md](contracts/st-inspect.md) section 2.
- Starts exactly 1 agent, `stratum:st-inspect` (FR-005, SC-001).
- Replaces: `skills/st-check/SKILL.md` (deleted, FR-007).

## Phase value (`.stratum/state.json` key `phase`)

- Values in Full-lane order: `define`, `plan`, `inspect`, `build`, `close`. `check` is no longer
  written.
- Transitions: `/stratum:st-inspect` accepts `plan` or `inspect` and sets `inspect`.
  `/stratum:st-build` accepts `inspect` or `build` and sets `build`. Any other value warns once
  and runs (research R9).

## Validate section (`## Validate` in `<feature>/plan.md`)

- Fields: date, net verdict (`PASS`, `CONDITIONAL`, `BLOCKED`), a table of 4 checks with
  `PASS`, `CONCERN` or `FAIL`, validate findings `F<n>`.
- Rule: one per `plan.md`. A rerun replaces it (spec edge case 1).
- Verdict rule (V5): any `FAIL` gives `BLOCKED`, only `CONCERN`s give `CONDITIONAL`, else `PASS`.

## Agent list (`hooks/st-models.py` `AGENTS`)

- Derived from the file names in `agents/*.md`. After the change: `st-build`, `st-close`,
  `st-debug`, `st-fast`, `st-git`, `st-inspect`, `st-plan`, `st-quick`, `st-review`, `st-test`
  (10, FR-009).
- A `.stratum/models.json` key outside this list blocks every Stratum agent start (FR-010).
