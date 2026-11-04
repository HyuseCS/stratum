---
name: st-update
description: Audit the project's Stratum files in every checkout, then update the install, statusline and harness lines after one OK.
---

# /stratum:st-update [folder]

Plugin root is two levels up from this skill's base directory. `<script>` is
`<plugin root>/scripts/st-update.sh`. Put single quotes around every argument you pass to the
script and to git (folder, kind, name, paths, message).

1. **Audit.** Run `bash <script> audit <folder>`, with the argument as `<folder>`, else the project root.
   Exit 1: show the line and stop.
   No row other than `current`, `gone` and `listed`: say every item is current and stop. No gate.
   Only `warn`, `invalid` or `skip` rows besides those: show those rows with their details, say st-update can change nothing here, and stop. No gate.
2. **Table.** Show one table. The header: the marketplace version and folder, and the config folder.
   The config folder is `$CLAUDE_CONFIG_DIR`, else `~/.claude`.
   Then, per folder, only the rows that are not `current`: folder, kind, name, state, detail.
   Then one line per folder with the count of its `current` items.
   A folder with `worker` in a detail is a worker worktree: say so on its rows and its count line.
3. **Gate.** A `marketplace-branch` row: above the question, warn
   `The marketplace folder <installLocation> is on branch <branch>, not main. The update installs that branch.`
   Then ask one question: OK to update all, or `skip <worktree>` or `skip <folder> <kind> <name>` (one or more each), or no.
   No: stop, nothing changed.
   Change nothing before the OK.
   A skipped worktree or item is left out of every step after the gate, and the report names it.
   An item is named by its folder, kind and name, as the table shows them.
   An `allow` item is named as `fix` names it: `skip <folder> allow <settings file>:<entry>`.
   A skip that names no row: say so and ask again.
4. **Plugin.** For each folder with an `install` row that is `outdated`, skipped worktrees and skipped `install` items left out,
   run `bash <script> plugin <folder>`. Exit 0 prints `ok <version> <installPath>`.
   Exit 1 prints the message and a `Run:` command on stderr. Keep both for the report and
   go on with the next folder.
   Then run the step 1 audit once more, with the same argument.
   Steps 5 to 7 take their rows from this second audit.
   Leave the skipped worktrees and items out of these rows.
5. **Ask.**
   For each `ask` row: show the old and the new `statusLine` command and ask. Yes: `fix ... --force`. No: leave it.
6. **Fix.** For every `outdated`, `new` and `discontinued` row, `statusline` rows included and
   `install` rows left out (they have no fix), run
   `bash <script> fix <folder> <kind> <name>`. It prints `changed <file>` or `same <file>`.
   An `allow` row: pass `<detail>:<name>` as the name, the settings file in its detail, a colon, then the entry in its name.
   Exit 3 prints `skip: <reason>` on stderr. Keep the reason for the report.
   `fix statusline` exits 3 when the folder's install is not at the marketplace version.
   Never run `fix` on a `skip` row. Report each `skip` row with its detail.
   A `file` row of `git-guard.json`, `models.json`, `powerline.json` or `advisor.json`:
   ask the question of st-init step 3, 4, 7 or 11, one at a time, each with a `skip` answer.
   Skip: leave the file missing. Else write it as that st-init step does.
   A `constitution.md` row: tell the user to run `/stratum:st-constitution`.
   A Bash call a hook or the classifier blocks: keep the exact command for the user.
7. **Commit.** `<paths>` are the files that `fix` printed in its `changed <file>` lines for this checkout,
   and `.stratum/advisor.json` when step 6 wrote it, minus each file that `git check-ignore` ignores.
   Never `.claude/settings.local.json`, never `.stratum/models.json`, never `.stratum/commit-mode`.
   Per checkout with such a file, one Bash call:
   `git -C <checkout> add -- <paths> && git -C <checkout> commit -m 'chore(stratum): update harness files to <version>' -m '<one line per item>' -- <paths>`
   The commit ends with `-- <paths>`, so files the user staged before stay out of it.
   No `-A`, no `--amend`, no `--no-verify`, no push.
   A denied commit: quote the deny reason and give the exact command (D11).
   Name no personal script. Never work around it.
8. **Report.** Per folder: what changed, what was skipped and why, the commands the user must run.
   Name each worktree and item skipped at the gate.
   Last line: `Restart running Claude Code sessions in these folders to load Stratum <version>.`

Never: change a user data file (FR-013), write before the gate, stage a path it did not change, run `claude plugin update` in a folder without its own record, edit `installed_plugins.json`.
