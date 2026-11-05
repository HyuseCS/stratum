# Quickstart: shared Codex advisor tab

## Stub tests (no herdr, no Codex, no network)

Run each from the repo root. Each must print no `FAIL` and exit 0.

```bash
bash tests/test_codex_agent.sh
bash tests/test_advisor_matrix.sh
bash tests/test_advisor.sh
bash tests/test_advisor_waive.sh
bash tests/test_advisor_rules.sh
bash tests/test_risk_rules.sh
bash tests/test_on_demand.sh
```

Case ids are in [contracts/advisor-tab.md](contracts/advisor-tab.md) section 7. During Build, each guard case was seen red once with its guard removed: the SC-005 guards (FR-002, FR-004, FR-006, FR-008, FR-009, FR-010), and also FR-003 (name rule, clash), FR-005 and FR-012 (no time limit, tab ended, no headless after a started review). M20 is the live screen and is not a guard.

## Live run in herdr (manual, the user drives it, D9, D12)

Prerequisites: inside herdr (`HERDR_ENV=1`), `codex` logged in, this repo trusted in `~/.codex/config.toml` (true today), `.stratum/advisor.json` mode `codex` or `auto`. Close any old `st-codex-<feature>` tab first. Do not change `~/.codex/config.toml`.

1. In Claude Code, run a Codex point, for example the plan point of this feature. The orchestrator starts the watch, then the point.
   Expect: one new tab `Codex` in this workspace. The review runs there. The point's last line is `codex: tab st-codex-stratum` (this workspace's label is `stratum`).
2. In the Codex tab, type a request of your own (for example "what does scripts/st-lock.sh do?") and wait for the answer.
   Expect: Codex answers with your normal config. Nothing from Stratum types into the tab.
3. Run a second point. Expect: the same tab, your conversation still there above the new review, no tab closed.
4. Start a long turn of your own in the tab, then run a point while it works.
   Expect: nothing typed into the tab. Last line `codex: headless (Codex tab in use)`.
5. Run a point whose review input asks Codex to run one command that needs the network (for example `git ls-remote origin`). With your normal settings, Codex asks for approval.
   Expect: the watch prints `codex tab waits: st-codex-<workspace label> <hash>`, the screen, and `codex tab waits: end`. The orchestrator handles the prompt by the rule: a prompt on the allow list gets a one-time yes through `st-advisor.sh answer --screen <hash> --keys <key>`; any other prompt (a network command is on the never list) comes to you with the exact screen lines. You answer it in the tab. The review ends in the tab.
6. The orchestrator saves the screen lines of step 5 as case M20 in `tests/test_advisor_matrix.sh` and runs `bash tests/test_advisor_matrix.sh`.
7. Run a point and close the Codex tab while the review runs.
   Expect: the point ends `BLOCKED: the Codex tab ended during the review`, and no headless run follows. If the point does not end, tell the orchestrator to stop it and report it (plan risk R6).
8. Change `"model"` in `.stratum/advisor.json`, run a point. Expect the line `codex: the Codex tab runs with ..., advisor.json asks for .... Close the tab to apply.` and the old tab reused. Close the tab yourself and run a point: a new tab opens.

Undo: put back `.stratum/advisor.json` with the Edit tool. Close the Codex tab when you want.
