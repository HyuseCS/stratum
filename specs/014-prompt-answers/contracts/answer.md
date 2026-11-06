# Contract: `st-worker.sh` on a permission dialog (FR-010, FR-011; D3, D6, D7)

T003 (commit 42c758b) built the first form: one option number, and a phrase list of lasting options. T012 changes it to this contract: a screen hash (D6) and an allow list of one-time yes forms (D7). Everything else in `answer` stays: the `not blocked` check, the key send for a worker question, the typed answer, the settle wait and the `state` line. `approve` and `pass` do not change.

## 1. The screen hash (D6)

The method of 013, `scripts/st-advisor.sh:35`:

```text
s = $(agent read <name> --source recent-unwrapped --lines 20 | sed $'s/\e\\[[0-9;]*[A-Za-z]//g')
hash = the first 12 hex characters of sha256sum <<<"$s"
```

`$(...)` drops the trailing newlines and `<<<` adds one, as in `st-advisor.sh`. A read that fails gives no hash.

The pane shows a permission dialog when a line of the last 15 lines of `s` matches `PERM` (`scripts/st-worker.sh:155`). Only the last 15 count, as before, so a dialog more than 15 lines up is not a dialog (AN4).

## 2. `wait` and `watch`

For a `blocked` worker (`st blocked`), right after the `state` line and before `pane text:`, read `s` once. When it shows a permission dialog, print:

```text
screen	<hash>
```

(tab-separated, like the `state` and `request` lines). No dialog, or a failed read: no `screen` line. The `pane text:` block does not change. `watch` prints the line the same way, since it uses `st blocked`.

## 3. `answer`

Inputs: `answer <id> [--machine <m>] [--screen <hash>] --keys <key>...` or `answer <id> [--machine <m>] --text <text>`. `--screen` comes before `--keys`, because `--keys` takes the rest of the line. `--screen` must match `^[0-9a-f]{12}$`, else the usage line and exit 2, with no herdr call.

Steps:

1. Read `s` as in section 1. Read fails: print the permission line, exit 1, send nothing (as today).
2. The last 15 lines of `s` show no permission dialog: go on as today. This is a worker question. `--screen` is not checked here.
3. A permission dialog:
   1. `--text`: print the permission line, exit 1, send nothing.
   2. No `--screen`: print `A permission prompt needs --screen <hash> from the screen line of wait or watch. Nothing sent.`, exit 1.
   3. The hash of `s` now differs from `--screen`: print `The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt.`, exit 1.
   4. More than one key, or a key that is not `^[1-9]$`: print `A permission prompt takes one option number. Nothing sent.`, exit 1.
   5. The option line is the last line of the last 15 lines of `s` that matches `^([[:space:]]|│)*(❯[[:space:]]*)?<key>\.[[:space:]]`. It must match the allow list in full:
      `^([[:space:]]|│)*(❯[[:space:]]*)?<key>\. (Yes|Yes, proceed|Yes, just this once)( \([a-z0-9]\))?[[:space:]]*$`
      No option line, or one that does not match: print `Option <key> is not a one-time yes. Nothing sent. Tell the user the workspace, the tab and the prompt.`, exit 1.
   6. Else send the key with `agent send-keys` and go on as today (settle wait, `state` line, exit 0 or 4).

The permission line stays word for word: `This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it.`

Step 3.5 replaces T003's "no option" line and its lasting-phrase check (D7). The allow list comes from 013's one-time yes forms (`skills/st-build/SKILL.md:98`). The key hint is one lowercase letter or digit in brackets, such as `(y)`. A longer hint such as `(shift+tab)` or `(esc)` is refused. The last line that starts with the key wins. So a line in the command text that looks like an option, above the real options, can never stand in for the real option line.

## 4. Stub cases (`tests/test_st_worker.sh`)

Every case: `mk`, then the pane in `$tmp/pane.txt`. "Nothing sent" means `cnt "^(agent\tsend-keys|pane\tsend-text)\t"` is 0. "The hash" is the `screen` line's hash from a `wait` run on the same pane (`states blocked` before `wait`, then `states blocked working` for a send). The dialog head for the cases below is `Do you want to proceed?`, and option 3 is `  3. No, and tell Claude what to do differently (esc)`, unless the row says otherwise.

| Id | Pane | Call | Expect |
|----|------|------|--------|
| AN1 | unchanged | `--text hi` | unchanged |
| AN2 | unchanged | | unchanged |
| AN3 | unchanged (a question) | `--keys 1`, no `--screen` | unchanged: exit 0, key sent |
| AN4 | unchanged | `--keys 1`, no `--screen` | unchanged: exit 0, key sent |
| AN5 | `❯ 1. Yes`, `  2. Yes, and don't ask again for git commands` | `--screen <the hash> --keys 1` | exit 0, `agent\tsend-keys\tworker-t004\t1` |
| AN5b | head `Do you want to make this edit to a.py?`, `❯ 1. Yes`, `  2. Yes, allow all edits during this session (shift+tab)` | `--screen <the hash> --keys 1` | exit 0, key 1 sent |
| AN6 | option 1 `❯ 1. Yes`; option 2 is each of: `  2. Yes, and don't ask again for git commands`, `  2. Yes, and don’t ask again for git commands`, `  2. Yes, allow reads for this session`, `  2. Yes, allow all edits during this session (shift+tab)`, `  2. Yes, and allow this in the future`, `  2. Yes, and always allow access to other/ from this project` | `--screen <the hash> --keys 2` | exit 1, `Option 2 is not a one-time yes. ...`, nothing sent. One case per text. |
| AN6b | `❯ 1. Yes`, `  2. Yes, allow reading from other-project/secrets/`, `     during this session` (a second line under option 2) | `--screen <the hash> --keys 2` | exit 1, the not-one-time-yes line, nothing sent |
| AN6c | head `Bash command`, `  printf "3. step three"`, then `Do you want to proceed?`, `❯ 1. Yes`, `  2. No, and tell Claude what to do differently (esc)` (no option 3) | `--screen <the hash> --keys 3` | exit 1, the not-one-time-yes line, nothing sent |
| AN6d | head `Bash command`, `  2. Yes` (a command line that looks like an option), then `Do you want to proceed?`, `❯ 1. Yes`, `  2. Yes, and don't ask again for git commands` | `--screen <the hash> --keys 2` | exit 1, the not-one-time-yes line, nothing sent |
| AN7 | the AN5 pane | `--screen <the hash>` with `--keys 1 enter`, `--keys enter`, `--keys down` | unchanged line: exit 1, `A permission prompt takes one option number. Nothing sent.`, nothing sent |
| AN8 | the AN5 pane | `--screen <the hash> --keys 4` | exit 1, `Option 4 is not a one-time yes. ...`, nothing sent |
| AN9 | the AN5 pane; and the AN3 question pane | `wait T004` | AN5 pane: one `screen\t<12 hex>` line, after the `state` line and before `pane text:`. Question pane: no `screen` line. |
| AN10 | each allowed option 1: `❯ 1. Yes`, `  1. Yes`, `│ 1. Yes`, `❯ 1. Yes, proceed`, `❯ 1. Yes, proceed (y)`, `❯ 1. Yes, just this once` | `--screen <the hash> --keys 1` | exit 0, key 1 sent. One case per form. |
| AN11 | the AN5 pane at `wait`; then the pane becomes head `Bash command`, `  git push`, `Do you want to proceed?`, `❯ 1. Yes`, `  2. No, and tell Claude what to do differently (esc)` | `--screen <the hash from the first pane> --keys 1` | exit 1, `The pane shows another prompt. ...`, nothing sent |
| AN12 | the AN5 pane | `--keys 1`, no `--screen` | exit 1, `A permission prompt needs --screen <hash> ...`, nothing sent |
| AN13 | the AN5 pane | `--screen` with `abc`, `0123456789abc` (13), `0123456789AB` (upper case), then `--keys 1` | exit 2, the usage line, nothing sent |

Red before T012: AN5, AN5b, AN6 (the new line, and the "always allow" text that T003 sends), AN6b, AN6c, AN6d, AN8 (new line), AN9 (no `screen` line), AN10 (`--screen` is not a known option today), AN11, AN12 and AN13 (today exit 1 or a key sent, not the usage exit 2).

## 5. Script negative controls (after green)

Each is a break made with the Edit tool, one test run, the named case seen `FAIL`, then the break undone with the Edit tool:

1. Skip the hash compare (step 3.3): AN11 goes red.
2. Skip the missing `--screen` refusal (step 3.2): AN12 goes red.
3. Check only the option prefix, not the full allow-list form (step 3.5): AN6 goes red.
4. Do not print the `screen` line in `st blocked`: AN9 and AN10 go red.
5. Take the first option line in place of the last (step 3.5): AN6d goes red.

## 6. A pane that redraws (D8)

If the last 20 lines of a blocked worker's pane change while the dialog waits, the hash never matches. Causes could be a statusline with a time segment (the Stratum statusline has `showDuration: true`, `statusline/powerline.json`) or a spinner with a timer. Every `answer` is then refused with the another-prompt line. This fails closed: nothing is sent, and the dialog goes to the user. The stub cannot show what a real Claude Code pane does.

D8: no `--expect` now. T012 puts this note on the line of the hash compare (step 3.3), word for word:

```text
# ponytail: the whole 20-line screen must match, add --expect <text> if a real worker pane redraws so its hash never matches
```
