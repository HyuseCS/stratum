#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

mkrepo() {
  mkdir -p "$1"
  git -C "$1" init -q -b main
  git -C "$1" config user.name t
  git -C "$1" config user.email t@t
  printf 'x = 1\n' > "$1/a.py"
  git -C "$1" add a.py
  git -C "$1" commit -q -m first
}
commit() { git -C "$1" add -A && git -C "$1" commit -q -m "$2"; }
run() { (cd "$1" && bash "$root/scripts/st-shortcuts.sh" "${@:2}"); }

r="$tmp/row"; mkrepo "$r"
git -C "$r" checkout -q -b feat
printf 'x = 1\ny = 2\n# ponytail: global lock\n' > "$r/a.py"
commit "$r" feat
out=$(run "$r" main); rc=$?
check "branch adds one marker: one row at its line" '[ $rc = 0 ] && [ "$out" = "a.py:3: # ponytail: global lock" ]'

r="$tmp/none"; mkrepo "$r"
git -C "$r" checkout -q -b feat
printf 'x = 1\ny = 2\n# explains y\n' > "$r/a.py"
commit "$r" feat
out=$(run "$r" main); rc=$?
check "no marker on branch: empty line, exit 0" '[ $rc = 0 ] && [ "$out" = "No new ponytail: markers." ]'

r="$tmp/old"; mkrepo "$r"
printf 'x = 1\n# ponytail: old lock\n' > "$r/a.py"
commit "$r" "marker on main"
git -C "$r" checkout -q -b feat
printf 'x = 1\n# ponytail: old lock\ny = 2\n' > "$r/a.py"
commit "$r" feat
out=$(run "$r" main); rc=$?
check "marker already on main is not listed" '[ $rc = 0 ] && [ "$out" = "No new ponytail: markers." ]'

r="$tmp/docs"; mkrepo "$r"
git -C "$r" checkout -q -b feat
mkdir -p "$r/docs"
printf 'use a // ponytail: comment\n' > "$r/docs/x.md"
commit "$r" feat
out=$(run "$r" main); rc=$?
check "md-only branch: empty line, exit 0" '[ $rc = 0 ] && [ "$out" = "No new ponytail: markers." ]'

r="$tmp/onmain"; mkrepo "$r"
base=$(git -C "$r" rev-parse HEAD)
printf 'x = 1\ny = 2\n# ponytail: global lock\n' > "$r/a.py"
commit "$r" "marker on main"
out=$(run "$r" "$base"); rc=$?
check "commits on main, base = SHA before them: one row" '[ $rc = 0 ] && [ "$out" = "a.py:3: # ponytail: global lock" ]'
out=$(run "$r"); rc=$?
check "commits on main, no base: no commits after main, exit 0" '[ $rc = 0 ] && [ "$out" = "No commits after main." ]'
out=$(run "$r" nosuch 2>&1); rc=$?
check "bad base: exit 1 with git error" '[ $rc = 1 ] && [[ "$out" == *nosuch* ]] && [[ "$out" != *"No commits after"* ]]'

r="$tmp/spec"; mkrepo "$r"
mkdir -p "$r/specs/001-x"
printf '# spec\n' > "$r/specs/001-x/spec.md"
commit "$r" spec
printf 'x = 1\ny = 2\n# ponytail: global lock\n' > "$r/a.py"
commit "$r" "marker on main"
cmd=$(grep -o 'git rev-parse "$(git log --diff-filter=A[^`]*' "$root/skills/st-close/SKILL.md" | sed 's#<feature dir>#specs/001-x#')
base=$( [ -n "$cmd" ] && cd "$r" && eval "$cmd")
out=$( [ -n "$base" ] && run "$r" "$base"); rc=$?
check "on main, base from spec.md commit: one row" '[ $rc = 0 ] && [ "$out" = "a.py:3: # ponytail: global lock" ]'

r="$tmp/js"; mkrepo "$r"
git -C "$r" checkout -q -b feat
printf '// ponytail: naive scan\n' > "$r/b.js"
commit "$r" feat
out=$(run "$r" main); rc=$?
check "js line comment marker: one row at line 1" '[ $rc = 0 ] && [ "$out" = "b.js:1: // ponytail: naive scan" ]'

r="$tmp/color"; mkrepo "$r"
git -C "$r" checkout -q -b feat
printf 'x = 1\ny = 2\n# ponytail: global lock\n' > "$r/a.py"
commit "$r" feat
out=$(export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always; run "$r" main); rc=$?
check "color.ui=always: one row at its line" '[ $rc = 0 ] && [ "$out" = "a.py:3: # ponytail: global lock" ]'

r="$tmp/space"; mkrepo "$r"
git -C "$r" checkout -q -b feat
mkdir -p "$r/dir x"
printf '# ponytail: sp\n' > "$r/dir x/s p.py"
commit "$r" feat
out=$(run "$r" main); rc=$?
check "path with spaces: one row, exact path" '[ $rc = 0 ] && [ "$out" = "dir x/s p.py:1: # ponytail: sp" ]'

check "agents/st-close.md names scripts/st-shortcuts.sh" 'grep -qF "scripts/st-shortcuts.sh" "$root/agents/st-close.md"'
check "skills/st-close names scripts/st-shortcuts.sh" 'grep -qF "scripts/st-shortcuts.sh" "$root/skills/st-close/SKILL.md"'
check "skills/st-close has --diff-filter=A" 'grep -qF -- "--diff-filter=A" "$root/skills/st-close/SKILL.md"'
check "skills/st-close has fix now or keep" 'grep -qF "fix now or keep" "$root/skills/st-close/SKILL.md"'
check "skills/st-fast has git rev-parse HEAD" 'grep -qF "git rev-parse HEAD" "$root/skills/st-fast/SKILL.md"'

exit $fail
