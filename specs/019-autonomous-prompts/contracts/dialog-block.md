# Contract: the dialog block in `scripts/st-worker.sh` (US1, FR-001 to FR-003, D3, D15)

Changes the screen-hash rule of `specs/014-prompt-answers/contracts/answer.md` §1-§3. Everything else in `wait`, `watch` and `answer` stays: the 40-line read `SC` and its ANSI strip (`screen()`, `:170`), the `perm` test on the last 15 lines (`:171`), the `--screen` syntax check (`:35-38`), the key and allow-list checks (`:456-466`), the settle wait and the `state` line.

## 1. The block

Input: `SC`, the 40-line read. Line numbers below count in `SC`, from 1 to `n`.

Terms (F9): the block starts at the top rule line. "Title line" in the spec means the HEAD line only (`Do you want to ...`). The line under the top rule (` Bash command`) is the header line.

| Name | Rule |
|------|------|
| Window | lines `max(1, n-14)` to `n` (the last 15, as today) |
| HEAD | `^([[:space:]]\|│)*Do you want to (proceed\|make this edit\|create\|allow\|run)` (today's `HEAD`, `:168`) |
| Top rule | `^[[:space:]]*(─)+[[:space:]]*$`, where `─` is U+2500 only. The group keeps all three bytes of `─` together, so the rule holds under the `C` locale too. `╌` (U+254C, the command box lines) does not match. |
| Option line | `^([[:space:]]\|│)*(❯[[:space:]]*)?[0-9]+\.[[:space:]]` (today's option prefix, `:465`) |
| Blank | `^[[:space:]]*$` |

Steps. The result is a mode (`block`, `cut` or none) and a hash `SH`:

1. The window holds exactly one HEAD line, at `h`. Zero or two or more: mode none, no hash (no single title line, D15).
2. `e` = the last option line after `h` (`h+1` to `n`). None: mode none, no hash.
3. While line `e+1` exists and is not blank, `e = e+1` (a wrapped option text stays in the block).
4. `t` = the last line above `h` (1 to `h-1`) that is a top rule.
   - Found: mode `block`. `DB` = lines `t` to `e` of `SC`, joined with `\n`. `SH` = the first 12 hex characters of `sha256sum <<<"$DB"` (same method as today).
   - None: mode `cut` (the top of the dialog is not in the 40-line read, scenario 3, D15). `SH` = the first 12 hex characters of `sha256sum <<<"$SC"`, the whole-screen hash of today. In this mode only a No may be sent (§3).

The top rule line is as wide as the terminal, and it is inside the hash. A pane resize between `wait` and `answer` therefore refuses with an unchanged dialog. That fails closed (FR-003); the live check reader should know this cause. In mode `cut` any change on the 40-line screen refuses, as today.

One function computes the mode and `SH`. `st blocked` (`wait` and `watch`) and `answer` both call it on their own `SC` (CHK002).

For the captured dialog (research P1) the block is the 12 lines from the `─` rule through ` 4. No`. It holds the header line, the tip, the description, both `╌` lines, the command line and the four options. It leaves out the transcript above the rule, the blank line and the `Esc to cancel · Tab to amend` footer.

## 2. `wait` and `watch` (`st blocked`, `:157-166`)

`screen\t<SH>` is printed when the read worked, `perm` is true and the mode is `block` or `cut`. Mode none: no `screen` line. `pane text:` and the full `SC` print as today.

## 3. `answer` (permission branch, `:452-467`)

Order of checks, each "Nothing sent", exit 1:

1. `--text`: the permission line (as today).
2. No `--screen`: `A permission prompt needs --screen <hash> from the screen line of wait or watch. Nothing sent.` (as today).
3. Mode none, or `SH` differs from `--screen`: `The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt.` (as today). Remove the old `ponytail:` comment on this line (its upgrade is this change).
4. Key count and form, then the option allow list (one-time yes, or a No with no lasting or host words): as today, unchanged, with the same `Option <k> is not a one-time yes. ...` line.
5. Mode `cut` and the option is a yes (it passed the yes part of the allow list, not the No part): `The top of the dialog is not on the screen, so only its No can be sent. Nothing sent. Tell the user the workspace, the tab and the prompt.` (new, D15).
6. Else send the key, as today.

This keeps the cut-off-dialog No flow of 837282c (`skills/st-worker/SKILL.md` step 6, tests NO1-NO3) unchanged.

## 4. Test cases (`tests/test_st_worker.sh`)

`REAL` is the captured dialog of research P1 with short paths and a 40-character rule:

```text
❯ Run this exact Bash command and nothing else: touch /tmp/p.txt
  ⎿  $ touch /tmp/p.txt

────────────────────────────────────────
 Bash command
 Tip: auto mode handles these prompts for you — choose "switch to auto mode" below
 Create empty file p.txt
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 │ touch /tmp/p.txt
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 Do you want to proceed?
 ❯ 1. Yes
   2. Yes, and always allow access to /tmp from this project
   3. Yes, and switch to auto mode · auto mode handles these prompts for you
   4. No

 Esc to cancel · Tab to amend
```

"The hash" is the `screen` line's hash from `wait` on the first pane. "Nothing sent": no `agent send-keys` and no `pane send-text` call.

| Id | Pane at `wait` | Pane at `answer` | Call | Expect |
|----|----------------|------------------|------|--------|
| DB1 | REAL | | `wait` | one `screen` line; its hash = first 12 hex of `sha256sum` of the 12 block lines (rule through ` 4. No`) |
| DB2 | REAL | REAL with the `⎿` line changed to `  ⎿  Running… (12s)` and 3 new transcript lines on top | `--screen <hash> --keys 1` | exit 0, key 1 sent (scenario 1) |
| DB3 | REAL | REAL with ` │ touch /tmp/q.txt` | `--screen <hash> --keys 1` | exit 1, another-prompt line, nothing sent (scenario 2) |
| DB4 | REAL | REAL with header line ` Bash command (unsandboxed)` | same | exit 1, another-prompt line, nothing sent |
| DB5 | REAL | REAL with option 2 `... access to / from this project` | same | exit 1, another-prompt line, nothing sent |
| DB6 | REAL | REAL with the footer ` Esc to cancel` | same | exit 0, key 1 sent (footer is outside the block) |
| DB7 | `CUT` = REAL with 45 lines ` │ line <i>` in place of the one command line (the rule is more than 40 lines up) | CUT | `wait`, then `--screen <hash> --keys 1` | `wait`: exit 4, one `screen` line whose hash = first 12 hex of `sha256sum` of the printed 40-line pane text. `answer`: exit 1, exactly the cut-off line of §3 step 5, nothing sent (scenario 3: never a yes) |
| DB7b | CUT | CUT | `--screen <hash> --keys 4` | exit 0, key 4 (`No`) sent (scenario 3, D15) |
| DB7c | CUT | CUT with one transcript line inside the 40 lines changed | `--screen <hash> --keys 4` | exit 1, another-prompt line, nothing sent (whole-screen hash, as today) |
| DB8 | REAL with the rule line removed | same | `wait`, then `--screen <hash> --keys 1`, then `--keys 4` | as DB7 and DB7b |
| DB9 | REAL with a second ` Do you want to proceed?` line between options 2 and 3 | same | `wait`, then `--screen 0123456789ab --keys 4` | `wait`: exit 4, no `screen` line (CHK003). `answer`: exit 1, another-prompt line, nothing sent |
| DB10 | REAL | | `watch --roster <roster>` | its `screen` hash equals DB1's (CHK002) |
| DB11 | REAL | REAL | `--screen <hash> --keys 2`; `--screen <hash> --keys 3`; `--screen <hash> --keys 4` | keys 2 and 3: exit 1, `Option <k> is not a one-time yes. ...`, nothing sent. Key 4 (`No`): exit 0, key sent (scenario 4, unchanged rule) |

Existing cases:

- Every AN fixture (`tests/test_st_worker.sh:1433-1557`) gets one 40-character `─` rule line as its first dialog line (above `Bash command`, `Read file` or the HEAD line), so each case keeps its meaning in mode `block`.
- AN6f (two HEAD lines): `wait` now prints no `screen` line. Its `answer` uses `--screen 0123456789ab` and expects exit 1, the another-prompt line, nothing sent.
- AN9b: the hash now equals the hash of the block lines, not of the printed pane text. Keep its check that the pane text holds `line 5` (the 40-line read).
- AN11b: `line 5` is outside the block. The answer is now sent (exit 0). This is the fix (scenario 1).
- NO1-NO3 (`:1509-1519`) keep their fixtures (no rule line, so mode `cut`) and their expectations: NO1 sends the No, NO2 refuses a wrong hash, NO3 refuses each lasting or other option with the not-one-time-yes line.
- AN1-AN4, AN12-AN14 keep their expectations.
