#!/usr/bin/env bash
SECONDS=0
die() { echo "$1" >&2; exit "${2:-1}"; }
[ $# -ge 4 ] || die "usage: st-codex-agent.sh <feature dir> <prompt file> <answer file> <codex home> [-m <model>] [-c <key=value>]" 2
fd=$1 pf=$2 af=$3 home=$4
shift 4
base=$(basename "$fd")
[[ $base =~ ^[0-9]{3} ]] || die "ERROR: feature dir must start with three digits" 2
name=st-codex-${base:0:3}
root=$(pwd -P)
[ -L "$home/auth.json" ] && h="[projects.\"$root\"]" awk '$0 == ENVIRON["h"] {s = 1; next} /^\[/ {s = 0} s && $0 == "trust_level = \"untrusted\"" {f = 1} END {exit !f}' "$home/config.toml" 2>/dev/null || die "ERROR: no Stratum Codex home" 2
ws=$HERDR_WORKSPACE_ID
nofolder='ERROR: Codex waits for an answer at start in its Codex tab. It did not show the Folder access screen. Check the tab, then run the point again.'

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
screen() { herdr agent read "$name" --source recent-unwrapped --lines 60 2>&1 | sed $'s/\e\\[[0-9;]*[A-Za-z]//g'; }

hd agent list
others=$(python3 -I -c '
import json, sys
for a in json.loads(sys.stdin.read())["result"]["agents"]:
    n = a.get("name", "")
    if a.get("workspace_id") == sys.argv[1] and n.startswith("st-codex-"):
        print(n + "\t" + a.get("tab_id", ""))' "$ws" <<<"$out") || die "ERROR: $(head -n1 <<<"$out")"
found=0
while IFS=$'\t' read -r n tab; do
  [ -n "$n" ] || continue
  if [ "$n" = "$name" ]; then found=1; else hd tab close "$tab"; fi
done <<<"$others"

if [ $found = 0 ]; then
  hd tab create --workspace "$ws" --cwd "$root" --label Codex --env "CODEX_HOME=$home" --no-focus
  pane=$(jget result root_pane pane_id <<<"$out")
  [ -n "$pane" ] || die "ERROR: $(head -n1 <<<"$out")"
  notready=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    out=$(herdr agent start "$name" --kind codex --pane "$pane" --timeout 120000 -- -s read-only -a never --no-alt-screen "$@" 2>&1) && break
    code=$(jget error code <<<"$out")
    [ "$code" = agent_not_ready ] && { notready=1; break; }
    [ "$code" = agent_pane_busy ] && [ $i -lt 10 ] || die "ERROR: $(head -n1 <<<"$out")"
    sleep 1
  done
  s=$(screen)
  if grep -q 'Folder access' <<<"$s" && grep -q 'Open restricted' <<<"$s"; then
    hd agent send-keys "$name" enter
    gone=0
    for i in $(seq 20); do
      screen | grep -q 'Folder access' || { gone=1; break; }
      sleep 1
    done
    [ $gone = 1 ] || die "$nofolder"
  elif [ $notready = 1 ]; then
    die "$nofolder"
  fi
fi

nonce=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
[[ $nonce =~ ^[0-9a-f]{12}$ ]] || die "ERROR: no nonce"
printf '%s\n' "The project root is $root. Read every path above relative to it." \
  'The JSON object has the keys verdict ("APPROVED", "REVISE" or "BLOCKED"), summary (a string) and findings (a list of objects with the string keys claim, evidence, location and severity, severity one of "CRITICAL", "HIGH", "MEDIUM", "LOW").' \
  "Print the line ST-ADVISOR-BEGIN-$nonce alone, then the JSON object on one line, then the line ST-ADVISOR-END-$nonce alone. Print nothing after the end line." >> "$pf" || die "ERROR: cannot write $pf"
hd agent prompt "$name" "Read the review request in $pf and follow it. Change no file." --wait --until done --until idle --until blocked --timeout $(( (480 - SECONDS) * 1000 ))
[ "$(jget result state <<<"$out")" = blocked ] && die "ERROR: Codex waits for an answer in its Codex tab."
[ -L "$home/auth.json" ] || die "ERROR: Codex replaced the login link in $home; your own Codex login may be stale. Run codex login status, then st-advisor.sh codex-home."

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
