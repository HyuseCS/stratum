# Quickstart: st-research

Run every command from the repo root. Python with `-B`.

## 1. Red states between tasks

| After | Red (expected) | Everything else |
|-------|----------------|-----------------|
| T001 | `tests/test_research.sh`: every US1 check; `tests/test_inspect.sh`: `16 agents`, `rename skills/st-init/SKILL.md:26`, `README paths` (test file not in README); `tests/test_model_hook.py`: `test_module_constants` | green |
| T002 | `tests/test_harness_model.sh`: `coverage-skills`, `coverage-agents`, `coverage-procedures`, `coverage-data`, `atlas`, `rebuild` | green |
| T003, T005, T007 | none | green |
| T004 | `tests/test_research.sh`: US2 rows only | green |
| T006 | `tests/test_research.sh`: US3 rows only | green |
| T008 | `tests/test_research.sh`: US4 rows and `FR-001 agent` (tools line) | green |
| T009, T010 | none | green |

## 2. Negative controls

Do each on a scratch copy (`cp -r . "$(mktemp -d)"/r`, then `ST_ROOT=<copy>`), never in the repo.

| # | Break | Command | Must show |
|---|-------|---------|-----------|
| N1 | In the copy's `skills/st-research/SKILL.md`, change `= "$CLAUDE_CODE_SESSION_ID"` to `!= "$CLAUDE_CODE_SESSION_ID"` | `ST_ROOT=<copy> bash tests/test_research.sh` | `FAIL FR-002 auto cmd` |
| N2 | In the copy's skill, delete `"$(realpath .)"/*) true ;; ` | same | `FAIL FR-005 path cmd` |
| N3 | In the copy's `tests/test_research.sh`, change the path command's `/*)` to `*)` | same | `FAIL` on the `../p2/x.md` case, and `FAIL FR-005 path cmd` |
| N4 | In the copy's test, write the autonomous command without `[ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && ` | same | `FAIL` on the empty-flag, empty-id case, and `FAIL FR-002 auto cmd` |
| N5 | Delete the copy's `procedures/research.md` | same | `FAIL` on every procedure row |

## 3. Manual runs

Run in a scratch project with `.stratum/` and git, no `specs/`, unless the row says otherwise.
Before and after each run, `git status --porcelain --untracked-files=all` must differ only by
the research file (SC-003).

| # | Story | Steps | Expected |
|---|-------|-------|----------|
| Q1 | US1 | Autonomous mode off. `/stratum:st-research check plan.md against the code: does main.sh read config.json? which file sets the port?` with a `plan.md` that names a wrong file | Scope and Q1, Q2 shown, path `.stratum/research/<short-name>.md`. Nothing starts before your OK. After OK: one file, each fact with `file:line` or a sha, a drift section with the wrong file and a cite, no advice (SC-001, SC-002) |
| Q2 | US1 | Say `autonomous mode`, then run Q1 again with the same words | No wait for an OK. The file gets `## Round 2` after the kept Round 1 |
| Q3 | US1 | `/stratum:st-research ... path ../out.md` and `path /tmp/x.md` | "The research file must be inside the project." No file written |
| Q4 | US1 | Remove `.stratum/`, run the skill | It stops and names `/stratum:st-init` |
| Q5 | US2 | `/stratum:st-define <a task whose grill needs a code fact>` | `specs/<NNN>-<name>/research.md` exists before `spec.md`; findings shown before the next question; after Specify one new folder only, `spec.md` in it, `state.json` names it (SC-005) |
| Q6 | US3 | Put a st-research `research.md` that answers every unknown in a feature, run `/stratum:st-plan` | Every round unchanged, a `## Decisions` heading at the end, no new facts (SC-004) |
| Q7 | US4 | One code question and one library-version question | Code answer has no URL. Library answer cites `(<url>, read YYYY-MM-DD)`. A page that disagrees with the pinned version shows `Conflict:` with both sources |
| Q8 | FR-002 | Before the PR: `git fetch origin && git log --oneline HEAD..origin/main` and `gh issue view 77 --json state` | If #77 merged, merge `origin/main` and update the step 4 command and test B1 to the new flag format |
