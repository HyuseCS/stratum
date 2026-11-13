#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: st-worker.sh start <id> --task <file> --test <cmd> --lane <text> --roster <file> [--machine <m> --repo <path>] [--model <name>] [--autonomous] [--project <p>] [--env <e>] [--issue <n> [--issue-task]] | goal <id> --test <cmd> [--machine <m>] | resend <id> [--machine <m>] | followup <id> --task <file> --test <cmd> [--machine <m>] | wait <id> [--machine <m>] | answer <id> [--machine <m>] [--screen <hash>] --keys <key>... | --text <text> | result <id> [--machine <m>] | close <id> [--machine <m>] | list [--machine <m>] | headless <id> --task <file> --test <cmd> [--model <name>] | approve <id> --request <rid> --input-hash <hash> --record <file> [--machine <m>] | pass <id> --request <rid> [--machine <m>] | autonomous-on | autonomous-off [--roster <file>] | watch --roster <file>" >&2; exit 2; }
fail() { echo "$1" >&2; exit 1; }
[ $# -gt 0 ] || usage
cmd=$1; shift
case $cmd in
  start | goal | resend | followup | wait | answer | result | close | headless | approve | pass) [ $# -gt 0 ] || usage; id=$1; shift ;;
  list | autonomous-off | watch) ;;
  autonomous-on) [ $# = 0 ] || usage ;;
  *) usage ;;
esac
m= repo= auto= itask=
unset proj envn issue
while [ $# -gt 0 ]; do
  case "$cmd $1" in
    "start --autonomous") auto=1; shift; continue ;;
    "start --issue-task") itask=1; shift; continue ;;
  esac
  [ $# -ge 2 ] || usage
  case "$cmd $1" in
    "start --task" | "followup --task" | "headless --task") task=$2 ;;
    "start --test" | "goal --test" | "followup --test" | "headless --test") test=$2 ;;
    "start --lane") lane=$2 ;;
    "start --roster" | "autonomous-off --roster" | "watch --roster") roster=$2 ;;
    "approve --request" | "pass --request") rid=$2 ;;
    "approve --record") record=$2 ;;
    "approve --input-hash")
      [[ $2 =~ ^[0-9a-f]{64}$ ]] || usage
      ihash=$2
      ;;
    "start --repo") repo=$2 ;;
    "start --project") proj=$2 ;;
    "start --env") envn=$2 ;;
    "start --issue") issue=$2 ;;
    "start --model" | "headless --model")
      [ -z "${model+x}" ] && [ -n "$2" ] || usage
      model=$2
      ;;
    "headless --machine" | "autonomous-off --machine" | "watch --machine") usage ;;
    *" --machine") m=$2 ;;
    "answer --text") text=$2 ;;
    "answer --screen")
      [[ $2 =~ ^[0-9a-f]{12}$ ]] || usage
      scr=$2
      ;;
    "answer --keys")
      keys=("${@:2}")
      break
      ;;
    *) usage ;;
  esac
  shift 2
done
case $cmd in
  start) [ -n "${task+x}" ] && [ -n "${test+x}" ] && [ -n "${lane+x}" ] && [ -n "${roster+x}" ] && { [ -z "$repo" ] || [ -n "$m" ]; } && { [ -z "$itask" ] || [ -n "${issue+x}" ]; } || usage ;;
  goal) [ -n "${test+x}" ] || usage ;;
  headless | followup) [ -n "${task+x}" ] && [ -n "${test+x}" ] || usage ;;
  answer) [ "${text+x}${keys+x}" = x ] || usage ;;
  approve) [ -n "${rid+x}" ] && [ -n "${record+x}" ] && [ -n "${ihash+x}" ] || usage ;;
  pass) [ -n "${rid+x}" ] || usage ;;
  watch) [ -n "${roster+x}" ] || usage ;;
esac
for v in ${text+"$text"} ${keys+"${keys[@]}"}; do [[ $v != -* ]] || { echo 'Answer values must not start with -.' >&2; exit 2; }; done

N=
if [ "$cmd" != list ] && [ "$cmd" != autonomous-off ] && [ "$cmd" != autonomous-on ] && [ "$cmd" != watch ]; then
  [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,24}$ ]] || fail "Task id must be letters, digits or dash, start with a letter or digit, and be at most 25 characters."
  N=worker-${id,,}
fi
if [ "$cmd" = approve ] || [ "$cmd" = pass ] || [ "$cmd" = autonomous-off ] || [ "$cmd" = autonomous-on ] || [ -n "$auto" ]; then
  python3 "$(cd "$(dirname "$0")/.." && pwd)/hooks/st-approve.py" --worker 2>/dev/null && c=0 || c=$?
  [ "$c" = 3 ] || fail "Run this from the orchestrator's checkout, not a worker worktree."
  d=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && MAIN=$(dirname "$d") || MAIN=
  SID=${CLAUDE_CODE_SESSION_ID:-}
  D=$MAIN/.stratum/autonomous
  [ "$cmd" = autonomous-on ] || { [[ $SID =~ ^[A-Za-z0-9-]+$ ]] && { [ "$cmd" = autonomous-off ] || { [ -n "$MAIN" ] && [ -d "$D" ] && [ ! -L "$D" ] && [ -f "$D/$SID" ] && [ ! -L "$D/$SID" ]; }; }; } || fail "Autonomous build mode is off for this session."
fi
if [ "$cmd" = approve ] || [ "$cmd" = pass ]; then
  [[ $rid =~ ^[0-9]+-[0-9]+$ ]] || fail "No request $rid for $N."
fi
if [ "$cmd" = start ] || [ "$cmd" = followup ] || [ "$cmd" = headless ]; then
  [ -f "$task" ] && [ -s "$task" ] || fail "Task file not found or empty: $task"
fi
if [ "$cmd" = start ] || [ "$cmd" = goal ] || [ "$cmd" = followup ] || [ "$cmd" = headless ]; then
  [[ -n $test && $test != *$'\n'* && $test != *[\(\)]* ]] || fail "Test command must be one line with no ( or )."
fi
[ "$cmd" != headless ] || [[ $test != *\** ]] || fail "Test command must not contain * for headless."
# ponytail: the token rule does not check git ref rules (a part ending in "." or ".lock"), git refuses those at worktree add before anything is made, check with git check-ref-format if a refusal confuses users
for v in ${proj+"$proj"} ${envn+"$envn"} ${issue+"$issue"}; do [[ ${v,,} =~ ^[a-z0-9][a-z0-9._-]*$ && $v != *..* ]] || fail "Name part $v must be letters, digits, dot, underscore or dash, start with a letter or digit, and have no \"..\"."; done
if [ "$cmd" = start ] || [ "$cmd" = headless ]; then
  [ -n "${model+x}" ] || { top=$(git rev-parse --show-toplevel 2>/dev/null) && model=$(jq -r '."st-worker".model // empty' "$top/.stratum/models.json" 2>/dev/null); } || model=
  [ -z "$model" ] || [[ $model =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "Model must be one token of letters, digits, dot, underscore or dash, starting with a letter or digit."
fi
if [ "$cmd" = start ]; then
  [[ -n $lane && $lane != *$'\n'* ]] || fail "Lane must be one line."
  [ -f "$roster" ] || fail "Roster has no line for $N."
  R=() n=0 own= orepo= obr=
  while IFS= read -r l || [ -n "$l" ]; do
    n=$((n + 1))
    [ -n "$l" ] || continue
    t=${l//[!$'\t']/}
    IFS=$'\t' read -r -a f <<<"$l"
    { { [ ${#t} = 3 ] && [ ${#f[@]} = 4 ]; } || { [ ${#t} = 4 ] && [ ${#f[@]} = 5 ]; }; } && [[ ${f[0]} == worker-* ]] || fail "Roster line $n must be: name, machine, branch, task, split by TAB."
    [ "${f[0]}" != "$N" ] || { own=1; orepo=${f[4]:-}; obr=${f[2]}; }
    R+=("${f[@]:0:4}")
  done <"$roster"
  [ -n "$own" ] || fail "Roster has no line for $N."
  [ -z "$auto" ] || [ -z "$m" ] || [ "$orepo" = "$repo" ] || fail "Roster row for $N needs the repo path as a fifth field."
fi
goalp() {
  P="/goal \`$test\` exits 0, the change is committed on branch $1, and result.md is written; read brief.md in this folder first and follow it"
  [ ${#P} -le 4000 ] || fail "The /goal prompt is over 4000 characters."
}
[ "$cmd" = headless ] || [ "$cmd" = autonomous-off ] || [ "$cmd" = autonomous-on ] || [ -n "$m" ] || { [ "${HERDR_ENV:-}" = 1 ] && { [ "$cmd" != start ] || [ -n "${HERDR_WORKSPACE_ID:-}" ]; }; } || fail "Not inside a herdr pane. Run it from a herdr pane, or name a --machine."
[ "$cmd" != start ] || [ -z "$m" ] || [[ $repo == [/~]* ]] || fail "A saved machine needs --repo <path> starting with / or ~."

H=(herdr)
WS= TAB= PANE= BR= WT= S= Q=
e=$(mktemp)
t=$(mktemp)
exec 4>&1
trap 'rm -f "$e" "$t"' EXIT
if [ -n "$m" ]; then
  ms=$(herdr machine list --json 2>"$e") || { msg=$(head -1 "$e"); fail "${msg:-herdr machine list failed.}"; }
  target=$(jq -r --arg m "$m" 'first(.[] | select(.label == $m or .id == $m) | .target) // empty' <<<"$ms" 2>/dev/null) || fail "herdr machine list gave no machine list."
  [ -n "$target" ] || fail "Unknown machine: $m. Saved: $(jq -r 'map(.label) | join(", ")' <<<"$ms")."
  H+=(--machine "$m")
  "${H[@]}" workspace list >/dev/null 2>"$e" || fail "Machine $m does not answer: $(head -1 "$e")"
fi

worker() { printf 'worker\t%s\t%s\t%s\t%s\t%s\t%s\n' "$N" "${m:-local}" "${TAB:--}" "${PANE:--}" "${BR:--}" "${WT:--}"; }
stop() {
  echo "stopped: $1"
  [ "$cmd" != start ] || worker
  exit 1
}
h() { r=$("${H[@]}" "$@" 2>"$e") || stop "$(head -1 "$e")"; }
sshq() { ssh -o BatchMode=yes -- "$target" "$*" 2>"$e"; }
rsh() {
  sshq "$@" && return
  local c=$?
  [ $c != 255 ] || stop "ssh to $target failed: $(head -1 "$e")" >&4
  return $c
}
rx() { if [ -n "$m" ]; then rsh "$1"; else bash -c "$1" 2>"$e"; fi; }
quote() {
  Q=$(printf %q "$1")
  Q=${Q/#\\~/\~}
}
get() { local v; v=$(jq -er "$2" <<<"$r") || stop "no $2 in the herdr answer"; printf -v "$1" %s "$v"; }
code() { jq -r '.error.code // empty' "$e" 2>/dev/null || true; }
look() {
  h agent get "$N"
  get S .result.agent.agent_status
  get PANE .result.agent.pane_id
}
panetext() {
  echo 'pane text:'
  "${H[@]}" agent read "$N" --source recent-unwrapped --lines 40 2>/dev/null || true
}
st() {
  printf 'state\t%s\t%s\t%s\n' "$1" "$N" "$PANE"
  case $1 in
    blocked)
      local d
      if [ -n "$m" ]; then d=$Q/.stratum/approve/dropped; sshq "[ -f $d ] && [ ! -L $d ] && head -c 4096 -- $d | head -n 1" >"$t"; else d=$WT/.stratum/approve/dropped; [ -f "$d" ] && [ ! -L "$d" ] && head -c 4096 -- "$d" | head -n 1 >"$t"; fi && { DL=$(LC_ALL=C tr -cd '[:print:]\t' <"$t"); printf 'dropped\t%s\n' "${DL:0:400}"; }
      ! screen || ! perm || { block; [ -z "$BM" ] || printf 'screen\t%s\n' "$SH"; }
      echo 'pane text:'
      [ -z "$SC" ] || printf '%s\n' "$SC"
      ;;
    stopped | unsent) panetext ;;
  esac
}
HEAD='^([[:space:]]|│)*Do you want to (proceed|make this edit|create|allow|run)'
PERM="$HEAD|don.t ask again|tell Claude what to do differently"
screen() { SC=$("${H[@]}" agent read "$N" --source recent-unwrapped --lines 40 2>/dev/null | sed $'s/\e\\[[0-9;]*[A-Za-z]//g') || return; }
perm() { tail -n 15 <<<"$SC" | grep -qaE "$PERM"; }
block() {
  local n w en tr
  BM= SH=
  n=$(wc -l <<<"$SC")
  w=$((n > 15 ? n - 14 : 1))
  HD=$(tail -n "+$w" <<<"$SC" | grep -naE "$HEAD" | cut -d: -f1) || :
  [[ $HD =~ ^[0-9]+$ ]] || return 0
  HD=$((HD + w - 1))
  en=$(tail -n "+$((HD + 1))" <<<"$SC" | grep -naE '^([[:space:]]|│)*(❯[[:space:]]*)?[0-9]+\.[[:space:]]' | tail -n 1 | cut -d: -f1) || :
  [ -n "$en" ] || return 0
  en=$((en + HD))
  while [ "$en" -lt "$n" ] && sed -n "$((en + 1))p" <<<"$SC" | grep -qav '^[[:space:]]*$'; do en=$((en + 1)); done
  tr=$(head -n "$((HD - 1))" <<<"$SC" | grep -naE '^(─)+[[:space:]]*$' | tail -n 1 | cut -d: -f1) || :
  if [ -n "$tr" ]; then BM=block SH=$(sed -n "$tr,${en}p" <<<"$SC" | sha256sum); else BM=cut SH=$(sha256sum <<<"$SC"); fi
  SH=${SH:0:12}
}
live() { awk -v n="$1" 'NR > n && /^([[:space:]]|│)*❯/ && !/^([[:space:]]|│)*❯[[:space:]]*[0-9]+\.[[:space:]]/ { f = 1 } END { exit f }' <<<"$2"; }
readpane() { "${H[@]}" agent read "$N" --source visible >"$t" 2>/dev/null; }
unsent() { readpane && grep -a '^❯' "$t" | tail -n 1 | grep -qaE '^❯.{0,2}/goal '; }
question() { readpane && ! grep -qaE "$PERM" "$t" && { grep -qa 'Enter to select' "$t" || { grep -qa 'Ready to submit your answers?' "$t" && grep -qaE '^([[:space:]]|❯)*1\. Submit answers[[:space:]]*$' "$t"; }; } && live "$(grep -naE 'Enter to select|Ready to submit your answers' "$t" | tail -n 1 | cut -d: -f1)" "$(<"$t")"; }
shown() {
  BM= SH=
  if screen && perm; then
    block
    [ -n "$BM" ] && live "$HD" "$SC"
  else
    question
  fi
}
push() {
  [ -n "$PANE" ] || look
  h pane send-keys "$PANE" enter
  "${H[@]}" agent wait "$N" --until working --until blocked --timeout 10000 >/dev/null 2>&1 || true # ponytail: fixed 10 s for a resent prompt to leave the input box, raise it if a live run measures a slower start
  ! unsent
}
noresult() {
  echo "no result file: $WT/result.md"
  panetext
  exit 1
}
find_worker() {
  h tab list
  local c C
  c=$(jq -er --arg n "$N" '[.result.tabs[] | select(.label == $n)] | length' <<<"$r") || stop "no .result.tabs in the herdr answer"
  [ "$c" != 0 ] || fail "No worker $N on ${m:-local}."
  [ "$c" = 1 ] || fail "More than one tab is labelled $N."
  TAB=$(jq -er --arg n "$N" 'first(.result.tabs[] | select(.label == $n) | .tab_id)' <<<"$r") && WS=$(jq -er --arg n "$N" 'first(.result.tabs[] | select(.label == $n) | .workspace_id)' <<<"$r") || fail "No worker $N on ${m:-local}."
  h pane list --workspace "$WS" # ponytail: only the first pane's cwd is used, a cd in a stopped worker's pane breaks the find, upgrade by falling back to <repo parent>/<repo name>-N
  C=$(jq -er --arg t "$TAB" 'first(.result.panes[] | select(.tab_id == $t) | .cwd)' <<<"$r") || fail "No worker $N on ${m:-local}."
  h worktree list --cwd "$C"
  pick "$C"
  [ -n "$WT" ] && [ -n "$BR" ] || fail "No worker $N on ${m:-local}."
  quote "$WT"
}
pick() {
  WT= BR=
  BR=$(jq -er --arg c "$1" 'first(.result.worktrees[] | select(.path == $c and .is_linked_worktree == true) | .branch)' <<<"$r" 2>/dev/null) && WT=$1 || BR=
  if [ -n "$WT" ]; then
    quote "$WT/.stratum/worker"
    rx "[ -f $Q ] && [ ! -L $Q ] && head -n 1 -- $Q" >"$t" && [ "worker-$(head -n 1 "$t")" = "$N" ] || WT= BR=
  fi
  [ -n "$WT" ] || { WT=$(jq -er --arg n "$N" 'first(.result.worktrees[] | select(.branch == $n) | .path)' <<<"$r" 2>/dev/null) && BR=$N; } || WT=
}
ownbr() {
  local g
  rx "[ -f $Q/.stratum/git-guard.json ] && [ ! -L $Q/.stratum/git-guard.json ] && cat -- $Q/.stratum/git-guard.json" >"$t" || :
  g=$(jq -r '.branch | strings' "$t" 2>/dev/null) || g=
  [ -n "$g" ] || fail "Worker $N has no branch in .stratum/git-guard.json. $1 refused."
  [ "$g" = "$BR" ] || fail "Worker $N is on branch $BR, not its branch $g. $1 refused."
}
render() { python3 "$(cd "$(dirname "$0")/.." && pwd)/hooks/st-approve.py" --render "$1"; }
owns() { awk 'f && (/^[[:space:]]*$/ || /^[[:space:]]*- \[/) { exit } !f && /Owns:/ { f = 1; sub(/.*Owns:/, "") } f { if (sub(/Test:.*/, "")) { print; exit } print }' "$task" | grep -o '`[^`]*`' | tr -d '`' || true; }
chkowns() {
  local p d
  mapfile -t O < <(owns)
  [ ${#O[@]} != 0 ] || fail "The task has no Owns: paths. Autonomous mode needs them."
  for p in "${O[@]}"; do
    [[ $p != *[*?[]* && $p != /* && $p != \~* && $p != ./* && /$p/ != */../* ]] || fail "Owns path $p must be repo-relative, with no glob."
    d=$(dirname -- "$p")
    [ "$d" = . ] || git cat-file -e "$sha:$d" 2>/dev/null || fail "Owns path $p: folder $d is not in the base commit."
  done
}
reqid() {
  if [ -n "$m" ]; then rsh "ls -1 $Q/.stratum/approve" >"$t" || return 1; else ls -1 "$WT/.stratum/approve/" >"$t" 2>/dev/null || return 1; fi
  rq=$(grep -m1 -xE '[0-9]+-[0-9]+\.req' "$t")
}
approval() {
  local f=$WT/.stratum/approve/ in s
  reqid || return 0
  if [ -n "$m" ]; then rsh "cat -- $Q/.stratum/approve/$rq" >"$t" || return 0; f=$t; else f=$f$rq; fi
  in=$(render "$f") || return 0
  s=$(sha256sum <<<"$in")
  printf 'state\tapproval\t%s\t%s\nrequest\t%s\ntab\ttab %s\ninput\t%s\ninputhash\t%s\n' "$N" "$PANE" "${rq%.req}" "$N" "$in" "${s:0:64}"
  jq -r '(.branch | strings | "branch\t\(gsub("[[:cntrl:]]"; "?"))"), (.staged | arrays | "staged\t\(map(tostring | gsub("[[:cntrl:]]"; "?")) | join(" "))")' "$f" 2>/dev/null || true
  panetext
  exit 6
}
prompt() {
  "${H[@]}" agent prompt "$N" "$P" --wait --until working --until blocked --timeout 30000 >/dev/null 2>"$e" && return
  if [ "$(code)" != agent_blocked ]; then
    unsent || stop "$(head -1 "$e")"
    push && return
    [ "$cmd" != start ] || worker
    look
    st unsent
    exit 7
  fi
  if [ "$cmd" = start ]; then worker; else look; fi
  st blocked
  exit 4
}
brief() {
  printf '%s\n\n' "# Brief: $N" "You are worker $N, started by the Stratum orchestrator. Read this file first and follow it." "## Task $id"
  cat -- "$task"
  printf '\n%s\n\n' '## Facts'
  printf '%s\n' "- Test command: \`$test\`" '- Test lock: if your task is marked [lock], run its test command as `bash <plugin root>/scripts/st-lock.sh -- <test command>`, with the plugin root of the Stratum plugin. Never write a wait loop of your own.' "- Lane: $lane. If it names a skill, start it with the Skill tool. Run only task $id; skip every other task, ticked or not." "- Branch: $BR" "- Model: ${model:-default}"
  [ -n "$m" ] || printf '%s\n' "- Plugin root: $(cd "$(dirname "$0")/.." && pwd)"
  printf '%s\n' "- Your machine: ${m:-local}. \`local\` is the orchestrator's machine." "- Result file: $WT/result.md"
  printf '\n%s\n\n%s\n%s\n' '## Roster' '| Name | Machine | Branch | Task |' '|------|---------|--------|------|'
  printf '| %s | %s | %s | %s |\n' "${R[@]}"
  printf '\n%s\n\n' '## Team rules'
  printf '%s\n' \
    '1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md, .stratum/git-guard.json, .stratum/worker or .stratum/approve/, and never write in .stratum/approve/.' \
    "2. Before you build on a teammate's work, merge its branch: \`git log <branch>\`, \`git merge <branch>\`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work." \
    '3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.' \
    "4. Never merge into the base branch and never push. Merging a teammate's branch into your own (rule 2) is fine. When your task says to run /stratum:st-pr, run it: it pushes your branch and opens the PR, and that is the only push allowed. The orchestrator reviews every branch and is the only one who merges into the base." \
    '5. Commit from the worktree root with `git add <path> <path> && git commit -m '"'"'<subject>'"'"' -m '"'"'<body>'"'"'`. Use no `cd`, no `git -C`, no pipe, no shell variable, no `$(...)`, no heredoc and no `-F` file: the orchestrator approves only this form. Give this rule word for word to the st-git agent.'
  printf '\n%s\n\n%s\n%s\n' '## Questions' 'Ask a question only with the AskUserQuestion tool, then wait for the answer. Do not ask in plain text and do not guess.' 'Do not edit tasks.md or .stratum/state.json. The orchestrator ticks the task after the merge.'
  printf '\n%s\n\n%s\n' '## When done' 'Write the result file with four lines:'
  printf '%s\n' 'Built: <what you built>' 'Tests: <test command> exit <code>' 'Commit: <sha>' 'Open: <open points, or none>'
  [ -n "$m" ] || [ ! -f "$(dirname "$0")/st-advisor.sh" ] || printf '\n%s\n\n%s\n' '## Advisor' 'The Codex advisor is installed (`scripts/st-advisor.sh` in the Stratum plugin). At each advisor point your lane names, run it and follow its verdict.'
}

case $cmd in
start)
  top=$(git rev-parse --show-toplevel 2>/dev/null) && sha=$(git rev-parse HEAD 2>/dev/null) || fail "Run start inside a git repo with a commit."
  [ -n "$m" ] || repo=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  W=$(grep -m1 -E '^#{1,6}[[:space:]]' -- "$task" | LC_ALL=C.UTF-8 sed -E 's/^[#[:space:]]+//; s/[*`[:cntrl:]]//g; s/[[:space:]#]+$//; s/^(.{30}).*/\1/; s/[[:space:]]+$//' || true) # ponytail: task words cut at a fixed 30 characters, make the length an option if users ask for longer workspace names
  pj=${proj:-$(basename "$repo")}
  pj=${pj,,}
  [[ $pj =~ ^[a-z0-9][a-z0-9._-]*$ && $pj != *..* ]] || fail "The repo folder name $pj is not a safe name part. Pass --project <name>."
  if [ -n "${issue+x}" ]; then F=${issue,,}${itask:+_${id,,}}; elif [ -n "$W" ]; then F=$(LC_ALL=C sed -E 's/[^a-z0-9]+/_/g' <<<"${W,,}"); else F=${id,,}; fi
  B=$pj${envn:+-${envn,,}}-$F
  [ "$obr" = "$B" ] || fail "Roster row for $N must name branch $B."
  G=$(jq -c --arg b "$B" '.commit="auto" | .branch=$b' <(cat "$top/.stratum/git-guard.json" 2>/dev/null || echo '{}')) || stop "cannot read $top/.stratum/git-guard.json"
  [ -n "$G" ] || G=$(jq -nc --arg b "$B" '{commit:"auto",branch:$b}')
  [ -z "$auto" ] || chkowns
  goalp "$B"
  h tab list
  c=$(jq -er --arg n "$N" '[.result.tabs[] | select(.label == $n)] | length' <<<"$r") || stop "no .result.tabs in the herdr answer"
  [ "$c" = 0 ] || fail "A worker $N already exists."
  if [[ $repo == \~* ]]; then
    quote "$repo"
    rsh "cd $Q && pwd" >"$t" || stop "$(head -1 "$e")"
    repo=$(<"$t")
    [[ $repo == /* && $repo != *$'\n'* ]] || stop "no absolute path for --repo on $m"
  fi
  path="$(dirname "$repo")/$B"
  L=
  [ "${HERDR_ENV:-}" != 1 ] || [ -z "${HERDR_WORKSPACE_ID:-}" ] || L=$(herdr workspace list 2>/dev/null | jq -r --arg w "$HERDR_WORKSPACE_ID" 'first(.result.workspaces[] | select(.workspace_id == $w) | .label | strings) // empty' 2>/dev/null) || L=
  [ -n "$L" ] || L=$(basename "$repo")
  L="$L / $id${W:+: $W}"
  if [ -n "$auto" ] && [ -n "$m" ]; then
    quote "$repo"
    sshq "[ ! -L $Q/.stratum ] || { echo \"$Q/.stratum is a symlink\" >&2; exit 3; }; [ ! -L $Q/.stratum/autonomous ] || { echo \"$Q/.stratum/autonomous is a symlink\" >&2; exit 3; }; [ ! -f $Q/.stratum/autonomous ] || rm -f -- $Q/.stratum/autonomous || :; mkdir -p $Q/.stratum/autonomous 2>/dev/null; [ -d $Q/.stratum/autonomous ] || { echo \"$Q/.stratum/autonomous is not a folder\" >&2; exit 3; }; [ ! -L $Q/.stratum/autonomous/$SID ] || { echo \"$Q/.stratum/autonomous/$SID is a symlink\" >&2; exit 3; }; [ -f $Q/.stratum/autonomous/$SID ] || : > $Q/.stratum/autonomous/$SID" </dev/null || { rc=$? msg=$(head -1 "$e"); fail "cannot write .stratum/autonomous on $m: ${msg:-exit $rc}"; }
  fi
  quote "$repo"
  qr=$Q
  quote "$path"
  qp=$Q
  rx "[ ! -e $qp ] || { echo \"$qp already exists\" >&2; exit 1; }; git -C $qr worktree add -q -b $B $qp $sha || exit 1" || stop "$(head -1 "$e")"
  BR=$B WT=$path need=
  if ! r=$("${H[@]}" workspace create --cwd "$path" --label "$L" --no-focus 2>"$e") || ! {
    need=.result.workspace.workspace_id && WS=$(jq -er "$need // empty" <<<"$r") &&
    need=.result.tab.tab_id && TAB=$(jq -er "$need // empty" <<<"$r") &&
    need=.result.root_pane.pane_id && PANE=$(jq -er "$need // empty" <<<"$r") &&
    need= && "${H[@]}" tab rename "$TAB" "$N" >/dev/null 2>"$e"
  }; then
    msg=$(head -1 "$e")
    [ -z "$need" ] || msg="no $need in the herdr answer"
    [ -z "$WS" ] || "${H[@]}" workspace close "$WS" >/dev/null 2>&1 || true
    TAB= PANE=
    rx "git -C $qr worktree remove $qp && git -C $qr branch -D $B >/dev/null" || stop "$msg; left $path and branch $B"
    BR= WT=
    stop "$msg"
  fi
  if [ -z "$m" ]; then
    [ ! -L "$WT/.stratum" ] || stop "$WT/.stratum is a symlink"
    for p in "$WT/brief.md" "$WT/result.md" "$WT/.stratum/git-guard.json" "$WT/.stratum/worker" ${auto:+"$WT/.stratum/approve"}; do [ ! -L "$p" ] || stop "$p is a symlink"; [ ! -e "$p" ] || stop "$p already exists"; done
    brief >"$WT/brief.md" || stop "cannot write $WT/brief.md"
    mkdir -p "$WT/.stratum" || stop "cannot make $WT/.stratum"
    printf '%s\n' "$G" >"$WT/.stratum/git-guard.json" || stop "cannot write the commit guard file in $WT/.stratum"
    printf '%s\n' "${id,,}" > "$WT/.stratum/worker" || stop "cannot write $WT/.stratum/worker"
    [ -z "$auto" ] || { mkdir "$WT/.stratum/approve" && owns >"$WT/.stratum/approve/owns" && printf '%s\n' "$SID" >"$WT/.stratum/approve/session"; } || stop "cannot write $WT/.stratum/approve"
  else
    quote "$WT"
    A=
    if [ -n "$auto" ]; then
      mapfile -t O < <(owns)
      A=": >"
      [ ${#O[@]} = 0 ] || A="printf '%s\n'$(printf ' %q' "${O[@]}") >"
      A=" && mkdir $Q/.stratum/approve && $A $Q/.stratum/approve/owns && printf '%s\n' $(printf %q "$SID") > $Q/.stratum/approve/session"
    fi
    qw=$Q
    quote "$repo"
    qr=$Q
    Q=$qw
    U=" && { [ ! -f $qr/.stratum/worker-setup.sh ] || { echo 'setup output:' && cd $Q && bash $qr/.stratum/worker-setup.sh $qr 2>&1 || { echo \"worker-setup.sh exited \$? on $m\" >&2; exit 4; }; }; }"
    rsh "[ ! -L $Q/.stratum ] || { echo \"$Q/.stratum is a symlink\" >&2; exit 3; }; for p in $Q/brief.md $Q/result.md $Q/.stratum/git-guard.json $Q/.stratum/worker${auto:+ $Q/.stratum/approve}; do [ ! -L \"\$p\" ] || { echo \"\$p is a symlink\" >&2; exit 3; }; [ ! -e \"\$p\" ] || { echo \"\$p already exists\" >&2; exit 3; }; done && cat > $Q/brief.md && mkdir -p $Q/.stratum && printf '%s\n' $(printf %q "$G") > $Q/.stratum/git-guard.json && printf '%s\n' ${id,,} > $Q/.stratum/worker$A$U" < <(brief) || { rc=$? msg=$(head -1 "$e"); [ "$rc" != 4 ] || stop "$msg"; stop "cannot write brief.md and .stratum/git-guard.json in $WT on $m: ${msg:-exit $rc}"; }
  fi
  [ -n "$m" ] || [ ! -f "$repo/.stratum/worker-setup.sh" ] || { echo 'setup output:' && (cd "$WT" && bash "$repo/.stratum/worker-setup.sh" "$repo" 2>&1); } || stop "worker-setup.sh exited $?"
  h pane split "$PANE" --direction right --cwd "$WT" --no-focus
  get p .result.pane.pane_id
  h pane run "$p" lazygit
  busy=10 # ponytail: fixed 10 s agent_pane_busy retry bound, same shape as D20 in specs/007-herdr-workspace, raise it if a live run measures a slower pane shell
  for ((i = 1; ; i++)); do
    "${H[@]}" agent start "$N" --kind claude --pane "$PANE" --timeout 120000 -- --permission-mode auto -n "$N" ${model:+--model "$model"} >/dev/null 2>"$e" && break
    c=$(code)
    if [ "$c" = agent_pane_busy ] && [ "$i" -lt "$busy" ]; then
      sleep 1
      continue
    fi
    [ "$c" = agent_not_ready ] || stop "$(head -1 "$e")"
    worker
    st blocked
    exit 4
  done
  prompt
  look
  worker
  [ "$S" = blocked ] || S=working
  st "$S"
  [ "$S" != blocked ] || exit 4
  ;;
goal)
  find_worker
  goalp "$BR"
  ! unsent || fail "The /goal prompt is still in the input box of $N. Run resend."
  prompt
  look
  [ "$S" = blocked ] || S=working
  st "$S"
  [ "$S" != blocked ] || exit 4
  ;;
resend)
  look
  unsent || fail "No unsent prompt in $N: $S"
  push || { st unsent; exit 7; }
  look
  [ "$S" = blocked ] || S=working
  st "$S"
  [ "$S" != blocked ] || exit 4
  ;;
followup)
  find_worker
  goalp "$BR"
  look
  case $S in idle | done) ;; *) fail "Worker $N is $S, not finished. Followup refused." ;; esac
  ! question || fail "Worker $N has an open question. Answer it first."
  rx "[ -f $Q/result.md ]" || fail "Worker $N has no result.md, not finished. Followup refused."
  O=()
  if rx "[ -d $Q/.stratum/approve ]"; then
    [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ "$(rx "head -n 1 -- $Q/.stratum/approve/session")" = "$CLAUDE_CODE_SESSION_ID" ] || fail "Worker $N is not in this autonomous run."
    sha=$(git rev-parse -q --verify "refs/heads/$BR" || git rev-parse HEAD)
    chkowns
  fi
  r=$(($(rx "ls -A -- $Q" | grep -c '^result-round[0-9]*\.md$' || :) + 2))
  {
    printf '## Round %s\n\n%s\n\n' "$r" "Round $r: do this task now. The rest of this brief still applies. Write result.md again when done."
    cat -- "$task"
    printf '\n'
  } | rx "[ ! -L $Q/brief.md ] && [ ! -L $Q/result.md ] && [ ! -e $Q/brief.new ] && [ ! -e $Q/result-round$((r - 1)).md ] && mv -- $Q/result.md $Q/result-round$((r - 1)).md && { cat; cat -- $Q/brief.md; } >$Q/brief.new && mv -- $Q/brief.new $Q/brief.md" || stop "cannot write the round $r brief in $WT"
  [ ${#O[@]} = 0 ] || printf '%s\n' "${O[@]}" | rx "[ ! -L $Q/.stratum/approve/owns ] && cat >>$Q/.stratum/approve/owns" || stop "cannot add the Owns paths to $WT/.stratum/approve/owns"
  printf 'round\t%s\t%s\n' "$N" "$r"
  prompt
  look
  [ "$S" = blocked ] || S=working
  st "$S"
  [ "$S" != blocked ] || exit 4
  ;;
wait)
  find_worker
  bound=540 # ponytail: fixed 540 s bound to stay under the Bash tool's 600 s cap, raise it if the cap moves
  resume=10000 # ponytail: fixed 10 s resume check between goal turns, raise it if quickstart section 2 measures a longer idle gap
  slice=10000 # ponytail: fixed 10 s slice between screen reads of a working worker, raise it if the extra reads cost too much
  sl=0
  end=$((SECONDS + bound))
  while :; do
    left=$(((end - SECONDS) * 1000))
    if [ "$left" -le 0 ] || [ "$sl" -ge 54 ]; then
      look
      st working
      exit 3
    fi
    if ! "${H[@]}" agent wait "$N" --timeout "$((left < slice ? left : slice))" >/dev/null 2>"$e"; then
      [ "$(code)" = timeout ] || stop "$(head -1 "$e")"
      sl=$((sl + 1))
    fi
    look
    [ "$S" != working ] || ! shown || S=blocked
    case $S in
      blocked)
        approval
        st blocked
        exit 4
        ;;
      idle | done)
        if question; then
          st blocked
          exit 4
        fi
        if { [ -z "$m" ] && [ -f "$WT/result.md" ]; } || { [ -n "$m" ] && rsh test -f "$Q/result.md"; }; then
          st finished
          exit 0
        fi
        if unsent; then
          st unsent
          exit 7
        fi
        "${H[@]}" agent wait "$N" --until working --until blocked --timeout "$resume" >/dev/null 2>&1 || {
          st stopped
          exit 5
        }
        ;;
    esac
  done
  ;;
answer)
  look
  q= dlg=
  ! question || q=1
  [ -n "$q" ] || [ "$S" = blocked ] || { [ "$S" = working ] && shown && [ -n "$BM" ] && dlg=1; } || fail "not blocked: $S"
  p="This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it."
  [ -n "$dlg" ] || screen || fail "$p"
  if perm; then
    [ -n "${keys+x}" ] || fail "$p"
    [ -n "${scr+x}" ] || fail "A permission prompt needs --screen <hash> from the screen line of wait or watch. Nothing sent."
    block
    [ -n "$BM" ] && [ "$SH" = "$scr" ] || fail "The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt."
    [ ${#keys[@]} = 1 ] && [[ ${keys[0]} =~ ^[1-9]$ ]] || fail "A permission prompt takes one option number. Nothing sent."
    k=${keys[0]}
    w=$(tail -n 15 <<<"$SC")
    n=$(sed -nE "/$HEAD/=" <<<"$w" | tail -n 1)
    o="^([[:space:]]|│)*(❯[[:space:]]*)?$k\.[[:space:]]"
    y=
    [ -n "$n" ] && [ "$(sed -nE "/$HEAD/=" <<<"$w" | wc -l)" -eq 1 ] && b=$(tail -n "+$((n + 1))" <<<"$w") && [ "$(grep -caE "$o" <<<"$b")" -eq 1 ] && l=$(grep -naE "$o" <<<"$b") && {
      { grep -qaE "^([[:space:]]|│)*(❯[[:space:]]*)?$k\. (Yes|Yes, proceed|Yes, just this once)( \([a-z0-9]\))?[[:space:]]*\$" <<<"${l#*:}" && y=1; } ||
        { grep -qaE "^([[:space:]]|│)*(❯[[:space:]]*)?$k\. No([,[:space:]].*)?\$" <<<"${l#*:}" && ! grep -qaiE "don'?t ask|always|this session|in the future|[a-z0-9-]\.[a-z]{2,}" <<<"${l#*:}"; }
    } && ! sed -n "$((${l%%:*} + 1))p" <<<"$b" | grep -qavE '^[[:space:]]*$|^([[:space:]]|│)*(❯[[:space:]]*)?[0-9]+\.[[:space:]]' || fail "Option $k is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt."
    [ "$BM" = block ] || [ -z "$y" ] || fail "The top of the dialog is not on the screen, so only its No can be sent. Nothing sent. Tell the user the workspace, the tab and the prompt."
  fi
  if [ -n "${keys+x}" ]; then
    h agent send-keys "$N" "${keys[@]}"
  else
    if [ -n "$q" ]; then
      readpane || fail "Cannot read the pane of $N."
      k=$(sed -nE 's/^[^0-9]*([0-9]+)\. Type something\.[[:space:]]*$/\1/p' "$t" | tail -n 1)
      [ -n "$k" ] || fail "The question has no \"Type something.\" option. Answer with --keys."
      h agent send-keys "$N" "$k"
    fi
    h pane send-text "$PANE" "$text"
    h pane send-keys "$PANE" enter
  fi
  settle=5000 # ponytail: fixed 5 s wait for blocked to clear after an answer (live T008 saw about 2 s), raise it if a live run measures a longer lag
  "${H[@]}" agent wait "$N" --until working --timeout "$settle" >/dev/null 2>&1 || true
  look
  [ -z "$dlg" ] || { sleep 2; ! shown || S=blocked; } # ponytail: fixed 2 s for a dialog to close after a key, raise it if a live run needs longer
  [ "$S" = blocked ] || S=working
  printf 'state\t%s\t%s\t%s\n' "$S" "$N" "$PANE"
  [ "$S" != blocked ] || exit 4
  ;;
result)
  find_worker
  if [ -z "$m" ]; then
    [ -f "$WT/result.md" ] || noresult
    printf 'result\t%s\t%s/result.md\n' "$N" "$WT"
    cat -- "$WT/result.md"
    exit 0
  fi
  ownbr Result
  rsh cat -- "$Q/result.md" >"$t" || noresult
  printf 'result\t%s\t%s/result.md\n' "$N" "$WT"
  cat -- "$t"
  GIT_SSH_COMMAND='ssh -o BatchMode=yes' git fetch -- "$target:$WT" "$BR:$BR" >/dev/null 2>"$e" || stop "$(head -1 "$e")"
  f=$(git rev-parse --verify "$BR" 2>"$e") || stop "$(head -1 "$e")"
  printf 'fetched\t%s\t%s\n' "$N" "$f"
  ;;
close)
  find_worker
  ownbr Close
  if r=$("${H[@]}" agent get "$N" 2>"$e"); then
    S=$(jq -er '.result.agent.agent_status' <<<"$r" 2>/dev/null) || fail "Worker $N: cannot read worker state. Close refused."
    case $S in working | blocked) fail "Worker $N is $S. Close refused." ;; esac
  else
    [ "$(code)" = agent_not_found ] || fail "Worker $N: cannot read worker state. Close refused."
  fi
  # ponytail: GitHub remote found by "github" in a remote URL, use gh's host list if a GitHub Enterprise host lacks the word
  if git remote -v 2>/dev/null | grep -q github; then
    p=$(gh pr list --head "$BR" --state open --json number -q length 2>/dev/null) || fail "Worker $N: cannot read its PRs. Close refused."
    [ "$p" = 0 ] || fail "Worker $N has an open PR. Close refused."
  fi
  rx "[ ! -L $Q/.stratum ]" || fail "Worker $N: .stratum is a symlink. Close refused."
  h agent list
  k=st-codex-$N
  k=$(jq -er --arg n "${k:0:32}" --arg w "$WS" '.result.agents | arrays | first(.[] | select(.name == $n and .workspace_id == $w) | .tab_id | strings) // ""' <<<"$r" 2>/dev/null) || stop "no .result.agents in the herdr answer"
  h tab list --workspace "$WS"
  c=0
  jq -e --arg n "$N" --arg k "$k" 'any(.result.tabs[]; .label == $n) and all(.result.tabs[]; .label == $n or .tab_id == $k)' <<<"$r" >/dev/null 2>&1 || c=$?
  [ $c -le 1 ] || stop "no .result.tabs in the herdr answer"
  if [ $c = 0 ] && { [ -n "$m" ] || { [ -n "${HERDR_WORKSPACE_ID:-}" ] && [ "$WS" != "$HERDR_WORKSPACE_ID" ]; }; }; then
    h workspace close "$WS"
  else
    h tab close "$TAB"
  fi
  for k in agent:name tab:label; do
    h "${k%:*}" list
    c=0
    jq -e --arg n "$N" "any(.result.${k%:*}s[]; .${k#*:} == \$n)" <<<"$r" >/dev/null 2>&1 || c=$?
    [ $c != 0 ] || fail "close left ${k%:*} $N"
    [ $c = 1 ] || fail "close left ${k%:*} $N: cannot read the list"
  done
  rx "[ ! -L $Q/.stratum ] && rm -f $Q/.stratum/git-guard.json && rm -rf $Q/.stratum/approve" || fail "Worker $N: closed, but cannot remove .stratum/git-guard.json."
  rx "rm -f $Q/.stratum/worker" || fail "Worker $N: closed, but cannot remove .stratum/worker."
  printf 'closed\t%s\nfolder\t%s\tready to remove\n' "$N" "$WT"
  ;;
list)
  h tab list
  x=$(jq -er '[.result.tabs[] | select(.label | strings | startswith("worker-")) | "\(.tab_id)\t\(.workspace_id)\t\(.label)"] | join("\n")' <<<"$r") || stop "no .result.tabs in the herdr answer"
  h agent list
  ag=$r
  h workspace list
  ws=$r
  jq -e '.result.workspaces | arrays' <<<"$ws" >/dev/null || stop "no .result.workspaces in the herdr answer"
  n=0
  while IFS=$'\t' read -r -u 3 tb w l; do
    [ -n "$tb" ] || continue
    N=$l WT= BR=
    h pane list --workspace "$w"
    c=$(jq -r --arg t "$tb" 'first(.result.panes[] | select(.tab_id == $t) | .cwd | strings) // empty' <<<"$r")
    if [ -n "$c" ]; then
      h worktree list --cwd "$c"
      pick "$c"
    fi
    a=$(jq -r --arg n "$l" 'first(.result.agents[] | select(.name == $n) | "\(.pane_id // "-")\t\(.agent_status)") // "-\tgone"' <<<"$ag")
    case ${a#*$'\t'} in
      idle | done)
        if question; then a=${a%$'\t'*}$'\tblocked'; elif unsent; then a=${a%$'\t'*}$'\tunsent'; fi
        ;;
    esac
    s=$(jq -r --arg w "$w" 'first(.result.workspaces[] | select(.workspace_id == $w) | .label | strings | select(. != "") | gsub("[[:cntrl:]]"; " ")) // "-"' <<<"$ws")
    printf 'found\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$l" "${m:-local}" "$tb" "$a" "${WT:--}" "$s" "${BR:--}"
    n=$((n + 1))
  done 3<<<"$x"
  [ "$n" != 0 ] || echo "no workers on ${m:-local}"
  ;;
watch)
  [ -f "$roster" ] || fail "Roster not found: $roster"
  sf=$roster.seen
  : >>"$sf" || fail "Cannot write $sf."
  mark() {
    awk -F'\t' -v n="$N" '$1 != n' "$sf" >"$sf.new"
    [ -z "$1" ] || printf '%s\t%s\n' "$N" "$1" >>"$sf.new"
    mv -- "$sf.new" "$sf"
  }
  mapfile -t rows < <(grep -v '^[[:space:]]*$' "$roster")
  [ ${#rows[@]} != 0 ] || fail "Roster $roster has no workers."
  declare -A tg=() wtc=() qc=() idle=() resent=()
  ms=
  for l in "${rows[@]}"; do
    IFS=$'\t' read -r -a f <<<"$l"
    [[ ${f[0]:-} == worker-* ]] && [ -n "${f[1]:-}" ] || fail "Roster lines must be: name, machine, branch, task, split by TAB."
    [ "${f[1]}" = local ] || [ -n "${tg[${f[1]}]:-}" ] || {
      [ -n "$ms" ] || ms=$(herdr machine list --json 2>"$e") || fail "herdr machine list failed."
      tg[${f[1]}]=$(jq -er --arg m "${f[1]}" 'first(.[] | select(.label == $m or .id == $m) | .target)' <<<"$ms" 2>/dev/null) || fail "Unknown machine: ${f[1]}."
    }
  done
  bound=540 # ponytail: fixed 540 s bound to stay under the Bash tool's 600 s cap, raise it if the cap moves
  tick=5    # ponytail: fixed 5 s between polls of all workers, lower it if a live run reacts too slowly
  end=$((SECONDS + bound))
  while :; do
    for l in "${rows[@]}"; do
      IFS=$'\t' read -r -a f <<<"$l"
      N=${f[0]} m= H=(herdr) target=
      [ "${f[1]}" = local ] || { m=${f[1]}; H=(herdr --machine "$m"); target=${tg[$m]}; }
      old=$(awk -F'\t' -v n="$N" '$1 == n { v = $2 } END { print v }' "$sf")
      if ! r=$("${H[@]}" agent get "$N" 2>"$e") || ! S=$(jq -er '.result.agent.agent_status' <<<"$r" 2>/dev/null); then
        case $old in gone | finished*) continue ;; esac
        mark gone
        printf 'state\tgone\t%s\t-\n' "$N"
        exit 5
      fi
      PANE=$(jq -r '.result.agent.pane_id // "-"' <<<"$r")
      key= dlg=
      [ "$S" != working ] || ! shown || { S=blocked; dlg=1; }
      case $S in
        blocked | idle | done)
          [ -n "${wtc[$N]:-}" ] || { find_worker; wtc[$N]=$WT; qc[$N]=$Q; }
          WT=${wtc[$N]} Q=${qc[$N]}
          ;;
      esac
      case $S in
        blocked)
          if reqid; then
            [ "approval ${rq%.req}" = "$old" ] && continue
            mark "approval ${rq%.req}"
            approval
          fi
          readpane || :
          key="blocked $(cksum <"$t" | cut -d" " -f1)"
          [ -z "$dlg" ] || [ "$BM" != block ] || key="blocked $SH"
          ;;
        idle | done)
          if question; then
            key="blocked $(cksum <"$t" | cut -d" " -f1)"
          elif ck=$(if [ -n "$m" ]; then rsh "cksum < $Q/result.md"; else cksum <"$WT/result.md"; fi 2>/dev/null); then
            key="finished $ck"
          elif unsent; then
            if [ -z "${resent[$N]:-}" ]; then
              resent[$N]=1
              ! push || continue
            fi
            key=unsent
          else
            idle[$N]=$((${idle[$N]:-0} + 1))
            [ "${idle[$N]}" -lt 3 ] || key=stopped
          fi
          ;;
      esac
      [ "$S" = idle ] || [ "$S" = done ] || unset "idle[$N]"
      if [ -z "$key" ]; then
        [ "$S" != working ] || [ -z "$old" ] || mark ""
        continue
      fi
      [ "$key" != "$old" ] || continue
      mark "$key"
      case $key in
        blocked*) st blocked; exit 4 ;;
        finished*) st finished; exit 0 ;;
        unsent) st unsent; exit 7 ;;
        stopped) st stopped; exit 5 ;;
      esac
    done
    if [ "$SECONDS" -ge "$end" ]; then
      printf 'watch\tno event\t%s workers\n' "${#rows[@]}"
      exit 3
    fi
    sleep "$tick"
  done
  ;;
approve | pass)
  find_worker
  F=$WT/.stratum/approve/$rid.req
  if [ -n "$m" ]; then
    rsh "head -n 1 -- $Q/.stratum/approve/session" >"$t" || :
    ws=$(head -n 1 "$t")
  else
    ws=$(head -n 1 "$WT/.stratum/approve/session" 2>/dev/null) || ws=
  fi
  [ -n "$ws" ] && [ "$ws" = "$SID" ] || fail "Worker $N is not in this autonomous run."
  if [ -n "$m" ]; then
    rsh "cat -- $Q/.stratum/approve/$rid.req" >"$t" || fail "No request $rid for $N."
    F=$t
  else
    [ -f "$F" ] || fail "No request $rid for $N."
  fi
  x=user
  if [ "$cmd" = approve ]; then
    x=ok
    want=$(render "$F") || fail "The input does not match request $rid. Approve nothing."
    [ ${#want} -le 4000 ] || fail "Request $rid is too long to approve. Pass it to the user."
    s=$(sha256sum <<<"$want")
    [ "${s:0:64}" = "$ihash" ] || fail "The input does not match request $rid. Approve nothing."
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$N" "tab $N" "${want%%: *}" "${want#*: }" >>"$record" || fail "Cannot write the record file $record. Approve nothing."
  fi
  if [ -n "$m" ]; then
    rsh "[ ! -L $Q/.stratum ] && [ ! -L $Q/.stratum/approve ] && [ ! -L $Q/.stratum/approve/$rid.$x ] && : > $Q/.stratum/approve/$rid.$x" || fail "Cannot write $rid.$x for $N."
  else
    [ ! -L "$WT/.stratum" ] && [ ! -L "$WT/.stratum/approve" ] && [ ! -L "$WT/.stratum/approve/$rid.$x" ] && : >"$WT/.stratum/approve/$rid.$x" || fail "Cannot write $rid.$x for $N."
  fi
  if [ "$cmd" = approve ]; then
    "${H[@]}" agent wait "$N" --until working --timeout 5000 >/dev/null 2>&1 || true
    printf 'approved\t%s\t%s\n' "$N" "$rid"
  else
    printf 'passed\t%s\t%s\n' "$N" "$rid"
  fi
  ;;
autonomous-on)
  [ -n "$MAIN" ] || fail "cannot turn on autonomous mode: not in a git repo"
  [[ $SID =~ ^[A-Za-z0-9-]+$ ]] || fail "cannot turn on autonomous mode: session id must be letters, digits or -"
  [ ! -L "$D" ] || fail "cannot turn on autonomous mode: $D is a symlink"
  [ ! -f "$D" ] || rm -f -- "$D" 2>/dev/null || :
  mkdir -p "$D" 2>/dev/null || :
  [ -d "$D" ] && [ ! -L "$D" ] || fail "cannot turn on autonomous mode: $D is not a folder"
  [ ! -L "$D/$SID" ] || fail "cannot turn on autonomous mode: $D/$SID is a symlink"
  [ -f "$D/$SID" ] || : >"$D/$SID" 2>/dev/null || fail "cannot turn on autonomous mode: cannot write $D/$SID"
  printf 'autonomous on\t%s\n' local
  off=${CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS+1}
  top=$(git rev-parse --show-toplevel 2>/dev/null) || top=
  for f in "$top/.claude/settings.json" "$top/.claude/settings.local.json" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"; do
    [ -n "$off" ] || ! jq -e '.includeGitInstructions == false' "$f" >/dev/null 2>&1 || off=1
  done
  [ -n "$off" ] || printf 'hint\t%s\n' "Autonomous build mode works better with Claude Code's built-in git instructions off: add \"includeGitInstructions\": false to .claude/settings.json (this project) or ~/.claude/settings.json (all projects), then start new sessions."
  ;;
autonomous-off)
  [ -z "${roster+x}" ] || [ -f "$roster" ] || fail "Roster not found: $roster"
  declare -A seen=()
  bad=0
  while IFS= read -r l || [ -n "$l" ]; do
    IFS=$'\t' read -r -a f <<<"$l"
    mm=${f[1]:-}
    k=$mm
    [ "$mm" = local ] || k+=$'\t'${f[4]:-}
    [ -n "$mm" ] && [ -z "${seen[$k]:-}" ] || continue
    seen[$k]=1
    msg= skip=
    if [ "$mm" = local ]; then
      if [ -z "$MAIN" ]; then
        msg="not in a git repo"
      elif [ -L "$D" ]; then
        msg="$D is a symlink"
      elif [ -L "$D/$SID" ]; then
        msg="$D/$SID is a symlink"
      elif [ -d "$D" ] && [ -f "$D/$SID" ]; then
        rm -f -- "$D/$SID" 2>"$e" || msg=$(head -1 "$e")
      else
        skip=1
      fi
    elif [ -z "${f[4]:-}" ]; then
      msg="Roster row for ${f[0]} needs the repo path as a fifth field."
    elif ! ms=$(herdr machine list --json 2>"$e"); then
      msg=$(head -1 "$e")
      msg=${msg:-herdr machine list failed.}
    elif ! target=$(jq -er --arg m "$mm" 'first(.[] | select(.label == $m or .id == $m) | .target)' <<<"$ms" 2>/dev/null); then
      msg="Unknown machine: $mm."
    else
      quote "${f[4]}"
      sshq "[ ! -L $Q/.stratum ] || { echo \"$Q/.stratum is a symlink\" >&2; exit 3; }; [ ! -L $Q/.stratum/autonomous ] || { echo \"$Q/.stratum/autonomous is a symlink\" >&2; exit 3; }; [ ! -L $Q/.stratum/autonomous/$SID ] || { echo \"$Q/.stratum/autonomous/$SID is a symlink\" >&2; exit 3; }; if [ -d $Q/.stratum/autonomous ] && [ -f $Q/.stratum/autonomous/$SID ]; then rm -f -- $Q/.stratum/autonomous/$SID; else echo skip; fi" </dev/null >"$t" || { rc=$?; msg=$(head -1 "$e"); msg=${msg:-exit $rc}; }
      [ -n "$msg" ] || [ "$(head -n 1 "$t")" != skip ] || skip=1
    fi
    if [ -n "$msg" ]; then
      printf 'autonomous off failed\t%s\t%s\n' "$mm" "$msg"
      bad=1
    elif [ -n "$skip" ]; then
      printf 'autonomous off skipped\t%s\tnot on for this session\n' "$mm"
    else
      printf 'autonomous off\t%s\n' "$mm"
    fi
  done < <(printf -- '-\tlocal\n'; [ -z "${roster+x}" ] || cat -- "$roster")
  exit "$bad"
  ;;
headless)
  top=$(git rev-parse --show-toplevel 2>/dev/null) && old=$(git rev-parse HEAD 2>/dev/null) || fail "Run headless inside a git repo with a commit."
  {
    printf '%s\n\n' "# Brief: $N (headless)" "## Task $id"
    cat -- "$task"
    printf '\n%s\n\n' '## Facts'
    printf '%s\n' "- Test command: \`$test\`" "- Model: ${model:-default}" '- Work in this folder. Leave the change uncommitted: never commit, never push.' '- Run the test command exactly as written, as one Bash call.' '- You cannot ask questions. If you need a decision, stop and say in your last reply what is missing.'
  } >"$t"
  cd "$top"
  [ -z "$(git status --porcelain)" ] || fail "Working tree is not clean."
  HP="/goal \`$test\` exits 0 and the change is left uncommitted; read $t first and follow it"
  bound=540 # ponytail: fixed 540 s bound to stay under the Bash tool's 600 s cap, raise it if the cap moves
  turns=30 # ponytail: fixed 30-turn cap per headless run, raise it if quickstart section 5 measures goal runs that need more
  rc=0
  j=$(timeout -k 10 "$bound" claude -p "$HP" --output-format json --max-turns "$turns" -n "$N" ${model:+--model "$model"} --tools Read,Edit,Write,Glob,Grep,Bash \
    --allowedTools Read Edit Write Glob Grep "Bash($test)" \
    --permission-mode dontAsk --permission-prompts none --strict-mcp-config) || rc=$?
  new=$(git rev-parse HEAD)
  [ "$old" = "$new" ] || fail "worker committed: $old -> $new"
  [ "$rc" != 124 ] && [ "$rc" != 137 ] || fail "timed out after $bound s"
  [ "$rc" = 0 ] || jq -e '.is_error == true or .subtype != "success"' <<<"$j" >/dev/null 2>&1 || fail "claude exited $rc"
  jq -e 'type == "object"' <<<"$j" >/dev/null 2>&1 || fail "claude gave no JSON result."
  printf 'headless\t%s\t%s\n' "$N" "$(jq -r '[.subtype, .num_turns, .total_cost_usd] | @tsv' <<<"$j")"
  echo 'result:'
  jq -r '.result // empty' <<<"$j"
  jq -e '.is_error != true and .subtype == "success"' <<<"$j" >/dev/null || exit 1
  ;;
esac
