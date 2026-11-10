# Quickstart: 020 worker workspaces

## Automated

From the repo root:

```bash
bash tests/test_st_worker.sh       # start, close, list, saved machine (herdr stub)
bash tests/test_advisor_matrix.sh  # Codex agent name for a worker and the orchestrator
bash tests/test_worker_rules.sh    # skill text
```

Each must exit 0 and print no `FAIL` line.

## By hand (live herdr, the only proof for SC-001 to SC-004)

The user runs this. Prerequisite: an orchestrator session in a herdr workspace labelled `stratum`, on a clean base branch.

1. Ask the orchestrator to start two workers, `f77` and `f79`, each with a task file whose first line is a `#` heading.
   Expect: two new sidebar entries, `stratum / f77: <heading words>` and `stratum / f79: <heading words>`, each with one tab `worker-f77` / `worker-f79` (agent left, lazygit right). Focus stays on `stratum`. The `stratum` workspace has no new tab.
2. In each worker, let a lane run the Codex advisor.
   Expect: each worker workspace gets a `Codex` tab. `herdr agent list` shows `st-codex-worker-f77` and `st-codex-worker-f79`. Neither point ends with `codex: headless (Codex tab name ... in use elsewhere)`.
3. In the orchestrator, run the advisor once.
   Expect: its last line is `codex: tab st-codex-stratum`, as before.
4. Run `bash <plugin root>/scripts/st-worker.sh list`.
   Expect: each `found` line ends with the worker's workspace name.
5. After both workers finish and merge, run `close f77` and `close f79`.
   Expect: both worker workspaces are gone with their `Codex` tabs. `stratum` is still open. Each `folder ... ready to remove` path still exists.
6. Saved machine (laptop): start one worker with `--machine laptop --repo <path>`.
   First run `locale -a | grep -i c.utf` on the laptop once. Expect a line. No line: the task-word cut counts bytes, not characters.
   Expect: on the laptop, a new workspace `stratum / <id>: <words>` with the worktree as folder. No `st-workers` workspace is made, and the laptop's main checkout workspace gets no tab. `close <id> --machine laptop` removes that workspace.

Notes for the user (by hand, once):

- A worker started before this feature has its tab in the orchestrator's workspace. If it ran the advisor after the update, its `Codex` tab (`st-codex-worker-<id>`) stays there after `close`. Close that tab by hand.
- A leftover `st-workers` workspace on a saved machine is no longer closed by `close`. Close it by hand.

## Round 3

Prerequisite (D25): #93 is merged into main, and origin/main is merged into worker-f94.

### Automated

From the repo root, each must exit 0 and print no `FAIL` line:

```bash
bash tests/test_st_worker.sh                      # names, marker, real branch, old workers
python3 tests/test_approve_hook.py                # lock 2 on the marker, worker by marker
bash tests/test_advisor_matrix.sh                 # Codex name from the marker
bash tests/test_research.sh                       # research worker check
bash tests/test_worker_rules.sh                   # skill and README text
bash tests/test_on_demand.sh                      # skill steps 8 and 11
bash tests/test_st_update.sh                      # .stratum/worker ignore row
bash tests/test_update_items.sh                   # st-init ignore list matches st-update
```

### By hand (live herdr, the user runs it)

Prerequisite: an orchestrator session in the `stratum` workspace, on a clean base branch.

1. Ask the orchestrator to start worker `f94` for the whole of issue 94.
   Expect: the `worker` line names branch `stratum-94` and folder `<parent>/stratum-94`. `git branch --list stratum-94` shows the branch. `<parent>/stratum-94/.stratum/worker` holds `f94`.
2. Ask it to start worker `T005` for task T005 of issue 93.
   Expect: branch and folder `stratum-93_t005`.
3. Start a second worker, id `f94b`, for issue 94 with no task id.
   Expect: `stopped: fatal: a branch named 'stratum-94' already exists`. No new workspace in the sidebar.
4. In the `stratum-94` worker, let a lane run the Codex advisor.
   Expect: the last line is `codex: tab st-codex-worker-f94`.
5. In the `stratum-94` worker pane, ask Claude to run `touch .stratum/autonomous` and, with the Write tool, to write `.stratum/worker`.
   Expect: both are denied with `.stratum/approve/, .stratum/autonomous and .stratum/worker are written only by the orchestrator.`
6. In the orchestrator, run `bash <plugin root>/scripts/st-worker.sh list`.
   Expect: the `f94` line ends with its workspace name and `stratum-94`.
7. After the merge, run `close f94`.
   Expect: `gh pr list --head stratum-94` is the PR check, the workspace is gone, `<parent>/stratum-94` still exists, and `<parent>/stratum-94/.stratum/worker` is gone.
8. A worker started before round 3 (folder `<repo>-worker-<id>`, branch `worker-<id>`), if one is open: run `wait`, `result` and `close` with its id.
   Expect: each works as before.
