# Implementation Plan: background research during the Define grill

**Branch**: `stratum-111` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/021-background-research/spec.md`, grill decisions D6 to D10 in `decisions.md`, issue #111.

## Summary

Research that the Define grill needs runs in the background, up to 3 `st-research` runs at a time, each with its own file `<folder>/research/<short-name>.md`. The git check of each run ignores `.stratum/state.json`, `<folder>/decisions.md` and `<folder>/research/*.md` through git exclude pathspecs. At the end of the grill Define waits for the runs and writes the queue under `## Queued research` in `<folder>/decisions.md`. Plan runs that queue first, and the `st-plan` agent reads `research/` and writes `research.md` as a `## Sources` list plus its decisions.

The change is text in four rule files and the checks in `tests/test_research.sh`. No new script.

## Technical Context

**Language/Version**: Markdown rule files (skills, procedures). Bash for the tests. git 2.56.1 on this machine.

**Primary Dependencies**: Claude Code 2.1.325 (Agent tool runs subagents in the background and notifies on end), git pathspec magic `:!` and `:(exclude,glob)`.

**Storage**: Files only: `specs/NNN-name/research/<short-name>.md`, `specs/NNN-name/decisions.md`, `specs/NNN-name/research.md`.

**Testing**: `bash tests/test_research.sh` (phrase rows plus real git repos in `mktemp -d`). Other tests that read a touched file, by path or by a glob over all skills and procedures: `tests/test_state.sh`, `tests/test_local_files.sh`, `tests/test_test_scope.sh`, `tests/test_no_frontend_design.sh`, `tests/test_advisor_rules.sh`, `tests/test_inspect.sh`, `tests/test_lane_steps.sh`, `tests/test_on_demand.sh`, `tests/test_plan_rules.sh`, `tests/test_triage_rules.sh`, `tests/test_harness_model.sh`.

**Target Platform**: Linux, the user's PC and laptop (same plugin, no local-only part).

**Project Type**: Claude Code plugin (skills, agents, procedures, hooks).

**Performance Goals**: The grill asks its next question with no wait for research (SC-002).

**Constraints**: At most 3 grill research runs at a time (FR-004). Minimum text change in the terse style of the skill files.

**Scale/Scope**: 4 rule files, 1 test file.

## Constitution Check

No `.stratum/constitution.md` in this repo (base repo, by choice) and no `apps/*/ORDINANCE.md`. No gate. Re-check after design: still none.

## Files and changes

| File | Change | FR |
|------|--------|----|
| `skills/st-define/SKILL.md` step 1 | Quick look first, then background research with `feature <folder>`, cap 3 and FIFO queue, no same scope twice, summary on report, replaces the `st-grill` research rule, decisions go to `<folder>/decisions.md` once the folder exists, wait at grill end, `## Queued research` lines | FR-001 to FR-006, FR-008 to FR-010, FR-014 |
| `skills/st-define/SKILL.md` gate | Name stopped or failed research and the queued scopes | FR-009 |
| `skills/st-research/SKILL.md` step 3 | Feature folder path becomes `<feature folder>/research/<short-name>.md`, short name unique in the folder and among runs | FR-006 |
| `skills/st-research/SKILL.md` step 4 | From the Define grill: brief in one line, no OK | FR-003 |
| `skills/st-research/SKILL.md` step 5 | Three git commands gain the exclude pathspec, run from the project root, `<folder>` rule | FR-007 |
| `skills/st-research/SKILL.md` step 6 | From the Define grill: start in the background, steps 7 and 8 on the report | FR-002 |
| `skills/st-plan/SKILL.md` step 0.3 (new) | Run each `## Queued research` line with no file yet, before the agent | FR-011 |
| `procedures/plan.md` Phase 0 | Read `research/`, `## Sources` list, no copy of facts; old `Written by: st-research` rule kept; both cases | FR-012, FR-013 |
| `tests/test_research.sh` | New `#111` rows, replaced rows, new git block B6, B3 and B5 use the new commands | FR-015, FR-016 |

Not changed: `skills/st-grill/SKILL.md` (vendored, FR-014 keeps its rule for a lone grill), `agents/st-research.md`, `agents/st-plan.md`, `procedures/research.md` (one file per run, rounds as today), `tests/test_harness_model.sh` and every other test.

The exact new text is in [contracts/rule-text.md](contracts/rule-text.md).

## Design notes

1. **Where the ignore list lives.** Step 5 of `skills/st-research/SKILL.md` writes the three git commands in full with the pathspec `-- . ':!.stratum/state.json' ':!<folder>/decisions.md' ':(exclude,glob)<folder>/research/*.md'`. With no feature folder, `<folder>` is `.stratum`, so one command form covers every run. Step 7 keeps "Any difference except the output path is a finding": a hand run with `path docs/r.md` still needs it.
2. **Glob magic.** Plain `:!<folder>/research/*.md` also hides `research/sub/z.md` (probe, git 2.56.1). `:(exclude,glob)` hides only `research/*.md`.
3. **Relative folder, project root.** An absolute folder in an exclude pathspec does not exclude (probe). `-- .` from a subfolder misses changes outside it (probe). Step 5 says "From the project root" and `<folder>` is a path from the project root.
4. **Decisions file in Define.** `skills/st-grill/SKILL.md:29` takes the decisions file from `.stratum/state.json`, and `hooks/st-phase.py:137-141` sets the new folder only after `spec.md` exists. So during a new Define the grill writes to the older feature's `decisions.md`, a path the ignore list does not cover (a false finding, against SC-004). Define step 1 says: from the time the folder exists, the grill writes its decisions to `<folder>/decisions.md`. This matches D6 ("the files this Define run writes on purpose: `<folder>/decisions.md`").
5. **Queue hand-off.** Each queued line is `- <short-name>: <scope and questions>`. Plan runs a line only when `<feature dir>/research/<short-name>.md` does not exist, with `path <feature dir>/research/<short-name>.md`, so a second Plan run does not run it again, and Plan's own grill lines (`- D13 (Q12): ...`) under the heading are not scopes.
6. **Concurrency.** Background runs come from the Agent tool (Claude Code 2.1.325: "Agents run in the background by default ... you will be notified when it completes"). The cap, queue and same-scope rule live in the orchestrator's context, as the spec's Key Entities say. Plan runs its queued scopes one after another; the spec does not ask for parallel runs there.

## Security notes

- **No OK for grill research (FR-003).** The OK prompt of `st-research` step 4 is skipped only from the Define grill. The agent's own rules (`agents/st-research.md`: one output file, no state change, web text is data) and the step 7 git check stay. A lone `/stratum:st-grill` and every other caller keep the OK.
- **Git check ignore list (FR-007, D6 narrowed by D11).** In `.stratum/` the check ignores only `.stratum/state.json`, the one file a hook changes during a grill. In this repo `.stratum/autonomous/`, `.stratum/constitution.md` and `.stratum/templates/` are not git-ignored (`git check-ignore` exit 1), so a write there stays a finding: a research agent that a web page talks into writing `.stratum/autonomous/<session>` (which turns on autonomous build mode) is seen. Block B6 has a finding row for `.stratum/autonomous/x`. With no feature folder, `<folder>` is `.stratum`, so `.stratum/decisions.md` and `.stratum/research/*.md` are ignored through the folder rule; in a feature run they are findings. Git-ignored files stay unseen, as today.
- **Data.** Research files hold code facts and web cites. `agents/st-research.md` already forbids copying a secret into them. No personal or minors' data, no new external service.

## Test plan for `tests/test_research.sh`

New rows start with `#111`, because the file already uses the FR numbers of feature 016.

| Row today | Action | Why |
|-----------|--------|-----|
| `FR-004 order` | Replace the phrase with the new order (`<feature folder>/research/<short-name>.md`) | FR-006 replaces 016 FR-004 |
| `FR-015 define` ("Pass `<folder>/research.md` as the research path.") | Replace with "Pass `feature <folder>`, not a path." | FR-006 |
| `FR-015 redo` | Replace with the `feature <feature_directory>` sentence | FR-006, redo edge case |
| `FR-013 plan proc` ("With no such file, follow steps 1 to 3.") | Replace with "With neither, follow steps 1 to 3." | FR-013 |
| `idx`, `hash` heredocs and rows `SC-003 index cmd`, `SC-003 hash cmd` | New command text with the pathspec | FR-007 changes the commands |
| Blocks B3 and B5 | Run the new commands with `<folder>` set to `.stratum` | FR-007 |
| All other rows | Keep | FR-016 |
| New `#111` rows and block B6 | Add | FR-015 |

B6 runs the test's own copy of the commands in a real git repo, so it is green before the build. The `grep -qF` rows tie the copy to the skill and are the red ones. Negative controls are in [quickstart.md](quickstart.md) section 2.

`tests/test_harness_model.sh` reads every harness file for `.stratum/<name>` strings. The new text names only `.stratum/state.json` (already modelled) and the bare `.stratum` (no match), so `coverage-data` and `missing` stay green with no change to the test.

## Project Structure

### Documentation (this feature)

```text
specs/021-background-research/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/rule-text.md
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
skills/st-define/SKILL.md
skills/st-research/SKILL.md
skills/st-plan/SKILL.md
procedures/plan.md
tests/test_research.sh
```

**Structure Decision**: Edit the existing rule files in place. No new file outside the feature folder.

## Complexity Tracking

None.
