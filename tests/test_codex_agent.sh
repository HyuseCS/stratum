#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
fail=0
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
    printf '{"id":"x","result":{}}\n' ;;
  "agent read")
    cat "$S/screen" ;;
  "agent send-keys")
    printf '{"id":"x","result":{}}\n' ;;
  "agent prompt")
    [ -f "$S/on_prompt" ] && (cd "$PROJ" && bash "$S/on_prompt")
    if [ -f "$S/screen_prompt" ]; then
      nonce=$(grep -o 'ST-ADVISOR-BEGIN-[0-9a-f]\{12\}' "$PF" | tail -1 | sed 's/.*-//')
      sed "s/@N@/$nonce/g" "$S/screen_prompt" > "$S/screen"
    fi
    [ -f "$S/prompt_timeout" ] && err timeout "timed out"
    [ -f "$S/prompt_err" ] && err "$(cat "$S/prompt_err")" "prompt failed"
    if [ -f "$S/prompt_blocked" ]; then st=blocked; else st=done; fi
    printf '{"id":"x","result":{"state":"%s"}}\n' "$st" ;;
  *) err unknown "unknown command" ;;
esac
FAKE
chmod +x "$tmp/bin/sleep" "$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH"
export HERDR_ENV=1

proj="$tmp/proj"
tabs="$tmp/state/stratum/codex-tabs"
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
}
go() {
  out=$(cd "$proj" && bash "$root/scripts/st-codex-agent.sh" st-codex-t1 "$pf" "$af" "$tabs" "$@" 2>&1)
  rc=$?
  tr '\t' ' ' < "$S/log" > "$S/log.txt"
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

new; echo 2 > "$S/start_busy"; go
check "e busy twice then ok: 3 start calls" '[ $rc -eq 0 ] && [ "$(cnt "^agent start")" = 3 ]'
new; echo 999 > "$S/start_busy"; go
check "e busy always: 10 start calls, ERROR, exit 1" '[ $rc -eq 1 ] && [ "$(cnt "^agent start")" = 10 ] && outhas "ERROR:" && [ "$(cnt "^agent prompt")" = 0 ]'

new; echo 2 > "$S/start_sleep"; go
ms=$(tail -1 "$S/log.txt" | grep '^agent prompt' | awk '{print $NF}')
[ -z "$ms" ] && ms=$(grep '^agent prompt' "$S/log.txt" | awk '{print $NF}')
check "g prompt file ends with the three step-4 lines" '[ "$(tail -3 "$pf" | head -1)" = "The project root is $pp. Read every path above relative to it." ] && tail -1 "$pf" | grep -Eq "^Print the line ST-ADVISOR-BEGIN-([0-9a-f]{12}) alone, then the JSON object on one line, then the line ST-ADVISOR-END-\1 alone\. Print nothing after the end line\.\$"'
check "g prompt argv ends with wait/until flags and timeout <= 478000 after 2 s start" 'p=$(grep "^agent prompt" "$S/log.txt"); case "$p" in *" --wait --until done --until idle --until blocked --timeout "*) ;; *) false;; esac && [ "$ms" -le 478000 ] && [ "$ms" -ge 400000 ]'
new; go
ms=$(grep '^agent prompt' "$S/log.txt" | awk '{print $NF}')
check "g timeout at most 480000" '[ "$ms" -le 480000 ] && [ "$ms" -ge 400000 ]'
check "g prompt names the request file" 'grep "^agent prompt st-codex-t1 " "$S/log.txt" | grep -qF "Read the review request in $pf and follow it. Change no file."'

new; touch "$S/prompt_blocked"; go
check "h blocked: error, exit 1" '[ $rc -eq 1 ] && outhas "ERROR: Codex waits for an answer in its Codex tab."'
new; touch "$S/prompt_timeout"; go
check "h2 prompt timeout: error, exit 1, no tab close" '[ $rc -eq 1 ] && outhas "ERROR:" && [ "$(cnt "^tab close")" = 0 ]'
new; agent_json st-codex-t1 "$HERDR_WORKSPACE_ID"; settings; touch "$S/prompt_timeout"; go
check "h3 prompt timeout on a reused tab: no tab close" '[ $rc -eq 1 ] && [ "$(cnt "^tab close")" = 0 ]'

new
printf '%s' $'Print the line ST-ADVISOR-BEGIN-@N@ alone, then the JSON, then the line ST-ADVISOR-END-@N@ alone.\n• ST-ADVISOR-BEGIN-@N@  \n  junk {not json\n• ST-ADVISOR-END-@N@\n• ST-ADVISOR-BEGIN-@N@\n• {"verdict":"APPROVED","summary":  \n  "fine, wrapped","findings":\n  []}   \n• ST-ADVISOR-END-@N@\n' > "$S/screen_prompt"
go
check "i last pair, wrapped JSON joined with single spaces" '[ $rc -eq 0 ] && [ "$(cat "$af")" = "{\"verdict\":\"APPROVED\",\"summary\": \"fine, wrapped\",\"findings\": []}" ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$af"'
new; go
check "i plain answer parses" '[ $rc -eq 0 ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$af"'

new; printf 'no markers here\nPrint the line ST-ADVISOR-BEGIN-@N@ alone then ST-ADVISOR-END-@N@ alone\n' > "$S/screen_prompt"; go
check "j no pair: error, exit 1, no answer file" '[ $rc -eq 1 ] && outhas "ERROR: no answer between the markers" && [ ! -s "$af" ]'

check "C8 no tab close in any case of this file" 'grep -q "^agent prompt" "$ALLLOG" && ! grep -q "^tab close" "$ALLLOG"'

exit $fail
