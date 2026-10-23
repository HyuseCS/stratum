# 001 codex-plan-only

What: Cut Codex calls. (1) The plan review moves from st-inspect to the end of st-plan, before the Plan gate. (2) st-fast uses `/advisor` only: no Codex, no mode, no record. (3) st-build keeps Codex at the test point. (4) The st-build diff point moves to `/advisor` (Q1 decided: branch B). Modes stay: `codex`, `both`, `off`; `both` = Codex at its points plus `/advisor`. Reason (D26): diff reviews cost about 37,000 tokens each and ran up to three rounds per feature (D19 to D21).
FRs: FR-001, FR-007, FR-009, FR-013, FR-016, FR-017 (and any text that names the points)
Impact area: core runtime

## Fixed edits (same in branch A and B)

- skills/st-plan/SKILL.md - new step 4 "Advisor", after Verify and before the commit step (commit becomes step 5, so fixes from Codex are committed): run `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>` from the project root, foreground, Bash timeout 600000 ms, wait. Codex reviews spec, plan and tasks (risks: missed auth invariants, schema or contract breaks, hidden breaking changes; improvements: simpler approach, tasks to cut or merge). Handle the answer as in "Advisor" in `<plugin root>/skills/st-build/SKILL.md`; big ones go to the user before the Plan gate. Step 5 commits `advisor.md` with the plan files. Fixes go back to the `st-plan` subagent and cost a round.
- skills/st-inspect/SKILL.md - remove step 4 (Codex run, with its "later re-run costs a round" line); old step 5 becomes 4. Gate keeps `check plan` and the "commit advisor.md if it changed" line. Verify the text "stale" still reads right: a plan changed by inspect fixes makes the approval stale, and the gate shows it.
- skills/st-build/SKILL.md "## Advisor" stays in st-build and is not moved. Reason: st-inspect already points there, the test rows point there, and a move would break both for no gain. Reword the intro (line 67): Codex runs at the plan point (run by `st-plan`, stale-checked by `st-inspect`), at the test point (a task red after 2 tries), and, branch A only, at the diff point. Add: "The Fast and Quick lanes have no Codex." Keep verdicts, rounds, modes, record, no-Codex path, `continued <point>`.
- skills/st-fast/SKILL.md - test point: "first if one is set (`/advisor`)", diff point: "If an advisor is set, consult it on the diff" (pre-#18 wording, `git show 932295b^1:skills/st-fast/SKILL.md`). Remove all `st-advisor.sh` calls (test, diff, check diff), the "Handle each advisor answer as in Advisor" line (23), and "with advisor.md if it changed" (29).
- skills/st-init/SKILL.md:62 - say Codex reviews the plan and a test still red after 2 tries (branch A adds "and the full diff"). Row "FR-015 init" is a prefix match and survives.
- README.md:161-168 - rewrite 161 to list the Codex points. "What leaves the machine": the prompt and the files it names; keep the test-point part (task text, test path, both failure outputs). Line 166 says "plan" (plus "or diff" in A). Fast lane: `/advisor` only.
- specs/006-codex-advisor/{spec.md, data-model.md, quickstart.md, checklists/requirements.md, contracts/advisor.md} - FR-001, FR-007, FR-009, FR-016, FR-017, success criteria and quickstart sections 2-4: plan review runs in st-plan; st-fast has no Codex. Contract section 7 (skill text): move the st-inspect step 4 text to st-plan, drop the st-fast text, keep section "Advisor" in st-build. Contract section 8 mirrors the phrase rows (rule P1): keep in step with the test rows below.
- specs/006-codex-advisor/decisions.md - add D26 (user, 2026-10-23): the Codex plan review moves to the end of st-plan; st-fast is `/advisor` only; Codex stays at the plan point and the st-build test point; the diff point decision as the user gives it (Q1). Reason: cost as above. Rejected: keep Codex in st-fast (the Fast lane is meant to be cheap).
- scripts/st-advisor.sh and tests/test_advisor.sh - no change for st-fast (it never ran in the script). `test` form, `check plan`, `continued plan|test` stay.
- docs/lessons.md - no change.

## Q1 DECIDED: st-build diff point (user, 2026-10-23: branch B)

The user picked branch B. Branch A stays below as the rejected option.

Branch A (keep Codex diff in st-build):
- Script, test_advisor.sh, data-model.md, contract sections 1, 2, 4, 6 keep the diff form, the untracked-file filter, the diff hash. FR-013 stays.
- st-build keeps the diff point and `check diff` lines and "advisor.md if it changed" in the end-of-build line.
- Only st-fast loses diff (fixed edits above).

Branch B (diff point to `/advisor`):
- st-build lines 58-61: diff point reads "consult the advisor if one is set (`/advisor`)" (pre-#18 wording); drop `st-advisor.sh diff`, `check diff`, and the advisor.md commit part of the end-of-build line.
- scripts/st-advisor.sh: usage becomes `plan|test|check|continued`; the `case "$cmd $point $#"` loses the diff, check diff and continued diff forms; remove the diff arms, `rules`, `$tmp/untracked`, the `shopt nocasematch` list, the `:(exclude,icase)` pathspec string, the diff hash. Keep pipefail (plan hash is `cat | sha256sum`), tmp, the timeout check. Contract section 1 quotes the usage line exactly.
- tests/test_advisor.sh: remove the diff-point checks, untracked-filter and diff-hash checks and orphans (`gitc`, `short`, second `x = 2` commit, `first` if unused). Keep the proj git init. "continued without a record" switches from `diff specs/002-empty` to `plan`.
- data-model.md lines 76, 90-101, spec lines 106-107, FR-013 (removed or marked superseded, supersedes D25), contract sections 1, 2, 4, 6, 8, README line 168 and the "or diff" text.
- test row "FR-001 build diff point" and "FR-008 stale build" removed.

## Tests (written first, must fail before the build)

- tests/test_on_demand.sh - new rows (red now), all branches:
  - st-plan contains `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>`, "in the foreground, with a Bash timeout of 600000 ms", and "Handle" + `"Advisor" in` the st-build path.
  - st-inspect does NOT contain `st-advisor.sh plan <feature dir>` (the run), but still contains `check plan <feature dir>`.
  - st-fast does NOT contain `st-advisor.sh`.
  - st-fast contains `advisor is set, consult it on the diff: hidden regressions? Handle its notes like findings.`
  - Branch B only: st-build does not contain `st-advisor.sh diff`.
  Command: `bash tests/test_on_demand.sh`
- tests/test_on_demand.sh existing #18 rows (edit in the same step as the skill edits):
  - "FR-001 inspect plan point", "FR-002 wait inspect", "FR-016 inspect rules": change file to skills/st-plan/SKILL.md.
  - "inspect keep" (`; big ones go to the user before the gate.`): it sits on the removed step 4; move it to st-plan with the new wording.
  - "FR-008 stale inspect", "L18 commit inspect": stay on st-inspect.
  - "FR-001 fast test point", "FR-001 fast diff point", "FR-002 wait fast", "FR-008 stale fast", "FR-016 fast rules", "L18 commit fast": delete (st-fast has no Codex).
  - "FR-016 readme" row "An approval of a plan or diff that changed since then is stale." and "FR-013 readme": follow the README (branch).
  - Build rows for test point, "FR-001 build worktree*", "L19 debug worktree": stay.
  - Contract section 8 mirrors these changes.
- Line 254 check ("FR-016 old advisor text gone"): the st-fast clauses ("first if one is set (`/advisor`)", "advisor is set, consult it on the diff") would go red once st-fast gets the pre-#18 wording back (see F1). Branch B also turns the st-build clause red.
- tests/test_advisor.sh - no red test for branch A (script unchanged). Branch B: in `badargs`, change `diff ...` to well-formed args (valid commit) and add `check diff`, `continued diff`; assert `usage: st-advisor.sh` first line, exit 2, no argv file, no record. Red now, green after the script change. `bash tests/test_advisor.sh`

## Findings

- F1 (DECIDED: option 1, user, 2026-10-23; tests/test_on_demand.sh:254): restored pre-#18 wording in st-fast (and in st-build, branch B) fails the "old text gone" check. Option 1: drop the st-fast and st-build clauses, keep the st-inspect clause. Option 2: reword the restored text to avoid the old phrases. Recommend 1: the old wording is wanted again, option 2 makes the wording differ for no gain, and the st-inspect clause still guards that the Codex plan point has no `/advisor` fallback. Rename the row "st-inspect old advisor text gone".
- F2: st-plan now runs Codex before its commit step and before the Plan gate. A Codex fix to plan.md or tasks.md after `st-inspect` makes the approval stale; the `check plan` at the build gate catches it. No change to the script (the plan hash covers spec, plan and tasks).
- F3: FR-013 (secret filter) goes with branch B (Q1). Its prompt rules stay; the diff-point filter goes (D26).
- F4: existing records in `specs/006-codex-advisor/advisor.md` stay as history.
- F5: report new `ok` counts for both test files after the build (baseline test_advisor.sh 93 ok).
