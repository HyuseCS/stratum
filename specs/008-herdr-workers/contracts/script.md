# Contract: `scripts/st-worker.sh`

Bash and jq only. Calls `herdr`, `ssh`, `git`, `jq`, `claude`, `timeout`, `mktemp` and `date` by
bare name, so a test can put stubs first on `PATH`. Reads no `HERDR_*_ID` variable and never
passes `--current`. No comments in the file except `ponytail:` markers.

D24 and D25 (decisions.md) are written into sections 3 and 4.

## 1. Usage

```text
st-worker.sh start <id> --task <file> --test <cmd> --lane <text> --roster <file> [--machine <m> --repo <path>]
st-worker.sh goal <id> --test <cmd> [--machine <m>]
st-worker.sh wait <id> [--machine <m>]
st-worker.sh answer <id> [--machine <m>] (--text <text> | --keys <key>...)
st-worker.sh result <id> [--machine <m>]
st-worker.sh close <id> [--machine <m>]
st-worker.sh list [--machine <m>]
st-worker.sh headless <id> --task <file> --test <cmd>
```

- `<id>`: `^[A-Za-z0-9][A-Za-z0-9-]{0,24}$`. The worker name is `worker-` + the id in lower case
  (research R2). `N` below is that name.
- `--keys` is last; every argument after it is one key for `agent send-keys`.
- `--repo` is required with `--machine` on `start`, and only there.
- `headless` has no `--machine` (D15: the headless path runs in the orchestrator's folder).
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
| 4 | `--lane` one line, not empty | `Lane must be one line.` |
| 5 | roster: every line has 4 TAB fields and a `worker-` name; one line is `N` | `Roster line <n> must be: name, machine, branch, task, split by TAB.` / `Roster has no line for <N>.` |
| 6 | the `/goal` prompt (section 4) is at most 4000 characters | `The /goal prompt is over 4000 characters.` |
| 7 | local: `HERDR_ENV` is `1` | `Not inside a herdr pane. Run it from a herdr pane, or name a --machine.` |
| 8 | `start` with `--machine`: `--repo` given and starts with `/` or `~` | `A saved machine needs --repo <path> starting with / or ~.` |
| 9 | `--machine`: `herdr machine list --json` exits 0 and is JSON | `herdr machine list failed.` (or its first stderr line) / `herdr machine list gave no machine list.` |
| 10 | `--machine`: a `label` or `id` matches | `Unknown machine: <m>. Saved: <labels, comma separated>.` |
| 11 | `--machine`: `herdr --machine <m> workspace list` exits 0 | `Machine <m> does not answer: <first stderr line from herdr>` |

Checks 9 to 11 are the ones in `scripts/st-herdr-workspace.sh` (#32 contract section 2, rows 4c0
to 4d), copied with their words. `<target>` is the `target` field of the matched entry and
nothing else (S2).

## 3. Brief (`start`)

Written to `<WT>/brief.md`, where `<WT>` is `.result.worktree.path` from `worktree create`.
Here: the script writes the file. On a saved machine: `ssh -o BatchMode=yes -- <target> "cat > <Q>/brief.md"`
with the brief on stdin, `<Q>` = `printf %q` of `<WT>`.

With the brief, `start` writes `<WT>/.stratum/git-guard.json` with the one line `{"commit":"auto"}`
(D24), after `mkdir -p <WT>/.stratum`. On a saved machine both files go in the same ssh call:
`ssh -o BatchMode=yes -- <target> "cat > <Q>/brief.md && mkdir -p <Q>/.stratum && printf '%s\n' '{\"commit\":\"auto\"}' > <Q>/.stratum/git-guard.json"`.
The script never writes `git-guard.json` anywhere else.

Exact text, with `<...>` filled in. The advisor block is written only when `st-advisor.sh` exists
in the same folder as `st-worker.sh`.

```text
# Brief: <N>

You are worker <N>, started by the Stratum orchestrator. Read this file first and follow it.

## Task <id>

<task file, as is>

## Facts

- Test command: `<test>`
- Lane: <lane>. Start it with the Skill tool. Run only task <id>; skip every other task, ticked or not.
- Branch: <N>
- Your machine: <m or local>. `local` is the orchestrator's machine.
- Result file: <WT>/result.md

## Roster

| Name | Machine | Branch | Task |
|------|---------|--------|------|
| <name> | <machine> | <branch> | <task id> |      (one row per roster line)

## Team rules

1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md or result.md.
2. Fetch before you build on a teammate's work. On your machine the teammate's branch is already in this repo: `git log <branch>`, `git merge <branch>`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work.
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
3 H agent start N --kind claude --pane PANE --timeout 120000 -- --permission-mode auto -n N
4 H agent prompt N P --wait --until working --until blocked --timeout 30000
5 H agent get N                          -> state
```

- `<repo>`: `git rev-parse --show-toplevel` here, `--repo` on a saved machine. `<sha>`:
  `git rev-parse HEAD` here.
- Step 3 answers `agent_not_ready`: print the `worker` line, `state blocked`, then `pane text:` and
  the last 40 lines of `H agent read N --source recent-unwrapped --lines 40` (`.result.read.text`),
  exit 4. No step 4.
- Any other failure at or after step 1: print `stopped: <first stderr line>`, then the `worker`
  line with `-` for every id not made yet, exit 1. Nothing is closed, nothing is retried.

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
1 H agent get N                          state != blocked -> "not blocked: <state>", exit 1, nothing sent
2 --keys: H agent send-keys N <key>...
  --text: H pane send-text <pane> <text>; H agent send-keys N enter
3 H agent get N                          -> state; exit 4 if still blocked, else 0
```

`result`:

```text
F1, F2
1 read <WT>/result.md                    here: the file; saved machine: ssh ... cat -- <Q>/result.md
2 saved machine only: git fetch <target>:<WT> N:N, then git rev-parse --verify N
```

Missing file: `no result file: <WT>/result.md`, then `pane text:` and the 40 pane lines, exit 1.
The pane text is never printed when the file exists.

`close` (research R11):

```text
F1, F2
1 H agent get N                          working|blocked -> refuse, exit 1; an error (agent gone) -> go on
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
3 timeout 540 claude -p <HP> --output-format json --max-turns 30 -n N
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
- Work in this folder. Leave the change uncommitted: never commit, never push.
- Run the test command exactly as written, as one Bash call.
- You cannot ask questions. If you need a decision, stop and say in your last reply what is missing.
```

Exit 124 from `timeout`: `timed out after 540 s`, exit 1. No JSON: `claude gave no JSON result.`,
exit 1. `old != new`: `worker committed: <old> -> <new>`, exit 1. `is_error` true or `subtype` not
`success`: exit 1 after the output.

Rules the test enforces, for every subcommand:

- Never: zero arguments, `pane close`, `worktree remove`, `--group`, `machine reconnect|add|remove|enable|disable`,
  `server`, `--current`, `--session`, `--remote`, `--trust-repository`, the value of any `HERDR_*_ID`.
- Saved machine: every herdr call except `machine list --json` starts `herdr --machine <m>`. Here:
  no call has `--machine`.
- `agent prompt` only in `start` and `goal`, exactly once each. Never in `wait`, `answer`,
  `result`, `close`, `list`.
- `agent start` argv after `--` is exactly `--permission-mode auto -n N` (FR-013).
- `workspace close` only on the `WS` from F1, at most once.

## 5. Output

Stdout, TAB-separated fields, one entity per line. Lines are printed only after the call that
makes their facts succeeded (lessons L20).

```text
worker	<N>	<m|local>	<WS|->	<pane|->	<branch|->	<WT|->      (start)
state	<working|blocked|finished|stopped>	<N>	<pane>          (start, goal, wait, answer)
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

Stubs on `PATH`: `herdr`, `ssh`, `claude`, and a `git` wrapper that logs `fetch` and passes every
other call to the real git. The stub `herdr` logs each argv as one TAB-joined line, gives ids with
a random part per run (L19), makes the `--path` folder on `worktree create`, answers `agent get`
from a state list the case sets, returns pane text `STUB PANE <random>`, and fails a named call on
request. The result file the test writes holds `RESULT FILE <random>`. Expectations come from the
stub log, never from built ids.

| Case | What it asserts |
|------|-----------------|
| S1 | `start` here: one `worktree create` with `--cwd <repo> --branch worker-t004 --base <HEAD sha> --path <parent>/<repo>-worker-t004 --label worker-t004 --no-focus`; brief.md in the stub's path with the task text, test command, lane, the line `Run only task T004; skip every other task, ticked or not.`, result path, every roster row and the four team rules; `<WT>/.stratum/git-guard.json` is `{"commit":"auto"}` and the repo's own `.stratum/git-guard.json` is unchanged; no advisor block; one `agent start` with `-- --permission-mode auto -n worker-t004`; exactly one `agent prompt` with text `P` and `--wait --until working --until blocked`; `worker` line ids from the stub log; exit 0 |
| S2 | same with a dummy `st-advisor.sh` next to a copy of the script: the advisor block is in the brief |
| S3 | `agent start` fails with `agent_not_ready`: `state blocked`, `pane text:`, the stub pane text, no `agent prompt`, exit 4; then `goal` sends exactly one `agent prompt`, exit 0 |
| S4 | `worktree create` fails: `stopped: ` with the stub message, `worker` line with `-` ids, no `agent start`, exit 1 |
| S5 | `agent prompt` fails with `agent_prompt_stalled`: `stopped:` line, no second prompt, nothing closed, exit 1 |
| P1-P8 | each check of section 2 rows 1 to 8: one line with the phrase, no herdr call, exit 1 |
| W1 | `wait`, stub settles `done`, result.md present: `state finished`, exit 0, zero `agent prompt` |
| W2 | `wait`, agent wait times out: `state working` with the pane, exit 3 |
| W3 | `wait`, settles `idle`, no result.md, resume check matches, then `done` with result.md: `state finished`, two `agent wait` without `--until`, exit 0 |
| W4 | `wait`, settles `idle`, no result.md, resume check times out: `state stopped`, pane text, exit 5 |
| W5 | `wait`, `blocked`: `state blocked`, the worker name, pane text, exit 4 |
| A1 | `answer --keys 1`, state `blocked`: one `agent send-keys worker-t004 1`, exit 0 |
| A2 | `answer --text yes`, state `working`: `not blocked: working`, no `send-keys`, no `send-text`, exit 1 (US2 scenario 3) |
| A3 | `answer --text "use main"`, state `blocked`: `pane send-text <pane> use main`, then `agent send-keys worker-t004 enter` |
| G1 | `result` here with result.md: prints `RESULT FILE <random>`, not `STUB PANE`, exit 0 |
| G2 | `result` here, no result.md: `no result file: `, `pane text:`, the stub pane text, exit 1 |
| C1 | `close`, state `done`: one `workspace close` on the stub's WS, `closed`, `folder <WT> ready to remove`, exit 0 |
| C2 | `close`, state `working`: refuse line, no `workspace close`, exit 1 |
| C3 | `close`, stub keeps the agent after close: `close left agent worker-t004`, exit 1 |
| C4 | `close`, no workspace with the label: `No worker worker-t004 on local.`, no `workspace close`, exit 1 |
| L1 | `list` with two worker workspaces and one other workspace: two `found` lines, the other label absent, states from the stub |
| R1 | `start --machine laptop --repo '~/proj'`: every call `--machine laptop` but `machine list --json`; one ssh line `-o BatchMode=yes -- u@stubhost` with `cat > ` and the quoted path and the `git-guard.json` write; the brief on its stdin holds the roster and rules |
| R2 | `result --machine laptop`: ssh `cat --` of the quoted result path, then `git fetch u@stubhost:<WT> worker-t004:worker-t004` in the git log; the test makes branch `worker-t004` in the temp repo first, and the `fetched` line has its sha |
| R3 | `wait --machine laptop`: the result check is an ssh `test -f` |
| R4-R7 | unknown machine, machine down, machine list fails, machine list junk: the #32 lines, no mutating call |
| R8 | `start --machine laptop` with no `--repo`: section 2 row 8 line |
| H1 | `headless`: stub claude argv has exactly the flags in section 4 step 3, the prompt `HP`, the brief file outside the repo; output `headless worker-t004 success <turns> <cost>` and the stub's result text; exit 0 |
| H2 | stub claude commits in the repo: `worker committed: <old> -> <new>`, exit 1 |
| H3 | stub claude exits 124: `timed out after 540 s`, exit 1 |
| H4 | stub claude prints junk: `claude gave no JSON result.`, exit 1 |
| H5 | the brief file is gone after the run |
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
