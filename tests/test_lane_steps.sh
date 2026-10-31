#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
rows() {
  cur=""; ok=1
  while IFS=$'\t' read -r name mode file phrase; do
    if [ "$name" != "$cur" ]; then
      [ -n "$cur" ] && check "FR-027 $cur" "[ $ok = 1 ]"
      cur=$name; ok=1
    fi
    if [ "$mode" = gone ]; then
      for f in "$root"/$file; do
        [ -f "$f" ] && ! sed 's/\\`/`/g' "$f" | grep -qF -- "$phrase" || ok=0
      done
    else
      [ -f "$root/$file" ] && sed 's/\\`/`/g' "$root/$file" | grep -qF -- "$phrase" || ok=0
    fi
  done
  [ -n "$cur" ] && check "FR-027 $cur" "[ $ok = 1 ]"
}
rows <<'EOF'
row 1	gone	skills/st-worker/SKILL.md	pick the one-time yes
row 2	gone	skills/st-worker/SKILL.md	a tool permission for the task's own command
row 3	gone	skills/st-worker/SKILL.md	The build loop (/stratum:st-build) does not use workers.
row 4	gone	skills/st-build/SKILL.md	merge it into `main`
row 5	gone	skills/st-build/SKILL.md	consult the advisor if one is set (`/advisor`) on the feature's full
row 6	gone	skills/st-build/SKILL.md	It runs at two points
row 7	gone	skills/st-build/SKILL.md	Then run the same point once more on the changed input.
row 8	gone	skills/st-build/SKILL.md	The mode comes from `.stratum/advisor.json` (`codex`, `both` or `off`).
row 9	has	skills/st-build/SKILL.md	`WAIVED sha256 <hash>`: the plan changed only by fixes, and `check plan` passes until the input changes again.
row 10	has	skills/st-build/SKILL.md	A test marked `[lock]` runs only through the test lock: `bash <plugin root>/scripts/st-lock.sh -- <test command>`.
row 11	has	skills/st-inspect/SKILL.md	If the plan changed at Inspect only by fixes of findings, with no approach change, run `bash <plugin root>/scripts/st-advisor.sh waive plan <feature dir> "<reason>"` in place of the plan point.
row 12	gone	skills/st-plan/SKILL.md	then offer GitHub issues
row 12	gone	skills/*/SKILL.md	Make GitHub issues from the tasks?
row 13	has	skills/st-plan/SKILL.md	that every task names its exact test command (`Test:`), that every `[P]` task names the files it owns (`Owns:`) and no two `[P]` tasks in one phase own the same file, and that every `[screen]` task has its mode.
row 14	gone	skills/st-full/SKILL.md	(asks: make GitHub issues?)
row 15	has	skills/st/SKILL.md	Before the first lane skill or agent starts, Quick too, say it in one line: `Lane: <lane>, risk <level> (<area>: <why>). Say "full", "fast", "quick" or "design" to override. Say "risk high", "risk normal" or "risk low" to change the risk.`
row 16	has	skills/st/SKILL.md	Write each small decision in a list as you make it. At each story review, and at the end of a Fast change, the list goes to the advisors the matrix names. A decision an advisor sends to the user is undone if the user says no.
row 17	gone	skills/st/SKILL.md	or at the `st-plan` question
row 18	has	skills/st/SKILL.md	When the task names GitHub issue numbers (`#51` or an issue URL), run `/stratum:st-triage` on them first (Skill tool), show its short verdict per issue, then pick the lane.
row 19	has	skills/st-fast/SKILL.md	At the end of the change, send the small-decision list to `/advisor` if one is set. A decision it sends to the user is undone if the user says no.
row 20	has	skills/st-init/SKILL.md	advisor mode `auto` (recommended: the risk level picks Codex, `/advisor` or both at each point; needs `codex` logged in for Codex), `codex` (Codex reviews the plan and a test red after 2 tries), `both` (Codex, then `/advisor` if set), or `off` (no Codex, nothing sent to OpenAI)?
row 21	gone	skills/st-sync/SKILL.md	Run the tests in `tests/` and report the result.
row 22	gone	agents/st-build.md	Then run the other tests that cover the files you touched.
row 22	gone	agents/st-build.md	design brief
row 23	gone	agents/st-debug.md	then the other tests that cover the touched files.
row 24	has	agents/st-test.md	A test marked `[lock]` runs only through the test lock: `bash <plugin root>/scripts/st-lock.sh -- <test command>`.
row 25	gone	agents/st-plan.md	Mark tasks that touch no common file `[P]`.
row 26	gone	procedures/tasks.md	**[P] marker**: Include ONLY if task is parallelizable
row 27	gone	templates/tasks.md	- [P] tasks = different files, no dependencies
row 27	gone	templates/tasks.md	Can run in parallel (different files, no dependencies)
row 28	has	README.md	`{"mode": "auto"}` (the default when the file has no `mode`): the risk level picks the advisors at each point.
row 29	has	scripts/st-worker.sh	- Test lock: if your task is marked [lock], run its test command as `bash <plugin root>/scripts/st-lock.sh -- <test command>`, with the plugin root of the Stratum plugin. Never write a wait loop of your own.
EOF
exit $fail
