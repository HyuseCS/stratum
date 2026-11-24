#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

proj="$tmp/proj"
feat="$proj/specs/001-x"
mkdir -p "$proj/.stratum" "$feat"
pre() { (cd "$proj" && bash "$root/scripts/check-prerequisites.sh" "$@" 2>&1); }
tpl() { (cd "$proj" && bash "$root/scripts/resolve-template.sh" "$@" 2>&1); }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$1" "$2"; }

out=$(pre); rc=$?
check "P1 no state.json: exit 1, Run st-define first" '[ $rc = 1 ] && grep -qF "Run st-define first" <<<"$out"'

printf '{"feature_directory": "specs/001-x"}\n' > "$proj/.stratum/state.json"
out=$(pre --require-plan); rc=$?
check "P2 no plan.md: exit 1, plan.md not found" '[ $rc = 1 ] && grep -qF "plan.md not found" <<<"$out"'

: > "$feat/plan.md"
out=$(pre --require-plan); rc=$?
check "P3 empty plan.md: exit 1, plan.md is empty" '[ $rc = 1 ] && grep -qF "plan.md is empty" <<<"$out"'

printf '# Plan\n' > "$feat/plan.md"
out=$(pre --require-tasks); rc=$?
check "P4 no tasks.md: exit 1, tasks.md not found" '[ $rc = 1 ] && grep -qF "tasks.md not found" <<<"$out"'

mkdir -p "$feat/contracts"
for f in spec.md tasks.md research.md contracts/x.md; do printf '# x\n' > "$feat/$f"; done
out=$(pre --require-spec --require-plan --require-tasks --include-tasks); rc=$?
check "P5 all files: exit 0, JSON, absolute FEATURE_DIR, AVAILABLE_DOCS" '[ $rc = 0 ] && python3 -c "
import json,sys
d = json.loads(sys.argv[1])
assert d[\"FEATURE_DIR\"] == sys.argv[2], d
assert d[\"AVAILABLE_DOCS\"] == [\"research.md\", \"contracts/\", \"tasks.md\"], d
" "$out" "$feat"'

printf '{"feature_directory": "specs/009-missing"}\n' > "$proj/.stratum/state.json"
out=$(pre --paths-only); rc=$?
check "P6 --paths-only, missing feature folder: exit 0, JSON" '[ $rc = 0 ] && [ "$(field "$out" FEATURE_DIR)" = "$proj/specs/009-missing" ]'

out=$(pre --paths-only --template plan); rc=$?
check "P7 --template plan, no override: plugin template" '[ $rc = 0 ] && [ "$(field "$out" TEMPLATE)" = "$root/templates/plan.md" ]'
mkdir -p "$proj/.stratum/templates"
printf '# mine\n' > "$proj/.stratum/templates/plan.md"
out=$(pre --paths-only --template plan); rc=$?
check "P7 --template plan, override: project template" '[ $rc = 0 ] && [ "$(field "$out" TEMPLATE)" = "$proj/.stratum/templates/plan.md" ]'

out=$(tpl Bad_Name); rc=$?
check "P8 bad template name: exit 1, Invalid template name" '[ $rc = 1 ] && grep -qF "Invalid template name" <<<"$out"'
out=$(tpl nope); rc=$?
check "P8 unknown template: exit 1, not found" '[ $rc = 1 ] && grep -qF "not found" <<<"$out"'

out=$(pre --bogus); rc=$?
check "P9 unknown option: exit 1" '[ $rc = 1 ] && grep -qF "Unknown option" <<<"$out"'

exit $fail
