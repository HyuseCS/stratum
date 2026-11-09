#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$tmp" XDG_STATE_HOME="$tmp/state"
repo_paths() { git -C "$root" status --porcelain --no-renames --untracked-files=all | cut -c4- | while IFS= read -r p; do echo "$(git -C "$root" hash-object -- "$p" 2>/dev/null) $p"; done | sort; }
repo_before=$(repo_paths)

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
printf '%s\n' "$*" >> "$FAKE_DIR/timeout.log"
shift 3
exec "$@"
FAKE
chmod +x "$tmp/bin/codex" "$tmp/bin/timeout"
realtimeout=$(command -v timeout)
export FAKE_DIR="$tmp"
export PATH="$tmp/bin:$PATH"
mkdir -p "$tmp/nosleep"
ln -s "$(type -P true)" "$tmp/nosleep/sleep"
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
  "agent get")
    if [ "$m" = gone ] && [ -e "$d/h.args" ]; then
      echo '{"error":{"code":"agent_not_found","message":"agent st-codex-demo not found"}}'
      exit 1
    fi
    n=$(( $(cat "$d/hget.n" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$d/hget.n"
    [ "$n" = 3 ] && rm -f "$XDG_STATE_HOME/stratum/codex-tabs/st-codex-demo.review"
    gws=$HERDR_WORKSPACE_ID gcwd=$(pwd -P)
    [ -e "$d/hgetws" ] && gws=wOther
    [ -e "$d/hgetcwd" ] && gcwd=/elsewhere
    echo "{\"result\":{\"agent\":{\"agent_status\":\"$hs\",\"workspace_id\":\"$gws\",\"cwd\":\"$gcwd\"}}}" ;;
  "workspace list")
    lab=$(cat "$d/hlabel" 2>/dev/null)
    [ -e "$d/hnows" ] && echo '{"result":{"workspaces":[]}}' || echo "{\"result\":{\"workspaces\":[{\"workspace_id\":\"$HERDR_WORKSPACE_ID\",\"label\":\"${lab:-demo}\"}]}}" ;;
  "tab create") echo '{"result":{"tab":{"tab_id":"w1:t2"},"root_pane":{"pane_id":"w1:p2"}}}' ;;
  "agent start") echo '{"result":{"agent":"codex","name":"st-codex-demo","pane_id":"w1:p2"}}' ;;
  "agent prompt") printf '%s\n' "$@" > "$d/h.args"
    [ "$m" = gone ] && { echo '{"error":{"code":"agent_not_found","message":"agent st-codex-demo not found"}}'; exit 1; }
    [ "$m" = writes ] && printf 'new\n' > "$d/proj/new.txt"; echo '{"result":{"state":"done"}}' ;;
  "agent read")
    if [[ " $* " == *" 400 "* ]]; then
      [ "$m" = nomarkers ] && { echo "some text without the markers"; exit 0; }
      pf=$(sed -n 's/.*request in \(.*\) and follow it.*/\1/p' "$d/h.args" | head -n1)
      nonce=$(grep -o 'ST-ADVISOR-BEGIN-[0-9a-f]\{12\}' "$pf" | tail -n1 | sed 's/ST-ADVISOR-BEGIN-//')
      echo "ready"
      echo "ST-ADVISOR-BEGIN-$nonce"
      cat "$d/answer"; echo
      echo "ST-ADVISOR-END-$nonce"
    else
      r=$(( $(cat "$d/hread.n" 2>/dev/null || echo 0) + 1 )); echo "$r" > "$d/hread.n"
      if [ -e "$d/hfixture" ]; then
        cat "$d/hfixture"
      elif [ -e "$d/hscreen2" ] && [ "$r" -ge 2 ]; then
        printf 'Do you want to run this command?\n> 1. Yes, proceed\n  2. No, and rm -rf x\n'
      else
        printf 'Do you want to run this command?\n> 1. Yes, proceed\n  2. No, tell Codex what to do differently\n'
      fi
    fi ;;
esac
exit 0
FAKE
chmod +x "$tmp/hbin2/herdr"
ws=wQ9
hrun() {
  rm -f "$tmp/argv" "$tmp/herdr.log" "$tmp/h.args" "$tmp/hget.n" "$tmp/timeout.log"
  printf '%s' "$1" > "$tmp/hmode"
  out=$(cd "$proj" && PATH="$tmp/hbin2:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=$ws bash "${sr:-$root}/scripts/st-advisor.sh" plan specs/001-demo); rc=$?
}
setmode '{"mode": "codex"}'
approve
h=$(plan_hash)
hrun folder
check "(k) tab path: APPROVED, codex exec not run, tab create, agent start, no send-keys" '[ $rc = 0 ] && [ "$(head -n1 <<<"$out")" = "APPROVED sha256 $h" ] && [ ! -e "$tmp/argv" ] && grep -qF -- "tab create" "$tmp/herdr.log" && grep -q "^agent start st-codex-demo --kind codex" "$tmp/herdr.log" && [ "$(grep -c "^agent send-keys" "$tmp/herdr.log")" = 0 ]'
check "(k) G5 tab path: the last line names the tab" '[ "$(tail -n1 <<<"$out")" = "codex: tab st-codex-demo" ]'
printf '%s' '{"verdict":"REVISE","summary":"s","findings":[{"claim":"c","evidence":"e","location":"l","severity":"URGENT"}]}' > "$tmp/answer"
hrun nofolder
check "(k8) tab answer with severity URGENT: BLOCKED: malformed answer, codex exec not run" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: malformed answer" ] && [ ! -e "$tmp/argv" ]'
approve

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
check "(k5) lock held: BLOCKED: Codex agent busy with another review, codex exec not run" '[ "$(head -n1 <<<"$out")" = "BLOCKED: Codex agent busy with another review" ] && [ ! -e "$tmp/argv" ] && ! grep -vqx "workspace list" "$tmp/herdr.log" 2>/dev/null'

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
h=$(plan_hash)
approve
hrun writes
check "(M6) Codex writes a file in the tab: first line BLOCKED with the file, exit 1, BLOCKED record, codex exec not run, file kept" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: Codex changed files during the review: new.txt" ] && [ ! -e "$tmp/argv" ] && [ -f "$proj/new.txt" ] && grep -qE "^## plan \| [^|]+ \| sha256 $h \| BLOCKED$" "$recf" && grep -qxF "reason: Codex changed files during the review: new.txt" "$recf"'
rm -f "$proj/new.txt"
mk="$tmp/state/stratum/codex-tabs/st-codex-demo.review"
mkdir -p "$tmp/state/stratum/codex-tabs"
akey() { rm -f "$tmp/herdr.log" "$tmp/hget.n" "$tmp/hread.n"; out=$(cd "$proj" && PATH="$tmp/hbin2:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=$ws bash "$root/scripts/st-advisor.sh" answer "$@"); rc=$?; }
wrun() { rm -f "$tmp/herdr.log" "$tmp/hget.n" "$tmp/hread.n"; out=$(cd "$proj" && PATH="$tmp/nosleep:$tmp/hbin2:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=$ws "$realtimeout" "$1" bash "$root/scripts/st-advisor.sh" watch); rc=$?; }
mark() { sleep 120 & live=$!; echo "$live" > "$mk"; }
unmark() { kill "$live" 2>/dev/null; wait "$live" 2>/dev/null; rm -f "$mk"; }
nokeys() { ! grep -q "^agent send-keys" "$tmp/herdr.log" 2>/dev/null; }
scr1=$'Do you want to run this command?\n> 1. Yes, proceed\n  2. No, tell Codex what to do differently'
scr2=$'Do you want to run this command?\n> 1. Yes, proceed\n  2. No, and rm -rf x'
sh1=$(sha256sum <<<"$scr1" | cut -c1-12)
sh2=$(sha256sum <<<"$scr2" | cut -c1-12)
printf blocked > "$tmp/hstatus"
rm -f "$mk"
akey --screen "$sh1" --keys y
check "(M7) answer --keys y, no marker: no review waits in the Codex tab, exit 1, no send-keys" '[ $rc = 1 ] && [ "$out" = "no review waits in the Codex tab" ] && nokeys'
sleep 120 & dead=$!; kill "$dead"; wait "$dead" 2>/dev/null
echo "$dead" > "$mk"
akey --screen "$sh1" --keys y
check "(M8) answer, marker with a dead pid, tab blocked: no review waits in the Codex tab, exit 1, no send-keys" '[ $rc = 1 ] && [ "$out" = "no review waits in the Codex tab" ] && nokeys'
rm -f "$mk"
printf idle > "$tmp/hstatus"
mark
akey --screen "$sh1" --keys y
unmark
check "(M9) answer, live marker, tab idle: no review waits in the Codex tab, exit 1, no send-keys" '[ $rc = 1 ] && [ "$out" = "no review waits in the Codex tab" ] && nokeys'
printf blocked > "$tmp/hstatus"
mark
akey --screen "$sh1" --keys y
unmark
check "(M10) answer with the screen hash, live marker, tab blocked: one send-keys y, sent: y, exit 0" '[ $rc = 0 ] && [ "$out" = "sent: y" ] && [ "$(grep -cxF "agent send-keys st-codex-demo y" "$tmp/herdr.log" 2>/dev/null)" = 1 ]'
mark
akey --screen 000000000000 --keys y
unmark
check "(M21) answer with another screen hash, live marker, tab blocked: the Codex tab shows another prompt, exit 1, no send-keys" '[ $rc = 1 ] && [ "$out" = "the Codex tab shows another prompt" ] && nokeys'
mark
akey --screen "$sh2" --keys y
unmark
check "(M21) answer with the hash of a screen not shown: refused, no send-keys" '[ $rc = 1 ] && [ "$out" = "the Codex tab shows another prompt" ] && nokeys'
ul="usage: st-advisor.sh plan|test|diff|decisions|change|review|round|check|continued|waive|note|talk|count|answer|watch ..."
ok=1
for k in 'a;b' '$(x)' -x --help; do
  akey --screen "$sh1" --keys "$k"
  [ $rc = 2 ] && [ "$(head -n1 <<<"$out")" = "$ul" ] && [ ! -e "$tmp/herdr.log" ] || ok=0
done
check "(M11) answer --keys with a;b, \$(x), -x or --help: usage line names answer|watch, exit 2, no herdr call" '[ $ok = 1 ]'
ok=1
mark
for a in "--keys y" "--screen --keys y" "--screen ${sh1}0 --keys y" "--screen ${sh1:1} --keys y" "--screen ABCDEF012345 --keys y" "--screen 0123456789ag --keys y" "--screen $sh1" "--keys y --screen $sh1"; do
  read -ra av <<<"$a"
  akey "${av[@]}"
  [ $rc = 2 ] && [ "$(head -n1 <<<"$out")" = "$ul" ] && [ ! -e "$tmp/herdr.log" ] || { ok=0; echo "  bad case: answer $a rc=$rc" >&2; }
done
unmark
check "(M22) answer with no, a short, a long, an uppercase or a non-hex --screen, or keys first: usage, exit 2, no herdr call" '[ $ok = 1 ]'
out=$(cd "$proj" && bash "$root/scripts/st-advisor.sh" answer --screen "$sh1" --keys y); rc=$?
outw=$(cd "$proj" && "$realtimeout" 20 bash "$root/scripts/st-advisor.sh" watch); rcw=$?
check "(M12) answer and watch outside herdr: not in herdr, exit 1" '[ $rc = 1 ] && [ "$out" = "not in herdr" ] && [ $rcw = 1 ] && [ "$outw" = "not in herdr" ]'
printf blocked > "$tmp/hstatus"
mark
wrun 20
unmark
exp=$(printf 'codex tab waits: st-codex-demo %s\n%s\ncodex tab waits: end' "$sh1" "$scr1")
check "(M13) watch, live marker, tab blocked: the screen once between the waits lines, the header names the screen hash, exit 0 after the marker goes" '[ $rc = 0 ] && [ "$out" = "$exp" ]'
scr20=$(cat <<'SCREEN'
• Ran git ls-remote origin
└ fatal: unable to access 'https://github.com/HyuseCS/stratum.git/': Could not resolve host: github.com
• Running git ls-remote origin
Would you like to run the following command?
Environment: local
Reason: May I run the plan’s required read-only remote-branch query with network access?
$ git ls-remote origin
› 1. Yes, proceed (y)
2. Yes, and don't ask again for commands that start with `git ls-remote origin` (p)
3. No, and tell Codex what to do differently (esc)
Press enter to confirm or esc to cancel
SCREEN
)
printf '%s\n' "$scr20" > "$tmp/hfixture"
sh20=$(sha256sum <<<"$scr20" | cut -c1-12)
printf blocked > "$tmp/hstatus"
mark
wrun 20
unmark
rm -f "$tmp/hfixture"
exp=$(printf 'codex tab waits: st-codex-demo %s\n%s\ncodex tab waits: end' "$sh20" "$scr20")
check "(M20) watch, live marker, tab blocked, the saved real screen: the screen between the waits lines, exit 0 after the marker goes" '[ $rc = 0 ] && [ "$out" = "$exp" ]'
check "(M20) watch: the header hash is the first 12 hex of sha256 of the printed screen" '[ "$(head -n1 <<<"$out")" = "codex tab waits: st-codex-demo $sh20" ]'
touch "$tmp/hscreen2"
mark
wrun 20
unmark
rm -f "$tmp/hscreen2"
exp=$(printf 'codex tab waits: st-codex-demo %s\n%s\ncodex tab waits: end\ncodex tab waits: st-codex-demo %s\n%s\ncodex tab waits: end' "$sh1" "$scr1" "$sh2" "$scr2")
check "(M23) watch, the blocked screen changes: a second block with the new hash, the same screen not again" '[ $rc = 0 ] && [ "$out" = "$exp" ]'
printf blocked > "$tmp/hstatus"
rm -f "$mk"
wrun 3
check "(M14) watch, no marker, tab blocked: no output and no exit within 3 s" '[ $rc = 124 ] && [ -z "$out" ]'
for f in hgetws hgetcwd; do
  touch "$tmp/$f"
  mark
  akey --screen "$sh1" --keys y
  unmark
  check "(M24) answer, live marker, tab blocked, $f differs: no review waits in the Codex tab, exit 1, no send-keys" '[ $rc = 1 ] && [ "$out" = "no review waits in the Codex tab" ] && nokeys'
  mark
  wrun 20
  unmark
  check "(M24) watch, live marker, tab blocked, $f differs: no output" '[ -z "$out" ] && [ $rc = 0 ]'
  rm -f "$tmp/$f"
done
setmode '{"mode": "codex"}'
approve
h=$(plan_hash)
touch "$tmp/htab"
printf idle > "$tmp/hstatus"
printf 'w1:t2\n' > "$tmp/state/stratum/codex-tabs/st-codex-demo"
rm -f "$mk"
hrun gone
check "(M15) the tab ends during the review: first line BLOCKED: the Codex tab ended during the review, record line, BLOCKED record, codex exec not run" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: the Codex tab ended during the review" ] && [[ "$(sed -n 2p <<<"$out")" == "record: "*specs/001-demo/advisor.md ]] && [ ! -e "$tmp/argv" ] && grep -qE "^## plan \| [^|]+ \| sha256 $h \| BLOCKED$" "$recf" && grep -qxF "reason: the Codex tab ended during the review" "$recf"'
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
hrun nofolder
check "(M18) tab path: no logged timeout call runs st-lock.sh or st-codex-agent.sh, last line names the tab" '[ $rc = 0 ] && [ "$(tail -n1 <<<"$out")" = "codex: tab st-codex-demo" ] && ! grep -qE "st-lock.sh|st-codex-agent.sh" "$tmp/timeout.log" 2>/dev/null'
hreset
hrun nomarkers
check "(M19) no markers in the tab answer: first line BLOCKED: no answer between the markers, exit 1, codex exec not run" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: no answer between the markers" ] && [ ! -e "$tmp/argv" ]'
hreset
setmode '{"mode": "codex"}'
approve
br=$(git -C "$proj" symbolic-ref --short HEAD)
rrecf="$proj/.stratum/advisor/${br//\//-}.md"
rrun() {
  rm -f "$tmp/argv" "$tmp/herdr.log" "$tmp/h.args" "$tmp/hget.n" "$tmp/timeout.log"
  printf '%s' "$1" > "$tmp/hmode"
  out=$(cd "$proj" && PATH="$tmp/hbin2:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=$ws bash "$root/scripts/st-advisor.sh" review "$first"); rc=$?
}
rrun nofolder
check "(R1) review in the tab: exit 0, no codex exec, last line names the tab" '[ $rc = 0 ] && [ ! -e "$tmp/argv" ] && [ "$(tail -n1 <<<"$out")" = "codex: tab st-codex-demo" ]'
check "(R2) review in the tab: exit 0 and no timeout call" '[ $rc = 0 ] && [ ! -e "$tmp/timeout.log" ]'
hreset
touch "$tmp/htab"
printf '%s' working > "$tmp/hstatus"
rrun nofolder
check "(R3) review, tab working: codex exec runs, last line says Codex tab in use" '[ $rc = 0 ] && [ -f "$tmp/argv" ] && [ "$(tail -n1 <<<"$out")" = "codex: headless (Codex tab in use)" ]'
hreset
touch "$tmp/helsewhere"
rrun nofolder
check "(R4) review, tab name in use elsewhere: codex exec runs, last line says so" '[ $rc = 0 ] && [ -f "$tmp/argv" ] && [ "$(tail -n1 <<<"$out")" = "codex: headless (Codex tab name st-codex-demo in use elsewhere)" ]'
hreset
rm -f "$rrecf"
rrun writes
check "(R5) review, Codex writes a file in the tab: BLOCKED with the file, exit 1, BLOCKED entry in the branch record" '[ $rc = 1 ] && [ "$(head -n1 <<<"$out")" = "BLOCKED: Codex changed files during the review: new.txt" ] && grep -qE "^## review \| [^|]+ \| sha256 [0-9a-f]{64} \| BLOCKED$" "$rrecf"'
rm -f "$proj/new.txt"
hreset
check "no repo writes" '[ -z "$(repo_paths | comm -13 <(printf "%s\n" "$repo_before") -)" ]'
exit $fail
