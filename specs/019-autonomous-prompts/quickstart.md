# Quickstart: 019 autonomous prompts

## 1. Unit tests (any machine)

Run from the repo root. Each must exit 0.

| Story | Command |
|-------|---------|
| US1 | `bash tests/test_st_worker.sh` |
| US2 | `python3 tests/test_git_guard.py` and `python3 tests/test_approve_hook.py` |
| US3 | `bash tests/test_update_rules.sh`, `bash tests/test_session_hooks.sh`, `bash tests/test_st_worker.sh` |
| US4 | `bash tests/test_codex_agent.sh` and `bash tests/test_advisor_matrix.sh` |

Cases: `contracts/dialog-block.md` §4, `contracts/commit-form.md` §4b and §5, `contracts/git-instructions.md` §7, `contracts/codex-log.md` §4.

## 2. Live check before merge (FR-015, D7)

Who: the user, with the orchestrator. Where: a herdr workspace on this machine, the branch checked out, the plugin loaded from it (`claude --plugin-dir <repo>` or the dev install). A Codex tab must be logged in. Write down the result of each step in the PR body.

Pass for SC-001: in steps L1 and L2 the user presses no key in any worker tab. Any key press in a worker tab is a fail of that step.

### L1. A heredoc commit is denied, retried with `-m`, and reaches the orchestrator in full

1. Start one worker in autonomous mode with a task that edits one owned file and commits it. In the task text, tell the worker to commit with a heredoc message: `git commit -m "$(cat <<'EOF'` ... `EOF` `)"`.
2. Expect in the worker pane: the git guard deny with the text of `contracts/commit-form.md` §3, then a new commit call of the form `git commit -m '<subject>' -m '<body>'`.
3. Expect in the orchestrator: `wait` exits 6 with `state approval`, an `input` line that holds the whole `-m` command, a `branch` line `worker-<id>` and a `staged` line with the owned file. Nothing about the commit is cut off.
4. Expect `wait` to print an `inputhash` line right after the `input` line. The orchestrator approves it with `approve <id> --request <rid> --input-hash <that hash> --record <file>` (no heredoc, D17), and the git guard does not deny that call. Expect: the commit exists on the worker branch (`git log -1 --format=%s worker-<id>` shows the subject).

Pass: steps 2-4 as written, no key press in the worker tab.

Result: pass. Deny, `-m` retry, approve by `--input-hash`, commit landed.

### L2. `answer` works on a worker whose screen keeps changing

0. Check the commit mode first: the worker's git guard must ask for a commit. `jq -r .commit .stratum/git-guard.json` (or the plugin option when that file has no `commit` key) must print `ask`. If it prints `auto`, set it to `ask` for this check, else no commit dialog shows.
1. Start one worker in normal mode (no `--autonomous`, so every dialog stays in the pane). Its task: start a background agent that works for some minutes (its status lines keep changing), then commit one owned file with `git commit -m '<subject>' -m '<body>'`. The git guard asks, so the commit dialog shows in the pane.
2. Expect: `wait` prints a `screen` line. Between `wait` and `answer`, lines above the dialog change (the background agent's status).
3. The orchestrator runs `answer <id> --screen <hash> --keys <one-time yes>`.

Pass: `answer` exits 0 or 4 with the `state` line and the dialog closes. It does not print `The pane shows another prompt` or `The top of the dialog is not on the screen, so only its No can be sent`. If it prints either, copy the 40-line pane text into the PR: the dialog may have no `─` top rule at column 0 in this Claude Code version (research P1 then falls back to mode `cut`, which allows only a No).

Result: pass with note. The first `answer` was refused because the dialog was still drawing; the second, with the fresh hash, worked. A dialog answered while lines above it keep changing was not observed.

### L3. A Codex answer with backticks and `"` comes back exact

1. Run a Codex advisor point in the tab (for example `bash <plugin root>/scripts/st-advisor.sh change specs/019-autonomous-prompts <a change file>`) whose review is likely to quote code: put a line with `` `x` ``, a `"` and a `\` in the change file and ask Codex to quote it in a finding.
2. Expect: the last line `codex: tab st-codex-<workspace label>`, and the recorded finding in `advisor.md` holds the backticks, the `"` and the `\` exactly as in the `task_complete.last_agent_message` of the newest rollout file (compare with `python3 -I` reading that file, read-only).
3. Measure: the time from the tab going idle to the `task_complete` line's `timestamp`. It must be under 15 s (the reader's tries). Write it in the PR.
The no-log path is not run live: pointing `CODEX_HOME` at an empty folder would also log the headless `codex exec` out, and copying `auth.json` to a temp folder copies a credential. `tests/test_advisor_matrix.sh` M19 and M25-M27 cover it.

Pass: step 2 has 0 changed characters (SC-004), step 3 is under 15 s.

Result: pass. Backticks, `"` and `\` came back exact from the log; lag about 1 s.

### L4. Settings scope (US3)

1. In a temp project, run `/stratum:st-init` four times from a clean copy and pick each scope in turn (project, user, local, not at all). Use a temp `CLAUDE_CONFIG_DIR` for the user pick.
2. Expect: only the chosen file has `"includeGitInstructions": false`, other keys unchanged; "not at all" leaves all three files without the key and writes the empty `.stratum/git-instructions-kept`.
3. In an older project with no setting and no marker, run `/stratum:st-update`: it asks once. Run it again after a project pick, and again after a "not at all" pick: it does not ask.
4. In a project with no setting, run `bash <plugin root>/scripts/st-worker.sh autonomous-on`: the on line and the `hint` line print, exit 0. Set the project pick and run it again: only the on line. Run `autonomous-off` after each.

Pass: as written.

Result: step 4 pass (the hint shows; it does not show with the setting off). Steps 1-3 not run: skipped by the user.
