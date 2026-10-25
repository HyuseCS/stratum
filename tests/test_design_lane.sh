#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
report() { if [ "$ok" = 1 ]; then echo "ok   $cur"; else echo "FAIL $cur"; fail=1; fi; }
phrases() {
  cur=""; ok=1
  while IFS=$'\t' read -r name target phrase; do
    if [ "$name" != "$cur" ]; then
      [ -n "$cur" ] && report
      cur=$name; ok=1
    fi
    grep -qF -- "$phrase" "$root/$target" || ok=0
  done
  report
}
lock() {
python3 -I - "$root/vendor.lock" <<'PY'
import json, re, sys
h = json.load(open(sys.argv[1])).get("hallmark", {})
sys.exit(not (h.get("repo") == "nutlope/hallmark" and re.fullmatch("[0-9a-f]{40}", h.get("commit", "")) and h.get("path") == "skills/hallmark" and h.get("license") == "MIT"))
PY
}

check "FR-017 lock" 'lock'
check "FR-017 copy" '[ -f "$root/skills/st-hallmark/SKILL.md" ] &&
  grep -qx "name: st-hallmark" "$root/skills/st-hallmark/SKILL.md" &&
  grep -qx "disable-model-invocation: true" "$root/skills/st-hallmark/SKILL.md" &&
  ! grep -qx "name: hallmark" "$root/skills/st-hallmark/SKILL.md" &&
  [ -f "$root/skills/st-hallmark/LICENSE" ] &&
  [ -f "$root/skills/st-hallmark/scripts/sloplint.mjs" ] &&
  [ -f "$root/skills/st-hallmark/scripts/sloplint-render.mjs" ] &&
  [ -f "$root/skills/st-hallmark/scripts/theme.mjs" ] &&
  [ -f "$root/skills/st-hallmark/references/themes/index.json" ] &&
  grep -qF "MIT License" "$root/licenses/hallmark.MIT.txt"'

phrases <<'EOF'
FR-017 THIRD_PARTY_NOTICES.md	THIRD_PARTY_NOTICES.md	| `skills/st-hallmark` | `licenses/hallmark.MIT.txt` |
EOF

exit $fail
