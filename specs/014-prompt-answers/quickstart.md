# Quickstart: validate the prompt-answer rules

No live herdr run (D2). Every check is a stub test or a text-rule row. Run from the repo root.

## Baseline (before T001)

All green on 2026-11-06 at `efab5fd`:

```bash
bash tests/test_worker_rules.sh; bash tests/test_lane_steps.sh; bash tests/test_advisor_rules.sh; bash tests/test_on_demand.sh; bash tests/test_st_worker.sh
```

## US1: a worker's permission dialog in normal mode

1. `bash tests/test_st_worker.sh`: AN1 to AN13, with AN6e, AN9b and AN11b, print `ok`. The cases are in `contracts/answer.md` section 4.
   - AN9: `wait` prints a `screen` line for a permission dialog, and none for a question. AN9b: the hash is of the printed pane text, 40 lines.
   - AN5, AN5b and AN10: with the hash from that line, key 1 is sent for each one-time yes form.
   - AN6 to AN6f and AN8: no key is sent for an option that is not a one-time yes form, a wrapped line, a look-alike line above the dialog head, or a second head line in the window.
   - AN11 and AN11b: no key is sent when the pane changed after `wait`, a change 25 lines up included. AN12: none without `--screen`. AN13: a bad hash is a usage error.
   - AN7: no key is sent for a key that is not one option number. AN1: `--text` on a permission dialog sends nothing.
2. Script negative controls, from `contracts/answer.md` section 5: break the guard with the Edit tool, run the test, see the named case `FAIL`, then undo the break with the Edit tool.
3. `bash tests/test_worker_rules.sh`: W1, W2, W18, W19, W28, W29, W31, W32, O1 and G5 to G9 print `ok`, and no G1 row is left.
4. `bash tests/test_lane_steps.sh` and `bash tests/test_on_demand.sh`: all `ok`.

Expected before T010 to T013 are built: AN5 to AN12, W1, W31, W32, G8 and G9 print `FAIL` (AN13 was already green). Expected before T015 is built: AN6e, AN9b and AN11b print `FAIL`.

## US2: the shared rule

1. `bash tests/test_worker_rules.sh`: W20, W21, W22, W23, W26 and W27 print `ok`.
2. `grep -cF 'Watch each agent you summon. Answer its permission prompt when the answer keeps it in its brief. Bring every other prompt to the user with the exact text.' skills/st/SKILL.md skills/st-build/SKILL.md skills/st-worker/SKILL.md` prints `:1` for each of the 3 files (SC-002).
3. `bash tests/test_advisor_rules.sh`: A18 to A28 and G5 print `ok` (FR-009).

## US3: the subagent note

1. `bash tests/test_worker_rules.sh`: W24, W25, W30 and S1 to S6 print `ok`.
2. Read `research.md` R4: each claim in W24, W30 and W25 maps to a numbered fact with a source FR-008 accepts: a URL and quote, a file and line, a dated denial text (D4), a dated run in this session (D5), or "not documented" (SC-003).

## End

```bash
bash tests/test_worker_rules.sh && bash tests/test_lane_steps.sh && bash tests/test_advisor_rules.sh && bash tests/test_on_demand.sh && bash tests/test_st_worker.sh && bash tests/test_risk_rules.sh && bash tests/test_state.sh && python3 tests/test_model_hook.py
```

All exit 0 (SC-004).
