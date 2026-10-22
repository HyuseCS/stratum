#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
repo_before=$(git -C "$root" status --porcelain)

mkdir -p "$tmp/bin"
cat > "$tmp/bin/codex" <<'FAKE'
#!/usr/bin/env bash
d=$FAKE_DIR
printf '%s\n' "$@" > "$d/argv"
cat > "$d/prompt"
o=; s=
while [ $# -gt 0 ]; do
  case $1 in -o) o=$2;; --output-schema) s=$2;; esac
  shift
done
[ -n "$s" ] && cp "$s" "$d/schema.json"
[ -n "${FAKE_ERR:-}" ] && printf '%s' "$FAKE_ERR" >&2
[ -f "$d/answer" ] && [ -n "$o" ] && cp "$d/answer" "$o"
exit "${FAKE_RC:-0}"
FAKE
cat > "$tmp/bin/timeout" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_DIR/timeout_argv"
[ -n "${FAKE_TIMEOUT:-}" ] && exit 124
shift 3
exec "$@"
FAKE
chmod +x "$tmp/bin/codex" "$tmp/bin/timeout"
export FAKE_DIR="$tmp"
export PATH="$tmp/bin:$PATH"

proj="$tmp/proj"
mkdir -p "$proj/specs/001-demo" "$proj/.stratum"
git -C "$proj" init -q
printf '# spec\n' > "$proj/specs/001-demo/spec.md"
printf '# plan\nPLANBODY7f3a\n' > "$proj/specs/001-demo/plan.md"
printf '# tasks\n' > "$proj/specs/001-demo/tasks.md"
printf 'x = 1\n' > "$proj/a.py"
printf '{"mode": "codex"}' > "$proj/.stratum/advisor.json"
git -C "$proj" add -A
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -m first
first=$(git -C "$proj" rev-parse HEAD)

adv() { (cd "$proj" && bash "$root/scripts/st-advisor.sh" "$@"); }
run() { out=$(adv "$@"); rc=$?; }
last_header() { grep -E "^## $1 \| " "$proj/specs/001-demo/advisor.md" 2>/dev/null | tail -n1; }
plan_hash() { (cd "$proj/specs/001-demo" && cat spec.md plan.md tasks.md | sha256sum | cut -d' ' -f1); }
answer() { printf '%s' "$1" > "$tmp/answer"; }

answer '{"verdict":"APPROVED","summary":"fine","findings":[]}'
run plan specs/001-demo
h=$(plan_hash)
check "plan APPROVED: exit 0, verdict line with the plan hash" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "APPROVED sha256 $h" ]'
check "plan record header" 'last_header plan | grep -qE "^## plan \| [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| sha256 $h \| APPROVED$"'
check "FR-012 argv read-only" '[ "$(head -n1 "$tmp/argv" 2>/dev/null)" = exec ] && grep -x -A1 -- "-s" "$tmp/argv" | grep -qx read-only && grep -qx -- "--ephemeral" "$tmp/argv" && grep -qx -- "--output-schema" "$tmp/argv" && grep -qx -- "-o" "$tmp/argv" && [ "$(tail -n1 "$tmp/argv")" = "-" ]'
check "FR-012 script has no write flag" '[ -f "$root/scripts/st-advisor.sh" ] && ! grep -qE -- "workspace-write|danger-full-access|dangerously-bypass|approve-for-me|add-dir|full-auto|exec review" "$root/scripts/st-advisor.sh"'
check "FR-003 schema" 'python3 -c "
import json,sys
s=json.load(open(sys.argv[1]))
f=s[\"properties\"][\"findings\"][\"items\"]
assert sorted(s[\"required\"])==[\"findings\",\"summary\",\"verdict\"]
assert sorted(s[\"properties\"][\"verdict\"][\"enum\"])==[\"APPROVED\",\"BLOCKED\",\"REVISE\"]
assert sorted(f[\"required\"])==[\"claim\",\"evidence\",\"location\",\"severity\"]
" "$tmp/schema.json"'
check "FR-013 prompt rules" 'grep -qxF "You are a reviewer for Stratum. Review only: never create, change or delete a file, and never build or fix anything." "$tmp/prompt" && grep -qxF "Read only the inputs named below and the files they cite. Never open .env files, keys, credentials, tokens or other secret files." "$tmp/prompt"'
check "FR-013 prompt: never quote a secret" 'grep -qxF "Never quote a secret value in a finding." "$tmp/prompt"'
check "FR-009 plan prompt names paths, no plan text" 'grep -qxF "Inputs: specs/001-demo/spec.md, specs/001-demo/plan.md, specs/001-demo/tasks.md" "$tmp/prompt" && ! grep -qF PLANBODY7f3a "$tmp/prompt"'

rm -f "$tmp/argv"
run plan specs/001-demo
check "FR-014 no model or effort flag without keys" '[ -f "$tmp/argv" ] && ! grep -qxE -- "-m|--model|-c|--config|-p|--profile|--oss" "$tmp/argv"'

answer '{"verdict":"REVISE","summary":"fix","findings":[{"claim":"claim-one","evidence":"ev-one","location":"a.py:3","severity":"HIGH"},{"claim":"claim-two","evidence":"ev-two","location":"a.py:9","severity":"LOW"}]}'
run plan specs/001-demo
check "REVISE prints and records findings" '[ $rc = 0 ] && [[ "$(head -n1 <<<"$out")" == "REVISE sha256 "* ]] && grep -qF -- "- [HIGH] a.py:3: claim-one Evidence: ev-one" <<<"$out" && grep -qF -- "- [HIGH] a.py:3: claim-one Evidence: ev-one" "$proj/specs/001-demo/advisor.md"'

answer '{"verdict":"BLOCKED","summary":"cannot-review","findings":[]}'
run plan specs/001-demo
check "Codex BLOCKED: exit 1, reason is summary" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: cannot-review" ]'

answer '{"verdict":"APPROVED","summary":"fine","findings":[]}'
printf 'TASKTEXT1\n' > "$tmp/task.txt"
printf 'FAILONE1\n' > "$tmp/f1.txt"
printf 'FAILTWO2\n' > "$tmp/f2.txt"
run test specs/001-demo "$tmp/task.txt" tests/x_test.sh "$tmp/f1.txt" "$tmp/f2.txt"
th=$(cat "$tmp/f1.txt" "$tmp/f2.txt" | sha256sum | cut -d' ' -f1)
check "test point pastes task, test path and both outputs" 'grep -qF "Point: test." "$tmp/prompt" && grep -qxF "Test: tests/x_test.sh" "$tmp/prompt" && grep -qF TASKTEXT1 "$tmp/prompt" && grep -qF FAILONE1 "$tmp/prompt" && grep -qF FAILTWO2 "$tmp/prompt"'
check "test point hash is both outputs" '[ "$(head -n1 <<<"$out")" = "APPROVED sha256 $th" ] && last_header test | grep -q "^## test | "'

printf 'x = 2\n' > "$proj/a.py"
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -am second
short=$(git -C "$proj" rev-parse --short "$first")
echo k > "$proj/new file.txt"
echo S=1 > "$proj/.env"
mkdir -p "$proj/sub"
echo k > "$proj/sub/k.pem"
echo k > "$proj/c.key"
echo k > "$proj/c.p12"
echo k > "$proj/c.pfx"
run diff specs/001-demo "$short"
lst=$(awk '/^Untracked files:/{f=1;next} f' "$tmp/prompt" 2>/dev/null)
check "diff point names full base and untracked files" 'grep -qF "$first" "$tmp/prompt" && grep -qxF "new file.txt" <<<"$lst" && ! grep -qxE "\.env|sub/k\.pem|c\.key|c\.p12|c\.pfx" <<<"$lst" && last_header diff | grep -q "^## diff | "'
rm -rf "$proj/new file.txt" "$proj/.env" "$proj/sub" "$proj/c.key" "$proj/c.p12" "$proj/c.pfx"

check "no repo writes" '[ "$(git -C "$root" status --porcelain)" = "$repo_before" ]'
exit $fail
