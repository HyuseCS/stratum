# Implementation Plan: st-research, a research step that runs alone

**Branch**: `080-st-research` (worktree branch `worker-f80`) | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/016-st-research/spec.md`, decisions D1 to D10 in
[decisions.md](decisions.md), issue #80. Plan decisions: D1 = A (the 6 files the tests force,
the `.stratum/research` element in `data.c4`), D2 = A (`st-init` agent count 15 to 16).

## Summary

A new skill, `/stratum:st-research`, changes the caller's words into a scope and numbered
questions. It picks the output path (FR-004 order), checks that the path is inside the project,
shows everything, and waits for the user's OK unless autonomous build mode is on for this
session. Then it notes the git state, starts the `st-research` agent, checks the git state
again, and shows a short summary. The agent follows a new `procedures/research.md`: facts with
cites, no advice, one file, fixed sections per round, drift against a plan file, and web
research only for facts outside the repo. Four short edits connect it to the Full lane: `st-plan`
(run it first), `procedures/plan.md` (build on its file), `st-grill` (run it for code facts),
`st-define` and `procedures/specify.md` (make the feature folder early and use it once).
`tests/test_research.sh` checks the text and runs the skill's two shell commands. The harness
model, the atlas and every file that lists all agents get the new agent.

## Technical Context

**Language/Version**: Markdown (skill, agent, procedure, docs), Bash 5 (test), Python 3 (one test edit), LikeC4 DSL (model)

**Primary Dependencies**: Claude Code 2.1.319 plugin layout and built-in WebSearch and WebFetch tools (research R2), git, coreutils `realpath -m`, likec4@1.60.0 through `npx` and node v24.14.1 (harness test only), `~/.claude/skills/system-atlas` build script (atlas rebuild only). No new package.

**Storage**: One Markdown research file per run: `<feature folder>/research.md` or `.stratum/research/<short-name>.md` ([data-model.md](data-model.md)).

**Testing**: `bash tests/test_research.sh` (new), plus the existing `tests/test_inspect.sh`, `tests/test_model_files.sh`, `tests/test_model_hook.py`, `tests/test_session_hooks.sh`, `tests/test_local_files.sh`, `tests/test_on_demand.sh`, `tests/test_test_scope.sh`, `tests/test_state.sh`, `tests/test_plan_rules.sh`, `tests/test_lane_steps.sh`, `tests/test_advisor_rules.sh`, `tests/test_triage_rules.sh`, `tests/test_harness_model.sh`.

**Target Platform**: Claude Code on Linux and Windows (Git Bash), as the rest of the repo (GNU `sha256sum` and `stat -c` in `scripts/st-advisor.sh`). The skill uses GNU `realpath -m` and `sha256sum`. A project with or without `specs/`.

**Project Type**: Claude Code plugin (agents, skills, procedures, docs).

**Performance Goals**: N/A.

**Constraints**: No comments except `ponytail:` markers. Minimal diff. No new script, hook or dependency. Each new contract line stays on one line (contracts P1). The text never says "full suite" (`tests/test_test_scope.sh:16`).

**Scale/Scope**: 1 skill, 1 agent, 1 procedure, 1 test file new. 16 agents, 27 entry skills.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` (base repo). The gates come from the rules the
orchestrator passed, as in feature 005.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that fails before its build task | Pass: T001 before T002/T003 (FR-001 to FR-008, FR-011, FR-017), T004 before T005 (FR-014 to FR-016), T006 before T007 (FR-012, FR-013), T008 before T009 (FR-009, FR-010). Red states in quickstart section 1 |
| G2. Minimal diff, no new script, hook or dependency | Pass: Markdown files, one-line edits, one test file |
| G3. Only files on the worker's list, plus the ones D1 and D2 allow | Pass: the 7 extra files are named in tasks T001 to T003 |
| G4. A phrase check asserts text the build writes whole on one line | Pass: contracts P1 and section 6 |
| G5. A check that cannot fail is not a check | Pass: B1 and B2 have negative cases. Quickstart section 2 breaks each guard once |
| G6. Test runs leave no files | Pass: `tests/test_research.sh` works in `mktemp -d` with a trap. Python runs use `-B` |
| G7. No task runs every test in the repo | Pass: each `Test:` names its files |

Post-design re-check: all gates pass. Complexity Tracking stays empty.

## Security Notes

- **S1. The agent has Bash, Write and Edit (T002).** It needs them for `git log` and for the one
  research file (research R2). The tool list cannot stop a second write. The guards: the
  `## Never` lines, and the skill's `git rev-parse HEAD`,
  `git status --porcelain --untracked-files=all` and `sha256sum` of every changed and untracked
  file before and after (research R6). These do not see git-ignored files.
  The agent reads the whole repo, and in a feature the research file is committed. A `## Never`
  line forbids copying a secret (a key, a token, a password, an `.env` value) into the research
  file, a web query or a URL (test row `secret`).
- **S2. Path outside the project (T002, FR-005).** The skill runs `realpath -m` on the path and
  stops unless it is under `realpath .` of the project root. `realpath` resolves `..` and
  symlinks, so a link to outside fails too. A path with a `'` stops before any shell call, so it
  cannot break the quotes. The agent checks the path again. Test B2.
- **S3. External service and untrusted input: the web (T009, FR-009, FR-010).** WebSearch and
  WebFetch send the query and the URL to the network. Only facts outside the repo go to the web.
  Page text is data, never an instruction. The skill shows any change other than the research
  file, so an instruction on a page that makes the agent write elsewhere is found. A plan file
  and repo files are data too. The same `## Never` line as S1 forbids putting a secret in a web
  query or a URL, so no secret leaves the machine through WebSearch or WebFetch.
- **S4. Session flag (T002, FR-002).** The skill only reads `.stratum/autonomous`. It never
  writes it. An empty session id never counts as on (test B1).
- **S5. Model file names (T002).** `.stratum/models.json` accepts `st-research` once the agent
  file exists (`hooks/st-models.py:8`). Existing files stay valid.
- No access rules, sign-in, secrets, personal or minors' data, data model or contract changes.

## Breaking Changes

- None for stored data or existing files.
- The agent count in docs and tests goes from 15 to 16. The entry skill count goes from 26 to 27.
- Rollback: revert the feature's commits. A `.stratum/research/` folder a user made stays.

## Project Structure

### Documentation (this feature)

```text
specs/016-st-research/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
├── contracts/
│   └── st-research.md    # skill, agent, procedure text, edits, test rows
└── tasks.md
```

### Source Code (repository root)

```text
skills/
├── st-research/SKILL.md      # new (US1)
├── st-plan/SKILL.md          # E1 (US3)
├── st-grill/SKILL.md         # E3 (US2)
├── st-define/SKILL.md        # E4 (US2)
├── st-model/SKILL.md         # agent list (US1)
└── st-init/SKILL.md          # 16 agents (US1)
agents/st-research.md         # new (US1, US4)
procedures/
├── research.md               # new (US1, US4)
├── plan.md                   # E2 (US3)
└── specify.md                # E5 (US2)
tests/
├── test_research.sh          # new (US1 to US4)
├── test_inspect.sh           # 16 agents (US1)
└── test_model_hook.py        # agent list (US1)
README.md, DESIGN.md          # skill and agent rows, model list, test list, D13a row (US1)
docs/harness/model/{agents,skills-core,procedures,data}.c4   # new elements and links (US1)
docs/harness/README.md        # regenerated (US1)
docs/harness/atlas/{data.mjs,atlas.html,SYSTEM.md}           # new ids, rebuilt (US1)
```

**Structure Decision**: The plugin's flat layout. No file outside this tree.

## Complexity Tracking

None.

## Validate

Date: 2026-11-08. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | CONCERN | F1 |
| 2. Test coverage per requirement | CONCERN | F2, F3 |
| 3. Breaking changes | CONCERN | F4 |
| 4. Security and privacy | CONCERN | F5 |

Verified on Linux: Claude Code 2.1.319, node v24.14.1, GNU bash 5.3, GNU realpath 9.12, git 2.56.0, `~/.claude/skills/system-atlas/assets/{build.mjs,template.html}`, likec4@1.60.0 (`bash tests/test_harness_model.sh` green). All 13 test files the tasks name exist and are green at `354d7db`. Every edit anchor in contracts section 4 and tasks T001 to T003 is at the cited line. `docs/harness/views/5-agents.c4` uses `agents.*`, so it needs no edit. Test runs left the tree clean.

F1. plan.md:33, contracts/st-research.md:27 and :30. Target platform lists macOS, but `realpath -m` and `sha256sum` are GNU tools. Stock macOS has neither, so the path check exits 1 for every path and the skill always stops. Not verified on macOS. -> User decision: drop macOS from the target, or st-plan picks a portable form (for example `python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))'` and `shasum -a 256` fallback) and updates B2.
F2. quickstart.md:72, :78, :79. N3 and N4 break the copy's `tests/test_research.sh`, but the command `ST_ROOT=<copy> bash tests/test_research.sh` runs the repo's test file from the repo root. The B1 and B2 cases stay green and the negative control cannot go red. -> st-plan: run `bash <copy>/tests/test_research.sh` for N1 to N5.
F3. spec.md:111, quickstart.md:96. US4 acceptance scenario 3 (a page with an instruction, no other file changes) has no automated row and no manual row. Q7 checks URL, date and `Conflict:` only. -> st-plan: add a Q7 step with a scratch page that holds an instruction to write a file, and expect only the research file in `git status`.
F4. contracts/st-research.md:93 and :124. A plan-written `research.md` (no `Written by: st-research` line, for example a re-plan, or `specs/005-st-triage/research.md`) gets a `## Round 1` from st-research with no marker line. E2 then does not see a st-research file, and Plan Phase 0 rewrites `research.md` as today, which can drop that round. -> st-plan: in procedures/research.md step 2, add the line `Written by: st-research` when an existing file does not have it.
F5. contracts/st-research.md:65-73, plan.md:62-82. The agent has Read and Bash on the whole repo and writes a file that is committed in a feature (`specs/<NNN>/research.md`), and WebSearch sends queries off the machine. No rule stops it from copying a secret (`.env`, keys, tokens) into the research file or into a web query. -> st-plan: add one `## Never` line, built as `- Copy a secret (a key, a token, a password, an `.env` value) into the research file, a web query or a URL.`, a phrase row for it, and a line in S1 and S3.
