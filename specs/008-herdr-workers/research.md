# Research: Orchestrator Starts Worker Sessions

Checked on 2026-10-23 on this machine: herdr 0.9.4, Claude Code 2.1.302, jq 1.8.2, GNU bash 5.3.20,
OpenSSH 10.6p1, git 2.56.0. This session runs inside herdr (`HERDR_ENV=1`, pane `w1P:p1`). Only
read-only herdr calls were run: the group usage lines, `herdr --skill`, `herdr api schema --json`,
`agent list`, `agent get w1P:p1`, `agent read w1P:p1`, `worktree list --workspace w1P`,
`workspace list`, `machine list --json`. The laptop (`hyuse@100.73.64.64`) still times out on
port 22 (007 plan B1), so nothing was checked there.

Sources: spike #9 report (`specs/003-session-mods/research.md`), #32 (`specs/007-herdr-workspace`,
`scripts/st-herdr-workspace.sh`, `tests/test_herdr_workspace.sh`), `/goal` docs
(https://code.claude.com/docs/en/goal.md), auto mode docs
(https://code.claude.com/docs/en/auto-mode-config.md), `hooks/st-git-guard.py`, the #18 spec on
branch `18-codex-advisor`.

## R1. herdr calls and the JSON they give (lessons L5)

- Decision: the script uses only the calls in contracts/script.md section 4 and reads ids and
  states from the JSON paths below.
- Evidence: `herdr api schema --json` (the bundled schema) and the live calls above.
  - `worktree create` answers `type: worktree_created` with `.result.workspace.workspace_id`,
    `.result.tab.tab_id`, `.result.root_pane.pane_id`, `.result.worktree.path`,
    `.result.worktree.branch` (all required in the schema).
  - `agent start` answers `agent_started` with `.result.agent` (AgentInfo) and `.result.argv`.
    `timeout_ms` must be above 3000 and at most 300000.
  - `agent get` answers `agent_info`: `.result.agent.agent_status` is one of `idle`, `working`,
    `blocked`, `done`, `unknown`; `.result.agent.pane_id`, `.workspace_id`, `.cwd`, `.name`
    (live: `agent get w1P:p1`).
  - `agent list` answers `.result.agents[]` with the same AgentInfo fields; `.name` is null for an
    unnamed agent (live).
  - `agent read` answers `pane_read`: `.result.read.text`.
  - `workspace list` answers `.result.workspaces[]` with `workspace_id` and `label` (live).
  - `worktree list --workspace <ws>` answers `.result.worktrees[]` with `path`, `branch`,
    `open_workspace_id` (live, `--workspace w1P`).
  - The schema has no own result type for `agent wait`. The script does not parse its output: exit
    0 is "settled", exit 1 is an error (its JSON on stderr), and the state is read with `agent get`
    right after.
  - Error JSON is on stderr with exit 1; syntax errors exit 2 (`herdr --skill`). Codes seen in the
    binary and the skill: `agent_not_ready`, `agent_prompt_stalled`, `agent_blocked`, `timeout`,
    `agent_name_taken`. Seen live in T005: `linked_worktree_source` (R3), `agent_pane_busy`.
- Verified live (T005, second attempt, after the stop below): `close T900` printed
  `closed<TAB>worker-t900` and `folder<TAB>/home/hyuse/Desktop/stratum-worker-t900<TAB>ready to remove`,
  exit 0. `workspace close` on the workspace that `worktree create` made (`w1X`) did not ask for
  `--group`, and `w1X` is gone from `workspace list`.
- Live T005 (2026-10-23, quickstart section 2, from `/home/hyuse/Desktop/stratum-003-demo`, a
  linked worktree of `/home/hyuse/Desktop/stratum`): step 1 `worktree create --cwd
  /home/hyuse/Desktop/stratum-003-demo ...` failed at once (0.016 s) with
  `{"error":{"code":"linked_worktree_source","message":"New and open worktree actions start from the repo parent workspace."},"id":"cli:worktree:create"}`.
  `start` printed `stopped: <that line>` and `worker worker-t900 local - - - -`, exit 1. Nothing
  was made: no workspace, agent, branch or folder `worker-t900`. So `<repo>` = `git rev-parse
  --show-toplevel` breaks `start` in every linked worktree (each Stratum feature runs in one).
  The `workspace close` answer and `--group` stay not verified: the run stopped before them.
- Live T005, second attempt (2026-10-23 07:05:03, same folder, script with the R3 fix):
  `worktree create` from the main checkout worked (WS `w1X`, pane `w1X:p1`, branch `worker-t900`,
  `.result.worktree.path` `/home/hyuse/Desktop/stratum-worker-t900`). Then `agent start` failed:
  `{"error":{"code":"agent_pane_busy","message":"agent target pane w1X:p1 is not an available shell"},"id":"cli:agent:start"}`.
  `start` printed `stopped: <that line>` and
  `worker	worker-t900	local	w1X	w1X:p1	worker-t900	/home/hyuse/Desktop/stratum-worker-t900`,
  exit 1, 0.133 s in total. So `agent start` ran about 0.1 s after `worktree create`, before the
  new pane's zsh was at its prompt (`herdr --skill`: "An available shell pane must be at its
  interactive prompt"). Seconds later `pane process-info --pane w1X:p1` showed only `zsh`
  (pid 2784020, cwd the worker folder) in the foreground, so the pane does become available.
  New error code: `agent_pane_busy`. The script has no wait between the two calls; this breaks
  `start` on every run (finding to the orchestrator). The `workspace close` answer and `--group`
  stay not verified: the run stopped before them.
- Decision (orchestrator, small, after the second attempt): `start` step 3 retries `agent start`
  while herdr answers `agent_pane_busy`, `sleep 1` between tries, up to 10 tries. Any other error,
  or still busy after the 10th try, is the normal stop. `ponytail:` fixed 10 s bound, the shape of
  D20 in specs/007-herdr-workspace. Test cases S11 and S11b (contracts/script.md section 6).

## R2. Worker names, labels and branch (FR-001, FR-016)

- Decision: the request names a task id (`T004`). The script makes the worker name
  `worker-<id in lower case>` (`worker-t004`). That one string is the herdr agent name, the
  workspace label, the branch, the Claude session name (`-n`) and the folder suffix. The id must
  match `^[A-Za-z0-9][A-Za-z0-9-]{0,24}$`, so the name fits herdr's `[a-z][a-z0-9_-]{0,31}`.
- Rationale: herdr agent names cannot hold capitals; one string per worker lets `list` find a
  worker by its label prefix `worker-` after the orchestrator session ended, with no state file.
  `-n` makes the session show under that name in ListAgents, which is how SendMessage reaches it
  (spike test 3: ListAgents listed the `-n` name).
- Alternatives: a state file in `.stratum/` listing workers. Rejected: herdr already holds every
  fact, and a file goes stale when a pane is closed by hand.

## R3. Worktree folder and base (FR-001, D15)

- Decision: `H worktree create --cwd <repo> --branch <name> --base <sha> --path <path> --label <name> --no-focus`.
  `<repo>` here is the main checkout, `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`,
  or `--repo` on a saved machine. `<path>` is `<repo parent>/<repo name>-<name>`, the
  `st-worktree.sh` shape, from that `<repo>`. `<sha>` is `git rev-parse HEAD` of the calling
  folder, for both machines. The guard file (D24) is read from the calling folder's
  `git rev-parse --show-toplevel`. Every later step uses `.result.worktree.path` from the answer, never
  the computed path (L19).
- Rationale: `~/.config/herdr/config.toml` sets no worktree folder and herdr's default is not
  documented, so the path is given. The base is the orchestrator's commit so the worker starts
  from the committed spec and tasks. On the laptop, a base that is not in its repo makes herdr
  fail: the script stops with herdr's line. It never pushes to make the commit appear (spec
  Assumption: nothing is pushed).
- Live (T005, 2026-10-23, see R1): `worktree create --cwd /home/hyuse/Desktop/stratum-003-demo`, a
  linked worktree, failed with `{"error":{"code":"linked_worktree_source","message":"New and open worktree actions start from the repo parent workspace."}}`
  in 0.016 s, nothing made. `herdr worktree list` from that pane gives
  `source: {repo_root: "/home/hyuse/Desktop/stratum", source_workspace_id: "w1G"}`. Rule: herdr
  makes worktrees only from the main checkout, so `--cwd` is the main checkout, and the worker
  folder sits next to it (`/home/hyuse/Desktop/stratum-worker-t900`). Test case S10.
- Live T005, second attempt: the R3 rule holds. `worktree create --cwd /home/hyuse/Desktop/stratum`
  made `/home/hyuse/Desktop/stratum-worker-t900` on branch `worker-t900` at `17bc17f` (the demo
  worktree's HEAD), with `brief.md` and `.stratum/git-guard.json` = `{"commit":"auto"}` written.
- `--trust-repository` is never passed (`herdr --skill`: only after the user has verified the
  repository). An untrusted-repository error is a stop line.

## R4. Folder trust for `claude` in a new worktree

- Finding: `~/.claude.json` has a `projects` entry, with `hasTrustDialogAccepted: true`, for
  `/home/hyuse/Desktop/stratum` and none for `stratum-003`, `stratum-18` or `stratum-22`, where
  `claude` runs every day with no dialog. So Claude Code keys a linked worktree to its main repo,
  and a new worker worktree of a trusted repo starts with no trust dialog.
- Decision: no trust step. If a dialog still shows, `agent start` answers `agent_not_ready` and
  the script reports the worker `blocked` with the pane text (FR-006 path). The skill handles it as a question (a trust dialog is an access decision, so it goes to the user, D26),
  then sends the prompt with the `goal` subcommand.
- Not verified live. Quickstart section 2 records whether a dialog showed.
- Live T005: `start` exit 1 at `worktree create` (`linked_worktree_source`, R1). `claude` never
  started, so the trust dialog is still not verified.
- Live T005, second attempt: `start` exit 1 at `agent start` (`agent_pane_busy`, R1). `claude`
  never started (`agent get worker-t900`: `agent_not_found`), so the trust dialog is still not
  verified.

## R5. The one prompt and `/goal` (FR-003, D21)

- Decision: `H agent prompt <name> "<prompt>" --wait --until working --until blocked --timeout 30000`,
  where `<prompt>` is
  ``/goal `<test command>` exits 0, the change is committed on branch <name>, and result.md is written; read brief.md in this folder first and follow it``.
  The script refuses a prompt over 4,000 characters.
- Rationale: `/goal` starts a turn at once with the condition as the directive (goal.md "Set a
  goal"). The evaluator reads only the transcript, so each part is something the worker's own
  output shows: the test run, `git log`, the file write (goal.md "Write an effective
  condition"). `--wait --until working --until blocked` returns as soon as the worker took the
  prompt; with no activity in 5 s herdr returns `agent_prompt_stalled` (`herdr --skill`). That is
  a stop line, not a retry: herdr says a stalled prompt may still have been delivered.
- `/goal` needs auto mode to run unattended (goal.md), so the worker starts with
  `--permission-mode auto` (D21). Auto mode still prompts on explicit ask rules and on a
  PreToolUse hook's ask (auto-mode-config.md, "Add a human checkpoint").
- Not verified live: that a pasted `/goal ...` runs as the slash command through
  `agent prompt` (bracketed paste). Quickstart section 2.
- Live T005: not reached; `start` stopped at `worktree create` (R1). `◎ /goal active` not seen.
- Live T005, second attempt: not reached; `start` stopped at `agent start` (`agent_pane_busy`,
  R1). `◎ /goal active` not seen.

## R6. Waiting (FR-004, D13, D14)

- Decision: `wait` loops up to 540 s in total:
  1. `H agent wait <name> --timeout <ms left>`. A `timeout` error ends the call with `working`.
  2. `H agent get <name>`: `blocked` ends with the question (R7).
  3. `idle` or `done`: if `result.md` exists in the worktree, `finished`. If not,
     `H agent wait <name> --until working --until blocked --timeout 10000`; a match goes back to
     step 1, else `stopped` with the pane text.
- Rationale: the Bash tool's foreground cap is 600 s, so one call returns before it. Between two
  `/goal` turns the evaluator runs as a Stop hook, and herdr may show `idle` for a moment; only
  the result file means finished (D13). The 10 s check stops a short idle from reading as a stop.
  No step sends a prompt (FR-004). `ponytail:` 540 s and 10 s are constants; quickstart section 2
  measures the gap between goal turns.
- Alternatives: `agent prompt --wait` as the wait. Rejected: D13 names the prompt wait, but a
  second prompt is a re-prompt (FR-004), and the one prompt already returns at `working`.
- Live T005: not reached; `start` stopped at `worktree create` (R1). No `state` line, no idle gap measured. D24 commit and guard file not checked: no worker worktree was made.
- Live T005, second attempt: not reached; `start` stopped at `agent start` (`agent_pane_busy`,
  R1). No `state` line, no idle gap measured. D24: the guard file was written
  (`cat /home/hyuse/Desktop/stratum-worker-t900/.stratum/git-guard.json` gives `{"commit":"auto"}`),
  but no worker ran, so the commit with no dialog is not verified.

## R7. Questions and answers (FR-006, D14, US2)

- Decision: the brief tells the worker to ask only with the AskUserQuestion tool. On
  `blocked`, `wait` prints the last 40 lines of `H agent read <name> --source recent-unwrapped`.
  `answer <id> --keys <key>...` sends `H agent send-keys <name> <key>...`; `answer <id> --text <text>`
  sends `H pane send-text <pane> <text>` then `H agent send-keys <name> enter`. Both first run
  `agent get`; a state other than `blocked` sends nothing and prints `not blocked: <state>`.
- Rationale: `agent prompt` rejects a blocked agent with `agent_blocked` before sending input
  (`herdr --skill`), so an answer to a dialog must be keys or text. A question asked in plain text
  ends the turn as `idle`, not `blocked`, and the `/goal` loop starts the next turn on its own, so
  the question would never reach the orchestrator. The state check is what keeps a second answer out when
  the user already answered in the pane (US2 scenario 3).
- A permission prompt (Stratum's commit guard, `hooks/st-git-guard.py:144-150`: `ask` unless the
  worktree's `.stratum/git-guard.json` says `auto`) shows as `blocked` the same way (US2
  scenario 4). D24: `start` writes the repo's own `.stratum/git-guard.json` (or `{}`) with
  `"commit": "auto"` set, as one line, to the worker worktree's `.stratum/git-guard.json`, so
  per-repo keys such as `"force_push": "deny"` carry over and a plain commit there does not ask; amend, push, `reset --hard` and
  branch delete still ask. The guard reads that file because it walks up from the cwd to the first
  folder with `.stratum/` or `.git` (`hooks/st-git-guard.py:105-114`), which is the worktree root.
- D26: the skill, not the script, decides each question with the `/stratum:st` rule: a small one
  it answers at once, a big one goes to the user first; it lists its own answers at the end of the
  run. The script does not change: `answer` sends what it is given.
- Not verified live: that herdr marks Claude Code's AskUserQuestion dialog `blocked`, and which
  keys pick an option or reach the free-text field. Quickstart section 3.

## R8. Result and fetch (FR-005, FR-007, D13)

- Decision: `result` finds the worktree path (R10), then reads `<path>/result.md`: `cat` here,
  `ssh -o BatchMode=yes -- <target> cat -- <quoted path>/result.md` on a saved machine. For a
  saved machine it then runs `git fetch <target>:<path> <name>:<name>` here. A missing file
  prints `no result file: <path>/result.md`, then the last 40 pane lines marked as pane text, and
  exits 1 (no merge).
- Rationale: D13 and FR-005: the file is the result, the pane is a fallback for a look. `git fetch`
  over ssh uses the same saved target; without `+` it refuses to move an existing local branch
  that is not a fast-forward.

## R9. Cross-machine reach (FR-007, FR-008, D16)

- Facts: the roster names machines by the orchestrator's labels (`local`, `laptop`). A worker on
  the laptop reaches a PC teammate with `herdr --machine <label>` only if the laptop has a saved
  profile for the PC, under a label the orchestrator cannot see while the laptop is down. This PC
  runs `sshd` on port 22 (tailscale 100.100.106.106), but whether the laptop holds a key for it is
  unknown.
- Decision for messages: the rule text gives both paths (SendMessage by name on the same machine,
  `herdr --machine <label> agent prompt <name> "<text>"` on another machine, with `<label>` from
  `herdr machine list` on the worker's own machine).
- Decision for git (D25): tasks that build on each other run on one machine, where worktrees
  share every branch. Teammates on different machines only exchange messages; no commit crosses
  machines. The skill places a task that builds on a teammate's work on that teammate's machine.

## R10. Finding workers again (FR-016)

- Decision: `list` reads `H workspace list` and keeps labels that start `worker-`, then
  `H agent list` for each name's state and pane, then `H worktree list --workspace <ws>` for the
  path (`open_workspace_id == ws`). Every subcommand after `start` finds its worker the same way,
  from the id alone, so a new orchestrator session needs no file.
- Rationale: all three calls were run live and their fields are in R1.

## R11. Close (FR-010, FR-012, D18)

- Decision: `close` refuses while the worker is `working` or `blocked`, with the line
  `Worker <N> is <state>. Close refused.` Else it runs
  `H workspace close <ws>` on the one workspace whose label is the worker name, then checks that
  `agent list` has no agent of that name and `workspace list` no label of that name, and prints
  the folder as ready to remove. It never runs `worktree remove`, `pane close`, `--group`,
  `machine reconnect` or `server stop`.
- Rationale: closing the workspace ends its pane and the `claude` in it; the transcript stays on
  disk (spike test 3). herdr's rule "never close what you did not create" holds because the label
  is the script's own `worker-` name. `ponytail:` no process check in the script; quickstart
  section 2 checks `pgrep` live.
- Live T005: `close` not run; `start` stopped at `worktree create` (R1). After the stop, `agent list` and `workspace list` held no `worker-t900` (grep exit 1 each); `agent read worker-t900` answered `agent_not_found`.
- Live T005, second attempt: `close` not run (the run stops at a `start` exit 1). Left open:
  workspace `w1X` `worker-t900` (in `workspace list`), its pane `w1X:p1` with a bare `zsh`, folder
  `/home/hyuse/Desktop/stratum-worker-t900`, branch `worker-t900`. `agent list` has no
  `worker-t900`; `pgrep -af -- '-n worker-t90[0]'` exit 1 (no `claude`).

## R12. Headless worker (FR-011, D12, D19)

- Decision:
  `timeout 540 claude -p "<prompt>" --output-format json --max-turns 30 -n <name> --tools Read,Edit,Write,Glob,Grep,Bash --allowedTools Read Edit Write Glob Grep "Bash(<test command>)" --permission-mode dontAsk --permission-prompts none --strict-mcp-config`,
  run in the project root. The prompt is
  ``/goal `<test command>` exits 0 and the change is left uncommitted; read <brief path> first and follow it``.
  The brief is a `mktemp` file outside the repo, removed on exit. The script prints
  `subtype`, `num_turns`, `total_cost_usd` and `result` from the JSON. It records `HEAD` before
  and after; a moved `HEAD` prints `worker committed: <old> -> <new>` and exits 1.
- Rationale: spike test 3 proved `claude -p --output-format json` with `-n`, `--max-turns` and
  `--strict-mcp-config`, and the JSON keys `type`, `subtype`, `is_error`, `result`,
  `session_id`, `num_turns`, `total_cost_usd`. `--tools` takes AskUserQuestion, SendMessage and
  Agent out of reach (no question tool, D14). `dontAsk` denies every call not allowed, and
  `--permission-prompts none` denies anything that would still prompt (`claude --help`), so the
  only shell command is the test command and no commit can run (L10: the tool list is the
  guard). The `HEAD` check is the second guard and can fail.
- The test command must be one line with no `(` or `)`, so it fits inside `Bash(...)`.
- `ponytail:` 540 s and 30 turns are constants.
- `/goal` docs (https://code.claude.com/docs/en/goal.md): "A goal doesn't change your permission
  mode", and "`/goal` works in non-interactive mode ... Setting a goal with `-p` runs the loop to
  completion in a single invocation". So `/goal` under `-p --permission-mode dontAsk` is expected
  to run, with a denied call failing instead of asking. If it does not start under `-p`, the
  fallback is a plain prompt with no `/goal`, and the finding goes to the orchestrator (T015).
- Not verified live: how `--max-turns` counts `/goal` turns, and the `subtype` when the turn
  limit ends the run. Quickstart section 5.

## R13. Brief and advisor line (FR-002, D21)

- Decision: the script writes the brief from its inputs and fixed text (contracts/script.md
  section 3). The advisor line is written only when `scripts/st-advisor.sh` exists next to
  `st-worker.sh`.
- Rationale: #18 (`18-codex-advisor`) is not merged; when it is, `scripts/st-advisor.sh` lands next
  to this script and the lane skills name the advisor points (#18 FR-001, FR-016). The worker runs
  the same plugin, so the line names the script, not a path on one machine.
- The brief also tells the worker not to edit `tasks.md` or `.stratum/state.json`. Two workers that
  tick adjacent task lines would make the merge conflict; the orchestrator ticks after the merge.
- The brief tells the worker to start its lane through the Skill tool (lessons L12) and to run only its own task: `st-build` works every unticked task in order, so a worker for T005 would start on an unticked T004.
- The headless brief says to run the test command exactly as written, as one Bash call: `Bash(<test>)` is an exact-match allow rule.

## R14. Merge and review (FR-009)

- Decision: the skill, not the script, reviews and merges, because `st-review` is an agent. Per
  worker, in task order: `result` (and fetch), `/stratum:st-review <base>..<branch>` through the
  Skill tool, check findings, for a worker on this machine run the test command in its worktree,
  then `git merge --no-ff --no-edit <branch>` and the test command here. A conflict: list the
  files, `git merge --abort`, bring them to the user, merge nothing after it.
- Test: an ordered phrase check on the skill text in `tests/test_on_demand.sh` (FR-015 covers the
  order, not a stub run).

## Open decisions

None. D24 (R7) and D25 (R9) are settled in decisions.md.
