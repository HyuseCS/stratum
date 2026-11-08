# Data model: st-advisor

## Review record

File: `<main checkout>/.stratum/advisor/<slug>.md`.

- `<main checkout>`: `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`, run in the review folder. Same file from the main checkout and from any linked worktree.
- `<slug>`: `git symbolic-ref -q --short HEAD` with each `/` as `-`. Detached HEAD: `git rev-parse --short HEAD`.
- The folder `.stratum/advisor` or the file is a symlink: the point stops with the usage line and writes nothing.
- Append only. A new entry starts with a blank line when the file is not empty. Earlier entries stay.
- Branches `feat/x` and `feat-x` share one record file, `feat-x.md`. Their entries mix in it; nothing is lost, because the file is append only.

Codex entry (written by `st-advisor.sh review`, same line format as `advisor.md`):

```text
## review | <UTC time YYYY-MM-DDTHH:MM:SSZ> | sha256 <64 hex of git diff --no-ext-diff --no-color <base> HEAD --, then the plan file when one is given> | APPROVED|REVISE|BLOCKED
summary: <one line>
- [CRITICAL|HIGH|MEDIUM|LOW] <location>: <claim> Evidence: <evidence>
```

BLOCKED by the script (timeout, malformed answer, files changed, tab ended): `reason: <one line>` in place of the summary and findings.

CodeRabbit section (PR form only, written by the skill with the Edit tool after the Codex point ends, only when CodeRabbit exited 0):

```text
## coderabbit | <UTC time> | base <base commit>
<coderabbit review --agent output, as printed>
```

Validation (from FR-007, FR-013): verdict one of `APPROVED`, `REVISE`, `BLOCKED`; `REVISE` needs at least one finding; `APPROVED` has none; severity one of `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`. These checks are the existing python check, unchanged.

## Review request

What the skill passes to the script: run folder (the cwd), base (a commit), optional plan file (absolute path, a readable regular file).

| Form | Run folder | Base |
|------|-----------|------|
| no argument | current folder | `git merge-base main HEAD` |
| `<base>` | current folder | `<base>` |
| `#<n>` | worktree with `refs/heads/<headRefName>` checked out at `headRefOid` | `git -C <worktree> merge-base <baseRefOid> HEAD` |

States: no review (usage, no change, mode off or not set, no `codex`), running (tab or headless), ended (APPROVED, REVISE, BLOCKED).
