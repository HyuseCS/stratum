# Contract: st-worker.sh and st-advisor.sh changes

Only the lines below change. Every other line, exit code and command keeps its current contract.

## start

herdr calls (local, or each with `--machine <m>`):

1. `tab list` (duplicate check, unchanged).
2. Local only, when `HERDR_ENV=1`: `workspace list` with no `--machine` (orchestrator label).
3. `workspace create --cwd <worktree> --label <label> --no-focus` (label rule: [data-model.md](../data-model.md)).
   A `workspace create` answer without a workspace, tab or pane id goes to the failure path below with `no <key> in the herdr answer`.
4. `tab rename <tab_id from step 3> worker-<id>`.
5. `pane split`, `pane run`, `agent start`, `agent prompt`: unchanged.

Gone: `tab create`, `worktree list --cwd <repo>` in `start`, any `st-workers` workspace.

Failure at step 3 (or a missing id in its answer): `git worktree remove` and `git branch -D` as today, then `stopped: <herdr message>`, then the `worker` line with `-` in fields 4 to 7.
Failure at step 4: `workspace close <new ws>` (`.result.workspace.workspace_id` of step 3; its failure does not stop the undo), then the same undo, `stopped: <rename message>`, and the `worker` line with `-` in fields 4 to 7.

`worker` line: unchanged (`worker	<N>	<machine>	<tab>	<pane>	<branch>	<path>`).

## close

After every existing refusal:

1. `agent list`. An answer with no `.result.agents` array stops with `stopped: no .result.agents in the herdr answer`. The worker's Codex tab is the `tab_id` of the agent whose name is `st-codex-worker-<id>` (cut to 32 characters) and whose `workspace_id` is `<ws>`.
2. `tab list --workspace <ws>`. An answer with no `.result.tabs` stops with `stopped: no .result.tabs in the herdr answer`.
3. `workspace close <ws>` when the worker tab is in the list, every tab is the worker tab (label `worker-<id>`) or the worker's Codex tab from step 1, and (local only) `HERDR_WORKSPACE_ID` is not empty and differs from `<ws>`. Otherwise `tab close <tab>`. A local close with an empty `HERDR_WORKSPACE_ID` closes only the tab.
4. `agent list`, `tab list` check loop: unchanged.

Output: unchanged (`closed	<N>`, `folder	<path>	ready to remove`).

## list

One extra call: `workspace list`. An answer with no `.result.workspaces` array stops with `stopped: no .result.workspaces in the herdr answer`. Line:

```text
found	<N>	<machine>	<tab>	<pane or ->	<status>	<path or ->	<workspace label or ->
```

The workspace label is the new last field. It is `-` when the workspace is not found or its label is empty or missing. Control characters in it are replaced with a space.

## st-advisor.sh tabname

Prints `st-codex-<branch>`, cut to 32 characters (D14, herdr name limit), when `git symbolic-ref -q --short HEAD` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`. Ids of 1 to 16 characters give the full `st-codex-worker-<id>`. Else prints the current label slug name. The last line of a Codex point, `codex: tab <name>`, shows that name.

## Docs (D15)

`README.md:266,270` and `skills/st-build/SKILL.md:97` name both forms: `st-codex-<workspace label>`, and `st-codex-worker-<id>` in a worker. Rows R7 and R17 of `tests/test_risk_rules.sh` grep the new lines 97 and 266.
