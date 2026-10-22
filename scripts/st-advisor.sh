#!/usr/bin/env bash
usage() { echo "usage: st-advisor.sh plan|test|diff|check|continued ..."; exit 2; }
point=${1:-}
case "$point:$#" in plan:2|test:6|diff:3) ;; *) usage ;; esac
f=${2%/}
[ -f "$f/spec.md" ] || usage
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

timeout -k 10 540 codex exec -s read-only --ephemeral --output-schema "$tmp/schema.json" -o "$tmp/answer.json" - < "$tmp/prompt" > "$tmp/out" 2> "$tmp/err"

python3 -I - "$point" "$f" "$hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tmp/answer.json" <<'PY'
import json, sys
point, f, h, ts, ans = sys.argv[1:]
a = json.loads(open(ans, "rb").read())
def clean(s):
    return s.replace("\r", " ").replace("\n", " ")
v = a["verdict"]
summary = clean(a["summary"])
found = [f"- [{clean(x['severity'])}] {clean(x['location'])}: {clean(x['claim'])} Evidence: {clean(x['evidence'])}" for x in a["findings"]]
with open(f"{f}/advisor.md", "a", encoding="utf-8") as r:
    r.write("".join(l + "\n" for l in [f"## {point} | {ts} | sha256 {h} | {v}", f"summary: {summary}", *found, ""]))
head = [f"BLOCKED: {summary}"] if v == "BLOCKED" else [f"{v} sha256 {h}", f"summary: {summary}"]
print("\n".join(head + found + [f"record: {f}/advisor.md"]))
sys.exit(1 if v == "BLOCKED" else 0)
PY
