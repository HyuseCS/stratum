# Contract: `scripts/st-worker.sh`

Bash and jq only. Calls `herdr`, `ssh`, `git`, `jq`, `claude`, `timeout`, `mktemp`, `date` and `sleep` by
bare name, so a test can put stubs first on `PATH`. Reads one `HERDR_*_ID` variable,
`HERDR_WORKSPACE_ID`, only in `start` on this machine (FR-018), and never passes `--current`. No
comments in the file except `ponytail:` markers.

D24 and D25 (decisions.md) are written into sections 3 and 4. #71 (D31 to D35): a pane worker is one
tab labelled `N` (research R17); sections 2 to 6 say how.

## 1. Usage

```text
st-worker.sh start <id> --task <file> --test <cmd> --lane <text> --roster <file> [--machine <m> --repo <path>] [--model <name>]
st-worker.sh goal <id> --test <cmd> [--machine <m>]
st-worker.sh wait <id> [--machine <m>]
st-worker.sh answer <id> [--machine <m>] (--text <text> | --keys <key>...)
st-worker.sh result <id> [--machine <m>]
st-worker.sh close <id> [--machine <m>]
st-worker.sh list [--machine <m>]
st-worker.sh headless <id> --task <file> --test <cmd> [--model <name>]
```

- `<id>`: `^[A-Za-z0-9][A-Za-z0-9-]{0,24}$`. The worker name is `worker-` + the id in lower case
  (research R2), always: an id that already starts with `worker-` gets the prefix again. `N`
  below is that name.
- `--keys` is last; every argument after it is one key for `agent send-keys`.
- `answer`: a key or a text value that starts with `-` is refused with
  `Answer values must not start with -.`, exit 2, before any herdr call. No `--` is passed to
  herdr: live T008, `herdr agent send-keys worker-t901 -- 1` failed with `invalid_key: unsupported key --`.
- `--repo` is required with `--machine` on `start`, and only there.
- `headless` has no `--machine` (D15: the headless path runs in the orchestrator's folder):
  `headless --machine ...` is a usage error, exit 2, no call.
- `--model` (D27, FR-017): at most once and not empty; given twice or empty is a usage error,
  exit 2.
- Every value is one argument. No `eval`, no `bash -c` on user text.

Exit codes:

| Code | Meaning |
|------|---------|
| 0 | done: started, finished, answered, result read, closed, listed, headless green |
| 1 | stopped or refused: a check or a call failed; one line says why |
| 2 | usage error: unknown subcommand or option, missing value |
| 3 | `wait`: still working when the bound ran out |
| 4 | `start`, `goal`, `wait`, `answer`: the worker is `blocked` |
| 5 | `wait`: the worker stopped with no result file |

## 2. Checks before any herdr call that changes something

Each failure prints exactly one line (to stderr) and exits 1. The script builds every line below
(lessons L1); tests assert these words, not words from the input.

| # | Check | Line |
|---|-------|------|
| 1 | id shape | `Task id must be letters, digits or dash, start with a letter or digit, and be at most 25 characters.` |
| 2 | `--task` file exists and is not empty (`start`, `headless`) | `Task file not found or empty: <file>` |
| 3 | `--test` one line, not empty, no `(` or `)` | `Test command must be one line with no ( or ).` |
| 3b | `headless` only: `--test` has no `*` (a `*` makes `Bash(<test>)` a wildcard rule) | `Test command must not contain * for headless.` |
| 4 | `--lane` one line, not empty | `Lane must be one line.` |
| 5 | roster: every line has 4 TAB fields and a `worker-` name; one line is `N` | `Roster line <n> must be: name, machine, branch, task, split by TAB.` / `Roster has no line for <N>.` |
| 6 | the `/goal` prompt (section 4) is at most 4000 characters | `The /goal prompt is over 4000 characters.` |
| 7 | local, every subcommand but `headless` (exempt: it makes no herdr call): `HERDR_ENV` is `1`; local `start` only: `HERDR_WORKSPACE_ID` is not empty | `Not inside a herdr pane. Run it from a herdr pane, or name a --machine.` |
| 8 | `start` with `--machine`: `--repo` given and starts with `/` or `~` | `A saved machine needs --repo <path> starting with / or ~.` |
| 9 | `--machine`: `herdr machine list --json` exits 0 and is JSON | `herdr machine list failed.` (or its first stderr line) / `herdr machine list gave no machine list.` |
| 10 | `--machine`: a `label` or `id` matches | `Unknown machine: <m>. Saved: <labels, comma separated>.` |
| 11 | `--machine`: `herdr --machine <m> workspace list` exits 0 | `Machine <m> does not answer: <first stderr line from herdr>` |
| 12 | `start`: no tab in `H tab list` (every workspace) has the label `N` (a read call, after rows 7 to 11; plan G10, lessons L11) | `A worker <N> already exists.` |
| 13 | `start`, `headless`: the model (from `--model`, or `st-worker.model` in models.json, section 4) matches `^[A-Za-z0-9][A-Za-z0-9._-]*$` (first character a letter or digit, so a value like `--dangerously-skip-permissions` cannot land after `--model` as an option) | `Model must be one token of letters, digits, dot, underscore or dash, starting with a letter or digit.` (no herdr or claude call) |

Checks 9 to 11 are the ones in `scripts/st-herdr-workspace.sh` (#32 contract section 2, rows 4c0
to 4d), copied with their words. `<target>` is the `target` field of the matched entry and
nothing else (S2).

## 3. Brief (`start`)

Written to `<WT>/brief.md`, where `<WT>` is the `<path>` that `start` gave `git worktree add`
(section 4), after `tab create` succeeded.
Here: the script writes the file. On a saved machine: `ssh -o BatchMode=yes -- <target> "cat > <Q>/brief.md"`
with the brief on stdin, `<Q>` = `printf %q` of `<WT>` with one leading `\~` turned back into `~`
(the #32 fix, specs/007-herdr-workspace/research.md R3, `scripts/st-herdr-workspace.sh`), so a
`~/...` path from `--repo` still expands on the saved machine. Every `<Q>` below is this one.

With the brief, `start` writes `<WT>/.stratum/git-guard.json` (D24), after
`mkdir -p <WT>/.stratum`. The content `G` is the repo's own guard file merged with the commit key:
read `.stratum/git-guard.json` of the calling folder (`git rev-parse --show-toplevel`, not `<repo>`) if
it exists, else `{}`; set `.commit = "auto"` and `.branch = "worker-<id>"`; write it as one line (`jq -c`). So per-repo keys such
as `"force_push": "deny"` carry over to the worker. On a saved machine both files go in the same
ssh call, with `G` quoted by `printf %q`:
`ssh -o BatchMode=yes -- <target> "cat > <Q>/brief.md && mkdir -p <Q>/.stratum && printf '%s\n' <G quoted> > <Q>/.stratum/git-guard.json"`.
`ponytail:` on a saved machine `G` comes from this machine's repo file; the saved machine's own
repo guard file is not read. The script never writes `git-guard.json` anywhere else.

Exact text, with `<...>` filled in. `<plugin root>` is the parent of the script's own folder,
`$(cd "$(dirname "$0")/.." && pwd)`. The advisor block is written only when `st-advisor.sh` exists
in the same folder as `st-worker.sh`. On a saved machine the brief has no `- Plugin root:` line and
no `## Advisor` block: both name paths on this machine.

```text
# Brief: <N>

You are worker <N>, started by the Stratum orchestrator. Read this file first and follow it.

## Task <id>

<task file, as is>

## Facts

- Test command: `<test>`
- Test lock: if your task is marked [lock], run its test command as `bash <plugin root>/scripts/st-lock.sh -- <test command>`, with the plugin root of the Stratum plugin. Never write a wait loop of your own.
- Lane: <lane>. If it names a skill, start it with the Skill tool. Run only task <id>; skip every other task, ticked or not.
- Branch: <N>
- Model: <model or default>
- Plugin root: <plugin root>
- Your machine: <m or local>. `local` is the orchestrator's machine.
- Result file: <WT>/result.md

## Roster

| Name | Machine | Branch | Task |
|------|---------|--------|------|
| <name> | <machine> | <branch> | <task id> |      (one row per roster line)

## Team rules

1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md, .stratum/git-guard.json or .stratum/approve/, and never write in .stratum/approve/.
2. Before you build on a teammate's work, merge its branch: `git log <branch>`, `git merge <branch>`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work.
3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.
4. Never merge into the base branch and never push. Merging a teammate's branch into your own (rule 2) is fine. The orchestrator reviews every branch and is the only one who merges into the base.

## Questions

Ask a question only with the AskUserQuestion tool, then wait for the answer. Do not ask in plain text and do not guess.
Do not edit tasks.md or .stratum/state.json. The orchestrator ticks the task after the merge.

## When done

Write the result file with four lines:
Built: <what you built>
Tests: <test command> exit <code>
Commit: <sha>
Open: <open points, or none>

## Advisor

The Codex advisor is installed (`scripts/st-advisor.sh` in the Stratum plugin). At each advisor point your lane names, run it and follow its verdict.
```

## 4. herdr calls, per subcommand

`H` is `herdr` here and `herdr --machine <m>` on a saved machine. Every call goes through `H`
except `machine list --json`. Ids come only from the JSON of a call (`jq -er`; a missing field is
a failed call). `P` is the prompt:

```text
/goal `<test>` exits 0, the change is committed on branch <N>, and result.md is written; read brief.md in this folder first and follow it
```

Finding a worker (`F`, research R17), used by `wait`, `result`, `close`, `followup`, `approve`,
`pass` and `watch`:

```text
F1 H tab list                            -> the one tab with label == N: TAB (.tab_id), WS (.workspace_id)
F2 H pane list --workspace WS            -> C: .cwd of the first pane with tab_id == TAB
F3 H worktree list --cwd C               -> WT: .path of the entry with branch == N
```

`ponytail:` F2 takes the cwd of the first pane in the worker tab only, so a `cd` out of the
worktree in a stopped worker's pane breaks F3; upgrade path: fall back to
`<repo parent>/<repo name>-N` when F3 finds no entry with `branch == N`. The script carries the
matching `# ponytail:` marker at F2.

No match in F1, F2 or F3: `No worker <N> on <m or local>.`, exit 1. More than one tab in F1:
`More than one tab is labelled <N>.`, exit 1.

`start`:

```text
0 H tab list                             -> a tab labelled N anywhere: row 12 line, exit 1
0b saved machine, `--repo` starts with `~`: `ssh -o BatchMode=yes -- <target> "cd <repo> && pwd"`, once (`<repo>` quoted as in section 3, `~` kept)
                                         -> one line that starts with `/` is `<repo>`; else `stopped: no absolute path for --repo on <m>`, exit 1
1 WS                                     here: $HERDR_WORKSPACE_ID
                                         saved machine: H worktree list --cwd <repo> -> .open_workspace_id of the
                                         entry with is_linked_worktree == false; absent ->
                                         H workspace list -> .workspace_id of the first workspace labelled st-workers; none ->
                                         H workspace create --cwd <repo> --label st-workers --no-focus -> .result.workspace.workspace_id
                                         (D35)
2 [ ! -e <path> ] || { echo "<path> already exists" >&2; exit 1; }; git -C <repo> worktree add -q -b N <path> <sha> || exit 1              (saved machine: the same string in one ssh call)
                                         -> BR = N, WT = <path>
3 H tab create --workspace WS --cwd <path> --label N --no-focus
                                         -> TAB (.result.tab.tab_id), PANE (.result.root_pane.pane_id)
  fails -> git -C <repo> worktree remove <path> && git -C <repo> branch -D N >/dev/null   (saved machine: one ssh call)
           then the stop below with the herdr line (D33)
4 write brief.md and .stratum/git-guard.json (section 3), the autonomous files, then worker-setup.sh
5 H pane split PANE --direction right --cwd <path> --no-focus -> p (.result.pane.pane_id); H pane run p lazygit
6 H agent start N --kind claude --pane PANE --timeout 120000 -- --permission-mode auto -n N [--model M]
7 H agent prompt N P --wait --until working --until blocked --timeout 30000
8 H agent get N                          -> state
```

- `<repo>`: here, the main checkout, `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`,
  also when the script runs in a linked worktree. On a saved machine, `--repo` (step 0b first when it starts with `~`). `<path>` is
  `<repo parent>/<repo name>-N` from that same `<repo>`. `<sha>`: `git rev-parse HEAD` of the
  calling folder. Over ssh every value is `printf %q` quoted, `~` restored as in section 3.
- Step 0b (since f0d61fc). Its ssh failures follow the step 2 rules: exit 255 prints the `ssh to` line, any other failure prints the first stderr line of the failed `cd`. After 0b `<repo>` is absolute, so every `--cwd` herdr gets (`workspace create`, `tab create`, `pane split`) is absolute. Herdr does not expand a leading `~` in `--cwd` (research R17). Step 0b is one extra ssh call, and it runs only when `--repo` starts with `~`. No section 6 case covers the `no absolute path` stop.
- The order is fixed: step 3 comes right after step 2, so on a failed tab the folder holds
  nothing of the script's and `git worktree remove` needs no `--force`. Step 3 is the only undo:
  it removes only the folder and the branch step 2 made in the same run, before any agent ran.
  If the undo fails too, the stop line is `stopped: <herdr line>; left <path> and branch N` and the
  `worker` line keeps BR and WT. After a good undo every field of the `worker` line but N and m is `-`.
- A folder at `<path>` left by an earlier run stops step 2 before git runs, with `stopped: <path> already exists`. A branch `N` left by an earlier worker makes git fail: the stop below with git's
  first stderr line. Nothing is undone, nothing was made.
- The workspace a saved-machine `start` makes in step 1 is labelled `st-workers` and keeps its own
  first tab; an open `st-workers` workspace is reused before a new one is made, so the workers of
  one run share it. `close` closes it once no `worker-*` tab is left in it (D35). Step 1 never
  uses this machine's `HERDR_WORKSPACE_ID` on a saved machine: herdr ids are valid on one server
  only. Here step 1 is always the orchestrator's own workspace.
- Gone since #71: `worktree create`, `tab rename ... Main`, the `Dev Servers` and `VM` tabs, and the
  S9 stop (the script now names the path itself).
- On a saved machine the ssh write of step 4 that fails with ssh's own exit 255 prints
  `stopped: ssh to <target> failed: <first stderr line>`; any other failure prints
  `stopped: cannot write brief.md and .stratum/git-guard.json in <WT> on <m>: <first stderr line>`.
  Both then print the `worker` line, exit 1 (R1c). The step 0b and step 2 ssh calls that fail with exit 255
  prints the same `ssh to` line. The step 2 string ends with `|| exit 1`, so git's own failure there exits 1 and prints its first stderr line instead (R16b).
- Step 6 answers `agent_pane_busy` (the new pane's shell is not at its prompt yet, research R1):
  `sleep 1` and run step 6 again, up to 10 tries in total. `ponytail:` fixed 10 s bound, the same
  shape as D20 in specs/007-herdr-workspace. Any other error, or still busy after the 10th try, is
  the normal stop below.
- Step 6 answers `agent_not_ready`, or step 7 answers `agent_blocked` (a dialog is up; herdr sends
  no input): print the `worker` line, `state blocked`, then `pane text:` and the last 40 lines of
  `H agent read N --source recent-unwrapped --lines 40`, the command's plain text output printed as
  is (`agent read` prints raw pane lines, not JSON), exit 4. After step 6
  there is no step 7. `goal` is the next step once the dialog is answered.
- Any other failure at or after step 1: print `stopped: <first stderr line>`, then the `worker`
  line with `-` for every id not made yet, exit 1. Nothing is closed, nothing else is retried, and
  nothing but step 3's undo is removed.
- Known gap (not built, not tested): when `tab create` exits 0 but its answer has no `.result.tab.tab_id` or no `.result.root_pane.pane_id`, `get` stops with `stopped: no <jq path> in the herdr answer`, and step 3's undo does not run. The folder and the branch stay, the `worker` line shows them, and a tab herdr made may stay too. Upgrade: run the undo on this stop too, with a stub case where `tab create` exits 0 with `{"result":{}}`.

Model `M` (D27, D28, `start` and `headless`): `--model <name>` if given. Else
`jq -r '."st-worker".model // empty'` of `<top>/.stratum/models.json`, where `<top>` is the calling
folder's `git rev-parse --show-toplevel` (as for the guard file). A missing file, an unparsable
file or a missing `st-worker.model` means no model, and no `--model` is passed (`ponytail:`
ignored, not an error). A present value from either source must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` (section 2 row 13) before
any command line. `effort` is not read: `claude` has no flag for it here.

`goal` (after a `start` that ended `blocked`): steps 7 and 8.

`wait` (research R6), bound 540 s from the first call:

```text
F1, F2, F3
1 H agent wait N --timeout <ms left>     timeout error -> state working, exit 3
2 H agent get N                          blocked -> state blocked, pane text, exit 4
3 idle|done: result.md in WT?            yes -> state finished, exit 0
                                         no  -> H agent wait N --until working --until blocked --timeout 10000
                                                matched -> back to 1; else state stopped, pane text, exit 5
```

The result file check is `test -f <WT>/result.md` here and
`ssh -o BatchMode=yes -- <target> test -f <Q>/result.md` on a saved machine. `unknown` counts as
`working` for step 3 (back to 1). An ssh that fails with exit 255 prints
`stopped: ssh to <target> failed: <first stderr line>`, exit 1; any other ssh failure on `test -f`
means no result file yet (R3b).

`answer`:

```text
0 a value starts with -                  -> "Answer values must not start with -.", exit 2, no herdr call
1 H agent get N                          state != blocked -> "not blocked: <state>", exit 1, nothing sent
2 --keys: H agent send-keys N <key>...
  --text: H pane send-text <pane> <text>; H agent send-keys N enter
3 H agent wait N --until working --timeout 5000   a timeout error only means still blocked
4 H agent get N                          -> state; exit 4 if still blocked, else 0
```

Step 1 is one line of the script: the `blocked` check and the `not blocked: <state>` print
together (NC5 deletes exactly that line). Step 3 is there because live T008 showed `blocked`
lingering about 2 s after a dialog key (research R7). `ponytail:` fixed 5 s bound. Step 4 prints
the `state` line of section 5,
`state<TAB><state><TAB><N><TAB><pane>`, with every state but `blocked` printed as `working`,
as `start` and `goal` do. `answer` never prints the pane text.

A typed answer to an AskUserQuestion dialog is two `answer` calls. Live T008 (research R7): the
dialog lists numbered options, then `Type something.` and `Chat about this`; a digit key picks
an option. So first `answer <id> --keys <number of "Type something.">`, which is expected to leave
the worker `blocked` at the text field (exit 4; not yet seen live), then `answer <id> --text <text>`.

`result`:

```text
F1, F2, F3
1 read <WT>/result.md                    here: the file; saved machine: ssh ... cat -- <Q>/result.md
2 saved machine only: GIT_SSH_COMMAND='ssh -o BatchMode=yes' git fetch <target>:<WT> N:N, then git rev-parse --verify N
```

Missing file: `no result file: <WT>/result.md`, then `pane text:` and the 40 pane lines, exit 1.
The pane text is never printed when the file exists. On a saved machine, an ssh that fails with
exit 255 is not a missing file: `stopped: ssh to <target> failed: <first stderr line>`, exit 1, no
`no result file` line and no pane text (R2b).

`close` (research R11, R17, FR-018):

```text
F1, F2, F3
1 H agent get N                          working|blocked -> "Worker <N> is <state>. Close refused.", exit 1; an error (agent gone) -> go on
1b D30                                   open PR -> refused; .stratum a symlink -> "Worker <N>: .stratum is a symlink. Close refused.", exit 1; rm -f <WT>/.stratum/git-guard.json (ssh on a saved machine), fails -> "Worker <N>: cannot remove .stratum/git-guard.json. Close refused.", exit 1
2 H tab close TAB
3 saved machine only: H workspace list  WS gone -> no call; WS label != st-workers -> no call
  H tab list --workspace WS              a tab label starting worker- -> no call; none -> H workspace close WS
4 H agent list, H tab list               N still there -> "close left <agent|tab> <N>", exit 1
```

`tab close` runs once, only on the TAB from F1. `workspace close` runs at most once, only on the
WS from F1, only on a saved machine, only when that workspace is labelled `st-workers` and holds no
tab labelled `worker-*` after the `tab close` (D35, FR-018), never with `--group`. A
`workspace close` that herdr refuses is the normal stop with herdr's line. The `st-workers` label is
reserved for the script: any workspace with that label on a saved machine counts as the script's,
also one the user made by hand (D36). So a local `close` never closes a workspace, and a workspace
with any other label (the main checkout one included) is never closed.

`list`:

```text
1 H tab list                             labels starting worker-: TAB, WS per worker
2 H agent list                           state and pane per name; no agent -> gone, -
3 F2, F3 per worker                      path; not found -> -
```

`headless` (research R12): no herdr call.

```text
1 cd "$(git rev-parse --show-toplevel)"; old=$(git rev-parse HEAD)
2 brief to a mktemp file outside the repo (headless text below), removed on exit
2b git status --porcelain is not empty   -> "Working tree is not clean.", exit 1, no claude call
3 timeout -k 10 540 claude -p <HP> --output-format json --max-turns 30 -n N [--model M]
    --tools Read,Edit,Write,Glob,Grep,Bash
    --allowedTools Read Edit Write Glob Grep "Bash(<test>)"
    --permission-mode dontAsk --permission-prompts none --strict-mcp-config
4 new=$(git rev-parse HEAD)
```

`HP` = ``/goal `<test>` exits 0 and the change is left uncommitted; read <brief file> first and follow it``.
Headless brief:

```text
# Brief: <N> (headless)

## Task <id>

<task file, as is>

## Facts

- Test command: `<test>`
- Model: <model or default>
- Work in this folder. Leave the change uncommitted: never commit, never push.
- Run the test command exactly as written, as one Bash call.
- You cannot ask questions. If you need a decision, stop and say in your last reply what is missing.
```

`-k 10` sends SIGKILL 10 s after the SIGTERM at 540 s, so a run never passes the Bash tool's
600 s. The exit rules are checked in this order, the first that holds wins:
1. `old != new`: `worker committed: <old> -> <new>`, exit 1.
2. Exit 124 or 137 from `timeout`: `timed out after 540 s`, exit 1.
3. No JSON: `claude gave no JSON result.`, exit 1.
4. `is_error` true or `subtype` not `success`: the `headless` line and `result:` text print, exit 1.

`ponytail:` the commit guard compares `HEAD` only; a push, a stash or a commit on another branch
is not seen. Widen to `git for-each-ref` if a live run shows a need (research R12).

Rules the test enforces, for every subcommand:

- Never: zero arguments, `pane close`, herdr `worktree remove`, `--group`, `machine reconnect|add|remove|enable|disable`,
  `server`, `--current`, `--session`, `--remote`, `--trust-repository`, the value of `HERDR_TAB_ID`
  or `HERDR_PANE_ID`. The script reads `HERDR_WORKSPACE_ID` only in a local `start`: in the row 7 check and as `WS`, for
  `tab create`. The same workspace id may come back from `tab list` (F1), so it may appear only as
  the value after `--workspace` on a `tab create` or `pane list` line, never on a `tab close` or
  `workspace close` line, and never on a saved machine (FR-018).
- Saved machine: every herdr call except `machine list --json` starts `herdr --machine <m>`. Here:
  no call has `--machine`.
- `agent prompt` only in `start` and `goal`, exactly once each. Never in `wait`, `answer`,
  `result`, `close`, `list`.
- `agent start` argv after `--` is exactly `--permission-mode auto -n N`, plus `--model M` when a
  model is set (FR-013, FR-017).
- `tab create` only in `start`, exactly once. `tab close` only in `close`, on the `TAB` from F1, at
  most once. `workspace close` only in `close` on a saved machine, on the `WS` from F1, at most
  once, only when WS is labelled `st-workers` (reserved for the script, D36) and no `worker-*` tab
  is left in it. Never on a workspace with any other label.
  `workspace create` only in `start` on a saved machine with no open main checkout and no open
  `st-workers` workspace, at most once, always with `--label st-workers`.
- git: `worktree add` only in `start`; `worktree remove` and `branch -D` only in `start`, only after a
  failed `tab create`, only on the path and branch `worktree add` made in that run (D33).

## 5. Output

Stdout, TAB-separated fields, one entity per line. Lines are printed only after the call that
makes their facts succeeded (lessons L27).

```text
worker	<N>	<m|local>	<tab|->	<pane|->	<branch|->	<WT|->     (start; field 4 is the tab id, D34)
state	<working|blocked|finished|stopped>	<N>	<pane>          (start, goal, wait, answer; start, goal and answer print working for every state but blocked; answer prints no pane text)
pane text:                                                        (then the pane lines as they are)
result	<N>	<WT>/result.md                                       (then the file as it is)
fetched	<N>	<sha>                                                (result, saved machine)
closed	<N>
folder	<WT>	ready to remove
headless	<N>	<subtype>	<num_turns>	<total_cost_usd>
result:                                                           (headless, then the JSON result text)
```

`list` prints one `found` line per worker:
`found	<N>	<m|local>	<tab>	<pane|->	<state|gone>	<WT|->`. Field 4 is the tab id (D34). No worker: `no workers on <m|local>`, exit 0.

`wait` on `approval` (autonomous mode) prints `tab	tab <N>` in place of the old
`tab	workspace <N>, tab Main`, and `approve` writes `tab <N>` as the third field of its record line
(the user finds the worker by its tab label).

## 6. Test cases (`tests/test_st_worker.sh`)

Stubs on `PATH`: `herdr`, `ssh`, `claude`, `timeout` (logs its arguments, then execs the rest of
the argv), and a `git` wrapper that logs `fetch`, `worktree add`, `worktree remove` and `branch -D`
and passes every other call to the real git. Since #71 the wrapper does `worktree add` itself (makes
the folder with a `.stratum/` inside, the `STUB_WT_LINK` cases, records path and branch for
`worktree list`), so the temp repo gets no real branch or worktree; `worktree remove` deletes the
folder, `branch -D` only logs. The stub `ssh` records the same on a `git ... worktree add` line, and answers `cd <dir> && pwd` with the path under `/stubhome` (`~` becomes `/stubhome`), so a `--repo '~/proj'` case sees `/stubhome/proj`. The
stub `herdr` logs each argv as one TAB-joined line, gives ids with
a random part per run (L26), keeps the tabs `tab create` and `workspace create` make (with
workspace, label and cwd) for `tab list`, `pane list` and `tab close`, answers `agent get`
from a state list the case sets, returns pane text `STUB PANE <random>` as plain text (the live CLI prints text, research R1), and fails a named call on
request. The result file the test writes holds `RESULT FILE <random>`. Expectations come from the
stub log, never from built ids.

| Case | What it asserts |
|------|-----------------|
| S1 | `start` here: one git `-C <repo> worktree add -q -b worker-t004 <parent>/<repo>-worker-t004 <HEAD sha>` in the git log; no herdr `worktree create`; then exactly one `tab create --workspace w1P --cwd <parent>/<repo>-worker-t004 --label worker-t004 --no-focus` (`w1P` is the test's `HERDR_WORKSPACE_ID`), one `pane split <root pane> --direction right --cwd <WT> --no-focus`, one `pane run <new pane> lazygit`, no `tab rename`, no `Dev Servers` or `VM` label; `agent start --pane` is the root pane of the `tab create` answer; brief.md in that path with the task text, test command, lane, the line `Run only task T004; skip every other task, ticked or not.`, result path, every roster row and the four team rules; the line `- Plugin root: <dir>` where `<dir>` is the parent of the folder that holds the script under test; with no guard file in the repo, `<WT>/.stratum/git-guard.json` is `{"commit":"auto","branch":"worker-t004"}` and the repo still has no guard file; no advisor block; one `agent start` with `-- --permission-mode auto -n worker-t004`; exactly one `agent prompt` with text `P` and `--wait --until working --until blocked`; `worker` line field 4 is the tab id and field 5 the root pane id of the `tab create` answer; exit 0 |
| S1b | `start` here with the repo file `.stratum/git-guard.json` = `{"force_push":"deny","branch":"main"}`: `<WT>/.stratum/git-guard.json` is the one line `{"force_push":"deny","commit":"auto","branch":"worker-t004"}`; the repo file is unchanged |
| S2 | same with a dummy `st-advisor.sh` next to a copy of the script: the advisor block is in the brief |
| S3 | `agent start` fails with `agent_not_ready`: `state blocked`, `pane text:`, the stub pane text, no `agent prompt`, exit 4; then `goal` sends exactly one `agent prompt`, exit 0 |
| S4 | git `worktree add` fails (the wrapper's `STUB_GIT_FAIL`): `stopped: ` with the wrapper's message, `worker` line with `-` in every id field and in the branch and path fields, no `tab create`, no `worktree remove`, no `branch -D`, no `agent start`, exit 1 |
| S4b | `<path>` already exists before `start`: one line `stopped: <path> already exists`, the `worker` line with `-` in fields 4 to 7, no `worktree add` in the git log, no `tab create`, exit 1 |
| S5 | `agent prompt` fails with `agent_prompt_stalled`: `stopped:` line, no second prompt, nothing closed, exit 1 |
| S6 | `start` when `tab list` already has a tab labelled `worker-t004` in another workspace: one line `A worker worker-t004 already exists.`, only `tab list` calls, no git `worktree add`, exit 1 (plan G10, lessons L11) |
| S7 | `agent prompt` fails with `agent_blocked`: `worker` line, `state blocked`, `pane text:`, the stub pane text, no second prompt, nothing closed, exit 4; then `goal` sends exactly one `agent prompt` |
| S8 | `start` with `agent get` answering `idle` after the prompt: the `state` line says `working`, no `idle` word, exit 0 |
| S9 | Removed by #71: the script names the path itself, so herdr cannot put it elsewhere |
| S10 | `start` run from a linked worktree of the temp repo: git `worktree add` has `-C <main checkout>` and the path `<main checkout parent>/<main checkout name>-worker-t004`, the commit is HEAD of the linked worktree, and the guard file is read from the linked worktree's `.stratum/git-guard.json` |
| S13 | `tab create` fails (`STUB_FAIL="tab create"`): the git log has, in order, `worktree add`, `-C <repo> worktree remove <WT>`, `-C <repo> branch -D worker-t004`; the folder is gone; one `stopped: ` line with the first stderr line of the failed `tab create` (herdr's JSON error line); the `worker` line has `-` in fields 4 to 7; no brief, no `pane split`, no `agent start`, exit 1. A second `start` with no `STUB_FAIL` then exits 0 (D33) |
| S13b | `tab create` fails and the wrapper fails `worktree remove`: one line `stopped: <the JSON error line of the failed tab create>; left <WT> and branch worker-t004`, the `worker` line keeps `worker-t004` and `<WT>` in fields 6 and 7, exit 1 |
| S11 | the stub's `agent start` answers `agent_pane_busy` on the first N calls (N below 10), then succeeds; a stub `sleep` exits 0 at once: the log shows N+1 `agent start` calls with the same argv and N `sleep 1`, then one `agent prompt`, exit 0 |
| S11b | `agent start` answers `agent_pane_busy` on every call: exactly 10 `agent start` calls, then `stopped: ` with the stub's `agent_pane_busy` line, the `worker` line, no `agent prompt`, nothing closed, exit 1 |
| P1-P7 | each check of section 2 rows 1 to 7: one line with the phrase, no herdr call, exit 1 |
| P2b | `start` with a task file that exists but is empty: section 2 row 2 line, no herdr call, exit 1 |
| P5b | roster with no line for `N`: `Roster has no line for worker-t004.`, no herdr call, exit 1 |
| P5c | roster line with an empty TAB field: section 2 row 5 line `Roster line 1 must be ...`, no herdr call, exit 1 |
| P5d | roster that ends with a blank line starts: exit 0, two roster rows in the brief |
| W1 | `wait`, stub settles `done`, result.md present: `state finished`, exit 0, zero `agent prompt` |
| W2 | `wait`, agent wait times out: `state working` with the pane, exit 3 |
| W3 | `wait`, settles `idle`, no result.md, resume check matches, then `done` with result.md: `state finished`, two `agent wait` without `--until`, exit 0 |
| W4 | `wait`, settles `idle`, no result.md, resume check times out: `state stopped`, pane text, exit 5 |
| W5 | `wait`, `blocked`: `state blocked`, the worker name, pane text, exit 4 |
| A1 | `answer --keys 1`, states `blocked` before and `working` after: one `agent send-keys worker-t004 1`, then one `agent wait worker-t004 --until working --timeout 5000` before the last `agent get`, the line `state<TAB>working<TAB>worker-t004<TAB><pane>`, exit 0 |
| A2 | `answer --text yes`, state `working`: `not blocked: working`, no `send-keys`, no `send-text`, exit 1 (US2 scenario 3) |
| A3 | `answer --text "use main"`, states `blocked` before and after (the stub's `agent wait --until working` times out): `pane send-text <pane> use main`, then `agent send-keys worker-t004 enter`, then the `agent wait`, the line `state<TAB>blocked<TAB>worker-t004<TAB><pane>`, exit 4 |
| A4 | `answer --keys -x` and `answer --text -x`: each prints `Answer values must not start with -.`, exit 2, no herdr call |
| G1 | `result` here with result.md: prints `RESULT FILE <random>`, not `STUB PANE`, exit 0 |
| G2 | `result` here, no result.md: `no result file: `, `pane text:`, the stub pane text, exit 1 |
| C1 | `close`, state `done`, the worker tab in `w1P` beside the orchestrator's own tab `w1P:t1`: finds the worker through `tab list`, `pane list --workspace w1P`, `worktree list --cwd <WT>`; one `tab close` on the worker's tab id; zero `workspace close`; `w1P:t1` in no call; `closed`, `folder <WT> ready to remove`, exit 0 |
| C2 | `close`, state `working`: the exact line `Worker worker-t004 is working. Close refused.`, no `workspace close`, exit 1 |
| C3 | `close`, stub keeps the agent after close: `close left agent worker-t004`, exit 1 |
| C4 | `close`, no tab with the label: `No worker worker-t004 on local.`, no `tab close`, no `workspace close`, exit 1 |
| C5 | `close`, `agent get` fails (agent gone): one `tab close` on the worker's tab, zero `workspace close`, `closed`, `folder <WT> ready to remove`, exit 0 |
| C11 | `close` with no GitHub remote: no `gh` call; one `tab close` on the worker's tab, zero `workspace close`, `closed` and `folder <WT> ready to remove`, exit 0 |
| C8 | as before, with `tab list` in place of `workspace list` for the after-close check: `close left tab worker-t004: cannot read the list` |
| C13 | `close` with tabs `worker-t004` and `worker-t005` and the orchestrator's tab in `w1P`: exactly one `tab close`, on worker-t004's tab id; the other two tabs are still in `tab list` |
| C14 | `close --machine laptop`, the worker tab is in a workspace labelled `st-workers` whose only other tab is its first tab (not `worker-*`): one `tab close`, then one `workspace close <WS>` with no `--group`, `closed`, exit 0 (D35) |
| C15 | as C14, but the stub removes the workspace with the tab: one `tab close`, zero `workspace close`, `closed`, exit 0 |
| C17 | `close --machine laptop`, the `st-workers` workspace still holds the tab `worker-t005`: one `tab close` on worker-t004's tab, zero `workspace close`, `worker-t005` still in `tab list` (D35) |
| C18 | local `close`, the orchestrator's workspace `w1P` labelled `st-workers` in the stub and no other worker tab: one `tab close`, zero `workspace close` (a local `close` never closes a workspace) |
| C16 | two tabs labelled `worker-t004`: `More than one tab is labelled worker-t004.`, no `tab close`, exit 1 |
| L1 | `list` with two worker tabs and one other tab: two `found` lines, field 4 each worker's tab id, the other label absent, states from the stub, paths from `worktree list --cwd` |
| L2 | `list` with an idle worker tab: state `unsent` when its prompt is still in the box, `blocked` when the pane shows an open question; field 4 the tab id, exit 0 |
| R1 | `start --machine laptop --repo '~/proj'`, the stub's `worktree list --cwd /stubhome/proj` has a main entry open in `stubMainWS` with one other tab: every call `--machine laptop` but `machine list --json`; `w1P` in no call; no `workspace create`; three ssh calls in order: first `cd ~/proj && pwd` (step 0b; the stub answers `/stubhome/proj`), then the step 2 string for `/stubhome/proj` and `/stubhome/proj-worker-t004`, ending `git -C /stubhome/proj worktree add -q -b worker-t004 /stubhome/proj-worker-t004 <HEAD sha> || exit 1`, then the brief write with `cat > /stubhome/proj-worker-t004/brief.md` and the `git-guard.json` write, no `\~`; between the second and the third call `tab create --workspace stubMainWS --cwd /stubhome/proj-worker-t004 --label worker-t004 --no-focus`; the brief on the third call's stdin holds the roster and rules, `- Result file: /stubhome/proj-worker-t004/result.md`, and has no `- Plugin root:` line and no `## Advisor` line |
| R1d | as R1, run from a copy of the script with a dummy `st-advisor.sh` next to it: the brief on ssh stdin still has no `- Plugin root:` line and no `## Advisor` line |
| R1b | Folded into R1 by #71: the path is always the one `--repo` gives |
| R15 | as R1, but the main entry has no `open_workspace_id` and no workspace is labelled `st-workers`: one `workspace create --cwd /stubhome/proj --label st-workers --no-focus` (the stub's answer for `--repo '~/proj'`), then `tab create --workspace <the WS it answered>` (D32, D35) |
| R15b | as R15, but `workspace list` has a workspace labelled `st-workers`: no `workspace create`, `tab create --workspace <that WS>` (D35 reuse) |
| R17 | `start --machine laptop --repo '~/proj'` with `STUB_NO_MAIN_WS=1` (no workspace has the main checkout open): every `--cwd` herdr gets is absolute and no herdr call has a `--cwd` that does not start with `/`: `workspace create --cwd /stubhome/proj --label st-workers --no-focus`, `tab create --workspace <the WS it answered> --cwd /stubhome/proj-worker-t004`, `pane split ... --cwd /stubhome/proj-worker-t004`; exit 0 (f0d61fc). No case covers the `no absolute path` stop of step 0b |
| R16 | as R1, `tab create` fails: the third ssh call, after `cd` and the worktree add, is the undo `git -C /stubhome/proj worktree remove /stubhome/proj-worker-t004 && git -C /stubhome/proj branch -D worker-t004 >/dev/null`, no brief ssh call, `stopped: ` with the stub message, exit 1 (D33) |
| R16b | `start --machine laptop`, git `worktree add` exits 255 on the remote: `stopped: fatal: ...` with git's first stderr line and no `ssh to` text, the `worker` line with `-` in fields 4 to 7, no `tab create`, exit 1 (the `|| exit 1` of step 2) |
| R1c | `start --machine laptop`, ssh exits 255: one `stopped: ssh to u@stubhost failed` line, one `worker` line, exit 1 |
| R14 | `start --machine laptop --repo <tmp>/rrepo` with no ssh exec: ssh holds `cat > <tmp>/rrepo-worker-t004/brief.md`, and `<tmp>/rrepo-worker-t004` does not exist on this machine after `start` |
| R2 | `result --machine laptop`: ssh `cat --` of the quoted result path, then `git fetch u@stubhost:<WT> worker-t004:worker-t004` in the git log with `GIT_SSH_COMMAND=ssh -o BatchMode=yes` in its environment (the wrapper logs it); the test makes branch `worker-t004` in the temp repo first, and the `fetched` line has its sha |
| R2b | `result --machine laptop`, ssh exits 255: one `stopped: ssh to u@stubhost failed` line, no `no result file` line, no pane text, exit 1 |
| R3 | `wait --machine laptop`: the result check is an ssh `test -f` |
| R3b | `wait --machine laptop`, settles `done`, `test -f` says no and the resume check times out: `state stopped`, exit 5 |
| R4-R7 | unknown machine, machine down, machine list fails, machine list junk: the #32 lines, no mutating call |
| R8 | `start --machine laptop` with no `--repo`: section 2 row 8 line |
| R8b | `start --machine laptop --repo proj` (no leading `/` or `~`): the same line |
| R9 | `close --machine laptop`: every herdr call starts `--machine laptop` but `machine list --json`; one `tab close`; zero `workspace close` (the main checkout tab stays in `stubMainWS`); `closed` line |
| R10 | `answer --machine laptop --keys 1`, state `blocked`: same `--machine` rule; one `agent send-keys` |
| R11 | `goal --machine laptop --test <cmd>`: same `--machine` rule; exactly one `agent prompt` |
| R12 | `list --machine laptop`: same `--machine` rule; `found` lines name `laptop`, field 4 the tab id |
| H1 | `headless`: stub claude argv has exactly the flags in section 4 step 3, the prompt `HP`, the brief file outside the repo; output `headless worker-t004 success <turns> <cost>` and the stub's result text; exit 0; the `timeout` log has `-k 10 540` |
| H2 | stub claude commits in the repo: `worker committed: <old> -> <new>`, exit 1 |
| H2b | stub claude commits and prints junk: the `worker committed` line wins, no `no JSON` line, exit 1 |
| H3 | stub claude exits 124: `timed out after 540 s`, exit 1 |
| H3b | stub claude commits, then exits 124: the `worker committed` line wins, not `timed out`, exit 1 |
| H3c | stub claude exits 137 (killed): `timed out after 540 s`, exit 1 |
| H4 | stub claude prints junk: `claude gave no JSON result.`, exit 1 |
| H5 | the brief file is gone after the run |
| H6 | stub claude prints `subtype` `error_max_turns` and `is_error` true: the `headless` line and the result text print, exit 1 |
| H7 | `HERDR_ENV` unset: `headless` still runs, exit 0 |
| H8 | `headless --machine laptop`: exit 2, no herdr, ssh or claude call |
| H9 | run from a subfolder of the repo: the script `cd`s to the toplevel first, the brief is outside the repo, the `HEAD` compare works (H2's commit is still caught) |
| H10 | `headless --test 'a *'`: one line `Test command must not contain * for headless.`, no claude call, exit 1 |
| H12 | the repo has an uncommitted change, a modified tracked file or an untracked file: one line `Working tree is not clean.`, no claude call, exit 1. The test repo ignores `.stratum/models.json` (as st-init does), so M6 keeps a clean tree |
| M1 | `start --model opus`: `agent start` argv ends `-n worker-t004 --model opus`; the brief has `- Model: opus` |
| M2 | `start` with no `--model`, models.json `{"st-worker":{"model":"sonnet"}}`: `--model sonnet` in the `agent start` argv; brief `- Model: sonnet` |
| M3 | `start` with no `--model` and no models.json: no `--model` in any argv; brief `- Model: default` (S1 stays as it is) |
| M4 | `start --model 'a b'` and `start --model 'x;y'`: the row 13 line, exit 1, no herdr call |
| M4d | models.json `{"st-worker":{"model":"--dangerously-skip-permissions"}}`, no `--model`: `start` and `headless` each print the row 13 line, exit 1, no herdr or claude call |
| M5 | `headless --model opus`: the claude argv has `--model opus` right after `-n worker-t004` |
| M6 | `headless` with no `--model`, models.json `{"st-worker":{"model":"sonnet"}}`: `--model sonnet` right after `-n worker-t004` |
| M7 | `--model` given twice, or `--model ''`: usage, exit 2, no call |
| NC1 | copy without the line that adds `--machine` to `H`: R1 goes red (SC-007) |
| NC2 | copy without the roster rows: S1 goes red (SC-007) |
| NC3 | copy without team rule 1: S1 goes red (SC-007) |
| NC4 | copy whose `result` reads the pane in place of the file: G1 goes red (SC-007) |
| NC5 | copy without the `blocked` check in `answer`: A2 goes red (FR-006) |
| NC6 | copy without `--allowedTools ...`: H1 goes red (L10) |
| NC7 | copy without the `git-guard.json` write: S1 goes red (D24) |
| NC8 | copy with the `st-workers` guard before `workspace close` in `close` disabled (the checks that the machine is a saved one, the label is `st-workers` and no `worker-*` tab is left), so `workspace close` runs after every `tab close`: R9 goes red, a `workspace close` on `stubMainWS` shows (FR-018, D35) |
| NC9 | copy with the D33 undo of `start` disabled (the removal of the worktree and branch after a failed `tab create`): S13 goes red (D33) |
| LY1, LY2 | (from specs/010) rewritten: in order `tab create`, `pane split`, `pane run ... lazygit`, `agent start`; no `tab rename`, no second `tab create` |
| WA1, AP1 | (from specs/010) the `tab` line is `tab	tab worker-t004`; the record's third field is `tab worker-t004` |

Every case asserts the never-list of section 4 with the `HERDR_*` rule as written there: the
test's `w1P` appears only as the value after `--workspace` on a `tab create` or `pane list` line,
`w1P:` (the tab and pane ids) in no call, and on a saved machine `w1P` in no call.
P7b: a local `start` with `HERDR_ENV=1` and an empty `HERDR_WORKSPACE_ID` prints the row 7 line,
no herdr call, exit 1.

NC1 to NC7 each name one line the build keeps unique, so the `sed` that breaks it matches once.
NC8 and NC9 are defined by the behaviour they disable; the test finds that behaviour in the
script as built and disables it in the copy, so they put no layout rule on the script.
Every case also asserts the never-list and the `--machine` rule of section 4. Each NC first checks
that its copy differs from the script, then runs the real script on the same input and state and
needs it green right before the copy runs (lessons L25).
