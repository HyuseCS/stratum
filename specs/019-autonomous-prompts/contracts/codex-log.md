# Contract: the Codex tab answer from the session log (US4, FR-011 to FR-013, D5)

## 1. `scripts/st-codex-agent.sh`

Everything up to the snapshot compare and the prompt result checks (`:1-127`) stays. The pane read and scrape (`:128-138`) go. In their place, the log reader of §2. No `herdr agent read` call is left in this script (FR-011, CHK010).

Exit codes:

| Exit | Output line | When |
|------|-------------|------|
| 0 | `codex: tab <name>` | the reader wrote the answer file |
| 1, 3, 4, 5 | as today | as today (tab errors, tab in use, tab ended or failed, files changed, name in use elsewhere) |
| 6 | `codex: no session log` | no log record holds this review's answer after 15 tries |
| 4 | `BLOCKED: the review was stopped in the Codex tab` | D14: this review's turn ended with `turn_aborted` (Esc in the tab). No headless run. |

Poll: up to 15 tries. After each failed try, `sleep 1`, so 15 failed tries make 15 `sleep 1` calls. Count tries, not seconds (the tests use a no-op `sleep`). `ponytail:` note on the loop: fixed 15 tries; raise it if quickstart L3 measures a longer lag from tab idle to the `task_complete` line.

## 2. The reader (inline `python3 -I`, like the other inline readers)

Inputs: the log root `${CODEX_HOME:-$HOME/.codex}/sessions`, the prompt file `$pf`, the nonce, the answer file `$af`.

1. Files: every `rollout-*.jsonl` under the root (any depth) whose mtime is not older than the mtime of `$pf`. No root folder: no file.
2. Each file is opened read-only. Each line is parsed as JSON. A line that is not JSON, or not an object, is skipped (a partial last line, research F37).
3. A record counts when `type == "event_msg"`, `payload.type == "task_complete"` and `payload.last_agent_message` is a string. Split it on `\n`. `e` = the last line whose text, with trailing spaces and `\r` cut, equals `ST-ADVISOR-END-<nonce>`. `b` = the last line before `e` that equals `ST-ADVISOR-BEGIN-<nonce>` the same way. Both found: the answer is lines `b+1` to `e-1`, joined with `\n`, unchanged.
4. More than one record found: take the last one read. The nonce is new for each review, so two records can only hold the same answer.
5. Found: write the answer to `$af` as UTF-8, exactly, and exit 0. Not found: exit 1 (the script tries again).
6. D14: a file that has a `response_item` user `message` whose `content[].text` holds `Read the review request in <pf> and follow it.` (a substring match; `<pf>` is unique per review), followed later in the same file by an `event_msg` with `payload.type == "turn_aborted"`, and no answer per step 3 after that message: exit 2. The script then prints `BLOCKED: the review was stopped in the Codex tab` and exits 4 at once (no more tries). `scripts/st-advisor.sh` already turns exit 4 into a BLOCKED record (`:252`), so it does not run headless.

The reader never writes, moves, renames, locks or deletes a file under the log root (CHK013). It prints nothing from the log.

## 3. `scripts/st-advisor.sh`

In the tab result case (`:253-258`) add `6) via="codex: headless (no session log)" ;;`. Remove the `ponytail:` note at `:263` (the 60 s floor now has test M27). Then today's code runs: the 60 s floor (`:264`, `BLOCKED: timed out`), the headless `codex exec ... -o "$tmp/answer.json"`, and the same answer checks (FR-012, FR-013). Nothing else in `st-advisor.sh` changes.

## 4. Test cases

All in a temp `CODEX_HOME`, set in the test file before any call. A fake rollout is written by the fake `herdr agent prompt` after it reads the nonce from `$PF`.

`tests/test_codex_agent.sh`:

| Id | Fake log | Expect |
|----|----------|--------|
| L1 | one file, a `task_complete` whose `last_agent_message` is `ST-ADVISOR-BEGIN-<n>\n{"verdict":"APPROVED","summary":"use `x` and \"y\" and \\z","findings":[]}\nST-ADVISOR-END-<n>` | exit 0, `codex: tab st-codex-t1`, the answer file equals the middle line byte for byte (backtick, `"` and `\` kept), and it parses as JSON (scenario 1, SC-004) |
| L2 | one file with two `task_complete` records: an older one with nonce `aaaaaaaaaaaa` and answer X, then this review's with answer Y | answer file is Y (scenario 2) |
| L3 | the answer JSON on 3 lines between the markers | answer file holds the 3 lines joined with `\n`, unchanged |
| L4 | no file | exit 6, `codex: no session log`, no answer file, 15 `sleep` calls (count them in the fake `sleep`) |
| L5 | a file with this review's record, but its mtime set older than `$pf` (`touch -d`) | exit 6 (the mtime rule) |
| L6 | a file whose last line is cut (`{"type":"event_ms`) after this review's record | exit 0, answer read |
| L7 | the record exists only from the 3rd try (the fake `sleep` writes it on its 2nd call) | exit 0 |
| L8 | the marker lines are on screen (fake `agent read` returns them) but no log | exit 6, and the log shows no `agent read` call (the screen is not read) |
| L9 | D14: the user prompt line (with this `$pf`) and a `turn_aborted` after it, no `task_complete` | exit 4, `BLOCKED: the review was stopped in the Codex tab`, no `sleep` call |
| L10 | D14 negative: a `turn_aborted` after a user prompt line that names another prompt file | exit 6 after 15 tries (an abort of another review does not count) |

Existing cases that change: C19b (agent read fails) goes, since there is no read. C23 (no marker pair) becomes L4. The two `i` cases (wrapped JSON joined with spaces) become L3. C24 (no agent read sees the marker) becomes "no `agent read` call at all". Every other case keeps its meaning; their fake `agent prompt` writes a valid log so they reach exit 0 as before.

`tests/test_advisor_matrix.sh` (real `st-advisor.sh` and `st-codex-agent.sh`, fake herdr and codex):
- Set `CODEX_HOME` to a temp folder for the whole file. The fake `agent prompt` writes the log record with the answer from `$d/answer`. Remove the `agent read ... 400` branch of the fake.
- M1-M24 exist. New cases start at M25.
- New M25: the fake `agent prompt` writes no log: the fake `codex exec` runs, the verdict comes from it, and the last line is `codex: headless (no session log)` (scenario 3).
- New M26: no log and the fake `codex exec` exits 1: the point ends `BLOCKED: codex exited 1`, exit 1 (scenario 4).
- New M27: no log and less than 60 s left (run the copied `st-advisor.sh` with `lim=540` changed to `lim=59`, the way the test already copies `scripts/` for k5): `BLOCKED: timed out`, the fake `codex exec` does not run (spec edge case).
- New M28 (D14): the fake writes this review's prompt line and a `turn_aborted` after it: `BLOCKED: the review was stopped in the Codex tab`, exit 1, the fake `codex exec` does not run.
- Changed M19 (`:501-502`, mode `nomarkers`): the fake `agent prompt` writes a log record whose `last_agent_message` has no marker pair. The reader finds no answer, `st-codex-agent.sh` exits 6, and the review runs headless. New expectation: exit 0, the fake `codex exec` runs (`$tmp/argv` exists), the verdict comes from the fake `codex exec` as in M4, and the last line is `codex: headless (no session log)`. The old line `BLOCKED: no answer between the markers` no longer exists.
- k8 (severity URGENT in the tab answer) keeps `BLOCKED: malformed answer` with no `codex exec`: the answer came from the log and was parsed.
