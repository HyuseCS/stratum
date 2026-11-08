# Contract: autonomous mode entries

Layout and fields: see `../data-model.md`.

## C1. Reader rule (FR-004, FR-005, FR-006, FR-008)

A session id `S` is on only when all are true:

1. `S` matches `^[A-Za-z0-9-]+$`.
2. `<folder>` is a directory and not a symlink.
3. `<folder>/S` is a regular file and not a symlink.

Every reader uses this rule and nothing else:

| Reader | `S` | `<folder>` |
|---|---|---|
| `statusline/st-statusline.sh` | `session_id` of the input | main checkout of `cwd`, else `<project>/.stratum/autonomous` as today |
| `hooks/st-approve.py` PermissionRequest | first line of `<worker root>/.stratum/approve/session` | main checkout of the worker root |
| `scripts/st-worker.sh` before `start --autonomous`, `approve`, `pass` | `$CLAUDE_CODE_SESSION_ID` | main checkout of the current dir |

When the rule fails, `st-worker.sh` prints `Autonomous build mode is off for this session.` and exits 1, as today.

## C2. Turn-on step (FR-001, FR-002, FR-005, FR-006, FR-008)

Steps, in order, the same here and on a saved machine (`start --autonomous --machine`):

1. Id fails C1.1: refuse, make nothing.
2. `.stratum` (saved machine) or `<folder>` is a symlink: refuse, make nothing.
3. `<folder>` is a regular file (old flag): remove it with a non-recursive `rm -f -- "<folder>"` on the exact path, with no trailing slash and no recursive option. A failed remove is ignored before step 4.
4. `mkdir -p <folder>`. It is not a directory afterwards: refuse.
5. `<folder>/S` is a symlink: refuse. Else make it empty (`: >`).

It never reads, changes or removes any other entry.

Saved machine: a refusal prints `cannot write .stratum/autonomous on <m>: <reason>` and exits 1 before `worktree add`, as today (tests AM4-AM6).

Local: `st-worker.sh autonomous-on` (D1 = A). No arguments; any argument prints usage (exit 2).

| Case | Output | Exit |
|---|---|---|
| Run from a worker worktree | `Run this from the orchestrator's checkout, not a worker worktree.` (as today for `autonomous-off`) | 1 |
| Not in a git repo | `cannot turn on autonomous mode: not in a git repo` | 1 |
| `$CLAUDE_CODE_SESSION_ID` empty or fails C1.1 | `cannot turn on autonomous mode: session id must be letters, digits or -` | 1 |
| folder or entry is a symlink | `cannot turn on autonomous mode: <path> is a symlink` | 1 |
| folder is still not a directory after step 4 | `cannot turn on autonomous mode: <path> is not a folder` | 1 |
| entry made (or already there) | `autonomous on` TAB `local` | 0 |

A refusal makes and removes nothing, except the old-flag remove of step 3. It needs no herdr pane.

## C3. `st-worker.sh autonomous-off [--roster <file>]` (FR-003)

- Run from a worker worktree: `Run this from the orchestrator's checkout, not a worker worktree.`, exit 1, as today.
- `$CLAUDE_CODE_SESSION_ID` fails C1.1: `Autonomous build mode is off for this session.`, exit 1, removes nothing, no ssh.
- Else one line per machine: `local` first, then each distinct roster machine and repo, as today.

| Case | Line (TAB split) |
|---|---|
| `<folder>/S` removed | `autonomous off` `<m>` |
| `<folder>/S` not there (also: no folder, or an old single-file flag) | `autonomous off skipped` `<m>` `not on for this session` |
| folder or entry is a symlink | `autonomous off failed` `<m>` `<path> is a symlink` |
| `rm` failed, ssh failed, unknown machine, no fifth roster field | `autonomous off failed` `<m>` `<reason>`, as today |

- Exit 1 when any line is `failed`, else 0.
- The line `autonomous off skipped <m> flag held by <id>` is gone: other entries are never read.
- On a saved machine, the removal runs in one ssh call per machine and repo, as today, and removes only `<repo>/.stratum/autonomous/<S>`.

## C4. Lock 2 (FR-007)

In a worker session (`hooks/st-approve.py` `worker_session`), PreToolUse is denied with the existing reason
`.stratum/approve/ and .stratum/autonomous are written only by the orchestrator.` when:

- a Bash command has a word that contains `.stratum/autonomous` (folder or any entry; make, change, remove, read), or
- a file tool (`Edit`, `Write`, `MultiEdit`, `NotebookEdit`, `Read`, `Grep`, `Glob`) names a path whose normal or real form contains `/.stratum/autonomous/` after a `/` is added at its end, or
- a Bash command runs `st-worker.sh` with a word in `RISKY` (`autonomous-off` stays, `autonomous-on` is added).

The guard stays a text match.
