#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$tmp" XDG_STATE_HOME="$tmp/state"

export REAL_SLEEP
REAL_SLEEP=$(command -v sleep)
export S="$tmp/s"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/sleep" <<'FAKE'
#!/bin/sh
exit 0
FAKE
cat > "$tmp/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
{ printf '%s' "$1"; for a in "${@:2}"; do printf '\t%s' "$a"; done; echo; } >> "$S/log"
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
  "agent read")
    cat "$S/screen" ;;
  "agent send-keys")
    [ -f "$S/screen_after" ] && cp "$S/screen_after" "$S/screen"
    printf '{"id":"x","result":{}}\n' ;;
  "agent prompt")
    if [ -f "$S/replace_auth" ]; then rm -f "$(cat "$S/replace_auth")/auth.json"; echo x > "$(cat "$S/replace_auth")/auth.json"; fi
    if [ -f "$S/screen_prompt" ]; then
      nonce=$(grep -o 'ST-ADVISOR-BEGIN-[0-9a-f]\{12\}' "$PF" | tail -1 | sed 's/.*-//')
      sed "s/@N@/$nonce/g" "$S/screen_prompt" > "$S/screen"
    fi
    [ -f "$S/prompt_timeout" ] && err timeout "timed out"
    if [ -f "$S/prompt_blocked" ]; then st=blocked; else st=done; fi
    printf '{"id":"x","result":{"state":"%s"}}\n' "$st" ;;
  *) err unknown "unknown command" ;;
esac
FAKE
chmod +x "$tmp/bin/sleep" "$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH"
export HERDR_ENV=1

proj="$tmp/proj"
mkdir -p "$proj/specs/010-demo" "$proj/specs/demo"
pp=$(cd "$proj" && pwd -P)
home="$tmp/home"
pf="$tmp/prompt.txt"
af="$tmp/answer.json"
export PF="$pf"
printf '{}' > "$tmp/user-auth.json"

fa=$'\033[1mFolder access\033[0m\n\nCodex can read files here.\n\n\033[36m› 1. Open restricted\033[0m\n  2. Back to Agent Command Center\n'
chat='› Ask Codex to do anything'
ans=$'• ST-ADVISOR-BEGIN-@N@\n• {"verdict":"APPROVED","summary":"fine","findings":[]}\n• ST-ADVISOR-END-@N@\n'
feat=specs/010-demo

new() {
  export HERDR_WORKSPACE_ID="ws$RANDOM$RANDOM"
  rm -rf "$S" "$home" "$pf" "$af"
  mkdir -p "$S" "$home"
  : > "$S/log"
  ln -s "$tmp/user-auth.json" "$home/auth.json"
  printf '[projects."%s"]\ntrust_level = "untrusted"\n' "$pp" > "$home/config.toml"
  printf '[]' > "$S/agents"
  printf '%s\n' "$chat" > "$S/screen"
  printf '%s' "$ans" > "$S/screen_prompt"
  printf 'REQUEST BODY\n' > "$pf"
  feat=specs/010-demo
}
go() {
  out=$(cd "$proj" && bash "$root/scripts/st-codex-agent.sh" "$feat" "$pf" "$af" "$home" "$@" 2>&1)
  rc=$?
  tr '\t' ' ' < "$S/log" > "$S/log.txt"
}
cnt() { grep -c -- "$1" "$S/log.txt"; }
lineno() { grep -n -m1 -- "$1" "$S/log.txt" | cut -d: -f1; }
outhas() { printf '%s\n' "$out" | grep -qF -- "$1"; }
agent_json() { printf '[{"name":"%s","workspace_id":"%s","tab_id":"%s:t3","pane_id":"p9","cwd":"%s"}]' "$1" "$2" "$2" "${3:-$pp}" > "$S/agents"; }
closed() { [ "$(cnt "^tab close $(cat "$S/tab")\$")" = 1 ]; }
nofolder='ERROR: Codex stopped at start on a screen Stratum does not know, so the Codex tab is closed. Run the point again, or check Codex.'

new; rm "$home/auth.json"; go
check "a0 no auth link: error, exit 2, no herdr call" '[ $rc -eq 2 ] && outhas "ERROR: no Stratum Codex home" && [ ! -s "$S/log" ]'
new; rm "$home/auth.json"; echo x > "$home/auth.json"; go
check "a0 auth.json a regular file: exit 2, no herdr call" '[ $rc -eq 2 ] && outhas "ERROR: no Stratum Codex home" && [ ! -s "$S/log" ]'
new; printf '[projects."/elsewhere"]\ntrust_level = "untrusted"\n' > "$home/config.toml"; go
check "a0b no entry for this root: exit 2, no herdr call" '[ $rc -eq 2 ] && [ "$out" = "ERROR: no Stratum Codex home entry for $pp: run st-advisor.sh codex-home" ] && [ ! -s "$S/log" ]'
new; printf '[projects."%s"]\n' "$pp" > "$home/config.toml"; go
check "a0b entry without trust_level: exit 2, no herdr call" '[ $rc -eq 2 ] && [ "$out" = "ERROR: no Stratum Codex home entry for $pp: run st-advisor.sh codex-home" ] && [ ! -s "$S/log" ]'

new; printf '%s' "$fa" > "$S/screen"; printf '%s\n' "$chat" > "$S/screen_after"
go -m m1 -c 'model_reasoning_effort="high"'
pane=$(cat "$S/pane" 2>/dev/null)
check "a rc 0 and answer written" '[ $rc -eq 0 ] && [ -s "$af" ]'
check "a tab create line" '[ "$(cnt "^tab create --workspace $HERDR_WORKSPACE_ID --cwd $pp --label Codex --env CODEX_HOME=$home --no-focus\$")" = 1 ]'
check "a agent start line with -m -c after --no-alt-screen" '[ "$(cnt "^agent start st-codex-010 --kind codex --pane $pane --timeout 120000 -- -s read-only -a never --no-alt-screen -m m1 -c model_reasoning_effort=\"high\"\$")" = 1 ]'
check "a tab create comes before agent start" '[ "$(lineno "^tab create")" -lt "$(lineno "^agent start")" ]'

new; agent_json st-codex-010 "$HERDR_WORKSPACE_ID"; go
check "b existing agent reused: no tab create, no agent start" '[ $rc -eq 0 ] && [ "$(cnt "^tab create")" = 0 ] && [ "$(cnt "^agent start")" = 0 ] && [ "$(cnt "^agent prompt st-codex-010")" = 1 ]'

new; agent_json st-codex-009 "$HERDR_WORKSPACE_ID"; go
check "c other st-codex agent: its tab closed before the new start" '[ $rc -eq 0 ] && [ "$(cnt "^tab close $HERDR_WORKSPACE_ID:t3\$")" = 1 ] && [ "$(lineno "^tab close")" -lt "$(lineno "^agent start")" ]'

new; agent_json st-codex-010 "wsOTHER$RANDOM"; go
check "d agent in another workspace ignored: new start, no tab close" '[ $rc -eq 0 ] && [ "$(cnt "^tab create")" = 1 ] && [ "$(cnt "^agent start st-codex-010")" = 1 ] && [ "$(cnt "^tab close")" = 0 ]'

new; agent_json st-codex-010 "$HERDR_WORKSPACE_ID" /elsewhere; go
check "d2 same name, cwd not this root: not reused, not closed" '[ "$(cnt "^tab create")" = 1 ] && [ "$(cnt "^tab close $HERDR_WORKSPACE_ID:t3\$")" = 0 ]'
new; agent_json st-codex-009 "$HERDR_WORKSPACE_ID" /elsewhere; go
check "d3 other st-codex agent, cwd not this root: not closed" '[ $rc -eq 0 ] && [ "$(cnt "^tab close")" = 0 ]'

new; echo 2 > "$S/start_busy"; go
check "e busy twice then ok: 3 start calls" '[ $rc -eq 0 ] && [ "$(cnt "^agent start")" = 3 ]'
new; echo 999 > "$S/start_busy"; go
check "e busy always: 10 start calls, ERROR, exit 1" '[ $rc -eq 1 ] && [ "$(cnt "^agent start")" = 10 ] && outhas "ERROR:" && [ "$(cnt "^agent prompt")" = 0 ]'

new; printf '%s' "$fa" > "$S/screen"; printf '%s\n' "$chat" > "$S/screen_after"; go
check "f exactly one enter" '[ $rc -eq 0 ] && [ "$(cnt "^agent send-keys")" = 1 ] && [ "$(cnt "^agent send-keys st-codex-010 enter\$")" = 1 ]'
check "f enter after start, before prompt" '[ "$(lineno "^agent start")" -lt "$(lineno "^agent send-keys")" ] && [ "$(lineno "^agent send-keys")" -lt "$(lineno "^agent prompt")" ]'

new; go
check "f1 no Folder access: no send-keys, prompt runs" '[ $rc -eq 0 ] && [ "$(cnt "^agent send-keys")" = 0 ] && [ "$(cnt "^agent prompt st-codex-010")" = 1 ]'
check "f1 start line ends at --no-alt-screen without -m/-c" '[ "$(cnt " -- -s read-only -a never --no-alt-screen\$")" = 1 ]'

new; touch "$S/notready"; printf '%s' "$fa" > "$S/screen"; printf '%s\n' "$chat" > "$S/screen_after"; go
check "f2 not_ready with Folder access: one enter, then prompt" '[ $rc -eq 0 ] && [ "$(cnt "^agent send-keys st-codex-010 enter\$")" = 1 ] && [ "$(cnt "^agent prompt")" = 1 ] && [ "$(lineno "^agent send-keys")" -lt "$(lineno "^agent prompt")" ]'

new; touch "$S/notready"; printf 'Trust this folder?\n1. Trust and continue\n2. Do not trust\n' > "$S/screen"; go
check "f3 not_ready with other screen: no key, error, exit 1, no prompt" '[ $rc -eq 1 ] && [ "$(cnt "^agent send-keys")" = 0 ] && outhas "$nofolder" && [ "$(cnt "^agent prompt")" = 0 ]'
check "f3 the tab this run made is closed" 'closed'

new; printf '%s' "$fa" > "$S/screen"; go
check "f4 Folder access never clears: one enter, error, exit 1, no prompt" '[ $rc -eq 1 ] && [ "$(cnt "^agent send-keys")" = 1 ] && outhas "$nofolder" && [ "$(cnt "^agent prompt")" = 0 ]'
check "f4 the tab this run made is closed" 'closed'

new; printf '\033[1mFolder access\033[0m\n\n\033[36m› 1. Trust and continue\033[0m\n  2. Open restricted\n' > "$S/screen"; printf '%s\n' "$chat" > "$S/screen_after"; go
check "f6 Folder access, option 1 not Open restricted: no key, error, exit 1, no prompt" '[ $rc -eq 1 ] && [ "$(cnt "^agent send-keys")" = 0 ] && outhas "$nofolder" && [ "$(cnt "^agent prompt")" = 0 ]'
new; printf '\033[1mFolder access\033[0m\n\n  1. Open restricted\n\033[36m› 2. Back to Agent Command Center\033[0m\n' > "$S/screen"; printf '%s\n' "$chat" > "$S/screen_after"; go
check "f7 mark on option 2: no key, error, exit 1, tab closed" '[ $rc -eq 1 ] && [ "$(cnt "^agent send-keys")" = 0 ] && outhas "$nofolder" && [ "$(cnt "^agent prompt")" = 0 ] && closed'
new; printf '\033[1mFolder access\033[0m\n\n\033[36m› 1. Open restricted\033[0m\n  2. Trust and continue\n' > "$S/screen"; printf '%s\n' "$chat" > "$S/screen_after"; go
check "f8 option 2 text different: no key, error, exit 1, tab closed" '[ $rc -eq 1 ] && [ "$(cnt "^agent send-keys")" = 0 ] && outhas "$nofolder" && [ "$(cnt "^agent prompt")" = 0 ] && closed'
new; printf '%s\n' '~/Desktop/stratum-worker-codex-tab                                                                                    11:39:36 PM' '❯ codex -s read-only -a never --no-alt-screen' '  Folder access' '  /home/hyuse/Desktop/stratum-worker-codex-tab' '  Config, hooks, and exec policies from untrusted folders stay disabled. Trusted project folders can still contribute settings.' '  Skills still load, and tools follow your permission settings. Opening will not change saved trust.' '› 1. Open restricted' '  2. Back to Agent Command Center' '  enter continue · esc back' > "$S/screen"; printf '%s\n' "$chat" > "$S/screen_after"; go
check "f9 real screen from the live run: one enter, then prompt" '[ $rc -eq 0 ] && [ "$(cnt "^agent send-keys st-codex-010 enter\$")" = 1 ] && [ "$(cnt "^agent prompt")" = 1 ]'

new; echo "$home" > "$S/replace_auth"; go
check "f5 login link replaced: error, exit 1, no answer file" '[ $rc -eq 1 ] && outhas "ERROR: Codex replaced the login link in $home;" && [ ! -e "$af" ]'

new; echo 2 > "$S/start_sleep"; go
ms=$(tail -1 "$S/log.txt" | grep '^agent prompt' | awk '{print $NF}')
[ -z "$ms" ] && ms=$(grep '^agent prompt' "$S/log.txt" | awk '{print $NF}')
check "g prompt file ends with the three step-4 lines" '[ "$(tail -3 "$pf" | head -1)" = "The project root is $pp. Read every path above relative to it." ] && tail -1 "$pf" | grep -Eq "^Print the line ST-ADVISOR-BEGIN-([0-9a-f]{12}) alone, then the JSON object on one line, then the line ST-ADVISOR-END-\1 alone\. Print nothing after the end line\.\$"'
check "g prompt argv ends with wait/until flags and timeout <= 478000 after 2 s start" 'p=$(grep "^agent prompt" "$S/log.txt"); case "$p" in *" --wait --until done --until idle --until blocked --timeout "*) ;; *) false;; esac && [ "$ms" -le 478000 ] && [ "$ms" -ge 400000 ]'
new; go
ms=$(grep '^agent prompt' "$S/log.txt" | awk '{print $NF}')
check "g timeout at most 480000" '[ "$ms" -le 480000 ] && [ "$ms" -ge 400000 ]'
check "g prompt names the request file" 'grep "^agent prompt st-codex-010 " "$S/log.txt" | grep -qF "Read the review request in $pf and follow it. Change no file."'

new; touch "$S/prompt_blocked"; go
check "h blocked: error, exit 1" '[ $rc -eq 1 ] && outhas "ERROR: Codex waits for an answer in its Codex tab."'
new; touch "$S/prompt_timeout"; go
check "h2 prompt timeout: error, exit 1, the tab this run made is closed" '[ $rc -eq 1 ] && outhas "ERROR:" && closed'
new; agent_json st-codex-010 "$HERDR_WORKSPACE_ID"; touch "$S/prompt_timeout"; go
check "h3 prompt timeout on a reused tab: no tab close" '[ $rc -eq 1 ] && [ "$(cnt "^tab close")" = 0 ]'

new
printf '%s' $'Print the line ST-ADVISOR-BEGIN-@N@ alone, then the JSON, then the line ST-ADVISOR-END-@N@ alone.\n• ST-ADVISOR-BEGIN-@N@  \n  junk {not json\n• ST-ADVISOR-END-@N@\n• ST-ADVISOR-BEGIN-@N@\n• {"verdict":"APPROVED","summary":  \n  "fine, wrapped","findings":\n  []}   \n• ST-ADVISOR-END-@N@\n' > "$S/screen_prompt"
go
check "i last pair, wrapped JSON joined with single spaces" '[ $rc -eq 0 ] && [ "$(cat "$af")" = "{\"verdict\":\"APPROVED\",\"summary\": \"fine, wrapped\",\"findings\": []}" ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$af"'
new; go
check "i plain answer parses" '[ $rc -eq 0 ] && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$af"'

new; printf 'no markers here\nPrint the line ST-ADVISOR-BEGIN-@N@ alone then ST-ADVISOR-END-@N@ alone\n' > "$S/screen_prompt"; go
check "j no pair: error, exit 1, no answer file" '[ $rc -eq 1 ] && outhas "ERROR: no answer between the markers" && [ ! -s "$af" ]'

new; feat=specs/demo; go
check "k feature dir without digits: error, exit 2" '[ $rc -eq 2 ] && outhas "ERROR: feature dir must start with three digits"'

exit $fail
