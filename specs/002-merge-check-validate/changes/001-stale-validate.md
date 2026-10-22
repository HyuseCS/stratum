# 001 stale-validate

What: GitHub issue #27. A fix in Inspect step 2 that removes or renames a task, but is not CRITICAL,
leaves the old `## Validate` section in `plan.md` with findings that cite the removed task. The skill
gets a new step 5 (before the gate): if a fix in step 2 or 4 removed or renamed a task, grep each old ID
from the fix's diff of `tasks.md` in the `## Validate` section of `plan.md`. Any hit means run `st-inspect` once more.
The agent already replaces the old section (V6) and is the one writer of it (FR-003), so no agent file changes.
FRs: FR-003 (Inspect agent writes `## Validate`), FR-005 (one agent, phases). The rerun rule is spec S4 and S7 (spec.md:152).
Impact area: core runtime (skill text, test, contract)

## Files
- `skills/st-inspect/SKILL.md:34` - step 3 stays untouched. New step 5 after step 4, one line (P1):
  ``If a fix removed or renamed a task in step 2 or 4, grep each old ID from the fix's diff of `tasks.md` in the `## Validate` section of `plan.md`; on any hit run `st-inspect` once more.``
- `tests/test_inspect.sh:80` - in the skill heredoc, add after the S5 rows a new row:
  `S7<TAB>skill<TAB>a fix removed or renamed a task`. A new S7 (not a second S4 phrase) so the
  negative control for S4 and for S7 each red only their own check (P2). The phrase is not a word
  every file holds (P3).
- `specs/002-merge-check-validate/contracts/st-inspect.md:116` - add a table row after S5:
  ``| S7 | `a fix removed or renamed a task` |``
- `specs/002-merge-check-validate/contracts/st-inspect.md:103-104` - the "rerun (S4)" bullet reads
  `the rerun (S4), the advisor (S5), the task rerun (S7)`. The S7 row sits after S5, as the bullet lists.

No change: `agents/st-inspect.md`, `agents/st-plan.md`. st-plan must not edit `## Validate`.

Drift fixed at close: `specs/002-merge-check-validate/spec.md:95` (edge case) and `spec.md:152` (S4, S7)
now name the removed or renamed task case.

## Tests (written first, must fail before the build)
- `tests/test_inspect.sh` - new heredoc row S7 runs the skill phrase check on
  `skills/st-inspect/SKILL.md`. Red before the build: the phrase is not there. Run now (before
  any edit): exit 0, all `ok`, including "statusline test passes under LC_ALL=C" (the test runs
  `tests/test_statusline.sh` too). Command: `bash /home/hyuse/Desktop/stratum-27/tests/test_inspect.sh`
- Negative control: after the build, delete the new SKILL.md line once, run the command, see only
  S7 go red (S4 stays ok), restore the line. Repeat for the S4 sentence: only S4 reds.

## Risks
- The rule depends on the orchestrator knowing which task IDs a fix removed or renamed. It reads them
  from the st-plan subagent's diff of `tasks.md` and `plan.md`. A fix that renames without telling is missed.
- A grep hit on a finding already marked closed also triggers a rerun. One extra agent run, no harm.
- The test checks that the phrase exists, not that the orchestrator follows it. Same limit as S1 to S6.
