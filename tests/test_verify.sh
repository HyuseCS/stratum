#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

proj="$tmp/proj"
mkdir -p "$proj"
git -C "$proj" init -q
printf 'x = 1\n' > "$proj/a.py"
printf '# Title\n' > "$proj/notes.md"
git -C "$proj" add a.py notes.md
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -m first
verify() { (cd "$proj" && bash "$root/scripts/st-verify.sh" "$@"); }
files=(a.py notes.md "new file.py" new.md)

out=$(verify "true" "${files[@]}"); rc=$?
check "green and clean: ok, exit 0" '[ $rc = 0 ] && grep -q "^ok" <<<"$out"'

out=$(verify "echo boom-line; exit 3" a.py); rc=$?
check "red test: FAIL, exit 1, shows output" '[ $rc = 1 ] && grep -q "^FAIL" <<<"$out" && grep -q "boom-line" <<<"$out"'

printf 'x = 1\n# explains x\n' > "$proj/a.py"
out=$(verify "true" "${files[@]}"); rc=$?
check "added comment: FAIL, exit 1, names it" '[ $rc = 1 ] && grep -q "^FAIL" <<<"$out" && grep -q "explains x" <<<"$out"'

printf 'x = 1\n# ponytail: global lock\n' > "$proj/a.py"
printf '# Title\n# more\n' > "$proj/notes.md"
out=$(verify "true" "${files[@]}"); rc=$?
check "ponytail and md lines pass" '[ $rc = 0 ] && grep -q "^ok" <<<"$out"'

printf 'x = 1\n' > "$proj/a.py"
printf '#!/usr/bin/env python3\ny = 2\n# explains y\n' > "$proj/new file.py"
out=$(verify "true" "${files[@]}"); rc=$?
check "comment in a new untracked file: FAIL, names file" '[ $rc = 1 ] && grep -q "new file.py" <<<"$out" && grep -q "explains y" <<<"$out"'
rm "$proj/new file.py"

printf '# Title\n' > "$proj/new.md"
out=$(verify "true" "${files[@]}"); rc=$?
check "new md file passes" '[ $rc = 0 ]'
rm "$proj/new.md"

printf '# stray\n' > "$proj/other.py"
out=$(verify "true" a.py); rc=$?
check "file not in the list is skipped" '[ $rc = 0 ]'
rm "$proj/other.py"

for case in 'a.c|*ptr = 1;|0' 'b.py|# see #!/bin/sh note|1' 'c.sql|-- sql note|1' 'd.html|<!-- html note -->|1' \
            'e.sh|#!/bin/sh|0' 'f.css|#outro { color: red; }|0' 'g.c|#include <stdio.h>|0' 'h.c| * block comment line|1' \
            'i.c|--i;|0'; do
  IFS='|' read -r name line want <<<"$case"
  printf '%s\n' "$line" > "$proj/$name"
  verify "true" "$name" >/dev/null; rc=$?
  check "$name '$line' exit $want" '[ $rc = $want ]'
  rm "$proj/$name"
done

out=$(verify "true"); rc=$?
check "no file list: exit 2" '[ $rc = 2 ]'

for s in st st-build st-fast st-quick; do
  check "skills/$s uses st-verify.sh" 'grep -qF "<plugin root>/scripts/st-verify.sh" "$root/skills/$s/SKILL.md"'
done
check "old inline grep gone from st and st-build" '! grep -qF "git diff -U0" "$root/skills/st/SKILL.md" "$root/skills/st-build/SKILL.md"'

exit $fail
