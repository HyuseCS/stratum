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
echo '{"tool_input":{"subagent_type":"stratum:st-check"}}' | python3 hooks/st-models.py
python3 -c 'import json; assert json.load(open(".stratum/models.json")) == json.load(open("templates/models.json"))'
```

Expected: the first prints `.stratum/models.json`, the second prints nothing (the file is valid and
has no `st-check` entry), the third exits 0. The third is the FR-012 check, by hand:
`tests/test_model_files.sh` only checks that the file passes the hook, because `st-model` edits
this file.

## 4. End to end with Claude Code (FR-002, FR-004, SC-001, SC-003)

This proves the real `hooks/st-models.py` changes a real subagent. It loads the hook through
`--settings`, so it does not depend on which Stratum copy is installed. It uses `stratum:st-check`
because that agent is read-only. Never use `st-git` here: it commits.

Setup, from the repo root:

```bash
cd /home/hyuse/Desktop/stratum
tmp=$(mktemp -d)
cp .stratum/models.json "$tmp/models.backup.json"
cat > "$tmp/settings.json" <<'EOF'
{"hooks": {"PreToolUse": [{"matcher": "Agent", "hooks": [{"type": "command", "command": "python3 /home/hyuse/Desktop/stratum/hooks/st-models.py", "timeout": 10}]}]}}
EOF
run() { claude -p --settings "$tmp/settings.json" "Start the stratum:st-check agent with the prompt 'Reply with only your model ID. Do not read or change any file.' Then print its reply, or the exact error if the start fails."; }
newest() { ls -t ~/.claude/projects/-home-hyuse-Desktop-stratum/*/subagents/agent-*.jsonl | head -1; }
```

Run A (override applies):

```bash
echo '{"st-check": {"model": "haiku", "effort": "low"}}' > .stratum/models.json
run; f=$(newest); grep -o '"model":"[^"]*"' "$f" | sort -u; grep -o '"effort":"[^"]*"' "$f" | sort -u
```

Expected: `claude-haiku-...` (`st-check`'s default is sonnet) and effort `low` where the
transcript records effort.

Recorded (T017, 2026-10-10, Claude Code 2.1.294): haiku, effort `low`.

Run B (an edit applies on the next start, SC-003):

```bash
echo '{"st-check": {"model": "opus", "effort": "high"}}' > .stratum/models.json
run; f=$(newest); grep -o '"model":"[^"]*"' "$f" | sort -u; grep -o '"effort":"[^"]*"' "$f" | sort -u
```

Expected: `claude-opus-...` and effort `high`, in a new transcript file.

Recorded (T017, 2026-10-10, Claude Code 2.1.294): opus, effort `high`, on the next start.

Run C (bad file blocks the start):

```bash
echo '{"st-check": {"model": "gpt"}}' > .stratum/models.json
run
```

Expected: the reply says the start was blocked, and the reason names `.stratum/models.json` and
`gpt`. No new subagent transcript.

Recorded (T017, 2026-10-10, Claude Code 2.1.294): blocked, with the reason naming `gpt`.

Restore:

```bash
cp "$tmp/models.backup.json" .stratum/models.json
```

## 5. Skills (manual, by the user, in a Claude Code session)

Run these after the plugin update reaches the installed copy. Use a fresh repo:
`mkdir -p /tmp/st-demo && git -C /tmp/st-demo init -q`, then start Claude Code in `/tmp/st-demo`.

1. `/stratum:st-init`. Answer no to "Change the model or effort for any agent?". Expect
   `.stratum/models.json` equal to `templates/models.json` (8 entries), a defaults table, and
   `git status` not listing the file (US3 scenarios 1 and 4).
2. Delete `.stratum/models.json`. Run `/stratum:st-init` and answer yes, then "put st-review on
   opus". Expect the 8 template entries plus `"st-review": {"model": "opus"}` (US3 scenario 2).
3. Run `/stratum:st-init` again. Expect no model question and `.stratum/models.json` unchanged
   (US3 scenario 3).
4. Say "make st-close use opus". Expect `"st-close": {"model": "opus", "effort": "xhigh"}` and the
   other entries unchanged.
5. Say "put st-close back on its default". Expect the `st-close` entry gone.
6. Say "make st-close use gpt". Expect no change and the allowed lists.
7. Delete `.stratum/models.json` and remove its line from `.gitignore`. Say "make st-close use
   opus". Expect the 8 template entries with `st-close` on opus, effort xhigh, a reply that says
   the template was copied (D17), and the `.gitignore` line back.
8. `/stratum:st-status`. Expect each override with its model and effort, and the source
   `.stratum/models.json`. Delete the file and run it again: expect "every agent uses the plugin
   defaults".
