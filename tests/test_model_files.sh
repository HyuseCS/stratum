#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

tpl="$root/templates/models.json"
init="$root/skills/st-init/SKILL.md"
want='{"st-build": {"model": "opus", "effort": "high"}, "st-debug": {"model": "opus", "effort": "high"}, "st-quick": {"model": "opus", "effort": "high"}, "st-plan": {"model": "opus", "effort": "high"}, "st-fast": {"model": "opus", "effort": "high"}, "st-close": {"model": "haiku", "effort": "xhigh"}, "st-git": {"model": "haiku", "effort": "xhigh"}, "st-test": {"model": "haiku", "effort": "xhigh"}}'
same() { python3 -c 'import json,sys; sys.exit(json.load(open(sys.argv[1])) != json.loads(sys.argv[2]))' "$1" "$2"; }

check "template equals expected" 'same "$tpl" "$want"'

mkdir -p "$tmp/proj/.stratum"
cp "$tpl" "$tmp/proj/.stratum/models.json" 2>/dev/null
hook() { printf '{"cwd": "%s", "tool_name": "Agent", "tool_input": {"subagent_type": "stratum:%s", "prompt": "p", "description": "d"}}' "$tmp/proj" "$1" | python3 "$root/hooks/st-models.py"; }
git_out=$(hook st-git); quick_out=$(hook st-quick)
check "hook st-git haiku xhigh" 'grep -q "\"model\": \"haiku\"" <<<"$git_out" && grep -q "\"effort\": \"xhigh\"" <<<"$git_out" && ! grep -q deny <<<"$git_out"'
check "hook st-quick opus high" 'grep -q "\"model\": \"opus\"" <<<"$quick_out" && grep -q "\"effort\": \"high\"" <<<"$quick_out" && ! grep -q deny <<<"$quick_out"'

check "st-init step 2 lists models.json" 'sed -n "/^2\. /,/^3\. /p" "$init" | grep -qF ".stratum/models.json"'
check "st-init names the template" 'grep -qF "templates/models.json" "$init"'
check "st-init keeps st-status steps 4 and 5" 'grep -qF "/stratum:st-status\` steps 4 and 5" "$init"'
check ".gitignore ignores models.json" 'grep -qx ".stratum/models.json" "$root/.gitignore"'

if [ -e "$root/.stratum/models.json" ]; then
  check "repo models.json equals template" '[ -f "$tpl" ] && same "$root/.stratum/models.json" "$(cat "$tpl")"'
else
  echo "skip repo .stratum/models.json absent"
fi

exit $fail
