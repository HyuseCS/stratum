# Quickstart: State writes from the hook only

Run from the repo root.

## Automated checks

```bash
python3 tests/test_phase_hook.py
python3 tests/test_model_hook.py
bash tests/test_state.sh
bash tests/test_inspect.sh
bash tests/test_risk_rules.sh
```

Expected: every file exits 0. `test_phase_hook.py` covers the four writes and their negative
controls (see [data-model.md](data-model.md)); `test_model_hook.py` proves the `Agent` wiring of
`st-models.py` still stands.

SC-001 check:

```bash
grep -rn 'st-state' skills procedures agents hooks scripts
grep -rn 'state\.json' skills procedures
```

Expected: the first prints nothing. The second prints reads of `state.json`, the st-define line that
says the hook records `feature_directory` (no instruction to write), the `{}` start line in
`procedures/specify.md:41`, the file creation in `skills/st-init/SKILL.md:11`, the st-init commit
list at `skills/st-init/SKILL.md:87` (a file name in a commit list, no write), and lines about other
tools' `state.json` files (st-impeccable). Only the `{}` start line and the file creation are SC-001
exceptions that write `.stratum/state.json`.

## Negative controls (SC-003)

For each guard, break it in `hooks/st-phase.py`, run the named test, see it fail, then undo the edit
with the Edit tool (never `git checkout`):

| Guard | Break | Test that must fail |
|-------|-------|---------------------|
| turn start | read the whole file, no stop at the last real prompt | `test_risk_ignores_out_of_turn` |
| reply text only | read `text` from `user` lines too | `test_risk_ignores_out_of_turn` |
| line start / whole line | `re.search` without `^`/`$` anchors | `test_phase_done_marker` |
| prefix is only a label and a bullet (D1) | replace the `PRE` group with `^.*` | `test_lane_marker_forms`, `test_done_marker_forms` |
| whole line after the prefix (D1) | drop the `[ \t]*$` end on `Phase: done` and `Build done` | `test_done_marker_forms` |
| reply text of another prompt | at the `promptId` stop, return all collected text, not only the text after the last line of this `prompt_id` | `test_turn_stops_at_other_prompt_id` |
| this prompt's reply after its tool result | never move the mark at a `user` line of this `prompt_id` | `test_turn_stops_at_other_prompt_id` |
| subagent skip | drop the `agent_id` check | `test_risk_ignores_out_of_turn` |
| sidechain filter | drop the `isSidechain` check on assistant lines | `test_risk_ignores_out_of_turn` |
| line type filter | read `message.content` text of any line type (`api-request-blob` too) | `test_risk_ignores_out_of_turn` |
| Stop append | do not append `last_assistant_message` | `test_risk_at_stop_from_last_message`, `test_phase_done_marker` |
| `phase == define` | drop the phase check | `test_feature_directory_on_define` |
| list needed | scan when `define_before` is missing (the redo row) | `test_feature_directory_on_define` |
| not in the list | drop the `not in define_before` check (an old folder counts as new) | `test_feature_directory_on_define` |
| name rule | drop the `[A-Za-z0-9._-]+` full match (an `x$(y)` folder counts) | `test_feature_directory_on_define` |
| `spec.md` needed | count a new folder with no `spec.md` | `test_feature_directory_on_define` |
| list removal | keep `define_before` after the switch (a later folder switches again) | `test_feature_directory_on_define` |
| whole-prompt match | `re.search` on the prompt | `test_risk_prompt` |
| main checkout path | write risk to the cwd file | `test_risk_goes_to_main_checkout` |
| missing main file | write the main file even when it is missing | `test_risk_goes_to_main_checkout` |

## Live check after merge

The session that builds this cannot load the new hook (spec Assumptions). After merge and a plugin
update, in a test project with `.stratum/state.json`, on both machines (PC and laptop):

1. Run `/stratum:st add a one-line note to README` and pick Fast. After the `Lane:` line and the
   `st-fast` planner agent, run `cat .stratum/state.json` yourself in a terminal: `risk` is `low`.
   The chat shows no command that writes `state.json`. At step 2 of the Fast run, the `advisors:` line
   that `st-advisor.sh change` prints reads `advisors: none (change, risk low)`. This needs mode `auto`
   in `.stratum/advisor.json` (or no file). A line that says `risk not set` means the risk did not land.
2. Send `risk high`. In the terminal: `risk` is `high`.
3. Finish the Fast run. The last reply has the line `Phase: done`. In the terminal: `phase` is `done`.
4. Run `/stratum:st-define` for a small feature. After `spec.md` exists: `feature_directory` names
   the new folder.
5. Run `/stratum:st-build` with no lane running, let it end with `Build done.`, then send `hi`: the
   reply has no `[st-build]` label.
