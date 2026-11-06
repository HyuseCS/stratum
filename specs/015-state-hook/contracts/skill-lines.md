# Contract: the six skill lines (FR-009)

Each new line replaces only the old line or sentence named. Other lines in these files stay as
they are (another branch edits `skills/st/SKILL.md`, `skills/st-build/SKILL.md` and
`skills/st-worker/SKILL.md`). The phrase tests check these strings word for word.

| Id | File:line | New text |
|----|-----------|----------|
| L1 | `skills/st/SKILL.md:37` | ``Put the `Lane:` line at the start of its own line: the Stratum hook writes the risk from it. On the user's "risk <level>", say the `Lane:` line again with the new level.`` |
| L2 | `procedures/specify.md:41` | ``   - If `.stratum/state.json` does not exist, create `.stratum/` and write `{}` to it. While Define runs, the Stratum hook writes `feature_directory` to it once `spec.md` exists. Later procedures find the feature through this file.`` |
| L3 | `skills/st-close/SKILL.md:58` | ``   After the commit lands, say `Phase: done` on its own line: the Stratum hook sets `phase` to `done`.`` |
| L4 | `skills/st-fast/SKILL.md:41` | ``10. After the last commit lands (step 9, or step 6 when step 9 is skipped), say `Phase: done` on its own line: the Stratum hook sets `phase` to `done`.`` |
| L5 | `skills/st-build/SKILL.md:77` | ``Then say `Build done.` on its own line: the Stratum hook clears the reply label.`` |
| L6 | `skills/st-worker/SKILL.md:52` | ``When the run ends (after the last close or the headless run), say `Build done.` on its own line: the Stratum hook clears the reply label. Skip this when `/stratum:st-build` sent you here: st-build says it.`` |

Leading spaces in L2 and L3 keep the list indent of the old line.

## Phrase test rows

| Test | Row | Checks |
|------|-----|--------|
| `tests/test_state.sh` | S1 | L3 in `skills/st-close/SKILL.md` |
| | S2 | L4 in `skills/st-fast/SKILL.md` |
| | S3 | L1 in `skills/st/SKILL.md` |
| | S4 | L2 (from `write {}` on) in `procedures/specify.md` |
| | S5 | L5 in `skills/st-build/SKILL.md` |
| | S6 | L6 in `skills/st-worker/SKILL.md` |
| | S7 | `scripts/st-state.sh` does not exist |
| | S8 | no file under `skills/`, `procedures/`, `agents/`, `hooks/`, `scripts/` names `st-state.sh` |
| `tests/test_inspect.sh` | H2 st-close skill phase | L3 without its leading spaces |
| `tests/test_risk_rules.sh` | R3 | L1 |
| `tests/test_phase_hook.py` | `test_agents_write_done` | ``say `Phase: done` on its own line`` in st-close and st-fast SKILL.md; the st-quick agent row and the st-close agent negative row unchanged |
