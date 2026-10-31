#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
readme="$root/README.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "no frontend-design text outside specs" 'git -C "$root" grep -n frontend-design -- ":!specs" ":!tests/test_no_frontend_design.sh"; [ $? = 1 ]'
check "skills/st-frontend-design is removed" '[ ! -e "$root/skills/st-frontend-design" ]'
check "licenses/frontend-design.Apache-2.0.txt is removed" '[ ! -e "$root/licenses/frontend-design.Apache-2.0.txt" ]'
check "vendor.lock is valid JSON" 'python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$root/vendor.lock"'
check "vendor.lock has no frontend-design key" 'python3 -c "import json,sys; sys.exit(\"frontend-design\" in json.load(open(sys.argv[1])))" "$root/vendor.lock"'
agrow='^\| `[^`]*` \| (Opus|Sonnet|Haiku|Fable) \|'
miss=$(diff <(for d in "$root"/skills/*/; do [ -f "$d/SKILL.md" ] && basename "$d"; done | sort) \
  <(grep -E '^\| `st' "$readme" | grep -vE "$agrow" | sed 's/ | .*//' | grep -oE '`(st[a-z-]*|-[a-z]+)' | tr -d '`' | sed 's/^-/st-ponytail-/' | sort -u))
check "README skills" '[ -z "$miss" ]'
exit $fail
