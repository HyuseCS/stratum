#!/usr/bin/env bash
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
# ponytail: polls agent get every 2 s, so a closed tab is seen up to 2 s late; use a herdr event if herdr adds one
hw() {
  local f p r
  f=$(mktemp) || die "ERROR: cannot make a temp file"
  herdr "$@" > "$f" 2>&1 &
  p=$!
  while kill -0 $p 2>/dev/null; do
    sleep 2
    [ "$(herdr agent get "$name" 2>&1 | jget error code)" = agent_not_found ] && kill $p 2>/dev/null && break
  done
  wait $p
  r=$?
  out=$(<"$f")
  rm -f "$f"
  return $r
}
# ponytail: a pid reused after a kill looks like a live review, store the start time too if that bites
mark() {
  trap 'rm -f "$tabs/$name.review"' EXIT
  (umask 077; mkdir -p "$tabs" && echo $$ > "$tabs/$name.review") || die "ERROR: cannot write $tabs/$name.review"
}
ended() {
  herdr agent get "$name" >/dev/null 2>&1 || die "BLOCKED: the Codex tab ended during the review" 4
  die "BLOCKED: the Codex tab failed during the review: $(head -n1 <<<"$out")" 4
}
# ponytail: a path with a newline breaks the snapshot lines, use -z through to the compare if one shows up
snap() {
  local - c e f l m p x=(-- . ':(exclude).stratum/state.json' ':(exclude,glob)**/.syncthing.*.tmp' ':(exclude,glob)**/~syncthing~*.tmp')
  set -o pipefail
  c=$(git rev-parse --show-cdup 2>/dev/null)
  echo "HEAD $(git rev-parse -q --verify HEAD 2>/dev/null)"
  git --no-optional-locks diff --cached --raw --no-abbrev --no-renames -z "${x[@]}" 2>/dev/null |
    while IFS= read -r -d '' m && IFS= read -r -d '' e; do
      printf '%s\tindex\t%s\n' "$e" "$m"
    done || return 1
  git --no-optional-locks status --porcelain=v1 -z --untracked-files=all --no-renames "${x[@]}" 2>/dev/null |
    while IFS= read -r -d '' e; do
      f=$c${e:3}
      printf '%s\t%s\t%s %s\n' "${e:3}" "${e:0:2}" "$(stat -c %f -- "$f" 2>/dev/null)" "$(if [ -L "$f" ]; then readlink -- "$f" | sha256sum | cut -d' ' -f1; elif [ -f "$f" ]; then sha256sum < "$f" | cut -d' ' -f1; fi)"
      [ ! -L "${f%/}" ] && [ -e "$f/.git" ] || continue
      p=${e:3}
      (cd -- "$f" && snap) | while IFS= read -r l; do printf '%s/%s\n' "${p%/}" "${l/#HEAD /HEAD$'\t'}"; done || exit 1
    done
}

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
    code=$(jget error code <<<"$out")
    [ "$code" = agent_not_ready ] && break
    [ "$code" = agent_pane_busy ] && [ $i -lt 10 ] || die "ERROR: $(head -n1 <<<"$out")"
    sleep 1
  done
  [[ $made =~ ^[A-Za-z0-9:_-]+$ ]] || die "ERROR: bad tab id from herdr: $made"
  (umask 077; mkdir -p "$tabs" && printf '%s\n' "$made" "$@" > "$tabs/$name") || die "ERROR: cannot write $tabs/$name"
  [ "$code" = agent_not_ready ] && { mark; hw agent wait "$name" --until idle --until done || ended; }
fi

before=$(snap) || die "ERROR: cannot read git status in $root"
hd agent get "$name"
# ponytail: herdr cannot see text typed but not sent in the tab, a point may type after it; check the pane input if herdr exposes it
case $(jget result agent agent_status <<<"$out") in working|blocked) die "codex: tab in use" 3 ;; esac
mark

nonce=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
[[ $nonce =~ ^[0-9a-f]{12}$ ]] || die "ERROR: no nonce"
printf '%s\n' "The project root is $root. Read every path above relative to it." \
  'The JSON object has the keys verdict ("APPROVED", "REVISE" or "BLOCKED"), summary (a string) and findings (a list of objects with the string keys claim, evidence, location and severity, severity one of "CRITICAL", "HIGH", "MEDIUM", "LOW").' \
  "Print the line ST-ADVISOR-BEGIN-$nonce alone, then the JSON object on one line, then the line ST-ADVISOR-END-$nonce alone. Print nothing after the end line." >> "$pf" || die "ERROR: cannot write $pf"
hw agent prompt "$name" "Read the review request in $pf and follow it. Change no file." --wait --until done --until idle
prc=$?
rm -f "$tabs/$name.review"
after=$(snap) || die "BLOCKED: cannot read git status in $root" 4
[ "$before" = "$after" ] || die "BLOCKED: Codex changed files during the review: $(comm -3 <(sort <<<"$before") <(sort <<<"$after") | sed 's/^\t//; s/^HEAD .*/HEAD/; s/\t.*//' | LC_ALL=C sort -u | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')" 4
[ $prc = 0 ] || {
  [ "$(jget error code <<<"$out")" = agent_blocked ] && die "codex: tab in use" 3
  ended
}

# ponytail: fixed 15 tries for the log to show the answer, raise it if quickstart L3 measures a longer lag
for _ in {1..15}; do
  python3 -I -c '
import glob, json, os, sys
root, pf, n, af = sys.argv[1:]
t0 = os.stat(pf).st_mtime_ns
ask = "Read the review request in " + pf + " and follow it."
best = None
stop = False
for p in glob.glob(os.path.join(glob.escape(root), "**", "rollout-*.jsonl"), recursive=True):
    asked = False
    try:
        if os.stat(p).st_mtime_ns < t0:
            continue
        with open(p, encoding="utf-8", errors="replace") as f:
            for l in f:
                try:
                    d = json.loads(l)
                except (ValueError, RecursionError):
                    continue
                q = d.get("payload") if isinstance(d, dict) else None
                if not isinstance(q, dict):
                    continue
                m = q.get("last_agent_message")
                if d.get("type") == "event_msg" and q.get("type") == "task_complete" and isinstance(m, str):
                    ls = m.split("\n")
                    k = [x.rstrip(" \r") for x in ls]
                    e = max((i for i, x in enumerate(k) if x == "ST-ADVISOR-END-" + n), default=-1)
                    b = max((i for i, x in enumerate(k[:e]) if x == "ST-ADVISOR-BEGIN-" + n), default=-1) if e > 0 else -1
                    if b >= 0:
                        best = "\n".join(ls[b + 1:e])
                elif d.get("type") == "response_item" and q.get("type") == "message" and q.get("role") == "user" and isinstance(q.get("content"), list):
                    asked = asked or any(isinstance(c, dict) and isinstance(c.get("text"), str) and ask in c["text"] for c in q["content"])
                elif asked and d.get("type") == "event_msg" and q.get("type") == "turn_aborted":
                    stop = True
    except OSError:
        continue
if best is not None:
    with open(af, "w", encoding="utf-8", newline="") as f:
        f.write(best)
    sys.exit(0)
sys.exit(2 if stop else 1)' "${CODEX_HOME:-$HOME/.codex}/sessions" "$pf" "$nonce" "$af"
  case $? in
    0) echo "codex: tab $name"; exit 0 ;;
    2) die "BLOCKED: the review was stopped in the Codex tab" 4 ;;
  esac
  sleep 1
done
die "codex: no session log" 6
