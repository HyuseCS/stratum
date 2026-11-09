# Data model: 019 autonomous prompts

No stored data is added. These are the values the feature reads, computes or writes.

## Dialog block (US1)

| Field | Value | Rule |
|-------|-------|------|
| source | `SC`, the 40-line `recent-unwrapped` read of the worker pane, ANSI stripped | as today (`scripts/st-worker.sh:170`) |
| HEAD | the one line in the last 15 lines that matches `HEAD` | exactly one; else mode none |
| end | the last option line after HEAD, plus the non-blank lines right after it | required; no option line: mode none |
| start | the last line above the HEAD line that holds only `─` (U+2500) | found: mode `block`; none: mode `cut` |
| mode | `block`, `cut` or none | `cut` allows only a No (D15); none prints no `screen` line |
| hash | `block`: first 12 hex of `sha256sum <<<"<block>"`; `cut`: the same of the whole 40-line read | `^[0-9a-f]{12}$`, as the `--screen` check today |

Relations: `wait` and `watch` print `screen\t<hash>`. `answer --screen <hash>` must equal the hash of the block of a new read. Full rules: `contracts/dialog-block.md`.

## Commit form test (US2)

| Field | Value |
|-------|-------|
| input | the raw Bash command text |
| true when | the command holds `<<`, or `SUBSTITUTION` (`hooks/st-approve.py:41`) matches |
| used by | the git guard (deny) and the approve channel's `commit_check` (refuse), D13 |
| deny text | `contracts/commit-form.md` §3, one fixed line, prefix `Commit form denied:` |

## Commit request (US2, unchanged)

The approve request file (`hooks/st-approve.py:267`, `:277`): `tool_name`, `tool_input.command` (full text), `time`, `branch`, `staged` (sorted list). No new field.

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

## Built-in git instructions setting (US3)

| Field | Value |
|-------|-------|
| key | `includeGitInstructions` (boolean, Claude Code default `true`) |
| written value | `false` |
| scopes | project `.claude/settings.json`, user `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`, local `.claude/settings.local.json`, or none |
| set at any level | the env var `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` is set, or any of the three files has the key |
| off at some level | the env var is set, or any of the three files has the key equal to `false` (FR-016 hint test) |
| "not at all" marker | empty file `.stratum/git-instructions-kept`, committed (D16) |

State: not set and no marker, then (one question) set in the chosen file, or the marker written for "not at all", or nothing for `skip`. `st-init` and `st-update` skip the question when the setting is set at any level or the marker exists. `autonomous-on` prints its hint when the setting is not off at any level.
