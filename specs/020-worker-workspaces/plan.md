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
3. Replace `tab create` (line 301) with `workspace create --cwd "$path" --label "$L" --no-focus`, read `WS`, `TAB` (`.result.tab.tab_id`) and `PANE` (`.result.root_pane.pane_id`), then `tab rename "$TAB" "$N"`. Neither call goes through `h`: `h` stops on failure and overwrites `$r`. Use the `if ! r=$("${H[@]}" ... 2>"$e")` form of today's `tab create`.
4. FR-008: if `workspace create` fails, undo the worktree and branch as today. If `tab rename` fails, also `workspace close "$WS"` before the undo. The `stopped:` line keeps the herdr message, and the worktree undo failure keeps its `; left <path> and branch <N>` text.

### close (`scripts/st-worker.sh` lines 520-530)

Replace `h tab close "$TAB"` and the `st-workers` block with:

- `h tab list --workspace "$WS"`.
- If every tab label there is `$N` or `Codex`, and (with no `--machine`) `$WS` is not `$HERDR_WORKSPACE_ID`: `h workspace close "$WS"`. Otherwise: `h tab close "$TAB"`.
- With `--machine` the id guard is skipped: workspace ids are per server, so a remote id can equal the local one.
- The agent and tab check loop after it stays as is.

### list (`scripts/st-worker.sh` lines 540-565)

One `h workspace list` before the loop. Each `found` line gets the label of the tab's workspace as a new last field, `-` when not found, with control characters replaced by a space (jq `gsub("[[:cntrl:]]"; " ")`) so a tab in a user label cannot shift the fields.

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
