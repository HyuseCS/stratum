#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() { if grep -qF -- "$3" "$root/$2"; then echo "ok   $1 $2"; else echo "FAIL $1 $2"; fail=1; fi; }

L1='A test marked `[lock]` runs only through the test lock: `bash <plugin root>/scripts/st-lock.sh -- <test command>`.'
L2='Never write a wait loop of your own. On a `lock:` timeout line, stop and report the line.'
L3='On a `lock:` timeout line from an agent, tell the user the line and the test that waits, in short words.'

for f in agents/st-test.md agents/st-build.md agents/st-debug.md skills/st-build/SKILL.md; do check L1 "$f" "$L1"; done
for f in agents/st-test.md agents/st-build.md agents/st-debug.md; do check L2 "$f" "$L2"; done
check L3 skills/st-build/SKILL.md "$L3"

exit $fail
