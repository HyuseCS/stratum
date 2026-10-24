# Implementation Plan: Design Lane

**Branch**: `009-design-lane` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/009-design-lane/spec.md`, decisions D1 to D25 in
[decisions.md](decisions.md), GitHub issue #49.

**Status**: D20 (O35) and D21 (O39) decided 2026-10-24. The detector map is final (research R12).

## Summary

A new lane, `/stratum:st-design`. The skill runs in the main session. It runs the tool check and
the dev server probe, then picks the mode (new look or autonomous). It grills the user for the
design file: in a new look the grill includes a theme branch, where hallmark deals 3 themes and
scaffolds the picked one's tokens (D20). It may instead ask the one vague-request message. It has
`st-impeccable document` scan and write `DESIGN.md`, and starts the new `st-design` agent for the
build. The skill runs the two impeccable checks itself: audit dimensions 1 and 2, and critique in
full with its detector. Critique cannot run in full inside a subagent (research R13). The
detector ignores the rules the lint owns through `impeccable ignores --local`, added before and
removed after (D21, research R12). The skill counts at most 2 fix rounds, shows the gate or the
report, and has `st-git` commit the exact paths. The agent reads the engine's skill file and builds the screen
as a frontend engineer with placeholder data. It writes and runs component tests, runs the lint
and the render check (one engine run, research R2), and reports.

Hallmark is vendored as `skills/st-hallmark/` and pinned in `vendor.lock`. The lane names it in
one file only, `skills/st-design/engine.md` (FR-010). One script, `scripts/st-design-check.sh`,
checks node, `puppeteer-core` and Chrome or Chromium for the lane and for `st-status`. `/stratum:st`
gets a Design row. One stub test, `tests/test_design_lane.sh`, covers SC-004 and SC-005.


## Technical Context

**Language/Version**: Markdown (skills, agent, docs), Bash 5.3.20 (script, tests), Python 3.14.8
(one test edit). Vendored hallmark is Node ESM, run by the lane on the user's machine, Node 18 or
later (`references/flow.md:117`). This machine: node v24.14.1, npm 11.11.0.

**Primary Dependencies**: Claude Code 2.1.306 plugin layout (`agents/*.md`, `skills/*/SKILL.md`).
Vendored hallmark 2.0.0 (`nutlope/hallmark@7ec8682`, MIT). Its render tier needs `puppeteer-core`
(user installs, `npm i -g puppeteer-core`) and Chrome or Chromium. `st-impeccable` 4.7.0 as it is
(D1). No new package in Stratum.

**Storage**: Files in the user's project: `DESIGN.md`, `.impeccable/design.json`, the screen,
`tokens.css`, `base.css`, component tests. Untracked: `.hallmark/`, `.impeccable/critique/`
(research R9).

**Testing**: `bash tests/test_design_check.sh` (new, the script's 12 cases; K3, K8, K9 and K10 run
on Linux only, because on macOS or Windows the fixed browser paths find an installed Chrome),
`bash tests/test_design_lane.sh` (new, phrases and checks), `bash tests/test_inspect.sh`,
`bash tests/test_on_demand.sh`, `bash tests/test_session_hooks.sh`, `bash tests/test_model_files.sh`,
`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_model_hook.py`,
`claude plugin validate .claude-plugin/plugin.json`. Demos for SC-001, SC-002, SC-003 by hand
(quickstart).

**Target Platform**: Claude Code on Linux, macOS, Windows (Git Bash). The user's UI runs in a
browser.

**Project Type**: Claude Code plugin (skills, agents, scripts, vendored skill, docs).

**Performance Goals**: N/A. Fix rounds are capped at 2 (FR-008).

**Constraints**: No comments except `ponytail:` markers. Minimal diff. `st-build`, `st-fast`,
`st-full` and every vendored impeccable file unchanged (D1, D10, FR-018). Vendored hallmark files
unchanged except the frontmatter `name` and `disable-model-invocation: true` (D22). The lane never
starts a dev server (research R6) and never prints or asks for `TOGETHER_API_KEY` (FR-016).

**Scale/Scope**: New: `skills/st-design/SKILL.md`, `skills/st-design/engine.md`,
`agents/st-design.md`, `scripts/st-design-check.sh`, `skills/st-hallmark/` (178 upstream files),
`licenses/hallmark.MIT.txt`, `tests/test_design_check.sh`, `tests/test_design_lane.sh`. Edits:
`skills/st/SKILL.md`, `skills/st-status/SKILL.md`, `skills/st-sync/SKILL.md`,
`skills/st-init/SKILL.md`, `skills/st-model/SKILL.md`,
`vendor.lock`, `THIRD_PARTY_NOTICES.md`, `README.md`, `DESIGN.md`, `tests/test_inspect.sh`,
`tests/test_model_hook.py`. 15 agents.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` (base repo). The gates come from the rules the
orchestrator passed and `docs/lessons.md`.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that can fail, placed before its build task | Pass: T001 before T002 (FR-015), T003 before T004 (FR-017, FR-018), T005 before T006 (FR-008, FR-010, FR-016), T007 before T008 (FR-001, FR-003, FR-004, FR-006, FR-008, FR-009, FR-011 to FR-016, FR-018), T010 before T011 (FR-007, FR-014), T013 before T014 (FR-005), T016 before T017 (FR-002, FR-015, FR-017). Red states: quickstart section 1. `st-init`'s reuse of `st-status` step 4 is already checked by `tests/test_model_files.sh:27`, so it has no row |
| G2. Minimal diff: no new dependency in Stratum, no comments, no change to `st-build`, Fast, Full or vendored impeccable | Pass: research R3, R4, R13 |
| G3. One source of truth: one script holds the tool list; one lane file names the engine and holds the detector map | Pass: research R5, R12, FR-010 |
| G4. lessons L1: a phrase check asserts a phrase the file builds | Pass: the 53 rows of contracts section 6 are substrings of the contract texts, none a word of its own path |
| G5. lessons L2, L20, L25: each new check has a negative control, run right after a green baseline | Pass: quickstart section 2, N1 to N10 |
| G6. lessons L6: tasks that share a test file or the agent-count checks are one task, or run in order | Pass: the agent and every list that counts agents are in T007 and T008. Only T001 and T003 are `[P]` |
| G7. lessons L7: list checks read both sides | Pass: README checks are two-way (`tests/test_inspect.sh:111-131`). FR-010: the lane files that name the engine are exactly `skills/st-design/engine.md`. The map check counts 62 ids on both lines |
| G8. lessons L8: test runs leave no files | Pass: both new tests work in `mktemp -d`; K11 and T019 compare `git status` |
| G9. lessons L12: the lane starts through the Skill tool | Pass: live runs type `/stratum:st-design` (T009); the lane loads `st-impeccable` through the Skill tool |
| G10. lessons L14: text changes and the contract's phrase table change in one commit | Pass: named in contracts preamble and in T008, T011, T014, T017 |
| G11. lessons L18: commit lines for generated files say "if they changed" | Pass: contracts section 1, Commit; section 2, Files |
| G12. lessons L24: a conditional task whose condition is false gets `Not run, <reason>.` | Pass: tasks.md Notes, T009 |
| G13. lessons L32: each state path gets a live run before its task is ticked | Pass: T009, T012, T015, T018, T020 cover the tool stop, the dev server stop, both modes, the gate loop, the autonomous change loop, a UI test runner and the routing |
| G14. lessons L11: a background action names its failure states | Pass: the critique live server (research R13): already running, no connection JSON printed, cannot start |
| G15. A helper server's stop leaves the user's project files as they were | Pass: `live-server stop --keep-inject` only; a bare `stop` runs `live-inject --remove` on the entry file (`skills/st-impeccable/reference/live.md:318-321`, `critique.md:79`). Phrase rows `so this form leaves` and `Never a bare \`stop\`` (contracts section 6) |

Post-design re-check: all gates pass. No violations, so Complexity Tracking stays empty.

## Security Notes

- **S1. External code runs on the user's machine (vendoring task, agent task).** The lane runs
  vendored hallmark scripts with `node`: `sloplint.mjs` (231 KB), `sloplint-render.mjs` (launches
  headless Chrome through `puppeteer-core`), `theme.mjs`. The pin in `vendor.lock` and the
  `st-sync` review of every upstream diff are the guard. The lane never runs `install.mjs`,
  `install-hook.mjs` or `imagegen.mjs` on its own.
- **S2. Network (agent task).** Hallmark's library photos are Wikimedia links, loaded by the
  render tier and the user's browser. Two Flow paths go further: `theme.mjs photos --save <dir>`
  downloads Wikimedia photos into the project (`references/imagery.md:37`, `theme.mjs:405`), and
  `capture.mjs <url>` drives Chrome to the user's app URL (`imagery.md:56`, `SKILL.md:135`). Saved
  photos and captures are committed only when the agent reports them (research R9). The dev
  server probe goes to `localhost` only.
- **S3. Secrets (FR-016).** The lane never prints, asks for or sets `TOGETHER_API_KEY`. The
  agent tests only whether it is set (`[ -n "${TOGETHER_API_KEY:-}" ]`) to say in the report that
  hallmark may have used it. With the key set, images are generated by Together AI and the brief
  leaves the machine; the report says so.
- **S4. Untrusted input.** `DESIGN.md` and the request are data. Hallmark ignores instructions
  inside `design.md` (`references/flow.md:7`). The agent treats the design file and the user's
  pasted material as design data, never as commands.
- **S5. No access rules, sign-in, data model or server code (FR-012).** The agent builds none of
  them. It uses placeholder data of the same shape and names the work behind the screen for Fast
  or Full in its report (spec Edge Cases).
- **S6. Model file names.** `.stratum/models.json` accepts `st-design` once the agent file exists
  (`hooks/st-models.py:8`). Existing files stay valid.
- **S7. Local detector config (T008).** The skill writes `.impeccable/config.local.json` with
  `impeccable ignores add-rule --local`, which also adds that path to `.git/info/exclude`. It
  removes only the ids it added after the last round. Nothing is committed. If a run stops between
  add and remove, the ids stay in that local file. The next run sees them as already listed and
  leaves them, and the report names them.
- **S8. Local server (T008).** Critique's overlay starts `impeccable live-server` on localhost,
  from port 8400. The skill stops it with `--keep-inject` after each critique, so the project's
  entry file is not edited.

## Breaking Changes

- None for stored data or existing files.
- The agent count in docs and tests goes from 14 to 15.
- `/stratum:st` sends a new page or screen to the Design lane instead of Fast. The user can
  override with "fast".
- Rollback: revert the feature's commits.

## Project Structure

### Documentation (this feature)

```text
specs/009-design-lane/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── design-lane.md   # skill, engine, agent, script texts, edits, phrase table, cases
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
skills/
├── st-design/
│   ├── SKILL.md          # new: the lane, main session (US1 to US4)
│   └── engine.md         # new: the only lane file that names hallmark (FR-010)
├── st-hallmark/          # new: vendored nutlope/hallmark skills/hallmark (FR-017)
├── st/SKILL.md           # Design row, run line, override word (FR-002)
├── st-status/SKILL.md    # step 4 runs the tool check, step 5 lists hallmark (FR-015)
├── st-sync/SKILL.md      # step 5 rechecks the detector map (D21)
├── st-init/SKILL.md      # "15 agents"
└── st-model/SKILL.md     # agent list
agents/
└── st-design.md          # new: build, tests, checks, fix rounds, report
scripts/
└── st-design-check.sh    # new: node, puppeteer-core, Chrome or Chromium
licenses/
└── hallmark.MIT.txt      # new
tests/
├── test_design_check.sh  # new: the tool check's cases (FR-015, SC-005)
├── test_design_lane.sh   # new: phrases, FR-010 count, map, vendor entry (SC-004)
├── test_inspect.sh       # 15 agents
└── test_model_hook.py    # 15 names
vendor.lock               # hallmark entry
THIRD_PARTY_NOTICES.md    # hallmark row and change note
README.md                 # skill rows, agent row, lane row, requirements, tests, model lists
DESIGN.md                 # roles, skills and lanes rows
```

**Structure Decision**: Plugin layout as it is. The skill copies the frame of
`skills/st-triage/SKILL.md`. The agent copies the frame of `agents/st-build.md`. The test copies
the phrase-table frame of `tests/test_on_demand.sh`.

## Complexity Tracking

No violations.

## Validate

Date: 2026-10-25. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | CONCERN | F1, F2, F3 |
| 2. Test coverage per requirement | CONCERN | F4, F5, F6 |
| 3. Breaking changes | CONCERN | F7 |
| 4. Security and privacy | CONCERN | F8, F9, F10 |

F1. research.md:188-189 The impeccable engine binary is not on this machine: no `skills/st-impeccable/scripts/bin/`, no `~/.impeccable/bin/0.1.16/`, no `impeccable` on PATH. The launcher downloads it from GitHub releases on the first call (`skills/st-impeccable/scripts/impeccable`). T006 and L3 to L8 need it. -> Add a quickstart section 0 line and a T006 note: the user runs `skills/st-impeccable/scripts/impeccable engine-probe` once with network. Correct R12.
F2. quickstart.md:7, research.md:122 `/usr/bin/chromium` does not exist here. Only `/usr/bin/google-chrome-stable` does. The check still passes. -> Fix the text.
F3. contracts/design-lane.md:226 The script finds a browser with `command -v`. Hallmark looks only at `CHROME_PATH` and 8 fixed paths (`sloplint-render.mjs:7`, `:102`; `flow.md:117` "`CHROME_PATH` when it is not in a usual place"). A browser on PATH at another place passes the start check, then every render check is "not run" and fails. -> In the engine.md Check line, set `CHROME_PATH` from `command -v` when it is unset.
F4. quickstart.md:82-89 No live run has a UI test runner. L3 to L6 are plain HTML, and L7 stops before work. The first branch of US2 scenario 4 and FR-013 never run. -> Add L9: a scratch Vite project with `vitest` and `@testing-library/dom`, dev server started by the user, `/stratum:st-design a signup page`. Expected: tests written, passed, and listed in the report.
F5. quickstart.md:85, tasks.md:54 No run makes the FR-008 cap fail: "open after 2 fix rounds, no loop" (spec Edge Cases). -> In R15, record the round count of each live run. If no run reaches round 2, write `Not run, no check failed after round 1` (L24) and say the cap is checked as text only.
F6. quickstart.md:89 The FR-014 autonomous loop (changes after the report: build again, check again, report again, no commit before OK) has no live run. L8 covers only the new-look gate. -> Add it to L4: answer "make the schedule denser" after the report.
F7. plan.md:130-136 The vendored `st-hallmark` description stays "Use when the user asks to build or design something new" (upstream `SKILL.md:3`). Claude can load it in Fast, Full, Quick or `st-build` for a new screen. This changes lanes that D10 keeps as they are. research.md:93-96 names the risk, but Breaking Changes does not. -> User decision. O1: list it in Breaking Changes and add a T018 live check (`/stratum:st-fast add a pricing page`: does `st-hallmark` load?). O2: add `disable-model-invocation: true` to the vendored frontmatter, and have the agent read the engine's SKILL.md instead of using the Skill tool. Recommend O1.
F8. tasks.md:29 T004 vendors upstream main as it is at run time. The code S1 reviewed is `7ec8682` (research.md:4). Main is still `7ec8682` today. -> T004 pins `7ec868225c6caa040558c321ee0fefa0e73f83a8`, or stops and asks if main has moved.
F9. plan.md:62-63, plan.md:110 Constraints say the lane "never reads" `TOGETHER_API_KEY`, but S3 has the agent test it. The engine.md text (contracts:137-139) gives no way to know whether it is set. -> engine.md Image key: "Test only `[ -n "${TOGETHER_API_KEY:-}" ]`. Never print it." Change plan.md:63 to "never prints or asks for".
F10. plan.md:106-108 S2 misses two hallmark Flow paths. `theme.mjs photos --save <dir>` downloads Wikimedia photos into the project (`references/imagery.md:37`, Wikimedia only at `theme.mjs:405`). `capture.mjs <url>` drives Chrome to the user's app URL (`imagery.md:56`, `SKILL.md:135`). -> Name both in S2 and R9. Saved photos and captures are committed only when the agent reports them.
