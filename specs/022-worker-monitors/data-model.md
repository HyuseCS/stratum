# Data model: worker monitors (022)

No database. The data is one agent, two text files per monitor, and one report per run.

## Monitor

One `stratum:st-monitor` background subagent of the main session.

| Field | Value | Rule |
|-------|-------|------|
| worker | `worker-<id>` | Exactly one. One worker has at most one live monitor (FR-003). |
| machine | `local` or a saved machine label | Passed as `--machine <m>` on every `st-worker.sh` call when not `local` (FR-005). |
| model | `opus` by default | From the `model:` line, or `.stratum/models.json` key `st-monitor` (FR-024). Weaker: `sonnet`, `haiku`. Not weaker: `opus`, `fable`. |
| agent id | the id the Agent tool returns | The main session keeps it, to continue the monitor with SendMessage or stop it with `TaskStop`. |
| folder | `<folder>` = `<scratchpad>/monitor-<machine>-<id>-<key>` | Made by the main session with `mktemp -d "<scratchpad>/monitor-<machine>-<id>-XXXXXXXXXXXXXXXX"` before the first start: `<machine>` is the `--machine` label as is, 1 to 25 lower-case letters or digits and not `local`, or `local` with no `--machine`, `<id>` is the worker id in lower case, and `<key>` is 16 random letters or digits (D36). Main session scratchpad, outside every git work tree (FR-014). Its path is only in that monitor's brief. It holds the beat file before the monitor's first start, so the monitor guard accepts it as a monitor folder. It belongs to the first monitor that uses it (its `owner` file). A monitor that takes over from a stopped one gets a new folder; the old one gets a `revoked` file, and it and its record stay. |

States, from the main session's view:

```text
started --report with an end state--> ended
started --report with no end state--> started again (SendMessage)          FR-020
started --stale line--> TaskStop --confirmed--> started again (SendMessage) FR-021
started --stale line--> TaskStop --confirmed, SendMessage says won't be resumed--> user's yes--> new monitor, new folder, old folder revoked   C1
user's no--> no monitor: the main session runs wait for that worker                                                   FR-022
ended (needs you) --user's answer--> started again (SendMessage)            FR-020
ended (finished) --follow-up round sent by the main session--> started again FR-020
Agent call fails --> no monitor: the main session runs wait for that worker  FR-022
```

## End state

One of `finished`, `stopped`, `gone`, `needs you` (FR-018). Each worker state maps to one:

| `wait` result | End state |
|---------------|-----------|
| `state finished` (exit 0) | `finished` |
| `state stopped` (exit 5) | `stopped` |
| `stopped: <herdr error>` (exit 1) | none: run `wait` again once. The same line a second time in a row: `gone`, with that line as its text |
| `No worker <name> on <m>.` (exit 1) | `gone` |
| `state working` (exit 3) | none: run `wait` again |
| `state blocked`, `state approval`, `state unsent` that the monitor cannot settle | `needs you` |

While a `needs you` waits for the user, the worker stays at its dialog or question. An approval request waits at most 300 s in the worker's hook (`hooks/st-approve.py:330`); after `pass` or that time, the worker shows its own dialog in its pane.

## Record file

`<folder>/record.tsv`. Written only by `scripts/st-worker.sh`. One line per action, fields split by TAB, control characters removed. It outlives the monitor (FR-008).

| Line | Fields |
|------|--------|
| answer | UTC time, `worker-<id>`, `tab worker-<id>`, `answer`, the question, the answer (`keys <k>...` or `text <t>`) |
| resend | UTC time, `worker-<id>`, `tab worker-<id>`, `resend`, `/goal prompt`, `Enter` |
| approve | UTC time, `worker-<id>`, `tab worker-<id>`, tool, input (the line `approve` writes today, `scripts/st-worker.sh:827`) |
| pass | UTC time, `worker-<id>`, `tab worker-<id>`, `pass`, the request id, `-` |

- The question is the screen block that the hash covers, as one line: lines joined by ` | `, the last 600 characters.
- An answer, resend or pass line is written only after the keys, the text or `<rid>.user` were sent or written. The approve line is written just before `<rid>.ok` (as today, `Approve nothing` when the line cannot be written); when `.ok` then cannot be written, approve exits 1 and the line stays.
- The file changes only when an answer or an approval is recorded.

## Codex files in the monitor folder

| File | Written by | Content |
|------|------------|---------|
| `spec.md` | the monitor (Write tool), just before its first Codex call | the task text of its brief. Only there because every `st-advisor.sh` point needs a readable `spec.md` in its folder (`scripts/st-advisor.sh:73-76`) |
| `views-<n>.md` | the monitor (Write tool) | one big decision: the question, the facts, the answer, the `advisor` answer, the `Owns:` files it touches |
| `advisor.md` | `scripts/st-advisor.sh` | the record of each `round decisions` run (`:77`) |

## Owner file

`<folder>/owner`. Made by the monitor guard in `hooks/st-approve.py` on the first monitor call for the folder, with an exclusive create that does not follow a symlink, and holds that call's `agent_id` (D36). Every later monitor call on the folder must carry the same `agent_id`, compared as exact bytes. No one else writes or removes it.

## Revoked file

`<folder>/revoked`. Written by the main session with the Write tool when it stops using a monitor folder, for any reason (a takeover, or a new monitor after a stopped one). The monitor guard denies every monitor call on a folder where any entry named `revoked` exists, whatever its kind (a file, a folder, a symlink, also a broken one). Its content is not read. A monitor cannot write it.

## Beat file

`<folder>/beat`. The one sign of life of the monitor (FR-021, research.md R6): its mtime. Written by the main session with the Write tool just before each start or continue of the monitor, and refreshed by `wait --beat <file>` at its start and at each 10 s slice. Its content is not read.

## Monitor report

The text a monitor ends its run with. The main session reads it as data (FR-017).

```text
[st-monitor]
end: finished | stopped | gone | needs you
worker: worker-<id> on <machine>
workspace: <workspace name>
tab: worker-<id>
screen: <hash>          (needs you, when wait printed one)
text:                   (needs you: the exact dialog, question or request text)
<text>
answers:
- <question> -> <answer>    (or: none)
big decisions made:
- <question> -> <answer>. advisor: <one line>. Codex: <verdict line>.    (or: none)
record: <path>
```

- A report with no `end:` line that names one of the four states counts as no end state (FR-020).
- `answers` and `big decisions made` hold everything since the monitor first started for this worker, not only this run (FR-019).

## Big decision made

One spec, scope or approach question that a monitor answered under FR-028. Fields: the question, the answer, the `/advisor` answer in one line, the Codex verdict line. The main session shows each one to the user before the merge (FR-030). On the user's "no", the main session sends a follow-up round that undoes it, and merges nothing before that round is `finished`.
