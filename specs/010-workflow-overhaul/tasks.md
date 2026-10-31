---

description: "Task list for 010-workflow-overhaul"
---

# Tasks: Workflow Overhaul

**Input**: `specs/010-workflow-overhaul/` (plan.md, research.md, data-model.md,
contracts/scripts.md, contracts/phrases.md, quickstart.md)

**Tests**: required. FR-031: every FR has a test that fails before its build task and passes
after. Test tasks go to `st-test`, build tasks to `st-build`.

## Format

`- [ ] T### [P] [USn] What to do. Owns: <files>. Test: <exact command>. (FRs, lessons)`

- **[P]**: shares no file with another task in its phase and needs no other task's result.
- **Order**: tasks run in the waves of "Execution waves" below, not phase by phase. All tasks of
  a wave run at the same time, and no two tasks in one wave own the same file. Phases only group
  tasks by story.
- **Owns**: the only files the task may write.
- **Inspect check**: `! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'` passes when every `tests/test_inspect.sh`
  row is green except `README tests`, which stays red until T008 and again until T046 (README
  lists the new test files only then). Each task that changes a file `tests/test_inspect.sh`
  reads (README, DESIGN, `skills/st/SKILL.md`, `skills/st-inspect/SKILL.md`,
  `skills/st-plan/SKILL.md`, `skills/st-full/SKILL.md`, `agents/st-plan.md`, the status line) runs
  it.
- **Test**: the exact command. No task runs every test in `tests/`.
- **[lock]**: none in this plan. Every test file uses its own temp folder and can run beside the
  others.
- Phrases (A1, S1, ...) are in `contracts/phrases.md`, word for word. Script behavior is in
  `contracts/scripts.md`.
- Built code adds no explanatory comments, only `ponytail:` lines for deliberate shortcuts.
- Python tests run as `PYTHONDONTWRITEBYTECODE=1 python3 tests/<file>.py` (lessons L8).
- Each test file starts with the `check()` style of `tests/test_advisor.sh:1-7` (shell) or
  `unittest` as in `tests/test_git_guard.py` (Python).

## Phase 1: Setup

- [X] T001 [P] Write `tests/test_lane_steps.sh`: one check per row of the plan.md "FR-027"
  table, named by its row number. A row with old text asserts that text is gone (the "Gone"
  lines of `contracts/phrases.md`, US1 to US6, in their files). A row that adds a missing step
  asserts the first phrase in its Fix column is present. Run it: it must be red now, one FAIL
  per row. Owns:
  `tests/test_lane_steps.sh`. Test: `bash tests/test_lane_steps.sh`. (FR-027, lessons L1)

## Phase 2: Foundational

None. No user story needs another story's code to start. The order is by wave (see Execution
waves).

## Phase 3: User Story 1 - Fewer advisor runs and no surprise full suite (P1) MVP

**Goal**: one Codex plan run when findings are MEDIUM and LOW, a waive line for fix-only Inspect
changes, no end-of-Build pass when nothing changed after the last review, a call count, and
scoped tests.

**Independent Test**: quickstart section 1.

### Tests (write first, must fail)

- [X] T002 [P] [US1] Write `tests/test_advisor_waive.sh` for `scripts/st-advisor.sh`. Copy the
  setup of `tests/test_advisor.sh:1-56` (stub `codex` and `timeout`, temp project) and add
  `unset HERDR_ENV HERDR_WORKSPACE_ID`. In `tests/test_advisor.sh`, move `"diff specs/001-demo $first"` and
  `"continued diff specs/001-demo"` out of `badargs` (line 198; `check diff` stays), because
  contract 1.1 makes both valid. Cases from contracts/scripts.md sections 1.1 and 1.2:
  (a) after an APPROVED `plan` run, `waive plan <f> "fix-only"` prints `WAIVED sha256 <h>` with `<h>` from the plan hash
  pipeline, then `reason: fix-only`, exit 0, and the stub `codex` wrote no argv file;
  (b) the record header matches `^## plan \| <ts> \| sha256 <h> \| WAIVED$` and the next line is
  `reason: fix-only`; (c) `check plan` after it prints `WAIVED sha256 <h>`, exit 0;
  (d) after a change to `tasks.md`, `check plan` prints `advisor approval is stale`, exit 1;
  (e) a reason that is empty, or only CR and LF, gives `usage:` and exit 2 with no record; a
  reason with an LF is recorded on one line; (f) after an APPROVED run, `waive` works with `{"mode": "off"}` and with
  no `advisor.json`; (f2) `waive` is refused with `nothing to waive: the last plan record is <verdict>`,
  exit 1, no record: with no record (`none`), after a `BLOCKED` record, after
  `BLOCKED, user continued`, and after a `REVISE` with one `HIGH` finding; it is allowed after a
  `REVISE` with only `MEDIUM` and `LOW` findings and after an earlier `WAIVED` (FR-001); (g) a `sha256sum` stub that prints nothing gives `cannot hash inputs`,
  exit 2, no record (lessons L16); (h) `note plan <f> "one line"` prints `noted: plan /advisor`,
  writes `## plan | <ts> | /advisor` and `summary: one line`, and `check plan` still passes on
  the earlier record; (i) after one APPROVED run, one waive and one note, `count <f>` prints
  `advisor calls: codex 1, waived 1, /advisor 1`; with no `advisor.md` it prints
  `advisor calls: codex 0, waived 0, /advisor 0`; a `BLOCKED, user continued` entry is not
  counted; (j) `diff <f> HEAD` with no change prints `no change since HEAD: skip`, exit 0, no
  record, no codex call; (k) `diff <f> <sha>` after a commit, in mode `codex` and in mode `both`,
  prints `advisors: /advisor (mode codex)` (or `both`), exit 0, no record; mode `off` prints
  `no advisor: mode off`; (l) `diff <f> nosuchref` gives `usage:`, exit 2. Run it: red. Owns:
  `tests/test_advisor_waive.sh`, `tests/test_advisor.sh`. Test: `bash tests/test_advisor_waive.sh`. (FR-001, FR-002, FR-003,
  FR-004, lessons L1, L16)
- [X] T003 [P] [US1] Write `tests/test_advisor_rules.sh`: assert A1 to A13 in their files, and
  that `Then run the same point once more on the changed input.` is gone from
  `skills/st-build/SKILL.md`. In `tests/test_on_demand.sh`, delete only the row
  `#18 FR-005 revise ... Then run the same point once more on the changed input.` (the row with
  `Two rounds at most` stays), and change the check `#18 plan-only st-build no diff point`
  (`tests/test_on_demand.sh:309`) to: `st-advisor.sh diff` appears in `skills/st-build/SKILL.md`
  only on the A9 line (zero matching lines also pass, so the check is green before T006 and after
  it), and `check diff` does not appear. Run it: red. Owns: `tests/test_advisor_rules.sh`,
  `tests/test_on_demand.sh`. Test: `bash tests/test_advisor_rules.sh`. (FR-001 to FR-004,
  lessons L1, L39)
- [X] T004 [P] [US1] Write `tests/test_test_scope.sh`: assert S1 to S6 in their files, the three
  "Gone" lines of the US1 test scope table, and the repo rule: every line that matches
  `full (test )?suite` (any case) in `skills/*/SKILL.md` (not `st-hallmark`, `st-impeccable`,
  `st-ui-ux`), `agents/*.md`, `procedures/*.md` and `templates/*.md` holds S1, S3, S4, S5 or
  `Do not run the full suite`. Run it: red. Owns: `tests/test_test_scope.sh`. Test:
  `bash tests/test_test_scope.sh`. (FR-005, FR-006, FR-007, lessons L1)

### Build

- [X] T005 [P] [US1] In `scripts/st-advisor.sh` add `waive plan`, `note`, `count` and `diff`
  (the no-change skip and the mode `codex`, `both`, `off` lines only; Codex at `diff` comes in
  T023), make `check plan` read only the last `^## plan \| [^|]* \| sha256 ` header, and name
  every form in the usage line (contracts/scripts.md sections 1.1, 1.2, the `diff` row of 1.3,
  and the mode `codex` and `both` rules of 1.4 for `diff`). Owns: `scripts/st-advisor.sh`. Test:
  `bash tests/test_advisor_waive.sh && bash tests/test_advisor.sh`. (FR-002, FR-003, FR-004,
  lessons L16, L18)
- [X] T006 [P] [US1] Write A1 to A4 and A7 to A13 in `skills/st-build/SKILL.md` (Advisor section
  and the end-of-Build paragraph) and A5, A6 in `skills/st-inspect/SKILL.md` (Gate), and remove
  `Then run the same point once more on the changed input.` Keep every other row that
  `tests/test_on_demand.sh` asserts for these files. Owns: `skills/st-build/SKILL.md`,
  `skills/st-inspect/SKILL.md`. Test: `bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh && bash tests/test_verify.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`.
  (FR-001 to FR-004, lessons L18, L39)
- [X] T007 [P] [US1] Write S1 and S2 in `agents/st-build.md` (step 4, in place of `Then run the
  other tests that cover the files you touched.`) and `agents/st-debug.md` (step 5, in place of
  `then the other tests that cover the touched files.`), S3 in `skills/st/SKILL.md` (Always), S4
  in `agents/st-plan.md` (Rules), S5 in `procedures/tasks.md` (Checklist Format), S6 as step 7
  of `skills/st-sync/SKILL.md`. Owns: `agents/st-build.md`, `agents/st-debug.md`,
  `skills/st/SKILL.md`, `agents/st-plan.md`, `procedures/tasks.md`, `skills/st-sync/SKILL.md`.
  Test: `bash tests/test_test_scope.sh && bash tests/test_on_demand.sh && bash tests/test_design_lane.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`.
  (FR-005, FR-006, FR-007)
- [X] T008 [US1] README task 1 of 2. Add to the Tests block of `README.md` every test file that
  exists at the end of wave 3: `bash tests/test_lane_steps.sh`, `bash tests/test_advisor_waive.sh`,
  `bash tests/test_advisor_rules.sh`, `bash tests/test_test_scope.sh`, `bash tests/test_lock.sh`,
  `bash tests/test_lock_rules.sh`, `bash tests/test_codex_agent.sh` (only if T050 passed),
  `bash tests/test_advisor_matrix.sh`, `python3 tests/test_approve_hook.py` (the style of
  `README.md:316`), `bash tests/test_plan_rules.sh`, `bash tests/test_screen_rules.sh`,
  `bash tests/test_triage_rules.sh`, `bash tests/test_no_frontend_design.sh`. Add one sentence
  beside the `scripts/` list: `scripts/st-lock.sh` runs tests marked `[lock]` one at a time per
  repo; it is not checked on Windows (research R-D). Runs last in wave 3, after T018. Owns:
  `README.md`. Test: `bash tests/test_inspect.sh`. (FR-009, FR-031, lessons L7)

**Checkpoint**: quickstart section 1 passes.

## Phase 4: User Story 2 - Workers do not stop on Stratum's own prompts (P1)

**Goal**: the guard reads unsplittable commands line by line; one lock for tests that cannot run
at the same time.

**Independent Test**: quickstart section 2.

### Tests (write first, must fail)

- [X] T009 [P] [US2] Add to `tests/test_git_guard.py` (contracts/scripts.md section 6). Each
  command has a stray `'` (as in `it's`) on a line, so the whole command does not split: (a) a
  heredoc with no git word, then `grep -n here t.txt`: no decision; (b) the same with a last
  line `git status`, and one with `git log --oneline`: no decision; (c) with `git commit -m x`:
  `ask`, also with commit mode `auto` (folder unknown); (d) with `git push --force`: `ask` and
  `force push` in the reason; (e) with `git add -A`: `deny`; (f) a Python heredoc whose line is
  `subprocess.run(["git", "commit", "-m", "x"])` and whose comment line is `# it's a test`: `ask`
  with `The git guard could not read a git command on this line.`; (g) `echo "run git status"`
  with a stray-quote line: `ask`; (h) a heredoc line `hooks/st-git-guard.py it's`: no decision;
  (i) the existing `test_parse_error_asks` stays; (j) escaped git words, each on a line after a
  stray-quote line: `\git push --force`, `g''it push --force` and `gi\t push --force` ask;
  `\git status`, `g''it status` and `gi\t status` give no decision. Run it: red. Owns: `tests/test_git_guard.py`.
  Test: `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py`. (FR-008, lessons L1, L3)
- [X] T010 [P] [US2] Write `tests/test_lock.sh` for `scripts/st-lock.sh` (contracts/scripts.md
  section 3). Make a temp git repo with one commit and a linked worktree (`git worktree add`).
  Cases: (a) free lock: the command runs, its exit code passes through (`sh -c 'exit 7'` gives
  7), the lock folder is gone after; (b) held: A `st-lock.sh -- sleep 3` in the background from
  the main checkout; when the lock folder exists (a test-side check with a 5 s bound), B
  `st-lock.sh -- date +%s` from the worktree prints `lock: waiting for test (pid <A>)` on stderr
  and its date is not before A's end; (c) timeout: A holds with `sleep 5`, B
  `--timeout 1 -- touch ran` exits 75, stderr matches
  `^lock: waited 1 s for test; held by pid [0-9]+ since [0-9TZ:-]+; ran nothing$`, and `ran`
  does not exist; (d) stale: a lock folder whose `pid` is a finished process's pid; B runs at
  once (under 2 s) and the folder is gone after; (e) the held lock is at
  `$(git rev-parse --path-format=absolute --git-common-dir)/stratum-test.lock` when taken from the
  worktree; (f) `--name codex-w1` runs while the `test` lock is held; (g) outside a git repo:
  `lock: not in a git repo`, exit 2; (h) `--timeout abc` and a missing `--` give a usage line,
  exit 2; (i) the script has no `pgrep`, `flock`, `pkill` or `ps ` text. Run it: red (no
  script). Owns: `tests/test_lock.sh`. Test: `bash tests/test_lock.sh`. (FR-009, lessons L29)
- [X] T011 [P] [US2] Write `tests/test_lock_rules.sh`: assert L1 in `agents/st-test.md`,
  `agents/st-build.md`, `agents/st-debug.md` and `skills/st-build/SKILL.md`, L2 in the three
  agents, L3 in `skills/st-build/SKILL.md`. Run it: red. Owns: `tests/test_lock_rules.sh`. Test:
  `bash tests/test_lock_rules.sh`. (FR-010, lessons L1)
- [X] T012 [P] [US2] In `tests/test_st_worker.sh` case S1, assert the brief holds the whole B1
  line (`grep -qxF`). Run it: red. Owns: `tests/test_st_worker.sh`. Test:
  `bash tests/test_st_worker.sh`. (FR-010, lessons L37)

### Build

- [X] T013 [P] [US2] Build the fallback in `hooks/st-git-guard.py` (contracts/scripts.md section
  6): move the segment loop body into a function that both the whole command and one line use.
  Then the negative control: `git show 6fe9d60:hooks/st-git-guard.py > <scratchpad>/old-guard.py`
  and run `ST_GIT_GUARD=<scratchpad>/old-guard.py PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py`
  right after a green run of the new guard: cases (a), (b) and (h) must fail on the old guard.
  Report each result. Owns: `hooks/st-git-guard.py`. Test:
  `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py`. (FR-008, lessons L2, L20, L25)
- [X] T014 [P] [US2] Write `scripts/st-lock.sh` (contracts/scripts.md section 3, data-model
  section 4), with the `ponytail:` line for the two-waiter race (research R-D). Owns:
  `scripts/st-lock.sh`. Test: `bash tests/test_lock.sh`. (FR-009, lessons L29)
- [X] T015 [P] [US2] Write L1 and L2 in `agents/st-test.md` (Steps), `agents/st-build.md` and
  `agents/st-debug.md` (Steps), and L1 and L3 in `skills/st-build/SKILL.md` (Per task). Owns:
  `agents/st-test.md`, `agents/st-build.md`, `agents/st-debug.md`, `skills/st-build/SKILL.md`.
  Test: `bash tests/test_lock_rules.sh && bash tests/test_test_scope.sh && bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh`.
  (FR-010)
- [X] T016 [P] [US2] Add B1 to the brief's Facts in `scripts/st-worker.sh` (after the Test
  command line) and the same line to section 3 of `specs/008-herdr-workers/contracts/script.md`.
  Owns: `scripts/st-worker.sh`, `specs/008-herdr-workers/contracts/script.md`. Test:
  `bash tests/test_st_worker.sh`. (FR-010, lessons L37)

**Checkpoint**: quickstart section 2 passes.

## Phase 5: User Story 3 - The right advisors for the risk (P2)

**Goal**: a risk level with the lane, the matrix in `st-advisor.sh`, Codex in a herdr tab, and
the High talk.

**Independent Test**: quickstart section 3 and 3L.

### Tests (write first, must fail)

- [X] T050 [US3] Live probe of the Stratum Codex home (research R-J, D25). Runs in wave 1, before
  any Codex adapter task. In a herdr pane: make `<scratchpad>/cxhome/` holding only
  `auth.json -> ~/.codex/auth.json`; make `<scratchpad>/cxproj/` (`git init`) with
  `.codex/config.toml` holding a canary `notify = ["sh", "-c", "touch <scratchpad>/canary-notify"]`
  and a canary `[mcp_servers.canary]` whose command touches `<scratchpad>/canary-mcp`; run
  `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <scratchpad>/cxproj --label cx-probe --env CODEX_HOME=<scratchpad>/cxhome --no-focus`
  and `herdr agent start cx-probe --kind codex --pane <its pane> --timeout 120000 -- -s read-only -a never --no-alt-screen`;
  answer a trust dialog, if one shows, with its "do not trust" option and note it; send
  `herdr agent prompt cx-probe "Say OK." --wait --until done --until idle --timeout 120000`.
  Pass when all hold: the agent answers with no login screen; the footer model is not
  `GPT-6-Astra xhigh`; neither canary file exists; `test -L <scratchpad>/cxhome/auth.json` holds
  after the run; `codex login status` in a normal shell still prints `Logged in using ChatGPT`.
  Close the tab. Record every result in research.md R-J. If it fails: T019, T021 and T024 are
  ticked `Not run, T050 failed: <first failed check>` (lessons L24), T018 drops case (k) and
  (n), T023 builds no herdr path and no `codex-home`, and T020 and T022 use the "T050 fails"
  lines of contracts/phrases.md. Owns: `specs/010-workflow-overhaul/research.md`. Test: the
  commands above. (FR-013, D25, security note S2, lessons L32)
- [X] T018 [P] [US3] Write `tests/test_advisor_matrix.sh` (setup as T002, plus a
  `.stratum/state.json` with `risk`). In `tests/test_advisor.sh` add
  `unset HERDR_ENV HERDR_WORKSPACE_ID` at the top and change the expected `mode not set` lines at
  lines 315 and 379 to R18's message, and in `badjson` (line 339) drop `{"model": "gpt-test-1"}`
  (11 cases left) and add a check that this file runs as `auto` (first line
  `advisors: codex (plan, risk normal)`), per D24. Cases from contracts/scripts.md sections 1.3 to 1.5: (a)
  mode `auto` from `{"mode": "auto"}`, from `{}` and from `{"model": "m1"}`; (b) for each of
  `plan`, `test`, `decisions`, `diff` and each risk `high`, `normal`, `low`, `none`: first line
  `advisors: <set> (<point>, risk <level>)` with the set from the matrix, and the stub `codex` is
  called only for `codex` and `both`, with no record otherwise; (c) no `risk`: first line
  `risk not set: normal`; (d) mode `codex`: `plan` prints today's first line (no `advisors:`
  line), `decisions` prints `advisors: /advisor (mode codex)`; mode `both`: `plan`'s first line is
  `mode both: also consult /advisor if one is set`; (e) `{"mode": "auto2"}`: `BLOCKED: bad
  advisor.json`; (f) `diff` in auto normal after a commit: the prompt has the exact `Point: diff.`
  line, the record is `## diff | ...`; a `git` stub that fails on `diff` (execs the real git
  otherwise) and a `sha256sum` stub that prints nothing each give `cannot hash inputs`, exit 2,
  no record (lessons L16, L17); (g) `decisions` with an unreadable list (`chmod 000`, skipped as
  root) gives `usage:`, exit 2; its prompt has the exact `Point: decisions.` line and the list
  text; (h) `round plan <f> 1 <views>` has the exact round line; round 3 adds the last-round
  line; round 4 gives `usage:`; the record is `## plan round 3 | <ts> | sha256 <hash of views> | <verdict>`
  and `check plan` still reads the last `## plan |` run; (i) `talk plan <f> <file>` with all five
  lines prints `talk recorded: plan, 3 rounds` and writes the header `## plan talk | <ts> | 3 rounds`
  and the lines; a file with no `calls:` line, or `rounds: 4`, gives `usage:`, exit 2, no record;
  (j) `count` counts round records as codex; (k) herdr path: `HERDR_ENV=1`,
  `HERDR_WORKSPACE_ID=ws<random>`, `XDG_STATE_HOME=<tmp>/state` with a Stratum Codex home made by
  `codex-home`, and a stub `herdr` that answers `agent list` (empty),
  `tab create`, `agent start`, `agent prompt` (`done`) and `agent read` (plain text with the
  markers and an APPROVED answer, using the nonce it reads from the prompt file named in the
  prompt text): `plan` prints `APPROVED sha256 <h>`, the stub `codex` saw no `exec`, and the
  herdr log has `agent start st-codex-001 --kind codex` and `tab create ... --env CODEX_HOME=<tmp>/state/stratum/codex-home`;
  (k2) the same with no Stratum Codex home: the stub `codex` saw `exec` and the stub `herdr` was
  not called (the fallback, D25); (l) the no-file line is R18's message; (m) run from a linked worktree whose
  `.stratum/state.json` says `risk: low` while the main checkout's says `high`: the first line
  names `risk high` (contract 1.4); (n) `codex-home` with `CODEX_HOME=<tmp>/user` holding
  `auth.json`: prints `codex home: <tmp>/state/stratum/codex-home`, the folder has mode 700 and
  only `auth.json`, a symlink to `<tmp>/user/auth.json`; a second run changes nothing; with no
  `<tmp>/user/auth.json`: `no codex login: run codex login, then run this again`, exit 1, no
  folder; no other command makes the folder (after (a) to (m), it exists only if (n) made it).
  Run it: red. Owns: `tests/test_advisor_matrix.sh`, `tests/test_advisor.sh`. Test:
  `bash tests/test_advisor_matrix.sh`. (FR-011, FR-012, FR-013, FR-014, FR-015, FR-016,
  D24, D25, lessons L14, L16, L17, L26, L31)
- [X] T019 Not run, T050 failed: check 1, the agent gave no answer. [P] [US3] Wave 2, after T050 passed. Write `tests/test_codex_agent.sh` for `scripts/st-codex-agent.sh` with a
  stub `herdr` whose ids have a random part (lessons L26) and whose `agent read` prints plain
  text (lessons L31), from a temp project with `specs/010-demo/`. Cases from contracts/scripts.md
  section 2, each run with a temp `<codex home>` whose `auth.json` is a symlink: (a0) a
  `<codex home>` with no `auth.json` link: `ERROR: no Stratum Codex home`, exit 2, no herdr call;
  (a) no agent: `tab create --workspace <ws> --cwd <pwd> --label Codex --env CODEX_HOME=<codex home> --no-focus`,
  then `agent start st-codex-010 --kind codex --pane <pane from the stub> --timeout 120000 -- -s read-only -a never --no-alt-screen`
  (TAB-split argv from the stub log); `-m m1 -c model_reasoning_effort="high"` come after
  `--no-alt-screen`; (b) `st-codex-010` in this workspace: no `tab create`, no `agent start`;
  (c) `st-codex-009` in this workspace: `tab close <its tab_id>` before the new start; (d)
  `st-codex-010` in another workspace: ignored, a new start here; (e) `agent_pane_busy` twice
  then ok: 3 start calls; busy every time: exactly 10 start calls, then `ERROR:` and exit 1
  (lessons L30); (f) `agent_not_ready`: the exact `ERROR: Codex waits for an answer at start in its Codex tab. If it asks whether to trust the folder, pick the option that does not trust it (trusting loads the project's .codex/config.toml), then run the point again.`, exit 1;
  (f2) the stub `agent prompt` replaces `<codex home>/auth.json` with a file: the exact
  `ERROR: Codex replaced the login link ...` line, exit 1, no answer file;
  (g) the prompt file ends with the three lines of step 4 and a 12-hex nonce; the prompt call
  argv ends `--wait --until done --until idle --until blocked --timeout <ms>` with `<ms>` at
  most 480000, and smaller when the stub's `agent start` takes 2 s; (h) prompt state
  `blocked`: `ERROR: Codex waits for an answer in its Codex tab.`, exit 1; (i) read text with a
  line that holds `ST-ADVISOR-BEGIN-<nonce>` inside other text, an earlier full pair around junk,
  and a last pair around JSON wrapped over 3 lines that start with `• ` or two spaces: the answer
  file is the JSON joined with single spaces, and `python3 -c 'import json,sys; json.load(open(sys.argv[1]))'`
  reads it; (j) no pair: `ERROR: no answer between the markers`, exit 1; (k) feature dir
  `specs/demo`: `ERROR: feature dir must start with three digits`, exit 2. Run it: red. Owns:
  `tests/test_codex_agent.sh`. Test: `bash tests/test_codex_agent.sh`. (FR-013, lessons L26,
  L30, L31)
- [X] T020 [P] [US3] Write `tests/test_risk_rules.sh`: assert R1 to R18 and R21 in their files, the US3
  "Gone" lines, and the kept `mode both` line. In
  `tests/test_on_demand.sh` change row `#18 FR-010 modes` (the `(\`codex\`, \`both\` or \`off\`).`
  row) to R4, the README row of `#18 FR-010 no file` to R18, and `#18 FR-015 init`
  (``advisor mode `codex` (recommended``) to R15, and row `#18 D23 readme`
  (`tests/test_on_demand.sh:295`) to R21. Run it: red. Owns:
  `tests/test_risk_rules.sh`, `tests/test_on_demand.sh`. Test: `bash tests/test_risk_rules.sh`.
  (FR-011 to FR-016, lessons L1, L38)

### Build

- [X] T021 Not run, T050 failed: check 1, the agent gave no answer. [P] [US3] Wave 3, after T050 passed and T019. Write `scripts/st-codex-agent.sh` (contracts/scripts.md section 2). Owns:
  `scripts/st-codex-agent.sh`. Test: `bash tests/test_codex_agent.sh`. (FR-013, lessons L26,
  L30, L31, L33)
- [ ] T022 [P] [US3] Write R1 to R3 and R12 in `skills/st/SKILL.md` (R1 replaces the lane line,
  R12 joins the small-decision bullet); R4 to R11 and R13 in `skills/st-build/SKILL.md`
  (Advisor section: R4 replaces the mode line, R5 goes after the kept `mode both` line, the
  matrix table with the R6 row and the other three rows from contracts/scripts.md section 1.4
  replaces the "It runs at two points" sentence; R13 in Per story); R14 in `skills/st-fast/SKILL.md`; R15 in
  `skills/st-init/SKILL.md` step 11; R19 in `skills/st-init/SKILL.md` step 11; R20 in the Advisor section of
  `skills/st-build/SKILL.md`; R16 to R18 and R21 (replaces the `--ignore-user-config` sentence at `README.md:182`) in the advisor part of `README.md` (with T050's
  result: R7 and R17 as written, or their "T050 fails" lines and no R19, R20). Owns:
  `skills/st/SKILL.md`, `skills/st-build/SKILL.md`, `skills/st-fast/SKILL.md`,
  `skills/st-init/SKILL.md`, `README.md`. Test:
  `bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh && bash tests/test_design_lane.sh && bash tests/test_advisor_rules.sh && bash tests/test_lock_rules.sh && bash tests/test_test_scope.sh && bash tests/test_shortcuts.sh && bash tests/test_screen_rules.sh && bash tests/test_model_files.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`.
  (FR-011 to FR-016, D25, security note S1, S2)
- [X] T023 [US3] In `scripts/st-advisor.sh` add mode `auto` (missing `mode` = `auto`), the risk
  read, the matrix and the `advisors:` line, Codex at `diff` with the checked hash, `decisions`,
  `round`, `talk`, `codex-home`, the herdr path with `st-lock.sh` and `st-codex-agent.sh` (only
  with the Stratum Codex home; both only if T050 passed), exit 75 as
  `BLOCKED: Codex agent busy with another review`, and the new no-file line (contracts/scripts.md
  sections 1.3 to 1.5). Depends on T021. Owns: `scripts/st-advisor.sh`. Test:
  `bash tests/test_advisor_matrix.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh`.
  (FR-012 to FR-016, security note S1, lessons L14, L16, L17)
- [X] T024 Not run, T050 failed: check 1, the agent gave no answer. [US3] Only if T050 passed. First run quickstart section 0 step 2 (the scripts in use are
  this branch's); no live result counts before it passes. Then the live run of quickstart section
  3L in a scratch clone in herdr. Record in research.md R-H: the time, the lines read, whether the
  JSON parsed, the tab and agent names, steps 2 to 4, and `test -L ~/.local/state/stratum/codex-home/auth.json`
  after the longest review (F10). A failure goes back to T021 or T023 with its first error line. Depends on
  T021 to T023. Owns: `specs/010-workflow-overhaul/research.md`. Test: the commands of
  quickstart section 3L. (FR-013, lessons L32)

**Checkpoint**: quickstart section 3 passes.

## Phase 6: User Story 4 - Autonomous build with workers (P2)

**Goal**: Build can use workers; workers get the full layout; autonomous mode routes permission
prompts through the hook; normal mode never answers them.

**Independent Test**: quickstart section 4 and 4L.

### Tests (write first, must fail)

- [X] T026 [P] [US4] Write `tests/test_approve_hook.py` (unittest) for `hooks/st-approve.py`
  (contracts/scripts.md section 5). Run the hook by subprocess with JSON on stdin and `cwd` in a
  temp git repo (the main checkout) with `.stratum/approve/`. "Autonomous on" means the main
  checkout's `.stratum/autonomous` and `.stratum/approve/session` both hold `S1`; every
  `PermissionRequest` case below runs with it on unless it says otherwise. Every "no output" and
  "no `.req`" case below also asserts exit 0 and empty stderr (F7). D27 lock 1 cases, each
  with no output and no `.req`: (a1) a stale `.stratum/approve/` and no `.stratum/autonomous`
  (normal mode); (a2) `.stratum/autonomous` holds `S1`, `session` holds `S2`; (a3) after a
  first `.req` round, `.stratum/autonomous` is removed ("stop autonomous") and a new prompt
  comes; (a4) a linked worktree as `cwd` whose own `.stratum/autonomous` and `session` hold `S1`
  while the main checkout has no `.stratum/autonomous`; (a5) an empty first line in both. D27
  lock 2 cases (`PreToolUse`, in a worker session: the root has `.stratum/approve/`):
  `echo x > .stratum/approve/1-1.ok`, `touch .stratum/'approve'/1-1.ok`,
  `touch .stra\tum/approve/1-1.ok`, `touch .stratum/./approve/1-1.ok`,
  `touch .stratum//approve/1-1.ok`, `ls .stratum/approve`, `echo S9 > .stratum/autonomous`,
  `bash scripts/st-worker.sh approve worker-t1 --request 1-1 --input-stdin --record r`,
  `st-worker.sh pass worker-t1 --request 1-1`, `st-worker.sh autonomous-off --roster r`,
  `touch .stratum/././approve/1-1.ok`, `touch .stratum///approve/1-1.ok`,
  `touch .stratum/x/../approve/1-1.ok`, `bash scripts/st-worker.sh $'approve' worker-t1`,
  `bash scripts/st-worker.sh "pass" worker-t1`, `st-worker.sh wait worker-b`,
  `st-worker.sh start t9 --autonomous`, `cd <main> && bash scripts/st-worker.sh pass worker-t1` (cwd the
  worktree, `CLAUDE_PROJECT_DIR` the worktree), and `git init sub && cd sub && st-worker.sh pass x`
  (cwd `sub`, a folder above it has `.stratum/approve/`) each
  get `permissionDecision` `deny` with the reason `.stratum/approve/ and .stratum/autonomous are written only by the orchestrator.`; Edit, Write,
  MultiEdit and NotebookEdit of `<root>/.stratum/approve/1-1.ok`, `<root>/.stratum/./approve/x`
  and `<root>/.stratum/autonomous` are denied the same way, and so are Read of
  `<root>/.stratum/approve/session`, Read of `<root>/.stratum/autonomous`, Grep with `path`
  `<root>/.stratum/approve`, Grep with `glob` `.stratum/approve/*` and Glob with `pattern`
  `.stratum/approve/*`; (D30) no output, exit 0 and empty stderr for `ls scripts/st-worker.sh`,
  `cat scripts/st-worker.sh`, `bash -n scripts/st-worker.sh`, `shellcheck scripts/st-worker.sh`,
  `grep -n approve scripts/st-worker.sh`, `git add scripts/st-worker.sh && git commit -m x`, an
  Edit of `scripts/st-worker.sh`, and a Grep with `pattern` `.stratum/approve` and a plain `path`
  `scripts` (the pattern is a content regex, not a path); (F7) `cwd` a non-worker folder and `CLAUDE_PROJECT_DIR` the worker worktree: `echo x > .stratum/approve/1-1.ok`
  is denied; a symlink `link -> .stratum/approve` and an Edit of `link/1-1.ok`: denied (realpath,
  F5); a worker session
  found only by its branch (`worker-t1`, no `.stratum/approve/`) denies `echo x > .stratum/autonomous`; Edit `src/a.py` and Bash
  `bash tests/x.sh` give no output; in a non-worker session (no `.stratum/approve/`, branch
  `010-demo`), `st-worker.sh approve ...` and `printf S1 > .stratum/autonomous` give no output. Then: (a) no `.stratum/approve`: no
  output, exit 0, nothing written; (b) `.stratum/approve` is a symlink: no output; (c) Bash `bash tests/x.sh`:
  a `<rid>.req` with `tool_name` and `tool_input` appears; the test then writes `<rid>.ok`; stdout
  is exactly the allow JSON; the three files are gone; (d) `.user`: no output, files gone; (e)
  `ST_APPROVE_WAIT=1` and no answer: no output, `.req` gone; (f) each of these gives no output
  and no `.req` ever: `git push`, `git push --force`, `git branch -D x`, `git worktree remove ../w`,
  `git reset --hard`, `cat .env`, `cat /etc/passwd`, `cat ../other/f`, `npm install left-pad`,
  `pip install x`, `curl https://example.com`, `gh pr list`, `echo x > .stratum/approve/1-1.ok`,
  `sudo ls`; Edit outside the root, Edit `.env.local`, Edit `package.json`, Edit
  `.stratum/git-guard.json`, Write under `.git/`; tool `WebFetch`; (g) Edit `src/a.py` inside
  the root: a `.req`; a heredoc with `it's` and a last line `git commit -m x` (a command the git
  guard cannot split): a `.req`; (h) a non-ASCII command with `PYTHONIOENCODING=cp1252`: a `.req` (lessons
  L3, a simulation); (h2) D23 commits, in a temp git repo as the root on branch `worker-t1`, with
  `.stratum/git-guard.json` `{"branch": "worker-t1"}` and `.stratum/approve/owns` holding
  `src/a.py`: `git add src/a.py && git commit -m x` gives a `.req` whose `branch` is `worker-t1`
  and `staged` is `["src/a.py"]`; no `.req` for each of: `git commit --amend -m x`,
  `git commit --no-verify -m x`, `git commit -n -m x`, `git commit -a -m x`, the same own-files
  commit after `git checkout -b other`, `git add src/b.py && git commit -m x` (not owned), a
  commit with `src/b.py` already staged (`git diff --cached`), `git -C ../x commit -m x`, an
  own-files commit with `owns` missing or empty, `git commit -m x src/b.py` (pathspec, no `--`),
  `git commit -o -m x src/a.py`, `git commit --only -m x src/a.py`,
  `git commit --pathspec-from-file=f -m x`, `git add -u && git commit -m x`,
  `git add -A && git commit -m x`, `GIT_INDEX_FILE=idx git commit -m x`,
  `GIT_DIR=.git git commit -m x`, `GIT_WORK_TREE=. git commit -m x` and
  `git -c user.name=x commit -m x`, and (F4) `git checkout other && git add src/a.py && git commit -m x`,
  `git rm src/b.py && git commit -m x`, `git mv src/a.py src/c.py && git commit -m x`,
  `git restore --staged src/b.py && git commit -m x`, `git apply --cached p.diff && git commit -m x`,
  `git stash pop && git commit -m x`, `\git checkout other # it's x` followed by an own-files commit,
  `sh -c "git checkout other" && git add src/a.py && git commit -m x` and
  `bash -c "git add src/b.py" && git commit -m x`; `git commit -m x -- src/a.py` gives a `.req` with `staged`
  `["src/a.py"]`, and (F6) `git add src/a.py && git commit -m "demo heredoc"` gives a `.req`
  with `staged` `["src/a.py"]` (the two-word message is not a pathspec), and (F10)
  `git add src/a.py && git commit -m "$(cat <<'EOF'` / `a message` / `EOF` / `)"` gives a `.req`
  with `staged` `["src/a.py"]`, and `git commit -m x > log.txt` treats `log.txt` as a redirect
  target, not a pathspec; (h3) test runners give a `.req`: `npm test`, `npm run test`, `npx vitest run`,
  `cargo test`, `go test ./...`, `pytest`, `uv run pytest`; install words give none:
  `npm install x`, `npm i x`, `pnpm add x`, `yarn add x`, `bun add x`, `pip install x`,
  `uv add x`, `uv pip install x`, `cargo add x`, `go get x`; (h4) F3: no `.req` for an Edit of
  `.claude/settings.json`, `.mcp.json`, `CLAUDE.md`, `AGENTS.md`, `.githooks/pre-commit` or
  `.husky/pre-commit`, nor for `echo x > .claude/settings.json`, `cd .claude && echo x > settings.local.json` or
  `echo {} > .mcp.json`; (h5) F3 commit parse: `git add src/a.py && git commit -m x 2>&1` gives a
  `.req` with `staged` `["src/a.py"]`; `git add src/a.py && git commit -m "explain git guard"` gives a
  `.req`; `git commit -F - <<'EOF'` with a body and `git commit --file=- -m x` give none; (h6) F6:
  `st-approve.py --render <req>` prints `Bash: ` and the sorted, compact, ASCII-escaped JSON of
  `tool_input` on one line (a `é` prints as `\u00e9`), and the same input with keys in another
  order prints the same bytes; (i) stdin that is not JSON: no output, exit 0; (j) `hooks/commands.json` has
  one `PermissionRequest` entry with command `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-approve.py"`
  and timeout 310, and one `PreToolUse` entry with matcher `Bash|Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Glob`,
  the same command and timeout 10; (k) no `PermissionRequest` case prints `deny`, and the hook
  file has no `"behavior": "deny"` text. Run it: red. Owns:
  `tests/test_approve_hook.py`. Test: `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_approve_hook.py`.
  (FR-019, D23, D27, D30, security notes S3, S4, lessons L3, L5)
- [X] T027 [P] [US4] Extend `tests/test_st_worker.sh` (contracts/scripts.md section 4). Teach the
  stub `herdr` `tab rename`, `pane split`, `pane run` and `tab create` with random ids, and an
  `agent read` text taken from a file the case writes. Cases: (a) `start` makes, in this order
  after `worktree create` and before `agent start`: `tab rename <tab> Main`, `pane split <root pane> --direction right --cwd <wt> --no-focus`,
  `pane run <new pane> lazygit`, then for `Dev Servers` and `VM` a `tab create` and a
  `pane split` of its root pane, ids read from the stub log; the same calls carry `--machine`
  for a saved machine; (b) `start --autonomous` with no `.stratum/autonomous`, and with a file
  whose line is not `$CLAUDE_CODE_SESSION_ID`: `Autonomous build mode is off for this session.`,
  exit 1, no herdr call; (b2) `start --autonomous --machine laptop --repo <path>` (D28): one `ssh`
  call writes the `$CLAUDE_CODE_SESSION_ID` line to `<path>/.stratum/autonomous` before
  `worktree create`, the remote `session` file holds the same line; a roster with a fifth `<path>` field still gives
  the four-column brief row; a remote row with no fifth field, or a different one, gives
  `Roster row for worker-t004 needs the repo path as a fifth field.`, exit 1, no call; a stale `<path>/.stratum/autonomous` with an old id is replaced; a
  symlinked `<path>/.stratum` or file is refused; `STUB_SSH_RC=255` on that write gives
  `cannot write .stratum/autonomous on laptop: <line>`, exit 1, and no `worktree create` or
  `agent start` call; (b3) `autonomous-off --roster <file>` with one local and one laptop row:
  removes the local main checkout's `.stratum/autonomous` (also when run from a linked worktree) and, over `ssh`, the laptop one, printing
  `autonomous off\tlocal` and `autonomous off\tlaptop`; a file whose line is another id is
  kept; a failed `ssh` prints `autonomous off failed\tlaptop\t<line>`, still removes the local
  one, and exits 1; with a match: `<wt>/.stratum/approve/` exists, `session` holds the
  `$CLAUDE_CODE_SESSION_ID` line, and `owns` lists the backticked paths of the task file's `Owns:`
  line, one per line (a task with no `Owns:` line: an empty `owns`); (c) `wait` on `blocked`
  with a `<rid>.req`: the lines `state\tapproval\t...`, `request\t<rid>`,
  `tab\tworkspace worker-t004, tab Main`, `input\tBash: {...}`, then `pane text:` and the stub's
  `STUB PANE` marker (F7, lessons L31), exit 6; a commit `.req` adds
  `branch\tworker-t004` and `staged\tsrc/a.py src/b.py`; with no `.req`: today's
  exit 4; (d) `approve <id> --request <rid> --input-stdin --record <file> <<'ST_INPUT_END'` with the input
  line's text: writes `<rid>.ok`, appends one
  TAB-split record line, calls `agent wait worker-t004 --until working --timeout 5000` before it
  prints `approved\tworker-t004\t<rid>`; refused when autonomous mode is off, for `--request ../x`,
  for a missing `.req`, for stdin text that differs from the `.req` by one character
  (`The input does not match request <rid>. Approve nothing.`, no `.ok`), for an input over
  4000 characters, and when the worker's `session` file differs from the flag (`Worker worker-t004 is not in this autonomous run.`);
  the text read from the heredoc keeps `$(touch pwned)` and backticks literal (no `pwned` file),
  its one trailing newline is dropped, and `<rid>.ok` is written; (d1) F4: the same `$(touch pwned)`
  approval with `--machine laptop`: the `.req` is read with `ssh ... cat`, the ssh log has no
  `pwned` text, no `pwned` file exists, and only the `<rid>.ok` write goes over ssh; `wait`'s
  `input` line and `approve`'s compare use the same rendering (a key order change in the `.req`
  JSON still matches); (d2) F2: `approve`, `pass`, `start --autonomous` and
  `autonomous-off` run from a feature's linked worktree read the main checkout's
  `.stratum/autonomous` (a different line in the linked worktree's own copy is ignored); run
  from a worker worktree (a `.stratum/approve/` folder, or branch `worker-t9`) each prints
  `Run this from the orchestrator's checkout, not a worker worktree.`, exit 1, no call;
  `pass` with autonomous mode off or a session mismatch is refused like `approve`; (e) `pass`: writes `<rid>.user`, prints `passed\t...`; (f) `answer`
  when the pane text has a line `Do you want to proceed?`, `Do you want to make this edit to a.py?`,
  `Do you want to create b.py?` or `❯ 1. Yes`, and when `agent read` fails: the exact
  refusal line, exit 1, no `send-keys` call; (g) `close` removes `.stratum/approve/`; (h) the
  brief's Team rule 1 is the whole B2 line: update the expected rule 1 text at
  `tests/test_st_worker.sh:174` and the check at `:231` (rule 1 now ends in
  `never write in .stratum/approve/.`). Update each existing case whose call order or count
  the layout changes, and name each one in the report. Run it: red. Owns:
  `tests/test_st_worker.sh`. Test: `bash tests/test_st_worker.sh`. (FR-017, FR-018, FR-019,
  FR-021, D23, lessons L26, L27, L34, L37)
- [X] T028 [P] [US4] In `tests/test_statusline.sh` add: input with `"session_id":"S1"` and
  `.stratum/autonomous` holding `S1`: line 2 has ` autonomous `; the file holds `S2`: no
  `autonomous`; no file: no `autonomous`; (F2) input `cwd` a linked worktree whose own
  `.stratum/autonomous` holds `S1` while the main checkout's holds `S2`: no `autonomous`, and the
  reverse shows it. Run it: red. Owns: `tests/test_statusline.sh`. Test:
  `bash tests/test_statusline.sh`. (FR-018)
- [ ] T029 [P] [US4] Write `tests/test_worker_rules.sh`: assert W1 to W17 in their files and the
  three "Gone" lines of the US4 table. In `tests/test_on_demand.sh` delete rows `#17 one-time yes`
  and `#17 FR-014 build`, and change the check `#17 FR-014 build skill` to: `/stratum:st-worker`
  appears in `skills/st-build/SKILL.md` on one line only, the W10 line; (F2) W8 and W9 name the
  main checkout path `\"$(dirname \"$(git rev-parse --path-format=absolute --git-common-dir)\")/.stratum/autonomous\"`, and no line of `skills/st/SKILL.md` writes or
  removes a bare `.stratum/autonomous`. Run it: red. Owns:
  `tests/test_worker_rules.sh`, `tests/test_on_demand.sh`. Test: `bash tests/test_worker_rules.sh`.
  (FR-017, FR-018, FR-019, FR-020, FR-021, FR-022, lessons L1, L39)

### Build

- [X] T030 [P] [US4] Write `hooks/st-approve.py` with both branches (contracts/scripts.md sections
  5.1 and 5.2) and add its `PermissionRequest` and `PreToolUse` entries to
  `hooks/commands.json`, with the `ponytail:` lines for the text never list and the text write
  lock, the D23 commit rules, the D27 session check, and the `--render` helper that
  `st-worker.sh` uses for `wait` and `approve` (F6). Owns: `hooks/st-approve.py`, `hooks/commands.json`. Test:
  `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_approve_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_phase_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_model_hook.py`.
  (FR-019, D23, D27, security notes S3, S4, S5, lessons L3, L5)
- [X] T031 [P] [US4] In `scripts/st-worker.sh` add `start --autonomous` (with the `owns` and
  `session` files, and the remote `.stratum/autonomous` write for `--machine`, D28),
  `autonomous-off`, the `input` rendering through `python3 <plugin root>/hooks/st-approve.py --render`
  (T030's helper, F6), the layout, the `wait`
  approval state, `approve`, `pass`, the `answer` refusal, the `close` cleanup and B2 (Team rule
  1); update the usage line; change rule 1 in section 3 of
  `specs/008-herdr-workers/contracts/script.md` to B2 (contracts/scripts.md section 4). Owns:
  `scripts/st-worker.sh`, `specs/008-herdr-workers/contracts/script.md`. Test:
  `bash tests/test_st_worker.sh`. (FR-017, FR-018, FR-019, FR-021, security notes S3, S5,
  lessons L26, L27, L30, L33, L34, L37)
- [X] T032 [P] [US4] Add the `autonomous` segment to `statusline/st-statusline.sh`
  (contracts/scripts.md section 7). Owns: `statusline/st-statusline.sh`. Test:
  `bash tests/test_statusline.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`. (FR-018)
- [ ] T033 [P] [US4] Write W1 to W7, W11, W14, W16 and W17 in `skills/st-worker/SKILL.md` (step 6 and the
  last line; remove two "Gone" phrases, `pick the one-time yes` and
  `a tool permission for the task's own command`, from the sentence at
  `skills/st-worker/SKILL.md:21` and keep the rest of that line, and replace the whole line
  `skills/st-worker/SKILL.md:39` (`The build loop ... does not use workers.`) with W11), W8, W9 and W12 in `skills/st/SKILL.md` (Always), W10
  in `skills/st-build/SKILL.md` (Parallel tasks), W13 in `skills/st-herdr-workspace/SKILL.md`,
  and W15 in `README.md` (beside the worker section). Owns: `skills/st-worker/SKILL.md`,
  `skills/st/SKILL.md`, `skills/st-build/SKILL.md`, `skills/st-herdr-workspace/SKILL.md`,
  `README.md`. Test:
  `bash tests/test_worker_rules.sh && bash tests/test_on_demand.sh && bash tests/test_risk_rules.sh && bash tests/test_lock_rules.sh && bash tests/test_advisor_rules.sh && bash tests/test_test_scope.sh && bash tests/test_screen_rules.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`.
  (FR-017 to FR-022, D23, security note S4)
- [ ] T034 [US4] First run quickstart section 0 step 3 (the hook in use is this branch's) on each
  machine used; no live result counts before it passes. If the `/plugin` update route does not
  make it pass, tick T034 `Not run, <the probe's result>`. Then the live run of quickstart section
  4L on a scratch branch in herdr. Record each step's output in research.md R-H, including whether the hook answers after more than 120 s.
  D28 step, on a saved machine (whichever machine is not the one running the orchestrator):
  `start t992 ... --machine <m> --repo <path> --autonomous`, one approval there, then
  `autonomous-off --roster <roster>`; record that `<path>/.stratum/autonomous` on `<m>` was
  written, then removed.
  D27 steps (deny reason `.stratum/approve/ and .stratum/autonomous are written only by the orchestrator.`): with autonomous mode on, ask the worker to run `echo x > .stratum/approve/1-1.ok`,
  `touch .stratum/././approve/2-2.ok` and `touch .stratum/x/../approve/3-3.ok`, and to Edit and
  Read `.stratum/approve/session`, and record each denial; then `rm -f "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/autonomous"`, make the
  worker hit a dialog, and record that no `.req` appears and the dialog stays.
  Extra step (F9): give the worker a command its classifier blocks that is not on the hook's
  never list (for example `rm -rf demo` after a task that does not ask for it), and record
  whether a dialog and a `.req` appear. If they do, the W3 rule (a request for an action the
  classifier blocked goes to the user) is the only guard: bring that result to the user.
  If the hook from `hooks/commands.json` never fires (no `.req` while the dialog shows), the
  contingency is that `start --autonomous` passes `--settings <generated file>` with the same
  hook command to `agent start`; bring it to the user before building it. If that fails too,
  autonomous mode stays off and every prompt goes to the user; there is no fallback to
  standing permissions (D29). A failure goes back
  to T030 or T031 with its first error line, or the task is ticked with
  `Not run, <first error line>`. Depends on T030, T031, T032 and T024 (research.md). Owns:
  `specs/010-workflow-overhaul/research.md`. Test: the commands of quickstart section 4L.
  (FR-019, FR-021, lessons L32, L34)

**Checkpoint**: quickstart section 4 passes.

## Phase 7: User Story 5 - Lanes use the Design lane and run more tasks at once (P2)

**Goal**: the planner marks `[P]` with owned files, `[lock]` and `[screen: <mode>]`; Build sends
new screens to the Design lane and runs file-disjoint stories together.

**Independent Test**: quickstart section 5.

### Tests (write first, must fail)

- [X] T036 [P] [US5] Write `tests/test_plan_rules.sh`: assert DL1 to DL10 and DL18 in their files and
  the "Gone" lines for `agents/st-plan.md`, `procedures/tasks.md` and `templates/tasks.md`. Run
  it: red. Owns: `tests/test_plan_rules.sh`. Test: `bash tests/test_plan_rules.sh`. (FR-023,
  FR-026, lessons L1, L41)
- [X] T037 [P] [US5] Write `tests/test_screen_rules.sh`: assert DL11 to DL17 and that `design brief`
  is gone from `agents/st-build.md` and ``merge it into `main` `` from `skills/st-build/SKILL.md`.
  Run it: red. Owns: `tests/test_screen_rules.sh`. Test: `bash tests/test_screen_rules.sh`.
  (FR-024, FR-025, FR-026, lessons L1, L11, L12, L40)

### Build

- [X] T038 [P] [US5] Write DL1 and DL2 in `agents/st-plan.md` (Rules; DL2 replaces
  `Mark tasks that touch no common file \`[P]\`.`), DL3 to DL5 in `procedures/tasks.md` (Format
  Components; DL3 replaces the old `[P] marker` item), DL6 to DL8 and DL18 in `templates/tasks.md`
  (Format list and Notes), DL9 and DL10 in `skills/st-plan/SKILL.md` (steps 3 and 2). Owns:
  `agents/st-plan.md`, `procedures/tasks.md`, `templates/tasks.md`, `skills/st-plan/SKILL.md`.
  Test: `bash tests/test_plan_rules.sh && bash tests/test_test_scope.sh && bash tests/test_on_demand.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`.
  (FR-023, FR-026)
- [X] T039 [P] [US5] Write DL11 to DL16 in `skills/st-build/SKILL.md` (DL11 to DL14 in Per task, DL15
  and DL16 in Parallel tasks; DL16 replaces ``merge it into `main` ``) and DL17 as step 5 of
  `agents/st-build.md`. Owns: `skills/st-build/SKILL.md`, `agents/st-build.md`. Test:
  `bash tests/test_screen_rules.sh && bash tests/test_advisor_rules.sh && bash tests/test_lock_rules.sh && bash tests/test_test_scope.sh && bash tests/test_on_demand.sh`.
  (FR-024, FR-025, FR-026)

**Checkpoint**: quickstart section 5 passes.

## Phase 8: User Story 6 - Skill clean-up (P3)

**Goal**: triage first, no issue offer, no `st-frontend-design`.

**Independent Test**: quickstart section 6.

### Tests (write first, must fail)

- [X] T041 [P] [US6] Write `tests/test_triage_rules.sh`: assert TP1 to TP4 and the US6 "Gone" lines
  (`Make GitHub issues from the tasks?` in no `skills/*/SKILL.md`), and that
  `Next phase: \`/stratum:st-inspect\`.` stays in `skills/st-plan/SKILL.md`. Run it: red. Owns:
  `tests/test_triage_rules.sh`. Test: `bash tests/test_triage_rules.sh`. (FR-028, FR-029,
  lessons L1, L12, L38)
- [X] T042 [P] [US6] Write `tests/test_no_frontend_design.sh`:
  `grep -rn frontend-design <root> --exclude-dir=.git --exclude-dir=specs --exclude=test_no_frontend_design.sh`
  prints nothing; `skills/st-frontend-design/` and `licenses/frontend-design.Apache-2.0.txt` do
  not exist; `vendor.lock` is valid JSON with no `frontend-design` key; and the two-way README
  skill check of `tests/test_inspect.sh:111-114`, copied. Run it: red. Owns:
  `tests/test_no_frontend_design.sh`. Test: `bash tests/test_no_frontend_design.sh`. (FR-030,
  lessons L7)

### Build

- [ ] T043 [P] [US6] Write TP1 at the start of section 1 of `skills/st/SKILL.md` and TP2 in place of
  its issue rule (keep `Do not end a reply with an offer to file issues`), TP3 as the description
  and remove the issue question from the Gate of `skills/st-plan/SKILL.md`, TP4 as line 2 of
  `skills/st-full/SKILL.md`. Owns: `skills/st/SKILL.md`, `skills/st-plan/SKILL.md`,
  `skills/st-full/SKILL.md`. Test:
  `bash tests/test_triage_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_worker_rules.sh && bash tests/test_test_scope.sh && bash tests/test_plan_rules.sh && bash tests/test_design_lane.sh && bash tests/test_on_demand.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`.
  (FR-028, FR-029)
- [X] T044 [P] [US6] Remove `st-frontend-design`: delete `skills/st-frontend-design/` and
  `licenses/frontend-design.Apache-2.0.txt`; remove the `frontend-design` entry from
  `vendor.lock`, its row (line 15) and its name in line 23 of `THIRD_PARTY_NOTICES.md`, its name
  in `README.md` lines 115 and 340, and the `DESIGN.md` mentions at lines 44 and 103; change
  `DESIGN.md:171` to say the visual-direction skill was removed in 010 (D6), with no
  `frontend-design` text in the new line. Owns: `skills/st-frontend-design/`,
  `licenses/frontend-design.Apache-2.0.txt`, `vendor.lock`, `THIRD_PARTY_NOTICES.md`,
  `README.md`, `DESIGN.md`. Test: `bash tests/test_no_frontend_design.sh && bash tests/test_design_lane.sh && ! bash tests/test_inspect.sh | grep '^FAIL' | grep -vxF 'FAIL README tests'`.
  (FR-030, lessons L7)

**Checkpoint**: quickstart section 6 passes.

## Phase 9: Polish and cross-cutting

- [ ] T046 README task 2 of 2, and the FR-027 check. Add `bash tests/test_risk_rules.sh` and
  `bash tests/test_worker_rules.sh` (the test files made after wave 3) to the Tests block of
  `README.md`. Then `bash tests/test_lane_steps.sh` must be green: every FR-027 row is fixed. A
  red row goes back to the task named in the plan.md FR-027 table. Owns: `README.md`. Test:
  `bash tests/test_lane_steps.sh && bash tests/test_inspect.sh`. (FR-027, FR-031, lessons L7)
- [ ] T047 FR-031 negative controls. Make a worktree of `6fe9d60` in the scratchpad
  (`git worktree add <scratchpad>/old 6fe9d60`), copy each new test file and each changed test
  file into it, and run each one there right after its green run here (lessons L25). Count only the
  cases whose behavior this feature changes: each must be red there, and each new file must
  have at least one red case. Cases for kept behavior (old phrases that stay, "no output"
  paths the old code also gives, guard asks the old guard already gives, as T013 names) are
  listed as `same on old` and not counted. Record one line per file in research.md as "R-I
  negative controls". Remove nothing: tell the user the scratch worktree path. Owns:
  `specs/010-workflow-overhaul/research.md`. Test: the commands of T048, run in the old
  worktree. (FR-031, lessons L2, L20, L25)
- [ ] T048 Scoped regression of every test file this feature adds or whose files it changes, one
  command at a time:
  `bash tests/test_lane_steps.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh && bash tests/test_advisor_rules.sh && bash tests/test_test_scope.sh && bash tests/test_lock.sh && bash tests/test_lock_rules.sh && bash tests/test_advisor_matrix.sh && { [ ! -f tests/test_codex_agent.sh ] || bash tests/test_codex_agent.sh; } && bash tests/test_risk_rules.sh && bash tests/test_st_worker.sh && bash tests/test_statusline.sh && bash tests/test_worker_rules.sh && bash tests/test_plan_rules.sh && bash tests/test_screen_rules.sh && bash tests/test_triage_rules.sh && bash tests/test_no_frontend_design.sh && bash tests/test_on_demand.sh && bash tests/test_design_lane.sh && bash tests/test_inspect.sh && bash tests/test_verify.sh && bash tests/test_shortcuts.sh && bash tests/test_model_files.sh && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_approve_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_phase_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_model_hook.py`.
  Not in the list because no file they check changes: `test_design_check.sh`,
  `test_herdr_workspace.sh`, `test_pr_skill.sh`, `test_session_hooks.sh`,
  `test_pr_workflow.mjs`, `test_token_weather.mjs`. Owns: nothing. Test: the command above.
- [ ] T049 Run the hand checks of quickstart sections 1, 2 and 6 and record the outputs in
  research.md R-H. Owns: `specs/010-workflow-overhaul/research.md`. Test: the commands in those
  sections.

## Dependencies and execution order

A task waits only for the earlier tasks that own a file it owns, whose output it needs, or whose
Test reads a file it changes. Test tasks still come before their build tasks.

### Execution waves

| Wave | Tasks | Waits for |
|------|-------|-----------|
| 1 | T001, T002, T003, T004, T009, T010, T011, T012, T026, T028, T036, T037, T041, T042, T050 | nothing: each writes its own test file, T050 writes `research.md` (T002 also `tests/test_advisor.sh`, T003 also `tests/test_on_demand.sh`) |
| 2 | T005, T006, T007, T013, T014, T016, T019, T030, T032, T044 | the wave 1 test of each; T019: T050 passed |
| 3 | T015, T018, T021, T027, T038, then T008 last | T015: T006, T007 (shared `skills/st-build/SKILL.md`, agents). T018: T005 (`tests/test_advisor.sh` is T005's Test). T027: T016 (`tests/test_st_worker.sh`). T038: T007 (`agents/st-plan.md`, `procedures/tasks.md`). T021: T019, T050. T008: T044 (`README.md`) and every test file it lists, so after T018 |
| 4 | T023, T031, T039 | T023: T018, T021, T014. T031: T027, T030 (the `--render` helper). T039: T015 |
| 5 | T020, T024 | T020: T003, T006, T007, T015, T039 (their Tests read `tests/test_on_demand.sh`). T024: T023 |
| 6 | T022 | T020, T039, T008 (`skills/st-build/SKILL.md`, `skills/st/SKILL.md`, `README.md`) |
| 7 | T029, T034 | T029: T022 (its Test reads `tests/test_on_demand.sh`). T034: T030, T031, T032, T024 (`research.md`) |
| 8 | T033 | T029, T022 |
| 9 | T043 | T033 (`skills/st/SKILL.md`), T038 (`skills/st-plan/SKILL.md`) |
| 10 | T046 | T043, T033, T022 (`README.md`), every story task (T001's rows) |
| 11 | T047 and T048, then T049 | T046, T034; T049 after T047 (`research.md`) |

- US1 MVP checkpoint: end of wave 3 (T002 to T008 done, quickstart section 1 passes).
- The code tasks run early, beside US1: git guard (T009, T013), lock (T010, T014), Codex adapter
  (T050 first, then T019, T021), approval hook (T026, T030), status line (T028, T032), the brief line (T012, T016),
  and the `st-frontend-design` removal (T042, T044).
- The text tasks form one chain, because they share `skills/st-build/SKILL.md`,
  `skills/st/SKILL.md`, `tests/test_on_demand.sh` and `README.md`: T006 and T007, then T015 and
  T038, then T039, then T020 (tests), then T022, then T033, then T043.
- A Test that reads a file another task of the same wave writes can see it half done. Run that
  Test again at the end of the wave before a red result counts.
- README tasks: two. T008 lists every test file that exists at the end of wave 3, T046 the two
  made later (`tests/test_risk_rules.sh` in wave 5, `tests/test_worker_rules.sh` in wave 7). Only
  T008, T046 and T048 run `tests/test_inspect.sh`, so it is green at each of them.

## Parallel example: wave 2

```text
T005 (st-advisor.sh), T006 (st-build, st-inspect skills), T007 (6 agent and skill files),
T013 (git guard), T014 (st-lock.sh), T016 (st-worker.sh, 008 contract), T019 (test_codex_agent.sh),
T030 (st-approve.py, commands.json), T032 (statusline), T044 (st-frontend-design removal, README, DESIGN, vendor.lock, notices)
```

## Implementation strategy

1. MVP: waves 1 to 3. US1 is done at the end of wave 3, and the US2 code (guard, lock) is done
   beside it.
2. Waves 4 to 9 finish the other stories. Run each story's quickstart section when its last
   task is done.
3. Waves 10 and 11 last.

## Counts

45 tasks: Setup 1, US1 7, US2 8, US3 8, US4 9, US5 4, US6 4, Polish 4. Live-run tasks: T050, T024,
T034.
