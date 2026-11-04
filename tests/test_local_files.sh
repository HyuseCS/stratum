#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
table=$(grep -oE '^  \| `\.stratum/[A-Za-z0-9_.-]+` \| (main|own|git) \|' "$root/DESIGN.md" | cut -d'`' -f2 | sort -u)
[ -n "$table" ] || { echo "FAIL no local file table in DESIGN.md D13a"; exit 1; }
used=$(grep -rhoIE '\.stratum/[A-Za-z0-9_-]+(\.[a-z]+)?' "$root/scripts" "$root/hooks" "$root/statusline" "$root/skills" "$root/agents" | sort -u)
while IFS= read -r f; do
  if grep -qxF "$f" <<<"$table"; then echo "ok   $f"; else echo "FAIL $f has no row in the DESIGN.md D13a table"; fail=1; fi
done <<<"$used"
exit $fail
