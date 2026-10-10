# Data Model: Agent model overrides

## Model file

Path: `<project>/.stratum/models.json`. Per project, per machine, git-ignored (D13). Read by the
hook on every Stratum agent start. Written by `st-init`, `st-model`, or by hand. The hook reads
the file as bytes: JSON decides the encoding, and a UTF-8 BOM is accepted.

| Field | Type | Rule |
|-------|------|------|
| top level | JSON object | Keys are agent names. Anything else is an error. |
| `<agent>` | string key | One of: `st-build`, `st-check`, `st-close`, `st-debug`, `st-fast`, `st-git`, `st-plan`, `st-quick`, `st-review`, `st-test`, `st-validate` (the file names in `agents/*.md`). |
| `<agent>` value | JSON object | Only the keys `model` and `effort`. `{}` is valid and means defaults. |
| `model` | string, optional | One of `sonnet`, `opus`, `haiku`, `fable`. |
| `effort` | string, optional | One of `low`, `medium`, `high`, `xhigh`, `max`. |

Missing file, missing entry or missing key: that agent keeps its default (FR-003).

Errors (FR-004), each blocks every Stratum agent start until fixed: file not valid JSON or not
readable, top level not an object, unknown agent, entry not an object, unknown key, unknown
model, unknown effort (including any non-string value).

## Model template

Path: `<plugin root>/templates/models.json`. Shipped in the plugin. Content (D12, D15, D16), 8 entries; `st-check`, `st-review`, `st-validate` have none:

```json
{
  "st-build": { "model": "opus", "effort": "high" },
  "st-debug": { "model": "opus", "effort": "high" },
  "st-quick": { "model": "opus", "effort": "high" },
  "st-plan": { "model": "opus", "effort": "high" },
  "st-fast": { "model": "opus", "effort": "high" },
  "st-close": { "model": "haiku", "effort": "xhigh" },
  "st-git": { "model": "haiku", "effort": "xhigh" },
  "st-test": { "model": "haiku", "effort": "xhigh" }
}
```

It must pass the hook's own check.

## Agent default

The `model:` line in `<plugin root>/agents/<agent>.md`. Unchanged by this feature (D12). No agent
sets an effort, so the default effort is Claude Code's default for that model.

## Allowed values

Held once in `hooks/st-models.py`: `MODELS`, `EFFORTS`, and the agent list built from
`agents/*.md` (research R5). The `st-model` skill and README repeat them, and
`tests/test_model_hook.py` fails if they drift.

## State over time

There is no state machine. Each Stratum agent start reads the file as it is at that moment.
