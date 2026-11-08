# Quickstart: check autonomous mode per session

Rules: `contracts/autonomous-mode.md`. Layout: `data-model.md`.

## Automated

Run from the repo root. Each file runs alone and uses only temp folders.

| Check | Command | Expect |
|---|---|---|
| Statusline, two sessions in two linked worktrees both show `autonomous` | `bash tests/test_statusline.sh` | no `FAIL` line, exit 0 |
| Approve hook routing per session, lock 2 on entries | `python3 tests/test_approve_hook.py` | `OK` |
| Worker script check, saved-machine write, off for one session only | `bash tests/test_st_worker.sh` | no `FAIL` line, exit 0 |
| Skill and README sentences | `bash tests/test_worker_rules.sh` | no `FAIL` line, exit 0 |
| Harness model and atlas | `bash tests/test_harness_model.sh` | no `FAIL` line, exit 0 (`validate` and `rebuild` need node 22.22.3 or later, else `SKIP`) |

Whole suite (once, at the end):

```bash
for f in tests/test_*.sh; do bash "$f" || exit 1; done; for f in tests/test_*.py; do python3 "$f" || exit 1; done
```

## By hand (two herdr workspaces)

Prerequisite: this branch is the installed plugin, two linked worktrees of one repo, each with its own orchestrator session in its own herdr workspace.

1. In session 1 say `autonomous mode`. Expect `Autonomous build mode: on for this run` and `autonomous` in its statusline.
2. In session 2 say `autonomous mode`. Expect the same. Session 1 still shows `autonomous`.
3. `ls <main checkout>/.stratum/autonomous/` shows two files, one per session id.
4. Start one worker per session with `build with workers`. A permission prompt of each worker goes to its own orchestrator (an `approval` state in that session's `wait` or `watch`).
5. In session 1 say `stop autonomous`. Expect `autonomous off	local` and `Autonomous build mode: off`. Session 2 still shows `autonomous`, and the folder holds one file.
6. In session 2 say "I will continue later". Expect the off lines before the handoff is written, and an empty folder.
