# Contract: shared Codex advisor tab

Every line in backticks below is exact text. Tasks and rule tests copy it word for word.

## 1. Tab name

D10. `st-advisor.sh` computes it in one place (run, `answer`, `watch`) and passes it to `st-codex-agent.sh`. It does not depend on the feature folder.

1. `herdr workspace list`. Take `label` of the entry in `.result.workspaces` whose `workspace_id` is `$HERDR_WORKSPACE_ID`.
2. Lowercase it. Every character outside `a-z0-9_-` becomes `-`. Keep the first 23 characters.
3. When the result has no letter or digit, or the list fails, or no entry matches: use `$HERDR_WORKSPACE_ID` through step 2 instead.
4. The name is `st-codex-` plus the result: at most 32 characters, matching `^[a-z][a-z0-9_-]{0,31}$`.

Examples: `stratum` -> `st-codex-stratum`; `Stratum Main!` -> `st-codex-stratum-main-`; `71-worker-workspace` -> `st-codex-71-worker-workspace`; label `~` with id `w3S` -> `st-codex-w3s`; a 40-character label -> its first 23 characters.

## 2. `scripts/st-codex-agent.sh`

```text
st-codex-agent.sh <tab name> <prompt file> <answer file> <state dir> [-m <model>] [-c <key=value>]
```

- `<tab name>` must match `^[a-z][a-z0-9_-]{0,31}$`, else the usage line and exit 2. `<state dir>` is `${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-tabs`.
- No `CODEX_HOME`, no `auth.json` check, no `config.toml` entry check.

Flow:

1. `herdr agent list`. The tab is the entry with `name` = tab name, `workspace_id` = `$HERDR_WORKSPACE_ID`, `cwd` = `pwd -P`. An entry with the tab name and another `workspace_id` or `cwd` is a clash: print `codex: tab name <tab name> in use elsewhere`, exit 5. No tab is made, started, typed into or closed.
2. Found: compare the settings record (data-model.md) with `<tab id>` and the options. On a difference print `codex: the Codex tab runs with <old>, advisor.json asks for <new>. Close the tab to apply.` `<old>` and `<new>` are the options joined by single spaces, `Codex defaults` when there are none, and `<old>` is `unknown settings` when there is no record for this tab id. The tab is reused.
3. Not found: `herdr tab create --workspace <ws> --cwd <root> --label Codex --no-focus`, then `herdr agent start <tab name> --kind codex --pane <pane> --timeout 120000 -- --no-alt-screen [options]`, with today's 10 tries on `agent_pane_busy` (all 10 busy: `ERROR: <first line>`, exit 1). Write the settings record. On `agent_not_ready`: write the marker, then `herdr agent wait <tab name> --until idle --until done` (no `--timeout`); a failed wait ends as step 8 says.
4. Snapshot (data-model.md).
5. `herdr agent get <tab name>`: `agent_status` `working` or `blocked` prints `codex: tab in use`, exit 3. Nothing is typed. A reused tab has no marker yet.
6. Write the marker `<state dir>/<tab name>.review` (its pid), removed by a trap on exit. Append today's three nonce lines to the prompt file.
7. `herdr agent prompt <tab name> "Read the review request in <prompt file> and follow it. Change no file." --wait --until done --until idle`, with no `--timeout` (D11).
8. Snapshot again, whatever step 7 returned. A difference: print `BLOCKED: Codex changed files during the review: <path>, <path>` (sorted, each once, `HEAD` when HEAD moved), exit 4.
9. Step 7 failed:
   - error code `agent_blocked`: print `codex: tab in use`, exit 3.
   - `herdr agent get <tab name>` fails (the user closed the tab or Codex exited): print `BLOCKED: the Codex tab ended during the review`, exit 4.
   - else print `BLOCKED: the Codex tab failed during the review: <first line of the herdr error>`, exit 4.
   The step 3 wait, when it fails, takes the last two rules.
10. Read the answer between the markers as today. No marker pair: `BLOCKED: no answer between the markers`, exit 4 (today `ERROR:` and exit 1; D11 bars the headless run once the review started). Last line `codex: tab <tab name>`, exit 0.

Never: `herdr tab close`, `herdr pane close`, any key sent by the script itself, a `--timeout` on `agent prompt` or `agent wait`.

Exit codes: 0 answer written; 1 error before the review text was sent, headless fallback; 2 usage; 3 tab in use, headless fallback; 4 BLOCKED, no fallback; 5 name clash, headless fallback.

## 3. `scripts/st-advisor.sh`

Removed: the `codex-home` command and `|codex-home` in the usage line, `dir`, `entry`, `add_entry`, the `BLOCKED: no Stratum Codex home` check. `st-advisor.sh codex-home` now prints the usage line and exits 2.

Point run inside herdr (`HERDR_ENV=1`, `HERDR_WORKSPACE_ID` set, `herdr` on PATH):

- Calls `bash st-lock.sh --name codex-<workspace id> --timeout 50 -- bash st-codex-agent.sh <tab name> <prompt.tab> <answer.json> <state dir> <options>` with no `timeout -k 10 540` around it (D11).
- Prints each `codex: the Codex tab runs with ` line of the tab output.
- rc 0: last line `codex: tab <tab name>`.
- rc 3: headless call as today, last line `codex: headless (Codex tab in use)`.
- rc 5: headless call as today, last line `codex: headless (Codex tab name <tab name> in use elsewhere)`.
- rc 4: `block "<reason>"` with the reason from the `BLOCKED: ` line of the tab output: prints `BLOCKED: <reason>` and `record: <feature dir>/advisor.md`, appends `## <point> | <ts> | sha256 <hash> | BLOCKED` and `reason: <reason>` to `advisor.md`, exit 1. No headless call.
- rc 75: as today. The `124|137` tab branch goes. Other: the `ERROR:` line as today, then the headless call with today's 540 s budget and 60 s floor.
- The usage line becomes `usage: st-advisor.sh plan|test|diff|decisions|change|round|check|continued|waive|note|talk|count|answer|watch ...`.

New command `answer`:

```text
st-advisor.sh answer --keys <key> [<key>...]
```

- Each key must match `^[A-Za-z0-9+_][A-Za-z0-9+_-]{0,15}$` (no leading `-`, so herdr never reads a key as a flag). Else the usage line, exit 2, no herdr call.
- Not in herdr: `not in herdr`, exit 1.
- The marker is missing, its pid is not alive, or `herdr agent get <tab name>` does not say `blocked`: `no review waits in the Codex tab`, exit 1, no key sent.
- Else `herdr agent send-keys <tab name> <key>...`, print `sent: <key> ...`, exit 0.

New command `watch`:

```text
st-advisor.sh watch
```

- Not in herdr: `not in herdr`, exit 1.
- Every 2 s: when the marker has a live pid and the tab is `blocked`, and this blocked spell is not reported yet, print `codex tab waits: <tab name>`, the screen (section 6), then `codex tab waits: end`. A spell ends when the tab is not `blocked`.
- Exits 0 when a marker it saw is gone or dead (the review ended). No time limit: the orchestrator stops it when the point ends.
- Prints nothing for a blocked tab with no live marker (the user's own turn).

## 4. Orchestrator rules (skill text)

Each block is the exact text of one skill line. The rule tests pin each line with `grep -F`. `st-codex-<workspace label>` is literal text in the skill and README.

`skills/st-build/SKILL.md`, Advisor section.

K1, replaces line 95 (D6):

```text
- Start `bash <plugin root>/scripts/st-advisor.sh watch` with the Monitor tool, then run `bash <plugin root>/scripts/st-advisor.sh <point> ...` with Bash `run_in_background`, both from the project root (a worktree's root for the test point of a `[P]` task). Change no file in that folder until the point ends. When it ends, stop the watch and handle the point's output.
```

K2, replaces line 96 (FR-001, FR-003):

```text
- Never run `codex` to build or fix. In herdr, Codex runs as the `st-codex-<workspace label>` agent in the `Codex` tab of this workspace, with the user's own Codex setup, and the user can watch it there. Otherwise it runs in the background in the read-only sandbox. The last line says which: `codex: tab st-codex-<workspace label>` or `codex: headless (<reason>)`. Show it to the user.
```

K2a, a new line right before K2 (FR-007, CHK010):

```text
- Codex only reviews: it never creates, changes or deletes a file, and never builds or fixes anything. The user may use the Codex tab for their own work.
```

K3 (FR-011):

```text
- On a `codex tab waits:` line, read the screen lines after it. A prompt on the allow list: answer it with `bash <plugin root>/scripts/st-advisor.sh answer --keys <key>`, the key of the one-time yes only ("Yes, proceed", "Yes, just this once"). Never pick an option that says "don't ask again", "allow ... for this session", "in the future" or "for these files", or one that names a host. Every other prompt: show the user the exact screen lines and leave the tab open.
```

K4, allow list (FR-011, CHK001, CHK005):

```text
  Allow list: read a file or list a folder anywhere, except a `.env` file or a key, credential, token or other secret file; run one command only, with no `;`, `&&`, `||`, `|`, `$(` or backticks: `git log`, `git diff`, `git show`, `git status`, `git blame`, `ls`, `cat`, `head`, `tail`, `wc`, `grep`, `rg` or `find`, with no `>`, `>>`, `tee`, `--output`, `--pre`, `-fprint`, `-fprintf`, `-fls`, `-delete`, `-exec`, `-execdir`, `-ok` or `-okdir`; or the project's test or lint command with no `--fix`, `--write`, `-w`, `-u` or `--update-snapshots`.
```

K5, never list (FR-011):

```text
  Never approve a file write, move or delete, a git change (`commit`, `checkout`, `switch`, `reset`, `restore`, `stash`, `add`, `rm`, `mv`, `merge`, `rebase`, `pull`, `fetch`, `push`, `tag`, `branch`, `clean`, `apply`, `am`), an install, network use, a `.env` file or secret, or a change to Codex settings or folder trust.
```

K6 (FR-005, CHK004):

```text
- `codex: the Codex tab runs with ...`: show the line to the user word for word. The tab keeps its old values until the user closes it.
```

K7 (FR-008, CHK011, CHK013):

```text
- `BLOCKED: Codex changed files during the review: <paths>`: show the paths. Revert nothing. The user checks them with `git diff` and keeps or reverts them, then says run the point again or continue (`continued`).
```

K8 (FR-012):

```text
- `BLOCKED: the Codex tab ended during the review` or `BLOCKED: the Codex tab failed during the review: ...`: show the line. A review in the tab has no time limit; it ends early only this way. Run the point again on the user's word, or `continued`. To stop a hung review, the user presses Esc in the tab or tells you to stop the point.
```

Removed from `skills/st-build/SKILL.md`: line 97 (`codex-home` on request) and line 116 (`BLOCKED: no Stratum Codex home`). Removed from `skills/st-init/SKILL.md`: line 86.

`skills/st-plan/SKILL.md` step 4, K9 replaces lines 30-31:

```text
4. **Advisor.** Run `bash <plugin root>/scripts/st-advisor.sh plan <feature dir>` as "Advisor" in `<plugin root>/skills/st-build/SKILL.md` says: the watch first, then the point in the background.
   Codex reads spec, plan and tasks and only advises: a simpler or better approach, tasks to cut or merge. It does not validate; st-inspect does.
```

## 5. README.md

K10, line 203 becomes (US1 changes only its second sentence, from "Codex runs in the read-only sandbox and only reviews: it never builds or fixes." to "Codex only reviews: it never builds or fixes."; US3 changes the first):

```text
  The orchestrator starts `scripts/st-advisor.sh watch`, runs `scripts/st-advisor.sh` in the background, and waits for the answer. Codex only reviews: it never builds or fixes.
```

K11, lines 214-216 become (line 3 "A review in the tab has no time limit ..." is US3, line 4 "Each review in the tab ..." is US2, the other lines are US1):

```text
  Inside herdr, Codex runs as the agent `st-codex-<workspace label>` in a `Codex` tab of your workspace, one per workspace, with your own Codex setup: your Codex home, config, login, history, skills, trust and approvals. You can watch each review there and use the tab yourself between points. Review prompts and the files Codex reads land in your own Codex history.
  A point never types into the tab while your own turn runs, and never closes it. When `model` or `effort` in `.stratum/advisor.json` changed, the point prints a line: close the tab to apply the new values.
  A review in the tab has no time limit. It ends early only when the tab ends (you close it or Codex exits): the point is then `BLOCKED`, and it does not run the review in the background. Press Esc in the tab to stop a hung review.
  Each review in the tab compares HEAD and the changed and untracked files before and after the turn. Any difference ends the point `BLOCKED` with the files named. Nothing is reverted.
  The last line of each Codex point says where Codex ran: `codex: tab st-codex-<workspace label>` or `codex: headless (<reason>)`. When that name is live in another workspace or folder (two workspaces with the same label, or a worktree in the same workspace), the point runs in the background and says so.
  Stratum no longer uses `~/.local/state/stratum/codex-home`. You may delete that folder. Close any old `st-codex-<feature>` Codex tab yourself: points no longer use or close it.
```

## 6. Screen text

Printed only by `watch`. The last 20 lines of `herdr agent read <tab name> --source recent-unwrapped --lines 20`, CSI escape codes removed (`sed $'s/\e\\[[0-9;]*[A-Za-z]//g'`).

## 7. Test cases

`tests/test_codex_agent.sh` (C) and `tests/test_advisor_matrix.sh` (M). "Guard" marks a negative control: the build task breaks the guard and sees the case go red.

| Id | Story | Case | Expect |
|----|-------|------|--------|
| C1 | US1 | no tab | `tab create --workspace <ws> --cwd <root> --label Codex --no-focus`; `agent start <tab name> --kind codex --pane <pane> --timeout 120000 -- --no-alt-screen -m m1 -c model_reasoning_effort="high"`; no `-s`, `-a`, `--env`; record = tab id, options; modes 700/600 |
| C2 | US1 | tab idle, record matches | no create, start or close; one prompt; no settings line |
| C3 | US1 | record `-m m1`, run `-m m2` (guard FR-004/005) | no close, create or start; prompt sent; exact line `codex: the Codex tab runs with -m m1, advisor.json asks for -m m2. Close the tab to apply.`; exit 0 |
| C3b | US1 | tab, no record | line with `unknown settings` |
| C4 | US1 | tab `working` (guard FR-006) | exit 3, `codex: tab in use`, no prompt, no send-keys, no marker |
| C5 | US1 | tab `blocked` | as C4 |
| C6 | US1 | tab `done`, tab `unknown` | prompt sent |
| C7 | US1 | prompt returns `agent_blocked` | exit 3 |
| C8 | US1 | every case of the file (guard FR-004) | no `tab close` in the whole run's log |
| C9 | US1 | the tab name live in another workspace, and in this workspace with another cwd (guard FR-003 clash) | exit 5, `codex: tab name st-codex-t1 in use elsewhere`; no tab create, agent start, prompt, send-keys or close |
| C10 | US2 | Codex changes a tracked file (guard FR-008) | exit 4, `BLOCKED: Codex changed files during the review: a.txt`, new content kept |
| C11 | US2 | Codex adds an untracked file | names it |
| C12 | US2 | Codex changes an untracked file that was there | names it |
| C13 | US2 | Codex removes an untracked file | names it |
| C14 | US2 | Codex commits (tree clean after) | names `HEAD` |
| C15 | US2 | no change | exit 0, answer written |
| C16 | US2 | tree dirty before, same after | exit 0 |
| C17 | US3 | prompt argv (guard FR-009, D11) | ends `--wait --until done --until idle`; no `--until blocked`; no `--timeout` |
| C18 | US3 | prompt fails, `agent get` says `agent_not_found` (guard FR-012) | exit 4, `BLOCKED: the Codex tab ended during the review`; no close; no `ERROR:` line |
| C19 | US3 | prompt fails with `agent_prompt_stalled`, agent still there | exit 4, `BLOCKED: the Codex tab failed during the review: <first line>`; no close |
| C20 | US3 | `agent_not_ready` at start | `agent wait <tab name> --until idle --until done` with no `--timeout`, before the prompt; prompt runs |
| C21 | US3 | `agent_not_ready`, wait fails, agent gone | exit 4, `BLOCKED: the Codex tab ended during the review`; no prompt; no close |
| C22 | US3 | marker | holds a live pid during the prompt; gone after exit; never written in C4; written before `agent wait` in C20 |
| C23 | US3 | no marker pair in the answer (guard D11) | exit 4, `BLOCKED: no answer between the markers` |
| M1 | US1 | `codex-home` (guard FR-002) | usage line, exit 2, no `codex-home` folder |
| M2 | US1 | tab path | no `--env CODEX_HOME`; record under `codex-tabs`; last line `codex: tab <tab name>` |
| M3 | US1 | two feature folders | the same tab name in both `agent start` lines |
| M4 | US1 | tab `working` | codex exec runs; no `agent prompt`; last line `codex: headless (Codex tab in use)` |
| M5 | US1 | tab idle, record differs | the settings line is in the output |
| M6 | US2 | Codex writes a file in the tab | first line `BLOCKED: Codex changed files during the review: <file>`; BLOCKED record; codex exec not run; file kept |
| M7 | US3 | `answer --keys y`, no marker (guard FR-010) | `no review waits in the Codex tab`, exit 1, no send-keys |
| M8 | US3 | marker with a dead pid | as M7 |
| M9 | US3 | live marker, tab `idle` | as M7 |
| M10 | US3 | live marker, tab `blocked` | `agent send-keys <tab name> y` once, `sent: y`, exit 0 |
| M11 | US3 | key `a;b`, key `$(x)`, key `-x`, key `--help` | usage, exit 2, no herdr call |
| M12 | US3 | `answer` or `watch` outside herdr | `not in herdr`, exit 1 |
| M13 | US3 | `watch`, live marker, tab `blocked` | `codex tab waits: <tab name>`, screen, `codex tab waits: end`, once per spell; exit 0 after the marker goes |
| M14 | US3 | `watch`, no marker, tab `blocked` | no output within 3 s |
| M15 | US3 | the tab ends during the review (guard FR-012, no headless after a started review) | first line `BLOCKED: the Codex tab ended during the review`, then `record:`; BLOCKED record; codex exec not run |
| M18 | US3 | tab path is not wrapped in `timeout` (guard D11) | the fake `timeout` logs its arguments; no logged call runs `st-lock.sh` or `st-codex-agent.sh` |
| M19 | US3 | no marker pair in the tab answer (old k6, guard D11) | first line `BLOCKED: no answer between the markers`; codex exec not run |
| M20 | US3 | live prompt screen, filled by T019 | `watch` with the saved real screen prints those lines between `codex tab waits:` and `codex tab waits: end`. Added by T019; not a guard and not counted for SC-005 before then |
| M16 | US1 | name rule (guard FR-003 name), fake `herdr workspace list` | label `stratum` -> `agent start st-codex-stratum`; `Stratum Main!` -> `st-codex-stratum-main-`; a 40-character label -> `st-codex-` plus its first 23 characters, 32 in all; label `~` with id `wQ9` -> `st-codex-wq9`; no entry for the id -> `st-codex-wq9` |
| M17 | US1 | the name live in another workspace | codex exec runs; no `tab create`, `agent start` or `agent prompt` in `herdr.log`; last line `codex: headless (Codex tab name st-codex-<label> in use elsewhere)` |
