---
name: st-model
description: Set the model or effort a Stratum agent uses in this project, saved in .stratum/models.json. Use for "make st-close use opus", "put st-test on high effort", "put st-close back on its default".
---

# /stratum:st-model <agent> <value>...

Plugin root is two levels up from this skill's base directory.

Agents: `st-build`, `st-close`, `st-debug`, `st-fast`, `st-git`, `st-inspect`, `st-plan`,
`st-quick`, `st-review`, `st-test`.

| Value | Effect on the agent's entry |
|-------|-----------------------------|
| `sonnet`, `opus`, `haiku`, `fable` | set `model` |
| `low`, `medium`, `high`, `xhigh`, `max` | set `effort` |
| `model default` | remove `model` |
| `effort default` | remove `effort` |
| `default` | remove the whole entry |

Take the agent and values from the arguments or the user's words. "Its default" with no key
named means `default`.

1. Unknown agent, unknown value, no value, or conflicting values (two models, two efforts, or
   `default` with another value): change nothing, show the agents, models, efforts and `default`
   forms above, and stop.
2. `<project>/.stratum/models.json` exists but is not valid JSON or not an object: change nothing,
   show the error, and stop. Never overwrite it.
3. File missing: start from templates/models.json. Copy `<plugin root>/templates/models.json`,
   then apply the change in step 4. If `<project>/.gitignore` lacks the line
   `.stratum/models.json`, add it (repos set up before 0.1.26 do not have it).
4. If the agent's entry exists and is not an object: change nothing, say why, and stop. Else apply
   the values to the entry. Remove the entry if it is left as `{}`. Keep every other entry and key.
5. Write the file.
6. From the project root, run `echo '{"tool_input":{"subagent_type":"stratum:st-inspect"}}' | python3 <plugin root>/hooks/st-models.py`.
   If it prints a deny, show its reason instead of "Applies on the next start." below.
   If step 3 copied the template, say so and list its entries. Then reply in one line:
   `<agent>: model <model or "default (<frontmatter model>)">, effort <effort or "default">.
   Applies on the next start.` The frontmatter model is the `model:` line in
   `<plugin root>/agents/<agent>.md`.
