# Implementation Plan: Shared Codex advisor tab

**Branch**: `013-codex-shared-tab` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md), decisions D1 to D10 in [decisions.md](decisions.md), checklist [checklists/safety.md](checklists/safety.md), issues #75 and #74 item 1.

**Status**: No open decisions. D10 settles the tab name.

## Summary

The advisor tab starts Codex with the user's own Codex home and normal approvals, and the Stratum Codex home and its `codex-home` command go. One tab per herdr workspace, named `st-codex-<workspace label>`, shared by every feature. When that name is live in another workspace or folder, the point runs headless and says so. The scripts never close it. A tab that is working or blocked is not touched: the review runs headless with `codex: headless (Codex tab in use)`. A settings change prints one line and keeps the tab.

Each review in the tab takes a snapshot of HEAD and the changed and untracked files before and after the turn. A difference ends the point BLOCKED with the files named. Nothing is reverted.

The review waits on a Codex prompt instead of failing. The orchestrator starts a new `st-advisor.sh watch` with the Monitor tool before it starts the point in the background. The watch reports a blocked tab only while a review drives it, with the screen text. The orchestrator answers a prompt on the allow list with a new `st-advisor.sh answer --keys <key>` and brings every other prompt to the user. When time runs out with a prompt open, the point ends BLOCKED with the screen text, and the tab stays.

## Technical Context

**Language/Version**: bash 5, inline `python3 -I` for JSON (as today)

**Primary Dependencies**: herdr 0.9.4 (`agent list|get|start|prompt|wait|read|send-keys`, `tab create`), codex-cli 0.166.0 (`--no-alt-screen`, `-m`, `-c`), git. No new dependency.

**Storage**: files under `${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-tabs` (settings record, review marker). See [data-model.md](data-model.md).

**Testing**: bash test scripts with a fake `herdr`, fake `codex`, fake `timeout` and `sleep` on PATH, temp dirs (`tests/test_codex_agent.sh`, `tests/test_advisor_matrix.sh`), and grep rule tests (`tests/test_advisor_rules.sh`, `tests/test_risk_rules.sh`, `tests/test_on_demand.sh`).

**Target Platform**: Linux, on the PC and the laptop. Inside herdr for the tab path, anywhere for the headless path.

**Project Type**: Claude Code plugin (scripts, skills, README).

**Performance Goals**: none new. One extra `git status` and a hash of each changed file, twice per review.

**Constraints**: the 540 s point budget and the 480 s tab budget stay. Minimal code, no comments except `ponytail:` markers, surgical changes.

**Scale/Scope**: 2 scripts, 3 skills, README, 5 test files.

## Constitution Check

There is no `.stratum/constitution.md` and no `apps/*/ORDINANCE.md` in this repo. The gates used are the user's rules: test first, minimal code, no comments except `ponytail:` markers, no change to the user's `~/.codex/config.toml`, features that work on both machines. The design passes them. Re-checked after Phase 1: pass.

## Design

Research R1 to R14 in [research.md](research.md). The interface is in [contracts/advisor-tab.md](contracts/advisor-tab.md).

1. Start (FR-001, FR-002): `tab create` loses `--env CODEX_HOME=...`. `agent start` loses `-s read-only -a never`. The Folder access auto-enter, `quit()`, and every `tab close` go. `st-codex-agent.sh` takes `<tab name>` and `<state dir>` in place of the feature folder and the Codex home.
2. Find and reuse (FR-003, FR-004, FR-005): `st-advisor.sh` computes the name from the workspace label (contract section 1). The tab script finds the tab by name, workspace and folder. The name live in another workspace or folder exits 5, and the point runs headless with `codex: headless (Codex tab name <name> in use elsewhere)`. Compare the settings record. Print the FR-005 line on a difference. Never close.
3. In use (FR-006): `agent_status` `working` or `blocked` in the list, or `agent_blocked` from the prompt, gives exit 3. `st-advisor.sh` runs the headless call and prints `codex: headless (Codex tab in use)`.
4. Change check (FR-008): snapshot before the prompt and after the prompt call. Exit 4 with the changed paths. `st-advisor.sh` turns exit 4 into a BLOCKED record with no headless call.
5. Wait (FR-009, FR-012): no `--until blocked`. Time out with the tab blocked gives exit 4 with the screen. The start-up `agent_not_ready` waits the same way.
6. Watch and answer (FR-010, FR-011): a review marker with the tab script's pid. `watch` and `answer` act only while it is live and the tab is blocked.
7. Text (FR-002, FR-007, FR-011): `skills/st-build/SKILL.md`, `skills/st-plan/SKILL.md`, `skills/st-init/SKILL.md`, `README.md`, per contract sections 4 and 5.

The headless call (`codex exec -s read-only --ignore-user-config`) does not change.

## Safety checklist settled

| Item | Where settled |
|------|---------------|
| CHK001 | Contract K4 and K5: the exact allow list and never list. |
| CHK002 | R6, data-model "Review snapshot": tracked changes, untracked files that are not ignored, HEAD. Not ignored files, not files outside the folder, not tags or stash. |
| CHK003 | R5: `watch` reports a blocked tab only while a review marker is live, and `answer` refuses without one. A prompt of the user's own turn never reaches the orchestrator. |
| CHK004 | Contract section 2 step 2: `codex: the Codex tab runs with <old>, advisor.json asks for <new>. Close the tab to apply.` |
| CHK005 | R12: a test or lint command is in only without a write flag. A cache it writes is ignored. Any other file it writes fails the change check. |
| CHK006 | R8, R12: an untrusted folder shows the trust screen at start. It goes to the user, because trust changes the user's Codex config. |
| CHK007 | R11: last 20 lines, CSI escapes removed. |
| CHK008 | Contract section 2: `working` or `blocked` before this run's prompt is FR-006 (headless). `blocked` after this run's own start or prompt is FR-009 (wait). |
| CHK009 | No path closes the tab, start-up failures and time-outs included. Case C8 checks the whole test run. |
| CHK010 | Contract K2 copies the wording of the prompt line `st-advisor.sh:169` ("never create, change or delete a file, and never build or fix anything"). |
| CHK011 | Spec edge case and K7: the check cannot tell who changed a file. The point fails and the user decides. K1 tells the orchestrator to change no file in that folder while a point runs. |
| CHK012 | R13: the existing `st-lock.sh --name codex-<workspace id>` lock. |
| CHK013 | K7: the user checks the files with `git diff`, keeps or reverts them, then the point runs again or `continued` skips it. |
| CHK014 | K11 says review prompts and read files land in the user's own Codex history. Accepted by D1 and D5. |
| CHK015 | R10: the 480 s tab budget includes the answer time. Expiry is FR-012. |

## Security notes

Tasks that touch these areas: T004, T005, T010, T011, T016, T017 (scripts), T006, T012, T018 (skills and README).

- S1 Approval policy (access rules): the tab no longer runs read-only. With the user's normal settings, Codex can write files in a trusted folder without asking. The guard is detection, not prevention: the snapshot check (FR-008), the review-only prompt and skill text (FR-007), and git as the undo. Ignored files (for example `.env`, caches) and files outside the folder are not checked. This is the trade D1 accepted.
- S2 Sign-in and secrets: the `auth.json` link in the Stratum Codex home goes. The tab uses the user's own login. The old folder stays on disk with its link; README tells the user they may delete it. No script reads or prints a token. The never list (K5) keeps `.env` files and secrets out of approvals. Screen text is shown to the user but is not written to `advisor.md` (only the one-line reason).
- S3 External service (OpenAI): the data sent is the same as today. New: review prompts and the files Codex reads are kept in the user's own Codex history, and the user's Codex config (MCP servers, hooks, notify) now loads in the tab. Accepted by D1 and D5. README K11 says so.
- S4 New command `answer` (trust boundary): it sends keys to a terminal. Each key must match `^[A-Za-z0-9+_][A-Za-z0-9+_-]{0,15}$` (no leading `-`, so no key reads as a herdr flag), and it refuses unless a live review marker exists and herdr reports the tab blocked. It cannot type into the user's own turn.
- S5 Contracts: `st-codex-agent.sh` arguments and exit codes change (contract section 2). Its only caller is `st-advisor.sh`.
- S6 State files: the settings record and the marker hold a tab id, launch options and a pid. Folder mode 700, file mode 600 (umask 077). No secret.

## Risks

- R1 A file changed by the orchestrator, a subagent or the user during a review fails the point (false BLOCKED). K1 tells the orchestrator to change no file in that folder until the point ends. `[P]` tasks run in their own worktrees.
- R2 herdr may not report the Codex trust screen or a Codex approval as `blocked`. Then the watch stays quiet and the point times out (BLOCKED only if herdr says blocked, else the headless fallback). The live run (T019) checks this.
- R3 The Monitor tool must turn each `watch` output line into an event for the orchestrator. The live run checks this.
- R4 A new tab whose `agent start` fails all 10 tries now stays open as an empty shell tab (FR-004). Today `quit()` closes it. The user closes it. The point runs headless as today.
- R5 A linked worktree in the same workspace as its main checkout gets the same name. While the main checkout's tab lives, the worktree's points run headless with the clash line (D10). The spec edge case "A linked worktree is a different folder: it gets its own tab" holds only when the worktree has its own workspace, as `st-worker` workspaces do.

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
scripts/st-advisor.sh          # codex-home removed, tab name, exit 3 and 4, answer, watch
skills/st-build/SKILL.md       # Advisor section lines 95-97, 116, new lines K1-K8
skills/st-plan/SKILL.md        # step 4, lines 30-31
skills/st-init/SKILL.md        # line 86 removed
README.md                      # lines 203, 214-216
tests/test_codex_agent.sh      # cases C1-C23
tests/test_advisor_matrix.sh   # cases M1-M15, codex-home cases removed
tests/test_advisor_rules.sh    # K1-K9 rows
tests/test_risk_rules.sh       # R7, R17 replaced; R19, R20 moved to the gone list
tests/test_on_demand.sh        # #18 FR-002 wait lines, FR-016 readme line
```

**Structure Decision**: no new file except the contract. Both commands go into `st-advisor.sh`, which already holds every advisor command.

## Open decisions

None. The tab name was settled by D10 in decisions.md: `st-codex-<workspace label>`, with a clash running headless (research R1, contract section 1).

## Complexity Tracking

None.
