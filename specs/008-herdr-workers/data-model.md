# Data Model: Orchestrator Starts Worker Sessions

No stored data of Stratum's own. herdr holds the live state; git holds the work. The script finds
every fact again from the worker id (research R10).

## Worker

| Field | Source | Rule |
|-------|--------|------|
| id | the request (`T004`) | `^[A-Za-z0-9][A-Za-z0-9-]{0,24}$` |
| name | `worker-` + id in lower case | agent name, tab label, branch, `-n` session name, folder suffix (R2, R17) |
| machine | `--machine` or none | a `label` or `id` in `herdr machine list --json`; none means this machine (`local`) |
| repo | the main checkout here, `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"` (herdr refuses a linked worktree, research R3); `--repo` on a saved machine | `--repo` starts with `/` or `~` |
| base | `git rev-parse HEAD` here | full sha |
| workspace | `start` here: `$HERDR_WORKSPACE_ID` (the only `HERDR_*` value read, FR-018); `start` on a saved machine: `open_workspace_id` of the main entry of `worktree list --cwd <repo>`, else the first workspace labelled `st-workers` in `workspace list`, else `.result.workspace.workspace_id` of `workspace create --label st-workers` (D35); later: `.workspace_id` of the tab labelled name in `tab list` | never built (L26); never this machine's id on a saved machine |
| tab, pane | `tab create` answer (`.result.tab.tab_id`, `.result.root_pane.pane_id`); later `tab list` (`tab_id`) and `agent get` (`pane_id`) | never built, only read (L26); the tab id is field 4 of the `worker` and `found` lines |
| branch | name, made by `git worktree add -b <name>` | `git worktree add` fails if it exists |
| path | `start`: `<repo parent>/<repo name>-<name>`, made by `git worktree add`; later: `.path` of the entry with `branch == name` in `worktree list --cwd <cwd>`, where `<cwd>` is the `cwd` of a pane of the tab in `pane list --workspace <ws>` | here absolute; on a saved machine as `--repo` gives it (`~/...` allowed) |
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
`closed` means the tab is gone; on a saved machine its workspace is closed too only when it is labelled `st-workers` and no `worker-*` tab is left in it (FR-018, D35).

## Brief (`<path>/brief.md`)

Written once by `start`. Fields, in order (contracts/script.md section 3 has the exact text):

| Field | Source | Rule |
|-------|--------|------|
| task | `--task <file>` | file exists and is not empty; written as is |
| test command | `--test` | one line, not empty, no `(` or `)` |
| lane | `--lane` | one line, not empty |
| branch | name | |
| model | `--model`, else `st-worker.model` in `.stratum/models.json`, else `default` | one token `^[A-Za-z0-9][A-Za-z0-9._-]*$` |
| plugin root | the parent of the script's folder | |
| your machine | machine or `local` | |
| result path | `<path>/result.md` | |
| roster | `--roster <file>` | see Roster |
| team rules | fixed text in the script | FR-008, four rules |
| questions line | fixed text | AskUserQuestion only (R7) |
| advisor line | fixed text | only when `scripts/st-advisor.sh` exists next to the script (R13) |

## Roster (`--roster <file>`)

One line per worker of the request, the worker itself included, fields split by one TAB:

```text
<name>	<machine>	<branch>	<task id>
```

Rules: exactly 4 non-empty fields per line, `<name>` starts with `worker-`, the worker's own name
is on one line, blank lines are skipped. The script does not check the machine, branch or task
fields; the skill writes `local` or the saved machine label. Written into the brief
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
