# 003 advisor-test-flakes

What: Fix issue #106 in the tests only. Part 1: the two `timeout` limit checks in `tests/test_advisor.sh` pin a value that depends on the clock, so they fail when the run crosses a second boundary. They will accept `lim - elapsed` and still fail on a wrong limit. Part 2: the "no repo writes" check in the three advisor tests watches the real checkout, so a file write by another process fails it. The tests will run the advisor from a private copy of `scripts/` and check only that copy.
FRs: 017 FR-005 (Part 1). 010 FR-001, FR-002, FR-012 (Part 2, the tests that hold the check, as in change 002).
Impact area: core runtime (test suite only, no script change)

## Cause

Part 1 (proven, red run 2026-11-13, base e81fa14). A `sha256sum` wrapper first on PATH sleeps 1.1 s and then runs the real one. `st-advisor.sh` calls it at :188 (plan) and :190 (review), before `left=$((lim - SECONDS))` at :267. A `paste` wrapper copies the argv line that the check reads.
- Plain run: `ok   timeout argv`, `ok   FR-005 review timeout argv is 1800`, rc 0.
- With the delay: `FAIL timeout argv` (argv `-k,10,539,codex`) and `FAIL FR-005 review timeout argv is 1800` (argv `-k,10,1799,codex`), rc 1. No other check failed.

The script is correct. The contracts set the limit to the time left: `specs/017-st-advisor/contracts/review-point.md:43` (`<1800 - elapsed>`) and `specs/010-workflow-overhaul/contracts/scripts.md:122` (`540 - SECONDS`, counted from script start). Bash counts `SECONDS` in whole clock seconds (`SECONDS=0; sleep 0.3` gave 1 in 6 of 20 runs). The cause is the test, which expects 0 s elapsed.

Bound check (2026-11-13, child `SECONDS=0; sleep 0.0N; echo $SECONDS`):
- `date +%s` after the run minus `date +%s` before it was never below the child's value: 0 of 2000 runs.
- The parent's own `$SECONDS` delta was below the child's value in 10 of 200 runs. Do not use `$SECONDS` in the test.

Part 2 (proven, red run 2026-11-13). `ST_ROOT=<scratch clone> bash tests/test_advisor_waive.sh`, with `(sleep 0.3; printf 'x\n' >> <clone>/README.md) &` started just before it. Result: `FAIL no repo writes`, rc 1. The test wrote nothing. Change 002 lists the same result for `write` and `newfile` in all three tests.

## Files

tests/test_advisor.sh
- :54 `run` and :492 `rrun` record the time around the call:
  `run() { t0=$(date +%s); out=$(adv "$@"); rc=$?; t1=$(date +%s); }` (`rrun` the same with `rvadv`).
- New helper after :54:
  `lim_ok() { local a n; a=$(sed -n 1,4p "$tmp/timeout_argv" 2>/dev/null | paste -sd,); n=${a#-k,10,}; n=${n%,codex}; [[ $a == -k,10,*,codex && $n =~ ^[0-9]+$ ]] && [ "$n" -le "$1" ] && [ "$n" -ge $(( $1 - (t1 - t0) )) ]; }`
- :205 becomes `check "timeout argv" 'lim_ok 540'`. The last call before it is the `run` at :202.
- :505 becomes `check "FR-005 review timeout argv is 1800" 'lim_ok 1800'`. The last call before it is the `rrun` at :500.
- Part 2 edits, listed below.

Part 2, the same edit in each file (tests/test_advisor.sh, tests/test_advisor_matrix.sh, tests/test_advisor_waive.sh):
- `repo_paths` and `repo_before` (test_advisor.sh:9-10, test_advisor_matrix.sh:10-11, test_advisor_waive.sh:9-10) become:
  ```
  repo=$tmp/repo
  mkdir "$repo" && cp -r "$root/scripts" "$repo/" || exit 1
  repo_files() { (cd "$repo" && find . -type f -exec sha256sum {} + | LC_ALL=C sort); }
  repo_before=$(repo_files)
  ```
- Each `"$root/scripts/st-advisor.sh"` becomes `"$repo/scripts/st-advisor.sh"`:
  - test_advisor.sh, 16 lines: :53, :67 (two on the line), :137, :334, :338, :359, :401, :403, :405, :432, :434, :442, :444, :491, :546, :560.
  - test_advisor_matrix.sh, 11 lines: :65, :135, :162, :245, :250, :360, :381, :382, :433, :434, :575. Also `${sr:-$root}` at :326 becomes `${sr:-$repo}`. The `cp -r "$root/scripts"` at :340 stays as is (it only reads).
  - test_advisor_waive.sh, 3 lines: :59, :155, :200.
- The check (test_advisor.sh:619, test_advisor_matrix.sh:595, test_advisor_waive.sh:206) becomes:
  `check "no repo writes" '[ "$(repo_files)" = "$repo_before" ]'`
- `$root` stays where the test needs the real checkout: test_advisor.sh:510 (`git -C "$root" check-ignore`, read only) and the copy source.

Why this works. Only `$(dirname "$0")` lets the scripts find the checkout. No script reads `ST_ROOT`, `CLAUDE_PLUGIN_ROOT` or another environment variable that holds the checkout path (grep of st-advisor.sh, st-codex-agent.sh, st-lock.sh). `cwd` is always a scratch repo under `$tmp`. A run from `$repo/scripts` therefore writes to `$repo` everything that it would write to the checkout. No other process knows `$tmp/repo`. The exact compare also catches deletes and reverts, which the check of change 002 missed.

## Tests (written first, must fail before the build)

All scratch files go in a scratch folder outside the repo (`$S` below). Wrappers are `$S/shim/sha256sum` (`sleep 1.1; exec /usr/bin/sha256sum "$@"`) and `$S/shim/paste` (runs `/usr/bin/paste "$@"` and appends its output to `$S/paste.log`). Use `$C` for a scratch clone: `git clone -q <repo> $C`, then copy the working-tree tests into `$C/tests/`.

1. Part 1 delay test: tests/test_advisor.sh, "timeout argv" and "FR-005 review timeout argv is 1800". Command: `PATH=$S/shim:$PATH bash tests/test_advisor.sh | grep -E '^FAIL|timeout argv'; grep '^-k,10' $S/paste.log`
   - Red before the build (done, see Cause): both checks FAIL, argv 539 and 1799.
   - Green after the build: both checks show `ok`, and the argv is still 539 and 1799.
2. Part 1 negative controls: wrong limit in `$C/scripts/st-advisor.sh`, then `ST_ROOT=$C bash $C/tests/test_advisor.sh | grep -E '^FAIL'`.
   - N1: `sed -i 's/^\[ \$point = review \] && lim=1800$/[ $point = review ] \&\& lim=540/'`. Expect only `FAIL FR-005 review timeout argv is 1800`.
   - N2: `sed -i 's/^lim=540$/lim=1800/'`. Expect `FAIL timeout argv` (review stays 1800).
   - Check that each sed changed the line (`grep -c`) before you trust the result.
3. Part 2 outside write, run once for each of the three tests `$t`. Command: `(sleep 0.3; printf 'x\n' >> $C/README.md; printf 'x\n' > $C/scripts/race-new.txt) & ST_ROOT=$C bash $C/tests/$t | grep -E '^FAIL|no repo writes'; wait`. Reset `$C` between runs.
   - Red before the build: test_advisor_waive.sh done (`FAIL no repo writes`). Run the other two the same way.
   - Green after the build: `ok   no repo writes` in all three.
   - This reverses change 002's expected result for its `write`, `newfile` and `writestaged` modes. Those were negative controls there. Now they must pass.
4. Part 2 negative controls: the advisor writes next to itself. Edit `$C/scripts/st-advisor.sh` after line 3, then run each of the three tests with `ST_ROOT=$C`.
   - N3: add `: > "$(dirname "$0")/../leak.txt"` (new file). Expect `FAIL no repo writes`, rc 1, in all three.
   - N4: add `printf '#\n' >> "$(dirname "$0")/st-lock.sh"` (changes a file that exists, the added line is a comment so the lock still works). Expect `FAIL no repo writes`, rc 1, in all three, and no other new FAIL line.
5. Done-when run (after the build). The three files loop 20 times each, at the same time as each other. `tests/test_codex_agent.sh` loops beside them as load only. Its result does not gate this change (see Risks R5):
   `cd <repo>; for t in test_advisor.sh test_advisor_matrix.sh test_advisor_waive.sh test_codex_agent.sh; do (for i in $(seq 20); do bash tests/$t >/dev/null 2>&1 || echo "FAIL $t run $i"; done; echo "done $t") & done; wait`
   - Expect 4 `done` lines and no `FAIL` line for the three advisor tests.
   - Repeat step 5 with `ST_ROOT=$C` and a writer loop that appends to `$C/README.md` every 0.2 s during the run. Expect the same result.

## Risks

- R1. The limit check now accepts any value from `lim - (t1 - t0)` to `lim`. A script that does not subtract elapsed time passes when the run takes under 1 s, as it did before. That bug is not in scope. The bound held in 2000 of 2000 runs.
- R2. The "no repo writes" check now watches a copy of `scripts/`, not the real checkout. A future script that finds the checkout through something other than `$0` (an environment variable, a fixed path) would not be seen.
- R3. `repo_files` lists files only. A script that creates an empty folder next to itself passes the check.
- R4. Each test copies `scripts/` (144K) once per run.
- R5. `tests/test_codex_agent.sh:272` and `:274` (C25, C26) require "within 5 s" by `$SECONDS`. Under parallel load they can fail. That is a different timing check and is out of scope.
