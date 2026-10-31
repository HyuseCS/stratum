#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$tmp"

lock="$root/scripts/st-lock.sh"
repo="$tmp/repo"
wt="$tmp/wt"
git init -q "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$repo" worktree add -q --detach "$wt"
held=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)/stratum-test.lock
re='^lock: waited 1 s for test; held by pid [0-9]+ since [0-9TZ:-]+; ran nothing$'
held_wait() { local i=0; while [ ! -d "$held" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done; [ -d "$held" ]; }
cd "$repo"

bash "$lock" -- sh -c 'touch "$1"; exit 7' sh "$tmp/free"; arc=$?
check "(a) free lock: command runs and exit 7 passes through" '[ "$arc" = 7 ] && [ -e "$tmp/free" ]'
check "(a) free lock: folder gone after" '[ "$arc" = 7 ] && [ ! -d "$held" ]'

bash "$lock" -- sh -c 'sleep 3; date +%s > "$1"' sh "$tmp/aend" & apid=$!
check "(b) held: lock folder exists within 5 s" 'held_wait'
(cd "$wt" && bash "$lock" -- date +%s > "$tmp/bdate" 2> "$tmp/berr"); brc=$?
wait "$apid"
check "(b) waiting run prints the holder pid once on stderr" '[ "$(grep -c "^lock: waiting for test (pid $apid)$" "$tmp/berr")" = 1 ]'
check "(b) waiting run runs after the holder ends" '[ "$brc" = 0 ] && [ "$(cat "$tmp/bdate")" -ge "$(cat "$tmp/aend")" ]'

bash "$lock" -- sleep 5 & apid=$!
held_wait
(cd "$wt" && bash "$lock" --timeout 1 -- touch "$tmp/ran" 2> "$tmp/cerr"); crc=$?
wait "$apid"
check "(c) timeout: exit 75, message matches, nothing ran" '[ "$crc" = 75 ] && grep -Eq "$re" "$tmp/cerr" && [ ! -e "$tmp/ran" ]'

sh -c 'exit 0' & dead=$!; wait "$dead"
rm -rf "$held"; mkdir "$held"; printf '%s\n' "$dead" > "$held/pid"; date -u +%Y-%m-%dT%H:%M:%SZ > "$held/since"
SECONDS=0; bash "$lock" -- touch "$tmp/stale"; drc=$?; dsec=$SECONDS
check "(d) stale lock: runs at once and the folder is gone after" '[ "$drc" = 0 ] && [ -e "$tmp/stale" ] && [ "$dsec" -lt 2 ] && [ ! -d "$held" ]'

rm -rf "$held"
(cd "$wt" && exec bash "$lock" -- sleep 5) & apid=$!
check "(e) held from a worktree: lock folder in the git common dir" 'held_wait'
wait "$apid"

bash "$lock" -- sleep 5 & apid=$!
held_wait; fheld=$?
SECONDS=0; (cd "$wt" && bash "$lock" --name codex-w1 -- touch "$tmp/w1"); frc=$?; fsec=$SECONDS
wait "$apid"
check "(f) --name codex-w1 runs while the test lock is held" '[ "$fheld" = 0 ] && [ "$frc" = 0 ] && [ -e "$tmp/w1" ] && [ "$fsec" -lt 2 ]'

mkdir "$tmp/nogit"
out=$(cd "$tmp/nogit" && bash "$lock" -- true 2>&1); grc=$?
check "(g) outside a git repo: message and exit 2" '[ "$grc" = 2 ] && [ "$out" = "lock: not in a git repo" ]'

bash "$lock" --timeout abc -- true > "$tmp/h1" 2>&1; h1=$?
bash "$lock" true > "$tmp/h2" 2>&1; h2=$?
check "(h) --timeout abc: usage line and exit 2" '[ "$h1" = 2 ] && grep -qi usage "$tmp/h1"'
check "(h) missing --: usage line and exit 2" '[ "$h2" = 2 ] && grep -qi usage "$tmp/h2"'

check "(i) no pgrep, flock, pkill or ps text in the script" '[ -f "$lock" ] && ! grep -Eq "(^|[^A-Za-z])(pgrep|flock|pkill|ps )" "$lock"'
exit $fail
