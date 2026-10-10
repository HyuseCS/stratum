#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
agent="${ST_INSPECT_AGENT:-$root/agents/st-inspect.md}"
skill="${ST_INSPECT_SKILL:-$root/skills/st-inspect/SKILL.md}"
readme="${ST_INSPECT_README:-$root/README.md}"
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
report() { if [ "$ok" = 1 ]; then echo "ok   $cur"; else echo "FAIL $cur"; fail=1; fi; }
phrases() {
  cur=""; ok=1
  while IFS=$'\t' read -r name target phrase; do
    if [ "$name" != "$cur" ]; then
      [ -n "$cur" ] && report
      cur=$name; ok=1
    fi
    case $target in
      agent) f=$agent ;;
      skill) f=$skill ;;
      readme) f=$readme ;;
      *) f=$root/$target ;;
    esac
    grep -qF -- "$phrase" "$f" || ok=0
  done
  report
}

check "agent frontmatter" 'grep -qx "name: st-inspect" "$agent" && grep -qx "tools: Read, Grep, Glob, Bash, Edit" "$agent" && grep -qx "model: opus" "$agent"'
phrases <<'EOF'
C1	agent	Duplicate requirements
C2	agent	Vague words with no measure
C2	agent	leftover placeholders
C3	agent	a story with no acceptance criteria
C3	agent	a task naming a file the spec and plan never define
C4	agent	Any break of a constitution MUST rule is CRITICAL
C5	agent	a requirement with no task
C5	agent	a task with no requirement
C5	agent	a success criterion with no task
C6	agent	one concept with two names
C6	agent	conflicting requirements
C7	agent	a test task placed after its build task
C7	agent	`[P]` tasks that touch the same file
C8	agent	Severity: critical, high, medium, low
C9	agent	Coverage line: requirements covered by tasks / total, by tests / total
C10	agent	Offer each fix, never apply it
C10	agent	needs a user decision
V1	agent	Do not install anything
V1	agent	read-only commands
V2	agent	a named test that can fail
V2	agent	the test command and its runner exist
V3	agent	Name each caller that breaks
V3	agent	Migrations need a rollback note
V4	agent	minors' data
V4	agent	Secrets never in code or git
V5	agent	PASS, CONCERN or FAIL
V5	agent	Any FAIL means BLOCKED. Only CONCERNs means CONDITIONAL.
V6	agent	replace an older `## Validate` section
V6	agent	Date: YYYY-MM-DD. Verdict: PASS | CONDITIONAL | BLOCKED
FR-003	agent	Edit anything except the `## Validate` section of `plan.md`
FR-003	agent	Install packages, run migrations, or change config
FR-003	agent	Run `git add` or `git commit`
FR-004	agent	Line 1: the net verdict (PASS, CONDITIONAL, BLOCKED) and counts
FR-004	agent	the per-check verdict (PASS, CONCERN, FAIL) of each validate check
EOF
check "skill frontmatter" 'grep -qx "name: st-inspect" "$skill"'
phrases <<'EOF'
FR-005	skill	Set `phase` to `inspect`
FR-005	skill	`phase` should be `plan` or `inspect`
FR-005	skill	Start the `st-inspect` subagent (`stratum:st-inspect`)
S1	skill	only `plan.md` may change
S1	skill	touches only its `## Validate` section
S1	skill	Note `git status --porcelain`
S2	skill	drop the false ones
S2	skill	one at a time
S3	skill	Fixes to spec, plan or tasks go to the `st-plan` subagent
S3	skill	have `st-git` commit them
S4	skill	If any CRITICAL finding was fixed, run `st-inspect` once more
S5	skill	a simpler or better approach
S5	skill	tasks to cut or merge
S5	skill	missed auth invariants
S5	skill	big ones go to the user before the gate
S6	skill	OK to build?
S6	skill	findings dropped
EOF
n=$(grep -cF '(`stratum:' "$skill")
check "one agent" '[ "$n" = 1 ]'

(cd "$root" && git grep -qwE 'st-(check|validate)' -- . ':!specs'); old_rc=$?
check "old names gone" '[ "$old_rc" = 1 ]'
count=$(ls "$root/agents" | grep -c '\.md$')
check "10 agents" '[ "$count" = 10 ]'
phrases <<'EOF'
rename skills/st/SKILL.md:32	skills/st/SKILL.md	`/stratum:st-plan`, `/stratum:st-inspect`, `/stratum:st-build`
rename skills/st-full/SKILL.md:12	skills/st-full/SKILL.md	3. `/stratum:st-inspect` (gate: user OKs the build)
rename skills/st-plan/SKILL.md:35	skills/st-plan/SKILL.md	Next phase: `/stratum:st-inspect`.
rename skills/st-build/SKILL.md:16	skills/st-build/SKILL.md	`phase` should be `inspect` or `build`
rename skills/st-status/SKILL.md:13	skills/st-status/SKILL.md	Inspect → "you OK the
rename skills/st-status/SKILL.md:37	skills/st-status/SKILL.md	stratum:st-inspect
rename skills/st-model/SKILL.md:35	skills/st-model/SKILL.md	stratum:st-inspect
rename skills/st-init/SKILL.md:26	skills/st-init/SKILL.md	Show a table of the 10 agents
rename tests/test_model_files.sh:31	tests/test_model_files.sh	stratum:st-inspect
rename README.md:75	README.md	| 3 | Inspect | `st-inspect` checks the files agree and the plan can be built | You OK the build |
rename README.md:90	README.md	`st-define`, `st-plan`, `st-inspect`, `st-build`, `st-close`
rename README.md:114-115	README.md	| `st-inspect` | Opus | Spec, plan, and tasks agree; setup, test coverage, breaking changes, security |
rename README.md:171-172	README.md	`st-inspect` and `st-review` have no entry and keep the plugin default
rename README.md:259	README.md	bash tests/test_inspect.sh
rename DESIGN.md:59-60	DESIGN.md	| `st-inspect` | Spec Kit analyze + vc validate | Opus | No | Spec, plan and tasks agree, and the plan is buildable: setup, test coverage, breaking changes, security. |
rename DESIGN.md:82	DESIGN.md	`st-define`, `st-plan`, `st-inspect`, `st-build`, `st-close`
rename DESIGN.md:119	DESIGN.md	| 3 | Inspect (`st-inspect`) | analyze and validate in one pass. Findings that need a decision go to the user. | User OKs the build |
EOF
d=$(grep -m1 "^description:" "$root/skills/st-full/SKILL.md")
check "rename skills/st-full/SKILL.md:3" 'grep -qF -- "Full lane (Define, Plan, Inspect, Build, Close)" <<<"$d"'
miss=""
for d in "$root"/skills/*/; do
  n=$(basename "$d"); [ -f "$d/SKILL.md" ] || continue
  case $n in st-ponytail-*) p="-${n#st-ponytail-}" ;; *) p=$n ;; esac
  grep -qF -e "\`$n\`" -e "\`$n " -e "\`$p\`" "$readme" || miss="$miss $n"
done
check "README skills" '[ -z "$miss" ]'
miss=""
for f in "$root"/agents/*.md; do
  a=$(basename "$f" .md); m=$(sed -n 's/^model: //p' "$f")
  m="$(echo "${m:0:1}" | tr a-z A-Z)${m:1}"
  grep -qF -- "| \`$a\` | $m |" "$readme" || miss="$miss $a"
done
check "README agents" '[ -z "$miss" ]'
miss=""
while read -r t; do
  [ -e "$root/$t" ] || miss="$miss $t"
done < <({ grep -oE '`(agents|hooks|licenses|procedures|scripts|skills|statusline|templates|tests)/[^` ]*`|`vendor\.lock`' "$readme"; grep -oE '\]\([^)]*\.md\)' "$readme"; } | tr -d '`' | sed -E 's/^\]\((.*)\)$/\1/')
check "README paths" '[ -z "$miss" ]'
miss=""
while read -r t; do
  [ -e "$root/$t" ] || miss="$miss $t"
done < <(grep -oE 'tests/[A-Za-z0-9_.-]*[A-Za-z0-9_]' "$readme")
for f in "$root"/tests/test_*; do
  grep -qF -- "tests/$(basename "$f")" "$readme" || miss="$miss $(basename "$f")"
done
check "README tests" '[ -z "$miss" ]'
miss=""
keys=$(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))))' "$root/statusline/themes.json")
for k in $keys; do grep -qF -- "\`$k\`" "$readme" || miss="$miss $k"; done
check "README themes" '[ -n "$keys" ] && [ -z "$miss" ]'
miss=""
keys=$(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["userConfig"]))' "$root/.claude-plugin/plugin.json")
for k in $keys; do grep -qF -- "\`$k\`" "$readme" || miss="$miss $k"; done
check "README git guard" '[ -n "$keys" ] && [ -z "$miss" ]'
phrases <<'EOF'
README st-status	readme	missing tools, duplicate installs, days since the last upstream sync, model overrides
README st-init	readme	asks for the git guard modes and any model overrides
README st-init	readme	writes the `AGENTS.md` and `CLAUDE.md` pointers
README python3	readme	git guard, model overrides hook, statusline, handoff facts
EOF

exit $fail
