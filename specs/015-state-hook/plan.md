# Implementation Plan: State writes from the hook only

**Branch**: `086-state-hook` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/015-state-hook/spec.md`

## Summary

Four `state.json` writes move from skill lines (`scripts/st-state.sh` calls the session runs in the
main chat) into `hooks/st-phase.py`: `risk`, `feature_directory`, `phase: done` and the reply-label
clear (`skill: ""`). The hook gets three new events (PreToolUse `Agent`, PostToolUse, Stop). It reads
marker lines from the main session's reply text of the current turn in the transcript, the
`risk <level>` prompt, and the `specs/` folder. The six skill lines say a marker instead of running
the script, and the script is deleted. See [research.md](research.md) R1-R9.

## Technical Context

**Language/Version**: Python 3 (stdlib only: `json`, `os`, `re`, `subprocess`, `tempfile`), Bash for the text tests.

**Primary Dependencies**: Claude Code hook input as measured on 2.1.316 (research R1, R2). `git` for the main-checkout path.

**Storage**: `.stratum/state.json` (cwd-walked file) and the main checkout's `.stratum/state.json` (risk only).

**Testing**: `unittest` in `tests/test_phase_hook.py` (runs the hook as a subprocess with JSON input and a fixture transcript). Phrase checks in `tests/test_state.sh`, `tests/test_inspect.sh`, `tests/test_risk_rules.sh`. No runner script and no CI: the README "Tests" list runs each file alone. One test: `python3 tests/test_phase_hook.py PhaseHookTest.test_<name>`.

**Target Platform**: Linux and macOS, any machine with the plugin loaded.

**Project Type**: Claude Code plugin (hooks, skills, procedures).

**Performance Goals**: The hook stays far below its 10 s timeout. Stop runs every turn: the transcript read stops at the turn start or after 16 MiB (R3).

**Constraints**: Never block, never print a state value, change nothing on any error (FR-012). Atomic writes (FR-008). Write only on change (R9). No explanatory comments in code; `# ponytail:` markers only.

**Scale/Scope**: One hook file, one wiring file, six skill lines, one deleted script, four test files, one design doc paragraph.

## Constitution Check

No `.stratum/constitution.md` in this repo (base repo) and no `apps/*/ORDINANCE.md`. No gates apply. Re-check after design: still none.

## Design

### Hook events after the change

| Event (matcher) | Today | New reads | New writes (file) |
|-----------------|-------|-----------|-------------------|
| UserPromptSubmit | phase, lane, held label, label line | prompt that is only `risk <level>` | `risk` (main) |
| PreToolUse `Skill\|Agent` | phase, lane, held label (Skill only) | reply markers, when no `agent_id` | `risk` (main), `phase` done, `skill` "" (cwd) |
| PostToolUse `Bash\|Write\|Edit\|MultiEdit` | none | `specs/` scan, only while `phase` is `define` | `feature_directory` (cwd) |
| PostToolUse `Agent` | none | `specs/` scan (define only), reply markers when no `agent_id` | all four |
| Stop | none | reply markers plus `last_assistant_message` | `risk` (main), `phase` done, `skill` "" (cwd) |

The marker grammar, the turn rule and the file rules are in [data-model.md](data-model.md) and
[contracts/hook.md](contracts/hook.md). The new skill lines are in
[contracts/skill-lines.md](contracts/skill-lines.md).

### Order inside one hook run

1. Read input. A PreToolUse input with no `skill` (the Agent call) must not fail: compute the skill
   name only for UserPromptSubmit and for `tool_name == "Skill"`. Today
   `"/" + (tool_input or {}).get("skill")` raises on the Agent input (`hooks/st-phase.py:22`) and the
   hook returns.
2. Find the cwd-walked state file as today (`hooks/st-phase.py:29-38`). Missing or bad: return before
   any transcript read (Stop runs in projects without Stratum too).
3. Apply the markers of the current turn (text before this event), then the `specs/` scan, then the
   existing phase, lane and held-label logic on the updated state.
4. Write the cwd file once if it changed. Write the risk to the main file if it changed (one write
   if both paths are the same file).
5. Print the label and out-of-order notes exactly as today. Stop and PostToolUse print nothing.

### Parity with today (SC-002)

| Step | Value today (skill line) | Writer after | Same file |
|------|--------------------------|--------------|-----------|
| Lane pick | `risk` in main checkout | hook, `Lane:` line | yes |
| User's `risk <level>` | `risk` in main checkout | hook, prompt or repeated `Lane:` line | yes |
| Define (specify) | `feature_directory`, `phase define`, `lane full` in `.stratum/state.json` | `phase`, `lane`: hook at st-define start (today too). `feature_directory`: hook `specs/` scan | yes |
| Plan, Inspect, Build start | `phase`, `lane` | unchanged | yes |
| Build end | `skill ""` in main checkout | hook, `Build done.` line | cwd file (same in main checkout, spec Assumptions) |
| Close end, Fast end | `phase done` in `<project>` | hook, `Phase: done` line | yes |

### Known limits

- A `Phase: done` or `Build done.` line stays in the turn. If the same turn later starts another
  phase skill, Stop applies the marker again after it. The skills say these lines at the end of a
  run, before a user gate, so a later phase in the same turn does not happen in the lanes today.
- `procedures/specify.md` keeps its `{}` start line (spec Assumptions). With a fresh `{}` file the
  phase is not `define`, so the hook records no feature until `/stratum:st-define` runs again.
- Interactive mode transcript timing is not measured (R1).

## Security notes

- **Data model** (`state.json`): the hook writes four keys in two files. Values are fixed sets
  (`high|normal|low|none`, `done`, `""`) or a `specs/NNN-*` folder name the hook read from disk.
  Writes are atomic (`mkstemp` in the same folder, then `os.replace`) and happen only on change.
- **Personal data**: the transcript holds the user's prompts and the replies. The hook reads it,
  keeps only the marker values, prints nothing and stores nothing else.
- **External process**: `git rev-parse --path-format=absolute --git-common-dir` runs with a list of
  arguments (no shell) in the input's `cwd`, with a 3 s timeout. A failure falls back to the
  cwd-walked file.
- **Trust**: hook input comes from Claude Code. The transcript path is read only and never written.
  A missing, unreadable or bad transcript gives no markers.
- No sign-in, access rules, secrets, minors' data or external service.

## Project Structure

### Documentation (this feature)

```text
specs/015-state-hook/
├── spec.md
├── plan.md              # this file
├── research.md          # R1 (orchestrator), R2-R9
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── hook.md          # hook input fields read, marker grammar, outputs
│   └── skill-lines.md   # the six new skill lines, word for word
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
