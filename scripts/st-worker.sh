#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: st-worker.sh start <id> --task <file> --test <cmd> --lane <text> --roster <file> [--machine <m> --repo <path>] [--model <name>] [--autonomous] | goal <id> --test <cmd> [--machine <m>] | wait <id> [--machine <m>] | answer <id> [--machine <m>] --keys <key>... | --text <text> | result <id> [--machine <m>] | close <id> [--machine <m>] | list [--machine <m>] | headless <id> --task <file> --test <cmd> [--model <name>] | approve <id> --request <rid> --input-stdin --record <file> [--machine <m>] | pass <id> --request <rid> [--machine <m>] | autonomous-off --roster <file>" >&2; exit 2; }
fail() { echo "$1" >&2; exit 1; }
[ $# -gt 0 ] || usage
cmd=$1; shift
case $cmd in
  start | goal | wait | answer | result | close | headless | approve | pass) [ $# -gt 0 ] || usage; id=$1; shift ;;
  list | autonomous-off) ;;
  *) usage ;;
esac
m= repo= auto= instdin=
while [ $# -gt 0 ]; do
  case "$cmd $1" in
    "start --autonomous") auto=1; shift; continue ;;
    "approve --input-stdin") instdin=1; shift; continue ;;
  esac
  [ $# -ge 2 ] || usage
  case "$cmd $1" in
    "start --task" | "headless --task") task=$2 ;;
    "start --test" | "goal --test" | "headless --test") test=$2 ;;
    "start --lane") lane=$2 ;;
    "start --roster" | "autonomous-off --roster") roster=$2 ;;
    "approve --request" | "pass --request") rid=$2 ;;
    "approve --record") record=$2 ;;
    "start --repo") repo=$2 ;;
    "start --model" | "headless --model")
      [ -z "${model+x}" ] && [ -n "$2" ] || usage
      model=$2
      ;;
    "headless --machine" | "autonomous-off --machine") usage ;;
    *" --machine") m=$2 ;;
    "answer --text") text=$2 ;;
    "answer --keys")
      keys=("${@:2}")
      break
      ;;
    *) usage ;;
  esac
  shift 2
done
case $cmd in
  start) [ -n "${task+x}" ] && [ -n "${test+x}" ] && [ -n "${lane+x}" ] && [ -n "${roster+x}" ] && { [ -z "$repo" ] || [ -n "$m" ]; } || usage ;;
  goal) [ -n "${test+x}" ] || usage ;;
  headless) [ -n "${task+x}" ] && [ -n "${test+x}" ] || usage ;;
  answer) [ "${text+x}${keys+x}" = x ] || usage ;;
  approve) [ -n "${rid+x}" ] && [ -n "${record+x}" ] && [ -n "$instdin" ] || usage ;;
  pass) [ -n "${rid+x}" ] || usage ;;
  autonomous-off) [ -n "${roster+x}" ] || usage ;;
esac
for v in ${text+"$text"} ${keys+"${keys[@]}"}; do [[ $v != -* ]] || { echo 'Answer values must not start with -.' >&2; exit 2; }; done

N=
if [ "$cmd" != list ] && [ "$cmd" != autonomous-off ]; then
  [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,24}$ ]] || fail "Task id must be letters, digits or dash, start with a letter or digit, and be at most 25 characters."
  N=worker-${id,,}
fi
if [ "$cmd" = approve ] || [ "$cmd" = pass ] || [ "$cmd" = autonomous-off ] || [ -n "$auto" ]; then
  if { tl=$(git rev-parse --show-toplevel 2>/dev/null) && [ -e "$tl/.stratum/approve" ]; } || [[ $(git symbolic-ref --short HEAD 2>/dev/null) == worker-* ]]; then
    fail "Run this from the orchestrator's checkout, not a worker worktree."
  fi
  d=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && MAIN=$(dirname "$d") || MAIN=
  SID=${CLAUDE_CODE_SESSION_ID:-}
  [ "$cmd" = autonomous-off ] || { [ -n "$MAIN" ] && [ -n "$SID" ] && [ -f "$MAIN/.stratum/autonomous" ] && [ "$(head -n 1 "$MAIN/.stratum/autonomous")" = "$SID" ]; } || fail "Autonomous build mode is off for this session."
fi
if [ "$cmd" = approve ] || [ "$cmd" = pass ]; then
  [[ $rid =~ ^[0-9]+-[0-9]+$ ]] || fail "No request $rid for $N."
fi
if [ "$cmd" = approve ]; then
  IFS= read -r -d '' input || true
  input=${input%$'\n'}
fi
if [ "$cmd" = start ] || [ "$cmd" = headless ]; then
  [ -f "$task" ] && [ -s "$task" ] || fail "Task file not found or empty: $task"
fi
if [ "$cmd" = start ] || [ "$cmd" = goal ] || [ "$cmd" = headless ]; then
  [[ -n $test && $test != *$'\n'* && $test != *[\(\)]* ]] || fail "Test command must be one line with no ( or )."
fi
[ "$cmd" != headless ] || [[ $test != *\** ]] || fail "Test command must not contain * for headless."
if [ "$cmd" = start ] || [ "$cmd" = headless ]; then
  [ -n "${model+x}" ] || { top=$(git rev-parse --show-toplevel 2>/dev/null) && model=$(jq -r '."st-worker".model // empty' "$top/.stratum/models.json" 2>/dev/null); } || model=
  [ -z "$model" ] || [[ $model =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "Model must be one token of letters, digits, dot, underscore or dash, starting with a letter or digit."
fi
if [ "$cmd" = start ]; then
  [[ -n $lane && $lane != *$'\n'* ]] || fail "Lane must be one line."
  [ -f "$roster" ] || fail "Roster has no line for $N."
  R=() n=0 own= orepo=
  while IFS= read -r l || [ -n "$l" ]; do
    n=$((n + 1))
    [ -n "$l" ] || continue
    t=${l//[!$'\t']/}
    IFS=$'\t' read -r -a f <<<"$l"
    { { [ ${#t} = 3 ] && [ ${#f[@]} = 4 ]; } || { [ ${#t} = 4 ] && [ ${#f[@]} = 5 ]; }; } && [[ ${f[0]} == worker-* ]] || fail "Roster line $n must be: name, machine, branch, task, split by TAB."
    [ "${f[0]}" != "$N" ] || { own=1; orepo=${f[4]:-}; }
    R+=("${f[@]:0:4}")
  done <"$roster"
  [ -n "$own" ] || fail "Roster has no line for $N."
  [ -z "$auto" ] || [ -z "$m" ] || [ "$orepo" = "$repo" ] || fail "Roster row for $N needs the repo path as a fifth field."
fi
if [ "$cmd" = start ] || [ "$cmd" = goal ]; then
  P="/goal \`$test\` exits 0, the change is committed on branch $N, and result.md is written; read brief.md in this folder first and follow it"
  [ ${#P} -le 4000 ] || fail "The /goal prompt is over 4000 characters."
fi
[ "$cmd" = headless ] || [ "$cmd" = autonomous-off ] || [ -n "$m" ] || [ "${HERDR_ENV:-}" = 1 ] || fail "Not inside a herdr pane. Run it from a herdr pane, or name a --machine."
[ "$cmd" != start ] || [ -z "$m" ] || [[ $repo == [/~]* ]] || fail "A saved machine needs --repo <path> starting with / or ~."

H=(herdr)
WS= PANE= BR= WT= S= Q=
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

worker() { printf 'worker\t%s\t%s\t%s\t%s\t%s\t%s\n' "$N" "${m:-local}" "${WS:--}" "${PANE:--}" "${BR:--}" "${WT:--}"; }
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
  case $1 in blocked | stopped) panetext ;; esac
}
noresult() {
  echo "no result file: $WT/result.md"
  panetext
  exit 1
}
find_worker() {
  h workspace list
  local c
  c=$(jq -er --arg n "$N" '[.result.workspaces[] | select(.label == $n)] | length' <<<"$r") || stop "no .result.workspaces in the herdr answer"
  [ "$c" != 0 ] || fail "No worker $N on ${m:-local}."
  [ "$c" = 1 ] || fail "More than one workspace is labelled $N."
  WS=$(jq -er --arg n "$N" 'first(.result.workspaces[] | select(.label == $n) | .workspace_id)' <<<"$r") || fail "No worker $N on ${m:-local}."
  h worktree list --workspace "$WS"
  WT=$(jq -er --arg w "$WS" 'first(.result.worktrees[] | select(.open_workspace_id == $w) | .path)' <<<"$r") || fail "No worker $N on ${m:-local}."
  quote "$WT"
}
render() { python3 "$(cd "$(dirname "$0")/.." && pwd)/hooks/st-approve.py" --render "$1"; }
owns() { awk 'f && (/^[[:space:]]*$/ || /^[[:space:]]*- \[/) { exit } !f && /Owns:/ { f = 1; sub(/.*Owns:/, "") } f { if (sub(/Test:.*/, "")) { print; exit } print }' "$task" | grep -o '`[^`]*`' | tr -d '`' || true; }
approval() {
  local f=$WT/.stratum/approve/ rq in
  if [ -n "$m" ]; then rsh "ls -1 $Q/.stratum/approve" >"$t" || return 0; else ls -1 "$f" >"$t" 2>/dev/null || return 0; fi
  rq=$(grep -m1 -xE '[0-9]+-[0-9]+\.req' "$t") || return 0
  if [ -n "$m" ]; then rsh "cat -- $Q/.stratum/approve/$rq" >"$t" || return 0; f=$t; else f=$f$rq; fi
  in=$(render "$f") || return 0
  printf 'state\tapproval\t%s\t%s\nrequest\t%s\ntab\tworkspace %s, tab Main\ninput\t%s\n' "$N" "$PANE" "${rq%.req}" "$N" "$in"
  jq -r '(.branch | strings | "branch\t\(gsub("[[:cntrl:]]"; "?"))"), (.staged | arrays | "staged\t\(map(tostring | gsub("[[:cntrl:]]"; "?")) | join(" "))")' "$f" 2>/dev/null || true
  panetext
  exit 6
}
prompt() {
  "${H[@]}" agent prompt "$N" "$P" --wait --until working --until blocked --timeout 30000 >/dev/null 2>"$e" && return
  [ "$(code)" = agent_blocked ] || stop "$(head -1 "$e")"
  if [ "$cmd" = start ]; then worker; else look; fi
  st blocked
  exit 4
}
brief() {
  printf '%s\n\n' "# Brief: $N" "You are worker $N, started by the Stratum orchestrator. Read this file first and follow it." "## Task $id"
  cat -- "$task"
  printf '\n%s\n\n' '## Facts'
  printf '%s\n' "- Test command: \`$test\`" '- Test lock: if your task is marked [lock], run its test command as `bash <plugin root>/scripts/st-lock.sh -- <test command>`, with the plugin root of the Stratum plugin. Never write a wait loop of your own.' "- Lane: $lane. If it names a skill, start it with the Skill tool. Run only task $id; skip every other task, ticked or not." "- Branch: $N" "- Model: ${model:-default}"
  [ -n "$m" ] || printf '%s\n' "- Plugin root: $(cd "$(dirname "$0")/.." && pwd)"
  printf '%s\n' "- Your machine: ${m:-local}. \`local\` is the orchestrator's machine." "- Result file: $WT/result.md"
  printf '\n%s\n\n%s\n%s\n' '## Roster' '| Name | Machine | Branch | Task |' '|------|---------|--------|------|'
  printf '| %s | %s | %s | %s |\n' "${R[@]}"
  printf '\n%s\n\n' '## Team rules'
  printf '%s\n' \
    '1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md, .stratum/git-guard.json or .stratum/approve/, and never write in .stratum/approve/.' \
    "2. Before you build on a teammate's work, merge its branch: \`git log <branch>\`, \`git merge <branch>\`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work." \
    '3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.' \
    "4. Never merge into the base branch and never push. Merging a teammate's branch into your own (rule 2) is fine. When your task says to run /stratum:st-pr, run it: it pushes your branch and opens the PR, and that is the only push allowed. The orchestrator reviews every branch and is the only one who merges into the base."
  printf '\n%s\n\n%s\n%s\n' '## Questions' 'Ask a question only with the AskUserQuestion tool, then wait for the answer. Do not ask in plain text and do not guess.' 'Do not edit tasks.md or .stratum/state.json. The orchestrator ticks the task after the merge.'
  printf '\n%s\n\n%s\n' '## When done' 'Write the result file with four lines:'
  printf '%s\n' 'Built: <what you built>' 'Tests: <test command> exit <code>' 'Commit: <sha>' 'Open: <open points, or none>'
  [ -n "$m" ] || [ ! -f "$(dirname "$0")/st-advisor.sh" ] || printf '\n%s\n\n%s\n' '## Advisor' 'The Codex advisor is installed (`scripts/st-advisor.sh` in the Stratum plugin). At each advisor point your lane names, run it and follow its verdict.'
}

case $cmd in
start)
  top=$(git rev-parse --show-toplevel 2>/dev/null) && sha=$(git rev-parse HEAD 2>/dev/null) || fail "Run start inside a git repo with a commit."
  [ -n "$m" ] || repo=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  G=$(jq -c --arg b "$N" '.commit="auto" | .branch=$b' <(cat "$top/.stratum/git-guard.json" 2>/dev/null || echo '{}')) || stop "cannot read $top/.stratum/git-guard.json"
  [ -n "$G" ] || G=$(jq -nc --arg b "$N" '{commit:"auto",branch:$b}')
  h workspace list
  c=$(jq -er --arg n "$N" '[.result.workspaces[] | select(.label == $n)] | length' <<<"$r") || stop "no .result.workspaces in the herdr answer"
  [ "$c" = 0 ] || fail "A worker $N already exists."
  path="$(dirname "$repo")/$(basename "$repo")-$N"
  if [ -n "$auto" ] && [ -n "$m" ]; then
    quote "$repo"
    sshq "[ ! -L $Q/.stratum ] || { echo \"$Q/.stratum is a symlink\" >&2; exit 3; }; [ ! -L $Q/.stratum/autonomous ] || { echo \"$Q/.stratum/autonomous is a symlink\" >&2; exit 3; }; mkdir -p $Q/.stratum && printf '%s\n' $(printf %q "$SID") > $Q/.stratum/autonomous" </dev/null || { rc=$? msg=$(head -1 "$e"); fail "cannot write .stratum/autonomous on $m: ${msg:-exit $rc}"; }
  fi
  h worktree create --cwd "$repo" --branch "$N" --base "$sha" --path "$path" --label "$N" --no-focus
  get WS .result.workspace.workspace_id
  get TAB .result.tab.tab_id
  get PANE .result.root_pane.pane_id
  get BR .result.worktree.branch
  get WT .result.worktree.path
  [ -n "$m" ] || [ "$WT" = "$path" ] || stop "herdr made the worktree in $WT, not $path"
  if [ -z "$m" ]; then
    [ ! -L "$WT/.stratum" ] || stop "$WT/.stratum is a symlink"
    for p in "$WT/brief.md" "$WT/result.md" "$WT/.stratum/git-guard.json" ${auto:+"$WT/.stratum/approve"}; do [ ! -L "$p" ] || stop "$p is a symlink"; [ ! -e "$p" ] || stop "$p already exists"; done
    brief >"$WT/brief.md" || stop "cannot write $WT/brief.md"
    mkdir -p "$WT/.stratum" || stop "cannot make $WT/.stratum"
    printf '%s\n' "$G" >"$WT/.stratum/git-guard.json" || stop "cannot write the commit guard file in $WT/.stratum"
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
    rsh "[ ! -L $Q/.stratum ] || { echo \"$Q/.stratum is a symlink\" >&2; exit 3; }; for p in $Q/brief.md $Q/result.md $Q/.stratum/git-guard.json${auto:+ $Q/.stratum/approve}; do [ ! -L \"\$p\" ] || { echo \"\$p is a symlink\" >&2; exit 3; }; [ ! -e \"\$p\" ] || { echo \"\$p already exists\" >&2; exit 3; }; done && cat > $Q/brief.md && mkdir -p $Q/.stratum && printf '%s\n' $(printf %q "$G") > $Q/.stratum/git-guard.json$A" < <(brief) || { rc=$? msg=$(head -1 "$e"); stop "cannot write brief.md and .stratum/git-guard.json in $WT on $m: ${msg:-exit $rc}"; }
  fi
  h tab rename "$TAB" Main
  h pane split "$PANE" --direction right --cwd "$WT" --no-focus
  get p .result.pane.pane_id
  h pane run "$p" lazygit
  for name in "Dev Servers" VM; do
    h tab create --workspace "$WS" --cwd "$WT" --label "$name" --no-focus
    get p .result.root_pane.pane_id
    h pane split "$p" --direction right --cwd "$WT" --no-focus
  done
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
  end=$((SECONDS + bound))
  while :; do
    left=$(((end - SECONDS) * 1000))
    if [ "$left" -le 0 ]; then
      look
      st working
      exit 3
    fi
    if ! "${H[@]}" agent wait "$N" --timeout "$left" >/dev/null 2>"$e"; then
      [ "$(code)" = timeout ] || stop "$(head -1 "$e")"
      look
      st working
      exit 3
    fi
    look
    case $S in
      blocked)
        approval
        st blocked
        exit 4
        ;;
      idle | done)
        if { [ -z "$m" ] && [ -f "$WT/result.md" ]; } || { [ -n "$m" ] && rsh test -f "$Q/result.md"; }; then
          st finished
          exit 0
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
  [ "$S" = blocked ] || fail "not blocked: $S"
  "${H[@]}" agent read "$N" --source recent-unwrapped --lines 40 >"$t" 2>"$e" && ! grep -qE '^([[:space:]]|│)*(Do you want to|(❯[[:space:]]*)?1\. Yes)' "$t" || fail "This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it."
  if [ -n "${keys+x}" ]; then
    h agent send-keys "$N" "${keys[@]}"
  else
    h pane send-text "$PANE" "$text"
    h agent send-keys "$N" enter
  fi
  settle=5000 # ponytail: fixed 5 s wait for blocked to clear after an answer (live T008 saw about 2 s), raise it if a live run measures a longer lag
  "${H[@]}" agent wait "$N" --until working --timeout "$settle" >/dev/null 2>&1 || true
  look
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
  rsh cat -- "$Q/result.md" >"$t" || noresult
  printf 'result\t%s\t%s/result.md\n' "$N" "$WT"
  cat -- "$t"
  GIT_SSH_COMMAND='ssh -o BatchMode=yes' git fetch -- "$target:$WT" "$N:$N" >/dev/null 2>"$e" || stop "$(head -1 "$e")"
  f=$(git rev-parse --verify "$N" 2>"$e") || stop "$(head -1 "$e")"
  printf 'fetched\t%s\t%s\n' "$N" "$f"
  ;;
close)
  find_worker
  if r=$("${H[@]}" agent get "$N" 2>"$e"); then
    S=$(jq -er '.result.agent.agent_status' <<<"$r" 2>/dev/null) || fail "Worker $N: cannot read worker state. Close refused."
    case $S in working | blocked) fail "Worker $N is $S. Close refused." ;; esac
  else
    [ "$(code)" = agent_not_found ] || fail "Worker $N: cannot read worker state. Close refused."
  fi
  # ponytail: GitHub remote found by "github" in a remote URL, use gh's host list if a GitHub Enterprise host lacks the word
  if git remote -v 2>/dev/null | grep -q github; then
    p=$(gh pr list --head "$N" --state open --json number -q length 2>/dev/null) || fail "Worker $N: cannot read its PRs. Close refused."
    [ "$p" = 0 ] || fail "Worker $N has an open PR. Close refused."
  fi
  if [ -n "$m" ]; then
    rsh "[ ! -L $Q/.stratum ] || exit 3; rm -f $Q/.stratum/git-guard.json && rm -rf $Q/.stratum/approve" || { [ $? != 3 ] || fail "Worker $N: .stratum is a symlink. Close refused."; fail "Worker $N: cannot remove .stratum/git-guard.json. Close refused."; }
  else
    [ ! -L "$WT/.stratum" ] || fail "Worker $N: .stratum is a symlink. Close refused."
    rm -f "$WT/.stratum/git-guard.json" || fail "Worker $N: cannot remove .stratum/git-guard.json. Close refused."
    rm -rf "$WT/.stratum/approve" || fail "Worker $N: cannot remove .stratum/approve. Close refused."
  fi
  h workspace close "$WS"
  for k in agent:name workspace:label; do
    h "${k%:*}" list
    c=0
    jq -e --arg n "$N" "any(.result.${k%:*}s[]; .${k#*:} == \$n)" <<<"$r" >/dev/null 2>&1 || c=$?
    [ $c != 0 ] || fail "close left ${k%:*} $N"
    [ $c = 1 ] || fail "close left ${k%:*} $N: cannot read the list"
  done
  printf 'closed\t%s\nfolder\t%s\tready to remove\n' "$N" "$WT"
  ;;
list)
  h workspace list
  x=$(jq -er '[.result.workspaces[] | select(.label | startswith("worker-")) | "\(.workspace_id)\t\(.label)"] | join("\n")' <<<"$r") || stop "no .result.workspaces in the herdr answer"
  h agent list
  ag=$r
  n=0
  while IFS=$'\t' read -r -u 3 w l; do
    [ -n "$w" ] || continue
    h worktree list --workspace "$w"
    p=$(jq -r --arg w "$w" 'first(.result.worktrees[] | select(.open_workspace_id == $w) | .path) // "-"' <<<"$r")
    a=$(jq -r --arg n "$l" 'first(.result.agents[] | select(.name == $n) | "\(.pane_id // "-")\t\(.agent_status)") // "-\tgone"' <<<"$ag")
    printf 'found\t%s\t%s\t%s\t%s\t%s\n' "$l" "${m:-local}" "$w" "$a" "$p"
    n=$((n + 1))
  done 3<<<"$x"
  [ "$n" != 0 ] || echo "no workers on ${m:-local}"
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
    [ "$input" = "$want" ] || fail "The input does not match request $rid. Approve nothing."
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$N" "workspace $N, tab Main" "${want%%: *}" "${want#*: }" >>"$record" || fail "Cannot write the record file $record. Approve nothing."
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
autonomous-off)
  [ -f "$roster" ] || fail "Roster not found: $roster"
  declare -A seen=()
  bad=0
  while IFS= read -r l || [ -n "$l" ]; do
    IFS=$'\t' read -r -a f <<<"$l"
    mm=${f[1]:-}
    k=$mm
    [ "$mm" = local ] || k+=$'\t'${f[4]:-}
    [ -n "$mm" ] && [ -z "${seen[$k]:-}" ] || continue
    seen[$k]=1
    msg=
    if [ "$mm" = local ]; then
      F=$MAIN/.stratum/autonomous
      if [ -z "$MAIN" ]; then
        msg="not in a git repo"
      elif [ -f "$F" ] && [ "$(head -n 1 "$F")" = "$SID" ]; then
        rm -f "$F" 2>"$e" || msg=$(head -1 "$e")
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
      sshq "[ ! -L $Q/.stratum ] || { echo \"$Q/.stratum is a symlink\" >&2; exit 3; }; [ ! -L $Q/.stratum/autonomous ] || { echo \"$Q/.stratum/autonomous is a symlink\" >&2; exit 3; }; [ ! -f $Q/.stratum/autonomous ] || [ \"\$(head -n 1 $Q/.stratum/autonomous)\" != $(printf %q "$SID") ] || rm -f $Q/.stratum/autonomous" </dev/null || { rc=$?; msg=$(head -1 "$e"); msg=${msg:-exit $rc}; }
    fi
    if [ -n "$msg" ]; then
      printf 'autonomous off failed\t%s\t%s\n' "$mm" "$msg"
      bad=1
    else
      printf 'autonomous off\t%s\n' "$mm"
    fi
  done <"$roster"
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
