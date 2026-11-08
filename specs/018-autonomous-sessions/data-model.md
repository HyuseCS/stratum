# Data model: Autonomous build mode per session

No database. Files only.

## Mode folder

- Path: `<main checkout>/.stratum/autonomous/`. The main checkout is `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`, the same from every linked worktree.
- On a saved machine: `<repo>/.stratum/autonomous/`, where `<repo>` is the fifth roster field.
- Must be a directory and not a symlink. Anything else counts as off for every session.
- Made by the turn-on step with `mkdir -p`. Never removed by this feature. An empty folder means no session is on.
- Untracked, not in `.gitignore`, as today.

## Mode entry

- Path: `<mode folder>/<session id>`.
- Content: empty. Readers check only that it exists as a regular file and is not a symlink.
- Made only by the turn-on step of that session. Removed only by `autonomous-off` of that session.
- Workers never make, change, read or remove one (lock 2).

## Session id

- Source: `CLAUDE_CODE_SESSION_ID` (worker script, skills), `session_id` in the statusline input, first line of `<worker worktree>/.stratum/approve/session` (approve hook: the orchestrator's id).
- Rule: matches `^[A-Za-z0-9-]+$`. Empty or any other id: no entry is made or read, the session is off.

## Old flag

- Path: `<main checkout>/.stratum/autonomous` as a regular file (earlier versions).
- Counts as off for every session.
- Replaced by the folder when any session turns on. `autonomous-off` leaves it alone and reports "not on for this session".

## States of one session

| From | Event | To | Effect on other sessions |
|---|---|---|---|
| off | turn-on with a valid id, no symlink | on (entry exists) | none |
| off | turn-on with a bad id or a symlink | off, refused | none |
| on | `autonomous-off` | off (entry removed) | none |
| on | session crashes | entry stays, counts for that id only | none |
| on | session resumed with the same id | on | none |
| off | `autonomous-off` | off, "not on for this session" line | none |
