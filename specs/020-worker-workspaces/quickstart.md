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
   Expect: on the laptop, a new workspace `stratum / <id>: <words>` with the worktree as folder. No `st-workers` workspace is made, and the laptop's main checkout workspace gets no tab. `close <id> --machine laptop` removes that workspace.
