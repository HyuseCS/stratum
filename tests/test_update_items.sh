#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
init="$root/skills/st-init/SKILL.md"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

step() { awk -v n="$2" '/^[0-9]+\. \*\*/{ split($0, a, "."); on = (a[1] == n) } on' "$1"; }

names=$({
  step "$init" 2 | grep -o '`[^`]*`' | tr -d '`' | grep -vxF '.gitignore'
  step "$init" 6 | grep -o '`@[^`]*`' | tr -d '`'
  grep -oE '`\.stratum/[^`<]+\.(json|md)`' "$init" | tr -d '`'
  for n in 7 8 10; do step "$init" "$n"; done | tr '\n' ' ' | grep -oiE 'merge( in)? +`[^`]*`' | sed -n 's/^[^`]*`"\([^"<]*\)":.*/\1/p'
  for n in 7 8 10; do step "$init" "$n"; done | tr '\n' ' ' | grep -oE 'into +`[^`]*`' | tr -d '`' | sed 's/^into *//'
} | sort -u)

[ -n "$names" ] || { echo "FAIL st-init names: none collected"; fail=1; }
items=$(bash "$root/scripts/st-update.sh" items) || { echo "FAIL st-update items exits non-zero"; fail=1; }
have=$(printf '%s\n' "$items" | cut -f2)

while IFS= read -r n; do
  [ -n "$n" ] || continue
  printf '%s\n' "$have" | grep -qxF -- "$n" || { echo "FAIL st-init names $n, st-update items lack it"; fail=1; }
done <<< "$names"

echo "checked $(printf '%s\n' "$names" | grep -c .) st-init names"

if [ -z "${ST_ROOT:-}" ]; then
  neg="$tmp/neg"
  mkdir -p "$neg/skills/st-init" "$neg/scripts"
  cp "$root/scripts/st-update.sh" "$neg/scripts/"
  sed 's|`graphify-out/`\.|`graphify-out/`, `.stratum/zz-drift.json`.|' "$init" > "$neg/skills/st-init/SKILL.md"
  out=$(ST_ROOT="$neg" bash "$0" 2>&1)
  rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qF -- '.stratum/zz-drift.json'; then
    echo "ok   negative control: .stratum/zz-drift.json goes red"
  else
    echo "FAIL negative control: exit $rc, .stratum/zz-drift.json not reported"
    fail=1
  fi
fi

exit $fail
