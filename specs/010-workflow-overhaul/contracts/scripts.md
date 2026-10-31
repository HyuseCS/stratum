# Contract: scripts and hooks

Record formats are in `data-model.md`. Exact skill and agent text is in `phrases.md`.

## 1. `scripts/st-advisor.sh` (changed)

### 1.1 Usage

```text
st-advisor.sh plan <feature dir>
st-advisor.sh test <feature dir> <task file> <test path> <failure 1 file> <failure 2 file>
st-advisor.sh diff <feature dir> <base>                       (new, US1)
st-advisor.sh decisions <feature dir> <list file>             (new, US3)
st-advisor.sh round <point> <feature dir> <n> <views file>    (new, US3)
st-advisor.sh check plan <feature dir>
st-advisor.sh continued <point> <feature dir>
st-advisor.sh waive plan <feature dir> <reason>               (new, US1)
st-advisor.sh note <point> <feature dir> <summary>            (new, US1)
st-advisor.sh talk <point> <feature dir> <file>               (new, US3)
st-advisor.sh count <feature dir>                             (new, US1)
st-advisor.sh codex-home                                       (new, US3, D25)
```

`<point>` is `plan`, `test`, `diff` or `decisions`. The usage line names every form. Any other
form, an unreadable input, `<n>` outside 1 to 3, a `<base>` that
`git rev-parse --verify --quiet "<base>^{commit}"` rejects, or an empty reason or summary after
CR and LF are replaced: `usage: ...` on stdout, exit 2, nothing recorded, nothing sent.

### 1.2 New commands that call no advisor

| Command | Output (stdout) | Exit | Record |
|---------|-----------------|------|--------|
| `waive plan` | `WAIVED sha256 <h>` / `reason: <r>` / `record: <f>/advisor.md` | 0 | waive entry, `<h>` = today's plan input hash |
| `waive plan`, refused | `nothing to waive: the last plan record is <verdict>` (`<verdict>` = `none` when there is no record) | 1 | none |
| `note` | `noted: <point> /advisor` | 0 | note entry |
| `talk` | `talk recorded: <point>, <n> rounds` | 0 | talk entry |
| `count` | `advisor calls: codex <a>, waived <b>, /advisor <c>` | 0 | none |
| `check plan` after `waive` | `WAIVED sha256 <h>` | 0 | none |
| `codex-home` | `codex home: <dir>` | 0 | none |

- `waive` runs only when the last `^## plan \| [^|]* \| sha256 ` record is `APPROVED`, `WAIVED`,
  or `REVISE` whose finding lines (`- [<SEV>] ...`) are all `MEDIUM` or `LOW` (FR-001). Any other
  last record (`BLOCKED`, `BLOCKED, user continued`, a `REVISE` with a `CRITICAL` or `HIGH`
  finding) or no record: refused, exit 1, nothing written.
- `waive` needs no `.stratum/advisor.json` and no `codex`. It hashes the plan input with the same
  pipeline as `plan`. A hash failure is `cannot hash inputs`, exit 2, nothing written (L16).
- `codex-home` (D25) makes the Stratum Codex home `<dir>` =
  `${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-home` (mode 700) holding only
  `auth.json`, a symlink to `${CODEX_HOME:-$HOME/.codex}/auth.json`. A missing login file:
  `no codex login: run codex login, then run this again`, exit 1, nothing made. Run again: same
  line, nothing changed. Only this command makes the folder. The skills run it only when the
  user opts in to a Codex advisor (st-init setup, or a request to add one or set a mode that
  uses Codex).
- `talk`'s file must hold one line each starting `rounds: ` (1 to 3), `agreed: `,
  `compromises: `, `to user: ` and `calls: ` (digits). Missing or bad: usage, exit 2.
- `count` counts headers: codex = run and round entries (`| APPROVED`, `| REVISE`, `| BLOCKED` at
  the end of a `sha256` header), waived = `| WAIVED`, /advisor = `| /advisor`. No `advisor.md`:
  all 0. `ponytail:` it counts a `BLOCKED` entry written before Codex started (bad
  `advisor.json`) as a run.
- `check plan` reads only the last header that matches `^## plan \| [^|]* \| sha256 `.

### 1.3 Points that can call Codex

| Point | Input hashed | Prompt `Point:` line (exact) |
|-------|--------------|------------------------------|
| `plan` | unchanged | unchanged |
| `test` | unchanged | unchanged |
| `diff` | `git diff --no-ext-diff --no-color <base> HEAD` (git exit checked) | `Point: diff. Review the changes in git diff <base>..HEAD (run it yourself): hidden regressions and broken rules of the project's constitution. Do not build or fix.` |
| `decisions` | the list file | `Point: decisions. Below is the list of small decisions the orchestrator made. For each one, say whether it is fine. A finding with severity CRITICAL or HIGH means the decision must go to the user.` then the file text |
| `round` | the views file | `Point: <point>, round <n> of 3 of a talk with another advisor. The views so far are below. For each open point, agree, or keep your view and give the reason.` then the file text |

- Round 3 adds the line `This is the last round. For every open point, propose a compromise aimed at the best result, one finding per compromise.`
- `diff` with no change (`git diff --quiet <base> HEAD`): `no change since <base>: skip`, exit 0,
  no record, before any mode logic (FR-003).
- A round header is `## <point> round <n> | ...`. The same validator handles every answer.

### 1.4 Mode and matrix (US3)

`mode` missing from the file = `auto` (D24). Risk comes from `risk` in the main checkout's
`.stratum/state.json`: `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/state.json`,
not the copy in a linked worktree; outside git, `./.stratum/state.json`. Missing or
other value: first print `risk not set: normal`, then use `normal`.

| Point | high | normal | low | none |
|-------|------|--------|-----|------|
| `plan` | both | codex | none | none |
| `test` | codex | codex | /advisor | none |
| `decisions` | both | codex | /advisor | none |
| `diff` | both | codex | /advisor | none |
| `round` | codex | codex | codex | codex |

- Mode `auto`: first line `advisors: <set> (<point>, risk <level>)`. Set `none` or `/advisor`:
  exit 0, no record, no Codex call. Set `codex` or `both`: Codex runs as today.
- Mode `codex`: `plan`, `test` and `round` run Codex with today's output (no `advisors:` line).
  `diff` and `decisions` print `advisors: /advisor (mode codex)` and exit 0.
- Mode `both`: as `codex`, and the first line of `plan` and `test` stays
  `mode both: also consult /advisor if one is set`. `diff` and `decisions` print
  `advisors: /advisor (mode both)`.
- Mode `off`: `no advisor: mode off` at every point (unchanged).
- No file: `no advisor: mode not set. Write .stratum/advisor.json with "mode": "auto", "codex", "both" or "off".`
- The Python check accepts `mode` in `auto`, `codex`, `both`, `off` or absent.

### 1.5 Where Codex runs (US3, FR-013)

- Budget: lock wait up to 50 s, then `st-codex-agent.sh` keeps its own start and review under
  480 s (section 2 step 5), so a slow step ends with its own `ERROR:` line, not the outer
  `timed out`.
- In herdr (`HERDR_ENV` is `1`, `HERDR_WORKSPACE_ID` is set, `herdr` is on PATH) and with the
  Stratum Codex home in place (`<dir>/auth.json` is a symlink):
  `timeout -k 10 540 bash <scripts>/st-lock.sh --name codex-<workspace id> --timeout 50 -- bash <scripts>/st-codex-agent.sh <feature dir> <prompt file> <answer file> <dir> [-m <model>] [-c model_reasoning_effort="<effort>"]`.
- Else (not in herdr, or no Stratum Codex home, or T050 failed and the tab path was not built):
  today's `codex exec -s read-only --ignore-user-config ... --ephemeral --output-schema ... -o ...`.
- Both write the answer file. The same validator reads it. Exit 75 from the lock:
  `BLOCKED: Codex agent busy with another review`. Other non-zero: today's
  `BLOCKED: codex exited <rc>` with the last `ERROR:` line.
- `command -v codex` is checked on both paths.

## 2. `scripts/st-codex-agent.sh` (new, US3)

```text
st-codex-agent.sh <feature dir> <prompt file> <answer file> <codex home> [-m <model>] [-c <key=value>]
```

1. Agent name `st-codex-<NNN>`, `<NNN>` the leading 3 digits of the feature dir's name. None:
   `ERROR: feature dir must start with three digits` on stderr, exit 2.
2. `herdr agent list`. Agents in `$HERDR_WORKSPACE_ID` whose name starts with `st-codex-`: the one
   with this exact name is used. Each other one gets `herdr tab close <its tab_id>` first.
3. None left: `herdr tab create --workspace <ws> --cwd <pwd> --label Codex --env CODEX_HOME=<codex home> --no-focus`, then
   `herdr agent start <name> --kind codex --pane <root pane> --timeout 120000 -- -s read-only -a never --no-alt-screen [-m ..] [-c ..]`.
   `agent_pane_busy`: retry, 10 tries, 1 s apart (L30). `agent_not_ready`:
   `ERROR: Codex waits for an answer at start in its Codex tab. If it asks whether to trust the folder, pick the option that does not trust it (trusting loads the project's .codex/config.toml), then run the point again.`,
   exit 1. Ids are read from herdr's answers, never built (L26). `<codex home>/auth.json` not a
   symlink: `ERROR: no Stratum Codex home`, exit 2, before any herdr call. An existing
   `st-codex-<NNN>` agent from before D25 is reused only if its tab was made by this script
   (label `Codex`); `ponytail:` the script cannot read a running pane's `CODEX_HOME`, so a tab
   the user made by hand with that name would be reused.
4. Nonce: 12 hex characters from `/dev/urandom`. The script appends to the prompt file:
   `The project root is <pwd>. Read every path above relative to it.`, the JSON shape line, and
   `Print the line ST-ADVISOR-BEGIN-<nonce> alone, then the JSON object on one line, then the line ST-ADVISOR-END-<nonce> alone. Print nothing after the end line.`
5. `herdr agent prompt <name> "Read the review request in <prompt file> and follow it. Change no file." --wait --until done --until idle --until blocked --timeout <ms>`,
   with `<ms>` = `(480 - SECONDS) * 1000` and `SECONDS=0` at the script's start, so lock wait,
   agent start and review stay inside the caller's 540 s `timeout`.
   A herdr error: `ERROR: <its first line>`, exit 1. State `blocked`:
   `ERROR: Codex waits for an answer in its Codex tab.`, exit 1.
6. After the review, `<codex home>/auth.json` must still be a symlink (F10). If Codex replaced it
   with a file: `ERROR: Codex replaced the login link in <codex home>; your own Codex login may be stale. Run codex login status, then st-advisor.sh codex-home.`,
   exit 1, and the answer is not used.
7. `herdr agent read <name> --source recent-unwrapped --lines 400`. Each line has leading `•`
   and spaces, and trailing spaces, removed. Take the last line equal to
   `ST-ADVISOR-END-<nonce>` and the last line equal to `ST-ADVISOR-BEGIN-<nonce>` before it.
   Join the lines between them with one space and write them to the answer file. No such pair:
   `ERROR: no answer between the markers`, exit 1.

## 3. `scripts/st-lock.sh` (new, US2)

```text
st-lock.sh [--name <name>] [--timeout <seconds>] -- <command> [args...]
```

- Lock: `<git common dir>/stratum-<name>.lock/` with `pid` and `since` (data-model section 4).
  `--name` default `test`, `--timeout` default `600`, digits only.
- Free: take it, run the command as a child, remove the folder on exit, exit with the
  command's code.
- Held: print `lock: waiting for <name> (pid <pid>)` once on stderr, try again every 1 s.
- Stale (`kill -0 <pid>` fails): remove the folder and try again.
- Timeout: `lock: waited <s> s for <name>; held by pid <pid> since <since>; ran nothing` on stderr,
  exit 75, the command never runs.
- Not in a git repo: `lock: not in a git repo`, exit 2. Bad args: a usage line, exit 2.
- Uses no `pgrep`, `flock`, `ps` or `pkill`.

## 4. `scripts/st-worker.sh` (changed)

| Change | Story | Rule |
|--------|-------|------|
| brief Facts | US2 | adds the test lock line from `phrases.md` (B1) |
| brief Team rule 1 | US4 | new text from `phrases.md` (B2); `specs/008-herdr-workers/contracts/script.md` section 3 changes in the same task (L37) |
| worker-tree refusal | US4 | `start --autonomous`, `approve`, `pass` and `autonomous-off` refuse to run inside a worker's worktree (this check follows the cwd, so a worker could `cd` past it; the hook's lock 2 denies, in a worker session, any Bash that runs `st-worker.sh` with `approve`, `pass`, `autonomous-off`, `wait` or `start`, which is the real stop) (its toplevel has `.stratum/approve/`, or `git symbolic-ref --short HEAD` starts with `worker-`): `Run this from the orchestrator's checkout, not a worker worktree.`, exit 1, before any call. A feature's linked worktree is allowed, because the orchestrator often runs in one (L29). |
| `start --autonomous` | US4 | a flag with no value. Refused unless `<main>/.stratum/autonomous`, where `<main>` = `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` (the main checkout, also when run from a linked worktree, F2)'s first line equals a non-empty `$CLAUDE_CODE_SESSION_ID`: `Autonomous build mode is off for this session.`, exit 1, before any herdr call. Makes `<worktree>/.stratum/approve/` (local `mkdir`, remote in the same `rsh` write as the brief), with the symlink checks the other files have, and writes `<worktree>/.stratum/approve/owns`: one path per line, the backticked paths of the task file's `Owns:` line, in order; no `Owns:` line gives an empty file (D23), and `<worktree>/.stratum/approve/session` with the
  `$CLAUDE_CODE_SESSION_ID` line (D27). With `--machine <m>` (D28): first, before `worktree create`, one `rsh` call writes that line to `<repo>/.stratum/autonomous` on `<m>` (`<repo>` = the `--repo` main checkout), with the symlink checks the other remote writes have (`<repo>/.stratum` and the file must not be symlinks), and replaces any file already there (a stale id from a crashed session). A failed write: `cannot write .stratum/autonomous on <m>: <first error line>`, exit 1, no herdr call that makes anything, no worker. A roster line may have a fifth TAB field, the `<repo>` of a worker on a saved machine (the skill writes it); the brief's roster table still shows the first four fields, and the error line for a bad roster line is unchanged. With `--autonomous --machine`, its own row must have that field equal to `--repo`, else `Roster row for <name> needs the repo path as a fifth field.`, exit 1, before any call. Which machine runs the orchestrator is never assumed: `local` in the roster is the machine this script runs on. |
| `autonomous-off --roster <file>` | US4 | new (D28). For each distinct machine in the roster: `local` removes `<main>/.stratum/autonomous`; another machine removes `<repo>/.stratum/autonomous` over `rsh`, `<repo>` from the fifth roster field (same symlink checks). It removes a file only when its first line equals `$CLAUDE_CODE_SESSION_ID`, so it never removes another live session's flag. Prints `autonomous off\t<machine>` per machine, or `autonomous off failed\t<machine>\t<first error line>` and goes on with the others; exit 1 if any failed, else 0. |
| `start` layout | US4 | after `worktree create`, before `agent start`: `tab rename <tab> Main`, `pane split <root pane> --direction right --cwd <wt> --no-focus`, `pane run <new pane> lazygit`, then for `Dev Servers` and `VM`: `tab create --workspace <ws> --cwd <wt> --label <name> --no-focus` and `pane split <its root pane> --direction right --cwd <wt> --no-focus`. Same calls as `st-herdr-workspace.sh:75-94`. The agent starts in the root pane. |
| `wait` | US4 | on `blocked`, first look for `<wt>/.stratum/approve/*.req` (remote: `rsh`). Oldest by name: print `state\tapproval\t<name>\t<pane>`, `request\t<rid>`, `tab\tworkspace <name>, tab Main`, `input\t<tool_name>: <tool_input as one-line JSON>` (the full text, never cut), and for a commit request also `branch\t<the .req branch>` and `staged\t<the .req staged paths, split by spaces>`, then today's `pane text:` block (the last 40 lines, F7), exit 6. None: today's `blocked`, exit 4. |
| `approve <id> --request <rid> --input-stdin --record <file> [--machine <m>]` | US4 | the stdin text is compared on the machine that runs this script: a remote `.req` is fetched with `rsh cat` as data, and the input text never goes into an `rsh` command string; only the checked `<rid>` does. `wait` and `approve` render `<tool_name>: <tool_input>` with one shared helper, `python3 <plugin root>/hooks/st-approve.py --render <req file>`, which prints `<tool_name>: ` and `json.dumps(tool_input, sort_keys=True, ensure_ascii=True, separators=(",", ":"))` on one line, so the byte compare holds. A remote `.req` is copied to a local temp file first. The autonomous check as `start`; the worker's `<wt>/.stratum/approve/session` first line (remote: `rsh`) must equal the flag (else `Worker <name> is not in this autonomous run.`, exit 1); `<rid>` must match `^[0-9]+-[0-9]+$`; `<rid>.req` must exist (`No request <rid> for <name>.`, exit 1); `--input-stdin` reads the text from stdin, fed by a quoted heredoc (`<<'ST_INPUT_END'`), and drops one trailing newline (the heredoc's); the rest must equal the `.req`'s `input` text as `wait` prints it, byte for byte (else `The input does not match request <rid>. Approve nothing.`, exit 1, nothing written), so the orchestrator's permission check sees the whole command it approves; an input over 4000 characters is refused (`Request <rid> is too long to approve. Pass it to the user.`, exit 1); writes `<rid>.ok`; appends one record line (data-model section 7); then `agent wait <name> --until working --timeout 5000` (L34); prints `approved\t<name>\t<rid>`. |
| `pass <id> --request <rid> [--machine <m>]` | US4 | the autonomous, session, `<rid>` and `.req` checks as `approve`; writes `<rid>.user`; prints `passed\t<name>\t<rid>`. |
| `answer` | US4 | before any key, `agent read <name> --source recent-unwrapped --lines 40`. A read failure, a pane line that starts with `Do you want to` (`proceed?`, `make this edit to`, `create`), or a numbered permission option line (`1. Yes`, with or without a `❯` in front): `This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it.`, exit 1, nothing sent. |
| `close` | US4 | also removes `<wt>/.stratum/approve/` (local `rm -rf`, remote `rsh`), with the `.stratum` symlink check. |

## 5. `hooks/st-approve.py` (new, US4) and `hooks/commands.json`

- Registered twice in `hooks/commands.json`: as `"PermissionRequest": [{"hooks": [{"type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/st-approve.py\"", "timeout": 310}]}]`,
  and as a `PreToolUse` entry with matcher `Bash|Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Glob`, the same
  command and `"timeout": 10`. The script branches on `hook_event_name`. Run as
  `st-approve.py --render <req file>` it is the shared input renderer of section 4 (no hook
  input read).
- Reads stdin as bytes (L3). Walks up from `cwd` to the first folder with `.stratum` or `.git`.

### 5.1 PreToolUse: the write lock (D27 lock 2)

- It acts in a worker session. The hook checks two folders: the input's `cwd` and
  `$CLAUDE_PROJECT_DIR`, when set (the session's project dir, which a `cd` in a command does not
  change).
  It is a worker session when either folder, or any folder above it, has `.stratum/approve/`, or
  `git -C <that folder> symbolic-ref --short HEAD` starts with `worker-`. Elsewhere (the
  orchestrator's session) no output, because the orchestrator runs `st-worker.sh approve` and
  writes `.stratum/autonomous` itself (W8).
- Normalize first. Bash: remove `\`, `'` and `"`, split on white space, and run
  `posixpath.normpath` on each word, so `.stratum/././approve`, `.stratum///approve` and
  `.stratum/x/../approve` all read `.stratum/approve`. Paths (`file_path`, `notebook_path`, Grep `path`
  and `glob`, Glob `path` and `pattern`): `os.path.realpath` of the path joined to `cwd` (symlinks resolved).
- Deny (`permissionDecision: "deny"`, reason `.stratum/approve/ and .stratum/autonomous are written only by the orchestrator.`):
  - a Bash command with a normalized word that contains `.stratum/approve` or
    `.stratum/autonomous`;
  - a Bash command with a normalized word `st-worker.sh`, or one ending in `/st-worker.sh`, whose
    next word, after `$` is removed (quotes and backslashes are already removed), is `approve`,
    `pass`, `autonomous-off`, `wait` or `start` (D30). So `st-worker.sh $'approve'` and
    `bash scripts/st-worker.sh "pass" worker-t1` are denied. Reading, editing, `git add`,
    `bash -n`, `shellcheck`, `grep` or `cat` of the file are allowed, so workers can work on
    Stratum's own `st-worker` files;
  - an Edit, Write, MultiEdit, NotebookEdit or Read whose path, a Grep whose `path` or `glob`
    field (never its `pattern`, which is a content regex), or a Glob whose `path` or `pattern`
    (a path glob) is inside a `.stratum/approve/` folder or names a `.stratum/autonomous` file (a
    worker cannot read `.stratum/approve/session` either).
- Anything else: no output.
- `ponytail:` a text match. Workers run as the same OS user, so this lock is a guard against
  mistakes and simple prompt injection, not a wall. Known gaps, accepted: a command that builds
  the path at run time (`cd .stratum && touch approve/x`, a variable); brace and glob forms
  (`.stratum/{approve,x}`, `.stratum/appro?e`); a Grep over the whole root or with a `glob`
  filter, which can read `.stratum/approve/session`. A write outside the worker's
  worktree still prompts, reaches the orchestrator, and is refused (W5). README states this (W15).

### 5.2 PermissionRequest: the approval channel (D27 lock 1)

- No output, nothing written, unless all of these hold: `<root>/.stratum/approve` is a real folder
  (not a file, not a symlink); the main checkout's `.stratum/autonomous`
  (`$(dirname "$(git -C <root> rev-parse --path-format=absolute --git-common-dir)")/.stratum/autonomous`)
  has a non-empty first line; and that line equals the first line of
  `<root>/.stratum/approve/session`. So normal mode, a stale `.stratum/approve/` and the time
  after "stop autonomous" all leave every prompt for the user.
- Never sent to the orchestrator (exit 0, no output, nothing written):
  - a tool other than `Bash`, `Edit`, `Write`, `MultiEdit`, `NotebookEdit`;
  - an edit whose path (`file_path` or `notebook_path`) is missing, resolves outside `<root>`,
    is under `<root>/.git` or `<root>/.stratum`, has a secret-looking name (`.env*`, `*.pem`,
    `*.key`, `id_rsa*`, `id_ed25519*`, `.npmrc`, `.netrc`, a name with `secret` or `credential`)
    is under `<root>/.claude/`, `<root>/.githooks/` or `<root>/.husky/`, is `<root>/.mcp.json`,
    `CLAUDE.md` or `AGENTS.md`, or is a dependency file (`package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`,
    `bun.lockb`, `pyproject.toml`, `requirements*.txt`, `uv.lock`, `Cargo.toml`, `Cargo.lock`,
    `go.mod`, `go.sum`, `Gemfile`, `Gemfile.lock`);
  - a Bash command with a `/` or `~` path word (other than `/dev/null`) or a `..` word that
    resolves outside `<root>`, or that matches a push, a branch
    delete, `worktree remove` or `prune`, `reset --hard`, a secret name, a package install or add
    (`npm`, `pnpm`, `yarn` or `bun` with `i`, `install`, `add`, `ci`, `update` or `upgrade`;
    `pip install`, `pip3 install`; `uv add`, `uv pip`, `uv tool`, `uv sync`; `poetry add`;
    `cargo add`, `cargo install`; `go get`, `go install`; `gem install`; `brew install`; `apt`,
    `apt-get`, `dnf`, `yum`, `pacman`, `apk`), a network tool
    (`curl`, `wget`, `ssh`, `scp`, `sftp`, `rsync`, `nc`, `ncat`, `telnet`, `ftp`, `gh`, a URL,
    `git clone`, `fetch`, `pull`, `ls-remote`, `remote add`), `.stratum`, `.claude` (regex `\.claude\b`), `.mcp.json`,
    `CLAUDE.md`, `AGENTS.md`, `.githooks`, `.husky`, `sudo` or `eval`;
  - a Bash command with a git commit (a `git` word followed by `commit`) unless all D23 rules
    hold:
    - every `git` word outside a quoted option value (so `-m "explain git guard"` passes) must be
      followed by `add` or `commit`: any other git subcommand (`checkout`, `switch`, `rm`, `mv`,
      `restore`, `apply`, `stash`, `reset`, ...) refuses. When the command does not split (the
      fallback below), quotes and backslashes are removed and every `git` word counts, comments
      and message words included;
    - a message the parse cannot read goes to the user: `-F -`, `--file=-`, or any `<<` or `<<<`
      redirect on the commit command;
    - no `sh -c`, `bash -c`, `zsh -c` or `eval` anywhere in the command;
    - no `GIT_INDEX_FILE=`, `GIT_DIR=` or `GIT_WORK_TREE=` anywhere in the command;
    - no option between `git` and `commit` or `add` (so no `-C`, `-c`, `--git-dir`,
      `--work-tree`);
    - `commit` options only from `-m`, `--message`, `-F`, `--file`, `--author`, `--date`, `-t`,
      `--template`, `--cleanup` (each takes the next word, or `=value`), `-s`, `--signoff`, `-q`,
      `--quiet`, `-v`, `--verbose`, `-e`, `--edit`, `--no-edit` and `--`; any other option
      (`--amend`, `--no-verify`, `-n`, `-a`, `--all`, `-i`, `--include`, `-o`, `--only`,
      `--pathspec-from-file`, ...) refuses;
    - `git add` options only from `-v`, `--verbose` and `--`; any other (`-u`, `--update`, `-A`,
      `--all`, `-p`, `-f`, `--pathspec-from-file`, ...) refuses;
    - `git -C <root> symbolic-ref --short HEAD` equals the `branch` of
      `<root>/.stratum/git-guard.json`;
    - every staged path is a line of `<root>/.stratum/approve/owns`. Staged paths =
      `git -C <root> diff --cached --name-only`, plus every non-option word after `git add` and
      every non-option word after `commit` that is not an option's value (a pathspec, with or
      without `--`), each taken relative to `<root>`. An empty, missing or unreadable `owns`,
      `git-guard.json` or git answer counts as a failed rule.
  - Test runners are sent like any other command, for example `npm test`, `npm run test`,
    `npx vitest run`, `cargo test`, `go test ./...`, `pytest`, `uv run pytest`. `ponytail:` `npx`
    and `uv run` can fetch a package they do not find; the orchestrator's judgement covers that.
- The commit rule splits the whole command with `shlex.shlex(command, posix=True,
  punctuation_chars=True)` (`whitespace_split = True`, `commenters = ""` as in the git guard), so
  `-m "demo heredoc"` is one value and `-m "$(cat <<'EOF' ... EOF)"` is one value. It skips each
  redirect token (`<`, `<<`, `<<<`, `>`, `>>`, `&>`, `>&`), the word after it, and a digit-only
  word right before it (so `2>&1` and `2>/dev/null` are one redirect). The words of one git
  command end at `&&`, `||`, `;` or `|`. A command shlex cannot split falls back to the
  white-space split below.
- `ponytail:` forms the commit parse does not read, which the orchestrator judges (W3):
  `GIT=git; $GIT checkout`, `GIT_CONFIG_PARAMETERS=...`, `/bin/sh -c`, `python3 -c` that calls git.
- Other words come from a split on white space (`re.findall(r"\S+", command)`), with leading
  `<>|&;()'"` and trailing `'";)` characters removed. The hook never fails on quoting: a
  command the git guard cannot split (a heredoc with `it's`) is still sent, because that is the
  prompt issue #55 is about. The never list runs on the raw command text.
- Else: writes `<rid>.req` (`<rid>` = `time_ns`-`pid`; a commit request also holds `branch`
  and `staged`), then checks every 1 s, up to 300 s
  (`ST_APPROVE_WAIT` seconds when set to digits, so a test can reach the limit path fast):
  `<rid>.ok` prints
  `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`;
  `<rid>.user` or the limit prints nothing. It removes its `.req`, `.ok` and `.user` files at the
  end. It never prints `deny` and never sets a mode or a rule (one time only).
- `ponytail:` the never list matches text. The orchestrator's rule (approve only a test, a lint,
  an edit inside the worktree or a D23 commit) is the main check, and the list is the backstop.

## 6. `hooks/st-git-guard.py` (changed, US2)

In the `except ValueError` path only:

1. Remove every `\`, `'` and `"` from a copy of each line, so `\git`, `g''it` and `gi\t` read as
   `git`. No copy has a git word: no decision. A git word is `git`, or a path ending in `/git`,
   with a line edge, white space, `;&|()` or a backtick on each side.
2. For each line whose copy has a git word: split the original line with `segments` (shlex
   removes the quoting, so `g''it push` is a git segment). It does not split: ask with
   `The git guard could not parse the command.`. No segment starts with git (after the prefix
   words today's loop skips): ask with `The git guard could not read a git command on this line.`.
   Else judge each git segment with today's `judge`, folder unknown (`elsewhere=True`), and keep
   the strongest decision.
3. The command outside the fallback is judged as today.

## 7. `statusline/st-statusline.sh` (changed, US4)

The main checkout's `.stratum/autonomous` (`git -C <input cwd> rev-parse --path-format=absolute --git-common-dir`, its parent folder; outside git, `<project>/.stratum/autonomous`) with a first line equal to the input's `session_id` (both non-empty):
line 2 left gets the segment `autonomous` (short `auto`) after `ponytail`, colored with the
palette's `contextWarning` background. Else no segment.
