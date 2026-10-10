# Contract: st-inspect agent, /stratum:st-inspect skill, renames

The build writes the exact phrases below. `tests/test_inspect.sh` greps for them with `grep -F`
(fixed strings, one line at a time).

Rules for the phrases:

- P1. Each phrase sits whole on one line. A line may run past 100 characters to keep a phrase
  whole.
- P2. Negative control per check: delete every line that holds the check's first phrase. Exactly
  that check goes red, and every other check stays green (quickstart section 2). So a line that
  holds one check's first phrase holds no phrase of another check.
- P3. No phrase is a word that every file already holds (`plan.md`, `CRITICAL`, `Validate`
  alone). Lessons L1.

## 1. Agent file `agents/st-inspect.md`

Frontmatter, exact lines (FR-002):

```text
name: st-inspect
tools: Read, Grep, Glob, Bash, Edit
model: opus
```

`description:` Full-lane Inspect phase. Use after st-plan to confirm spec, plan and tasks agree
and the plan can be built - setup, test coverage, breaking changes, security and privacy. Writes
only the ## Validate section of plan.md.

Body sections, in order. Copy the shared lines (sr-opus-5 line, Inputs, Navigation) from
`agents/st-validate.md` before it is deleted. Inputs drop the line about passed findings.

1. Intro: "You are the Inspect agent." It checks that spec, plan and tasks agree, and tests the
   plan against the real project. It writes only the `## Validate` section of plan.md, changes no
   code, never commits.
2. `## Inputs`, `## Navigation`.
3. `## Analysis`: "Follow `<plugin root>/procedures/analyze.md`." Then "Look for at least:" and
   one bullet per item C1-C7, then the C10 line.
4. `## Validate checks`: numbered checks 1-4 (V1-V4), then the V5 line.
5. `## Output`: the V6 line, then the section format below.
6. `## Never`: the FR-003 lines.
7. `## Report`: the FR-004, C8 and C9 lines.

Validate section format (unchanged from the old agent, research R6):

```text
## Validate

Date: YYYY-MM-DD. Verdict: PASS | CONDITIONAL | BLOCKED

| Check | Verdict | Findings |
|-------|---------|----------|

F1. <file:line> <finding> -> <fix or decision needed>
```

Report: one finding list F1, F2... for the analysis and the validate checks. Each finding has a
severity, `file:line`, its analysis category or validate check, what is wrong, and whether it
needs a user decision. The net verdict comes from the 4 validate checks only (research R7).

### Phrase table: agent

| Check | Phrases (all must be present; the first one is the control) |
|-------|-------------------------------------------------------------|
| C1 | `Duplicate requirements` |
| C2 | `Vague words with no measure` · `leftover placeholders` |
| C3 | `a story with no acceptance criteria` · `a task naming a file the spec and plan never define` |
| C4 | `Any break of a constitution MUST rule is CRITICAL` |
| C5 | `a requirement with no task` · `a task with no requirement` · `a success criterion with no task` |
| C6 | `one concept with two names` · `conflicting requirements` |
| C7 | `a test task placed after its build task` · `` `[P]` tasks that touch the same file `` |
| C8 | `Severity: critical, high, medium, low` |
| C9 | `Coverage line: requirements covered by tasks / total, by tests / total` |
| C10 | `Offer each fix, never apply it` · `needs a user decision` |
| V1 | `Do not install anything` · `read-only commands` |
| V2 | `a named test that can fail` · `the test command and its runner exist` |
| V3 | `Name each caller that breaks` · `Migrations need a rollback note` |
| V4 | `minors' data` · `Secrets never in code or git` |
| V5 | `PASS, CONCERN or FAIL` · `Any FAIL means BLOCKED. Only CONCERNs means CONDITIONAL.` |
| V6 | `` replace an older `## Validate` section `` · `Date: YYYY-MM-DD. Verdict: PASS \| CONDITIONAL \| BLOCKED` |
| FR-003 | `` Edit anything except the `## Validate` section of `plan.md` `` · `Install packages, run migrations, or change config` · `` Run `git add` or `git commit` `` |
| FR-004 | `Line 1: the verdict and counts` · `The verdict of each validate check` |

(`\|` in the V6 row is a plain `|` in the file.)

## 2. Skill file `skills/st-inspect/SKILL.md`

Frontmatter: `name: st-inspect` (exact line). `description:` Full-lane Inspect phase. Run
st-inspect (cross-artifact analysis and validate checks in one pass), bring decisions to the user,
and stop at the gate "user OKs the build".

Heading `# /stratum:st-inspect`. Same frame as `skills/st-check/SKILL.md` (orchestrator lines,
`## 0. Start`, `## Steps`, `## Gate: user OKs the build`, `## Always`), with these changes:

- Start step 2: the FR-005 order line. Start step 3: set `phase` to `inspect`.
- Steps: one agent start (no second agent, no passing of findings), then findings (S2, S3), the
  rerun (S4), the advisor (S5). Gate (S6): "the verdict" in place of "validate's verdict".

### Phrase table: skill

| Check | Phrases (all must be present; the first one is the control) |
|-------|-------------------------------------------------------------|
| FR-005 | `` Set `phase` to `inspect` `` · `` `phase` should be `plan` or `inspect` `` · `` Start the `st-inspect` subagent (`stratum:st-inspect`) `` |
| S1 | `` only `plan.md` may change `` · `` touches only its `## Validate` section `` · `git status --porcelain` |
| S2 | `drop the false ones` · `one at a time` |
| S3 | `` Fixes to spec, plan or tasks go to the `st-plan` subagent `` · `` have `st-git` commit them `` |
| S4 | `` If any CRITICAL finding was fixed, run `st-inspect` once more `` |
| S5 | `a simpler or better approach` · `tasks to cut or merge` · `missed auth invariants` · `big ones go to the user before the gate` |
| S6 | `OK to build?` · `findings dropped` |

One agent (FR-005, SC-001): exactly 1 line of the skill holds `` (`stratum: ``.

## 3. Renames (FR-007, FR-008, FR-009)

Old text to new text. Each row is a `grep -F` check in `tests/test_inspect.sh` on the new text, unless the row names other guards.

| File | New text the file must hold |
|------|-----------------------------|
| `skills/st/SKILL.md:32` | `` `/stratum:st-plan`, `/stratum:st-inspect`, `/stratum:st-build` `` |
| `skills/st-full/SKILL.md:3` | description: `Full lane (Define, Plan, Inspect, Build, Close)` |
| `skills/st-full/SKILL.md:12` | `` 3. `/stratum:st-inspect` (gate: user OKs the build) `` |
| `skills/st-plan/SKILL.md:35` | `` Next phase: `/stratum:st-inspect`. `` |
| `skills/st-build/SKILL.md:16` | `` `phase` should be `inspect` or `build` `` |
| `skills/st-status/SKILL.md:13` | `Inspect → "you OK the` |
| `skills/st-status/SKILL.md:37` | `stratum:st-inspect` in the hook probe |
| `skills/st-model/SKILL.md:10-11` | the 10 agents in sorted order, `` `st-inspect` `` between `` `st-git` `` and `` `st-plan` `` (checked by `test_st_model_skill_matches_hook`, `tests/test_model_files.sh:42` and the old-name search, no phrase check) |
| `skills/st-model/SKILL.md:35` | `stratum:st-inspect` in the hook probe |
| `skills/st-init/SKILL.md:26` | `Show a table of the 10 agents` |
| `tests/test_model_files.sh:31` | `stratum:st-inspect` in the hook probe |
| `README.md:75` | `` \| 3 \| Inspect \| `st-inspect` checks the files agree and the plan can be built \| You OK the build \| `` |
| `README.md:90` | `` `st-define`, `st-plan`, `st-inspect`, `st-build`, `st-close` `` |
| `README.md:114-115` | one row `` \| `st-inspect` \| Opus \| Spec, plan, and tasks agree; setup, test coverage, breaking changes, security \| `` |
| `README.md:166-168` | the 10 agents in sorted order (checked by `test_docs_cover_feature` and the old-name search, no phrase check) |
| `README.md:171-172` | `` `st-inspect` and `st-review` have no entry and keep the plugin default `` |
| `README.md:259` | add the line `bash tests/test_inspect.sh` after `bash tests/test_model_files.sh` |
| `DESIGN.md:59-60` | one row `` \| `st-inspect` \| Spec Kit analyze + vc validate \| Opus \| No \| Spec, plan and tasks agree, and the plan is buildable: setup, test coverage, breaking changes, security. \| `` |
| `DESIGN.md:82` | `` `st-define`, `st-plan`, `st-inspect`, `st-build`, `st-close` `` |
| `DESIGN.md:119` | `` \| 3 \| Inspect (`st-inspect`) \| analyze and validate in one pass. Findings that need a decision go to the user. \| User OKs the build \| `` |

(`\|` is a plain `|` in the file.)

Repo-wide checks:

- `git grep -nwE 'st-(check|validate)' -- . ':!specs'` prints nothing (research R1).
- `agents/` holds exactly 10 `.md` files.
- `tests/test_model_hook.py` `test_module_constants`: `AGENTS == ["st-build", "st-close",
  "st-debug", "st-fast", "st-git", "st-inspect", "st-plan", "st-quick", "st-review", "st-test"]`.

## 4. Release note (FR-011)

The body of the version bump commit, word for word (research R2). No other trailer.

```text
Bump version to 0.1.27

/stratum:st-check, st-check and st-validate are replaced by /stratum:st-inspect and st-inspect.
The Full lane phase check is now inspect.
A .stratum/models.json that names st-check or st-validate blocks every Stratum agent start.
Rename that entry to st-inspect or drop it.
```
