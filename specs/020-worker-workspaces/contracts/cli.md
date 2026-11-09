# Contract: st-worker.sh and st-advisor.sh changes

Only the lines below change. Every other line, exit code and command keeps its current contract.

## start

herdr calls (local, or each with `--machine <m>`):

1. `tab list` (duplicate check, unchanged).
2. Local only, when `HERDR_ENV=1`: `workspace list` with no `--machine` (orchestrator label).
3. `workspace create --cwd <worktree> --label <label> --no-focus` (label rule: [data-model.md](../data-model.md)).
4. `tab rename <tab_id from step 3> worker-<id>`.
5. `pane split`, `pane run`, `agent start`, `agent prompt`: unchanged.

Gone: `tab create`, `worktree list --cwd <repo>` in `start`, any `st-workers` workspace.

Failure at step 3: `git worktree remove` and `git branch -D` as today, then `stopped: <herdr message>`, then the `worker` line with `-` in fields 4 to 7.
Failure at step 4: `workspace close <new ws>`, then the same undo and lines.

`worker` line: unchanged (`worker	<N>	<machine>	<tab>	<pane>	<branch>	<path>`).

## close

After every existing refusal:

1. `tab list --workspace <ws>`.
2. `workspace close <ws>` when all labels are `worker-<id>` or `Codex` and (local only) `<ws>` is not `$HERDR_WORKSPACE_ID`. Otherwise `tab close <tab>`.
3. `agent list`, `tab list` check loop: unchanged.

Output: unchanged (`closed	<N>`, `folder	<path>	ready to remove`).

## list

One extra call: `workspace list`. Line:

```text
found	<N>	<machine>	<tab>	<pane or ->	<status>	<path or ->	<workspace label or ->
```

The workspace label is the new last field. Control characters in it are replaced with a space.

## st-advisor.sh tabname

Prints `st-codex-<branch>`, cut to 32 characters (D14, herdr name limit), when `git symbolic-ref -q --short HEAD` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`. Ids of 1 to 16 characters give the full `st-codex-worker-<id>`. Else prints the current label slug name. The last line of a Codex point, `codex: tab <name>`, shows that name.

## Docs (D15)

`README.md:266,270` and `skills/st-build/SKILL.md:97` name both forms: `st-codex-<workspace label>`, and `st-codex-worker-<id>` in a worker. Rows R7 and R17 of `tests/test_risk_rules.sh` grep the new lines 97 and 266.
