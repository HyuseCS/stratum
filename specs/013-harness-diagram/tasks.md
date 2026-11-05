---

description: "Task list for 013-harness-diagram"
---

# Tasks: Harness Diagram

**Input**: Design documents from `specs/013-harness-diagram/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Test first. `tests/test_harness_model.sh` (T001) covers every FR and fails before any
model file exists. Every later task names the checks of that script that prove it.

**Organization**: Tasks are grouped by user story. US2 (model) comes before US1 (views and page)
because the page needs the model. Both are P1, and their file tasks run at the same time (see
Dependencies).

## Format: `- [ ] T### [P?] [Story] What. Owns: <files, [P] only>. Test: <cmd>.`

- **[P]**: no shared file in the phase and no other task's result. The task ends with `Owns:`.
- **[lock]**: none in this feature. The test writes only in `mktemp -d` folders.
- **[screen]**: none in this feature.
- Run every command from the repo root.

## Rules for every model and view task (T003 to T010, T013 to T017)

- Write the exact text shape of [contracts/model-format.md](contracts/model-format.md), with ids,
  kinds and titles from [data-model.md](data-model.md). No backtick in a `.c4` file. No `<` or `>`
  in a title, summary or label.
- Read the source file of each element before you write its summary or its links. Do not use
  README.md alone. A link comes from the file whose text gives the instruction or holds the code.
- Summaries: 1 or 2 short sentences in plain words, at most 200 characters.
- Links: one per line, fully qualified ids, a kind from the 5, a label that names the data, and no
  tags (D12: lane membership is only in the lane views).
- Draw only what exists now (FR-014). Do not change any skill, agent, hook, script, procedure,
  statusline or template file.
- A target that the registry does not list: use the id that the id rule gives, do not declare it,
  and name it under "Unregistered ids" in your report.
- A gap you see (a step that says one thing in one file and another in another, a file nothing
  reads): do not draw it. Name it under "Gaps" in your report with `file:line` (D5).
- Your per-task test cannot run `likec4 validate`, because links point into files that other tasks
  write. T018 runs it.

---

## Phase 1: Setup (test first)

**Purpose**: the test exists and fails before any model file exists.

- [ ] T001 Write `tests/test_harness_model.sh` as [contracts/test-contract.md](contracts/test-contract.md) says: the checks `coverage` (with `coverage-skills`, `coverage-agents`, `coverage-hooks`, `coverage-statusline`, `coverage-scripts`, `coverage-procedures`, `coverage-data`), `missing`, `summaries`, `links`, `kinds`, `vendored`, `views`, `page`, `readme`, `nomcp`, `validate`, `rebuild`; check names as arguments; `ST_ROOT`; one version variable `v=1.60.0`; `ok`/`FAIL`/`SKIP` lines; exit 1 on any FAIL; SKIP for `validate` and `rebuild` only when `npx` is not on PATH or `node --version` is below 22.22.3 (D9); temp files only in `mktemp -d` with `trap`. Use the `.stratum` grep of research R10 (same as `tests/test_local_files.sh`). Security: it runs `npx` from the npm registry (plan.md Security notes). Test: `bash tests/test_harness_model.sh; test $? -eq 1` (must fail now: no model, with `FAIL coverage-skills` lines that name each skill).

---

## Phase 2: Foundational (blocks all stories)

**Purpose**: the project folder, the kinds, the groups and the actors that every other file uses.

- [ ] T002 Write `docs/harness/likec4.config.json` (`{"name": "stratum-harness", "title": "Stratum harness"}`) and `docs/harness/model/0-spec.c4`: the specification block of model-format.md exactly; the 12 groups and the 6 actors of data-model.md, each with a title and a summary (Codex: the OpenAI CLI that reviews at the advisor points, read-only; `/advisor`: the reviewer model the user sets in Claude Code; read `README.md` "Advisor" and `scripts/st-advisor.sh` for both). Depends on T001 (its test uses T001's script). Test: `bash tests/test_harness_model.sh kinds summaries links && npx -y likec4@1.60.0 validate docs/harness`.

**Checkpoint**: `0-spec.c4` validates alone. US2 and US1 file tasks can all start.

---

## Phase 3: User Story 2 - An LLM reads the whole harness (Priority: P1)

**Goal**: every skill, agent, hook, script, statusline file, procedure and data file is one element
with a summary, and every link has a kind and a data label.

**Independent Test**: `bash tests/test_harness_model.sh coverage missing summaries links kinds vendored`
prints only `ok`. Then quickstart.md section 3: the LLM's list of the steps that write
`.stratum/state.json` matches the grep.

- [ ] T003 [P] [US2] Write `docs/harness/model/skills-core.c4`: the 10 skills of the `skills-core.c4` row in data-model.md, from `skills/<name>/SKILL.md` (for `st-design` also `skills/st-design/engine.md` and `skills/st-design/design-tool.md`), and every link whose source is one of them: the agents and skills each starts, the scripts each runs (`st-advisor.sh`, `st-verify.sh`, `st-state.sh`, `st-design-check.sh`, `st-worker.sh` ...), the procedures each follows, the files each reads or writes, and what each passes to `user`, `codex`, `advisor`, `git`, `github`. Owns: `docs/harness/model/skills-core.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored`.
- [ ] T004 [P] [US2] Write `docs/harness/model/skills-tools.c4`: the 19 skills of the `skills-tools.c4` row in data-model.md, from `skills/<name>/SKILL.md`, and every link whose source is one of them. Owns: `docs/harness/model/skills-tools.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored`.
- [ ] T005 [P] [US2] Write `docs/harness/model/skills-vendored.c4`: the 11 vendored skills of data-model.md, each with `#vendored` as the first line of its block (FR-008), from `skills/<name>/SKILL.md`, and every link whose source is one of them (for example what `st-graphify` writes to `project.graphify-out`, what `st-impeccable` writes to `project.impeccable`). Owns: `docs/harness/model/skills-vendored.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored`.
- [ ] T006 [P] [US2] Write `docs/harness/model/agents.c4`: the 15 agents of data-model.md, from `agents/<name>.md`, and every link whose source is an agent: the files each reads (`sr-opus-5.md`, `graphify-out/GRAPH_REPORT.md`, procedures, feature files) and writes, the scripts each runs, and the report each passes back to the skill that starts it. Owns: `docs/harness/model/agents.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored coverage-agents`.
- [ ] T007 [P] [US2] Write `docs/harness/model/hooks.c4`: the 7 events, the 17 hook files and the 3 statusline files of data-model.md, from `hooks/commands.json`, `hooks/hooks.json`, each file under `hooks/` and `hooks/ponytail/`, and each file under `statusline/`. Links: `claude -[reads]->` `hooks.commands-json` and `hooks.hooks-json`; one `events.<event> -[runs]-> hooks.<file>` link per event and hook pair with the matcher in the label (research R11: `st-approve.py`, `st-phase.py` and `st-handoff-facts.sh` get one link per event); `claude -[runs]-> statusline.st-statusline-sh`; and every link whose source is a hook or statusline file (the `.stratum` files each reads or writes, the ponytail modules each loads). Owns: `docs/harness/model/hooks.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored coverage-hooks coverage-statusline`.
- [ ] T008 [P] [US2] Write `docs/harness/model/scripts.c4`: the 15 scripts of data-model.md, from `scripts/<file>`, and every link whose source is a script: the files each reads and writes, the scripts each runs (`common.sh` sourced counts as `runs`), what `st-advisor.sh` and `st-codex-agent.sh` pass to `codex` and `advisor`, and the verdict each passes back, plus `codex -[passes]-> scripts.st-advisor-sh` for the answer (actor source, target in this file). Owns: `docs/harness/model/scripts.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored coverage-scripts`.
- [ ] T009 [P] [US2] Write `docs/harness/model/procedures.c4`: the 9 procedures of data-model.md, from `procedures/<file>`, and every link whose source is a procedure: the scripts each runs (`check-prerequisites.sh`, `resolve-template.sh`), the templates each reads, the feature and `.stratum` files each writes (for example `procedures/specify.md` writes `feature.spec-md`, `feature.checklists` and `stratum.state-json`). Owns: `docs/harness/model/procedures.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored coverage-procedures`.
- [ ] T010 [P] [US2] Write `docs/harness/model/data.c4`: the 15 `.stratum` files, the 12 feature files, and each `project`, `plugin` and `outside` file of data-model.md that a harness source file names (grep `skills agents hooks scripts statusline procedures` for it first; skip one that no file names). Each summary says what the file holds and who owns it (read the `DESIGN.md` D13a table and the code that reads the file). Links whose source is an actor and whose target is in this file: `user -[writes]-> stratum.worker-setup-sh`, `claude -[reads]-> plugin.claude-plugin-plugin-json`, and others the sources show. Owns: `docs/harness/model/data.c4`. Test: `bash tests/test_harness_model.sh summaries links missing vendored coverage-data`.
- [ ] T011 [US2] Run the US2 checks on the whole model and fix each FAIL in the file that owns the element: `bash tests/test_harness_model.sh coverage missing summaries links kinds vendored`. Then check 10 links against their source, 2 per kind, with `file:line`, and fix a wrong one. Then run quickstart.md section 3 grep for `stratum.state-json` and add any `writes` link that is missing. Depends on T003 to T010. Test: `bash tests/test_harness_model.sh coverage missing summaries links kinds vendored`.

**Checkpoint**: the model is complete. It may not validate yet if views or unregistered ids are missing (T018).

---

## Phase 4: User Story 1 - See how each lane works (Priority: P1)

**Goal**: one numbered view per lane, three topic views, and the page that GitHub draws, linked
from the main README.

**Independent Test**: quickstart.md section 2: the 7 views draw on GitHub, and a reader names the
Full lane's phases and gates in order in under 2 minutes.

- [ ] T012 [P] [US1] Add a `## Harness diagram` section to `README.md`, after `## Project files`: a link to `docs/harness/README.md` and what its 7 views show; how to edit (`docs/harness/model/*.c4` for elements and links, `docs/harness/views/*.c4` for views, drag in the VS Code LikeC4 preview saves to `docs/harness/.likec4/`); how to check (`npx -y likec4@1.60.0 validate docs/harness`, `bash tests/test_harness_model.sh`); how to rebuild (`npx -y likec4@1.60.0 export markdown docs/harness`, then commit the page); that it needs Node 22.22.3 or later; the one-time MCP command `claude mcp add --scope user likec4 -- npx -y @likec4/mcp@1.60.0` with one line that says user scope starts the server in every project the user opens; that an LLM can also read the `.c4` text or run `npx -y likec4@1.60.0 export json docs/harness`. Add `bash tests/test_harness_model.sh` to the `## Tests` list. The new section has no table row that starts with a backtick and `st` (`tests/test_inspect.sh` "README skills" reads such rows as skills). Commit `README.md` together with T018's page or after it, never before: the link makes the "README paths" check of `tests/test_inspect.sh` fail until `docs/harness/README.md` exists. Security: the MCP note (plan.md Security notes). Owns: `README.md`. Test: `bash tests/test_harness_model.sh readme nomcp`.
- [ ] T013 [P] [US1] Write `docs/harness/views/1-full.c4`: dynamic view `full`, title `Full lane`. Read `skills/st/SKILL.md`, `skills/st-full/SKILL.md`, `skills/st-define/SKILL.md`, `skills/st-plan/SKILL.md`, `skills/st-inspect/SKILL.md`, `skills/st-build/SKILL.md`, `skills/st-close/SKILL.md`, and the procedures and agents they name. Steps in order: Define, Plan, Inspect, Build (per task: test, build, verify, debug after 2 tries, advisor points; per story: review; screen tasks go to `/st-design`), Close, with each gate as `(n) gate: <what the user says>` (at least 3) and the data passed on each step. Owns: `docs/harness/views/1-full.c4`. Test: `bash tests/test_harness_model.sh views`.
- [ ] T014 [P] [US1] Write `docs/harness/views/2-fast.c4`: dynamic view `fast`, title `Fast lane`, from `skills/st-fast/SKILL.md` steps 1 to 10, `agents/st-fast.md` and the agents it starts; the change-plan gate as `(n) gate: ...`. Owns: `docs/harness/views/2-fast.c4`. Test: `bash tests/test_harness_model.sh views`.
- [ ] T015 [P] [US1] Write `docs/harness/views/3-quick.c4`: dynamic view `quick`, title `Quick lane`, from `skills/st-quick/SKILL.md`, `agents/st-quick.md` and the Quick bullet of `skills/st/SKILL.md` section 2 (one file to the `st-quick` agent; a few files to the `st-build` agent in brief mode; verify; `st-git` commits). Owns: `docs/harness/views/3-quick.c4`. Test: `bash tests/test_harness_model.sh views`.
- [ ] T016 [P] [US1] Write `docs/harness/views/4-design.c4`: dynamic view `design`, title `Design lane`, from `skills/st-design/SKILL.md`, `skills/st-design/engine.md`, `skills/st-design/design-tool.md` and `agents/st-design.md`. Show the three modes (new look, autonomous, custom) in that file's order, each gate as `(n) gate: ...`. Owns: `docs/harness/views/4-design.c4`. Test: `bash tests/test_harness_model.sh views`.
- [ ] T017 [P] [US1] Write the three topic views with the include rules of model-format.md "Topic views": `docs/harness/views/5-agents.c4` (view `agents`, title `Agents`), `docs/harness/views/6-harness.c4` (view `harness`, title `Harness`: hooks by event, statusline, advisors and risk level), `docs/harness/views/7-dataflow.c4` (view `dataflow`, title `Data flow`). Owns: `docs/harness/views/5-agents.c4`, `docs/harness/views/6-harness.c4`, `docs/harness/views/7-dataflow.c4`. Test: `bash tests/test_harness_model.sh views`.
- [ ] T018 [US1] Integrate and make the page. Declare each unregistered id that T003 to T010 reported in `docs/harness/model/data.c4` (id rule of data-model.md, with a summary and `path` or `data`). Run `npx -y likec4@1.60.0 validate docs/harness` and fix each error in the file that owns it. Run `npx -y likec4@1.60.0 export markdown docs/harness` to write `docs/harness/README.md`. Check that each Mermaid block is under 50,000 characters and 500 edges. If Data flow is over, split it as model-format.md says and update the `page` check headings in `tests/test_harness_model.sh` in the same change. Depends on T002 to T017. Test: `bash tests/test_harness_model.sh validate rebuild page views links summaries missing`.

**Checkpoint**: the page is committed and every check except the US3 checks by hand passes.

---

## Phase 5: User Story 3 - The developer edits the diagram (Priority: P2)

**Goal**: drag and save works, the README notes work, and the MCP server sees the model in a worktree.

**Independent Test**: quickstart.md sections 4, 5 and 6.

- [ ] T019 [P] [US3] Check by hand with the user: quickstart.md section 5. The user first installs the LikeC4 VS Code extension `likec4.likec4-vscode` (`code --install-extension likec4.likec4-vscode`; the PC does not have it today). Then drag one box in the VS Code LikeC4 preview, save, reopen). If the user keeps the layout, it is `docs/harness/.likec4/full.likec4.snap`. If the box does not stay, report it: it is a spec gap for US3 scenario 1, not a fix in this task. Owns: `docs/harness/.likec4/`. Test: `bash tests/test_harness_model.sh nomcp rebuild`.
- [ ] T020 [P] [US3] Check by hand with the user: quickstart.md section 4 in a copy, so the repo stays as it is while T021 copies it (`c=$(mktemp -d); cp -r docs/harness "$c/h"`, edit the label of one `starts` link in `$c/h/model/agents.c4` or a skills file (the Agents view draws it), `npx -y likec4@1.60.0 validate "$c/h"`, `npx -y likec4@1.60.0 export markdown "$c/h"`, `diff docs/harness/README.md "$c/h/README.md"` shows only that label, `rm -rf "$c"`) and section 6 (the user adds the MCP server once, then a session in a worktree lists the 7 views). If the server finds no project, report it with the error text. A change to the README command is a decision for the user. Owns: none (checks by hand and in a temp copy). Test: `bash tests/test_harness_model.sh rebuild`.

---

## Phase 6: User Story 4 - The model does not drift (Priority: P2)

**Goal**: proof that the test goes red for each kind of drift.

**Independent Test**: each negative control gives its expected line.

- [ ] T021 [US4] Run each negative control in [contracts/test-contract.md](contracts/test-contract.md) "Negative controls" in a fresh copy (`c=$(mktemp -d); cp -r . "$c/r"`, change the copy, `ST_ROOT="$c/r" bash tests/test_harness_model.sh <checks>`, `rm -rf "$c"`). For the `PATH` control use `env PATH=<a folder with bash, python3, grep, coreutils and no npx>`. For the two Node controls put a folder first on `PATH` with an executable `node` that runs `[ "$1" = --version ] && echo v22.22.2 || exec <real node> "$@"` (then `v22.9.0`). Each must print its expected line and the right exit code. If one does not, fix `tests/test_harness_model.sh` and run all controls again. Depends on T018. Test: `bash tests/test_harness_model.sh` (on the unchanged repo: exit 0) and the 15 control commands of the table.

---

## Phase 7: Polish

- [ ] T022 [P] Write `specs/013-harness-diagram/gaps.md` (D5): a short list of the gaps that T003 to T017 reported, each with its `file:line`. It is a side note, not linked from `README.md` or `docs/harness/`. Owns: `specs/013-harness-diagram/gaps.md`. Test: `test -s specs/013-harness-diagram/gaps.md && ! grep -rn '013-harness-diagram/gaps' README.md docs/harness` (the page draws the generic `specs/NNN-feature/gaps.md` element, so only this feature's file name counts).
- [ ] T023 [P] Run quickstart.md sections 1, 3 and 7: the whole harness test, the `state.json` writers compared with the grep (SC-004), and no change under `skills agents hooks scripts statusline procedures templates .claude-plugin` (FR-014). Report each result. Also run the two repo tests that read `README.md` and `.stratum` names. Owns: none. Test: `bash tests/test_harness_model.sh && bash tests/test_inspect.sh && bash tests/test_local_files.sh && test -z "$(git diff --stat main...HEAD -- skills agents hooks scripts statusline procedures templates .claude-plugin)"`.

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (T001): first. The test must fail before any model file exists.
- Foundational (T002): after T001. Blocks every story.
- US2 file tasks T003 to T010 and US1 file tasks T012 to T017: all start after T002, at the same
  time. They share no file. Ids are fixed in data-model.md, so none needs another's result.
- T011: after T003 to T010.
- T018: after T011 and T012 to T017. It is the first task that runs `likec4 validate`. T012's
  `README.md` is committed with T018's page or after it (`tests/test_inspect.sh` "README paths").
- US3 (T019, T020) and US4 (T021): after T018. They share no file, so they run at the same time.
- Polish (T022, T023): after T018 to T021.

### User Story Dependencies

- US2 (P1): needs only Foundational.
- US1 (P1): its file tasks need only Foundational. Its page (T018) needs US2, because the page is
  drawn from the model. US1 and US2 share no files: run them at the same time.
- US3 (P2) and US4 (P2): need the page (T018). US3 and US4 share no files: run them at the same time.

### Within Each Story

- The test (T001) is written and fails before any model or view file.
- Per-task tests check one file's shape. `validate` and `rebuild` run first in T018.

## Parallel Example

```text
After T002, start these 14 tasks together (no shared file):
T003 model/skills-core.c4      T004 model/skills-tools.c4    T005 model/skills-vendored.c4
T006 model/agents.c4           T007 model/hooks.c4           T008 model/scripts.c4
T009 model/procedures.c4       T010 model/data.c4            T012 README.md
T013 views/1-full.c4           T014 views/2-fast.c4          T015 views/3-quick.c4
T016 views/4-design.c4         T017 views/5-agents.c4, 6-harness.c4, 7-dataflow.c4
Then T011, then T018. Then T019, T020 and T021 together.
```

## Implementation Strategy

### MVP

T001, T002, US2 (T003 to T011), then US1 (T012 to T018). Stop and run quickstart.md sections 1 to 3.
Both P1 stories make the MVP: the page has no value without the model, and the model without
the page fails US1.

### Incremental Delivery

1. Test, then foundation.
2. Model and views in one wave, then T011 and T018: MVP.
3. US3 and US4 checks.
4. Gap note and quickstart run.

## Notes

- Commit after each task or group (the orchestrator commits, exact paths).
- `docs/harness/README.md` is only ever written by `likec4 export markdown`.
- No task changes a skill, agent, hook, script, procedure, statusline or template file (FR-014).
