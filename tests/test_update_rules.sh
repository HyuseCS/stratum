#!/usr/bin/env bash
set -u
root="${ST_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

while IFS='|' read -r id file phrase; do
  check "$id $file" 'grep -qF -- "$phrase" "$root/$file"'
done <<'ROWS'
R1|skills/st-update/SKILL.md|bash <script> audit <folder>
R1b|skills/st-update/SKILL.md|show the line and stop.
R2|skills/st-update/SKILL.md|only the rows that are not `current`
R2b|skills/st-update/SKILL.md|one line per folder with the count
R3|skills/st-update/SKILL.md|OK to update all, or `skip <worktree>`
R3b|skills/st-update/SKILL.md|No: stop, nothing
R4|skills/st-update/SKILL.md|is on branch <branch>, not main. The update installs that branch.
R5|skills/st-update/SKILL.md|bash <script> plugin <folder>
R5b|skills/st-update/SKILL.md|go on with the next folder.
R5c|skills/st-update/SKILL.md|Exit 0: run `fix <folder> statusline statusLine` for that folder
R7|skills/st-update/SKILL.md|ask the question of st-init step 3, 4, 7 or 11, one at a time
R7b|skills/st-update/SKILL.md|Skip: leave the file missing.
R7c|skills/st-update/SKILL.md|tell the user to run `/stratum:st-constitution`
R8|skills/st-update/SKILL.md|git -C <checkout> add -- <paths> && git -C <checkout> commit -m "chore(stratum): update harness files to <version>" -m "<one line per item>" -- <paths>
R8b|skills/st-update/SKILL.md|The commit ends with `-- <paths>`, so files the user staged before stay out of it.
R8c|skills/st-update/SKILL.md|No `-A`, no
R8d|skills/st-update/SKILL.md|`--amend`, no `--no-verify`, no push
R9|skills/st-update/SKILL.md|A denied commit: quote the deny reason and
R9b|skills/st-update/SKILL.md|give the exact command (D11)
R9c|skills/st-update/SKILL.md|Name no personal script.
R10|skills/st-update/SKILL.md|A Bash call a hook or the classifier blocks: keep the exact command for the user
R11|skills/st-update/SKILL.md|Per folder: what changed, what was skipped and why, the commands the user must run.
R11b|skills/st-update/SKILL.md|Restart running Claude Code sessions in these folders to load Stratum <version>.
ROWS

check "front matter skills/st-update/SKILL.md" 'head -n 5 "$root/skills/st-update/SKILL.md" | grep -qx "name: st-update"'

check "R9d no veent-commit-ask skills/st-update/SKILL.md" 'test -f "$root/skills/st-update/SKILL.md" && ! grep -qF -- veent-commit-ask "$root/skills/st-update/SKILL.md"'

exit $fail
