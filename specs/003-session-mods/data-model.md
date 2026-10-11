# Data Model: Mods That Talk To and Start Other Sessions

The spike stores no data. The one structure is the `## Spike report` in `research.md`.
`spikes/check.sh` reads it line by line, so this file is the single definition of its format.

## Line format

Every field is one line: `- <Field>: <value>`. An empty value means "not filled". A value is
compared after trimming white space. Labels are lower case.

## Entities

### Question (Q1 to Q5)

Section `### Q<n>. <question text>`.

| Field | Rule |
|-------|------|
| Answer | not empty |
| Evidence | not empty. A doc source (`file:line`), a command and its output, or a spike file path. A reasoned guess is not evidence (CHK008) |

### Test result (Test 1, Test 2, Test 3)

Section `### Test <n>. <title>`.

| Field | Rule |
|-------|------|
| Outcome | Test 1: `full pass`, `partial pass` or `blocked`. Test 2 and Test 3: `pass` or `blocked` (CHK006: "full pass" and "partial pass" exist only for test 1, where D9 defines them) |
| Approaches tried | not empty. Approach IDs from plan.md: `A1`-`A3` (test 1), `B1`-`B3` (test 2), `C1`-`C3` (test 3). Each with its result, `;` between them. At most 3 distinct IDs, none above 3 |
| Evidence | not empty |
| Limit | `none` when the outcome is a pass. The exact error text or the missing feature when `blocked` or `partial pass` |
| Result back | Test 2 and 3 only: `yes` or `no` (FR-005 definition in plan.md). `yes` needs the raw reply quoted in Evidence: `spk003-t2<x>-ok` for test 2, `spk003-t3<x>-ok` for test 3, `<x>` in `a`-`c` |
| Human step | Test 2 and 3 only: `none`, or what the human did after the start call and before the result (an answered permission prompt counts). For test 2 the user's `/spike-start` is the trigger and does not count (D17). `pass` needs `none` |
| Stops | Test 2 and 3 only: `yes` or `no` (FR-006 held for this test) |
| ListAgents | Test 3 only: `seen` or `not seen`, and which approach (FR-016) |
| SendMessage | Test 3 only: `delivered` or `not delivered`, and what the receiver showed |
| Over the Agent tool | Test 3 only: not empty |

Test 1, "second session not running" (CHK010): a send that fails because the peer was not running
is a retry of the same approach, not a fail of the API. It is noted in Approaches tried and does
not make the test `blocked`.

### Started session

One row per session a test starts, in the table under `### Started sessions`:

`| Name | Test | Approach | Argv | Turn limit | Started | Stopped | Stopped by | Process check |`

| Field | Rule |
|-------|------|
| Name | holds `spk003` |
| Argv | the exact command. Holds `haiku` (FR-012) |
| Turn limit | `--max-turns 3`, or `no tools` where the start method refused a turn limit (FR-012, D14). The Argv holds `--max-turns 3` or `--tools ""` to match |
| Started, Stopped | clock times `HH:MM:SS`, same day. The Argv holds `timeout 300`, or Stopped minus Started is at most 300 seconds |
| Stopped by | exit, `timeout`, `claude stop` + `claude rm`, module unload, or `cleanup.sh` |
| Process check | the `check.sh` result with no `FAIL R5` |

State: `running` -> `done` (exit 0) or `failed` (exit not 0, signal, or timeout) -> `stopped`
(the process check passed). The test 2 pane shows the first three.

### Report sections with one field

| Section | Field | Rule |
|---------|-------|------|
| `### Mod vs model` | Compare | not empty (FR-010) |
| `### Cloud limit` | Limit, Source | both not empty (FR-009) |
| `### Claude Code version` | Version | matches `^[0-9]+\.[0-9]+\.[0-9]+` (FR-015) |

### Verdict (FR-011, D12)

Section `### Verdict`.

| Field | Rule |
|-------|------|
| Starts | `yes` if Test 2 or Test 3 has Outcome `pass`, else `no` |
| Result back | `yes` if a test with Outcome `pass` has Result back `yes`, else `no` |
| Stops | `yes` if a test has Outcome `pass`, Result back `yes` and Stops `yes`, else `no` |
| Verdict | `yes` only if Stops is `yes` (the three parts hold for the same test, D12 "its result"), else `no` |
| Failed part | `none` when Verdict is `yes`. Otherwise the first part that is `no`: `starts`, `result back` or `stops` |
| Follow-up issue | the proposed issue title when Verdict is `yes` (not opened until the owner says so), else `none` |

A test 1 pass alone never makes a part `yes` (FR-011).

## check.sh rules

`check.sh [research.md path] [quickstart.md path]` reads the given files, defaults
`specs/003-session-mods/research.md` and `specs/003-session-mods/quickstart.md`. The second
argument exists for the R9 negative control. It prints `FAIL R<n>: <reason>` per broken rule and exits 1
if any rule fails, else prints `ok` and exits 0.

| Rule | Checks | FR |
|------|--------|----|
| R1 | Each test: Outcome in its label set, Approaches tried with 1 to 3 valid IDs, Evidence filled, Limit filled (`none` only on a pass). Tests 2 and 3: Result back and Stops are `yes` or `no`; Result back `yes` only when Evidence holds `spk003-t<n>[a-c]-ok` (`<n>` the test number) after check.sh removes the prompt text `exactly the text spk003-t<n>[a-c]-ok` from Evidence; Human step filled, and `pass` only with Human step `none` | FR-003, FR-005, FR-007, SC-001, D17 |
| R2 | Q1 to Q5: Answer and Evidence filled | FR-008, SC-002 |
| R3 | Verdict parts equal the values computed from the tests as above. Failed part and Follow-up issue match. Compare, Cloud limit, Source and Version filled | FR-009, FR-010, FR-011, FR-015, SC-004 |
| R4 | Started sessions table has at least 1 data row (the heading row and the separator row are skipped). Every data row: Name holds `spk003`; Argv holds `haiku`; Turn limit `--max-turns 3` with `--max-turns 3` in Argv, or `no tools` with `--tools ""` in Argv; Argv holds `timeout 300`, or Stopped minus Started is at most 300 seconds | FR-012 |
| R5 | No process matches `spk00[3]`. `claude agents --json --all` lists no name matching it, completed background sessions included. No worktree path or local branch matches it | FR-006, SC-003 |
| R6 | Every `git status --porcelain` path is under `specs/003-session-mods/` or is `.stratum/state.json`. Ignored by exact match: `.stratum/commit-mode`, `brag-output/`, `skills/st-ui-ux/scripts/__pycache__/` | FR-001, SC-005 |
| R7 | Test 3 has ListAgents, SendMessage and Over the Agent tool filled | FR-016 |
| R8 | No `TOKEN=`, `SECRET=` or `KEY=` followed by a value in the report or under `spikes/` (`check.sh` and the engine's `.claude-plugin/types/` folders excluded). Every report line holding `"sessionId"` or `"id":` (a session row copied from `claude agents --json` or ListAgents, one compact row per line; background rows carry `"id":`) also holds `spk003` or `spike-` | FR-013 |
| R9 | `quickstart.md` (second argument, or the default) has the headings `Open the second session`, `Load a mod`, `Hot reload answer` and `Process check` | FR-014 |
