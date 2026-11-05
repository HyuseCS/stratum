# Quickstart: shared Codex advisor tab

## Stub tests (no herdr, no Codex, no network)

Run each from the repo root. Each must print no `FAIL` and exit 0.

```bash
bash tests/test_codex_agent.sh
bash tests/test_advisor_matrix.sh
bash tests/test_advisor.sh
bash tests/test_advisor_rules.sh
bash tests/test_risk_rules.sh
bash tests/test_on_demand.sh
```

Case ids are in [contracts/advisor-tab.md](contracts/advisor-tab.md) section 7. Each guard case (FR-002, FR-004, FR-005, FR-006, FR-008, FR-009, FR-010) was seen red once with its guard removed, during Build.

## Live run in herdr (manual, the user drives it, D9)

Prerequisites: inside herdr (`HERDR_ENV=1`), `codex` logged in, this repo trusted in `~/.codex/config.toml` (true today), `.stratum/advisor.json` mode `codex` or `auto`. No other Codex tab of Stratum open in this workspace. Do not change `~/.codex/config.toml`.

1. In Claude Code, run a Codex point, for example the plan point of this feature. The orchestrator starts the watch, then the point.
   Expect: one new tab `Codex` in this workspace. The review runs there. The point's last line is `codex: tab st-codex-stratum` (this workspace's label is `stratum`).
2. In the Codex tab, type a request of your own (for example "what does scripts/st-lock.sh do?") and wait for the answer.
   Expect: Codex answers with your normal config. Nothing from Stratum types into the tab.
3. Run a second point. Expect: the same tab, your conversation still there above the new review, no tab closed.
4. Start a long turn of your own in the tab, then run a point while it works.
   Expect: nothing typed into the tab. Last line `codex: headless (Codex tab in use)`.
5. Get one real prompt in a review: run a point whose review needs a command outside the sandbox (for example a test point whose test needs the network, or ask in the review input to run `git log` if your approvals ask for it).
   Expect: the watch prints `codex tab waits: <tab name>` and the screen. The orchestrator answers a prompt on the allow list with `st-advisor.sh answer --keys <key>`, and the review ends in the tab. A prompt not on the allow list comes to you with the exact screen lines.
6. Save the screen lines of step 5 into `tests/test_codex_agent.sh` as the C23 fixture, and run `bash tests/test_codex_agent.sh`.
7. Change `"model"` in `.stratum/advisor.json`, run a point. Expect the line `codex: the Codex tab runs with ..., advisor.json asks for .... Close the tab to apply.` and the old tab reused. Close the tab yourself and run a point: a new tab opens.

Undo: put back `.stratum/advisor.json` with the Edit tool. Close the Codex tab when you want.
