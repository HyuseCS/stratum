#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

while IFS='|' read -r id file phrase; do
  check "$id" 'grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
A1|skills/st-build/SKILL.md|A `REVISE` with only MEDIUM and LOW findings counts as passed: handle each finding and do not run the point again.
A2|skills/st-build/SKILL.md|Run the point again only when a CRITICAL or HIGH fix changed the plan, or the plan's approach changed.
A3|skills/st-build/SKILL.md|The approach changed when a user story or task was added or removed, a file outside the plan's file list is now touched, or a design choice in `plan.md` was replaced. A fix inside a task's own text and files is not an approach change.
A4|skills/st-build/SKILL.md|Two rounds at most per point per gate pass, then the user decides.
A5|skills/st-inspect/SKILL.md|If the plan changed at Inspect only by fixes of findings, with no approach change, run `bash <plugin root>/scripts/st-advisor.sh waive plan <feature dir> "<reason>"` in place of the plan point.
A6|skills/st-inspect/SKILL.md|At "OK to build?", show the `WAIVED` line and its reason.
A7|skills/st-build/SKILL.md|`WAIVED sha256 <hash>`: the plan changed only by fixes, and `check plan` passes until the input changes again.
A8|skills/st-build/SKILL.md|Skip the end-of-Build advisor pass when every story had an `st-review` and no code changed after the last one.
A9|skills/st-build/SKILL.md|Otherwise run it once, on the changes after the last review only: `bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <last review sha>`.
A10|skills/st-build/SKILL.md|Note `git rev-parse HEAD` after each story's review fixes are committed: that is the story's review point.
A11|skills/st-build/SKILL.md|Then run `bash <plugin root>/scripts/st-advisor.sh count <feature dir>` and show its line word for word.
A12|skills/st-build/SKILL.md|After each `/advisor` call, run `bash <plugin root>/scripts/st-advisor.sh note <point> <feature dir> "<one-line summary>"`.
A13|skills/st-build/SKILL.md|`no change since <base>: skip`: nothing changed after the last review, so the pass is skipped.
TABLE

while IFS='|' read -r id file phrase; do
  check "$id gone" '! grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
G1|skills/st-build/SKILL.md|Then run the same point once more on the changed input.
G2|skills/st-build/SKILL.md|consult the advisor if one is set (`/advisor`) on the feature's full
TABLE

exit $fail
