#!/usr/bin/env bash
SECONDS=0
die() { echo "$1" >&2; exit "${2:-1}"; }
[ $# -ge 4 ] || die "usage: st-codex-agent.sh <feature dir> <prompt file> <answer file> <codex home> [-m <model>] [-c <key=value>]" 2
fd=$1 pf=$2 af=$3 home=$4
shift 4
base=$(basename "$fd")
base=${base//[!A-Za-z0-9-]/-}
name=st-codex-${base:0:20}
root=$(pwd -P)
[ -L "$home/auth.json" ] || die "ERROR: no Stratum Codex home" 2
h="[projects.\"$root\"]" awk '$0 == ENVIRON["h"] {s = 1; next} /^\[/ {s = 0} s && $0 == "trust_level = \"untrusted\"" {f = 1} END {exit !f}' "$home/config.toml" 2>/dev/null || die "ERROR: no Stratum Codex home entry for $root: run st-advisor.sh codex-home" 2
ws=$HERDR_WORKSPACE_ID
want=$(printf '%s\n' "$name" "$root" "$@")
made=
nofolder='ERROR: Codex stopped at start on a screen Stratum does not know, so the Codex tab is closed. Run the point again, or check Codex.'

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
quit() { [ -n "$made" ] && herdr tab close "$made" >/dev/null 2>&1; die "$1"; }
screen() { herdr agent read "$name" --source recent-unwrapped --lines 60 2>&1 | sed $'s/\e\\[[0-9;]*[A-Za-z]//g'; }

hd agent list
others=$(python3 -I -c '
import json, sys
for a in json.loads(sys.stdin.read())["result"]["agents"]:
    n = a.get("name", "")
    if a.get("workspace_id") == sys.argv[1] and a.get("cwd") == sys.argv[2] and n.startswith("st-codex-"):
        print(n + "\t" + a.get("tab_id", ""))' "$ws" "$root" <<<"$out") || die "ERROR: $(head -n1 <<<"$out")"
found=0
while IFS=$'\t' read -r n tab; do
  r=$home/agents/$tab
  [[ $tab =~ ^[A-Za-z0-9:_-]+$ ]] && [ "$(head -n2 "$r" 2>/dev/null)" = "$n"$'\n'"$root" ] || continue
  if [ "$n" = "$name" ] && [ "$(cat "$r")" = "$want" ]; then found=1; else hd tab close "$tab"; rm -f "$r"; fi
done <<<"$others"

if [ $found = 0 ]; then
  hd tab create --workspace "$ws" --cwd "$root" --label Codex --env "CODEX_HOME=$home" --no-focus
  made=$(jget result tab tab_id <<<"$out")
  pane=$(jget result root_pane pane_id <<<"$out")
  [ -n "$pane" ] || die "ERROR: $(head -n1 <<<"$out")"
  notready=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    out=$(herdr agent start "$name" --kind codex --pane "$pane" --timeout 120000 -- -s read-only -a never --no-alt-screen "$@" 2>&1) && break
    code=$(jget error code <<<"$out")
    [ "$code" = agent_not_ready ] && { notready=1; break; }
    [ "$code" = agent_pane_busy ] && [ $i -lt 10 ] || quit "ERROR: $(head -n1 <<<"$out")"
    sleep 1
  done
  s=$(screen)
  if grep -q 'Folder access' <<<"$s" && grep -q '^[[:space:]]*› 1\. Open restricted' <<<"$s" && grep -qF '2. Back to Agent Command Center' <<<"$s"; then
    hd agent send-keys "$name" enter
    gone=0
    for i in $(seq 20); do
      screen | grep -q 'Folder access' || { gone=1; break; }
      sleep 1
    done
    [ $gone = 1 ] || quit "$nofolder"
  elif [ $notready = 1 ] || grep -q 'Folder access' <<<"$s"; then
    quit "$nofolder"
  fi
  [[ $made =~ ^[A-Za-z0-9:_-]+$ ]] || quit "ERROR: bad tab id from herdr: $made"
  (umask 077; mkdir -p "$home/agents" && printf '%s\n' "$want" > "$home/agents/$made") || quit "ERROR: cannot write $home/agents/$made"
fi

nonce=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
[[ $nonce =~ ^[0-9a-f]{12}$ ]] || die "ERROR: no nonce"
printf '%s\n' "The project root is $root. Read every path above relative to it." \
  'The JSON object has the keys verdict ("APPROVED", "REVISE" or "BLOCKED"), summary (a string) and findings (a list of objects with the string keys claim, evidence, location and severity, severity one of "CRITICAL", "HIGH", "MEDIUM", "LOW").' \
  "Print the line ST-ADVISOR-BEGIN-$nonce alone, then the JSON object on one line, then the line ST-ADVISOR-END-$nonce alone. Print nothing after the end line." >> "$pf" || die "ERROR: cannot write $pf"
out=$(herdr agent prompt "$name" "Read the review request in $pf and follow it. Change no file." --wait --until done --until idle --until blocked --timeout $(( (480 - SECONDS) * 1000 )) 2>&1) || {
  e="ERROR: $(head -n1 <<<"$out")"
  [ "$(jget error code <<<"$out")" = timeout ] && quit "$e"
  die "$e"
}
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
echo "codex: tab $name"
