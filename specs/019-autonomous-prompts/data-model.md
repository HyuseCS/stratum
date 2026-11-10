# Data model: 019 autonomous prompts

Two small files are written: the empty marker `.stratum/git-instructions-kept` (US3) and the one-line `.stratum/approve/dropped` (US2, D20). Nothing else is stored. These are the values the feature reads, computes or writes.

## Dialog block (US1)

| Field | Value | Rule |
|-------|-------|------|
| source | `SC`, the 40-line `recent-unwrapped` read of the worker pane, ANSI stripped | as today (`scripts/st-worker.sh:170`) |
| HEAD | the one line in the last 15 lines that matches `HEAD` | exactly one; else mode none |
| end | the last option line after HEAD, plus the non-blank lines right after it | required; no option line: mode none |
| start | the last line above the HEAD line that starts at column 0 and holds only `─` (U+2500) | found: mode `block`; none: mode `cut` |
| mode | `block`, `cut` or none | `cut` allows only a No (D15); none prints no `screen` line |
| hash | `block`: first 12 hex of `sha256sum <<<"<block>"`; `cut`: the same of the whole 40-line read | `^[0-9a-f]{12}$`, as the `--screen` check today |

Relations: `wait` and `watch` print `screen\t<hash>`. `answer --screen <hash>` must equal the hash of the block of a new read. Full rules: `contracts/dialog-block.md`.

## Commit form test (US2)

| Field | Value |
|-------|-------|
| input | the raw Bash command text |
| true when | the command, with each backslash-newline joined (`JOIN`), holds `<<`, or `SUBSTITUTION` (`hooks/st-approve.py:41`) matches |
| used by | the git guard (deny) and the approve channel's `commit_check` (refuse), D13 |
| deny text | `contracts/commit-form.md` §3, one fixed line, prefix `Commit form denied:` |

## Commit request (US2, unchanged)

The approve request file (`hooks/st-approve.py:267`, `:277`): `tool_name`, `tool_input.command` (full text), `time`, `branch`, `staged` (sorted list). No new field.

## Approve input hash (D17, FR-017)

| Field | Value |
|-------|-------|
| source | the rendered request `in` (`hooks/st-approve.py --render`, the text of the `input` line) |
| hash | full `sha256sum <<<"$in"`, `^[0-9a-f]{64}$` |
| printed | `inputhash\t<hash>`, right after the `input` line of `wait` and `watch` |
| checked | `approve --input-hash <hash>` renders again and refuses on a mismatch with today's line |

## Codex session log record (US4)

| Field | Value | Use |
|-------|-------|-----|
| file | `${CODEX_HOME:-~/.codex}/sessions/**/rollout-*.jsonl`, mtime not older than the review's prompt file | candidate files, read-only |
| line | one JSON object per line: `ordinal`, `payload`, `timestamp`, `type` | non-JSON lines skipped |
| answer record | `type: "event_msg"`, `payload.type: "task_complete"`, `payload.last_agent_message` (string) | the text between this review's marker lines |
| abort record | `type: "event_msg"`, `payload.type: "turn_aborted"`, `payload.reason` | D14: after this review's prompt record, the point is BLOCKED |
| prompt record | `type: "response_item"`, `payload.type: "message"`, `payload.role: "user"`, `payload.content[].text` | D14: ties an abort to this review |

## Review nonce and prompt line (US4)

| Field | Value |
|-------|-------|
| nonce | 12 lowercase hex, new per review (`scripts/st-codex-agent.sh:113-114`) |
| markers | `ST-ADVISOR-BEGIN-<nonce>`, `ST-ADVISOR-END-<nonce>`, each alone on its line |
| prompt line | `Read the review request in <prompt file> and follow it. Change no file.`; the prompt file is in a new `mktemp -d` folder per review |

## Drop reason (US2, D20, FR-018)

| Field | Value | Rule |
|-------|-------|------|
| file | `<worker root>/.stratum/approve/dropped` | written by the approve hook only, through a temp file and `os.rename`; removed when the hook writes a `.req` file |
| line | `<rule>\t<detail>\t<command>` | rule: `never-list`, `commit-never`, `unjudgeable`, `git-word`, `flag`, `branch`, `owns-missing`, `outside-owns` or `git-error`; detail may be empty; command: control characters as `?`, cut to 300 characters |
| printed | `dropped\t<first line>` after the `state` line of `wait` and `watch`, when the worker is blocked with no request | regular file only (a symlink, a FIFO or a failed remote read prints nothing); bytes that are not printable or TAB removed; cut to 400 characters |

Full rules: `contracts/commit-form.md` §4c.

## Built-in git instructions setting (US3)

| Field | Value |
|-------|-------|
| key | `includeGitInstructions` (boolean, Claude Code default `true`) |
| written value | `false` |
| scopes | project `.claude/settings.json`, user `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`, local `.claude/settings.local.json`, or none |
| set at any level | the env var `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` is set, or any of the three files has the key |
| off at some level | the env var is set, or any of the three files has the key equal to `false` (FR-016 hint test) |
| "not at all" marker | empty file `.stratum/git-instructions-kept`, committed (D16) |

State: not set and no marker, then (one question) set in the chosen file, or the marker written for "not at all", or nothing for `skip` (an answer of st-update's one-time step only: st-init has no `skip`). `st-init` and `st-update` skip the question when the setting is set at any level or the marker exists. `autonomous-on` prints its hint when the setting is not off at any level.
