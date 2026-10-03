#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

proj="$tmp/proj"
mkdir -p "$proj/.stratum" "$proj/specs/001-x"
git -C "$proj" init -q
git -C "$proj" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "first commit"
echo '{"feature":"001-x","phase":"implement","lane":"full","feature_directory":"specs/001-x"}' > "$proj/.stratum/state.json"
printf -- '- [x] T001 a\n- [X] T002 b\n- [ ] T003 c\nnot a task\n' > "$proj/specs/001-x/tasks.md"
printf '# Handoff\n\nNext step: write tests.\n' > "$proj/.stratum/handoff.md"
touch "$proj/dirty.txt"

export CLAUDE_PROJECT_DIR="$proj" CLAUDE_PLUGIN_ROOT="$root"
bash "$root/hooks/st-handoff-facts.sh"
bash "$root/hooks/st-handoff-facts.sh"
h="$proj/.stratum/handoff.md"
check "one facts block" '[ "$(grep -c "st-facts:start" "$h")" = 1 ] && [ "$(grep -c "st-facts:end" "$h")" = 1 ]'
check "user text kept" 'grep -q "Next step: write tests." "$h"'
check "tasks 2/3" 'grep -q "Tasks: 2/3" "$h"'
check "phase and lane" 'grep -q "Phase: implement | Lane: full | Feature: 001-x" "$h"'
check "commit listed" 'grep -q "first commit" "$h"'
check "dirty file listed" 'grep -q "dirty.txt" "$h"'

noproj="$tmp/plain"; mkdir -p "$noproj"
CLAUDE_PROJECT_DIR="$noproj" bash "$root/hooks/st-handoff-facts.sh"
check "no .stratum, no file" '[ ! -e "$noproj/.stratum" ]'

mkdir -p "$tmp/home/.claude"
cp "$root/sr-opus-5.md" "$tmp/home/.claude/sr-opus-5.md"
marker=$(grep -m1 -v '^\s*$' "$root/sr-opus-5.md")
out=$(HOME="$tmp/home" bash "$root/hooks/st-session-start.sh")
check "handoff printed" 'grep -q "Session handoff" <<<"$out" && grep -q "Next step: write tests." <<<"$out"'
check "sr-opus-5 skipped when identical" '! grep -qF -- "$marker" <<<"$out"'

echo "changed" >> "$tmp/home/.claude/sr-opus-5.md"
out=$(HOME="$tmp/home" bash "$root/hooks/st-session-start.sh")
check "sr-opus-5 printed when different" 'grep -qF -- "$marker" <<<"$out"'

exit $fail
