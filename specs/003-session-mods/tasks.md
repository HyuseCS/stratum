---

description: "Task list for Mods That Talk To and Start Other Sessions (spike)"
---

# Tasks: Mods That Talk To and Start Other Sessions

**Input**: Design documents from `/specs/003-session-mods/`

**Prerequisites**: plan.md, spec.md, decisions.md, research.md, data-model.md, quickstart.md

**Tests**: Required. `specs/003-session-mods/spikes/check.sh` is written first and is red until the
report is complete (T002). Each mod has a `hooks/register.test.tsx` that is red before its
`register.tsx` exists. Do not edit a test to make it green, except for a bug in the test that you
show.

**Organization**: Tasks are grouped by user story. Paths are from the repo root
`/home/hyuse/Desktop/stratum`. `<feat>` below means `specs/003-session-mods`.

**Rules for every task**: no comments except `ponytail:` markers, minimal code, no new dependency.
Change nothing outside `<feat>/` (FR-001). Never run `git add` or `git commit` inside a test step.
Every started session uses the argv in plan.md section Started sessions (FR-012). Run
`bash <feat>/spikes/cleanup.sh` and then `bash <feat>/spikes/check.sh` before and after each test,
and after any test that stopped partway. The next test starts only when `check.sh` prints no
`FAIL R5` line (FR-006, CHK004). Run `cleanup.sh` and `check.sh` in a Bash call of their own, whose command line holds no `spk003`: a shell whose argv holds the marker is itself a marked process, and `cleanup.sh` would kill it. The test 1 peer `spike-peer` is opened by the user and carries no marker, so cleanup never closes it mid-test (plan.md Started sessions). Approach rules are in plan.md section Approaches (CHK007). Write
only test text into the report (FR-013, plan.md S4 and S5). Copy session rows with `jq -c`, one row per line (R8).

**Order**: US1 (test 3) runs first: it needs no human and decides most of the verdict. US2 and US3
(tests 1 and 2) need the user live. US4 (the report) needs all three tests, so it comes last,
though it is P1.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 to US4 from spec.md
- **MANUAL**: the user does the steps in quickstart.md. The model prepares, then records
- **MAIN**: needs the ListAgents and SendMessage tools of the main session. A subagent without
  them stops and hands the task to the orchestrator

## FR map

| FR | Check (red first) | Build or run |
|----|-------------------|--------------|
| FR-001 | R6 (T001, negative control T027), `claude plugin validate` (T012, T018) | T010, T016 |
| FR-002 | T011 | T012, T013, T014 |
| FR-003 | R1 (T002) | T015 |
| FR-004 | T017 | T018, T019, T020 |
| FR-005 | R1 raw reply rule, R3 (T002) | T006, T007, T009, T021 |
| FR-006 | R5 (T001, negative control T027) | T003, every test task |
| FR-007 | R1 (T002) | T009, T015, T021 |
| FR-008 | R2 (T002, negative control T027) | T022 |
| FR-009 | R3 (T002) | T023 |
| FR-010 | R3 (T002) | T024 |
| FR-011 | R3 (T002, negative control T028) | T025 |
| FR-012 | R4 (T002), argv assert in T017 | T006, T007, T018 (D14 fallback in T007) |
| FR-013 | R8 (T001, negative control T027), token grep (T028) | T028 |
| FR-014 | R9 (T001, negative control T027) | quickstart.md (written by the plan) |
| FR-015 | R3 (T002) | T005 |
| FR-016 | R7 (T002) | T007, T009 |

---

## Phase 1: Setup

None. All tools are installed (plan.md Technical Context). The feature folder exists.

---

## Phase 2: Foundational (blocks every story)

**Purpose**: the check that fails until the spike is done, and the cleanup every test uses.

- [X] T001 Create `specs/003-session-mods/spikes/check.sh`, rules R1 to R9 of `specs/003-session-mods/data-model.md` section "check.sh rules", exactly as defined there. Shape: `#!/usr/bin/env bash`, `set -u`, `root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"`, `report="${1:-$root/specs/003-session-mods/research.md}"`, `quick="${2:-$root/specs/003-session-mods/quickstart.md}"` (the second argument is for the R9 negative control), a `fail()` that prints `FAIL R<n>: <reason>` and sets `rc=1`, then `ok` and exit 0 when nothing failed, else exit 1. One `awk` helper reads the value of `- <Field>:` inside the section whose heading starts with `### <prefix>`, up to the next `### `; values are trimmed. Label sets: Test 1 `full pass|partial pass|blocked`, Tests 2 and 3 `pass|blocked`. Approach IDs: `grep -oE '[ABC][0-9]'`, distinct count 1 to 3, digits 1 to 3. R1 also, for Tests 2 and 3: Result back `yes` only when that test's Evidence matches `spk003-t<n>[a-c]-ok` (`<n>` the test number); Human step not empty; Outcome `pass` only with Human step `none` (D17). R4 per data-model R4: per data row, Name holds `spk003`, Argv holds `haiku`, Turn limit `--max-turns 3` with that text in Argv or `no tools` with `--tools ""` in Argv, and Argv holds `timeout 300` or Stopped minus Started (`HH:MM:SS`, `date -d` to seconds) is at most 300. R3 computes Starts, Result back, Stops, Verdict and Failed part from the Test 2 and Test 3 fields as in the data-model Verdict table ("the three parts hold for the same test"). R5: `command pgrep -f 'spk00[3]'` finds nothing; `claude agents --json | jq '[.[] | select((.name // "") | test("spk00[3]"))] | length'` is `0`; `git -C "$root" worktree list --porcelain` and `git -C "$root" branch --list` hold no `spk003`. The pattern is written `spk00[3]` wherever a shell argv could hold it. R6: `git -C "$root" status --porcelain`, path from column 4, allowed prefix `specs/003-session-mods/` or exact `.stratum/state.json`, ignored exact `.stratum/commit-mode`, `brag-output/`, `skills/st-ui-ux/scripts/__pycache__/`. R8: `grep -rEn '(TOKEN|SECRET|KEY)=[^[:space:]]+'` over the report and `$root/specs/003-session-mods/spikes`, excluding `check.sh` and the engine's `.claude-plugin/types/` folders; and every report line holding `"sessionId"` also holds `spk003` or `spike-`. R9: `grep -qF` each of the four headings in `$quick`. Use `command pgrep`, never a bare `pkill` (the Bash tool wraps it). Security: plan.md S4, S5.
- [X] T002 Run `bash specs/003-session-mods/spikes/check.sh`. Expected: exit 1, with FAIL lines for R1, R2, R3, R4 and R7 (the outline is empty) and none for R5, R6, R8, R9. Any other result is a bug in `check.sh` or in the outline: fix `check.sh`, never the expected list. Report the full output. This is the red state for FR-003, FR-005, FR-007 to FR-012, FR-015.
- [X] T003 [P] Create `specs/003-session-mods/spikes/cleanup.sh`. `#!/usr/bin/env bash`, `set -u`, `root` as in T001. Steps, each printing what it removed: (1) `command pgrep -af 'spk00[3]'` then `command pkill -f 'spk00[3]'`, wait up to 5 s, then `command pkill -9 -f 'spk00[3]'` for any left; (2) for each `claude agents --json --all` entry whose `name` matches `spk00[3]` (keys: `cwd`, `kind`, `name`, `pid`, `sessionId`, `startedAt`, `status`): `claude stop <sessionId>` then `claude rm <sessionId>`; if `claude stop` refuses the `sessionId`, use the `name`, and keep in the script the one that worked (confirm on first use); (3) for each `git worktree list --porcelain` path holding `spk003`: `git worktree remove --force <path>`, then `git worktree prune`; (4) for each `git branch --list '*spk00[3]*'`: `git branch -D <name>`. Print `nothing to clean` when no step found anything. Exit 0. Security: plan.md S5 (print only marked rows).
- [X] T004 Run `bash specs/003-session-mods/spikes/cleanup.sh`: prints `nothing to clean`. Run `bash specs/003-session-mods/spikes/check.sh`: no `FAIL R5` line.

**Checkpoint**: `check.sh` red on the report only. `cleanup.sh` works on an empty state.

---

## Phase 3: User Story 1 - The model starts a session on its own (Priority: P1) MVP

**Goal**: test 3. The model starts a local session with no human step, gets the exact reply text,
and stops it. Also records whether that session shows in ListAgents and receives a SendMessage.

**Independent Test**: after T009, `check.sh` prints no FAIL line about Test 3 (R1 for Test 3, R7)
and no `FAIL R5`.

- [X] T005 [US1] Record the version and the environment. Run `claude --version` and write the number into `specs/003-session-mods/research.md` under `### Claude Code version` as `- Version: 2.1.296` (or what it prints). Run `env | cut -d= -f1 | grep -i claude` and compare the names with research.md R10. Add any new name to R10. Never print values (plan.md S4).
- [X] T006 [US1] Approach C1. Run cleanup and check (Rules). Through Bash run the plan.md argv with `<id>` `t3a` and `--output-format json` added after `-p`. If it refuses to start because it is nested, retry with `env -u <name>` for the names the error names (a retry, plan.md Approaches) and record them. From the JSON record: the field names, the reply field's value, the session id, and the cost and token fields (Q5 evidence). Compare the reply with `spk003-t3a-ok` after trimming (FR-005). Record whether `-n` and `--max-turns` were accepted. Then write the argv that worked (flags dropped, `env -u` names added) into the argv block of `specs/003-session-mods/plan.md` section Started sessions, so one place defines it for T017 and later runs. Tell the orchestrator: that plan.md edit gets its own commit before T017 starts (D16). Run cleanup and check. Add one row to the `### Started sessions` table in `specs/003-session-mods/research.md` (data-model Started session, Turn limit `--max-turns 3` or `no tools`). Note any permission prompt you saw for the Human step field. Security: plan.md S1, S4.
- [X] T007 [US1] MAIN. Approach C2, always run (plan.md Approaches). Run cleanup and check. Through Bash run the `--bg` form of the argv with `<id>` `t3b`, and note the start time and the id it prints. If `--bg` refuses `-n`, record the error and retry without it. If it refuses `--max-turns`, record the error, drop the flag and keep `--tools ""` as the limit (FR-012, D14); the Started sessions row then has Turn limit `no tools`. The 5-minute stop applies either way. Then: (a) `claude agents --json | jq -c '.[] | select((.name // "") | test("spk00[3]"))'` and copy the result; (b) call ListAgents and copy only the row of `spk003-t3b`, or record `not seen` (FR-016); (c) `claude logs <id>` and compare the reply with `spk003-t3b-ok`; (d) call SendMessage to `spk003-t3b` (or the address ListAgents shows) with `spk003-t3b: reply with exactly the text spk003-t3b-ping-ok`, then `claude logs <id>` and record whether the message and a reply show; (e) before 300 s from the start: `claude stop <id>`, `claude rm <id>`, and note the stop time. Run cleanup and check. Add a Started sessions row with both times as `HH:MM:SS`. Note any permission prompt you saw for the Human step field. Security: plan.md S1, S3, S5.
- [X] T008 [US1] Approach C3, only if C1 and C2 both failed. Otherwise write `C3: not run, <C1 or C2> passed` in Approaches tried and skip the rest. Run cleanup and check. Through Bash run the plan.md argv with `<id>` `t3c` and `-w spk003-t3c` added after `-p`. Record the reply, then `git worktree list --porcelain` and `git branch --list '*spk00[3]*'`. Run cleanup (it removes the worktree and branch) and check. Add a Started sessions row.
- [X] T009 [US1] Fill `### Test 3. The model starts a session` in `specs/003-session-mods/research.md` per data-model.md: Outcome `pass` or `blocked`, Approaches tried (`C1: ...; C2: ...; C3: ...`), Evidence (commands and output excerpts, marked rows only, and the raw reply line quoted, such as `spk003-t3a-ok`), Limit, Result back, Stops, Human step (`none`, or the prompt that was answered; `pass` needs `none`, D17), ListAgents, SendMessage, and Over the Agent tool (what a separate session gives that the built-in Agent tool does not, from what T006 and T007 showed: own process, own model and tools, survives the parent or not, reachable by other sessions or not, addressable by name or not). Run `bash specs/003-session-mods/spikes/check.sh`: no FAIL line names Test 3, no `FAIL R5`, no `FAIL R7`.

**Checkpoint**: the D12 parts can already be read from test 3.

---

## Phase 4: User Story 2 - A mod sends a message to a second session and shows the reply (Priority: P2)

**Goal**: test 1. Mod `spike-send` sends one message to the hand-opened `spike-peer` session and
shows the reply in a pane.

**Independent Test**: `claude plugin test specs/003-session-mods/spikes/spike-send` passes, and
quickstart.md section 5 shows the reply text in the pane.

### Tests for User Story 2

- [X] T010 [P] [US2] Create the mod frame, copying the layout of `git show st-tree:mods/st-tree/...`: `specs/003-session-mods/spikes/spike-send/.claude-plugin/plugin.json` (`"name": "spike-send"`, `"version": "0.0.1"`, a one-line description, `"types": "./types/index.d.ts"`), `specs/003-session-mods/spikes/spike-send/hooks/hooks.json` (`{ "modules": ["./register.tsx"] }`), `specs/003-session-mods/spikes/spike-send/types/index.d.ts` (`declare module 'claude-code' { interface PluginState { 'spike-send': { sent: string; reply: string; origin: string } } }`, no import).
- [X] T011 [US2] Create `specs/003-session-mods/spikes/spike-send/hooks/register.test.tsx` with the kit from `claude-code/testing` (types file from line 14882). First raise `$.session.start({ cwd: '.', surface: 'terminal', isInteractive: true })` so the command is registered. Every `$.command.run` passes the full `CommandRunInput` (d.ts 1767-1825): `{ command, args, origin: { kind: 'composer' }, presentation: { isFullscreen: false, columns: 80 } }`. Cases (FR-002): (a) `/spike-send` with args `spike-peer` and a test `on('session.send')` hook that records `e` and answers `{ isDelivered: true }`: `e.to` is `spike-peer` and `e.text` holds `spk003`; (b) args `sid:<a fixed uuid>`: the call resolves without a rejection and `e.to` is not the literal text `sid:<uuid>` (the kit may not spell `{ sessionId }` as a session does); (c) `$.session.receive({ origin: { kind: 'peer' }, text: 'spk003-pong' })`, then `$.ui.mount` of `Pane` with requestId `spike-send` on `terminal`: the tree shows `spk003-pong` and `peer`; (d) a received text without `spk003` is not shown. Run `claude plugin test specs/003-session-mods/spikes/spike-send`: exit 1, and the failure names the missing `register.tsx` (not a bad input shape). Report the output.

### Implementation for User Story 2

- [X] T012 [US2] Create `specs/003-session-mods/spikes/spike-send/hooks/register.tsx`, approach A1, in the style of `examples/pane.tsx`: `session.start` registers command `spike-send`; `command.run` for it opens pane `{ id: 'spike-send', title: 'spike-send' }`, turns args `sid:<id>` into `{ sessionId: <id> }` and any other args into the name string, calls `$.session.send({ to, text: 'spk003 ping: reply to this message with SendMessage, text exactly spk003-pong' })`, and writes `sent: delivered` or `sent: not delivered <reason>` to `$.state`; `session.receive` with no matcher writes `e.text` and `e.origin.kind` to `$.state` when the kind is `peer` or `peer-send-message` and the text holds `spk003`, then returns `next(e)`; `ui.render` for `Pane` `spike-send` draws the sent, reply and origin rows. Run `claude plugin validate specs/003-session-mods/spikes/spike-send` (passes) and `claude plugin validate --json specs/003-session-mods/spikes/spike-send` (save its `gatingHooks` and calls for Q1 and Q2), then `claude plugin test specs/003-session-mods/spikes/spike-send`: exit 0. Security: plan.md S3.
- [ ] T013 [US2] MANUAL. Test 1, approach A1. Run cleanup and check before the user opens the peer. The peer `spike-peer` stays open through A1 to A3 (it carries no marker, so cleanup between approaches leaves it alone); the user closes it at the end of test 1 (quickstart.md section 5, steps 10 and 11). After the user loaded the mod, run `git status --porcelain --ignored specs/003-session-mods/spikes`: the engine's `spike-send/.claude-plugin/types/` folder must show as `!!` (ignored by the `.gitignore` the engine lays inside it, as in `mods/st-tree/.claude-plugin/types/.gitignore`). If it shows as `??`, create `specs/003-session-mods/spikes/.gitignore` with the line `**/.claude-plugin/types/` and run the command again. Ask the user to follow `specs/003-session-mods/quickstart.md` section 5 and send back the pane text. Record the send result, the reply text, the origin kind, and any permission prompt in the peer. Run cleanup and check. Security: plan.md S1, S3, S5.
- [ ] T014 [US2] Only if A1 failed. A2: first add to `specs/003-session-mods/spikes/spike-send/hooks/register.test.tsx` a case where `/spike-send` makes a `tool.call` of `SendMessage` (a test `on('tool.call', { tool: 'SendMessage' })` hook records it), run `claude plugin test` (red), change `specs/003-session-mods/spikes/spike-send/hooks/register.tsx` to call `$.tool.call({ tool: 'SendMessage', to, message })`, run it (green), then MANUAL quickstart section 5 again. If A2 failed: A3, MANUAL, quickstart section 5 "A3", no code change (the receive hook already shows the reply). Run cleanup and check after each.
- [ ] T015 [US2] Fill `### Test 1. A mod sends a message to a second session and shows the reply` in `specs/003-session-mods/research.md`: Outcome `full pass` (A1 or A2), `partial pass` (A3) or `blocked`, Approaches tried, Evidence (pane text, `isDelivered` result), Limit (for partial pass, the exact reason the mod could not send). A peer that was not running is a retry, not a fail (CHK010). Run `check.sh`: no FAIL line names Test 1, no `FAIL R5`.

---

## Phase 5: User Story 3 - A mod starts a session and shows its status (Priority: P3)

**Goal**: test 2. Mod `spike-start` starts `claude -p` with no further human step and shows
running, done or failed in a pane.

**Independent Test**: `claude plugin test specs/003-session-mods/spikes/spike-start` passes, and
quickstart.md section 6 shows `done` and `spk003-t2a-ok`.

### Tests for User Story 3

- [X] T016 [P] [US3] Create the mod frame as T010, for `spike-start`: `specs/003-session-mods/spikes/spike-start/.claude-plugin/plugin.json`, `specs/003-session-mods/spikes/spike-start/hooks/hooks.json`, `specs/003-session-mods/spikes/spike-start/types/index.d.ts` (`'spike-start': { status: string; name: string; reply: string; detail: string }`).
- [X] T017 [US3] Create `specs/003-session-mods/spikes/spike-start/hooks/register.test.tsx`. First raise `$.session.start({ cwd: '.', surface: 'terminal', isInteractive: true })` so the command is registered. `$.command.run` passes the full `CommandRunInput`: `{ command: 'spike-start', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: false, columns: 80 } }`. Cases (FR-004, FR-012): (a) a test `on('process.spawn', async function* ($, e) { ... })` hook records `e.argv`, yields `{ stream: 'stdout', text: 'spk003-t2a-ok\n' }` and returns `{ code: 0, signal: null }`; after the command runs and the stream ends, `e.argv` equals exactly the argv in `specs/003-session-mods/plan.md` section Started sessions as T006 confirmed it, with `<id>` `t2a` (today: `['timeout', '300', 'claude', '-p', '--model', 'haiku', '--max-turns', '3', '--tools', '', '--strict-mcp-config', '--no-session-persistence', '-n', 'spk003-t2a', 'spk003-t2a: reply with exactly the text spk003-t2a-ok and nothing else.']`), and the mounted `Pane` `spike-start` shows `done` and `spk003-t2a-ok`; (b) the hook returns `{ code: 124, signal: null }`: the pane shows `failed` and `124`; (c) while the hook has yielded nothing yet, the pane shows `running` and `spk003-t2a`. If the kit cannot answer `process.spawn` from a test hook (research R8), record the error and test the argv and the status function by a direct import instead. Run `claude plugin test specs/003-session-mods/spikes/spike-start`: exit 1, and the failure names the missing `register.tsx`. Report the output.

### Implementation for User Story 3

- [ ] T018 [US3] Create `specs/003-session-mods/spikes/spike-start/hooks/register.tsx`, approach B1: `session.start` registers command `spike-start`; `command.run` opens pane `{ id: 'spike-start', title: 'spike-start' }`, sets status `running`, and starts a loop that outlives the hook (the `void (async () => { ... })()` form of the `$.process.spawn` example "a child for the session's life" in the types file, 3540-3551) over `$.process.spawn({ argv })` with the argv of T017; it collects stdout, keeps the last stderr text, and on the end sets `done` (code 0) or `failed` (code not 0, or a signal) with the reply or the detail; `ui.render` for `Pane` `spike-start` draws status, name, reply, detail. Run `claude plugin validate specs/003-session-mods/spikes/spike-start`, `claude plugin validate --json specs/003-session-mods/spikes/spike-start` (save `gatingHooks` and calls for Q2), and `claude plugin test specs/003-session-mods/spikes/spike-start`: exit 0. Security: plan.md S2.
- [ ] T019 [US3] MANUAL. Test 2, approach B1. Run cleanup and check. Ask the user to follow `specs/003-session-mods/quickstart.md` section 6 and send back the pane text, the `pgrep -af spk003` output, and any step they answered after `/spike-start` (Human step, D17). Run cleanup and check. Add a Started sessions row (Turn limit, `HH:MM:SS` times) to `specs/003-session-mods/research.md`. Security: plan.md S1.
- [ ] T020 [US3] Only if B1 failed. B2: first add a case to `specs/003-session-mods/spikes/spike-start/hooks/register.test.tsx` (a test `on('process.run')` hook answers `claude --bg` with an id and `claude agents --json` with a running, then a finished entry), run it (red), change `specs/003-session-mods/spikes/spike-start/hooks/register.tsx` to start with `$.process.run(['claude', '--bg', ...])`, poll `claude agents --json` with `$.clock.every`, read the reply with `claude logs`, and end with `claude stop` and `claude rm` before 300 s; run it (green); MANUAL quickstart section 6 again. If B2 failed: B3, the same way with `-w spk003-t2c` added to the B1 argv. Run cleanup and check after each. Security: plan.md S1, S2.
- [ ] T021 [US3] Fill `### Test 2. A mod starts a session and shows its status` in `specs/003-session-mods/research.md`: Outcome, Approaches tried, Evidence (quote the raw reply line, such as `spk003-t2a-ok`), Limit, Result back (the pane showed the exact reply), Stops, Human step (`/spike-start` itself does not count; `pass` needs `none`, D17). Run `check.sh`: no FAIL line names Test 2, no `FAIL R5`.

---

## Phase 6: User Story 4 - The report and the verdict (Priority: P1)

**Goal**: `research.md` answers Q1 to Q5 with evidence, compares mod and model, records the cloud
limit, and gives the D12 verdict.

**Independent Test**: `bash specs/003-session-mods/spikes/check.sh` prints `ok` and exits 0.

- [ ] T022 [US4] Fill Q1 to Q5 in `specs/003-session-mods/research.md`. Each Answer is one to three sentences. Each Evidence names at least one d.ts line, a command and its output, or a spike file (data-model Question). Use research R1 to R10, the `claude plugin validate --json` output of T012 and T018 (Q1, Q2), T006 cost fields (Q5), and what T007 showed about sessions that outlive the parent (Q5). Q3: what a mod can see of a session it did not start (its own `session.receive` deliveries, `claude agents --json` status, SendMessage `notify_when_idle` per the tool input in the types file) and what it cannot (no hook fires for another session's tool calls). Copy only marked session rows, with `jq -c` (plan.md S5, R8).
- [ ] T023 [US4] MAIN. Fill `### Cloud limit` in `specs/003-session-mods/research.md`: quote the ListAgents tool description line about cloud sessions as the main session sees it, and the issue #9 lead. If neither the tool description nor the d.ts has a line on replies, write that the issue lead is the only source (research R9). Start no cloud session (D8).
- [ ] T024 [US4] Fill `### Mod vs model` in `specs/003-session-mods/research.md`: test 2 against test 3 on start effort, result path, status, stop, survival after the parent ends, and cost, from the recorded evidence only.
- [ ] T025 [US4] Fill `### Verdict` in `specs/003-session-mods/research.md` per the data-model Verdict table. For `yes`, the Follow-up issue line holds a proposed title. Do not open the issue (the owner decides).
- [ ] T026 [US4] Run `bash specs/003-session-mods/spikes/check.sh`: prints `ok`, exit 0. Fix the report, not the script.

---

## Phase 7: Polish and negative controls

Each control proves one rule can go red. Run them on copies or on a marked dummy, never on the real
report.

- [ ] T027 Negative controls. Each row breaks one rule, runs `check.sh`, expects exit 1 with only the listed FAIL line, then restores. Report copies go in `d=$(mktemp -d)` (`cp specs/003-session-mods/research.md $d/r.md`, `cp specs/003-session-mods/quickstart.md $d/q.md`), never the real files. Run `check.sh` and `cleanup.sh` in Bash calls of their own (Rules). After the last row, `check.sh` prints `ok`. Remove `$d`.

  | Rule | Change made | Command | Expected FAIL line | Restore |
  |------|-------------|---------|--------------------|---------|
  | R2 | In `$d/r.md`, empty the `- Evidence:` line under `### Q3.` with `sed` | `check.sh $d/r.md` | `FAIL R2` | none (copy) |
  | R3 | In `$d/r.md`, flip `- Verdict:` (`yes` to `no`, or `no` to `yes`) | `check.sh $d/r.md` | `FAIL R3` | none (copy) |
  | R5 | `setsid -f bash -c 'exec -a spk003-nc sleep 120'` | `check.sh` | `FAIL R5` | `cleanup.sh` prints the `spk003-nc` process |
  | R6 | `touch nc-r6.tmp` in the repo root | `check.sh` | `FAIL R6` | `rm nc-r6.tmp` |
  | R8 | Append the line `TOKEN=nc` to `$d/r.md` | `check.sh $d/r.md` | `FAIL R8` | none (copy) |
  | R9 | In `$d/q.md`, delete the `## 3. Hot reload answer` heading line | `check.sh specs/003-session-mods/research.md $d/q.md` | `FAIL R9` | none (copy) |

- [ ] T028 Privacy review (FR-013). Read `specs/003-session-mods/research.md` and every file under `specs/003-session-mods/spikes/`. Only test prompts, replies and command output may be there. Run `grep -c "$CLAUDE_CODE_SESSION_ID" specs/003-session-mods/research.md`: `0` (the running session's id is not test text). Run `grep -rlF -f <(printenv CLAUDE_CODE_MESSAGING_TOKEN) specs/003-session-mods/` in bash: no output (the value goes in by file, never in argv or output; plan.md S4). Remove anything else that is not test text, then run `check.sh`: `ok`.
- [ ] T029 Run `specs/003-session-mods/quickstart.md` section 8 and report the actual output of `check.sh` and `git status --porcelain`.

---

## Dependencies and Execution Order

- Phase 2: T001 then T002. T003 in parallel with T001 and T002. T004 after T001 and T003.
- US1: T005 to T009 in order, after T004.
- US2 build (T010 to T012) may run after T004, in parallel with US1: separate folder. T011 after
  T010, T012 after T011.
- US3 build (T016 to T018) runs after T006, because T017 asserts the argv T006 confirmed. T017
  after T016, T018 after T017.
- Live tests run one at a time, because cleanup and the process check sit between them: T006, T007,
  T008, then T013 and T014, then T019 and T020. T013 needs T012 and T009. T019 needs T018 and T015.
- T015 after T013 and T014. T021 after T019 and T020.
- US4: T022 to T025 after T009, T015 and T021. T026 last in US4.
- Polish: T027 to T029 after T026, in order. T029 last.

## Parallel Example

```text
Lane 1: T001 -> T002            (check.sh)
Lane 2: T003                    (cleanup.sh)
then
Lane 1: T005 -> T006 -> T007 -> T008 -> T009   (test 3, runs live sessions)
Lane 2: T010 -> T011 -> T012                   (spike-send, no live session)
Lane 3: after T006: T016 -> T017 -> T018       (spike-start, no live session)
```

`claude plugin test` starts no model session, so lanes 2 and 3 do not disturb the process check of
lane 1.

## Implementation Strategy

1. MVP: Phase 2 and US1. Test 3 alone can settle all three D12 parts.
2. Then US2 and US3 with the user live, one session at a time.
3. Then US4 and the controls. The verdict follows the data-model rule, which `check.sh` R3 checks.
