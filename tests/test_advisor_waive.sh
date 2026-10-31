#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$tmp"
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
[ "${FAKE_TIMEOUT:-}" = 137 ] && exit 137
[ -n "${FAKE_TIMEOUT:-}" ] && exit 124
shift 3
exec "$@"
FAKE
chmod +x "$tmp/bin/codex" "$tmp/bin/timeout"
export FAKE_DIR="$tmp"
export PATH="$tmp/bin:$PATH"
unset HERDR_ENV HERDR_WORKSPACE_ID

proj="$tmp/proj"
mkdir -p "$proj/.stratum"
git -C "$proj" init -q
printf 'x = 1\n' > "$proj/a.py"
printf '{"mode": "codex"}' > "$proj/.stratum/advisor.json"
feat() {
  mkdir -p "$proj/$1"
  printf '# spec\n' > "$proj/$1/spec.md"
  printf '# plan\nPLANBODY\n' > "$proj/$1/plan.md"
  printf '# tasks\n' > "$proj/$1/tasks.md"
}
for d in 001-demo 002-reasons 003-refuse 004-note 005-zero 006-cont 007-off 008-nofile 009-diff 010-hash; do feat "specs/$d"; done
git -C "$proj" add -A
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -m first
first=$(git -C "$proj" rev-parse HEAD)

adv() { (cd "$proj" && bash "$root/scripts/st-advisor.sh" "$@"); }
run() { out=$(adv "$@"); rc=$?; }
answer() { printf '%s' "$1" > "$tmp/answer"; }
plan_hash() { (cd "$proj/$1" && { cat spec.md; awk '/^```/{f=!f} !f&&/^## Validate$/{s=1;next} !f&&/^## /{s=0} !s' plan.md; cat tasks.md; } | sha256sum | cut -d' ' -f1); }
snap() { cat "$proj/$1/advisor.md" 2>/dev/null; }
last_header() { grep -E "^## $1 \| " "$proj/$2/advisor.md" 2>/dev/null | tail -n1; }

answer '{"verdict":"APPROVED","summary":"fine","findings":[]}'
run plan specs/001-demo
h=$(plan_hash specs/001-demo)
rm -f "$tmp/argv"
run waive plan specs/001-demo fix-only
check "(a) waive prints WAIVED hash, reason and record line, exit 0" '[ $rc = 0 ] && [ "$(sed -n 1p <<<"$out")" = "WAIVED sha256 $h" ] && [ "$(sed -n 2p <<<"$out")" = "reason: fix-only" ] && [ "$(sed -n 3p <<<"$out")" = "record: specs/001-demo/advisor.md" ]'
check "(a) waive calls no codex" '[ $rc = 0 ] && [ ! -e "$tmp/argv" ]'
check "(b) record header is WAIVED with the hash, reason line directly after it" 'last_header plan specs/001-demo | grep -qE "^## plan \| [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| sha256 $h \| WAIVED$" && [ "$(tail -n2 "$proj/specs/001-demo/advisor.md" | sed -n 2p)" = "reason: fix-only" ] && [ "$(tail -n2 "$proj/specs/001-demo/advisor.md" | head -n1)" = "$(last_header plan specs/001-demo)" ]'
run check plan specs/001-demo
check "(c) check plan after waive prints WAIVED hash, exit 0" '[ $rc = 0 ] && [ "$out" = "WAIVED sha256 $h" ]'
echo "more" >> "$proj/specs/001-demo/tasks.md"
run check plan specs/001-demo
check "(d) check plan stale after a tasks.md change, on a WAIVED record" 'last_header plan specs/001-demo | grep -q "| WAIVED$" && [ $rc = 1 ] && [ "$out" = "advisor approval is stale" ]'

answer '{"verdict":"APPROVED","summary":"fine","findings":[]}'
run plan specs/002-reasons
run waive plan specs/002-reasons $'fix\nonly'
h=$(plan_hash specs/002-reasons)
check "(e) an LF in the reason is recorded on one line" '[ $rc = 0 ] && [ "$(sed -n 1p <<<"$out")" = "WAIVED sha256 $h" ] && [ "$(tail -n2 "$proj/specs/002-reasons/advisor.md" | sed -n 2p)" = "reason: fix only" ]'
b=$(snap specs/002-reasons)
run waive plan specs/002-reasons ""
check "(e) an empty reason: usage, exit 2, no record" 'last_header plan specs/002-reasons | grep -q "| WAIVED$" && [ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == "usage: st-advisor.sh"* ]] && [ "$(snap specs/002-reasons)" = "$b" ]'
run waive plan specs/002-reasons $'\r\n'
check "(e) a reason of only CR and LF: usage, exit 2, no record" 'last_header plan specs/002-reasons | grep -q "| WAIVED$" && [ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == "usage: st-advisor.sh"* ]] && [ "$(snap specs/002-reasons)" = "$b" ]'

run waive plan specs/003-refuse fix-only
check "(f2) waive with no record is refused: none, exit 1, no record" '[ $rc = 1 ] && [ "$out" = "nothing to waive: the last plan record is none" ] && [ ! -e "$proj/specs/003-refuse/advisor.md" ]'
answer '{"verdict":"BLOCKED","summary":"cannot-review","findings":[]}'
run plan specs/003-refuse
b=$(snap specs/003-refuse)
run waive plan specs/003-refuse fix-only
check "(f2) waive after BLOCKED is refused, no record" '[ $rc = 1 ] && [ "$out" = "nothing to waive: the last plan record is BLOCKED" ] && [ "$(snap specs/003-refuse)" = "$b" ]'
run continued plan specs/003-refuse
b=$(snap specs/003-refuse)
run waive plan specs/003-refuse fix-only
check "(f2) waive after BLOCKED, user continued is refused, no record" '[ $rc = 1 ] && [ "$out" = "nothing to waive: the last plan record is BLOCKED, user continued" ] && [ "$(snap specs/003-refuse)" = "$b" ]'
answer '{"verdict":"REVISE","summary":"fix","findings":[{"claim":"c","evidence":"e","location":"l","severity":"HIGH"}]}'
run plan specs/003-refuse
b=$(snap specs/003-refuse)
run waive plan specs/003-refuse fix-only
check "(f2) waive after REVISE with a HIGH finding is refused, no record" '[ $rc = 1 ] && [ "$out" = "nothing to waive: the last plan record is REVISE" ] && [ "$(snap specs/003-refuse)" = "$b" ]'
answer '{"verdict":"REVISE","summary":"fix","findings":[{"claim":"c1","evidence":"e1","location":"l1","severity":"MEDIUM"},{"claim":"c2","evidence":"e2","location":"l2","severity":"LOW"}]}'
run plan specs/003-refuse
h=$(plan_hash specs/003-refuse)
run waive plan specs/003-refuse fix-only
check "(f2) waive after REVISE with only MEDIUM and LOW is allowed" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "WAIVED sha256 $h" ]'
run waive plan specs/003-refuse fix-only
check "(f2) waive after an earlier WAIVED is allowed" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "WAIVED sha256 $h" ]'

answer '{"verdict":"APPROVED","summary":"fine","findings":[]}'
run plan specs/004-note
h=$(plan_hash specs/004-note)
run note plan specs/004-note "one line"
check "(h) note prints noted line, exit 0" '[ $rc = 0 ] && [ "$out" = "noted: plan /advisor" ]'
check "(h) note writes a header and a one-line summary" 'last_header plan specs/004-note | grep -qE "\| /advisor\$" && [ "$(grep -A1 -F "| /advisor" "$proj/specs/004-note/advisor.md" | tail -n1)" = "summary: one line" ]'
run check plan specs/004-note
check "(h) check plan still passes on the earlier record after a note" 'grep -qF "| /advisor" "$proj/specs/004-note/advisor.md" && [ $rc = 0 ] && [ "$out" = "APPROVED sha256 $h" ]'
run waive plan specs/004-note fix-only
run count specs/004-note
check "(i) count after one APPROVED run, one waive and one note" '[ $rc = 0 ] && [ "$out" = "advisor calls: codex 1, waived 1, /advisor 1" ]'
run count specs/005-zero
check "(i) count with no advisor.md prints zeros" '[ $rc = 0 ] && [ "$out" = "advisor calls: codex 0, waived 0, /advisor 0" ] && [ ! -e "$proj/specs/005-zero/advisor.md" ]'
answer '{"verdict":"BLOCKED","summary":"cannot-review","findings":[]}'
run plan specs/006-cont
run continued plan specs/006-cont
run count specs/006-cont
check "(i) a BLOCKED, user continued entry is not counted" '[ $rc = 0 ] && [ "$out" = "advisor calls: codex 1, waived 0, /advisor 0" ]'

answer '{"verdict":"APPROVED","summary":"fine","findings":[]}'
run plan specs/007-off
h=$(plan_hash specs/007-off)
printf '{"mode": "off"}' > "$proj/.stratum/advisor.json"
rm -f "$tmp/argv"
run waive plan specs/007-off fix-only
check "(f) waive works with mode off, no codex call" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "WAIVED sha256 $h" ] && [ ! -e "$tmp/argv" ]'
printf '{"mode": "codex"}' > "$proj/.stratum/advisor.json"
run plan specs/008-nofile
h=$(plan_hash specs/008-nofile)
rm -f "$proj/.stratum/advisor.json"
run waive plan specs/008-nofile fix-only
check "(f) waive works with no advisor.json" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "WAIVED sha256 $h" ]'
printf '{"mode": "codex"}' > "$proj/.stratum/advisor.json"

answer '{"verdict":"APPROVED","summary":"fine","findings":[]}'
run plan specs/010-hash
b=$(snap specs/010-hash)
mkdir -p "$tmp/nosha"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/nosha/sha256sum"
chmod +x "$tmp/nosha/sha256sum"
out=$(cd "$proj" && PATH="$tmp/nosha:$PATH" bash "$root/scripts/st-advisor.sh" waive plan specs/010-hash fix-only 2>&1); rc=$?
check "(g) sha256sum prints nothing: cannot hash inputs, exit 2, no record" '[ $rc = 2 ] && [ "$out" = "cannot hash inputs" ] && [ "$(snap specs/010-hash)" = "$b" ]'

rm -f "$tmp/argv"
run diff specs/009-diff HEAD
check "(j) diff with no change: skip, exit 0, no record, no codex call" '[ $rc = 0 ] && [ "$out" = "no change since HEAD: skip" ] && [ ! -e "$tmp/argv" ] && [ ! -e "$proj/specs/009-diff/advisor.md" ]'
printf 'x = 2\n' > "$proj/a.py"
git -C "$proj" add a.py
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -m second
rm -f "$tmp/argv"
run diff specs/009-diff "$first"
kout=$out; krc=$rc
check "(k) diff after a commit, mode codex: advisors line, exit 0, no record, no codex call" '[ $krc = 0 ] && [ "$(head -n1 <<<"$kout")" = "advisors: /advisor (mode codex)" ] && [ ! -e "$tmp/argv" ] && [ ! -e "$proj/specs/009-diff/advisor.md" ]'
printf '{"mode": "both"}' > "$proj/.stratum/advisor.json"
run diff specs/009-diff "$first"
check "(k) diff after a commit, mode both: advisors line, exit 0, no record" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "advisors: /advisor (mode both)" ] && [ ! -e "$proj/specs/009-diff/advisor.md" ]'
printf '{"mode": "off"}' > "$proj/.stratum/advisor.json"
run diff specs/009-diff "$first"
check "(k) diff after a commit, mode off: no advisor line" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "no advisor: mode off" ] && [ ! -e "$proj/specs/009-diff/advisor.md" ]'
printf '{"mode": "codex"}' > "$proj/.stratum/advisor.json"
run diff specs/009-diff nosuchref
check "(l) diff with an unknown base: usage, exit 2" '[ "$(head -n1 <<<"$kout")" = "advisors: /advisor (mode codex)" ] && [ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == "usage: st-advisor.sh"* ]]'

check "no repo writes" '[ "$(git -C "$root" status --porcelain)" = "$repo_before" ]'
exit $fail
