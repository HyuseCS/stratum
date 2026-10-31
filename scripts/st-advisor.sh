#!/usr/bin/env bash
set -o pipefail
usage() { echo "usage: st-advisor.sh plan|test|diff|decisions|round|check|continued|waive|note|talk|count ..."; exit 2; }
cmd=run
case ${1:-} in check|continued|waive|note|round|talk) cmd=$1; shift ;; count) cmd=count ;; esac
point=${1:-}
case "$cmd $point $#" in "run plan 2"|"run test 6"|"run diff 3"|"run decisions 3"|"round plan 4"|"round test 4"|"round diff 4"|"round decisions 4"|"check plan 2"|"continued plan 2"|"continued test 2"|"continued diff 2"|"continued decisions 2"|"waive plan 3"|"note plan 3"|"note test 3"|"note diff 3"|"note decisions 3"|"talk plan 3"|"talk test 3"|"talk diff 3"|"talk decisions 3"|"count count 2") ;; *) usage ;; esac
at=$point
label=$point
[ $cmd = round ] && { at=round; label="$point round $3"; }
f=${2%/}
[ -f "$f/spec.md" ] && [ -r "$f/spec.md" ] || usage
[ -L "$f/advisor.md" ] && usage
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [ $cmd = count ]; then
  src=/dev/null
  [ -e "$f/advisor.md" ] && src=$f/advisor.md
  awk '/^## .* \| sha256 [^ ]* \| (APPROVED|REVISE|BLOCKED)$/{a++} /^## .* \| sha256 [^ ]* \| WAIVED$/{b++} /^## .* \| \/advisor$/{c++} END{printf "advisor calls: codex %d, waived %d, /advisor %d\n", a, b, c}' "$src" || exit 1
  exit 0
fi
if [ $cmd = waive ] || [ $cmd = note ]; then
  text=${3//[$'\r\n']/ }
  [[ $text = *[![:space:]]* ]] || usage
fi
if [ $cmd = note ]; then
  { [ -s "$f/advisor.md" ] && echo; printf '## %s | %s | /advisor\nsummary: %s\n' "$point" "$ts" "$text"; } >> "$f/advisor.md" || exit 1
  echo "noted: $point /advisor"
  exit 0
fi
if [ $cmd = talk ]; then
  [ -f "$3" ] && [ -r "$3" ] || usage
  body=$(awk '{sub(/\r$/, ""); gsub(/\r/, " ")} /^rounds: /{r++; if ($0 !~ /^rounds: [1-3]$/) bad=1; n=substr($0, 9)} /^agreed: /{a++} /^compromises: /{c++} /^to user: /{u++} /^calls: /{k++; if ($0 !~ /^calls: [0-9]+$/) bad=1} /^(rounds|agreed|compromises|to user|calls): /{print} END{if (bad || r != 1 || a != 1 || c != 1 || u != 1 || k != 1) exit 1; print n}' "$3") || usage
  n=${body##*$'\n'}
  { [ -s "$f/advisor.md" ] && echo; printf '## %s talk | %s | %s rounds\n%s\n' "$point" "$ts" "$n" "${body%$'\n'*}"; } >> "$f/advisor.md" || exit 1
  echo "talk recorded: $point, $n rounds"
  exit 0
fi
if [ $cmd = check ] || [ $cmd = continued ]; then
  rec=$(grep -aE "^## $point \| [^|]* \| sha256 " "$f/advisor.md" 2>/dev/null | tail -n1)
  if [ -z "$rec" ]; then echo "no record: $point"; [ $cmd = check ] && exit 1; exit 2; fi
  rest=${rec#* | * | sha256 }
  rhash=${rest%% | *}
  if [ $cmd = continued ]; then
    { [ -s "$f/advisor.md" ] && echo; printf '## %s | %s | sha256 %s | BLOCKED, user continued\n' "$point" "$ts" "$rhash"; } >> "$f/advisor.md" || exit 1
    echo "BLOCKED, user continued sha256 $rhash"
    exit 0
  fi
fi
case $cmd-$point in
  round-*) [[ $3 =~ ^[1-3]$ ]] && [ -f "$4" ] && [ -r "$4" ] || usage ;;
  *-plan) [ -f "$f/plan.md" ] && [ -r "$f/plan.md" ] && [ -f "$f/tasks.md" ] && [ -r "$f/tasks.md" ] || usage ;;
  *-decisions) [ -f "$3" ] && [ -r "$3" ] || usage ;;
  *-test) [ -f "$3" ] && [ -r "$3" ] && [ -f "$5" ] && [ -r "$5" ] && [ -f "$6" ] && [ -r "$6" ] || usage ;;
  *-diff) git rev-parse --verify --quiet "$3^{commit}" >/dev/null || usage
    git diff --quiet "$3" HEAD --
    case $? in 0) echo "no change since $3: skip"; exit 0 ;; 1) ;; *) usage ;; esac ;;
esac
if [ $cmd = waive ]; then
  last=$(awk '/^## plan \| [^|]* \| sha256 /{sub(/^.* sha256 [^ ]* \| /, ""); v=$0; bad=0; r=1; next} /^## /{r=0} r && /^- / && !/^- \[(MEDIUM|LOW)\] /{bad=1} END{if (v != "") print v (bad ? " bad" : "")}' "$f/advisor.md" 2>/dev/null)
  case ${last:=none} in APPROVED|WAIVED|REVISE) ;; *) echo "nothing to waive: the last plan record is ${last% bad}"; exit 1 ;; esac
fi
bad=0 say=
if [ $cmd = run ]; then
  [ -e .stratum/advisor.json ] || { echo 'no advisor: mode not set. Write .stratum/advisor.json with "mode": "auto", "codex", "both" or "off".'; exit 0; }
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && sf=$(dirname "$common")/.stratum/state.json || sf=.stratum/state.json
  cfg=$(python3 -I - "$sf" <<'PY'
import json, re, sys
try:
    s = json.loads(open(".stratum/advisor.json", "rb").read())
except (OSError, ValueError, RecursionError):
    sys.exit(1)
if not (isinstance(s, dict) and set(s) <= {"mode", "model", "effort"} and all(isinstance(v, str) for v in s.values())
        and s.get("mode", "auto") in ("auto", "codex", "both", "off")
        and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}", s.get("model", "x"))
        and re.fullmatch(r"[a-z]{1,16}", s.get("effort", "x"))):
    sys.exit(1)
try:
    r = json.loads(open(sys.argv[1], "rb").read()).get("risk")
except (OSError, ValueError, RecursionError, AttributeError):
    r = None
print(s.get("mode", "auto"), s.get("model", ""), s.get("effort", ""), r if r in ("high", "normal", "low", "none") else "", sep="\n")
PY
) || bad=1
  if [ $bad = 0 ]; then
    { read -r mode; read -r model; read -r effort; read -r risk; } <<<"$cfg"
    [ $mode = off ] && { echo "no advisor: mode off"; exit 0; }
    if [ $mode = auto ]; then
      [ -n "$risk" ] || { echo "risk not set: normal"; risk=normal; }
      case $at-$risk in
        round-*) aset=codex ;;
        plan-high|decisions-high|diff-high) aset=both ;;
        *-none|plan-low) aset=none ;;
        *-low) aset=/advisor ;;
        *) aset=codex ;;
      esac
      say="advisors: $aset ($at, risk $risk)"
      case $aset in none|/advisor) echo "$say"; exit 0 ;; esac
    else
      case $at in diff|decisions) echo "advisors: /advisor (mode $mode)"; exit 0 ;; esac
      [ $mode = both ] && [ $at != round ] && echo "mode both: also consult /advisor if one is set"
    fi
    opts=()
    [ -n "$model" ] && opts+=(-m "$model")
    [ -n "$effort" ] && opts+=(-c "model_reasoning_effort=\"$effort\"")
    command -v codex >/dev/null || { echo "no advisor: codex not found"; exit 0; }
  fi
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

case $cmd-$point in
  round-*) hash=$(sha256sum < "$4") || { echo "cannot hash inputs"; exit 2; } ;;
  *-decisions) hash=$(sha256sum < "$3") || { echo "cannot hash inputs"; exit 2; } ;;
  *-plan) hash=$({ cat "$f/spec.md" && awk '/^```/{f=!f} !f&&/^## Validate$/{s=1;next} !f&&/^## /{s=0} !s' "$f/plan.md" && cat "$f/tasks.md"; } | sha256sum) || { echo "cannot hash inputs"; exit 2; } ;;
  *-test) hash=$(cat "$5" "$6" | sha256sum) || { echo "cannot hash inputs"; exit 2; } ;;
  *-diff) hash=$(git diff --no-ext-diff --no-color "$3" HEAD -- | sha256sum) || { echo "cannot hash inputs"; exit 2; } ;;
esac
hash=${hash%% *}
[[ $hash =~ ^[0-9a-f]{64}$ ]] || { echo "cannot hash inputs"; exit 2; }
if [ $cmd = check ]; then
  [ "$hash" = "$rhash" ] || { echo "advisor approval is stale"; exit 1; }
  echo "${rest#* | } sha256 $hash"
  exit 0
fi
if [ $cmd = waive ]; then
  { [ -s "$f/advisor.md" ] && echo; printf '## plan | %s | sha256 %s | WAIVED\nreason: %s\n' "$ts" "$hash" "$text"; } >> "$f/advisor.md" || exit 1
  printf 'WAIVED sha256 %s\nreason: %s\nrecord: %s/advisor.md\n' "$hash" "$text" "$f"
  exit 0
fi
block() {
  { [ -s "$f/advisor.md" ] && echo; printf '## %s | %s | sha256 %s | BLOCKED\nreason: %s\n' "$label" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hash" "$1"; } >> "$f/advisor.md" || exit 1
  printf 'BLOCKED: %s\nrecord: %s/advisor.md\n' "$1" "$f"
  exit 1
}
[ -n "${say:-}" ] && echo "$say"
[ $bad = 0 ] || block "bad advisor.json"
command -v timeout >/dev/null || block "timeout not found"

printf '%s\n' '{"type":"object","additionalProperties":false,"required":["verdict","summary","findings"],"properties":{"verdict":{"type":"string","enum":["APPROVED","REVISE","BLOCKED"]},"summary":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["claim","evidence","location","severity"],"properties":{"claim":{"type":"string"},"evidence":{"type":"string"},"location":{"type":"string"},"severity":{"type":"string","enum":["CRITICAL","HIGH","MEDIUM","LOW"]}}}}}}' > "$tmp/schema.json"

{
  printf '%s\n' \
    'You are a reviewer for Stratum. Review only: never create, change or delete a file, and never build or fix anything.' \
    'Read only the inputs named below and the files they cite. Never open .env files, keys, credentials, tokens or other secret files.' \
    'Never quote a secret value in a finding.' \
    'Answer with verdict APPROVED (nothing to fix), REVISE (findings to fix) or BLOCKED (you cannot review, or the work must stop). Each finding has a claim, the evidence, a location (file:line when known) and a severity.'
  case $cmd-$point in
    round-*)
      printf '%s\n' "Point: $point, round $3 of 3 of a talk with another advisor. The views so far are below. For each open point, agree, or keep your view and give the reason."
      [ "$3" = 3 ] && printf '%s\n' 'This is the last round. For every open point, propose a compromise aimed at the best result, one finding per compromise.'
      cat "$4" ;;
    *-decisions)
      printf '%s\n' 'Point: decisions. Below is the list of small decisions the orchestrator made. For each one, say whether it is fine. A finding with severity CRITICAL or HIGH means the decision must go to the user.'
      cat "$3" ;;
    *-diff)
      printf '%s\n' "Point: diff. Review the changes in git diff $3..HEAD (run it yourself): hidden regressions and broken rules of the project's constitution. Do not build or fix." ;;
    *-plan)
      printf '%s\n' \
        'Point: plan. Advise only on how the plan could be built better or done differently for a better outcome: a simpler or better approach, tasks to cut or merge. Do not check correctness, coverage or risks: the Inspect phase does that.' \
        "Inputs: $f/spec.md, $f/plan.md, $f/tasks.md" ;;
    *-test)
      printf '%s\n' 'Point: test. This task'"'"'s test is still red after two build tries. Root cause or rabbit hole?' "Test: $4" 'Task:' "$(cat "$3")" 'Failure output 1:' "$(cat "$5")" 'Failure output 2:' "$(cat "$6")" ;;
  esac
} > "$tmp/prompt"

rc=0
timeout -k 10 540 codex exec -s read-only --ignore-user-config "${opts[@]}" --ephemeral --output-schema "$tmp/schema.json" -o "$tmp/answer.json" - < "$tmp/prompt" > "$tmp/out" 2> "$tmp/err" || rc=$?

python3 -I - "$label" "$f" "$hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tmp/answer.json" "$rc" "$tmp/err" <<'PY'
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
