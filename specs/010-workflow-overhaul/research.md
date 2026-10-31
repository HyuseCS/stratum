# Research: Workflow Overhaul

Tool versions on this machine (2026-10-31): `claude --version` = `2.1.312 (Claude Code)`,
`codex --version` = `codex-cli 0.166.0`, `herdr --version` = `herdr 0.9.4`,
`bash --version` = `GNU bash, version 5.3.20(1)-release`.

Live probes ran in the orchestrator's own herdr workspace (`w13`), each in a new tab that was
closed after the probe. Scratch files: `<scratchpad>/ra/` (R-A) and `<scratchpad>/rc/` (R-C).

## R-A. Can a worker's permission hook hand a prompt to the orchestrator and wait for the answer?

- Decision: Yes. Use a `PermissionRequest` hook. FR-019 needs no fallback.
- Evidence (binary help text, `strings /opt/claude-code/bin/claude`):

  ```text
  PermissionRequest:{summary:"When a permission dialog is displayed",description:`Input to command is JSON with tool_name, tool_input, and tool_use_id.
  Output JSON with hookSpecificOutput containing decision to allow or deny.
  Exit code 0 - use hook decision if provided
  ```
  and `(PermissionRequest decision must be {"behavior": "allow"} or {"behavior": "deny", "message": "..."})`.
  The string `PermissionRequest hook failed before a hook's ask for` shows the hook also runs
  after a PreToolUse hook's `ask` (the git guard's case).
- Evidence (live, 2026-10-31 11:56): a claude session started with
  `herdr agent start ra-probe --kind claude --pane w13:p7 -- --permission-mode auto --settings <scratch>/settings.json --model sonnet`.
  The settings had a PreToolUse Bash hook that answers `ask` for `ra-probe`, and a
  `PermissionRequest` hook (`timeout: 300`) that saves its input and waits for a file `ok`.
  1. The hook fired in auto mode. Its saved input (transcript path removed):
     `{"session_id":"315eace7-…","cwd":"<scratch>/ra","permission_mode":"auto","hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"echo ra-probe > <scratch>/ra/out.txt","description":"Write probe text to file"}}`.
     There is no `tool_use_id` field, although the help text names it.
  2. While the hook waited, the dialog was on screen at the same time
     (`Hook PreToolUse:Bash requires confirmation for this command: ra test ask` … `Do you want to proceed? ❯ 1. Yes 2. No`),
     and `herdr agent get` said `blocked` at every 5 s check from 5 s to 40 s.
  3. At 75 s (`elapsed=75`) the probe wrote `ok`. The hook printed
     `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`,
     the dialog closed, `out.txt` held `ra-probe`, and the agent went on (`done`).
- Consequences for the design:
  - A hook wait of at least 75 s works. The cap for a command hook's `timeout` was not found in
    the binary. The plan uses a 300 s wait (`timeout: 310`); T034 measures it live.
  - The user can answer the dialog while the hook waits. A request the orchestrator never answers
    stays for the user (spec edge case), with no extra code.
  - `st-worker.sh wait` sees `blocked` while the hook waits, so `wait` must look for a request
    file before it reports `blocked` (contracts/scripts.md section 4).
  - The request id cannot come from `tool_use_id`. The hook makes its own id.
- Plugin copy in use (F9): `~/.claude/plugins/installed_plugins.json` lists `stratum@stratum` for
  this project at `installPath` `.../cache/stratum/stratum/0.2.1`, while
  `known_marketplaces.json` gives the marketplace as `{'source': 'directory', 'path': '/home/hyuse/Desktop/stratum'}`.
  So a live run can load an old hook. quickstart section 0 has the probe and the reload step
  (`claude --help` lists `--plugin-dir <path>  Load a plugin from a directory or .zip for this session only`).
- Not verified: the probe registered the hook with `--settings`. The plan registers it in the
  plugin's `hooks/commands.json`. T034 checks that the plugin hook fires. Contingency: `start
  --autonomous` passes `--settings <generated file>` with the same hook command to
  `agent start`.
- D29: no fallback to permissions the user grants. If neither the plugin hook nor the
  `--settings` hook fires, autonomous mode stays off.
- Alternatives considered: the fallback "permissions the user grants at worker start"
  (`--allowedTools` at `agent start`). Not needed, because the hook works.

## R-B. How does the orchestrator send its answer so the classifier sees it?

- Decision: The orchestrator runs `bash <plugin root>/scripts/st-worker.sh approve <id> --request <rid> --input-stdin --record <file>` with the input text
  in a quoted heredoc (`<<'ST_INPUT_END'`), so `$(...)` and backticks in it never run
  in its own Bash tool. That call writes `<worktree>/.stratum/approve/<rid>.ok`. The worker's
  hook reads the file and answers `allow` one time. The orchestrator's permission check (its
  classifier in auto mode, or the user in default mode) sees the call, its name, the request
  id and the full command it approves (the heredoc text, checked byte for byte against the `.req`) in plain text.
  `st-worker.sh` must never be on a permission allow list, or no check is left. If that check blocks the call, nothing is written, the hook times out with
  no decision, and the dialog stays for the user. That is D1's "tries no other way" by
  construction. The hook never answers `deny`.
- Rationale: one visible command per approval, no send-keys into the dialog (rejected O4), and a
  file channel that `rsh` already reaches on a saved machine.
- Guard: `approve` refuses unless the main checkout's `.stratum/autonomous` (found through the git
  common dir) holds the caller's
  `$CLAUDE_CODE_SESSION_ID`. Evidence: `env` in this session shows
  `CLAUDE_CODE_SESSION_ID=a5645c15-5e7e-448a-bb3c-12b611437958`, the same id as the session's
  scratchpad folder. This variable is not in the public docs. If a later Claude Code drops it,
  `approve` refuses and every prompt goes to the user (safe side).
- D27 adds two locks against a worker approving itself. (1) The `PermissionRequest` branch acts
  only while the main checkout's `.stratum/autonomous` (found with `git rev-parse --git-common-dir`)
  holds the same session id as the worktree's `.stratum/approve/session`, which `start
  --autonomous` writes. A worker cannot change the main checkout's file through a path in its
  own tree, and normal mode, a stale folder or "stop autonomous" leave every prompt for the user.
  (2) A `PreToolUse` branch of the same hook denies a Bash command, Edit or Write that touches
  `.stratum/approve/`. Remote workers (D28): `start --autonomous --machine` writes the session id into that
  machine's main checkout `.stratum/autonomous` over the existing `rsh` path, and
  `autonomous-off` removes it at the end of the run, so the hook on that machine checks the same
  rule.
- Alternatives considered: `herdr agent send-keys` on the dialog (rejected by D1, O4); a hook
  `deny` with a message (it would stop the worker's tool call instead of leaving it to the user).

## R-C. Codex as an interactive herdr agent

- Decision: Start Codex once per workspace and feature with
  `herdr agent start st-codex-<NNN> --kind codex --pane <pane> --timeout 120000 -- -s read-only -a never --no-alt-screen [-m <model>] [-c model_reasoning_effort="<effort>"]`
  in a new tab labelled `Codex`. Send each review as a short prompt that names a prompt file.
  Read the answer with `herdr agent read <name> --source recent-unwrapped --lines 400`, take
  the last pair of exact marker lines, and join the lines between them with one space.
- D25 changes the config part below: the tab gets its own `CODEX_HOME` (R-J), so the user's
  config is not read there.
- Evidence, flags (`codex --help`): `-s, --sandbox <SANDBOX_MODE> [possible values: read-only, workspace-write, danger-full-access]`,
  `-a, --ask-for-approval … never: Never ask for user approval`, `--no-alt-screen … preserving terminal scrollback history`.
  The TUI has no `--ignore-user-config`, no `--ephemeral` and no `--output-schema`: those are
  `codex exec` flags only (`codex exec --help`). So in herdr, `~/.codex/config.toml` applies
  (model, hooks), the session is saved under `~/.codex/sessions/`, and the JSON shape is checked
  only by `st-advisor.sh`'s validator.
- Evidence, start (live 11:59): `{"agent":"codex","agent_status":"idle",…,"interactive_ready":true,"name":"st-codex","pane_id":"w13:p8",…}`.
  The folder was already trusted in `~/.codex/config.toml` (`[projects."/home/hyuse/Desktop/stratum"] trust_level = "trusted"`).
  An untrusted folder may show a trust dialog at start. The live claude probe hit the same kind
  of dialog: `{"error":{"code":"agent_not_ready","message":"agent ra-probe is blocked during startup and is not ready for prompts"}}`.
  So `agent_not_ready` at Codex start ends as `BLOCKED` with a line that names the tab.
- Evidence, review (live): `herdr agent prompt st-codex "Read the file <scratch>/rc/prompt.md and follow it." --wait --until idle --until done --until blocked --timeout 540000`
  returned `done` after 19.4 s. Codex ran `rg` and read files in the read-only sandbox with no
  prompt. The screen showed:

  ```text
  • ST-ADVISOR-BEGIN-k7Q2x9
    {"verdict":"APPROVED","summary":"The file defines a function named project_root.","findings":[{"claim":"The file /home/hyuse/
    Desktop/stratum/scripts/common.sh defines a function named project_root.","evidence":"Line 5 contains the explicit Bash
    function declaration project_root() {, …
    ST-ADVISOR-END-k7Q2x9
  ```
  Codex wraps long lines itself, so `recent-unwrapped` cannot undo the wrap. Sometimes the
  wrap is at a space (`Bash` / `function`) and sometimes it is not (`/home/hyuse/` /
  `Desktop`). Stripping `•` and leading spaces from each line and joining the lines with one
  space gave valid JSON: `APPROVED /home/hyuse/Desktop/stratum/scripts/common.sh:5`. Inside
  string values, a wrap that was not at a space now has a stray space
  (`The file /home/hyuse/ Desktop/…`). Verdict and severity values have no spaces, so they are
  exact.
- Evidence, prompt echo: the pane showed only the short prompt (`Read the file … and follow it.`),
  not the marker lines. The prompt file holds the markers. Codex may show part of the file in a
  tool output, so the parser takes the last exact pair.
- Evidence, new conversation: `herdr agent prompt st-codex "/new"` answered
  `agent_prompt_stalled` and opened a dialog (`Where should the new conversation run? › 1. Use current Git worktree`).
  After that dialog was answered, the question "What claim did you review earlier in this
  conversation?" got `• NONE`. `/new` works, but it needs a second key for a dialog. Decision:
  for a new feature, close the old `st-codex-*` tab (`herdr tab close <tab>`) and start a new
  agent. One code path serves a new feature and a tab the user closed.
- Evidence, workspace scope: `herdr agent list` gives each agent `workspace_id`, `tab_id` and
  `name`, so "one Codex agent per workspace" is a filter on `workspace_id` and the name prefix
  `st-codex-`.
- Risk: the lines `recent` keeps were not measured. A review with many findings may have more
  than 400 lines on screen. T024 measures a real plan review.
- Alternatives considered: read Codex's session file (exact text, but herdr gives no session id
  for codex (`"agent_session":null`), and the newest-file guess fails with two Codex sessions);
  `codex exec` in the tab (rejected O25).

## R-J. A Stratum-owned Codex home for the tab (D25)

- Decision: the tab runs with `CODEX_HOME=${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-home`,
  set with `herdr tab create --env CODEX_HOME=<dir>` (an option `herdr tab create --help` lists:
  `--env <KEY=VALUE> Set an environment variable for the launched process`). The folder holds
  only `auth.json`, a symlink to the user's `~/.codex/auth.json`. `st-advisor.sh codex-home`
  makes it, and only when the user opts in to a Codex advisor.
- Why there: it is outside every repo, so no `.gitignore` entry is needed and it can never be
  committed. It is not inside the project tree, which here is synced (`.stfolder` and
  `.stignore` at the repo root): a symlink to the login inside the project would travel to other
  machines. One folder per user means one login link for every project. `$HOME` exists in Git
  Bash too.
- Rejected: `<project>/.stratum/codex-home/` (inside the tree, synced, needs a git-ignore rule
  in every project); a temp folder per run (a new Codex session folder each time, and the tab
  outlives one run).
- Not verified yet, so T050 probes it live before any adapter build:
  1. the TUI starts with that `CODEX_HOME` and is logged in (no login screen, a prompt gets an
     answer);
  2. it loads no user setting: the footer model is not the user's `GPT-6-Astra xhigh`
     (`~/.codex/config.toml`: `model = "gpt-6-astra"`, `model_reasoning_effort = "xhigh"`);
  3. a scratch project's `.codex/config.toml` with a canary `notify` command and a canary MCP
     server (each touches a file) does not fire;
  4. whether a trust dialog shows for the project, and what answering "do not trust" does;
  5. after the run, `auth.json` is still a symlink (Codex may replace it with a copy when it
     refreshes the token, which would leave the user's own login stale), and
     `codex login status` in a normal shell still says `Logged in using ChatGPT`.
- If any step fails: the tab path is not built. Codex runs in the background through
  `codex exec --ignore-user-config` as today, at every point, in herdr too. tasks.md names the
  tasks this skips.
- T050 result (live, 2026-10-31 16:38 to 16:44 +08:00, codex-cli 0.166.0, herdr 0.9.4):
  **FAIL. First failed check: 1, the agent gave no answer.**
  - Setup: `<scratch>/cxhome/` held only `auth.json -> /home/hyuse/.codex/auth.json`.
    `<scratch>/cxproj/` (`git init`) had `.codex/config.toml` with
    `notify = ["sh", "-c", "touch <scratch>/canary-notify"]` and `[mcp_servers.canary]`
    (`command = "sh"`, `args = ["-c", "touch <scratch>/canary-mcp; sleep 30"]`).
  - `herdr tab create --workspace w13 --cwd <scratch>/cxproj --label cx-probe --env CODEX_HOME=<scratch>/cxhome --no-focus`
    gave tab `w13:t6`, pane `w13:p9`. `herdr agent start cx-probe --kind codex --pane w13:p9 --timeout 120000 -- -s read-only -a never --no-alt-screen`
    gave `"agent_status":"idle",…,"interactive_ready":true`.
  - Codex used the scratch home. The first screen line was
    `WARNING: proceeding, even though we could not create PATH aliases: Refusing to create helper binaries under temporary dir "/tmp" (codex_home: AbsolutePathBuf("<scratch>/cxhome"))`.
    This comes from the scratch folder being under `/tmp`. The real home under
    `~/.local/state` does not hit it.
  - Trust dialog: yes, at start. Text: `Trust this folder? … Folder settings can run code automatically, even without a model request. … Your trust decision will be saved.`
    Options: `1. Trust and continue`, `2. Back to Agent Command Center`. There is no
    "do not trust" label. Option 2 is the only one that does not trust, so the probe picked it.
  - What "do not trust" does: it opens an empty `Agent command center` (`No tasks yet`).
    `herdr agent prompt cx-probe "Say OK." --wait --until done --until idle --timeout 120000`
    there gave `{"error":{"code":"agent_prompt_stalled","message":"agent prompt produced no observed working or blocked state within 5000 ms; current status is idle"}}`.
    Its `n new` key shows the same trust dialog again. Option 2 again, then `esc`, opens
    the chat box with the footer `GPT-6.1-Sol default` and `⚠ 1 warning`. The warning (f2):
    `Project-local config, hooks, and exec policies are disabled in the following folders until the project is trusted, but skills still load.`
    The same prompt there gave `agent_prompt_stalled` again, and the screen showed
    `• Queued follow-up inputs ↳ Say OK.` A plain `enter` and 3 minutes of waiting did not
    run it. The Codex log (`<scratch>/cxhome/logs_2.sqlite`) has no thread or turn start.
    Its only ERROR line is the project-config warning above.
  - No decision was saved. `<scratch>/cxhome/config.toml` held only
    `[tui] screen_reader_detection_done = true`, and `grep -c cxproj ~/.codex/config.toml`
    printed `0`.
  - Checks:
    1. FAIL. There was no login screen (the log shows `account/read` and `getAuthStatus`
       calls, and `wham/security-setup` returned `200 OK`), but no answer came.
    2. PASS. The footer model was `GPT-6.1-Sol default`, not `GPT-6-Astra xhigh`.
    3. PASS. `ls <scratch>` showed only `cxhome cxproj`, with no `canary-notify` and no
       `canary-mcp`. The proof is weak, because Codex never ran a turn and kept the project
       config off without trust.
    4. Trust dialog: yes. Without trust, no chat path takes a prompt.
    5. PASS. `test -L <scratch>/cxhome/auth.json` gave `rc=0` (it points to
       `/home/hyuse/.codex/auth.json`). `codex login status` printed `Logged in using ChatGPT`.
       `~/.codex/auth.json` was last changed `2026-10-25 00:22:37`, so it did not change.
  - The probe closed tab `w13:t6` (`{"type":"ok"}`). After that, `herdr agent list` had no
    `cx-probe`.
  - Open question for the user: the probe did not test trust. The dialog says that trust is
    saved and that folder settings can then run code. The probe did not check where trust is
    saved. With trust, the project's `.codex/config.toml` would load. To run checks 1 to 3
    with trust, a second probe and a design change are necessary.

## R-D. A portable test lock

- Decision: `scripts/st-lock.sh`. It uses `mkdir` as the atomic step, writes its own `$$` to
  `<lock>/pid`, removes the folder on exit (`trap`), and frees a lock whose pid fails
  `kill -0`. The lock folder is `<git common dir>/stratum-<name>.lock`
  (`git rev-parse --path-format=absolute --git-common-dir`), so all worktrees of one repo share
  it (L29). It waits with `sleep 1` up to `--timeout` seconds (default 600), then prints one
  `lock:` line and exits 75 with nothing run.
- Evidence (live, this machine): eight concurrent `mkdir L` calls printed one `win 1`. A finished
  child's pid gave `gone pid=196499` on `kill -0`. `git rev-parse --path-format=absolute --git-common-dir`
  printed `/home/hyuse/Desktop/stratum/.git`.
- Not verified: macOS and Windows (Git Bash). `mkdir` is atomic on both, and `kill -0` works on
  Git Bash's own pids. A Windows pid seen through a non-MSYS tool would not match. Say so in the
  README, as L3 did for the console encoding.
- Known limit: two waiters that both see a dead owner in the same second can both remove the
  folder, and both can run. The script marks it with a `ponytail:` line.
- Alternatives considered: `flock` (not on macOS by default), `pgrep` loops (match their own
  command line, issue #55, L21).

## R-E. The status line shows "autonomous"

- Decision: The orchestrator writes `.stratum/autonomous` with one line, its
  `$CLAUDE_CODE_SESSION_ID`, when the user turns the mode on, and removes the file when the run
  ends or on "stop autonomous". `statusline/st-statusline.sh` adds an `autonomous` segment to line
  2 only when that line equals the `session_id` in the status line's JSON input. A new session
  has a new id, so it never shows or uses the mode, even if an old file is left (D21). No
  SessionStart hook change is needed.
- Evidence: `statusline/st-statusline.sh:16-20` reads the JSON input. `hooks/st-phase.py:29-48`
  loads `state.json`, changes only `phase` and `lane`, and writes the whole object back, so a new
  `risk` key in `state.json` (FR-011) is kept.
- Alternatives considered: a flag in `.stratum/state.json` (it would outlive the session and needs
  a SessionStart reset); clearing it in `hooks/st-session-start.sh` (it would also clear it on
  `compact` in the middle of a run).

## R-F. Git guard on a command it cannot split (FR-008)

- Decision: In the `except ValueError` path, read each line of the command that has a git word,
  after removing `\`, `'` and `"` from a copy of the line, so `\git`, `g''it` and `gi\t` count
  (today's guard asks on `\git push --force` and `g''it push --force`, because shlex removes the
  quoting).
  A git word is `git` as a whole word, or a path that ends in `/git`, with a shell separator,
  quote or line edge on each side (`st-git-guard.py` does not match). Split that line alone with
  the same `segments`. Judge each segment whose first word is git with today's `judge`, with the
  folder unknown (`elsewhere=True`). A git line that does not split, or that has no segment
  starting with git, asks.
- Evidence (current guard, run on this repo):
  `heredoc git status -> … "permissionDecision": "ask", "permissionDecisionReason": "The git guard could not parse the command."`,
  same for `heredoc git commit`. A heredoc with balanced quotes splits today and gets no
  decision, so the tests must use an unbalanced quote (an apostrophe as in `it's`) to reach the
  fallback.
- Finding: `python3 - <<'EOF'` with `subprocess.run(["git", "commit", "-m", "x"])` and no stray
  quote splits today and gets no decision. The guard does not read git inside other programs.
  That is today's behavior outside the parse-failure path, and this feature does not change it.

## R-G. Existing tests that assert text this feature changes

`tests/test_on_demand.sh` rows `#17 one-time yes`, `#17 FR-014 build`, the check
`#17 FR-014 build skill` (`! grep -qF st-worker skills/st-build/SKILL.md`), `#18 FR-005 revise`
(`Then run the same point once more on the changed input.`), `#18 FR-010 modes`,
`#18 FR-010 no file` (both rows), `#18 FR-015 init` (`advisor mode \`codex\` (recommended`).
`tests/test_advisor.sh:315,379` assert the `mode not set` line. `tests/test_design_lane.sh:82`
asserts `Say "full", "fast", "quick" or "design" to override.`, so the new lane line keeps that
sentence. `tests/test_inspect.sh:111-127` checks README skill rows both ways and needs every
`tests/test_*` file named in README. `tests/test_advisor.sh` runs the real script: inside herdr
(`HERDR_ENV=1`) it would take the new herdr path, so it must unset `HERDR_ENV` and
`HERDR_WORKSPACE_ID`.

## R-H. Live runs still to record

T050 (Stratum Codex home probe, R-J, runs first), T024 (Codex plan review through herdr, real answer length), T034 (worker with full layout,
autonomous approval through the plugin hook, `pass`, a hook wait past 120 s). Each one is
recorded here when it runs, or ticked with `Not run, <first error line>` (L32).

- T050: failed at check 1 (R-J). T019, T021 and T024: not run.
- T034: not run. The PC was not reachable this session, so quickstart 4L (and the D28 step on a
  saved machine) must run before the merge.
- T049, 2026-10-31, on `125e02c`:
  - Section 1 (scratch repo, stub `codex`, mode `codex`): `plan` printed `APPROVED sha256 54b05a…`;
    `waive plan … "fix-only change"` printed `WAIVED sha256 54b05a…` and `reason: fix-only change`
    with no new `codex` call (1 call in all); `check plan` printed `WAIVED sha256 54b05a…`, rc 0;
    after a change to `tasks.md` it printed `advisor approval is stale`, rc 1; `count` printed
    `advisor calls: codex 1, waived 1, /advisor 0`; `diff … HEAD` printed `no change since HEAD: skip`.
  - Section 2 (this repo): a second `st-lock.sh -- echo second` printed
    `lock: waiting for test (pid <A>)`, then `second` after A ended; `--timeout 3` printed
    `lock: waited 3 s for test; held by pid <A> since <time>; ran nothing`, exit 75, no `never`;
    after `kill -9` of the holder, `st-lock.sh -- echo freed` printed `freed` at once.
  - Section 6: `git grep -n frontend-design -- ':!specs'` lists only
    `tests/test_no_frontend_design.sh`; test_triage_rules, test_no_frontend_design, test_inspect and
    test_design_lane exit 0.

## R-I. Negative controls

Base `6fe9d60`, HEAD `125e02c`. Old tree: git worktree at `<scratchpad>/old`, detached at 6fe9d60. All 19 changed or new test files were green at HEAD (rc 0), then copied into the old tree and run there. Unit: one `ok` or `FAIL` line per case in the `.sh` files, one method per case in the `.py` files (`python3 <file> -v`). Red = a changed behavior that fails on old. Same = a kept behavior, or a no-output or negative check that old also passes. `tests/test_codex_agent.sh` is skipped (T050 failed).

| File | Red on old | Same on old | Verdict |
|---|---|---|---|
| tests/test_advisor.sh | 3 | 79 | OK |
| tests/test_advisor_matrix.sh | 20 | 11 | OK, see note 2 |
| tests/test_advisor_rules.sh | 14 | 1 | OK |
| tests/test_advisor_waive.sh | 33 | 3 | OK |
| tests/test_approve_hook.py | 31 | 0 | OK, see note 1 |
| tests/test_git_guard.py | 9 | 37 | OK |
| tests/test_lane_steps.sh | 29 | 0 | OK |
| tests/test_lock.sh | 13 | 0 | OK, see note 1 |
| tests/test_lock_rules.sh | 8 | 0 | OK |
| tests/test_no_frontend_design.sh | 4 | 2 | OK |
| tests/test_on_demand.sh | 4 | 164 | OK, see note 3 |
| tests/test_plan_rules.sh | 15 | 0 | OK |
| tests/test_risk_rules.sh | 22 | 2 | OK, see note 4 |
| tests/test_screen_rules.sh | 9 | 0 | OK |
| tests/test_st_worker.sh | 87 | 385 | OK |
| tests/test_statusline.sh | 4 | 53 | OK |
| tests/test_test_scope.sh | 11 | 1 | OK |
| tests/test_triage_rules.sh | 11 | 1 | OK |
| tests/test_worker_rules.sh | 20 | 1 | OK |

Total: 347 red, 740 same. Every file has at least one red case.

1. Red by absence. `scripts/st-lock.sh` and `hooks/st-approve.py` do not exist at 6fe9d60. In `test_approve_hook.py`, 155 of 156 failures are `hooks/st-approve.py does not exist yet`. Only `test_registered_in_commands_json` checks the changed `commands.json`.
2. `test_advisor_matrix.sh` aborts on old at `(j) count` (`usage: unbound variable` under `set -u`). The literal run evaluates 25 of 31 cases (17 red, 8 same). The table uses a scratch copy with `set -u` relaxed, which evaluates all 31.
3. `test_on_demand.sh` check `#18 plan-only st-build no diff point` changed and passes on old. The grep matches zero lines on old, as T003 intends.
4. `test_risk_rules.sh` R21 passes on old. With T050 failed, the fallback sentence equals `README.md:182` at 6fe9d60.
