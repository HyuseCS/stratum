---

description: "Tasks for the Design lane (009)"
---

# Tasks: Design Lane

**Input**: `/specs/009-design-lane/` plan.md, spec.md, research.md, data-model.md,
contracts/design-lane.md, quickstart.md

**Tests**: Required. Every FR has a check that can fail, written before the task that builds it.
Texts and phrase rows are in contracts/design-lane.md. Red states are in quickstart section 1.

**Organization**: Setup and Foundational (tool check, vendoring, engine) carry no story label. Then
one phase per story in spec order. US4 comes last because its routing row sends work to a lane
that must exist first.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: touches no file another open task touches.
- Run every test with `PYTHONDONTWRITEBYTECODE=1` and leave no file behind (lessons L8).
- Each task's commit: the `st-git` agent commits the exact paths the task names.

## Phase 1: Setup (tool check and vendoring)

- [ ] T001 [P] Write `tests/test_design_check.sh` with cases K1 to K11 of contracts section 7 (`root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"`, stubs in `mktemp -d`, `PATH=<stub dir>` only, the whole output asserted per case). Run it: every K case red because `scripts/st-design-check.sh` does not exist. FR-015, SC-005 (lessons L1, L8)
- [X] T002 Build `scripts/st-design-check.sh` per contracts section 4 until `bash tests/test_design_check.sh` is green. Add `bash tests/test_design_check.sh` to the Tests block and the `puppeteer-core` row to Requirements in `README.md`. Run negative controls N1 and N2 (quickstart section 2). FR-015, SC-005 (lessons L2)
- [ ] T003 [P] Create `tests/test_design_lane.sh` in the frame of `tests/test_on_demand.sh` (`root="${ST_ROOT:-...}"`) with the `FR-017 lock` and `FR-017 copy` checks and the `FR-017 THIRD_PARTY_NOTICES.md` phrase row of contracts section 6. Run it: those three red. FR-017 (lessons L1)
- [x] T004 Vendor hallmark. Security: external code that runs on the user's machine (plan S1). Pin `7ec868225c6caa040558c321ee0fefa0e73f83a8`, the code S1 reviewed. If `gh api repos/nutlope/hallmark/commits/main --jq .sha` gives another sha, stop and report it before any copy. Download that tree's `skills/hallmark/` into a new empty scratch folder and copy it whole to `skills/st-hallmark/`. In `skills/st-hallmark/SKILL.md` change only the frontmatter: `name: hallmark` to `name: st-hallmark`, and add `disable-model-invocation: true` (D22). Write `licenses/hallmark.MIT.txt` (upstream root `LICENSE` at that sha), the `vendor.lock` entry with that sha, and the `THIRD_PARTY_NOTICES.md` row and change bullet (contracts section 5). Add `bash tests/test_design_lane.sh` to the README Tests block. Add `st-hallmark` to the README design skills row and `hallmark` to the README duplicate installs list. Add `st-hallmark` to the forked tools list in `DESIGN.md` D9. Run quickstart section 3. Then `bash tests/test_design_lane.sh` FR-017 rows and `bash tests/test_inspect.sh` are green. Run negative control N10. Record the sha in research.md R4. FR-017, FR-018

## Phase 2: Foundational (the engine file)

- [ ] T005 Add to `tests/test_design_lane.sh`: the `FR-010 one place` check, the `FR-008 map` check (62 ids, 35 on `ignore:` and 27 on `keep:`, none twice, none on both lines, the 16 detector-only ids of research R12 on `keep:`), and the `skills/st-design/engine.md` rows (FR-008, FR-016). Run it: these red. FR-008, FR-010, FR-016 (lessons L1, L7)
- [ ] T006 Write `skills/st-design/engine.md` from contracts section 2. Copy the `ignore:` line (35 ids) and the `keep:` line (27 ids) from contracts section 2 as written. If no engine binary is on this machine, the user first runs `skills/st-impeccable/scripts/impeccable engine-probe` once with network (quickstart section 0). Then run `<impeccable> detect --json --no-config` on a scratch copy of `skills/st-hallmark/scripts/fixtures/`, outside the repo. Record the ids that fire in research R12, and check that each one is on a map line. Then `bash tests/test_design_lane.sh` T005 rows are green. Run negative controls N5 and N6. FR-008, FR-010, FR-016, D21 (lessons L2)

## Phase 3: User Story 1 - A new look, made with the user (Priority: P1) MVP

**Goal**: grill, theme pick, `DESIGN.md` confirmed, one reference screen built and checked, one gate, commit.

**Independent Test**: quickstart L3 and L8.

- [ ] T007 [US1] Add to `tests/test_design_lane.sh` the `FR-001` checks (skill and agent frontmatter, one start each) and the contract section 6 rows for FR-001, FR-003, FR-004, FR-006, the `skills/st-design/SKILL.md` FR-008 rows, FR-009, FR-011, FR-012, FR-013, FR-014 (`Only after ...`), the `skills/st-design/SKILL.md` FR-015 rows, the FR-016 skill row and both FR-018 rows. Change `tests/test_inspect.sh` to `15 agents` and the rename phrase `Show a table of the 15 agents`. Add `"st-design"` after `"st-debug"` in `tests/test_model_hook.py` `test_module_constants`, and a case where a `.stratum/models.json` holding only `st-design` does not deny a `stratum:st-design` start (lessons L35). Run all three: the new rows, `15 agents`, `test_module_constants` and the new `st-design` case red. One task, because these checks share files with T008 (lessons L6). FR-001, FR-003, FR-004, FR-006, FR-008, FR-009, FR-011 to FR-016, FR-018
- [ ] T008 [US1] Write `skills/st-design/SKILL.md` from contracts section 1, all of it but section 3 "Autonomous" (T011 and T014 add it). Write `agents/st-design.md` from contracts section 3, with the `[PONYTAIL]` paragraph copied from `agents/st-build.md`. Change `skills/st-init/SKILL.md` to `Show a table of the 15 agents`. Add `st-design` to the Agents line of `skills/st-model/SKILL.md`. Add to `README.md`: the `st-design` skill row, the agent row and the two model override lists. Add to `DESIGN.md`: the D7 row, `Twenty-five entry skills` and the D9 row. Security: secrets (`TOGETHER_API_KEY` never read or asked for, plan S3), untrusted input (`DESIGN.md` as data, S4), external service (Wikimedia photos, Together AI only with the user's key, S2), no code behind the screen (S5), model file names (S6). Then T007's rows and every suite of quickstart section 1 are green. The commit line for generated files says "if they changed" (lessons L18). FR-001, FR-003, FR-004, FR-006, FR-008, FR-009, FR-011 to FR-016, FR-018 (lessons L6, L14)
- [ ] T009 [US1] Live runs L3 (SC-001) and L8 (quickstart section 4). Start the lane by typing `/stratum:st-design` (lessons L12). Record each in research.md R15: the questions asked, the themes dealt, the stops counted, the check results per round, no live server left, and the committed paths. If a run fails, write `Not run, <first error line>` beside the tick. SC-001, FR-006, FR-008 (lessons L32)

## Phase 4: User Story 2 - A new page in the existing look (Priority: P1)

**Goal**: autonomous build with no question, or one message for a vague request, then report and commit on OK.

**Independent Test**: quickstart L4 and L5.

- [ ] T010 [US2] Add the FR-007 rows and the FR-014 row `report again before any commit` to `tests/test_design_lane.sh`. Run: those red. FR-007, FR-014
- [ ] T011 [US2] Add section 3 steps 2 and 3 ("Autonomous") of contracts section 1 to `skills/st-design/SKILL.md`. Then T010's rows are green. FR-007, FR-009, FR-013, FR-014 (lessons L14)
- [ ] T012 [US2] Live runs L4 (SC-002, with the change after the report, FR-014) and L5 (SC-003). Record them in research.md R15 with the message count, the report sections, and `.impeccable/config.local.json` before and after. SC-002, SC-003 (lessons L32)

- [ ] T020 [US2] Live run L9 (quickstart section 4): a scratch Vite project with `vitest` and `@testing-library/dom`. The user starts its dev server. Record in research.md R15 the tests written, their result, and the report's test list. FR-013 (lessons L32)

## Phase 5: User Story 3 - A look in the code, no design file (Priority: P2)

**Goal**: the grill starts from the look in the code, and the user confirms the file, once per project.

**Independent Test**: quickstart L6.

- [ ] T013 [US3] Add the FR-005 rows to `tests/test_design_lane.sh`. Run: those red. FR-005
- [ ] T014 [US3] Add section 3 step 1 of contracts section 1 to `skills/st-design/SKILL.md`. Then T013's rows are green. FR-005, FR-004 (lessons L14)
- [ ] T015 [US3] Live run L6. Record it in research.md R15, including that the second request runs no grill. FR-005 (lessons L32)

## Phase 6: User Story 4 - Getting into the lane, and its tools (Priority: P2)

**Goal**: `/stratum:st` routes a new look or a new screen to Design. `st-status` and `st-init` run the same tool check. `st-sync` rechecks the detector map.

**Independent Test**: quickstart L1, L2, L7, and the routing runs in T018.

- [ ] T016 [US4] Add to `tests/test_design_lane.sh` the FR-002 rows, the `skills/st-status/SKILL.md` FR-015 row, and the FR-017 `skills/st-sync/SKILL.md` row. Run: all red. `st-init`'s reuse of `st-status` step 4 is checked by `tests/test_model_files.sh:27`. FR-002, FR-015, FR-017
- [ ] T017 [US4] Edit `skills/st/SKILL.md` (description, Design row, say line, run line), `skills/st-status/SKILL.md` (step 4 sentence, step 5 list) and `skills/st-sync/SKILL.md` (new step 5, then renumber), per contracts section 5. Add to `README.md` the Lanes row and the Design lane line. Add the D10 row to `DESIGN.md`. Then T016's rows and quickstart section 1 are green. Run negative controls N3, N4 and N7. FR-002, FR-015, FR-017 (lessons L2, L14)
- [ ] T018 [US4] Live runs. L1 and L2: first run `npm rm -g puppeteer-core` if it is installed, then `npm i -g puppeteer-core` after. L7. Routing: `/stratum:st add a pricing page` says `Lane: design (...)`, `/stratum:st fix the header spacing on the home page` says Fast or Quick, and "fast" overrides the first one. Record all in research.md R15. FR-002, FR-015, SC-005 (lessons L32)

## Phase 7: Polish

- [ ] T019 Run quickstart sections 1, 2 (N1 to N10; before each break, the real file is green on the same copy) and 3. Record the results in research.md R15, with the fix-round count of each live run. If no live run reached fix round 2, write `Not run, no check failed after round 1` for the FR-008 cap and say it is checked as text only (lessons L24). Check `git status --porcelain --untracked-files=all` lists only this feature's files. SC-004 (lessons L2, L20, L25, L8)

## Dependencies

- T001 before T002. T003 before T004. T005 needs T003, because it adds to the file T003 creates. T005 before T006.
- T007 needs T004 and T006, because the FR-010 check reads `skills/st-design/`. T008 follows T007.
- US2 (T010 to T012, T020) and US3 (T013 to T015) follow T008, because they edit the same skill file. Do them one after the other.
- US4 (T016, T017) needs T008, because the routing row points to `/stratum:st-design`. T018 needs T017.
- Live runs (T009, T012, T015, T018, T020) need `puppeteer-core` installed, except L1 and L2.
- T019 is last.

## Parallel Opportunities

- T001 and T003 write different new files. Start them in one message.
- Every other task shares `tests/test_design_lane.sh`, `skills/st-design/SKILL.md` or `README.md` with another task, so they run one after the other (lessons L6).

## Implementation Strategy

1. MVP: Phases 1 to 3 (T001 to T009). A new look works end to end when you call `/stratum:st-design` directly.
2. Then US2 (the user's main way of working), then US3, then US4 routing.
3. Stop after each story and run its live run before the next one.

## Notes

- A conditional task whose condition is false gets `Not run, <reason>.` beside its tick (lessons L24).
- No `[P]` task shares a test file with another open task (lessons L6).
