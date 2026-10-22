# 001 stale-validate

What: GitHub issue #27. A fix in Inspect step 2 that removes or renames a task, but is not CRITICAL,
leaves the old `## Validate` section in `plan.md` with findings that cite the removed task. Step 3 of
the skill gets a second rerun rule: after the step-2 fixes are committed, grep each task ID a fix
removed or renamed in the `## Validate` section of `plan.md`. Any hit means run `st-inspect` once more.
The agent already replaces the old section (V6) and is the one writer of it (FR-003), so no agent file changes.
FRs: FR-003 (Inspect agent writes `## Validate`), FR-005 (one agent, phases). The rerun rule is spec S4 (spec.md:150).
Impact area: core runtime (skill text, test, contract)

## Files
- `skills/st-inspect/SKILL.md:28` - step 3 keeps its sentence untouched (`If any CRITICAL finding was
  fixed, run `st-inspect` once more. It replaces its older `## Validate` section.`). Add one new line
  after it, indented 3 spaces like step 1, as its own sentence:
  ``If a fix removed or renamed a task, grep its ID in the `## Validate` section of `plan.md`; on any hit run `st-inspect` once more.``
  Whole on one line (P1). Do not splice words into the S4 sentence.
- `tests/test_inspect.sh:75` - in the skill heredoc, add after the S4 row a new row:
  `S7<TAB>skill<TAB>a fix removed or renamed a task`. A new S7 (not a second S4 phrase) so the
  negative control for S4 and for S7 each red only their own check (P2). The phrase is not a word
  every file holds (P3).
- `specs/002-merge-check-validate/contracts/st-inspect.md:114` - add a table row after S4:
  ``| S7 | `a fix removed or renamed a task` |``
- `specs/002-merge-check-validate/contracts/st-inspect.md:103-104` - the "rerun (S4)" bullet: name
  S7 too (`rerun (S4, S7)`). Check that the S7 row sits in the order the bullet lists.

No change: `agents/st-inspect.md`, `agents/st-plan.md`. st-plan must not edit `## Validate`.

For st-close drift fix (do not edit now): `specs/002-merge-check-validate/spec.md:93` (the CRITICAL
rerun scenario) and `spec.md:150` (S4 "After a CRITICAL fix, the agent runs once more") describe the
rerun rule. Both need the removed or renamed task case.

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
