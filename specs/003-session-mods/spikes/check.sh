#!/usr/bin/env bash
set -u

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
report="${1:-$root/specs/003-session-mods/research.md}"
quick="${2:-$root/specs/003-session-mods/quickstart.md}"
spk="$root/specs/003-session-mods/spikes"
rc=0

fail() { echo "FAIL R$1: $2"; rc=1; }

sec() {
  awk -v h="### $1" -v f="- $2:" '
    /^### / { s = index($0, h) == 1; next }
    s && index($0, f) == 1 { print substr($0, length(f) + 1); exit }
  ' "$report" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

cell() { sed -e 's/^ *//' -e 's/ *$//' <<< "$1"; }

r1() {
  local n=$1 letter=$2 labels=$3 sct="Test $1"
  local outcome approaches evidence limit ids pass result stops human
  outcome="$(sec "$sct" Outcome)"
  approaches="$(sec "$sct" "Approaches tried")"
  evidence="$(sec "$sct" Evidence)"
  limit="$(sec "$sct" Limit)"
  grep -qxE "$labels" <<< "$outcome" || fail 1 "Test $n Outcome '$outcome' is not $labels"
  ids="$(grep -oE '[ABC][0-9]' <<< "$approaches" | sort -u)"
  if [ -z "$ids" ] || [ "$(wc -l <<< "$ids")" -gt 3 ] || grep -qvxE "$letter[1-3]" <<< "$ids"; then
    fail 1 "Test $n Approaches tried needs 1 to 3 IDs $letter<1-3>"
  fi
  case "$outcome" in pass|'full pass') pass=1 ;; *) pass=0 ;; esac
  [ -n "$evidence" ] || fail 1 "Test $n Evidence empty"
  [ -n "$limit" ] || fail 1 "Test $n Limit empty"
  [ "$pass" = 1 ] && [ "$limit" != none ] && fail 1 "Test $n passes but Limit is not none"
  [ "$pass" = 0 ] && [ "$limit" = none ] && fail 1 "Test $n Limit none without a pass"
  if [ "$n" = 1 ]; then return; fi
  result="$(sec "$sct" "Result back")"
  stops="$(sec "$sct" Stops)"
  human="$(sec "$sct" "Human step")"
  case "$result" in yes|no) ;; *) fail 1 "Test $n Result back '$result' is not yes or no" ;; esac
  case "$stops" in yes|no) ;; *) fail 1 "Test $n Stops '$stops' is not yes or no" ;; esac
  if [ "$result" = yes ] && ! [[ $evidence =~ spk00[3]-t${n}[a-c]-ok ]]; then
    fail 1 "Test $n Result back yes but Evidence lacks spk003-t${n}<a-c>-ok"
  fi
  [ -n "$human" ] || fail 1 "Test $n Human step empty"
  [ "$outcome" = pass ] && [ "$human" != none ] && fail 1 "Test $n pass with Human step not none"
}

r1 1 A 'full pass|partial pass|blocked'
r1 2 B 'pass|blocked'
r1 3 C 'pass|blocked'

for q in 1 2 3 4 5; do
  [ -n "$(sec "Q$q" Answer)" ] || fail 2 "Q$q Answer empty"
  [ -n "$(sec "Q$q" Evidence)" ] || fail 2 "Q$q Evidence empty"
done

r3() {
  local starts=no result_back=no stops=no failed follow n o r s ver
  for n in 2 3; do
    o="$(sec "Test $n" Outcome)"
    r="$(sec "Test $n" "Result back")"
    s="$(sec "Test $n" Stops)"
    if [ "$o" = pass ]; then
      starts=yes
      if [ "$r" = yes ]; then
        result_back=yes
        if [ "$s" = yes ]; then stops=yes; fi
      fi
    fi
  done
  if [ "$stops" = yes ]; then failed=none
  elif [ "$starts" = no ]; then failed=starts
  elif [ "$result_back" = no ]; then failed='result back'
  else failed=stops; fi
  [ "$(sec Verdict Starts)" = "$starts" ] || fail 3 "Verdict Starts is not $starts"
  [ "$(sec Verdict 'Result back')" = "$result_back" ] || fail 3 "Verdict Result back is not $result_back"
  [ "$(sec Verdict Stops)" = "$stops" ] || fail 3 "Verdict Stops is not $stops"
  [ "$(sec Verdict Verdict)" = "$stops" ] || fail 3 "Verdict Verdict is not $stops"
  [ "$(sec Verdict 'Failed part')" = "$failed" ] || fail 3 "Verdict Failed part is not $failed"
  follow="$(sec Verdict 'Follow-up issue')"
  if [ "$stops" = yes ]; then
    [ -n "$follow" ] && [ "$follow" != none ] || fail 3 "Verdict is yes but Follow-up issue is not a title"
  else
    [ "$follow" = none ] || fail 3 "Verdict is no but Follow-up issue is not none"
  fi
  [ -n "$(sec 'Mod vs model' Compare)" ] || fail 3 "Mod vs model Compare empty"
  [ -n "$(sec 'Cloud limit' Limit)" ] || fail 3 "Cloud limit Limit empty"
  [ -n "$(sec 'Cloud limit' Source)" ] || fail 3 "Cloud limit Source empty"
  ver="$(sec 'Claude Code version' Version)"
  [[ $ver =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || fail 3 "Claude Code version '$ver' is not x.y.z"
}
r3

r4() {
  local rows name argv limit started stopped
  rows="$(awk '/^### / { s = index($0, "### Started sessions") == 1; next } s && /^\| / && !/^\| Name \|/' "$report")"
  if [ -z "$rows" ]; then fail 4 "Started sessions has no data row"; return; fi
  while IFS='|' read -r _ name _ _ argv limit started stopped _; do
    name="$(cell "$name")"; argv="$(cell "$argv")"; limit="$(cell "$limit")"
    started="$(cell "$started")"; stopped="$(cell "$stopped")"
    [[ $name == *spk003* ]] || fail 4 "row '$name' does not hold spk003"
    [[ $argv == *haiku* ]] || fail 4 "row '$name' Argv lacks haiku"
    if [[ $limit == *'--max-turns 3'* ]]; then
      [[ $argv == *'--max-turns 3'* ]] || fail 4 "row '$name' Turn limit is --max-turns 3 but Argv lacks it"
    elif [[ $limit == *'no tools'* ]]; then
      [[ $argv == *'--tools ""'* ]] || fail 4 "row '$name' Turn limit is no tools but Argv lacks --tools \"\""
    else
      fail 4 "row '$name' Turn limit '$limit' is neither --max-turns 3 nor no tools"
    fi
    if [[ $argv != *'timeout 300'* ]]; then
      if [[ $started =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ && $stopped =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] \
        && (( $(date -d "$stopped" +%s) - $(date -d "$started" +%s) <= 300 )); then :; else
        fail 4 "row '$name' has no timeout 300 and Stopped minus Started is not 300 s or less"
      fi
    fi
  done <<< "$rows"
}
r4

r5() {
  local n
  if command pgrep -f 'spk00[3]' >/dev/null; then fail 5 "a process matches spk00[3]"; fi
  n="$(claude agents --json 2>/dev/null | jq '[.[] | select((.name // "") | test("spk00[3]"))] | length' 2>/dev/null)"
  [ "$n" = 0 ] || fail 5 "claude agents --json lists '$n' spk003 session(s), expected 0"
  if git -C "$root" worktree list --porcelain | grep -q 'spk00[3]'; then fail 5 "a worktree path matches spk00[3]"; fi
  if git -C "$root" branch --list | grep -q 'spk00[3]'; then fail 5 "a local branch matches spk00[3]"; fi
}
r5

r6() {
  local line p
  while IFS= read -r line; do
    p="${line:3}"
    case "$p" in
      specs/003-session-mods/*|.stratum/state.json|.stratum/commit-mode|brag-output/|skills/st-ui-ux/scripts/__pycache__/) ;;
      *) fail 6 "$p is outside the allowed paths" ;;
    esac
  done < <(git -C "$root" status --porcelain)
}
r6

for f in ListAgents SendMessage 'Over the Agent tool'; do
  [ -n "$(sec 'Test 3' "$f")" ] || fail 7 "Test 3 $f empty"
done

r8() {
  local line hits
  hits="$(grep -HEn '(TOKEN|SECRET|KEY)=[^[:space:]]+' "$report" 2>/dev/null
    find "$spk" -type f ! -name check.sh ! -path '*/.claude-plugin/types/*' -exec grep -HEn '(TOKEN|SECRET|KEY)=[^[:space:]]+' {} + 2>/dev/null)"
  if [ -n "$hits" ]; then fail 8 "a KEY-style assignment with a value at $(cut -d: -f1,2 <<< "$hits" | tr '\n' ' ')"; fi
  while IFS= read -r line; do
    [[ $line == *spk003* || $line == *spike-* ]] || fail 8 "a sessionId row in the report holds neither spk003 nor spike-"
  done < <(grep '"sessionId"' "$report" 2>/dev/null)
}
r8

for h in 'Open the second session' 'Load a mod' 'Hot reload answer' 'Process check'; do
  grep -qF "$h" "$quick" || fail 9 "quickstart has no '$h' heading"
done

[ "$rc" = 0 ] && echo ok
exit "$rc"
