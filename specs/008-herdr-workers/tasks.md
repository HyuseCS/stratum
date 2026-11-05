# Tasks: Orchestrator Starts Worker Sessions

**Input**: Design documents from `/specs/008-herdr-workers/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/script.md, contracts/skill.md, quickstart.md

**Tests**: Required. Each FR gets a test task that fails before its build task (user rule: test first).

**Rules for every task**: bash and jq only, no new dependency. Add NO explanatory comments to any
code or test file; the only allowed comment is a `ponytail:` marker. Match the style of
`scripts/st-herdr-workspace.sh` and `tests/test_herdr_workspace.sh` (`check`, `mktemp -d`, `trap`,
stub bin dir first on `PATH`, `nc()` with a green baseline). Keep every contract phrase whole on
one line. Never run bare `herdr`, `machine reconnect`, `server stop`, herdr `worktree remove`, a push,
or any `close` on a workspace the task did not make. Do not edit `spec.md`, `decisions.md`, the
checklists, `scripts/st-herdr-workspace.sh` or `skills/st-build/SKILL.md`. Print every line that
starts with `#` (brief headings, stub output) with `printf` or a quoted variable, never as a
heredoc line that starts with `#`, because `scripts/st-verify.sh` flags such an added line as a
comment (same rule as specs/007-herdr-workspace/tasks.md T005).

**Settled**: D24 (`start` writes `{"commit":"auto"}` to the worker worktree's
`.stratum/git-guard.json` only) and D25 (tasks that build on each other share a machine; no commit
crosses machines). Both are in contracts/script.md section 3.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 to US5 from spec.md

## Phase 1: Setup

None. `scripts/`, `skills/`, `tests/` exist. herdr 0.9.4, Claude Code 2.1.302, jq 1.8.2, bash
5.3.20, OpenSSH 10.6p1 and git 2.56.0 are installed (research header).

## Phase 2: Foundational

None. T001 builds the stubs that every later test task extends.

---

## Phase 3: User Story 1 - One worker in a herdr pane on this machine (Priority: P1) MVP

**Goal**: start, goal, wait, result, close and list for a worker on this machine, plus the skill.

**Independent Test**: `bash tests/test_st_worker.sh` and `bash tests/test_on_demand.sh` green;
quickstart section 2 run live.

### Tests for User Story 1

- [X] T001 [US1] Write `tests/test_st_worker.sh` and add the line `bash tests/test_st_worker.sh` to the Tests block of `README.md` (after `bash tests/test_shortcuts.sh`, keep the block sorted as it is). Stubs in `mktemp -d`, first on `PATH`, checked with `command -v` like `tests/test_herdr_workspace.sh`: `herdr` (logs each argv as one TAB-joined line; zero arguments logs `BARE` and exits 99; ids with a random part per run; `worktree create` makes the `--path` folder with a `.stratum/` inside and answers the JSON paths of research R1; `workspace list`, `worktree list --workspace`, `agent get`, `agent list`, `agent wait`, `agent read`, `agent prompt`, `agent start`, `workspace close` answer from files in the temp dir; `agent get` takes its state from a list the case sets, one per call; `agent read` prints `STUB PANE <random>` as plain text, not JSON, as the live CLI does (research R1); `STUB_FAIL="<group> <sub>"` fails that call with JSON on stderr, exit 1, and `STUB_FAIL_CODE` sets the error code such as `agent_not_ready`, `agent_blocked`, `agent_prompt_stalled`, `timeout`). The test makes a temp git repo with one commit and a tracked `.stratum/state.json`, and runs the script from it with `HERDR_ENV=1` and `HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID` set to `w1P` values that must never appear in a call. Cases from contracts/script.md section 6: S1 (with a two-line roster; asserts every item of S1: the Facts lines `- Model:`, `- Plugin root:` (the parent of the script's folder) and `- Your machine:` in that order, the four team rules whole (rule 4 names "the base branch" and allows merging a teammate's branch), and `{"commit":"auto"}` in `<WT>/.stratum/git-guard.json` and the repo's own `.stratum/git-guard.json` absent), S1b (repo guard file `{"force_push":"deny"}` gives `{"force_push":"deny","commit":"auto"}`), S2, S3, S4, S5, S6 (worker already exists, section 2 row 12; plan G10, lessons L11), S7 (`agent_blocked` on the prompt), S8 (`idle` after the prompt prints `working`), S9 (herdr made the worktree in another folder: stop line), S10 (`start` from a linked worktree: `--cwd` and `--path` from the main checkout, guard file from the calling folder), S11 and S11b (`agent_pane_busy` retried up to 10 tries), P1 to P7 (section 2 rows 1 to 7, each line asserted as built by the script, lessons L1), P2b (empty task file), P5b (no roster line for the worker), P5c (empty TAB field fails), P5d (trailing blank roster line passes), W1, W2, W3, W4, W5, G1, G2, C1, C2, C3, C4, C5, L1, and NC2, NC3, NC4, NC7 through an `nc()` that checks the `sed` copy differs and runs the real script green on the same input and state right before the copy (lessons L25). Every case also asserts the never-list and "no `--machine`" from contracts/script.md section 4, ids taken from the stub log (lessons L26), `-` ids on a stop (lessons L27), and that a result file holding `RESULT FILE <random>` is printed while `STUB PANE` is not. Run it before T003 and show it fails because `scripts/st-worker.sh` does not exist. Lessons L1, L7, L8, L25, L26, L27.

- [X] T002 [P] [US1] Add to `tests/test_on_demand.sh` a `phrases` block with every row of contracts/skill.md section 2 (target `skills/st-worker/SKILL.md`), the three `check` lines of that section (frontmatter and heading; order `/stratum:st-review` before `git merge --no-ff` before `st-worker.sh close`; `skills/st-build/SKILL.md` holds no `st-worker`, FR-014), and change the `#32 st-status tools` row to the phrase `` `herdr` and `jq` (optional, for `st-herdr-workspace` and `st-worker`) ``. Run it and show it fails because the skill file is missing and `skills/st-status/SKILL.md` has the old line. Only this file changes, so it runs beside T001 and T003. Lessons L1, L6.

### Implementation for User Story 1

- [X] T003 [US1] Write `scripts/st-worker.sh` (mode 755) per contracts/script.md: usage and exit codes (section 1), checks rows 1 to 7 and 12 (section 2), the brief text (section 3: the Facts lines include `- Model:` and `- Plugin root:`, team rule 4 forbids merging into the base branch and pushing, and allows merging a teammate's branch) and the `{"commit":"auto"}` write to `<WT>/.stratum/git-guard.json` (section 3, D24), and the subcommands `start`, `goal`, `wait`, `result`, `close`, `list` for this machine (section 4), with the output lines of section 5. Later review fixes in the same files: the `agent_pane_busy` retry (S11, S11b), the stop when herdr made the worktree elsewhere (S9), and `agent read` printed as plain text. In this task `--machine`, `answer` and `headless` print the usage line and exit 2. Ids only from the JSON of the call that made them (`jq -er`). Constants with `ponytail:` markers: `wait` bound 540 s, resume check 10 s. Each line that an NC breaks (the roster rows, team rule 1, the result file read, the `git-guard.json` write) must be one unique line. Done when `bash tests/test_st_worker.sh` is green. Lessons L5, L27, L28.

- [X] T004 [US1] After T002, write `skills/st-worker/SKILL.md` per contracts/skill.md section 1 (all steps, including the question handling (D26), team, merge, close, list and headless parts, so the skill is written once), and in the same task: add the `st-worker` row to the skill table in `README.md` and in `DESIGN.md`, change `DESIGN.md` "Twenty-three entry skills" to "Twenty-four entry skills", change the `README.md` tool row to `` | `herdr` 0.9.4, `jq` | optional, for `st-herdr-workspace` and `st-worker` | ``, and change the tool line in step 4 of `skills/st-status/SKILL.md` to name `st-herdr-workspace` and `st-worker`. Done when `bash tests/test_on_demand.sh` and `bash tests/test_inspect.sh` are green. Runs beside T003 (different files). Lessons L7, L12.

- [X] T005 [US1] Live local run: quickstart section 2 from a herdr pane, after T003 and T004. Record in `specs/008-herdr-workers/research.md` under each research item: `start` exit code and whether a trust dialog showed (R4), `◎ /goal active` seen (R5), the worker committed with no dialog (D24), every `state` line of `wait` and the longest `idle` between goal turns (R6), the `workspace close` answer and whether herdr asked for `--group` (R1), and the empty `agent list`, `workspace list` and `pgrep -af -- '-n worker-t90[0]'` after `close` (R11, SC-005; the bracket keeps pgrep from matching its own shell, lessons L21). A measured value that breaks a constant or a JSON path goes to the orchestrator as a finding before the story closes. Lessons L5.

**Checkpoint**: US1 works alone; the user can run "run T004 in a worker" on this machine.

---

## Phase 4: User Story 2 - The worker asks, the orchestrator answers or asks the user (Priority: P2)

**Goal**: `answer` sends an answer (the orchestrator's for a small question, the user's for a big one, D26) into a blocked worker, and sends nothing when the user already answered in the pane.

**Independent Test**: cases A1 to A3 and NC5 green; quickstart section 3 run live.

### Tests for User Story 2

- [X] T006 [US2] Add to `tests/test_st_worker.sh` the cases A1, A2, A3 and NC5 of contracts/script.md section 6, with the stub logging `agent send-keys` and `pane send-text` argv. A2 asserts `not blocked: working`, no `send-keys`, no `send-text`, exit 1 (US2 scenario 3). Run it and show A1 to A3 fail (`answer` exits 2 after T003). Lessons L1, L25.

### Implementation for User Story 2

- [X] T007 [US2] Add `answer` to `scripts/st-worker.sh` per contracts/script.md section 4 (`agent get` first; `--keys` through `agent send-keys`; `--text` through `pane send-text` then `agent send-keys <N> enter`; `agent get` after; exit 4 if still blocked). The `blocked` check is one unique line (NC5). Done when `bash tests/test_st_worker.sh` is green.

- [X] T008 [US2] Live question run: quickstart section 3, after T007. Record in `specs/008-herdr-workers/research.md` R7: whether herdr shows the AskUserQuestion dialog as `blocked`, which key picks an option, what reaches the free-text field, the `not blocked: working` line when the user answered in the pane first, which dialog kind showed for a permission prompt (Stratum's git guard or a Claude Code tool permission) and which key answered it, the push question answered `no` (nothing pushed), and which questions the orchestrator answered itself and which went to the user, as the end-of-run list shows them (D26, SC-003).

**Checkpoint**: US1 and US2 work on this machine.

---

## Phase 5: User Story 3 - A worker on the laptop (Priority: P3)

**Goal**: every subcommand except `headless` works with `--machine <m>`; brief, guard file and result cross by ssh; the branch is fetched here.

**Independent Test**: cases R1 to R8 and NC1 green; quickstart section 6 when the laptop answers.

### Tests for User Story 3

- [X] T009 [US3] Add to `tests/test_st_worker.sh` a stub `ssh` (logs argv as one TAB-joined line and its stdin to a file per call; answers `cat` of a result path with `RESULT FILE <random>`, `test -f` from a flag the case sets; `STUB_SSH_RC` fails it) and a `git` wrapper (logs `fetch` argv and the value of `GIT_SSH_COMMAND`, and exits 0, passes every other call to the real git found before `PATH` changes), the stub `machine list --json` entry `{"id":"stubid0001","label":"laptop","target":"u@stubhost",...}` as in `tests/test_herdr_workspace.sh`, and the cases R1 to R12 and NC1 of contracts/script.md section 6. R1 asserts every herdr call but `machine list --json` starts `--machine laptop`, `--path ~/proj-worker-t004` on `worktree create`, the one ssh call `-o BatchMode=yes -- u@stubhost` with `cat > ` and the `git-guard.json` write holding `~/proj-worker-t004/` unescaped (no `\~`), and the brief on its stdin with the roster and the four rules. R2 makes branch `worker-t004` in the temp repo first and asserts `GIT_SSH_COMMAND=ssh -o BatchMode=yes` on the fetch. R9 to R12 run `close`, `answer`, `goal` and `list` with `--machine laptop` under the same rule. R1b and R1c (a `~` path from herdr; ssh down on `start`), R2b (ssh down on `result`), R3b (no result file on the machine) and R8b (relative `--repo`) were added by review fixes. Run it and show R1 to R12 fail (`--machine` exits 2 after T003). Lessons L1, L25, L26.

### Implementation for User Story 3

- [X] T010 [US3] Add `--machine` to `scripts/st-worker.sh`: checks rows 8 to 11 of contracts/script.md section 2 (rows 9 to 11 copied with their words from `scripts/st-herdr-workspace.sh`), `H+=(--machine "<m>")` on one unique line (NC1), the target only from `machine list --json`, the ssh calls of sections 3 and 4 with `printf %q` paths and the leading `\~` turned back into `~` (as `scripts/st-herdr-workspace.sh` does), and `GIT_SSH_COMMAND='ssh -o BatchMode=yes' git fetch <target>:<WT> <N>:<N>` then `git rev-parse --verify <N>` in `result`. Done when `bash tests/test_st_worker.sh` is green.

- [X] T011 [US3] Run 2026-10-24: the live remote run of quickstart section 6 passed (laptop repo at 3275e07; results in quickstart section 6; plan B1 closed). Earlier, not run, `herdr --machine laptop workspace list` (2026-10-23, 11 s): `Error: Custom { kind: ConnectionAborted, error: "machine 'laptop' (session default): remote SSH connection failed: ssh: connect to host 100.73.64.64 port 22: Connection timed out" }`. Live remote run: quickstart section 6. Runnable only when `herdr --machine laptop workspace list` exits 0; the laptop times out on port 22 today (plan B1). If it still does not answer, tick it with `Not run, <first herdr error line>.` (lessons L24) and leave plan B1 as it is. If it runs, record the results and the laptop's herdr and Claude Code versions in `specs/008-herdr-workers/research.md` and close plan B1 in `specs/008-herdr-workers/plan.md`.

**Checkpoint**: US1 to US3 work; the remote live check waits on the laptop.

---

## Phase 6: User Story 4 - A team of workers on one project (Priority: P4)

**Goal**: two or more workers with one roster, the team rules, and merges in task order by the orchestrator only.

**Independent Test**: quickstart section 4. No new code: the roster and rules (FR-002, FR-008) are
built in T003 and tested by S1 with a two-line roster; the D25 machine rule and the review, merge
and conflict steps (FR-009) are built in T004 and tested by T002.

- [X] T012 [US4] Live team run: quickstart section 4, after T007. Two workers on this machine, the second builds on the first. Record in `specs/008-herdr-workers/research.md` (new item R15): both briefs hold both roster rows, worker-t903's transcript shows a SendMessage to `worker-t902` and a `git merge worker-t902`, both finish, the skill merges both in task order with `/stratum:st-review` run on each branch first, and both are closed (SC-004). Cross-machine messages are not run here (D25; laptop down).

**Checkpoint**: teams work on one machine.

---

## Phase 7: User Story 5 - A headless worker for a quick local task (Priority: P5)

**Goal**: `headless` runs `claude -p "/goal ..."` with the explicit allow list, reads the JSON, and refuses a run that committed.

**Independent Test**: cases H1 to H5 and NC6 green; quickstart section 5 run live.

### Tests for User Story 5

- [X] T013 [US5] Add to `tests/test_st_worker.sh` a stub `claude` (logs argv one per line; reads the brief path from the prompt and copies the brief to the temp dir; prints the JSON of spike test 3 with `subtype` `success`, `num_turns`, `total_cost_usd` and a `result` holding `HEADLESS <random>`; `STUB_CLAUDE=commit` makes a commit in the repo first, `=junk` prints junk, `=slow` exits 124), a stub `timeout` (logs its arguments, then execs the rest of the argv), and the cases H1 to H5, H3b, H6 to H10 and NC6 of contracts/script.md section 6. H1 asserts the exact flags of section 4 `headless` step 3, `-k 10 540` in the `timeout` log, the prompt `HP`, the brief outside the repo, and no herdr call. H2b asserts the commit check wins over junk output, H3b wins over a timeout, H3c a 137 exit reads as timed out; H10 asserts the `*` rule (section 2 row 3b). Run it and show H1 to H5 fail (`headless` exits 2 after T003). Lessons L1, L10, L25.

### Implementation for User Story 5

- [X] T014 [US5] Add `headless` to `scripts/st-worker.sh` per contracts/script.md section 4: `HEAD` before and after, the headless brief in a `mktemp` file removed by `trap`, `timeout -k 10 540 claude -p ...` with the exact flags, `--allowedTools ...` on one unique line (NC6), the `headless` and `result:` output lines, the exit rules in order (commit check first, then timeout 124 or 137, then no JSON, then `is_error` or `subtype`), the `*` check (section 2 row 3b), no `HERDR_ENV` check, and `--machine` as a usage error. `ponytail:` markers on 540 s and 30 turns. Done when `bash tests/test_st_worker.sh` is green. Lessons L10.

- [X] T015 [US5] Live headless run: quickstart section 5. Record in `specs/008-herdr-workers/research.md` R12: the `headless` line, `num_turns`, how `--max-turns` counted the goal turns, the same `HEAD` before and after, the untracked file, no process left by `pgrep -af -- '-n worker-t90[4]'` (SC-006; lessons L21), and whether `dontAsk` denied a Bash call that was not the test command. If `/goal` does not start under `-p`, the fallback is a plain prompt with no `/goal`; send that finding to the orchestrator before changing `scripts/st-worker.sh`.

**Checkpoint**: all five stories work on this machine.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T016 Final check from the project root, no file edits unless a check fails. If `main` moved, merge it first, then diff the README skill table, tool row and `## Tests` list and the DESIGN.md skill count line against `main` (other branches edit the same lines): keep main's lines plus ours (lessons L9). Run quickstart section 1 (`bash tests/test_st_worker.sh`, `bash tests/test_on_demand.sh`, `bash tests/test_inspect.sh`), then `bash scripts/st-verify.sh 'bash tests/test_st_worker.sh' scripts/st-worker.sh tests/test_st_worker.sh` and `bash scripts/st-verify.sh 'bash tests/test_on_demand.sh' skills/st-worker/SKILL.md tests/test_on_demand.sh README.md DESIGN.md skills/st-status/SKILL.md` (these re-run the tests; after the per-task commits their comment scan has no diff to read, so also run `git diff -U0 67a5113 -- scripts/st-worker.sh tests/test_st_worker.sh | grep -E '^\+[[:space:]]*#([[:space:]]|$)' | grep -v 'ponytail:'` and expect no output), `git diff --quiet 5d8a8e7 -- skills/st-build/SKILL.md agents/st-build.md` (FR-014), and `git status --porcelain` shows no file left by a test run (lessons L8).

---

---

## Phase 9: Addition, worker model (D27, D28)

**Goal**: an optional model per worker, from `--model` or the `st-worker` entry of `.stratum/models.json` (FR-017).

- [X] T017 [US1] Add the cases M1 to M7 and M4d of contracts/script.md section 6 to `tests/test_st_worker.sh` (models.json written in the temp repo for M2 and M6), the `#17 D27 model` row of contracts/skill.md section 2 to `tests/test_on_demand.sh`, a case in `tests/test_model_hook.py` where models.json holds `{"st-worker":{"model":"sonnet"}}` and an `st-git` start is not denied, and, in `tests/test_model_files.sh`, a check that `skills/st-model/SKILL.md` names `` `st-worker` ``. Run all four and show they fail before T018. Lessons L1, L25.

- [X] T018 [US1] Build FR-017: `scripts/st-worker.sh` (`--model` for `start` and `headless`, the models.json read, row 13, the `- Model:` brief line, `--model M` after `-n N`), `skills/st-worker/SKILL.md` (the `--model` line of contracts/skill.md step 1), `hooks/st-models.py` (accept `st-worker` beside the names from `agents/*.md`), `skills/st-model/SKILL.md` (list `st-worker` with the agents). Done when `bash tests/test_st_worker.sh`, `bash tests/test_on_demand.sh`, `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_model_hook.py` and `bash tests/test_model_files.sh` are green.

## FR to task map

| FR | Test | Build |
|----|------|-------|
| FR-001 | T001 S1, S6, T009 R1 | T003, T010 |
| FR-002 | T001 S1, S2, T009 R1 | T003, T010 |
| FR-003 | T001 S1, S3, S5, S7, P6 | T003 |
| FR-004 | T001 W1 to W5 | T003 |
| FR-005 | T001 G1, G2, NC4, T009 R2 | T003, T010 |
| FR-006 | T001 W5, T006 A1 to A3, NC5, T002 FR-006 rows | T003, T007, T004 |
| FR-007 | T009 R1 to R12, NC1 | T010 |
| FR-008 | T001 S1, NC3, T002 D25 row | T003, T004 |
| FR-009 | T002 review, merge, conflict rows and order check | T004 |
| FR-010 | T001 C1, C2, C4, C5, T002 close row | T003, T004 |
| FR-011 | T013 H1 to H5, NC6 | T014 |
| FR-012 | T001 C3; live T005 | T003 |
| FR-013 | T001 S1 (agent start argv), NC7 (D24 file) | T003 |
| FR-014 | T002 st-build check; T016 diff | T004 |
| FR-015 | the test file and NC1 to NC7 | T001, T006, T009, T013 |
| FR-016 | T001 L1 and every subcommand found by id | T003 |
| FR-017 | T017 M1 to M7 and M4d, hook case, phrase row, st-model check | T018 |

## Dependencies & Execution Order

### Phase Dependencies

- US1 (T001 to T005) first. T001 -> T003 -> T005. T002 -> T004 -> T005. T002 and T004 run beside T001 and T003.
- US2, US3 and US5 each need T003. They share `tests/test_st_worker.sh` and `scripts/st-worker.sh`, so their test and build tasks run one after another, never in parallel (lessons L6): T006 -> T007 -> T009 -> T010 -> T013 -> T014.
- Live tasks T008, T012, T015 run after their build task; T011 only when the laptop answers.
- T017 and T018 (Phase 9) run before T016. T016 last.

### User Story Dependencies

- US2, US3, US5: after US1 (they extend its script and test).
- US4: after US2 (a team member may ask a question).

### Within Each User Story

- The test task runs red before its build task. The build task is done when that test is green.

### Parallel Opportunities

- T002 and T004 (skill lane: `tests/test_on_demand.sh`, `skills/st-worker/SKILL.md`, `README.md` skill and tool rows, `DESIGN.md`, `skills/st-status/SKILL.md`) beside T003 (`scripts/st-worker.sh`). T001 writes the `README.md` test line, so it ends before T004 starts.
- No other pair: every other code task touches `tests/test_st_worker.sh` or `scripts/st-worker.sh`.

## Parallel Example: User Story 1

```text
Lane A: T001 (tests/test_st_worker.sh, README.md test line) -> T003 (scripts/st-worker.sh)
Lane B: T002 (tests/test_on_demand.sh) -> T004 after T001 (skills/st-worker/SKILL.md, README.md rows, DESIGN.md, skills/st-status/SKILL.md)
Then:   T005 (live run)
```

## Implementation Strategy

### MVP First (User Story 1 Only)

T001 to T005: one worker on this machine, start to close, with the skill. Stop and check
quickstart section 2 before going on.

### Incremental Delivery

US2 (questions), then US3 (laptop, stub-proven; live when it answers), then US4 (team, live only),
then US5 (headless). Each phase ends green on `bash tests/test_st_worker.sh`.

## Notes

- `docs/lessons.md` is written at Close by `st-close`, not by a Build task.
- 18 tasks: Setup 0, Foundational 0, US1 5, US2 3, US3 3, US4 1, US5 3, Polish 1, Addition 2 (T017, T018).

---

## Phase 10: #71 tests, a worker is one tab (US1, US3; D31 to D35)

**Goal**: the stub test and the skill-phrase test describe the #71 worker (contracts/script.md
sections 2 to 6, research R17) and go red on the current script and skill.

**Independent Test**: `bash tests/test_st_worker.sh` and `bash tests/test_worker_rules.sh` run and
fail only on the #71 cases.

The done tasks T001 to T018 stay as written; their workspace wording is history. Same rules as
above: no comments but `ponytail:`, print `#` lines with `printf`, every phrase whole on one line.

- [X] T019 [P] [US1] Change `tests/test_st_worker.sh` to the #71 contract (contracts/script.md sections 4 to 6). Stubs: (a) the `git` wrapper handles `-C <dir> worktree add -b <b> <p> <sha>` itself: logs the argv TAB-joined to `$STUB_T/gitlog`, appends `worktree add` to `$STUB_T/order`, fails with `fatal: stub git refused` on stderr and exit 128 when `STUB_GIT_FAIL=add`, else runs the `STUB_WT_LINK` case block moved here from the herdr stub (lines 37 to 45, the folder `<p>` with `.stratum/` inside) and appends `{path:<p>,branch:<b>}` to `$STUB_T/wt.json`; `-C <dir> worktree remove <p>`: logs, fails when `STUB_GIT_FAIL=remove`, else `rm -rf <p>`; `-C <dir> branch -D <b>`: logs, exit 0; every other call passes to the real git as now, so the temp repo gets no real branch or worktree and `fresh()` needs no branch cleanup. (b) The `ssh` stub, when not in `STUB_SSH_EXEC` mode, appends `{path,branch}` to `wt.json` for a command that holds `worktree add -b <b> <p>`. (c) The herdr stub: drop `worktree create`; `tab create` parses `--workspace`, `--cwd`, `--label`, makes ids `<ws>:t<random>` and `<ws>:p<random>`, writes its answer `{result:{type:"tab_created",tab:{tab_id,workspace_id,label},root_pane:{pane_id,cwd}}}` to `$T/tc.json` and stdout, appends to `tabs.json` and `panes.json` and to `made` as now; `tab list [--workspace W]` answers `{result:{tabs:...}}` from `tabs.json`; `pane list --workspace W` answers `{result:{panes:...}}` from `panes.json`; `worktree list --cwd C` answers `{result:{worktrees:<wt.json>}}`; `tab close <t>` touches `closed`, removes the tab, its panes and (unless `STUB_KEEP_AGENT`) the agents on those panes, and with `STUB_TABCLOSE_WS=1` also removes a workspace left with no tab; `workspace create --cwd C --label L --no-focus` makes `stubNewWS<random>` labelled `L` in `ws.json` with a root tab (label `1`, not `worker-*`) and pane, registers them, answers `.result.workspace.workspace_id`, `.result.tab.tab_id`, `.result.root_pane.pane_id`; `workspace close <w>` removes the workspace, its tabs, panes and agents; `agent start`, `agent get` and the `resume_result` write read `tc.json` (`.result.tab.workspace_id`, `.result.root_pane.pane_id`, `.result.root_pane.cwd`) in place of `wc.json`. `fresh()` seeds `tabs.json` with the orchestrator's tab `{tab_id:"w1P:t1",label:"orchestrator",workspace_id:"w1P"}`, a decoy tab labelled `notaworker` in `stubDecoyWS` and a tab labelled `main` in `stubMainWS`; `ws.json` with those three workspaces; `wt.json` with the decoy and a main entry `{path:"~/proj",branch:"main",is_linked_worktree:false,open_workspace_id:"stubMainWS"}` (`STUB_NO_MAIN_WS=1` drops its `open_workspace_id`); and empties `gitlog`, `tc.json`, `panes.json` and the `rrepo-worker-*` folders. Helpers: `wsid`, `tabid`, `pane`, `wt` read `tc.json` (`.result.tab.workspace_id`, `.result.tab.tab_id`, `.result.root_pane.pane_id`, `.result.root_pane.cwd`); drop `devroot` and `vmroot`. `never()` and `rnever()` take `<tab closes> <prompts> [<workspace closes, default 0>]`; `never()` replaces `! grep -q w1P` with: `w1P` appears only as the value after `--workspace` on a `tab<TAB>create` or `pane<TAB>list` line (find uses `pane list --workspace w1P` for every local worker), no line holds `w1P:`, and no `tab<TAB>close` or `workspace<TAB>close` line holds `w1P`; `rnever()` keeps `! grep -q w1P`. New case P7b: `HERDR_ENV=1` with an empty `HERDR_WORKSPACE_ID` (the `run` helper sets it to `w1P` today; let the case pass it empty) gives the row 7 line, no herdr call, exit 1. Cases, each as contracts/script.md section 6 words it: S1 (git log argv, one `tab create --workspace w1P`, split, lazygit, no `tab rename`, no `Dev Servers` or `VM`, field 4 the tab id), S4 (`STUB_GIT_FAIL=add`), S6 (a `worker-t004` tab in `stubDecoyWS`), delete S9, S10 (`-C <main checkout>` in the git log), S12 and S12b through the moved `STUB_WT_LINK`, new S13 and S13b (`STUB_FAIL="tab create"`; undo order in the git log; folder gone; second `start` exits 0; `STUB_GIT_FAIL=remove` gives `stopped: <stub message>; left <WT> and branch worker-t004`), W1 (`tab list`, `pane list --workspace w1P`, `worktree list --cwd <WT>`), C1 and C5 (`hascall "tab\tclose\t%s" "$(tabid)"`, zero `workspace close`), C3, C8 and C11 (now at lines 532, 560 and 579: each asserts `hascall "tab\tclose\t%s" "$(tabid)"` and zero `workspace close` in place of `hascall "workspace\tclose\t%s" "$(wsid)"`; C3 and C8 print `close left tab ...` in place of `close left workspace ...`), new C13 to C18 (C14, C15 and C17 start the worker with `--machine laptop` and `STUB_NO_MAIN_WS=1`, so it sits in the `st-workers` workspace `start` made; C17 first starts `worker-t005` the same way so both tabs share that workspace; C15 sets `STUB_TABCLOSE_WS=1`; C18 labels `w1P` `st-workers` in `ws.json` and closes a local worker), L1 and L2 (worker tabs in place of worker workspaces, field 4 the tab id), R1 (folds R1b: two ssh lines, the first the `git -C ~/proj worktree add -b worker-t004 ~/proj-worker-t004 <sha>` line, `tab create --workspace stubMainWS`, no `w1P`; the brief is now the stdin of the second ssh call, `ssh_in.2`), new R15 (`STUB_NO_MAIN_WS=1`: one `workspace create --cwd ~/proj --label st-workers --no-focus`), R15b (`STUB_NO_MAIN_WS=1` and a workspace labelled `st-workers` already in `ws.json`: no `workspace create`, `tab create --workspace` that workspace) and R16, R9 (one `tab close`, zero `workspace close`), R12 (field 4 the tab id), R14 (`--repo "$tmp/rrepo"`, no folder made here), LY1 and LY2 (order `tab create`, `pane split`, `pane run`, `agent start`; one `tab create`), WA1 (`hasline "tab\ttab worker-t004"`), `recok()` (third field `tab worker-t004`), SU1 (`worktree add` in `order` before `setup`), SU3 (two ssh calls: the `worktree add` one, then the brief one with the setup), AM1, AM4 to AM6 (`worktree add` in place of `worktree create`), and every `STUB_WT_PATH="$tmp/rwt"` case (axrun, AP1m, SU3, SU5, FU9) moved to the folder `$tmp/rrepo-worker-t004` that the exec'd ssh makes through the git wrapper (drop `STUB_WT_PATH`). New negative controls through `nc()`, defined by the behaviour they disable, not by a line of the script: NC8 is a copy whose `st-workers` guard before `workspace close` in `close` is disabled (the saved-machine, `st-workers` label and no-`worker-*`-tab-left checks), so `workspace close` runs after every `tab close`, run on R9 as a function `r9`, goes red because a `workspace close stubMainWS` shows (FR-018, D35); NC9 is a copy whose D33 undo in `start` (the removal of the worktree and the branch after a failed `tab create`) is disabled, run on S13 as a function `s13`, goes red. The mutation mechanics live only in this file: find that behaviour in the script in whatever form T021 builds it and disable it in the copy; keep the `nc()` checks (the copy differs, the copy parses, the real script is green on the same input right before). If T021's form needs a different mutation, change only this file. Run it and show the #71 cases fail on the current script (`worktree create`, `workspace list`). Owns: `tests/test_st_worker.sh`. Test: bash tests/test_st_worker.sh. Lessons L1, L25, L26, L27.

- [X] T020 [P] [US1] In `tests/test_worker_rules.sh` replace the W14 row (line 23) with this one line: ``W14|skills/st-worker/SKILL.md|Each worker is one tab labelled `worker-<id>` in this workspace (on a saved machine, in its workspace that has the main checkout open): the worker agent and lazygit side by side.`` Run it and show W14 fails on the current skill. Owns: `tests/test_worker_rules.sh`. Test: bash tests/test_worker_rules.sh.

**Checkpoint**: both tests are red only on the #71 rows.

## Phase 11: #71 build (US1, US3)

**Goal**: the script and the skill match contracts/script.md sections 2 to 5 and the W14 phrase.

**Independent Test**: `bash tests/test_st_worker.sh`, `bash tests/test_worker_rules.sh` and
`bash tests/test_on_demand.sh` green.

- [X] T021 [P] [US1] Change `scripts/st-worker.sh` to contracts/script.md sections 2 to 5 (#71). Security: plan S2, S3, S7 (herdr session control, ssh to the saved machine, the undo deletes a folder and a branch). (1) Row 7: a local `start` also needs a non-empty `HERDR_WORKSPACE_ID`, same line; that is the only `HERDR_*_ID` read, and only there. (2) `find_worker`: F1 `tab list` (one tab labelled `$N`: `TAB`, `WS`; none: `No worker $N on ${m:-local}.`; more: `More than one tab is labelled $N.`), F2 `pane list --workspace "$WS"` (`.cwd` of the first pane with `tab_id == TAB`; put a `# ponytail:` marker there as contracts/script.md section 4 words it: only the first pane's cwd is used, a `cd` in a stopped worker's pane breaks the find, upgrade by falling back to `<repo parent>/<repo name>-N`), F3 `worktree list --cwd <cwd>` (`.path` of the entry with `.branch == $N`), then `quote "$WT"` as now. (3) `start`: replace the `workspace list` check (lines 248 to 250) with the `tab list` label check, same line; `WS` is `$HERDR_WORKSPACE_ID` here, and on a saved machine `.open_workspace_id` of the entry with `.is_linked_worktree == false` in `worktree list --cwd "$repo"`, else the `.workspace_id` of the first workspace labelled `st-workers` in `workspace list`, else `.result.workspace.workspace_id` of `workspace create --cwd "$repo" --label st-workers --no-focus` (D35); move the `rx` helper of `followup` (line 336) up beside `rsh` and run `git -C <repo> worktree add -b $N <path> $sha` through it with `printf %q` values (one line for both machines; the stop line is git's first stderr line); set `BR=$N`, `WT=$path`; then `tab create --workspace "$WS" --cwd "$path" --label "$N" --no-focus` (`TAB` from `.result.tab.tab_id`, `PANE` from `.result.root_pane.pane_id`), called as `"${H[@]}" tab create ... 2>"$e"` and not through `h`, because `h` stops before the undo can run; the local branch of `rx` gets `2>"$e"` so a git stop line is git's first stderr line; on its failure run `git -C <repo> worktree remove <path> && git -C <repo> branch -D $N` through `rx`, then stop with the herdr line, or with `<herdr line>; left <path> and branch $N` when the undo failed; after a good undo clear `BR` and `WT` so the `worker` line has `-` in fields 4 to 7. Keep the brief, guard, autonomous and `worker-setup.sh` code as is, after `tab create`. Then `pane split "$PANE" --direction right --cwd "$WT" --no-focus` and `pane run <new pane> lazygit`. Delete `worktree create`, the `herdr made the worktree in` stop, `tab rename ... Main` and the `Dev Servers`/`VM` loop. `worker()` prints `TAB` in field 4. (4) `close`: after the refusals and the guard-file removal, `h tab close "$TAB"`, then, on a saved machine only, `workspace close "$WS"` only when WS is still in `h workspace list` with the label `st-workers` and `h tab list --workspace "$WS"` holds no tab labelled `worker-*`, never `--group` (D35; a local `close` never closes a workspace); the leftover loop checks `agent:name tab:label`. (5) `list`: `tab list` labels starting `worker-`, F2 and F3 per worker (`-` when not found), `found` field 4 the tab id. (6) Line 200: `tab\ttab %s` with `$N`; line 612: the third field `tab $N`. Ids only from JSON (`jq -er`). No new comments. Done when the test is green, NC8 and NC9 included. Owns: `scripts/st-worker.sh`. Test: bash tests/test_st_worker.sh. Lessons L5, L25, L27.

- [X] T022 [P] [US1] In `skills/st-worker/SKILL.md` replace line 18 with this text, as one line with the same three-space indent: ``Each worker is one tab labelled `worker-<id>` in this workspace (on a saved machine, in its workspace that has the main checkout open): the worker agent and lazygit side by side.`` Change nothing else. Owns: `skills/st-worker/SKILL.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_on_demand.sh.

**Checkpoint**: the #71 worker passes every stub case.

## Phase 12: #71 live on this PC (US1, SC-001, SC-005)

- [ ] T023 [US1] Live run of quickstart section 2b on this PC from the orchestrator's own herdr pane, after T021 and T022: start a worker (fresh id, T920 if free), see its tab labelled `worker-t920` in this workspace with two panes and lazygit, wait, read the result, close it, and do not merge. Record in `specs/008-herdr-workers/research.md` R17 under `Live (T023)`: the `worker` line, the tab list before, after `start` and after `close`, the `pane list` of the tab, the `tab close` answer, whether this workspace is still listed, and the agent and pgrep checks. A value that differs from quickstart section 2b goes to the orchestrator as a finding before the phase closes. Close only the worker tab `start` made. Test: after `close`, `herdr tab list | jq -r '.result.tabs[].label' | grep -x worker-t920` exits 1 and `herdr tab list --workspace "$HERDR_WORKSPACE_ID" | jq -r '.result.tabs[].tab_id' | grep -x "$HERDR_TAB_ID"` exits 0.

## Phase 13: #71 live on the laptop (US3, SC-002, SC-005; D37)

- [ ] T024 [US3] Live run of quickstart section 6b on the saved machine `laptop`, from a herdr pane here, after T021, T022 and T023, with no laptop workspace holding the main checkout open and no `st-workers` workspace there: start one worker (fresh id, T921 if free), see its tab labelled `worker-t921` open in a new `st-workers` workspace with two panes and lazygit, wait, read the result, close it, and do not merge. Record in `specs/008-herdr-workers/research.md` R17 under `Live (T024)`: `herdr --machine laptop workspace list` and `tab list` before, after `start` and after `close`; the `pane list` cwd values of the worker tab, and so whether `~` is expanded in `tab create --cwd` and `pane split --cwd`; what herdr does when the worker tab closes (herdr #4379; the worker tab is not that workspace's last tab, so say whether the last-tab case was reached); the `worker` and `closed` lines. A value that differs from quickstart section 6b goes to the orchestrator as a finding before the phase closes. Close only what `start` made (the worker tab and the `st-workers` workspace, through `close`). Test: after `close`, `herdr --machine laptop tab list | jq -r '.result.tabs[].label' | grep -x worker-t921` exits 1 and `herdr --machine laptop workspace list | jq -r '.result.workspaces[].label' | grep -x st-workers` exits 1.

## #71 FR to task map

| FR | Test | Build |
|----|------|-------|
| FR-001 | T019 S1, S4, S6, S10, S13, S13b, R1, R14, R15, R15b, R16, LY1, LY2, NC9; live T023, T024 | T021 |
| FR-010 | T019 C1, C5, C13, C14, C15, C17, R9; live T023, T024 | T021 |
| FR-015 | T019 (the test file, NC8, NC9) | T019 |
| FR-016 | T019 W1, L1, L2, R12 | T021 |
| FR-018 | T019 `never()`, P7b, C1, C13 to C18, R9, NC8; live T023, T024 | T021 |
| SC-005 | T023, T024 | T021 |
| US3 (remote tab, `st-workers`) | T019 R1, R15, R15b, R16, C14, C15, C17; live T024 | T021 |
| skill line 18 | T020 W14 | T022 |

## #71 dependencies

- Phase 10 (T019, T020) before Phase 11 (T021, T022) before Phase 12 (T023) before Phase 13
  (T024). T024 needs T021, T022 and T023, and runs only when `herdr --machine laptop workspace list`
  exits 0; if it does not, tick it with `Not run, <first herdr error line>.` (lessons L24).
- T019 and T020 run at the same time; T021 and T022 run at the same time: no shared file.
- US1 and US3 share `scripts/st-worker.sh` and `tests/test_st_worker.sh`, so no #71 story runs on
  its own. No test here needs `[lock]`: each uses its own `mktemp -d`.
- 6 #71 tasks (T019 to T024): T019 to T023 US1-labelled, T024 US3; the US3 stub cases sit in T019
  and T021.
