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
