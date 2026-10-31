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

- [ ] T001 [P] Write `tests/test_lane_steps.sh`: one check per row of the plan.md "FR-027"
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

- [ ] T002 [P] [US1] Write `tests/test_advisor_waive.sh` for `scripts/st-advisor.sh`. Copy the
  setup of `tests/test_advisor.sh:1-56` (stub `codex` and `timeout`, temp project) and add
  `unset HERDR_ENV HERDR_WORKSPACE_ID`. Cases from contracts/scripts.md sections 1.1 and 1.2:
  (a) `waive plan <f> "fix-only"` prints `WAIVED sha256 <h>` with `<h>` from the plan hash
  pipeline, then `reason: fix-only`, exit 0, and the stub `codex` wrote no argv file;
  (b) the record header matches `^## plan \| <ts> \| sha256 <h> \| WAIVED$` and the next line is
  `reason: fix-only`; (c) `check plan` after it prints `WAIVED sha256 <h>`, exit 0;
  (d) after a change to `tasks.md`, `check plan` prints `advisor approval is stale`, exit 1;
  (e) a reason that is empty, or only CR and LF, gives `usage:` and exit 2 with no record; a
  reason with an LF is recorded on one line; (f) `waive` works with `{"mode": "off"}` and with
  no `advisor.json`; (g) a `sha256sum` stub that prints nothing gives `cannot hash inputs`,
  exit 2, no record (lessons L16); (h) `note plan <f> "one line"` prints `noted: plan /advisor`,
  writes `## plan | <ts> | /advisor` and `summary: one line`, and `check plan` still passes on
  the earlier record; (i) after one APPROVED run, one waive and one note, `count <f>` prints
  `advisor calls: codex 1, waived 1, /advisor 1`; with no `advisor.md` it prints
  `advisor calls: codex 0, waived 0, /advisor 0`; a `BLOCKED, user continued` entry is not
  counted; (j) `diff <f> HEAD` with no change prints `no change since HEAD: skip`, exit 0, no
  record, no codex call; (k) `diff <f> <sha>` after a commit, in mode `codex` and in mode `both`,
  prints `advisors: /advisor (mode codex)` (or `both`), exit 0, no record; mode `off` prints
  `no advisor: mode off`; (l) `diff <f> nosuchref` gives `usage:`, exit 2. Run it: red. Owns:
  `tests/test_advisor_waive.sh`. Test: `bash tests/test_advisor_waive.sh`. (FR-002, FR-003,
  FR-004, lessons L1, L16)
- [ ] T003 [P] [US1] Write `tests/test_advisor_rules.sh`: assert A1 to A13 in their files, and
  that `Then run the same point once more on the changed input.` is gone from
  `skills/st-build/SKILL.md`. In `tests/test_on_demand.sh`, delete only the row
  `#18 FR-005 revise ... Then run the same point once more on the changed input.` (the row with
  `Two rounds at most` stays). Run it: red. Owns: `tests/test_advisor_rules.sh`,
  `tests/test_on_demand.sh`. Test: `bash tests/test_advisor_rules.sh`. (FR-001 to FR-004,
  lessons L1, L39)
- [ ] T004 [P] [US1] Write `tests/test_test_scope.sh`: assert S1 to S6 in their files, the three
  "Gone" lines of the US1 test scope table, and the repo rule: every line that matches
  `full (test )?suite` (any case) in `skills/*/SKILL.md` (not `st-hallmark`, `st-impeccable`,
  `st-ui-ux`), `agents/*.md`, `procedures/*.md` and `templates/*.md` holds S1, S3, S4, S5 or
  `Do not run the full suite`. Run it: red. Owns: `tests/test_test_scope.sh`. Test:
  `bash tests/test_test_scope.sh`. (FR-005, FR-006, FR-007, lessons L1)

### Build

- [ ] T005 [P] [US1] In `scripts/st-advisor.sh` add `waive plan`, `note`, `count` and `diff`
  (the no-change skip and the mode `codex`, `both`, `off` lines only; Codex at `diff` comes in
  T023), make `check plan` read only the last `^## plan \| [^|]* \| sha256 ` header, and name
  every form in the usage line (contracts/scripts.md sections 1.1, 1.2, the `diff` row of 1.3,
  and the mode `codex` and `both` rules of 1.4 for `diff`). Owns: `scripts/st-advisor.sh`. Test:
  `bash tests/test_advisor_waive.sh && bash tests/test_advisor.sh`. (FR-002, FR-003, FR-004,
  lessons L16, L18)
- [ ] T006 [P] [US1] Write A1 to A4 and A7 to A13 in `skills/st-build/SKILL.md` (Advisor section
  and the end-of-Build paragraph) and A5, A6 in `skills/st-inspect/SKILL.md` (Gate), and remove
  `Then run the same point once more on the changed input.` Keep every other row that
  `tests/test_on_demand.sh` asserts for these files. Owns: `skills/st-build/SKILL.md`,
  `skills/st-inspect/SKILL.md`. Test: `bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh && bash tests/test_verify.sh`.
  (FR-001 to FR-004, lessons L18, L39)
- [ ] T007 [P] [US1] Write S1 and S2 in `agents/st-build.md` (step 4, in place of `Then run the
  other tests that cover the files you touched.`) and `agents/st-debug.md` (step 5, in place of
  `then the other tests that cover the touched files.`), S3 in `skills/st/SKILL.md` (Always), S4
  in `agents/st-plan.md` (Rules), S5 in `procedures/tasks.md` (Checklist Format), S6 as step 7
  of `skills/st-sync/SKILL.md`. Owns: `agents/st-build.md`, `agents/st-debug.md`,
  `skills/st/SKILL.md`, `agents/st-plan.md`, `procedures/tasks.md`, `skills/st-sync/SKILL.md`.
  Test: `bash tests/test_test_scope.sh && bash tests/test_on_demand.sh && bash tests/test_design_lane.sh`.
  (FR-005, FR-006, FR-007)
- [ ] T008 [US1] README task 1 of 2. Add to the Tests block of `README.md` every test file that
  exists at the end of wave 3: `bash tests/test_lane_steps.sh`, `bash tests/test_advisor_waive.sh`,
  `bash tests/test_advisor_rules.sh`, `bash tests/test_test_scope.sh`, `bash tests/test_lock.sh`,
  `bash tests/test_lock_rules.sh`, `bash tests/test_codex_agent.sh`,
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

- [ ] T009 [P] [US2] Add to `tests/test_git_guard.py` (contracts/scripts.md section 6). Each
  command has a stray `'` (as in `it's`) on a line, so the whole command does not split: (a) a
  heredoc with no git word, then `grep -n here t.txt`: no decision; (b) the same with a last
  line `git status`, and one with `git log --oneline`: no decision; (c) with `git commit -m x`:
  `ask`, also with commit mode `auto` (folder unknown); (d) with `git push --force`: `ask` and
  `force push` in the reason; (e) with `git add -A`: `deny`; (f) a Python heredoc whose line is
  `subprocess.run(["git", "commit", "-m", "x"])` and whose comment line is `# it's a test`: `ask`
  with `The git guard could not read a git command on this line.`; (g) `echo "run git status"`
  with a stray-quote line: `ask`; (h) a heredoc line `hooks/st-git-guard.py it's`: no decision;
  (i) the existing `test_parse_error_asks` stays. Run it: red. Owns: `tests/test_git_guard.py`.
  Test: `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py`. (FR-008, lessons L1, L3)
- [ ] T010 [P] [US2] Write `tests/test_lock.sh` for `scripts/st-lock.sh` (contracts/scripts.md
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
- [ ] T011 [P] [US2] Write `tests/test_lock_rules.sh`: assert L1 in `agents/st-test.md`,
  `agents/st-build.md`, `agents/st-debug.md` and `skills/st-build/SKILL.md`, L2 in the three
  agents, L3 in `skills/st-build/SKILL.md`. Run it: red. Owns: `tests/test_lock_rules.sh`. Test:
  `bash tests/test_lock_rules.sh`. (FR-010, lessons L1)
- [ ] T012 [P] [US2] In `tests/test_st_worker.sh` case S1, assert the brief holds the whole B1
  line (`grep -qxF`). Run it: red. Owns: `tests/test_st_worker.sh`. Test:
  `bash tests/test_st_worker.sh`. (FR-010, lessons L37)

### Build

- [ ] T013 [P] [US2] Build the fallback in `hooks/st-git-guard.py` (contracts/scripts.md section
  6): move the segment loop body into a function that both the whole command and one line use.
  Then the negative control: `git show 6fe9d60:hooks/st-git-guard.py > <scratchpad>/old-guard.py`
  and run `ST_GIT_GUARD=<scratchpad>/old-guard.py PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py`
  right after a green run of the new guard: cases (a), (b) and (h) must fail on the old guard.
  Report each result. Owns: `hooks/st-git-guard.py`. Test:
  `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py`. (FR-008, lessons L2, L20, L25)
- [ ] T014 [P] [US2] Write `scripts/st-lock.sh` (contracts/scripts.md section 3, data-model
  section 4), with the `ponytail:` line for the two-waiter race (research R-D). Owns:
  `scripts/st-lock.sh`. Test: `bash tests/test_lock.sh`. (FR-009, lessons L29)
- [ ] T015 [P] [US2] Write L1 and L2 in `agents/st-test.md` (Steps), `agents/st-build.md` and
  `agents/st-debug.md` (Steps), and L1 and L3 in `skills/st-build/SKILL.md` (Per task). Owns:
  `agents/st-test.md`, `agents/st-build.md`, `agents/st-debug.md`, `skills/st-build/SKILL.md`.
  Test: `bash tests/test_lock_rules.sh && bash tests/test_test_scope.sh && bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh`.
  (FR-010)
- [ ] T016 [P] [US2] Add B1 to the brief's Facts in `scripts/st-worker.sh` (after the Test
  command line) and the same line to section 3 of `specs/008-herdr-workers/contracts/script.md`.
  Owns: `scripts/st-worker.sh`, `specs/008-herdr-workers/contracts/script.md`. Test:
  `bash tests/test_st_worker.sh`. (FR-010, lessons L37)

**Checkpoint**: quickstart section 2 passes.

## Phase 5: User Story 3 - The right advisors for the risk (P2)

**Goal**: a risk level with the lane, the matrix in `st-advisor.sh`, Codex in a herdr tab, and
the High talk.

**Independent Test**: quickstart section 3 and 3L.

### Tests (write first, must fail)

- [ ] T018 [P] [US3] Write `tests/test_advisor_matrix.sh` (setup as T002, plus a
  `.stratum/state.json` with `risk`). In `tests/test_advisor.sh` add
  `unset HERDR_ENV HERDR_WORKSPACE_ID` at the top and change the expected `mode not set` lines at
  lines 315 and 379 to R18's message. Cases from contracts/scripts.md sections 1.3 to 1.5: (a)
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
  `HERDR_WORKSPACE_ID=ws<random>` and a stub `herdr` that answers `agent list` (empty),
  `tab create`, `agent start`, `agent prompt` (`done`) and `agent read` (plain text with the
  markers and an APPROVED answer, using the nonce it reads from the prompt file named in the
  prompt text): `plan` prints `APPROVED sha256 <h>`, the stub `codex` saw no `exec`, and the
  herdr log has `agent start st-codex-001 --kind codex`; (l) the no-file line is R18's message.
  Run it: red. Owns: `tests/test_advisor_matrix.sh`, `tests/test_advisor.sh`. Test:
  `bash tests/test_advisor_matrix.sh`. (FR-011, FR-012, FR-013, FR-014, FR-015, FR-016,
  lessons L14, L16, L17, L26, L31)
- [ ] T019 [P] [US3] Write `tests/test_codex_agent.sh` for `scripts/st-codex-agent.sh` with a
  stub `herdr` whose ids have a random part (lessons L26) and whose `agent read` prints plain
  text (lessons L31), from a temp project with `specs/010-demo/`. Cases from contracts/scripts.md
  section 2: (a) no agent: `tab create --workspace <ws> --cwd <pwd> --label Codex --no-focus`,
  then `agent start st-codex-010 --kind codex --pane <pane from the stub> --timeout 120000 -- -s read-only -a never --no-alt-screen`
  (TAB-split argv from the stub log); `-m m1 -c model_reasoning_effort="high"` come after
  `--no-alt-screen`; (b) `st-codex-010` in this workspace: no `tab create`, no `agent start`;
  (c) `st-codex-009` in this workspace: `tab close <its tab_id>` before the new start; (d)
  `st-codex-010` in another workspace: ignored, a new start here; (e) `agent_pane_busy` twice
  then ok: 3 start calls; busy every time: exactly 10 start calls, then `ERROR:` and exit 1
  (lessons L30); (f) `agent_not_ready`: the exact `ERROR: Codex waits for an answer at start in its Codex tab. Answer it there, then run the point again.`, exit 1;
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
- [ ] T020 [P] [US3] Write `tests/test_risk_rules.sh`: assert R1 to R18 in their files, the US3
  "Gone" lines, and the kept `mode both` line. In
  `tests/test_on_demand.sh` change row `#18 FR-010 modes` (the `(\`codex\`, \`both\` or \`off\`).`
  row) to R4, the README row of `#18 FR-010 no file` to R18, and `#18 FR-015 init`
  (``advisor mode `codex` (recommended``) to R15. Run it: red. Owns:
  `tests/test_risk_rules.sh`, `tests/test_on_demand.sh`. Test: `bash tests/test_risk_rules.sh`.
  (FR-011 to FR-016, lessons L1, L38)

### Build

- [ ] T021 [P] [US3] Write `scripts/st-codex-agent.sh` (contracts/scripts.md section 2). Owns:
  `scripts/st-codex-agent.sh`. Test: `bash tests/test_codex_agent.sh`. (FR-013, lessons L26,
  L30, L31, L33)
- [ ] T022 [P] [US3] Write R1 to R3 and R12 in `skills/st/SKILL.md` (R1 replaces the lane line,
  R12 joins the small-decision bullet); R4 to R11 and R13 in `skills/st-build/SKILL.md`
  (Advisor section: R4 replaces the mode line, R5 goes after the kept `mode both` line, the
  matrix table with the R6 row and the other three rows from contracts/scripts.md section 1.4
  replaces the "It runs at two points" sentence; R13 in Per story); R14 in `skills/st-fast/SKILL.md`; R15 in
  `skills/st-init/SKILL.md` step 11; R16 to R18 in the advisor part of `README.md`. Owns:
  `skills/st/SKILL.md`, `skills/st-build/SKILL.md`, `skills/st-fast/SKILL.md`,
  `skills/st-init/SKILL.md`, `README.md`. Test:
  `bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh && bash tests/test_design_lane.sh && bash tests/test_advisor_rules.sh && bash tests/test_lock_rules.sh && bash tests/test_test_scope.sh && bash tests/test_shortcuts.sh && bash tests/test_screen_rules.sh`.
  (FR-011 to FR-016, security note S1, S2)
- [ ] T023 [US3] In `scripts/st-advisor.sh` add mode `auto` (missing `mode` = `auto`), the risk
  read, the matrix and the `advisors:` line, Codex at `diff` with the checked hash, `decisions`,
  `round`, `talk`, the herdr path with `st-lock.sh` and `st-codex-agent.sh`, exit 75 as
  `BLOCKED: Codex agent busy with another review`, and the new no-file line (contracts/scripts.md
  sections 1.3 to 1.5). Depends on T021. Owns: `scripts/st-advisor.sh`. Test:
  `bash tests/test_advisor_matrix.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh`.
  (FR-012 to FR-016, security note S1, lessons L14, L16, L17)
- [ ] T024 [US3] Live run of quickstart section 3L in a scratch clone in herdr. Record in
  research.md R-H: the time, the lines read, whether the JSON parsed, the tab and agent names,
  and steps 2 to 4. A failure goes back to T021 or T023 with its first error line. Depends on
  T021 to T023. Owns: `specs/010-workflow-overhaul/research.md`. Test: the commands of
  quickstart section 3L. (FR-013, lessons L32)

**Checkpoint**: quickstart section 3 passes.

## Phase 6: User Story 4 - Autonomous build with workers (P2)

**Goal**: Build can use workers; workers get the full layout; autonomous mode routes permission
prompts through the hook; normal mode never answers them.

**Independent Test**: quickstart section 4 and 4L.

### Tests (write first, must fail)

- [ ] T026 [P] [US4] Write `tests/test_approve_hook.py` (unittest) for `hooks/st-approve.py`
  (contracts/scripts.md section 5). Run the hook by subprocess with JSON on stdin and `cwd` in a
  temp folder with `.stratum/approve/`. Cases: (a) no `.stratum/approve`: no output, exit 0,
  nothing written; (b) `.stratum/approve` is a symlink: no output; (c) Bash `bash tests/x.sh`:
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
  commit with `src/b.py` already staged (`git diff --cached`), `git -C ../x commit -m x`, and an
  own-files commit with `owns` missing or empty; (i) stdin that is not JSON: no output, exit 0; (j) `hooks/commands.json` has
  one `PermissionRequest` entry with command `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-approve.py"`
  and timeout 310; (k) the hook file has no `"deny"` text. Run it: red. Owns:
  `tests/test_approve_hook.py`. Test: `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_approve_hook.py`.
  (FR-019, D23, security notes S3, S4, lessons L3, L5)
- [ ] T027 [P] [US4] Extend `tests/test_st_worker.sh` (contracts/scripts.md section 4). Teach the
  stub `herdr` `tab rename`, `pane split`, `pane run` and `tab create` with random ids, and an
  `agent read` text taken from a file the case writes. Cases: (a) `start` makes, in this order
  after `worktree create` and before `agent start`: `tab rename <tab> Main`, `pane split <root pane> --direction right --cwd <wt> --no-focus`,
  `pane run <new pane> lazygit`, then for `Dev Servers` and `VM` a `tab create` and a
  `pane split` of its root pane, ids read from the stub log; the same calls carry `--machine`
  for a saved machine; (b) `start --autonomous` with no `.stratum/autonomous`, and with a file
  whose line is not `$CLAUDE_CODE_SESSION_ID`: `Autonomous build mode is off for this session.`,
  exit 1, no herdr call; with a match: `<wt>/.stratum/approve/` exists and `owns` lists the backticked paths of the task file's `Owns:`
  line, one per line (a task with no `Owns:` line: an empty `owns`); (c) `wait` on `blocked`
  with a `<rid>.req`: the lines `state\tapproval\t...`, `request\t<rid>`,
  `tab\tworkspace worker-t004, tab Main`, `input\tBash: {...}`, exit 6; a commit `.req` adds
  `branch\tworker-t004` and `staged\tsrc/a.py src/b.py`; with no `.req`: today's
  exit 4; (d) `approve <id> --request <rid> --record <file>`: writes `<rid>.ok`, appends one
  TAB-split record line, calls `agent wait worker-t004 --until working --timeout 5000` before it
  prints `approved\tworker-t004\t<rid>`; refused when autonomous mode is off, for `--request ../x`,
  and for a missing `.req`; (e) `pass`: writes `<rid>.user`, prints `passed\t...`; (f) `answer`
  when the pane text holds `Do you want to proceed?`, and when `agent read` fails: the exact
  refusal line, exit 1, no `send-keys` call; (g) `close` removes `.stratum/approve/`; (h) the
  brief's Team rule 1 is the whole B2 line. Update each existing case whose call order or count
  the layout changes, and name each one in the report. Run it: red. Owns:
  `tests/test_st_worker.sh`. Test: `bash tests/test_st_worker.sh`. (FR-017, FR-018, FR-019,
  FR-021, D23, lessons L26, L27, L34, L37)
- [ ] T028 [P] [US4] In `tests/test_statusline.sh` add: input with `"session_id":"S1"` and
  `.stratum/autonomous` holding `S1`: line 2 has ` autonomous `; the file holds `S2`: no
  `autonomous`; no file: no `autonomous`. Run it: red. Owns: `tests/test_statusline.sh`. Test:
  `bash tests/test_statusline.sh`. (FR-018)
- [ ] T029 [P] [US4] Write `tests/test_worker_rules.sh`: assert W1 to W16 in their files and the
  three "Gone" lines of the US4 table. In `tests/test_on_demand.sh` delete rows `#17 one-time yes`
  and `#17 FR-014 build`, and change the check `#17 FR-014 build skill` to: `/stratum:st-worker`
  appears in `skills/st-build/SKILL.md` on one line only, the W10 line. Run it: red. Owns:
  `tests/test_worker_rules.sh`, `tests/test_on_demand.sh`. Test: `bash tests/test_worker_rules.sh`.
  (FR-017, FR-018, FR-019, FR-020, FR-021, FR-022, lessons L1, L39)

### Build

- [ ] T030 [P] [US4] Write `hooks/st-approve.py` and add its `PermissionRequest` entry to
  `hooks/commands.json` (contracts/scripts.md section 5), with the `ponytail:` line for the text
  never list, and the D23 commit rules. Owns: `hooks/st-approve.py`, `hooks/commands.json`. Test:
  `PYTHONDONTWRITEBYTECODE=1 python3 tests/test_approve_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_phase_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_model_hook.py`.
  (FR-019, security notes S3, S4, S5, lessons L3, L5)
- [ ] T031 [P] [US4] In `scripts/st-worker.sh` add `start --autonomous` (with the `owns` file), the layout, the `wait`
  approval state, `approve`, `pass`, the `answer` refusal, the `close` cleanup and B2 (Team rule
  1); update the usage line; change rule 1 in section 3 of
  `specs/008-herdr-workers/contracts/script.md` to B2 (contracts/scripts.md section 4). Owns:
  `scripts/st-worker.sh`, `specs/008-herdr-workers/contracts/script.md`. Test:
  `bash tests/test_st_worker.sh`. (FR-017, FR-018, FR-019, FR-021, security notes S3, S5,
  lessons L26, L27, L30, L33, L34, L37)
- [ ] T032 [P] [US4] Add the `autonomous` segment to `statusline/st-statusline.sh`
  (contracts/scripts.md section 7). Owns: `statusline/st-statusline.sh`. Test:
  `bash tests/test_statusline.sh`. (FR-018)
- [ ] T033 [P] [US4] Write W1 to W7, W11, W14 and W16 in `skills/st-worker/SKILL.md` (step 6 and the
  last line; remove the three "Gone" lines), W8, W9 and W12 in `skills/st/SKILL.md` (Always), W10
  in `skills/st-build/SKILL.md` (Parallel tasks), W13 in `skills/st-herdr-workspace/SKILL.md`,
  and W15 in `README.md` (beside the worker section). Owns: `skills/st-worker/SKILL.md`,
  `skills/st/SKILL.md`, `skills/st-build/SKILL.md`, `skills/st-herdr-workspace/SKILL.md`,
  `README.md`. Test:
  `bash tests/test_worker_rules.sh && bash tests/test_on_demand.sh && bash tests/test_risk_rules.sh && bash tests/test_lock_rules.sh && bash tests/test_advisor_rules.sh && bash tests/test_test_scope.sh && bash tests/test_screen_rules.sh`.
  (FR-017 to FR-022, D23, security note S4)
- [ ] T034 [US4] Live run of quickstart section 4L on a scratch branch in herdr. Record each
  step's output in research.md R-H, including whether the hook answers after more than 120 s.
  If the hook from `hooks/commands.json` never fires (no `.req` while the dialog shows), the
  contingency is that `start --autonomous` passes `--settings <generated file>` with the same
  hook command to `agent start`; bring it to the user before building it. A failure goes back
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

- [ ] T036 [P] [US5] Write `tests/test_plan_rules.sh`: assert D1 to D10 and D18 in their files and
  the "Gone" lines for `agents/st-plan.md`, `procedures/tasks.md` and `templates/tasks.md`. Run
  it: red. Owns: `tests/test_plan_rules.sh`. Test: `bash tests/test_plan_rules.sh`. (FR-023,
  FR-026, lessons L1, L41)
- [ ] T037 [P] [US5] Write `tests/test_screen_rules.sh`: assert D11 to D17 and that `design brief`
  is gone from `agents/st-build.md` and ``merge it into `main` `` from `skills/st-build/SKILL.md`.
  Run it: red. Owns: `tests/test_screen_rules.sh`. Test: `bash tests/test_screen_rules.sh`.
  (FR-024, FR-025, FR-026, lessons L1, L11, L12, L40)

### Build

- [ ] T038 [P] [US5] Write D1 and D2 in `agents/st-plan.md` (Rules; D2 replaces
  `Mark tasks that touch no common file \`[P]\`.`), D3 to D5 in `procedures/tasks.md` (Format
  Components; D3 replaces the old `[P] marker` item), D6 to D8 and D18 in `templates/tasks.md`
  (Format list and Notes), D9 and D10 in `skills/st-plan/SKILL.md` (steps 3 and 2). Owns:
  `agents/st-plan.md`, `procedures/tasks.md`, `templates/tasks.md`, `skills/st-plan/SKILL.md`.
  Test: `bash tests/test_plan_rules.sh && bash tests/test_test_scope.sh && bash tests/test_on_demand.sh`.
  (FR-023, FR-026)
- [ ] T039 [P] [US5] Write D11 to D16 in `skills/st-build/SKILL.md` (D11 to D14 in Per task, D15
  and D16 in Parallel tasks; D16 replaces ``merge it into `main` ``) and D17 as step 5 of
  `agents/st-build.md`. Owns: `skills/st-build/SKILL.md`, `agents/st-build.md`. Test:
  `bash tests/test_screen_rules.sh && bash tests/test_advisor_rules.sh && bash tests/test_lock_rules.sh && bash tests/test_test_scope.sh`.
  (FR-024, FR-025, FR-026)

**Checkpoint**: quickstart section 5 passes.

## Phase 8: User Story 6 - Skill clean-up (P3)

**Goal**: triage first, no issue offer, no `st-frontend-design`.

**Independent Test**: quickstart section 6.

### Tests (write first, must fail)

- [ ] T041 [P] [US6] Write `tests/test_triage_rules.sh`: assert T1 to T4 and the US6 "Gone" lines
  (`Make GitHub issues from the tasks?` in no `skills/*/SKILL.md`), and that
  `Next phase: \`/stratum:st-inspect\`.` stays in `skills/st-plan/SKILL.md`. Run it: red. Owns:
  `tests/test_triage_rules.sh`. Test: `bash tests/test_triage_rules.sh`. (FR-028, FR-029,
  lessons L1, L12, L38)
- [ ] T042 [P] [US6] Write `tests/test_no_frontend_design.sh`:
  `grep -rn frontend-design <root> --exclude-dir=.git --exclude-dir=specs --exclude=test_no_frontend_design.sh`
  prints nothing; `skills/st-frontend-design/` and `licenses/frontend-design.Apache-2.0.txt` do
  not exist; `vendor.lock` is valid JSON with no `frontend-design` key; and the two-way README
  skill check of `tests/test_inspect.sh:111-114`, copied. Run it: red. Owns:
  `tests/test_no_frontend_design.sh`. Test: `bash tests/test_no_frontend_design.sh`. (FR-030,
  lessons L7)

### Build

- [ ] T043 [P] [US6] Write T1 at the start of section 1 of `skills/st/SKILL.md` and T2 in place of
  its issue rule (keep `Do not end a reply with an offer to file issues`), T3 as the description
  and remove the issue question from the Gate of `skills/st-plan/SKILL.md`, T4 as line 2 of
  `skills/st-full/SKILL.md`. Owns: `skills/st/SKILL.md`, `skills/st-plan/SKILL.md`,
  `skills/st-full/SKILL.md`. Test:
  `bash tests/test_triage_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_worker_rules.sh && bash tests/test_test_scope.sh && bash tests/test_plan_rules.sh && bash tests/test_design_lane.sh && bash tests/test_on_demand.sh`.
  (FR-028, FR-029)
- [ ] T044 [P] [US6] Remove `st-frontend-design`: delete `skills/st-frontend-design/` and
  `licenses/frontend-design.Apache-2.0.txt`; remove the `frontend-design` entry from
  `vendor.lock`, its row (line 15) and its name in line 23 of `THIRD_PARTY_NOTICES.md`, its name
  in `README.md` lines 115 and 340, and the `DESIGN.md` mentions at lines 44 and 103; change
  `DESIGN.md:171` to say the skill was removed in 010 (D6). Owns: `skills/st-frontend-design/`,
  `licenses/frontend-design.Apache-2.0.txt`, `vendor.lock`, `THIRD_PARTY_NOTICES.md`,
  `README.md`, `DESIGN.md`. Test: `bash tests/test_no_frontend_design.sh && bash tests/test_design_lane.sh`.
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
  file into it, and run each one there right after its green run here (lessons L25). Every new
  file and every new case must be red there. Record one line per file in research.md as "R-I
  negative controls". Remove nothing: tell the user the scratch worktree path. Owns:
  `specs/010-workflow-overhaul/research.md`. Test: the commands of T048, run in the old
  worktree. (FR-031, lessons L2, L20, L25)
- [ ] T048 Scoped regression of every test file this feature adds or whose files it changes, one
  command at a time:
  `bash tests/test_lane_steps.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh && bash tests/test_advisor_rules.sh && bash tests/test_test_scope.sh && bash tests/test_lock.sh && bash tests/test_lock_rules.sh && bash tests/test_advisor_matrix.sh && bash tests/test_codex_agent.sh && bash tests/test_risk_rules.sh && bash tests/test_st_worker.sh && bash tests/test_statusline.sh && bash tests/test_worker_rules.sh && bash tests/test_plan_rules.sh && bash tests/test_screen_rules.sh && bash tests/test_triage_rules.sh && bash tests/test_no_frontend_design.sh && bash tests/test_on_demand.sh && bash tests/test_design_lane.sh && bash tests/test_inspect.sh && bash tests/test_verify.sh && bash tests/test_shortcuts.sh && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_git_guard.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_approve_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_phase_hook.py && PYTHONDONTWRITEBYTECODE=1 python3 tests/test_model_hook.py`.
  Not in the list because no file they check changes: `test_design_check.sh`,
  `test_herdr_workspace.sh`, `test_model_files.sh`, `test_pr_skill.sh`, `test_session_hooks.sh`,
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
| 1 | T001, T002, T003, T004, T009, T010, T011, T012, T019, T026, T028, T036, T037, T041, T042 | nothing: each writes its own test file (T003 also `tests/test_on_demand.sh`) |
| 2 | T005, T006, T007, T013, T014, T016, T021, T030, T032, T044 | the wave 1 test of each |
| 3 | T015, T018, T027, T038, then T008 last | T015: T006, T007 (shared `skills/st-build/SKILL.md`, agents). T018: T005 (`tests/test_advisor.sh` is T005's Test). T027: T016 (`tests/test_st_worker.sh`). T038: T007 (`agents/st-plan.md`, `procedures/tasks.md`). T008: T044 (`README.md`) and every test file it lists, so after T018 |
| 4 | T020, T023, T031, T039 | T020: T003, T006, T007, T015 (their Tests read `tests/test_on_demand.sh`). T023: T018, T021, T014. T031: T027. T039: T015 |
| 5 | T022, T024 | T022: T020, T039, T008 (`skills/st-build/SKILL.md`, `skills/st/SKILL.md`, `README.md`). T024: T023 |
| 6 | T029, T034 | T029: T022 (its Test reads `tests/test_on_demand.sh`). T034: T030, T031, T032, T024 (`research.md`) |
| 7 | T033 | T029, T022 |
| 8 | T043 | T033 (`skills/st/SKILL.md`), T038 (`skills/st-plan/SKILL.md`) |
| 9 | T046 | T043, T033, T022 (`README.md`), every story task (T001's rows) |
| 10 | T047 and T048, then T049 | T046, T034; T049 after T047 (`research.md`) |

- US1 MVP checkpoint: end of wave 3 (T002 to T008 done, quickstart section 1 passes).
- The code tasks run early, beside US1: git guard (T009, T013), lock (T010, T014), Codex adapter
  (T019, T021), approval hook (T026, T030), status line (T028, T032), the brief line (T012, T016),
  and the `st-frontend-design` removal (T042, T044).
- The text tasks form one chain, because they share `skills/st-build/SKILL.md`,
  `skills/st/SKILL.md`, `tests/test_on_demand.sh` and `README.md`: T006 and T007, then T015 and
  T038, then T039, then T022, then T033, then T043.
- A Test that reads a file another task of the same wave writes can see it half done. Run that
  Test again at the end of the wave before a red result counts.
- README tasks: two. T008 lists every test file that exists at the end of wave 3, T046 the two
  made later (`tests/test_risk_rules.sh` in wave 4, `tests/test_worker_rules.sh` in wave 6). Only
  T008, T046 and T048 run `tests/test_inspect.sh`, so it is green at each of them.

## Parallel example: wave 2

```text
T005 (st-advisor.sh), T006 (st-build, st-inspect skills), T007 (6 agent and skill files),
T013 (git guard), T014 (st-lock.sh), T016 (st-worker.sh, 008 contract), T021 (st-codex-agent.sh),
T030 (st-approve.py, commands.json), T032 (statusline), T044 (st-frontend-design removal, README, DESIGN, vendor.lock, notices)
```

## Implementation strategy

1. MVP: waves 1 to 3. US1 is done at the end of wave 3, and the US2 code (guard, lock) is done
   beside it.
2. Waves 4 to 8 finish the other stories. Run each story's quickstart section when its last
   task is done.
3. Waves 9 and 10 last.

## Counts

44 tasks: Setup 1, US1 7, US2 8, US3 7, US4 9, US5 4, US6 4, Polish 4. Live-run tasks: T024,
T034.
