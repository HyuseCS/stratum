# Research: Shared Codex advisor tab

Checked against herdr 0.9.4 (`herdr agent --help`, `herdr agent get`, `herdr agent list`, `herdr --skill`) and codex-cli 0.166.0 (`codex --help` with a temp `CODEX_HOME`). No live tab or agent was started.

## R1. Agent names in herdr are unique per server

- Decision (D10): `st-codex-<workspace label>`. The label comes from `herdr workspace list`, `.result.workspaces[]`, the entry whose `workspace_id` is `$HERDR_WORKSPACE_ID`, field `label` (checked live: labels `~`, `stratum`, `71-worker-workspace`, `78-harness-diagram`). Lowercase it, map every character outside `a-z0-9_-` to `-`, cut it to 23 characters so the name has at most 32. When the result has no letter or digit (label `~`), or the list fails, or no entry matches, use the lowercased workspace id, mapped the same way. `st-advisor.sh` computes it in one place.
- Clash: when `herdr agent list` has the name live with another `workspace_id` or `cwd`, the tab script exits 5 and the point runs headless with `codex: headless (Codex tab name <name> in use elsewhere)`. Two workspaces with the same label, and a linked worktree in the same workspace as its main checkout, clash this way.
- Rationale: `herdr --skill` says names "must match `[a-z][a-z0-9_-]{0,31}` and be unique among live agents", and "IDs and live agent names are scoped to one server". A literal `st-codex` can live in one workspace only.
- Alternatives: `st-codex-` plus a hash (O23), one `st-codex` per server (O24). Both rejected in D10.

## R2. How the script reads the tab state (FR-006)

- Decision: `herdr agent get <tab name>`, `.result.agent.agent_status`, read once, right after the first snapshot and right before the marker and the prompt (Inspect F9). `answer` and `watch` read the same field.
- Rationale: `agent_status` is `idle`, `working`, `blocked`, `done` or `unknown` (checked live). `working` or `blocked` is in use. `idle`, `done` and `unknown` are free. Reading it last keeps the gap to the prompt as short as it can be: the snapshot hashes files, so it goes first.
- Alternatives: the status in the `herdr agent list` output of step 1 (older by the time of the snapshot, Inspect F9); `herdr agent wait --until idle` before the prompt (rejected by D3, O6).
- Limit: herdr cannot see unsent text in the tab, and the user can start a turn in the short gap between the check and the prompt. `herdr agent prompt` returns `agent_blocked` when the tab became blocked in that gap; the script treats that as in use. One `ponytail:` note covers both.

## R3. Waiting on a prompt (FR-009)

- Decision (D11): send the review with `herdr agent prompt <tab> <text> --wait --until done --until idle`, with no `--timeout`. Drop `--until blocked`, the `blocked` exit and the `480 - SECONDS` budget (`scripts/st-codex-agent.sh:2,85,90`).
- Rationale: without `--until blocked`, a blocked state does not end the wait. Without `--timeout`, the wait goes on until the turn ends. `herdr agent wait --help`: "Without --timeout, waits indefinitely."
- Any failure of the prompt call except `agent_blocked` (rejected before any input) means the review text may already be in the tab. The point ends BLOCKED and never runs headless (D11): `the Codex tab ended during the review` when `herdr agent get` no longer finds the agent (the user closed the tab or Codex exited), else `the Codex tab failed during the review: <first line of the herdr error>`. `agent_prompt_stalled` (the 2026-11-04 failure) takes the second reason.
- Unknown: whether `agent prompt --wait` returns at once when the agent goes away during the wait. The live run checks it (plan risk R6). If it does not, the point waits until the user stops it, as D11 allows ("The user stops a hung review with Esc in the tab or by telling the orchestrator").

## R4. How the orchestrator watches the tab (FR-011, US3 scenario 1)

- Decision: a new `st-advisor.sh watch` command. The orchestrator starts it with the Monitor tool before it starts the point. Then it starts the point with Bash `run_in_background`.
- Rationale: a background Bash call shows its output only when it exits, so a line the script prints early does not reach the orchestrator in time. A watch that starts before the point is watching before the tab exists and before the review prompt is sent. It needs no early line. `watch` reports a blocked tab only while a review runs in it (R5), so a prompt from the user's own turn never reaches the orchestrator (CHK003).
- Alternatives: an early line in the point's output (does not reach the orchestrator before exit); the point itself as the Monitor command (its stdout passes through `st-advisor.sh`, which captures the tab script's output into a file, so this needs a file-descriptor path through `st-lock.sh` and `timeout`).

## R5. Review marker

- Decision: while `st-codex-agent.sh` drives the tab, it keeps `<state dir>/<tab name>.review` with its own pid. It writes the file right after the in-use check passes (or right after it starts a new tab, so a start-up screen is watched too) and removes it on exit (`trap`). `watch` and `answer` act only when the file exists and its pid is alive (`kill -0`).
- Rationale: this is the one signal that tells "a review waits" from "the user's own turn waits". A kill (the orchestrator stops the point) can leave the file, but the pid is dead, so it counts as absent.
- Limit: pid reuse after a kill. Accepted, `ponytail:` note.

## R6. Change check (FR-008, CHK002)

- Decision: one snapshot before the prompt and one after the prompt call returns (any result). The snapshot is `git rev-parse -q --verify HEAD`, then one line per entry of `git --no-optional-locks status --porcelain=v1 -z --untracked-files=all --no-renames -- . ':(exclude).stratum/state.json' ':(exclude,glob)**/.syncthing.*.tmp' ':(exclude,glob)**/~syncthing~*.tmp'`: path, status letters, sha256 of the worktree file (empty when the file is gone). Any difference ends the point BLOCKED with the changed paths (and `HEAD` when HEAD moved). Nothing is reverted.
- Covered: tracked files with changes, untracked files that are not ignored, the checked-out commit. Not covered: ignored files, files outside the project folder, other refs (tags, stash), and the three excluded paths. Tab path only: the headless call keeps `codex exec -s read-only`.
- Excluded (Inspect F12): `.stratum/state.json` is tracked and `hooks/st-phase.py:33,62` can write it on each user prompt and each skill the orchestrator starts, and both can happen while a point runs in the background. Syncthing writes `.syncthing.<name>.tmp` and `~syncthing~<name>.tmp` while it syncs this repo (`.stfolder` is in the repo root). Both would fail a clean review. Codex writing `.stratum/state.json` is not caught; that file holds only the phase, risk and feature folder. A file Syncthing finishes syncing during a review is a real change and still fails the point.
- Rationale: `--no-optional-locks` keeps `git status` from writing the index while the user uses git. HEAD is in the snapshot because a commit by Codex leaves `git status` clean.
- Limit: a path with a newline breaks the line format. `ponytail:` note.
- A non-git folder gives two empty snapshots, so no check. Stratum projects are git repos (`st-lock.sh` already needs git).

## R7. Settings record (FR-005)

- Decision: `<state dir>/<tab name>` with the tab id on line 1 and the launch options on the next lines, mode 600 in a mode 700 folder. `<state dir>` is `${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-tabs`. `st-advisor.sh` passes it to the tab script.
- Rationale: the Stratum Codex home goes (FR-002), and with it `$home/agents/<tab>`. herdr does not report launch options. The repo is the wrong place: the record is per machine and per herdr tab.
- The record decides nothing about closing (the scripts never close a tab). It only drives the one line of FR-005. No record, or a record for another tab id, prints `unknown settings` as the old values.

## R8. Codex start in the tab (FR-001)

- Decision: `herdr tab create --workspace <ws> --cwd <root> --label Codex --no-focus` (no `--env CODEX_HOME=...`), then `herdr agent start <tab name> --kind codex --pane <pane> --timeout 120000 -- --no-alt-screen [-m <model>] [-c model_reasoning_effort="<effort>"]` (no `-s read-only -a never`).
- Rationale: the new shell uses the user's own environment, so Codex reads `${CODEX_HOME:-~/.codex}`. `--no-alt-screen`, `-m` and `-c` exist in codex-cli 0.166.0.
- Start screens: the Folder access auto-enter (`scripts/st-codex-agent.sh:64-75`) goes. The spec edge case says a trust screen goes to the user. On `agent_not_ready` the script writes the marker and waits for `idle` or `done` with no time limit, like a review prompt (R3), and the watch reports the screen. A failed wait ends the point BLOCKED with the R3 reasons.

## R9. Exit codes from `st-codex-agent.sh`

- Decision: 0 answer written; 1 error (headless fallback, as today); 2 usage; 3 tab in use (headless fallback with `codex: headless (Codex tab in use)`); 4 BLOCKED (files changed, or the tab ended or failed after the review text was sent; no fallback); 5 name clash (headless fallback with `codex: headless (Codex tab name <name> in use elsewhere)`). 75 stays the lock's busy code. Exit 1 happens only before the review text is sent.
- Rationale: `st-advisor.sh:205-206` turns every nonzero code into the fallback today. 3, 4 and 5 do not clash with `st-lock.sh` (1, 2, 75).

## R10. Time budget (CHK015, D11)

- Decision: no time limit on the tab path. `st-advisor.sh` drops `timeout -k 10 540` around `st-lock.sh ... st-codex-agent.sh` (`:203`) and the `124|137` tab branch (`:205`). The tab script drops `SECONDS=0` and the `480 - SECONDS` timeouts. `herdr agent start --timeout 120000` stays: it is herdr's start-up wait, which returns `agent_not_ready`.
- The headless call keeps its own budget: `left=$((540 - SECONDS))`, the 60 s floor and `timeout -k 10 $left codex exec ...` (`:208-211`). The tab path falls back only before the review text is sent (exit 1, 3, 5), so `left` is close to 540 there, unless a start-up screen waited long; then the 60 s floor gives `BLOCKED: timed out`, as today.
- `watch` has no time limit either. It ends when a marker it saw is gone or dead, or when the orchestrator stops it after the point ends.
- The orchestrator runs the point with `run_in_background`. Assumed: a background Bash call has no Bash timeout, so a long review is not cut. The live run checks it with a review that runs past 10 minutes only if one happens; it is not forced (plan risk R3).

## R11. Screen text (CHK007)

- Decision: the last 20 lines of `herdr agent read <tab name> --source recent-unwrapped --lines 20`, with CSI escape codes removed (the `screen()` sed of today). Only `watch` prints it. `st-codex-agent.sh` no longer prints a screen, so its `screen()` goes.

## R12. Who answers what (CHK001, CHK005, CHK006)

- Decision: the exact lists are in `contracts/advisor-tab.md` section 4. The skill copies them word for word.
- Only a one-time yes (Inspect F1). codex-cli 0.166.0 also offers "Yes, and don't ask again for commands that start with ...", "... for these files" and "... for this command in this session", and `~/.codex/rules/default.rules` exists. Such a key writes a rule into the user's Codex config, so K3 bars it.
- One command only (Inspect F2). A chain (`;`, `&&`, `||`, `|`, `$(`, backticks) or a write or exec flag of an allowed tool (`git diff --output`, `git log --output`, `rg --pre`, `find -fprint`, `-fprintf`, `-fls`, `-delete`, `-exec`, `-execdir`, `-ok`, `-okdir`) can write outside the folder or use the network, which the snapshot does not see. K4 bars them.
- A test or lint command is in only without a write flag (`--fix`, `--write`, `-w`, `-u`, `--update-snapshots`). A cache the test writes is an ignored file and is not checked. A tracked or untracked file it writes fails the change check.
- A folder that is not trusted in the user's Codex shows the trust screen at start. It goes to the user: trusting a folder changes the user's Codex config.

## R13. Parallel points (CHK012)

- Decision: unchanged. `st-lock.sh --name codex-<workspace id> --timeout 50` keeps one tab run per workspace at a time. A second point waits up to 50 s, then ends `BLOCKED: Codex agent busy with another review`.

## R14. Callers that pin old text

- `skills/st-build/SKILL.md:95-97,116`, `skills/st-plan/SKILL.md:30-31`, `skills/st-init/SKILL.md:86`, `README.md:203,214-216`.
- Rule tests that pin those lines: `tests/test_risk_rules.sh` R7, R17, R19, R20; `tests/test_on_demand.sh:266-267,285-286`.
- `tests/test_advisor_waive.sh` runs `scripts/st-advisor.sh` (usage and exit 2 cases), so it runs with each `st-advisor.sh` task.
- Tabs started by today's code keep their names (`st-codex-<feature>`). The new scripts match only the new name, so they neither reuse nor close them. README tells the user to close them (Inspect F8).
- Script tests: `tests/test_codex_agent.sh` (all), `tests/test_advisor_matrix.sh:214-225,252-288,290-366`.
