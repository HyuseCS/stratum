# Contract: the monitor guard in `hooks/st-approve.py`

A PreToolUse rule for one agent only. It is the guard that the checks of SC-003 turn red by removing (research.md R5).

## When it runs

- Event `PreToolUse` and `agent_type` equal to `stratum:st-monitor` (the plugin-scoped name, `hooks.md` line 2740). The hook already runs for Bash, Edit, Write, MultiEdit, NotebookEdit, Read, Grep and Glob (`hooks/commands.json`).
- For every other agent and for the main session nothing changes. `lock2` and `request` do not change (FR-032).
- For `stratum:st-monitor` it fails closed: an error while it judges the call gives a deny.

## What it allows

1. Bash, when all are true:
   - The raw command has none of: newline, `;`, `&`, `|`, `<`, `>`, `` ` ``, `$`, `(`, `)`.
   - Split with `shlex`, the words are `bash`, a path whose real path is this plugin's `scripts/st-worker.sh`, then one of `wait`, `answer`, `approve`, `pass`, `resend`, then the script's own arguments.
   - `answer` has `--screen` and `--record`. `resend` and `approve` have `--record`. `wait` has `--beat`.
   - The `--record` and `--beat` paths are not inside a git work tree.
2. Bash: the Codex call of FR-028 (D30), when all are true:
   - The raw command has none of the characters of item 1.
   - Split with `shlex`, the words are exactly these eight: `HERDR_ENV=0`, `bash`, a path whose real path is this plugin's `scripts/st-advisor.sh`, `round`, `decisions`, a folder, `1`, a file.
   - The folder and the file are not inside a git work tree.
   - Any other `st-advisor.sh` point, round number or env word is denied.
3. Write, Edit, MultiEdit, NotebookEdit: when the path (joined with the cwd, both as given and as its real path) is not inside a git work tree. Inside a git work tree means a folder on the way up from the path holds a `.git` file or folder.
4. Read: any path, except a file named `result.md` or `result-round<n>.md`.
5. Grep and Glob: any.

## What it denies

Everything else, with this reason:

```text
st-monitor runs only st-worker.sh wait, answer, approve, pass and resend, and HERDR_ENV=0 st-advisor.sh round decisions <folder> 1 <file>. It writes no file inside a git work tree and reads no result file.
```

The output is the same deny shape the hook uses for `lock2` (`hooks/st-approve.py:372-378`).

## Where it fails open

The rule acts only on `agent_type == "stratum:st-monitor"`. That value is known from the docs only. A missing or different value gives no deny, and the unit tests stay green. Quickstart section 3 step 3 is the live check, and it must pass before the release.

## Kinds it covers (SC-003)

| FR | Denied calls a test feeds in |
|----|------------------------------|
| FR-010 | `st-worker.sh result`, `followup`, `close`; `git merge <b>`; `gh pr merge`; Write or Edit of `<repo>/specs/x/tasks.md`; Read of `<worktree>/result.md` |
| FR-013 | `st-worker.sh start`, `goal`, `autonomous-on`, `autonomous-off`, `watch`, `list`, `headless` |
| FR-014 | Write of `<repo>/a.txt`; Edit of `<worktree>/src/x.sh`; `bash -c 'echo x > f'`; `cp a b` |
| FR-015 | `st-advisor.sh review`, `diff`, `plan`, `change`, `test`; `round decisions` with round `2` or `3`; `round plan`; the round call with no `HERDR_ENV=0`; the round call with its folder or file inside a git work tree; any other script |
| FR-007 | `answer` with no `--screen`; any call with no `--record` where one is needed; `wait` with no `--beat` |

Negative control for each row: remove the `agent_type` branch from `main()` and the same test goes red.
