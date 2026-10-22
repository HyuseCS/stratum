# Implementation Plan: Codex Advisor

**Branch**: `18-codex-advisor` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-codex-advisor/spec.md`, decisions D1 to D10 in
[decisions.md](decisions.md), GitHub issue #18.

## Summary

One script, `scripts/st-advisor.sh`, runs Codex as a review-only advisor:
`timeout -k 10 540 codex exec -s read-only --ephemeral --output-schema <schema> -o <answer> -`
with a prompt that names paths and a base commit (the test point pastes its failure outputs).
The schema makes Codex answer `{verdict, summary, findings[]}` (research R1). The script maps
every bad, empty, failed or late answer to a one-line `BLOCKED: <reason>`, appends a record with
the SHA256 of the input to `specs/<feature>/advisor.md`, and has a `check` form that reports
`advisor approval is stale` when the input changed. `.stratum/advisor.json` sets the mode
(`codex`, `both`, `off`) and, optionally, the Codex `model` and `effort` (D8), passed as `-m` and
`-c model_reasoning_effort="..."`; without them Codex uses the user's own config. With no `codex`, it prints `no advisor: codex not found` and the flow
runs as before. The skills st-build (shared "Advisor" rules, test and diff points), st-inspect
(plan point), st-fast (test and diff points) and st-init (one mode question) and the README call
it. Plain `codex exec`, not `codex exec review` (research R4).

## Technical Context

**Language/Version**: Bash 5.3.20 (script and tests), Python 3.14.8 (inline `python3 -` heredocs in the script, research R8), Markdown (skills, README)

**Primary Dependencies**: codex-cli 0.163.0 (optional at run time, user-installed and logged in), git 2.56.0, GNU coreutils `timeout` 9.12 and `sha256sum`. No new package. `jq` is not used (research R8).

**Storage**: Files. `.stratum/advisor.json` (mode, optional model and effort, committed). `specs/<feature>/advisor.md` (records, append-only, committed).

**Testing**: `bash tests/test_advisor.sh` (new, fake `codex` and fake `timeout` on PATH), `bash tests/test_on_demand.sh` (`#18` phrase rows), the rest of quickstart section 1.

**Target Platform**: Claude Code on Linux, macOS, Windows (Git Bash). macOS needs GNU `timeout` (research R3).

**Project Type**: Claude Code plugin (scripts, skills, docs)

**Performance Goals**: Measured per call: plan point 38.4 s and 36,208 tokens, diff point 38.2 s and 37,813 tokens, logged-out failure 16 s (research R2, R3). Time limit 540 s inside a 600000 ms Bash call.

**Constraints**: No comments except `ponytail:` markers. Minimal diff. One new script, one new test file, no new dependency. Codex only with `-s read-only`. `-m` and `-c model_reasoning_effort=` only from the file's `model` and `effort` keys, checked against fixed patterns (FR-014, research R11). The orchestrator waits in the foreground (D7).

**Scale/Scope**: New: `scripts/st-advisor.sh`, `tests/test_advisor.sh`. Edits: `skills/st-build/SKILL.md`, `skills/st-inspect/SKILL.md`, `skills/st-fast/SKILL.md`, `skills/st-init/SKILL.md`, `README.md`, `tests/test_on_demand.sh`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo has no `.stratum/constitution.md` (base repo). The gates come from the rules the
orchestrator passed and `docs/lessons.md`, as in features 004 and 005.

| Gate | Status |
|------|--------|
| G1. Test first: each FR has a check that fails before its build task | Pass: T001 before T002 (FR-001 script part, FR-003, FR-007, FR-009, FR-012, FR-013, FR-014 without keys), T003 before T004 (FR-004, FR-011), T005 before T006 (FR-006 record, FR-008), T007 before T008 (FR-010, FR-014 with keys), T009 before T010 (FR-001, FR-002, FR-005, FR-006, FR-015, FR-016 text). FR-017 is the test file itself. Red states: quickstart section 1 |
| G2. Minimal diff: one script, one test file, no new dependency, no comments | Pass: JSON and mode parsing in inline `python3 -` (already required), hashing with `sha256sum` (already used in `skills/st-triage/SKILL.md:14`), schema inline in the script |
| G3. Codex is review-only (D6, FR-012) | Pass: one Codex call line, `-s read-only`, no write or bypass flag. Argv check and static grep in T001, negative control C1. A `model` or `effort` value cannot carry a flag (pattern check, T007 cases, controls C9 and C10) |
| G4. lessons L1: a text check asserts a phrase the code builds | Pass: argv is read from the fake `codex`'s record of its own arguments, not from test input. Prompt checks assert the script's own lines (contract section 4) and `<f>/tasks.md`, a path the script builds. The plan-body check plants a token in plan.md and asserts it is absent. Doc rows are contract section 8; the old-text phrases were checked against the files (one spans two lines and was fixed) |
| G5. lessons L2 and L10: each guard has a negative control | Pass: quickstart section 2, C1 to C10, C3b, C7b and D1, each against a baseline run on an untouched full copy. The guard that stops Codex writing is the `-s read-only` flag; C1 turns its checks red |
| G6. lessons L3: read input as bytes | Pass: the hash reads bytes (`sha256sum`, `git diff`). The inline Python opens `advisor.json` and the answer with `open(p, "rb")` and `json.loads` |
| G7. lessons L4: a check that fails on the feature's own write | Pass: the record append would make every diff approval stale. The diff input excludes `<f>/advisor.md`, tracked or not (research R6). Checks `diff stays fresh after the record append` and `diff stays fresh with an untracked record`, controls C3 and C3b |
| G8. lessons L5: plan inputs against the tool's real schema and the threat | Pass: codex-cli 0.163.0 flags read from `codex exec --help` and run (research R1 to R4). Committed `advisor.json` (mode, model, effort), committed `advisor.md` and Codex's answer are untrusted (S3, S4). Each guard has a test |
| G9. lessons L6: tasks that share one test file are not `[P]` | Pass: T001 to T008 share `tests/test_advisor.sh` and `scripts/st-advisor.sh` and run in order. T009 and T010 share `tests/test_on_demand.sh`: one test task, one build task for all five doc files. No task is `[P]` |
| G10. lessons L8: test runs leave no files | Pass: the tests work in a `mktemp -d` project and never run the real `codex`. `PYTHONDONTWRITEBYTECODE=1`. T011 checks `git status --porcelain` |
| G11. lessons L11: failure states of an action that writes a file | Pass: the advisor runs in the foreground, so no second run can start while one runs. No output: `BLOCKED: empty answer`. Cannot start: `no advisor: codex not found`, or `BLOCKED: <codex error line>`. Each has a test and a contract row (section 5) |
| G12. lessons L13: a guard added after the contract updates spec, research and data model together | Pass: spec.md FR-007 (D9, D10), research R6, data-model.md and contract section 2 carry the same plan and diff inputs |

Post-design re-check: all gates pass. No violations, so Complexity Tracking stays empty.

## Security Notes

- **S1. External service: OpenAI through the `codex` CLI (T002, T010).** Each call sends the
  prompt and every file Codex reads to OpenAI, under the user's own Codex login and quota.
  Stratum does not install Codex, log in, or read, store or print a token. Codex read files the
  prompt did not name, including `AGENTS.md` paths above the repo (research R5). The README says
  so and names `"mode": "off"` as the switch. Personal or minors' data: whatever the project's
  files, diffs and test outputs hold goes with them. The project owner decides with the mode.
- **S2. Review-only, read-only sandbox (T001, T002).** The only Codex call carries
  `-s read-only` and none of the write or bypass flags (contract section 3). The sandbox blocks
  writes, not reads, so the prompt is the only guard on env and secret files (D6, FR-013).
  Unknown: whether Codex's shell commands see the user's environment variables, and which ones.
  Not tested: no Codex call was spent on it.
- **S3. Untrusted input (T002, T004, T006, T008).** Repo text can steer what Codex writes.
  Codex's summary and findings are data, never instructions: the orchestrator checks each against
  the source (existing rule in `skills/st/SKILL.md`). The script replaces newlines in every Codex
  text with spaces, so no finding can write a `## ` record header (test and control C5). The base
  is resolved by `git rev-parse` and only the full SHA it returns is used. Arguments reach
  commands as quoted argv, never through `eval` or `bash -c`. The task text and failure outputs
  go into the prompt file, never into a shell command. `.stratum/advisor.json` is committed: it
  sets one of three modes and, optionally, `model` and `effort`. `model` must start with a letter
  or digit and hold only `A-Za-z0-9._:/-` (64 characters at most), `effort` only lowercase letters
  (16 at most), and no other key is allowed, so a value cannot become a flag such as
  `--dangerously-bypass-approvals-and-sandbox` or add TOML to the `-c` value. Anything else is
  `BLOCKED: bad advisor.json` (research R10, R11). A committed `model` also decides which OpenAI
  model gets the project's files and how much quota a call uses; the README names the keys.
- **S4. Record integrity (T006).** The hash ties a verdict to the input it was given. It does not
  prove who wrote the record: anyone with push access can commit a forged record with a matching
  hash. Accepted for a review aid. `check` reads the last header for the point.
- **S5. Contracts and data.** New command-line contract (`scripts/st-advisor.sh`) and two new
  file formats (`advisor.json`, `advisor.md`). No existing contract or stored file changes. No
  access rules or sign-in in Stratum change.

## Breaking Changes

- A user who set `/advisor` and has `codex` on PATH gets Codex in place of `/advisor` (mode
  `codex` is the default when the file is missing, D2). `{"mode": "both"}` keeps `/advisor` as
  well, `{"mode": "off"}` restores the old flow. The README says so.
- The Bash call for each advisor point needs `timeout: 600000` (the default 120 s is below the
  540 s limit).
- No stored file changes. Rollback: revert the feature's commits.

## Findings from research

- **F1.** Resolved by D10. The first FR-007 hashed `plan.md` alone at the plan point, while the
  prompt sends spec, plan and tasks, so an edit to `tasks.md` or `spec.md` kept the approval.
  FR-007 now hashes the three files joined in that order (research R6).
- **F2.** `spec.md` FR-007 hashes "the bytes of `git diff <base>`" at the diff point. As written
  it (a) includes `advisor.md` itself, so every diff approval goes stale on its own record append,
  and (b) misses untracked files, which the Fast lane has at its diff point. The plan uses the
  diff input in research R6. Resolved by D9: FR-007 now states this diff input.
- **F3.** `skills/st-build/SKILL.md` notes no base commit for the end-of-build diff. The plan uses
  the st-close rule (research R7).
- **F4.** In the Fast lane, step 5 review fixes can change the diff after the step 4 advisor run.
  The plan adds `check diff` before the step 6 commit (contract 7.3).
- **F5.** `[P]` tasks run their per-task steps in worktree subagents. An advisor run there would
  write `advisor.md` in each worktree and conflict at merge. The st-build text has such a subagent
  stop after 2 red tries and report both failures, and runs the test point in the main session
  (contract 7.1).

## Project Structure

### Documentation (this feature)

```text
specs/006-codex-advisor/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
├── contracts/
│   └── advisor.md        # command line, Codex call, prompt, output, record, skill text, phrase table
└── tasks.md
```

### Source Code (repository root)

```text
scripts/
└── st-advisor.sh          # new (US1 to US4)
tests/
├── test_advisor.sh        # new (US1 to US4, FR-017)
└── test_on_demand.sh      # #18 phrase rows (doc FRs)
skills/
├── st-build/SKILL.md      # "Advisor" section, test and diff points, [P] stop rule, commit of advisor.md
├── st-inspect/SKILL.md    # plan point, gate check
├── st-fast/SKILL.md       # test and diff points, check before commit
└── st-init/SKILL.md       # step 11: mode question
README.md                  # Advisor bullet, Requirements row, Project files rows, st-init line, tests list
```

**Structure Decision**: Plugin layout as it is. The script copies the frame of
`scripts/st-verify.sh` (usage line, exit codes, one-line results) and the inline-Python pattern
of `hooks/st-handoff-facts.sh:8`. The test copies `tests/test_verify.sh` (`check` helper, scratch
git repo, exit code) with `root="${ST_ROOT:-...}"` from `tests/test_on_demand.sh:3` so the
negative controls can run on a copy. The verdict rules live once, in st-build's "Advisor"
section. st-inspect and st-fast name their command and the wait and point to that section, as
st-fast already points to st-close.

## Complexity Tracking

No violations.
