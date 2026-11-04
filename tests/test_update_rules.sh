#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

while IFS='|' read -r id file phrase; do
  check "$id $file" 'grep -qF -- "$phrase" "$root/$file"'
done <<'ROWS'
R1|skills/st-update/SKILL.md|bash <script> audit <folder>
R1b|skills/st-update/SKILL.md|show the line and stop.
R2|skills/st-update/SKILL.md|only the rows that are not `current`
R2b|skills/st-update/SKILL.md|one line per folder with the count
R3|skills/st-update/SKILL.md|OK to update all, or `skip <worktree>`
R3b|skills/st-update/SKILL.md|No: stop, nothing
R4|skills/st-update/SKILL.md|is on branch <branch>, not main. The update installs that branch.
ROWS

check "front matter skills/st-update/SKILL.md" 'head -n 5 "$root/skills/st-update/SKILL.md" | grep -qx "name: st-update"'

exit $fail
