#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

while IFS='|' read -r id file phrase; do
  check "$id $file" 'grep -qF -- "$phrase" "$root/$file"'
done <<'ROWS'
DL1|agents/st-plan.md|Mark each task that makes a page or view the app does not have yet `[screen]` (not a new part of an existing page, not a dialog). Return each one as an open decision: its Design lane mode, A: autonomous (existing look), B: new look. Offer custom design as a third option only when `skills/st-design/SKILL.md` names a custom mode. After the answer, write the mode in the task line: `[screen: autonomous]` or `[screen: new look]`.
DL2|agents/st-plan.md|Mark `[P]` every task that shares no file with another task in its phase and needs no other task's result. Each `[P]` task ends with `Owns:` and the files it owns. No two `[P]` tasks in one phase own the same file. Say in Dependencies which user stories share no files: those run at the same time. Mark `[lock]` each test that cannot run at the same time as another.
DL3|procedures/tasks.md|**[P] marker**: every task that shares no file with another task in its phase and needs no other task's result. It ends with `Owns:` and the files it owns. No two `[P]` tasks in one phase own the same file.
DL4|procedures/tasks.md|**[lock] marker**: a test that cannot run at the same time as another. Build runs it through `scripts/st-lock.sh`.
DL5|procedures/tasks.md|**[screen: <mode>] marker**: a task that makes a page or view the app does not have yet, with its Design lane mode.
DL6|templates/tasks.md|- **[lock]**: Test that cannot run at the same time as another; it runs through the test lock
DL7|templates/tasks.md|- **[screen: <mode>]**: New screen; Build sends it to the Design lane in that mode
DL8|templates/tasks.md|- [P] tasks = no shared file in the phase and no other task's result; each names the files it owns (`Owns:`)
DL9|skills/st-plan/SKILL.md|that every task names its exact test command (`Test:`), that every `[P]` task names the files it owns (`Owns:`) and no two `[P]` tasks in one phase own the same file, and that every `[screen]` task has its mode.
DL10|skills/st-plan/SKILL.md|A `[screen]` task's Design lane mode is an open decision like the others: the user picks autonomous or new look, and custom design only when `skills/st-design/SKILL.md` names a custom mode.
DL18|templates/tasks.md|- **[P]**: Can run in parallel: no shared file in the phase and no other task's result; the task ends with `Owns:`
ROWS

while IFS='|' read -r file phrase; do
  check "Gone $file $phrase" '[ -f "$root/$file" ] && ! grep -qF -- "$phrase" "$root/$file"'
done <<'ROWS'
agents/st-plan.md|Mark tasks that touch no common file `[P]`.
procedures/tasks.md|**[P] marker**: Include ONLY if task is parallelizable
templates/tasks.md|- [P] tasks = different files, no dependencies
templates/tasks.md|Can run in parallel (different files, no dependencies)
ROWS

exit $fail
