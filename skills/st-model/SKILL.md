---
name: st-model
description: Set the model or effort a Stratum agent uses in this project, saved in .stratum/models.json. Use for "make st-close use opus", "put st-test on high effort", "put st-close back on its default".
---

# /stratum:st-model <agent> <value>...

Agents: `st-build`, `st-check`, `st-close`, `st-debug`, `st-fast`, `st-git`, `st-plan`,
`st-quick`, `st-review`, `st-test`, `st-validate`.

| Value | Effect on the agent's entry |
|-------|-----------------------------|
| `sonnet`, `opus`, `haiku`, `fable` | set `model` |
| `low`, `medium`, `high`, `xhigh`, `max` | set `effort` |
| `model default` | remove `model` |
| `effort default` | remove `effort` |
| `default` | remove the whole entry |

1. Unknown agent, unknown value, or no value: change nothing, show the agents, models, efforts
   and `default` forms above, and stop.
2. `<project>/.stratum/models.json` exists but is not valid JSON or not an object: change nothing,
   show the error, and stop. Never overwrite it.
3. File missing: start from templates/models.json. Copy `<plugin root>/templates/models.json`,
   then apply the change in step 4. If `<project>/.gitignore` lacks the line
   `.stratum/models.json`, add it (repos set up before 0.1.26 do not have it).
4. Apply the values to the agent's entry. Remove the entry if it is left as `{}`. Keep every other
   entry and key.
5. Write the file.
6. If step 3 copied the template, say so and list its entries. Then reply in one line:
   `<agent>: model <model or "default (<frontmatter model>)">, effort <effort or "default">.
   Applies on the next start.` The frontmatter model is the `model:` line in
   `<plugin root>/agents/<agent>.md`.
