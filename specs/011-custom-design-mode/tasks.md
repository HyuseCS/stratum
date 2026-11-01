---

description: "Tasks for the custom design mode (011)"
---

# Tasks: Custom Design Mode

**Input**: `/specs/011-custom-design-mode/` plan.md, spec.md, research.md, data-model.md,
contracts/custom-mode.md, quickstart.md

**Prerequisites**: FigCraft installed by the user (quickstart section 0) before T004.

**Tests**: Required. Every FR has a check that can fail, written before the task that builds it.
Texts, phrase rows and cases are in contracts/custom-mode.md.

**Organization**: Phase 1 runs the spikes. Their results can change four named parts of the
contract before anything is built. Phase 2 builds the FigCraft script, the tool check, the MCP
entry and `design-tool.md`, which every story needs. US1 writes every lane text, US2's and US3's
sentences included, in one test task and one build task. US2 and US3 then keep only their live
runs. US4 adds the optional-tool texts.

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

- **[P]**: Can run in parallel: no shared file in the phase and no other task's result; the task ends with `Owns:`
- **[lock]**: none in this feature. Each `tests/test_figcraft.sh` case takes its own free port and run dir
- **[screen: <mode>]**: none in this feature. It changes Stratum and adds no app screen
- Run every test from the repo root with `PYTHONDONTWRITEBYTECODE=1` and leave no file or process behind
- Each task's commit: the `st-git` agent commits the exact paths the task names
- A spike or live run that cannot run gets `Not run, <reason>` beside its tick, never a bare tick
- Agents never install FigCraft or run `sudo`. The user does (quickstart section 0)

## Phase 1: Setup (spikes)

**Purpose**: test the spec's Assumptions before any build. Each spike writes its entry in research.md
R15. When a spike fails, Build stops and brings its two options to the user. Nothing in Phase 2
starts until T001, T002, T004 and T005 have a result. The Flatpak needs no spike: its manifest
already shows no CLI and no project access (research R2).

- [X] T001 Spike S3: does the `plugin.json` MCP entry break or warn in a session with no `figcraft-cli`, and does an agent whose `tools:` names that absent server's tool still start? Run quickstart section 1 S3, both checks, in the scratchpad (scratch copy `stratum-spike`, a `fail.sh` that exits 127, scratch agent `spike-read`). The user does the start-screen look. Record both in `specs/011-custom-design-mode/research.md` R15. Pass: no change. Fail of the entry check: apply contract section 6's fallback to `specs/011-custom-design-mode/contracts/custom-mode.md` sections 2, 3, 6, 7d and 9 and to `specs/011-custom-design-mode/plan.md` security note S4 before Phase 2. Fail of the agent check: apply the quickstart S3 fallback (no `tools:` line) to contract section 3a and its two checks in section 9, and to plan.md security note S6, before Phase 2. Test: claude --plugin-dir <s3>/stratum-spike -p "Say ok."
- [X] T002 Spike S2: can a plugin subagent call the plugin's MCP tool, and what is the tool's exact name? Run quickstart section 1 S2 (scratch stdio server with one `ping` tool, scratch agent). Record the reply, the exact name, whether a prompt appeared without `--allowedTools`, and whether a per-tool D23 rule in a scratch `.claude/settings.json` stops the prompt for the named tool and not for an unnamed one, in `specs/011-custom-design-mode/research.md` R15 and R8. Pass with another name form: change the prefix in `specs/011-custom-design-mode/contracts/custom-mode.md` sections 2 (with its Tools line), 3a, 7d and 9. Fail: stop and ask the user. A: the orchestrator (main session) makes the FigCraft calls and the agent only builds code. This changes D18 and FR-015. B: no MCP; the agent draws with `figcraft-cli run` scripts on the saved file and the user reopens it in FigCraft after each change. This loses the live view and the selection (D18 rejected O22). Recommend A. Test: claude --plugin-dir <s2>/stratum-spike -p "Start the stratum-spike:spike agent. It calls its ping tool and reports the reply." --allowedTools mcp__plugin_stratum-spike_figcraft__ping
- [X] T003 The user installs FigCraft 0.13.1 on this laptop with the pacman line of quickstart section 0. Record S0 in `specs/011-custom-design-mode/research.md` R15: both paths and the `--version` line. No `figcraft-cli` from the package: stop and ask the user. A: use the AppImage (`figcraft cli`, research R1). B: install the CLI from source with `cargo build --release -p figcraft-cli`. Recommend A. Test: command -v figcraft figcraft-cli && figcraft-cli --version
- [X] T004 Spike S1: does the attached MCP server see the user's unsaved changes and selection? Run quickstart section 1 S1 steps 1 to 6 in a scratch project (step 5: `collab.host` refused, so sharing is off). The user drags and selects by hand at step 3. Record each step's result in `specs/011-custom-design-mode/research.md` R15. Fail of step 3: stop and ask the user. A: the stop tells the user to save in FigCraft (Ctrl+S) before saying good. Save then reads the file, and "this" changes name the layer instead of a selection. B: drop the live window for the build path and keep only the saved file (no change to the stop text). Recommend A. Fail of step 5: stop and ask the user, since FR-007 and SC-005 do not hold. Fail of step 2 or 6: apply the quickstart fallback to `specs/011-custom-design-mode/contracts/custom-mode.md` section 2 or 4. Test: figcraft-cli mcp --attach 7979 (driven by the scratch client, quickstart S1)
- [X] T005 Spike S5: does the CLI read the full layer tree with no window? Run quickstart section 1 S5 on T004's `design/s1.figcraft`. Record what `design.json` holds per layer in `specs/011-custom-design-mode/research.md` R15 and R6. Fail: take research R6's fallback and change `specs/011-custom-design-mode/contracts/custom-mode.md` section 2 Read and its FR-010 rows in section 9. Test: figcraft-cli convert design/s1.figcraft design/.read/s1/design.json --automation-read-root <p> --automation-write-root <p>/design

---

## Phase 2: Foundational (FigCraft script, tool check, MCP entry, design-tool file)

**Purpose**: the pieces every story uses. FR-005 to FR-010, FR-012, FR-014 to FR-016.

- [X] T006 [P] Write `tests/test_figcraft.sh` with cases F1 to F10 of contract section 10, in the frame of `tests/test_design_check.sh` (`root="${ST_ROOT:-…}"`, `mktemp -d`, stub PATH of fakes plus symlinked `python3`, `mkdir`, `nohup`, `tail`, `sleep`, `XDG_RUNTIME_DIR` in the temp dir, a free port per case, a trap that kills every started pid). Run it: F1 to F9 red because `scripts/st-figcraft.sh` does not exist, and F10 green (no writes, no pids). FR-005, FR-007. Owns: `tests/test_figcraft.sh`. Test: bash tests/test_figcraft.sh
- [X] T007 [P] Add K14 to K20 of contract section 10 to `tests/test_design_check.sh`. `run` gains an optional fourth argument passed to the script. Every existing case keeps its exact output. Run it: K14, K15, K16, K17, K19 and K20 red, and K18 and the old cases green. FR-016, SC-004. Owns: `tests/test_design_check.sh`. Test: bash tests/test_design_check.sh
- [X] T008 Write `scripts/st-figcraft.sh` per contract section 4 until `bash tests/test_figcraft.sh` is green. Add the two `ponytail:` comments: the port seam, and the stale-pid gap (plan S3). Add `bash tests/test_figcraft.sh` after `bash tests/test_design_lane.sh` in the `README.md` Tests block. Security: external app launch, local socket, file roots (plan S1, S2, S3). Run negative controls N1 and N2 (quickstart section 3). FR-005, FR-007. Test: bash tests/test_figcraft.sh && bash tests/test_inspect.sh
- [X] T009 Add the `--custom` branch to `scripts/st-design-check.sh` per contract section 5 (`"$BASH" "${0%/*}/st-figcraft.sh" check`, no `bash` or `dirname` on the stub PATH) until `bash tests/test_design_check.sh` is green. Run negative controls N3 and N4. FR-016, SC-004. Test: bash tests/test_design_check.sh
- [X] T010 [P] Add to `tests/test_design_lane.sh`, with the `C-` names of contract section 9: the `C-FR-015 mcp entry` and `C-FR-015 tool list` checks and every `skills/st-design/design-tool.md` row (C-FR-005, all three C-FR-006 rows with the US2 one, C-FR-007, C-FR-008, both C-FR-009, both C-FR-010, C-FR-012 and C-FR-014). Run it: these red, and the old 009 rows green. FR-005 to FR-010, FR-012, FR-014, FR-015. Owns: `tests/test_design_lane.sh`. Test: bash tests/test_design_lane.sh
- [X] T011 Write `skills/st-design/design-tool.md` whole from contract section 2, the Draw sentence for a page or screen the project has included. Add `mcpServers` to `.claude-plugin/plugin.json` per contract section 6 and keep every other key. Add the FigCraft row to the `README.md` Requirements table (contract 7e). Security: MCP server in every session (plan S4), external app (S1). Then T010's rows are green, and 009's `FR-010 one place` check stays green: `design-tool.md` names no engine. Run negative controls N5, N8 and N10. FR-005 to FR-010, FR-012, FR-014, FR-015. Test: bash tests/test_design_lane.sh && claude plugin validate .claude-plugin/plugin.json && bash tests/test_inspect.sh

**Checkpoint**: `st-figcraft.sh start` runs FigCraft confined to a project, the check knows `--custom`, and the MCP entry and the tool file exist.

---

## Phase 3: User Story 1 - A screen designed by hand in FigCraft, then built (Priority: P1) MVP

**Goal**: grill, Start, draw, one stop with changes, save, design file, build, checks, gate, commit with the saved design. The lane texts for US2 (existing screen, routing) and US3 (gate changes) are written here too.

**Independent Test**: quickstart section 4 L1.

- [X] T012 [US1] In `tests/test_design_lane.sh`, with the `C-` names of contract section 9: add the rows for `skills/st-design/SKILL.md` (C-FR-001, all three C-FR-002 rows with the `[screen: custom]` row and the US2 row, C-FR-004, C-FR-005, C-FR-006, both C-FR-008, C-FR-009, C-FR-010, both C-FR-011, C-FR-012, the four C-FR-013 US3 rows, C-FR-016), the `C-FR-002 st` row for `skills/st/SKILL.md`, and the rows for `agents/st-design.md` (C-FR-010, C-FR-014, both C-FR-007). Change 009's `FR-001 agent frontmatter` check to the `tools:` line of contract 3a. Add the `C-FR-015 agent tools` and `C-FR-014 one place` checks. In `tests/test_plan_rules.sh`, change DL1 to the contract's `DL1|agents/st-plan.md|…` row. Run both: the new rows and checks, the changed agent frontmatter check and DL1 red. One task, because these checks share files with T013. FR-001 to FR-016 (FR-003 through DL1). Test: bash tests/test_design_lane.sh && bash tests/test_plan_rules.sh
- [X] T013 [US1] Edit `skills/st-design/SKILL.md` per contract 1a to 1h, section 6 written whole (step 3's existing-screen sentence and step 8's change routing included). Add the Custom design row to `skills/st/SKILL.md` per 7a. Edit `agents/st-design.md` per contract 3a to 3f. Edit `agents/st-plan.md` per 7b. Edit `README.md` lines 91 and 92 per 7e, and the `DESIGN.md` `st-design <task>` row per 7f. Security: untrusted design text (plan S5), agent tool scope (S6). Then T012's rows and checks are green, and 009's `FR-001 one start each` check still counts 1. Run negative controls N6, N7 and N9. FR-001 to FR-016. Test: bash tests/test_design_lane.sh && bash tests/test_plan_rules.sh && bash tests/test_inspect.sh
- [ ] T014 [US1] Live run L1 and both edge runs (quickstart section 4) on this laptop. Start the lane by typing `/stratum:st-design`. Record in `specs/011-custom-design-mode/research.md` R16: the questions, the stop count between "good" and the gate, the three changes in the gate screenshots, the committed paths, `git status` after, the window-closed run and the port-in-use run. SC-001, SC-002, SC-003, SC-005. Test: quickstart section 4 L1 (by hand)

**Checkpoint**: a new screen goes from grill to commit through one FigCraft stop.

---

## Phase 4: User Story 2 - Redesign a screen that already exists (Priority: P1)

**Goal**: `/stratum:st` sends custom design on an existing screen to the Design lane, and the first design is the current screen. Texts written in T011 and T013.

**Independent Test**: quickstart section 4 L2.

- [ ] T015 [US2] Live run L2 (quickstart section 4). Record in `specs/011-custom-design-mode/research.md` R16: the lane line, the first design against the current screen, and the rebuilt screen's diff. FR-002, FR-006. Test: quickstart section 4 L2 (by hand)

---

## Phase 5: User Story 3 - Changes at the gate, in the tool or in code (Priority: P2)

**Goal**: each gate change goes the way the user names, or by the default rule. Text written in T013.

**Independent Test**: quickstart section 4 L3.

- [ ] T016 [US3] Live run L3 (quickstart section 4). Record in `specs/011-custom-design-mode/research.md` R16: which change stopped in FigCraft, which went to code, and the gate after each. FR-013. Test: quickstart section 4 L3 (by hand)

---

## Phase 6: User Story 4 - FigCraft as an optional tool (Priority: P3)

**Goal**: `st-init` offers FigCraft and its allow rule, `st-status` shows it as optional, and only custom runs check it.

**Independent Test**: quickstart section 4 L4.

- [ ] T017 [US4] Add the US4 rows of contract section 9 (`C-FR-017`) to `tests/test_design_lane.sh`, both D22/D23 allow-rule rows included. Run it: those red. FR-017, D22, D23. Test: bash tests/test_design_lane.sh
- [ ] T018 [US4] Edit `skills/st-status/SKILL.md` step 4 per contract 7c, and `skills/st-init/SKILL.md` step 10 per contract 7d: the FigCraft offer and, on yes, the D22/D23 merge of each tool name on the Tools line of `skills/st-design/design-tool.md` (the 11 names, in the form T002 recorded) into `permissions.allow` of the project's `.claude/settings.json`, every other key kept. No server-wide `mcp__plugin_stratum_figcraft` entry. Step 12's commit list already holds `.claude/settings.json`. Security: install commands printed, never run (plan S1). Only the 11 tools run without a prompt; `pointer`, `key`, `type_text` and the rest still ask (S6). Then T017's rows are green and `bash tests/test_model_files.sh` stays green (st-init reuses st-status step 4). FR-017. Test: bash tests/test_design_lane.sh && bash tests/test_model_files.sh
- [ ] T019 [US4] Live run L4 (quickstart section 4). Record in `specs/011-custom-design-mode/research.md` R16: the offer, the command printed, the 11 names in `permissions.allow` of `.claude/settings.json` (and no server-wide entry), the custom stop with the link, the new-look run that went on, and the status lines. SC-004. Test: quickstart section 4 L4 (by hand)

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T020 Live run L5 on the PC (SC-006): `git pull`, quickstart section 0 with the PC's package manager, then L1. PC not reachable: `Not run, PC not reachable`, and the user runs it before the PR merges. Record in `specs/011-custom-design-mode/research.md` R16. Test: quickstart section 4 L5 (by hand)
- [ ] T021 Check that the built texts match contract sections 1 to 7 and every phrase row (lessons L14). Fix drift in `specs/011-custom-design-mode/contracts/custom-mode.md`, not in the built files, unless the built text is wrong. Run the touched suites once more and `git status` (no leftovers). Test: bash tests/test_figcraft.sh && bash tests/test_design_check.sh && bash tests/test_design_lane.sh && bash tests/test_plan_rules.sh && bash tests/test_inspect.sh && bash tests/test_model_files.sh && claude plugin validate .claude-plugin/plugin.json

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1: T001 and T002 need nothing and run their probes side by side, each in its own scratch folder (`<s3>` and `<s2>`, quickstart S3 and S2). Only after both probes end, each records its result in research.md and the contract, one at a time. T003 is the user's install. T004 needs T003. T005 needs T004 (it reads T004's `design/s1.figcraft`).
- Phase 2 needs T001, T002, T004 and T005 (their results can change the contract).
- Phase 3 needs Phase 2. Phases 4 and 5 need T013 (their texts) and run after T014. Phase 6 needs T013 (it adds rows to `tests/test_design_lane.sh` after T012 and T013 wrote it).
- Phase 7 needs the stories it re-runs (T020 needs US1; T021 needs all).

### User Story Dependencies

- US2 and US3 have no edit tasks: their texts land in T011 and T013, so their live runs follow US1.
- US4 shares only `tests/test_design_lane.sh` with US1. It needs T013, so it runs after T012 and T013 have written that file, not at the same time.
- No two stories run at the same time.

### Within Each Story

- The test task, then the build task, then the live run.

### Parallel Opportunities

- Phase 2: T006, T007 and T010 run at the same time (three test files, no shared result).
- Nothing else: every other task shares a file or needs an earlier result.

## Parallel Example: Phase 2

```text
T006 tests/test_figcraft.sh      (owns tests/test_figcraft.sh)
T007 tests/test_design_check.sh  (owns tests/test_design_check.sh)
T010 tests/test_design_lane.sh   (owns tests/test_design_lane.sh)
then T008 -> T009, and T011
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 spikes. Stop on any fail and get the user's pick.
2. Phase 2.
3. US1 (T012 to T014). Stop and show L1 to the user.

### Incremental Delivery

The US2 live run (the user's most common use), then US3's, then US4, then the PC run and the drift
check.

## Notes

- 21 tasks: Phase 1: 5, Phase 2: 6, US1: 3, US2: 1, US3: 1, US4: 3, Polish: 2.
- No open decisions. D22 and D23 (decisions.md) settle the FigCraft allow rule: the 11 tool names.
