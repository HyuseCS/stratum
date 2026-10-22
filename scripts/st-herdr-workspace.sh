#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: st-herdr-workspace.sh <folder> --label <name> [--machine <label-or-id>] [--template full|basic] [--agent claude|claude2]" >&2; exit 2; }
fail() { echo "$1" >&2; exit 1; }
[ -n "${1:-}" ] || usage
folder=$1; shift
label= machine= template=full agent=claude
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage
  case $1 in
    --label) label=$2 ;;
    --machine) machine=$2 ;;
    --template) template=$2 ;;
    --agent) agent=$2 ;;
    *) usage ;;
  esac
  shift 2
done

[ -n "$label" ] || fail "Label is required: --label <issue-or-name>."
[[ $label =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "Label must be letters, digits, dot, dash or underscore, and start with a letter or digit."
case $template in full | basic) ;; *) fail "Template must be full or basic." ;; esac
case $agent in claude | claude2) ;; *) fail "Agent must be claude or claude2." ;; esac
[ -n "$machine" ] || [ "${HERDR_ENV:-}" = 1 ] || fail "Not inside a herdr pane. Run it from a herdr pane, or name a --machine."

Q=$(printf %q "$folder")
probe=$(bash -c "cd -- $Q && pwd && { git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null || true; }" 2>/dev/null) || fail "Folder not found on ${machine:-local}: $folder"
D=${probe%%$'\n'*}
git=$(tail -n +2 <<<"$probe" | awk '/^# branch\.head /{h=$3} /^# branch\.ab /{ab="ahead " substr($3,2) ", behind " substr($4,2) " (as of last fetch)"} /^# branch\./{g=1} /^[^#]/{n++} END{if(!g)print "not a git repo"; else print h ", " (n ? n " changed" : "clean") ", " (ab ? ab : "no upstream")}')

H=(herdr)
[ -z "$machine" ] || H+=(--machine "$machine")
e=$(mktemp)
trap 'rm -f "$e"' EXIT
WS= rep=()
declare -A st

report() {
  local l k id _ p c
  local -A cwd
  while IFS=$'\t' read -r p c; do cwd[$p]=$c; done < <("${H[@]}" pane list --workspace "$WS" 2>/dev/null | jq -r '.result.panes[] | "\(.pane_id)\t\(.cwd)"' 2>/dev/null)
  printf 'workspace\t%s\t%s\t%s\n' "$WS" "$label" "${machine:-local}"
  printf 'folder\t%s\t%s\n' "$D" "$git"
  for l in "${rep[@]}"; do
    IFS=$'\t' read -r k id _ <<<"$l"
    if [ "$k" = tab ]; then echo "$l"; else printf '%s\t%s\t%s\n' "$l" "${st[$id]:--}" "${cwd[$id]:-?}"; fi
  done
}
stop() {
  echo "stopped: $1"
  [ -z "$WS" ] || report
  exit 1
}
h() { r=$("${H[@]}" "$@" 2>"$e") || stop "$(head -1 "$e")"; }
get() { local v; v=$(jq -er "$2" <<<"$r") || stop "no $2 in the herdr answer"; printf -v "$1" %s "$v"; }
row() { local IFS=$'\t'; rep+=("$*"); }

h workspace create --cwd "$D" --label "$label" --no-focus
get WS .result.workspace.workspace_id
get T1 .result.tab.tab_id
get P1 .result.root_pane.pane_id
row tab "$T1" Main
row pane "$P1" "$T1" "$agent"
st[$P1]="not seen"
h tab rename "$T1" Main
h pane split "$P1" --direction right --cwd "$D" --no-focus
get P2 .result.pane.pane_id
row pane "$P2" "$T1" lazygit
st[$P2]="not seen"
h pane run "$P1" "$agent"
h pane run "$P2" lazygit
for name in "Dev Servers" VM; do
  h tab create --workspace "$WS" --cwd "$D" --label "$name" --no-focus
  get t .result.tab.tab_id
  get p .result.root_pane.pane_id
  row tab "$t" "$name"
  row pane "$p" "$t" shell
  h pane split "$p" --direction right --cwd "$D" --no-focus
  get p .result.pane.pane_id
  row pane "$p" "$t" shell
done
h workspace focus "$WS"

wait=10 # ponytail: fixed 10 s running-check bound, raise it if quickstart section 2 measures a slower claude start
for ((i = 1; i <= wait; i++)); do
  [ "$i" = 1 ] || sleep 1
  for p in "$P1" "$P2"; do
    n=lazygit
    [ "$p" != "$P1" ] || n=claude
    if [ "${st[$p]}" != running ] && "${H[@]}" pane process-info --pane "$p" 2>/dev/null | jq -e --arg n "$n" 'any(.result.process_info.foreground_processes[]?; .name == $n)' >/dev/null 2>&1; then st[$p]=running; fi
  done
  if [ "${st[$P1]}${st[$P2]}" = runningrunning ]; then break; fi
done

report
