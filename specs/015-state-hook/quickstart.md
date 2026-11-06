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

Expected: the first prints nothing. The second shows only reads of `state.json`, the `{}` start
line in `procedures/specify.md`, the file creation in `skills/st-init/SKILL.md:11`, and the
st-define line that says the hook records `feature_directory` (no instruction to write). These are
the SC-001 exceptions.

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
| subagent skip | drop the `agent_id` check | `test_risk_ignores_out_of_turn` |
| sidechain filter | drop the `isSidechain` check on assistant lines | `test_risk_ignores_out_of_turn` |
| line type filter | read `message.content` text of any line type (`api-request-blob` too) | `test_risk_ignores_out_of_turn` |
| Stop append | do not append `last_assistant_message` | `test_risk_at_stop_from_last_message`, `test_phase_done_marker` |
| `phase == define` | drop the phase check | `test_feature_directory_on_define` |
| higher number only | drop the compare with the current number | `test_feature_directory_on_define` |
| `define_floor` | drop the floor check (switch with no floor or at or below it) | `test_feature_directory_on_define` |
| folder name | loosen `^\d{3}-[a-z0-9-]+$` to `^\d{3}-` | `test_feature_directory_on_define` |
| whole-prompt match | `re.search` on the prompt | `test_risk_prompt` |
| main checkout path | write risk to the cwd file | `test_risk_goes_to_main_checkout` |
| missing main file | write the main file even when it is missing | `test_risk_goes_to_main_checkout` |

## Live check after merge

The session that builds this cannot load the new hook (spec Assumptions). After merge and a plugin
update, in a test project with `.stratum/state.json`, on both machines (PC and laptop):

1. Run `/stratum:st add a one-line note to README` and pick Fast. After the `Lane:` line and the
   `st-fast` planner agent, run `cat .stratum/state.json` yourself in a terminal: `risk` is `low`.
   The chat shows no command that writes `state.json`.
2. Send `risk high`. In the terminal: `risk` is `high`.
3. Finish the Fast run. The last reply has the line `Phase: done`. In the terminal: `phase` is `done`.
4. Run `/stratum:st-define` for a small feature. After `spec.md` exists: `feature_directory` names
   the new folder.
5. Run `/stratum:st-build` with no lane running, let it end with `Build done.`, then send `hi`: the
   reply has no `[st-build]` label.
