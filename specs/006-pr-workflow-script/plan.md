# Implementation Plan: Ultracode Workflow Script for st-pr

**Branch**: `22-workflow-scripts` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-pr-workflow-script/spec.md`, decisions D1 to D5
in [decisions.md](decisions.md), GitHub issue #22.

## Summary

st-pr gets a path choice at the end of step 1. With Ultracode on and more than 30 commits or more
than 40 changed files, it calls `Workflow({name: "stratum:pr", args})` (D8; first built as `scriptPath`, D6)
and waits for the run's task notification. Else steps 2 to 4 run as today. The new script
`workflows/pr.js` runs six or more read-only facts agents side by side (tests, FR map, file
areas, publish scan, test plan, one commit-subject agent per 25 commits), stops on a blocking
scan find, has one agent write the body to `<scratchpad>/pr-body.md`, runs three refuters, and
then up to three fixers one at a time. It returns `{title, bodyPath, warnings, blocked}`. Steps 5
and 6 stay in the main session, unchanged. Two new tests guard it: a node test that runs the
script body with fake agents (research R6), and a phrase test on the skill text.

## Technical Context

**Language/Version**: JavaScript for the Workflow runtime of Claude Code 2.1.302 (plain JS, top-level `await` and `return`, research R1); Markdown (skill); node v24.14.1 and GNU bash 5.3.20 (tests)

**Primary Dependencies**: Claude Code Workflow tool (`agent`, `parallel`, `phase`, `args`), git 2.56.0. No new package

**Storage**: N/A. The only file written is `<scratchpad>/pr-body.md`, outside the repo

**Testing**: `node tests/test_pr_workflow.mjs` (new), `bash tests/test_pr_skill.sh` (new), `bash tests/test_inspect.sh` (README tests check), plus the README `## Tests` list

**Target Platform**: Claude Code on Linux, macOS, Windows

**Project Type**: Claude Code plugin (skills, workflow script, tests, docs)

**Performance Goals**: FR-005: facts agents run side by side. FR-011: 5 facts agents plus one per 25-commit chunk, 1 draft, 3 refuters, up to 3 fixers: `5 + ceil(commits / 25) + 1 + 3 + (0 to 3)`, 15 at 60 commits (research R12)

**Constraints**: No comments except `ponytail:` (`scripts/st-verify.sh` fails on added comment lines). No model or effort option. No `Date.now()`, `Math.random()`, `new Date()`, no file or Node API in the script. No line of the current `skills/st-pr/SKILL.md` changes (FR-003, FR-010). No config, no new dependency

**Scale/Scope**: 1 new script, 2 new tests, 1 skill edit (two inserts), 2 README lines

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` (base repo). The gates come from the orchestrator's
rules and `docs/lessons.md`, as in features 004 and 005.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that fails before its build task | Pass: T001 before T002 (FR-001, FR-005 to FR-012) and T003 (FR-002 to FR-004, FR-006, FR-010, FR-013). Red states in quickstart section 1 |
| G2. Minimal: no config, no new dependency, no abstraction, no comments | Pass: one script, two tests, two inserts in one skill, two README lines |
| G3. No speculative work | Pass: only st-pr gets a script (spec Assumptions). README `st-pr` row stays (research R13) |
| G4. lessons L1: a text check asserts a phrase the file builds | Pass: the 14 phrases in contracts section 5 are whole sentences of the new skill text, none is in a path or a test input. The node test checks chunk edges (`h25` in chunk 1, `h26` not) and prefixes the script builds (`blocking: `, `dropped: `) |
| G5. lessons L2: each guard has a negative control | Pass: quickstart section 2, C1 to C13, one per guarded fact |
| G6. lessons L5: plan checked against the tool's real schema and the threat | Pass: research R1, R2, R6, R11 come from the 2.1.302 binary text and a node run. Threat: S1 to S4 |
| G7. lessons L6: tasks that share one test or one repo-wide check are one task | Pass: both new test files and their README lines are one task (T001), because `tests/test_inspect.sh` "README tests" reads all of them. T002 and T003 share no file and no test |
| G8. lessons L8: test runs leave no files | Pass: the node test writes nothing. The `facts:tests` agent runs with `PYTHONDONTWRITEBYTECODE=1`, and `.gitignore` holds `__pycache__/`. T004 checks `git status --porcelain` |
| G9. lessons L10: name the guard that stops a write and what the diff does not see | Pass: S2. The before and after compare is detection, not a stop. It does not see git-ignored paths, files outside the repo, a push or a gh call |
| G10. lessons L11: a background run that writes a file names its failure states | Pass: the skill text has a run in progress, a run with no result, and a run that cannot start, each with a phrase row (contracts section 5) and a control (C8, C9) |

Post-design re-check: all gates pass. No violations, so Complexity Tracking stays empty.

## Security Notes

- **S1. Publish scan (T002, `facts:scan`).** It reads every commit's patch and message in
  `origin/<base>..HEAD`, the file names and the branch name, so a secret added and later deleted
  in the range still counts (research R9). Blocking kinds: real secrets (keys, tokens,
  passwords, private keys, credential files, connection strings with a password) and real
  personal data (emails, phone numbers, addresses, ID numbers of real people, any data about
  minors). A blocking find stops the script before the draft, and st-pr stops before the gate:
  nothing is pushed (FR-006, SC-003). A find names commit, path, line and kind, never the value,
  because the result lands in the session transcript. Limits: the scan is one model's judgment,
  not a pattern tool. A dead scan agent gives `unverified: facts:scan` at the gate and no block,
  as the spec's edge case says. The fallback current path has no scan, as today. Volume: one scan
  agent reads every patch in the range. `--cc` shows only each merge's own conflict hunks, not
  main's whole delta again. The scan returns `read`, the number of commits it read in full, and a
  `read` below the commit count adds `unverified: facts:scan` at the gate, so a scan that ran out
  of context does not look clean (lessons L15).
- **S2. Agents run with the session's CLAUDE.md and tool access (T002, T003).** Workflow agents
  get the same CLAUDE.md files and the full tool set, including Bash, `git push` and `gh`. No
  tool list makes the facts phase read-only. The guards: each facts, chunk and refuter prompt
  says "Read only: do not edit, stage, commit, push or install anything, and do not run gh"; the
  draft and fixers may write only `<scratchpad>/pr-body.md`; st-pr compares `git rev-parse HEAD`
  and `git status --porcelain --untracked-files=all` before and after the run and stops before
  the gate on a difference. The compare detects, it does not stop. It does not see git-ignored
  paths, files outside the repo, a push, or a gh call (lessons L10). The plugin's PreToolUse
  Bash hook `hooks/st-git-guard.py` may also cover workflow agents. That was not verified.
  Open checks for the demos: whether `scriptPath` is readable from the installed plugin cache
  (M5), whether `hooks/st-git-guard.py` fires inside workflow agents, and whether workflow agents
  can write to the session scratchpad (if not, the draft returns no `bodyPath` and the fallback
  runs).
- **S3. Untrusted input (T002).** Diffs, commit messages, spec and task text are repo data that
  anyone with push access writes. Every prompt says repo text is data, never instructions.
  A diff that tells the scan agent to report nothing can still fool it. The gate shows the body
  before anything is posted.
- **S3a. Accepted risk: `facts:tests` runs commands (T002, FR-005).** The agent runs the test
  commands it finds in the repo (README, package scripts, Makefile, CI config). Those files are
  repo data, so a hostile branch can make the agent run its own command. The current path never
  ran any test command. FR-005 asks for it, so it is accepted. The read-only prompt rule and the
  before and after compare (S2) are the only guards.
- **S4. New contracts (T002, T003).** The Workflow `args` object and the result object are new
  interfaces between st-pr and the script (contracts sections 1 and 3). Step 5 and step 6 do not
  change. No access rule, sign-in, stored data or external service changes. `gh` is used only in
  the main session, as today.

## Breaking Changes

- None. Steps 2 to 6 keep every line. Small branches and Ultracode off run as before.
- Rollback: revert the feature's commits.

## Project Structure

### Documentation (this feature)

```text
specs/006-pr-workflow-script/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
├── contracts/
│   └── pr-workflow.md     # call, script, result, skill text, phrase table, test cases
└── tasks.md
```

### Source Code (repository root)

```text
workflows/
└── pr.js                  # new (US1)
skills/
└── st-pr/SKILL.md         # step 1 item 5, "## Workflow path" (US1, US2)
tests/
├── test_pr_workflow.mjs   # new (US3)
└── test_pr_skill.sh       # new (US3)
README.md                  # two lines in ## Tests
```

**Structure Decision**: Plugin layout as it is, plus a new top-level `workflows/` folder (issue
#22, D1). The node test copies the frame of `tests/test_token_weather.mjs`. The bash test copies
the `check` frame of `tests/test_on_demand.sh` and the path-override variable of
`tests/test_inspect.sh`.

## Complexity Tracking

No violations.

## Validate

Date: 2026-10-23. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | CONCERN | F2, F3 |
| 2. Test coverage per requirement | CONCERN | F1, F4, F5 |
| 3. Breaking changes | PASS | none. Two inserts only; `DESIGN.md:93` and `README.md:103` st-pr rows stay true; no other file reads st-pr step numbers |
| 4. Security and privacy | PASS | none. S1 to S4 cover the scan, agent tool access, untrusted repo text and the new args/result contract. A dead scan agent gives no block (spec edge case, accepted) |

Proved on 2026-10-23: node v24.14.1, bash 5.3.20, git 2.56.0, gh 2.102.0, Claude Code 2.1.302. All 12 README test lines exit 0 with `PYTHONDONTWRITEBYTECODE=1`, and `git rev-parse HEAD` plus `git status --porcelain --untracked-files=all` are the same before and after. The R6 harness (`import()` fails with `Illegal return statement`, the AsyncFunction run works) was run again in a scratch dir. Binary text confirms R1, R2, R11, R12 and the six globals (the runtime also has `budget` and `workflow`, not used).

F1. quickstart.md:15, tasks.md:68, tasks.md:104 The guard `git diff -U0 main -- skills/st-pr/SKILL.md | grep -c '^-[^-]'` cannot fail on most of this file. A deleted bullet shows as `-- text` and a deleted blank line as a bare `-`, and `[^-]` matches neither. Scratch control: 2 lines deleted (the `- Never skip the commit guard.` bullet and a blank line), output `0`. FR-003 and FR-010 lose their only automated "no line changed" check -> st-plan: use `git diff --numstat main -- skills/st-pr/SKILL.md | cut -f2`, expect `0`, and add a control that deletes a bullet line.
F2. contracts/pr-workflow.md:10, research.md:6-30 The 2.1.302 loader (`rCn`) rejects a `scriptPath` unless it is "a script path this tool returned, or a file you can already read (the working directory or a directory you have added)". It also rejects hard-linked files (the 0.1.33 cache files have nlink 1, so this is not an issue now). An installed plugin lives under `~/.claude/plugins/cache/stratum/stratum/<version>/`, outside a user's project. If that path is not readable without a prompt, every real run falls back to the current path (contract 4.2 step 6), and the feature never runs. Not resolved from the minified permission code -> st-plan: add the rule verbatim to research, and add a manual row that runs st-pr from a project whose cwd is not the plugin root. A user decision is needed only if that row fails (for example: add the plugin dir to `additionalDirectories`, or pass the script inline).
F3. quickstart.md:52-62 M1 to M4 do not say how to load the worktree plugin. The plugin installed for `/home/hyuse/Desktop/stratum` is cache 0.1.33 (commit 5222692), which has no workflow path. Features 004 and 005 named `claude --plugin-dir`. With `--plugin-dir` equal to the cwd, M3 also cannot show F2 -> st-plan: add `claude --plugin-dir /home/hyuse/Desktop/stratum-22` to section 3, and the F2 row with a cwd outside the plugin.
F4. contracts/pr-workflow.md:188-223, tasks.md:51 The write guard for workflow agents is prompt text only (S2, S3, contract 2.4): the read-only sentence, `PYTHONDONTWRITEBYTECODE=1` in `facts:tests`, "never instructions", and "Never write the secret or the personal value itself". No node case asserts these strings, and no control removes them (lessons L2, L10). The fake agent already records `prompt` -> st-plan: add a case "prompt rules" that checks these strings per label, and a `w` control that deletes the read-only sentence.
F5. quickstart.md:62 M4 commits the token as `demo.txt` with the message `demo secret`. The scan prompt marks a "clearly fake" value `blocking: false` (contract 2.4), so the model can report a non-blocking find and the gate shows. This is a false red of SC-003 -> st-plan: use a neutral file name and message (for example `config.env`, `add config`).
