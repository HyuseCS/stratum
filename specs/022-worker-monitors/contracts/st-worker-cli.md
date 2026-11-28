# Contract: `scripts/st-worker.sh` changes

Only the parts below change. Every other command, line and exit code stays as it is.

## Usage line

```text
... | wait <id> [--machine <m>] [--beat <file>] | answer <id> [--machine <m>] [--screen <hash>] [--record <file>] --keys <key>... | --text <text> | ... | resend <id> [--machine <m>] [--record <file>] | ... | pass <id> --request <rid> [--record <file>] [--machine <m>] | ... | stale <beat file>...
```

`--record` comes before `--keys`, as `--screen` does today (`--keys` takes the rest of the line).

## `screen` line for a work question (FR-007)

- `wait` and `watch` print `screen\t<hash>` in the `state blocked` block for an open work question too, in the same place as for a dialog (`scripts/st-worker.sh:187`).
- The question block: in the screen lines (`recent-unwrapped`, 40 lines, colour codes removed, the same lines as for a dialog), find the last line with `Enter to select` or `Ready to submit your answers?`. The block is the 15 lines that end at that line, plus, after `Ready to submit your answers?`, the numbered option lines that follow it. Empty lines between that line and the first option are skipped: they are not in the block. The hash is the first 12 hex characters of the block's sha256.
- A status line below the block does not change the hash. A block with an input box (a `❯` line that is not an option) below it is not an open question: no `screen` line is printed.
- A `state blocked` screen that is neither a dialog with a block nor a question prints no `screen` line, as today.

## `answer --screen` on a work question (FR-007, SC-004)

- With `--screen <hash>` and a screen that is not a permission dialog: `answer` takes the question block again just before it sends. A different hash, or no question block, prints `The pane shows another prompt. Nothing sent. Tell the user the workspace, the tab and the prompt.`, exits 1 and sends nothing.
- With `--screen <hash>` and `--text`, `answer` sends the `Type something.` key first. It takes this key from the hashed question block. It does not read the pane again for it.
- `answer --text`, with or without `--screen`: the text goes in with `pane send-text`, then `answer` waits 1 s, then sends `enter` with `pane send-keys`. The wait is a fixed sleep (`scripts/st-worker.sh:603`): a live run lost the Enter when it came at once (research.md, T013 3.2).
- With no `--screen`: as today, with the wait above for `--text`.
- The permission dialog path does not change, except the never check below.

## Never check on a one-time yes (FR-011)

- When `answer` is about to send a one-time yes to a dialog (`y=1` at `scripts/st-worker.sh:576`), it checks the dialog block (the lines the screen hash covers) with `python3 <plugin root>/hooks/st-approve.py --never`, which reads the text on stdin, removes every copy of this plugin's own `scripts/st-lock.sh` path (the strip `bash_ok` makes, `hooks/st-approve.py:164-166`), and exits 0 when what is left matches the hook's `NEVER` pattern (`hooks/st-approve.py:28-39`), on the text or on the text with quotes removed, and 4 when it does not. The match also runs on a joined copy of the text, with and without quotes: a backslash at a line end is removed with its line break and the spaces, tabs and `│` after it, and each other line break with the spaces, tabs and `│` around it becomes one space, so an action split over two screen lines still matches. The match also runs on a third copy, with and without quotes. This copy removes a backslash at a line end in the same way. It removes each other line break, with the spaces, tabs and `│` around it, and puts no space there. Thus a word broken inside a long token over two screen lines (`.en`, then `v.local`) still matches. The join also puts a description or option line next to the command, so a never-list word there refuses the yes too: the user then answers in the pane. Known limits: a plugin root reached through a symlink is not stripped, so its [lock] test dialog is refused; a command that writes to the plugin's own `st-lock.sh` is not on the never list, like any other path outside the worktree (no path rule, D42). Exit 4 is the only "clean" code: a crash or the SIGTERM handler (`hooks/st-approve.py:474-476`) exits 1, and `answer` must never read that as clean.
- Exit 0 prints `The dialog's action is on the never list. Nothing sent. Tell the user the workspace, the tab and the prompt.`, exits 1 and sends nothing.
- Any exit other than 0 and 4 prints `The never check did not run. Nothing sent. Tell the user the workspace, the tab and the prompt.`, exits 1 and sends nothing. `answer` sends the yes only on exit 4.
- A "No" option is never checked: it is always allowed when the rest of the rules allow it.

## `--record <file>` (FR-008)

- `answer`: after the keys or the text were sent (after `send-keys` or the `enter` of a typed answer), add one line: `<UTC time>\tworker-<id>\ttab worker-<id>\tanswer\t<question>\t<answer>`. `<question>` is the dialog block or the question block that the hash covers, or with no `--screen` the last 15 screen lines; lines joined by ` | `, control characters removed, the last 600 characters. `<answer>` is `keys <k>...` or `text <t>`. A line that cannot be written prints `Sent, but cannot write the record file <file>.` and exits 1.
- `resend`: after Enter was pressed, add `<UTC time>\tworker-<id>\ttab worker-<id>\tresend\t/goal prompt\tEnter`. The line is written also when the prompt then stays in the input box (exit 7, `state unsent`). An Enter that herdr refuses prints a `stopped: ` line, exits 1 and writes no line. A line that cannot be written prints `Sent, but cannot write the record file <file>.` and exits 1.
- `approve --record`: no change.
- `pass`: takes `--record <file>` too (D36: every monitor command names a path in its own folder). After it writes `<rid>.user`, add `<UTC time>\tworker-<id>\ttab worker-<id>\tpass\t<rid>\t-`. A line that cannot be written prints `Sent, but cannot write the record file <file>.` and exits 1; `<rid>.user` stays. With no `--record`, as today.
- The record file changes only when an answer or an approval is recorded.
- For a worker on a saved machine the record file is on this machine, the same as for a local worker (FR-005).

## `wait --beat <file>` (FR-021)

- This flag is how `wait` learns the path of the beat file: the smallest form, one explicit path.
- Before the first herdr call, make the file if it is missing and set its mtime; set the mtime again at each loop slice. A file that cannot be written prints `Cannot write the beat file <file>.` and exits 1 before any herdr call.
- The main session writes the same file with the Write tool just before it starts or continues a monitor (contracts/st-worker-skill.md C1). Its content is not read.
- For a worker on a saved machine the beat file is on this machine.

## `stale <beat file>...` (FR-021)

- Needs no herdr pane and no worker id.
- For each beat file older than the bound, it prints `stale\t<file>\t<age in s>`. For a missing beat file, it prints `stale\t<file>\t-`.
- Exit 4 when it printed a line, else exit 0 with no output. No argument: the usage line, exit 2.
- The bound is a constant in the script with a `ponytail:` comment. The task that builds `stale` sets its number from the T001 measure with the formula of research.md R6. T001 runs before every build task, so the number is known then.
