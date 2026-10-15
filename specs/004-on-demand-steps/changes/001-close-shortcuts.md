# 001 close-shortcuts

What: At the end of a feature, Close lists only the `ponytail:` markers that the feature's diff
adds, as `file:line: <marker line>`. The user picks per row: fix now or keep (Q1: "log for later" joins "keep"; the marker in
the code is the record, and `st-ponytail-debt` finds it).
One script does the listing, the `st-close` agent runs it, and both lanes reach that agent.
FRs: none. spec.md Assumptions lists I5 as out of scope, and decisions.md D2 sends it to the Fast lane (agreed with the user 2026-10-14).
Impact area: core runtime

## Files
- scripts/st-shortcuts.sh (new) - `st-shortcuts.sh [base]`, base defaults to `main`. Runs
  `git diff -U0 <base>...HEAD -- . ':!*.md'`. An awk step (same style as `st-verify.sh`) tracks the
  file and the `+` line numbers from the `@@` headers. It keeps added lines that match
  `(#|//|/[*]) ?ponytail:` (the regex from `skills/st-ponytail-debt/SKILL.md:20`) and prints
  `<file>:<line>: <line text>`. If nothing matches, it prints `No new ponytail: markers.` Exit 0.
- agents/st-close.md - Inputs: add "base for the shortcut list". New step `### 4. Shortcuts`:
  run `bash <plugin root>/scripts/st-shortcuts.sh <base>` from the project root and report the
  rows as printed. Report line 1 adds the count, e.g. "Close done: 4 drift fixes, 2 gaps, 1 lesson,
  3 shortcuts".
- skills/st-close/SKILL.md - step 2 passes base `main`. New step after 5 (Lessons) and before
  6 (Docs graph): "Shortcuts". Show each row and the user picks fix now or keep.
  Fix now goes to `stratum:st-build`, then `st-verify.sh`. Keep needs no record because
  `st-ponytail-debt` finds kept markers across the whole repo. Gate line adds "shortcuts and their fate".
- skills/st-fast/SKILL.md - step 1: note `git rev-parse HEAD` before the agent starts. Step 7:
  pass that SHA to `st-close` as the base, and change "drift fix only" so it does not exclude
  the shortcut list. Step 8: handle the rows as in `/stratum:st-close` "Shortcuts".

Base: the Full lane uses `main`. The Fast lane always uses the HEAD noted at step 1. If the
work is committed on `main`, `main...HEAD` is empty (checked on a temp repo: 0 lines). No hook
blocks commits on `main`. The noted SHA also leaves out earlier commits on the same branch.

## Tests (written first, must fail before the build)
- tests/test_shortcuts.sh (new) - temp git repo, modeled on `tests/test_verify.sh`. Each check
  fails today because the script does not exist. Checks:
  - a branch that adds `# ponytail: global lock` to `a.py` prints exactly one row,
    `a.py:<n>: # ponytail: global lock`
  - a branch with no marker prints `No new ponytail: markers.` (negative control)
  - a marker that is already on `main` and not changed on the branch is not listed
  - a branch that adds only `docs/x.md` with `use a // ponytail: comment` prints the empty line
  - commits on `main`, `[base]` = the SHA before them, print the row. With no base, the same
    commits print the empty line.
  - phrase checks (`grep -qF`): `agents/st-close.md` and `skills/st-close/SKILL.md` name
    `scripts/st-shortcuts.sh`, `skills/st-close/SKILL.md` has `fix now or keep`, and
    `skills/st-fast/SKILL.md` has `git rev-parse HEAD`
  - command: `bash tests/test_shortcuts.sh`

## Risks
- R1: I5's own test file adds `printf '# ponytail: ...'` fixture lines in a `.sh` file, so its
  own Close lists them. Accept them (keep). No special case.
- R2: A real marker in a `.md` file is skipped. This is the same trade-off `st-verify.sh` makes.
- R3: If the session breaks between Fast steps 1 and 7, the noted SHA is lost. Fall back to
  `main`, or to the parent of the first commit that added the change plan.

## Out of scope
- F3 (Q2): Fast step 6 commits before step 7, so `st-close` doc edits in the Fast lane are
  never committed. This was there before this change. It is a separate item.
