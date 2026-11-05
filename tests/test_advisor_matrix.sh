#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$tmp" XDG_STATE_HOME="$tmp/state"
repo_before=$(git -C "$root" status --porcelain)

mkdir -p "$tmp/bin"
cat > "$tmp/bin/codex" <<'FAKE'
#!/usr/bin/env bash
d=$FAKE_DIR
printf '%s\n' "$@" > "$d/argv"
cat > "$d/prompt"
o=
while [ $# -gt 0 ]; do [ "$1" = -o ] && o=$2; shift; done
[ -f "$d/answer" ] && [ -n "$o" ] && cp "$d/answer" "$o"
exit 0
FAKE
cat > "$tmp/bin/timeout" <<'FAKE'
#!/usr/bin/env bash
shift 3
exec "$@"
FAKE
chmod +x "$tmp/bin/codex" "$tmp/bin/timeout"
export FAKE_DIR="$tmp"
export PATH="$tmp/bin:$PATH"
unset HERDR_ENV HERDR_WORKSPACE_ID

proj="$tmp/proj"
mkdir -p "$proj/specs/001-demo" "$proj/specs/002-count" "$proj/.stratum"
git -C "$proj" init -q
for d in 001-demo 002-count; do
  printf '# spec\n' > "$proj/specs/$d/spec.md"
  printf '# plan\nPLANBODY\n' > "$proj/specs/$d/plan.md"
  printf '# tasks\n' > "$proj/specs/$d/tasks.md"
done
printf 'x = 1\n' > "$proj/a.py"
printf '{"mode": "auto"}' > "$proj/.stratum/advisor.json"
git -C "$proj" add -A
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -m first
first=$(git -C "$proj" rev-parse HEAD)
printf 'x = 2\n' > "$proj/a.py"
git -C "$proj" add -A
git -C "$proj" -c user.name=t -c user.email=t@t commit -q -m second
printf '{"risk": "normal"}' > "$proj/.stratum/state.json"
printf 'TASKTEXT1\n' > "$tmp/task.txt"
printf 'FAILONE1\n' > "$tmp/f1.txt"
printf 'FAILTWO2\n' > "$tmp/f2.txt"
printf 'DECIDEDLIST1\n' > "$tmp/list.txt"
printf 'VIEWONE\n' > "$tmp/views.txt"
mf="$proj/.stratum/advisor.json"
recf="$proj/specs/001-demo/advisor.md"

approve() { printf '%s' '{"verdict":"APPROVED","summary":"fine","findings":[]}' > "$tmp/answer"; }
adv() { (cd "$proj" && bash "$root/scripts/st-advisor.sh" "$@"); }
run() { rm -f "$tmp/argv" "$tmp/prompt"; out=$(adv "$@"); rc=$?; }
nrec() { cat "$recf" 2>/dev/null | grep -c '^## '; }
plan_hash() { (cd "$proj/specs/001-demo" && { cat spec.md; awk '/^```/{f=!f} !f&&/^## Validate$/{s=1;next} !f&&/^## /{s=0} !s' plan.md; cat tasks.md; } | sha256sum | cut -d' ' -f1); }
setmode() { printf '%s' "$1" > "$mf"; }
setrisk() { printf '{"risk": "%s"}' "$1" > "$proj/.stratum/state.json"; }
rline() { printf 'Point: plan, round %s of 3 of a talk with another advisor. The views so far are below. For each open point, agree, or keep your view and give the reason.\n' "$1"; }
calls_ok() { if [ "$1" = 1 ]; then [ -f "$tmp/argv" ] && [ "$(nrec)" = $((n0 + 1)) ]; else [ ! -e "$tmp/argv" ] && [ "$(nrec)" = "$n0" ]; fi; }

matrix="plan high both
plan normal codex
plan low none
plan none none
test high codex
test normal codex
test low /advisor
test none none
decisions high both
decisions normal codex
decisions low /advisor
decisions none none
diff high both
diff normal codex
diff low /advisor
diff none none
change high both
change normal codex
change low none
change none none"
printf '# change 001\nCHANGEBODY\n' > "$tmp/change.md"
grid() {
  local ok=1 pt lvl aset calls
  while read -r pt lvl aset <&3; do
    setrisk "$lvl"
    n0=$(nrec)
    case $pt in
      plan) run plan specs/001-demo ;;
      test) run test specs/001-demo "$tmp/task.txt" tests/x_test.sh "$tmp/f1.txt" "$tmp/f2.txt" ;;
      decisions) run decisions specs/001-demo "$tmp/list.txt" ;;
      diff) run diff specs/001-demo "$first" ;;
      change) run change specs/001-demo "$tmp/change.md" ;;
    esac
    case $aset in codex|both) calls=1 ;; *) calls=0 ;; esac
    { [ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "advisors: $aset ($pt, risk $lvl)" ] && calls_ok $calls; } || { ok=0; echo "  bad case: $pt risk $lvl set $aset rc=$rc first=$(head -n1 <<<"$out")" >&2; }
  done 3<<<"$matrix"
  [ $ok = 1 ]
}

approve
for c in '{"mode": "auto"}' '{}' '{"model": "m1"}'; do
  setmode "$c"
  run plan specs/001-demo
  check "(a) mode auto from $c: advisors: codex (plan, risk normal), Codex runs" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "advisors: codex (plan, risk normal)" ] && [ -f "$tmp/argv" ]'
done
check "(a) the model from the file is passed under auto" 'grep -x -A1 -- -m "$tmp/argv" | grep -qx m1'

setmode '{"mode": "auto"}'
setrisk normal
approve
check "(b) plan, test, decisions and diff at risk high, normal, low, none: first line names the set, Codex only for codex and both" 'grid'

printf '{}' > "$proj/.stratum/state.json"
run plan specs/001-demo
check "(c) no risk: first line is risk not set: normal" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "risk not set: normal" ]'
setrisk normal

setmode '{"mode": "codex"}'
h=$(plan_hash)
run plan specs/001-demo
check "(d) mode codex: plan prints today's first line, no advisors line" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "APPROVED sha256 $h" ] && ! grep -q "^advisors:" <<<"$out"'
out=$(cd "$proj" && say='advisors: none (plan, risk none)' bash "$root/scripts/st-advisor.sh" plan specs/001-demo); rc=$?
check "(d) mode codex with say in the environment: no advisors line" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "APPROVED sha256 $h" ] && ! grep -q "^advisors:" <<<"$out"'
n0=$(nrec)
run decisions specs/001-demo "$tmp/list.txt"
check "(d) mode codex: decisions prints advisors: /advisor (mode codex), no record, no Codex" '[ $rc = 0 ] && [ "$out" = "advisors: /advisor (mode codex)" ] && calls_ok 0'
setmode '{"mode": "both"}'
run plan specs/001-demo
check "(d) mode both: plan first line is the both line" '[ "$(head -n1 <<<"$out")" = "mode both: also consult /advisor if one is set" ]'
run diff specs/001-demo "$first"
check "(d) mode both: diff prints advisors: /advisor (mode both)" '[ "$out" = "advisors: /advisor (mode both)" ]'

setmode '{"mode": "auto2"}'
n0=$(nrec)
run plan specs/001-demo
check "(e) mode auto2: BLOCKED: bad advisor.json, no Codex, one record" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: bad advisor.json" ] && [ ! -e "$tmp/argv" ] && [ "$(nrec)" = $((n0 + 1)) ]'

setmode '{"mode": "auto"}'
setrisk normal
approve
dline="Point: diff. Review the changes in git diff $first..HEAD (run it yourself): hidden regressions and broken rules of the project's constitution. Do not build or fix."
run diff specs/001-demo "$first"
check "(f) diff auto normal: Point line names the base, Codex runs, record is ## diff" 'grep -qxF "$dline" "$tmp/prompt" && grep -q "^## diff | " "$recf"'
realgit=$(command -v git)
mkdir -p "$tmp/gitfail" "$tmp/nosha"
printf '#!/usr/bin/env bash\n[ "$1" = diff ] && exit 1\nexec %s "$@"\n' "$realgit" > "$tmp/gitfail/git"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/nosha/sha256sum"
chmod +x "$tmp/gitfail/git" "$tmp/nosha/sha256sum"
rundiff() { rm -f "$tmp/argv"; n0=$(nrec); out=$(cd "$proj" && PATH="$1" bash "$root/scripts/st-advisor.sh" diff specs/001-demo "$first"); rc=$?; }
rundiff "$tmp/gitfail:$PATH"
check "(f) git diff fails: cannot hash inputs, exit 2, no record, no Codex" '[ $rc = 2 ] && [ "$out" = "cannot hash inputs" ] && calls_ok 0'
rundiff "$tmp/nosha:$PATH"
check "(f) sha256sum prints nothing: cannot hash inputs, exit 2, no record, no Codex" '[ $rc = 2 ] && [ "$out" = "cannot hash inputs" ] && calls_ok 0'

setmode '{"mode": "auto"}'
setrisk normal
approve
dline="Point: decisions. Below is the list of small decisions the orchestrator made. For each one, say whether it is fine. A finding with severity CRITICAL or HIGH means the decision must go to the user."
run decisions specs/001-demo "$tmp/list.txt"
check "(g) decisions: prompt has the Point line and the list text" 'grep -qxF "$dline" "$tmp/prompt" && grep -qxF DECIDEDLIST1 "$tmp/prompt"'
if [ "$(id -u)" = 0 ]; then
  echo "skip unreadable decisions list: running as root"
else
  chmod 000 "$tmp/list.txt"
  run decisions specs/001-demo "$tmp/list.txt"
  chmod 644 "$tmp/list.txt"
  check "(g) decisions with an unreadable list: usage, exit 2, no Codex" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == "usage:"* ]] && [ ! -e "$tmp/argv" ]'
fi

setmode '{"mode": "auto"}'
approve
run plan specs/001-demo
h=$(plan_hash)
run round plan specs/001-demo 1 "$tmp/views.txt"
check "(h) round 1: exact round line and the views text" '[ $rc = 0 ] && grep -qxF "$(rline 1)" "$tmp/prompt" && grep -qxF VIEWONE "$tmp/prompt"'
printf '%s' '{"verdict":"REVISE","summary":"s","findings":[{"claim":"c","evidence":"e","location":"l","severity":"LOW"}]}' > "$tmp/answer"
run round plan specs/001-demo 3 "$tmp/views.txt"
vh=$(sha256sum < "$tmp/views.txt" | cut -d' ' -f1)
check "(h) round 3: last-round line, record ## plan round 3 with the views hash and verdict" '[ $rc = 0 ] && grep -qxF "$(rline 3)" "$tmp/prompt" && grep -qxF "This is the last round. For every open point, propose a compromise aimed at the best result, one finding per compromise." "$tmp/prompt" && grep -qE "^## plan round 3 \| [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| sha256 $vh \| REVISE$" "$recf"'
n0=$(nrec)
run round plan specs/001-demo 4 "$tmp/views.txt"
check "(h) round 4: usage, exit 2, no record, no Codex" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == "usage:"* ]] && calls_ok 0'
run check plan specs/001-demo
check "(h) check plan still reads the last ## plan run, not the round records" '[ $rc = 0 ] && [ "$out" = "APPROVED sha256 $h" ]'

printf 'rounds: 3\nagreed: 2\ncompromises: 1\nto user: 0\ncalls: 5\n' > "$tmp/talk.txt"
n0=$(nrec)
run talk plan specs/001-demo "$tmp/talk.txt"
check "(i) talk: prints talk recorded, writes the header and the five lines" '[ $rc = 0 ] && [ "$out" = "talk recorded: plan, 3 rounds" ] && grep -qE "^## plan talk \| [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| 3 rounds$" "$recf" && [ "$(grep -cxF -f "$tmp/talk.txt" "$recf")" = 5 ] && [ "$(nrec)" = $((n0 + 1)) ]'
printf 'rounds: 3\nagreed: 2\ncompromises: 1\nto user: 0\n' > "$tmp/talk-nocalls.txt"
sed 's/^rounds: 3$/rounds: 4/' "$tmp/talk.txt" > "$tmp/talk-4.txt"
for f in talk-nocalls talk-4; do
  n0=$(nrec)
  run talk plan specs/001-demo "$tmp/$f.txt"
  check "(i) talk file $f: usage, exit 2, no record" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == "usage:"* ]] && calls_ok 0'
done

setmode '{"mode": "codex"}'
approve
run plan specs/002-count
run count specs/002-count
c0=${out#advisor calls: codex }
c0=${c0%%,*}
check "(j) the plan run before the round is one codex call" '[ "$c0" = 1 ]'
run round plan specs/002-count 1 "$tmp/views.txt"
run count specs/002-count
check "(j) count: the round record counts as codex" '[ "$out" = "advisor calls: codex $((c0 + 1)), waived 0, /advisor 0" ]'

rm -f "$mf"
r18='no advisor: mode not set. Write .stratum/advisor.json with "mode": "auto", "codex", "both" or "off".'
n0=$(nrec)
run plan specs/001-demo
check "(l) no advisor.json: R18 message, exit 0, no Codex, no record" '[ $rc = 0 ] && [ "$out" = "$r18" ] && calls_ok 0'
run round plan specs/001-demo 1 "$tmp/views.txt"
check "(n) round with no advisor.json: R18 message, exit 0, no Codex, no record" '[ $rc = 0 ] && [ "$out" = "$r18" ] && calls_ok 0'
setmode '{"mode": "off"}'
run round plan specs/001-demo 1 "$tmp/views.txt"
check "(n) round with mode off: no advisor: mode off, exit 0, no Codex, no record" '[ $rc = 0 ] && [ "$out" = "no advisor: mode off" ] && calls_ok 0'
setmode '{"mode": "auto", "model": "m1", "effort": "high"}'
setrisk low
approve
run round plan specs/001-demo 1 "$tmp/views.txt"
check "(n) round under auto at risk low: Codex runs with -m m1 and the effort option" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "advisors: codex (round, risk low)" ] && grep -x -A1 -- -m "$tmp/argv" | grep -qx m1 && grep -x -A1 -- -c "$tmp/argv" | grep -qxF "model_reasoning_effort=\"high\""'

setmode '{"mode": "auto"}'
setrisk high
wt="$tmp/wt"
git -C "$proj" worktree add -q --detach "$wt"
mkdir -p "$wt/.stratum"
printf '{"risk": "low"}' > "$wt/.stratum/state.json"
approve
out=$(cd "$wt" && bash "$root/scripts/st-advisor.sh" plan specs/001-demo); rc=$?
check "(m) linked worktree: risk comes from the main checkout (high)" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "advisors: both (plan, risk high)" ]'

mkdir -p "$tmp/user"
printf '{"tokens":"x"}' > "$tmp/user/auth.json"
out=$(cd "$proj" && CODEX_HOME="$tmp/user" bash "$root/scripts/st-advisor.sh" codex-home); rc=$?
check "(M1) codex-home: usage line without codex-home, exit 2, no Stratum Codex home folder" '[ $rc = 2 ] && [[ "$(head -n1 <<<"$out")" == "usage:"* ]] && [[ "$(head -n1 <<<"$out")" != *codex-home* ]] && [ ! -e "$tmp/state/stratum/codex-home" ]'

mkdir -p "$tmp/hbin2"
cat > "$tmp/hbin2/herdr" <<'FAKE'
#!/usr/bin/env bash
d=$FAKE_DIR
printf '%s\n' "$*" >> "$d/herdr.log"
m=$(cat "$d/hmode" 2>/dev/null)
hs=$(cat "$d/hstatus" 2>/dev/null)
hs=${hs:-idle}
case "$1 $2" in
  "agent list")
    e=
    [ -e "$d/htab" ] && e="{\"name\":\"st-codex-demo\",\"workspace_id\":\"$HERDR_WORKSPACE_ID\",\"cwd\":\"$(pwd -P)\",\"tab_id\":\"w1:t2\",\"agent_status\":\"$hs\"}"
    [ -e "$d/helsewhere" ] && e="${e:+$e,}{\"name\":\"st-codex-demo\",\"workspace_id\":\"wOther\",\"cwd\":\"$(pwd -P)\",\"tab_id\":\"w9:t1\",\"agent_status\":\"idle\"}"
    echo "{\"result\":{\"agents\":[$e]}}" ;;
  "agent get") echo "{\"result\":{\"agent\":{\"agent_status\":\"$hs\"}}}" ;;
  "workspace list")
    lab=$(cat "$d/hlabel" 2>/dev/null)
    [ -e "$d/hnows" ] && echo '{"result":{"workspaces":[]}}' || echo "{\"result\":{\"workspaces\":[{\"workspace_id\":\"$HERDR_WORKSPACE_ID\",\"label\":\"${lab:-demo}\"}]}}" ;;
  "tab create") echo '{"result":{"tab":{"tab_id":"w1:t2"},"root_pane":{"pane_id":"w1:p2"}}}' ;;
  "agent start")
    if [ "$m" = notready ]; then
      echo '{"error":{"code":"agent_not_ready","message":"agent st-codex-demo is blocked during startup and is not ready for prompts"}}'
      echo '{"error":{"code":"agent_not_ready","message":"agent st-codex-demo is blocked during startup and is not ready for prompts"}}' >&2
      exit 1
    fi
    echo '{"result":{"agent":"codex","name":"st-codex-demo","pane_id":"w1:p2"}}' ;;
  "agent send-keys") touch "$d/h.entered" ;;
  "agent prompt") printf '%s\n' "$@" > "$d/h.args"; echo '{"result":{"state":"done"}}' ;;
  "agent read")
    if [[ " $* " == *" 400 "* ]]; then
      [ "$m" = nomarkers ] && { echo "some text without the markers"; exit 0; }
      pf=$(sed -n 's/.*request in \(.*\) and follow it.*/\1/p' "$d/h.args" | head -n1)
      nonce=$(grep -o 'ST-ADVISOR-BEGIN-[0-9a-f]\{12\}' "$pf" | tail -n1 | sed 's/ST-ADVISOR-BEGIN-//')
      echo "ready"
      echo "ST-ADVISOR-BEGIN-$nonce"
      cat "$d/answer"; echo
      echo "ST-ADVISOR-END-$nonce"
    elif [ "$m" = folder ] && [ ! -e "$d/h.entered" ]; then
      printf 'Folder access\n› 1. Open restricted\n  2. Back to Agent Command Center\n'
    elif [ "$m" = notready ]; then
      echo "Trust this folder?"
    else
      echo "chat box"
    fi ;;
esac
exit 0
FAKE
chmod +x "$tmp/hbin2/herdr"
ws=wQ9
hrun() {
  rm -f "$tmp/argv" "$tmp/herdr.log" "$tmp/h.entered" "$tmp/h.args"
  printf '%s' "$1" > "$tmp/hmode"
  out=$(cd "$proj" && PATH="${hp:-}$tmp/hbin2:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=$ws bash "${sr:-$root}/scripts/st-advisor.sh" plan specs/001-demo); rc=$?
}
setmode '{"mode": "codex"}'
approve
h=$(plan_hash)
hrun folder
check "(k) tab path: APPROVED, codex exec not run, tab create, agent start, no send-keys" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "APPROVED sha256 $h" ] && [ ! -e "$tmp/argv" ] && grep -qF -- "tab create" "$tmp/herdr.log" && grep -q "^agent start st-codex-demo --kind codex" "$tmp/herdr.log" && [ "$(grep -c "^agent send-keys" "$tmp/herdr.log")" = 0 ]'
check "(k) G5 tab path: the last line names the tab" '[ "$(tail -n1 <<<"$out")" = "codex: tab st-codex-demo" ]'
hrun nofolder
check "(k1) tab path, no Folder access screen: APPROVED, no send-keys, codex exec not run" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "APPROVED sha256 $h" ] && [ ! -e "$tmp/argv" ] && grep -q "^agent start st-codex-demo" "$tmp/herdr.log" && ! grep -q "send-keys" "$tmp/herdr.log"'
hrun nomarkers
check "(k6) no markers in the answer: the ERROR line, then codex exec runs and the verdict is APPROVED" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "ERROR: no answer between the markers" ] && grep -qx "APPROVED sha256 $h" <<<"$out" && [ "$(head -n1 "$tmp/argv")" = exec ]'
printf '%s' '{"verdict":"REVISE","summary":"s","findings":[{"claim":"c","evidence":"e","location":"l","severity":"URGENT"}]}' > "$tmp/answer"
hrun nofolder
check "(k8) tab answer with severity URGENT: BLOCKED: malformed answer, codex exec not run" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: malformed answer" ] && [ ! -e "$tmp/argv" ]'
approve
mkdir -p "$tmp/t124"
printf '#!/usr/bin/env bash\n[ "$4" = bash ] && exit 124\nshift 3\nexec "$@"\n' > "$tmp/t124/timeout"
chmod +x "$tmp/t124/timeout"
hp="$tmp/t124:" hrun folder
check "(k7) tab path timed out (124): ERROR: Codex tab timed out, then codex exec runs and the verdict is APPROVED" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "ERROR: Codex tab timed out" ] && grep -qx "APPROVED sha256 $h" <<<"$out" && [ "$(head -n1 "$tmp/argv")" = exec ]'

mkdir -p "$tmp/sc"
cp -r "$root/scripts" "$tmp/sc/scripts"
sed -i 's/^  sleep 1$/  :/' "$tmp/sc/scripts/st-lock.sh"
check "(k5) setup: the copied lock does not sleep" '! grep -q "^  sleep 1$" "$tmp/sc/scripts/st-lock.sh"'
sleep 120 & holder=$!
mkdir "$proj/.git/stratum-codex-$ws.lock"
echo "$holder" > "$proj/.git/stratum-codex-$ws.lock/pid"
sr="$tmp/sc" hrun folder
kill "$holder" 2>/dev/null
wait "$holder" 2>/dev/null
rm -rf "$proj/.git/stratum-codex-$ws.lock"
check "(k5) lock held: BLOCKED: Codex agent busy with another review, codex exec not run" '[ "$(head -n1 <<<"$out")" = "BLOCKED: Codex agent busy with another review" ] && [ ! -e "$tmp/argv" ] && [ ! -e "$tmp/herdr.log" ]'

hreset() { rm -f "$tmp/htab" "$tmp/helsewhere" "$tmp/hnows" "$tmp/hlabel" "$tmp/hstatus"; }
hreset
rm -rf "$tmp/state/stratum/codex-tabs"
hrun nofolder
check "(M2) tab path: no --env in herdr calls, record under codex-tabs, last line names the tab" '[ $rc = 0 ] && ! grep -q -- "--env" "$tmp/herdr.log" && [ -f "$tmp/state/stratum/codex-tabs/st-codex-demo" ] && [ "$(tail -n1 <<<"$out")" = "codex: tab st-codex-demo" ]'
hreset
rm -f "$tmp/herdr.log"
printf '%s' nofolder > "$tmp/hmode"
for fd in 001-demo 002-count; do (cd "$proj" && PATH="$tmp/hbin2:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=$ws bash "$root/scripts/st-advisor.sh" plan "specs/$fd" >/dev/null); done
check "(M3) two feature folders: both agent start lines name st-codex-demo" '[ "$(grep -c "^agent start st-codex-demo --kind codex" "$tmp/herdr.log")" = 2 ]'
hreset
touch "$tmp/htab"
printf '%s' working > "$tmp/hstatus"
hrun nofolder
check "(M4) tab working: codex exec runs, no agent prompt, last line says headless" '[ $rc = 0 ] && [ -f "$tmp/argv" ] && ! grep -q "^agent prompt" "$tmp/herdr.log" && [ "$(tail -n1 <<<"$out")" = "codex: headless (Codex tab in use)" ]'
hreset
touch "$tmp/htab"
mkdir -p "$tmp/state/stratum/codex-tabs"
printf 'w1:t2\n-m\nold\n' > "$tmp/state/stratum/codex-tabs/st-codex-demo"
hrun nofolder
check "(M5) tab idle, record differs: the settings line is in the output" 'grep -qxF "codex: the Codex tab runs with -m old, advisor.json asks for Codex defaults. Close the tab to apply." <<<"$out"'
hreset
for pair in 'stratum|st-codex-stratum' 'Stratum Main!|st-codex-stratum-main-' 'abcdefghijklmnopqrstuvwxyz0123456789ABCD|st-codex-abcdefghijklmnopqrstuvw' '~|st-codex-wq9'; do
  printf '%s' "${pair%%|*}" > "$tmp/hlabel"
  hrun nofolder
  got=$(sed -n 's/^agent start \([^ ]*\) .*/\1/p' "$tmp/herdr.log" 2>/dev/null | head -n1)
  check "(M16) label ${pair%%|*}: agent start ${pair#*|}" '[ "$got" = "${pair#*|}" ]'
done
touch "$tmp/hnows"
hrun nofolder
got=$(sed -n 's/^agent start \([^ ]*\) .*/\1/p' "$tmp/herdr.log" 2>/dev/null | head -n1)
check "(M16) no workspace entry for the id: agent start st-codex-wq9" '[ "$got" = st-codex-wq9 ]'
hreset
touch "$tmp/helsewhere"
hrun nofolder
check "(M17) name live in another workspace: codex exec runs, no tab create, agent start or agent prompt, last line says so" '[ $rc = 0 ] && [ -f "$tmp/argv" ] && ! grep -qE "^(tab create|agent start|agent prompt)" "$tmp/herdr.log" && [ "$(tail -n1 <<<"$out")" = "codex: headless (Codex tab name st-codex-demo in use elsewhere)" ]'
hreset
check "no repo writes" '[ "$(git -C "$root" status --porcelain)" = "$repo_before" ]'
exit $fail
