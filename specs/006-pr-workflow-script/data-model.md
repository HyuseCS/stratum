# Data Model: Ultracode Workflow Script for st-pr

Nothing is stored. These are the values that pass between st-pr, the script and its agents.
Exact shapes: [contracts/pr-workflow.md](contracts/pr-workflow.md).

## Size rule (session, step 1 item 5)

| Field | Source | Rule |
|-------|--------|------|
| commits | `git rev-list --count origin/<base>..HEAD` | workflow when more than 30 |
| files | `git diff --name-only origin/<base>...HEAD \| wc -l` | workflow when more than 40 |
| ultracode | latest system-reminder about Ultracode | must be on |

Workflow path = ultracode on AND (commits > 30 OR files > 40). Exactly 30 and 40 take the
current path. Both thresholds are fixed text in `skills/st-pr/SKILL.md`, not a setting.

## Args (session to script)

`projectRoot`, `pluginRoot`, `scratchpad`: absolute paths. `base`, `branch`: names.
`featureDir`: absolute path or `""`. `commits`: array of `"<%h> <%s>"` strings, newest first,
never empty (step 1 stops on an empty range). A JSON object, never a string.

## Facts (script, phase Facts)

| Label | Shape | Null means |
|-------|-------|------------|
| `facts:tests` | text | `unverified: facts:tests` |
| `facts:frs` | text, `N/A` with no feature dir | `unverified: facts:frs` |
| `facts:areas` | text | `unverified: facts:areas` |
| `facts:scan` | `{finds: [{commit, path, line, kind, blocking}]}` | `unverified: facts:scan`, no block |
| `facts:plan` | text, `N/A` with no feature dir | `unverified: facts:plan` |
| `chunk:<n>` | `{flagged: [{commit, why}]}` | `unverified: chunk:<n>` |

Chunk n = `commits.slice(25 * (n - 1), 25 * n)`, n from 1 to `ceil(commits.length / 25)`.
A find never holds the secret or personal value.

## Draft

`{title, unverified: [string]}` from the `draft` agent, plus the file `<scratchpad>/pr-body.md`.
Title under 70 characters, not from a flagged subject, no AI attribution.

## Problem (phase Verify)

`{line, wrong, right}` from a `refute:<lens>` agent. Lens is one of `paths`, `frs`, `commands`,
set by the script from the label.

## Fix (phase Fix)

`{dropped: [{line, why}]}` from a `fix:<lens>` agent. Runs only for a lens with problems, one
at a time, order paths, frs, commands.

## Result (script to session)

`{title, bodyPath, warnings, blocked}`. States:

```text
Facts --blocking find--> Blocked   {null, null, warnings, true}    st-pr stops before the gate
Facts --draft null-----> No draft  {null, null, warnings, false}   st-pr runs steps 2 to 4
Facts -> Draft -> Verify -> Fix -> Done {title, path, warnings, false} st-pr goes to step 5
```

Warnings are strings with one of the prefixes `blocking: `, `unverified: `, `subject: `, `scan: `,
`dropped: `. On a block the `blocking: ` lines come first.
