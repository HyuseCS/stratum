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
| `prompt_id` | PreToolUse, PostToolUse `Agent`, Stop | turn boundary: the transcript read stops at a `user` line whose `promptId` differs (research R10). Missing: the real-prompt rule alone |
| `agent_id` | PreToolUse, PostToolUse | present: no transcript read |
| `transcript_path` | PreToolUse, PostToolUse `Agent`, Stop | reply markers of the current turn |
| `last_assistant_message` | Stop | appended after the transcript text |

Any field missing or of the wrong type: that part does nothing. Exit code is always 0.

## Output

- UserPromptSubmit and PreToolUse Skill: the existing `hookSpecificOutput.additionalContext` line
  (label, out-of-order note), unchanged.
- PreToolUse Agent, PostToolUse, Stop: no output at all.
- Never a `decision`, `permissionDecision` or `continue` field.

## Marker grammar

See [../data-model.md](../data-model.md) "Marker lines" and "Transcript turn".
