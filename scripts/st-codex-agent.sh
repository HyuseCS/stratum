#!/usr/bin/env bash
SECONDS=0
die() { echo "$1" >&2; exit "${2:-1}"; }
[ $# -ge 4 ] && [[ $1 =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || die "usage: st-codex-agent.sh <tab name> <prompt file> <answer file> <state dir> [-m <model>] [-c <key=value>]" 2
name=$1 pf=$2 af=$3 tabs=$4
shift 4
root=$(pwd -P)
ws=$HERDR_WORKSPACE_ID

jget() {
  python3 -I -c '
import json, sys
for l in sys.stdin:
    try:
        d = json.loads(l)
    except ValueError:
        continue
    if not isinstance(d, dict):
        continue
    for k in sys.argv[1:]:
        d = d.get(k) if isinstance(d, dict) else None
    print(d if isinstance(d, str) else "")
    break' "$@"
}
hd() { out=$(herdr "$@" 2>&1) || die "ERROR: $(head -n1 <<<"$out")"; }

hd agent list
tab=$(python3 -I -c '
import json, sys
for a in json.loads(sys.stdin.read())["result"]["agents"]:
    if a.get("name") == sys.argv[1]:
        if a.get("workspace_id") != sys.argv[2] or a.get("cwd") != sys.argv[3]:
            sys.exit(5)
        print(a.get("tab_id", ""))' "$name" "$ws" "$root" <<<"$out")
rc=$?
[ $rc = 5 ] && die "codex: tab name $name in use elsewhere" 5
[ $rc = 0 ] || die "ERROR: $(head -n1 <<<"$out")"

if [ -n "$tab" ]; then
  have=$(cat "$tabs/$name" 2>/dev/null)
  if [ "$have" != "$(printf '%s\n' "$tab" "$@")" ]; then
    old="unknown settings"
    [ "$(head -n1 <<<"$have")" = "$tab" ] && { old=$(tail -n +2 <<<"$have" | paste -sd ' '); old=${old:-Codex defaults}; }
    new="$*"
    echo "codex: the Codex tab runs with $old, advisor.json asks for ${new:-Codex defaults}. Close the tab to apply."
  fi
else
  hd tab create --workspace "$ws" --cwd "$root" --label Codex --no-focus
  made=$(jget result tab tab_id <<<"$out")
  pane=$(jget result root_pane pane_id <<<"$out")
  [ -n "$pane" ] || die "ERROR: $(head -n1 <<<"$out")"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    out=$(herdr agent start "$name" --kind codex --pane "$pane" --timeout 120000 -- --no-alt-screen "$@" 2>&1) && break
    [ "$(jget error code <<<"$out")" = agent_pane_busy ] && [ $i -lt 10 ] || die "ERROR: $(head -n1 <<<"$out")"
    sleep 1
  done
  [[ $made =~ ^[A-Za-z0-9:_-]+$ ]] || die "ERROR: bad tab id from herdr: $made"
  (umask 077; mkdir -p "$tabs" && printf '%s\n' "$made" "$@" > "$tabs/$name") || die "ERROR: cannot write $tabs/$name"
fi

hd agent get "$name"
# ponytail: herdr cannot see text typed but not sent in the tab, a point may type after it; check the pane input if herdr exposes it
case $(jget result agent agent_status <<<"$out") in working|blocked) die "codex: tab in use" 3 ;; esac

nonce=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
[[ $nonce =~ ^[0-9a-f]{12}$ ]] || die "ERROR: no nonce"
printf '%s\n' "The project root is $root. Read every path above relative to it." \
  'The JSON object has the keys verdict ("APPROVED", "REVISE" or "BLOCKED"), summary (a string) and findings (a list of objects with the string keys claim, evidence, location and severity, severity one of "CRITICAL", "HIGH", "MEDIUM", "LOW").' \
  "Print the line ST-ADVISOR-BEGIN-$nonce alone, then the JSON object on one line, then the line ST-ADVISOR-END-$nonce alone. Print nothing after the end line." >> "$pf" || die "ERROR: cannot write $pf"
out=$(herdr agent prompt "$name" "Read the review request in $pf and follow it. Change no file." --wait --until done --until idle --until blocked --timeout $(( (480 - SECONDS) * 1000 )) 2>&1) || {
  [ "$(jget error code <<<"$out")" = agent_blocked ] && die "codex: tab in use" 3
  die "ERROR: $(head -n1 <<<"$out")"
}
[ "$(jget result state <<<"$out")" = blocked ] && die "ERROR: Codex waits for an answer in its Codex tab."

hd agent read "$name" --source recent-unwrapped --lines 400
python3 -I -c '
import sys
n, af = sys.argv[1:]
ls = [l.rstrip().lstrip("• ") for l in sys.stdin.read().split("\n")]
e = max((i for i, l in enumerate(ls) if l == "ST-ADVISOR-END-" + n), default=-1)
b = max((i for i, l in enumerate(ls[:e]) if l == "ST-ADVISOR-BEGIN-" + n), default=-1) if e > 0 else -1
if b < 0:
    sys.exit(1)
with open(af, "w", encoding="utf-8") as f:
    f.write(" ".join(ls[b + 1:e]))' "$nonce" "$af" <<<"$out" || die "ERROR: no answer between the markers"
echo "codex: tab $name"
