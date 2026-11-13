# 002 enter-and-working-dialogs

What: (#104) The Enter that submits typed text is sent with `pane send-keys <pane> enter`, which submits on old and new herdr. (#105) `wait` and `watch` report a live permission dialog or open question of a `working` worker as `blocked`, within one 10 s slice. `answer` also accepts a `working` worker whose screen shows a live dialog, and it keeps every present check.
FRs: 008 FR-004 (wait bound), FR-006 (answer a blocked worker), FR-007 (`--machine` on every herdr call), FR-015 (stub-checkable). 014 FR-010, FR-011. 019 FR-001 to FR-003, FR-014. `resend`, `watch` and `unsent` have no FR (issues #65 and #68).
Impact area: core runtime

## Files
- scripts/st-worker.sh `push()` (:198-199): `[ -n "$PANE" ] || look`, then `h pane send-keys "$PANE" enter`. `goal` reaches `prompt` with `PANE` empty. `start` and `resend` have it, and `watch` sets it at :657.
- scripts/st-worker.sh `answer` (:528): the Enter becomes `h pane send-keys "$PANE" enter`. The `"$k"` digit for "Type something." (:525) stays `agent send-keys`. Nothing else changes after the settle wait.
- scripts/st-worker.sh new helpers next to `block()` (:179):
  - `block()` keeps the head line number in a global `HD` (today `hd` is local).
  - `live <line> <text>`: true when no line after `<line>` in `<text>` starts with `❯`, except an option line (`^❯[[:space:]]*[0-9]+\.[[:space:]]`). An input box below the dialog means the dialog is quoted output.
  - `qlive()`: `question && live <last line of $t matching "Enter to select|Ready to submit your answers"> "$(cat "$t")"`. `question()` itself does not change, so `wait` idle/done, `list` and `followup` keep their present rule.
  - `shown()`: first `BM= SH=`. Then, if `screen && perm`, run `block` and `[ -n "$BM" ] && live "$HD" "$SC"`. Else `qlive`.
- scripts/st-worker.sh `wait` (:453-465): slice the wait. Run `agent wait "$N" --timeout <min(left, 10000)>`. A `timeout` error no longer exits. It adds one to a slice count, and the loop goes on to `look`. Exit 3 (`state working`) when `left <= 0` or after 54 timed-out slices. The count stops a hot loop when herdr, or the stub in W2, returns a timeout at once. After `look` (:466): `[ "$S" != working ] || ! shown || S=blocked`, so the present `blocked` branch runs: `approval`, `st blocked`, exit 4. `ponytail:` fixed 10 s slice. Raise it if the extra screen reads cost too much.
- scripts/st-worker.sh `watch`: at the top of each row, reset a flag `dlg=`. Right after `PANE=` (:657): `[ "$S" != working ] || ! shown || { S=blocked; dlg=1; }`. This must come before the `blocked | idle | done` `find_worker` case (:659), so `WT` and `Q` belong to this row and not to the last row. In the `blocked` branch (:672-673), when `dlg` is set and `BM` is `block`, the seen key is `blocked $SH` (the 019 block hash, stable while a spinner line changes). Else it is `blocked <cksum of the visible screen>` as today. `shown()` clears `BM` and `SH`, and the `dlg` reset is per row, so no row uses another row's values.
- scripts/st-worker.sh `answer` (:497-498): `! qlive || q=1`. The gate stays on one line, so NC5 still deletes it whole: `[ -n "$q" ] || [ "$S" = blocked ] || { [ "$S" = working ] && shown; } || fail "not blocked: $S"`. A quoted question no longer sets `q`. The `perm` checks after it (:501-516) do not change: `--text` refused, `--screen` needed, hash match, one key, one-time yes or a plain No. After a key to a `working` worker, `answer` prints `state working`, exit 0, because herdr cannot show "still blocked". The next `wait` or `watch` reports the dialog if it is still open.
- tests/test_st_worker.sh herdr stub:
  - (:109-110) Move the `pane.after` swap from `"agent send-keys"` to a new `"pane send-keys"` case with the same rule (last argument `enter`).
  - (:20) After the `--machine` shift, add one line: on `agent prompt`, if `$T/pane.prompt` exists, move it to `$T/pane.txt` (for GO2).
  - `"agent read"` reads `$T/pane.<name>.txt` when it exists, else `$T/pane.txt` (for WD9).
  - Add `"$tmp/pane.prompt"` and `"$tmp"/pane.worker-*.txt` to the `fresh()` rm list (:261).
- tests/test_st_worker.sh helpers:
  - `sendlog` (:833) also matches `pane\tsend-keys`.
  - Every "nothing sent" pattern `^(agent\tsend-keys|pane\tsend-text)\t` becomes `^(agent\tsend-keys|pane\tsend-(text|keys))\t` (one sed over the file).
  - Every bare "no key" count `cnt "^agent\tsend-keys\t")" = 0` becomes `cnt "^(agent|pane)\tsend-keys\t")" = 0`. These are W7 (:607), RS2 (:622), A2 (:847), and AQ4, AQ7, AQ8, AQ9 (:871-884). Without this change, RS2, W7 and A2 still pass when an Enter goes out by `pane send-keys`.
  - The `pane.after` users are S5b (:395), RS1 (:617) and WC4 (:1880). All three need the moved swap.
- Docs that must follow (same build, after the tests are green):
  - specs/008-herdr-workers/contracts/script.md:
    - The `wait` steps (:249-262) get the 10 s slices, the 54-slice count, and a working worker with a live dialog becoming `blocked`.
    - The `answer` steps (:266-283): step 1 adds "or a `working` worker whose screen shows a live dialog", and a question counts only when it is live. Step 2's `--text` Enter is `H pane send-keys <pane> enter`.
    - Row A3 (:464) changes. New rows are added for the tests below. A short `watch` note is added, because `watch` has no section today.
  - specs/008-herdr-workers/contracts/skill.md:45 and :91: keep the `not blocked` sentence word for word, and add the case of a `working` worker whose screen shows a live dialog.
  - skills/st-worker/SKILL.md step 6, line 26: `watch` also reports a live dialog of a `working` worker. Line 27: keep "`not blocked` means the user answered in the pane: send nothing more." word for word, because tests/test_on_demand.sh:223 pins it.
  - specs/008-herdr-workers/decisions.md: new D38 (pane send-keys for Enter, the live rule, 10 s slices, the watch key, the `working`-only answer gate).
  - One pointer line to this change in specs/014-prompt-answers/contracts/answer.md section 2 ("For a blocked worker") and in specs/019-autonomous-prompts/contracts/dialog-block.md section 2. specs/008-herdr-workers/research.md:220-221 and quickstart.md:107 are history: no edit.

## Tests (written first, must fail before the build)
Command for every row: `bash tests/test_st_worker.sh`. After the SKILL.md edit, also run `bash tests/test_on_demand.sh`.

Part 1, changed rows:
- S5b and S5c (:397, :400), RS1 and RS3 (:619, :625), WC4 and WC5 (:1882, :1885): count `pane\tsend-keys\t<pane>\tenter` = 1 and `agent\tsend-keys\t[^\t]*\tenter$` = 0. With the swap moved in the stub, S5b, RS1 and WC4 also go red on the old script by behaviour (the prompt stays in the box, so exit 7).
- A3 (:853) and AQ1 (:862): the expected `sendlog` has `pane\tsend-keys\t<pane>\tenter` in place of `agent\tsend-keys\tworker-t004\tenter`.
- R10 (:1053) stays: a digit still goes through `agent send-keys`.

Part 1, new rows:
- R10b: `rmk; states blocked working`, then `answer --machine laptop --text "use main"`. `rcall "pane\tsend-keys\t%s\tenter" "$(pane)"`, no `agent send-keys ... enter`, and `rnever 0 0` (every call names `--machine laptop`).
- GO2: `mk`, `sentpane > pane.txt`, `unsentpane > pane.prompt`, `sentpane > pane.after`, `STUB_FAIL="agent prompt" STUB_FAIL_CODE=agent_prompt_stalled`, then `goal T004`. It gives exit 0 and the exact call `pane\tsend-keys\t<pane>\tenter` with the real pane id. This proves that `push` looks up `PANE` in `goal`.

Part 2, new rows (after the DB block, :1966, where `REAL`, `bh`, `dbput`, `dbwait` and `wrun` exist). The input-box lines are `✻ Working… (esc to interrupt)`, `$rule`, `❯$nb`, `$rule`, `  ⏵⏵ auto mode on (shift+tab to cycle)`.
- WD1 wait: `mk; states working; dbput "${REAL[@]}"`, `STUB_FAIL="agent wait" STUB_FAIL_CODE=timeout`, `wait T004`. It gives exit 4, `state blocked`, one `screen` line with hash = `$bh`, `pane text:`, and exactly one `agent wait` call, which has `--timeout\t10000`. The old script gives exit 3.
- WD2 wait, quoted dialog: `REAL` plus the input-box lines. It gives exit 3, `state working`, no `screen` line and 54 `agent wait` calls. A script without `live` goes red.
- WD3 wait, question while working: `dialogpane` gives exit 4, `state blocked` and no `screen` line. WD3b: `dialogpane` plus the input-box lines gives exit 3.
- WD4 watch: `mk; rm -f "$wr.seen"; states working; dbput "${REAL[@]}"; wrun`. It gives exit 4, `shash` = `$bh`, and `$wr.seen` is `worker-t004\tblocked <bh>`.
- WD5 watch, quoted: `states working working done`, the WD2 pane, `printf 'R\n' > "$lw/result.md"`. It gives exit 0, `state finished`, no `state\tblocked` line and `sleeps` = 2.
- WD6 answer: `dbwait "${REAL[@]}"`, then `states working working` and `answer --screen "$h" --keys 1`. It gives exit 0, `agent send-keys worker-t004 1` and `state working`. The old script prints `not blocked: working`.
- WD7 answer, quoted dialog: the WD2 pane, `states working`, `--screen "$bh" --keys 1`. It gives `not blocked: working` and nothing sent.
- WD8 answer while working, with the checks kept. `--keys 1` without `--screen` gives the needs-screen line. `--screen "$h" --keys 2` gives `Option 2 is not a one-time yes. ...`. `--text hi` gives the permission line. Nothing is sent in each case.
- WD3c answer, quoted question: the WD3b pane, `states working`. Both `--keys 1` and `--text hi` give `not blocked: working`, and nothing is sent. Today's script sends in both, because `q` is set.
- WD9 watch, two workers: a roster with `worker-t004 local repo-t004 T004` and `worker-t005 local repo-t005 T005`, and both started.
  - `pane.worker-t004.txt` is the WD2 pane (a quoted permission dialog). `pane.worker-t005.txt` is `dialogpane` (a live question).
  - `states working working`, then `wrun`. It gives exit 4 and `state blocked` for worker-t005. The seen key of worker-t005 is `blocked <cksum -d' ' -f1 of pane.worker-t005.txt>`, not a 12-hex hash.
  - Change the question line in `pane.worker-t005.txt`, `states working working`, `reset`, then `wrun` again. It gives exit 4 again for worker-t005.
  - Without the `BM= SH=` reset, worker-t005 gets the stale `SH` of worker-t004 as its key, so the second run reports nothing and goes red.

Existing rows run through the new rule:
- AQ4 and AQ8 stay `not blocked: done`. The new gate reads the screen only for `working`.
- AQ7 and AQ9 stay `not blocked: done`. They show no head and no live question.
- AQ1, AQ2, AQ3 (`dialogpane`, AQ3 without the "Type something." line) and AQ6 (`reviewpane`) stay green. `qlive` is true for each:
  - In `dialogpane` the anchor `Enter to select …` is the last line.
  - In `reviewpane` the anchor `Ready to submit your answers?` is followed only by `❯ 1. Submit answers` (an option line) and `  2. Cancel`.
  - No test fixture has an input box below a question. The question fixtures are at :306, :608, :819, :860-866, :873 and :2034.
- A2 stays (`STUB PANE` text, no dialog). NC5 stays: `not blocked: ` is on one line.

## Live proof (#104)
Run on 2026-11-13 with herdr 0.9.5 (installed 2026-11-12), in one scratch Claude pane that is now closed. `herdr agent send-keys <name> enter` submitted in all three places:
- the prompt box,
- the "Type something." field while the worker was `blocked`,
- the same field while it was `done` (read 8 s after the key).

`pane send-keys <pane> enter` also submits, and capital `Enter` works with both. So the bug does not happen on 0.9.5. It was seen on the older herdr, and the laptop's herdr version is unknown. The key change keeps one form that submits on both. No manual step is left for #104.

## Risks
- R1: The live text of a subagent dialog is not in the repo. `shown` uses the present `HEAD`, `PERM`, option-line and question patterns. `live` assumes that Claude hides the input box under an open dialog (REAL fixture, tests/test_st_worker.sh:1915) and shows it while working (`sentpane`, :305). If a subagent dialog keeps the box below it, `shown` stays false and the worker is handled as today. That means no report, never a wrong report.
  - Optional capture: in a scratch pane with `--permission-mode default`, ask for a subagent that runs one Bash command. Save `herdr agent get <name>` and `herdr agent read <name> --source recent-unwrapped --lines 40`. Check that the status is `working` and that no input-box `❯` line is below the dialog.
- R2: A dialog of a `working` worker with two head lines (the AN6f shape) or no option line has `BM` empty, so it is not reported. The same as today.
- R3: Each 5 s poll of a `working` worker in `watch`, and each 10 s slice in `wait`, now adds one or two `agent read` calls. On a saved machine, these go through herdr's machine link.
- R4: W2 and WD2 now run 54 stub slices each. This adds a few seconds to the test run.
- R5: `list` still shows a `working` worker that has a dialog as `working`. This was not in the request.
- R6: `answer` now refuses a quoted question that today's script answers. A worker whose real question sits above an input box would get `not blocked`. No fixture or live capture shows that shape.
