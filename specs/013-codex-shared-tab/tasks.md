---

description: "Task list for the shared Codex advisor tab"
---

# Tasks: Shared Codex advisor tab

**Input**: Design documents from `/specs/013-codex-shared-tab/`

**Prerequisites**: plan.md, spec.md, decisions.md, research.md, data-model.md, contracts/advisor-tab.md, quickstart.md

**Tests**: Required (D9). Each FR gets a case that can fail, written before the task that builds it. Case ids C1 to C23, M1 to M20 and skill lines K1 to K11 are in `contracts/advisor-tab.md` sections 4, 5 and 7. FR coverage is at the end.

**Tab name (D10)**: `st-codex-<workspace label>` by the rule in `contracts/advisor-tab.md` section 1. "The tab name" in a task means that rule's result.

**Rules for every task**: no comments in code except `ponytail:` markers. No new dependency, no `jq`. Tests use temp folders, `XDG_STATE_HOME` under the temp folder, and fake `herdr`, `codex`, `timeout` and `sleep` on PATH only. No task starts a real herdr tab or agent, runs the real `codex`, or reads or changes `~/.codex`. A guard task proves its negative control: break the guard, run the test, see the named case `FAIL`, then undo the break with the Edit tool, never `git checkout`.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

- **[P]**: Can run in parallel: no shared file in the phase and no other task's result; the task ends with `Owns:`
- **[lock]**: Test that cannot run at the same time as another; it runs through the test lock
- **[screen: <mode>]**: New screen; Build sends it to the Design lane in that mode
- **[Story]**: Which user story this task belongs to (US1 to US3)

No task is `[lock]`: every fixture lives under its own temp folder. No task is `[screen]`: the feature has no page or view.

---

## Phase 1: Setup

None. The repo has the layout already.

## Phase 2: Foundational

None. US1 changes the interface that US2 and US3 grow.

---

## Phase 3: User Story 1 - Use the Codex tab yourself (Priority: P1) MVP

**Goal**: one Codex tab per workspace, named from the workspace label, started with the user's own Codex setup, shared by every feature, never closed, never typed into while in use. The Stratum Codex home and `codex-home` are gone.

**Independent Test**: `bash tests/test_codex_agent.sh` cases C1 to C9 and `bash tests/test_advisor_matrix.sh` cases M1 to M5, M16 and M17 pass. Rule rows for K2, K6, K11 (US1 lines) pass.

### Tests for User Story 1

- [X] T001 [P] [US1] Rewrite `tests/test_codex_agent.sh` for the new interface `st-codex-agent.sh <tab name> <prompt file> <answer file> <state dir> [options]` (contract section 2): `go()` passes the fixed tab name `st-codex-t1` and `$tmp/state/stratum/codex-tabs` (the script takes the name as an argument; the name rule is tested in M16); every `st-codex-010-demo` literal in the cases kept becomes `st-codex-t1`. Fake `herdr`: add `agent get` (`{"result":{"agent":{"agent_status":"<status>"}}}` with the status from `$S/status`, default `idle`; `agent_not_found` error when `$S/gone` exists) and `agent wait`; every call is also appended to `$tmp/alllog`. Delete cases a0, a0b (Codex home), a, b, b2, d (C1, C2, C3, C9 replace them; b2 expects a `tab close` and d a start beside a live name), f to f9 (Folder access), f5 (login link), b1, b3, b4, c, c1, d2, d3 (ownership records) and k, k1 (name from the feature folder). Add C1 to C9 exactly as the contract table says; C9 runs twice, once with the `st-codex-t1` entry in another `workspace_id` and once in this workspace with another `cwd`. C3 expects the exact line `codex: the Codex tab runs with -m m1, advisor.json asks for -m m2. Close the tab to apply.`; C3b expects `<old>` = `unknown settings`; C8 checks `! grep -q '^tab close' "$tmp/alllog"` at the end of the file. Keep e, g, h, i, j; change h2 and h3 to expect no `tab close`. Red now: the script still reads a Codex home. Owns: `tests/test_codex_agent.sh`. Test: bash tests/test_codex_agent.sh.
- [X] T002 [P] [US1] Change `tests/test_advisor_matrix.sh`: delete k2 (:214-225), the `no Stratum Codex home is made` check and the whole `(n) codex-home` block (:252-288), k4 and k9 (:357-366), and k3 with its G5 line (:342-344: the Folder access screen and its error line go, C20 and C21 cover the start-up wait). In (k) drop the `--env CODEX_HOME=$home` assertion and expect zero `agent send-keys` lines; G5 expects `codex: tab <tab name>`. Every `st-codex-001-demo` literal in the file, the `hbin2/herdr` responses at :301-305 included, becomes the tab name. Fake `hbin2/herdr`: `agent list` returns the tab (the tab name, `workspace_id` `$ws`, `cwd` `$proj`, `tab_id` `w1:t2`, `agent_status` from `$FAKE_DIR/hstatus`) when `$FAKE_DIR/htab` exists, else `[]`; add `agent get`. Fake `hbin2/herdr` gains `workspace list`, returning `{"result":{"workspaces":[{"workspace_id":"<HERDR_WORKSPACE_ID>","label":"<label>"}]}}` with the label from `$FAKE_DIR/hlabel` (default `demo`), and `[]` when `$FAKE_DIR/hnows` exists; set `ws=wQ9` so the id fallback is `wq9`. `agent list` returns a second entry with the tab name, another `workspace_id` and `agent_status` `idle` when `$FAKE_DIR/helsewhere` exists. Add M1 to M5, M16 and M17 as the contract table says. M16 reads the name from the `agent start` line in `herdr.log` for each label. M17 sets `helsewhere` and no `htab`. M1 runs `st-advisor.sh codex-home` and expects the usage line, exit 2 and no `$tmp/state/stratum/codex-home`. M4 expects `codex exec` ran, no `agent prompt` in `herdr.log`, last line `codex: headless (Codex tab in use)`. M5 writes a record `w1:t2`, `-m`, `old` under `$tmp/state/stratum/codex-tabs/<tab name>` and expects the settings line in the output. Red now: `codex-home` still works. Owns: `tests/test_advisor_matrix.sh`. Test: bash tests/test_advisor_matrix.sh.
- [X] T003 [P] [US1] Rule rows. In `tests/test_risk_rules.sh`: replace R7 with the K2 line (from "Never run `codex` to build or fix. In herdr," to "Show it to the user."), R17 with the first line of K11, add R22 with the K6 line; move R19 and R20 to the gone table as G5 `skills/st-init/SKILL.md|st-advisor.sh codex-home`, G6 `skills/st-build/SKILL.md|st-advisor.sh codex-home`, G7 `README.md|st-advisor.sh codex-home`, and add G8 `README.md|marks the project untrusted`. In `tests/test_on_demand.sh:286` change the phrase to `Codex only reviews: it never builds or fixes.` and add a row for `Stratum no longer uses \`~/.local/state/stratum/codex-home\`. You may delete that folder. Close any old \`st-codex-<feature>\` Codex tab yourself: points no longer use or close it.` in `README.md`. Red now: the skill and README still have the old text. Owns: `tests/test_risk_rules.sh`, `tests/test_on_demand.sh`. Test: bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh.

### Implementation for User Story 1

- [X] T004 [US1] Change `scripts/st-codex-agent.sh` per contract section 2 steps 1 to 3 and the exit codes 0, 1, 2, 3 and 5: an entry with the tab name and another `workspace_id` or `cwd` prints `codex: tab name <tab name> in use elsewhere` and exits 5 before any `tab create`; usage line with the new arguments and the tab name check `^[a-z][a-z0-9_-]{0,31}$`; delete lines 7 to 9, 11 and 12 (name from the feature folder, Codex home checks) and keep `root=$(pwd -P)` (line 10); delete the ownership loop that closes tabs (:44-49), `quit()`, `screen()`, `nofolder`, the Folder access block (:64-75), the record write in `$home/agents` (:77) and the login link check (:91); `tab create` without `--env`; `agent start` with `-- --no-alt-screen "$@"`; write the settings record in `<state dir>/<tab name>` (umask 077, `mkdir -p`); on reuse print the FR-005 line on a difference; right before the prompt (contract step 5), `herdr agent get` `working` or `blocked`, or `agent_blocked` from the prompt, prints `codex: tab in use` and exits 3. Add `# ponytail: herdr cannot see text typed but not sent in the tab, a point may type after it; check the pane input if herdr exposes it` at the in-use check. Negative controls: put back a `herdr tab close` on a settings difference (C3 and C8 go red); drop the in-use exit (C4 goes red); drop the clash exit (C9 goes red). Test: bash tests/test_codex_agent.sh.
- [X] T005 [US1] Change `scripts/st-advisor.sh` per contract section 3: drop `|codex-home` from the usage line (:4), delete :5 to :26 and :198-199; compute the tab name in one function per contract section 1 (`herdr workspace list`, `label` of the entry whose `workspace_id` is `$HERDR_WORKSPACE_ID`, read with `python3 -I`; lowercase, `[^a-z0-9_-]` to `-`, first 23 characters; no letter or digit, a failed list or no entry: the workspace id the same way) and `tabs=${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-tabs`; call `st-codex-agent.sh "$name" "$tmp/prompt.tab" "$tmp/answer.json" "$tabs" "${opts[@]}"`; print each `codex: the Codex tab runs with ` line of `$tmp/tab`; rc 3 sets `via="codex: headless (Codex tab in use)"` and runs the headless call, and `[ $rc = 0 ] || via=...(Codex tab failed)` must not overwrite it. Negative controls: put back the `codex-home` branch (M1 goes red); map rc 3 to the failed line (M4 goes red); map rc 5 to the failed line (M17 goes red); skip the lowercase step (M16 `Stratum Main!` goes red); skip the id fallback (M16 `~` goes red). rc 5 sets `via="codex: headless (Codex tab name $name in use elsewhere)"` and runs the headless call. Test: bash tests/test_advisor_matrix.sh && bash tests/test_codex_agent.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh.
- [X] T006 [US1] Text. `skills/st-build/SKILL.md`: line 96 becomes K2, add K6 after the `WAIVED` line, delete line 97 and line 116. `skills/st-init/SKILL.md`: delete line 86. `README.md`: in line 203 change only "Codex runs in the read-only sandbox and only reviews: it never builds or fixes." to "Codex only reviews: it never builds or fixes."; lines 214-216 become K11 lines 1, 2, 5 and 6. Test: bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh.

**Checkpoint**: US1 works alone. A review in the tab still fails on a Codex prompt as today (h), still has the 480 s limit, and has no change check yet.

---

## Phase 4: User Story 2 - A review never changes files (Priority: P1)

**Goal**: a snapshot before and after each review turn in the tab. Any difference ends the point BLOCKED with the files named. Nothing is reverted. The skill says Codex only reviews.

**Independent Test**: `bash tests/test_codex_agent.sh` cases C10 to C16, `bash tests/test_advisor_matrix.sh` case M6 and the K2a and K7 rule rows pass.

### Tests for User Story 2

- [X] T007 [P] [US2] In `tests/test_codex_agent.sh`: a helper `repo()` that runs `rm -rf "$tmp/proj"`, makes it again with `specs/010-demo`, runs `git -C "$tmp/proj" init -q` and commits `a.txt` (`-c user.name=t -c user.email=t@t`, `GIT_CONFIG_GLOBAL=/dev/null` is set already); C10 to C16 call it after `new`. No `reset --hard` or `clean`. The fake `agent prompt` runs `$S/on_prompt` with `bash` in `$proj` when it exists. Add C10 to C16 as the contract table says. C10 expects `a.txt` still holds the new text after exit 4. C14 runs `git -C "$proj" commit` from `on_prompt` with a staged new file and expects `HEAD` named. C16 dirties `a.txt` before the run and expects exit 0. Red now: no snapshot. Owns: `tests/test_codex_agent.sh`. Test: bash tests/test_codex_agent.sh.
- [X] T008 [P] [US2] In `tests/test_advisor_matrix.sh`: fake `hbin2/herdr` mode `writes` makes `agent prompt` write `$proj/new.txt`. Add M6: first line `BLOCKED: Codex changed files during the review: new.txt`, a `| BLOCKED` record with `reason: Codex changed files during the review: new.txt` in `specs/001-demo/advisor.md`, no `$tmp/argv` (no `codex exec`), `new.txt` still there; remove `new.txt` after the case. Red now: exit 4 does not exist. Owns: `tests/test_advisor_matrix.sh`. Test: bash tests/test_advisor_matrix.sh.
- [X] T009 [P] [US2] In `tests/test_advisor_rules.sh` add rows A14 K2a in `skills/st-build/SKILL.md`, A15 K7 in `skills/st-build/SKILL.md`, A16 K11 line 4 in `README.md`. Red now: the lines are missing. Owns: `tests/test_advisor_rules.sh`. Test: bash tests/test_advisor_rules.sh.

### Implementation for User Story 2

- [X] T010 [US2] In `scripts/st-codex-agent.sh` add the snapshot (data-model.md "Review snapshot", research R6): one function with the pathspec excludes of research R6 (`.stratum/state.json`, Syncthing temp files); call it before the `herdr agent get` in-use check (contract step 4, so the check stays right before the prompt) and again right after the `agent prompt` call, before any other result handling; on a difference print `BLOCKED: Codex changed files during the review: <paths>` (sorted, each once, `HEAD` when HEAD moved) and exit 4. Add `# ponytail: a path with a newline breaks the snapshot lines, use -z through to the compare if one shows up`. Negative control: make the compare always pass (C10 goes red). Test: bash tests/test_codex_agent.sh.
- [X] T011 [US2] In `scripts/st-advisor.sh`: rc 4 calls `block` with the reason from the first `BLOCKED: ` line of `$tmp/tab`, before any headless call. Negative control: let rc 4 fall through to the headless call (M6 goes red). Test: bash tests/test_advisor_matrix.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh.
- [X] T012 [US2] Text. `skills/st-build/SKILL.md`: add K2a right before K2, and K7 right before the generic `BLOCKED: <reason>` line. `README.md`: add K11 line 4 after K11 line 2. Test: bash tests/test_advisor_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh.

**Checkpoint**: US1 and US2 work. A Codex prompt during a review still ends the tab run early (h).

---

## Phase 5: User Story 3 - The orchestrator answers Codex's prompts (Priority: P2)

**Goal**: the review waits on a prompt with no time limit (D11); `watch` reports a prompt with the screen while a review drives the tab; `answer` sends the one-time yes; the tab ending during a review is BLOCKED, never headless; the skill runs the point in the background with the watch first.

**Independent Test**: `bash tests/test_codex_agent.sh` cases C17 to C23, `bash tests/test_advisor_matrix.sh` cases M7 to M15, M18 and M19, and the K1, K3 to K5, K8, K9, K10, K11 line 3 rule rows pass. Then the live run (T019), which adds M20.

### Tests for User Story 3

- [ ] T013 [P] [US3] In `tests/test_codex_agent.sh`: change both g timeout checks into C17 (argv ends `--wait --until done --until idle`, no `--until blocked`, no `--timeout`); delete h, h2, h3 (the time-out paths go; C8 keeps the no-close check) and j (C23 replaces it); fake `agent prompt` copies `<state dir>/<tab name>.review` to `$S/marker_seen` and checks its pid with `kill -0`, writing `$S/marker_live`; it fails with the error code in `$S/prompt_err` when that file exists, and creates `$S/gone` first when `$S/prompt_gone` exists; fake `agent wait` logs its argv and fails with `agent_not_found` (creating `$S/gone`) when `$S/wait_gone` exists. Add C18 to C23 as the contract table says. C22 also checks the marker file is gone after every case, was never written in C4, and was written before `agent wait` in C20. Red now: the script still uses `--timeout` and `--until blocked`. Owns: `tests/test_codex_agent.sh`. Test: bash tests/test_codex_agent.sh.
- [ ] T014 [P] [US3] In `tests/test_advisor_matrix.sh`: save `realtimeout=$(command -v timeout)` before the fake `timeout` goes on PATH; a `$tmp/nosleep/sleep` stub for `watch`; fake `hbin2/herdr` gains `agent send-keys` logging, `agent get` from `$FAKE_DIR/hstatus`, and `agent read` of a fixed 3-line screen; a live marker is `sleep 120 &` with its pid written to `$tmp/state/stratum/codex-tabs/<tab name>.review`, killed after the case. The fake `timeout` in `$tmp/bin` also appends `$*` to `$FAKE_DIR/timeout.log`. Delete k6 (M19 replaces it) and k7 with its `t124` fake (the tab path has no `timeout` any more; M18 replaces it). Add M7 to M15, M18 and M19 as the contract table says, and assert the usage line names `answer|watch` (M11). M13: the fake `agent get` removes the marker after its 3rd call, so `watch` ends; expect the three lines once between `codex tab waits: <tab name>` and `codex tab waits: end`. M14 runs `"$realtimeout" 3 bash .../st-advisor.sh watch` with no marker and expects empty output. M15: mode `gone` makes `agent prompt` fail and `agent get` fail with `agent_not_found`; expect first line `BLOCKED: the Codex tab ended during the review`, the `record:` line, a BLOCKED record, no `$tmp/argv`. Red now: `answer` and `watch` print the usage line, and the tab path runs under `timeout`. Owns: `tests/test_advisor_matrix.sh`. Test: bash tests/test_advisor_matrix.sh.
- [ ] T015 [P] [US3] Rule rows. In `tests/test_advisor_rules.sh` add A17 K1, A18 K3, A19 K4, A20 K5, A21 K8 in `skills/st-build/SKILL.md`, A22 the K3 phrase `the key of the one-time yes only ("Yes, proceed", "Yes, just this once"). Never pick an option that says "don't ask again", "allow ... for this session", "in the future" or "for these files", or one that names a host.` in `skills/st-build/SKILL.md`, A23 the K4 phrase `run one command only, with no \`;\`, \`&&\`, \`||\`, \`|\`, \`$(\` or backticks` in `skills/st-build/SKILL.md`, A24 K11 line 3 in `README.md`, and gone rows G3 `skills/st-build/SKILL.md|No background run, no polling.`, G4 `skills/st-plan/SKILL.md|in the foreground, with a Bash timeout of 600000 ms`. In `tests/test_on_demand.sh` replace `#18 FR-002 wait build` with the K1 phrase from "Change no file in that folder until the point ends." to "handle the point's output.", `#18 FR-002 wait plan` with the first K9 line from "as \"Advisor\" in", and `#18 FR-016 readme` (line 285) with the K10 first sentence. Red now: the old lines are there. Owns: `tests/test_advisor_rules.sh`, `tests/test_on_demand.sh`. Test: bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh.

### Implementation for User Story 3

- [ ] T016 [US3] In `scripts/st-codex-agent.sh` per contract section 2 steps 3, 6, 7, 9 and 10 (D11): drop `SECONDS=0` and every `(480 - SECONDS)` timeout; the marker `<state dir>/<tab name>.review` with `$$`, written right after the in-use check passes or right after a new tab starts, removed by `trap ... EXIT`; on `agent_not_ready` write the marker and run `herdr agent wait <tab name> --until idle --until done` with no `--timeout`; the prompt with `--wait --until done --until idle` and no `--timeout`; drop `--until blocked` and the `blocked` exit (:85, :90); a failed prompt or wait other than `agent_blocked`: `herdr agent get` fails -> `BLOCKED: the Codex tab ended during the review`, else `BLOCKED: the Codex tab failed during the review: <first line>`, exit 4; no marker pair -> `BLOCKED: no answer between the markers`, exit 4. Add `# ponytail: a pid reused after a kill looks like a live review, store the start time too if that bites`. Negative controls: put back `--timeout` on the prompt (C17 goes red); put back `--until blocked` (C17 goes red); map the gone agent to exit 1 (C18 goes red); map no marker pair to exit 1 (C23 goes red). Test: bash tests/test_codex_agent.sh.
- [ ] T017 [US3] In `scripts/st-advisor.sh`: the usage line gets `|answer|watch` (contract section 3); add `answer --keys <key>...` (each key `^[A-Za-z0-9+_][A-Za-z0-9+_-]{0,15}$`) and `watch`, handled before the feature folder parsing, with the tab name from the one place T005 made and the screen of contract section 6; `watch` polls every 2 s and ends only when a marker it saw is gone or dead; drop `timeout -k 10 540` around the tab run (:203) and the `124|137` tab branch (:205), keep the headless `left` budget, the 60 s floor and the headless `timeout` (:208-211). Add `# ponytail: watch polls every 2 s, switch to herdr agent wait if herdr gains a wait on a state change`. Negative controls: drop the marker check in `answer` (M7 goes red); drop the `blocked` check (M9 goes red); drop the marker check in `watch` (M14 goes red); put the `timeout -k 10 540` back (M18 goes red); let rc 4 run headless (M15 goes red). Test: bash tests/test_advisor_matrix.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh.
- [ ] T018 [US3] Text. `skills/st-build/SKILL.md`: line 95 becomes K1; add K3 with K4 and K5 under it after K2, and K8 after K7. `skills/st-plan/SKILL.md`: lines 30-31 become K9. `README.md`: line 203's first sentence becomes the first sentence of K10; add K11 line 3 after K11 line 2. Test: bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh && bash tests/test_risk_rules.sh.
- [ ] T019 [US3] Live run in herdr, manual and driven by the user (D9, D12): quickstart.md "Live run" steps 1 to 8. The orchestrator gives the user the exact steps and watches; it changes no `~/.codex` file. It passes when one real prompt during a review, made by asking the review for something that needs approval (a command that needs the network), reaches the orchestrator through the watch and is handled by the rule: approved with a one-time yes when on the allow list, else brought to the user with the exact text. Save that real screen as M20 in `tests/test_advisor_matrix.sh` (the `agent read` fixture for a `watch` case; escape codes removed; ask the user before saving if the screen shows a path or value they want kept out). Record in the PR the prompt and how it was handled. When herdr does not report the prompt as `blocked` (plan risk R2), the Monitor shows no `watch` lines (R3), or closing the tab does not end the point (R6), stop and bring it to the user. Test: bash tests/test_advisor_matrix.sh.

**Checkpoint**: all three stories work, stub and live.

---

## Phase 6: Polish

- [ ] T020 Check the whole diff of the feature: no added comment line other than the four `ponytail:` markers of T004, T010, T016 and T017 (`git diff main -- scripts tests | grep -E '^\+\s*#' | grep -v ponytail:`); no `codex-home`, `CODEX_HOME` or `tab close` left in `scripts/` (`grep -n 'codex-home\|CODEX_HOME\|tab close' scripts/st-codex-agent.sh scripts/st-advisor.sh` prints nothing); no `--timeout` on `agent prompt` or `agent wait` in `scripts/st-codex-agent.sh`; run each touched test file once, one after another. Test: bash tests/test_codex_agent.sh && bash tests/test_advisor_matrix.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh && bash tests/test_advisor_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_on_demand.sh.

---

## Dependencies

- US1 -> US2 -> US3. The three stories share `scripts/st-codex-agent.sh`, `scripts/st-advisor.sh`, `tests/test_codex_agent.sh`, `tests/test_advisor_matrix.sh`, `skills/st-build/SKILL.md` and `README.md`, so no two stories run at the same time.
- Inside a phase: the `[P]` test tasks run at the same time. The script task for `st-codex-agent.sh` comes before the one for `st-advisor.sh` (T004 before T005, T010 before T011, T016 before T017): the matrix tests run the real tab script. The text task (T006, T012, T018) can run at the same time as the script tasks once its rule test exists.
- T019 needs T016 to T018. T020 is last.

## Parallel examples

- US1: T001, T002 and T003 together. Then T004 and T006 together, then T005.
- US2: T007, T008 and T009 together. Then T010 and T012 together, then T011.
- US3: T013, T014 and T015 together. Then T016 and T018 together, then T017, then T019.

## Implementation strategy

MVP is US1: the user can use the tab, and it is never closed or typed into while busy. US2 adds the guard that D1 requires before the tab runs with normal approvals for long, so ship US1 and US2 together. US3 adds the answer flow and the live run.

## FR coverage

| FR | Test task (cases) | Build task |
|----|-------------------|------------|
| FR-001 | T001 (C1), T002 (M2) | T004, T005 |
| FR-002 | T002 (M1), T003 (G5 to G8) | T005, T006 |
| FR-003 | T001 (C2, C9), T002 (M3, M16, M17) | T004, T005 |
| FR-004 | T001 (C3, C8), T013 (C18, C19, C21) | T004, T016 |
| FR-005 | T001 (C3, C3b), T002 (M5), T003 (R22) | T004, T005, T006 |
| FR-006 | T001 (C4 to C7), T002 (M4) | T004, T005 |
| FR-007 | T009 (A14); prompt line already pinned by `tests/test_advisor.sh` FR-013 and `tests/test_codex_agent.sh` g | T012 |
| FR-008 | T007 (C10 to C16), T008 (M6), T009 (A15, A16) | T010, T011, T012 |
| FR-009 | T013 (C17, C20, C22) | T016 |
| FR-010 | T014 (M7 to M12) | T017 |
| FR-011 | T014 (M13, M14), T015 (A17 to A20, A22, A23, G3, G4) | T017, T018 |
| FR-012 | T013 (C17, C18, C19, C21, C23), T014 (M15, M18, M19), T015 (A21, A24) | T016, T017, T018 |
| SC-003 | T019 (M20, not a guard) | T019 |
