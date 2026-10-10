# Contract: `/stratum:st-model`

Skill file: `skills/st-model/SKILL.md`, in the `st-shape` / `st-theme` style. Refines D14
(research R9, R10; D17, D18).

## Frontmatter

- `name: st-model`
- `description` must let Claude Code pick the skill from plain words. It names: model, effort,
  Stratum agent, `.stratum/models.json`, and examples "make st-close use opus", "put st-test on
  high effort", "put st-close back on its default".

## Arguments

`/stratum:st-model <agent> <value>...`

| Value | Effect on `<agent>`'s entry |
|-------|-----------------------------|
| a model: `sonnet`, `opus`, `haiku`, `fable` | set `model` |
| an effort: `low`, `medium`, `high`, `xhigh`, `max` | set `effort` |
| `model default` | remove `model` |
| `effort default` | remove `effort` |
| `default` | remove the whole entry |

Agents: `st-build`, `st-check`, `st-close`, `st-debug`, `st-fast`, `st-git`, `st-plan`,
`st-quick`, `st-review`, `st-test`, `st-validate`.

## Steps

1. Unknown agent, unknown value, or no value: change nothing, list the allowed agents, models,
   efforts and the `default` forms, and stop.
2. `<project>/.stratum/models.json` exists but is not valid JSON or not an object: change nothing,
   show the error, and stop. Never overwrite it.
3. File missing: start from `templates/models.json`: copy `<plugin root>/templates/models.json`,
   then apply the change in step 4 (D17). If `.gitignore` lacks the line `.stratum/models.json`,
   add it (repos set up before 0.1.26 do not have it).
4. Apply the values to the agent's entry. Remove the entry if it is left as `{}`. Keep every other
   entry and key as it is.
5. Write the file.
6. If step 3 copied the template, say so and list its entries. Then reply in one line: `<agent>: model <model or "default (<frontmatter model>)">, effort <effort or
   "default">. Applies on the next start.` The frontmatter model comes from the `model:` line in
   `<plugin root>/agents/<agent>.md`.
