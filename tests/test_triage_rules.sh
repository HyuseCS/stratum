#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
report() { if [ "$ok" = 1 ]; then echo "ok   $cur"; else echo "FAIL $cur"; fail=1; fi; }
phrases() {
  cur=""; ok=1
  while IFS=$'\t' read -r name target phrase; do
    if [ "$name" != "$cur" ]; then
      [ -n "$cur" ] && report
      cur=$name; ok=1
    fi
    grep -qF -- "$phrase" "$root/$target" || ok=0
  done
  report
}

phrases <<'EOF'
TP1	skills/st/SKILL.md	When the task names GitHub issue numbers (`#51` or an issue URL), run `/stratum:st-triage` on them first (Skill tool), show its short verdict per issue, then pick the lane.
TP2	skills/st/SKILL.md	Make a GitHub issue only when the user asks in their own words.
TP3	skills/st-plan/SKILL.md	description: Full-lane Plan phase. Start the st-plan subagent for plan and tasks, and grill the user on its open decisions.
TP4	skills/st-full/SKILL.md	2. `/stratum:st-plan` (gate: the user answers its open decisions)
keep st-inspect	skills/st-plan/SKILL.md	Next phase: `/stratum:st-inspect`.
EOF

check "gone issue question" '[ -z "$(grep -lF -- "Make GitHub issues from the tasks?" "$root"/skills/*/SKILL.md)" ]'
check "gone st-plan question" '! grep -qF -- "or at the \`st-plan\` question" "$root/skills/st/SKILL.md"'
check "gone offer issues" '! grep -qF -- "then offer GitHub issues" "$root/skills/st-plan/SKILL.md"'
check "gone asks issues" '! grep -qF -- "(asks: make GitHub issues?)" "$root/skills/st-full/SKILL.md"'

exit $fail
