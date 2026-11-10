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

## Round 3

Names and rules: [data-model.md](../data-model.md) "Round 3". Decisions D27 to D33: plan.md.

### start

```text
st-worker.sh start <id> --task <file> --test <cmd> --lane <text> --roster <file> [--machine <m> --repo <path>] [--model <name>] [--autonomous] [--project <p>] [--env <e>] [--issue <n> [--issue-task]]
```

- `--issue-task` without `--issue`: usage line, exit 2.
- A bad `--project`, `--env` or `--issue` value: exit 1, one line, no git or herdr call:
  `Name part <value> must be letters, digits, dot, underscore or dash, start with a letter or digit, and have no "..".`
- An unsafe repo folder name with no `--project`: exit 1, one line, no herdr call:
  `The repo folder name <name> is not a safe name part. Pass --project <name>.`
- Own roster row with another branch in field 3 (D28): exit 1, one line, no herdr call: `Roster row for <N> must name branch <B>.`
- Brief rule 1 (D29): `1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md, .stratum/git-guard.json, .stratum/worker or .stratum/approve/, and never write in .stratum/approve/.`
- Taken folder: `stopped: <path> already exists`. Taken branch: `stopped: fatal: a branch named '<B>' already exists`. Both with the `worker` line with `-` in fields 4 to 7, and no `workspace create`.
- git: `worktree add -q -b <B> <repo parent>/<B> <base sha>`. The undo: `worktree remove`, `branch -D <B>`.
- Files in the worktree: `brief.md` (`- Branch: <B>`), `.stratum/git-guard.json` (`branch: <B>`), `.stratum/worker` (one line, the id lower-cased). On a saved machine the `rsh` string checks `.stratum/worker` for a symlink or an existing file with the others, then writes it after the guard file.
- `/goal` prompt: `/goal \`<test>\` exits 0, the change is committed on branch <B>, and result.md is written; read brief.md in this folder first and follow it`.
- `worker` line: unchanged fields; field 6 is `<B>`.

### goal, followup

Both find the worker first (`goal` gains `tab list`, `pane list --workspace`, `worktree list --cwd`) and send the `/goal` prompt with the worker's real branch.

### result (saved machine)

`git fetch -- <target>:<WT> <branch>:<branch>`, `git rev-parse --verify <branch>`, with the worker's real branch. Lines unchanged.

### close

`gh pr list --head <branch> --state open --json number -q length` with the real branch. Removes `.stratum/worker` with `.stratum/git-guard.json` (one `rm -f` with both paths). Output and refusals unchanged.

### list

```text
found	<N>	<machine>	<tab>	<pane or ->	<status>	<path or ->	<workspace label or ->	<branch or ->
```

The branch is the new last field. Path and branch come from the worktree whose path is the pane folder, else (old workers) the one on branch `worker-<id>`.

### hooks/st-approve.py

- PreToolUse in a worker session (rule: data-model.md "Worker session rule") denies, with reason `.stratum/approve/, .stratum/autonomous and .stratum/worker are written only by the orchestrator.`, a Bash command with a word `.stratum/worker` or `*/.stratum/worker`, and an Edit, Write, MultiEdit, NotebookEdit, Read, Grep or Glob whose path is `.stratum/worker` or under it. `.stratum/worker-setup.sh` is not matched.
- `python3 hooks/st-approve.py --worker` (D27) reads no stdin, prints nothing, exits 0 in a worker session (from its own folder and `CLAUDE_PROJECT_DIR`), 1 otherwise. Callers: the orchestrator-only check of `st-worker.sh` (`approve`, `pass`, `autonomous-on`, `autonomous-off`, `start --autonomous`; message unchanged) and research skill step 4.

### Ignore lists (D29)

`.gitignore`, `scripts/st-update.sh` `IGNORE` and `skills/st-init/SKILL.md` step 2 name `.stratum/worker`. `st-update.sh audit` gives an `ignore` row for it; `fix <folder> ignore .stratum/worker` adds the line.

### st-advisor.sh tabname

`l` is `worker-<first line of $(git rev-parse --show-toplevel)/.stratum/worker>` when that is a plain file, else the current branch. Then as before: `st-codex-<l>` cut to 32 when `l` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`, else the label slug name.
