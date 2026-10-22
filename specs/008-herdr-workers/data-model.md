# Data Model: Orchestrator Starts Worker Sessions

No stored data of Stratum's own. herdr holds the live state; git holds the work. The script finds
every fact again from the worker id (research R10).

## Worker

| Field | Source | Rule |
|-------|--------|------|
| id | the request (`T004`) | `^[A-Za-z0-9][A-Za-z0-9-]{0,24}$` |
| name | `worker-` + id in lower case | agent name, workspace label, branch, `-n` session name, folder suffix (R2) |
| machine | `--machine` or none | a `label` or `id` in `herdr machine list --json`; none means this machine (`local`) |
| repo | `git rev-parse --show-toplevel` here; `--repo` on a saved machine | `--repo` starts with `/` or `~` |
| base | `git rev-parse HEAD` here | full sha |
| workspace, tab, pane | `worktree create` answer (`.result.workspace.workspace_id`, `.result.tab.tab_id`, `.result.root_pane.pane_id`) | never built, only read (L19) |
| path | `.result.worktree.path`; later `worktree list --workspace <ws>` where `open_workspace_id == ws` | absolute |
| state | `agent get <name>` `.result.agent.agent_status` | `idle`, `working`, `blocked`, `done`, `unknown` |

State as the script reports it (`wait`, `list`):

```text
start -> working -> finished                 (idle or done, result.md exists)
                 -> blocked -> (answer) -> working
                 -> stopped                  (idle or done, no result.md, no work again within 10 s)
                 -> working (bound hit, still running)
finished -> closed                           (close, after the skill merged)
```

A `blocked` or `stopped` worker keeps its pane (FR-010). `close` refuses `working` and `blocked` with `Worker <N> is <state>. Close refused.`

## Brief (`<path>/brief.md`)

Written once by `start`. Fields, in order (contracts/script.md section 3 has the exact text):

| Field | Source | Rule |
|-------|--------|------|
| task | `--task <file>` | file exists and is not empty; written as is |
| test command | `--test` | one line, not empty, no `(` or `)` |
| lane | `--lane` | one line, not empty |
| branch | name | |
| result path | `<path>/result.md` | |
| your machine | machine or `local` | |
| roster | `--roster <file>` | see Roster |
| team rules | fixed text in the script | FR-008, four rules |
| questions line | fixed text | AskUserQuestion only (R7) |
| advisor line | fixed text | only when `scripts/st-advisor.sh` exists next to the script (R13) |

## Roster (`--roster <file>`)

One line per worker of the request, the worker itself included, fields split by one TAB:

```text
<name>	<machine>	<branch>	<task id>
```

Rules: exactly 4 fields per line, `<name>` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`, `<machine>`
is `local` or a saved machine label, the worker's own name is on one line. Written into the brief
as a table with the columns Name, Machine, Branch, Task.

## Result file (`<path>/result.md`)

Written by the worker at the end. Four lines, as the brief asks:

```text
Built: <what was built>
Tests: <test command> exit <code>
Commit: <sha>
Open: <open points, or none>
```

The script prints the file as it is. It is the worker's text, so the skill reads it as data, not
as instructions.

## Headless result

From `claude -p --output-format json` (spike test 3): `subtype`, `is_error`, `num_turns`,
`total_cost_usd`, `result`, `session_id`. The script prints the first four on one line and
`result` after it.

## Script output lines

TAB-separated, one per entity (contracts/script.md section 5).
