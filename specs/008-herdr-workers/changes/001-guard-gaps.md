# 001 guard-gaps

What: Close the commit guard gaps PR #41 left open. (1) `commit: auto` applies only when the command cannot target another checkout (adds `--git-dir`, `--work-tree`, `GIT_DIR=`, `GIT_WORK_TREE=`, `pushd`). (2) `git merge` elsewhere asks. (3) `st-worker.sh close` removes the worker's `.stratum/git-guard.json`.
FRs: none new. Serves D24 (amended by cfa95c0) and the worker commit guard in plan.md S4. Spec FR numbers not re-checked, orchestrator to confirm.
Impact area: core runtime

## Files
- hooks/st-git-guard.py - `parse_git` returns `elsewhere` as a 4th value: true for `-C` (both forms), `--git-dir`/`--work-tree` (both forms), and a `GIT_DIR=`/`GIT_WORK_TREE=` prefix. The `-C` dir still goes to `cdir`, so the summary dir stays right. `main` sets `moved` for `seg[0] in ("cd", "pushd")` and passes `elsewhere or moved`. `judge` gets `if sub in ("merge", "pull", "cherry-pick", "revert", "am") and elsewhere: ask` (gate Q2: B). In-folder runs stay unruled.
- scripts/st-worker.sh (close, after the open-PR check, before `h workspace close`) - local: `rm -f "$WT/.stratum/git-guard.json" || fail "Worker $N: cannot remove .stratum/git-guard.json. Close refused."`. Remote: `rsh "rm -f $Q/.stratum/git-guard.json"` with the same fail line. Check that `$Q` is set in `close` (call `quote` as other remote branches do).
- specs/008-herdr-workers/decisions.md - new D30 (below). Amend the D24 line (line 20): drop "Known gap, not fixed now", add the new cases and "close removes the file (D30)".
- specs/008-herdr-workers/plan.md - amend D24 (line 88) and S4 (line ~123) the same way: elsewhere cases, merge asks elsewhere, close removes the guard file.

## D30 text (draft)
D30 (change 001, guard gaps, 2026-10-23): `st-worker.sh close` deletes `.stratum/git-guard.json` from the worker folder (local `rm -f`, remote `rm -f` over ssh), after the working/blocked and open-PR refusals and before `workspace close`. If the rm fails, close is refused. Rejected: "auto only while worker-<id> is checked out", because the branch stays checked out after close and the hook would need herdr to know the worker is gone. Removed, not neutralized: the file is the repo file merged with `commit: auto`, no original is kept, and the folder is "ready to remove".

## Tests (written first, must fail before the build)
- tests/test_git_guard.py - new `test_commit_auto_elsewhere_forms`: with `commit: auto` file, each of `git --git-dir /x commit -m x`, `git --git-dir=/x commit -m x`, `git --work-tree /x commit -m x`, `git --work-tree=/x commit -m x`, `GIT_DIR=/x git commit -m x`, `GIT_WORK_TREE=/x git commit -m x`, `pushd /x && git commit -m x` asks. Plain `git commit -m x` still passes. `test_dash_c_commit_summary` stays green. - `python3 -m unittest tests/test_git_guard.py`
- tests/test_git_guard.py - new `test_merge_elsewhere_asks`: with `commit: auto`, `git -C /x merge b`, `cd /x && git merge b`, `GIT_DIR=/x git merge b`, `git -C /x pull`, `git -C /x cherry-pick c`, `git -C /x revert c`, `git -C /x am p` ask. `git merge b` and `git pull` in the folder give `(None, "")`. - same command
- tests/test_st_worker.sh - extend C1 with a new check `C1b`: before close, the worktree has `.stratum/git-guard.json` (start wrote it); after close it is gone. Add `R9b`: `sshs` contains `rm -f /home/u/proj-worker-t004/.stratum/git-guard.json` (or the `~/` form the stub gives). Stub ssh has no `rm` case, so it falls through and exits 0. R9 counts only workspace close and agent prompt, so no count changes. - `bash tests/test_st_worker.sh`
- Negative control (existing C2/C3/C9 refusals): add to C2 and C9 `[ -e "$(wt)/.stratum/git-guard.json" ]`, so a refused close keeps the file. Two asserts on existing tests, no new test.

## Risks
- R1: `env GIT_DIR=X git commit` makes `parse_git` return None (seg[0] is `env`), so no rule fires in any mode. `export GIT_DIR=X; git commit` has the same hole. Not in this plan (gate Q1: A, deferred).
- R3: `moved` is per command, not per segment. `pushd` is treated like `cd` the same way. Over-asks only, never under-asks.
- R4: A worker folder without `.stratum` (rare, manual removal) is fine, `rm -f` returns 0.

## Open questions for the gate
- Q1: cover `env GIT_DIR=X git commit` and `export GIT_DIR=X`? Option A: defer (listed in R1). Option B: parse `env`/`export` in `parse_git` (about 6 lines, one more test). Recommend A: the file's own parser cannot see shell state across commands, and B is a new class.
- Q2: cover `pull`/`cherry-pick`/`revert`/`am` with the same `elsewhere` check? Option A: merge only (asked). Option B: `sub in ("merge","pull","cherry-pick","revert","am") and elsewhere`, one line plus test cases. Recommend B: the code is the same one-line set, and the hole is the same.

## Item 4 (user, added after the build, 2026-10-23)
st-git commits as `cd <worktree root>; git commit` or `git -C <worktree root> commit`, so since cfa95c0 every st-git commit in a worker asks. `-C`, `cd` and `pushd` count as elsewhere only when the resolved target is another checkout. Resolve: track the dir across segments from the session cwd (`cd`/`pushd` targets joined in order, `-C` joined on top), realpath it, and compare `git rev-parse --show-toplevel` there with the session's. Different toplevel, a failed lookup, no session toplevel, or a target that cannot be read literally (`$`, backtick, glob chars, `cd` with no arg, `cd -`) is elsewhere. Toplevel equality, not a path prefix, so a nested repo or submodule inside the folder stays elsewhere. Same for merge/pull/cherry-pick/revert/am. `--git-dir`, `--work-tree` and the `GIT_DIR=`/`GIT_WORK_TREE=` prefixes stay elsewhere always. The staged summary reads from the resolved dir.
- Test (red first), tests/test_git_guard.py `test_commit_auto_same_checkout_paths`: commit auto; `cd <same worktree> && git commit -m x`, `git -C <same worktree> commit -m x` and `cd <same worktree>/deep && git commit -m x` pass; `cd <other checkout> && git commit -m x`, `git -C <other checkout> commit -m x`, `cd $X && git commit -m x` and `cd <nested repo inside the folder> && git commit -m x` ask.

## Review fixes (whole-file st-review, 2026-10-23)
- F1 `hooks/st-git-guard.py` segments: `lex.commenters = ""`, so a `#` line no longer hides the rest of the command.
- F2 cd/pushd targets: bash `cd` is logical (falls back to physical when the logical path is missing). Check both `normpath` and `realpath` of the target; elsewhere if either is another checkout. Track `here` as the logical path when it is a dir, else the physical one.
- F3 a shlex parse error asks ("could not parse the command") instead of dropping the rest.
- F4 `git -c core.hooksPath=...` is denied like `--no-verify`; `git -c alias.<x>=...` asks.
- F5 leading `command`, `builtin`, `exec` and `VAR=` words are skipped before the cd/pushd and git checks.
- F7 staged summary runs `git -c core.fsmonitor=false diff ...`, so a target repo's fsmonitor command does not run.
- F11 `scripts/st-worker.sh` close refuses when `$WT/.stratum` is a symlink (local and remote), before the rm.
- Dropped: F8 (measured 1-5 ms per call), F10 fixed by the orchestrator in .stratum/state.json. F6 goes to the user.

## F6 (user: close it, 2026-10-23)
A worker with commit auto could move the base branch from inside its own folder. Fix:
- `scripts/st-worker.sh start` writes `"branch": "worker-<id>"` into the worker guard file beside `"commit": "auto"` (local and remote).
- Hook: when the guard file has `branch`, commit auto and the in-folder merge family (merge, pull, cherry-pick, revert, am) pass only while `git symbolic-ref --short HEAD` in the resolved dir equals it; otherwise they ask. No `branch` key: behavior unchanged.
- Hook: a `git switch` or `git checkout` segment marks the rest of the command elsewhere (the branch is read before the command runs). Over-asks `git checkout -- f && git commit`; accepted.
- Hook: `git update-ref`, `git branch` with `-f`/`--force`/`-M`/`-C`, and `git fetch` with a `<src>:<dst>` refspec ask in every mode: each moves a local branch with no commit.
- Tests: tests/test_git_guard.py `test_commit_auto_needs_worker_branch` (guard file with branch; on that branch plain commit and merge pass; on another branch both ask; `git switch main && git commit` asks), `test_ref_moves_ask` (update-ref, branch -f, branch -M, fetch . a:main ask; branch -a and fetch origin pass). tests/test_st_worker.sh: S1/S1b/S1c/R1 expect the branch key.
- Build follow-ups (same class as F4 and F6): `git --config-env core.hooksPath=...` (both forms) denies; `git pull <remote> a:main` asks like fetch.
- Left open: `sudo`, `env`, `nice` prefixes and `GIT_CONFIG_PARAMETERS`/`GIT_CONFIG_COUNT` env prefixes (gate Q1 class).
