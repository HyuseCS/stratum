# Decisions: #74 items 2 to 4 (answer the prompts of summoned agents)

Item 1 (the Codex tab) was built in 013 (PR #82). 013's D7 already decided item 2: in normal mode the orchestrator answers a worker's permission dialog with `answer --keys`, with the autonomous allow and never lists, and `skills/st-worker/SKILL.md:26` changes to match. 013's Q8 (item 4) had a recommended O17 whose text was never recorded.

- D1 (Q1): O1. Each agent kind keeps the lists it has. The Codex tab uses the allow and never lists in `skills/st-build/SKILL.md`. Workers use the lists in `skills/st-worker/SKILL.md` (the autonomous `approve` lists). No new list is written. Rejected: O2 (the st-build lists for every agent; they block every file write and commit, so a worker would send all its normal work to the user).
- D2 (Q2): O3. Done is proved by text-rule tests: one row per new rule line in the skill files, and each row is shown red once with its line removed. No live run. Rejected: O4 (also a live herdr worker run in normal mode).
