# Quickstart: Agent model overrides

Checks that prove the feature works. Contracts: [hook](contracts/hook.md),
[models file](contracts/models-file.md), [st-model](contracts/st-model.md).

## Prerequisites

- `python3`, `bash`, `git`
- Claude Code 2.1.294 or later (for the end-to-end run)
- Run from the repo root: `/home/hyuse/Desktop/stratum`

## 1. Automated tests

```bash
python3 tests/test_model_hook.py
bash tests/test_model_files.sh
python3 tests/test_git_guard.py
bash tests/test_session_hooks.sh
bash tests/test_statusline.sh
node tests/test_token_weather.mjs
claude plugin validate .claude-plugin/plugin.json
```

Expected: every test passes, every shell check prints `ok`, and the validate command reports no
errors.

## 2. Hook by hand

```bash
tmp=$(mktemp -d); mkdir -p "$tmp/.stratum"
cp templates/models.json "$tmp/.stratum/models.json"
echo '{"cwd":"'"$tmp"'","tool_name":"Agent","tool_input":{"description":"d","prompt":"p","subagent_type":"stratum:st-close","model":"sonnet"}}' \
  | python3 hooks/st-models.py
```

Expected: `updatedInput` with `"model": "haiku"`, `"effort": "xhigh"`, the same `description`
and `prompt`, and no `permissionDecision`.

```bash
echo '{"st-closee": {}}' > "$tmp/.stratum/models.json"
# same echo | python3 command as above
```

Expected: `"permissionDecision": "deny"` and a reason that names `st-closee` and the 11 agents.

Same input with `"subagent_type": "Explore"`: no output.

## 3. This repo (FR-012)

```bash
git check-ignore .stratum/models.json
python3 -c 'import json; assert json.load(open(".stratum/models.json")) == json.load(open("templates/models.json"))'
```

Expected: the first prints `.stratum/models.json`, the second exits 0.

## 4. End to end with Claude Code

This proves the shipped hook is registered and changes the real subagent. The research runs used
a temporary hook, not this one.

```bash
tmp=$(mktemp -d); mkdir -p "$tmp/.stratum"; git -C "$tmp" init -q
cp templates/models.json "$tmp/.stratum/models.json"
cd "$tmp" && claude -p --plugin-dir /home/hyuse/Desktop/stratum \
  "Start the stratum:st-close agent with the prompt 'Reply with the word done.' and show its reply."
```

Expected: the subagent transcript shows a Haiku model. Find it under
`~/.claude/projects/<tmp path with / as ->/<session id>/subagents/agent-*.jsonl` and run
`grep -o '"model":"[^"]*"' <file> | sort -u`. Expect `claude-haiku-...`.

Then write `{"st-close": {"model": "gpt"}}` to `$tmp/.stratum/models.json` and run the same
command. Expect the start to be blocked with the message from the hook.

If the installed Stratum plugin also loads, both copies of the hook may run. For a clean run, turn
off the installed plugin for this session or check that the result still matches.

## 5. Skills (manual, in a Claude Code session)

1. Fresh repo, `/stratum:st-init`, answer no to "Change the model or effort for any agent?".
   Expect `.stratum/models.json` equal to `templates/models.json`, a defaults table, and
   `git status` not listing the file.
2. Say "make st-close use opus". Expect `"st-close": {"model": "opus", "effort": "xhigh"}` and the
   other 7 entries unchanged.
3. Say "put st-close back on its default". Expect the `st-close` entry gone.
4. Say "make st-close use gpt". Expect no change and the allowed lists.
   Then delete `.stratum/models.json` and say "make st-close use opus" again. Expect the 8 template
   entries with `st-close` on opus, effort xhigh, and a reply that says the template was copied (D17).
5. `/stratum:st-status`. Expect each override with its model and effort, and the source
   `.stratum/models.json`. Delete the file and run it again: expect "every agent uses the plugin
   defaults".
