#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

while IFS='|' read -r id file phrase; do
  check "$id" 'grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
A1|skills/st-build/SKILL.md|A `REVISE` with only MEDIUM and LOW findings counts as passed: handle each finding and do not run the point again.
A2|skills/st-build/SKILL.md|Run the point again only when a CRITICAL or HIGH fix changed the plan, or the plan's approach changed.
A3|skills/st-build/SKILL.md|The approach changed when a user story or task was added or removed, a file outside the plan's file list is now touched, or a design choice in `plan.md` was replaced. A fix inside a task's own text and files is not an approach change.
A4|skills/st-build/SKILL.md|Two rounds at most per point per gate pass, then the user decides.
A5|skills/st-inspect/SKILL.md|If the plan changed at Inspect only by fixes of findings, with no approach change, run `bash <plugin root>/scripts/st-advisor.sh waive plan <feature dir> "<reason>"` in place of the plan point.
A6|skills/st-inspect/SKILL.md|At "OK to build?", show the `WAIVED` line and its reason.
A7|skills/st-build/SKILL.md|`WAIVED sha256 <hash>`: the plan changed only by fixes, and `check plan` passes until the input changes again.
A8|skills/st-build/SKILL.md|Skip the end-of-Build advisor pass when every story had an `st-review` and no code changed after the last one.
A9|skills/st-build/SKILL.md|Otherwise run it once, on the changes after the last review only: `bash <plugin root>/scripts/st-advisor.sh diff <feature dir> <last review sha>`.
A10|skills/st-build/SKILL.md|Note `git rev-parse HEAD` after each story's review fixes are committed: that is the story's review point.
A11|skills/st-build/SKILL.md|Then run `bash <plugin root>/scripts/st-advisor.sh count <feature dir>` and show its line word for word.
A12|skills/st-build/SKILL.md|After each `/advisor` call, run `bash <plugin root>/scripts/st-advisor.sh note <point> <feature dir> "<one-line summary>"`.
A13|skills/st-build/SKILL.md|`no change since <base>: skip`: nothing changed after the last review, so the pass is skipped.
A14|skills/st-build/SKILL.md|Codex only reviews: it never creates, changes or deletes a file, and never builds or fixes anything. The user may use the Codex tab for their own work.
A15|skills/st-build/SKILL.md|`BLOCKED: Codex changed files during the review: <paths>`: show the paths. Revert nothing. The user checks them with `git diff` and keeps or reverts them, then says run the point again or continue (`continued`).
A16|README.md|Each review in the tab compares HEAD and the changed and untracked files before and after the turn. Any difference ends the point `BLOCKED` with the files named. Nothing is reverted.
A17|skills/st-build/SKILL.md|Start `bash <plugin root>/scripts/st-advisor.sh watch` with the Monitor tool, then run `bash <plugin root>/scripts/st-advisor.sh <point> ...` with Bash `run_in_background`, both from the project root (a worktree's root for the test point of a `[P]` task). Change no file in that folder until the point ends. When it ends, stop the watch and handle the point's output.
A18|skills/st-build/SKILL.md|On a `codex tab waits:` line, read the screen lines after it. A prompt on the allow list: answer it with `bash <plugin root>/scripts/st-advisor.sh answer --keys <key>`, the key of the one-time yes only ("Yes, proceed", "Yes, just this once"). Never pick an option that says "don't ask again", "allow ... for this session", "in the future" or "for these files", or one that names a host. Every other prompt: show the user the exact screen lines and leave the tab open.
A19|skills/st-build/SKILL.md|Allow list: read a file or list a folder anywhere, except a `.env` file or a key, credential, token or other secret file; run one command only, with no `;`, `&&`, `||`, `|`, `$(` or backticks: `git log`, `git diff`, `git show`, `git status`, `git blame`, `ls`, `cat`, `head`, `tail`, `wc`, `grep`, `rg` or `find`, with no `>`, `>>`, `tee`, `--output`, `--pre`, `-fprint`, `-fprintf`, `-fls`, `-delete`, `-exec`, `-execdir`, `-ok` or `-okdir`; or the project's test or lint command with no `--fix`, `--write`, `-w`, `-u` or `--update-snapshots`.
A20|skills/st-build/SKILL.md|Never approve a file write, move or delete, a git change (`commit`, `checkout`, `switch`, `reset`, `restore`, `stash`, `add`, `rm`, `mv`, `merge`, `rebase`, `pull`, `fetch`, `push`, `tag`, `branch`, `clean`, `apply`, `am`), an install, network use, a `.env` file or secret, or a change to Codex settings or folder trust.
A21|skills/st-build/SKILL.md|`BLOCKED: the Codex tab ended during the review` or `BLOCKED: the Codex tab failed during the review: ...`: show the line. A review in the tab has no time limit; it ends early only this way. Run the point again on the user's word, or `continued`. To stop a hung review, the user presses Esc in the tab or tells you to stop the point.
A22|skills/st-build/SKILL.md|the key of the one-time yes only ("Yes, proceed", "Yes, just this once"). Never pick an option that says "don't ask again", "allow ... for this session", "in the future" or "for these files", or one that names a host.
A23|skills/st-build/SKILL.md|run one command only, with no `;`, `&&`, `||`, `|`, `$(` or backticks
A24|README.md|A review in the tab has no time limit. It ends early only when the tab ends (you close it or Codex exits): the point is then `BLOCKED`, and it does not run the review in the background. Press Esc in the tab to stop a hung review.
TABLE

while IFS='|' read -r id file phrase; do
  check "$id gone" '! grep -qF -- "$phrase" "$root/$file"'
done <<'TABLE'
G1|skills/st-build/SKILL.md|Then run the same point once more on the changed input.
G2|skills/st-build/SKILL.md|consult the advisor if one is set (`/advisor`) on the feature's full
G3|skills/st-build/SKILL.md|No background run, no polling.
G4|skills/st-plan/SKILL.md|in the foreground, with a Bash timeout of 600000 ms
TABLE

exit $fail
