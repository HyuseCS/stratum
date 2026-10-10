#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
agent="${ST_INSPECT_AGENT:-$root/agents/st-inspect.md}"
skill="${ST_INSPECT_SKILL:-$root/skills/st-inspect/SKILL.md}"
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
S1	skill	git status --porcelain
S2	skill	drop the false ones
S2	skill	one at a time
S3	skill	Fixes to spec, plan or tasks go to the `st-plan` subagent
S3	skill	have `st-git` commit them
S4	skill	If any CRITICAL finding was fixed, run `st-inspect` once more
S6	skill	OK to build?
S6	skill	findings dropped
EOF
n=$(grep -cF '(`stratum:' "$skill")
check "one agent" '[ "$n" = 1 ]'

exit $fail
