#!/usr/bin/env bash
usage() { echo "usage: st-advisor.sh plan|test|diff|check|continued ..."; exit 2; }
cmd=run
case ${1:-} in check|continued) cmd=$1; shift ;; esac
point=${1:-}
case "$cmd $point $#" in "run plan 2"|"run test 6"|"run diff 3"|"check plan 2"|"check diff 3"|"continued plan 2"|"continued test 2"|"continued diff 2") ;; *) usage ;; esac
f=${2%/}
[ -f "$f/spec.md" ] || usage
if [ $cmd != run ]; then
  rec=$(grep -a "^## $point | " "$f/advisor.md" 2>/dev/null | tail -n1)
  if [ -z "$rec" ]; then echo "no record: $point"; [ $cmd = check ] && exit 1; exit 2; fi
  rest=${rec#* | * | sha256 }
  rhash=${rest%% | *}
  if [ $cmd = continued ]; then
    printf '## %s | %s | sha256 %s | BLOCKED, user continued\n\n' "$point" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rhash" >> "$f/advisor.md"
    echo "BLOCKED, user continued sha256 $rhash"
    exit 0
  fi
fi
case $point in
  plan) [ -f "$f/plan.md" ] && [ -f "$f/tasks.md" ] || usage ;;
  test) [ -f "$3" ] && [ -f "$5" ] && [ -f "$6" ] || usage ;;
  diff) sha=$(git rev-parse --verify --quiet "$3^{commit}") && [ -n "$sha" ] || usage ;;
esac
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

case $point in
  plan) hash=$(cat "$f/spec.md" "$f/plan.md" "$f/tasks.md" | sha256sum) ;;
  test) hash=$(cat "$5" "$6" | sha256sum) ;;
  diff)
    git ls-files -z --others --exclude-standard -- . ":(exclude)$f/advisor.md" > "$tmp/untracked"
    hash=$({
      git diff "$sha" -- . ":(exclude)$f/advisor.md"
      while IFS= read -r -d '' p; do git diff --no-index -- /dev/null "$p"; done < "$tmp/untracked"
    } | sha256sum) ;;
esac
hash=${hash%% *}
if [ $cmd = check ]; then
  [ "$hash" = "$rhash" ] || { echo "advisor approval is stale"; exit 1; }
  echo "${rest#* | } sha256 $hash"
  exit 0
fi
command -v codex >/dev/null || { echo "no advisor: codex not found"; exit 0; }

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
      echo 'Failure output 1:'
      cat "$5"
      echo 'Failure output 2:'
      cat "$6" ;;
    diff)
      printf '%s\n' \
        'Point: diff. Review the full diff before the build is called done: hidden regressions, broken project rules, missed requirements.' \
        "Inputs: run git diff $sha -- . ':(exclude)$f/advisor.md' and read each untracked file listed below. The feature dir is $f." \
        'Untracked files:'
      list=
      while IFS= read -r -d '' p; do
        case ${p##*/} in .env*|*.pem|*.key|*.p12|*.pfx) ;; *) list+="$p"$'\n' ;; esac
      done < "$tmp/untracked"
      [ -n "$list" ] || list=$'none\n'
      printf '%s' "$list" ;;
  esac
} > "$tmp/prompt"

rc=0
timeout -k 10 540 codex exec -s read-only --ephemeral --output-schema "$tmp/schema.json" -o "$tmp/answer.json" - < "$tmp/prompt" > "$tmp/out" 2> "$tmp/err" || rc=$?

python3 -I - "$point" "$f" "$hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tmp/answer.json" "$rc" "$tmp/err" <<'PY'
import json, os, sys
point, f, h, ts, ans, rc, err = sys.argv[1:]
def clean(s):
    return s.replace("\r", " ").replace("\n", " ")
def record(v, lines):
    with open(f"{f}/advisor.md", "a", encoding="utf-8") as r:
        r.write("".join(l + "\n" for l in [f"## {point} | {ts} | sha256 {h} | {v}", *lines, ""]))
def blocked(reason):
    reason = clean(reason)
    record("BLOCKED", [f"reason: {reason}"])
    print(f"BLOCKED: {reason}\nrecord: {f}/advisor.md")
    sys.exit(1)
def answer():
    if rc in ("124", "137"):
        blocked("timed out")
    if rc != "0":
        lines = [l for l in open(err, "rb").read().decode("utf-8", "replace").split("\n") if l.strip()]
        errs = [l for l in lines if l.startswith("ERROR:")]
        blocked((errs or lines or [f"codex exited {rc}"])[-1])
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
    return a
a = answer()
v = a["verdict"]
summary = clean(a["summary"])
found = [f"- [{clean(x['severity'])}] {clean(x['location'])}: {clean(x['claim'])} Evidence: {clean(x['evidence'])}" for x in a["findings"]]
record(v, [f"summary: {summary}", *found])
head = [f"BLOCKED: {summary}"] if v == "BLOCKED" else [f"{v} sha256 {h}", f"summary: {summary}"]
print("\n".join(head + found + [f"record: {f}/advisor.md"]))
sys.exit(1 if v == "BLOCKED" else 0)
PY
