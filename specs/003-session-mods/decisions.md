# Decisions: issue #9 (mods that talk to and start other sessions)

- D6 (Q6): O1, spike only. Deliver the write-up for Q1 to Q5, two test mods (or the exact limit that stops each), and a yes or no for Stratum. Stratum use becomes a new issue. Rejected: O2, spike plus a first Stratum use.
- D7 (Q7): O3. Test mods in `specs/003-session-mods/spikes/<mod name>/`, report in `specs/003-session-mods/research.md`. Work on a new branch off `main`, separate from `st-tree`. Rejected: O4, build on the `st-tree` branch.
- D8 (Q8): O5. Local sessions only for both test mods. For cloud, the report records the known limit (a cloud session cannot reply yet) with its source. Rejected: O6, start and message a real cloud session.
- D9 (Q9): O7. "Mod sends" is a full pass. "Model sends with SendMessage, mod shows the reply in a pane" is a partial pass, and the report names the exact limit. Rejected: O8, only "mod sends" counts.
- D10 (Q10): O9. For test 1 the user opens the second session by hand, with exact steps. Test 1 does not depend on test 2. User add: also test if Claude Code can start another session on its own (scope set in Q11). Rejected: O10, test 2's mod starts the session for test 1.
- D11 (Q11): O11. Add test 3: the model starts a session with no human step (for example `claude -p` through Bash, or a tool such as `EnterWorktree`) and checks it is alive. The report compares "mod starts" (test 2) with "model starts" (test 3). Rejected: O12, no test 3.
- D12 (Q12): O13. "Yes" for Stratum only if all hold: a session starts with no human step (test 2 or 3), its result comes back (message or file), and it can be stopped with no process left alive. Any one false means "no", and the report names the failed part. Rejected: O14, no fixed rule.
- D13 (Q13): O15. Each test gets at most 3 different approaches. If all 3 fail, the test is "blocked" and the report names the exact limit (error text or missing API). Rejected: O16, no limit.
