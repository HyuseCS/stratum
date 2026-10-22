#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: st-worker.sh start <id> --task <file> --test <cmd> --lane <text> --roster <file> | goal <id> --test <cmd> | wait <id> | result <id> | close <id> | list" >&2; exit 2; }
fail() { echo "$1" >&2; exit 1; }
[ $# -gt 0 ] || usage
cmd=$1; shift
case $cmd in
  start | goal | wait | result | close) [ $# -gt 0 ] || usage; id=$1; shift ;;
  list) ;;
  *) usage ;;
esac
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage
  case "$cmd $1" in
    "start --task") task=$2 ;;
    "start --test" | "goal --test") test=$2 ;;
    "start --lane") lane=$2 ;;
    "start --roster") roster=$2 ;;
    *) usage ;;
  esac
  shift 2
done
case $cmd in
  start) [ -n "${task+x}" ] && [ -n "${test+x}" ] && [ -n "${lane+x}" ] && [ -n "${roster+x}" ] || usage ;;
  goal) [ -n "${test+x}" ] || usage ;;
esac

N=
if [ "$cmd" != list ]; then
  [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,24}$ ]] || fail "Task id must be letters, digits or dash, start with a letter or digit, and be at most 25 characters."
  N=worker-${id,,}
fi
if [ "$cmd" = start ]; then
  [ -f "$task" ] && [ -s "$task" ] || fail "Task file not found or empty: $task"
fi
if [ "$cmd" = start ] || [ "$cmd" = goal ]; then
  [[ -n $test && $test != *$'\n'* && $test != *[\(\)]* ]] || fail "Test command must be one line with no ( or )."
fi
if [ "$cmd" = start ]; then
  [[ -n $lane && $lane != *$'\n'* ]] || fail "Lane must be one line."
  [ -f "$roster" ] || fail "Roster has no line for $N."
  R=() n=0 own=
  while IFS= read -r l || [ -n "$l" ]; do
    n=$((n + 1))
    [ -n "$l" ] || continue
    t=${l//[!$'\t']/}
    IFS=$'\t' read -r -a f <<<"$l"
    [ ${#t} = 3 ] && [ ${#f[@]} = 4 ] && [[ ${f[0]} == worker-* ]] || fail "Roster line $n must be: name, machine, branch, task, split by TAB."
    [ "${f[0]}" != "$N" ] || own=1
    R+=("${f[@]}")
  done <"$roster"
  [ -n "$own" ] || fail "Roster has no line for $N."
fi
if [ "$cmd" = start ] || [ "$cmd" = goal ]; then
  P="/goal \`$test\` exits 0, the change is committed on branch $N, and result.md is written; read brief.md in this folder first and follow it"
  [ ${#P} -le 4000 ] || fail "The /goal prompt is over 4000 characters."
fi
[ "${HERDR_ENV:-}" = 1 ] || fail "Not inside a herdr pane. Run it from a herdr pane, or name a --machine."

H=(herdr)
WS= PANE= BR= WT= S=
e=$(mktemp)
trap 'rm -f "$e"' EXIT

worker() { printf 'worker\t%s\tlocal\t%s\t%s\t%s\t%s\n' "$N" "${WS:--}" "${PANE:--}" "${BR:--}" "${WT:--}"; }
stop() {
  echo "stopped: $1"
  [ "$cmd" != start ] || worker
  exit 1
}
h() { r=$("${H[@]}" "$@" 2>"$e") || stop "$(head -1 "$e")"; }
get() { local v; v=$(jq -er "$2" <<<"$r") || stop "no $2 in the herdr answer"; printf -v "$1" %s "$v"; }
code() { jq -r '.error.code // empty' "$e" 2>/dev/null || true; }
look() {
  h agent get "$N"
  get S .result.agent.agent_status
  get PANE .result.agent.pane_id
}
panetext() {
  echo 'pane text:'
  "${H[@]}" agent read "$N" --source recent-unwrapped --lines 40 2>/dev/null | jq -r .result.read.text 2>/dev/null || true
}
st() {
  printf 'state\t%s\t%s\t%s\n' "$1" "$N" "$PANE"
  case $1 in blocked | stopped) panetext ;; esac
}
find_worker() {
  h workspace list
  local c
  c=$(jq -er --arg n "$N" '[.result.workspaces[] | select(.label == $n)] | length' <<<"$r") || stop "no .result.workspaces in the herdr answer"
  [ "$c" != 0 ] || fail "No worker $N on local."
  [ "$c" = 1 ] || fail "More than one workspace is labelled $N."
  WS=$(jq -er --arg n "$N" 'first(.result.workspaces[] | select(.label == $n) | .workspace_id)' <<<"$r") || fail "No worker $N on local."
  h worktree list --workspace "$WS"
  WT=$(jq -er --arg w "$WS" 'first(.result.worktrees[] | select(.open_workspace_id == $w) | .path)' <<<"$r") || fail "No worker $N on local."
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
  printf '%s\n' "- Test command: \`$test\`" "- Lane: $lane. Start it with the Skill tool. Run only task $id; skip every other task, ticked or not." "- Branch: $N" "- Your machine: local. \`local\` is the orchestrator's machine." "- Result file: $WT/result.md"
  printf '\n%s\n\n%s\n%s\n' '## Roster' '| Name | Machine | Branch | Task |' '|------|---------|--------|------|'
  printf '| %s | %s | %s | %s |\n' "${R[@]}"
  printf '\n%s\n\n' '## Team rules'
  printf '%s\n' \
    '1. Commit each finished unit with the st-git agent, exact paths only. Never commit brief.md, result.md or .stratum/git-guard.json.' \
    "2. Before you build on a teammate's work, merge its branch: \`git log <branch>\`, \`git merge <branch>\`. A teammate on another machine shares no commits with you: send it messages only, and do not build on its work." \
    '3. Ask a teammate by name: on your machine, SendMessage to its name; on another machine, `herdr --machine <label> agent prompt <name> "<text>"`, with `<label>` from `herdr machine list` on your machine.' \
    '4. Never merge and never push. The orchestrator reviews every branch and is the only one who merges.'
  printf '\n%s\n\n%s\n%s\n' '## Questions' 'Ask a question only with the AskUserQuestion tool, then wait for the answer. Do not ask in plain text and do not guess.' 'Do not edit tasks.md or .stratum/state.json. The orchestrator ticks the task after the merge.'
  printf '\n%s\n\n%s\n' '## When done' 'Write the result file with four lines:'
  printf '%s\n' 'Built: <what you built>' 'Tests: <test command> exit <code>' 'Commit: <sha>' 'Open: <open points, or none>'
  [ ! -f "$(dirname "$0")/st-advisor.sh" ] || printf '\n%s\n\n%s\n' '## Advisor' 'The Codex advisor is installed (`scripts/st-advisor.sh` in the Stratum plugin). At each advisor point your lane names, run it and follow its verdict.'
}

case $cmd in
start)
  repo=$(git rev-parse --show-toplevel 2>/dev/null) && sha=$(git rev-parse HEAD 2>/dev/null) || fail "Run start inside a git repo with a commit."
  h workspace list
  c=$(jq -er --arg n "$N" '[.result.workspaces[] | select(.label == $n)] | length' <<<"$r") || stop "no .result.workspaces in the herdr answer"
  [ "$c" = 0 ] || fail "A worker $N already exists."
  path="$(dirname "$repo")/$(basename "$repo")-$N"
  h worktree create --cwd "$repo" --branch "$N" --base "$sha" --path "$path" --label "$N" --no-focus
  get WS .result.workspace.workspace_id
  get PANE .result.root_pane.pane_id
  get BR .result.worktree.branch
  get WT .result.worktree.path
  [ "$WT" = "$path" ] || stop "herdr made the worktree in $WT, not $path"
  brief >"$WT/brief.md" || stop "cannot write $WT/brief.md"
  mkdir -p "$WT/.stratum" || stop "cannot make $WT/.stratum"
  jq -c '.commit="auto"' <(cat "$repo/.stratum/git-guard.json" 2>/dev/null || echo '{}') >"$WT/.stratum/git-guard.json" || stop "cannot write the commit guard file in $WT/.stratum"
  if ! "${H[@]}" agent start "$N" --kind claude --pane "$PANE" --timeout 120000 -- --permission-mode auto -n "$N" >/dev/null 2>"$e"; then
    [ "$(code)" = agent_not_ready ] || stop "$(head -1 "$e")"
    worker
    st blocked
    exit 4
  fi
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
        st blocked
        exit 4
        ;;
      idle | done)
        if [ -f "$WT/result.md" ]; then
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
result)
  find_worker
  [ -f "$WT/result.md" ] || {
    echo "no result file: $WT/result.md"
    panetext
    exit 1
  }
  printf 'result\t%s\t%s/result.md\n' "$N" "$WT"
  cat -- "$WT/result.md"
  ;;
close)
  find_worker
  if r=$("${H[@]}" agent get "$N" 2>"$e"); then
    S=$(jq -r '.result.agent.agent_status // empty' <<<"$r" 2>/dev/null || true)
    case $S in working | blocked) fail "Worker $N is $S. Close refused." ;; esac
  fi
  h workspace close "$WS"
  h agent list
  ! jq -e --arg n "$N" 'any(.result.agents[]; .name == $n)' <<<"$r" >/dev/null 2>&1 || fail "close left agent $N"
  h workspace list
  ! jq -e --arg n "$N" 'any(.result.workspaces[]; .label == $n)' <<<"$r" >/dev/null 2>&1 || fail "close left workspace $N"
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
    printf 'found\t%s\tlocal\t%s\t%s\t%s\n' "$l" "$w" "$a" "$p"
    n=$((n + 1))
  done 3<<<"$x"
  [ "$n" != 0 ] || echo "no workers on local"
  ;;
esac
