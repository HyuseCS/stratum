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
check "st-init step 4 asks the question" 'sed -n "/^4\. /,/^5\. /p" "$init" | grep -qF "Change the model or effort for any agent?"'
check "st-init step 4 skips an existing file" 'sed -n "/^4\. /,/^5\. /p" "$init" | grep -qF "If \`.stratum/models.json\` exists, skip this step and change nothing."'
check "st-init keeps st-status steps 4 and 5" 'grep -qF "/stratum:st-status\` steps 4 and 5" "$init"'
check ".gitignore ignores models.json" 'grep -qx ".stratum/models.json" "$root/.gitignore"'

if [ -e "$root/.stratum/models.json" ]; then
  check "repo models.json passes the hook" 'out=$(cd "$root" && echo "{\"tool_input\":{\"subagent_type\":\"stratum:st-check\"}}" | python3 "$root/hooks/st-models.py") && ! grep -q deny <<<"$out"'
else
  echo "skip repo .stratum/models.json absent"
fi

sm="$root/skills/st-model/SKILL.md"
check "st-model skill exists" '[ -f "$sm" ]'
check "st-model frontmatter name" 'sed -n "1,/^---\$/p;" "$sm" | grep -qx "name: st-model"'
check "st-model description names models.json" 'grep -m1 "^description:" "$sm" | grep -qF ".stratum/models.json"'
check "st-model description has examples" 'd=$(grep -m1 "^description:" "$sm"); grep -qF "make st-close use opus" <<<"$d" && grep -qF "put st-test on high effort" <<<"$d" && grep -qF "put st-close back on its default" <<<"$d"'
check "st-model description names model and effort" 'd=$(grep -m1 "^description:" "$sm"); grep -qw model <<<"$d" && grep -qw effort <<<"$d"'
check "st-model names every agent" '(for a in $(ls "$root/agents" | sed "s/\.md$//"); do grep -qF "\`$a\`" "$sm" || exit 1; done)'
check "st-model names default forms" 'grep -qF "model default" "$sm" && grep -qF "effort default" "$sm" && grep -F "remove the whole entry" "$sm" | grep -qF "\`default\`"'
check "st-model runs the hook" 'grep -qF "hooks/st-models.py" "$sm"'
check "st-model uses template" 'grep -qF "templates/models.json" "$sm"'
check "st-model adds gitignore line" 'grep -qF ".gitignore" "$sm"'
check "st-model applies on next start" 'grep -qF "Applies on the next start." "$sm"'

ss="$root/skills/st-status/SKILL.md"
check "st-status step 4 is Tools" 'grep -q "^4\. \*\*Tools:\*\*" "$ss"'
check "st-status has step 7" 'grep -q "^7\. " "$ss"'
check "st-status runs the hook" 'grep -qF "hooks/st-models.py" "$ss"'
check "st-status step 7 names models.json" 'sed -n "/^7\. /,\$p" "$ss" | grep -qF ".stratum/models.json"'

exit $fail
