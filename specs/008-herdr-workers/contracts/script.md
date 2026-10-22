# Contract: `scripts/st-worker.sh`

Bash and jq only. Calls `herdr`, `ssh`, `git`, `jq`, `claude`, `timeout`, `mktemp`, `date` and `sleep` by
bare name, so a test can put stubs first on `PATH`. Reads no `HERDR_*_ID` variable and never
passes `--current`. No comments in the file except `ponytail:` markers.

D24 and D25 (decisions.md) are written into sections 3 and 4.

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
| 7 | local, every subcommand but `headless` (exempt: it makes no herdr call): `HERDR_ENV` is `1` | `Not inside a herdr pane. Run it from a herdr pane, or name a --machine.` |
| 8 | `start` with `--machine`: `--repo` given and starts with `/` or `~` | `A saved machine needs --repo <path> starting with / or ~.` |
| 9 | `--machine`: `herdr machine list --json` exits 0 and is JSON | `herdr machine list failed.` (or its first stderr line) / `herdr machine list gave no machine list.` |
| 10 | `--machine`: a `label` or `id` matches | `Unknown machine: <m>. Saved: <labels, comma separated>.` |
| 11 | `--machine`: `herdr --machine <m> workspace list` exits 0 | `Machine <m> does not answer: <first stderr line from herdr>` |
| 12 | `start`: no workspace in `H workspace list` has the label `N` (a read call, after rows 7 to 11; plan G10, lessons L11) | `A worker <N> already exists.` |
| 13 | `start`, `headless`: the model (from `--model`, or `st-worker.model` in models.json, section 4) matches `^[A-Za-z0-9._-]+$` | `Model must be one token of letters, digits, dot, underscore or dash.` (no herdr or claude call) |

Checks 9 to 11 are the ones in `scripts/st-herdr-workspace.sh` (#32 contract section 2, rows 4c0
to 4d), copied with their words. `<target>` is the `target` field of the matched entry and
nothing else (S2).

## 3. Brief (`start`)

Written to `<WT>/brief.md`, where `<WT>` is `.result.worktree.path` from `worktree create`.
Here: the script writes the file. On a saved machine: `ssh -o BatchMode=yes -- <target> "cat > <Q>/brief.md"`
with the brief on stdin, `<Q>` = `printf %q` of `<WT>` with one leading `\~` turned back into `~`
(the #32 fix, specs/007-herdr-workspace/research.md R3, `scripts/st-herdr-workspace.sh`), so a
`~/...` path that herdr returns still expands on the saved machine. Every `<Q>` below is this one.

With the brief, `start` writes `<WT>/.stratum/git-guard.json` (D24), after
`mkdir -p <WT>/.stratum`. The content `G` is the repo's own guard file merged with the commit key:
read `.stratum/git-guard.json` of the calling folder (`git rev-parse --show-toplevel`, not `<repo>`) if
it exists, else `{}`; set `.commit = "auto"`; write it as one line (`jq -c`). So per-repo keys such
as `"force_push": "deny"` carry over to the worker. On a saved machine both files go in the same
ssh call, with `G` quoted by `printf %q`:
`ssh -o BatchMode=yes -- <target> "cat > <Q>/brief.md && mkdir -p <Q>/.stratum && printf '%s\n' <G quoted> > <Q>/.stratum/git-guard.json"`.
`ponytail:` on a saved machine `G` comes from this machine's repo file; the saved machine's own
repo guard file is not read. The script never writes `git-guard.json` anywhere else.

Exact text, with `<...>` filled in. The advisor block is written only when `st-advisor.sh` exists
in the same folder as `st-worker.sh`.

```text
# Brief: <N>

You are worker <N>, started by the Stratum orchestrator. Read this file first and follow it.

## Task <id>

<task file, as is>

## Facts

- Test command: `<test>`
- Lane: <lane>. If it names a skill, start it with the Skill tool. Run only task <id>; skip every other task, ticked or not.
- Branch: <N>
- Model: <model or default>
- Your machine: <m or local>. `local` is the orchestrator's machine.
- Result file: <WT>/result.md

## Roster

| Name | Machine | Branch | Task |
|------|---------|--------|------|
| <name> | <machine> | <branch> | <task id> |      (one row per roster line)

## Team rules

1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md or .stratum/git-guard.json.
2. Before you build on a teammate's work, merge its branch: `git log <branch>`, `git merge <branch>`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work.
3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.
4. Never merge and never push. The orchestrator reviews every branch and is the only one who merges.

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

Finding a worker (`F`), used by `wait`, `result`, `close`:

```text
F1 H workspace list                      -> WS: the one workspace with label == N
F2 H worktree list --workspace WS        -> WT: .path of the entry with open_workspace_id == WS
```

No match: `No worker <N> on <m or local>.`, exit 1. More than one: `More than one workspace is labelled <N>.`, exit 1.

`start`:

```text
1 H worktree create --cwd <repo> --branch N --base <sha> --path <repo parent>/<repo name>-N --label N --no-focus
                                         -> WS, T, PANE, WT
2 write brief.md and .stratum/git-guard.json (section 3)
3 H agent start N --kind claude --pane PANE --timeout 120000 -- --permission-mode auto -n N [--model M]
4 H agent prompt N P --wait --until working --until blocked --timeout 30000
5 H agent get N                          -> state
```

- `<repo>`: here, the main checkout, `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`,
  also when the script runs in a linked worktree: herdr refuses a linked worktree as the source
  (`linked_worktree_source`, research R3). On a saved machine, `--repo`. `<repo parent>` and
  `<repo name>` in `--path` come from that same `<repo>`. `<sha>`: `git rev-parse HEAD` of the
  calling folder.
- Step 3 answers `agent_pane_busy` (the new pane's shell is not at its prompt yet, research R1):
  `sleep 1` and run step 3 again, up to 10 tries in total. `ponytail:` fixed 10 s bound, the same
  shape as D20 in specs/007-herdr-workspace. Any other error, or still busy after the 10th try, is
  the normal stop below.
- Step 3 answers `agent_not_ready`, or step 4 answers `agent_blocked` (a dialog is up; herdr sends
  no input): print the `worker` line, `state blocked`, then `pane text:` and the last 40 lines of
  `H agent read N --source recent-unwrapped --lines 40`, the command's plain text output printed as
  is (`agent read` prints raw pane lines, not JSON), exit 4. After step 3
  there is no step 4. `goal` is the next step once the dialog is answered.
- Any other failure at or after step 1: print `stopped: <first stderr line>`, then the `worker`
  line with `-` for every id not made yet, exit 1. Nothing is closed, nothing else is retried.

Model `M` (D27, D28, `start` and `headless`): `--model <name>` if given. Else
`jq -r '."st-worker".model // empty'` of `<top>/.stratum/models.json`, where `<top>` is the calling
folder's `git rev-parse --show-toplevel` (as for the guard file). A missing file, an unparsable
file or a missing `st-worker.model` means no model, and no `--model` is passed (`ponytail:`
ignored, not an error). A present value from either source goes through section 2 row 13 before
any command line. `effort` is not read: `claude` has no flag for it here.

`goal` (after a `start` that ended `blocked`): steps 4 and 5.

`wait` (research R6), bound 540 s from the first call:

```text
F1, F2
1 H agent wait N --timeout <ms left>     timeout error -> state working, exit 3
2 H agent get N                          blocked -> state blocked, pane text, exit 4
3 idle|done: result.md in WT?            yes -> state finished, exit 0
                                         no  -> H agent wait N --until working --until blocked --timeout 10000
                                                matched -> back to 1; else state stopped, pane text, exit 5
```

The result file check is `test -f <WT>/result.md` here and
`ssh -o BatchMode=yes -- <target> test -f <Q>/result.md` on a saved machine. `unknown` counts as
`working` for step 3 (back to 1).

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
F1, F2
1 read <WT>/result.md                    here: the file; saved machine: ssh ... cat -- <Q>/result.md
2 saved machine only: GIT_SSH_COMMAND='ssh -o BatchMode=yes' git fetch <target>:<WT> N:N, then git rev-parse --verify N
```

Missing file: `no result file: <WT>/result.md`, then `pane text:` and the 40 pane lines, exit 1.
The pane text is never printed when the file exists.

`close` (research R11):

```text
F1, F2
1 H agent get N                          working|blocked -> "Worker <N> is <state>. Close refused.", exit 1; an error (agent gone) -> go on
2 H workspace close WS
3 H agent list, H workspace list         N still there -> "close left <agent|workspace> <N>", exit 1
```

`list`:

```text
1 H workspace list                       labels starting worker-
2 H agent list                           state and pane per name; no agent -> gone, -
3 H worktree list --workspace WS         path, per worker
```

`headless` (research R12): no herdr call.

```text
1 cd "$(git rev-parse --show-toplevel)"; old=$(git rev-parse HEAD)
2 brief to a mktemp file outside the repo (headless text below), removed on exit
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

- Never: zero arguments, `pane close`, `worktree remove`, `--group`, `machine reconnect|add|remove|enable|disable`,
  `server`, `--current`, `--session`, `--remote`, `--trust-repository`, the value of any `HERDR_*_ID`.
- Saved machine: every herdr call except `machine list --json` starts `herdr --machine <m>`. Here:
  no call has `--machine`.
- `agent prompt` only in `start` and `goal`, exactly once each. Never in `wait`, `answer`,
  `result`, `close`, `list`.
- `agent start` argv after `--` is exactly `--permission-mode auto -n N`, plus `--model M` when a
  model is set (FR-013, FR-017).
- `workspace close` only on the `WS` from F1, at most once.

## 5. Output

Stdout, TAB-separated fields, one entity per line. Lines are printed only after the call that
makes their facts succeeded (lessons L20).

```text
worker	<N>	<m|local>	<WS|->	<pane|->	<branch|->	<WT|->      (start)
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
`found	<N>	<m|local>	<WS>	<pane|->	<state|gone>	<WT>`. No worker: `no workers on <m|local>`, exit 0.

## 6. Test cases (`tests/test_st_worker.sh`)

Stubs on `PATH`: `herdr`, `ssh`, `claude`, `timeout` (logs its arguments, then execs the rest of
the argv), and a `git` wrapper that logs `fetch` and passes every
other call to the real git. The stub `herdr` logs each argv as one TAB-joined line, gives ids with
a random part per run (L19), makes the `--path` folder on `worktree create`, answers `agent get`
from a state list the case sets, returns pane text `STUB PANE <random>`, and fails a named call on
request. The result file the test writes holds `RESULT FILE <random>`. Expectations come from the
stub log, never from built ids.

| Case | What it asserts |
|------|-----------------|
| S1 | `start` here: one `worktree create` with `--cwd <repo> --branch worker-t004 --base <HEAD sha> --path <parent>/<repo>-worker-t004 --label worker-t004 --no-focus`; brief.md in the stub's path with the task text, test command, lane, the line `Run only task T004; skip every other task, ticked or not.`, result path, every roster row and the four team rules; with no guard file in the repo, `<WT>/.stratum/git-guard.json` is `{"commit":"auto"}` and the repo still has no guard file; no advisor block; one `agent start` with `-- --permission-mode auto -n worker-t004`; exactly one `agent prompt` with text `P` and `--wait --until working --until blocked`; `worker` line ids from the stub log; exit 0 |
| S1b | `start` here with the repo file `.stratum/git-guard.json` = `{"force_push":"deny"}`: `<WT>/.stratum/git-guard.json` is the one line `{"force_push":"deny","commit":"auto"}`; the repo file is unchanged |
| S2 | same with a dummy `st-advisor.sh` next to a copy of the script: the advisor block is in the brief |
| S3 | `agent start` fails with `agent_not_ready`: `state blocked`, `pane text:`, the stub pane text, no `agent prompt`, exit 4; then `goal` sends exactly one `agent prompt`, exit 0 |
| S4 | `worktree create` fails: `stopped: ` with the stub message, `worker` line with `-` in every id field and in the branch field, no `agent start`, exit 1 |
| S5 | `agent prompt` fails with `agent_prompt_stalled`: `stopped:` line, no second prompt, nothing closed, exit 1 |
| S6 | `start` when `workspace list` already has the label `worker-t004`: one line `A worker worker-t004 already exists.`, no `worktree create`, no other mutating call, exit 1 (plan G10, lessons L11) |
| S7 | `agent prompt` fails with `agent_blocked`: `worker` line, `state blocked`, `pane text:`, the stub pane text, no second prompt, nothing closed, exit 4; then `goal` sends exactly one `agent prompt` |
| S10 | `start` run from a linked worktree of the temp repo: `worktree create` has `--cwd <main checkout>` and `--path <main checkout parent>/<main checkout name>-worker-t004`, `--base` is HEAD of the linked worktree, and the guard file is read from the linked worktree's `.stratum/git-guard.json` |
| S11 | the stub's `agent start` answers `agent_pane_busy` on the first N calls (N below 10), then succeeds; a stub `sleep` exits 0 at once: the log shows N+1 `agent start` calls with the same argv and N `sleep 1`, then one `agent prompt`, exit 0 |
| S11b | `agent start` answers `agent_pane_busy` on every call: exactly 10 `agent start` calls, then `stopped: ` with the stub's `agent_pane_busy` line, the `worker` line, no `agent prompt`, nothing closed, exit 1 |
| P1-P7 | each check of section 2 rows 1 to 7: one line with the phrase, no herdr call, exit 1 |
| P2b | `start` with a task file that exists but is empty: section 2 row 2 line, no herdr call, exit 1 |
| P5b | roster with an empty TAB field on one line: section 2 row 5 line `Roster line <n> must be ...`, exit 1; a roster that ends with a blank line passes the check |
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
| C1 | `close`, state `done`: one `workspace close` on the stub's WS, `closed`, `folder <WT> ready to remove`, exit 0 |
| C2 | `close`, state `working`: the exact line `Worker worker-t004 is working. Close refused.`, no `workspace close`, exit 1 |
| C3 | `close`, stub keeps the agent after close: `close left agent worker-t004`, exit 1 |
| C4 | `close`, no workspace with the label: `No worker worker-t004 on local.`, no `workspace close`, exit 1 |
| C5 | `close`, `agent get` fails (agent gone): one `workspace close` on the stub's WS, `closed`, `folder <WT> ready to remove`, exit 0 |
| L1 | `list` with two worker workspaces and one other workspace: two `found` lines, the other label absent, states from the stub |
| R1 | `start --machine laptop --repo '~/proj'`: every call `--machine laptop` but `machine list --json`; `worktree create` has `--path ~/proj-worker-t004`; the stub answers that path as `.result.worktree.path`; one ssh line `-o BatchMode=yes -- u@stubhost` with `cat > ` and the `git-guard.json` write, holding `~/proj-worker-t004/` unescaped (no `\~`); the brief on its stdin holds the roster and rules |
| R2 | `result --machine laptop`: ssh `cat --` of the quoted result path, then `git fetch u@stubhost:<WT> worker-t004:worker-t004` in the git log with `GIT_SSH_COMMAND=ssh -o BatchMode=yes` in its environment (the wrapper logs it); the test makes branch `worker-t004` in the temp repo first, and the `fetched` line has its sha |
| R3 | `wait --machine laptop`: the result check is an ssh `test -f` |
| R4-R7 | unknown machine, machine down, machine list fails, machine list junk: the #32 lines, no mutating call |
| R8 | `start --machine laptop` with no `--repo`: section 2 row 8 line |
| R9 | `close --machine laptop`: every herdr call starts `--machine laptop` but `machine list --json`; `closed` line |
| R10 | `answer --machine laptop --keys 1`, state `blocked`: same `--machine` rule; one `agent send-keys` |
| R11 | `goal --machine laptop --test <cmd>`: same `--machine` rule; exactly one `agent prompt` |
| R12 | `list --machine laptop`: same `--machine` rule; `found` lines name `laptop` |
| H1 | `headless`: stub claude argv has exactly the flags in section 4 step 3, the prompt `HP`, the brief file outside the repo; output `headless worker-t004 success <turns> <cost>` and the stub's result text; exit 0; the `timeout` log has `-k 10 540` |
| H2 | stub claude commits in the repo: `worker committed: <old> -> <new>`, exit 1 |
| H3 | stub claude exits 124: `timed out after 540 s`, exit 1 |
| H3b | stub claude commits, then exits 124: the `worker committed` line wins, not `timed out`, exit 1 |
| H4 | stub claude prints junk: `claude gave no JSON result.`, exit 1 |
| H5 | the brief file is gone after the run |
| H6 | stub claude prints `subtype` `error_max_turns` and `is_error` true: the `headless` line and the result text print, exit 1 |
| H7 | `HERDR_ENV` unset: `headless` still runs, exit 0 |
| H8 | `headless --machine laptop`: exit 2, no herdr, ssh or claude call |
| H9 | run from a subfolder of the repo: the script `cd`s to the toplevel first, the brief is outside the repo, the `HEAD` compare works (H2's commit is still caught) |
| H10 | `headless --test 'a *'`: one line `Test command must not contain * for headless.`, no claude call, exit 1 |
| M1 | `start --model opus`: `agent start` argv ends `-n worker-t004 --model opus`; the brief has `- Model: opus` |
| M2 | `start` with no `--model`, models.json `{"st-worker":{"model":"sonnet"}}`: `--model sonnet` in the `agent start` argv; brief `- Model: sonnet` |
| M3 | `start` with no `--model` and no models.json: no `--model` in any argv; brief `- Model: default` (S1 stays as it is) |
| M4 | `start --model 'a b'` and `start --model 'x;y'`: the row 13 line, exit 1, no herdr call |
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

NC1 to NC7 each name one line the build keeps unique, so the `sed` that breaks it matches once.
Every case also asserts the never-list and the `--machine` rule of section 4. Each NC first checks
that its copy differs from the script, then runs the real script on the same input and state and
needs it green right before the copy runs (lessons L18).
