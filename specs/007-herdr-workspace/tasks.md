---

description: "Task list for Open a herdr Workspace From a Layout Template"
---

# Tasks: Open a herdr Workspace From a Layout Template

**Input**: Design documents from `/specs/007-herdr-workspace/`

**Prerequisites**: plan.md, spec.md, decisions.md, research.md, data-model.md, contracts/script.md, contracts/skill.md, quickstart.md

**Tests**: Required (FR-014, SC-005). Every FR has a check that fails before its build task.
Expected red states between tasks are in quickstart.md section 1. Do not edit a test to make it green.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum-003` (branch `003-session-mods`).

**Rules for every task**: add NO explanatory comments to code; only `ponytail:` markers (plan.md
"ponytail notes"). Minimal diff, no abstraction, bash and jq only, no new dependency. Match the
style of `scripts/st-worktree.sh` and `tests/test_verify.sh` (`check`, `mktemp -d`, `trap`).
Keep every contract phrase whole on one line. Never run bare `herdr`, `machine reconnect`, any
`close`, or `server stop`. Do not edit `spec.md`, `decisions.md`, the checklists, or
`~/.config/herdr/templates.sh`.

**Running check**: D20 (decisions.md, research R5): poll `pane process-info`, up to 10 s.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1, US2 or US3 from spec.md

## Phase 1: Setup

None. `scripts/`, `skills/`, `tests/` exist. herdr 0.9.4, jq 1.8.2, bash 5.3.20 are installed (research header).

## Phase 2: Foundational

None. T001 builds the stubs every later test task extends.

---

## Phase 3: User Story 1 - Open a full workspace on this machine (Priority: P1) MVP

**Goal**: one script call inside herdr makes the six-pane `full` workspace in the folder, starts
the agent and `lazygit`, focuses it and prints the report. The skill runs it.

**Independent Test**: `bash tests/test_herdr_workspace.sh` local cases `ok`; quickstart section 2.

### Tests for User Story 1

- [X] T001 [US1] Create `tests/test_herdr_workspace.sh` with the stubs and the local `full` cases, and add `bash tests/test_herdr_workspace.sh` to the README test list before `bash tests/test_inspect.sh` in `README.md` (FR-001, FR-002 full, FR-003, FR-005, FR-006 local, FR-007, FR-008, FR-009, FR-010, FR-011, FR-012, FR-014; lessons L1, L2, L8).
  - Harness: `set -u`, `root` from `$(dirname "$0")/..`, `tmp=$(mktemp -d)`, `trap 'rm -rf "$tmp"' EXIT`, `check` as in `tests/test_verify.sh`. One function `run <script> <args...>` runs a script with `PATH="$tmp/bin:$PATH"`, `HERDR_PANE_ID=w1P:p1 HERDR_TAB_ID=w1P:t1 HERDR_WORKSPACE_ID=w1P`, a fresh call log, and captures stdout+stderr and exit code. The stub files are made executable with `chmod +x`. First check of the test, before any case: under that `PATH`, `command -v herdr` must print `$tmp/bin/herdr` (and, once T005 adds the ssh stub, `command -v ssh` must print `$tmp/bin/ssh`); if not, print which binary was found and exit 1, since the test runs inside a live herdr session with the real `herdr` later on `PATH`.
  - Stub `herdr` in `$tmp/bin/herdr`: with zero arguments log `BARE` and exit 99. Else append the argv as one TAB-joined line to `$tmp/calls`, drop a leading `--machine X`, then answer by subcommand, each answer also appended to `$tmp/resp`: `workspace create` -> `{"result":{"workspace":{"workspace_id":"stubW"},"tab":{"tab_id":"stubW:t1"},"root_pane":{"pane_id":"stubW:p1"}}}`; `tab create` -> next `stubW:tN` and `stubW:pN`; `pane split` -> next `stubW:pN` in `.result.pane.pane_id`; `pane list` -> `{"result":{"panes":[{"pane_id":...,"tab_id":...,"cwd":"$STUB_CWD"}, ...]}}`, one entry per pane made so far; `tab rename`, `pane run`, `workspace focus`, `workspace list` -> `{"result":{}}`. Counters live in files under `$tmp`. `STUB_FAIL="<group> <sub>"` makes that call print `{"error":{"code":"stub","message":"stub refused"}}` on stderr and exit 1. `pane process-info --pane <id>` -> `{"result":{"process_info":{"pane_id":"<id>","foreground_processes":[{"name":"<n>"}]}}}` where `<n>` is `claude` if a logged `pane run <id>` started `claude` or `claude2`, `lazygit` if it started `lazygit`, else `zsh`; with `STUB_NOTSEEN=1` always `zsh`.
  - Stub `sleep` in `$tmp/bin/sleep`: exit 0 at once.
  - One function `calls_ok <log> <folder> <machine-or-empty>` asserts, each as its own `check`: exactly one `workspace create` line and it has `--cwd<TAB><folder>`; every `tab create` and every `pane split` line has `--cwd<TAB><folder>`; no line has `--machine` (empty machine) or every line except `machine<TAB>list<TAB>--json` starts `--machine<TAB><machine>` (machine given); every id after `rename`, `split`, `run`, `focus`, `--workspace`, `--pane` starts `stub` and is in `$tmp/resp`; no line has `w1P`, `--current`, `--session` or `--remote`; no call's subcommand (fields 1 and 2, or 3 and 4 after a `--machine X` prefix; never the whole line, which holds the folder and label) is `* close`, `machine reconnect`, `machine add`, `machine remove`, `machine enable`, `machine disable` or `server *`; no `BARE`; `workspace focus` comes once and no `create`, `split`, `rename` or `pane run` line follows it.
  - Case L1 full, dirty repo: `git init` a repo in `$tmp/proj dir` (space in the name), one commit, one untracked file; `STUB_CWD` = that path; `HERDR_ENV=1`; run with `--label 32-herdr-workspace`. Expect exit 0, `calls_ok`, two `tab create` lines labelled `Dev Servers` and `VM`, three `pane split` lines, exactly two `pane run` lines: the `root_pane` of `workspace create` with `claude`, the first split's pane with `lazygit`. Report lines exactly as contracts/script.md section 5, TAB-separated: `workspace<TAB>stubW<TAB>32-herdr-workspace<TAB>local`, a `folder` line with the path and `1 changed` and `no upstream`, 3 `tab` lines, 6 `pane` lines with the folder as cwd, `claude<TAB>running` and `lazygit<TAB>running`, four `shell<TAB>-`.
  - Case L2 `--agent claude2`: the agent `pane run` line ends `claude2` and the report says `claude2`.
  - Case L3 not seen (`STUB_NOTSEEN=1`): exit 0, both programs `not seen`, no `close` line, `pane process-info` lines only for the two `Main` panes, at most 10 each, all after `workspace focus`.
  - Case L4 behind: make a second commit, `git branch up`, `git reset -q --hard HEAD~1`, `git branch --set-upstream-to=up`; expect `behind 1` and `(as of last fetch)` in the `folder` line and exit 0.
  - Case L5 not a git repo: a plain `mktemp -d` folder; expect `not a git repo` and exit 0.
  - Cases L6 to L11, each: exit 1, exactly one output line holding the contract phrase, zero `$tmp/calls` lines: folder `/no/such/dir` (`Folder not found on local:`); `--agent codex` (`Agent must be claude or claude2.`); `--template big` (`Template must be full or basic.`); no `--label` (`Label is required: --label <issue-or-name>.`); `--label -x` (`Label must be letters, digits, dot, dash or underscore`); `HERDR_ENV` unset (`Not inside a herdr pane.`).
  - Case L12 stop: `STUB_FAIL="tab create"`. Expect exit 1, first line `stopped: ` then the stub's message, then `workspace`, `tab<TAB>stubW:t1<TAB>Main` and two `pane` lines with the folder as cwd (step 12 read back still runs); exactly one `tab create` line; no `workspace focus`; no `close`.
  - Case L13: `--bogus` exits 2.
  - Case L14 cwd read back: as L1 but `STUB_CWD=/stub/elsewhere`; expect `/stub/elsewhere` as the cwd in all six `pane` lines (proves the cwd column comes from step 12, not from the folder the script holds).
  - Case L15 read back fails: as L1 but `STUB_FAIL="pane list"`; expect exit 0 and `?` in the cwd column of every `pane` line.
  - Case L16 running check fails: as L1 but `STUB_FAIL="pane process-info"`; expect exit 0, `not seen` for P1 and P2, and the `workspace focus` line present (step 11 is the stop-rule exception, contracts/script.md section 4).
  - Negative controls, run through the same checks and expected to make at least one fail (`check "NC1 ... goes red"`): NC1 a copy of the script in `$tmp` with `--cwd` removed from the first `pane split` (`sed` on that line only); NC3 a copy whose first split target is `"$HERDR_PANE_ID"`. Each control first checks `! cmp -s` against the script, so a `sed` that matched nothing fails the test.
  - Run it now: every case red (no script). That red is the L2 proof for this file.

### Implementation for User Story 1

- [X] T002 [US1] Create `scripts/st-herdr-workspace.sh` for the local `full` path per contracts/script.md sections 1 to 5: argument parsing (exit 2 on unknown option), pre-checks 1, 2, 3, 4a and 5 in that order with their exact lines, the probe run with `bash -c`, one call wrapper that runs in the main shell, prepends the (here empty) `--machine` prefix, keeps stdout in a variable and on failure prints `stopped: <first stderr line>` and the report so far and exits 1, the `full` steps 1 to 10 and 12, the read back with `jq -r '.result.panes[]'` (`pane_id`, `tab_id`, `cwd`), the running check per contracts/script.md section 4 step 11 (D20: `pane process-info` on P1 and P2, `sleep 1` between rounds, up to 10 rounds, `running` when a foreground `name` is `claude` or `lazygit`), and the report. `--template basic` is accepted by the check but builds nothing yet (T009 adds it). Ids via `jq -er`; label rule `^[A-Za-z0-9][A-Za-z0-9._-]*$`; wait bound 10 s with a `# ponytail:` marker. Security: plan S1, S3, S4. Done when `bash tests/test_herdr_workspace.sh` passes every T001 case and control.

- [X] T003 [P] [US1] Add one `phrases <<'EOF'` heredoc before `exit $fail` in `tests/test_on_demand.sh` with the nine rows of `specs/007-herdr-workspace/contracts/skill.md` section 2, in table order, each `name<TAB>skills/st-herdr-workspace/SKILL.md<TAB>phrase`, one more row `#32 st-status tools<TAB>skills/st-status/SKILL.md<TAB>` followed by the phrase ``` `herdr` and `jq` (optional, for `st-herdr-workspace`) ```, and one `check "#32 skill"` that the file has the line `name: st-herdr-workspace` and a line starting `# /stratum:st-herdr-workspace` (FR-009, FR-011, FR-013; lessons L1, L6). Run it: red on the `#32` rows only.

- [X] T004 [US1] Create `skills/st-herdr-workspace/SKILL.md` per contracts/skill.md section 1, with every section 2 phrase whole on one line; add the row ``| `st-herdr-workspace <folder>` | Open a project folder as a new herdr workspace with the full or basic layout, here or on a saved machine. |`` after the `st-triage` row in `README.md`'s skill table and the tool row ``| `herdr` 0.9.4, `jq` | optional, for `st-herdr-workspace` |`` after the `gh` row; add the same skill row after the `st-triage` row in `DESIGN.md` section 3 and change `Twenty-two entry skills` to `Twenty-three entry skills`; in `skills/st-status/SKILL.md` step 4 (**Tools:**, which st-init's step 10 Tool check reuses) insert `` `herdr` and `jq` (optional, for `st-herdr-workspace`), `` right after `(statusline), ` (the end of the `bunx` entry, start of line 22) and before `` `graphify --version` ``, keep that phrase whole on one line and keep the line `4. **Tools:**` start that `tests/test_model_files.sh:50` checks (FR-001, FR-009, FR-013; lessons L7). Depends on T001 (both edit `README.md`) and T003. Done when `bash tests/test_on_demand.sh`, `bash tests/test_inspect.sh` and `bash tests/test_model_files.sh` are green.

**Checkpoint**: US1 works on this machine and is fully tested with stubs.

---

## Phase 4: User Story 2 - Open the same workspace on a saved remote machine (Priority: P2)

**Goal**: `--machine <m>` makes the same workspace on the saved machine, with the folder and git
checks over ssh and `--machine` on every herdr call.

**Independent Test**: `bash tests/test_herdr_workspace.sh` remote cases `ok`; quickstart section 3 when the laptop answers.

### Tests for User Story 2

- [X] T005 [US2] Add the remote cases to `tests/test_herdr_workspace.sh` (FR-004, FR-005, FR-006 remote, FR-007 remote, FR-011; lessons L2). Depends on T002.
  - Stub `herdr`: `machine list --json` -> `[{"id":"stubid0001","label":"laptop","target":"u@stubhost","session":"default","enabled":true,"selected":false}]`; `STUB_DOWN=1` makes `workspace list` print `Error: stub machine down` on stderr and exit 1.
  - Stub `ssh` in `$tmp/bin/ssh`: append argv TAB-joined to `$tmp/ssh`; exit `$STUB_SSH_RC` with `ssh: stub failure` on stderr when it is set; else print `/home/u/proj x`, then `# branch.oid 0123`, `# branch.head main`, `# branch.upstream origin/main`, `# branch.ab +3 -2`. Print these lines with `printf '%s\n' '# branch.oid 0123' '# branch.head main' ...`, never as heredoc lines, so no line of the test file starts with `#`: `scripts/st-verify.sh` flags an added line that starts with `#` and a space as a comment.
  - Case R1: `HERDR_ENV` unset, `STUB_CWD='/home/u/proj x'`, folder `~/proj x`, `--machine laptop`. Expect exit 0; `calls_ok` with machine `laptop` and folder `/home/u/proj x` (the ssh output, never `~`); exactly one ssh line, which starts `-o<TAB>BatchMode=yes<TAB>--<TAB>u@stubhost` and whose last field holds `cd -- ~/proj\ x` (the `~` not escaped); report `workspace` line ends `laptop`, `folder` line has `ahead 3, behind 2`.
  - Case R2: `--machine stubid0001` works the same way.
  - Cases R3 to R7, each exit 1, one line, no mutating call: `--machine nosuch` (`Unknown machine: nosuch. Saved: laptop.`, no ssh line); `STUB_DOWN=1` (`Machine laptop does not answer: Error: stub machine down`, no ssh line); `STUB_SSH_RC=1` (`Folder not found on laptop: ~/proj x`); `STUB_SSH_RC=255` (`ssh to u@stubhost failed: ssh: stub failure`); folder `proj` (`A remote folder must start with / or ~.`, no ssh line).
  - Negative controls: NC2 a copy with the `--machine` prefix removed from the call wrapper; NC4 a copy without the `\~` to `~` fix. Each first passes `! cmp -s`, then must make R1 fail.
  - Run it: R1 to R7 and NC2, NC4 red; every T001 case still green.

### Implementation for User Story 2

- [X] T006 [US2] Add the remote path to `scripts/st-herdr-workspace.sh`: pre-checks 4b, 4c, 4d, the probe over `ssh -o BatchMode=yes -- "$target"` with the target only from `machine list --json`, the `printf %q` quote with the leading `\~` turned back into `~`, and the `--machine <m>` prefix in the call wrapper (contracts/script.md sections 2 to 4). `HERDR_ENV` is not checked when `--machine` is given (D8). Security: plan S2, S4, S5. Done when every T001 and T005 case and control is green.

- [ ] T007 [US2] Live remote run per quickstart section 3 (SC-002), only when `herdr --machine laptop workspace list` exits 0. Also run the remote command once from a terminal with `HERDR_ENV` unset (`env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_TAB_ID -u HERDR_WORKSPACE_ID bash scripts/st-herdr-workspace.sh ...`); it must work the same, as the live proof of D8. Record the report and the read back in `specs/007-herdr-workspace/research.md` under a new `R9. Live remote run`. If the laptop still does not answer, tick it with `Not run, <herdr's error line>.` in this task text (lessons L17) and leave plan B1 open.

**Checkpoint**: US1 and US2 pass the stub test; US2 live waits on B1.

---

## Phase 5: User Story 3 - Open a basic workspace (Priority: P3)

**Goal**: `--template basic` makes one tab `Main` with two shells in the folder and starts nothing.

**Independent Test**: `bash tests/test_herdr_workspace.sh` basic cases `ok`; quickstart section 4.

### Tests for User Story 3

- [X] T008 [US3] Add the basic cases to `tests/test_herdr_workspace.sh` (FR-002 basic, FR-003). Depends on T006. Case B1 local and B2 remote (`--machine laptop`), each `--template basic`: exit 0, `calls_ok`, exactly one `workspace create`, one `tab rename` to `Main`, one `pane split`, zero `tab create`, zero `pane run`, zero `pane process-info`; report has one `tab` line and two `shell<TAB>-` pane lines. Run it: B1 and B2 red, every earlier case green.

### Implementation for User Story 3

- [X] T009 [US3] Wrap steps 4 to 9 and the running check of `scripts/st-herdr-workspace.sh` in the `full` branch, as `templates.sh` does with `if [ "$1" = full ]` (contracts/script.md section 4, `basic`). Done when every case and control in `tests/test_herdr_workspace.sh` is green.

**Checkpoint**: all three stories pass the stub test.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T010 If `main` moved, merge it first. Then diff the README `## Tests` list and the DESIGN.md skill count line against `main` (another plan, branch `22-workflow-scripts`, `specs/006-pr-workflow-script`, edits the same lines): keep main's lines plus ours. Run `bash tests/test_herdr_workspace.sh`, `bash tests/test_on_demand.sh`, `bash tests/test_inspect.sh`, `bash tests/test_verify.sh`, then `bash scripts/st-verify.sh 'bash tests/test_herdr_workspace.sh' scripts/st-herdr-workspace.sh tests/test_herdr_workspace.sh tests/test_on_demand.sh`. After the per-task commits this call only re-runs the tests; its comment scan has no diff to read, so the comment check is the per-task st-verify step during the build. Then `git status --porcelain --untracked-files=all`: only the feature's files may show (lessons L8).

- [ ] T011 Live local run per quickstart sections 2 and 4 from a herdr pane (SC-001, SC-003, SC-004 local). Record the `time` of the `full` run in `specs/007-herdr-workspace/research.md` R5, and raise the 10 s bound in `scripts/st-herdr-workspace.sh` only if `claude` was not seen within it. Tell the user which test workspaces to close; the script and the agent close nothing.

---

## Dependencies & Execution Order

- T001 -> T002 -> T005 -> T006 -> T008 -> T009 (one test file, one script: lessons L6).
- T003 [P] can run any time; T004 after T001 (shared `README.md`) and T003.
- T007 after T006 and only when the laptop answers. T010 after T009 and T004. T011 after T010.
- US2 and US3 use the US1 script and harness, so stories run in priority order.

## Parallel Example

```bash
Task: "T001 tests/test_herdr_workspace.sh local cases"   # sequential chain owner
Task: "T003 #32 phrase rows in tests/test_on_demand.sh"   # [P], touches only that file
```

## Implementation Strategy

1. MVP: T001 to T004 gives US1 on this machine with the skill.
2. Add US2 (T005, T006), then US3 (T008, T009).
3. T010 and T011 close the build. T007 runs when B1 clears.
