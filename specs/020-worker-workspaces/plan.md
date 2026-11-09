# Implementation Plan: Workers in their own herdr workspaces, each with its own Codex tab

**Branch**: `worker-f94` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/020-worker-workspaces/spec.md`

## Summary

`st-worker.sh start` makes one new herdr workspace per worker (`workspace create --cwd <worktree> --label "<orchestrator> / <id>: <task words>" --no-focus`) and renames its default tab to `worker-<id>`. It no longer adds a tab to the orchestrator's workspace, and the saved-machine path (main checkout workspace, `st-workers`) goes away: the same call runs with `--machine`. `close` closes the whole workspace when it holds only the worker tab and `Codex` tabs, else only the worker tab. `list` adds the workspace label as the last field. `st-advisor.sh` `tabname` names the Codex agent `st-codex-<branch>` when the current branch is a worker branch (`worker-<id>`). The skill text drops the old layout.

## Technical Context

**Language/Version**: Bash 5 (scripts), Python 3 inline in `st-advisor.sh` (unchanged)

**Primary Dependencies**: herdr 0.9.4 (`workspace create`, `tab rename <TAB_ID> <LABEL>`, `workspace close <id>`, `tab list --workspace`), jq, git

**Storage**: N/A (herdr state only)

**Testing**: `bash tests/test_st_worker.sh` (herdr, ssh, git stubs), `bash tests/test_advisor_matrix.sh` (fake herdr in `hbin2`), `bash tests/test_worker_rules.sh` (skill phrase greps)

**Target Platform**: Linux, PC and laptop (saved machine through `herdr --machine`)

**Project Type**: CLI scripts inside the Stratum Claude Code plugin

**Performance Goals**: N/A. `start` adds one local `workspace list` and one `tab rename`. `close` adds one `tab list --workspace`. `list` adds one `workspace list`.

**Constraints**: Keep the diff small: issue #93 changes `answer`, the `wait`/`watch` screen hashing and the Codex answer reader in the same scripts. Touch only `start`, `close`, `list` and `tabname`. herdr agent names must match `[a-z][a-z0-9_-]{0,31}` (32 characters max, `herdr --skill` line 57).

**Scale/Scope**: about 30 changed lines in `scripts/st-worker.sh`, 2 in `scripts/st-advisor.sh`, 3 lines of skill text, and test changes.

## Constitution Check

No `.stratum/constitution.md` in this repo (base repo, no constitution). No app ordinances. Gate: pass.

Build code rules (from the brief):

- Minimal code. No new functions, helpers or options. Reuse `h`, `get`, `rx`, `stop`, `jq` the way the code around them does.
- No explanatory comments. Only `# ponytail: <limit>, <when to upgrade>` markers on deliberate shortcuts: the 30-character cut of the task words, the 32-character cut of the Codex name (D14), and the `Codex` label match in `close`.
- Do not touch `answer`, `wait`, `watch`, `screen`, `find_worker`, or `scripts/st-codex-agent.sh`.

## Design

### start (`scripts/st-worker.sh` lines 281-308)

1. After the `--repo ~` resolution (line 275), build the label `L` (rules in [data-model.md](data-model.md)). The orchestrator part comes from a plain `herdr workspace list` (never `"${H[@]}"`: the orchestrator is local) only when `HERDR_ENV=1` and `HERDR_WORKSPACE_ID` is set. A failed or empty lookup falls back to `basename "$repo"`, with no stop.
2. Delete the `if [ -z "$m" ]; then WS=... else ... st-workers ... fi` block (lines 281-294).
3. Replace `tab create` (line 301) with `workspace create --cwd "$path" --label "$L" --no-focus`, read `WS`, `TAB` (`.result.tab.tab_id`) and `PANE` (`.result.root_pane.pane_id`), then `tab rename "$TAB" "$N"`. Neither call goes through `h`: `h` stops on failure and overwrites `$r`. The task-word cut runs with `LC_ALL=C.UTF-8` so it counts characters. A `workspace create` answer without a workspace, tab or pane id goes to the undo below with `no <key> in the herdr answer`. Use the `if ! r=$("${H[@]}" ... 2>"$e")` form of today's `tab create`.
4. FR-008: if `workspace create` fails, undo the worktree and branch as today. If `tab rename` fails, also run `"${H[@]}" workspace close "$WS"` (not through `h`) before the undo, and go on to the undo even if that close fails. `WS` comes from `.result.workspace.workspace_id`. Clear `TAB= PANE=` with `BR= WT=` before the stop. The `stopped:` line keeps the herdr message, and the worktree undo failure keeps its `; left <path> and branch <N>` text.

### close (`scripts/st-worker.sh` lines 520-530)

Replace `h tab close "$TAB"` and the `st-workers` block with:

- `h tab list --workspace "$WS"` stops with `no .result.tabs in the herdr answer` when the answer has no tabs array.
- If the worker tab `$N` is in the list, every tab label there is `$N` or `Codex`, and (with no `--machine`) `$HERDR_WORKSPACE_ID` is not empty and `$WS` differs from it: `h workspace close "$WS"`. Otherwise: `h tab close "$TAB"`. A local close with an empty `HERDR_WORKSPACE_ID` closes only the tab.
- With `--machine` the id guard is skipped: workspace ids are per server, so a remote id can equal the local one.
- The agent and tab check loop after it stays as is.

### list (`scripts/st-worker.sh` lines 540-565)

One `h workspace list` before the loop. An answer with no `.result.workspaces` array stops with `no .result.workspaces in the herdr answer`. Each `found` line gets the label of the tab's workspace as a new last field, `-` when not found or when the label is empty or missing, with control characters replaced by a space (jq `gsub("[[:cntrl:]]"; " ")`) so a tab in a user label cannot shift the fields.

### tabname (`scripts/st-advisor.sh` lines 6-22)

First line of `tabname`: when `git symbolic-ref -q --short HEAD` matches `^worker-[a-z0-9][a-z0-9-]{0,24}$`, print `st-codex-<branch>` and return. Else the label slug path runs as today, so the orchestrator name does not change. The Codex tab already opens in `$HERDR_WORKSPACE_ID`, which is the worker's own workspace (live probe, spec Assumptions). Why the branch: see [research.md](research.md) R2.

Long ids (D14): `st-codex-worker-` is 16 characters, so ids over 16 characters give a name over herdr's 32-character limit. `tabname` cuts the name to 32 characters, as the label slug path does today. Two ids over 16 characters with the same first 16 clash, and the second point goes headless ("in use elsewhere"). This gets a `# ponytail:` marker.

### Docs (D15)

`README.md:266`, `README.md:270` and `skills/st-build/SKILL.md:97` get one clause each for the worker name `st-codex-worker-<id>`. Rows R7 and R17 in `tests/test_risk_rules.sh` grep lines 97 and 266 word for word, so they change first.

### Skill (`skills/st-worker/SKILL.md`)

Step 4: replace the layout sentence (tested as W14 in `tests/test_worker_rules.sh`) with the per-worker workspace and its name. Step 11: `close` closes the worker's workspace with its Codex tab. Step 12: `found` lines end with the workspace name. No `st-workers`.

## Decisions taken in Plan

- D14: cut `st-codex-worker-<id>` to 32 characters (herdr name limit).
- D15: add the worker Codex name to `README.md:266,270` and `skills/st-build/SKILL.md:97`, and update rows R7 and R17 in `tests/test_risk_rules.sh`.

No open decisions.

## Security and safety notes

- `workspace close` kills every pane and agent in that workspace. Guards: it runs only after every existing refusal of `close` (working or blocked worker, open PR, unreadable PRs, symlinked `.stratum`). It closes only a workspace whose tabs are all `worker-<id>` or `Codex`. Locally it never closes `$HERDR_WORKSPACE_ID`. It never uses `--group`.
- The workspace label comes from the task file and from herdr. It goes to herdr as one argv element and never into an `rsh`, `ssh` or `bash -c` string.
- External services: herdr (local and `--machine`) and ssh, as today. No secrets, no personal data, no data model or access-rule change.

## Project Structure

### Documentation (this feature)

```text
specs/020-worker-workspaces/
├── spec.md
├── decisions.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/cli.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/st-worker.sh          # start, close, list
scripts/st-advisor.sh         # tabname
skills/st-worker/SKILL.md     # steps 4, 11, 12
skills/st-build/SKILL.md      # line 97, worker Codex name (D15)
README.md                     # lines 266, 270, worker Codex name (D15)
tests/test_risk_rules.sh      # rows R7, R17 (D15)
tests/test_st_worker.sh       # stub: workspace create writes tc.json, tab rename; start, close, list cases
tests/test_advisor_matrix.sh  # worker Codex name cases
tests/test_worker_rules.sh    # W14 phrase, st-workers gone row
```

**Structure Decision**: existing layout, no new files outside the feature folder.

## Complexity Tracking

None.

## Validate

Date: 2026-11-09. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | PASS | Local only. herdr 0.9.4 client and server (`herdr status`). `workspace create --cwd --label --no-focus`, `tab rename <TAB_ID> <LABEL>` and `workspace close <workspace_id>` exist (`--help`). `herdr --skill` line 89: `workspace create` returns `.result.workspace`, `.result.tab` and `.result.root_pane`. Line 57: agent names match `[a-z][a-z0-9_-]{0,31}`. jq 1.8.2, bash 5.3.20, git and python3 are installed. No new dependency. Baseline: test_st_worker, test_advisor_matrix, test_worker_rules, test_risk_rules, test_on_demand, test_state and test_lane_steps exit 0 with no FAIL line. Not checked: the laptop (ssh timed out), so the remote herdr version and remote `tab rename` are not proven. Quickstart step 6 is the proof. |
| 2. Test coverage per requirement | CONCERN | F2, F3, F4, F5 |
| 3. Breaking changes | CONCERN | F6, F7. The `list` line gets a new last field. Only the skill (step 12) and the tests L1, L2 and R12 read it, and T010 and T012 change them. No stored data, no migration. |
| 4. Security and privacy | PASS | `workspace close` runs only after every refusal of `close`. It runs only when every tab label is `worker-<id>` or `Codex`, and locally never on `$HERDR_WORKSPACE_ID`. NC8 (T007) proves that guard can fail. No `--group`. The label goes to herdr as one argv element, never into `rx`/`rsh`. `list` replaces control characters in the label (L3). No secrets and no personal data. |

F2. tasks.md:77 (T014), spec.md:145 (FR-012). FR-012 says all existing tests must pass, but T014 and T012 run only 7 suites. `tests/test_advisor.sh` and `tests/test_advisor_waive.sh` load the changed `scripts/st-advisor.sh`, and no task runs them. Low risk: both unset `HERDR_ENV` (line 39), so `tabname` does not run. -> st-plan: add both suites to the T014 test command.
F3. tasks.md:33 (T004), plan.md:47-48. The `tab rename` failure path has three gaps. (1) T004 reads `TAB` and `PANE` before the rename. "Today's undo" (`scripts/st-worker.sh:304`) clears only `BR= WT=`, but S13c (tasks.md:31) and contracts/cli.md:17-18 expect `-` in fields 4 to 7. (2) T004 does not say what to do when the cleanup `workspace close` fails. Through `h`, `stop` runs before the worktree undo. (3) T004 names no jq path for `WS`. -> st-plan: add `TAB= PANE=` to the undo. Run `workspace close` without `h`, and on failure continue to the worktree undo. Read `WS` from `.result.workspace.workspace_id`, as `scripts/st-worker.sh:292` does.
F4. spec.md:122, spec.md:126, tasks.md:31 (WS4). Two spec edge cases have no test. (1) The orchestrator's workspace exists but has an empty label. WS4 tests only a missing workspace (`HWS=wNone`). (2) A leftover workspace with the same label but no `worker-<id>` tab does not block `start`. -> st-plan: add both cases to T002.
F5. tasks.md:56 (T007), tests/test_st_worker.sh:1564. T007 adds CL1 to CL4, but `CL1` already exists in that file ("CL1 close: exit 0, the approve folder is gone"). -> st-plan: use new ids, for example WC1 to WC4.
F6. tasks.md:45 (T005), branch `093-autonomous-prompts` specs/019-autonomous-prompts/tasks.md:104 (T016). Issue #93 adds M25, M26 and M27 to `tests/test_advisor_matrix.sh`, and T005 adds M25a to M25d to the same file. Both features also change `scripts/st-worker.sh`, `tests/test_st_worker.sh` and `tests/test_worker_rules.sh`. The hunks are in different regions (#93: `:168-170`, `:253`, `answer`, autonomous-on). -> st-plan: give T005 ids that #93 does not use, for example M30a to M30d. Whichever branch merges second rebases and runs test_st_worker, test_advisor_matrix and test_worker_rules again.
F7. research.md:18, data-model.md:31, scripts/st-worker.sh:291. Two transition leftovers. (1) research.md:18 says the extra Codex tab of an old-layout worker "ends when those workers close". It does not end: an old-layout worker sits in the orchestrator's workspace, so `close` takes the tab-only path. Its `Codex` tab and its `st-codex-worker-<id>` agent stay there. (2) An `st-workers` workspace on the laptop keeps the first tab that its own `workspace create` made. The new rule never closes it after its last old worker closes, but the old rule did. -> st-plan: correct R2 and add a one-time by-hand note to skill step 11 or to quickstart.
