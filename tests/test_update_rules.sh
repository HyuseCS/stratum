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
R3c|skills/st-update/SKILL.md|or `skip <folder> <kind> <name>`
R3d|skills/st-update/SKILL.md|An item is named by its folder, kind and name, as the table shows them.
R3e|skills/st-update/SKILL.md|A skipped worktree or item is left out of every step after the gate
R3f|skills/st-update/SKILL.md|`skip <folder> allow <settings file>:<entry>`
R3g|skills/st-update/SKILL.md|A skip that names no row: say so and ask again.
R4|skills/st-update/SKILL.md|is on branch <branch>, not main. The update installs that branch.
R5|skills/st-update/SKILL.md|bash <script> plugin <folder>
R5b|skills/st-update/SKILL.md|go on with the next folder.
R5c|skills/st-update/SKILL.md|Steps 5 to 7 take their rows from this second audit.
R5d|skills/st-update/SKILL.md|Leave the skipped worktrees and items out of these rows.
R6|skills/st-update/SKILL.md|For each `ask` row: show the old and the new `statusLine` command and ask. Yes: `fix ... --force`. No: leave it.
R7|skills/st-update/SKILL.md|ask the question of st-init step 3, 4, 7 or 11, one at a time
R7b|skills/st-update/SKILL.md|Skip: leave the file missing.
R7c|skills/st-update/SKILL.md|tell the user to run `/stratum:st-constitution`
R8|skills/st-update/SKILL.md|git -C <checkout> add -- <paths> && git -C <checkout> commit -m 'chore(stratum): update harness files to <version>' -m '<one line per item>' -- <paths>
R8b|skills/st-update/SKILL.md|The commit ends with `-- <paths>`, so files the user staged before stay out of it.
R8c|skills/st-update/SKILL.md|No `-A`, no
R8d|skills/st-update/SKILL.md|`--amend`, no `--no-verify`, no push
R8e|skills/st-update/SKILL.md|`<paths>` are the files that `fix` printed in its `changed <file>` lines for this checkout
R9|skills/st-update/SKILL.md|A denied commit: quote the deny reason and
R9b|skills/st-update/SKILL.md|give the exact command (D11)
R9c|skills/st-update/SKILL.md|Name no personal script.
R10|skills/st-update/SKILL.md|A Bash call a hook or the classifier blocks: keep the exact command for the user
R11|skills/st-update/SKILL.md|Per folder: what changed, what was skipped and why, the commands the user must run.
R11b|skills/st-update/SKILL.md|Restart running Claude Code sessions in these folders to load Stratum <version>.
R11c|skills/st-update/SKILL.md|Name each worktree and item skipped at the gate.
R12|skills/st-update/SKILL.md|Never: change a user data file (FR-013), write before the gate, stage a path it did not change, run `claude plugin update` in a folder without its own record, edit `installed_plugins.json`.
R13|README.md|claude plugin update stratum@stratum -s local
R13b|README.md|claude plugin update stratum@stratum -s project
R13c|README.md|bash tests/test_st_update.sh
R13d|README.md|bash tests/test_update_rules.sh
R13e|README.md|bash tests/test_update_items.sh
GI1|skills/st-init/SKILL.md|12. **Git instructions.**
GI2|skills/st-init/SKILL.md|with jq into only that file. Keep every other key.
GI3|skills/st-init/SKILL.md|`CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` is set
GI4|skills/st-init/SKILL.md|13. **Report**
GI4b|skills/st-init/SKILL.md|Not at all: write no settings file, and write the empty file `.stratum/git-instructions-kept` so the question is not asked again.
GI4c|skills/st-init/SKILL.md|`.stratum/advisor.json`, `.stratum/git-instructions-kept`,
GI5|skills/st-update/SKILL.md|Built-in git instructions, once per run:
GI5b|skills/st-update/SKILL.md|or for "not at all" the marker in each listed folder
GI6|skills/st-update/SKILL.md|ponytail: one-time step for checkouts set up before 019, remove it when every Stratum checkout on the PC and the laptop has run this update
GI7|skills/st-update/SKILL.md|and `.claude/settings.json` or `.stratum/git-instructions-kept` when the git instructions paragraph wrote it,
GI8|agents/st-git.md|Run it as `git commit -m 'subject' -m 'body'`: single quotes, no heredoc, no backticks, no `$(`, no `-F`.
GI9|agents/st-git.md|Exception: a deny that starts with `Commit form denied:`.
ROWS

check "front matter skills/st-update/SKILL.md" 'head -n 5 "$root/skills/st-update/SKILL.md" | grep -qx "name: st-update"'

check "R9d no veent-commit-ask skills/st-update/SKILL.md" 'test -f "$root/skills/st-update/SKILL.md" && ! grep -qF -- veent-commit-ask "$root/skills/st-update/SKILL.md"'

exit $fail
