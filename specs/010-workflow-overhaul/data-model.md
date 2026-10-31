# Data Model: Workflow Overhaul

All entities are plain files. None holds personal data. Two can hold text from a prompt (approval
request, approval record) and stay out of git.

## 1. Advisor setting (`.stratum/advisor.json`, committed)

| Field | Rule |
|-------|------|
| `mode` | `auto`, `codex`, `both` or `off`. Missing key = `auto` (FR-012). |
| `model` | optional, `^[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}$` (unchanged) |
| `effort` | optional, `^[a-z]{1,16}$` (unchanged) |

No other key. Any other value is `bad advisor.json` (unchanged). No file: the
`no advisor: mode not set` line, nothing sent (unchanged privacy default, see plan.md S1).

## 2. Risk level (`.stratum/state.json` key `risk`, not committed by this feature)

`high`, `normal`, `low` or `none`, written by the orchestrator with the lane (FR-011), in the
main checkout's `.stratum/state.json`. `st-advisor.sh` reads it there, through
`git rev-parse --git-common-dir`, also when it runs in a linked worktree.
`st-phase.py` keeps the key (research R-E). Missing or other value: `st-advisor.sh` uses `normal`
and prints `risk not set: normal`.

## 3. Advisor record (`<feature>/advisor.md`, committed if it changed)

One block per entry. Header line, then detail lines. Existing headers stay as they are.

| Entry | Header | Detail lines | Counted as |
|-------|--------|--------------|-----------|
| run (existing) | `## <point> \| <ts> \| sha256 <h> \| APPROVED\|REVISE\|BLOCKED` | `summary:`, findings, or `reason:` | Codex run |
| round (new) | `## <point> round <n> \| <ts> \| sha256 <h> \| APPROVED\|REVISE\|BLOCKED` | as run | Codex run |
| continued (existing) | `## <point> \| <ts> \| sha256 <h> \| BLOCKED, user continued` | none | nothing |
| waive (new) | `## plan \| <ts> \| sha256 <h> \| WAIVED` | `reason: <one line>` | waive line |
| note (new) | `## <point> \| <ts> \| /advisor` | `summary: <one line>` | `/advisor` call |
| talk (new) | `## <point> talk \| <ts> \| <rounds> rounds` | `rounds:`, `agreed:`, `compromises:`, `to user:`, `calls:` | nothing |

- `<point>`: `plan`, `test`, `diff` or `decisions`. `<n>`: 1 to 3. `<ts>`: `date -u +%Y-%m-%dT%H:%M:%SZ`.
- `check plan` reads only the last `## plan | <ts> | sha256 ` header, so note, talk and round
  entries never change a check.
- Text from a caller (reason, summary, talk lines) has CR and LF replaced by a space, as the
  existing `clean()` does.
- A waive reason or note summary that is empty after that is a usage error (exit 2), and nothing
  is written.

## 4. Test lock (`<git common dir>/stratum-<name>.lock/`, never committed)

| Part | Rule |
|------|------|
| folder | made with `mkdir`, the only atomic step |
| `pid` | the owner `st-lock.sh` process's `$$` |
| `since` | `date -u +%Y-%m-%dT%H:%M:%SZ` at the take |
| `<name>` | `^[A-Za-z0-9][A-Za-z0-9._-]{0,40}$`, default `test` |

States: free (no folder), held (folder and live pid), stale (folder and `kill -0 <pid>` fails:
removed by the next waiter). The owner removes the folder on exit. One lock per repo, shared by
all its worktrees.

## 5. Autonomous flag (`<main checkout>/.stratum/autonomous`, never committed)

The main checkout is the parent of `git rev-parse --path-format=absolute --git-common-dir`.
Every writer, remover and reader (W8, W9, `st-worker.sh`, the hook, the status line) uses that
path, also from a linked worktree. One line: the orchestrator's `$CLAUDE_CODE_SESSION_ID`. On only while that line equals the
current session's id. Made on the user's words, removed at the end of the run or on
"stop autonomous" (FR-018). Read by the approval hook through the git common dir, so a worker's
worktree copy never counts (D27). On a saved machine the same file sits in that machine's main
checkout (`--repo`): `start --autonomous --machine` writes or replaces it, `autonomous-off`
removes it at the end of the run or on "stop autonomous" (D28). A stale copy left by a crashed
session still matches the `session` file of that session's workers, so their hook sends the
request and waits up to 300 s with the dialog showing; no live orchestrator holds that id, so
`approve` refuses and nothing is approved.

## 6. Approval channel (`<worktree>/.stratum/approve/`, never committed)

Made by `st-worker.sh start --autonomous`, removed by `close`.

| File | Writer | Content |
|------|--------|---------|
| `session` | `st-worker.sh start --autonomous` | one line: the orchestrator's `$CLAUDE_CODE_SESSION_ID`; the hook acts only while it equals the main checkout's `.stratum/autonomous` (D27) |
| `owns` | `st-worker.sh start --autonomous` | one path per line, from the task's `Owns:` line (D23) |
| `<rid>.req` | worker hook `hooks/st-approve.py` | JSON `{"tool_name", "tool_input", "time"}`, and for a commit `"branch"` and `"staged"` (list) |
| `<rid>.ok` | `st-worker.sh approve` | empty: allow one time |
| `<rid>.user` | `st-worker.sh pass` | empty: leave the dialog to the user |

Roster (scratchpad, D28): a remote worker's row may have a fifth TAB field, the `--repo` main
checkout, so `autonomous-off` can find that machine's flag. The brief shows only the first four.

`<rid>`: `^[0-9]+-[0-9]+$` (`time_ns`-`pid`). The hook removes its own three files when it ends.
States: pending (`.req` only) to approved (`.ok`), passed (`.user`) or timed out (300 s, no answer).

## 7. Approval record (a file in the orchestrator's scratchpad, never committed)

One line per approval, TAB-split: time, worker name, `workspace <name>, tab Main`, tool name,
the request input as one line. Listed word for word at the end of the run (FR-019). It is not in
the repo because a prompt can hold a secret (spec Assumptions).

## 8. Task line marks (`tasks.md`)

`[P]`, `[USn]`, `[lock]` (test that cannot run at the same time, FR-026, FR-010),
`[screen: autonomous]` or `[screen: new look]` (new-screen task and its Design lane mode,
FR-023). A `[P]` task ends with `Owns:` (its files) and every task with `Test:` (its exact
command, FR-005).

## 9. Stratum Codex home (`${XDG_STATE_HOME:-$HOME/.local/state}/stratum/codex-home/`, outside every repo)

| Part | Rule |
|------|------|
| folder | mode 700, made only by `st-advisor.sh codex-home` when the user opts in to a Codex advisor (D25) |
| `auth.json` | a symlink to `${CODEX_HOME:-$HOME/.codex}/auth.json`, the user's Codex login |
| anything else | written by Codex itself while the tab runs (sessions, logs); never read from the user's `~/.codex` |

Used as `CODEX_HOME` for the herdr Codex tab only. `codex exec` keeps `--ignore-user-config`.
