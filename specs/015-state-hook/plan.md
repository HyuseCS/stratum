# Implementation Plan: State writes from the hook only

**Branch**: `086-state-hook` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/015-state-hook/spec.md`

## Summary

Four `state.json` writes move from skill lines (`scripts/st-state.sh` calls the session runs in the
main chat) into `hooks/st-phase.py`: `risk`, `feature_directory`, `phase: done` and the reply-label
clear (`skill: ""`). The hook gets three new events (PreToolUse `Agent`, PostToolUse, Stop). It reads
marker lines from the main session's reply text of the current turn in the transcript, the
`risk <level>` prompt, and the `specs/` folder. The six skill lines say a marker instead of running
the script, and the script is deleted. See [research.md](research.md) R1-R10.

## Technical Context

**Language/Version**: Python 3 (stdlib only: `json`, `os`, `re`, `subprocess`, `tempfile`), Bash for the text tests.

**Primary Dependencies**: Claude Code hook input as measured on 2.1.316 (research R1, R2). `git` for the main-checkout path.

**Storage**: `.stratum/state.json` (cwd-walked file) and the main checkout's `.stratum/state.json` (risk only).

**Testing**: `unittest` in `tests/test_phase_hook.py` (runs the hook as a subprocess with JSON input and a fixture transcript). Phrase checks in `tests/test_state.sh`, `tests/test_inspect.sh`, `tests/test_risk_rules.sh`. No runner script and no CI: the README "Tests" list runs each file alone. One test: `python3 tests/test_phase_hook.py PhaseHookTest.test_<name>`.

**Target Platform**: Linux and macOS, any machine with the plugin loaded.

**Project Type**: Claude Code plugin (hooks, skills, procedures).

**Performance Goals**: The hook stays far below its 10 s timeout. Stop runs every turn: the transcript read stops at the turn start or after 16 MiB (R3).

**Constraints**: Never block, never print a state value, change nothing on any error (FR-012). Atomic writes (FR-008). Write only on change (R9). No explanatory comments in code; `# ponytail:` markers only.

**Scale/Scope**: One hook file, one wiring file, six skill lines plus the st-define step 2 text, one deleted script, four test files, one design doc paragraph.

## Constitution Check

No `.stratum/constitution.md` in this repo (base repo) and no `apps/*/ORDINANCE.md`. No gates apply. Re-check after design: still none.

## Design

### Hook events after the change

| Event (matcher) | Today | New reads | New writes (file) |
|-----------------|-------|-----------|-------------------|
| UserPromptSubmit | phase, lane, held label, label line | prompt that is only `risk <level>`; text after `/stratum:st-define` | `risk` (main); `define_before` set or removed (cwd) |
| PreToolUse `Skill\|Agent` | phase, lane, held label (Skill only) | reply markers, when no `agent_id`; `tool_input.args` of `st-define` | `risk` (main), `phase` done, `skill` "", `define_before` set or removed (cwd) |
| PostToolUse `Bash\|Write\|Edit\|MultiEdit` | none | new-folder scan of `specs/`, only while `phase` is `define` and `define_before` is a list | `feature_directory` set and `define_before` removed (cwd) |
| PostToolUse `Agent` | none | new-folder scan (as above), reply markers when no `agent_id` | all four, and `define_before` removed |
| Stop | none | reply markers plus `last_assistant_message` | `risk` (main), `phase` done, `skill` "" (cwd) |

The marker grammar, the turn rule and the file rules are in [data-model.md](data-model.md) and
[contracts/hook.md](contracts/hook.md). The new skill lines are in
[contracts/skill-lines.md](contracts/skill-lines.md).

### Order inside one hook run

1. Read input. The skill name comes from a UserPromptSubmit prompt or from a `Skill` tool call
   (`tool_input.skill`). An Agent input has no `skill`, so none is read from it.
2. Find the cwd-walked state file: walk up to the first folder with `.stratum/` or `.git`. If the
   file cannot be loaded and the walk found neither a `.stratum/` folder nor a `.git` file, return
   before any transcript read (Stop runs in projects without Stratum too). If the file cannot be
   loaded but the walk found one of those, the run goes on with no state file: the cwd file gets no
   key, and the risk still reaches the main checkout (a linked worktree with no `state.json`).
3. Read the current turn's reply markers when the input has no `agent_id`, on PreToolUse `Skill` and
   `Agent`, PostToolUse `Agent` and Stop (Stop appends `last_assistant_message`). `risk` is the last
   `Lane:` line, or the `risk <level>` prompt on UserPromptSubmit.
4. With a loaded state file only: the done and clear markers set `phase` to `done` and `skill` to
   `""`. On PostToolUse while `phase` is `define` and `define_before` is a list, the new-folder scan
   runs (data-model.md "`feature_directory` transition"). Then the existing phase, lane and
   held-label logic runs on the updated state. A Define with a description sets `define_before` in
   the same step that sets `phase` to `define`. A Define with no description removes it.
5. Writes: the risk goes to the main checkout's file first, one write when it is the cwd file too.
   Then the cwd file is written once, if it changed. A main file that is missing or bad is not
   created or rewritten.
6. Print: the label (UserPromptSubmit only) and the out-of-order note (UserPromptSubmit or Skill).
   PreToolUse Agent, PostToolUse and Stop print nothing.

### Parity with today (SC-002)

| Step | Value today (skill line) | Writer after | Same file |
|------|--------------------------|--------------|-----------|
| Lane pick | `risk` in main checkout | hook, `Lane:` line | yes |
| User's `risk <level>` | `risk` in main checkout | hook, prompt or repeated `Lane:` line | yes |
| Define (specify) | `feature_directory`, `phase define`, `lane full` in `.stratum/state.json` | `phase`, `lane`: hook at st-define start (today too). `feature_directory`: hook, the new folder not in `define_before` | yes |
| Plan, Inspect, Build start | `phase`, `lane` | unchanged | yes |
| Build end | `skill ""` in main checkout | hook, `Build done.` line | cwd file (same in main checkout, spec Assumptions) |
| Close end, Fast end | `phase done` in `<project>` | hook, `Phase: done` line | yes |

### Known limits

- A `Phase: done` or `Build done.` line stays in the turn. If the same turn later starts another
  phase skill, Stop applies the marker again after it. The skills say these lines at the end of a
  run, before a user gate, so a later phase in the same turn does not happen in the lanes today.
- `procedures/specify.md` keeps its `{}` start line (spec Assumptions). With a fresh `{}` file the
  Define start found no state file, so `phase` is not `define` and there is no `define_before`: the
  hook records no feature for that run. The user sets `feature_directory` once by hand.
- `define_before` sits in `state.json` only during Define: from a Define start with a description
  until the hook finds the new folder (or a redo removes it). If Define ends with no new `spec.md`,
  the list stays until the next Define start. In a repo with many spec folders the list makes
  `state.json` longer for that time, and a commit made then carries the key.
- Stop may not fire when the user interrupts the reply or the API call fails. A `Phase: done` or
  `Build done.` line said just before is then lost, and the value stays as it was. A `Lane:` line is
  also read at PreToolUse `Skill` and `Agent` and at PostToolUse `Agent`. If Stop does not fire and
  no later Skill or Agent call comes in the turn, the risk is lost.
- Fast lane order (R8): the `Lane:` line and the step-2 read of `st-advisor.sh change` must be in
  different model messages. The skill as written puts the step-1 Agent call in a later message, so
  PreToolUse Agent writes the risk before step 2. If a step-2 read ever ran in the same model message
  as the `Lane:` line, no hook reads between them, and the risk lands only at Stop, after the read.
  This cannot happen with the skill as written.
- A write error (a folder that cannot take the temp file) ends the run with exit 1 and a traceback.
  No file is half written. Only exit 2 blocks a hook in Claude Code, so the session goes on (not
  measured live).
- The hook reads Claude Code's transcript format (`type`, `isMeta`, `isSidechain`, `promptId`,
  `api-request-blob`, `last_assistant_message`), measured on 2.1.316 headless (R1, R2, R4). If the
  format changes, the writes stop with no sign: a stale `risk` picks the wrong advisors and the held
  label sticks. The live check after merge (quickstart.md) runs on both machines, PC and laptop. In a
  Fast run it reads the `advisors:` line of `st-advisor.sh change`: `advisors: none (change, risk low)`
  in the default `auto` mode.
- Interactive mode transcript timing is not measured (R1).

## Security notes

- **Data model** (`state.json`): the hook writes four keys in two files. Values are fixed sets
  (`high|normal|low|none`, `done`, `""`), a list of folder names (`define_before`), or a
  `specs/<name>` folder name the hook read from disk. Two guards keep a bad name out of
  `feature_directory`, a value skills put into shell commands. A folder that came with a clone is
  already on disk when Define starts, so it is in `define_before` and never counts as new. A new
  folder counts only when its name fully matches `[A-Za-z0-9._-]+`, so a name with shell
  characters (such as `x$(y)`) is ignored.
  Writes are atomic (`mkstemp` in the same folder, then `os.replace`) and happen only on change.
- **Personal data**: the transcript holds the user's prompts and the replies. The hook reads it,
  keeps only the marker values, prints nothing and stores nothing else.
- **External process**: `git rev-parse --path-format=absolute --git-common-dir` runs with a list of
  arguments (no shell) in the input's `cwd`, with a 3 s timeout. A `git` failure falls back to the
  cwd-walked file. A missing or bad main file is never created or rewritten.
- **Trust**: hook input comes from Claude Code. The transcript path is read only and never written.
  A missing, unreadable or bad transcript gives no markers.
- No sign-in, access rules, secrets, minors' data or external service.

## Project Structure

### Documentation (this feature)

```text
specs/015-state-hook/
├── spec.md
├── plan.md              # this file
├── research.md          # R1 (orchestrator), R2-R10
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── hook.md          # hook input fields read, marker grammar, outputs
│   └── skill-lines.md   # the new skill lines (L1-L7), word for word
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
hooks/
├── st-phase.py          # extend: markers, risk prompt, specs/ scan, Agent/PostToolUse/Stop input
└── commands.json        # wiring: PreToolUse Skill|Agent, PostToolUse, Stop
scripts/
└── st-state.sh          # delete
skills/
├── st/SKILL.md          # line 37
├── st-define/SKILL.md   # lines 24-27 (step 2 text)
├── st-close/SKILL.md    # line 58
├── st-fast/SKILL.md     # line 41
├── st-build/SKILL.md    # line 77
└── st-worker/SKILL.md   # line 52
procedures/
└── specify.md           # line 41
DESIGN.md                # D20, D21: hook events and who clears the label
tests/
├── test_phase_hook.py   # new hook tests, wiring test, test_agents_write_done phrase
├── test_state.sh        # phrase table only (R6)
├── test_inspect.sh      # H2 row
└── test_risk_rules.sh   # R3 row
```

**Structure Decision**: extend the existing hook and tests in place. No new script, module or test file.

## Complexity Tracking

None.

## Validate

Date: 2026-11-06. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | CONCERN | F8 |
| 2. Test coverage per requirement | CONCERN | F9 |
| 3. Breaking changes | PASS | none |
| 4. Security and privacy | CONCERN | F10 |

Proof: Python 3.14.9, git 2.56.0 (`--path-format` needs 2.31+), bash 5.3.20, Claude Code 2.1.316 (the version R1 and R2 measured). No new package. Baseline green: `test_phase_hook.py` (23), `test_model_hook.py` (35), `test_state.sh`, `test_inspect.sh`, `test_risk_rules.sh`. The planned marker patterns give the expected result on every positive and negative row of T003 and T009. Callers of `scripts/st-state.sh`: the six FR-009 lines and `tests/test_state.sh` only, all in tasks; branch `074-prompt-answers` adds no new caller. `tests/test_model_hook.py:257` (one `Agent` matcher) and `tests/test_approve_hook.py:494` stay valid with the new wiring. No stored-data change, no migration.

F8. research.md:27, data-model.md:39-55 The hook reads Claude Code's transcript JSONL (`isMeta`, `isSidechain`, `api-request-blob`, `last_assistant_message`), measured only on 2.1.316 headless. On a format change the hook stops writing with no sign: stale `risk` picks the wrong advisors, the held label sticks. -> Add this to "Known limits" and run the live check (quickstart.md:47-60) on both machines after merge.

F9. spec.md:55, spec.md:76, quickstart.md:47 FR-003 (risk lands before `st-advisor.sh change`) and SC-002 (Full-run parity) have no test that can fail before merge. The hook tests prove reads at PostToolUse `Agent` and Stop, not the order against the advisor. -> Accepted by spec Assumptions; the live check is the only proof. Keep it on the merge checklist.

F10. data-model.md:31, tasks.md:63 The `specs/` scan takes any folder name that starts with `^\d{3}-`. A folder in a cloned repo such as `999-x$(...)` with a `spec.md` wins the scan and becomes `feature_directory`, a value skills put into shell commands. -> Tighten to `^\d{3}-[a-z0-9-]+$` (every folder in `specs/` matches it) and add a T007 row. Needs a user decision (it narrows FR-004).
