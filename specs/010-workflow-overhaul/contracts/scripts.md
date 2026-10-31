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
```

`<point>` is `plan`, `test`, `diff` or `decisions`. The usage line names every form. Any other
form, an unreadable input, `<n>` outside 1 to 3, a `<base>` that
`git rev-parse --verify --quiet "<base>^{commit}"` rejects, or an empty reason or summary after
CR and LF are replaced: `usage: ...` on stdout, exit 2, nothing recorded, nothing sent.

### 1.2 New commands that call no advisor

| Command | Output (stdout) | Exit | Record |
|---------|-----------------|------|--------|
| `waive plan` | `WAIVED sha256 <h>` / `reason: <r>` / `record: <f>/advisor.md` | 0 | waive entry, `<h>` = today's plan input hash |
| `note` | `noted: <point> /advisor` | 0 | note entry |
| `talk` | `talk recorded: <point>, <n> rounds` | 0 | talk entry |
| `count` | `advisor calls: codex <a>, waived <b>, /advisor <c>` | 0 | none |
| `check plan` after `waive` | `WAIVED sha256 <h>` | 0 | none |

- `waive` needs no `.stratum/advisor.json` and no `codex`. It hashes the plan input with the same
  pipeline as `plan`. A hash failure is `cannot hash inputs`, exit 2, nothing written (L16).
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

`mode` missing from the file = `auto`. Risk comes from `.stratum/state.json` `risk`. Missing or
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
- In herdr (`HERDR_ENV` is `1`, `HERDR_WORKSPACE_ID` is set, `herdr` is on PATH):
  `timeout -k 10 540 bash <scripts>/st-lock.sh --name codex-<workspace id> --timeout 50 -- bash <scripts>/st-codex-agent.sh <feature dir> <prompt file> <answer file> [-m <model>] [-c model_reasoning_effort="<effort>"]`.
- Else: today's `codex exec -s read-only --ignore-user-config ... --ephemeral --output-schema ... -o ...`.
- Both write the answer file. The same validator reads it. Exit 75 from the lock:
  `BLOCKED: Codex agent busy with another review`. Other non-zero: today's
  `BLOCKED: codex exited <rc>` with the last `ERROR:` line.
- `command -v codex` is checked on both paths.

## 2. `scripts/st-codex-agent.sh` (new, US3)

```text
st-codex-agent.sh <feature dir> <prompt file> <answer file> [-m <model>] [-c <key=value>]
```

1. Agent name `st-codex-<NNN>`, `<NNN>` the leading 3 digits of the feature dir's name. None:
   `ERROR: feature dir must start with three digits` on stderr, exit 2.
2. `herdr agent list`. Agents in `$HERDR_WORKSPACE_ID` whose name starts with `st-codex-`: the one
   with this exact name is used. Each other one gets `herdr tab close <its tab_id>` first.
3. None left: `herdr tab create --workspace <ws> --cwd <pwd> --label Codex --no-focus`, then
   `herdr agent start <name> --kind codex --pane <root pane> --timeout 120000 -- -s read-only -a never --no-alt-screen [-m ..] [-c ..]`.
   `agent_pane_busy`: retry, 10 tries, 1 s apart (L30). `agent_not_ready`:
   `ERROR: Codex waits for an answer at start in its Codex tab. Answer it there, then run the point again.`,
   exit 1. Ids are read from herdr's answers, never built (L26).
4. Nonce: 12 hex characters from `/dev/urandom`. The script appends to the prompt file:
   `The project root is <pwd>. Read every path above relative to it.`, the JSON shape line, and
   `Print the line ST-ADVISOR-BEGIN-<nonce> alone, then the JSON object on one line, then the line ST-ADVISOR-END-<nonce> alone. Print nothing after the end line.`
5. `herdr agent prompt <name> "Read the review request in <prompt file> and follow it. Change no file." --wait --until done --until idle --until blocked --timeout <ms>`,
   with `<ms>` = `(480 - SECONDS) * 1000` and `SECONDS=0` at the script's start, so lock wait,
   agent start and review stay inside the caller's 540 s `timeout`.
   A herdr error: `ERROR: <its first line>`, exit 1. State `blocked`:
   `ERROR: Codex waits for an answer in its Codex tab.`, exit 1.
6. `herdr agent read <name> --source recent-unwrapped --lines 400`. Each line has leading `•`
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
| `start --autonomous` | US4 | a flag with no value. Refused unless `<top>/.stratum/autonomous`'s first line equals a non-empty `$CLAUDE_CODE_SESSION_ID`: `Autonomous build mode is off for this session.`, exit 1, before any herdr call. Makes `<worktree>/.stratum/approve/` (local `mkdir`, remote in the same `rsh` write as the brief), with the symlink checks the other files have, and writes `<worktree>/.stratum/approve/owns`: one path per line, the backticked paths of the task file's `Owns:` line, in order; no `Owns:` line gives an empty file (D23). |
| `start` layout | US4 | after `worktree create`, before `agent start`: `tab rename <tab> Main`, `pane split <root pane> --direction right --cwd <wt> --no-focus`, `pane run <new pane> lazygit`, then for `Dev Servers` and `VM`: `tab create --workspace <ws> --cwd <wt> --label <name> --no-focus` and `pane split <its root pane> --direction right --cwd <wt> --no-focus`. Same calls as `st-herdr-workspace.sh:75-94`. The agent starts in the root pane. |
| `wait` | US4 | on `blocked`, first look for `<wt>/.stratum/approve/*.req` (remote: `rsh`). Oldest by name: print `state\tapproval\t<name>\t<pane>`, `request\t<rid>`, `tab\tworkspace <name>, tab Main`, `input\t<tool_name>: <tool_input as one-line JSON, cut at 2000 chars>`, and for a commit request also `branch\t<the .req branch>` and `staged\t<the .req staged paths, split by spaces>`, exit 6. None: today's `blocked`, exit 4. |
| `approve <id> --request <rid> --record <file> [--machine <m>]` | US4 | the autonomous check as `start`; `<rid>` must match `^[0-9]+-[0-9]+$`; `<rid>.req` must exist (`No request <rid> for <name>.`, exit 1); writes `<rid>.ok`; appends one record line (data-model section 7); then `agent wait <name> --until working --timeout 5000` (L34); prints `approved\t<name>\t<rid>`. |
| `pass <id> --request <rid> [--machine <m>]` | US4 | `<rid>` and `.req` checks as `approve`; writes `<rid>.user`; prints `passed\t<name>\t<rid>`. |
| `answer` | US4 | before any key, `agent read <name> --source recent-unwrapped --lines 40`. A read failure or a pane that shows `Do you want to proceed?`: `This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it.`, exit 1, nothing sent. |
| `close` | US4 | also removes `<wt>/.stratum/approve/` (local `rm -rf`, remote `rsh`), with the `.stratum` symlink check. |

## 5. `hooks/st-approve.py` (new, US4) and `hooks/commands.json`

- Registered as `"PermissionRequest": [{"hooks": [{"type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/st-approve.py\"", "timeout": 310}]}]`.
- Reads stdin as bytes (L3). Walks up from `cwd` to the first folder with `.stratum` or `.git`.
  No real folder `<root>/.stratum/approve` (missing, a file or a symlink): exit 0, no output.
  This is the normal-mode path and every non-worker session.
- Never sent to the orchestrator (exit 0, no output, nothing written):
  - a tool other than `Bash`, `Edit`, `Write`, `MultiEdit`, `NotebookEdit`;
  - an edit whose path (`file_path` or `notebook_path`) is missing, resolves outside `<root>`,
    is under `<root>/.git` or `<root>/.stratum`, has a secret-looking name (`.env*`, `*.pem`,
    `*.key`, `id_rsa*`, `id_ed25519*`, `.npmrc`, `.netrc`, a name with `secret` or `credential`)
    or is a dependency file (`package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`,
    `bun.lockb`, `pyproject.toml`, `requirements*.txt`, `uv.lock`, `Cargo.toml`, `Cargo.lock`,
    `go.mod`, `go.sum`, `Gemfile`, `Gemfile.lock`);
  - a Bash command with a `/` or `~` path word (other than `/dev/null`) or a `..` word that
    resolves outside `<root>`, or that matches a push, a branch
    delete, `worktree remove` or `prune`, `reset --hard`, a secret name, a package install or add
    (`npm`, `pnpm`, `yarn`, `bun`, `npx`, `bunx`, `pip`, `uv`, `poetry`, `cargo`, `go get`,
    `go install`, `gem`, `brew`, `apt`, `apt-get`, `dnf`, `yum`, `pacman`, `apk`), a network tool
    (`curl`, `wget`, `ssh`, `scp`, `sftp`, `rsync`, `nc`, `ncat`, `telnet`, `ftp`, `gh`, a URL,
    `git clone`, `fetch`, `pull`, `ls-remote`, `remote add`), `.stratum`, `sudo` or `eval`;
  - a Bash command with a git commit (a `git` word followed by `commit`) unless all D23 rules
    hold: no `--amend`, no `--no-verify`, no `-n`, no `-a`, `--all`, `-i`, `--include`, no
    `-C`, `--git-dir` or `--work-tree`; `git -C <root> symbolic-ref --short HEAD` equals the
    `branch` of `<root>/.stratum/git-guard.json`; and every staged path is a line of
    `<root>/.stratum/approve/owns`. Staged paths = `git -C <root> diff --cached --name-only`, plus
    the path words after `git add` and after `--` in `git commit` in the same command, each
    taken relative to `<root>`. An empty, missing or unreadable `owns`, `git-guard.json` or git
    answer counts as a failed rule.
- Words come from a split on white space (`re.findall(r"\S+", command)`), with leading
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
- `ponytail:` the never list matches text. The orchestrator's rule (approve only a test, a lint
  or an edit inside the worktree) is the main check, and the list is the backstop.

## 6. `hooks/st-git-guard.py` (changed, US2)

In the `except ValueError` path only:

1. No line has a git word: no decision. A git word is `git`, or a path ending in `/git`, with a
   line edge, white space, `;&|()` or a quote or backtick on each side.
2. For each line with a git word: split that line with `segments`. It does not split: ask with
   `The git guard could not parse the command.`. No segment starts with git (after the prefix
   words today's loop skips): ask with `The git guard could not read a git command on this line.`.
   Else judge each git segment with today's `judge`, folder unknown (`elsewhere=True`), and keep
   the strongest decision.
3. The command outside the fallback is judged as today.

## 7. `statusline/st-statusline.sh` (changed, US4)

`<project>/.stratum/autonomous`'s first line equal to the input's `session_id` (both non-empty):
line 2 left gets the segment `autonomous` (short `auto`) after `ponytail`, colored with the
palette's `contextWarning` background. Else no segment.
