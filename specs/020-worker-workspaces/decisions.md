# Decisions: issue #94 (workers in their own herdr workspaces, each with its own Codex tab)

Grill done with the user on 2026-11-09, before this worker started. Codes continue from that grill (D10 to D12, Q11 to Q13, O19 to O24).

- Fact (live probe 2026-11-09, herdr 0.9.4): a pane in a workspace made by `herdr workspace create` gets that workspace's own `HERDR_WORKSPACE_ID`. Such a workspace is in no group, so it is a separate sidebar entry, not under the orchestrator.
- D10 (Q11): O20. Each worker runs in its own herdr workspace, as #94 says, and is a separate sidebar entry. The user accepts that it is not under the orchestrator (the #71 grouping). The workspace must be named so it is clear which worker and which orchestrator it belongs to. Rejected: O19 (workers stay tabs with Codex in a third pane).
- D11 (Q12): O22. The worker workspace name starts with the orchestrator's name, so one orchestrator's workers sort together. The Codex tab name is then built from the worker's own id, not from the first 23 characters of the workspace label (which would cut off the worker part). Rejected: O21 (worker id first).
- D12 (Q13): O23. The workspace name is `<orchestrator> / <id>: <task words>`, for example `stratum / f77: autonomous sessions`. The task words come from the task's title, cut to about 30 characters. The id stays the key that every command uses to find the worker. Rejected: O24 (no id, find workers by branch).
- Defaults (no question, follow from D10 to D12):
  - Inside its workspace the worker keeps one tab labelled `worker-<id>` (agent and lazygit). `find_worker` already matches tab labels across all workspaces, so `wait`, `watch`, `answer`, `followup` and `result` need no change. `start`, `close` and `list` change.
  - The worker's Codex tab opens in the worker's own workspace, named `st-codex-worker-<id>`.
  - `close` closes the worker's whole workspace, Codex tab included.
  - On a saved machine `start` makes the same per-worker workspace there. The `st-workers` workspace path goes away.
  - The orchestrator name is the label of the workspace that runs `start` (`HERDR_WORKSPACE_ID`). The task words are the first heading of the task file.
  - New workspaces open with `--no-focus`.
- D13 (user, spec gate, 2026-11-09): the spec is agreed as written (US1 to US5, FR-001 to FR-012, SC-001 to SC-005), with the orchestrator's three choices: `close` closes the whole workspace only when it holds just the worker tab and its Codex tab (an older worker is a tab in the orchestrator's workspace), `list` names the workspace on each line, and the orchestrator part falls back to the repo folder name.
- D14 (orchestrator, Plan, small): herdr agent names match `[a-z][a-z0-9_-]{0,31}`, and a worker id can be 25 characters, so `st-codex-worker-<id>` is cut to 32 characters, as the label slug is today. Ids longer than 16 characters that share their first 16 can clash; the clash falls back to headless. Rejected: `start` refuses ids over 16 characters (changes the id rule).
- D15 (orchestrator, Plan, small): `README.md` and `skills/st-build/SKILL.md` name the Codex agent `st-codex-<workspace label>`. Both lines get a clause for the worker name, and rows R7 and R17 of `tests/test_risk_rules.sh` change to match. Rejected: leave them (wrong for every worker).
- Scope note (brief): issue #93 (`specs/019-autonomous-prompts`) changes `answer`, `wait`/`watch` screen hashing and the Codex answer reader in the same scripts at the same time. This feature keeps to `start`, `close`, `list`, the saved-machine path and the Codex tab name.
