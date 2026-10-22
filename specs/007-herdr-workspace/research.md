# Research: Open a herdr Workspace From a Layout Template

Checked on 2026-10-23: herdr 0.9.4 (`/home/hyuse/.local/bin/herdr`), jq 1.8.2, GNU bash 5.3.20,
OpenSSH 10.6p1, git 2.56.0, Claude Code 2.1.302, lazygit 0.66.2. This session runs inside herdr
(`HERDR_ENV=1`, pane `w1P:p1`). Only read-only herdr commands were run.

## R1. herdr calls and their JSON

- Decision: use the calls in contracts/script.md section 4, with the argv shapes printed by
  `herdr workspace`, `herdr tab`, `herdr pane` (no subcommand).
- Rationale: verified usage lines: `workspace create [--cwd PATH] [--label TEXT] ... [--focus] [--no-focus]`,
  `tab create [--workspace ID] [--cwd PATH] [--label TEXT] ... [--no-focus]`,
  `pane split [<pane_id>|...] --direction right|down ... [--cwd PATH] ... [--no-focus]`,
  `tab rename <tab_id> <label>`, `pane run <pane_id> <command>`, `workspace focus <id>`,
  `pane list [--workspace ID]`, `pane process-info [--pane ID|--current]`. `herdr --skill` names
  the response fields: `workspace create` gives `.result.workspace`, `.result.tab`,
  `.result.root_pane`; `tab create` gives `.result.tab`, `.result.root_pane`; `pane split` gives
  `.result.pane`. Live `pane list --workspace w1P` shows `pane_id`, `tab_id`, `cwd` per pane.
  `herdr --skill`: "CLI server errors are JSON on stderr with exit status 1. CLI syntax errors
  exit with status 2."
- Alternatives: `herdr api snapshot` for the read back. Rejected: one `pane list` gives the cwd.

## R2. Is the machine answering (US2 scenario 2)

- Decision: `herdr --machine <m> workspace list`. Exit 0 = answers. Else print herdr's first
  stderr line.
- Rationale: it tests the exact path the build uses (API forwarding to the remote server).
  Measured: `herdr --machine laptop workspace list` exits 1 after 11 s with
  `Error: Custom { kind: ConnectionAborted, error: "machine 'laptop' (session default): remote SSH connection failed: ssh: connect to host 100.73.64.64 port 22: Connection timed out" }`.
  `herdr --machine nosuchbox workspace list` exits 2 with
  ``error: unknown machine 'nosuchbox'; use `herdr machine list` ``.
- Alternatives: `herdr machine status <m> --json`. Rejected: it exits 0 even on failure and only
  the `"status":"error"` value is known; the value for a good machine was not seen, so a branch on
  it cannot be checked (lessons L5).

## R3. Remote folder check and quoting (FR-006, D5)

- Decision: one probe command (contracts/script.md section 3) run by `bash -c` locally and by
  `ssh -o BatchMode=yes -- <target>` remotely. The folder is quoted with `printf %q`, then a
  leading `\~` is turned back into `~`. The probe prints the absolute path, which is the `--cwd`
  for every herdr call.
- Rationale: ssh joins its arguments into one remote shell line, so the path must be quoted.
  Measured: `printf %q '~/x y'` gives `\~/x\ y`, which stops `~` expansion; turning the leading
  `\~` back fixes that and keeps the rest quoted. `herdr --skill`: "Remote worktree paths must be
  absolute, `~`, or start with `~/`", so a remote folder not starting with `/` or `~` is refused
  before ssh. Sending the resolved absolute path to herdr removes any doubt about where herdr
  expands `~`. `BatchMode=yes` makes ssh fail instead of asking for a password (spec Assumption).
  `--` keeps a target that starts with `-` from being read as an option (verified:
  `ssh -G -- example.com` works). `printf %q` may emit `$'...'`, which bash and zsh read; a fish
  login shell on the target would not (`ponytail:` ceiling, see plan).
- Alternatives: `ssh target test -d <path>` then a second ssh for git. Rejected: two round trips
  and two quoting sites.

## R4. Git state (FR-007)

- Decision: `git --no-optional-locks status --porcelain=v2 --branch` in the probe. Ahead and behind
  come from `# branch.ab`, counted against the upstream as last fetched. No `git fetch`.
- Rationale: spec Assumption: "Opening a workspace changes only herdr state ... No repo file
  changes." `git fetch` writes refs and `FETCH_HEAD` and may ask for credentials.
  `--no-optional-locks` keeps `git status` from rewriting the index. The report says
  `(as of last fetch)` so the user does not read it as current.
- Alternatives: fetch first. Rejected by the Assumption above.

## R5. Is `claude` or `lazygit` running (FR-010, D7, D20)

- Finding: `herdr pane wait-output` reads `recent_unwrapped` by default and "searches the selected
  snapshot immediately, so output that already exists can match" (`herdr --skill`). `pane run`
  types the command into the shell, so the shell's own echo of `claude` or `lazygit` is already in
  the snapshot, and so is `zsh: command not found: lazygit`. A `--match claude` or
  `--match lazygit` passes when the program never started (lessons L1).
- Verified live: `herdr pane process-info --pane w1P:p2` lists `"name":"lazygit"`;
  `--pane w1P:p1` lists `"name":"claude"`; a plain shell pane lists `"name":"zsh"`. lazygit draws
  `Status` (a live `wait-output --match lazygit` matched the frame line, exit 0). No read-only way
  was found to see a stable text that Claude Code 2.1.302 draws at start: the bottom frame
  depends on the user's statusline and permission mode, and no `Claude Code v` banner was in the
  scrollback of two claude panes.
- `claude2` is a zsh alias, `CLAUDE_CONFIG_DIR=$HOME/.claude-work claude`, so its process name is
  `claude`. On the laptop the alias is not verified.
- Decision (D20): after `workspace focus`, poll `H pane process-info --pane P1` and
  `--pane P2` once per round, `sleep 1` between rounds, up to 10 rounds. A pane is `running` when
  any `.result.process_info.foreground_processes[].name` is `claude` (P1, for both `claude` and
  `claude2`) or `lazygit` (P2). Stop polling as soon as both are seen. A pane not seen after the
  last round is `not seen`; a failed `process-info` call counts as not seen and does not stop the
  run (D7). `ponytail:` fixed 10 s bound, measured in quickstart section 2 before the build is
  closed.
- Rationale: verified live on both programs, and the process name does not appear because the
  shell echoed the typed command (lessons L1).
- Alternatives: `pane wait-output` with `Status` (lazygit) and `Claude Code` (claude). Rejected:
  the claude text is not verified and depends on the user's settings.

## R5a. Facts next to D20 (choices from the spec text, no decision code)

- No `git fetch`: ahead and behind count against the last fetch, from the spec Assumption "No
  repo file changes" (R4).
- A run that stops after the workspace exists does not focus it, because the edge case says "the
  run stops" (R6).

## R6. Order, focus and stop

- Decision: create with `--no-focus` on every create and split, `workspace focus` once after the
  last `pane run` (D9), then the running check and the read back. A failed call stops the run: no
  focus, nothing closed (spec Edge Cases, FR-011).
- Rationale: `templates.sh` does the same order (`workspace create --no-focus` ... `workspace focus`).
  The edge case says the run stops, so FR-012 (focus) holds for a run that ends normally.
- Alternatives: focus on create. Rejected: the user's tab focus jumps while tabs are still made.

## R7. Tests without herdr (FR-014, SC-005)

- Decision: `tests/test_herdr_workspace.sh` writes stub `herdr`, `ssh` and `sleep` into a
  `mktemp -d` dir first on `PATH`. The stub `herdr` logs each argv as one TAB-joined line, answers
  canned JSON with ids that start `stub`, and fails on zero arguments. One assert function takes a
  script path. Negative controls run `sed`-broken copies of the script through the same function
  and expect red (lessons L2). Each control first checks that its copy differs from the script, so
  a `sed` that matches nothing fails the test instead of passing.
- Rationale: matches `tests/test_verify.sh` and `tests/test_on_demand.sh` (`check`, `mktemp -d`,
  `trap` cleanup). The stub `sleep` keeps the `not seen` case from waiting 10 s without a knob.
- Alternatives: a named test herdr session (`herdr --session`). Rejected: needs a running server
  and is not "checkable without herdr" (FR-014).

## R8. Layout source (FR-002, FR-013, D1)

- Decision: copy `full` and `basic` from `~/.config/herdr/templates.sh` as of 2026-10-23 into the
  script, and add `--cwd D` on every split (FR-003; `templates.sh` has none), `--label` on create
  (FR-009), and drop the fzf pickers and the `trap ... read` prompt.
- Rationale: the issue: "A split without `--cwd` over `--machine` was not tested."
