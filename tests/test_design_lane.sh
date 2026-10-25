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

detector_map() {
python3 -I - "$root/skills/st-design/engine.md" <<'PY'
import sys
ig, kp = [], []
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith("ignore: "):
        ig += line.split()[1:]
    elif line.startswith("keep: "):
        kp += line.split()[1:]
detector_only = "flat-type-hierarchy blinking-cursor buried-raster hard-offset-shadow extreme-negative-tracking script-error edge-flush-cards first-viewport-column-overflow straggler clipped-overflow-container design-system-font design-system-color design-system-radius design-system-font-size gpt-thin-border-wide-shadow theater-slop-phrase".split()
sys.exit(not (len(ig) == 35 and len(kp) == 27 and len(set(ig)) == 35 and len(set(kp)) == 27 and not set(ig) & set(kp) and len(set(ig + kp)) == 62 and set(detector_only) <= set(kp)))
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
check "FR-010 one place" '[ "$(grep -rliE "hallmark|sloplint" "$root/skills/st-design" "$root/agents/st-design.md" "$root/scripts/st-design-check.sh")" = "$root/skills/st-design/engine.md" ]'
check "FR-008 map" 'detector_map'

phrases <<'EOF'
FR-017 THIRD_PARTY_NOTICES.md	THIRD_PARTY_NOTICES.md	| `skills/st-hallmark` | `licenses/hallmark.MIT.txt` |
EOF

phrases <<'EOF'
FR-008 engine.md	skills/st-design/engine.md	Each passes with 0 `FAIL` and 0
FR-008 engine.md	skills/st-design/engine.md	Do not run its Step 1 questions, its hero review, its finish review,
FR-008 engine.md	skills/st-design/engine.md	`summary.render` other than `ran` fails the render check.
FR-016 engine.md	skills/st-design/engine.md	Never ask for, print or set the key.
FR-016 engine.md	skills/st-design/engine.md	Test only `[ -n "${TOGETHER_API_KEY:-}" ]`.
EOF

exit $fail
