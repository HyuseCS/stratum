#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { bash "$root/scripts/st-state.sh" "$@"; }
get() { python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])), sort_keys=True))' "$1"; }

f="$tmp/state.json"
printf '{"feature_directory": "specs/001-x", "phase": "build", "lane": "full"}\n' > "$f"
run "$f" phase done; rc=$?
check "one pair: sets the key, keeps the others" '[ $rc = 0 ] && [ "$(get "$f")" = "{\"feature_directory\": \"specs/001-x\", \"lane\": \"full\", \"phase\": \"done\"}" ]'
check "no temp file left" '[ "$(ls -A "$tmp")" = "state.json" ]'

run "$f" phase define risk high; rc=$?
check "two pairs: sets both keys" '[ $rc = 0 ] && [ "$(get "$f")" = "{\"feature_directory\": \"specs/001-x\", \"lane\": \"full\", \"phase\": \"define\", \"risk\": \"high\"}" ]'

cp "$f" "$tmp/before"
err=$(run "$f" phase 2>&1 >/dev/null); rc=$?
check "odd pairs: exit 1, one-line error, file unchanged" '[ $rc = 1 ] && [ -n "$err" ] && [ "$(printf "%s\n" "$err" | wc -l)" = 1 ] && cmp -s "$f" "$tmp/before"'
err=$(run "$f" phase done risk 2>&1 >/dev/null); rc=$?
check "odd pairs after a full pair: exit 1, file unchanged" '[ $rc = 1 ] && [ -n "$err" ] && cmp -s "$f" "$tmp/before"'
err=$(run "$f" 2>&1 >/dev/null); rc=$?
check "no pairs: exit 1, file unchanged" '[ $rc = 1 ] && [ -n "$err" ] && cmp -s "$f" "$tmp/before"'

b="$tmp/bad.json"
printf '{"phase": "build",\n' > "$b"
cp "$b" "$tmp/bad.before"
err=$(run "$b" phase done 2>&1 >/dev/null); rc=$?
check "bad JSON: exit 1, one-line error, file unchanged" '[ $rc = 1 ] && [ -n "$err" ] && [ "$(printf "%s\n" "$err" | wc -l)" = 1 ] && cmp -s "$b" "$tmp/bad.before"'

err=$(run "$tmp/none.json" phase done 2>&1 >/dev/null); rc=$?
check "missing file: exit 1, not created" '[ $rc = 1 ] && [ -n "$err" ] && [ ! -e "$tmp/none.json" ]'

while IFS='|' read -r id file phrase; do
  check "$id" 'grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
S1|skills/st-close/SKILL.md|`bash <plugin root>/scripts/st-state.sh <project>/.stratum/state.json phase done`
S2|skills/st-fast/SKILL.md|`bash <plugin root>/scripts/st-state.sh <project>/.stratum/state.json phase done`
S3|skills/st/SKILL.md|`bash <plugin root>/scripts/st-state.sh "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.stratum/state.json" risk <level>`
S4|procedures/specify.md|`bash <PLUGIN_ROOT>/scripts/st-state.sh .stratum/state.json feature_directory <FEATURE_DIRECTORY> phase define`
TABLE

exit $fail
