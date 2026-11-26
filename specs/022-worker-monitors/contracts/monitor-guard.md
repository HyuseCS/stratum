# Contract: the monitor guard in `hooks/st-approve.py`

A PreToolUse rule for one agent only. It is the guard that the checks of SC-003 turn red by removing (research.md R5).

## When it runs

- Event `PreToolUse` and `agent_type` equal to `stratum:st-monitor` (the plugin-scoped name, `hooks.md` line 2740). The hook already runs for Bash, Edit, Write, MultiEdit, NotebookEdit, Read, Grep and Glob (`hooks/commands.json`).
- In `main()` it runs after `lock2` (`hooks/st-approve.py:372-378`). When `lock2` denies a call, that deny and its reason stand, and the monitor rule is not reached. A worker session that starts a `stratum:st-monitor` subagent so gets no call that `lock2` denies today.
- It adds denies only, and its only write is the `owner` file of the owner check below. For a call it allows it prints nothing: no `permissionDecision: allow`. So the user's own permission rules and the classifier still judge that call.
- For every other agent and for the main session nothing changes. `lock2` and `request` do not change (FR-032).
- For a call with `agent_type` `stratum:st-monitor`, any error on its path through `main()` gives a deny: an error in `worker_session`, in `lock2` or in the monitor rule itself. `lock2` itself, and what the hook does for every other caller, do not change (FR-032).

## Monitor folder

Path form: a path that is not absolute, or that has a `.` or `..` part, is denied. The name, `beat` and symlink checks run on the path as given. The git work tree check runs on its real path.

A monitor folder is a folder that meets all of these:

- Its name is `monitor-<id>-<key>`: `<id>` is the worker id in lower case, and `<key>` is 16 letters or digits. The main session makes the folder with `mktemp -d "<scratchpad>/monitor-<id>-XXXXXXXXXXXXXXXX"` before the monitor's first start and gives its path only in that monitor's brief (D36). The key is not the lock: it only keeps the folder name hard to guess in the seconds before the right monitor's first call. The lock is the owner check below.
- Its real path is not inside a git work tree. Inside a git work tree means a folder on the way up from the path holds a `.git` file or folder.
- It already holds a regular file named `beat`. The main session writes that file before each start or continue of a monitor (contracts/st-worker-skill.md C1), so a monitor cannot use a folder that the main session did not prepare.
- The monitor folder itself and the file the call names are not symlinks. A symlink in a parent folder is allowed, for example `/tmp` and `/var` on macOS, which point to `/private/tmp` and `/private/var`.

## Own worker only (FR-035, D36)

A monitor runs commands only for its own worker. The lock is who makes the call: the `agent_id` of the hook input, which Claude Code sets and the model cannot change.

- Every allowed Bash command and every allowed Write names a monitor folder (`--record`, `--beat`, the Write path, the round call's folder), and the folder name must hold the worker id of the same command. That is why `pass` takes `--record` too.
- Owner check, for each such call, as the last check, after every other check of the call passed: when `<folder>/owner` does not exist, the hook makes it with an exclusive create that does not follow a symlink (`O_CREAT | O_EXCL | O_NOFOLLOW`), and writes the `agent_id` of the hook input into it, and the call is allowed. When `<folder>/owner` exists, the call is allowed only if it is a regular file, not a symlink, and its content is equal to the hook input's `agent_id` as exact bytes, with no strip and no added newline.
- A call that another check denies makes no `owner` file.
- A monitor call with no `agent_id`, an empty one, or one that holds a newline or another control character, is denied.
- Revoked folder: a monitor call is denied when any entry named `revoked` exists in the folder it names, whatever its kind (a file, a folder, a symlink, also a broken one), also for the folder's owner. The main session writes `<folder>/revoked` with the Write tool when it stops using a monitor folder, for any reason (contracts/st-worker-skill.md C1). A monitor cannot write it. So one worker has at most one usable folder at any time. An error on this path gives a deny, as the rest of the monitor rule does.
- The `owner` file is the hook's only write. A monitor cannot write it: Write stays at `spec.md` and `views-<n>.md`.
- A continue with SendMessage keeps the same monitor and so the same `agent_id` and `owner`. A new monitor after a stopped one gets a new folder from the main session (contracts/st-worker-skill.md C1), so no `owner` file is ever removed.

## What it allows

1. Bash, when all are true:
   - The raw command has none of: newline, `;`, `&`, `|`, `<`, `>`, `` ` ``, `$`, `(`, `)`.
   - None of `--record`, `--beat`, `--screen`, `--machine` and `--request` is given more than one time (`scripts/st-worker.sh` keeps the last value, so a second one could name a different folder than the one the guard checked).
   - Split with `shlex`, the words are `bash`, a path whose real path is this plugin's `scripts/st-worker.sh`, then one of `wait`, `answer`, `approve`, `pass`, `resend`, then the worker id, then the script's own arguments.
   - `answer` has `--screen` and `--record`. `resend`, `approve` and `pass` have `--record`. `wait` has `--beat`.
   - The `--record` path is `<monitor folder>/record.tsv` and the `--beat` path is `<monitor folder>/beat`, where the folder name is `monitor-<id>-<key>` with `<id>` the worker id of the same command (compared in lower case).
2. Bash: the Codex call of FR-028 (D30), when all are true:
   - The raw command has none of the characters of item 1.
   - Split with `shlex`, the words are exactly these eight: `HERDR_ENV=0`, `bash`, a path whose real path is this plugin's `scripts/st-advisor.sh`, `round`, `decisions`, a monitor folder, `1`, a file named `views-<n>.md` (`<n>` digits) in that folder.
   - Any other `st-advisor.sh` point, round number or env word is denied.
3. Write: when the path is `<monitor folder>/spec.md` or `<monitor folder>/views-<n>.md`. Edit, MultiEdit and NotebookEdit: never (the tools line has no Edit).
4. Read: any path, except a file named `result.md` or `result-round<n>.md`.

## What it denies

Everything else, Grep and Glob included (the tools line has neither), with this reason:

```text
st-monitor runs only st-worker.sh wait, answer, approve, pass and resend, and HERDR_ENV=0 st-advisor.sh round decisions <folder> 1 <file>. It acts only in the monitor folder that its own agent id owns, writes only spec.md and views-<n>.md there, and reads no result file.
```

The output is the same deny shape the hook uses for `lock2` (`hooks/st-approve.py:372-378`).

## Where it fails open

The rule acts only on `agent_type == "stratum:st-monitor"`. That value is known from the docs only. A missing or different value gives no deny, and the unit tests stay green. Quickstart section 3 step 3 is the live check, and it must pass before monitors run on real work.

## Kinds it covers (SC-003)

| FR | Denied calls a test feeds in |
|----|------------------------------|
| FR-010 | `st-worker.sh result`, `followup`, `close`; `git merge <b>`; `gh pr merge`; Write of `<repo>/specs/x/tasks.md`; Read of `<worktree>/result.md` |
| FR-035 | with monitor B's folder `<dir>/monitor-t005-<keyB>/` (with `beat`) whose `owner` holds agent id `idB`, a call with agent id `idA` that names B's full folder: `wait T005 --beat <B folder>/beat`; `answer T005 ... --record <B folder>/record.tsv`; `approve T005 ... --record <B folder>/record.tsv`; `pass T005 --request <rid> --record <B folder>/record.tsv`; `resend T005 --record <B folder>/record.tsv`; Write of `<B folder>/views-1.md`; the round call with `<B folder>` and `<B folder>/views-1.md`. Also: any of these with no `agent_id` or an empty one; any of these when `owner` is a symlink; `pass T004 --request <rid>` (no `--record`); `wait T005 --beat <A folder>/beat` (worker id not in the folder name); any of these on a folder that holds `revoked`, also with the owner's own `agent_id`; a call on a folder where `revoked` is a folder; `wait T004 --beat <A folder>/beat --beat <B folder>/beat`; `answer T004 ... --record <A folder>/record.tsv --record <B folder>/record.tsv`; a second `--screen`, `--machine` or `--request`; an `agent_id` with a newline or a control character. Also: a call with `;` on a folder with no `owner`, and a call on a folder with no `beat`, are denied and leave no `owner` file |
| FR-013 | `st-worker.sh start`, `goal`, `autonomous-on`, `autonomous-off`, `watch`, `list`, `headless` |
| FR-014 | Write of `<repo>/a.txt`; Write of `~/.claude/settings.json`; Write of `<monitor folder>/x.sh`; Write of `<folder named monitor-t004 with no beat file>/spec.md`; Edit of any path; `bash -c 'echo x > f'`; `cp a b`; `answer T004 ... --record ~/.bashrc`; `answer T004 ... --record <dir>/monitor-t005/record.tsv`; `wait T004 --beat <dir>/monitor-t004/other`; a `record.tsv` that is a symlink; a monitor folder that is a symlink; `--record monitor-t004/record.tsv` (relative); `--record <dir>/x/../monitor-t004/record.tsv` (a `..` part); Grep and Glob |
| FR-015 | `st-advisor.sh review`, `diff`, `plan`, `change`, `test`; `round decisions` with round `2` or `3`; `round plan`; the round call with no `HERDR_ENV=0` or with `HERDR_ENV=1`; the round call with a folder that is not a monitor folder, or a file that is not `views-<n>.md` in it; any other script |
| FR-007 | `answer` with no `--screen`; any call with no `--record` where one is needed; `wait` with no `--beat` |
| FR-032 | `wait x --beat <tmp>/monitor-x-<key>/beat` (a valid monitor folder with `beat`) from a cwd inside a worker session (`.stratum/approve` present): the `lock2` reason, not the monitor reason |
| fail closed | with `lock2` made to raise: a deny for the monitor `agent_type`, and no output for `agent_type` `stratum:st-build` |

Allow rows include a monitor folder under a parent folder that is a symlink (as `/tmp` on macOS); the first monitor call for a folder with no `owner`, which makes `owner` with its `agent_id`; a later call with the same `agent_id`; and every command of monitor B on B's own folder with `idB`. Every allow row expects an empty stdout.

Negative controls: remove the `agent_type` branch from `main()` and every deny row of the table goes red; drop the monitor folder rule (name, `beat` file, worker id) and the FR-014 path rows go red; run the monitor rule before `lock2` and the FR-032 row goes red; compare the whole path with its real path again and the symlinked-parent allow row goes red; drop the symlink check and the rows for a folder or a file that is a symlink itself go red; drop the path form check and the relative and `..` rows go red; let the generic `except` in `main()` return for the monitor `agent_type` and the fail-closed row goes red; drop the owner compare and the different-`agent_id` rows go red; let a call with no `agent_id` through and the no-`agent_id` rows go red; follow a symlinked `owner` and the symlink row goes red; drop the worker id compare and the `T005` on A's folder row goes red; let `pass` run with no `--record` and the `pass T004` row goes red; drop the revoked check and the `revoked` rows go red; check only for a regular file named `revoked` and the row where `revoked` is a folder goes red; check only the first occurrence of a flag and the two given-twice rows go red; make `owner` first, before the other checks, and the no-`owner`-left rows go red; strip the `agent_id` or allow control characters and the newline row goes red.
