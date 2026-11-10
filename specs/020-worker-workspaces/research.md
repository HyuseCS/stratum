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
- Limit: two live workers with the same id in two projects on one herdr server share the name `st-codex-worker-<id>`, and the second runs headless.
- Limit: an orchestrator checkout on a `worker-*` branch (for example the user testing a worker branch before merge) takes the worker's Codex name.
- Limit: on a host without the `C.UTF-8` locale, the 30-character cut of the task words falls back to bytes.
- Effect on old-layout workers: a worker tab in the orchestrator's workspace now gets its own `st-codex-worker-<id>` agent in a second `Codex` tab there, not the headless fallback. That `Codex` tab and its agent stay after `close`, because `close` closes only the worker tab in a shared workspace. The user closes it by hand.
- Effect on saved machines: a leftover `st-workers` workspace from before this feature is no longer closed by `close`. The user closes it by hand.

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

## Round 3 (2026-11-10)

Code read on worker-f94 `31b9e39` and `origin/093-autonomous-prompts` `daac275`. Line numbers are from worker-f94.

### R7. A taken name is already refused before anything is made

- Fact (probe, git 2.56.0, scratch repo): `git -C r worktree add -q -b r-94 <path> HEAD` with branch `r-94` present exits 255 with `fatal: a branch named 'r-94' already exists` and makes no folder.
- Fact: `start` runs `[ ! -e $qp ] || { echo "$qp already exists" >&2; exit 1; }; git -C $qr worktree add -q -b $N $qp $sha || exit 1` through `rx` (`scripts/st-worker.sh:290`), before `workspace create` (`:292`). The `|| exit 1` turns git's 255 into 1, so `rsh` does not report it as an ssh failure (`:138`).
- Decision (D32): FR-017 needs no new check, only `$N` replaced by the new name `B`. Tests: the git stub's `worktree add` (`tests/test_st_worker.sh`, the `-C ... worktree add -q -b` branch) refuses with git's message when `refs/heads/<b>` exists in the real repo, so a "taken branch" case can run.
- Alternative: a separate `git show-ref` check before `worktree add`. Rejected: same result, one more git call and one more remote string change.

### R8. find_worker and list can read the real branch from herdr

- Fact (live, herdr 0.9.4): `herdr worktree list --cwd <worktree>` gives `.result.worktrees[]` with `path`, `branch`, `is_linked_worktree`, `open_workspace_id`. For this worktree: `{"branch":"worker-f94","path":"/home/hyuse/Desktop/stratum-worker-f94",...}`.
- Fact (live, 2026-11-10): `herdr pane list --workspace w4B` gives both panes of this worker's tab (`w4B:t6`) the `cwd` `/home/hyuse/Desktop/stratum-worker-f94`, the same string as that worktree's `.path` above. A path match works as an exact string compare.
- Fact: today `find_worker` (`:194-195`) and `list` (`:553-554`) pick the worktree by `.branch == worker-<id>`, which finds no new-name worker.
- Decision: pick by `.path == <pane cwd>`, else by `.branch == worker-<id>` (old workers whose pane left its folder, FR-019). Read `WT` and `BR` from that entry. Same three herdr calls.
- Limit: a new-name worker whose pane left its worktree root is not found. This is the limit the ponytail note at `:192` already names.

### R9. Lock 2 denies a Bash read of the marker (input to D27)

- Fact: `lock2()` denies any Bash command in a worker session whose words name `.stratum/approve` or `.stratum/autonomous`, reads included (`tests/test_approve_hook.py` `LOCK2_BASH` has `ls .stratum/approve`).
- Fact: `tests/test_research.sh` "FR-002 B4 hook allows worker cmd" runs the research skill's worker check through the live hook in a worker and needs no deny.
- So once lock 2 guards `.stratum/worker` (FR-022), a research check like `[ -f .stratum/worker ]` is denied in exactly the sessions it must detect. Options: D27.
- Fact: `st-worker.sh` already runs the hook as a command (`render()`, `:198`), so a hook `--worker` mode follows an existing pattern.

### R10. When each name part can be checked (FR-016)

- Fact: `--project`, `--env`, `--issue` are known after argument parsing, before the herdr check (`:110`) and `herdr machine list` (`:120`).
- Fact: the default project needs the repo path: local from `git rev-parse --git-common-dir` (`:263`), on a saved machine from `--repo` (`~` is resolved over ssh only at `:270-275`).
- Decision: check given parts in the argument checks. Check the default project right after it is made: locally after one read-only git call, on a saved machine from the `--repo` text before `~` is resolved (`~/proj` gives `proj`). Both are before any herdr call in `start` and before anything is made.

### R11. The `/goal` prompt and `goal`

- Fact: `P` is built at `:106-109`, before any herdr call, for `start`, `goal` and `followup`, and names `$N` as the branch. `goal` does not call `find_worker`; it uses `look` and `unsent` (`:353-360`). `followup` calls `find_worker` first (`:371`), then writes the round brief (`:387`) before `prompt` (`:390`).
- Decision (D30): helper `goalp <branch>` builds and checks `P`. `start` calls it with the new name before `h tab list` (P6 keeps "no herdr call"). `goal` calls `find_worker` then `goalp "$BR"`. `followup` calls `goalp "$BR"` right after `find_worker`, before it writes anything.

### R12. The marker and the Codex name agree

- Fact: `close` matches the Codex agent `st-codex-$N` cut to 32 (`:518-519`), with `N=worker-${id,,}` (`:61`). `tabname` builds `st-codex-<l>` cut to 32 when `l` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$` (`scripts/st-advisor.sh:8-10`).
- Decision (D33): the marker holds `${id,,}`. `tabname` sets `l=worker-<marker line>` and keeps its regex, so both sides make the same string and a bad marker falls back to the slug.

### R13. Test churn in tests/test_st_worker.sh

- Fact: every `start` case builds the name from the default rule. The shared task file has no heading, so the default name is `repo-t004` locally and `proj-t004` on the saved machine, where the cases expect `repo-worker-t004`, `proj-worker-t004` and branch `worker-t004` (39 path lines and about 120 branch mentions on worker-f94, 32 path lines on #93).
- Decision: the existing cases are changed to the new default name. Old-worker coverage (FR-019) comes from a fixture that moves a started worker to the old folder and branch in the stub state. `fresh()` must also remove the new folders (`$tmp/repo-t004`, `$tmp/repo-94` ...) and never `$tmp/repo` or the real worktrees `repo-feat` and `repo-w9`.
- Fact: if D28 is A, the 15 roster fixture lines (`printf 'worker-t004\t...`) need the real branch in field 3.

### R14. Other `worker-` branch reads (not changed)

- `scripts/st-update.sh:254` labels a checkout ` worker` in its report when its branch starts with `worker-`. It is a report label, not a worker check, and FR-021 does not list it. A new-name worker shows no label there.
- `scripts/st-worker.sh:99` and `:584` check the roster name field (`worker-<id>`), not the session. Unchanged.
