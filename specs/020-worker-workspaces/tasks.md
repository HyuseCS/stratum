---
description: "Tasks for 020 worker workspaces"
---

# Tasks: Workers in their own herdr workspaces, each with its own Codex tab

**Input**: `specs/020-worker-workspaces/` (spec.md, plan.md, research.md, data-model.md, contracts/cli.md)

**Tests**: required (FR-011, FR-012). Each test task comes before the task that builds it and must fail first.

**Build rules (plan.md)**: minimal code, no new functions or options, no explanatory comments; only `# ponytail: <limit>, <when to upgrade>` markers. Do not touch `answer`, `wait`, `watch`, `screen`, `find_worker` or `scripts/st-codex-agent.sh` (issue #93 changes them).

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

Line numbers below are from commit `2471ee0`. They move as tasks land: find the case by its id (S1, C13, R15 ...).

---

## Phase 1: Setup

- [ ] T001 Stub rework in tests/test_st_worker.sh. In the herdr stub: `workspace create` also writes `$T/tc.json` in the `tab create` shape, `{result:{tab:{tab_id,workspace_id},root_pane:{pane_id,cwd}}}` with `cwd` = the `--cwd` value (pipe its answer through `tee "$T/tc.json"`, as `tab create` does). Add a `"tab rename")` case: set `.label` of tab `$3` to `$4` in `tabs.json`, answer `{"result":{}}`. Add one self-check right after the stub is made (call the stub directly with `STUB_T` set): after `workspace create --cwd /x --label L --no-focus` and `tab rename <its tab> worker-z`, `tc.json` has `root_pane.cwd == "/x"` and `tabs.json` has a tab `worker-z` in the new workspace. All current cases still pass (start still uses `tab create`). Test: bash tests/test_st_worker.sh.

---

## Phase 3: User Story 1 - each worker gets its own workspace (P1), with the saved-machine start (US4)

**Goal**: `start` makes `<O> / <id>: <W>` with `--no-focus`, renames its tab to `worker-<id>`, adds nothing to the orchestrator's workspace, and on a saved machine does the same with no `st-workers` and no main checkout workspace. One code change serves US1 and US4.

**Independent Test**: T002 and T003 cases pass.

- [ ] T002 [US1] Local start tests in tests/test_st_worker.sh, red until T004. Change: S1 (in `s1`) expects one `workspace\tcreate\t--cwd\t<tmp>/repo-worker-t004\t--label\torchestrator / T004\t--no-focus` (the `fresh` task file has no heading; w1P's label is `orchestrator`), one `tab\trename\t<tabid>\tworker-t004`, zero `tab\tcreate`; drop its "no rename" part. LY1 expects the order workspace create, tab rename, pane split, pane run, agent start; drop "no tab rename". S4, S4b: the "no tab create" counts become `workspace\tcreate` counts of 0. S13 (`s13`) and S13b: `STUB_FAIL="workspace create"`, same undo checks. Add: WS1 task file whose first heading is ``# **Autonomous** `sessions` `` gives label `orchestrator / T004: Autonomous sessions`; WS2 a heading of 40 letters gives task words of exactly 30 characters ("cut to 30 characters, then remove trailing spaces"); WS3 a body line before the heading and a heading on line 3: the heading is used; WS4 `HWS=wNone` (no such workspace) gives `repo / T004` (fallback: basename of the repo path); WS5 after start, `tabs.json` holds the same w1P tabs as before and no herdr call names `w1P`; WS6 w1P exists with an empty label (`""`): the label is `repo / T004`; WS7 a leftover workspace labelled `orchestrator / T004` with no `worker-t004` tab is in `ws.json` before start: exit 0, one workspace create, the leftover workspace is untouched (no call names its id); S13c `STUB_FAIL="tab rename"`: exit 1, one `workspace\tclose\t<new ws>`, git log worktree add, worktree remove, branch -D, one `stopped:` line with `stub refused`, worker line `worker\tworker-t004\tlocal\t-\t-\t-\t-`, the new workspace is gone from `ws.json`. Keep every mk-based wait, answer, result, goal, resend, followup case unchanged (FR-004). Test: bash tests/test_st_worker.sh.
- [ ] T003 [US4] Saved-machine start tests in tests/test_st_worker.sh, red until T004. R1 and LY2: one `--machine\tlaptop\tworkspace\tcreate\t--cwd\t/stubhome/proj-worker-t004\t--label\tproj / T004\t--no-focus`, one `tab rename` on the machine, no call names `stubMainWS`, no `worktree\tlist` call. R15 (`STUB_NO_MAIN_WS=1`): exactly one workspace create, and it is the worker's (label `proj / T004`), no `st-workers`. R15b: with an `st-workers` workspace and the main checkout workspace present, no call names `stubSW<x>` or `stubMainWS`, one workspace create. R17: workspace create and pane split get absolute `--cwd` values. R16, R16b: `STUB_FAIL="workspace create"`, the "no tab create" count becomes a workspace create count of 0, same ssh undo checks. Add R18: `--machine laptop` run with `HENV=1`: label `orchestrator / T004`, exactly one local `workspace\tlist` line with no `--machine` in `calls` (check it directly; `rnever` forbids local calls). Test: bash tests/test_st_worker.sh.
- [ ] T004 [US1] Build start in scripts/st-worker.sh (lines 270-308). After the `--repo ~` resolution, set `L` per data-model.md: `<O>` from a plain `herdr workspace list` (never `"${H[@]}"`) only when `HERDR_ENV=1` and `HERDR_WORKSPACE_ID` is set, else or on failure or empty `basename "$repo"`, with no stop; `<W>` = first `^#{1,6}[[:space:]]` line, "Remove the leading `#` marks and spaces, every `*` and backtick, every control character, and trailing spaces and `#`. Cut to 30 characters, then remove trailing spaces." (`# ponytail:` marker on the fixed 30); `<id>` as passed. Delete the `WS=$HERDR_WORKSPACE_ID` / main checkout / `st-workers` block (lines 281-294). Replace `tab create` with `workspace create --cwd "$path" --label "$L" --no-focus` and `tab rename "$TAB" "$N"`; read `WS` from `.result.workspace.workspace_id`, `TAB` from `.result.tab.tab_id` and `PANE` from `.result.root_pane.pane_id` of the create answer, before the rename. Do not use `h` for either call: `h` stops on failure (skipping the cleanup) and overwrites `$r`. Use the explicit `if ! r=$("${H[@]}" ... 2>"$e")` form the current `tab create` uses, and run the rename the same way. On a create failure: today's undo. On a rename failure: run `"${H[@]}" workspace close "$WS"` without `h`, ignore its result and go on to today's worktree undo even if it fails; keep the `stopped:` herdr message (from the rename) and the `; left <path> and branch <N>` text. Before each `stop` on these paths clear `TAB= PANE=` together with `BR= WT=`, so the worker line shows `-` in fields 4 to 7. The label never goes into an `rx`/`rsh` string. Test: bash tests/test_st_worker.sh.

**Checkpoint**: T001 to T004 green.

---

## Phase 4: User Story 2 - each worker gets its own Codex tab (P1)

**Goal**: in a worker worktree the Codex agent is `st-codex-worker-<id>`; the orchestrator name is unchanged.

**Independent Test**: T005 cases pass.

- [ ] T005 [US2] Tests in tests/test_advisor_matrix.sh, red until T006. Add after the M16 loop: `git -C "$proj" checkout -q -b worker-f77`, then with `hlabel` `stratum` and with `hlabel` `abcdefghijklmnopqrstuvwxyz0123456789ABCD`, `hrun nofolder` gives `agent start st-codex-worker-f77` (M30a, M30b); then `git -C "$proj" checkout -q -` so M16 to M18 and later cases still see `st-codex-demo`. Add M30c: on branch `worker-Foo` (no match, uppercase) the name is the label slug. The existing M16 pairs stay as the unchanged-orchestrator check. Add M30d (D14): on branch `worker-abcdefghijklmnopqrstuvwxy` (25-character id) the name is `st-codex-worker-abcdefghijklmnop` (exactly 32 characters). Switch back to the first branch after each case. Test: bash tests/test_advisor_matrix.sh.
- [ ] T006 [US2] Build tabname in scripts/st-advisor.sh (lines 6-22): first, when `git symbolic-ref -q --short HEAD` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`, print `st-codex-<branch>` cut to 32 characters (D14) and return; else the current label slug path, unchanged. `# ponytail:` marker: ids over 16 characters with the same first 16 clash and go headless, add a short hash of the id if that happens. Test: bash tests/test_advisor_matrix.sh.

---

## Phase 5: User Story 3 - close removes the worker's whole workspace (P1), with the saved-machine close (US4)

**Goal**: `close` closes the worker's workspace when it holds only the worker tab and `Codex` tabs, else only the tab; never the workspace that runs `close`.

**Independent Test**: T007 and T008 cases pass.

- [ ] T007 [US3] Local close tests in tests/test_st_worker.sh, red until T009. In `never()`, also allow `w1P` as `--workspace w1P` on `tab list` (read-only). Flip C1, C3, C5, C8, C11 to one `workspace\tclose\t<wsid>`, zero `tab close` (`never 0 0 1`). C13: add `worker-t005` to the worker's own workspace (`addtab "$(wsid):t9" worker-t005 "$(wsid)"`): one tab close on worker-t004's tab, zero workspace close, worker-t005 stays. C18: replace with CW3 below. New ids CW1 to CW4 (`CL1` and `WC1` to `WC4` already exist in this file). Add CW1: a `Codex` tab and an agent `st-codex-worker-t004` in the worker's workspace: one workspace close, the workspace, both tabs and that agent are gone, `closed` and `folder ... ready to remove` lines, the folder still exists. CW2 (old layout): after `mk`, move the worker tab, its panes and its agent to `w1P` with jq: one tab close, zero workspace close, w1P and its `orchestrator` tab stay. CW3: run close with `HWS=$(wsid)`: one tab close, zero workspace close. C2, C4, C6, C7, C9, C10, C12, C16 keep "no workspace close". Replace NC8: a sed that removes the `$HERDR_WORKSPACE_ID` guard (check the sed changes exactly one line), and `nc NC8` on a function that wraps CW3 must go red. Test: bash tests/test_st_worker.sh.
- [ ] T008 [US4] Saved-machine close tests in tests/test_st_worker.sh, red until T009. R9: one workspace close of the worker's workspace on the machine, zero tab close (`rnever 0 0 1`), the `stubMainWS:t1` tab stays. C14: drop `STUB_NO_MAIN_WS` and the `st-workers` wording, same workspace close check. C15: replace with a non-worker tab added to the worker's workspace on the machine: one tab close, zero workspace close. C17: closing T004 closes only T004's workspace, worker-t005's tab stays. Add CW4: `--machine` close with `HWS=$(wsid)`: the workspace is still closed (the id guard is local only). Test: bash tests/test_st_worker.sh.
- [ ] T009 [US3] Build close in scripts/st-worker.sh (lines 520-530): replace `h tab close "$TAB"` and the `st-workers` block with `h tab list --workspace "$WS"`; if every label is `$N` or `Codex` and (`-n "$m"` or `$WS` != `${HERDR_WORKSPACE_ID:-}`) then `h workspace close "$WS"`, else `h tab close "$TAB"` (`# ponytail:` marker: `Codex` is the label `scripts/st-codex-agent.sh` sets, match its tab id from the codex-tabs record if that label changes). No `--group`. Keep the agent/tab check loop. Test: bash tests/test_st_worker.sh.

---

## Phase 6: User Story 5 - list names each worker's workspace (P3)

**Goal**: each `found` line ends with the workspace label.

**Independent Test**: T010 cases pass.

- [ ] T010 [US5] List tests in tests/test_st_worker.sh, red until T011. L1: add `ws.json` entries `stubA<x>` with label `orchestrator / T004: x` and none for `stubB<x>`; expect `...\t/stub/a<x>\torchestrator / T004: x` and `...\t/stub/b<x>\t-`. L2 lines gain the same last field. R12 lines gain the last field on the machine. Add L3: a label with a TAB in it is printed with a space there. Test: bash tests/test_st_worker.sh.
- [ ] T011 [US5] Build list in scripts/st-worker.sh (lines 540-565): one `h workspace list` before the loop, kept in its own variable; each `found` line gets `first(.result.workspaces[] | select(.workspace_id == $w) | .label | strings | gsub("[[:cntrl:]]"; " ")) // "-"` as the last field. Test: bash tests/test_st_worker.sh.

---

## Phase 7: Polish

- [ ] T012 [P] Skill text in skills/st-worker/SKILL.md and its phrase test in tests/test_worker_rules.sh. Test first: change row W14 and add row G14 (below) in tests/test_worker_rules.sh, run the test, see W14 and G14 FAIL. Then edit the skill so they pass. Step 4: replace the sentence "Each worker is one tab labelled `worker-<id>` in this workspace (on a saved machine, ... `st-workers` workspace): the worker agent and lazygit side by side." with one that says each worker gets its own herdr workspace named `<orchestrator> / <id>: <task words>`, with its worktree as folder, on its machine, not focused, holding one tab `worker-<id>` (agent and lazygit side by side) and later its `Codex` tab. Step 11: `close` closes the worker's workspace with its Codex tab (only the tab when the workspace holds other tabs). Step 12: each `found` line ends with the worker's workspace name. Change row W14 in tests/test_worker_rules.sh to the new step 4 sentence, and add a gone row `G14|skills/st-worker/SKILL.md|st-workers`. Owns: `skills/st-worker/SKILL.md`, `tests/test_worker_rules.sh`. Test: bash tests/test_worker_rules.sh && bash tests/test_on_demand.sh && bash tests/test_state.sh && bash tests/test_lane_steps.sh.
- [ ] T013 [P] Codex name docs (D15). Test first: in tests/test_risk_rules.sh change row R7 to the new skills/st-build/SKILL.md line 97 and row R17 to the new README.md line 266, run the test, see R7 and R17 FAIL. Then edit the docs so they pass. skills/st-build/SKILL.md:97: after "Codex runs as the `st-codex-<workspace label>` agent" add " (in a worker, `st-codex-worker-<id>`, in the worker's own workspace)", and after "`codex: tab st-codex-<workspace label>`" add " (`st-codex-worker-<id>` in a worker)". README.md:266: after "runs as the agent `st-codex-<workspace label>`" add " (in a worker, `st-codex-worker-<id>`, in the worker's own workspace)". README.md:270: after "`codex: tab st-codex-<workspace label>`" add " (`codex: tab st-codex-worker-<id>` in a worker)". Change no other text in those lines. Owns: `README.md`, `skills/st-build/SKILL.md`, `tests/test_risk_rules.sh`. Test: bash tests/test_risk_rules.sh.
- [ ] T014 Final check: run the automated part of specs/020-worker-workspaces/quickstart.md, then hand the "By hand" steps to the user (live herdr is the only proof of SC-001 to SC-004). Test: bash tests/test_st_worker.sh && bash tests/test_advisor_matrix.sh && bash tests/test_worker_rules.sh && bash tests/test_risk_rules.sh && bash tests/test_advisor.sh && bash tests/test_advisor_waive.sh.

---

## Dependencies & Execution Order

- T001 before T002. Phases 3, 5, 6 run in that order: they all edit `scripts/st-worker.sh` and `tests/test_st_worker.sh`.
- Phase 4 (US2) shares no file with any other phase: it runs at the same time as phases 1, 3, 5, 6.
- T012 and T013 share no file with any other task or with each other: they run at any time.
- T014 runs last.
- Within each story: the test task first (it must fail), then the build task.

## Requirement map

FR-001, FR-002, FR-003: T002, T004. FR-004: the unchanged mk-based cases in T002. FR-005: T005, T006. FR-006: T007, T009. FR-007: T003, T008, T004, T009. FR-008: T002 (S13, S13b, S13c), T004. FR-009: T010, T011. FR-010: T012. FR-011: T002, T003, T005, T007, T008, T010. FR-012: T014. D14: T005, T006. D15: T013.

## Notes

- No `[screen]` tasks: CLI only.
- No `[lock]` tasks: each test file runs in its own `mktemp -d`.
- No open decisions. D14 and D15 are in decisions.md.
- MVP: T001 to T006 (US1, US4 start, US2).
