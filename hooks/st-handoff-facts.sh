#!/usr/bin/env bash
project="${CLAUDE_PROJECT_DIR:-$(pwd)}"
dir="$project/.stratum"
[ -d "$dir" ] || exit 0
cd "$project" || exit 0

{
  state=$(python3 - "$dir/state.json" <<'PY' 2>/dev/null
import json, re, sys
try:
    s = json.load(open(sys.argv[1]))
except Exception:
    s = {}
print(f"- Phase: {s.get('phase', '?')} | Lane: {s.get('lane', '?')} | Feature: {s.get('feature', '?')}")
fd = s.get("feature_directory")
done = total = 0
if fd:
    try:
        for line in open(f"{fd}/tasks.md"):
            m = re.match(r"\s*- \[([ xX])\]", line)
            if m:
                total += 1
                done += m.group(1) in "xX"
    except OSError:
        pass
print(f"- Tasks: {done}/{total}")
PY
)

  block="<!-- st-facts:start -->
## Facts ($(date '+%Y-%m-%d %H:%M:%S %z'))
- Branch: $(git branch --show-current 2>/dev/null)
${state}

Last 5 commits:
\`\`\`
$(git log --oneline -5 2>/dev/null)
\`\`\`

Uncommitted files:
\`\`\`
$(git status --short 2>/dev/null)
\`\`\`
<!-- st-facts:end -->"

  file="$dir/handoff.md"
  body=""
  [ -f "$file" ] && body=$(sed '/<!-- st-facts:start -->/,/<!-- st-facts:end -->/d' "$file")
  if [ -n "$body" ]; then
    printf '%s\n\n%s\n' "$body" "$block" > "$file.tmp"
  else
    printf '%s\n' "$block" > "$file.tmp"
  fi
  mv "$file.tmp" "$file"
} 2>/dev/null
exit 0
