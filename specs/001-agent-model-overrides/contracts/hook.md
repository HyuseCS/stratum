# Contract: `hooks/st-models.py`

Registered in `hooks/commands.json`:

```json
{
  "matcher": "Agent",
  "hooks": [
    { "type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/st-models.py\"", "timeout": 10 }
  ]
}
```

It is a second entry in the `PreToolUse` array, next to the `Bash` git guard entry.

## Input (stdin)

```json
{
  "cwd": "/path/in/project",
  "tool_name": "Agent",
  "tool_input": {
    "description": "...",
    "prompt": "...",
    "subagent_type": "stratum:st-close",
    "model": "sonnet",
    "run_in_background": false
  }
}
```

`tool_input` may hold more fields. The hook keeps every one of them.

## Steps

1. Stdin is not valid JSON: exit 0, no output.
2. `tool_input.subagent_type` does not start with `stratum:`: exit 0, no output. Do not read the
   file.
3. Find the project folder: walk up from `cwd` to the first folder that has `.stratum/` or `.git`.
4. `<project>/.stratum/models.json` does not exist: exit 0, no output.
5. Read and check the whole file (all entries). Any problem, or any exception: deny.
6. No entry for the agent, or the entry is `{}`: exit 0, no output.
7. Else: rewrite.

## Output: rewrite

```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse",
  "updatedInput": {"description": "...", "prompt": "...", "subagent_type": "stratum:st-close",
                   "model": "haiku", "effort": "xhigh", "run_in_background": false}}}
```

- `updatedInput` = a copy of `tool_input` with `model` and `effort` set from the entry. Only the
  keys the entry has are set. A value the call already had is replaced. No key is removed.
- No `permissionDecision` key.
- Exit 0.

## Output: deny

```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse",
  "permissionDecision": "deny",
  "permissionDecisionReason": "<path>/.stratum/models.json: <problem>\n<problem>\nFix the file, then run the step again."}}
```

Exit 0. One line per problem. Each problem names the bad item and the allowed values:

| Case | Problem text must contain |
|------|---------------------------|
| Not valid JSON or not readable | `cannot be read` and the error text |
| Top level not an object | `must be a JSON object` |
| Unknown agent | the bad name and all 11 agent names |
| Entry not an object | the agent name and `model`, `effort` |
| Unknown key | the bad key, the agent name, and `model`, `effort` |
| Unknown model | the bad value, the agent name, and `sonnet`, `opus`, `haiku`, `fable` |
| Unknown effort | the bad value, the agent name, and `low`, `medium`, `high`, `xhigh`, `max` |

The reason always contains `.stratum/models.json`.

## Module names (for the drift test)

The test loads the hook with `importlib.util.spec_from_file_location` and reads `AGENTS`,
`MODELS`, `EFFORTS`. `AGENTS` is built from `<plugin root>/agents/*.md`. The hook must not run
`main()` on import (`if __name__ == "__main__":`, as in the git guard).
