---
description: "Tasks for 018-autonomous-sessions"
---

# Tasks: Autonomous build mode in more than one session at the same time

**Input**: `specs/018-autonomous-sessions/` (plan.md, spec.md, research.md, data-model.md, contracts/autonomous-mode.md, quickstart.md)

**Tests**: required. Each FR gets a test task, in the phase before the task that builds it. A test task's test must fail before its build task and pass after.

**Organization**: each user story has a test phase and a build phase, so the tasks inside one phase can run at the same time.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

## Rules for every task

- Work only in temp folders in tests (`mktemp -d`, `tempfile.TemporaryDirectory`). Never touch the `.stratum/autonomous` of any real checkout.
- This build runs in a worker worktree. Lock 2 denies a Bash call whose text names the mode folder or the approve folder by path. Do not grep or ls those paths in Bash. Run the test files only.
- Change an existing test only where it builds or checks the old single-file flag (FR-013). Keep every other assertion.
- Rules to quote: session id "matches `^[A-Za-z0-9-]+$`"; mode folder "Must be a directory and not a symlink"; mode entry "Content: empty", "a regular file and not a symlink" (data-model.md, contract C1).
- No comments that narrate the change.

---

## Phase 1: User Story 1 tests (two sessions on at the same time)

**Goal**: failing tests for reader rule C1, the turn-on step C2 and the two-session cases.

**Independent Test**: in two linked worktrees of one temp repo, sessions S1 and S2 are both on. The statusline shows `autonomous` for each, and a worker prompt of each goes to its own orchestrator.

- [ ] T001 [P] [US1] In `tests/test_statusline.sh` (lines 102-124), move the autonomous cases to the entry layout: make the folder `.stratum/autonomous/` with an empty entry named for the session, in place of a file that holds the id. Keep each case's meaning: own entry gives the segment; only another session's entry gives none; no folder gives none; empty folder with no `session_id` gives none; a linked worktree's own folder is ignored and the main checkout's folder decides. Add these cases (FR-004, FR-005, FR-006, FR-008, FR-012): (a) `$tmp/repo` plus a second linked worktree `$tmp/wt2`, entries S1 and S2 in the main checkout, `session_id` S1 from `$tmp/wt` and S2 from `$tmp/wt2`: both show ` autonomous ` on line 2; (b) S3 with no entry: no segment; (c) an old single file in place of the folder that holds `S1`: no segment for S1; (d) the folder is a symlink to a folder with an S1 entry: no segment; (e) the S1 entry is a symlink to a file: no segment; (f) `session_id` `../x` with a regular file `.stratum/x` in the main checkout, while the mode folder is a real directory with another entry (S2), so the id rule alone decides: no segment. Every "no segment" case also checks that the script exits 0 and that line 2 is present, so a crash cannot pass. Owns: `tests/test_statusline.sh`. Test: bash tests/test_statusline.sh.
- [ ] T002 [P] [US1] In `tests/test_approve_hook.py`, move `setUp` and tests `test_a1` to `test_a5` from the file that holds `S1` to an empty entry `S1` in the folder `<main>/.stratum/autonomous/`. Add these tests (FR-004, FR-005, FR-006, FR-008, FR-012, US2 scenario 1): (a) two linked worktrees of the main repo, one with `approve/session` S1 and one with S2, entries S1 and S2: a Bash PermissionRequest from each is sent (a `.req` file appears in its own approve folder); (b) remove entry S1: the S1 worker is silent and the S2 worker is still sent; (c) a worker with `approve/session` S3 and no S3 entry: silent; (d) an old single file that holds `S1` in place of the folder: silent; (e) the folder is a symlink to a folder with an S1 entry: silent; (f) the S1 entry is a symlink: silent; (g) `approve/session` holds `../x` and a regular file `.stratum/x` exists in the main checkout, while the mode folder is a real directory with another entry (S2), so the id rule alone decides: silent. Owns: `tests/test_approve_hook.py`. Test: python3 tests/test_approve_hook.py.
- [ ] T003 [P] [US1] In `tests/test_st_worker.sh`, move the helpers `autoset` and `autoclr` (line 1153) to the entry layout: `autoset <id>` makes the folder `$repo/.stratum/autonomous/` and an empty entry `<id>`, and `autoclr` removes the whole folder or file with `rm -rf`. Move the other direct writes of the old file to the entry layout: `$wk` (line 1200), `repo-feat2` (line 1220), the saved-machine repo files in AO1-AO6 and AM1-AM5. Change the checks to contract C1, C2 and C3: B1-B3 keep the line `Autonomous build mode is off for this session.`; AM1 checks that the entry `$rrepo/.stratum/autonomous/$sid` exists and keeps the single-ssh-call and order checks; AM3 starts from an old single file in `$rrepo` and checks it became the folder with the `$sid` entry; AM5 uses a symlinked entry; AO2 and AO5 now expect `autonomous off skipped<TAB><m><TAB>not on for this session`, with the other session's entry kept. Add cases: ON1 `autonomous-on` from `$repo` makes the empty entry and prints `autonomous on<TAB>local`, exit 0; ON2 from the linked worktree `repo-feat2` it makes the entry in the main checkout, not in the worktree; ON3 with entry `other-session` present it keeps that entry; ON4 an old single file is replaced by the folder; ON5 an empty id, and the id `../x`, print `cannot turn on autonomous mode: session id must be letters, digits or -`, exit 1, and make no file (check that `$repo/.stratum/x` does not exist); ON6 a symlinked folder and a symlinked entry each print the `is a symlink` line, exit 1, and leave the target unchanged; ON7 `autonomous-on` with an argument prints usage, exit 2; WT5 `autonomous-on` from `$wk` and from `repo-w9` prints the worker-worktree line, exit 1 (in the existing WT loop); ON8 two `autonomous-on` runs for ids `sA` and `sB` started in the background at the same time over an old single file: both exit 0 and both entries exist. Off cases (US2 scenarios 1, 2 and 5, FR-003): OF1 with entries `$sid` and `other-session` here and on the saved machine, `autonomous-off --roster` removes only the `$sid` entries and prints `autonomous off<TAB>local` and `autonomous off<TAB>laptop`; OF2 an empty id, and `../x`, print `Autonomous build mode is off for this session.`, exit 1, remove nothing and make no ssh call, and a bait file `$repo/.stratum/x` still exists after the `../x` run; OF3 a symlinked folder prints `autonomous off failed<TAB>local<TAB><path> is a symlink`, exit 1; OF3b a symlinked local entry prints the `failed ... is a symlink` line, exit 1, and the symlink target is kept; OF3c on the saved machine, a symlinked folder and, in a second run, a symlinked entry each print `autonomous off failed<TAB>laptop<TAB>...`, exit 1, and the target is kept; OF4 `autonomous-off` for `sA` and `sB` at the same time removes both and only those; OF5 an old single-file flag in place of the folder prints `autonomous off skipped<TAB>local<TAB>not on for this session`, exit 0, and the file is kept; ON9 `autonomous-on` run from a temp folder outside any git repo prints `cannot turn on autonomous mode: not in a git repo`, exit 1. Two sessions (FR-012): LW5 from `repo-feat2` with session `$sid` and from a second linked worktree `repo-feat3` with session `sid2`, both entries set: `start --autonomous` exits 0 in each, and `approve` from S1 on S2's worker prints `Worker worker-<id> is not in this autonomous run.`; LW4 checks that only the `$sid` entry is removed. Owns: `tests/test_st_worker.sh`. Test: bash tests/test_st_worker.sh.
- [ ] T004 [P] [US1] In `tests/test_worker_rules.sh`, replace the phrase of row W8 with: ``Autonomous build mode turns on only when the user says so in their own words for this run ("build with workers, autonomous", "autonomous mode"). Then run `bash <plugin root>/scripts/st-worker.sh autonomous-on`, show its line word for word, and say `Autonomous build mode: on for this run`. It makes only this session's entry in the main checkout, also from a linked worktree, and leaves the entries of other sessions alone.`` In the phrase of row W15, replace ``(the main checkout's `.stratum/autonomous` and the worker's session file must match)`` with ``(the main checkout's `.stratum/autonomous/` folder holds an entry named with the session id in the worker's session file)``. Add a gone row G11 for `skills/st/SKILL.md` with the phrase `printf '%s\n' "$CLAUDE_CODE_SESSION_ID" >`. Keep G4 and F2. Owns: `tests/test_worker_rules.sh`. Test: bash tests/test_worker_rules.sh.

**Checkpoint**: T001-T004 each fail on the current code.

---

## Phase 2: User Story 1 build

- [ ] T005 [P] [US1] In `statusline/st-statusline.sh` (lines 52-57), apply contract C1 with `S` = `data.get("session_id")`: `S` "matches `^[A-Za-z0-9-]+$`" (`re.fullmatch`), the folder (main checkout of `cwd`, else `proj`, as today) is a directory and not a symlink, and `<folder>/<S>` is a regular file and not a symlink. Do not read the file content. Owns: `statusline/st-statusline.sh`. Test: bash tests/test_statusline.sh.
- [ ] T006 [P] [US1] In `hooks/st-approve.py` `request()` (lines 253-258), apply contract C1 with `S` = first line of `<worker root>/.stratum/approve/session`: check `S` with `re.fullmatch(r"[A-Za-z0-9-]+", S)` before you join it to the folder `<dirname(common)>/.stratum/autonomous`, then folder `isdir` and not `islink`, entry `isfile` and not `islink`. Leave `lock2`, `locked_path` and `RISKY` for T016. Owns: `hooks/st-approve.py`. Test: python3 tests/test_approve_hook.py.
- [ ] T007 [P] [US1] In `scripts/st-worker.sh`: (1) line 68: contract C1 in bash with `D=$MAIN/.stratum/autonomous`: `[[ $SID =~ ^[A-Za-z0-9-]+$ ]] && [ -d "$D" ] && [ ! -L "$D" ] && [ -f "$D/$SID" ] && [ ! -L "$D/$SID" ]`, else the existing off line; (2) new subcommand `autonomous-on` per contract C2: add it to the usage line, to the no-id case at line 9, to the skips at lines 58 and 108, and to the line-62 block (worker-worktree refusal), skipping the on-check like `autonomous-off`; it takes no option; steps 1-5 of C2 with the exact lines of the C2 table, and on success `printf 'autonomous on\t%s\n' local`; (3) the saved-machine write at line 277: C2 steps in the same one `sshq` call, making `$Q/.stratum/autonomous/<id>` empty, with the same `cannot write .stratum/autonomous on $m:` error line, before `worktree add`; (4) `autonomous-off` (lines 690-732) per contract C3: first check the id (else the off line, exit 1, no ssh); per machine remove only `<folder>/<SID>` here and in the one `sshq` call; lines `autonomous off`, `autonomous off skipped<TAB><m><TAB>not on for this session`, `autonomous off failed<TAB><m><TAB><reason>`; drop the `flag held by` line. Use the full entry path in every `rm` and `: >`, so an id that starts with `-` is never an option. In both the local `autonomous-on` and the saved-machine write, remove an old flag (C2 step 3) only with a non-recursive `rm -f -- "<folder>"` on the exact path, with no trailing slash and no recursive option, and ignore a failed remove before step 4. Owns: `scripts/st-worker.sh`. Test: bash tests/test_st_worker.sh.
- [ ] T008 [P] [US1] In `skills/st/SKILL.md` line 89, replace the sentence with the exact W8 phrase from T004. `tests/test_worker_rules.sh` passes only when every build task of this phase is done (it also checks T009's W15 row); this task's other test files must pass alone. Owns: `skills/st/SKILL.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_design_lane.sh && bash tests/test_verify.sh && bash tests/test_risk_rules.sh && bash tests/test_state.sh && bash tests/test_lane_steps.sh && bash tests/test_triage_rules.sh && bash tests/test_on_demand.sh && bash tests/test_inspect.sh && bash tests/test_test_scope.sh && bash tests/test_harness_model.sh coverage missing.
- [ ] T009 [P] [US1] In `README.md` line 293, replace the parenthesis named in T004 with the new one from T004. `tests/test_worker_rules.sh` passes only when every build task of this phase is done (it also checks T008's W8 and G11 rows); this task's other test files must pass alone. Owns: `README.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_advisor_rules.sh && bash tests/test_inspect.sh && bash tests/test_lane_steps.sh && bash tests/test_risk_rules.sh && bash tests/test_no_frontend_design.sh && bash tests/test_update_rules.sh && bash tests/test_on_demand.sh && bash tests/test_triage_rules.sh && python3 tests/test_model_hook.py && python3 tests/test_phase_hook.py && bash tests/test_harness_model.sh readme.

**Checkpoint**: US1 works. Each session turns on and off only its own entry, and every reader uses C1.

---

## Phase 3: User Story 2 tests (each session turns only its own mode off)

**Goal**: failing tests for the skill triggers (FR-009, FR-010, FR-011). The script's off cases are in T003, because `tests/test_st_worker.sh` shares its helpers with the on cases.

**Independent Test**: with S1 and S2 on, `autonomous-off` in S1 leaves S2 on, here and on a saved machine (T003 OF1, OF4), and the skills turn the mode off at the end of a run, on "stop autonomous" and before a "continue later" handoff.

- [ ] T010 [P] [US2] In `tests/test_worker_rules.sh`, replace the phrase of row W9 with: ``It ends when the Build or worker run ends, when the user says "stop autonomous", or when the user says they will continue some other time (before the handoff): run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` if workers ran, else `bash <plugin root>/scripts/st-worker.sh autonomous-off`. It removes only this session's entry. Show its lines word for word, and say `Autonomous build mode: off`. A new session never starts in it.`` Replace the phrase of row W17 with: ``For a worker on a saved machine, write its repo path as a fifth roster field. On a saved machine, `start --autonomous` also makes this session's entry in that machine's main checkout; at the end of the run or on "stop autonomous", run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` and show its lines word for word.`` Add row W34 for `skills/st/SKILL.md`: ``When the user says they are done or will continue some other time, run `/stratum:st-handoff`.`` Add row W35 for `skills/st-handoff/SKILL.md`: ``The user said they are done or will continue some other time, and autonomous build mode is on for this session: before you write, run `bash <plugin root>/scripts/st-worker.sh autonomous-off --roster <roster file>` if workers ran, else `bash <plugin root>/scripts/st-worker.sh autonomous-off`. Show its lines word for word and say `Autonomous build mode: off`.`` Owns: `tests/test_worker_rules.sh`. Test: bash tests/test_worker_rules.sh.

---

## Phase 4: User Story 2 build

- [ ] T011 [P] [US2] In `skills/st/SKILL.md`, replace the line-90 sentence with the W9 phrase from T010, and line 93 with the W34 phrase. `tests/test_worker_rules.sh` passes only when every build task of this phase is done (it also checks T012's W35 and T013's W17 rows); this task's other test files must pass alone. Owns: `skills/st/SKILL.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_design_lane.sh && bash tests/test_verify.sh && bash tests/test_risk_rules.sh && bash tests/test_state.sh && bash tests/test_lane_steps.sh && bash tests/test_triage_rules.sh && bash tests/test_on_demand.sh && bash tests/test_inspect.sh && bash tests/test_test_scope.sh && bash tests/test_harness_model.sh coverage missing.
- [ ] T012 [P] [US2] In `skills/st-handoff/SKILL.md`, under "Where it runs", add the W35 phrase from T010 as a new bullet right after the bullet that starts "The user said they are done or is ending the session". Leave every other bullet word for word (rows FR-009 in `tests/test_on_demand.sh`). `tests/test_worker_rules.sh` passes only when every build task of this phase is done (it also checks T011's W9 and W34 and T013's W17 rows); this task's other test files must pass alone. Owns: `skills/st-handoff/SKILL.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_on_demand.sh && bash tests/test_harness_model.sh coverage missing.
- [ ] T013 [P] [US2] In `skills/st-worker/SKILL.md` line 43, replace the sentence with the W17 phrase from T010 (FR-011). `tests/test_worker_rules.sh` passes only when every build task of this phase is done (it also checks T011's W9 and W34 and T012's W35 rows); this task's other test files must pass alone. Owns: `skills/st-worker/SKILL.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_on_demand.sh && bash tests/test_state.sh && bash tests/test_harness_model.sh coverage missing.

**Checkpoint**: US1 and US2 work.

---

## Phase 5: User Story 3 tests (workers still cannot turn the mode on)

**Goal**: failing tests for lock 2 on the folder and every entry (FR-007, contract C4).

**Independent Test**: in a worker worktree, every Bash and file-tool try on the folder or an entry, and `st-worker.sh autonomous-on` and `autonomous-off`, are denied.

- [ ] T014 [P] [US3] In `tests/test_approve_hook.py`: add to `LOCK2_BASH` `touch .stratum/autonomous/S9`, `rm -f .stratum/autonomous/S1`, `mkdir -p .stratum/autonomous` and `rm -rf .stratum/autonomous`; add `st-worker.sh autonomous-on` and `bash scripts/st-worker.sh autonomous-on` to `LOCK2_WORKER_CALLS`; in `test_worker_denies_file_tools_on_approve_and_autonomous`, add the targets `<wt>/.stratum/autonomous/S1` and `<wt>/.stratum/./autonomous/S1` (Edit, Write, MultiEdit, NotebookEdit), the cases `Read` of `<wt>/.stratum/autonomous/S1`, `Glob` with pattern `.stratum/autonomous/*`, and `Grep` with path `<wt>/.stratum/autonomous`. In `test_orchestrator_session_is_silent`, add that `touch .stratum/autonomous/S1` from a non-worker repo stays silent. Owns: `tests/test_approve_hook.py`. Test: python3 tests/test_approve_hook.py.
- [ ] T015 [P] [US3] In `tests/test_worker_rules.sh`, in the phrase of row W5, replace ``with `approve`, `pass`, `autonomous-off`,`` with ``with `approve`, `pass`, `autonomous-on`, `autonomous-off`,``. Owns: `tests/test_worker_rules.sh`. Test: bash tests/test_worker_rules.sh.

---

## Phase 6: User Story 3 build

- [ ] T016 [P] [US3] In `hooks/st-approve.py`, change `locked_path` (line 91) to `return "/.stratum/approve/" in p + "/" or "/.stratum/autonomous/" in p + "/"`, and add `"autonomous-on"` to `RISKY` (line 16). Leave the Bash substring check at line 100 and `REASON` as they are. Owns: `hooks/st-approve.py`. Test: python3 tests/test_approve_hook.py.
- [ ] T017 [P] [US3] In `skills/st-worker/SKILL.md` line 34, make the same insert as T015 (`autonomous-on` before `autonomous-off` in the never list). Owns: `skills/st-worker/SKILL.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_on_demand.sh && bash tests/test_state.sh && bash tests/test_harness_model.sh coverage missing.

**Checkpoint**: all three stories work.

---

## Phase 6b: D21 fixes, tests (FR-014, FR-015)

**Goal**: failing tests for the "Ready to submit your answers?" screen and the new step-6 wording.

**Independent Test**: `answer T004 --keys 1` on that screen while herdr says `done` sends `1`, and the worker skill has the FR-015 sentence.

- [ ] T021 [P] In `tests/test_st_worker.sh`, next to the AQ cases (around line 722), add a helper `reviewpane` that prints the AskUserQuestion review screen: ` Review your answers`, ` ● Which folder holds the brief.md? → Newest brief.md folder`, an empty line, `Ready to submit your answers?`, an empty line, `❯ 1. Submit answers`, `  2. Cancel` (no `Enter to select` line). Add: AQ6 `mk; states done working; reviewpane > "$tmp/pane.txt"`, `answer T004 --keys 1`: exit 0 and `agent<TAB>send-keys<TAB>worker-t004<TAB>1` sent once; AQ7 state `done` with a pane of plain output and no question (no `Enter to select`, no `Ready to submit your answers?`), `answer T004 --keys 1`: exit 1, `not blocked: done`, no send-keys; AQ8 the review screen with a permission line `Do you want to proceed?` above it still gives `not blocked: done` and nothing sent. Use the existing herdr stub, `states`, `run`, `hascall` and `cnt` helpers. Owns: `tests/test_st_worker.sh`. Test: bash tests/test_st_worker.sh.
- [ ] T022 [P] In `tests/test_worker_rules.sh`: in the phrase of row W1 and in row W28, replace `The dialog must show the whole command or path. Else send no key and tell the user.` with `Approve a one-time yes only when what the dialog shows is safe and any part it cuts off can only be inside the worker's own worktree or its scratchpad. Else send no key and tell the user.` Add the gone row G12 for `skills/st-worker/SKILL.md` with the phrase `The dialog must show the whole command or path.` Keep W5 (the never list) and O1 (`Never approve a push` once) as they are. Owns: `tests/test_worker_rules.sh`. Test: bash tests/test_worker_rules.sh.

---

## Phase 6c: D21 fixes, build

- [ ] T023 [P] In `scripts/st-worker.sh` `question()` (line 172), keep `readpane && ! grep -qaE "$PERM" "$t"` first, and match `Enter to select` or `Ready to submit your answers?` after it (one `grep -qaE` with both, or two greps joined by `||` inside braces). Change nothing in `answer`, `perm()` or `PERM`. Owns: `scripts/st-worker.sh`. Test: bash tests/test_st_worker.sh.
- [ ] T024 [P] In `skills/st-worker/SKILL.md` step 6 (line 28), replace `The dialog must show the whole command or path. Else send no key and tell the user.` with the exact new sentence from T022. Leave the never list (line 34) as it is. Owns: `skills/st-worker/SKILL.md`. Test: bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_on_demand.sh && bash tests/test_state.sh && bash tests/test_harness_model.sh coverage missing.

---

## Phase 7: Polish (harness docs and the quickstart run)

- [ ] T018 [P] In `docs/harness/model/data.c4`, set the `stratum.autonomous` summary to `One empty entry per session in this folder of the main checkout, named with the session id. st-worker.sh makes and removes it, st-worker.sh, st-approve.py and the statusline read it.` (one or two sentences, at most 200 characters). In `docs/harness/model/hooks.c4` line 46, change "the autonomous flag" to "the autonomous folder". Change no relationship label (D2 = A). In `DESIGN.md` line 194, change "Only the main checkout holds the flag" to "Only the main checkout holds the mode folder, one entry per session" and keep the row's table format (`tests/test_local_files.sh` reads it). Owns: `docs/harness/model/data.c4`, `docs/harness/model/hooks.c4`, `DESIGN.md`. Test: bash tests/test_harness_model.sh coverage missing summaries links validate rebuild && bash tests/test_local_files.sh && bash tests/test_design_lane.sh && bash tests/test_inspect.sh && bash tests/test_screen_rules.sh && bash tests/test_on_demand.sh && bash tests/test_triage_rules.sh && python3 tests/test_model_hook.py.
- [ ] T019 [P] In `docs/harness/atlas/data.mjs`, node `S` `how`, change `<code>autonomous</code>` to `<code>autonomous/</code>`. Then rebuild `docs/harness/atlas/atlas.html` and `docs/harness/atlas/SYSTEM.md` with the exact `META.buildCmd` from `data.mjs` line 6, run from the repo root. Owns: `docs/harness/atlas/data.mjs`, `docs/harness/atlas/atlas.html`, `docs/harness/atlas/SYSTEM.md`. Test: bash tests/test_harness_model.sh atlas nomcp readme.
- [ ] T020 Run the five checks of `quickstart.md` "Automated" one by one and fix only what this feature broke (needs T001-T019 and T021-T024). Test: bash tests/test_statusline.sh && python3 tests/test_approve_hook.py && bash tests/test_st_worker.sh && bash tests/test_worker_rules.sh && bash tests/test_harness_model.sh.

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 has no dependency. Each build phase needs its test phase. Phase 3 needs Phase 2, Phase 5 needs Phase 4, Phase 6b needs Phase 6 (T021 and T023 share `tests/test_st_worker.sh` and `scripts/st-worker.sh` with US1, T022 and T024 share `tests/test_worker_rules.sh` and `skills/st-worker/SKILL.md` with US2 and US3). Phase 6c needs Phase 6b. T020 needs Phase 6c.
- Inside each phase every task is `[P]`: no two own the same file and none needs another's result.

### User Story Dependencies

- No two stories are file-disjoint, so they run one after the other (US1, US2, US3):
  - US1 and US2 share `skills/st/SKILL.md`, `tests/test_worker_rules.sh`, and `scripts/st-worker.sh` with `tests/test_st_worker.sh` (the off cases are built in T003/T007).
  - US1 and US3 share `hooks/st-approve.py` and `tests/test_approve_hook.py`.
  - US2 and US3 share `skills/st-worker/SKILL.md` and `tests/test_worker_rules.sh`.
- Polish (T018, T019) shares no file with any story and can run at any time. T020 runs last.

### FR coverage (test task -> build task)

| FR | Test | Build |
|---|---|---|
| FR-001 | T003 ON1, ON2 | T007 |
| FR-002 | T003 ON3, ON8 | T007 |
| FR-003 | T003 AO1-AO6, OF1-OF5, ON9 | T007 |
| FR-004 | T001, T002, T003 B1-B3, AM1 | T005, T006, T007 |
| FR-005 | T001 (f), T002 (g), T003 ON5, OF2 | T005, T006, T007 |
| FR-006 | T001 (d)(e), T002 (e)(f), T003 ON6, OF3, OF3b, OF3c, AM4, AM5 | T005, T006, T007 |
| FR-007 | T014, T015, T003 WT4, WT5 | T016, T017, T007 |
| FR-008 | T001 (c), T002 (d), T003 ON4, ON8, OF5, AM3 | T005, T006, T007 |
| FR-009 | T004 (W8), T010 (W9, W34) | T008, T011 |
| FR-010 | T010 (W35) | T012 |
| FR-011 | T010 (W17), T015 (W5) | T013, T017 |
| FR-012 | T001 (a), T002 (a)(b), T003 LW5, OF1 | T005, T006, T007 |
| FR-013 | T020 | all |
| FR-014 | T021 AQ6-AQ8 | T023 |
| FR-015 | T022 (W1, W28, G12) | T024 |

### Parallel Opportunities

- Phase 1: T001, T002, T003, T004 at once. Phase 2: T005-T009 at once.
- Phase 4: T011, T012, T013. Phase 5: T014, T015. Phase 6: T016, T017. Phase 6b: T021, T022. Phase 6c: T023, T024.
- T018 and T019 can run beside any phase.

---

## Parallel Example: User Story 1

```bash
Task: "T001 statusline entry cases in tests/test_statusline.sh"
Task: "T002 approve hook routing cases in tests/test_approve_hook.py"
Task: "T003 worker script on, off and two-session cases in tests/test_st_worker.sh"
Task: "T004 rows W8, W15, G11 in tests/test_worker_rules.sh"
```

---

## Implementation Strategy

1. MVP: Phases 1-2 (US1). This fixes #77 for the readers and adds `autonomous-on` and the per-session `autonomous-off`.
2. Phases 3-4 (US2): the skills turn the mode off at the right times.
3. Phases 5-6 (US3): lock 2 covers every entry.
4. Phase 7: harness docs and the quickstart run. The orchestrator runs the full suite.

## Notes

- `[P]` tasks share no file in their phase and need no other task's result. Each names its files under `Owns:`.
- No `[lock]` and no `[screen]` tasks.
- `skills/st-build/SKILL.md`, `docs/harness/model/scripts.c4` and `docs/harness/README.md` do not change (plan.md).
