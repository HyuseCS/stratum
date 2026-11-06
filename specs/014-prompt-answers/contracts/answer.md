# Contract: `st-worker.sh answer` on a permission dialog (FR-010, D3)

Changes only the permission check of `answer` (`scripts/st-worker.sh:434`). Everything else in `answer` stays: the `not blocked` check (`:433`), the key send, the typed answer, the settle wait and the `state` line (`:435-452`). `wait`, `watch`, `approve` and `pass` do not change.

## Inputs

`answer <id> [--machine <m>] --keys <key>...` or `answer <id> [--machine <m>] --text <text>`, as today.

## Steps

1. Read the pane as today: `agent read <name> --source recent-unwrapped --lines 15` into `$t`.
2. Read fails: print the permission line, exit 1, send nothing (as today).
3. No line of `$t` matches `PERM` (`:155`): go on as today. This is a worker question.
4. A line matches `PERM` (a permission dialog):
   1. `--text`: print the permission line, exit 1, send nothing (as today).
   2. `--keys` with more than one key, or a key that is not `^[1-9]$`: print `A permission prompt takes one option number. Nothing sent.`, exit 1.
   3. The option line is the last line of `$t` that matches `^[^0-9]*<key>\.[[:space:]]`. None: print `The permission prompt has no option <key>. Nothing sent.`, exit 1.
   4. The option line matches `ask again|this session|in the future`, case-insensitive: print `Option <key> lasts beyond this call. Nothing sent. Tell the user the workspace, the tab and the prompt.`, exit 1.
   5. Else send the key with `agent send-keys` and go on as today (settle wait, `state` line, exit 0 or 4).

The permission line stays word for word: `This is a permission prompt. Tell the user the workspace, the tab and the prompt; do not answer it.`

`ask again` covers "don't ask again" with a straight or a curly apostrophe. `this session` covers "for this session" (D3) and "during this session" (the Claude Code edit dialog's "Yes, allow all edits during this session"). Both are wider than the D3 text, so the script refuses more, never less.

## Stub cases (`tests/test_st_worker.sh`)

Every case: `mk`, then the pane in `$tmp/pane.txt`. "Nothing sent" means `cnt "^(agent\tsend-keys|pane\tsend-text)\t"` is 0.

| Id | Pane | Call | Expect |
|----|------|------|--------|
| AN1 | each of the 5 lines of today's AN1 loop (`:1362`), `states blocked` | `answer T004 --text hi` | exit 1, the permission line, nothing sent |
| AN2 | `agent read` fails (`STUB_FAIL="agent read"`), `states blocked` | `answer T004 --keys 1` | unchanged: exit 1, the permission line, nothing sent |
| AN3 | unchanged | | |
| AN4 | unchanged | | |
| AN5 | `Do you want to proceed?`, `❯ 1. Yes`, `  2. Yes, and don't ask again for git commands`, `  3. No, and tell Claude what to do differently (esc)`, `states blocked working` | `answer T004 --keys 1` | exit 0, `agent\tsend-keys\tworker-t004\t1` called (the one-time yes) |
| AN5b | `Do you want to make this edit to a.py?`, `❯ 1. Yes`, `  2. Yes, allow all edits during this session (shift+tab)`, `  3. No, and tell Claude what to do differently (esc)`, `states blocked working` | `answer T004 --keys 1` | exit 0, key 1 sent |
| AN6 | `Do you want to proceed?`, `❯ 1. Yes`, then option 2 is each of: `  2. Yes, and don't ask again for git commands`, `  2. Yes, and don’t ask again for git commands` (curly), `  2. Yes, allow reads for this session`, `  2. Yes, allow all edits during this session (shift+tab)`, `  2. Yes, and allow this in the future`, then `  3. No, and tell Claude what to do differently (esc)`; `states blocked` | `answer T004 --keys 2` | exit 1, the `Option 2 lasts beyond this call. ...` line, nothing sent. One case per option text: these are the negative controls (SC-005). |
| AN7 | the AN5 pane, `states blocked` | `--keys 1 enter`, `--keys enter`, `--keys down` | exit 1, `A permission prompt takes one option number. Nothing sent.`, nothing sent |
| AN8 | the AN5 pane, `states blocked` | `answer T004 --keys 4` | exit 1, `The permission prompt has no option 4. Nothing sent.`, nothing sent |

Red before the build: AN5 and AN5b (today exit 1, no key), and AN6, AN7 and AN8 (today they print the permission line, not the new line). AN1 is green before and after: it guards that `--text` keeps refusing, and negative control 3 shows it can fail.

## Script negative controls (after green)

Each is a break made with the Edit tool, one test run, the named case seen `FAIL`, then the break undone with the Edit tool:

1. Drop step 4.4 (the lasting check): AN6 goes red.
2. Drop step 4.2 (one option number): AN7 goes red.
3. Drop step 4.1 (let `--text` through on a permission dialog): AN1 goes red.
