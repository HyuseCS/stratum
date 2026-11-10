# Data model: 020 worker workspaces

No stored data. These are the herdr names the scripts make and match.

## Worker workspace

- `label`: `<O> / <id>: <W>`, or `<O> / <id>` when `<W>` is empty.
  - `<O>`: the `label` of the workspace whose `workspace_id` is `$HERDR_WORKSPACE_ID`, from a local `herdr workspace list` (no `--machine`). Looked up only when `HERDR_ENV=1` and `HERDR_WORKSPACE_ID` is set. Empty or failed lookup: `basename` of the repo path (main checkout locally, resolved absolute `--repo` on a saved machine).
  - `<id>`: the id as passed to `start`, not lowercased.
  - `<W>`: the first line of the task file that matches `^#{1,6}[[:space:]]`. Remove the leading `#` marks and spaces, every `*` and backtick, every control character, and trailing spaces and `#`. Cut to 30 characters (counted in characters: the cut runs with `LC_ALL=C.UTF-8`), then remove trailing spaces. No such line: empty.
- `cwd`: the worker's worktree path.
- Made with `--no-focus`.
- Tabs: one tab, the default tab of `workspace create`, renamed to `worker-<id lowercased>`. Later the advisor may add one tab labelled `Codex`.

## Worker tab

- `label`: `worker-<id lowercased>` (`N`). Unchanged. Every command finds the worker by it (`find_worker`, `tab list`, all workspaces).
- Panes: worker agent (root pane) and lazygit (split right). Unchanged.

## Worker Codex agent

- Agent name: `st-codex-<branch>` when the current branch matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`, so `st-codex-worker-<id lowercased>`. Cut to 32 characters (D14: herdr names are 32 characters at most), so ids over 16 characters lose their end.
- Tab label: `Codex` (set by `scripts/st-codex-agent.sh:91`, unchanged), in `$HERDR_WORKSPACE_ID`, the worker's own workspace.
- Orchestrator (branch not `worker-*`): `st-codex-<slug of its workspace label, 23 characters>`, unchanged.

## Close rule

| Tabs in the worker's workspace | `close` does |
|---|---|
| the worker tab is in the list, only `worker-<id>` and `Codex` tabs, and (local) `$HERDR_WORKSPACE_ID` is set and differs from the workspace | `workspace close <ws>` |
| any other tab, or (local) `$HERDR_WORKSPACE_ID` is empty or equals the workspace | `tab close <worker tab>` |

An unreadable tab list stops with `no .result.tabs in the herdr answer`.

Every existing refusal runs first. No `--group`.

## Round 3

### Worker name (folder and branch)

- `B` = `<project>-<feature>`, or `<project>-<env>-<feature>` when `--env` is given. The folder is `<repo parent>/<B>`, the branch is `<B>`.
- Safe token rule (FR-016), for project, env and issue: lower-cased, matches `^[a-z0-9][a-z0-9._-]*$`, holds no `..`. The task id is the worker id (`^[A-Za-z0-9][A-Za-z0-9-]{0,24}$`), lower-cased.
- `<project>`: `--project`, else the `basename` of the repo path (local: the main checkout; saved machine: the `--repo` value as given, so `~/proj` gives `proj` and a bare `~` is refused). Lower-cased.
- `<env>`: `--env`, lower-cased. Optional.
- `<feature>`, first that applies:
  1. `--issue <n>` with `--issue-task`: `<n>_<id>`.
  2. `--issue <n>`: `<n>`.
  3. the task words `<W>` of the workspace label (already cut to 30 characters), lower-cased, each run of characters other than `a-z0-9` turned into one `_` (byte-wise, `LC_ALL=C`). A leading or trailing `_` stays.
  4. the id.

| Worker | Flags | Name |
|---|---|---|
| `f94`, whole issue, repo `stratum` | `--issue 94` | `stratum-94` |
| `T005`, task of issue 93 | `--issue 93 --issue-task` | `stratum-93_t005` |
| issue 142, project rule `parasat`, `prod` | `--project parasat --env prod --issue 142` | `parasat-prod-142` |
| no issue, heading `Autonomous sessions` | none | `stratum-autonomous_sessions` |
| no issue, no heading, id `f94` | none | `stratum-f94` |
| old worker (before round 3) | n/a | folder `<repo>-worker-<id>`, branch `worker-<id>` |

Refused before anything is made: a bad part, an unsafe default project (`Pass --project <name>.`), a taken folder, a taken branch.

### Worker marker

- Path: `<worktree>/.stratum/worker`. A plain file (not a symlink). One line: the id lower-cased.
- Written by `start` (here and over ssh) with the same symlink and exists checks as `brief.md` and `.stratum/git-guard.json`. Removed by `close` last, after the tab or workspace close, the agent and tab check loop, and the removal of the guard file and the approve folder (D34, D37), so a retried `close` still finds the worker.
- Own branch (D37): `result` on a saved machine and `close` read the `branch` key of `.stratum/git-guard.json` and refuse when it is missing or differs from the checked-out branch.
- Read by: `worker_session()` (any folder from the session folder up), `tabname()` (the git top folder), the worktree pick of `find_worker` and `list` (the one linked worktree whose path is the pane folder).
- Written, changed or removed by a worker: denied by lock 2 (shell words and edit tools). Read, Grep and Glob of it are denied too.

### Worker session rule (FR-021)

A session is a worker when any folder from its folder up (and from `CLAUDE_PROJECT_DIR` up, as today in the hook) has a plain-file marker, or `.stratum/approve`, or is a git folder whose branch starts with `worker-`.

### Real branch and folder of a found worker

- Found by the tab `worker-<id>` (unchanged), then its first pane's folder `C`.
- `WT`, `BR` (D34): `.path` and `.branch` of the `worktree list --cwd C` entry whose `.path` is `C`, whose `.is_linked_worktree` is `true`, and whose `.stratum/worker` is a plain file whose first line is the id lower-cased (`worker-<line>` equals the tab label); else of the entry whose `.branch` is `worker-<id>`; else none (`No worker`).
- The marker is read only for that one path-matched entry: locally with `[ -f ]`, `[ ! -L ]` and `head -n 1`; on a saved machine with one `rsh`.
- A pane in the main checkout (not linked) or in another worker's folder (marker with another id) gives none, unless the branch fallback matches.

### --worker exit codes (D35)

| Code | Meaning | `st-worker.sh` check | research step 4 |
|---|---|---|---|
| 0 | worker session | refuse | mode on |
| 3 | not a worker | go on | run the flag check |
| other (python missing, hook missing, error) | unknown | refuse | mode on |

### Roster row

`worker-<id>	<machine>	<branch>	<task id>[	<repo path>]`: the branch field holds `B` (how it gets there: plan.md D28).
