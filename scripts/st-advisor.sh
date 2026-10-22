#!/usr/bin/env bash
set -o pipefail
usage() { echo "usage: st-advisor.sh plan|test|diff|check|continued ..."; exit 2; }
cmd=run
case ${1:-} in check|continued) cmd=$1; shift ;; esac
point=${1:-}
case "$cmd $point $#" in "run plan 2"|"run test 6"|"run diff 3"|"check plan 2"|"check diff 3"|"continued plan 2"|"continued test 2"|"continued diff 2") ;; *) usage ;; esac
f=${2%/}
[ -f "$f/spec.md" ] && [ -r "$f/spec.md" ] || usage
[ -L "$f/advisor.md" ] && usage
if [ $cmd != run ]; then
  rec=$(grep -a "^## $point | " "$f/advisor.md" 2>/dev/null | tail -n1)
  if [ -z "$rec" ]; then echo "no record: $point"; [ $cmd = check ] && exit 1; exit 2; fi
  rest=${rec#* | * | sha256 }
  rhash=${rest%% | *}
  if [ $cmd = continued ]; then
    { [ -s "$f/advisor.md" ] && echo; printf '## %s | %s | sha256 %s | BLOCKED, user continued\n' "$point" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rhash"; } >> "$f/advisor.md" || exit 1
    echo "BLOCKED, user continued sha256 $rhash"
    exit 0
  fi
fi
case $point in
  plan) [ -f "$f/plan.md" ] && [ -r "$f/plan.md" ] && [ -f "$f/tasks.md" ] && [ -r "$f/tasks.md" ] || usage ;;
  test) [ -f "$3" ] && [ -r "$3" ] && [ -f "$5" ] && [ -r "$5" ] && [ -f "$6" ] && [ -r "$6" ] || usage ;;
  diff) sha=$(git rev-parse --verify --quiet "$3^{commit}") && [ -n "$sha" ] || usage ;;
esac
bad=0
if [ $cmd = run ]; then
  [ -e .stratum/advisor.json ] || { echo 'no advisor: mode not set. Write .stratum/advisor.json with "mode": "codex", "both" or "off".'; exit 0; }
  cfg=$(python3 -I - <<'PY'
import json, re, sys
try:
    s = json.loads(open(".stratum/advisor.json", "rb").read())
except (OSError, ValueError, RecursionError):
    sys.exit(1)
if not (isinstance(s, dict) and set(s) <= {"mode", "model", "effort"} and all(isinstance(v, str) for v in s.values())
        and s.get("mode") in ("codex", "both", "off")
        and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}", s.get("model", "x"))
        and re.fullmatch(r"[a-z]{1,16}", s.get("effort", "x"))):
    sys.exit(1)
print(s["mode"], s.get("model", ""), s.get("effort", ""), sep="\n")
PY
) || bad=1
  if [ $bad = 0 ]; then
    { read -r mode; read -r model; read -r effort; } <<<"$cfg"
    [ $mode = off ] && { echo "no advisor: mode off"; exit 0; }
    [ $mode = both ] && echo "mode both: also consult /advisor if one is set"
    opts=()
    [ -n "$model" ] && opts+=(-m "$model")
    [ -n "$effort" ] && opts+=(-c "model_reasoning_effort=\"$effort\"")
    command -v codex >/dev/null || { echo "no advisor: codex not found"; exit 0; }
  fi
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

case $point in
  plan) hash=$(cat "$f/spec.md" "$f/plan.md" "$f/tasks.md" | sha256sum) || { echo "cannot hash inputs"; exit 2; } ;;
  test) hash=$(cat "$5" "$6" | sha256sum) || { echo "cannot hash inputs"; exit 2; } ;;
  diff)
    git ls-files -z --others --exclude-standard -- . ":(exclude)$f/advisor.md" > "$tmp/untracked" &&
    (
      git diff --no-ext-diff --no-color --no-renames --default-prefix "$sha" -- . ":(exclude)$f/advisor.md" || exit 1
      while IFS= read -r -d '' p; do [[ $p == */ ]] && continue; git diff --no-ext-diff --no-color --no-renames --default-prefix --no-index -- /dev/null "$p" || [ $? -eq 1 ] || exit 1; done < "$tmp/untracked"
    ) > "$tmp/diff" || { echo "cannot hash inputs"; exit 2; }
    hash=$(sha256sum < "$tmp/diff") || { echo "cannot hash inputs"; exit 2; } ;;
esac
hash=${hash%% *}
[[ $hash =~ ^[0-9a-f]{64}$ ]] || { echo "cannot hash inputs"; exit 2; }
if [ $cmd = check ]; then
  [ "$hash" = "$rhash" ] || { echo "advisor approval is stale"; exit 1; }
  echo "${rest#* | } sha256 $hash"
  exit 0
fi
block() {
  { [ -s "$f/advisor.md" ] && echo; printf '## %s | %s | sha256 %s | BLOCKED\nreason: %s\n' "$point" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hash" "$1"; } >> "$f/advisor.md" || exit 1
  printf 'BLOCKED: %s\nrecord: %s/advisor.md\n' "$1" "$f"
  exit 1
}
[ $bad = 0 ] || block "bad advisor.json"
command -v timeout >/dev/null || block "timeout not found"

printf '%s\n' '{"type":"object","additionalProperties":false,"required":["verdict","summary","findings"],"properties":{"verdict":{"type":"string","enum":["APPROVED","REVISE","BLOCKED"]},"summary":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["claim","evidence","location","severity"],"properties":{"claim":{"type":"string"},"evidence":{"type":"string"},"location":{"type":"string"},"severity":{"type":"string","enum":["CRITICAL","HIGH","MEDIUM","LOW"]}}}}}}' > "$tmp/schema.json"

{
  printf '%s\n' \
    'You are a reviewer for Stratum. Review only: never create, change or delete a file, and never build or fix anything.' \
    'Read only the inputs named below and the files they cite. Never open .env files, keys, credentials, tokens or other secret files.' \
    'Never quote a secret value in a finding.' \
    'Answer with verdict APPROVED (nothing to fix), REVISE (findings to fix) or BLOCKED (you cannot review, or the work must stop). Each finding has a claim, the evidence, a location (file:line when known) and a severity.'
  case $point in
    plan)
      printf '%s\n' \
        'Point: plan. Review the plan before the build. Risks: missed access rules, schema or contract breaks, hidden breaking changes. Improvements: a simpler approach, tasks to cut or merge.' \
        "Inputs: $f/spec.md, $f/plan.md, $f/tasks.md" ;;
    test)
      printf '%s\n' 'Point: test. This task'"'"'s test is still red after two build tries. Root cause or rabbit hole?' "Test: $4" 'Task:'
      cat "$3"
      [ -z "$(tail -c1 "$3")" ] || echo
      echo 'Failure output 1:'
      cat "$5"
      [ -z "$(tail -c1 "$5")" ] || echo
      echo 'Failure output 2:'
      cat "$6"
      [ -z "$(tail -c1 "$6")" ] || echo ;;
    diff)
      printf '%s\n' \
        'Point: diff. Review the full diff before the build is called done: hidden regressions, broken project rules, missed requirements.' \
        "Inputs: run git diff $sha -- . ':(exclude)$f/advisor.md' ':(exclude).env*' ':(exclude)*/.env*' ':(exclude)*.pem' ':(exclude)*.key' ':(exclude)*.p12' ':(exclude)*.pfx' and read each untracked file listed below. Env and secret files are left out of that diff. The feature dir is $f." \
        'Untracked files:'
      list=
      while IFS= read -r -d '' p; do
        [[ $p == */ ]] && continue
        case ${p##*/} in .env*|*.pem|*.key|*.p12|*.pfx) ;; *) list+="$p"$'\n' ;; esac
      done < "$tmp/untracked"
      [ -n "$list" ] || list=$'none\n'
      printf '%s' "$list" ;;
  esac
} > "$tmp/prompt"

rc=0
timeout -k 10 540 codex exec -s read-only "${opts[@]}" --ephemeral --output-schema "$tmp/schema.json" -o "$tmp/answer.json" - < "$tmp/prompt" > "$tmp/out" 2> "$tmp/err" || rc=$?

python3 -I - "$point" "$f" "$hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tmp/answer.json" "$rc" "$tmp/err" <<'PY'
import json, os, sys
sys.stdout.reconfigure(errors="replace")
point, f, h, ts, ans, rc, err = sys.argv[1:]
def clean(s):
    return s.replace("\r", " ").replace("\n", " ")
def record(v, lines):
    with open(f"{f}/advisor.md", "a", encoding="utf-8", errors="replace") as r:
        r.write("\n" * bool(r.tell()) + "".join(l + "\n" for l in [f"## {point} | {ts} | sha256 {h} | {v}", *lines]))
def blocked(reason, extra=()):
    reason = clean(reason)
    record("BLOCKED", [f"reason: {reason}"])
    print("\n".join([f"BLOCKED: {reason}", *extra, f"record: {f}/advisor.md"]))
    sys.exit(1)
if rc in ("124", "137"):
    blocked("timed out")
if rc != "0":
    errs = [clean(l) for l in open(err, "rb").read().decode("utf-8", "replace").split("\n") if l.startswith("ERROR:")]
    blocked(f"codex exited {rc}", errs[-1:])
raw = open(ans, "rb").read() if os.path.isfile(ans) else b""
if not raw.strip():
    blocked("empty answer")
try:
    a = json.loads(raw)
except (ValueError, RecursionError):
    blocked("malformed answer")
if not isinstance(a, dict):
    blocked("malformed answer")
if a.get("verdict") not in ("APPROVED", "REVISE", "BLOCKED"):
    blocked("no verdict")
keys = ("claim", "evidence", "location", "severity")
fs = a.get("findings")
if not isinstance(a.get("summary"), str) or not isinstance(fs, list) or not all(isinstance(x, dict) and all(isinstance(x.get(k), str) for k in keys) for x in fs):
    blocked("malformed answer")
if a["verdict"] == "REVISE" and not fs:
    blocked("REVISE with no findings")
if a["verdict"] == "APPROVED" and fs:
    blocked("APPROVED with findings")
v = a["verdict"]
summary = clean(a["summary"])
found = [f"- [{clean(x['severity'])}] {clean(x['location'])}: {clean(x['claim'])} Evidence: {clean(x['evidence'])}" for x in a["findings"]]
record(v, [f"summary: {summary}", *found])
head = [f"BLOCKED: {summary}"] if v == "BLOCKED" else [f"{v} sha256 {h}", f"summary: {summary}"]
print("\n".join(head + found + [f"record: {f}/advisor.md"]))
sys.exit(1 if v == "BLOCKED" else 0)
PY
