# 002 enter-and-working-dialogs

What: (#104) The Enter that submits typed text is sent with `pane send-keys <pane> enter`, which submits on old and new herdr. (#105) `wait` and `watch` report a live permission dialog or open question of a `working` worker as `blocked`, within one 10 s slice. `answer` also accepts a `working` worker whose screen shows a live permission dialog, keeps every present check, and reports `blocked` when the dialog is still open after the key.
FRs: 008 FR-004 (wait bound), FR-006 (answer a blocked worker), FR-007 (`--machine` on every herdr call), FR-015 (stub-checkable). 014 FR-010, FR-011. 019 FR-001 to FR-003, FR-014. `resend`, `watch` and `unsent` have no FR (issues #65 and #68).
Impact area: core runtime

## Files
- scripts/st-worker.sh `push()` (:208): `[ -n "$PANE" ] || look`, then `h pane send-keys "$PANE" enter`. `goal` reaches `prompt` with `PANE` empty.
- scripts/st-worker.sh `answer --text` (:540): the Enter is `h pane send-keys "$PANE" enter`. The `"$k"` digit for "Type something." stays `agent send-keys`.
- scripts/st-worker.sh helpers (:179-206):
  - `block()` keeps the head line number in a global `HD`.
  - `live <line> <text>` (:195): true when no line after `<line>` starts with `^([[:space:]]|│)*❯`, except an option line (`❯` then `<digits>.`). An input box below the dialog, also an indented or framed one, means the dialog is quoted output.
  - `question()` (:198) ends with `live`, anchored on its last `Enter to select` or `Ready to submit your answers` line. Every question caller uses this rule: `wait` idle/done, `watch`, `list`, `followup` and `answer`.
  - `shown()` (:199): first `BM= SH=`. If `screen && perm`, then `block` and `[ -n "$BM" ] && live "$HD" "$SC"`. Else `question`.
- scripts/st-worker.sh `wait` (:459-480): slice the wait. `agent wait "$N" --timeout <min(left, 10000)>`. A `timeout` adds one to a slice count. Exit 3 (`state working`) when `left <= 0` or after 54 timed-out slices. The count stops a hot loop when herdr, or the stub in W2, returns a timeout at once. After `look`: `[ "$S" != working ] || ! shown || S=blocked`, so the present `blocked` branch runs. `ponytail:` fixed 10 s slice.
- scripts/st-worker.sh `watch` (:671): each row starts with `key= dlg=`, then `[ "$S" != working ] || ! shown || { S=blocked; dlg=1; }`. This comes before the `find_worker` case, so `WT` and `Q` belong to this row. When `dlg` is set and `BM` is `block`, the seen key is `blocked $SH` (the 019 block hash). Else it is the cksum of the visible screen, as today.
- scripts/st-worker.sh `answer` (:507-547):
  - `! question || q=1`. The gate stays on one line (NC5): `[ -n "$q" ] || [ "$S" = blocked ] || { [ "$S" = working ] && shown && [ -n "$BM" ] && dlg=1; } || fail "not blocked: $S"`.
  - So a `working` worker passes through `shown` only with a live permission dialog. A question still needs `q`.
  - When `dlg` is set, the screen read of the gate is the one that gets judged, with no second read. The `perm` checks after it do not change: `--text` refused, `--screen` needed, hash match, one key, one-time yes or a plain No.
  - After the key, when `dlg` is set: `sleep 2`, then if the dialog is still open, `state blocked`, exit 4. Else `state working`, exit 0. `ponytail:` fixed 2 s.
- tests/test_st_worker.sh herdr stub (:107-116):
  - The `pane.after` swap is moved to a new `"pane send-keys"` case.
  - On `agent prompt`, `pane.prompt` moves to `pane.txt` (GO2).
  - `"agent read"` reads `$T/pane.<name>.txt` when it exists (WD9). With `swap.after` and `swap.at`, it moves in a new pane after a set number of reads (WD10, WD13).
- tests/test_st_worker.sh helpers:
  - `sendlog` (:841) matches `pane\tsend-(text|keys)`.
  - The "nothing sent" pattern is `^(agent\tsend-keys|pane\tsend-(text|keys))\t`.
  - The bare "no key" counts (W7, RS2, A2, AQ4, AQ7, AQ8, AQ9) are `^(agent|pane)\tsend-keys\t`.
- Docs: specs/008-herdr-workers/contracts/script.md (the `wait`, `answer` and `watch` steps, and rows A3 and WD), contracts/skill.md:45 and :91, skills/st-worker/SKILL.md step 6, and decisions.md D38. specs/014 answer.md §2 and specs/019 dialog-block.md §2 each get one pointer line. research.md and quickstart.md are history: no edit.

## Tests (written first, must fail before the build)
Command: `bash tests/test_st_worker.sh`, and `bash tests/test_on_demand.sh` for the SKILL.md text.

Part 1:
- Changed: S5b, S5c, RS1, RS3, WC4 and WC5 count one `pane\tsend-keys\t<pane>\tenter` and no `agent send-keys ... enter`. In A3 and AQ1, `sendlog` has the pane Enter. R10 stays (a digit).
- New: R10b (`--machine laptop --text`) and GO2 (`goal` with a stalled prompt). Each checks that exactly one Enter goes out, with the real pane id.

Part 2 (the input-box lines are a spinner, `$rule`, `❯$nb`, `$rule` and a footer):
- WD1, WD3 wait: a live dialog, or a live question, while `working` gives exit 4 after one 10 s slice. WD1 has the block hash on the `screen` line.
- WD2, WD3b wait: a quoted dialog, or a quoted question, gives exit 3 after 54 slices.
- WD4 watch: a live dialog gives the seen key `blocked <bh>`.
- WD5 watch: a quoted dialog is not reported.
- WD9 watch, two workers: a quoted dialog in row 1, then a live question in row 2. Row 2 gets the cksum key, and a changed question is reported again.
- WD6 answer: a live dialog while `working` that stays open after the key gives key 1 sent once, one `sleep 2`, `state blocked`, exit 4.
- WD10 answer: the dialog closes after the gate read. The call is judged on the gate screen: `--keys 1` is sent and gives exit 0, `--keys 2` and `--text` are refused.
- WD7, WD3c, WD12 answer: a quoted dialog, a quoted question, or an indented or framed input box gives `not blocked: working` and nothing sent.
- WD8 answer while `working`: no `--screen`, a lasting option and `--text` are each refused, and nothing is sent.
- WD11: a `done` worker with a quoted question. `wait` gives `finished`, and `followup` is not refused.
- WD12 also has a `wait` row: exit 3.
- WD13 answer `--text`: a live question shows up only after the first read of a `working` worker. It gives `not blocked: working`, nothing sent.
- Existing rows:
  - AQ4, AQ7, AQ8 and AQ9 stay `not blocked: done`.
  - AQ1, AQ2, AQ3, AQ6, W8 and L2 stay green: no question fixture has an input box below it.
  - A2 and NC5 stay.

## Live proof (#104)
Run on 2026-11-13 with herdr 0.9.5 (installed 2026-11-12), in one scratch Claude pane that is now closed. `herdr agent send-keys <name> enter` submitted in all three places:
- the prompt box,
- the "Type something." field while the worker was `blocked`,
- the same field while it was `done` (read 8 s after the key).

`pane send-keys <pane> enter` also submits, and capital `Enter` works with both. So the bug does not happen on 0.9.5. It was seen on the older herdr, and the laptop's herdr version is unknown. The key change keeps one form that submits on both. No manual step is left for #104.

## Risks
- R1: The live text of a subagent dialog is not in the repo. `shown` uses the present `HEAD`, `PERM`, option-line and question patterns. `live` assumes that Claude hides the input box under an open dialog (REAL fixture) and shows it while working (`sentpane`). If a subagent dialog keeps the box below it, the worker is handled as today: no report, never a wrong report.
  - Optional capture: in a scratch pane with `--permission-mode default`, ask for a subagent that runs one Bash command. Save `herdr agent get <name>` and `herdr agent read <name> --source recent-unwrapped --lines 40`.
- R2: A dialog of a `working` worker with two head lines (the AN6f shape) or no option line has `BM` empty, so it is not reported. The same as today.
- R3: Each 5 s poll of a `working` worker in `watch`, and each 10 s slice in `wait`, adds one or two `agent read` calls. On a saved machine, these go through herdr's machine link.
- R4: W2, WD2 and WD3b run 54 stub slices each. This adds a few seconds to the test run.
- R5: `list` still shows a `working` worker that has a dialog as `working`. This was not in the request.
- R6: Every question caller (`wait`, `watch`, `list`, `followup`, `answer`) now ignores a question that has an input box below it. A real question in that shape would not be seen. No fixture or live capture shows that shape.

## Review record
- st-review findings fixed:
  - two screen reads in `answer` (now the gate read is the judged one),
  - no re-check after a key (now `sleep 2` and `state blocked`),
  - `question` and `qlive` not agreeing (`live` moved into `question`),
  - the bare `^❯` prefix (now `^([[:space:]]|│)*❯`).
- Dropped: `PANE` is `-` in `watch`.
