#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
S1='Test scope: run the tests of the changed files and of the files that import them (find the importers with grep). Never run the full test suite unless the user asks in their own words.'
S2='If the change touches shared config, test setup, a schema or migration, middleware, or a file more than 20 files import, run no other tests and report `Needs a test choice: <why>`.'
S3='On `Needs a test choice: <why>`, ask the user: say why in short words, and offer a named list of tests or the full suite.'
S4='Every task names its exact test command. No task runs the full test suite.'
S5='Every task ends with `Test:` and its exact test command. No task runs the full test suite.'
S6='7. Run the tests that check the ported files (grep `tests/` for each changed path) and report the result. Run every test in `tests/` only when the user asks in their own words. Push only on the user'\''s "push".'
G1='Then run the other tests that cover the files you touched.'
G2='then the other tests that cover the touched files.'
G3='Run the tests in `tests/` and report the result.'
suite_lines() {
  grep -inE 'full (test )?suite' "$root"/skills/*/SKILL.md "$root"/agents/*.md "$root"/procedures/*.md "$root"/templates/*.md | grep -vE '/skills/st-(hallmark|impeccable|ui-ux)/SKILL\.md:'
}
suite_bad() {
  suite_lines | while IFS= read -r l; do
    case "$l" in *"$S1"*|*"$S3"*|*"$S4"*|*"$S5"*|*'Do not run the full suite'*) ;; *) echo "$l" ;; esac
  done
}
check "S1 agents/st-build.md" 'grep -qF -- "$S1" "$root/agents/st-build.md"'
check "S1 agents/st-debug.md" 'grep -qF -- "$S1" "$root/agents/st-debug.md"'
check "S2 agents/st-build.md" 'grep -qF -- "$S2" "$root/agents/st-build.md"'
check "S2 agents/st-debug.md" 'grep -qF -- "$S2" "$root/agents/st-debug.md"'
check "S3 skills/st/SKILL.md" 'grep -qF -- "$S3" "$root/skills/st/SKILL.md"'
check "S4 agents/st-plan.md" 'grep -qF -- "$S4" "$root/agents/st-plan.md"'
check "S5 procedures/tasks.md" 'grep -qF -- "$S5" "$root/procedures/tasks.md"'
check "S6 skills/st-sync/SKILL.md" 'grep -qF -- "$S6" "$root/skills/st-sync/SKILL.md"'
check "gone G1 agents/st-build.md" '[ "$(grep -cF -- "$G1" "$root/agents/st-build.md")" = 0 ]'
check "gone G2 agents/st-debug.md" '[ "$(grep -cF -- "$G2" "$root/agents/st-debug.md")" = 0 ]'
check "gone G3 skills/st-sync/SKILL.md" '[ "$(grep -cF -- "$G3" "$root/skills/st-sync/SKILL.md")" = 0 ]'
check "repo rule: every full suite line holds S1, S3, S4, S5 or Do not run the full suite" '[ -z "$(suite_bad)" ]'
exit $fail
