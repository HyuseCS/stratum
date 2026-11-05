# Data model: Shared Codex advisor tab

No database. Three small things live on disk or in herdr.

## Advisor tab (herdr agent)

| Field | Value |
|-------|-------|
| name | `st-codex-<workspace label>`, at most 32 characters, `contracts/advisor-tab.md` section 1 (D10) |
| workspace_id | `$HERDR_WORKSPACE_ID` of the point |
| cwd | `pwd -P` of the point (the project root or a linked worktree root) |
| tab label | `Codex` |
| agent_status | `idle`, `working`, `blocked`, `done` or `unknown`, read from herdr |

Rules:
- At most one per workspace (FR-003). The scripts find it in `herdr agent list` by name, `workspace_id` and `cwd`.
- The name live with another `workspace_id` or `cwd` is a clash: the point runs headless and says so. The scripts do not touch that agent.
- In use when `agent_status` is `working` or `blocked` (FR-006).
- The scripts never close it (FR-004). Only the user does.

States seen by a point:

```text
absent  --point-->  started (tab create + agent start)  --> idle --> review turn (working <-> blocked) --> done/idle
idle/done/unknown --point--> review turn
working/blocked   --point--> not touched, review runs headless
review turn --tab closed or Codex exits--> point BLOCKED, no headless run (no time limit otherwise)
```

## Settings record

Path: `<state dir>/<tab name>`, `<state dir>` = `${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-tabs`. Folder mode 700, file mode 600.

| Line | Value |
|------|-------|
| 1 | herdr tab id, matches `^[A-Za-z0-9:_-]+$` |
| 2.. | the launch options, one per line: `-m`, `<model>`, `-c`, `model_reasoning_effort="<effort>"` (none when `advisor.json` sets neither) |

Rules:
- Written only when a point starts a new tab.
- On reuse, a record whose line 1 is not the live tab id counts as no record.
- A difference prints the FR-005 line (contract section 3). The tab stays.

## Review marker

Path: `<state dir>/<tab name>.review`. One line: the pid of the running `st-codex-agent.sh`.

Rules:
- Written after the in-use check passes, or right after a new tab starts. Removed on exit by a trap.
- Present with a live pid means "a review drives the tab now". `watch` and `answer` act only then.

## Review snapshot

Text, built twice per review (before the prompt, after the prompt call returns). Never written to disk.

| Line | Value |
|------|-------|
| 1 | `HEAD <sha>` (`git rev-parse -q --verify HEAD`, empty in a repo with no commit) |
| 2.. | `<path>\tindex\t<raw entry>` for each entry of `git --no-optional-locks diff --cached --raw --no-abbrev --no-renames -z` with the same pathspec as the next row (modes, blob ids and status of each staged change) |
| next | `<path>\t<XY>\t<mode> <sha256>` for each entry of `git --no-optional-locks status --porcelain=v1 -z --untracked-files=all --no-renames -- . ':(exclude).stratum/state.json' ':(exclude,glob)**/.syncthing.*.tmp' ':(exclude,glob)**/~syncthing~*.tmp'`. `<mode>` is `stat -c %f` of the path, symlinks not followed (file type and permission bits). `<sha256>` is the hash of the link target text (`readlink`) for a symlink, of the file content for a regular file. Both empty when the path is gone |

Rules:
- Any line that differs makes the point BLOCKED, with each differing path (and `HEAD`) named once, in sorted order. The name is the text before the first tab of the line.
- Covers tracked changes (staged and in the worktree), untracked files that are not ignored, file modes, symlink targets, and HEAD. Not ignored files, not files outside the folder, not `.stratum/state.json` (written by `hooks/st-phase.py`) and not Syncthing temp files (research R6).
