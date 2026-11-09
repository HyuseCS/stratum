# Research: 020 worker workspaces

## R1. herdr calls (installed 0.9.4)

- Decision: `herdr workspace create --cwd <p> --label <t> --no-focus`, then `herdr tab rename <TAB_ID> <LABEL>` on `.result.tab.tab_id`. `herdr workspace close <workspace_id>`. `herdr tab list --workspace <id>`.
- Rationale: checked with `--help` on herdr 0.9.4. `workspace create` makes one default tab with a root pane (`.result.workspace.workspace_id`, `.result.tab.tab_id`, `.result.root_pane.pane_id`). Renaming that tab gives the one `worker-<id>` tab FR-003 asks for. A second `tab create` would leave an extra tab.
- Alternatives: `tab create` in the new workspace (rejected: two tabs). `workspace create --env` (not needed, see R2).

## R2. How `tabname` knows it runs in a worker

- Decision: the current git branch. When `git symbolic-ref -q --short HEAD` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`, the name is `st-codex-<branch>`, which is `st-codex-worker-<id lowercased>`.
- Rationale: `start` always makes the worktree on branch `worker-<id lowercased>` (`scripts/st-worker.sh:61`, `:299`), and the advisor runs from that worktree's root. No herdr call, no label parsing, and `start` needs no change for it. `scripts/st-worker.sh:64` already uses `worker-*` on the branch to tell a worker worktree. Only `st-worker.sh` makes `worker-*` branches (`scripts/st-worktree.sh` takes the user's branch name). The orchestrator's checkout is not on a `worker-*` branch, so its name stays the label slug.
- Alternatives:
  - A tab labelled `worker-*` in `$HERDR_WORKSPACE_ID`: rejected. Workers started before this feature are tabs in the orchestrator's workspace (live: `w4B` holds `worker-f94` now), so the orchestrator's own name would change, against FR-005. It also costs one more herdr call and a new case in the advisor fake herdr.
  - The label matches ` / <id>`: rejected. A user label can hold ` / `, and the user can rename the workspace.
  - `workspace create --env ST_WORKER=<N>`: not probed. It needs a change in `start` and a live probe that makes a real workspace. The branch gives the same answer with neither.
- Limit: a worker that checks out another branch mid-task gets the label slug name, and its point goes headless ("in use elsewhere"). Accepted: the brief tells workers to commit on their branch.
- Effect on old-layout workers: a worker tab in the orchestrator's workspace now gets its own `st-codex-worker-<id>` agent in a second `Codex` tab there, not the headless fallback. Accepted: it ends when those workers close.

## R3. herdr agent name limit

- Fact: `herdr --skill` line 57: names must match `[a-z][a-z0-9_-]{0,31}`, so 32 characters at most. The current slug cut at 23 (`st-codex-` is 9) follows this.
- `st-codex-worker-` is 16 characters. Ids of 1 to 16 characters fit. The id rule allows 25 (`scripts/st-worker.sh:60`), which gives 41.
- Decision (D14): cut the name to 32 characters, as the slug path does. Rejected: `start` refuses ids over 16 (changes the id rule).

## R4. Orchestrator name and task words

- Decision: label of `$HERDR_WORKSPACE_ID` from a local `herdr workspace list`, only with `HERDR_ENV=1`. Else `basename` of the repo path (main checkout locally, resolved `--repo` on a saved machine). Task words: first `#` heading of the task file, marks removed, cut to 30 characters. Exact rules in data-model.md.
- Rationale: FR-002 and the spec edge cases. A failed lookup must not stop `start`, because the fallback is a valid name. Tests run saved-machine cases with `HERDR_ENV=0`, so those cases make no local call.
- The label keeps the id as the user typed it (`f77`, `T004`). It is display text only: every command finds the worker by the tab label `worker-<id lowercased>`.

## R5. Test stub (tests/test_st_worker.sh)

- Fact: only the stub's `tab create` writes `$T/tc.json`. `wsid`, `tabid`, `pane`, `wt` and the stub's own `agent start` and `agent get` read it. The stub has no `tab rename` case (it answers `{}` and changes nothing), so after the change `find_worker` would not see `worker-t004`.
- Decision: the stub's `workspace create` writes `tc.json` in the `tab create` shape (`tab.tab_id`, `tab.workspace_id`, `root_pane.pane_id`, `root_pane.cwd`), and a new `tab rename` case sets the label in `tabs.json`. This is task T001, before any start change.

## R6. Overlap with issue #93

- Branch `093-autonomous-prompts` has only `specs/019-autonomous-prompts` changes now (`git diff --stat main...093-autonomous-prompts`). The conflict note is forward-looking. This plan does not touch `answer`, `wait`, `watch`, `screen`, `find_worker` or `scripts/st-codex-agent.sh`.
