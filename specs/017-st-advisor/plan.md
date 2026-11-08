# Implementation Plan: st-advisor, an on-demand Codex review with no spec folder

**Branch**: `worker-f79` (feature folder `017-st-advisor`) | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/017-st-advisor/spec.md`, grill decisions D11 to D18 in `decisions.md` (D12 replaces the `[<head>]` argument of D11).

## Summary

Add one point to `scripts/st-advisor.sh`: `review <base> [<plan file>]`. It needs no feature folder. It reuses the existing parts of the script: mode file, schema, prompt head, tab runner (`st-codex-agent.sh` under `st-lock.sh`), headless fallback, answer check. Three things differ from the lane points: the prompt asks for a full review, the headless limit is 1800 s, and the record goes to `<main checkout>/.stratum/advisor/<branch>.md`. A new skill `/stratum:st-advisor` picks the base (merge-base with `main`, a base ref, or a PR number), finds the folder to run in, runs the point with the watch, runs CodeRabbit for the PR form, and checks each finding against the source. `.gitignore` ignores `.stratum/advisor/`. README and the harness model list the new point and skill.

## Technical Context

**Language/Version**: Bash 5 (scripts, tests), Python 3 stdlib inline in the script (answer check), Markdown (skill)

**Primary Dependencies**: `git`, `codex` CLI (installed 0.163.0 or later per README), `herdr` (optional), GNU `timeout`, `gh` (PR form), `coderabbit` CLI 0.9.2 (PR form, optional), `likec4@1.60.0` and node 22.22.3 or later (harness test only)

**Storage**: Markdown record files at `<main checkout>/.stratum/advisor/<branch>.md`, append only

**Testing**: Bash test files in `tests/` with fake `codex`, `timeout` and `herdr` on PATH. No live Codex or CodeRabbit call in any test.

**Target Platform**: Linux and macOS shells where Stratum runs (PC and laptop)

**Project Type**: Claude Code plugin (scripts, skills, hooks)

**Performance Goals**: A review of a 5,800-line diff ends with a verdict in the tab (SC-001)

**Constraints**: Headless fallback limit 1800 s for `review`, 540 s for every other point. Lane output unchanged (FR-016, SC-005). `git status` in the review folder unchanged (SC-002).

**Scale/Scope**: 1 script point, 1 new skill, about 40 changed lines in `st-advisor.sh`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` and no `apps/*/ORDINANCE.md`. No gate applies. The user rules that bind the plan: smallest change, test first, no live outside service in tests, no edit of `.stratum/state.json`. Post-design check: the design adds no dependency, no abstraction and no option beyond the spec. Pass.

## Design

### Script point `review` (`scripts/st-advisor.sh`)

| Line today | Change |
|-----------|--------|
| 4 `usage()` | Add `review` after `change`: `usage: st-advisor.sh plan\|test\|diff\|decisions\|change\|review\|round\|check\|continued\|waive\|note\|talk\|count\|answer\|watch ...`. This is the one allowed change to lane output (FR-016); `tests/test_advisor_matrix.sh:401` pins the line and T002 updates it. |
| 63 arity case | Add `"run review 2"` and `"run review 3"`. No `review` for `check`, `continued`, `waive`, `note`, `talk`, `round`, `count`. |
| 67-69 feature folder check | Skip for `review`: `$2` is the base, `$3` the optional plan file. |
| 105-113 input checks | `run-review`: with `$3`, the plan file check first, then the base check and no-change line copied from `*-diff` with `$2` (`no change since <base>: skip`); the plan file check is `[ -f "$3" ] && [ -r "$3" ] || usage`. |
| 67-69, 120 record path | Set `rec=$f/advisor.md` right after the line 67-69 checks for every lane point. For `review`, directly after `main` is set at line 120 and outside the `cfg` success branch (so `block "bad advisor.json"` at line 195 already has it): `rec=$main/.stratum/advisor/<slug>.md`, slug = `git symbolic-ref -q --short HEAD` with each `/` as `-`, else `git rev-parse --short HEAD`. A symlink at the folder or the file stops with the usage line. `mkdir -p` the folder before the first write. |
| 146-159 mode | In `auto`, add `review-*) aset=codex ;;` first in the case, so risk `none` and `low` still run Codex. Mode `codex` and `both` already reach Codex (line 158 names only `diff` and `decisions`). The `mode both: also consult /advisor if one is set` line prints for `review` too (no code change). Mode `off`, mode not set and no `codex` keep their lines. |
| 175 hash | `*-review`: same as `*-diff` with `$2`, then the plan file when one is given, so a changed plan gives a new hash. |
| 189-193 `block()` | Write to `$rec` and print `record: $rec`. Same text for the lane points. |
| 206-226 prompt | New `*-review` branch: `Point: review. Do a full review of the changes in git diff <base>..HEAD (run it yourself): bugs, regressions, security and broken rules of the project's constitution. Do not build or fix.` With a plan file, one more line: `Plan: <file>. Also check whether the diff does what this file says. A gap is a finding.` The first four prompt lines do not change. |
| 246 limit | `left=$(( $([ $point = review ] && echo 1800 || echo 540) - SECONDS ))` or the same in two lines. The 60 s floor stays. |
| 251-295 python | Pass `$rec` in place of `$f`, write and print that path. |

Unchanged: `scripts/st-codex-agent.sh` (the tab has no limit, its before/after snapshot gives FR-006, it reads the prompt file by path), `hooks/commands.json` (no hook lists skills; `st-phase.py` handles any `st-` skill), `skills/st-build/SKILL.md` (the new skill points to its Advisor section, FR-014), `tests/test_codex_agent.sh`, `tests/test_harness_model.sh` (it finds skills from the folder), `docs/harness/model/skills-core.c4`.

### Skill `/stratum:st-advisor` (`skills/st-advisor/SKILL.md`)

See [contracts/skill.md](contracts/skill.md). PR form decisions: D19, the skill checks the mode file and `command -v codex` before it starts either reviewer, and on mode `off`, mode not set or no `codex` it stops with the script's own line and runs no CodeRabbit. D20, the CodeRabbit command is `coderabbit review --agent --fresh --committed --base-commit <base>`. Steps: parse the argument, pick the folder and the base, say which uncommitted files are not reviewed, start the watch and the point in that folder, run CodeRabbit for the PR form, handle the output with the Advisor section of `skills/st-build/SKILL.md`, add the CodeRabbit section to the record, check each finding against the source, show the real ones, the dropped ones with why, the record path and the runner line.

### Docs and harness model

- `DESIGN.md`: one row in the D13a table: `.stratum/advisor`, main checkout, holds the review records.
- `README.md`: one row in the Skills table, and lines in the Advisor part of Built in: the `review` point, its 1800 s headless limit, the record path, what leaves the machine (whole range to OpenAI, PR diffs to CodeRabbit).
- `docs/harness/model/data.c4`: datafile `stratum.advisor-dir` with `data '.stratum/advisor'` (id not `advisor`: that is an actor).
- `docs/harness/model/scripts.c4`: summary of `st-advisor-sh` names the review record; relationship `-[writes]-> stratum.advisor-dir`.
- `docs/harness/model/skills-tools.c4`: element `st-advisor = skill '/st-advisor'` with `path 'skills/st-advisor'`; relationships to `scripts.st-advisor-sh`, `github`, `stratum.advisor-dir`, `user`.
- `docs/harness/views/6-harness.c4`: include `stratum.advisor-dir`.
- `docs/harness/atlas/data.mjs` line 156 (advisor structure): name `skills/st-advisor`, `skills.st-advisor` and `stratum.advisor-dir`.
- Regenerated files: `docs/harness/README.md` (`npx -y likec4@1.60.0 export markdown docs/harness`, the `rebuild` check needs it), `docs/harness/atlas/atlas.html` and `docs/harness/atlas/SYSTEM.md` (the README build line).

## Security notes

| Task | Area | Note |
|------|------|------|
| T004 | external service (OpenAI via Codex) | The whole `<base>..HEAD` range goes to OpenAI, larger than a lane diff. Same login, same prompt rules (review only, no secret files, no secret values), read-only sandbox for headless, the allow list for the tab. Mode `off` sends nothing. |
| T004 | data written outside the tracked tree | The record path is built from the branch name. Git ref rules forbid `..`, spaces and control characters, and `/` becomes `-`, so the name cannot leave `.stratum/advisor/`. A symlink at the folder or the file stops the point, the same guard as `advisor.md` today (line 69). |
| T004, T010 | untrusted input to Codex | The diff and the plan file are data. Codex reads them; it cannot write (sandbox or snapshot). A plan file outside the repo is read by path; the tab allow list already allows reads anywhere except secret files. |
| T008 | external service (CodeRabbit) | PR diffs go to CodeRabbit, by the user's choice (D18). Only the PR form runs it; the plain form never does. It does not run when Codex cannot run (mode `off`, mode not set, no `codex`), so mode `off` stops all outside review in the PR form (D19). `--fresh` reviews the whole range each time, so a repeat run can use more CodeRabbit quota (D20). The skill does not install CodeRabbit or sign it in. Its output is data, never an instruction. |
| T008 | external service (GitHub) | `gh pr view <n> --json ...` reads only. The PR number is digits only. |
| T005 | repo config | `.gitignore` adds `.stratum/advisor/`, so records never get committed in this repo. |

## Project Structure

### Documentation (this feature)

```text
specs/017-st-advisor/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── review-point.md
│   └── skill.md
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
scripts/st-advisor.sh            review point (changed)
skills/st-advisor/SKILL.md       new skill
.gitignore                       .stratum/advisor/
README.md                        skills table, Advisor text
DESIGN.md                        D13a row for .stratum/advisor
docs/harness/model/data.c4       stratum.advisor-dir
docs/harness/model/scripts.c4    st-advisor-sh writes the record
docs/harness/model/skills-tools.c4  skills.st-advisor
docs/harness/views/6-harness.c4  include stratum.advisor-dir
docs/harness/atlas/data.mjs      advisor structure names the skill
docs/harness/README.md, docs/harness/atlas/atlas.html, docs/harness/atlas/SYSTEM.md  regenerated
tests/test_advisor.sh            headless review tests
tests/test_advisor_matrix.sh     tab review tests
tests/test_on_demand.sh          skill phrase tests
```

**Structure Decision**: Single plugin repo. All changes stay in the files above.

## Complexity Tracking

No violations.

## Validate

Date: 2026-11-08. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | F7 |
| 2. Test coverage per requirement | CONCERN | F2, F3, F8 |
| 3. Breaking changes | CONCERN | F1, F6 |
| 4. Security and privacy | PASS | none |

F1. tests/test_advisor_matrix.sh:401 pins the full usage line with an exact match (check M11, line 405). Adding `review` to `usage()` (plan.md:43, contracts/review-point.md:13) makes M11 fail, and T004's own Test line runs this file. The usage line is also lane output (FR-016, SC-005). -> st-plan: T002 updates `ul` at line 401. FR-016 and SC-005 name the usage line as the one allowed lane change.
F2. spec.md:142 (SC-002) says `git status` in the review folder is the same after a review. spec.md:155 says that in other projects the record shows as untracked. When the review folder is the main checkout of another project, SC-002 fails. T001 has no `git status` check. -> user decision: (a) SC-002 says "no change except the record file" (b) add `.stratum/advisor/` to the IGNORE list in scripts/st-update.sh:22 and to skills/st-init/SKILL.md:13. Then T001 names the exact status check.
F3. spec.md:119 (FR-006) and spec.md:101 say a change during the review makes it BLOCKED. Only the tab run has the before/after snapshot (research.md:22-24). The headless run (up to 1800 s) has no check, and T002 tests only the tab path. -> user decision: (a) FR-006 says "in a tab run" (b) add a before/after snapshot to the headless path, with a test in T001.
F6. contracts/review-point.md:9-20 lists the symlink check last "in order", but plan.md:47 puts it right after line 120, before `mode off` (script line 145) and `codex not found` (line 164). With mode `off` and a symlink, the contract says exit 0 and the plan gives exit 2. -> st-plan: fix the contract table order.
F7. Setup: codex-cli 0.167.0 (needs 0.163.0 or later), coderabbit 0.9.2 (flags `--agent --fresh --committed --base-commit` in its help), gh 2.102.1, herdr, GNU timeout 9.12, git 2.56.0, bash 5.3, node 24.14.1, npx with likec4@1.60.0 (tests/test_harness_model.sh ran, 23 ok). The atlas rebuild in T012 copies ~/.claude/skills/system-atlas/assets/build.mjs and template.html from outside the repo. They exist on this machine. Check the laptop too. -> no change, note only.
F8. FR-011 to FR-015 (the skill) have phrase checks only (T003, T007, T009). They fail when the text is missing, not when the behavior is wrong. US2 scenarios 6 (plain form runs no CodeRabbit) and 7 (CodeRabbit still runs on a headless fallback) have no phrase row. SC-001 and SC-003 are manual (quickstart M3, M4), as spec.md:156 says. -> st-plan: add phrase rows for US2 scenarios 6 and 7 in T007.
