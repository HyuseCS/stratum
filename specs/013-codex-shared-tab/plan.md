# Implementation Plan: Shared Codex advisor tab

**Branch**: `013-codex-shared-tab` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md), decisions D1 to D12 in [decisions.md](decisions.md), checklist [checklists/safety.md](checklists/safety.md), issues #75 and #74 item 1.

**Status**: No open decisions. D10 settles the tab name, D11 the time limit, D12 the live run. Inspect F1, F2 and F5 to F14 are fixed in the design files.

## Summary

The advisor tab starts Codex with the user's own Codex home and normal approvals, and the Stratum Codex home and its `codex-home` command go. One tab per herdr workspace, named `st-codex-<workspace label>`, shared by every feature. When that name is live in another workspace or folder, the point runs headless and says so. The scripts never close it. A tab that is working or blocked is not touched: the review runs headless with `codex: headless (Codex tab in use)`. A settings change prints one line and keeps the tab.

Each review in the tab takes a snapshot of HEAD, the staged entries, and the changed and untracked files with their modes and hashes, before and after the turn. A difference ends the point BLOCKED with the files named. Nothing is reverted.

The review waits on a Codex prompt instead of failing, with no time limit (D11). The orchestrator starts a new `st-advisor.sh watch` with the Monitor tool before it starts the point in the background. The watch reports a blocked tab only while a review drives it, with the screen text. The orchestrator answers a prompt on the allow list with a one-time yes through a new `st-advisor.sh answer --screen <hash> --keys <key>` and brings every other prompt to the user. The point ends early only when the tab ends (the user closes it or Codex exits): BLOCKED, and never headless once the review started in the tab.

## Technical Context

**Language/Version**: bash 5, inline `python3 -I` for JSON (as today)

**Primary Dependencies**: herdr 0.9.4 (`agent list|get|start|prompt|wait|read|send-keys`, `tab create`), codex-cli 0.166.0 (`--no-alt-screen`, `-m`, `-c`), git. No new dependency.

**Storage**: files under `${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-tabs` (settings record, review marker). See [data-model.md](data-model.md).

**Testing**: bash test scripts with a fake `herdr`, fake `codex`, fake `timeout` and `sleep` on PATH, temp dirs (`tests/test_codex_agent.sh`, `tests/test_advisor_matrix.sh`), and grep rule tests (`tests/test_advisor_rules.sh`, `tests/test_risk_rules.sh`, `tests/test_on_demand.sh`).

**Target Platform**: Linux, on the PC and the laptop. Inside herdr for the tab path, anywhere for the headless path.

**Project Type**: Claude Code plugin (scripts, skills, README).

**Performance Goals**: none new. One extra `git status`, one `git diff --cached` and a `stat` and a hash of each changed file, twice per review.

**Constraints**: no time limit on the tab path (D11): the 480 s tab budget and the `timeout -k 10 540` around the tab run go. The headless call keeps its 540 s budget. Minimal code, no comments except `ponytail:` markers, surgical changes.

**Scale/Scope**: 2 scripts, 3 skills, README, 5 test files.

## Constitution Check

There is no `.stratum/constitution.md` and no `apps/*/ORDINANCE.md` in this repo. The gates used are the user's rules: test first, minimal code, no comments except `ponytail:` markers, no change to the user's `~/.codex/config.toml`, features that work on both machines. The design passes them. Re-checked after Phase 1: pass.

## Design

Research R1 to R14 in [research.md](research.md). The interface is in [contracts/advisor-tab.md](contracts/advisor-tab.md).

1. Start (FR-001, FR-002): `tab create` loses `--env CODEX_HOME=...`. `agent start` loses `-s read-only -a never`. The Folder access auto-enter, `quit()`, and every `tab close` go. `st-codex-agent.sh` takes `<tab name>` and `<state dir>` in place of the feature folder and the Codex home.
2. Find and reuse (FR-003, FR-004, FR-005): `st-advisor.sh` computes the name from the workspace label (contract section 1). The tab script finds the tab by name, workspace and folder. The name live in another workspace or folder exits 5, and the point runs headless with `codex: headless (Codex tab name <name> in use elsewhere)`. Compare the settings record. Print the FR-005 line on a difference. Never close.
3. In use (FR-006): `herdr agent get` right before the marker and the prompt, after the snapshot (Inspect F9). `working` or `blocked`, or `agent_blocked` from the prompt, gives exit 3. `st-advisor.sh` runs the headless call and prints `codex: headless (Codex tab in use)`.
4. Change check (FR-008): snapshot before the in-use check and after the prompt call. `.stratum/state.json` and Syncthing temp files are left out (Inspect F12, research R6). Exit 4 with the changed paths. `st-advisor.sh` turns exit 4 into a BLOCKED record with no headless call.
5. Wait (FR-009, FR-012, D11): no `--until blocked`, no `--timeout`, and no `timeout` around the tab run. A failed prompt (the tab ended, or another herdr error) or a missing answer gives exit 4: BLOCKED, no headless run. The start-up `agent_not_ready` waits the same way.
6. Watch and answer (FR-010, FR-011): a review marker with the tab script's pid. `watch` and `answer` act only while it is live and the tab is blocked.
7. Text (FR-002, FR-007, FR-011): `skills/st-build/SKILL.md`, `skills/st-plan/SKILL.md`, `skills/st-init/SKILL.md`, `README.md`, per contract sections 4 and 5.

The headless call (`codex exec -s read-only --ignore-user-config`) does not change.

## Safety checklist settled

| Item | Where settled |
|------|---------------|
| CHK001 | Contract K4 and K5: the exact allow list and never list. |
| CHK002 | R6, data-model "Review snapshot": tracked changes, staged entries, untracked files that are not ignored, file modes, symlink targets, HEAD. Not ignored files, not files outside the folder, not tags or stash. |
| CHK003 | R5: `watch` reports a blocked tab only while a review marker is live, and `answer` refuses without one. A prompt of the user's own turn never reaches the orchestrator. |
| CHK004 | Contract section 2 step 2: `codex: the Codex tab runs with <old>, advisor.json asks for <new>. Close the tab to apply.` |
| CHK005 | R12: a test or lint command is in only without a write flag. A cache it writes is ignored. Any other file it writes fails the change check. |
| CHK006 | R8, R12: an untrusted folder shows the trust screen at start. It goes to the user, because trust changes the user's Codex config. |
| CHK007 | R11: last 20 lines, CSI escapes removed. |
| CHK008 | Contract section 2: `working` or `blocked` before this run's prompt is FR-006 (headless). `blocked` after this run's own start or prompt is FR-009 (wait). |
| CHK009 | No path closes the tab, start-up failures and a tab that ends included. Case C8 checks the whole test run. |
| CHK010 | Contract K2a copies the wording of the prompt line `st-advisor.sh:169` ("never create, change or delete a file, and never build or fix anything"). |
| CHK011 | Spec edge case and K7: the check cannot tell who changed a file. The point fails and the user decides. K1 tells the orchestrator to change no file in that folder while a point runs. |
| CHK012 | R13: the existing `st-lock.sh --name codex-<workspace id>` lock. |
| CHK013 | K7: the user checks the files with `git diff`, keeps or reverts them, then the point runs again or `continued` skips it. |
| CHK014 | K11 says review prompts and read files land in the user's own Codex history. Accepted by D1 and D5. |
| CHK015 | R10 and D11: no time limit for a review in the tab, answer time included. It ends early only when the tab ends (FR-012). The user stops a hung review with Esc in the tab or by telling the orchestrator. |

## Security notes

Tasks that touch these areas: T004, T005, T010, T011, T016, T017 (scripts), T006, T012, T018 (skills and README).

- S1 Approval policy (access rules): the tab no longer runs read-only. With the user's normal settings, Codex can write files in a trusted folder without asking. The guard is detection, not prevention: the snapshot check (FR-008), the review-only prompt and skill text (FR-007), and git as the undo. Ignored files (for example `.env`, caches), files outside the folder, `.stratum/state.json` and Syncthing temp files are not checked. This is the trade D1 accepted. The orchestrator approves only a one-time yes (K3) to one command with no chain and no write or exec flag (K4), so an approval adds no lasting rule to the user's Codex config and no hidden write.
- S2 Sign-in and secrets: the `auth.json` link in the Stratum Codex home goes. The tab uses the user's own login. The old folder stays on disk with its link; README tells the user they may delete it. No script reads or prints a token. The never list (K5) keeps `.env` files and secrets out of approvals. The `watch` screen text goes to the orchestrator and the user but is never written to `advisor.md` (a BLOCKED record holds only the one-line reason).
- S3 External service (OpenAI): the data sent is the same as today. New: review prompts and the files Codex reads are kept in the user's own Codex history, and the user's Codex config (MCP servers, hooks, notify) now loads in the tab. Accepted by D1 and D5. README K11 says so.
- S4 New command `answer` (trust boundary): it sends keys to a terminal. Each key must match `^[A-Za-z0-9+_][A-Za-z0-9+_-]{0,15}$` (no leading `-`, so no key reads as a herdr flag), and it refuses unless a live review marker exists and herdr reports the tab blocked. It cannot type into the user's own turn.
- S5 Contracts: `st-codex-agent.sh` arguments and exit codes change (contract section 2). Its only caller is `st-advisor.sh`.
- S6 State files: the settings record and the marker hold a tab id, launch options and a pid. Folder mode 700, file mode 600 (umask 077). No secret.

## Risks

- R1 A file changed by the orchestrator, a subagent or the user during a review fails the point (false BLOCKED). K1 tells the orchestrator to change no file in that folder until the point ends. `[P]` tasks run in their own worktrees. Two more writers are handled by leaving them out of the snapshot (research R6): `hooks/st-phase.py` writes the tracked `.stratum/state.json` on user prompts and skill starts, and Syncthing writes `.syncthing.*.tmp` and `~syncthing~*.tmp` files while it syncs the repo (`.stfolder` is in the repo root). A file Syncthing finishes syncing during a review is a real change and still fails the point.
- R2 herdr may not report the Codex trust screen or a Codex approval as `blocked`. Then the watch stays quiet and the review waits with no limit until the user acts in the tab. The live run (T019) checked this: a Codex approval prompt is reported as `blocked`, and `watch` printed it (M20 holds the screen). The trust screen did not appear: the linked worktree inherited trust from the main repo.
- R3 The Monitor tool must turn each `watch` output line into an event for the orchestrator, and a `run_in_background` Bash call must have no time limit. The live run showed the Monitor printing each `watch` line. The second is assumed and was not observed in the live run.
- R4 A new tab whose `agent start` fails all 10 tries now stays open as an empty shell tab (FR-004). Before this feature, `quit()` closed it. The user closes it. The point runs headless as today.
- R5 A linked worktree in the same workspace as its main checkout gets the same name. While the main checkout's tab lives, the worktree's points run headless with the clash line (D10). It gets its own tab only when it has its own workspace with its own label, as `st-worker` workspaces do.
- R6 Found live: `herdr agent prompt --wait` did not return when the Codex tab closed. Fixed in 5c52e8e: the call runs in the background and `herdr agent get` is checked every 2 s (C25, C26). The live run then ended the point BLOCKED (commit 09e12a0).
- R7 Test flake: `(k5)` in `tests/test_advisor_matrix.sh` failed 2 of 9 runs in one reviewer's copies and 0 of 10 here. No code change; the cause is not known.

## Project Structure

### Documentation (this feature)

```text
specs/013-codex-shared-tab/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/advisor-tab.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/st-codex-agent.sh      # tab start, reuse, in-use check, snapshot, wait, marker
scripts/st-advisor.sh          # codex-home removed, tab name, exit 3, 4 and 5, answer, watch, no timeout on the tab run
skills/st-build/SKILL.md       # Advisor section lines 95-97, 116, new lines K1-K8
skills/st-plan/SKILL.md        # step 4, lines 30-31
skills/st-init/SKILL.md        # line 86 removed
README.md                      # lines 203, 214-216
tests/test_codex_agent.sh      # cases C1-C26
tests/test_advisor_matrix.sh   # cases M1-M24; codex-home cases, k3, k6, k7 removed
tests/test_advisor_rules.sh    # rows A14-A28 (K1, K2a, K3, K4, K5, K7, K8, K11), G3 to G5
tests/test_risk_rules.sh       # R7, R17 replaced; R19, R20 moved to the gone list
tests/test_on_demand.sh        # #18 FR-002 wait lines, FR-016 readme line
```

**Structure Decision**: no new file except the contract. Both commands go into `st-advisor.sh`, which already holds every advisor command.

## Open decisions

None. The tab name was settled by D10 in decisions.md: `st-codex-<workspace label>`, with a clash running headless (research R1, contract section 1).

## Complexity Tracking

None.
## Validate

Date: 2026-11-05. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | none. bash 5.3.20, python 3.14.9, git 2.56.0, herdr 0.9.4, codex-cli 0.166.0 (`--no-alt-screen`, `-s`, `-a` present), `timeout`, `sha256sum`, `od` on PATH. herdr `workspace list` (`label`, `workspace_id`), `agent list` (`agent_status`, `cwd`, `workspace_id`, `tab_id`), `agent get` (`.result.agent.agent_status`), `agent wait`, `agent read --source recent-unwrapped`, `agent send-keys` checked live. |
| 2. Test coverage per requirement | CONCERN | F4, F5, F6, F7 |
| 3. Breaking changes | CONCERN | F8 |
| 4. Security and privacy | CONCERN | F1, F2, F3, F9 |

F1. contracts/advisor-tab.md:110 (K3) "the key the screen gives for yes" does not exclude the persistent options. codex-cli 0.166.0 offers "Yes, and don't ask again for commands that start with ...", "... for these files" and "... for this command in this session", and `~/.codex/rules/default.rules` exists. Pressing a "don't ask again" key writes a rule into the user's Codex config, which K5 and the user rules forbid. -> K3: "the key for a one-time yes only; never a `don't ask again` or `allow ... in this session` option". Add the same to K4 or K5. st-plan, no user decision.

F2. contracts/advisor-tab.md:116 (K4) bars only `>`, `>>` and `tee`. It does not bar chains (`;`, `&&`, `||`, `|`, `$(`, backticks) or write and exec flags of allowed tools (`git diff --output`, `git log --output`, `rg --pre`, `find -fprint`, `-fprintf`, `-fls`, `-execdir`, `-okdir`). An escalated command can write outside the folder or use the network, which the snapshot does not see. -> K4: "one command only, no `;`, `&&`, `||`, `|`, `$(` or backticks", and name the flags above. st-plan, no user decision.

F3. contracts/advisor-tab.md:39 and :199 (C19). A prompt that times out while the tab is `working` exits 1 and falls back to headless. The review keeps running in the tab with the user's write rights after the second snapshot and after the marker is gone, so its later writes are not checked and a later prompt looks like the user's own turn. -> Option A: end BLOCKED with "the review still runs in the Codex tab" and no fallback. Option B: keep the fallback and say in K11 that a late review is not checked. User decision.

F4. quickstart.md:29 (step 5), spec.md:103 (SC-003), tasks.md:100 (T019). The user's `~/.codex/config.toml` sets no `approval_policy` or `sandbox_mode`, so Codex runs with its defaults and runs reads and `git log` without asking (spec.md:109 says so). The step 5 example "a test whose test needs the network" hits the never list (K5 "network use"), so it goes to the user, not to the orchestrator. The live run may never show an allow-list prompt, and SC-003 and the C23 fixture then cannot be met. -> Name one prompt that is on the allow list and certain to appear (for example a test or lint command that writes a cache outside the folder), and confirm it before T019. st-plan.

F5. tasks.md:47 (T001). Cases `a`, `b`, `b2` and `d` of tests/test_codex_agent.sh are in neither the delete list nor the keep list. `b2` (tests/test_codex_agent.sh:128) expects one `tab close`, against FR-004 and C8. `d` (:140) expects a new start when the name lives in another workspace, against C9. -> Add `a`, `b`, `b2`, `d` to the delete list (C1, C2, C3, C9 replace them). st-plan.

F6. tasks.md:91 (T013). C23 is a copy of C18 until T019 fills it, so it cannot fail on its own before the live run. -> Do not count C23 for FR-012 until T019 saves the real screen. st-plan.

F7. tasks.md:54, :76, :98, :108. tests/test_advisor_waive.sh runs scripts/st-advisor.sh (usage and exit 2 cases) but is in no `Test:` command of T005, T011, T017 or T020. -> Add `bash tests/test_advisor_waive.sh` to T005 and T020. st-plan.

F8. contracts/advisor-tab.md:167 (K11 line 5). Tabs started by the current code keep their old names (`st-codex-013-codex-shared-tab` is live in this workspace now, with the Stratum Codex home). The new scripts match the exact new name, so they neither reuse nor close these tabs. No data is lost and no migration is needed. -> K11 line 5: "Close any old `st-codex-<feature>` tab." st-plan.

F9. contracts/advisor-tab.md:29-34 (steps 2 to 6). The in-use status comes from `agent list` in step 1. Then the marker write and the snapshot (a hash of every changed file) run before the prompt. herdr refuses a prompt only when the tab is `blocked`, not `working`. A user turn that starts in that gap gets the review typed into it, and if it stops on a prompt while the marker is live, `watch` hands the user's own prompt to the orchestrator. CHK003 (plan.md:61) says this cannot happen. -> Take the snapshot first, then `herdr agent get` right before the marker and the prompt. st-plan.
