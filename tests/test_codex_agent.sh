#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
fail=0
left=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$tmp" XDG_STATE_HOME="$tmp/state"

export REAL_SLEEP
REAL_SLEEP=$(command -v sleep)
export S="$tmp/s"
export ALLLOG="$tmp/alllog"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/sleep" <<'FAKE'
#!/bin/sh
exit 0
FAKE
cat > "$tmp/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
{ printf '%s' "$1"; for a in "${@:2}"; do printf '\t%s' "$a"; done; echo; } | tee -a "$S/log" | tr '\t' ' ' >> "$ALLLOG"
err() { printf '{"error":{"code":"%s","message":"%s"}}\n' "$1" "$2"; exit 1; }
[ -e "$tabs/st-codex-t1.review" ] && touch "$S/marker_at_$2"
case "$1 $2" in
  "agent list")
    printf '{"id":"x%s","result":{"agents":%s}}\n' "$RANDOM" "$(cat "$S/agents")" ;;
  "tab create")
    ws=$HERDR_WORKSPACE_ID
    printf 'p%s%s' "$RANDOM" "$RANDOM" > "$S/pane"
    printf '%s:t%s' "$ws" "$RANDOM" > "$S/tab"
    printf '{"id":"x%s","result":{"tab":{"tab_id":"%s","workspace_id":"%s"},"root_pane":{"pane_id":"%s"}}}\n' "$RANDOM" "$(cat "$S/tab")" "$ws" "$(cat "$S/pane")" ;;
  "tab close")
    printf '{"id":"x","result":{}}\n' ;;
  "agent start")
    [ -f "$S/start_sleep" ] && "$REAL_SLEEP" "$(cat "$S/start_sleep")"
    n=$(cat "$S/startcount" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$S/startcount"
    [ "$n" -le "$(cat "$S/start_busy" 2>/dev/null || echo 0)" ] && err agent_pane_busy "pane is busy"
    [ -f "$S/notready" ] && err agent_not_ready "agent did not become ready"
    pane=
    while [ $# -gt 0 ]; do [ "$1" = --pane ] && pane=$2; shift; done
    [ "$pane" = "$(cat "$S/pane" 2>/dev/null)" ] || err pane_not_found "no such pane"
    printf '{"id":"x%s","result":{"agent":{"name":"ok"}}}\n' "$RANDOM" ;;
  "agent get")
    [ -f "$S/gone" ] && err agent_not_found "no such agent"
    [ "$3" = st-codex-t1 ] || err agent_not_found "no such agent"
    printf '{"id":"x%s","result":{"agent":{"agent_status":"%s"}}}\n' "$RANDOM" "$(cat "$S/status" 2>/dev/null || echo idle)" ;;
  "agent wait")
    [ -f "$S/wait_gone" ] && { touch "$S/gone"; err agent_not_found "no such agent"; }
    [ -f "$S/wait_hang" ] && { touch "$S/gone"; exec "$REAL_SLEEP" 10; }
    printf '{"id":"x","result":{}}\n' ;;
  "agent read")
    [ -f "$S/read_err" ] && err agent_read_failed "read failed"
    cat "$S/screen" ;;
  "agent send-keys")
    printf '{"id":"x","result":{}}\n' ;;
  "agent prompt")
    [ -f "$S/on_prompt" ] && (cd "$PROJ" && bash "$S/on_prompt")
    [ -f "$tabs/st-codex-t1.review" ] && { cp "$tabs/st-codex-t1.review" "$S/marker_seen"; kill -0 "$(cat "$S/marker_seen")" 2>/dev/null && touch "$S/marker_live"; }
    if [ -f "$S/screen_prompt" ]; then
      nonce=$(grep -o 'ST-ADVISOR-BEGIN-[0-9a-f]\{12\}' "$PF" | tail -1 | sed 's/.*-//')
      sed "s/@N@/$nonce/g" "$S/screen_prompt" > "$S/screen"
    fi
    [ -f "$S/prompt_hang" ] && { touch "$S/gone"; exec "$REAL_SLEEP" 10; }
    [ -f "$S/prompt_gone" ] && touch "$S/gone"
    [ -f "$S/prompt_err" ] && err "$(cat "$S/prompt_err")" "prompt failed"
    printf '{"id":"x","result":{"state":"done"}}\n' ;;
  *) err unknown "unknown command" ;;
esac
FAKE
chmod +x "$tmp/bin/sleep" "$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH"
export HERDR_ENV=1

proj="$tmp/proj"
tabs="$tmp/state/stratum/codex-tabs"
export tabs
mkdir -p "$proj"
pp=$(cd "$proj" && pwd -P)
pf="$tmp/prompt.txt"
af="$tmp/answer.json"
export PF="$pf"
export PROJ="$proj"

chat='› Ask Codex to do anything'
ans=$'• ST-ADVISOR-BEGIN-@N@\n• {"verdict":"APPROVED","summary":"fine","findings":[]}\n• ST-ADVISOR-END-@N@\n'

new() {
  export HERDR_WORKSPACE_ID="ws$RANDOM$RANDOM"
  rm -rf "$S" "$tabs" "$pf" "$af"
  mkdir -p "$S"
  : > "$S/log"
  printf '[]' > "$S/agents"
  printf '%s\n' "$chat" > "$S/screen"
  printf '%s' "$ans" > "$S/screen_prompt"
  printf 'REQUEST BODY\n' > "$pf"
  repo
}
go() {
  out=$(cd "$proj" && bash "$root/scripts/st-codex-agent.sh" st-codex-t1 "$pf" "$af" "$tabs" "$@" 2>&1)
  rc=$?
  tr '\t' ' ' < "$S/log" > "$S/log.txt"
  if [ -e "$tabs/st-codex-t1.review" ]; then left=1; fi
}
cnt() { grep -c -- "$1" "$S/log.txt"; }
outhas() { printf '%s\n' "$out" | grep -qF -- "$1"; }
outline() { printf '%s\n' "$out" | grep -qxF -- "$1"; }
agent_json() { printf '[{"name":"%s","workspace_id":"%s","tab_id":"%s:t3","pane_id":"p9","cwd":"%s"}]' "$1" "$2" "$2" "${3:-$pp}" > "$S/agents"; }
settings() { mkdir -p "$tabs" && printf '%s\n' "$HERDR_WORKSPACE_ID:t3" "$@" > "$tabs/st-codex-t1"; }
repo() {
  rm -rf "$proj"
  mkdir -p "$proj/specs/010-demo"
  git -C "$proj" init -q
  printf 'old\n' > "$proj/a.txt"
  git -C "$proj" add a.txt
  git -C "$proj" -c user.name=t -c user.email=t@t commit -qm init
}

new; go -m m1 -c 'model_reasoning_effort="high"'
pane=$(cat "$S/pane" 2>/dev/null)
check "C1 no tab: tab create without --env, agent start with -- --no-alt-screen and the options, exit 0" '[ $rc -eq 0 ] && [ "$(cnt "^tab create --workspace $HERDR_WORKSPACE_ID --cwd $pp --label Codex --no-focus\$")" = 1 ] && [ "$(cnt "^agent start st-codex-t1 --kind codex --pane $pane --timeout 120000 -- --no-alt-screen -m m1 -c model_reasoning_effort=\"high\"\$")" = 1 ]'
check "C1 settings record: tab id and options, folder 700, file 600" '[ "$(cat "$tabs/st-codex-t1")" = "$(printf "%s\n" "$(cat "$S/tab")" -m m1 -c "model_reasoning_effort=\"high\"")" ] && [ "$(stat -c %a "$tabs")" = 700 ] && [ "$(stat -c %a "$tabs/st-codex-t1")" = 600 ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; go
check "C2 tab idle, record matches: no create, start or close, one prompt, no settings line" '[ $rc -eq 0 ] && [ "$(cnt "^tab create")" = 0 ] && [ "$(cnt "^agent start")" = 0 ] && [ "$(cnt "^tab close")" = 0 ] && [ "$(cnt "^agent prompt st-codex-t1 ")" = 1 ] && ! outhas "codex: the Codex tab runs with"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings -m m1; go -m m2
check "C3 record -m m1, run -m m2: no close, create or start, prompt sent, exact settings line, exit 0" '[ $rc -eq 0 ] && [ "$(cnt "^tab close")" = 0 ] && [ "$(cnt "^tab create")" = 0 ] && [ "$(cnt "^agent start")" = 0 ] && [ "$(cnt "^agent prompt st-codex-t1 ")" = 1 ] && outline "codex: the Codex tab runs with -m m1, advisor.json asks for -m m2. Close the tab to apply."'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; go -m m1
check "C3b tab with no record: settings line says unknown settings" '[ $rc -eq 0 ] && outline "codex: the Codex tab runs with unknown settings, advisor.json asks for -m m1. Close the tab to apply."'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; echo working > "$S/status"; go
check "C4 tab working: exit 3, codex: tab in use, no prompt, no send-keys, no marker" '[ $rc -eq 3 ] && outline "codex: tab in use" && [ "$(cnt "^agent prompt")" = 0 ] && [ "$(cnt "^agent send-keys")" = 0 ] && [ ! -e "$tabs/st-codex-t1.review" ]'
check "C22 C4 marker not written before the in-use check" '[ ! -e "$S/marker_at_get" ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; echo blocked > "$S/status"; go
check "C5 tab blocked: exit 3, codex: tab in use, no prompt, no send-keys, no marker" '[ $rc -eq 3 ] && outline "codex: tab in use" && [ "$(cnt "^agent prompt")" = 0 ] && [ "$(cnt "^agent send-keys")" = 0 ] && [ ! -e "$tabs/st-codex-t1.review" ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; echo done > "$S/status"; go
check "C6 tab done: prompt sent, exit 0" '[ $rc -eq 0 ] && [ "$(cnt "^agent prompt st-codex-t1 ")" = 1 ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; echo unknown > "$S/status"; go
check "C6 tab unknown: prompt sent, exit 0" '[ $rc -eq 0 ] && [ "$(cnt "^agent prompt st-codex-t1 ")" = 1 ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; echo agent_blocked > "$S/prompt_err"; go
check "C7 prompt returns agent_blocked: exit 3, codex: tab in use" '[ $rc -eq 3 ] && outline "codex: tab in use"'

new; agent_json st-codex-t1 "wsOTHER$RANDOM"; go
check "C9 name live in another workspace: exit 5, in use elsewhere, no create, start, prompt, send-keys or close" '[ $rc -eq 5 ] && outline "codex: tab name st-codex-t1 in use elsewhere" && [ "$(cnt "^tab create")" = 0 ] && [ "$(cnt "^agent start")" = 0 ] && [ "$(cnt "^agent prompt")" = 0 ] && [ "$(cnt "^agent send-keys")" = 0 ] && [ "$(cnt "^tab close")" = 0 ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID" /elsewhere; go
check "C9 name live in this workspace with another cwd: exit 5, in use elsewhere, no create, start, prompt, send-keys or close" '[ $rc -eq 5 ] && outline "codex: tab name st-codex-t1 in use elsewhere" && [ "$(cnt "^tab create")" = 0 ] && [ "$(cnt "^agent start")" = 0 ] && [ "$(cnt "^agent prompt")" = 0 ] && [ "$(cnt "^agent send-keys")" = 0 ] && [ "$(cnt "^tab close")" = 0 ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; echo 'printf changed > a.txt' > "$S/on_prompt"; go
check "C10 Codex changes a tracked file: exit 4, BLOCKED names it, new content kept" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: a.txt" && [ "$(cat "$proj/a.txt")" = changed ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; echo 'printf x > b.txt' > "$S/on_prompt"; go
check "C11 Codex adds an untracked file: exit 4, BLOCKED names it" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: b.txt"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; printf old > "$proj/u.txt"; echo 'printf new > u.txt' > "$S/on_prompt"; go
check "C12 Codex changes an untracked file that was there: exit 4, BLOCKED names it" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: u.txt"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; printf old > "$proj/u.txt"; echo 'rm u.txt' > "$S/on_prompt"; go
check "C13 Codex removes an untracked file: exit 4, BLOCKED names it" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: u.txt"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; echo 'printf x > c.txt; git add c.txt; git -c user.name=t -c user.email=t@t commit -qm c' > "$S/on_prompt"; go
check "C14 Codex commits: exit 4, BLOCKED names HEAD" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: HEAD"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; go
check "C15 no change: exit 0, answer written, no BLOCKED line" '[ $rc -eq 0 ] && [ -s "$af" ] && ! outhas "BLOCKED:"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; printf dirty > "$proj/a.txt"; go
check "C16 tree dirty before and the same after: exit 0, no BLOCKED line" '[ $rc -eq 0 ] && ! outhas "BLOCKED:"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; echo 'rm a.txt; printf x > b.txt' > "$S/on_prompt"; go
check "C10b Codex deletes a tracked file and adds one: exit 4, BLOCKED names both" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: a.txt, b.txt"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; (cd "$proj" && printf X > a.txt && git add a.txt && printf Y > a.txt); echo 'printf Z > a.txt; git add a.txt; printf Y > a.txt' > "$S/on_prompt"; go
check "C16b Codex restages a file that was MM: exit 4, BLOCKED names it" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: a.txt"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; printf dirty > "$proj/a.txt"; echo 'chmod +x a.txt' > "$S/on_prompt"; go
check "C16e Codex sets the x bit on a dirty tracked file: exit 4, BLOCKED names it" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: a.txt"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; (cd "$proj" && printf same > x.txt && printf same > y.txt && ln -s x.txt l); echo 'ln -sfn y.txt l' > "$S/on_prompt"; go
check "C16f Codex retargets an untracked symlink to a file with the same bytes: exit 4, BLOCKED names it" '[ $rc -eq 4 ] && outline "BLOCKED: Codex changed files during the review: l"'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; GIT_DIR="$tmp/nowhere" go
check "C16c git status fails before the prompt: ERROR, exit 1, no prompt" '[ $rc -eq 1 ] && outline "ERROR: cannot read git status in $pp" && [ "$(cnt "^agent prompt")" = 0 ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; repo; echo 'mv .git .git.x' > "$S/on_prompt"; go
check "C16d git status fails after the prompt: exit 4, BLOCKED cannot read git status" '[ $rc -eq 4 ] && outline "BLOCKED: cannot read git status in $pp"'

new; echo 2 > "$S/start_busy"; go
check "e busy twice then ok: 3 start calls" '[ $rc -eq 0 ] && [ "$(cnt "^agent start")" = 3 ]'
new; echo 999 > "$S/start_busy"; go
check "e busy always: 10 start calls, ERROR, exit 1" '[ $rc -eq 1 ] && [ "$(cnt "^agent start")" = 10 ] && outhas "ERROR:" && [ "$(cnt "^agent prompt")" = 0 ]'

new; echo 2 > "$S/start_sleep"; go
check "g prompt file ends with the three step-4 lines" '[ "$(tail -3 "$pf" | head -1)" = "The project root is $pp. Read every path above relative to it." ] && tail -1 "$pf" | grep -Eq "^Print the line ST-ADVISOR-BEGIN-([0-9a-f]{12}) alone, then the JSON object on one line, then the line ST-ADVISOR-END-\1 alone\. Print nothing after the end line\.\$"'
check "C17 prompt argv ends --wait --until done --until idle, no --until blocked, no --timeout" '[[ $(grep "^agent prompt" "$S/log.txt") == *" --wait --until done --until idle" ]] && [[ $(grep "^agent prompt" "$S/log.txt") != *"--until blocked"* ]] && [[ $(grep "^agent prompt" "$S/log.txt") != *"--timeout"* ]]'
new; go
check "C17 plain run: prompt argv ends --wait --until done --until idle, no --until blocked, no --timeout" '[[ $(grep "^agent prompt" "$S/log.txt") == *" --wait --until done --until idle" ]] && [[ $(grep "^agent prompt" "$S/log.txt") != *"--until blocked"* ]] && [[ $(grep "^agent prompt" "$S/log.txt") != *"--timeout"* ]]'
check "g prompt names the request file" 'grep "^agent prompt st-codex-t1 " "$S/log.txt" | grep -qF "Read the review request in $pf and follow it. Change no file."'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; touch "$S/prompt_gone"; echo agent_not_found > "$S/prompt_err"; go
check "C18 prompt fails, agent get says agent_not_found: exit 4, the tab ended, no close, no ERROR line" '[ $rc -eq 4 ] && outline "BLOCKED: the Codex tab ended during the review" && [ "$(cnt "^tab close")" = 0 ] && ! outhas "ERROR:"'
new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; echo agent_prompt_stalled > "$S/prompt_err"; go
check "C19 prompt fails, agent still there: exit 4, the tab failed, no close" '[ $rc -eq 4 ] && outhas "BLOCKED: the Codex tab failed during the review: " && [ "$(cnt "^tab close")" = 0 ]'
new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; touch "$S/read_err"; go
check "C19b agent read fails after the prompt: exit 4, first line the tab failed, no ERROR line, no answer file" '[ $rc -eq 4 ] && [ "$(printf "%s\n" "$out" | grep -m1 "^BLOCKED: ")" = "BLOCKED: the Codex tab failed during the review: {\"error\":{\"code\":\"agent_read_failed\",\"message\":\"read failed\"}}" ] && ! outhas "ERROR:" && [ ! -s "$af" ]'
new; touch "$S/notready"; go
check "C20 agent_not_ready at start: agent wait with no --timeout before the prompt, prompt runs, exit 0" '[ $rc -eq 0 ] && grep -qxF "agent wait st-codex-t1 --until idle --until done" "$S/log.txt" && [ "$(cnt "^agent prompt st-codex-t1 ")" = 1 ] && [ "$(grep -n "^agent wait" "$S/log.txt" | cut -d: -f1)" -lt "$(grep -n "^agent prompt" "$S/log.txt" | cut -d: -f1)" ]'
check "C22 marker exists when agent wait runs in C20" '[ -e "$S/marker_at_wait" ]'
new; touch "$S/notready" "$S/wait_gone"; go
check "C21 agent_not_ready, wait fails, agent gone: exit 4, the tab ended, no prompt, no close" '[ $rc -eq 4 ] && outline "BLOCKED: the Codex tab ended during the review" && [ "$(cnt "^agent prompt")" = 0 ] && [ "$(cnt "^tab close")" = 0 ]'
new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; touch "$S/prompt_hang"; t0=$SECONDS; go
check "C25 prompt never returns, tab gone: exit 4 within 5 s, the tab ended, no answer file, no ERROR line" '[ $rc -eq 4 ] && [ $((SECONDS - t0)) -lt 5 ] && outline "BLOCKED: the Codex tab ended during the review" && [ ! -s "$af" ] && ! outhas "ERROR:" && [ "$(cnt "^agent read")" = 0 ]'
new; touch "$S/notready" "$S/wait_hang"; t0=$SECONDS; go
check "C26 agent wait never returns, tab gone: exit 4 within 5 s, the tab ended, no prompt" '[ $rc -eq 4 ] && [ $((SECONDS - t0)) -lt 5 ] && outline "BLOCKED: the Codex tab ended during the review" && [ "$(cnt "^agent prompt")" = 0 ] && [ ! -s "$af" ]'

new
printf '%s' $'Print the line ST-ADVISOR-BEGIN-@N@ alone, then the JSON, then the line ST-ADVISOR-END-@N@ alone.\n• ST-ADVISOR-BEGIN-@N@  \n  junk {not json\n• ST-ADVISOR-END-@N@\n• ST-ADVISOR-BEGIN-@N@\n• {"verdict":"APPROVED","summary":  \n  "fine, wrapped","findings":\n  []}   \n• ST-ADVISOR-END-@N@\n' > "$S/screen_prompt"
go
check "i last pair, wrapped JSON joined with single spaces" '[ $rc -eq 0 ] && [ "$(cat "$af")" = "{\"verdict\":\"APPROVED\",\"summary\": \"fine, wrapped\",\"findings\": []}" ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$af"'
new; go
check "i plain answer parses" '[ $rc -eq 0 ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$af"'

new; printf 'no markers here\nPrint the line ST-ADVISOR-BEGIN-@N@ alone then ST-ADVISOR-END-@N@ alone\n' > "$S/screen_prompt"; go
check "C23 no marker pair: exit 4, BLOCKED no answer between the markers, no answer file" '[ $rc -eq 4 ] && outline "BLOCKED: no answer between the markers" && [ ! -s "$af" ]'

new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; go
check "C22 marker holds a live pid during the prompt and is gone after exit" '[ -e "$S/marker_live" ] && [ ! -e "$tabs/st-codex-t1.review" ]'
check "C24 marker gone right after the prompt returns: agent read sees no marker" '[ "$(cnt "^agent read st-codex-t1 ")" = 1 ] && [ ! -e "$S/marker_at_read" ]'

check "C8 no tab close in any case of this file" 'grep -q "^agent prompt" "$ALLLOG" && ! grep -q "^tab close" "$ALLLOG"'
check "C22 marker gone after every case of this file" '[ "$left" = 0 ]'

exit $fail
