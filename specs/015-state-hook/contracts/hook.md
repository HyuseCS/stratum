# Contract: `hooks/st-phase.py`

## Wiring (`hooks/commands.json`)

| Event | Matcher | Entry |
|-------|---------|-------|
| UserPromptSubmit | none | unchanged (after the ponytail tracker) |
| PreToolUse | `Skill\|Agent` | the existing `Skill` entry, matcher widened. The `Agent` entry with `st-models.py` stays its own entry (`tests/test_model_hook.py:257` needs exactly one `Agent` matcher) |
| PostToolUse | `Bash\|Write\|Edit\|MultiEdit\|Agent` | new entry |
| Stop | none | new entry |

Every entry: `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/st-phase.py"`, `"timeout": 10`.

## Input fields read

| Field | Events | Use |
|-------|--------|-----|
| `hook_event_name` | all | event switch |
| `cwd` | all | find the state file; `git` working folder for the risk path |
| `session_id` | UserPromptSubmit, PreToolUse | held label (unchanged) |
| `prompt` | UserPromptSubmit | phase skill name (unchanged), `risk <level>`, the text after `/stratum:st-define` (description or none, for `define_before`) |
| `tool_name` | PreToolUse, PostToolUse | `Skill` gives a skill name; `Agent` reads markers |
| `tool_input.skill` | PreToolUse Skill | phase skill name (unchanged) |
| `tool_input.args` | PreToolUse Skill `st-define` | non-blank: set `define_before`; blank or missing: remove it |
| `prompt_id` | PreToolUse, PostToolUse `Agent`, Stop | turn boundary: the transcript read stops at a `user` line whose `promptId` differs, and keeps only the reply text after the first `user` line with this `prompt_id` (research R10). Missing: the real-prompt rule alone |
| `agent_id` | PreToolUse, PostToolUse | present: no transcript read |
| `transcript_path` | PreToolUse, PostToolUse `Agent`, Stop | reply markers of the current turn |
| `last_assistant_message` | Stop | appended after the transcript text |

Any field missing or of the wrong type: that part does nothing. The exit code is 0 unless a write
fails (a folder that cannot take the temp file): then Python prints a traceback and exits 1. No file
is half written, and only exit 2 blocks in Claude Code (not measured live).

## Output

- UserPromptSubmit: the existing `hookSpecificOutput.additionalContext` line (the label, and the
  out-of-order note when there is one), unchanged.
- PreToolUse Skill: the out-of-order note only, when there is one, unchanged.
- PreToolUse Agent, PostToolUse, Stop: no output at all.
- Never a `decision`, `permissionDecision` or `continue` field.

## Marker grammar

See [../data-model.md](../data-model.md) "Marker lines" and "Transcript turn".
